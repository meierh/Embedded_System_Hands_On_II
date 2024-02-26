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
interface AXIGrayscaleWriter#(numeric type addrwidth, numeric type datawidth,
                             numeric type windowsizeX, numeric type mimoInOutMax,
                             numeric type mimoLen);
    method ActionValue#(Bool) configure (Bit#(addrwidth) _outputAddress, Bit#(addrwidth) _resolutionX, Bit#(addrwidth) _resolutionY);
    method Action setWindow(Tuple2#(Bit#(addrwidth),Vector#(windowsizeX,UInt#(8))) window);
    interface AXI4_Master_Wr_Fab#(addrwidth,datawidth,1,0) axi4Fab;
endinterface

module mkAXIGrayscaleWriter(AXIGrayscaleWriter#(addrwidth,datawidth,windowsizeX,mimoInOutMax,mimoLen))
                                provisos(Max#(addrwidth,8,addrwidth), // 8 <= addrwidth
                                         Div#(datawidth,8,pixelsPerBeat),
                                         Add#(2, c__, TMul#(pixelsPerBeat, mimoLen)),
                                         Add#(d__, TMul#(8, mimoInOutMax), TMul#(8, TMul#(pixelsPerBeat, mimoLen))),
                                         Add#(e__, mimoInOutMax, TMul#(pixelsPerBeat, mimoLen)),
                                         Add#(f__, 8, datawidth),
                                         Mul#(pixelsPerBeat,8,datawidth), // datawidth multiple of 8
                                         Log#(pixelsPerBeat,4), // datawidth fixed to 128
                                         Add#(a__, 8, addrwidth),
                                         Add#(b__,TLog#(TAdd#(mimoInOutMax,1)),addrwidth),
                                         Max#(mimoInOutMax,windowsizeX,mimoInOutMax), // windowsizeX <= mimoInOutMax
                                         Max#(mimoInOutMax,16,mimoInOutMax)); // windowsizeX <= mimoInOutMax   

// Configuration registers
    Reg#(Bit#(addrwidth)) outputImageAddress <- mkReg(0);
    Reg#(Bit#(addrwidth)) resolutionX <- mkReg(0);
    Reg#(Bit#(addrwidth)) resolutionY <- mkReg(0);
    Reg#(Bit#(addrwidth)) imageSize <- mkReg(0);
    Reg#(Bool) validConfig <- mkReg(False);
    
    MIMOConfiguration cfg;
    cfg.unguarded = False;
    cfg.bram_based = True;
    MIMO#(mimoInOutMax,mimoInOutMax,TMul#(pixelsPerBeat,mimoLen),UInt#(8)) outputBuffer <- mkMIMO(cfg);

// AXI connect
    AXI4_Master_Wr#(addrwidth,datawidth,1,0) axiDataWr <- mkAXI4_Master_Wr(1,1,1,False);
    
    Reg#(Bit#(addrwidth)) addrOffset <- mkReg(0);
    Reg#(AXIBurstPhase) axiSendPhase <- mkReg(Request);
    
    Reg#(Bool) lastBurst <- mkReg(False);
    Reg#(Bit#(addrwidth)) requestedBeats <- mkReg(0);
    Reg#(Bit#(addrwidth)) beatCounter <- mkReg(0);
    Reg#(Bool) incompleteLastBeat <- mkReg(False);
    Reg#(Bit#(addrwidth)) lastBeatPixelOverhang <- mkReg(0);
    
    rule sendRequest (axiSendPhase==Request);
        if(addrOffset < imageSize)
            begin
            Bit#(addrwidth) writeAddress = imageSize + addrOffset;
            Bit#(addrwidth) remainingPixels = imageSize - addrOffset;
            Bit#(addrwidth) remainingBeats = remainingPixels >> 4;
            Bool _lastBurst = False;
            Bool _incompleteLastBeat = False;
            Bit#(addrwidth) _lastBeatPixelOverhang = 0;
            Bit#(addrwidth) _requestedBeats = remainingBeats;
            if(remainingBeats<=256)
                begin
                _lastBurst = True;
                _lastBeatPixelOverhang = remainingBeats*16-remainingPixels;
                if(_lastBeatPixelOverhang!=0)
                    _incompleteLastBeat = False;
                end
            else
                _requestedBeats = 256;
            Bit#(addrwidth) _requestedBeats_Min1 = _requestedBeats-1;
            Bit#(8) _requestedBeats_Min1_Trunc = truncate(_requestedBeats_Min1);
            axi4_write_addr(axiDataWr,writeAddress,unpack(_requestedBeats_Min1_Trunc));
            axiSendPhase <= Send;
            lastBurst <= _lastBurst;
            requestedBeats <= _requestedBeats;
            beatCounter <= 0;
            incompleteLastBeat <= _incompleteLastBeat;
            lastBeatPixelOverhang <= _lastBeatPixelOverhang;
            end
        else
            validConfig <= False;
    endrule
    
    rule sendAction(axiSendPhase==Send && outputBuffer.deqReady());
        if(beatCounter < requestedBeats-1)
            begin
            UInt#(addrwidth) testDeqSizeUInt = fromInteger(valueOf(datawidth)/8);
            LUInt#(mimoInOutMax) testDeqSizeLUInt = truncate(testDeqSizeUInt);            if(outputBuffer.deqReadyN(testDeqSizeLUInt))
                begin
                Vector#(mimoInOutMax, UInt#(8)) extractPixels = outputBuffer.first;
                outputBuffer.deq(testDeqSizeLUInt);
                addrOffset <= addrOffset + fromInteger(valueOf(datawidth)/8);
                Bit#(datawidth) writeData = 0;
                Integer pixelBitStart = valueOf(datawidth)-1;
                for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
                    begin
                    writeData[pixelBitStart:pixelBitStart-7] = pack(extractPixels[i]);
                    pixelBitStart = pixelBitStart - 8;
                    end
                Bit#(TDiv#(datawidth, 8)) byte_enable = 0;
                byte_enable = byte_enable-1;
                axi4_write_data(axiDataWr,writeData,byte_enable,False);
                end
            end
        else if(beatCounter == requestedBeats-1)
            begin
            Bit#(addrwidth) validPixels;
            if(incompleteLastBeat)
                validPixels = lastBeatPixelOverhang;
            else
                validPixels = fromInteger(valueOf(datawidth)/8);
            UInt#(addrwidth) testDeqSizeUInt = unpack(validPixels);
            LUInt#(mimoInOutMax) testDeqSizeLUInt = truncate(testDeqSizeUInt);  
            if(outputBuffer.deqReadyN(testDeqSizeLUInt))
                begin
                Vector#(mimoInOutMax, UInt#(8)) extractPixels = outputBuffer.first;
                outputBuffer.deq(testDeqSizeLUInt);
                addrOffset <= addrOffset + validPixels;
                Bit#(datawidth) writeData;
                Bit#(TDiv#(datawidth, 8)) byte_enable = 0;
                Integer pixelBitStart = valueOf(datawidth)-1;
                Integer enableBitStart = (valueOf(datawidth)/8)-1;
                for(Integer i=0; fromInteger(i)<validPixels; i=i+1)
                    begin
                    byte_enable[enableBitStart] = 1'b1;
                    writeData[pixelBitStart:pixelBitStart-7] = pack(extractPixels[i]);
                    pixelBitStart = pixelBitStart - 8;
                    enableBitStart = enableBitStart - 1;
                    end
                axi4_write_data(axiDataWr,writeData,byte_enable,False);
                end
            end
        else
            axiSendPhase <= Request;
    endrule
    
    method Action setWindow(Tuple2#(Bit#(addrwidth),Vector#(windowsizeX,UInt#(8))) window);
        Bit#(addrwidth) windowSize = tpl_1(window);
        Vector#(windowsizeX,UInt#(8)) windowVec = tpl_2(window);
        Vector#(mimoInOutMax,UInt#(8)) enqVector = newVector;
        for(Integer i=0; i<valueOf(mimoInOutMax); i=i+1)
            if(fromInteger(i)<windowSize)
                enqVector[i] = windowVec[i];
        UInt#(addrwidth) windowSizeUInt = unpack(windowSize);
        LUInt#(mimoInOutMax) windowSizeLUInt = truncate(windowSizeUInt);
        outputBuffer.enq(windowSizeLUInt,enqVector);
    endmethod

    method ActionValue#(Bool) configure (Bit#(addrwidth) _outputAddress, Bit#(addrwidth) _resolutionX, Bit#(addrwidth) _resolutionY) if(!validConfig);
        outputImageAddress <= _outputAddress;
        resolutionX <= _resolutionX;
        resolutionY <= _resolutionY;
        imageSize <= _resolutionX * _resolutionY;
        return True;
    endmethod
    
    interface axi4Fab = axiDataWr.fab;
    
endmodule

endpackage
