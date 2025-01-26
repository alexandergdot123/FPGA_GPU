//-------------------------------------------------------------------------
//    mb_usb_hdmi_top.sv                                                 --
//    Zuofu Cheng                                                        --
//    2-29-24                                                            --
//                                                                       --
//                                                                       --
//    Spring 2024 Distribution                                           --
//                                                                       --
//    For use with ECE 385 USB + HDMI                                    --
//    University of Illinois ECE Department                              --
//-------------------------------------------------------------------------

module mb_usb_hdmi_top(
    input logic Clk,
    input logic reset_rtl_0,
    //UART
    input logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,
    
    //USB signals
//    input logic [0:0] gpio_usb_int_tri_i,
//    output logic gpio_usb_rst_tri_o,
//    input logic usb_spi_miso,
//    output logic usb_spi_mosi,
//    output logic usb_spi_sclk,
//    output logic usb_spi_ss,
    
    //HDMI
    output logic hdmi_tmds_clk_n,
    output logic hdmi_tmds_clk_p,
    output logic [2:0]hdmi_tmds_data_n,
    output logic [2:0]hdmi_tmds_data_p,
    
//    //ddr3
    input logic sys_clk_n, //I have this commented out because it is commented out on the xdc file.
    input logic sys_clk_p, //^^^same here
    output logic [12:0] ddr3_addr,
    output logic [2:0] ddr3_ba,
    output logic ddr3_cas_n,
    output logic ddr3_ck_n,
    output logic ddr3_ck_p,
    output logic ddr3_cke,
    output logic [1:0] ddr3_dm,
    inout wire [15:0] ddr3_dq,
    inout wire [1:0] ddr3_dqs_n,
    inout wire [1:0] ddr3_dqs_p,
    output logic ddr3_odt,
    output logic ddr3_ras_n,
    output logic ddr3_reset_n,
    output logic ddr3_we_n,
    output logic ram_init_error,
    output logic ram_init_done,
//    input logic clk_ref_i, //I have this commented out because I am going to use the common clock instead.
//    input logic sys_rst, //I have this commented out because I am going to use the common microBlaze reset instead.
    
//    //sd card
    output logic sd_sclk,
    output logic sd_mosi,
    output logic sd_cs,
    input logic sd_miso,
    
    output logic[15:0]  LED
);

    logic [7:0] red, green, blue;
    logic [9:0] drawX, drawY;
    logic twoHundred;
//    debugStuff debugStuffInst(
//        .clk(Clk),
//        .red(red),
//        .green(green),
//        .blue(blue),
//        .drawX(drawX),
//        .drawY(drawY),
//        .twoMHz(twoHundred),
//        .reset(reset_rtl_0)
//    );
    
    (* MARK_DEBUG = "TRUE" *) logic ram_init_done_debug;
    assign ram_init_done_debug = ram_init_done_debug;
    logic [26:0] alexAddress;
    logic [127:0] alexReadData, alexWriteData;
    logic [7:0] alexWriteBytes;
    logic [1:0] alexMemEnable;
    logic alexFinishedAction, alexFinishedCommand, alexNewCommand;
    (* MARK_DEBUG = "TRUE" *) logic [3:0] alexMemReady;
    
//    (* MARK_DEBUG = "TRUE" *) logic [26:0] cacheAddress;
//    (* MARK_DEBUG = "TRUE" *) logic [127:0] cacheReadData, cacheWriteData;
//    (* MARK_DEBUG = "TRUE" *) logic [7:0] cacheWriteBytes;
//    (* MARK_DEBUG = "TRUE" *) logic cacheMemEnable, cacheMemWriteEnable, cacheFinishedAction;
//    (* MARK_DEBUG = "TRUE" *) logic oldCache, oldAlexFinishedCommand;
    
//     logic [3:0] alexMemReady;
    
     logic [26:0] cacheAddress;
     logic [127:0] cacheReadData, cacheWriteData;
     (* MARK_DEBUG = "TRUE" *) logic [7:0] cacheWriteBytes;
     logic cacheMemEnable, cacheMemWriteEnable, cacheFinishedAction;
     logic oldCache, oldAlexFinishedCommand;
    
    (* MARK_DEBUG = "TRUE" *) logic cacheMemEnableDebug, cacheMemWriteEnableDebug;
    assign cacheMemWriteEnableDebug = cacheMemWriteEnable;
    assign cacheMemEnableDebug = cacheMemEnable;
