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
typedef 32 AXICONFIGDATAWIDTH;

typedef 128 AXIIMAGEDATAWIDTH;
typedef 16 AXIIMAGEDATALEN;

typedef 80 FILTEREDDATAWIDTH;
typedef 10 FILTEREDWIDTH;

typedef 32 MAXAXIBURSTLEN;

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
    Reg#(Bit#(AXICONFIGDATAWIDTH)) chunksCountX <- mkReg(0);
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
                endaction
    endfunction : writeOutputAddr
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeOutputAddrStruct;
    writeOutputAddrStruct = WriteOperation { index:16, fun:writeOutputAddr };
    writeOutputAddress = tagged Write writeOutputAddrStruct;
    configurationOperations = List::cons(writeOutputAddress,configurationOperations);
    
// Write chunksCountX command operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeChunksCountX;    
    function Action writeChunksCountXSize (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    chunksCountX <= d;
                endaction
    endfunction : writeChunksCountXSize
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeChunksCountXStruct;
    writeChunksCountXStruct = WriteOperation { index:24, fun:writeChunksCountXSize };
    writeChunksCountX = tagged Write writeChunksCountXStruct;
    configurationOperations = List::cons(writeChunksCountX,configurationOperations);
    
// Write resolutionY command operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeResolutionY;    
    function Action writeResolutionYSize (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    resolutionY <= d;
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
    AXIGrayscaleReader#(AXICONFIGDATAWIDTH,AXIIMAGEDATAWIDTH,MAXAXIBURSTLEN) reader <- mkAXIGrayscaleReader();
    AXIGrayscaleWriter#(AXICONFIGDATAWIDTH,AXIIMAGEDATAWIDTH,FILTEREDWIDTH,MAXAXIBURSTLEN) writer <- mkAXIGrayscaleWriter();
    
    Vector#(FILTEREDWIDTH,SobelOperator) filterCores = newVector;
    for(Integer x=0; x<valueOf(FILTEREDDATAWIDTH)/8; x=x+1)
        filterCores[x] <- mkSobelOperator();
        //filterCores[x] <- mkSobelPassthrough();
        
    rule startComputation (topLevelStatus==Configuration && executeCmd);
        $display("Start Computation chunksCountX:%d, resolutionY:%d inputImageAddress:%d outputImageAddress:%d topLevelStatus:%d",chunksCountX,resolutionY,inputImageAddress,outputImageAddress,topLevelStatus);
        reader.configure(inputImageAddress,chunksCountX,resolutionY);
        Bit#(AXICONFIGDATAWIDTH) numberChunks = chunksCountX*(resolutionY-6);
        writer.configure(outputImageAddress,numberChunks);
        for(Integer x=0; x<valueOf(FILTEREDDATAWIDTH)/8; x=x+1)
            filterCores[x].configure(kernelSize);
        topLevelStatus <= Execution;
        executeCmd <= False;
    endrule
        
    rule insertStencils;
        //$display("Insert stencil");
        Vector#(7,Vector#(AXIIMAGEDATALEN,Bit#(8))) _window <- reader.getWindow();
        for(Integer offsetX=0; offsetX<valueOf(FILTEREDDATAWIDTH)/8; offsetX=offsetX+1)
            begin
            Vector#(7,Vector#(7,UInt#(8))) stencil = newVector;
            for(Integer stencilX=0; stencilX<7; stencilX=stencilX+1)
                begin
                Integer stencilXWind = offsetX + stencilX;
                for(Integer stencilY=0; stencilY<7; stencilY=stencilY+1)
                    stencil[stencilY][stencilX] = unpack(_window[stencilY][stencilXWind]);
                end
            filterCores[offsetX].insertStencil(stencil);
            end        
    endrule
    
    rule extractStencils;
        //$display("Extract stencil");
        Vector#(FILTEREDWIDTH,Bit#(8)) filteredValues = newVector;
        for(Integer offsetX=0; offsetX<valueOf(FILTEREDDATAWIDTH)/8; offsetX=offsetX+1)
            begin
            UInt#(8) oneFilteredPixel <- filterCores[offsetX].getGradMag();
            filteredValues[offsetX] = pack(oneFilteredPixel);
            end
        //$display("Extract Chunk %d %d %d %d %d %d %d %d %d %d",filteredValues[0],filteredValues[1],filteredValues[2],filteredValues[3],filteredValues[4],filteredValues[5],filteredValues[6],filteredValues[7],filteredValues[8],filteredValues[9]);

        writer.setWindow(filteredValues);
    endrule
    
    rule finishExec(topLevelStatus==Execution && writer.done());
        $display("------------------------Sobel Done---------------------------");
        topLevelStatus <= Configuration;
    endrule

/*************************************** Image Transfer************************************************/    
    interface axiC_rd  = axiConfigSlave.s_rd;
    interface axiC_wr  = axiConfigSlave.s_wr;
    
    interface axiD_rd = reader.axi4Fab;
    interface axiD_wr = writer.axi4Fab;
endmodule

endpackage
