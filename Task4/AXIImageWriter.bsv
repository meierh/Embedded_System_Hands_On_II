package AXIImageReader;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import AXI4_Types :: * ;
import AXI4_Master :: * ;
import SobelTypes :: * ;
import MIMO :: *;

Integer fifoDepth = 50;

typedef 2000 MAXROWBUFFERLEN;

typedef enum {
    Request = 1'b0,
    Read = 1'b1
    } Loadphase deriving (Bits,Eq);

(* always_ready, always_enabled *)
interface AXIImageReader#(numeric type addrwidth, numeric type windowsize, numeric type shiftsize);
// Add custom interface definitions
    method Action configure (Bit#(addrwidth) _outputAddress, Bit#(addrwidth) _resolutionX, Bit#(addrwidth) _resolutionY)
    method ActionValue#(Vector#(windowsize,Vector#(windowsize,UInt#(8)))) getPaddedWindow ();
    interface AXI4_Master_Rd_Fab#(addrwidth,128,1,1) axi4Fab;
endinterface

module mkAXIImageReader#(Integer imageWidth)(AXIImageReader#(numeric type addrwidth, numeric type windowsize, numeric type shiftsize));

    Reg#(Bit#(addrwidth)) outputImageAddress <- mkReg(0);
    Reg#(Bit#(addrwidth)) resolutionX <- mkReg(0);
    Reg#(Bit#(addrwidth)) resolutionY <- mkReg(0);
    Reg#(Bit#(addrwidth)) imageSize <- mkReg(0);
    Reg#(Bool) validConfig <- mkReg(0);
    
    Reg#(Bit#(addrwidth)) x <- mkReg(0);
    Reg#(Bit#(addrwidth)) y <- mkReg(0);
    Reg#(Bit#(addrwidth)) local_addr <- mkReg(0);
    AXI4_Master_Wr#(addrwidth,128,1,1) axiDataWr <- mkAXI4_Master_Wr(1,1,1,False);
    
// Load data from AXI slave
    /*
    Reg#(Bit#(9)) requestedBeats <- mkReg(0);
    Reg#(Bit#(9)) countBeats <- mkReg(0);
    Reg#(Bit#(addrwidth)) pixelBeatOverhang <- mkRegU();
    
    Reg#(Bit#(13)) writeIndex <- mkReg(0);
    Reg#(Bool) doneFillingriting <- mkReg(True);
    Reg#(Bit#(13)) readIndex <- mkReg(0);
    */
    
    
    Reg#(Loadphase) writePhase <- mkReg(Request);
    Vector(256*16,Reg#(Bit#(8))) burstStorage <- newVector;
    Reg#(Bool) burstStorageFilled <- mkReg(False);
    Reg#(Bit#(9)) writeInd <- mkReg(0);
    Reg#(Bit#(9)) fillSize <- mkReg(0);
    Reg#(Bit#(16)) lastByteEnable <- mkReg(0);

    rule requestAddr (writePhase==Request && burstStorageFilled);
        Bit#(addrwidth) reqAddr = inputImageAddress + local_addr;
        Bit#(8) beats = truncate(fillSize-1);
        axi4_write_addr(axiDataWr,reqAddr,unpack(beats));
        writePhase <= Write;
        writeInd <= 0;
    endrule
    
    rule writeData (writePhase==Write)
        if(writeInd < fillSize) // Inside burst
            begin
            Bit#(128) data;
            Integer pixelBitStart = 127;
            for(Integer i=0; i<16; i=i+1)
                begin
                data[pixelBitStart:pixelBitStart-7] = unpack(burstStorage[writeInd+i]);
                pixelBitStart = pixelBitStart - 8;
                end
            local_addr <= local_addr + 16;
            Bit#(16) byte_enable = 16'hFFFF;
            Bool last = False;
            if (writeInd==fillSize-1) // Last beat
                begin
                byte_enable = lastByteEnable;
                last = True;
                end
            axi4_write_data(axiDataWr,data,byte_enable,last);
            writeInd <= writeInd + 16;
            end
        else // After last beat
            begin
            writePhase <= Request;
            burstStorageFilled <= False;
            fillSize <= 0;
            end
    endrule
    
    
    Vector#(windowsize,MIMO#(16,16,MAXROWBUFFERLEN,UInt#(8))) rowBuffers <- mkMIMOBRAM({unguarded:True,bram_based:True});
    Vector#(windowsize,Reg#(UInt#(addrwidth))) rowBuffersInSize;
    Vector#(windowsize,Reg#(UInt#(addrwidth))) rowBuffersOutSize;
    for(Integer i=0; i<windowsize+1; i=i+1)
        begin
        rowBuffersInSize[i] <- mkReg(0);
        rowBuffersOutSize[i] <- mkReg(0);
        end
    
    // Move data from burstStorage to row buffer
    rule moveDataToBurstStorage (rowBuffers[0].deqReady && !burstStorageFilled)
        if(fillSize<256)
            begin
            Bit#(9) remainSize = 256-fillSize;
            if(rowBuffers[0].deqReadyN(16) && remainSize>=16)
                begin
                Vector#(16,UInt#(8)) items = rowBuffers[0].first;
                for(Integer i=0; i<16; i=i+1)
                    burstStorage[fillSize+i] <= items[i];
                fillSize <= fillSize + 16;
                rowBuffers[0].deq(16);
                rowBuffersOutSize[0] <= rowBuffersOutSize[0] + 16;
                end
            else if(rowBuffers[0].deqReadyN(8) && remainSize>=8)
                begin
                Vector#(16,UInt#(8)) items = rowBuffers[0].first;
                for(Integer i=0; i<8; i=i+1)
                    burstStorage[fillSize+i] <= items[i];
                fillSize <= fillSize + 8;
                rowBuffers[0].deq(8);
                rowBuffersOutSize[0] <= rowBuffersOutSize[0] + 8;
                end
            else if(rowBuffers[0].deqReadyN(4) && remainSize>=4)
                begin
                Vector#(16,UInt#(8)) items = rowBuffers[0].first;
                for(Integer i=0; i<4; i=i+1)
                    burstStorage[fillSize+i] <= items[i];
                fillSize <= fillSize + 4;
                rowBuffers[0].deq(4);
                rowBuffersOutSize[0] <= rowBuffersOutSize[0] + 4;
                end
            else 
                begin
                Vector#(16,UInt#(8)) items = rowBuffers[0].first;
                burstStorage[fillSize] <= items[0];
                fillSize <= fillSize + 1;
                rowBuffers[0].deq(1);
                rowBuffersOutSize[0] <= rowBuffersOutSize[0] + 1;
                end
            end
        else // burstStorage is full
            begin
                burstStorageFilled <= True;
                writePhase <= Request;
            end
    endrule

    Reg#(Bool) doYShift <-mkReg(False);
    Reg#(Bit#(addrwidth) yShiftSize <-mkReg(windowsize);
    Reg#(Bit#(addrwidth) yShiftCount <-mkReg(windowsize);
    
    Reg#(Bool) windowValid <- mkReg(False);
    Reg#(Bit#(addrwidth)) lastXShift <- mkReg(shiftsize);
    Reg#(Bit#(addrwidth)) lastYShift <- mkReg(shiftsize);
    Reg#(Bit#(addrwidth)) windowX0 <- mkReg(0);
    Reg#(Bit#(addrwidth)) windowY0 <- mkReg(0);
    Vector#(windowsize,Vector#(windowsize,Reg#(UInt#(8)))) windowStorage = newVector;
    
    method Action putWindow(Vector#(windowsize,Vector#(windowsize,Tuple2#(Bool,UInt#(8)))));
        
    endmethod
    
    method ActionValue#(Bool) configure (Bit#(addrwidth) _imageAddress, Bit#(addrwidth) _resolutionX, Bit#(addrwidth) _resolutionY) if(!valid);
        inputImageAddress <= _imageAddress;
        resolutionX <= _resolutionX;
        resolutionY <= _resolutionY;
        imageSize <= _resolutionX * _resolutionY;
        for(Integer i=0; i<windowsize; i=i+1)
            rowBuffers_PixelCount[i] <= 0;
        x <= 0;
        y <= 0;
        local_addr <= 0;
        windowRegsFilled <= False;
        Bool valid;
        if(shiftsize<=16 && windowsize<=16 && windowsize<=resolutionX && windowsize<=resolutionY && shiftsize<=windowsize)
            valid = True
        else
            valid = False;
        validConfig <= valid;
        return valid;
    endmethod
    
    interface axi4Fab = axiDataRd.fab;
    
endmodule

endpackage
