module instructionBuffer(
    input logic clk,
    input logic reset,
    input logic coresReady,
    input logic newInstruction,
    input logic [31:0] instructionIn,
    output logic [31:0] instructionOut,
    output logic [4:0] bufferFill,
    output logic sentInstruction
);
    //sentInstruction will not percolate out fast enough to affect coresReady.
    //I used coresReadyToSend to delay by one cycle. Its combinational logic is at the bottom of the file.


    //can only have maximum 31 items in the buffer

    logic [4:0] counter;
    logic [4:0] counterUp, counterDown;
    logic [31:0] instructions[32];
    
    (* MARK_DEBUG = "TRUE" *) logic [4:0] bufferFillValueDebug;
    assign bufferFillValueDebug = counter;
    logic coresReadyToSend;
    
    int i, j;
    always_ff @(posedge clk) begin

        //instruction buffer logic
        if(reset) begin
            instructions[31] <= 0;
        end
        for(i = 0; i<31; i+=1) begin
            if(reset) begin
                instructions[i] <= 0;
            end
            else begin
                if(i != counter && coresReadyToSend) begin //if the cores are ready and a new instruction is ready, shift down except for the counter
                    instructions[i] <= instructions[i+1];
                end
                else if (newInstruction && i== counter) begin //this is an else-if, so it assumes i== counter and there is a new instruction
                    instructions[i] <= instructionIn;
                end
            end
        end

        //counter logic
        if(reset) begin
            counter <= 0;
        end
        else if(coresReadyToSend && !newInstruction && |counter) begin
            counter <= counterDown;
        end
        else if(!coresReadyToSend && newInstruction && ~(&counter)) begin
            counter <= counterUp;
        end

        //sentInstruction logic
        if (reset) begin
            sentInstruction <= 1'b0;  // Reset `sentInstruction` on reset.
        end
        else if (coresReadyToSend && !sentInstruction && (counter != 0 || newInstruction)) begin
            sentInstruction <= 1'b1;  // Assert `sentInstruction` for one cycle if cores are ready and there's work to do.
        end
        else begin
            sentInstruction <= 1'b0;  // Automatically deassert `sentInstruction` after one cycle.
        end       
        
        if(reset) begin //InstructionOut is now a register.
            instructionOut <= 32'hAAAAAAAA;
        end
        else if(coresReadyToSend && !sentInstruction && counter != 0) begin
            instructionOut <= instructions[0];
        end
        else if(coresReadyToSend && !sentInstruction && newInstruction) begin
            instructionOut <= instructionIn;
        end
        
        
    end
    always_comb begin
        counterUp = counter + 1;
        counterDown = counter - 1;
        bufferFill = counter;
        coresReadyToSend = (sentInstruction) ? 1'b0 : coresReady;
        
        
    end
endmodule
