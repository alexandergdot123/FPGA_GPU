module sysClock(
    input logic reset,
    input logic clk,
    output logic [31:0] timeMicro
);
    logic [6:0] underMS;
    logic [31:0] overMS;

    always_ff @(posedge clk) begin
        if(reset) begin
            underMS <= 0;
            overMS <= 0;
        end
        else begin
            if(underMS == 99) begin
                underMS <= 0;
                overMS <= overMS + 1;
            end
            else begin
                underMS <= underMS + 1;
                overMS <= overMS;
            end
        end

    end
    assign timeMicro = overMS;
endmodule
