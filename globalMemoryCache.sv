module globalMemoryCache(
    input logic [31:0] writingMemoryDataGlobal, //the status of each core and whether it is writing memory data
    output logic [31:0] finishedWritingMemoryDataGlobal, //the values to tell each core whether it was finished writing its data
    input logic [31:0] readingMemoryDataGlobal, //the status of each core and whether it is reading memory data
    output logic [31:0] finishedReadingMemoryDataGlobal,  //the values to tell each core whether it was finished reading memory data
    input logic reset,
    input logic clk,
    input logic [1023:0] writeData, //the data to write from the cores
    input logic [1023:0] mar, //the memory addresses for each core
    output logic [1023:0] dataOut, //the data read from the memory for each core
    input logic globalMemFinishedAction, //whether the ddr3 has finished a transacction
    output logic [25:0] globalMemAddr, //the ddr3 address
    output logic [127:0] globalMemDataWrite, //the data to write from the cores
    input logic [127:0] globalMemRead, //the data read from the memory
    output logic [7:0] globalMemoryWriteByteEnable, //Whether to write each byte, depending on whether a core is active
    output logic globalEnable, //whether to activate the memory for a transaction
    output logic globalWriteEnable //whether a memory transaction is a read or a write
);
    import gpuCoreTypes::*; // Import the package of memory cache states
    
    memState state;
    
    function memState getMemState(); //for simulation purposes
        return state;
    endfunction
    
    logic [30:0] adjacencyChecker; // whether each address is adjacent to its neighboring address (should be increasing)
    
    
    logic [4:0] nonAdjacentCounter, nonAdjacentCounterPlusOne;
    logic [2:0] adjacentCounter, adjacentCounterPlusOne;
    logic [2:0] adjacentOffAxisWriteCounter, adjacentOffAxisWriteCounterPlusOne;
    logic cacheHitBit;

    (* MARK_DEBUG = "TRUE" *) logic [2:0] adjacentCounterDebug; //should be optimized away during implementation
    assign adjacentCounterDebug = adjacentCounter;




    logic [31:0] masterMar; //the memory address to either search the cache or the ddr3
    logic [127:0] nonAdjacentMasterDataIn; 
    logic [127:0] masterDataIn;

    logic [127:0] globalMemReadRegister; //the register saving the value of the ddr3 read

    logic [127:0] dataBramOut, dataBramIn; // inputs and output for the cache data

    logic [15:0] bramHeaderDataIn, bramHeaderDataOut; //inputs and outputs for the cache tags
    logic [10:0] bramHeaderAddress; //the hashed value of the bram

    logic [3:0] dataBramIndividualEnable, dataBramSegmentsOn; //whether to enable each cache data bram to allow for writing in 32-bit segments only

    logic [1:0] lateMarBits; //the first two bits of core 0's memory address. This means the system breaks if core 0 does not write but other cores do.

    logic [3:0] globalMemoryWriteByteEnableConcatenated; //I only allow cores to write in 32-bit segments.

    logic [10:0] resetHeaderBramCounter; //to reset the header bram to all xFFFFs upon reset. This prevents the cache from holding bad data.
    
    logic headerBramEnable, headerBramWriteEnable, dataBramEnable, dataBramWriteEnable, loadDataBramFromGlobal;
    logic loadGlobalMemReadRegister, globalMemFinishedActionReg;
    always_ff @(posedge clk) begin
        if(reset) begin
            state <= Idle;
            nonAdjacentCounter <= 0;
            adjacentCounter <= 0;
            adjacentOffAxisWriteCounter <= 0;
            globalMemReadRegister <= 0;
            lateMarBits <= 0;
            resetHeaderBramCounter <= 0;
            globalMemFinishedActionReg <= 0; 
            globalMemoryWriteByteEnableConcatenated <= 0;
        end
        else begin
            globalMemFinishedActionReg <= globalMemFinishedAction; //I pipelined this because the signal does not propogate far enough otherwise 
            if(resetHeaderBramCounter != 11'h7FF) begin //increment resetHeaderBramCounter until it reaches all 1's
                resetHeaderBramCounter <= resetHeaderBramCounter + 1;
            end

            case(state) //state transitions
                Idle: state <= (|writingMemoryDataGlobal) ? adjacentCheckWrite : ((|readingMemoryDataGlobal) ? adjacentCheckRead : Idle); //If idle, next decide whether to read or write

                //If it's a read, decide whether it is adjacent - if it is, decide whether it is on an even axis or the first and last reads should be treated specially
                adjacentCheckRead: state <= (&adjacencyChecker) ? ((mar[1:0] == 2'b00) ? adjacentReadRegularLoadMasters : adjacentReadOffAxisFirstLoadMasters) : nonAdjacentReadLoadMasters;
                //If it's a write, decide whether it is adjacent - if it is, decide whether it is on an even axis or the first and last writes should be treated specially
                adjacentCheckWrite: state <= (&adjacencyChecker) ? ((mar[1:0] == 2'b00) ? adjacentWriteRegularLoadMasters : adjacentWriteOffAxisFirstLoadMasters) : nonAdjacentWriteLoadMasters;

                //reading off-axis data. The first read not-aligned with the ddr3 addressability 4 times larger than the core size (128 bits)
                adjacentReadOffAxisFirstLoadMasters: state <= adjacentReadOffAxisFirstSearchHeader1; //load the master address
                adjacentReadOffAxisFirstSearchHeader1: state <= adjacentReadOffAxisFirstCheckHit; // check whether the value is in cache (search the tag)
                adjacentReadOffAxisFirstSearchHeader2: state <= adjacentReadOffAxisFirstCheckHit; //should never reach.
                //if the tag matches, we call it a "cache hit." Branch accordingly.
                adjacentReadOffAxisFirstCheckHit: state <= (cacheHitBit) ? adjacentReadOffAxisFirstCacheHitDistributeData : adjacentReadOffAxisFirstCacheMissGlobalRead1;
                adjacentReadOffAxisFirstCacheHitDistributeData: state <= adjacentReadRegularLoadMasters; //if it was a cache hit, tell the cores it was a hit, and send the read data to the cores.
                adjacentReadOffAxisFirstCacheMissGlobalRead1: state <= adjacentReadOffAxisFirstCacheMissGlobalRead2; //if it was a miss, send the ddr3 the data request
                //Then, wait until the ddr3 comes back with a response.
                adjacentReadOffAxisFirstCacheMissGlobalRead2: state <= (globalMemFinishedActionReg) ? adjacentReadOffAxisFirstCacheMissDistributeData : adjacentReadOffAxisFirstCacheMissGlobalRead2;
                adjacentReadOffAxisFirstCacheMissDistributeData: state <= adjacentReadRegularLoadMasters; //send the cores the data, and send the cache the read data too.

                //Occurs 6 times.
                adjacentReadRegularLoadMasters: state <= adjacentReadRegularSearchHeader1; // load the master Memory address register with the correct address
                adjacentReadRegularSearchHeader1: state <= adjacentReadRegularCheckHit; //send the cache tag BRAM the address to search whether the data is in the cache
                adjacentReadRegularSearchHeader2: state <= adjacentReadRegularCheckHit; //should be unreachable
                //if the tag matches, we call it a "cache hit." Branch accordingly.
                adjacentReadRegularCheckHit: state <= (cacheHitBit) ? adjacentReadRegularCacheHitDistributeData : adjacentReadRegularCacheMissGlobalRead1;
                //If the cache was a hit, distribute the data to the cores. Also, if it is the 6th read (24 cores / 4 cores per read), return to idle state
                adjacentReadRegularCacheHitDistributeData: state <= (adjacentCounter==3'b101) ? Idle : adjacentReadRegularLoadMasters;
                adjacentReadRegularCacheMissGlobalRead1: state <= adjacentReadRegularCacheMissGlobalRead2; //If it was a miss, send the command to the ddr3
                adjacentReadRegularCacheMissGlobalRead2: state <= (globalMemFinishedActionReg) ? adjacentReadRegularCacheMissDistributeData : adjacentReadRegularCacheMissGlobalRead2; //wait for the ddr3 to finish
                adjacentReadRegularCacheMissDistributeData: state <= (adjacentCounter==3'b101) ? Idle : adjacentReadRegularLoadMasters; //when finished, distribute read data, and if it's the 6th read, return to idle state.

                //Non adjacent reads. Loops 24 times, one for each core
                nonAdjacentReadLoadMasters: state <= nonAdjacentReadSearchHeader1; //load the master memory address register with the correct address
                nonAdjacentReadSearchHeader1: state <= nonAdjacentReadCheckHit; //send the address to the cache tag bram, searching whether the data is present
                nonAdjacentReadSearchHeader2: state <= nonAdjacentReadCheckHit; //should never happen, unreachable
                nonAdjacentReadCheckHit: state <= (cacheHitBit) ? nonAdjacentReadCacheHitDistributeData : nonAdjacentReadCacheMissGlobalRead1; //branch whether the data is in cache or not
                //If the data is present in cache, distribute it the cores. Only do another read if there are more reads requested by the cores.
                nonAdjacentReadCacheHitDistributeData: state <= ((nonAdjacentCounter == 5'b10111) || ~(|readingMemoryDataGlobal)) ? Idle : nonAdjacentReadLoadMasters; 
                nonAdjacentReadCacheMissGlobalRead1: state <= nonAdjacentReadCacheMissGlobalRead2; //if cache miss, send data request to the ddr3
                nonAdjacentReadCacheMissGlobalRead2: state <= (globalMemFinishedActionReg) ? nonAdjacentReadCacheMissDistributeData : nonAdjacentReadCacheMissGlobalRead2; //when the ddr3 responds, distribute the data after
                //When the data has been read by the ddr3, write it to the cache, and send it to the cores. Continue reading for next cycle if there are more cores requesting data
                nonAdjacentReadCacheMissDistributeData: state <= ((nonAdjacentCounter == 5'b10111 )|| ~(|readingMemoryDataGlobal)) ? Idle : nonAdjacentReadLoadMasters;

                //Adjacent, off axis writes
                adjacentWriteOffAxisFirstLoadMasters: state <= adjacentWriteOffAxisFirstSearchHeader; //Load the master memory address register with MAR 1
                adjacentWriteOffAxisFirstSearchHeader: state <= adjacentWriteOffAxisFirstCheckHit; //Send the command to the BRAM to check whether it has the data
                //check the Most significant bits of the addresses stored in the tags. If it is equal, the data is present.
                adjacentWriteOffAxisFirstCheckHit: state <= (cacheHitBit) ? adjacentWriteOffAxisFirstPartialWrite : adjacentWriteOffAxisFirstOnlyGlobal; 
                adjacentWriteOffAxisFirstPartialWrite: state <= adjacentWriteOffAxisFirstGlobalWait; //If the data exists in cache, make sure to overwrite it as well.
                adjacentWriteOffAxisFirstOnlyGlobal: state <= adjacentWriteOffAxisFirstGlobalWait; //If the data doesn't exist in cache, no need to overwrite - just send the write to DDR3
                adjacentWriteOffAxisFirstGlobalWait: state <= (globalMemFinishedActionReg) ? adjacentWriteOffAxisMiddleLoadMasters : adjacentWriteOffAxisFirstGlobalWait; //Wait for DDR3 to respond
                
                
                //regular writes. This will occur 8 times.
                adjacentWriteRegularLoadMasters: state <= adjacentWriteRegularSearchHeader; //Load the master memory address register with MAR 1
                adjacentWriteRegularSearchHeader: state <= adjacentWriteRegularCheckHit; //Send the command to the BRAM to check whether it has the data
                //check the Most significant bits of the addresses stored in the tags. If it is equal, the data is present.
                adjacentWriteRegularCheckHit: state <= (cacheHitBit) ? adjacentWriteRegularWriteBoth : adjacentWriteRegularWriteOnlyGlobal;
                adjacentWriteRegularWriteBoth: state <= adjacentWriteRegularGlobalWait; //If the data exists in cache, make sure to overwrite it as well.
                adjacentWriteRegularWriteOnlyGlobal: state <= adjacentWriteRegularGlobalWait; //If the data doesn't exist in cache, no need to overwrite - just send the write to DDR3
                adjacentWriteRegularGlobalWait: state <= (globalMemFinishedActionReg) ? ((adjacentCounter==3'b101) ? Idle : adjacentWriteRegularLoadMasters) : adjacentWriteRegularGlobalWait; //Wait for DDR3 to respond

                //middle of off axis writes. This will occur seven times.
                adjacentWriteOffAxisMiddleLoadMasters: state <= adjacentWriteOffAxisMiddleSearchHeader; //Load the master memory address register with MAR 1
                adjacentWriteOffAxisMiddleSearchHeader: state <= adjacentWriteOffAxisMiddleCheckHit; //Send the command to the BRAM to check whether it has the data
                //check the Most significant bits of the addresses stored in the tags. If it is equal, the data is present.
                adjacentWriteOffAxisMiddleCheckHit: state <= (cacheHitBit) ? adjacentWriteOffAxisMiddleWriteBoth : adjacentWriteOffAxisMiddleWriteOnlyGlobal; //If the data exists in cache, make sure to overwrite it as well.
                adjacentWriteOffAxisMiddleWriteBoth: state <= adjacentWriteOffAxisMiddleGlobalWait; //If the data exists in cache, make sure to overwrite it as well.
                adjacentWriteOffAxisMiddleWriteOnlyGlobal: state <= adjacentWriteOffAxisMiddleGlobalWait; //If the data doesn't exist in cache, no need to overwrite - just send the write to DDR3
                adjacentWriteOffAxisMiddleGlobalWait: state <= (globalMemFinishedActionReg) ? ((adjacentOffAxisWriteCounter == 3'b100) ? adjacentWriteOffAxisLastLoadMasters : adjacentWriteOffAxisMiddleLoadMasters) : adjacentWriteOffAxisMiddleGlobalWait;
                //Wait for DDR3 to respond
                
                //adjcent, off axis write. Just writes the last segment of data.
                adjacentWriteOffAxisLastLoadMasters: state <= adjacentWriteOffAxisLastSearchHeader; //Last Write in an off-axis series of writes - load the master MAR
                adjacentWriteOffAxisLastSearchHeader: state <= adjacentWriteOffAxisLastCheckHit;//Send the command to the BRAM to check whether it has the data
                //check the Most significant bits of the addresses stored in the tags. If it is equal, the data is present.
                adjacentWriteOffAxisLastCheckHit: state <=  (cacheHitBit) ? adjacentWriteOffAxisLastPartialWrite : adjacentWriteOffAxisLastOnlyGlobal;
                adjacentWriteOffAxisLastPartialWrite: state <= adjacentWriteOffAxisLastGlobalWait; //If the data exists in cache, make sure to overwrite it as well.
                adjacentWriteOffAxisLastOnlyGlobal: state <= adjacentWriteOffAxisLastGlobalWait; //If the data doesn't exist in cache, no need to overwrite - just send the write to DDR3
                adjacentWriteOffAxisLastGlobalWait: state <= (globalMemFinishedActionReg) ? Idle : adjacentWriteOffAxisLastGlobalWait; //When the DDR3 responds, because it is the last write, return to Idle

                //loops 24 times. Writes all core data streams.
                nonAdjacentWriteLoadMasters: state <= nonAdjacentWriteSearchHeader1; //Load the master memory address register
                nonAdjacentWriteSearchHeader1: state <= nonAdjacentWriteCheckHit; //Send the command to the cache address tag BRAM
                nonAdjacentWriteCheckHit: state <= (cacheHitBit) ? nonAdjacentWritePartialWrite : nonAdjacentWriteGlobal1; //Check if the cache is a hit or not by comparing MSBs of tag
                nonAdjacentWritePartialWrite: state <= nonAdjacentWriteGlobal2; //Write to both cache and to DDR3
                nonAdjacentWriteGlobal1: state <= nonAdjacentWriteGlobal2; //Send write command only to DDR3
                nonAdjacentWriteGlobal2: state <= (globalMemFinishedActionReg) ? (((nonAdjacentCounter == 5'b10111)  | ~(|writingMemoryDataGlobal)) ? Idle : nonAdjacentWriteLoadMasters) : nonAdjacentWriteGlobal2;
                //When DDR3 responds, check whether all 24 cores have finished writing - if so, return to Idle
            endcase
            if(state == Idle) begin  //If Idle, reset counters
                nonAdjacentCounter <= 0;
                adjacentCounter <= 0;
                adjacentOffAxisWriteCounter <= 0;
            end
            else begin
                if(state == adjacentReadRegularCacheHitDistributeData || state == adjacentReadRegularCacheMissDistributeData || ((state == adjacentWriteRegularGlobalWait) && (globalMemFinishedActionReg))) begin
                    adjacentCounter <= adjacentCounterPlusOne; //increment adjacent counter when an adjacent read or write completes
                end
                if((state == nonAdjacentWriteGlobal2 && globalMemFinishedActionReg)||
                state == nonAdjacentReadCacheHitDistributeData || state == nonAdjacentReadCacheMissDistributeData) begin
                    nonAdjacentCounter <= nonAdjacentCounterPlusOne;//increment non-adjacent counter when a non-adjacent read or non-adjacent write completes
                end
                if(state == adjacentWriteOffAxisMiddleGlobalWait && globalMemFinishedActionReg) begin
                    adjacentOffAxisWriteCounter <= adjacentOffAxisWriteCounterPlusOne; //Increment adjacentOffAxisWriteCounter when a write which is off-axis completes
                end
            end

            if(state == adjacentReadOffAxisFirstLoadMasters) begin 
                masterMar <= mar[31:0]; //on adjacent off-axis reads, the first core begins first
            end
            else if (state == adjacentReadRegularLoadMasters) begin //on regular adjacent reads, multiplex the correct memory address
                //The adjacent counter determines the first 3 selector bits, and of the 128 other memory bits, index 4 minus last two core bits
                masterMar <= mar[ { adjacentCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0], 5'b00000} +: 32];
            end
            else if (state == nonAdjacentReadLoadMasters) begin //On non-adjacent reads, the non-adjacent counter selects which address to choose, linearly
                masterMar <= mar[{nonAdjacentCounter[4:0], 5'b00000} +:32];
            end
            else if (state == adjacentWriteOffAxisFirstLoadMasters) begin
                masterMar <= mar[31:0]; //for off-axis adjacent writes, the first core begins
            end
            else if (state == adjacentWriteRegularLoadMasters) begin //On a regular write, select the address with the adjacent counter times 'd128
                masterMar <= mar[{ adjacentCounter[2:0], 2'b00, 5'b00000} +: 32];
            end
            else if (state == adjacentWriteOffAxisMiddleLoadMasters) begin //On a middle off-axis write, after selecting 'd128 bit pair, select 32 bit word using 4-mar[1:0]
                masterMar <= mar[{ adjacentOffAxisWriteCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0], 5'b00000} +: 32];  
            end
            else if (state == adjacentWriteOffAxisLastLoadMasters) begin //On an off-axis write, for the last one, just pick the last 128 bits
                masterMar <= mar[{3'b101, lateMarBits[1] ^ lateMarBits[0], lateMarBits[0], 5'b00000} +: 32]; //Then select with 4 - first memory address
            end
            else if (state == nonAdjacentWriteLoadMasters) begin //On non-adjacent write, just select which memory address using non-adjacent counter
                masterMar <= mar[{nonAdjacentCounter[4:0], 5'b00000} +:32];
            end


            if (state == adjacentWriteOffAxisFirstLoadMasters) begin
                case(mar[1:0])//write 32 * (4 - first two bits of first core address) to most significant bits of masterDataIn register
                    2'b01: masterDataIn[127:32] <= writeData[95:0]; 
                    2'b10: masterDataIn[127:64] <= writeData[63:0]; 
                    2'b11: masterDataIn[127:96] <= writeData[31:0];
                endcase
            end
            else if (state == adjacentWriteRegularLoadMasters) begin //On a regular write, just use adjacent counter as a selector counter
                masterDataIn <= writeData[{adjacentCounter[2:0], 2'b00, 5'b00000} +: 128];
            end
            else if (state == adjacentWriteOffAxisMiddleLoadMasters) begin //On the middle write of an off-axis write, use the counter to select 128 bit groups
                masterDataIn <= writeData[{adjacentOffAxisWriteCounter[2:0], lateMarBits[1]^lateMarBits[0], lateMarBits[0], 5'b00000} +: 128]; //Then use 4 - (mar[1:0])
            end
            else if (state == adjacentWriteOffAxisLastLoadMasters) begin //On the last write of an off-axis adjacent write
                case(mar[1:0]) //write 32 * (4 - mar[1:0])
                    2'b01: masterDataIn[31:0] <= writeData[767:736];
                    2'b10: masterDataIn[63:0] <= writeData[767:704];
                    2'b11: masterDataIn[95:0] <= writeData[767:672];
                endcase
            end
            else if (state == nonAdjacentWriteLoadMasters) begin //if the write is non-adjacent
                masterDataIn <= nonAdjacentMasterDataIn; //just use the non-adjacent counter as selector bits for the writeData.
            end

            if(loadGlobalMemReadRegister) begin //loadGlobalMemReadRegister saves the output from the DDR3
                globalMemReadRegister <= globalMemRead;
            end

            if(state == Idle) begin //save the first two bits of mar, as this will allow for understanding on-axis vs off-axis reads/writes
                lateMarBits <= mar[1:0];
            end

            if (state == adjacentWriteRegularWriteOnlyGlobal || state == adjacentWriteRegularWriteBoth) begin //If a regular read, use adjacentCounter as selector bits for which cores are active
                globalMemoryWriteByteEnableConcatenated <= writingMemoryDataGlobal[{adjacentCounter[2:0], 2'b00} +: 4];
            end
            else if (state == adjacentWriteOffAxisMiddleWriteOnlyGlobal || state == adjacentWriteOffAxisMiddleWriteBoth) begin //If off-axis, offset by 4-mar[1:0]
                globalMemoryWriteByteEnableConcatenated <= writingMemoryDataGlobal[{adjacentOffAxisWriteCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4];
            end
                                
                   
            else if (state == adjacentWriteOffAxisLastPartialWrite || state == adjacentWriteOffAxisLastOnlyGlobal) begin
                case(lateMarBits) //for last off-axis write, only write 32 sets of mar[1:0] bits total
                    2'b01: globalMemoryWriteByteEnableConcatenated <= {3'b000, writingMemoryDataGlobal[23]};
                    2'b10: globalMemoryWriteByteEnableConcatenated <= {2'b00, writingMemoryDataGlobal[23:22]};
                    2'b11: globalMemoryWriteByteEnableConcatenated <= {1'b0, writingMemoryDataGlobal[23:21]};
                endcase
            end
            
            else if (state == adjacentWriteOffAxisFirstPartialWrite || state == adjacentWriteOffAxisFirstOnlyGlobal) begin
                case(lateMarBits)//for last off-axis write, only write 32 sets of 4 - mar[1:0] bits total
                    2'b01: globalMemoryWriteByteEnableConcatenated <= {writingMemoryDataGlobal[2:0], 1'b0};
                    2'b10: globalMemoryWriteByteEnableConcatenated <= {writingMemoryDataGlobal[1:0], 2'b00};
                    2'b11: globalMemoryWriteByteEnableConcatenated <= {writingMemoryDataGlobal[0], 3'b000};
                endcase
            end
            
            else if (state == nonAdjacentWriteGlobal1 || state == nonAdjacentWritePartialWrite) begin
                globalMemoryWriteByteEnableConcatenated <= 0; //on non-adjacent writes, only write one set of 32 bits
                globalMemoryWriteByteEnableConcatenated[masterMar[1:0]] <= writingMemoryDataGlobal[nonAdjacentCounter];
            end


        end
    end

    always_comb begin
        adjacentCounterPlusOne = adjacentCounter + 1; //incremented counters
        nonAdjacentCounterPlusOne = nonAdjacentCounter + 1;
        adjacentOffAxisWriteCounterPlusOne = adjacentOffAxisWriteCounter + 1;
        
        nonAdjacentMasterDataIn = 128'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
        case(mar[{nonAdjacentCounter[4:0], 5'b00000}+: 2]) //depending on the mar, write only 32 bits to one of four locations in the masterDataIn
            2'b00: nonAdjacentMasterDataIn[31:0] = writeData[{nonAdjacentCounter[4:0], 5'b00000} +: 32];
            2'b01: nonAdjacentMasterDataIn[63:32] = writeData[{nonAdjacentCounter[4:0], 5'b00000} +: 32];
            2'b10: nonAdjacentMasterDataIn[95:64] = writeData[{nonAdjacentCounter[4:0], 5'b00000} +: 32];
            2'b11: nonAdjacentMasterDataIn[127:96] = writeData[{nonAdjacentCounter[4:0], 5'b00000} +: 32];
        endcase



        headerBramEnable = 0;
        if (state inside { //all conditions for whether to enable the cache tag BRAM
            adjacentReadOffAxisFirstSearchHeader1, 
            adjacentReadOffAxisFirstCacheMissDistributeData, 
            adjacentReadRegularSearchHeader1, 
            adjacentReadRegularCacheMissDistributeData,
            nonAdjacentReadSearchHeader1,
            adjacentWriteOffAxisFirstSearchHeader,
            adjacentWriteOffAxisFirstPartialWrite,
            adjacentWriteRegularSearchHeader,
            adjacentWriteRegularWriteBoth,
            adjacentWriteOffAxisMiddleSearchHeader,
            adjacentWriteOffAxisMiddleWriteBoth,
            adjacentWriteOffAxisLastSearchHeader,
            adjacentWriteOffAxisLastPartialWrite,
            nonAdjacentWriteSearchHeader1,
            nonAdjacentWritePartialWrite
        }) begin
            headerBramEnable = 1;

        unique case (state)
            // States where headerBramWriteEnable = 0
            adjacentReadOffAxisFirstSearchHeader1, //These are all cases when reading
            adjacentWriteRegularSearchHeader,
            adjacentReadRegularSearchHeader1,
            nonAdjacentReadSearchHeader1,
            adjacentWriteOffAxisFirstSearchHeader,
            adjacentWriteOffAxisLastSearchHeader,
            adjacentWriteOffAxisMiddleSearchHeader,
            nonAdjacentWriteSearchHeader1: headerBramWriteEnable = 0;
    
            // States where headerBramWriteEnable = 1
            adjacentReadOffAxisFirstCacheMissDistributeData, //These are all cases when writing
            adjacentReadRegularCacheMissDistributeData,
            adjacentWriteOffAxisFirstPartialWrite,
            adjacentWriteRegularWriteBoth,
            adjacentWriteOffAxisMiddleWriteBoth,
            adjacentWriteOffAxisLastPartialWrite,
            nonAdjacentWritePartialWrite: headerBramWriteEnable = 1;
    
            // Default case (optional)
            default: headerBramWriteEnable = 0; //This should be when the BRAM is disabled
        endcase
        
        end


        dataBramEnable = 0;
        if (state inside { //All conditions for whether to enable the cache data BRAMs
            adjacentReadOffAxisFirstSearchHeader1, 
            adjacentReadOffAxisFirstCacheMissDistributeData, 
            adjacentReadRegularSearchHeader1, 
            adjacentReadRegularCacheMissDistributeData,
            nonAdjacentReadSearchHeader1,
            adjacentWriteOffAxisFirstPartialWrite,
            adjacentWriteRegularWriteBoth,
            adjacentWriteOffAxisMiddleWriteBoth,
            adjacentWriteOffAxisLastPartialWrite,
            nonAdjacentWritePartialWrite
        }) begin
            dataBramEnable = 1;
        end

        case (state)
        // States where headerBramWriteEnable = 0
            adjacentReadOffAxisFirstSearchHeader1, //Only scenarios when reading and checking for a cache hit - preload data to be ready
            adjacentReadRegularSearchHeader1,
            nonAdjacentReadSearchHeader1: dataBramWriteEnable = 0;

            // States where headerBramWriteEnable = 1
            adjacentReadOffAxisFirstCacheMissDistributeData, //scenarios when to overwrite data in the cache
            adjacentReadRegularCacheMissDistributeData,
            adjacentWriteOffAxisFirstPartialWrite,
            adjacentWriteRegularWriteBoth,
            adjacentWriteOffAxisMiddleWriteBoth,
            adjacentWriteOffAxisLastPartialWrite,
            nonAdjacentWritePartialWrite: dataBramWriteEnable = 1;

            // Default case (optional)
            default: dataBramWriteEnable = 1'bx;
        endcase


        if(state inside {
            adjacentReadOffAxisFirstCacheMissGlobalRead1, //All conditions whhen to turn on DDR3
            adjacentReadRegularCacheMissGlobalRead1,
            nonAdjacentReadCacheMissGlobalRead1,
            adjacentWriteOffAxisFirstPartialWrite,
            adjacentWriteOffAxisFirstOnlyGlobal,
            adjacentWriteRegularWriteOnlyGlobal,
            adjacentWriteOffAxisMiddleWriteBoth,
            adjacentWriteOffAxisMiddleWriteOnlyGlobal,
            adjacentWriteRegularWriteBoth,
            adjacentWriteOffAxisLastPartialWrite,
            adjacentWriteOffAxisLastOnlyGlobal
        }) begin
            globalEnable = 1;
        end
        else if (state inside { 
            nonAdjacentWriteGlobal1,
            nonAdjacentWritePartialWrite        
        }) begin
            globalEnable = 1; //Just turn off the DDR3 writing by using writeBytes
        end
        else begin
            globalEnable = 0; //Otherwise the memory should be off
        end
        

        case (state)
            adjacentReadOffAxisFirstCacheMissGlobalRead1, //read when there is a cache miss
            adjacentReadRegularCacheMissGlobalRead1,
            nonAdjacentReadCacheMissGlobalRead1: globalWriteEnable = 0;

            adjacentWriteOffAxisFirstPartialWrite, //Otherwise, write during all writing cases
            adjacentWriteOffAxisFirstOnlyGlobal,
            adjacentWriteRegularWriteBoth,
            adjacentWriteOffAxisMiddleWriteBoth,
            adjacentWriteOffAxisMiddleWriteOnlyGlobal,
            adjacentWriteRegularWriteOnlyGlobal,
            adjacentWriteOffAxisLastPartialWrite,
            adjacentWriteOffAxisLastOnlyGlobal,
            nonAdjacentWriteGlobal1,
            nonAdjacentWritePartialWrite: globalWriteEnable = 1;

            // Default case (optional)
            default: globalWriteEnable = 1'bx;
        endcase

        unique case(state) //This signal writes data to the data BRAM straight from the DDR3 read register rather than from the cores
            adjacentReadOffAxisFirstCacheMissDistributeData, 
            adjacentReadRegularCacheMissDistributeData,
            nonAdjacentReadCacheMissDistributeData: loadDataBramFromGlobal = 1; //If the cache was a miss and the data comes back

            adjacentWriteOffAxisFirstPartialWrite,
            adjacentWriteRegularWriteBoth,
            adjacentWriteOffAxisMiddleWriteBoth,
            adjacentWriteOffAxisMiddleWriteOnlyGlobal,
            adjacentWriteRegularWriteOnlyGlobal,
            adjacentWriteOffAxisLastPartialWrite,
            nonAdjacentWritePartialWrite: loadDataBramFromGlobal = 0; //Some of these states are unnecessary I think

            default: loadDataBramFromGlobal = 1'bx;
        endcase


        case(state) //Only load the DDR3 read register when a read cache miss occurs and the DDR3 is activated
            adjacentReadOffAxisFirstCacheMissGlobalRead2,
            adjacentReadRegularCacheMissGlobalRead2,
            nonAdjacentReadCacheMissGlobalRead2: loadGlobalMemReadRegister = 1;
            default: loadGlobalMemReadRegister = 0;
        endcase

        dataBramIn = (loadDataBramFromGlobal) ? globalMemReadRegister : masterDataIn; //The data bram data should be loaded from either the cores or the DDR3 read cache miss

        globalMemAddr = {masterMar[24:2], 3'b000}; //Bits [3:1] should always be 0. If they aren't I screwed up (unless there is a non-consecutive write, in which case it is expected)
        
        globalMemDataWrite = masterDataIn; //We write the data from the master data in register
        
        bramHeaderDataIn = (resetHeaderBramCounter != 11'h7FF) ? 16'hFFFF : {4'b0000, masterMar[24:13]}; //Twelve bits in the data, unless we are resetting the cache to not read bad data.
        
        bramHeaderAddress = (resetHeaderBramCounter != 11'h7FF) ? resetHeaderBramCounter : masterMar[12:2]; //Eleven bits in the address. I have enough room I think if I wanted to to double this.
        
        cacheHitBit = bramHeaderDataOut[11:0] == masterMar[24:13]; // The cache is a hit if the tags in the BRAM header, and if it matches the mar, it is a success!


        if(state == adjacentReadOffAxisFirstCacheMissDistributeData || state == adjacentReadOffAxisFirstSearchHeader1) begin
            dataBramSegmentsOn = 4'b1111; //no harm to writing all of the data
        end
        else if (state == adjacentReadRegularCacheMissDistributeData || state == adjacentReadRegularSearchHeader1) begin
              dataBramSegmentsOn = 4'b1111; //no harm to writing all of the data
        end
        else if (state == nonAdjacentReadCacheMissDistributeData) begin
            // dataBramSegmentsOn = 0; //This doesn't need to be the case I think
            // dataBramSegmentsOn[masterMar[1:0]] = readingMemoryDataGlobal[nonAdjacentCounter];
              dataBramSegmentsOn = 4'b1111; //no harm to writing all of the data
        end

        //Now for writes
        else if (state == adjacentWriteOffAxisFirstPartialWrite) begin
            case(lateMarBits) //If the cache was hit, only write 32 * (4 - mar[1:0]) bits
                2'b01: dataBramSegmentsOn = {writingMemoryDataGlobal[2:0], 1'b0};
                2'b10: dataBramSegmentsOn = {writingMemoryDataGlobal[1:0], 2'b00};
                2'b11: dataBramSegmentsOn = {writingMemoryDataGlobal[0], 3'b000};
                default: dataBramSegmentsOn = 4'h0;
            endcase
        end
        
        else if (state == adjacentWriteRegularWriteBoth) begin // write only the brams that the cores want to write to
            dataBramSegmentsOn = writingMemoryDataGlobal[{adjacentCounter[2:0], 2'b00} +: 4];
        end
        else if (state == adjacentWriteOffAxisMiddleWriteBoth) begin // write only the brams that the cores want to write to, offsetting the indices using 4 - mar[1:0]
            dataBramSegmentsOn = writingMemoryDataGlobal[{adjacentOffAxisWriteCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4];
        end
               
        else if (state == adjacentWriteOffAxisLastPartialWrite) begin 
            case(lateMarBits) // for the last write on adjacent off-axis, only write mar[1:0] segments.
                2'b01: dataBramSegmentsOn = {3'b000, writingMemoryDataGlobal[23]};
                2'b10: dataBramSegmentsOn = {2'b00, writingMemoryDataGlobal[23:22]};
                2'b11: dataBramSegmentsOn = {1'b0, writingMemoryDataGlobal[23:21]};
            endcase
        end
        else if (state == nonAdjacentWritePartialWrite) begin //On non-adjacent writes with cache hits, only write 1 of 4 bram segments, depending
            dataBramSegmentsOn = 0; //                          On the pixel axis of the write
            dataBramSegmentsOn[masterMar[1:0]] = writingMemoryDataGlobal[nonAdjacentCounter];
        end
        else begin
            dataBramSegmentsOn = 4'b0000; //Otherwise don't write anything
        end



        globalMemoryWriteByteEnable[1:0] = {2{globalMemoryWriteByteEnableConcatenated[0]}}; //Only allow 32 bits to be written at a time
        globalMemoryWriteByteEnable[3:2] = {2{globalMemoryWriteByteEnableConcatenated[1]}};
        globalMemoryWriteByteEnable[5:4] = {2{globalMemoryWriteByteEnableConcatenated[2]}};
        globalMemoryWriteByteEnable[7:6] = {2{globalMemoryWriteByteEnableConcatenated[3]}};


        dataBramIndividualEnable = {4{dataBramEnable}} & dataBramSegmentsOn; //only turn the cache data brams on when they should be turned on and individual cores are turned on

        dataOut = 128'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
        if(state == adjacentReadOffAxisFirstCacheHitDistributeData) begin 
            case(mar[1:0])//distribute the bram data to different cores on cache hits for the first adjacent off-axis reads.
                2'b01: dataOut[95:0] = dataBramOut[127:32];
                2'b10: dataOut[63:0] = dataBramOut[127:64];
                2'b11: dataOut[31:0] = dataBramOut[127:96];
            endcase
        end
        else if (state == adjacentReadRegularCacheHitDistributeData) begin // for regular reads, send data to the cores from the cache depending on the counter index and mar[1:0]
            dataOut[{adjacentCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0], 5'b00000} +: 128] = dataBramOut;
        end
        else if (state == nonAdjacentReadCacheHitDistributeData) begin //For non-adjacent reads, send the core indexed by nonAdjacentCounter the data from the data BRAM depending on its last two address bits
            dataOut[{nonAdjacentCounter[4:0], 5'b00000} +: 32] = dataBramOut[{masterMar[1:0], 5'b00000} +: 32];
        end 
        else if (state == adjacentReadOffAxisFirstCacheMissDistributeData) begin
            case(mar[1:0]) //If the read is the first off axis read and the cache hits, distribute the data to the cores
                2'b01: dataOut[95:0] = globalMemReadRegister[127:32];
                2'b10: dataOut[63:0] = globalMemReadRegister[127:64];
                2'b11: dataOut[31:0] = globalMemReadRegister[127:96];
            endcase
        end
        else if (state == adjacentReadRegularCacheMissDistributeData) begin // if the read was a cache miss, distribute the data from the DDR3 read register
            dataOut[{adjacentCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0], 5'b00000} +: 128] = globalMemReadRegister;
        end
        else if (state == nonAdjacentReadCacheMissDistributeData) begin // if the read was a cache miss, distribute only the data from the DDR3 read register that matches that core that was read
            dataOut[{nonAdjacentCounter[4:0], 5'b00000} +: 32] = globalMemReadRegister[{masterMar[1:0], 5'b00000} +: 32];
        end



        finishedWritingMemoryDataGlobal = 0;
        if(state == adjacentWriteOffAxisFirstGlobalWait && globalMemFinishedActionReg) begin
            case(lateMarBits) //if the write is the first non-adjacent, only tell the first 4-mar[1:0] cores they are finished
                2'b01: finishedWritingMemoryDataGlobal[2:0] = 3'b111;
                2'b10: finishedWritingMemoryDataGlobal[2:0] = 3'b011;
                2'b11: finishedWritingMemoryDataGlobal[2:0] = 3'b001;
            endcase        
        end
        else if (state == adjacentWriteRegularGlobalWait && globalMemFinishedActionReg) begin
            finishedWritingMemoryDataGlobal[{adjacentCounter, 2'b00} +: 4] = 4'b1111; //Tell the four cores they are finished on writes. 
        end                                                                          //You are allowed to tell an Idle core it is finished
        
        else if (state == adjacentWriteOffAxisMiddleGlobalWait && globalMemFinishedActionReg) begin //Same above but for non-adjacent writes, offset by 4 - mar[1:0]
            finishedWritingMemoryDataGlobal[{adjacentOffAxisWriteCounter, lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4] = 4'b1111;
        end
                      
        else if (state == adjacentWriteOffAxisLastGlobalWait && globalMemFinishedActionReg) begin
            case(lateMarBits) //On the last write, tell the last cores they are finished
                2'b01: finishedWritingMemoryDataGlobal[23:21] = 3'b100; //This isn't strictly necessary, but they should all be done regardless.
                2'b10: finishedWritingMemoryDataGlobal[23:21] = 3'b110;
                2'b11: finishedWritingMemoryDataGlobal[23:21] = 3'b111;
            endcase       
        end
        else if (state == nonAdjacentWriteGlobal2 && globalMemFinishedActionReg) begin
            finishedWritingMemoryDataGlobal[nonAdjacentCounter] = 1'b1; //When writing non-adjacently, only tell one core at a time that it is finished
        end

        finishedReadingMemoryDataGlobal = 0;
        if(state == adjacentReadOffAxisFirstCacheHitDistributeData) begin
            case(lateMarBits) //when reading on a cache hit or miss on the first off-axis read, tell the first 4 - mar[1:0] they are finished
                2'b01: finishedReadingMemoryDataGlobal[2:0] = 3'b111;
                2'b10: finishedReadingMemoryDataGlobal[2:0] = 3'b011;
                2'b11: finishedReadingMemoryDataGlobal[2:0] = 3'b001;
            endcase        
        end
        else if (state == adjacentReadOffAxisFirstCacheMissDistributeData) begin
            case(lateMarBits)
                2'b01: finishedReadingMemoryDataGlobal[2:0] = 3'b111;
                2'b10: finishedReadingMemoryDataGlobal[2:0] = 3'b011;
                2'b11: finishedReadingMemoryDataGlobal[2:0] = 3'b001;
            endcase           
        end
        else if (state == adjacentReadRegularCacheHitDistributeData) begin //adjacent reads can just be finished reading on either a cache hit or a miss 
            finishedReadingMemoryDataGlobal[{adjacentCounter, lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4] = 4'b1111;
        end
        else if (state == adjacentReadRegularCacheMissDistributeData) begin
            finishedReadingMemoryDataGlobal[{adjacentCounter, lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4] = 4'b1111;    
        end
        else if (state == nonAdjacentReadCacheHitDistributeData || state == nonAdjacentReadCacheMissDistributeData) begin
            finishedReadingMemoryDataGlobal[nonAdjacentCounter] = 1'b1; //When reading non-adjacently, only tell 1 core at a time it is finished, indexed by nonAdjacentCounter
        end

    end
    int adjacencyInt;
    always_comb begin //This checks whether the core addresses are adjacent or not. This algorithm should be improved in the future
        for(adjacencyInt = 0; adjacencyInt < 31; adjacencyInt += 1) begin //If a single core's mar is one minus the next core's mar, then it is adjacent
            adjacencyChecker[adjacencyInt] = (readingMemoryDataGlobal[adjacencyInt + 1] | writingMemoryDataGlobal[adjacencyInt + 1]) &
            ((mar[(adjacencyInt + 1) * 32 +: 32] - mar[(adjacencyInt) * 32 +: 32]) == 32'h0001); // If the core is turned off, it is not adjacent
        end
    
    end    
    
    
    genvar dataBram; // Generate loop variable
    generate
        for(dataBram = 0; dataBram < 4; dataBram+=1) begin //This is going to need to be 4 BRAMs because I can't make a 128 bit wide BRAM
            blk_mem_gen_2 u_blk_mem_gen_2 (
                .clka  (clk),      
                .ena   (dataBramIndividualEnable[dataBram]),       
                .wea   (dataBramWriteEnable),        //different brams will only be either written to or read from at once.
                .addra (masterMar[12:2]),    //hash with the lower bits of the memory address
                .dina  (dataBramIn[dataBram * 32 +: 32]),    
                .douta (dataBramOut[dataBram * 32 +: 32])
            );
        end
    endgenerate
    blk_mem_gen_3 u_blk_mem_gen_3 (
        .clka  (clk),      
        .ena   ( (headerBramEnable | (resetHeaderBramCounter != 11'h7FF)) ),  //If the resetHeaderBramCounter is still counting up, it is enabled and writing.
        .wea   ( (headerBramWriteEnable | (resetHeaderBramCounter != 11'h7FF)) ),        
        .addra (bramHeaderAddress),    
        .dina  (bramHeaderDataIn),    
        .douta (bramHeaderDataOut)
    );
endmodule
