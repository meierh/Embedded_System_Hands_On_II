package AXIGrayscaleReader;

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
    Read = 2'b01,
    Move = 2'b10
    } AXIBurstStoragePhase deriving (Bits,Eq);
    
typedef enum {
    InitialFillRowBuffer = 3'b000,
    InitialFillWindow = 3'b001,
    Valid = 3'b010,
    YShift = 3'b011,
    End = 3'b100
    } WindowPhase deriving (Bits,Eq);

(* always_ready, always_enabled *)
interface AXIGrayscaleReader#(numeric type addrwidth, numeric type datawidth,
                              numeric type windowsizeX, numeric type windowsizeY,
                              numeric type shiftX, numeric type shiftY,
                              numeric type maxResolutionX, numeric type mimoInOutMax,
                              numeric type maxBurstLen);
    method ActionValue#(Bool) configure (Bit#(addrwidth) _imageAddress, Bit#(addrwidth) _resolutionX, Bit#(addrwidth) _resolutionY);
    method ActionValue#(Tuple3#(Bit#(addrwidth),Bit#(addrwidth),Vector#(windowsizeY,Vector#(windowsizeX,UInt#(8))))) getWindow ();
    interface AXI4_Master_Rd_Fab#(addrwidth,datawidth,1,0) axi4Fab;
endinterface

