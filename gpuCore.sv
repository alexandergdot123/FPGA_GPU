module gpuCore(
    input logic [31:0] instruction,
    input logic executeInstruction,
    input logic clk,
    input logic [31:0] threadId,
    input logic reset,
    input logic finishedReadMemoryDataShared,
    input logic finishedReadMemoryDataGlobal,
    input logic finishedWriteMemoryDataShared,
    input logic finishedWriteMemoryDataGlobal,
    input logic [31:0] MDRIn,
    output logic readyForNextInstruction,
    output logic writingMemoryDataShared,
    output logic writingMemoryDataGlobal,
    output logic readingMemoryDataShared,
    output logic readingMemoryDataGlobal,
    output logic [31:0] marOut,
    output logic [31:0] mdrOut
);
    logic [1:0] writeBytes;
    import gpuCoreTypes::*; // Import the package

    state_t state;
    
    
    function state_t getState();
        return state;
    endfunction
    
    
    logic [31:0] SR1Out, SR2Out, multOut, mainBus, addIn2, addInAddInstruction, addInMemInstruction, 
        addOut, bitShiftOut, bitwiseOut, comparatorOut, comparatorInput2, DRIn, multInReg1, multInReg2, multOutReg,
        addOutReg, bitShiftOutReg, bitwiseOutReg;
    logic [31:0] IR, mdr, mar;
    logic [5:0] countdown;
    logic countdownOn, comparatorPositive, comparatorNegative, comparatorZero, skipLines;
    logic [2:0] chooseSR1, chooseSR2, chooseDR;
    logic loadReg, loadMar, loadMdr, gateMultOut, gateBitwiseOut, gateBitshiftOut, gateAddOut, 
        gateMdrOut, loadIR, gateSR1Out, externalMdrGate, loadAdder, loadMultiplier, loadBitwise, loadBitshift; 
    logic [1:0] writeBits;
    regFile regFileInst(
        .reset(reset),
        .clk(clk), 
        .loadReg(loadReg),
        .sr1(chooseSR1),
        .sr2(chooseSR2),
        .dr(chooseDR),
        .dataIn(mainBus),
        .sr1Out(SR1Out),
        .sr2Out(SR2Out),
        .threadID(threadId)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= Decode;
            IR <= 0;
            countdown <= 0;
            mar <= 0;
            mdr <= 0;
            writeBits <= 0;
            multOutReg <= 0;
            multInReg1 <= 0;
            multInReg2 <= 0;
            bitShiftOutReg <= 0;
            bitwiseOutReg <= 0;
        end
        else begin
            multInReg1 <= SR1Out;
            multInReg2 <= ((IR[21]) ? {{16{IR[15]}},IR[15:0]} : SR2Out);
            multOutReg <= multOut;
            bitShiftOutReg <= bitShiftOut;
            bitwiseOutReg <= bitwiseOut;
            //state transitions
            if(state == Decode && executeInstruction && !countdownOn) begin
                IR <= instruction;
                case(instruction[31:28])
                    4'b0000: state <= Add1;
                    4'b0001: state <= Bitwise1;
                    4'b0010: state <= Multiply1;
                    4'b0011: state <= BitShift1;
                    4'b0100: state <= CompareImmediate1;
                    4'b0101: state <= CompareDual1;
                    4'b1000: state <= LoadSharedImmediate1;
                    4'b1001: state <= LoadSharedReg1;
                    4'b1010: state <= LoadGlobalImmediate1;
                    4'b1011: state <= LoadGlobalReg1;
                    4'b1100: state <= StoreSharedImmediate1;
                    4'b1101: state <= StoreSharedReg1;
                    4'b1110: state <= StoreGlobalImmediate1;
                    4'b1111: state <= StoreGlobalReg1;
                    default: state <= Decode;
                endcase
            end
            else begin
                unique case(state)
                    Add1: state <= Add2;
                    Bitwise1: state <= Bitwise2;
                    Multiply1: state <= Multiply2;
                    BitShift1: state <= BitShift2;
                    Add2: state <= Decode;
                    Bitwise2: state <= Decode;
                    Multiply2: state <= Multiply3;
                    Multiply3: state <= Multiply4;
                    Multiply4: state <= Decode;

                    BitShift2: state <= Decode;
                    CompareImmediate1: state <= CompareImmediate2;
                    CompareDual1: state <= CompareDual2;
                    CompareImmediate2: state <= Decode;
                    CompareDual2: state <= Decode;
                    
                    LoadSharedImmediate1: state <= LoadSharedImmediate2;
                    LoadGlobalImmediate1: state <= LoadGlobalImmediate2;
                    LoadSharedReg1: state <= LoadSharedReg2;
                    LoadGlobalReg1: state <= LoadGlobalReg2;
                    
                    LoadSharedImmediate2: state <= ReadMemoryDataShared;
                    LoadGlobalImmediate2: state <= ReadMemoryDataGlobal;
                    LoadSharedReg2: state <= ReadMemoryDataShared;
                    LoadGlobalReg2: state <= ReadMemoryDataGlobal;
                    
                    StoreMemoryDataShared: state <= WriteMemoryDataShared;
                    StoreMemoryDataGlobal: state <= WriteMemoryDataGlobal;
                    
                    StoreSharedImmediate1: state <= StoreSharedImmediate2;
                    StoreSharedReg1: state <= StoreSharedReg2;
                    StoreGlobalImmediate1: state <= StoreGlobalImmediate2;
                    StoreGlobalReg1: state <= StoreGlobalReg2;
                    
                    StoreSharedImmediate2: state <= StoreMemoryDataShared;
                    StoreSharedReg2: state <= StoreMemoryDataShared;
                    StoreGlobalImmediate2: state <= StoreMemoryDataGlobal;
                    StoreGlobalReg2: state <= StoreMemoryDataGlobal;
                    
                    ReadMemoryDataShared: state <= (finishedReadMemoryDataShared) ? StoreReadMemoryData : ReadMemoryDataShared;
                    ReadMemoryDataGlobal: state <= (finishedReadMemoryDataGlobal) ? StoreReadMemoryData : ReadMemoryDataGlobal;
                    StoreReadMemoryData: state <= Decode;
                    WriteMemoryDataGlobal: state <= (finishedWriteMemoryDataGlobal) ? Decode : WriteMemoryDataGlobal;
                    WriteMemoryDataShared: state <= (finishedWriteMemoryDataShared) ? Decode : WriteMemoryDataShared;
                    Decode: state <= Decode;
                    default: state <= Bad; //this should never happen
                endcase
            end

            //For the Countdown
            if(skipLines && (state == CompareImmediate2 || state == CompareDual2)) begin
                countdown <= IR[24:19];
            end
            else begin
                if(executeInstruction && countdownOn) begin
                    countdown <= countdown - 1;
                end
                else begin
                    countdown <= countdown;
                end
            end

            //For Mar
            if(loadMdr) begin
                mdr <= (externalMdrGate) ? MDRIn : mainBus; //if externalMDRGate is 1, then get the MDR value from external to the module
            end

            mar <= (loadMar) ? mainBus : mar;

            if(state == StoreGlobalImmediate1) begin
                writeBits <= IR[19:18];
            end
            else if (state == StoreGlobalReg1) begin
                writeBits <= IR[16:15];
            end
        end
    end

    always_comb begin
        writeBytes = writeBits;
        countdownOn = |countdown;
        multOut = multInReg1 * multInReg2;
//        addInAddInstruction = (((IR[21]) ? {{16{1'b0}}, IR[15:0]} : SR2Out) ^ {32{IR[20]}}) + {{31{1'b0}}, IR[20]}; //this no longer sign extends the immediate value
        addInAddInstruction = (IR[21]) ? {16'h0000, IR[15:0]} : SR2Out;
        case(state)
            LoadSharedReg2: addInMemInstruction = SR2Out;
            LoadSharedImmediate2: addInMemInstruction = {{10{IR[21]}},IR[21:0]};
            LoadGlobalReg2: addInMemInstruction = SR2Out;
            LoadGlobalImmediate2: addInMemInstruction = {{10{IR[21]}},IR[21:0]};
            StoreSharedImmediate2: addInMemInstruction = {{14{IR[17]}},IR[17:0]};
            StoreSharedReg2: addInMemInstruction = SR2Out;
            StoreGlobalImmediate2: addInMemInstruction = {{14{IR[17]}},IR[17:0]};
            StoreGlobalReg2: addInMemInstruction = SR2Out;
            default: addInMemInstruction = 32'hxxxxxxxx;
        endcase
        addIn2 = (state == Add2) ? addInAddInstruction : addInMemInstruction;
//        addOut = SR1Out + addIn2;
        addOut = (state == Add2 && IR[20]) ? (SR1Out - addIn2) : (SR1Out + addIn2);

        case(IR[21:18])
            4'b0000: bitShiftOut = {1'b0, SR1Out[31:1]};
            4'b0001: bitShiftOut = {2'b0, SR1Out[31:2]};
            4'b0010: bitShiftOut = {4'b0, SR1Out[31:4]};
            4'b0011: bitShiftOut = {8'b0, SR1Out[31:8]};
            4'b0100: bitShiftOut = {16'b0, SR1Out[31:16]};
            4'b0101: bitShiftOut = {24'b0, SR1Out[31:24]};
            4'b1000: bitShiftOut = {SR1Out[30:0], 1'b0};
            4'b1001: bitShiftOut = {SR1Out[29:0], 2'b0};
            4'b1010: bitShiftOut = {SR1Out[27:0], 4'b0};
            4'b1011: bitShiftOut = {SR1Out[23:0], 8'b0};
            4'b1100: bitShiftOut = {SR1Out[15:0], 16'b0};
            4'b1101: bitShiftOut = {SR1Out[7:0], 24'b0};
            default: bitShiftOut = SR1Out;
        endcase
        case(IR[21:20])
            2'b00: bitwiseOut = SR1Out & SR2Out;
            2'b01: bitwiseOut = SR1Out & {{16{IR[19]}}, IR[15:0]};
            2'b10: bitwiseOut = SR1Out | SR2Out;
            2'b11: bitwiseOut = SR1Out | {{16{IR[19]}}, IR[15:0]};
        endcase
        comparatorInput2 = (state == CompareDual2) ? SR2Out : {{16{IR[15]}}, IR[15:0]};
        comparatorOut = SR1Out - comparatorInput2;
        comparatorNegative = comparatorOut[31];
        comparatorZero = !(|comparatorOut);
        comparatorPositive = ~(comparatorZero | comparatorNegative);
        skipLines = (comparatorNegative & ~IR[25]) | (comparatorZero & ~IR[26]) | (comparatorPositive & ~IR[27]);
        readyForNextInstruction = state == Decode;
    end





    always_comb begin
        // Default values for control signals
        loadReg = 1'b0;
        loadMar = 1'b0;
        loadMdr = 1'b0;
        gateMultOut = 1'b0;
        gateBitwiseOut = 1'b0;
        gateBitshiftOut = 1'b0;
        gateAddOut = 1'b0;
        gateMdrOut = 1'b0;
        gateSR1Out = 1'b0;
        writingMemoryDataGlobal = 1'b0;
        writingMemoryDataShared = 1'b0;
        readingMemoryDataGlobal = 1'b0;
        readingMemoryDataShared = 1'b0;
        externalMdrGate = 1'b0;
        chooseSR1 = 3'bxxx;
        chooseSR2 = 3'bxxx;
        chooseDR = 3'bxxx;
        // State-based control signal assignments
        case (state)
            Decode: begin
            end
            Add1: begin
                chooseSR1 = IR[24:22];
                chooseSR2 = IR[19:17];
            end
            Add2: begin
                loadReg = 1; // Load result into register
                gateAddOut = 1; // Enable ALU add output
                chooseDR = IR[27:25];
            end
            Bitwise1: begin
                chooseSR1 = IR[24:22];
                chooseSR2 = IR[19:17];
            end
            Bitwise2: begin
                loadReg = 1; // Load result into register
                gateBitwiseOut = 1; // Enable bitwise operation output
                chooseDR = IR[27:25];
            end
            Multiply1: begin
                chooseSR1 = IR[24:22];
                chooseSR2 = IR[19:17];
            end
            Multiply4: begin
                loadReg = 1; // Load result into register
                gateMultOut = 1; // Enable multiplier output
                chooseDR = IR[27:25];
            end
            BitShift1: begin
                chooseSR1 = IR[24:22];
            end
            BitShift2: begin
                loadReg = 1; // Load result into register
                gateBitshiftOut = 1; // Enable bit shift output
                chooseDR = IR[27:25];
            end
            CompareImmediate1: begin
                chooseSR1 = IR[18:16];
            end
            CompareDual1: begin
                chooseSR1 = IR[18:16];
                chooseSR2 = IR[15:13];
            end
            CompareImmediate2: begin
            
            end
            CompareDual2: begin
            
            end
            LoadSharedImmediate1: begin
                chooseSR1 = IR[24:22];
            end
            LoadSharedReg1: begin
                chooseSR1 = IR[24:22];
                chooseSR2 = IR[21:19];
            end
            LoadGlobalImmediate1: begin
                chooseSR1 = IR[24:22];
            end
            LoadGlobalReg1: begin
                chooseSR1 = IR[24:22];
                chooseSR2 = IR[21:19];
            end
            StoreSharedImmediate1: begin
                chooseSR1 = IR[24:22];
            end
            StoreSharedReg1: begin

                chooseSR1 = IR[24:22];
                chooseSR2 = IR[21:19];
            end
            StoreGlobalImmediate1: begin
                chooseSR1 = IR[24:22];
            end
            StoreGlobalReg1: begin
                chooseSR1 = IR[24:22];
                chooseSR2 = IR[21:19];
            end
            LoadSharedImmediate2: begin
                loadMar = 1; // Load address into MAR
                gateAddOut = 1;
            end
            LoadSharedReg2: begin
                loadMar = 1; // Load memory data register
                gateAddOut = 1; 
            end
            LoadGlobalImmediate2: begin
                loadMar = 1; // Load global address into MAR
                gateAddOut = 1; 
            end
            LoadGlobalReg2: begin
                loadMar = 1; // Load global data into MDR
                gateAddOut = 1; 
            end
            StoreSharedImmediate2: begin
                loadMar = 1; // Load address into MAR
                gateAddOut = 1; 
                chooseSR1 = IR[27:25];
            end
            StoreSharedReg2: begin
                loadMar = 1; // Load address into MAR
                gateAddOut = 1; 
                chooseSR1 = IR[27:25];
            end
            StoreGlobalImmediate2: begin
                loadMar = 1; // Load address into MAR
                gateAddOut = 1; 
                chooseSR1 = IR[27:25];
            end
            StoreGlobalReg2: begin
                loadMar = 1; // Load address into MAR
                gateAddOut = 1; 
                chooseSR1 = IR[27:25];
            end
            StoreMemoryDataShared: begin
                loadMdr = 1;
                gateSR1Out = 1; 
            end
            StoreMemoryDataGlobal: begin
                loadMdr = 1;
                gateSR1Out = 1; 
            end
            WriteMemoryDataShared: begin
                writingMemoryDataShared = 1;
            end
            WriteMemoryDataGlobal: begin
                writingMemoryDataGlobal = 1;
            end
            ReadMemoryDataShared: begin
                readingMemoryDataShared = 1;
                externalMdrGate = 1;
                loadMdr = 1;
            end
            ReadMemoryDataGlobal: begin
                readingMemoryDataGlobal = 1;
                externalMdrGate = 1;
                loadMdr = 1;
            end
            StoreReadMemoryData: begin
                loadReg = 1;
                gateMdrOut = 1;
                chooseDR = IR[27:25];
            end
            default: begin

            end
        endcase
        
        marOut = mar;
        mdrOut = mdr;
           
        case (1'b1)
            gateMultOut: mainBus = multOutReg;
            gateBitwiseOut: mainBus = bitwiseOut;
            gateBitshiftOut: mainBus = bitShiftOut;
            gateAddOut: mainBus = addOut;
            gateMdrOut: mainBus = mdr;
            gateSR1Out: mainBus = SR1Out;
            default: mainBus = 32'hXXXX;
        endcase
    end

endmodule


module regFile(
    input logic clk,
    input logic loadReg,
    input logic [2:0] sr1,
    input logic [2:0] sr2,
    input logic [2:0] dr,
    input logic [31:0] threadID,
    input logic [31:0] dataIn,
    input logic reset,
    output logic [31:0] sr1Out,
    output logic [31:0] sr2Out
);
    logic [2:0] addr1, addr2;
    logic [31:0] dataInModified;
    blk_mem_gen_0 u_blk_mem_gen_0 (
        .clka  (clk),      
        .ena   (1'b1),       
        .wea   ((loadReg | reset)),        
        .addra (addr1),    
        .dina  (dataInModified),    
        .douta (sr1Out),   
    
        .clkb  (clk), 
        .enb   (1'b1),        
        .web   ((loadReg | reset)),    
        .addrb (addr2),
        .dinb(dataInModified),
        .doutb (sr2Out)
    );
    always_comb begin
        addr1 = (reset) ? 3'b111 : ((loadReg) ? dr : sr1);
        addr2 = (reset) ? 3'b111 : ((loadReg) ? dr : sr2);

        dataInModified = (reset) ? threadID : dataIn;
    end
endmodule
