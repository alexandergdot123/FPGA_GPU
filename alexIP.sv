`timescale 1 ns / 1 ps

module alexIP_v1_0 #
(
    // Parameters of Axi Slave Bus Interface S00_AXI
    // Modify parameters as necessary for access of full VRAM range

    parameter integer C_AXI_DATA_WIDTH	= 32,
    parameter integer C_AXI_ADDR_WIDTH	= 16
)
(
    // Users to add ports here
//    input logic clock_100MHZ,
//    input logic resetAH,


//    output logic hdmi_clk_n,
//    output logic hdmi_clk_p,
//    output logic [2:0] hdmi_tx_n,
//    output logic [2:0] hdmi_tx_p,
    input logic [9:0] drawX,
    input logic [9:0] drawY,
    // User ports ends
    
    
    // Do not modify the ports beyond this line
    // Ports of Axi Slave Bus Interface AXI
    input logic  axi_aclk,
    input logic  axi_aresetn,
    input logic [C_AXI_ADDR_WIDTH-1 : 0] axi_awaddr,
    input logic [2 : 0] axi_awprot,
    input logic  axi_awvalid,
    output logic  axi_awready,
    input logic [C_AXI_DATA_WIDTH-1 : 0] axi_wdata,
    input logic [(C_AXI_DATA_WIDTH/8)-1 : 0] axi_wstrb,
    input logic  axi_wvalid,
    output logic  axi_wready,
    output logic [1 : 0] axi_bresp,
    output logic  axi_bvalid,
    input logic  axi_bready,
    input logic [C_AXI_ADDR_WIDTH-1 : 0] axi_araddr,
    input logic [2 : 0] axi_arprot,
    input logic  axi_arvalid,
    output logic  axi_arready,
    output logic [31 : 0] axi_rdata,
    output logic [1 : 0] axi_rresp,
    output logic  axi_rvalid,
    input logic  axi_rready,
    
    //ddr3 here
//    input logic sys_clk_n,
//    input logic sys_clk_p,
//    output logic [12:0] ddr3_addr,
//    output logic [2:0] ddr3_ba,
//    output logic ddr3_cas_n,
//    output logic ddr3_ck_n,
//    output logic ddr3_ck_p,
//    output logic ddr3_cke,
//    output logic [1:0] ddr3_dm,
//    inout wire [15:0] ddr3_dq,
//    inout wire [1:0] ddr3_dqs_n,
//    inout wire [1:0] ddr3_dqs_p,
//    output logic ddr3_odt,
//    output logic ddr3_ras_n,
//    output logic ddr3_reset_n,
//    output logic ddr3_we_n,
////    input logic clk_ref_i,
////    input logic sys_rst,
//    output logic        ram_init_error,
//    output logic        ram_init_done,

    output logic [26:0] alexAddress,
    output logic [127:0] alexWriteData,
    input logic [127:0] alexReadData,
    output logic alexMemEnable,
    output logic alexMemWriteEnable,
    output logic [7:0] alexWriteBytes,
    input logic alexFinishedAction

    
    //sd card
//    output logic sd_sclk,
//    output logic sd_mosi,
//    output logic sd_cs,
//    output logic sd_miso
    
);


//logic [26:0] alexAddress;
//logic [127:0] alexWriteData;
//logic [127:0] alexReadData;
//logic alexMemEnable;
//logic alexMemWriteEnable;
//logic [7:0] alexWriteBytes;
//logic alexFinishedAction;


//additional logic variables as necessary to support VGA, and HDMI modules.
// Instantiation of Axi Bus Interface AXI
hdmi_text_controller_v1_0_AXI # ( 
    .C_S_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH)
) hdmi_text_controller_v1_0_AXI_inst (




    .alexAddress(alexAddress),
    .alexWriteData(alexWriteData),
    .alexReadData(alexReadData),
    .alexMemEnable(alexMemEnable),
    .alexMemWriteEnable(alexMemWriteEnable),
    .alexWriteBytes(alexWriteBytes),
    .alexFinishedAction(alexFinishedAction),

//    .hdmi_clk_n(hdmi_clk_n),
//    .hdmi_clk_p(hdmi_clk_p),
//    .hdmi_tx_n(hdmi_tx_n),
//    .hdmi_tx_p(hdmi_tx_p),
    .drawX(drawX),
    .drawY(drawY),

    //don't modify below this!
    .S_AXI_ACLK(axi_aclk),
    .S_AXI_ARESETN(axi_aresetn),
    .S_AXI_AWADDR(axi_awaddr),
    .S_AXI_AWPROT(axi_awprot),
    .S_AXI_AWVALID(axi_awvalid),
    .S_AXI_AWREADY(axi_awready),
    .S_AXI_WDATA(axi_wdata),
    .S_AXI_WSTRB(axi_wstrb),
    .S_AXI_WVALID(axi_wvalid),
    .S_AXI_WREADY(axi_wready),
    .S_AXI_BRESP(axi_bresp),
    .S_AXI_BVALID(axi_bvalid),
    .S_AXI_BREADY(axi_bready),
    .S_AXI_ARADDR(axi_araddr),
    .S_AXI_ARPROT(axi_arprot),
    .S_AXI_ARVALID(axi_arvalid),
    .S_AXI_ARREADY(axi_arready),
    .S_AXI_RDATA(axi_rdata),
    .S_AXI_RRESP(axi_rresp),
    .S_AXI_RVALID(axi_rvalid),
    .S_AXI_RREADY(axi_rready)
);
endmodule
