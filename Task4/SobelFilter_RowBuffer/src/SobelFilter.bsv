package SobelFilter;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import BlueAXI :: * ;
import AXI4_Types :: * ;
import SobelTypes :: * ;
import AXIGrayscaleReader :: *;
import AXIGrayscaleWriter :: *;
import SobelOperator :: * ;


// must be equal to AXICONFIGDATAWIDTH
typedef 8 AXICONFIGADDRWIDTH;
typedef 64 AXICONFIGDATAWIDTH;
typedef 128 AXIIMAGEDATAWIDTH;

typedef 22 WINDOWSIZEX;
typedef 7 WINDOWSIZEY;
typedef 16 SHIFTX;
typedef 3 PAD;

typedef 2000 MAXRESOLUTIONX;

typedef 256 MAXAXIBEATLEN;

//(* always_ready, always_enabled *)
interface SobelFilter;
// Add custom interface definitions
    (*prefix = "AXI_Config"*) interface AXI4_Lite_Slave_Rd_Fab#(AXICONFIGADDRWIDTH, AXICONFIGDATAWIDTH) axiC_rd;
    (*prefix = "AXI_Config"*) interface AXI4_Lite_Slave_Wr_Fab#(AXICONFIGADDRWIDTH, AXICONFIGDATAWIDTH) axiC_wr;
    
    (*prefix = "AXI_Image"*) interface AXI4_Master_Rd_Fab#(AXICONFIGDATAWIDTH,AXIIMAGEDATAWIDTH,1,0) axiD_rd;
    (*prefix = "AXI_Image"*) interface AXI4_Master_Wr_Fab#(AXICONFIGDATAWIDTH,AXIIMAGEDATAWIDTH,1,0) axiD_wr;
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
                    Bit#(2) lastBits = d[1:0];
                    case (lastBits)
                        pack(Sobel3) : kernelSize <= Sobel3;
                        pack(Sobel5) : kernelSize <= Sobel5;
                        pack(Sobel7) : kernelSize <= Sobel7;
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
    Vector#(SHIFTX,SobelOperator) filterCores = newVector;
    for(Integer x=0; x<valueOf(SHIFTX); x=x+1)
        filterCores[x] <- mkSobelPassthrough();
    //Reg#(FilterStatus) _filteringStatus <- mkReg(Idle);
    Reg#(Computephase) computePhase <- mkReg(LoadAndFilter);
    
    AXIGrayscaleReader#(AXICONFIGDATAWIDTH,AXIIMAGEDATAWIDTH,WINDOWSIZEX,WINDOWSIZEY,SHIFTX,MAXRESOLUTIONX,WINDOWSIZEX,MAXAXIBEATLEN) imageReader <- mkAXIGrayscaleReader();
    
    AXIGrayscaleWriter#(AXICONFIGDATAWIDTH,AXIIMAGEDATAWIDTH,SHIFTX,SHIFTX,MAXRESOLUTIONX) imageWriter <- mkAXIGrayscaleWriter();
    
    rule startComputation (topLevelStatus==Configuration && executeCmd);
        if(resolutionX <= fromInteger(valueOf(MAXRESOLUTIONX)))
            begin
            _inputImageAddress <= inputImageAddress;
            _outputImageAddress <= outputImageAddress;
            _resolutionX <= resolutionX;
            _resolutionY <= resolutionY;
            _kernelSize <= kernelSize;
            //_filteringStatus <= Prepared;
            topLevelStatus <= Execution;            
            for(Integer x=0; x<valueOf(SHIFTX); x=x+1)
                filterCores[x].configure(_kernelSize);
            end
        executeCmd <= False;
    endrule
        
    rule insertStencils;
        Tuple3#(Bit#(AXICONFIGDATAWIDTH),Bit#(AXICONFIGDATAWIDTH),Vector#(WINDOWSIZEY,Vector#(WINDOWSIZEX,UInt#(8)))) windowData <- imageReader.getWindow();
        Bit#(AXICONFIGDATAWIDTH) validSpan = tpl_1(windowData);
        Vector#(WINDOWSIZEY,Vector#(WINDOWSIZEX,UInt#(8))) windowImg = tpl_3(windowData);
        for(Integer x=0; x<valueOf(SHIFTX); x=x+1)
            begin
            Vector#(7,Vector#(7,UInt#(8))) stencil = newVector;
            for(Integer stencilX=0; stencilX<7; stencilX=stencilX+1)
                begin
                Integer stencilXWind = x + stencilX;
                for(Integer stencilY=0; stencilY<7; stencilY=stencilY+1)
                    stencil[stencilY][stencilX] = windowImg[stencilY][stencilXWind];
                end
            if(validSpan < (fromInteger(x)+7))
                filterCores[x].insertStencil(tuple2(stencil,True));
            else
                filterCores[x].insertStencil(tuple2(stencil,False));
            end        
    endrule
    
    rule extractStencils;
        Vector#(SHIFTX,UInt#(8)) filteredValues = newVector;
        Bit#(AXICONFIGDATAWIDTH) validSpan = fromInteger(valueOf(SHIFTX));
        for(Integer x=0; x<valueOf(SHIFTX); x=x+1)
            begin
            Tuple2#(UInt#(8),Bool) oneFilteredPixel <- filterCores[x].getGradMag();
            if(!tpl_2(oneFilteredPixel))
                validSpan = min(fromInteger(x),validSpan);
            filteredValues[x] = tpl_1(oneFilteredPixel);
            end
        imageWriter.setWindow(tuple2(validSpan,filteredValues));
    endrule

/*************************************** Image Transfer************************************************/    
    interface axiC_rd  = axiConfigSlave.s_rd;
    interface axiC_wr  = axiConfigSlave.s_wr;
    
    interface axiD_rd = imageReader.axi4Fab;
    interface axiD_wr = imageWriter.axi4Fab;
endmodule

endpackage
