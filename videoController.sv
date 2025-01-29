module videoController(
    input  logic clk,
    input  logic reset,
    input  logic [7:0] red,
    input  logic [7:0] green,
    input  logic [7:0] blue,
    output logic hdmi_clk_n,
    output logic hdmi_clk_p,
    output logic [2:0] hdmi_tx_n,
    output logic [2:0] hdmi_tx_p,
    output logic [9:0] drawX,
    output logic [9:0] drawY
);

    logic clk_25;
    logic clk_125;
    logic lock_wiz;
    // //clock wizard configured with a 1x and 5x clock for HDMI
    clk_wiz_0 clk_wiz (
        .clk_out1(clk_25),
        .clk_out2(clk_125),
        .reset(reset),
        .locked(lock_wiz),
        .clk_in1(clk)
    );

    logic hsync;
    logic vsync;
    logic vde;

    //VGA Sync signal generator
    vga_controller vga (
        .pixel_clk(clk_25),
        .reset(reset), 
        .hs(hsync),
        .vs(vsync),
        .active_nblank(vde),
        .drawX(drawX),
        .drawY(drawY)
    );    

    //Real Digital VGA to HDMI converter
    hdmi_tx_0 vga_to_hdmi (
        //Clocking and Reset
        .pix_clk(clk_25),
        .pix_clkx5(clk_125),
        .pix_clk_locked(lock_wiz),
        //Reset is active LOW
        .rst(reset),
        //Color and Sync Signals
        .red(red),
        .green(green),
        .blue(blue),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        
        //aux Data (unused)
             .aux0_din(4'b0),
             .aux1_din(4'b0),
             .aux2_din(4'b0),
             .ade(1'b0),
        
        //Differential outputs
        .TMDS_CLK_P(hdmi_clk_p),          
        .TMDS_CLK_N(hdmi_clk_n),          
        .TMDS_DATA_P(hdmi_tx_p),         
        .TMDS_DATA_N(hdmi_tx_n)          
    );

endmodule