//    always_ff @(posedge twoHundred) begin
//        if(reset_rtl_0) begin
//            LED <= 0;
//            oldCache <= 0;
//            oldAlexFinishedCommand <= 0;
//        end
//        else begin
//            oldCache <= cacheMemEnable;
//            oldAlexFinishedCommand <= alexFinishedAction;      
//            if(~oldCache && cacheMemEnable) begin
//                LED <= cacheAddress[18:3];
//            end  
//        end
//    end

    
    mb_block mb_block_i (
        .clk_100MHz(Clk),
//        .reset_rtl_0(~(reset_rtl_0 || ~ram_init_done)), //Block designs expect active low reset, all other modules are active high
        .reset_rtl_0(~(reset_rtl_0)), //Block designs expect active low reset, all other modules are active high
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .drawX_0(drawX),
        .drawY_0(drawY),
        .alexFinishedAction_0(cacheFinishedAction),
//        .alexReadData_0(128'h00000000000000000000000000000000),
        .alexReadData_0(cacheReadData),
        .alexAddress_0(cacheAddress),
        .alexWriteData_0(cacheWriteData),
        .alexMemEnable_0(cacheMemEnable),
        .alexMemWriteEnable_0(cacheMemWriteEnable),
        .alexWriteBytes_0(cacheWriteBytes)
    );
//    always_comb begin
//        cacheAddress = 0;
//        cacheWriteData = 0;
//        cacheMemEnable = 0;
//        cacheMemWriteEnable = 0;
//        cacheWriteBytes = 0;
//    end


    rtl_ddr3_top rtl_ddr3_top_Inst(
        .ddr3_addr(ddr3_addr),
        .ddr3_ba(ddr3_ba),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_cke(ddr3_cke),
        .ddr3_dm(ddr3_dm),
        .ddr3_dq(ddr3_dq),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_odt(ddr3_odt),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_we_n(ddr3_we_n),
            
        .ram_init_error(ram_init_error),
        .ram_init_done(ram_init_done),
        
        .clk_ref_i(Clk), //IM GOING TO USE FASTCLOCK ON THIS WHICH SHOULD BE 200MHZ
        .sys_rst(reset_rtl_0), //I think it expects a high reset input. Not totally sure though.
        
        
        .sd_sclk(sd_sclk),
        .sd_mosi(sd_mosi),
        .sd_cs(sd_cs),
        .sd_miso(sd_miso),
        
        .alexAddress(alexAddress),
        .alexWriteData(alexWriteData),
        .alexReadData(alexReadData),
        .alexMemEnable(alexMemEnable),
        .alexFinishedMemory(alexFinishedAction),
        .alexWriteBytes(cacheWriteBytes),
        .alexMemReady(alexMemReady),
        .alexFinishedCommand(alexFinishedCommand),
        .alexNewCommand(alexNewCommand),
        .otherClock(twoHundred)

    );
        
    videoController videoControllerInst(
        .clk(Clk),
        .reset(reset_rtl_0),
        .red(red),
        .green(green),
        .blue(blue),
//        .red(4'h0),
//        .green(4'h0),
//        .blue(4'h0),
        .hdmi_clk_n(hdmi_tmds_clk_n),
        .hdmi_clk_p(hdmi_tmds_clk_p),
        .hdmi_tx_n(hdmi_tmds_data_n),
        .hdmi_tx_p(hdmi_tmds_data_p),
        .drawX(drawX),
        .drawY(drawY)
    );    
    
    
    memoryController memoryControllerInst(
        .clk(twoHundred),
        .reset(reset_rtl_0),
        
//        .cacheDataWrite(128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .cacheDataWrite(cacheWriteData),

        .cacheAddress(cacheAddress),
        .cacheDataRead(cacheReadData),
        .cacheEnableGlobal(cacheMemEnable),
        .cacheEnableGlobalWrite(cacheMemWriteEnable),
        .cacheWriteBytes(cacheWriteBytes),
        .cacheFinishedAction(cacheFinishedAction),
        //from the cachce
        //from the vga controller
        .drawX(drawX),
        .drawY(drawY),
        // input logic chooseBuffer,
    
        //obvious
        
        
        
        .red(red),
        .green(green),
        .blue(blue),



        //talks to the ddr3
        .alexAddress(alexAddress),
        .alexReadData(alexReadData),
        .alexWriteData(alexWriteData),
        .alexMemEnable(alexMemEnable),
        .alexWriteBytes(alexWriteBytes),
        .alexFinishedMemAction(alexFinishedAction),
        .alexCommandAcknowledged(alexFinishedCommand),
        .alexNewCommand(alexNewCommand)
    );   
    
endmodule
