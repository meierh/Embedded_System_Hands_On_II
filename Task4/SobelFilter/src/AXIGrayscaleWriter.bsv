package AXIGrayscaleWriter;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import AXI4_Types :: * ;
import AXI4_Master :: * ;
import MIMO :: *;
import GetPut :: *;
import BRAMFIFO :: * ;
import MIMO :: * ;

typedef enum {
    Request = 2'b00,
    Send = 2'b01
    } AXIBurstPhase deriving (Bits,Eq);

(* always_ready, always_enabled *)
interface AXIGrayscaleWriter#(numeric type addrwidth, numeric type datawidth, numeric type filterwidth, numeric type maxBurstLen);
    method Action configure (Bit#(addrwidth) _outputAddress, Bit#(addrwidth) _numberChunks);
    method Action setWindow(Vector#(filterwidth,Bit#(8)) _window);
    method Bool done();
    interface AXI4_Master_Wr_Fab#(addrwidth,datawidth,1,0) axi4Fab;
endinterface

module mkAXIGrayscaleWriter(AXIGrayscaleWriter#(addrwidth,datawidth,filterwidth,maxBurstLen))
                                            provisos(Add#(a__, 8, addrwidth),
                                                     Add#(b__, TLog#(TAdd#(TDiv#(datawidth, 8), 1)), addrwidth),
                                                     Add#(c__, 8, datawidth),
                                                     Add#(2, d__, maxBurstLen),
                                                     Add#(e__, filterwidth, maxBurstLen),
                                                     Add#(f__, TDiv#(datawidth, 8), maxBurstLen),
                                                     Add#(g__, TMul#(8, TDiv#(datawidth, 8)), TMul#(8, maxBurstLen)),
                                                     Log#(TAdd#(TDiv#(datawidth, 8), 1), TLog#(TAdd#(filterwidth, 1))));

// Configuration registers
    Reg#(Bit#(addrwidth)) outputImageAddress <- mkReg(0);
    /*
    Reg#(Bit#(addrwidth)) resolutionX <- mkReg(0);
    Reg#(Bit#(addrwidth)) resolutionY <- mkReg(0);
    */
    Reg#(Bit#(addrwidth)) chunkNumber <- mkReg(0);
    Reg#(Bool) validConfig <- mkReg(False);
    
// AXI connect
    AXI4_Master_Wr#(addrwidth,datawidth,1,0) axiDataWr <- mkAXI4_Master_Wr(1,1,1,False);
    
    MIMOConfiguration cfg;
    cfg.unguarded = True;
    cfg.bram_based = True;
    MIMO#(filterwidth,TDiv#(datawidth,8),maxBurstLen,Bit#(8)) outputMIMO <- mkMIMO(cfg);
    
    Reg#(Bit#(addrwidth)) chunkCounter <- mkReg(0);
    Reg#(Bit#(addrwidth)) addrOffset <- mkReg(0);
    Reg#(AXIBurstPhase) axiSendPhase <- mkReg(Request);
    Reg#(Bit#(addrwidth)) announedChunks <- mkReg(0);
    Reg#(Bit#(addrwidth)) announedChunksCounter <- mkReg(0);
    
    Bit#(addrwidth) deqCountBit = fromInteger(valueOf(datawidth)/8);
    UInt#(addrwidth) deqCountBitUInt = unpack(deqCountBit);
    LUInt#(TDiv#(datawidth,8)) deqCountBitLUInt = truncate(deqCountBitUInt);
    
    Bit#(addrwidth) enqCountBit = fromInteger(valueOf(filterwidth));
    UInt#(addrwidth) enqCountBitUInt = unpack(deqCountBit);
    LUInt#(TDiv#(datawidth,8)) enqCountBitLUInt = truncate(deqCountBitUInt);
    
    rule announceData (validConfig && axiSendPhase==Request && outputMIMO.deqReadyN(deqCountBitLUInt));
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
            axiSendPhase <= Send;
            chunkCounter <= chunkCounter + _announcedChunks;
            addrOffset <= addrOffset + _announcedChunks * 16;
            announedChunksCounter <= 0;
            end
        else
            validConfig <= False;
    endrule
    
    rule readData (axiSendPhase==Send && outputMIMO.deqReadyN(deqCountBitLUInt));
        if(announedChunksCounter < announedChunks)
            begin
            Vector#(TDiv#(datawidth,8),Bit#(8)) oneChunk = outputMIMO.first;
            /*
            Bit#(addrwidth) deqCountBit = fromInteger(valueOf(datawidth)/8);
            UInt#(addrwidth) deqCountBitUInt = unpack(deqCountBit);
            LUInt#(TDiv#(datawidth,8)) deqCountBitLUInt = truncate(deqCountBitUInt);
            */
            outputMIMO.deq(deqCountBitLUInt);
                    
            Bit#(datawidth) writeData = 0;
            Integer pixelBitStart = valueOf(datawidth)-1;
            Integer enableBitStart = valueOf(datawidth)/8-1;
            Bit#(TDiv#(datawidth, 8)) byte_enable = 0;
            for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
                begin
                writeData[pixelBitStart:pixelBitStart-7] = oneChunk[i];
                pixelBitStart = pixelBitStart - 8;
                end
            axi4_write_data(axiDataWr,writeData,byte_enable,False);
            announedChunksCounter <= announedChunksCounter + 1;
            end
        else
            begin
            announedChunksCounter <= 0;
            axiSendPhase <= Request;
            end
    endrule
       
    method Action configure (Bit#(addrwidth) _outputAddress, Bit#(addrwidth) _numberChunks) if(!validConfig);
        outputImageAddress <= _outputAddress;
        chunkNumber <= _numberChunks;
        validConfig <= True;
    endmethod
    
    method Action setWindow(Vector#(filterwidth,Bit#(8)) _window) if(outputMIMO.enqReadyN(enqCountBitLUInt));    
        outputMIMO.enq(enqCountBitLUInt,_window);
    endmethod
    
    method Bool done();
        return !validConfig && (axiSendPhase==Request);
    endmethod
    
    interface axi4Fab = axiDataWr.fab;
    
endmodule

endpackage
