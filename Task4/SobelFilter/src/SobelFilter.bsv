package SobelFilter;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import BlueAXI :: * ;
import AXI4_Types :: * ;
import SobelTypes :: * ;
import SobelOperator :: * ;

typedef 8 AXICONFIGADDRWIDTH;
typedef 64 AXICONFIGDATAWIDTH;

typedef 180 MAXIMAGEWIDTH;
typedef 1 SIMULTROWS;

typedef 10 SLIDINGWINDOWX;
typedef 10 SLIDINGWINDOWY;
typedef 16 SLIDINGWINDOWXPAD;
typedef 16 SLIDINGWINDOWYPAD;

typedef 4 MAXPAD;

// must be equal to SIMULTROWS+maxPad(8)
//typedef 9 IMAGEDATAHEIGHT;
// must be equal to  MAXIMAGEWIDTH+maxPad(8)
//typedef 188 IMAGEDATAWIDTH;

// must be equal to AXICONFIGDATAWIDTH
typedef 64 AXIIMAGEADDRWIDTH;
typedef 8 AXIIMAGEDATAWIDTH;
typedef 1 AXIIMAGEIDWIDTH;
typedef 1 AXIIMAGEUSERWIDTH;

typedef 256 MAXAXIBEATLEN;

typedef 2 FIFODEPTH;

typedef struct {Bit#(AXICONFIGDATAWIDTH) x; Bit#(AXICONFIGDATAWIDTH) y;} COORD deriving (Bits);
typedef Vector#(SLIDINGWINDOWYPAD,Vector#(SLIDINGWINDOWXPAD,UInt#(8))) WINDOWDATA_PAD;
typedef struct{COORD x0y0; WINDOWDATA_PAD data;} WINDOW_IN deriving (Bits);
typedef Vector#(SLIDINGWINDOWY,Vector#(SLIDINGWINDOWX,UInt#(8))) WINDOWDATA;
typedef struct{COORD x0y0; WINDOWDATA data;} WINDOW_OUT deriving (Bits);

//(* always_ready, always_enabled *)
interface SobelFilter;
// Add custom interface definitions
    (*prefix = "AXI_Config"*) interface AXI4_Lite_Slave_Rd_Fab#(AXICONFIGADDRWIDTH, AXICONFIGDATAWIDTH) axiC_rd;
    (*prefix = "AXI_Config"*) interface AXI4_Lite_Slave_Wr_Fab#(AXICONFIGADDRWIDTH, AXICONFIGDATAWIDTH) axiC_wr;
    
    (*prefix = "AXI_Image"*) interface AXI4_Master_Rd_Fab#(AXIIMAGEADDRWIDTH,AXIIMAGEDATAWIDTH,AXIIMAGEIDWIDTH,
                                                           AXIIMAGEUSERWIDTH) axiD_rd;
    (*prefix = "AXI_Image"*) interface AXI4_Master_Wr_Fab#(AXIIMAGEADDRWIDTH,AXIIMAGEDATAWIDTH,AXIIMAGEIDWIDTH,
                                                           AXIIMAGEUSERWIDTH) axiD_wr;
endinterface

module mkSobelFilter(SobelFilter);

/******************************* Configuration Registers **********************************************/
    Reg#(Bit#(AXICONFIGDATAWIDTH)) inputImageAddress <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) outputImageAddress <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) resolutionX <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) resolutionY <- mkReg(0);
    Reg#(FilterType) kernelSize <- mkReg(Sobel3);
    Reg#(Bool) executeCmd <- mkReg(False);
    Reg#(TopLevelStatusInfo) topLevelStatus <- mkReg(Configuration);
    
/************************************ AXI Configuration ***********************************************/
    List#(RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH)) configurationOperations;
    
// Read status operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) readStatus;
    function ActionValue#(Bit#(AXICONFIGDATAWIDTH)) readStat (AXI4_Lite_Prot p);
              actionvalue
                    return extend(pack(topLevelStatus));
               endactionvalue
    endfunction : readStat
    ReadOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) readStatStruct;
    readStatStruct = ReadOperation { index:0, fun:readStat };
    readStatus = tagged Read readStatStruct;
    configurationOperations = List::replicate(1,readStatus);
    
