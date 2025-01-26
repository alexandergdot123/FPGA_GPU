module globalMemoryCache(
    input logic [31:0] writingMemoryDataGlobal,
    output logic [31:0] finishedWritingMemoryDataGlobal,
    input logic [31:0] readingMemoryDataGlobal,
    output logic [31:0] finishedReadingMemoryDataGlobal, 
    input logic reset,
    input logic clk,
    input logic [1023:0] writeData,
    input logic [1023:0] mar,
    output logic [1023:0] dataOut,
    input logic globalMemFinishedAction,
    output logic [25:0] globalMemAddr,
    output logic [127:0] globalMemDataWrite,
    input logic [127:0] globalMemRead,
    output logic [7:0] globalMemoryWriteByteEnable,
    output logic globalEnable,
    output logic globalWriteEnable
);
    import gpuCoreTypes::*; // Import the package
    
    memState state;
    
    function memState getMemState();
        return state;
    endfunction
    
    logic [30:0] adjacencyChecker;
    
    
    logic [4:0] nonAdjacentCounter, nonAdjacentCounterPlusOne;
    logic [2:0] adjacentCounter, adjacentCounterPlusOne;
    logic [2:0] adjacentOffAxisWriteCounter, adjacentOffAxisWriteCounterPlusOne;
    logic cacheHitBit;

    (* MARK_DEBUG = "TRUE" *) logic [2:0] adjacentCounterDebug;
    assign adjacentCounterDebug = adjacentCounter;




    logic [31:0] masterMar;
    logic [127:0] nonAdjacentMasterDataIn;
    logic [127:0] masterDataIn;

    logic [127:0] globalMemReadRegister;

    logic [127:0] dataBramOut, dataBramIn;

    logic [15:0] bramHeaderDataIn, bramHeaderDataOut;
    logic [10:0] bramHeaderAddress;

    logic [3:0] dataBramIndividualEnable, dataBramSegmentsOn;

    logic [1:0] lateMarBits;

    logic [3:0] globalMemoryWriteByteEnableConcatenated;

    logic [10:0] resetHeaderBramCounter;

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
            globalMemFinishedActionReg <= globalMemFinishedAction; 
            if(resetHeaderBramCounter != 11'h7FF) begin
                resetHeaderBramCounter <= resetHeaderBramCounter + 1;
            end

            case(state)
                Idle: state <= (|writingMemoryDataGlobal) ? adjacentCheckWrite : ((|readingMemoryDataGlobal) ? adjacentCheckRead : Idle);

                //which state to go into
                adjacentCheckRead: state <= (&adjacencyChecker) ? ((mar[1:0] == 2'b00) ? adjacentReadRegularLoadMasters : adjacentReadOffAxisFirstLoadMasters) : nonAdjacentReadLoadMasters;
                adjacentCheckWrite: state <= (&adjacencyChecker) ? ((mar[1:0] == 2'b00) ? adjacentWriteRegularLoadMasters : adjacentWriteOffAxisFirstLoadMasters) : nonAdjacentWriteLoadMasters;

                //reading off axis data. The first non-aligned data read.
                adjacentReadOffAxisFirstLoadMasters: state <= adjacentReadOffAxisFirstSearchHeader1;
                adjacentReadOffAxisFirstSearchHeader1: state <= adjacentReadOffAxisFirstCheckHit; // changing
                adjacentReadOffAxisFirstSearchHeader2: state <= adjacentReadOffAxisFirstCheckHit;
                adjacentReadOffAxisFirstCheckHit: state <= (cacheHitBit) ? adjacentReadOffAxisFirstCacheHitDistributeData : adjacentReadOffAxisFirstCacheMissGlobalRead1;
                adjacentReadOffAxisFirstCacheHitDistributeData: state <= adjacentReadRegularLoadMasters;
                adjacentReadOffAxisFirstCacheMissGlobalRead1: state <= adjacentReadOffAxisFirstCacheMissGlobalRead2;
                adjacentReadOffAxisFirstCacheMissGlobalRead2: state <= (globalMemFinishedActionReg) ? adjacentReadOffAxisFirstCacheMissDistributeData : adjacentReadOffAxisFirstCacheMissGlobalRead2;
                adjacentReadOffAxisFirstCacheMissDistributeData: state <= adjacentReadRegularLoadMasters;

                //Occurs 8 times. The last time it occurs, I need to have special care for reading off axis data.
                adjacentReadRegularLoadMasters: state <= adjacentReadRegularSearchHeader1;
                adjacentReadRegularSearchHeader1: state <= adjacentReadRegularCheckHit; //changing
                adjacentReadRegularSearchHeader2: state <= adjacentReadRegularCheckHit;
                adjacentReadRegularCheckHit: state <= (cacheHitBit) ? adjacentReadRegularCacheHitDistributeData : adjacentReadRegularCacheMissGlobalRead1;
                adjacentReadRegularCacheHitDistributeData: state <= (adjacentCounter==3'b101) ? Idle : adjacentReadRegularLoadMasters;
                adjacentReadRegularCacheMissGlobalRead1: state <= adjacentReadRegularCacheMissGlobalRead2;
                adjacentReadRegularCacheMissGlobalRead2: state <= (globalMemFinishedActionReg) ? adjacentReadRegularCacheMissDistributeData : adjacentReadRegularCacheMissGlobalRead2;
                adjacentReadRegularCacheMissDistributeData: state <= (adjacentCounter==3'b101) ? Idle : adjacentReadRegularLoadMasters;

                //Non adjacent reads. Loops 32 times.
                nonAdjacentReadLoadMasters: state <= nonAdjacentReadSearchHeader1;
                nonAdjacentReadSearchHeader1: state <= nonAdjacentReadCheckHit; //changing
                nonAdjacentReadSearchHeader2: state <= nonAdjacentReadCheckHit;
                nonAdjacentReadCheckHit: state <= (cacheHitBit) ? nonAdjacentReadCacheHitDistributeData : nonAdjacentReadCacheMissGlobalRead1;
                nonAdjacentReadCacheHitDistributeData: state <= ((nonAdjacentCounter == 5'b10111) || ~(|readingMemoryDataGlobal)) ? Idle : nonAdjacentReadLoadMasters;
                nonAdjacentReadCacheMissGlobalRead1: state <= nonAdjacentReadCacheMissGlobalRead2;
                nonAdjacentReadCacheMissGlobalRead2: state <= (globalMemFinishedActionReg) ? nonAdjacentReadCacheMissDistributeData : nonAdjacentReadCacheMissGlobalRead2;
                nonAdjacentReadCacheMissDistributeData: state <= ((nonAdjacentCounter == 5'b10111 )|| ~(|readingMemoryDataGlobal)) ? Idle : nonAdjacentReadLoadMasters;

                //Adjacent, off axis writes
                adjacentWriteOffAxisFirstLoadMasters: state <= adjacentWriteOffAxisFirstSearchHeader;
                adjacentWriteOffAxisFirstSearchHeader: state <= adjacentWriteOffAxisFirstCheckHit; //changing
                adjacentWriteOffAxisFirstCheckHit: state <= (cacheHitBit) ? adjacentWriteOffAxisFirstPartialWrite : adjacentWriteOffAxisFirstOnlyGlobal;
                adjacentWriteOffAxisFirstPartialWrite: state <= adjacentWriteOffAxisFirstGlobalWait;
                adjacentWriteOffAxisFirstOnlyGlobal: state <= adjacentWriteOffAxisFirstGlobalWait;
                adjacentWriteOffAxisFirstGlobalWait: state <= (globalMemFinishedActionReg) ? adjacentWriteOffAxisMiddleLoadMasters : adjacentWriteOffAxisFirstGlobalWait;
                
                
                //regular writes. This will occur 8 times.
                adjacentWriteRegularLoadMasters: state <= adjacentWriteRegularSearchHeader;
                adjacentWriteRegularSearchHeader: state <= adjacentWriteRegularCheckHit;
                adjacentWriteRegularCheckHit: state <= (cacheHitBit) ? adjacentWriteRegularWriteBoth : adjacentWriteRegularWriteOnlyGlobal;
                adjacentWriteRegularWriteBoth: state <= adjacentWriteRegularGlobalWait;
                adjacentWriteRegularWriteOnlyGlobal: state <= adjacentWriteRegularGlobalWait;
                adjacentWriteRegularGlobalWait: state <= (globalMemFinishedActionReg) ? ((adjacentCounter==3'b101) ? Idle : adjacentWriteRegularLoadMasters) : adjacentWriteRegularGlobalWait;

                //middle of off axis writes. This will occur seven times.
                adjacentWriteOffAxisMiddleLoadMasters: state <= adjacentWriteOffAxisMiddleSearchHeader;
                adjacentWriteOffAxisMiddleSearchHeader: state <= adjacentWriteOffAxisMiddleCheckHit;
                adjacentWriteOffAxisMiddleCheckHit: state <= (cacheHitBit) ? adjacentWriteOffAxisMiddleWriteBoth : adjacentWriteOffAxisMiddleWriteOnlyGlobal;
                adjacentWriteOffAxisMiddleWriteBoth: state <= adjacentWriteOffAxisMiddleGlobalWait;
                adjacentWriteOffAxisMiddleWriteOnlyGlobal: state <= adjacentWriteOffAxisMiddleGlobalWait;//I changed below number from 100 to 101
                adjacentWriteOffAxisMiddleGlobalWait: state <= (globalMemFinishedActionReg) ? ((adjacentOffAxisWriteCounter == 3'b100) ? adjacentWriteOffAxisLastLoadMasters : adjacentWriteOffAxisMiddleLoadMasters) : adjacentWriteOffAxisMiddleGlobalWait;

                //adjcent, off axis write. Just writes the last segment of data.
                adjacentWriteOffAxisLastLoadMasters: state <= adjacentWriteOffAxisLastSearchHeader;
                adjacentWriteOffAxisLastSearchHeader: state <= adjacentWriteOffAxisLastCheckHit; //changing
                adjacentWriteOffAxisLastCheckHit: state <=  (cacheHitBit) ? adjacentWriteOffAxisLastPartialWrite : adjacentWriteOffAxisLastOnlyGlobal;
                adjacentWriteOffAxisLastPartialWrite: state <= adjacentWriteOffAxisLastGlobalWait;
                adjacentWriteOffAxisLastOnlyGlobal: state <= adjacentWriteOffAxisLastGlobalWait;
                adjacentWriteOffAxisLastGlobalWait: state <= (globalMemFinishedActionReg) ? Idle : adjacentWriteOffAxisLastGlobalWait;

                //loops 32 times. Writes all core data streams.
                nonAdjacentWriteLoadMasters: state <= nonAdjacentWriteSearchHeader1;
                nonAdjacentWriteSearchHeader1: state <= nonAdjacentWriteCheckHit; //changing
                nonAdjacentWriteCheckHit: state <= (cacheHitBit) ? nonAdjacentWritePartialWrite : nonAdjacentWriteGlobal1;
                nonAdjacentWritePartialWrite: state <= nonAdjacentWriteGlobal2;
                nonAdjacentWriteGlobal1: state <= nonAdjacentWriteGlobal2;
                nonAdjacentWriteGlobal2: state <= (globalMemFinishedActionReg) ? (((nonAdjacentCounter == 5'b10111)  | ~(|writingMemoryDataGlobal)) ? Idle : nonAdjacentWriteLoadMasters) : nonAdjacentWriteGlobal2;
            endcase
            if(state == Idle) begin
                nonAdjacentCounter <= 0;
                adjacentCounter <= 0;
                adjacentOffAxisWriteCounter <= 0;
            end
            else begin
            
            
            
            
            
                if(state == adjacentReadRegularCacheHitDistributeData || state == adjacentReadRegularCacheMissDistributeData || ((state == adjacentWriteRegularGlobalWait) && (globalMemFinishedActionReg))) begin
                    adjacentCounter <= adjacentCounterPlusOne;
                end
                if((state == nonAdjacentWriteGlobal2 && globalMemFinishedActionReg)|| 
                state == nonAdjacentReadCacheHitDistributeData || state == nonAdjacentReadCacheMissDistributeData) begin
                    nonAdjacentCounter <= nonAdjacentCounterPlusOne;
                end
                if(state == adjacentWriteOffAxisMiddleGlobalWait && globalMemFinishedActionReg) begin
                    adjacentOffAxisWriteCounter <= adjacentOffAxisWriteCounterPlusOne;
                end
            end



            if(state == adjacentReadOffAxisFirstLoadMasters) begin 
                masterMar <= mar[31:0];
            end
            else if (state == adjacentReadRegularLoadMasters) begin
                masterMar <= mar[ { adjacentCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0], 5'b00000} +: 32];
            end
            else if (state == nonAdjacentReadLoadMasters) begin
                masterMar <= mar[{nonAdjacentCounter[4:0], 5'b00000} +:32];
            end
            else if (state == adjacentWriteOffAxisFirstLoadMasters) begin
                masterMar <= mar[31:0];
            end
            else if (state == adjacentWriteRegularLoadMasters) begin
                masterMar <= mar[{ adjacentCounter[2:0], 2'b00, 5'b00000} +: 32];
            end
            else if (state == adjacentWriteOffAxisMiddleLoadMasters) begin
                masterMar <= mar[{ adjacentOffAxisWriteCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0], 5'b00000} +: 32]; //I need to be careful with these two different counters...  
            end
            else if (state == adjacentWriteOffAxisLastLoadMasters) begin
                masterMar <= mar[{3'b101, lateMarBits[1] ^ lateMarBits[0], lateMarBits[0], 5'b00000} +: 32];
            end
            else if (state == nonAdjacentWriteLoadMasters) begin
                masterMar <= mar[{nonAdjacentCounter[4:0], 5'b00000} +:32];
            end


            if (state == adjacentWriteOffAxisFirstLoadMasters) begin
                case(mar[1:0])
                    2'b01: masterDataIn[127:32] <= writeData[95:0];
                    2'b10: masterDataIn[127:64] <= writeData[63:0];
                    2'b11: masterDataIn[127:96] <= writeData[31:0];
                endcase
            end
            else if (state == adjacentWriteRegularLoadMasters) begin
                masterDataIn <= writeData[{adjacentCounter[2:0], 2'b00, 5'b00000} +: 128];
            end
            else if (state == adjacentWriteOffAxisMiddleLoadMasters) begin
                masterDataIn <= writeData[{adjacentOffAxisWriteCounter[2:0], lateMarBits[1]^lateMarBits[0], lateMarBits[0], 5'b00000} +: 128];
            end
            else if (state == adjacentWriteOffAxisLastLoadMasters) begin
                case(mar[1:0])
                    2'b01: masterDataIn[31:0] <= writeData[767:736];
                    2'b10: masterDataIn[63:0] <= writeData[767:704];
                    2'b11: masterDataIn[95:0] <= writeData[767:672];
                endcase
            end
            else if (state == nonAdjacentWriteLoadMasters) begin
                masterDataIn <= nonAdjacentMasterDataIn;
            end

            if(loadGlobalMemReadRegister) begin
                globalMemReadRegister <= globalMemRead;
            end

            if(state == Idle) begin
                lateMarBits <= mar[1:0];
            end

            if (state == adjacentWriteRegularWriteOnlyGlobal || state == adjacentWriteRegularWriteBoth) begin
                globalMemoryWriteByteEnableConcatenated <= writingMemoryDataGlobal[{adjacentCounter[2:0], 2'b00} +: 4];
            end
            else if (state == adjacentWriteOffAxisMiddleWriteOnlyGlobal || state == adjacentWriteOffAxisMiddleWriteBoth) begin
                globalMemoryWriteByteEnableConcatenated <= writingMemoryDataGlobal[{adjacentOffAxisWriteCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4];
            end
                                
                   
            else if (state == adjacentWriteOffAxisLastPartialWrite || state == adjacentWriteOffAxisLastOnlyGlobal) begin
                case(lateMarBits)
                    2'b01: globalMemoryWriteByteEnableConcatenated <= {3'b000, writingMemoryDataGlobal[23]};
                    2'b10: globalMemoryWriteByteEnableConcatenated <= {2'b00, writingMemoryDataGlobal[23:22]};
                    2'b11: globalMemoryWriteByteEnableConcatenated <= {1'b0, writingMemoryDataGlobal[23:21]};
                endcase
            end
            
            else if (state == adjacentWriteOffAxisFirstPartialWrite || state == adjacentWriteOffAxisFirstOnlyGlobal) begin
                case(lateMarBits)
                    2'b01: globalMemoryWriteByteEnableConcatenated <= {writingMemoryDataGlobal[2:0], 1'b0};
                    2'b10: globalMemoryWriteByteEnableConcatenated <= {writingMemoryDataGlobal[1:0], 2'b00};
                    2'b11: globalMemoryWriteByteEnableConcatenated <= {writingMemoryDataGlobal[0], 3'b000};
                endcase
            end
            
            
            else if (state == nonAdjacentWriteGlobal1 || state == nonAdjacentWritePartialWrite) begin
                globalMemoryWriteByteEnableConcatenated <= 0;
                globalMemoryWriteByteEnableConcatenated[masterMar[1:0]] <= writingMemoryDataGlobal[nonAdjacentCounter];
            end


        end
    end

    always_comb begin
        adjacentCounterPlusOne = adjacentCounter + 1;
        nonAdjacentCounterPlusOne = nonAdjacentCounter + 1;
        adjacentOffAxisWriteCounterPlusOne = adjacentOffAxisWriteCounter + 1;
        nonAdjacentMasterDataIn = 128'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
        case(mar[{nonAdjacentCounter[4:0], 5'b00000}+: 2]) //maybe I should add in another state to reduce the number of LUTs. ( up to 3 states for this branch, so still not a lot.)
            2'b00: nonAdjacentMasterDataIn[31:0] = writeData[{nonAdjacentCounter[4:0], 5'b00000} +: 32];
            2'b01: nonAdjacentMasterDataIn[63:32] = writeData[{nonAdjacentCounter[4:0], 5'b00000} +: 32];
            2'b10: nonAdjacentMasterDataIn[95:64] = writeData[{nonAdjacentCounter[4:0], 5'b00000} +: 32];
            2'b11: nonAdjacentMasterDataIn[127:96] = writeData[{nonAdjacentCounter[4:0], 5'b00000} +: 32];
        endcase



        headerBramEnable = 0;
        if (state inside {
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
            adjacentReadOffAxisFirstSearchHeader1,
            adjacentWriteRegularSearchHeader,
            adjacentReadRegularSearchHeader1,
            nonAdjacentReadSearchHeader1,
            adjacentWriteOffAxisFirstSearchHeader,
            adjacentWriteOffAxisLastSearchHeader,
            adjacentWriteOffAxisMiddleSearchHeader,
            nonAdjacentWriteSearchHeader1: headerBramWriteEnable = 0;
    
            // States where headerBramWriteEnable = 1
            adjacentReadOffAxisFirstCacheMissDistributeData,
            adjacentReadRegularCacheMissDistributeData,
            adjacentWriteOffAxisFirstPartialWrite,
            adjacentWriteRegularWriteBoth,
            adjacentWriteOffAxisMiddleWriteBoth,
            adjacentWriteOffAxisLastPartialWrite,
            nonAdjacentWritePartialWrite: headerBramWriteEnable = 1;
    
            // Default case (optional)
            default: headerBramWriteEnable = 0;
        endcase
        
        end


        dataBramEnable = 0;
        if (state inside {
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
            adjacentReadOffAxisFirstSearchHeader1,
            adjacentReadRegularSearchHeader1,
            nonAdjacentReadSearchHeader1: dataBramWriteEnable = 0;

            // States where headerBramWriteEnable = 1
            adjacentReadOffAxisFirstCacheMissDistributeData,
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
            adjacentReadOffAxisFirstCacheMissGlobalRead1,
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
            globalEnable = writingMemoryDataGlobal[nonAdjacentCounter];
        end
        else begin
            globalEnable = 0;
        end
        

        case (state)
        // States where headerBramWriteEnable = 0
            adjacentReadOffAxisFirstCacheMissGlobalRead1,
            adjacentReadRegularCacheMissGlobalRead1,
            nonAdjacentReadCacheMissGlobalRead1: globalWriteEnable = 0;

            // States where headerBramWriteEnable = 1
            adjacentWriteOffAxisFirstPartialWrite,
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

        unique case(state)
            adjacentReadOffAxisFirstCacheMissDistributeData,
            adjacentReadRegularCacheMissDistributeData,
            nonAdjacentReadCacheMissDistributeData: loadDataBramFromGlobal = 1;

            adjacentWriteOffAxisFirstPartialWrite,
            adjacentWriteRegularWriteBoth,
            adjacentWriteOffAxisMiddleWriteBoth,
            adjacentWriteOffAxisMiddleWriteOnlyGlobal,
            adjacentWriteRegularWriteOnlyGlobal,
            adjacentWriteOffAxisLastPartialWrite,
            nonAdjacentWritePartialWrite: loadDataBramFromGlobal = 0;

            default: loadDataBramFromGlobal = 1'bx;
        endcase


        case(state)
            adjacentReadOffAxisFirstCacheMissGlobalRead2,
            adjacentReadRegularCacheMissGlobalRead2,
            nonAdjacentReadCacheMissGlobalRead2: loadGlobalMemReadRegister = 1;
            default: loadGlobalMemReadRegister = 0;
        endcase

        dataBramIn = (loadDataBramFromGlobal) ? globalMemReadRegister : masterDataIn;

        globalMemAddr = {masterMar[24:2], 3'b0}; //Bits [3:1] should always be 0. If they aren't I fucked up (unless there is a non-consecutive write, in which case it is expected)
        
        globalMemDataWrite = masterDataIn;
        
        bramHeaderDataIn = (resetHeaderBramCounter != 11'h7FF) ? 16'hFFFF : {4'b0000, masterMar[24:13]}; //Twelve bits in the data
        
        bramHeaderAddress = (resetHeaderBramCounter != 11'h7FF) ? resetHeaderBramCounter : masterMar[12:2]; //Eleven bits in the address. I have enough room I think if I wanted to to double this.
        
        cacheHitBit = bramHeaderDataOut[11:0] == masterMar[24:13];


        if(state == adjacentReadOffAxisFirstCacheMissDistributeData || state == adjacentReadOffAxisFirstSearchHeader1) begin
//            case(lateMarBits)
//                2'b01: dataBramSegmentsOn = {readingMemoryDataGlobal[2:0], 1'b0};
//                2'b10: dataBramSegmentsOn = {readingMemoryDataGlobal[1:0], 2'b00};
//                2'b11: dataBramSegmentsOn = {readingMemoryDataGlobal[0], 3'b000};
//            endcase
            dataBramSegmentsOn = 4'b1111;
        end
        else if (state == adjacentReadRegularCacheMissDistributeData || state == adjacentReadRegularSearchHeader1) begin
//            if(adjacentCounter!=3'b111) begin
//                dataBramSegmentsOn = readingMemoryDataGlobal[{adjacentCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4];
//            end
//            else begin
//                case(lateMarBits)
//                    2'b01: dataBramSegmentsOn = {3'b000, readingMemoryDataGlobal[31]};
//                    2'b10: dataBramSegmentsOn = {2'b00, readingMemoryDataGlobal[31:30]};
//                    2'b11: dataBramSegmentsOn = {1'b0, readingMemoryDataGlobal[31:29]};
//                endcase
//            end
              dataBramSegmentsOn = 4'b1111;
        end
        else if (state == nonAdjacentReadCacheMissDistributeData) begin
            dataBramSegmentsOn = 0;
            dataBramSegmentsOn[masterMar[1:0]] = readingMemoryDataGlobal[nonAdjacentCounter];
        end
        else if (state == adjacentWriteOffAxisFirstPartialWrite) begin
            case(lateMarBits)
                2'b01: dataBramSegmentsOn = {writingMemoryDataGlobal[2:0], 1'b0};
                2'b10: dataBramSegmentsOn = {writingMemoryDataGlobal[1:0], 2'b00};
                2'b11: dataBramSegmentsOn = {writingMemoryDataGlobal[0], 3'b000};
                default: dataBramSegmentsOn = 4'h0;
            endcase
        end
        

        
        else if (state == adjacentWriteRegularWriteBoth) begin
            dataBramSegmentsOn = writingMemoryDataGlobal[{adjacentCounter[2:0], 2'b00} +: 4];
        end
        else if (state == adjacentWriteOffAxisMiddleWriteBoth) begin
            dataBramSegmentsOn = writingMemoryDataGlobal[{adjacentOffAxisWriteCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4];
        end
               
        else if (state == adjacentWriteOffAxisLastPartialWrite) begin 
            case(lateMarBits)
                2'b01: dataBramSegmentsOn = {3'b000, writingMemoryDataGlobal[23]};
                2'b10: dataBramSegmentsOn = {2'b00, writingMemoryDataGlobal[23:22]};
                2'b11: dataBramSegmentsOn = {1'b0, writingMemoryDataGlobal[23:21]};
            endcase
        end
        else if (state == nonAdjacentWritePartialWrite) begin
            dataBramSegmentsOn = 0;
            dataBramSegmentsOn[masterMar[1:0]] = writingMemoryDataGlobal[nonAdjacentCounter];
        end
        else begin
            dataBramSegmentsOn = 4'b0000;
        end



        globalMemoryWriteByteEnable[1:0] = {2{globalMemoryWriteByteEnableConcatenated[0]}};
        globalMemoryWriteByteEnable[3:2] = {2{globalMemoryWriteByteEnableConcatenated[1]}};
        globalMemoryWriteByteEnable[5:4] = {2{globalMemoryWriteByteEnableConcatenated[2]}};
        globalMemoryWriteByteEnable[7:6] = {2{globalMemoryWriteByteEnableConcatenated[3]}};


        dataBramIndividualEnable = {4{dataBramEnable}} & dataBramSegmentsOn;

        dataOut = 128'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
        if(state == adjacentReadOffAxisFirstCacheHitDistributeData) begin //I'm going to double wire all of these. This is wasteful, and if I'm out of space I should redo this.
            case(mar[1:0])                                                //Otherwise, just load the masterDataOut and distribute it there.
                2'b01: dataOut[95:0] = dataBramOut[127:32];
                2'b10: dataOut[63:0] = dataBramOut[127:64];
                2'b11: dataOut[31:0] = dataBramOut[127:96];
            endcase
        end
        else if (state == adjacentReadRegularCacheHitDistributeData) begin
            dataOut[{adjacentCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0], 5'b00000} +: 128] = dataBramOut;
        end
        else if (state == nonAdjacentReadCacheHitDistributeData) begin
            dataOut[{nonAdjacentCounter[4:0], 5'b00000} +: 32] = dataBramOut[{masterMar[1:0], 5'b00000} +: 32];
        end 
        else if (state == adjacentReadOffAxisFirstCacheMissDistributeData) begin
            case(mar[1:0])                                                
                2'b01: dataOut[95:0] = globalMemReadRegister[127:32];
                2'b10: dataOut[63:0] = globalMemReadRegister[127:64];
                2'b11: dataOut[31:0] = globalMemReadRegister[127:96];
            endcase
        end
        else if (state == adjacentReadRegularCacheMissDistributeData) begin
            dataOut[{adjacentCounter[2:0], lateMarBits[1] ^ lateMarBits[0], lateMarBits[0], 5'b00000} +: 128] = globalMemReadRegister;
        end
        else if (state == nonAdjacentReadCacheMissDistributeData) begin
            dataOut[{nonAdjacentCounter[4:0], 5'b00000} +: 32] = globalMemReadRegister[{masterMar[1:0], 5'b00000} +: 32];
        end



        finishedWritingMemoryDataGlobal = 0;
        if(state == adjacentWriteOffAxisFirstGlobalWait && globalMemFinishedActionReg) begin
            case(lateMarBits)
                2'b01: finishedWritingMemoryDataGlobal[2:0] = 3'b111;
                2'b10: finishedWritingMemoryDataGlobal[2:0] = 3'b011;
                2'b11: finishedWritingMemoryDataGlobal[2:0] = 3'b001;
            endcase        
        end
                
        else if (state == adjacentWriteRegularGlobalWait && globalMemFinishedActionReg) begin
            finishedWritingMemoryDataGlobal[{adjacentCounter, 2'b00} +: 4] = 4'b1111;
        end
        else if (state == adjacentWriteOffAxisMiddleGlobalWait && globalMemFinishedActionReg) begin
            finishedWritingMemoryDataGlobal[{adjacentOffAxisWriteCounter, lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4] = 4'b1111;
        end
                      
        else if (state == adjacentWriteOffAxisLastGlobalWait && globalMemFinishedActionReg) begin
            case(lateMarBits)
                2'b01: finishedWritingMemoryDataGlobal[23:21] = 3'b100;
                2'b10: finishedWritingMemoryDataGlobal[23:21] = 3'b110;
                2'b11: finishedWritingMemoryDataGlobal[23:21] = 3'b111;
            endcase       
        end
             
        
        
//        else if (state == nonAdjacentWriteCheckHit) begin
//            finishedWritingMemoryDataGlobal[nonAdjacentCounter] = ~cacheHitBit;
//        end
        else if (state == nonAdjacentWriteGlobal2 && globalMemFinishedActionReg) begin
            finishedWritingMemoryDataGlobal[nonAdjacentCounter] = 1'b1;
//              finishedWritingMemoryDataGlobal[nonAdjacentCounter] = 1'b1;
        end

        finishedReadingMemoryDataGlobal = 0;
        if(state == adjacentReadOffAxisFirstCacheHitDistributeData) begin
            case(lateMarBits)
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
        else if (state == adjacentReadRegularCacheHitDistributeData) begin
            finishedReadingMemoryDataGlobal[{adjacentCounter, lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4] = 4'b1111;
        end
        else if (state == adjacentReadRegularCacheMissDistributeData) begin
            finishedReadingMemoryDataGlobal[{adjacentCounter, lateMarBits[1] ^ lateMarBits[0], lateMarBits[0]} +: 4] = 4'b1111;    
        end
        else if (state == nonAdjacentReadCacheHitDistributeData || state == nonAdjacentReadCacheMissDistributeData) begin
            finishedReadingMemoryDataGlobal[nonAdjacentCounter] = 1'b1;
        end

    end
    int adjacencyInt;
    always_comb begin
        for(adjacencyInt = 0; adjacencyInt < 31; adjacencyInt += 1) begin
            adjacencyChecker[adjacencyInt] = ~(readingMemoryDataGlobal[adjacencyInt + 1] | writingMemoryDataGlobal[adjacencyInt + 1]) | 
            ((mar[(adjacencyInt + 1) * 32 +: 32] - mar[(adjacencyInt) * 32 +: 32]) == 32'h0001);
        end
    
    end    
    
    
    genvar dataBram; // Generate loop variable
    generate
        for(dataBram = 0; dataBram < 4; dataBram+=1) begin //This is going to need to be 4 BRAMs because I can't make a 128 bit wide BRAM
            blk_mem_gen_2 u_blk_mem_gen_2 (
                .clka  (clk),      
                .ena   (dataBramIndividualEnable[dataBram]),       
                .wea   (dataBramWriteEnable),        
                .addra (masterMar[12:2]),    
                .dina  (dataBramIn[dataBram * 32 +: 32]),    
                .douta (dataBramOut[dataBram * 32 +: 32])
            );
        end
    endgenerate
    blk_mem_gen_3 u_blk_mem_gen_3 (
        .clka  (clk),      
        .ena   ( (headerBramEnable | (resetHeaderBramCounter != 11'h7FF)) ),       
        .wea   ( (headerBramWriteEnable | (resetHeaderBramCounter != 11'h7FF)) ),        
        .addra (bramHeaderAddress),    
        .dina  (bramHeaderDataIn),    
        .douta (bramHeaderDataOut)
    );
endmodule
