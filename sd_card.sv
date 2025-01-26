//Zuofu Cheng (2024) for ECE 385, wrapper for VHDL XESS SDCard driver
//
//State machine to load (RAW) SD Card blocks into memory
//memory is assumed to be 64Mx16 (for now)
//loads up to MAX_RAM_ADDRESS parameter from SD card
//This design assumes 64-bit data into the DDR3 MIG (e.g. 2:1 clock with 16 bit chip)
//
//Note that your SD Card must be written with RAW binary data (e.g. no filesystem)
//On *nix you can use the dd (direct disk) command to write a binary file directly
//to the SD block device; on Windows, you can try using: http://www.chrysocome.net/dd
//Note that dd is a *dangerous program*, you can easily overwrite your boot 
//disk and brick your computer. Triple check your output device is the SD Card (and not your boot drive!)
//
//By default tested using 16GB micro SDHC cards, should work with 'old' SD, but you will
//need to change both the parameter in this module, and the default generic in the VHDL 
//code (SDCard.VHD)


module sdcard_init (
	input  logic clk,
	input  logic reset,               //starts as soon reset is deasserted
	output logic [26:0] ram_address,  //the following 4 signals control the command FIFO
    output logic [2:0] ram_cmd,       //since the job of this module is only to do writes, 
    output logic ram_en,              //every command should be followed by a data
    input  logic ram_rdy,
    output logic [63:0] ram_wdf_data, //the following 4 signals control the RAM write data FIFO
    output logic ram_wdf_wren,        //write into write data FIFO
	input  logic ram_wdf_rdy,         //acknowledge from write data FIFO
	output logic ram_wdf_end,         //toggle every other word (1/2 clock mode)
	output logic ram_init_error, //error initializing
	output logic ram_init_done,  //done with reading all MAX_RAM_ADDRESS words
	output logic cs_bo, //SD card pins (also make sure to disable USB CS if using DE10-Lite)
	output logic sclk_o,
	output logic mosi_o,
	input  logic miso_i  
);

parameter 			MAX_RAM_ADDRESS = 27'b011_1111_1111_1111_1111_1111_1111;
parameter			SDHC 				 = 1'b1;

logic 				sd_read_block;
logic				sd_busy;
logic				sd_data_rdy;
logic				sd_data_next;
logic				sd_continue;
logic	[15:0]		sd_error;
logic   [7:0] 		sd_output_data;
logic   [31:0] 		sd_block_addr;

//registers written in 2-always method
enum logic [8:0]	{RESET, READBLOCK, READ, READ_ACK, WRITE_ADDR, WRITE_DATA_0, WRITE_DATA_1, ERROR, DONE} state_r, state_x;
logic [24:0]		ram_addr_r, ram_addr_x;  //word address for memory initialization
logic [127:0]		data_r, data_x;
logic [3:0]         byte_counter_r, byte_counter_x;

//assign primary outputs to correct registers
assign ram_address = ram_addr_r;

