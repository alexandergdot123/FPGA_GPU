
//Im just gonna make this module run at 200Mhz. It will be easier.

module memoryController(
    input logic clk,
    input logic reset,

    //from the cache
     input logic [127:0] cacheDataWrite,
     input logic [26:0] cacheAddress,
     output logic [127:0] cacheDataRead,
     input logic cacheEnableGlobal,
     input logic cacheEnableGlobalWrite,
     input logic [7:0] cacheWriteBytes,
    output logic cacheFinishedAction,

    //from the vga controller
    input logic [9:0] drawX,
    input logic [9:0] drawY,
    // input logic chooseBuffer,

    //obvious
    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue,

    //talks to the ddr3
    output logic [26:0] alexAddress,
    input logic [127:0] alexReadData,
    output logic [127:0] alexWriteData,
    output logic [1:0] alexMemEnable,
    output logic [7:0] alexWriteBytes,
    input logic alexFinishedMemAction,
    input logic alexCommandAcknowledged,
    output logic alexNewCommand
);
    logic [9:0] writeCounter;
    logic [9:0] readCounter;
    logic [19:0] rowColIndexWire, rowColIndexReg, aheadAddress, frozenRowColIndex, wrappedRowColIndex;    
    logic [127:0] pixelsOut, cacheWriteDataSave;
    logic [127:0] copyReadData;
    logic [31:0] pixel;    
    logic [26:0] cacheAddressSave;
    
    logic vgaLoadWhenReady, cacheMemQueue;
    (* MARK_DEBUG = "TRUE" *) logic cacheWriteEnableSave, cacheWriteEnableSaveDebug;
    assign cacheWriteEnableSaveDebug = cacheWriteEnableSave;
    logic usedToBeIdle;
    
    logic [7:0] cacheWriteBytesSave;
    logic oldAlexFinishedMemAction, oldAlexCommandAcknowledged;
    assign rowColIndexWire = drawX + drawY * 640;
    typedef enum {
        Idle,
        readVGA,
        writeVGA,
        
        sendCore,
        waitCore,
        receiveCore
    } memControllerState; //These are the different values that the state of the controller can take on

    memControllerState curState;
    always_ff @(posedge clk) begin
        if(reset) begin
            cacheAddressSave <= 0;
            cacheWriteEnableSave <= 0;
            cacheMemQueue <= 0;
            cacheWriteDataSave <= 0;
            cacheWriteBytesSave <= 0;
            
            rowColIndexReg <= 0;
            alexMemEnable <= 2'b00;
            alexWriteBytes <= 0;
            curState <= Idle;
            readCounter <= 0;
            writeCounter <= 0;
            frozenRowColIndex <= 0;
            copyReadData <= 0;
            vgaLoadWhenReady <= 0;
            cacheFinishedAction <= 0;
            oldAlexFinishedMemAction <= 0;
            alexAddress <= 0;
            usedToBeIdle <= 0;
            oldAlexCommandAcknowledged <= 0;
            
        end
        else begin
            oldAlexFinishedMemAction <= alexFinishedMemAction; //tracks the previous value of alexFinishedMemAction
            oldAlexCommandAcknowledged <= alexCommandAcknowledged; //tracks the previous value of alexCommandAcknowledged
            rowColIndexReg <= rowColIndexWire;
            usedToBeIdle <= curState == Idle;
            case(curState)
                Idle: curState <= (vgaLoadWhenReady) ? readVGA : ((cacheMemQueue) ? sendCore : Idle);
                readVGA: curState <= (readCounter == 10'b1000000001) ? writeVGA : readVGA;
                writeVGA: curState <= (writeCounter == 10'b1000000000) ? Idle : writeVGA;
                
                sendCore: curState <= (cacheWriteEnableSave) ? ((alexCommandAcknowledged) ? receiveCore : sendCore) : ((alexCommandAcknowledged) ? waitCore : sendCore);
                waitCore: curState <= (alexFinishedMemAction) ? receiveCore : waitCore;
                receiveCore: curState <= Idle;
            
            endcase
            
            if(curState == Idle) begin
                alexMemEnable <= 2'b00;
                readCounter <= 0;
                alexNewCommand <= 0;
                writeCounter <= 0;
                cacheFinishedAction <= 0;
            end
            else if(curState == readVGA) begin
                
                alexMemEnable <= 2'b01; //signifies to ram_reader a read is occurring
                alexNewCommand <= 1; //hold high that there is always a new command
                if(alexCommandAcknowledged) begin
                    alexAddress <= {6'b000000, (wrappedRowColIndex[19:2] + readCounter), 3'b000}; //increment the row-column index by the read counter
                    readCounter <= readCounter + 1; //increment the readCounter each time a new command is acknowledged/received
                end
                
                if(alexFinishedMemAction) begin
                    copyReadData <= alexReadData; //whenever a new read is completed, copy over the data to a register
                end
                if(usedToBeIdle) begin //The first time the state is in readVGA
                    writeCounter <= 0; //reset the writeCounter
                    readCounter <= 10'b0000000001; //set the readCounter
                    alexAddress <= {6'b000000, (wrappedRowColIndex[19:2]), 3'b000}; //put the previous wrappedRowColIndex into the address
                end               
                else if(oldAlexFinishedMemAction) begin
                    writeCounter <= writeCounter + 1; //increment the writeCounter every time a read has been finished
                end
                
            end
            else if(curState == writeVGA) begin //once all of the reads have been sent, the last reads need to be received
                alexNewCommand <= 0; //no more commands being sent
                alexMemEnable <= 2'b01; //continue reading
                if(alexFinishedMemAction) begin
                    copyReadData <= alexReadData; //copy the data if there is new data being received
                end
                if(oldAlexFinishedMemAction) begin
                    writeCounter <= writeCounter + 1; //increment the writeCounter every time a read is completed
                end
            end
            
            else if (curState == sendCore) begin //when the state is sending the commands from the cores
                if(cacheWriteEnableSave) begin //if it is a write
                    alexMemEnable <= 2'b10;  //signal writes
                    alexWriteBytes <= cacheWriteBytesSave; //send the 32-bit write enable
                    cacheFinishedAction <= alexCommandAcknowledged; //when the write is received, tell the cores
                end
                else begin
                    alexMemEnable <= 2'b01; //signal reads
                    cacheFinishedAction <= 0; //wait until the DDR3 has the data to receive any data
                end
                alexNewCommand <= ~alexCommandAcknowledged; //turn off alexNewCommand when the command is acknowledged
                alexAddress <= cacheAddressSave; //send the address
            end
            else if (curState == waitCore) begin
                alexNewCommand <= 0;
                cacheDataRead <= alexReadData; //load the data read
                cacheFinishedAction <= alexFinishedMemAction; //when the read is received, tell the cores
            end
            else if (curState == receiveCore) begin //once the data has been received
                alexNewCommand <= 0; //turn off that there is anew command
                cacheFinishedAction <= 1; //because we are working with half the clock period of the cores, hold cacheFinishedAction high for 2 cycles
            end
            
            if(curState != readVGA && curState != writeVGA && rowColIndexReg[10:2] == 0 && ~vgaLoadWhenReady && drawY < 'd480 && drawX < 'd640) begin
                vgaLoadWhenReady <= 1; //On the 2048th iteration of the VGA, signal that it is ready to fetch new pixels from DDR3
                frozenRowColIndex <= rowColIndexReg; //save the address at which to get new pixels from (plus 2048)
            end
            else if (curState == readVGA) begin
                vgaLoadWhenReady <= 0; //reset the vgaLoadWhenReady whenever the reading from the DDR3 actually begins
            end
            
            if(curState != sendCore && curState != receiveCore && curState != waitCore && cacheEnableGlobal) begin
                cacheMemQueue <= 1; //Whenever the cores have a new command and a core command is not being administered to, save the data
                cacheAddressSave <= cacheAddress; // save the address
                if(~cacheWriteEnableSave) begin //Sometimes the writeEnableSave is overwritten due to the dual clocks, so Only measure the first one
                    cacheWriteEnableSave <= cacheEnableGlobalWrite;
                end
                cacheWriteDataSave <= cacheDataWrite; //save the write data
                cacheWriteBytesSave <= cacheWriteBytes;
            end
            else if (curState == receiveCore) begin //If a request has been finished being administered to, clear the data
                cacheMemQueue <= 0;
                cacheWriteEnableSave <= 0;
            end

        end
        pixel <= pixelsOut[{rowColIndexReg[1:0], 5'b00000} +: 32]; //use a register to hold the data of a pixel
    end
    always_comb begin
        alexWriteData = cacheDataWrite; // the data actually doesn't change from the cache (held in register), so doesn't matter
        aheadAddress = frozenRowColIndex + 'd2048; //this is the address with which to use a double buffer to get pixels in advance of need
        wrappedRowColIndex = (aheadAddress >= 'd307200) ? aheadAddress - 'd307200 : aheadAddress; //wrap around the end of the frame buffer
        red = pixel[31:24];
        green = pixel[23:16];
        blue = pixel[15:8];
    end

    genvar i;
    generate
        for(i = 0; i<4; i+=1) begin
            blk_mem_gen_0 u_blk_mem_gen_0 (
                .clka   (clk),       // Clock for port A
                .ena    (oldAlexFinishedMemAction && (curState == readVGA || curState == writeVGA)), //whenever a read has been completed for a pixel
                .wea    (1'b1),
                .addra  ({~frozenRowColIndex[11], writeCounter[8:0]}), // Address for port A
                .dina   (copyReadData[i*32 +: 32]),   
//                .douta  (),             // No output needed for write-only port A
            
                .clkb   (clk),       // Clock for port B
                .enb    (1'b1),      // Enable for port B
//                .web    (1'b0),      // Port B is read-only
                .addrb  (rowColIndexReg[11:2]), // Simply read the current pixel address
//                .dinb   (32'b0),     // No input needed for read-only port B
                .doutb  (pixelsOut[i*32 +: 32])   // Data output for port B
            );

        
        
        end
    endgenerate

endmodule
