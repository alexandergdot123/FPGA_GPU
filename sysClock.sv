module sysClock(
    input logic reset,
    input logic clk, //expects a 100MHz clock
    output logic [31:0] timeMicro //time in microseconds
);
    logic [6:0] underMS; //reaches 100, then increments overMS
    logic [31:0] overMS; //counts in microseconds

    always_ff @(posedge clk) begin
        if(reset) begin
            underMS <= 0;
            overMS <= 0;
        end
        else begin
            if(underMS == 99) begin//if underMS hits 99 (one before 100
                underMS <= 0; //reset it
                overMS <= overMS + 1; //and increment overMS
            end
            else begin
                underMS <= underMS + 1; //otherwise, just increment underMS
                overMS <= overMS; //and maintain overMS
            end
        end

    end
    assign timeMicro = overMS;
endmodule
