package AXIGrayscaleReader;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import AXI4_Types :: * ;
import AXI4_Master :: * ;
import MIMO :: *;
import GetPut :: *;
    
typedef enum {
    Request = 2'b00,
    Read = 2'b01,
    Move = 2'b10
    } AXIBurstStoragePhase deriving (Bits,Eq);

(* always_ready, always_enabled *)
interface AXIGrayscaleReader#(numeric type addrwidth, numeric type datawidth,
                              numeric type windowsizeX, numeric type windowsizeY,
                              numeric type shiftX, numeric type shiftY,
                              numeric type maxResolutionX, numeric type mimoInOutMax);
    method ActionValue#(Bool) configure (Bit#(addrwidth) _imageAddress, Bit#(addrwidth) _resolutionX, Bit#(addrwidth) _resolutionY);
    method ActionValue#(Vector#(windowsizeY,Vector#(windowsizeX,Tuple2#(Bool,UInt#(8))))) getWindow ();
    interface AXI4_Master_Rd_Fab#(addrwidth,datawidth,1,0) axi4Fab;
endinterface

module mkAXIGrayscaleReader(AXIGrayscaleReader#(addrwidth,datawidth,windowsizeX,windowsizeY,shiftX,shiftY,maxResolutionX,mimoInOutMax))
                                provisos(Max#(windowsizeX,shiftX,windowsizeX), // shiftX <= windowsizeX
                                         Max#(windowsizeY,shiftY,windowsizeY), // shiftY <= windowsizeY
                                         Max#(windowsizeX,maxResolutionX,maxResolutionX), // windowsizeX <= maxResolutionX
                                         Max#(addrwidth,8,addrwidth), // 8 <= addrwidth
                                         Div#(datawidth,8,pixelsPerBeat), 
                                         Mul#(pixelsPerBeat,8,datawidth), // datawidth fixed to 128
                                         Log#(pixelsPerBeat,4),
                                         Add#(a__, 8, addrwidth),
                                         Add#(b__,TLog#(TAdd#(mimoInOutMax,1)),addrwidth),
                                         Max#(mimoInOutMax,windowsizeX,mimoInOutMax)); // windowsizeX <= mimoInOutMax
                                         

// Configuration registers
    Reg#(Bit#(addrwidth)) inputImageAddress <- mkReg(0);
    Reg#(Bit#(addrwidth)) resolutionX <- mkReg(0);
    Reg#(Bit#(addrwidth)) resolutionY <- mkReg(0);
    Reg#(Bit#(addrwidth)) imageSize <- mkReg(0);
    Reg#(Bool) validConfig <- mkReg(False);

// AXI connect
    AXI4_Master_Rd#(addrwidth,datawidth,1,0) axiDataRd <- mkAXI4_Master_Rd(1,1,False);
    
// Load data from AXI slave
    Reg#(Bit#(addrwidth)) addrOffset <- mkReg(0);
    Reg#(AXIBurstStoragePhase) axiLoadPhase <- mkReg(Request);
    
    Reg#(Bool) completeBurst <- mkRegU();
    Reg#(Bit#(TDiv#(datawidth, 8))) lastBeatValidity <- mkRegU();

    Vector#(TMul#(256,TDiv#(datawidth,8)),Reg#(UInt#(8))) burstStorage = newVector;
    Reg#(Bool) doneWriting <- mkReg(True);
    Reg#(Bit#(addrwidth)) writeIndex <- mkReg(0);
    Reg#(Bit#(addrwidth)) readIndex <- mkReg(0);

    rule requestData (validConfig && axiLoadPhase==Request);
        if(addrOffset < imageSize)
            begin
            Bit#(addrwidth) reqAddr = inputImageAddress + addrOffset;
            Bit#(addrwidth) _remainigPixels = imageSize - addrOffset;
            Bit#(addrwidth) _remainingBeats = _remainigPixels >> 4; // Hardcoded division by 16
            Bit#(TDiv#(datawidth,8)) _lastBeatValidity = 0;
            Bit#(addrwidth) _requestedBeats;
            if(_remainingBeats < 256)
                begin
                _requestedBeats = _remainingBeats;
                Bit#(addrwidth) _lastBeatPixelOverhang = _remainigPixels % 16;
                if(_lastBeatPixelOverhang==0)
                    _lastBeatValidity = invert(_lastBeatValidity);
                else
                    for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
                        if(fromInteger(i)<_lastBeatPixelOverhang)
                            _lastBeatValidity[i] = 1;
                completeBurst <= False;
                end
            else
                begin
                _requestedBeats = 256;
                completeBurst <= True;
                _lastBeatValidity = invert(_lastBeatValidity);
                end
            lastBeatValidity <= _lastBeatValidity;
            Bit#(addrwidth) _requestedBeats_Min1 = _requestedBeats-1;
            Bit#(8) _requestedBeats_Min1_Trunc = truncate(_requestedBeats_Min1);
            axi4_read_data(axiDataRd,reqAddr,unpack(_requestedBeats_Min1_Trunc));
            axiLoadPhase <= Read;
            doneWriting <= False;
            writeIndex <= 0;
            end
        else
            validConfig <= False;
    endrule
    
    rule readData (validConfig && axiLoadPhase==Read);
        let readResponse <- axiDataRd.response.get();
        Bit#(datawidth) responseData  = readResponse.data;
        Bool responseLast = readResponse.last;
        addrOffset <= addrOffset + fromInteger(valueOf(datawidth)/8);
        
        Vector#(TDiv#(datawidth,8),UInt#(8)) pixels;
        Integer pixelBitStart = valueOf(datawidth)-1;
        for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
            begin
            pixels[i] = unpack(responseData[pixelBitStart:pixelBitStart-7]);
            pixelBitStart = pixelBitStart - 8;
            end
        
        Bit#(addrwidth) nextWriteIndex = writeIndex + fromInteger(valueOf(datawidth)/8);
        if(nextWriteIndex > fromInteger(256*(valueOf(datawidth)/8)))
            nextWriteIndex = fromInteger(256*(valueOf(datawidth)/8));
        writeIndex <= writeIndex + nextWriteIndex;
        
        if(!responseLast)
            begin
            for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
                burstStorage[writeIndex+fromInteger(i)] <= pixels[i];
            end
        else
            begin
            for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
                if(lastBeatValidity[i]==1)
                    burstStorage[writeIndex+fromInteger(i)] <= pixels[i];
            axiLoadPhase <= Move;
            doneWriting <= True;
            end
    endrule
    
    Vector#(windowsizeY,MIMO#(mimoInOutMax,mimoInOutMax,maxResolutionX,UInt#(8))) rowBuffers = newVector;
    Vector#(windowsizeY,Reg#(Bit#(addrwidth))) rowBuffersInSize;
    Vector#(windowsizeY,Reg#(Bit#(addrwidth))) rowBuffersOutSize;
    for(Integer i=0; i<valueOf(windowsizeY); i=i+1)
        begin
        rowBuffersInSize[i] <- mkReg(0);
        rowBuffersOutSize[i] <- mkReg(0);
        end
    
    // Move data from burstStorage to row buffer
    (* descending_urgency = "readData, moveDataToRowBuffer" *)
    rule moveDataToRowBuffer (readIndex < writeIndex && (axiLoadPhase == Read || axiLoadPhase == Move));
        Bit#(addrwidth) validBufferSpan = writeIndex - readIndex;
        Bit#(addrwidth) transferSpan = min(validBufferSpan,fromInteger(valueOf(mimoInOutMax)));            
        
        Vector#(mimoInOutMax,UInt#(8)) enqVector = newVector;
        for(Integer i=0; i<valueOf(mimoInOutMax); i=i+1)
            if(fromInteger(i) < validBufferSpan)
                enqVector[i] = burstStorage[readIndex+fromInteger(i)];
        UInt#(addrwidth) enqCountUInt = unpack(transferSpan);
        LUInt#(mimoInOutMax) enqCount = truncate(enqCountUInt);
        rowBuffers[valueOf(windowsizeY)-1].enq(enqCount,enqVector);
        
        if(doneWriting && !(readIndex+transferSpan < writeIndex))
            begin
            writeIndex <= 0;
            readIndex <= 0;
            axiLoadPhase <= Request;
            end
        else
            readIndex <= readIndex + transferSpan;
    endrule

    Reg#(Bool) doYShift <-mkReg(False);
    Reg#(Bit#(addrwidth)) yShiftSize <- mkReg(fromInteger(valueOf(windowsizeY)));
    Reg#(Bit#(addrwidth)) yShiftCount <- mkReg(fromInteger(valueOf(windowsizeY)));
    Reg#(Bool) windowValid <- mkReg(False);
    
    // Move pixels through row buffers until they are filled by a row
    rule yShift (doYShift);
        Bit#(addrwidth) necessaryShift = yShiftCount - yShiftSize*resolutionX;
        if(necessaryShift > 0)
            begin
            
            Bit#(addrwidth) nextShift = necessaryShift;
            if(necessaryShift > fromInteger(valueOf(mimoInOutMax)))
                nextShift = fromInteger(valueOf(mimoInOutMax));
            UInt#(addrwidth) nextShiftUInt = unpack(nextShift);
            LUInt#(mimoInOutMax) nextShiftLUInt = truncate(nextShiftUInt);

            for(Integer row=valueOf(windowsizeY)-1; row<0; row=row-1)
                begin
                Vector#(mimoInOutMax, UInt#(8)) enqNextRow = rowBuffers[row].first;
                
                rowBuffers[row].deq(nextShiftLUInt);
                rowBuffersOutSize[row] <= rowBuffersOutSize[row] + nextShift;
                
                rowBuffers[row-1].enq(nextShiftLUInt,enqNextRow);
                rowBuffersInSize[row-1] <= rowBuffersInSize[row-1] + nextShift;
                end
            rowBuffers[0].deq(nextShiftLUInt);
            rowBuffersOutSize[0] <= rowBuffersOutSize[0] + nextShift;
            yShiftCount <= yShiftCount + nextShift;

            end
        else
            begin
            windowValid <= False;
            doYShift <= False;
            yShiftCount <= 0;
            end
    endrule
    
    //Reg#(Bit#(addrwidth)) lastXShift <- mkReg(shiftsize);
    //Reg#(Bit#(addrwidth)) lastYShift <- mkReg(shiftsize);
    //Reg#(Bit#(addrwidth)) windowX0 <- mkReg(0);
    //Reg#(Bit#(addrwidth)) windowY0 <- mkReg(0);
    Vector#(windowsizeY,Vector#(windowsizeX,Reg#(UInt#(8)))) windowStorage = newVector;
    
    // Move pixels to window regs until they are filled by a row
    rule fillWindow (!windowValid && !doYShift);
        for(Integer row=valueOf(windowsizeY)-1; row>=0; row=row-1)
            begin
            Vector#(mimoInOutMax, UInt#(8)) rowBufferSet = rowBuffers[row].first;
            UInt#(addrwidth) shiftXUInt = fromInteger(valueOf(shiftX));
            LUInt#(mimoInOutMax) shiftXLUInt = truncate(shiftXUInt);
            rowBuffers[row].deq(shiftXLUInt);
            for(Integer x=0; x<valueOf(windowsizeX); x=x+1)
                windowStorage[row][x] <= rowBufferSet[x];
            end
        windowValid <= True;
    endrule
    
    method ActionValue#(Vector#(windowsizeY,Vector#(windowsizeX,Tuple2#(Bool,UInt#(8))))) getWindow () if(windowValid);
        Vector#(windowsizeY,Vector#(windowsizeX,UInt#(8))) _window = newVector;
        Vector#(windowsizeY,Vector#(windowsizeX,Bool)) _windowValidity = newVector;
        for(Integer y=0; y<valueOf(windowsizeY); y=y+1)
            for(Integer x=0; x<valueOf(windowsizeX); x=x+1)
                begin
                _windowValidity[y][x] = True;
                _window[y][x] = windowStorage[y][x];
                end
        /*
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
                    Vector#(16,UInt#(8)) enqVector = newVector;
                    Bit#(16) enqSize = windowsize-_xShiftSize;
                    for(Integer i=0; i<16; i=i+1)
                        if(i<enqSize)
                            enqVector[i] = windowRegs[i];
                    LUInt#(16) enqCount = enqSize;
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
        */

        Vector#(windowsizeY,Vector#(windowsizeX,Tuple2#(Bool,UInt#(8)))) result = newVector;
        for(Integer y=0; y<valueOf(windowsizeY); y=y+1)
            for(Integer x=0; x<valueOf(windowsizeX); x=x+1)
                result[y][x] = tuple2(_windowValidity[y][x],_window[y][x]);
        return result;
    endmethod
    
    method ActionValue#(Bool) configure (Bit#(addrwidth) _imageAddress, Bit#(addrwidth) _resolutionX, Bit#(addrwidth) _resolutionY) if(!validConfig);
        $display("Image address: %b",_imageAddress);
        inputImageAddress <= _imageAddress;
        resolutionX <= _resolutionX;
        resolutionY <= _resolutionY;
        imageSize <= _resolutionX * _resolutionY;
        /*
        for(Integer i=0; i<windowsize; i=i+1)
            rowBuffers_PixelCount[i] <= 0;
        */
        addrOffset <= 0;
        //windowRegsFilled <= False;
        Bool valid = True;
        /*
        if(shiftsize<=16 && windowsize<=16 && windowsize<=resolutionX && windowsize<=resolutionY && shiftsize<=windowsize)
            valid = True;
        else
            valid = False;
        */
        validConfig <= valid;
        return valid;
    endmethod
    
    interface axi4Fab = axiDataRd.fab;
    
endmodule

endpackage
