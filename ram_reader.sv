`timescale 1ns / 1ps
// Updated ram_reader module for both reads and writes to DDR3 memory.

module ram_reader(
    input  logic clk,
    input  logic reset,               // starts as soon as reset is deasserted
    output logic [26:0] ram_address,  // the following 4 signals control the command FIFO
    output logic [2:0] ram_cmd,       
    output logic ram_en,             
    input  logic ram_rdy,
    input  logic ram_rd_valid,
    input  logic ram_rd_data_end,
    input  logic [63:0] ram_rd_data,
    output logic [63:0] ram_wdf_data, // Write data FIFO input
    output logic ram_wdf_wren,        // Write data FIFO write enable
    output logic ram_wdf_end,         // Indicates the last word in a burst
    output logic [7:0] ram_wdf_mask,  // Mask for write data (not used in this example)
    input  logic ram_wdf_rdy,
    
    // Alex's interface for memory operations
    input  logic [26:0] alexAddress,
    input  logic [127:0] alexWriteData,
    output logic [127:0] alexReadData,
    output logic alexFinishedAction,
    input  logic [1:0] alexMemEnable,
    input  logic [7:0] alexWriteBytes,
    output logic [3:0] alexMemReady,
    input  logic alexNewCommand,
    output logic alexFinishedCommand
    
    
);

    logic [2:0] writeState;
    logic [1:0] readState;
    logic [6:0] counter;
    (*MARK_DEBUG = "TRUE"*) logic ram_wdf_rdy_debug;
    (*MARK_DEBUG = "TRUE"*) logic [7:0] checkWriteBytes;
    assign checkWriteBytes = ram_wdf_mask;
    assign ram_wdf_rdy_debug = ram_wdf_rdy;
    logic [63:0] ram_rd_data_copy;
    assign ram_rd_data_copy = ram_rd_data;
    logic [127:0] data_burst; // Temporary storage for read data
    assign alexReadData = data_burst; // Provide the full read burst data to Alex's interface
//    assign ram_wdf_mask[1:0] = alexWriteBytes[7:6]; // No write masking (all bytes valid)
//    assign ram_wdf_mask[3:2] = alexWriteBytes[5:4]; // No write masking (all bytes valid)
//    assign ram_wdf_mask[5:4] = alexWriteBytes[3:2]; // No write masking (all bytes valid)
//    assign ram_wdf_mask[7:6] = alexWriteBytes[1:0]; // No write masking (all bytes valid)
//    assign ram_wdf_mask = alexWriteBytes;
    logic ram_rdy_old, ram_rd_valid_old, ram_rd_data_end_old;
    

    always_ff @(posedge clk) begin
        ram_rdy_old <= ram_rdy;
        ram_rd_valid_old <= ram_rd_valid;
        ram_rd_data_end_old <= ram_rd_data_end;
    
    
        if (reset) begin
            ram_cmd <= 3'b000;
//            ram_en <= 1'b0;
            data_burst <= 'h0;
            alexFinishedAction <= 0;
            writeState <= 3'b000;
            ram_wdf_data <= 0;
//            ram_wdf_wren <= 0;
//            ram_wdf_end <= 0;
            counter <= 0;
        end 
        else begin
            if(alexMemEnable == 2'b01 && ~alexFinishedAction) begin
                counter <= counter + 1;
            end
            else begin
                counter <= 0;
            end
        
        
            case(writeState)
                3'b000: writeState <= (alexNewCommand && alexMemEnable == 2'b10 && ram_rdy) ? 3'b001: 3'b000;
                3'b001: writeState <= (ram_rdy) ? 3'b010 : 3'b001;
                3'b010: writeState <= (ram_wdf_rdy) ? 3'b011 : 3'b010;
                3'b011: writeState <= (ram_wdf_rdy) ? 3'b100 : 3'b011;
                3'b100: writeState <= 3'b000;
            endcase       
            case(readState)
                2'b00: readState <= (alexNewCommand && alexMemEnable == 2'b01 && ram_rdy) ? 2'b01 : 2'b00;
                2'b01: readState <= (ram_rdy && ram_rdy_old) ? 2'b10 : 2'b01;
                2'b10: readState <= 2'b11;
                2'b11: readState <= 2'b00;
            endcase
            // Handle reads
            if(alexMemEnable == 2'b00) begin
//                ram_en <= 1'b0;
                alexFinishedCommand <= 0;
                alexFinishedAction <= 0;
                readState <= 2'b00;
                writeState <= 3'b000;
            end
            else if (alexMemEnable == 2'b01) begin //This signifies a read
                if(ram_rdy && alexNewCommand && readState == 2'b00) begin
//                    ram_en <= 1;
                    ram_cmd <= 3'b001;
                    ram_address <= {alexAddress[26:3], 3'b000};
                    alexFinishedCommand <= 1;
                end
                else begin
//                    ram_en <= 0;
                    alexFinishedCommand <= 0;
                end               
                
                if((ram_rd_valid_old && ram_rd_data_end && ~ram_rd_data_end_old && ~alexFinishedAction) || (&counter)) begin
                    data_burst[63:0] <= ram_rd_data;
                    alexFinishedAction <= 1;
                end
                else if(ram_rd_valid) begin
                    data_burst[127:64] <= ram_rd_data;     
                    alexFinishedAction <= 0;          
                end
                else begin
                    alexFinishedAction <= 0;
                end
            end
            else if (alexMemEnable == 2'b10) begin //This is going to be writes.
                if(writeState == 3'b000 && alexNewCommand && ram_rdy) begin
//                    ram_en <= 1;
                    ram_cmd <= 3'b000;
                    ram_address <= {alexAddress[26:3], 3'b000};
//                    ram_wdf_end <= 0;
//                    ram_wdf_wren <= 0;
                    alexFinishedCommand <= 0;
                    alexFinishedAction <= 0;
                end
                else if (writeState == 3'b001) begin
//                    ram_en <= 0;
//                    ram_wdf_wren <= 1;
                    ram_wdf_data <= alexWriteData[127:64];
//                    ram_wdf_end <= 0;
                end
                else if (writeState == 3'b010 && ram_wdf_rdy) begin
//                    ram_en <= 0;
//                    ram_wdf_wren <= 1;
//                    ram_wdf_end <= 1;
                    ram_wdf_data <= alexWriteData[63:0];
                    alexFinishedAction <= 0;
                    alexFinishedCommand <= 0;
                end
                else if (writeState == 3'b011) begin
////                    ram_en <= 0;
//                    ram_wdf_wren <= 0;
//                    ram_wdf_end <= 0;
                    alexFinishedAction <= 1;
                    alexFinishedCommand <= 1;                
                end
                else if (writeState == 3'b100) begin
//                    ram_wdf_wren <= 0;
//                    ram_wdf_end <= 0;
                    alexFinishedAction <= 0;
                    alexFinishedCommand <= 0;        
                end
            end
        end
    end
    always_comb begin    
        ram_wdf_mask = ( writeState == 3'b011) ? {{4{alexWriteBytes[3]}}, {4{alexWriteBytes[1]}}} : {{4{alexWriteBytes[7]}}, {4{alexWriteBytes[5]}}};
        ram_en = (readState == 2'b01 && ram_rdy && ram_rdy_old) || (writeState == 3'b001);
        ram_wdf_end = writeState == 3'b011;
        ram_wdf_wren = writeState == 3'b010 || writeState == 3'b011;
        alexMemReady[0] = ram_rdy;
        alexMemReady[1] = ram_wdf_wren;
        alexMemReady[2] = ram_wdf_end;
        alexMemReady[3] = ram_en;
    end
endmodule