module mkAXIGrayscaleReader(AXIGrayscaleReader#(addrwidth,datawidth,windowsizeX,windowsizeY,shiftX,shiftY,maxResolutionX,mimoInOutMax,maxBurstLen))
                                provisos(Max#(windowsizeX,shiftX,windowsizeX), // shiftX <= windowsizeX
                                         Max#(windowsizeY,shiftY,windowsizeY), // shiftY <= windowsizeY
                                         Max#(windowsizeX,maxResolutionX,maxResolutionX), // windowsizeX <= maxResolutionX
                                         Max#(addrwidth,8,addrwidth), // 8 <= addrwidth
                                         Div#(datawidth,8,pixelsPerBeat), 
                                         Mul#(pixelsPerBeat,8,datawidth), // datawidth multiple of 8
                                         Log#(pixelsPerBeat,4), // datawidth fixed to 128
                                         Add#(a__, 8, addrwidth),
                                         Add#(b__,TLog#(TAdd#(mimoInOutMax,1)),addrwidth),
                                         Max#(mimoInOutMax,windowsizeX,mimoInOutMax), // windowsizeX <= mimoInOutMax
                                         Max#(mimoInOutMax,16,mimoInOutMax), // windowsizeX <= mimoInOutMax   
                                         Add#(2, c__, maxResolutionX), //mkMIMO
                                         Add#(e__, mimoInOutMax, maxResolutionX), //mkMIMO
                                         Add#(d__, TMul#(8, mimoInOutMax), TMul#(8, maxResolutionX)), //mkMIMO
                                         Add#(1, f__, TAdd#(addrwidth, TMul#(TMul#(maxBurstLen, TDiv#(datawidth, 8)), 8)))); //mkFIFO                                  
                                         

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
    Reg#(Bit#(addrwidth)) lastBeatValidityCount <- mkRegU();

    rule requestData (validConfig && axiLoadPhase==Request);
        if(addrOffset < imageSize)
            begin
            Bit#(addrwidth) reqAddr = inputImageAddress + addrOffset;
            Bit#(addrwidth) _remainigPixels = imageSize - addrOffset;
            Bit#(addrwidth) _remainingBeats = _remainigPixels >> 4; // Hardcoded division by 16
            Bit#(addrwidth) _lastBeatPixelOverhang = _remainigPixels % 16;
            if(_lastBeatPixelOverhang != 0)
                _remainingBeats = _remainingBeats + 1;
            Bit#(TDiv#(datawidth,8)) _lastBeatValidity = 0;
            Bit#(addrwidth) _requestedBeats;
            Bit#(addrwidth) _lastBeatValidityCount = 16;
            if(_remainingBeats < fromInteger(valueOf(maxBurstLen)))
                begin
                _requestedBeats = _remainingBeats;
                if(_lastBeatPixelOverhang==0)
                    _lastBeatValidity = invert(_lastBeatValidity);
                else
                    begin
                    for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
                        if(fromInteger(i)<_lastBeatPixelOverhang)
                            _lastBeatValidity[i] = 1;
                        _lastBeatValidityCount = _lastBeatPixelOverhang;
                    end
                completeBurst <= False;
                end
            else
                begin
                _requestedBeats = fromInteger(valueOf(maxBurstLen));
                completeBurst <= True;
                _lastBeatValidity = invert(_lastBeatValidity);
                end
            lastBeatValidity <= _lastBeatValidity;
            lastBeatValidityCount <= _lastBeatValidityCount;
            Bit#(addrwidth) _requestedBeats_Min1 = _requestedBeats-1;
            Bit#(8) _requestedBeats_Min1_Trunc = truncate(_requestedBeats_Min1);
            axi4_read_data(axiDataRd,reqAddr,unpack(_requestedBeats_Min1_Trunc));
            $display("_remainigPixels: %d",_remainigPixels);
            $display("_remainingBeats: %d",_remainingBeats);
            $display("_lastBeatPixelOverhang: %d",_lastBeatPixelOverhang);
            $display("_lastBeatValidity: %b",_lastBeatValidity);
            $display("_lastBeatValidityCount: %d",_lastBeatValidityCount);
            $display("axi4_read_data from %b beats %b | %d",reqAddr,_requestedBeats_Min1_Trunc,_requestedBeats_Min1_Trunc);
            $display("datawidth %d",valueOf(datawidth));
            $display("datawidth/8 %d",valueOf(datawidth)/8);
            axiLoadPhase <= Read;
            end
        else
            validConfig <= False;
    endrule
    
    Vector#(TMul#(maxBurstLen,TDiv#(datawidth,8)),Reg#(UInt#(8))) axiBurstRegisters;
    for(Integer i=0; i<valueOf(maxBurstLen)*valueOf(datawidth)/8; i=i+1)
        axiBurstRegisters[i] <- mkRegU();
    Reg#(Bit#(addrwidth)) axiBurstRegWriteIndex <- mkReg(0);
    //Reg#(Bit#(addrwidth)) axiBurstRegWriteLimitIndex <- mkReg(0);
    
    rule readData (axiLoadPhase==Read);
        let readResponse <- axiDataRd.response.get();
        Bit#(datawidth) responseData  = readResponse.data;
        Bool responseLast = readResponse.last;
        
        Vector#(TDiv#(datawidth,8),UInt#(8)) pixels;
        Integer pixelBitStart = valueOf(datawidth)-1;
        for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
            begin
            pixels[i] = unpack(responseData[pixelBitStart:pixelBitStart-7]);
            pixelBitStart = pixelBitStart - 8;
            end

        Bit#(addrwidth) writeSpan = fromInteger(valueOf(datawidth)/8);
        if(!responseLast)
            for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
                axiBurstRegisters[axiBurstRegWriteIndex+fromInteger(i)] <= pixels[i];
        else
            begin
            for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
                if(lastBeatValidity[i]==1)
                    axiBurstRegisters[axiBurstRegWriteIndex+fromInteger(i)] <= pixels[i];
            axiLoadPhase <= Move;
            writeSpan = lastBeatValidityCount;
            end
        axiBurstRegWriteIndex <= axiBurstRegWriteIndex + writeSpan;
        addrOffset <= addrOffset + writeSpan;
        $display("Write %d to %d--phase: %b Num:%d",axiBurstRegWriteIndex,axiBurstRegWriteIndex+writeSpan,axiLoadPhase,pixels[0],$time);
    endrule
    
    Vector#(TMul#(maxBurstLen,TDiv#(datawidth,8)),Reg#(UInt#(8))) intermedBurstRegisters;
    for(Integer i=0; i<valueOf(maxBurstLen)*valueOf(datawidth)/8; i=i+1)
        intermedBurstRegisters[i] <- mkRegU();
    Reg#(Bool) intermedBurstRegistersValid <- mkReg(False);
    Reg#(Bit#(addrwidth)) intermedBurstRegistersLimitIndex <- mkReg(0);
    Reg#(Bit#(addrwidth)) intermedBurstRegistersRead <- mkReg(0);
    
    rule axiBurst_to_IntermedBurst (axiLoadPhase==Move && !intermedBurstRegistersValid);
        $display("To intermediate [0:%d]",axiBurstRegWriteIndex);
        for(Integer i=0; i<valueOf(maxBurstLen)*(valueOf(datawidth)/8); i=i+1)
            intermedBurstRegisters[i] <= axiBurstRegisters[i];
        $display("axiBurstRegisters 30 %d",axiBurstRegisters[30]);
        $display("axiBurstRegisters 50 %d",axiBurstRegisters[50]);
        intermedBurstRegistersValid <= True;
        intermedBurstRegistersLimitIndex <= axiBurstRegWriteIndex;
        intermedBurstRegistersRead <= 0;
        axiBurstRegWriteIndex <= 0;
        axiLoadPhase <= Request;
    endrule 

    MIMOConfiguration cfg;
    cfg.unguarded = False;
    cfg.bram_based = True;
    Vector#(windowsizeY,MIMO#(mimoInOutMax,mimoInOutMax,maxResolutionX,UInt#(8))) rowBuffers = newVector;
    Vector#(windowsizeY,Reg#(Bit#(addrwidth))) rowBuffersInSize;
    Vector#(windowsizeY,Reg#(Bit#(addrwidth))) rowBuffersOutSize;
    for(Integer i=0; i<valueOf(windowsizeY); i=i+1)
        begin
        rowBuffersInSize[i] <- mkReg(0);
        rowBuffersOutSize[i] <- mkReg(0);
        rowBuffers[i] <- mkMIMO(cfg);
        end
        
    //Fill row buffer and window initially
    Vector#(windowsizeY,Vector#(windowsizeX,Reg#(UInt#(8)))) windowStorage = newVector;
    for(Integer y=0; y<valueOf(windowsizeY); y=y+1)
        for(Integer x=0; x<valueOf(windowsizeX); x=x+1)
            windowStorage[y][x] <- mkReg(0);
    Reg#(WindowPhase) windowState <- mkReg(InitialFillRowBuffer);    
    Reg#(Bit#(addrwidth)) currentRow <- mkReg(0);
    
    rule initialFillRowBuffer(windowState==InitialFillRowBuffer && intermedBurstRegistersValid);
        if(intermedBurstRegistersRead < intermedBurstRegistersLimitIndex)
            begin
            Bit#(addrwidth) transferSpan = intermedBurstRegistersLimitIndex-intermedBurstRegistersRead;
            transferSpan = min(transferSpan,fromInteger(valueOf(mimoInOutMax)));
            if(rowBuffersInSize[currentRow] < resolutionX) // One row buffer still to fill
                begin
                transferSpan = min(transferSpan,resolutionX-rowBuffersInSize[currentRow]);
                Vector#(mimoInOutMax,UInt#(8)) enqVector = newVector;
                for(Integer i=0; i<valueOf(mimoInOutMax); i=i+1)
                    if(fromInteger(i)<transferSpan)
                        enqVector[i] = intermedBurstRegisters[intermedBurstRegistersRead+fromInteger(i)];
                UInt#(addrwidth) enqCountUInt = unpack(transferSpan);
                LUInt#(mimoInOutMax) enqCount = truncate(enqCountUInt);
                rowBuffers[currentRow].enq(enqCount,enqVector);
                rowBuffersInSize[currentRow] <= rowBuffersInSize[currentRow] + transferSpan;
                intermedBurstRegistersRead <= intermedBurstRegistersRead + transferSpan;
                $display("Row %d filled by %d from: %d Num:%d",currentRow,transferSpan,rowBuffersInSize[currentRow],enqVector[0],$time);
                end
            else // One row buffer filled
                begin
                Bit#(addrwidth) nextRow = currentRow + 1;
                $display("Row %d filled",currentRow);
                if(nextRow < fromInteger(valueOf(windowsizeY))) // Fill next row buffer
                    currentRow <= currentRow + 1;
                else // Filling complete
                    begin
                    currentRow <= 0;
                    windowState <= InitialFillWindow;
                    end
                end
            end
        else
            begin
            $display("Initial fill: Refill intermediate",$time);
            intermedBurstRegistersValid <= False;
            end
    endrule

    Reg#(Bit#(addrwidth)) validWindowSizeY <- mkReg(0);
    Reg#(Bit#(addrwidth)) validWindowSizeX <- mkReg(0);
    rule initialFillWindow (windowState==InitialFillWindow);
        validWindowSizeY <= fromInteger(valueOf(windowsizeY));
        validWindowSizeX <= fromInteger(valueOf(windowsizeX));
        for(Integer row=0; row<valueOf(windowsizeY); row=row+1)
            begin
            $display("%d: Window fill",row,$time);
        
            Bit#(addrwidth) windowFill = fromInteger(valueOf(windowsizeX));
            UInt#(addrwidth) windowFillUInt = unpack(windowFill);
            LUInt#(mimoInOutMax) windowFillLUInt = truncate(windowFillUInt);
        
            Vector#(mimoInOutMax, UInt#(8)) enqNextRow = rowBuffers[row].first;
            rowBuffers[row].deq(windowFillLUInt);
            rowBuffersOutSize[row] <= rowBuffersOutSize[row] + windowFill;
            for(Integer col=0; col<valueOf(windowsizeX); col=col+1)
                begin
                windowStorage[row][col] <= enqNextRow[col];
                end
            end
        windowState <= Valid;
    endrule 
    
    // Move data from burstStorage to row buffer
    rule axiBurstRegister_to_rowBuffer (windowState!=InitialFillRowBuffer &&
                                        windowState!=InitialFillWindow &&
                                        intermedBurstRegistersValid);
        $display("To row buffer %d < %d",intermedBurstRegistersRead,intermedBurstRegistersLimitIndex);
        if(intermedBurstRegistersRead < intermedBurstRegistersLimitIndex)
            begin
            Bit#(addrwidth) transferSpan = intermedBurstRegistersLimitIndex-intermedBurstRegistersRead;
            transferSpan = min(transferSpan,fromInteger(valueOf(mimoInOutMax)));
            
            Vector#(mimoInOutMax,UInt#(8)) enqVector = newVector;
            for(Integer i=0; i<valueOf(mimoInOutMax); i=i+1)
                if(fromInteger(i)<transferSpan)
                    enqVector[i] = intermedBurstRegisters[intermedBurstRegistersRead+fromInteger(i)];
            UInt#(addrwidth) enqCountUInt = unpack(transferSpan);
            LUInt#(mimoInOutMax) enqCount = truncate(enqCountUInt);
            rowBuffers[valueOf(windowsizeY)-1].enq(enqCount,enqVector);
            rowBuffersInSize[valueOf(windowsizeY)-1] <= rowBuffersInSize[valueOf(windowsizeY)-1] + 1;
            intermedBurstRegistersRead <= intermedBurstRegistersRead + transferSpan;
            //$display("Read to row buffer from %d to %d",intermedBurstRegistersRead,intermedBurstRegistersRead+transferSpan,$time);
            end
        else
            begin
            intermedBurstRegistersValid <= False;
            end
    endrule

    function Bool validEnqShift(Bit#(addrwidth) enqSpan)
        UInt#(addrwidth) enqSpanUInt = unpack(enqSpan);
        LUInt#(mimoInOutMax) enqSpanLUInt = truncate(enqSpanUInt);
        Vector#(valueOf(windowsizeY), Bool) valEnq = newVector;
        for(Integer row=0; row<valueOf(windowsizeY)-1; row=row+1)
            valEnq[row] = rowBuffers[row].deqReadyN(enqSpanLUInt);
        return and(valEnq);
    endfunction
    
    function Bool validDeqShift(Bit#(addrwidth) deqSpan)
        UInt#(addrwidth) deqSpanUInt = unpack(deqSpan);
        LUInt#(mimoInOutMax) deqSpanLUInt = truncate(deqSpanUInt);
        Vector#(valueOf(windowsizeY), Bool) valDeq = newVector;
        for(Integer row=0; row<valueOf(windowsizeY); row=row+1)
            valDeq[row] = rowBuffers[row].enqReadyN(enqSpanLUInt);
        return and(valDeq);
    endfunction
    
    Reg#(Bit#(addrwidth)) shiftCounter <- mkReg(0);
    rule shiftYRowBuffer(windowState==YShift);
        $display("Y Shift");
        if(shiftCounter < resolutionX*fromInteger(valueOf(shiftY)))
            begin
            Bit#(addrwidth) transferSpan = resolutionX*fromInteger(valueOf(shiftY))-shiftCounter;
            transferSpan = min(transferSpan,fromInteger(valueOf(mimoInOutMax)));
            transferSpan = min(transferSpan,resolutionX);
            Vector#(2, Bool) transferAble = newVector;
            
            
            $display("Shift by: %d of %d * %d = %d",transferSpan,resolutionX,fromInteger(valueOf(shiftY)),resolutionX*fromInteger(valueOf(shiftY)));
            Bool deqEnqValid = False;
            
            UInt#(addrwidth) transferSpanUInt = unpack(transferSpan);
            LUInt#(mimoInOutMax) transferSpanLUInt = truncate(transferSpanUInt);
            shiftCounter <= shiftCounter + transferSpan;
            for(Integer row=0; row<valueOf(windowsizeX)-1; row=row+1)
                begin
                //$display(" rowBuffers[%d].deqReadyN(transferSpanLUInt): %b",row,rowBuffers[row].deqReadyN(transferSpanLUInt));
                //$display(" rowBuffers[%d].deqReadyN(transferSpanLUInt): %b",row,rowBuffers[row].deqReadyN(transferSpanLUInt/2));
                //$display(" rowBuffers[%d].deqReady: %b",row,rowBuffers[row].deqReady);
                Vector#(mimoInOutMax,UInt#(8)) deqVector = rowBuffers[row].first;
                $display("row: %d -- %d",row,deqVector[0]);
                rowBuffers[row].deq(transferSpanLUInt);
                rowBuffersOutSize[row] <= rowBuffersOutSize[row] + transferSpan;
                if(row-1 >= 0)
                    begin
                    $display("rowBuffers[%d].enqReadyN(transferSpanLUInt): %b",row-1,rowBuffers[row-1].enqReadyN(transferSpanLUInt));
                    //rowBuffers[row-1].enq(transferSpanLUInt,deqVector);
                    rowBuffersInSize[row-1] <= rowBuffersInSize[row-1] + transferSpan;
                    end
                end
            end
        else
            begin
            windowState <= InitialFillWindow;
            shiftCounter <= 0;
            end
    endrule
    
    Reg#(Bit#(addrwidth)) windowX0 <- mkReg(0);
    Reg#(Bit#(addrwidth)) windowY0 <- mkReg(0);
    Reg#(Bool) lastRows <- mkReg(False);
    
    method ActionValue#(Tuple3#(Bit#(addrwidth),Bit#(addrwidth),Vector#(windowsizeY,Vector#(windowsizeX,UInt#(8))))) getWindow () if(windowState==Valid);
        Vector#(windowsizeY,Vector#(windowsizeX,UInt#(8))) _window = newVector;
        for(Integer y=0; y<valueOf(windowsizeY); y=y+1)
            for(Integer x=0; x<valueOf(windowsizeX); x=x+1)
                _window[y][x] = windowStorage[y][x];
        
        Bit#(addrwidth) nextWindowX0 = windowX0 + fromInteger(valueOf(shiftX));
        Bit#(addrwidth) necessaryResolutionX = nextWindowX0 + fromInteger(valueOf(windowsizeX));        
        if(windowX0+fromInteger(valueOf(windowsizeX)) <= resolutionX) // Shift in x direction
            begin
            
            // Move back into mimo
            for(Integer row=1; row<valueOf(windowsizeY); row=row+1)
                begin
                Vector#(mimoInOutMax,UInt#(8)) enqVector = newVector;
                for(Integer x=0; x<valueOf(shiftX); x=x+1)
                    enqVector[x] = windowStorage[row][x];
                UInt#(addrwidth) enqCountUInt = fromInteger(valueOf(shiftX));
                LUInt#(mimoInOutMax) enqCount = truncate(enqCountUInt);
                rowBuffers[row-1].enq(enqCount,enqVector);
                rowBuffersInSize[row] <= rowBuffersInSize[row] + pack(enqCountUInt);
                end
            
            // Move inside window storage
            for(Integer row=0; row<valueOf(windowsizeY); row=row+1)
                for(Integer x=0; x<valueOf(windowsizeX)-valueOf(shiftX); x=x+1)
                    windowStorage[row][x] <= windowStorage[row][valueOf(shiftX)+x];
            
            //Insert into window from mimo
            Bit#(addrwidth) remainingPixelsInRow = resolutionX-windowX0-fromInteger(valueOf(windowsizeX));
            Bit#(addrwidth) extractMIMOSpan = min(fromInteger(valueOf(shiftX)),remainingPixelsInRow);
            $display("remainingPixelsInRow:%d / extractMIMOSpan:%d / shiftX:%d",remainingPixelsInRow,extractMIMOSpan,valueOf(shiftX));
            UInt#(addrwidth) extractMIMOSpanUInt = unpack(extractMIMOSpan);
            LUInt#(mimoInOutMax) extractMIMOSpanLUInt = truncate(extractMIMOSpanUInt);
            for(Integer row=0; row<valueOf(windowsizeY); row=row+1)
                begin                
                Vector#(mimoInOutMax, UInt#(8)) extractRow = rowBuffers[row].first;
                rowBuffers[row].deq(extractMIMOSpanLUInt);
                rowBuffersOutSize[row] <= rowBuffersOutSize[row] + extractMIMOSpan;
                for(Integer x=0; x<valueOf(shiftX); x=x+1)
                    windowStorage[row][fromInteger(valueOf(windowsizeX))-fromInteger(valueOf(shiftX))+fromInteger(x)] <= extractRow[x];
                end
            $display("X0:%d - nextX0:%d -- Step X  nesResX %d <= resX%d",windowX0,nextWindowX0,necessaryResolutionX,resolutionX);
            $display("extractMIMOSpan:%d / windowsizeX:%d / shiftX:%d",extractMIMOSpan,valueOf(windowsizeX),valueOf(shiftX));
            windowX0 <= nextWindowX0;
            validWindowSizeX <= extractMIMOSpan+fromInteger(valueOf(windowsizeX)-valueOf(shiftX));
            end
        else
            begin
            if(lastRows)
                windowState <= End;
            else
                begin
                $display("Set to YShift");
                windowState <= YShift;
                windowY0 <= windowY0+fromInteger(valueOf(shiftY));
                if(windowY0+fromInteger(valueOf(windowsizeY)) >= resolutionY)
                    lastRows <= True;
                end
            $display("Y0:%d - nextY0:%d -- Step Y %d",windowY0,windowY0+fromInteger(valueOf(shiftY)),resolutionY);
            end
        return tuple3(validWindowSizeX,validWindowSizeY,_window);
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

        validConfig <= valid;
        /*
        for(Integer i=0; i<valueOf(windowsizeY); i=i+1)
            begin
            initialFillCount[i] <=  resolutionX*(fromInteger(valueOf(i)+1));
            end
        */
        
        return valid;
    endmethod
    
    interface axi4Fab = axiDataRd.fab;
    
endmodule

endpackage
