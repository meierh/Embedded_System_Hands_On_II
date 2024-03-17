package AXIGrayscaleWriter;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import AXI4_Types :: * ;
import AXI4_Master :: * ;
import MIMO :: *;
import GetPut :: *;
import FIFOF :: * ;
import BRAMFIFO :: * ;

typedef enum {
    Request = 2'b00,
    Send = 2'b01,
    Response = 2'b10
    } AXIBurstPhase deriving (Bits,Eq);

(* always_ready, always_enabled *)
interface AXIGrayscaleWriter#(numeric type addrwidth, numeric type datawidth, numeric type filterwidth, numeric type maxBurstLen);
    method Action configure (Bit#(addrwidth) _outputAddress, Bit#(addrwidth) _numberChunks);
    method Action setWindow(Vector#(filterwidth,Bit#(8)) _window);
    method Bool done();
    interface AXI4_Master_Wr_Fab#(addrwidth,datawidth,1,0) axi4Fab;
endinterface

module mkAXIGrayscaleWriter(AXIGrayscaleWriter#(addrwidth,datawidth,filterwidth,maxBurstLen))
                                                    provisos(Add#(a__, 8, datawidth),
                                                             Add#(b__, 8, addrwidth),
                                                             Add#(1, c__, TMul#(TDiv#(datawidth, 8), 8))
                                                            );

// Configuration registers
    Reg#(Bit#(addrwidth)) outputImageAddress <- mkReg(0);
    Reg#(Bit#(addrwidth)) chunkNumber <- mkReg(0);
    Reg#(Bool) validConfig <- mkReg(False);
    
    FIFOF#(Vector#(TDiv#(datawidth,8),Bit#(8))) windowFIFO <- mkSizedBRAMFIFOF(valueOf(maxBurstLen));
           
// AXI connect
    AXI4_Master_Wr#(addrwidth,datawidth,1,0) axiDataWr <- mkAXI4_Master_Wr(1,1,1,False);

    Reg#(Bit#(addrwidth)) chunkCounter <- mkReg(0);
    Reg#(Bit#(addrwidth)) addrOffset <- mkReg(0);
    Reg#(AXIBurstPhase) axiSendPhase <- mkReg(Request);
    Reg#(Bit#(addrwidth)) announedChunks <- mkReg(0);
    Reg#(Bit#(addrwidth)) announedChunksCounter <- mkReg(0);
    
    rule announceData (validConfig && axiSendPhase==Request);
        if(chunkCounter < chunkNumber)
            begin
            Bit#(addrwidth) announceAddr = outputImageAddress + addrOffset;
            Bit#(addrwidth) _remainigChunks = chunkNumber - chunkCounter;
            Bit#(addrwidth) _announcedChunks = fromInteger(valueOf(maxBurstLen));
            if(_remainigChunks < _announcedChunks)
                _announcedChunks = _remainigChunks;
            announedChunks <= _announcedChunks;
            Bit#(addrwidth) _announcedChunks_Min1 = _announcedChunks-1;
            Bit#(8) _announcedChunks_Min1_Trunc = truncate(_announcedChunks_Min1);
            axi4_write_addr(axiDataWr,announceAddr,unpack(_announcedChunks_Min1_Trunc));
            //$display("Announce from %d with %d chunks of %d remaining",announceAddr,_announcedChunks,_remainigChunks);
            axiSendPhase <= Send;
            chunkCounter <= chunkCounter + _announcedChunks;
            addrOffset <= addrOffset + _announcedChunks * 16;
            //announedChunksCounter <= 0;
            end
        else
            begin
            validConfig <= False;
            //$display("Announcation done");
            end
    endrule
    
    rule writeData (axiSendPhase==Send && announedChunksCounter < announedChunks);
        //$display("writeData announedChunksCounter %d, announedChunks %d, axiSendPhase %b",announedChunksCounter,announedChunks,axiSendPhase);

        Vector#(TDiv#(datawidth,8),Bit#(8)) oneChunk = windowFIFO.first;
        windowFIFO.deq;
                
        Bit#(datawidth) writeData = 0;
        Integer pixelBitStart = valueOf(datawidth)-1;
        Integer enableBitStart = valueOf(datawidth)/8-1;
        Bit#(TDiv#(datawidth, 8)) byte_enable = 0;
        byte_enable = byte_enable - 1;
        for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
            begin
            writeData[pixelBitStart:pixelBitStart-7] = oneChunk[i];
            pixelBitStart = pixelBitStart - 8;
            end
        Bool lastBeat = False;
        if(announedChunksCounter==announedChunks-1)
            lastBeat = True;
            
        axi4_write_data(axiDataWr,writeData,byte_enable,lastBeat);
        //$display("Out Chunk %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d ",oneChunk[0],oneChunk[1],oneChunk[2],oneChunk[3],oneChunk[4],oneChunk[5],oneChunk[6],oneChunk[7],oneChunk[8],oneChunk[9],oneChunk[10],oneChunk[11],oneChunk[12],oneChunk[13],oneChunk[14],oneChunk[15]);
        //$display("announedChunksCounter %d, announedChunks %d, axiSendPhase %b byte_enable %d lastBeat %b",announedChunksCounter,announedChunks,axiSendPhase,byte_enable,lastBeat);
        announedChunksCounter <= announedChunksCounter + 1;
    endrule
    
    rule endWriteData (axiSendPhase==Send && announedChunksCounter >= announedChunks);
        //$display("Last Beat");
        announedChunksCounter <= 0;
        axiSendPhase <= Response;
    endrule
    
    rule responseData (axiSendPhase==Response);
        AXI4_Write_Rs#(1,0) resp <- axi4_write_response(axiDataWr);
        axiSendPhase <= Request;
    endrule
       
    method Action configure (Bit#(addrwidth) _outputAddress, Bit#(addrwidth) _numberChunks) if(!validConfig);
        //$display("configure writer");
        outputImageAddress <= _outputAddress;
        chunkNumber <= _numberChunks;
        validConfig <= True;
        chunkCounter <= 0;
        addrOffset <= 0;
        axiSendPhase <= Request;
        announedChunks <= 0;
        announedChunksCounter <= 0;
    endmethod
    
    method Action setWindow(Vector#(filterwidth,Bit#(8)) _window);
        Vector#(TDiv#(datawidth,8),Bit#(8)) _extWindow = newVector;
        for(Integer i=0;i<valueOf(datawidth)/8; i=i+1)
            _extWindow[i] = 0;
        for(Integer i=0;i<valueOf(filterwidth); i=i+1)
            _extWindow[i] = _window[i];
        windowFIFO.enq(_extWindow);
    endmethod
    
    method Bool done();
        return !validConfig && (axiSendPhase==Request);
    endmethod
    
    interface axi4Fab = axiDataWr.fab;
    
endmodule

endpackage
