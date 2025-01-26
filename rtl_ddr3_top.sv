`timescale 1ns / 1ps
//Zuofu Cheng (2024) for ECE 385, wrapper for VHDL XESS SDCard driver
//
//
//
//Module which initializes with SDCard and emulates asynchronous ROM
//Useful for porting various emulation designs to the Urbana board
//Note that the student must set up the MIG configuration according to the
//Using DDR3 MIG for RTL Designs document from the ECE 385 materials.
//

module rtl_ddr3_top (
//   (input  logic sys_clk_n, //differential system clock input
//    input  logic sys_clk_p, //note that this is different than previous designs
    output logic [12:0] ddr3_addr,
    output logic [2:0] ddr3_ba,
    output logic ddr3_cas_n,
    output logic ddr3_ck_n, //differential DDR3 clock, typically between 300-333MHz
    output logic ddr3_ck_p,
    output logic ddr3_cke,
    output logic [1:0] ddr3_dm,
    inout wire [15:0] ddr3_dq, //bidirectional signals need to be of type wire
    inout wire [1:0] ddr3_dqs_n,
    inout wire [1:0] ddr3_dqs_p,
    output logic ddr3_odt,   
    output logic ddr3_ras_n,
    output logic ddr3_reset_n,
    output logic ddr3_we_n,
    input logic clk_ref_i,
    input logic sys_rst,
    
    //SDCard
    output logic        sd_sclk,
    output logic        sd_mosi,
    output logic        sd_cs,
    input logic         sd_miso,
    
    //HEX displays
//    output logic [7:0]  hex_segA,
//    output logic [7:0]  hex_segB,
//    output logic [3:0]  hex_gridA,
//    output logic [3:0]  hex_gridB,
    
    //Switches
//    input logic [15:0]  SW,
    input logic [26:0] alexAddress,
    input logic [127:0] alexWriteData,
    output logic [127:0] alexReadData,
    input logic [1:0] alexMemEnable,
    output logic alexFinishedMemory,
    input logic [7:0] alexWriteBytes,    
    output logic [3:0] alexMemReady,
    input logic alexNewCommand,
    output logic alexFinishedCommand,
    
    output logic        ram_init_error,
    output logic        ram_init_done,
    output logic otherClock
    
    //LEDs
//    output logic[15:0]  LED
    );
    //logic [16:0]  sw_i;
    localparam ADDR_WIDTH = 27;
    localparam APP_DATA_WIDTH = 64;
    localparam APP_MASK_WIDTH = 8;
    
    //internal signals
    logic [ADDR_WIDTH-1:0]                 app_wr_addr, app_rd_addr, app_addr; //shared signals between writing and reading sides
    logic [2:0]                            app_wr_cmd, app_rd_cmd, app_cmd;    //ram_init_done used to arbitrate between in this
    logic                                  app_wr_en, app_rd_en, app_en;       //example. All writes from SDCard happen first.
    (* MARK_DEBUG = "TRUE" *) logic                                  app_rdy;
    logic [APP_DATA_WIDTH-1:0]             app_rd_data;
    logic                                  app_rd_data_end;
    logic                                  app_rd_data_valid;
    logic [APP_DATA_WIDTH-1:0]             app_wdf_data;
    (* MARK_DEBUG = "TRUE" *) logic                                  app_wdf_end;
    logic [APP_MASK_WIDTH-1:0]             app_wdf_mask;
    (* MARK_DEBUG = "TRUE" *) logic                                  app_wdf_rdy;
    logic                                  app_sr_active;
    logic                                  app_ref_ack;
    logic                                  app_zq_ack;
    (* MARK_DEBUG = "TRUE" *) logic                                  app_wdf_wren;
    
    logic                                  ui_clk, ui_sync_rst;

    logic                                  init_calib_complete;
        
    
    logic sys_clk_p, sys_clk_n;
    
 
    mig_7series_0 u_mig_7series_0
    (
       // External memory interface ports
       .ddr3_addr                      (ddr3_addr),
       .ddr3_ba                        (ddr3_ba),
       .ddr3_cas_n                     (ddr3_cas_n),
       .ddr3_ck_n                      (ddr3_ck_n),
       .ddr3_ck_p                      (ddr3_ck_p),
       .ddr3_cke                       (ddr3_cke),
       .ddr3_ras_n                     (ddr3_ras_n),
       .ddr3_we_n                      (ddr3_we_n),
       .ddr3_dq                        (ddr3_dq),
       .ddr3_dqs_n                     (ddr3_dqs_n),
       .ddr3_dqs_p                     (ddr3_dqs_p),
       .ddr3_reset_n                   (ddr3_reset_n),
       .init_calib_complete            (init_calib_complete),
       .ddr3_dm                        (ddr3_dm),
       .ddr3_odt                       (ddr3_odt),

        // Application interface ports
       .app_addr                       (app_addr),
       .app_cmd                        (app_cmd),
       .app_en                         (app_en),
       .app_wdf_data                   (app_wdf_data),
       .app_wdf_end                    (app_wdf_end),
       .app_wdf_wren                   (app_wdf_wren),
       .app_rd_data                    (app_rd_data),
       .app_rd_data_end                (app_rd_data_end),
       .app_rd_data_valid              (app_rd_data_valid),
       .app_rdy                        (app_rdy),
       .app_wdf_rdy                    (app_wdf_rdy),
       .app_sr_req                     (1'b0),
       .app_ref_req                    (1'b0),
       .app_zq_req                     (1'b0),
       .app_sr_active                  (app_sr_active),
       .app_ref_ack                    (app_ref_ack),
       .app_zq_ack                     (app_zq_ack),
       .ui_clk                         (ui_clk),
       .ui_clk_sync_rst                (ui_sync_rst),
       .app_wdf_mask                   (app_wdf_mask),

        // System Clock Ports
       //.sys_clk_p                      (sys_clk_p),
       //.sys_clk_n                      (sys_clk_n),
        .sys_clk_i(clk_ref_i),
        // Reference Clock Ports
       .clk_ref_i                      (clk_ref_i),
       .device_temp                    (),
       .sys_rst                        (sys_rst)
   );
  
   
   logic [63:0] sd_ram_wdf_data;
   logic sd_ram_wdf_wren;
   logic sd_ram_wdf_end;
   
    sdcard_init #(.MAX_RAM_ADDRESS(27'h7FFFFF),//copy 256KBytes to SDRAM
                  .SDHC(1'b1))
    sdcard_init_0(
    .clk(ui_clk),
    .reset(~init_calib_complete),     //starts after calibration has been completed
    .ram_cmd(app_wr_cmd),
    .ram_en(app_wr_en),
    .ram_rdy(app_rdy),
    .ram_address(app_wr_addr),
    .ram_wdf_data(sd_ram_wdf_data),
    .ram_wdf_wren(sd_ram_wdf_wren),     //RAM interface pins
    .ram_wdf_rdy(app_wdf_rdy),       //acknowledge from RAM to move to next word
    .ram_wdf_end(sd_ram_wdf_end),       //toggle every other word
    .ram_init_error(ram_init_error), //error initializing
    .ram_init_done(ram_init_done),   //done with reading all MAX_RAM_ADDRESS words
    .cs_bo (sd_cs), 
    .sclk_o (sd_sclk),
    .mosi_o (sd_mosi),
    .miso_i (sd_miso)
    );
       
   logic [63:0] ram_reader_write_data;
   logic ram_reader_wdf_wren, ram_reader_wdf_end;
   logic [7:0] ram_reader_wdf_mask;
   
   ram_reader ram_reader_0(
       .clk(ui_clk),
	   .reset(~ram_init_done || sys_rst),     //start reading when RAM init is finished
       .ram_address (app_rd_addr),  //the following 4 signals control the command FIFO
       .ram_cmd (app_rd_cmd),       
       .ram_en (app_rd_en),             
       .ram_rdy(app_rdy),
       .ram_rd_valid(app_rd_data_valid),
       .ram_rd_data_end (app_rd_data_end),
       .ram_rd_data(app_rd_data),
       //I added all below this line I think
       .ram_wdf_data(ram_reader_write_data),
       .ram_wdf_wren(ram_reader_wdf_wren),
       .ram_wdf_end(ram_reader_wdf_end),       
       .ram_wdf_mask(ram_reader_wdf_mask), 
       .ram_wdf_rdy(app_wdf_rdy),
       
       .alexAddress(alexAddress),
       .alexWriteData(alexWriteData),
       .alexReadData(alexReadData),
       .alexFinishedAction(alexFinishedMemory),
       .alexMemEnable(alexMemEnable),
       .alexWriteBytes(alexWriteBytes),
       .alexMemReady(alexMemReady),
       .alexNewCommand(alexNewCommand),
       .alexFinishedCommand(alexFinishedCommand)       
       
    );

    assign app_addr = ram_init_done ? app_rd_addr : app_wr_addr; //MUX shared RAM control signals 
    assign app_en   = ram_init_done ? app_rd_en : app_wr_en;     //between write logic and read
    assign app_cmd  = ram_init_done ? app_rd_cmd : app_wr_cmd;   //logic
    assign app_wdf_data = ram_init_done ? ram_reader_write_data : sd_ram_wdf_data;
    assign app_wdf_end = ram_init_done ? ram_reader_wdf_end : sd_ram_wdf_end;
    assign app_wdf_wren = ram_init_done ? ram_reader_wdf_wren : sd_ram_wdf_wren;
    assign app_wdf_mask = ram_init_done ? (~ram_reader_wdf_mask) : 8'h00;

//    assign app_wdf_mask = 8'h00;

    assign otherClock = ui_clk;
//    hex_driver hexA   (.clk(ui_clk), 
//                      .reset(ui_sync_rst),
//                      .in({SW[15:12], SW[11:8], SW[7:4], SW[3:0]}),
//                      .hex_seg(hex_segA),
//                      .hex_grid(hex_gridA));
 
//    hex_driver hexB   (.clk(ui_clk), 
//                      .reset(ui_sync_rst),
//                      .in({read_data_display[15:12], read_data_display[11:8], read_data_display[7:4], read_data_display[3:0]}),
//                      .hex_seg(hex_segB),
//                      .hex_grid(hex_gridB));

endmodule
