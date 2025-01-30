module gpuLinker(
    input logic clk,
    input logic reset,
    input logic [31:0] instruction,
    input logic executeInstruction,
    output logic coresReady,
    
    input logic globalMemFinishedAction,
    output logic [25:0] globalMemAddr,
    output logic [127:0] globalMemDataWrite,
    output logic [7:0] writeBytes,
    input logic [127:0] globalMemReadData,
    output logic globalEnable,
    output logic globalWriteEnable
);

    // Internal signals for memory operation status
    logic writingShared, readingShared;

    // Signals to handle memory data and control for GPU cores
    logic [31:0] finishedReadMemoryDataGlobal, finishedWriteMemoryDataShared, 
                 finishedWriteMemoryDataGlobal, readyForNextInstruction, writingMemoryDataShared, 
                 writingMemoryDataGlobal, readingMemoryDataShared, readingMemoryDataGlobal, finishedReadMemoryDataShared;

    logic [1023:0] MdrInGlobal, MarOut, MdrOut, MdrInMultiplexed, dataReadShared; 

    // Generate block for instantiating multiple GPU cores
    genvar core;
    generate
        for(core = 0; core < 24; core+=1) begin : gpu_core_instances
            gpuCore coreInst(
                .instruction(instruction),
                .executeInstruction(executeInstruction),
                .clk(clk),
                .reset(reset),
                .threadId(core), //individual core IDs in register 7
                .MDRIn(MdrInMultiplexed[core*32 +: 32]),
                .marOut(MarOut[core*32 +: 32]),
                .mdrOut(MdrOut[core*32 +:32]),
                .readyForNextInstruction(readyForNextInstruction[core]),
                .writingMemoryDataShared(writingMemoryDataShared[core]),
                .writingMemoryDataGlobal(writingMemoryDataGlobal[core]),
                .readingMemoryDataShared(readingMemoryDataShared[core]),
                .readingMemoryDataGlobal(readingMemoryDataGlobal[core]),
                .finishedReadMemoryDataShared(finishedReadMemoryDataShared[core]),
                .finishedReadMemoryDataGlobal(finishedReadMemoryDataGlobal[core]),
                .finishedWriteMemoryDataShared(finishedWriteMemoryDataShared[core]),
                .finishedWriteMemoryDataGlobal(finishedWriteMemoryDataGlobal[core])
            );
        end
    endgenerate

    // Signals for shared memory operations
    logic isWritingShared, isReadingShared;
    logic [31:0] addressesForPortARead [2:0], addressesForPortBRead [2:0];
    logic [3:0] writeCounter;
    logic [1:0] readCounter, readCounterDelayed;

    // Memory addresses and data handling signals
    logic [7:0] addressForPortAWrite, addressForPortBWrite, addressForPortARead [2:0], addressForPortBRead [2:0], portAAddress [2:0], portBAddress [2:0];
    int choosePortInt, dataOutInt;
    logic [191:0] readOutBram;

    logic [31:0] portADataIn, portBDataIn;

    logic [31:0] isCoreActive;

    // Combinational logic for shared memory and core control
    always_comb begin
        portADataIn = MdrOut[ {writeCounter, 1'b0, 5'b00000} +: 32];
        portBDataIn = MdrOut[ {writeCounter, 1'b1, 5'b00000} +: 32];

        if (isWritingShared) begin
            isCoreActive = writingMemoryDataShared;
        end else if (isReadingShared) begin
            isCoreActive = 32'hFFFFFFFF; //because reading is non-destructive, I can turn on all of the core signals
        end else begin
            isCoreActive = 32'h00000000;
        end

        isWritingShared = |writingMemoryDataShared;
        isReadingShared = |readingMemoryDataShared;

        // Assign addresses for ports based on read/write operations
        for(choosePortInt = 0; choosePortInt < 3; choosePortInt += 1) begin //addressesForPortRead are chosen between 4 addresses per port
            addressesForPortARead[choosePortInt][readCounter * 8 +: 8] = MarOut[ readCounter * 192 + 64 * choosePortInt +: 8];
            addressesForPortBRead[choosePortInt][readCounter * 8 +: 8] = MarOut[ readCounter * 192 + 64 * choosePortInt + 32 +: 8];
            addressForPortAWrite = MarOut[ writeCounter * 64 +: 8]; //All writes must be synchronized, so each is chosen between 12 addresses
            addressForPortBWrite = MarOut[ writeCounter * 64 + 32 +: 8];
            addressForPortARead[choosePortInt] = addressesForPortARead[choosePortInt][readCounter * 8 +: 8]; //select between each address to read from
            addressForPortBRead[choosePortInt] = addressesForPortBRead[choosePortInt][readCounter * 8 +: 8];
            portAAddress[choosePortInt] = (writingShared) ? addressForPortAWrite: addressForPortARead[choosePortInt]; //multiplex between write and read addresses
            portBAddress[choosePortInt] = (writingShared) ? addressForPortBWrite: addressForPortBRead[choosePortInt];
        end

        for(dataOutInt = 0; dataOutInt < 4; dataOutInt += 1) begin //share the readOutBram data between each set of 6 cores
            dataReadShared[dataOutInt * 192 +: 192] = readOutBram;
        end
    end

    // Instantiate shared memory blocks
    genvar sharedMemInt;
    generate //Uses true dual-port memory for maximum writing speeds
        for(sharedMemInt = 0; sharedMemInt < 3; sharedMemInt += 1) begin
            blk_mem_gen_4 u_blk_mem_gen_4 (
                .clka  (clk),      
                .ena   (isCoreActive[{writeCounter, 1'b0}]),   //for writes, if a core is off, then you don't want to write that one.    
                .wea   (writingShared),        
                .addra (portAAddress[sharedMemInt]),    
                .dina  (portADataIn),    
                .douta (readOutBram[sharedMemInt * 64 +: 32]),   
                
                .clkb  (clk), 
                .enb   (isCoreActive[{writeCounter, 1'b1}]),        
                .web   (writingShared),    
                .addrb (portBAddress[sharedMemInt]),
                .dinb  (portBDataIn),
                .doutb (readOutBram[sharedMemInt * 64 + 32 +: 32])
            );
        end
    endgenerate

    // Initial values for ready flags and shared memory signals
    always_comb begin
        readyForNextInstruction[31:24] = 8'hFF; //turn off cores 31-24 because there are only 24 total cores (deprecated from 32)
        writingMemoryDataShared[31:24] = 8'h00;
        writingMemoryDataGlobal[31:24] = 8'h00;
        readingMemoryDataShared[31:24] = 8'h00;
        readingMemoryDataGlobal[31:24] = 8'h00;
    end

    // Signals for shared memory state and address handling
    logic [3:0] sharedMemState;
    logic [31:0] writeDataA, writeDataB;
    logic [9:0] marWriteAddressA, marWriteAddressB;
    logic [1023:0] globalCacheDataOut;
    logic currentlyWritingShared, currentlyReadingShared;

    // Combinational logic for MdrIn and instruction handling
    always_comb begin
        coresReady = &readyForNextInstruction; //make sure all cores are in Decode state
        MdrInGlobal = globalCacheDataOut;
        MdrInMultiplexed = (isReadingShared) ? dataReadShared : MdrInGlobal;

        // Handle shared memory write completion flags
        if(writingShared) begin //only finished when currently writing shared memory
            case (writeCounter) //tell two cores at a time that they are finished - one for each port in true dual port memory
                4'b0000: finishedWriteMemoryDataShared = 32'h00000003;
                4'b0001: finishedWriteMemoryDataShared = 32'h0000000C;
                4'b0010: finishedWriteMemoryDataShared = 32'h00000030;
                4'b0011: finishedWriteMemoryDataShared = 32'h000000C0;
                4'b0100: finishedWriteMemoryDataShared = 32'h00000300;
                4'b0101: finishedWriteMemoryDataShared = 32'h00000C00;
                4'b0110: finishedWriteMemoryDataShared = 32'h00003000;
                4'b0111: finishedWriteMemoryDataShared = 32'h0000C000;
                4'b1000: finishedWriteMemoryDataShared = 32'h00030000;
                4'b1001: finishedWriteMemoryDataShared = 32'h000C0000;
                4'b1010: finishedWriteMemoryDataShared = 32'h00300000;
                4'b1011: finishedWriteMemoryDataShared = 32'h00C00000;
                4'b1100: finishedWriteMemoryDataShared = 32'h03000000;
                4'b1101: finishedWriteMemoryDataShared = 32'h0C000000;
                4'b1110: finishedWriteMemoryDataShared = 32'h30000000;
                4'b1111: finishedWriteMemoryDataShared = 32'hC0000000;
            endcase
        end else begin
            finishedWriteMemoryDataShared = 32'h00000000;
        end

        // Handle read completion flags based on read counter
        if(readCounter != readCounterDelayed) begin
            case (readCounterDelayed) //if reading, 3 brams times dual ports mean 6 total read ports. 24/6 = 4 cycles. Turn off 6 cores per cycle
                2'b00: finishedReadMemoryDataShared = 32'h0000003F;
                2'b01: finishedReadMemoryDataShared = 32'h00000FC0;
                2'b10: finishedReadMemoryDataShared = 32'h0003F000;
                2'b11: finishedReadMemoryDataShared = 32'h00FC0000;
            endcase               
        end else begin
            finishedReadMemoryDataShared = 32'h00000000;
        end
    end

    // Sequential logic for updating counters and flags
    always_ff @(posedge clk) begin
        readCounterDelayed <= readCounter;
        if(reset) begin
            readCounter <= 0;
            writeCounter <= 0;
            writingShared <= 0;
            readingShared <= 0;
        end else begin
            writingShared <= (writeCounter == 4'b1011) ? 0 : isWritingShared;//if writeCounter maxes out, writingShared is turned off.
            readingShared <= isReadingShared; //readingShared delayes isReadingShared by a cycle
            if(writingShared) begin
                writeCounter <= (writeCounter == 4'b1011) ? 4'b0000 : writeCounter + 1; //increment writeCounter up to 12
                readCounter <= 0;
            end else if (isReadingShared) begin
                readCounter <= readCounter + 1;    //increment readCounter from 0 to 3 and back to 0
                writeCounter <= 0;
            end else begin
                readCounter <= 0;
                writeCounter <= 0;    
            end
        end
    end

    // Instantiation of global memory cache
    globalMemoryCache globalMemoryCacheInst(
        .writingMemoryDataGlobal(writingMemoryDataGlobal),
        .finishedWritingMemoryDataGlobal(finishedWriteMemoryDataGlobal),
        .readingMemoryDataGlobal(readingMemoryDataGlobal),
        .finishedReadingMemoryDataGlobal(finishedReadMemoryDataGlobal),
        .reset(reset),
        .clk(clk),
        .writeData(MdrOut),
        .mar(MarOut),
        .dataOut(globalCacheDataOut),
        .globalMemFinishedAction(globalMemFinishedAction),
        .globalMemAddr(globalMemAddr),
        .globalMemDataWrite(globalMemDataWrite),
        .globalMemRead(globalMemReadData),
        .globalMemoryWriteByteEnable(writeBytes),
        .globalEnable(globalEnable),
        .globalWriteEnable(globalWriteEnable)
    );
endmodule
