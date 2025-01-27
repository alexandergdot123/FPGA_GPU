`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/22/2024 10:34:11 PM
// Design Name: 
// Module Name: gpuCoreTestBench
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


module gpuCoreTestBench(

    );
    logic [31:0] instruction;
    logic executeInstruction;
    logic clk;
    logic [31:0] threadId;
    logic reset;
    logic finishedReadMemoryDataShared; //input
    logic finishedReadMemoryDataGlobal;  //input
    logic finishedWriteMemoryDataShared; //input
    logic finishedWriteMemoryDataGlobal; //input
    logic [31:0] MDRIn; //input
    logic writingMemoryDataShared; //output
    logic writingMemoryDataGlobal; //output
    logic readingMemoryDataShared; //output
    logic readingMemoryDataGlobal; //output
    logic readyForNextInstruction; //output
    logic [31:0] marOut, mdrOut; //output
    
    logic [2:0] chooseSR1, chooseSR2;
    logic [31:0] sr1Out, sr2Out, IR;
    
    import gpuCoreTypes::*; // Import the package

    state_t state; // Testbench's local state
    always_comb begin
        state = gpuCoreInst.getState();
    end
    gpuCore gpuCoreInst(
        .*    
    );
    logic [31:0] regfileDataIn;
    logic loadReg;
    assign IR = gpuCoreInst.IR;
    assign loadReg = gpuCoreInst.regFileInst.loadReg;
    assign regfileDataIn = gpuCoreInst.regFileInst.dataInModified;
    assign sr1Out = gpuCoreInst.regFileInst.sr1Out;
    assign chooseSR1 = gpuCoreInst.regFileInst.addr1;
    assign sr2Out = gpuCoreInst.regFileInst.sr2Out;
    assign chooseSR2 = gpuCoreInst.regFileInst.addr2;
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period
    end
    initial begin
        #5;
        reset = 1;
        instruction = 0;
        threadId = 2;
        executeInstruction = 0;
        finishedReadMemoryDataShared = 0;
        finishedReadMemoryDataGlobal = 0;
        finishedWriteMemoryDataShared = 0;
        finishedWriteMemoryDataGlobal = 0;
        MDRIn = 32'hABCDEF12;
        #30;
        reset = 0; //no state should be currently active
        #30;
        instruction = 32'b0000_010_111_1_0_0000_0000_0000_0000_0001; //add R7, R0, store in R2
        #30;
        executeInstruction = 1;
        #20;
        executeInstruction = 0;
        
        #80;
//        instruction = 32'b0010_011_010_1_00000_11111111_00001110; //this is multiplication
        instruction = 32'b0001_011_010_1_1_1_000_0000_0000_0000_0000; //This is an OR
//        instruction = 32'b0011_011_010_1_000_00_0000000000000000; // this is a bitshift operator
//        instruction = 32'b0101_010_000001_111_010_0000000000000; // this is a compare operation

        #20;
        executeInstruction = 1;
        #10;
        executeInstruction = 0;
        #30;
//        instruction = 32'b1101_011_111_010_0000000000000000000; // this is a shared memory store Register operation
//        instruction = 32'b1100_011_111_0000_00_0000_0000_0011_0000; //shared memory store immediate operation
//        instruction = 32'b1110_011_111_0101_00_0000_0000_0011_0000; //Global memory store immediate operation
//        instruction = 32'b1111_011_111_010_0101_000000000000000; // this is a Global memory store Register operation
        instruction = 32'b1011_101_111_011_000_0000_0000_0000_0000; //global mem read reg operation
//        instruction = 32'b1001_101_111_011_000_0000_0000_0000_0000; //shared mem read reg operation
//        instruction = 32'b1000_101_111_000000_00000000_00000000; //shared mem read immediate operation
//        instruction = 32'b1010_101_111_000000_00000000_00000000; //Global mem read immediate operation



//        instruction = 32'b0011_011_011_0_011_00_0000000000000000;
        #20;
        executeInstruction = 1;
        #10;
        executeInstruction = 0;
        #100;        
        finishedReadMemoryDataGlobal = 1;
        #100;
        executeInstruction = 1;
        #10;
        executeInstruction = 0;
        #100;        
        $stop;

    end
endmodule