// Write input address operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeInputAddress;    
    function Action writeInputAddr (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    inputImageAddress <= unpack(d);
                    /*
                    if(topLevelStatus==Unconfigured)
                        inputImageAddressValid <= True;
                    */
                endaction
    endfunction : writeInputAddr
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeInputAddrStruct;
    writeInputAddrStruct = WriteOperation { index:8, fun:writeInputAddr };
    writeInputAddress = tagged Write writeInputAddrStruct;
    configurationOperations = List::cons(writeInputAddress,configurationOperations);
    
// Write output address operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeOutputAddress;    
    function Action writeOutputAddr (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    outputImageAddress <= unpack(d);
                    /*
                    if(topLevelStatus==Unconfigured)
                        outputImageAddressValid <= True;
                    */
                endaction
    endfunction : writeOutputAddr
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeOutputAddrStruct;
    writeOutputAddrStruct = WriteOperation { index:16, fun:writeOutputAddr };
    writeOutputAddress = tagged Write writeOutputAddrStruct;
    configurationOperations = List::cons(writeOutputAddress,configurationOperations);
    
// Write resolutionX command operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeResolutionX;    
    function Action writeResolutionXSize (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    resolutionX <= d;
                    /*
                    if(topLevelStatus==Unconfigured)
                        resolutionXValid <= True;
                    */
                endaction
    endfunction : writeResolutionXSize
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeResolutionXStruct;
    writeResolutionXStruct = WriteOperation { index:24, fun:writeResolutionXSize };
    writeResolutionX = tagged Write writeResolutionXStruct;
    configurationOperations = List::cons(writeResolutionX,configurationOperations);
    
// Write resolutionY command operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeResolutionY;    
    function Action writeResolutionYSize (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    resolutionY <= d;
                    /*
                    if(topLevelStatus==Unconfigured)
                        resolutionYValid <= True;
                    */
                endaction
    endfunction : writeResolutionYSize
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeResolutionYStruct;
    writeResolutionYStruct = WriteOperation { index:32, fun:writeResolutionYSize };
    writeResolutionY = tagged Write writeResolutionYStruct;
    configurationOperations = List::cons(writeResolutionY,configurationOperations);
    
// Write kernel size operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeKernelSize;    
    function Action writeKernelSz (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    Bit#(4) lastBits = d[3:0];
                    case (lastBits)
                        pack(Sobel3) : kernelSize <= Sobel3;
                        pack(Sobel5) : kernelSize <= Sobel5;
                        pack(Sobel7) : kernelSize <= Sobel7;
                        pack(Sobel9) : kernelSize <= Sobel9;
                        default : kernelSize <= Sobel3;
                    endcase
                endaction
    endfunction : writeKernelSz
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeKernelStruct;
    writeKernelStruct = WriteOperation { index:40, fun:writeKernelSz };
    writeKernelSize = tagged Write writeKernelStruct;
    configurationOperations = List::cons(writeKernelSize,configurationOperations);
    
// Write execution command operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeExecuteCommand;    
    function Action writeExecuteCmd (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    if(topLevelStatus==Configuration)
                        executeCmd <= True;
                    else
                        executeCmd <= False;
                endaction
    endfunction : writeExecuteCmd
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeExecuteCmdStruct;
    writeExecuteCmdStruct = WriteOperation { index:48, fun : writeExecuteCmd };
    writeExecuteCommand = tagged Write writeExecuteCmdStruct;
    configurationOperations = List::cons(writeExecuteCommand,configurationOperations);
    
    // Construct AXI Slave  
    GenericAxi4LiteSlave#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) axiConfigSlave <- mkGenericAxi4LiteSlave(configurationOperations,1,1);

/******************************************************************************************************/


/********************************* Image Filtering Registers ******************************************/
    Reg#(Bit#(AXICONFIGDATAWIDTH)) _inputImageAddress <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) _outputImageAddress <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) _resolutionX <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) _resolutionY <- mkReg(0);
    Reg#(FilterType) _kernelSize <- mkReg(Sobel3);
    Reg#(FilterStatus) _filteringStatus <- mkReg(Idle);
    
    Reg#(Computephase) computePhase <- mkReg(LoadAndFilter);
    
    // Main Computation Filtering Loop
    Reg#(COORD) windowCoord <- mkReg(COORD{x:0,y:0});    
    
    // Read data from AXI connect
    AXI4_Master_Rd#(AXIIMAGEADDRWIDTH,AXIIMAGEDATAWIDTH,AXIIMAGEIDWIDTH,AXIIMAGEUSERWIDTH) axiDataRd <- mkAXI4_Master_Rd(1,1,False);
    
    Reg#(Bool) axi_readImage_Done <- mkReg(True);
    Reg#(WINDOW_IN) axi_readImage <- mkRegU();
    
    FIFO#(WINDOW_IN) imageInFIFO <- mkSizedFIFO(valueOf(FIFODEPTH));

    Reg#(Bit#(AXICONFIGDATAWIDTH)) localX_load <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) localY_load <- mkReg(0);
    Reg#(Bit#(8)) reqBeats_load <- mkReg(0);
    Reg#(Bit#(8)) countBeats_load <- mkReg(0);
    Reg#(Loadphase) loadPhase <- mkReg(Request);
    
    rule loadViaAXI (topLevelStatus==Execution && !axi_readImage_Done);
        Bit#(AXICONFIGDATAWIDTH) globalX = localX_load + windowCoord.x;
        Bit#(AXICONFIGDATAWIDTH) globalY = localY_load + windowCoord.y;
        if(localY_load < fromInteger(valueOf(SLIDINGWINDOWYPAD)) && globalY < resolutionY)
            begin
            if(loadPhase == Request)
                begin
                Bit#(AXICONFIGDATAWIDTH) reqAddr = _inputImageAddress + globalY*resolutionX + globalX;
                Bit#(AXICONFIGDATAWIDTH) reqSpan = _resolutionX - globalX;
                if (reqSpan > fromInteger(valueOf(MAXAXIBEATLEN)))
                    reqSpan = fromInteger(valueOf(MAXAXIBEATLEN));
                Bit#(8) beats = truncate(reqSpan-1);
                reqBeats_load <= beats;
                axi4_read_data(axiDataRd,reqAddr,unpack(beats));
                loadPhase <= Read;
                countBeats_load <= 0;
                end
            else // loadPhase == Read
                begin
                Bit#(AXIIMAGEDATAWIDTH) data <- axi4_read_response(axiDataRd);
                axi_readImage.data[localY_load][localX_load] <= unpack(data);
                if(countBeats_load==reqBeats_load) // End of burst
                    begin
                    loadPhase <= Request;
                    if(localX_load < fromInteger(valueOf(SLIDINGWINDOWXPAD))) // Inside sliding window row
                        localX_load <= localX_load + 1;
                    else // End of sliding window row
                        localX_load <= 0;
                        localY_load <= localY_load + 1;
                    end
                else // Inside Burst
                    localX_load <= localX_load + 1;
                    countBeats_load <= countBeats_load + 1;
                end
            end
        else // Insert window into imageInFIFO and move window
            begin
                WINDOW_IN completeWindow = axi_readImage;
                completeWindow.x0y0 = windowCoord;
                imageInFIFO.enq(completeWindow);
                localX_load <= 0;
                localY_load <= 0;
                loadPhase <= Request;
                COORD nextWindowCoord = windowCoord;
                nextWindowCoord.y = nextWindowCoord.y + fromInteger(valueOf(SLIDINGWINDOWY));
                if(!(nextWindowCoord.y < resolutionY)) // Window moves up and in x dir
                    begin
                    nextWindowCoord.x = nextWindowCoord.x + fromInteger(valueOf(SLIDINGWINDOWX));
                    nextWindowCoord.y = 0;
                    if(!(nextWindowCoord.x < resolutionX)) // End of image reached
                        axi_readImage_Done <= True;
                        nextWindowCoord = COORD{x:0,y:0};
                    end
                windowCoord <= nextWindowCoord;                
            end
    endrule

    
    // Filter image window
    FIFO#(COORD) coordPipe <- mkSizedFIFO(valueOf(FIFODEPTH));
    Vector#(SLIDINGWINDOWY,Vector#(SLIDINGWINDOWX,SobelOperator)) filterCores = newVector;
    for(Integer localY=0; localY<valueOf(SLIDINGWINDOWY); localY=localY+1)
        for(Integer localX=0; localX<valueOf(SLIDINGWINDOWX); localX=localX+1)
            filterCores[localY][localX] <- mkSobelOperator();

    // Push window into filter cores
    rule inputImageInFilter;
        WINDOW_IN window = imageInFIFO.first;
        imageInFIFO.deq;
        coordPipe.enq(window.x0y0);
        for(Integer windowY=0; windowY<valueOf(SLIDINGWINDOWY); windowY=windowY+1)
            for(Integer windowX=0; windowX<valueOf(SLIDINGWINDOWX); windowX=windowX+1)
                begin
                Vector#(7,Vector#(7,UInt#(8))) stencil;// = newVector;
                for(Integer localY=0; localY<7; localY=localY+1)
                    for(Integer localX=0; localX<7; localX=localX+1)
                        begin
                        Integer globalWindowY = windowY + localY;
                        Integer globalWindowX = windowX + localX;
                        stencil[localY][localX] = window.data[globalWindowX][globalWindowY];
                        end
                filterCores[windowY][windowX].insertStencil(stencil);
                end
    endrule
    
    // Pull results out of filter cores
    FIFO#(WINDOW_OUT) filterResultOutFIFO <- mkSizedFIFO(valueOf(FIFODEPTH));
    
    rule pullDataFromFilterCores;
        COORD coords = coordPipe.first;
        coordPipe.deq;
        WINDOW_OUT filteredRes;
        filteredRes.x0y0 = coords;
        for(Integer windowY=0; windowY<valueOf(SLIDINGWINDOWY); windowY=windowY+1)
            for(Integer windowX=0; windowX<valueOf(SLIDINGWINDOWX); windowX=windowX+1)
                begin
                UInt#(8) filteredPx <- filterCores[windowY][windowX].getGradMag();
                filteredRes.data[windowY][windowX] = filteredPx;
                end
        filterResultOutFIFO.enq(filteredRes);
    endrule
    
    //Send filtered results
    Reg#(Bool) axi_sendfilteredImage_Valid <- mkReg(False);
    Reg#(WINDOW_OUT) axi_sendfilteredImage <- mkRegU();
    
    AXI4_Master_Wr#(AXIIMAGEADDRWIDTH,AXIIMAGEDATAWIDTH,AXIIMAGEIDWIDTH,AXIIMAGEUSERWIDTH) axiDataWr <- mkAXI4_Master_Wr(1,1,1,False);
    
    Reg#(Bit#(AXICONFIGDATAWIDTH)) localX_send <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) localY_send <- mkReg(0);
    Reg#(Bit#(8)) reqBeats_send <- mkReg(0);
    Reg#(Bit#(8)) countBeats_send <- mkReg(0);
    Reg#(Sendphase) sendPhase <- mkReg(Request);
    
    rule sendViaAXI (topLevelStatus==Execution);
        if(axi_sendfilteredImage_Valid)
            begin
            Bit#(AXICONFIGDATAWIDTH) globalX = localX_send + axi_sendfilteredImage.x0y0.x;
            Bit#(AXICONFIGDATAWIDTH) globalY = localY_send + axi_sendfilteredImage.x0y0.y;
            if(sendPhase == Request)
                begin
                Bit#(AXICONFIGDATAWIDTH) reqAddr = _outputImageAddress + globalY*resolutionX + globalX;
                Bit#(AXICONFIGDATAWIDTH) reqSpan = fromInteger(valueOf(SLIDINGWINDOWX)) - localX_send;
                reqSpan = min(reqSpan,resolutionX - globalX);
                reqSpan = min(reqSpan,fromInteger(valueOf(MAXAXIBEATLEN))-1);
                Bit#(8) beats = truncate(reqSpan);
                reqBeats_send <= beats;
                axi4_write_addr(axiDataWr,reqAddr,unpack(beats));
                sendPhase <= Write;
                countBeats_send <= 0;
                end
            else // sendPhase == Write
                begin
                UInt#(8) filteredData = axi_sendfilteredImage.data[localY_send][localX_send];
                Bit#(TDiv#(AXIIMAGEDATAWIDTH, 8)) byte_enable = 0;
                byte_enable = invert(byte_enable);
                Bool last = False;
                if(countBeats_send==reqBeats_send) // End of burst
                    begin
                    last = True;
                    sendPhase <= Request;
                    if(!(localX_send < fromInteger(valueOf(SLIDINGWINDOWX)))) // Row completely send
                        begin
                        localX_send <= 0;
                        if(localY_send+1 < fromInteger(valueOf(SLIDINGWINDOWY)))
                            localY_send <= localY_send + 1;
                        else // All Rows completely send
                            begin
                            axi_sendfilteredImage_Valid <= False;
                            localY_send <= 0;
                            end
                        end
                    end
                else // Inside burst
                    begin
                    countBeats_send <= countBeats_send + 1;
                    localX_send <= localX_send + 1;
                    end
                axi4_write_data(axiDataWr,pack(filteredData),byte_enable,last);
                end
            end
        else // Get next image window
            begin
                WINDOW_OUT axi_sendWindow = filterResultOutFIFO.first;
                filterResultOutFIFO.deq;
                axi_sendfilteredImage <= axi_sendWindow;
                axi_sendfilteredImage_Valid <= True;
                localX_send <= 0;
                localY_send <= 0;
                sendPhase <= Request;             
            end
    endrule
    
    rule startComputation (executeCmd);
    // TODO: Check for valid values
        _inputImageAddress <= inputImageAddress;
        _outputImageAddress <= outputImageAddress;
        _resolutionX <= resolutionX;
        _resolutionY <= resolutionY;
        _kernelSize <= kernelSize;
        _filteringStatus <= Prepared;
        executeCmd <= False;
        topLevelStatus <= Execution;
        for(Integer localY=0; localY<valueOf(SLIDINGWINDOWY); localY=localY+1)
            for(Integer localX=0; localX<valueOf(SLIDINGWINDOWX); localX=localX+1)
                filterCores[localY][localX].configure(_kernelSize);
    endrule
    

/*************************************** Image Transfer************************************************/



    


/*************************************** Image Transfer************************************************/    
    interface axiC_rd  = axiConfigSlave.s_rd;
    interface axiC_wr  = axiConfigSlave.s_wr;
    
    interface axiD_rd = axiDataRd.fab;
    interface axiD_wr = axiDataWr.fab;
endmodule

endpackage