SdCardCtrl m_sdcard ( .clk_i(clk),
							 .reset_i(reset),
							 .rd_i(sd_read_block),
							 .wr_i(1'b0), //never write
							 .continue_i(sd_continue), //FSM keeps track of address
							 .addr_i(sd_block_addr),
							 .data_i(), //never write
							 .data_o(sd_output_data),
							 .busy_o(sd_busy),
							 .hndShk_o(sd_data_rdy),
							 .hndShk_i(sd_data_next),		
							 .error_o(sd_error),
							 .cs_bo(cs_bo),
							 .sclk_o(sclk_o),
							 .mosi_o(mosi_o),
							 .miso_i(miso_i));
							 

always_ff @ (posedge clk) 
begin
	if (reset) begin
		state_r <= RESET;
		ram_addr_r <= 'h0;
		data_r <= 'h0;
		byte_counter_r <= 'h0;
	end
	else begin
		state_r <= state_x;
		data_r <= data_x;
		ram_addr_r <= ram_addr_x;
		byte_counter_r <= byte_counter_x;
	end
end


always_comb 
begin
	//default combinational assignments
	sd_read_block = 1'b0;
	sd_continue = 1'b0;
	sd_data_next = 1'b0;
	ram_init_error = 1'b0;
	ram_init_done = 1'b0;
	
	ram_en = 1'b0;
    ram_wdf_wren = 1'b0;        //write into write data FIFO
    ram_wdf_end = 1'b0;
    ram_wdf_data = 'h0;
	ram_cmd = 3'b001;
	
	if (SDHC)//if SDHC mode, then this is block address (note that you need to change VHDL generic)
		sd_block_addr = ram_addr_r >> 8;
	else
		sd_block_addr = ram_addr_r << 1; //in SD mode, this is the *byte* address, change for SDHC 
	state_x = state_r;
	data_x = data_r;
	ram_addr_x = ram_addr_r;
	byte_counter_x = byte_counter_r;

	unique case (state_r)
		RESET: begin //reset state, wait for SD initialization - if failed for any reason, go into ERROR state
			if ((sd_busy == 1'b0) && (sd_error == 16'h0000))
				state_x = READBLOCK;//properly initialized
			else if ((sd_busy == 1'b0) && (sd_error != 16'h0000))
				state_x = ERROR;
		end
		READBLOCK: begin //send enable to start block read
			if (ram_addr_r >= MAX_RAM_ADDRESS) //done with the whole range
				state_x = DONE;
			else begin
				sd_read_block = 1'b1; //start block read
				if (sd_block_addr != 32'h00000000)
					sd_continue = 1'b1;
				if (sd_busy == 1'b1)
					state_x = READ;
			end
		end
		READ: begin //read each byte
			if (sd_busy == 1'b0) //busy going low signals end of block, read next block
				state_x = READBLOCK;
			else if (sd_data_rdy == 1'b1) begin//still have more data in this block, read more bytes
				data_x[byte_counter_r*8 +: 8] = sd_output_data;
				state_x = READ_ACK;
			end
		end
		READ_ACK: begin //ack each byte
			sd_data_next = 1'b1;
			if (sd_data_rdy == 1'b0) begin
			 if (byte_counter_r == 'hF) begin //done with the word
				state_x = WRITE_ADDR;
                byte_counter_x <= 'h0;
             end
             else begin //move onto next byte 
				state_x = READ;
				byte_counter_x <= byte_counter_r +1 ;
             end
           end    
         end
		WRITE_ADDR: begin //first issue write command to command FIFO, make sure it's acknowledged
			ram_en = 1'b1;
			ram_cmd = 3'b000;
			if (ram_rdy == 1'b1) begin //RAM accepted command
				ram_addr_x = ram_addr_r + 8;
				state_x = WRITE_DATA_0;
			end
		end
        WRITE_DATA_0: begin //issue data, notice that we have to break this into 2 transactions due to 2:1 clock ratio
			ram_wdf_wren = 1'b1;
            ram_wdf_end = 1'b0;  //shouldn't need to do this, but just in case
            ram_wdf_data = data_r[127:64];
			if (ram_wdf_rdy == 1'b1) begin //RAM accepted data
				state_x = WRITE_DATA_1;
			end
		end
		WRITE_DATA_1: begin //issue data, notice that we have to break this into 2 transactions due to 2:1 clock ratio
			ram_wdf_wren = 1'b1;
            ram_wdf_end = 1'b1;  //indicates this is the end of a burst (128 bytes for x16 DDR3)
            ram_wdf_data = data_r[63:0];
			if (ram_wdf_rdy == 1'b1) begin //RAM accepted data
				state_x = READ;
			end
		end
		ERROR: begin
			ram_init_error = 1'b1;
		end
		DONE: begin
			ram_init_done = 1'b1;
		end
	endcase 
end //end comb
	
endmodule
