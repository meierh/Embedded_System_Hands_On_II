package DCT;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import BlueAXI :: * ;
import AXI4_Types :: * ;
import AXIDCTBlockReader :: *;

typedef 8 AXICONFIGADDRWIDTH;
typedef 64 AXICONFIGDATAWIDTH;

typedef 64 AXIIMAGEADDRWIDTH;
typedef 8 AXIIMAGEDATAWIDTH;
typedef 1 AXIIMAGEIDWIDTH;
typedef 1 AXIIMAGEUSERWIDTH;

typedef 180 MAXIMAGEWIDTH;
typedef 1 SIMULTROWS;

typedef 10 SLIDINGWINDOWX;
typedef 10 SLIDINGWINDOWY;
typedef 16 SLIDINGWINDOWXPAD;
typedef 16 SLIDINGWINDOWYPAD;

typedef enum {
    Configuration = 3'b000,
    Execution = 3'b001,
    Finished = 3'b010
    } TopLevelStatusInfo deriving (Bits,Eq);

interface DCT;
    (*prefix = "AXI_Config"*) interface AXI4_Lite_Slave_Rd_Fab#(AXICONFIGADDRWIDTH, AXICONFIGDATAWIDTH) axiC_rd;
    (*prefix = "AXI_Config"*) interface AXI4_Lite_Slave_Wr_Fab#(AXICONFIGADDRWIDTH, AXICONFIGDATAWIDTH) axiC_wr;
    
    (*prefix = "AXI_Image"*) interface AXI4_Master_Rd_Fab#(AXIIMAGEADDRWIDTH,AXIIMAGEDATAWIDTH,AXIIMAGEIDWIDTH,
                                                           AXIIMAGEUSERWIDTH) axiD_rd;
    (*prefix = "AXI_Image"*) interface AXI4_Master_Wr_Fab#(AXIIMAGEADDRWIDTH,AXIIMAGEDATAWIDTH,AXIIMAGEIDWIDTH,
                                                           AXIIMAGEUSERWIDTH) axiD_wr;
endinterface

module mkDCT(DCT);

/******************************* Configuration Registers **********************************************/
    Reg#(Bit#(AXICONFIGDATAWIDTH)) inputImageAddress <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) outputImageAddress <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) numberBlocks <- mkReg(0);
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
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeNumberBlocks;    
    function Action writeNumberBlocksFunc (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    numberBlocks <= d;
                    /*
                    if(topLevelStatus==Unconfigured)
                        resolutionXValid <= True;
                    */
                endaction
    endfunction : writeNumberBlocksFunc
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeNumberBlocksStruct;
    writeNumberBlocksStruct = WriteOperation { index:24, fun:writeNumberBlocksFunc };
    writeNumberBlocks = tagged Write writeNumberBlocksStruct;
    configurationOperations = List::cons(writeNumberBlocks,configurationOperations);
    
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
    writeExecuteCmdStruct = WriteOperation { index:32, fun : writeExecuteCmd };
    writeExecuteCommand = tagged Write writeExecuteCmdStruct;
    configurationOperations = List::cons(writeExecuteCommand,configurationOperations);
    
    Reg#(Bit#(AXICONFIGDATAWIDTH)) _inputImageAddress <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) _outputImageAddress <- mkReg(0);
    Reg#(Bit#(AXICONFIGDATAWIDTH)) _numberBlocks <- mkReg(0);
    
    rule startComputation (executeCmd);
    // TODO: Check for valid values
        _inputImageAddress <= inputImageAddress;
        _outputImageAddress <= outputImageAddress;
        _numberBlocks <= numberBlocks;
        executeCmd <= False;
        topLevelStatus <= Execution;
    endrule
    
    AXIDCTBlockReader#(AXICONFIGDATAWIDTH,4) readBlocks <- mkAXIDCTBlockReader();
    
    interface axiD_rd = readBlocks.axi4Fab;
    interface axiD_wr = axiDataWr.fab;
endmodule

endpackage
