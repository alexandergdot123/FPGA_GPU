`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/03/2024 06:12:56 PM
// Design Name: 
// Module Name: gpuLinkerTestBench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module gpuLinkerTestBench(

    );
    // Testbench signals
    logic clk;
    logic reset;
    logic [31:0] instruction;
    logic executeInstruction;
    logic coresReady;
    
    logic globalMemFinishedAction;
    logic [25:0] globalMemAddr;
    logic [127:0] globalMemDataWrite;
    logic [7:0] writeBytes;
    logic [127:0] globalMemReadData;
    logic globalEnable;
    logic globalWriteEnable;

    // Clock generation
    always #5 clk = ~clk; // Generate a clock with 10ns period

    // Instantiate the gpuLinker
    gpuLinker uut (
        .clk(clk),
        .reset(reset),
        .instruction(instruction),
        .executeInstruction(executeInstruction),
        .coresReady(coresReady),
        .globalMemFinishedAction(globalMemFinishedAction),
        .globalMemAddr(globalMemAddr),
        .globalMemDataWrite(globalMemDataWrite),
        .writeBytes(writeBytes),
        .globalMemReadData(globalMemReadData),
        .globalEnable(globalEnable),
        .globalWriteEnable(globalWriteEnable)
    );

    // Input Ports
    logic [1:0] lateMarBits;
    assign lateMarBits = uut.globalMemoryCacheInst.lateMarBits;
//    logic globalMemFinishedActionReg;
//    assign globalMemFinishedActionReg = uut.globalMemoryCacheInst.globalMemFinishedActionReg;
    
    logic [10:0] resetCounter;
    assign resetCounter = uut.globalMemoryCacheInst.resetHeaderBramCounter;
    
    
    logic [31:0] writingMemoryDataGlobal;
    assign writingMemoryDataGlobal = uut.globalMemoryCacheInst.writingMemoryDataGlobal;
    
    logic [31:0] readingMemoryDataGlobal;
    assign readingMemoryDataGlobal = uut.globalMemoryCacheInst.readingMemoryDataGlobal;
    
    
    logic [1023:0] writeData;
    assign writeData = uut.globalMemoryCacheInst.writeData;
    
    logic [1023:0] mar;
    assign mar = uut.globalMemoryCacheInst.mar;
       
    // Output Ports
    logic [31:0] finishedWritingMemoryDataGlobal;
    assign finishedWritingMemoryDataGlobal = uut.globalMemoryCacheInst.finishedWritingMemoryDataGlobal;
    
    logic [31:0] finishedReadingMemoryDataGlobal;
    assign finishedReadingMemoryDataGlobal = uut.globalMemoryCacheInst.finishedReadingMemoryDataGlobal;
    
    logic [1023:0] dataOut;
    assign dataOut = uut.globalMemoryCacheInst.dataOut;
   
    
    logic [7:0] globalMemoryWriteByteEnable;
    assign globalMemoryWriteByteEnable =  uut.globalMemoryCacheInst.globalMemoryWriteByteEnable;
    
    // Logic Registers and Variables
    logic [4:0] nonAdjacentCounter;
    assign nonAdjacentCounter = uut.globalMemoryCacheInst.nonAdjacentCounter;
    
    logic [4:0] nonAdjacentCounterPlusOne;
    assign nonAdjacentCounterPlusOne = uut.globalMemoryCacheInst.nonAdjacentCounterPlusOne;
    
    logic [2:0] adjacentCounter;
    assign adjacentCounter = uut.globalMemoryCacheInst.adjacentCounter;
    
    logic [2:0] adjacentCounterPlusOne;
    assign adjacentCounterPlusOne = uut.globalMemoryCacheInst.adjacentCounterPlusOne;
    
    logic [2:0] adjacentOffAxisWriteCounter;
    assign adjacentOffAxisWriteCounter = uut.globalMemoryCacheInst.adjacentOffAxisWriteCounter;
    
    logic [2:0] adjacentOffAxisWriteCounterPlusOne;
    assign adjacentOffAxisWriteCounterPlusOne = uut.globalMemoryCacheInst.adjacentOffAxisWriteCounterPlusOne;
    
    logic cacheHitBit;
    assign cacheHitBit = uut.globalMemoryCacheInst.cacheHitBit;
    
    logic [31:0] masterMar;
    assign masterMar = uut.globalMemoryCacheInst.masterMar;
    
    logic [127:0] nonAdjacentMasterDataIn;
    assign nonAdjacentMasterDataIn = uut.globalMemoryCacheInst.nonAdjacentMasterDataIn;
    
    logic [127:0] masterDataIn;
    assign masterDataIn = uut.globalMemoryCacheInst.masterDataIn;
    
    logic [127:0] globalMemReadRegister;
    assign globalMemReadRegister = uut.globalMemoryCacheInst.globalMemReadRegister;
    
    logic [127:0] dataBramOut;
    assign dataBramOut = uut.globalMemoryCacheInst.dataBramOut;
    
    logic [127:0] dataBramIn;
    assign dataBramIn = uut.globalMemoryCacheInst.dataBramIn;
    
    logic [15:0] bramHeaderDataIn;
    assign bramHeaderDataIn = uut.globalMemoryCacheInst.bramHeaderDataIn;
    
    logic [15:0] bramHeaderDataOut;
    assign bramHeaderDataOut = uut.globalMemoryCacheInst.bramHeaderDataOut;
    
    logic [10:0] bramHeaderAddress;
    assign bramHeaderAddress = uut.globalMemoryCacheInst.bramHeaderAddress;
    
    logic [3:0] dataBramIndividualEnable;
    assign dataBramIndividualEnable = uut.globalMemoryCacheInst.dataBramIndividualEnable;
    
    logic [3:0] dataBramSegmentsOn;
    assign dataBramSegmentsOn = uut.globalMemoryCacheInst.dataBramSegmentsOn;
    
    logic [1:0] lateMarBits;
    assign lateMarBits = uut.globalMemoryCacheInst.lateMarBits;
    
    logic [3:0] globalMemoryWriteByteEnableConcatenated;
    assign globalMemoryWriteByteEnableConcatenated = uut.globalMemoryCacheInst.globalMemoryWriteByteEnableConcatenated;
    
    logic headerBramEnable;
    assign headerBramEnable = uut.globalMemoryCacheInst.headerBramEnable;
    
    logic headerBramWriteEnable;
    assign headerBramWriteEnable = uut.globalMemoryCacheInst.headerBramWriteEnable;
    
    logic dataBramEnable;
    assign dataBramEnable = uut.globalMemoryCacheInst.dataBramEnable;
    
    logic dataBramWriteEnable;
    assign dataBramWriteEnable = uut.globalMemoryCacheInst.dataBramWriteEnable;
    
    logic loadDataBramFromGlobal;
    assign loadDataBramFromGlobal = uut.globalMemoryCacheInst.loadDataBramFromGlobal;
    
    logic loadGlobalMemReadRegister;
    assign loadGlobalMemReadRegister = uut.globalMemoryCacheInst.loadGlobalMemReadRegister;
    
    logic core31loadReg;    
    logic core3loadReg;
    import gpuCoreTypes::*; // Import the package
    memState memoryState;
    state_t core0State, core1State, core2State, core3State, core4State, core5State, core6State, core7State, core8State, core9State, core10State, core11State, core12State, core13State, core14State, core15State,
    core16State, core17State, core18State, core19State, core20State, core21State, core22State, core23State;
    always_comb begin
        memoryState = uut.globalMemoryCacheInst.getMemState();
        core0State = uut.gpu_core_instances[0].coreInst.getState();
        core1State = uut.gpu_core_instances[1].coreInst.getState();
        core2State = uut.gpu_core_instances[2].coreInst.getState();
        core3State = uut.gpu_core_instances[3].coreInst.getState();
        core4State = uut.gpu_core_instances[4].coreInst.getState();
        core5State = uut.gpu_core_instances[5].coreInst.getState();
        core6State = uut.gpu_core_instances[6].coreInst.getState();
        core7State = uut.gpu_core_instances[7].coreInst.getState();
        core8State = uut.gpu_core_instances[8].coreInst.getState();
        core9State = uut.gpu_core_instances[9].coreInst.getState();
        core10State = uut.gpu_core_instances[10].coreInst.getState();
        core11State = uut.gpu_core_instances[11].coreInst.getState();
        core12State = uut.gpu_core_instances[12].coreInst.getState();
        core13State = uut.gpu_core_instances[13].coreInst.getState();
        core14State = uut.gpu_core_instances[14].coreInst.getState();
        core15State = uut.gpu_core_instances[15].coreInst.getState();
        core16State = uut.gpu_core_instances[16].coreInst.getState();
        core17State = uut.gpu_core_instances[17].coreInst.getState();
        core18State = uut.gpu_core_instances[18].coreInst.getState();
        core19State = uut.gpu_core_instances[19].coreInst.getState();
        core20State = uut.gpu_core_instances[20].coreInst.getState();
        core21State = uut.gpu_core_instances[21].coreInst.getState();
        core22State = uut.gpu_core_instances[22].coreInst.getState();
        core23State = uut.gpu_core_instances[23].coreInst.getState();
        core3loadReg = uut.gpu_core_instances[3].coreInst.loadReg;
    end
    // Test initialization
    
    initial begin
        globalMemReadData = 128'h0000_0003_0000_0002_0000_0001_0000_0000; // Initial value
    end
    
   always @(posedge clk) begin
        // Generate a random number between 0 and 4
        if ($urandom_range(0, 4) == 0) begin
            globalMemFinishedAction = 1; // 1 out of 5 chance
        end else begin
            globalMemFinishedAction = 0; // Otherwise 0
        end
    end
    
    
    
    // Update globalMemReadData on every positive edge of clk
    always @(posedge clk) begin
        globalMemReadData[31:0]   = globalMemReadData[31:0] + 4;
        globalMemReadData[63:32]  = globalMemReadData[63:32] + 4;
        globalMemReadData[95:64]  = globalMemReadData[95:64] + 4;
        globalMemReadData[127:96] = globalMemReadData[127:96] + 4;
    end
    
    
    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;
        instruction = 0;
        executeInstruction = 0;

        // Apply reset for a few clock cycles
        #30;
        reset = 0; // No state should be currently active
        #20500;
        
        // First instruction (Add)
        instruction = 32'b0000_010_111_1_0_0000_0000_0000_0000_0001; // add R7, R0, store in R2
        #30;
        executeInstruction = 1;
        #20;
        executeInstruction = 0;
        
        // Second instruction (Multiplication)
        #80;
        instruction = 32'b0010_011_010_1_00000_11111111_00001110; // multiplication
        #20;
        executeInstruction = 1;
        #10;
        executeInstruction = 0;
        
        // Third instruction (Global memory store register)
        #30;
        instruction = 32'b1110_111_111_010_0101_000000000000001; // Global memory store Register operation
//        instruction = 32'b1010_110_111_000000_00000000_00000001; //Global mem read immediate operation

        #20;
        executeInstruction = 1;
        #10;
        executeInstruction = 0;
        
        
        
        #1000;
        instruction = 32'b1110_111_111_010_0101_000000000000000; // Global memory store Register operation
//        instruction = 32'b1010_110_111_000000_00000000_00000001; //Global mem read immediate operation

        #20;
        executeInstruction = 1;
        #10;
        executeInstruction = 0;
        
        // Finish the test after the instructions are executed
        #4000;
//        instruction = 32'b1110_011_111_0000_00_0000_0000_0000_0000; //Global memory store immediate operation
        instruction = 32'b1010_110_111_000000_00000000_00000000; //Global mem read immediate operation

        #20;
        executeInstruction = 1;
        #10;
        executeInstruction = 0;
        instruction = 0;
        #4000;
        instruction = 32'b1010_110_111_000000_00000000_00000000; //Global mem read immediate operation
        executeInstruction = 1;
        #10;
        executeInstruction = 0;
        #1000;
        instruction = 32'b1010_110_100_000000_00000000_00000000; //Global mem read immediate operation
        executeInstruction = 1;
        #10;
        executeInstruction = 0;
        #8000;
        instruction = 32'b1110_111_100_000000_00000000_00000000; //Global mem read immediate operation
        executeInstruction = 1;
        #10;
        executeInstruction = 0;
        #8000;
        $stop;
    end

endmodule
