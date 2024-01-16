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
    Reg#(Loadphase) loadPhase <- mkReg(Request);
    Reg#(Bit#(9)) requestedBeats <- mkReg(0);
    Reg#(Bit#(9)) countBeats <- mkReg(0);
    Reg#(Bit#(addrwidth)) pixelBeatOverhang <- mkRegU();
    
    Reg#(Bit#(13)) writeIndex <- mkReg(0);
    Reg#(Bool) doneWriting <- mkReg(True);
    Reg#(Bit#(13)) readIndex <- mkReg(0);
    Vector(256*16,Reg#(Bit#(8))) burstStorage <- newVector;
    Reg#(Bool) blockedBurstStorage <- mkReg(False);

    rule requestData (validConfig && loadPhase==Request && !blockedBurstStorage);
        if(local_addr < imageSize)
            begin
            Bit#(addrwidth) reqAddr = inputImageAddress + local_addr;
            Bit#(addrwidth) _remainigPixels = local_addr - reqAddr:
            Bit#(addrwidth) _remainingBeats = _remainigPixels >> 4;
            Bit#(addrwidth) _pixelBeatOverhang = _remainigPixels % 16;
            Bit#(addrwidth) _requestedBeats;
            if(_remainingBeats < 256) 
                _requestedBeats = _remainingBeats;
            else
                _requestedBeats = 256;
            pixelBeatOverhang <= _pixelBeatOverhang;
            requestedBeats <= truncate(_requestedBeats);
            Bit#(8) beats = truncate(_requestedBeats-1);
            axi4_read_data(axiDataRd,reqAddr,unpack(beats));
            loadPhase <= Read;
            countBeats <= 0;
            blockedBurstStorage <= True;
            doneWriting <= False;
            end
        else
            validConfig <= False;
    endrule
    
    rule readData (loadPhase==Read) 
        if(countBeats < requestedBeats) // Inside burst
            begin
            Bit#(128) data <- axi4_read_response(axiDataRd);
            local_addr <= local_addr + 16;
            countBeats <= countBeats + 1;
            Vector#(16,UInt#(8)) pixelVec;
            Integer pixelBitStart = 127;
            for(Integer i=0; i<16; i=i+1) // Split bits into pixels
                begin
                pixelVec[i] = unpack(data[pixelBitStart:pixelBitStart-7]);
                pixelBitStart = pixelBitStart - 8;
                burstStorage[writeIndex+i] <= pixelVec[i];
                end
            if(countBeats < requestedBeats-1) // Not last burst
                writeIndex <= writeIndex + 16;
            else // Is last burst
                begin
                Bit#(9) pixelBeatOverhang_trunc = truncate(pixelBeatOverhang);
                writeIndex <= writeIndex + pixelBeatOverhang_trunc;
                end
            end
        else // After last beat
            begin
            loadPhase <= Request;
            doneWriting <= False;
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
    rule moveDataToRowBuffer (readIndex < writeIndex)
        Bit#(13) validSpan = writeIndex - readIndex;
        validSpan = min(validSpan,16);            
        readIndex <= readIndex + validSpan;
        Vector(16,UInt#(8)) enqVector = newVector;
        for(Integer i=0; i<16; i=i+1)
            if(i<validSpan)
                enqVector[i] <= burstStorage[readIndex+i];
        LUint#(16) enqCount = validSpan;
        rowBuffers[windowsize-1].enq(enqCount,enqVector);
        rowBuffersInSize[windowsize-1] <= rowBuffersInSize[windowsize-1] + extend(validSpan);
        if(doneWriting && !(readIndex<writeIndex))
            begin
            blockedBurstStorage <= False;
            writeIndex <= 0;
            readIndex <= 0;
            end
    endrule

    Reg#(Bool) doYShift <-mkReg(False);
    Reg#(Bit#(addrwidth) yShiftSize <-mkReg(windowsize);
    Reg#(Bit#(addrwidth) yShiftCount <-mkReg(windowsize);
    
    // Move pixels through row buffers until they are filled by a row
    rule yShift (doYShift);
        Bit#(addrwidth) necessaryShift = yShiftCount - yShiftSize*resolutionX;
        if(necessaryShift > 0)
            begin
            if(necessaryShift>16)
                necessaryShift = 16;
            Bit#(16) necessaryShift_small = truncate(necessaryShift);
            for(Integer row=window-1; row<0; row=row-1)
                begin
                Vector#(16, UInt#(8)) enqNextRow = rowBuffers[row].first;
                rowBuffers[row].deq(necessaryShift);
                rowBuffersOutSize[row] <= rowBuffersOutSize[row] + necessaryShift_small;
                
                LUint#(16) enqCount = unpack(necessaryShift_small);
                rowBuffers[row-1].enq(enqCount,enqNextRow);
                rowBuffersInSize[row-1] <= rowBuffersInSize[row-1] + necessaryShift_small;
                end
            rowBuffers[0].deq(necessaryShift);
            rowBuffersOutSize[0] <= rowBuffersOutSize[0] + necessaryShift_small;
            yShiftCount <= yShiftCount + necessaryShift;
            end
        else
            begin
            doYShift <= False;
            yShiftCount <= 0;
            windowValid <= False;
            end            
    endrule

    Reg#(Bool) windowValid <- mkReg(False);
    Reg#(Bit#(addrwidth)) lastXShift <- mkReg(shiftsize);
    Reg#(Bit#(addrwidth)) lastYShift <- mkReg(shiftsize);
    Reg#(Bit#(addrwidth)) windowX0 <- mkReg(0);
    Reg#(Bit#(addrwidth)) windowY0 <- mkReg(0);
    Vector#(windowsize,Vector#(windowsize,Reg#(UInt#(8)))) windowStorage = newVector;
    
    // Move pixels to window regs until they are filled by a row
    rule fillWindow (!windowValid & !doYShift);
        for(Integer row=windowsize-1; row>=0; row=row-1)
            begin
            Vector#(16, UInt#(8)) rowBufferSet = rowBuffers[row].first;
            rowBuffers[row].deq(windowsize);
            for(Integer x=0; x<windowsize; x=x+1)
                windowRegs[row][x] <= rowBufferSet[row][x];
            end
        windowValid <= True;
    endrule
    
    method Action putWindow(Tuple3#(Bit#(addrwidth),Bit#(addrwidth),#(windowsize,Vector#(windowsize,UInt#(8)))));
        Vector#(windowsize,Vector#(windowsize,UInt#(8))) _window = windowRegs;
        Bit#(addrwidth) _xShiftSize = resolutionX - (windowX0+windowsize);
        Bit#(addrwidth) _yShiftSize = resolutionY - (windowY0+windowsize);
        if(_xShiftSize > 0) // XShift necessary
            begin
            if(_xShiftSize > shiftsize)
                _xShiftSize = shiftsize;
            for(Integer row=windowsize-1; row>=0; row=row-1)
                begin
                // Move row buffer content into window registers
                Vector#(16, UInt#(8)) rowBufferSet = rowBuffers[row].first;
                rowBuffers[row].deq(_xShiftSize);
                rowBuffersOutSize[row] <= rowBuffersOutSize[row] + _xShiftSize;
                for(Integer i=0; i<16; i=i+1)
                    if(i<_xShiftSize)
                        windowRegs[windowsize-_xShiftSize] <= rowBufferSet[i];
                // Move window register contents into row buffer
                if(row>0)
                    begin
                    Vector(16,UInt#(8)) enqVector = newVector;
                    Bit#(16) enqSize = windowsize-_xShiftSize
                    for(Integer i=0; i<16; i=i+1)
                        if(i<enqSize)
                            enqVector[i] = windowRegs[i];
                    LUint#(16) enqCount = enqSize;
                    rowBuffers[row-1].enq(enqCount,enqVector);
                    rowBuffersInSize[row-1] <= rowBuffersInSize[row-1] + extend(enqSize);
                    end
                end
            windowX0 <= windowX0 + _xShiftSize;
            lastXShift <= _xShiftSize;
            windowValid <= True;
            end
        else // YShift necessary
            begin
            if(_yShiftSize > 0) // YShift
                begin
                if(_yShiftSize > shiftsize)
                    _yShiftSize = shiftsize;
                doYShift <= True;
                yShiftSize <= _yShiftSize;
                yShiftCount <= 0;
                windowX0 <= 0;
                windowY0 <= windowY0 + _yShiftSize;
                end
            else // End of image
                begin
                windowX0 <= 0;
                windowY0 <= 0;
                lastXShift <= shiftsize;
                lastYShift <= shiftsize;
                end
            windowValid <= False;
            end
        return tuple3(lastXShift,lastYShift,windowStorage);
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
