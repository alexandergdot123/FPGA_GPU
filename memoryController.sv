
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
    } memControllerState;

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
            oldAlexFinishedMemAction <= alexFinishedMemAction;
            oldAlexCommandAcknowledged <= alexCommandAcknowledged;
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
                
                alexMemEnable <= 2'b01;
                alexNewCommand <= 1;
                if(alexCommandAcknowledged) begin //I think that alexCommandAcknowledged needs to be low at least 50% of the time
                    alexAddress <= {6'b000000, (wrappedRowColIndex[19:2] + readCounter), 3'b000};
                    readCounter <= readCounter + 1;
                end
                
                if(alexFinishedMemAction) begin
                    copyReadData <= alexReadData;
                end
                if(usedToBeIdle) begin
                    writeCounter <= 0;
                    readCounter <= 10'b0000000001;
                    alexAddress <= {6'b000000, (wrappedRowColIndex[19:2]), 3'b000};
                end               
                else if(oldAlexFinishedMemAction) begin
                    writeCounter <= writeCounter + 1;
                end
                
            end
            else if(curState == writeVGA) begin
                alexNewCommand <= 0;
                alexMemEnable <= 2'b01;
                if(alexFinishedMemAction) begin
                    copyReadData <= alexReadData;
                end
                if(oldAlexFinishedMemAction) begin
                    writeCounter <= writeCounter + 1;
                end
            end
            
            else if (curState == sendCore) begin
                if(cacheWriteEnableSave) begin
                    alexMemEnable <= 2'b10;
                    alexWriteBytes <= cacheWriteBytesSave;
                    cacheFinishedAction <= alexCommandAcknowledged;
                end
                else begin
                    alexMemEnable <= 2'b01;
                    cacheFinishedAction <= 0;
                end
                alexNewCommand <= ~alexCommandAcknowledged;
                alexAddress <= cacheAddressSave;
            end
            else if (curState == waitCore) begin
                alexNewCommand <= 0;
                cacheDataRead <= alexReadData;
                cacheFinishedAction <= alexFinishedMemAction;
            end
            else if (curState == receiveCore) begin
                alexNewCommand <= 0;
                cacheFinishedAction <= 1;
            end
            
            if(curState != readVGA && curState != writeVGA && rowColIndexReg[10:2] == 0 && ~vgaLoadWhenReady && drawY < 'd480 && drawX < 'd640) begin
                vgaLoadWhenReady <= 1;
                frozenRowColIndex  <= rowColIndexReg;
            end
            else if (curState == readVGA) begin
                vgaLoadWhenReady <= 0;
            end
            
            if(curState != sendCore && curState != receiveCore && curState != waitCore && cacheEnableGlobal) begin
                cacheMemQueue <= 1;
                cacheAddressSave <= cacheAddress;
                if(~cacheWriteEnableSave) begin
                    cacheWriteEnableSave <= cacheEnableGlobalWrite;
                end
                cacheWriteDataSave <= cacheDataWrite;
                cacheWriteBytesSave <= cacheWriteBytes;
            end
            else if (curState == receiveCore) begin
                cacheMemQueue <= 0;
                cacheWriteEnableSave <= 0;
            end

        end
        pixel <= pixelsOut[{rowColIndexReg[1:0], 5'b00000} +: 32];
    end
    always_comb begin
//        alexWriteData = cacheWriteDataSave;
        alexWriteData = cacheDataWrite;
        aheadAddress = frozenRowColIndex + 'd2048;//this should normally be 2048
        wrappedRowColIndex = (aheadAddress >= 'd307200) ? aheadAddress - 'd307200 : aheadAddress;
//        red = (rowColIndexReg[11:2] == 0) ? 8'hFF : pixel[31:24];
//        green = (rowColIndexReg[10:2] == 0) ? 8'hFF : pixel[23:16];
//        blue = (rowColIndexReg [11:2] == 0) ? 8'hFF : pixel[15:8];
        red = pixel[31:24];
        green = pixel[23:16];
        blue = pixel[15:8];
    end

    genvar i;
    generate
        for(i = 0; i<4; i+=1) begin
            blk_mem_gen_0 u_blk_mem_gen_0 (
                .clka   (clk),       // Clock for port A
                .ena    (oldAlexFinishedMemAction && (curState == readVGA || curState == writeVGA)),      // Enable for port A
                .wea    (1'b1),
                .addra  ({~frozenRowColIndex[11], writeCounter[8:0]}), // Address for port A
                .dina   (copyReadData[i*32 +: 32]),   
//                .douta  (),             // No output needed for write-only port A
            
                .clkb   (clk),       // Clock for port B
                .enb    (1'b1),      // Enable for port B
//                .web    (1'b0),      // Port B is read-only
                .addrb  (rowColIndexReg[11:2]), // Address for port B 
//                .dinb   (32'b0),     // No input needed for read-only port B
                .doutb  (pixelsOut[i*32 +: 32])   // Data output for port B
            );

        
        
        end
    endgenerate

endmodule
