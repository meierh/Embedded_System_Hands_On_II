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

typedef 1080 MAXIMAGEWIDTH;
typedef 1 SIMULTROWS;

// must be SIMULTROWS+maxPad(8)
typedef 9 IMAGEDATAHEIGHT;
// must be MAXIMAGEWIDTH+maxPad(8)
typedef 1088 IMAGEDATAWIDTH;

typedef 8 AXIIMAGEADDRWIDTH;
typedef 128 AXIIMAGEDATAWIDTH;
typedef 1 AXIIMAGEIDWIDTH;
typedef 1 AXIIMAGEUSERWIDTH;

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
    Reg#(UInt#(AXICONFIGDATAWIDTH)) resolutionX <- mkReg(0);
    Reg#(UInt#(AXICONFIGDATAWIDTH)) resolutionY <- mkReg(0);
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
                    resolutionX <= unpack(d);
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
                    resolutionY <= unpack(d);
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
    Reg#(UInt#(AXICONFIGDATAWIDTH)) _resolutionX <- mkReg(0);
    Reg#(UInt#(AXICONFIGDATAWIDTH)) _resolutionY <- mkReg(0);
    Reg#(FilterType) _kernelSize <- mkReg(Sobel3);
    Reg#(FilterStatus) _filteringStatus <- mkReg(Idle);

    rule startComputation (executeCmd);
        _inputImageAddress <= inputImageAddress;
        _outputImageAddress <= outputImageAddress;
        _resolutionX <= resolutionX;
        _resolutionY <= resolutionY;
        _kernelSize <= kernelSize;
        _filteringStatus <= Prepared;
        executeCmd <= False;
        topLevelStatus <= Execution;
    endrule
    
    
    //Vector#(IMAGEDATAHEIGHT,Vector#(IMAGEDATAWIDTH,Reg#(UInt#(8)))) imageData;
    Vector#(IMAGEDATAHEIGHT,Reg#(Vector#(IMAGEDATAWIDTH,UInt#(8)))) imageData;
    Vector#(IMAGEDATAHEIGHT,Reg#(UInt#(32))) imageData_ImageRowInd;
    for(Integer i=0; i<valueOf(IMAGEDATAHEIGHT); i=i+1)
    begin
        imageData[i] <- mkReg(replicate(0));
        imageData_ImageRowInd[i] <- mkReg(0);
    end
    
    
    Vector#(SIMULTROWS,Reg#(FilteredDataRegs)) filteredDataRegsStatus;
    Reg#(Bool) filteredDataFilled <- mkReg(False);
    Vector#(SIMULTROWS,Reg#(Tuple2#(UInt#(32),Vector#(MAXIMAGEWIDTH,UInt#(8))))) filteredData;
    for(Integer i=0; i<valueOf(SIMULTROWS); i=i+1)
    begin
        filteredDataRegsStatus[i] <- mkReg(Empty);
        filteredData[i] <- mkReg(tuple2(0,replicate(0)));
    end

    SobelOperator op <- mkSobelOperator();
    Vector#(IMAGEDATAWIDTH,SobelOperator) computeCores = replicate(op);
    
    rule shiftUp;
        for(Integer i=valueOf(SIMULTROWS); i<valueOf(IMAGEDATAHEIGHT); i=i+1)
        begin
            imageData[i-valueOf(SIMULTROWS)] <= imageData[i];
            imageData_ImageRowInd[i-valueOf(SIMULTROWS)] <= imageData_ImageRowInd[i];
        end
    endrule
    
    
    // Return filtered Data
    Reg#(int) rowInd <- mkReg(0);
    Reg#(int) colInd <- mkReg(0);
    Reg#(SendPhase) sendPhase <- mkReg(PutAddr);
    Reg#(Bool) sendFilteredDataDone <- mkReg(False);
    rule sendResults (filteredDataFilled && !sendFilteredDataDone);
        if(sendPhase == PutAddr) // 
            begin
            if(rowInd < valueOf(SIMULTROWS))
                begin
                if(colInd < resolutionX)
                    begin
                        
                    end
                else // Step to next row
                    begin
                        colInd <= 0;
                        rowInd <= rowInd + 1;
                    end
                end
            else // Send of data chunk done
                begin
                    rowInd <= 0;
                    sendFilteredDataDone <= True;
                end
            end
        else
            begin
                let req = AXI4_Write_Rq_Addr{id:0,
            end
    endrule

/*************************************** Image Transfer************************************************/

    AXI4_Master_Rd#(AXIIMAGEADDRWIDTH,AXIIMAGEDATAWIDTH,AXIIMAGEIDWIDTH,AXIIMAGEUSERWIDTH) axiDataRd <- mkAXI4_Master_Rd(1,1,False);
    AXI4_Master_Wr#(AXIIMAGEADDRWIDTH,AXIIMAGEDATAWIDTH,AXIIMAGEIDWIDTH,AXIIMAGEUSERWIDTH) axiDataWr <- mkAXI4_Master_Wr(1,1,1,False);

/*************************************** Image Transfer************************************************/    
    interface axiC_rd  = axiConfigSlave.s_rd;
    interface axiC_wr  = axiConfigSlave.s_wr;
    
    interface axiD_rd = axiDataRd.fab;
    interface axiD_wr = axiDataWr.fab;
endmodule

endpackage
