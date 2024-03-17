package DCT;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import BlueAXI :: * ;
import AXI4_Types :: * ;
import AXIDCTBlockReader :: *;
import AXIDCTBlockWriter :: *;
import DCTOperator :: *;

typedef 8 AXICONFIGADDRWIDTH;
typedef 32 AXICONFIGDATAWIDTH;
typedef 128 AXIIMAGEDATAWIDTH;

typedef 1 SIMULTBLOCKS;

typedef enum {
    Configuration = 1'b0,
    Execution = 1'b1
    } TopLevelStatusInfo deriving (Bits,Eq);

interface DCT;
    (*prefix = "AXI_Config"*) interface AXI4_Lite_Slave_Rd_Fab#(AXICONFIGADDRWIDTH, AXICONFIGDATAWIDTH) axiC_rd;
    (*prefix = "AXI_Config"*) interface AXI4_Lite_Slave_Wr_Fab#(AXICONFIGADDRWIDTH, AXICONFIGDATAWIDTH) axiC_wr;
    
    (*prefix = "AXI_Image"*) interface AXI4_Master_Rd_Fab#(AXICONFIGDATAWIDTH,AXIIMAGEDATAWIDTH,1,0) axiD_rd;
    (*prefix = "AXI_Image"*) interface AXI4_Master_Wr_Fab#(AXICONFIGDATAWIDTH,AXIIMAGEDATAWIDTH,1,0) axiD_wr;
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
                    //$display("readStat: %d",topLevelStatus);
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
                    //$display("inputImageAddress: %d",d);
                endaction
    endfunction : writeInputAddr
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeInputAddrStruct;
    writeInputAddrStruct = WriteOperation { index:4, fun:writeInputAddr };
    writeInputAddress = tagged Write writeInputAddrStruct;
    configurationOperations = List::cons(writeInputAddress,configurationOperations);
    
// Write output address operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeOutputAddress;    
    function Action writeOutputAddr (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    outputImageAddress <= unpack(d);
                    //$display("outputImageAddress: %d",d);
                endaction
    endfunction : writeOutputAddr
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeOutputAddrStruct;
    writeOutputAddrStruct = WriteOperation { index:8, fun:writeOutputAddr };
    writeOutputAddress = tagged Write writeOutputAddrStruct;
    configurationOperations = List::cons(writeOutputAddress,configurationOperations);
    
// Write resolutionX command operation
    RegisterOperator#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeNumberBlocks;    
    function Action writeNumberBlocksFunc (Bit#(AXICONFIGDATAWIDTH) d, Bit#(TDiv#(AXICONFIGDATAWIDTH, 8)) s, AXI4_Lite_Prot p);
                action
                    numberBlocks <= d;
                    //$display("numberBlocks: %d",d);
                endaction
    endfunction : writeNumberBlocksFunc
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeNumberBlocksStruct;
    writeNumberBlocksStruct = WriteOperation { index:12, fun:writeNumberBlocksFunc };
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
                    //$display("topLevelStatus: %d",topLevelStatus);
                endaction
    endfunction : writeExecuteCmd
    WriteOperation#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) writeExecuteCmdStruct;
    writeExecuteCmdStruct = WriteOperation { index:16, fun : writeExecuteCmd };
    writeExecuteCommand = tagged Write writeExecuteCmdStruct;
    configurationOperations = List::cons(writeExecuteCommand,configurationOperations);
    
    GenericAxi4LiteSlave#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) configAXISlave <- mkGenericAxi4LiteSlave(configurationOperations,1,1);
    
/************************************** Execution *************************************************/
    AXIDCTBlockReader#(AXICONFIGDATAWIDTH,SIMULTBLOCKS) reader <- mkAXIDCTBlockReader();
    AXIDCTBlockWriter#(AXICONFIGDATAWIDTH,SIMULTBLOCKS) writer <- mkAXIDCTBlockWriter();
    Vector#(SIMULTBLOCKS,DCTOperator) dctOperators = newVector;
    for(Integer i=0; i<valueOf(SIMULTBLOCKS); i=i+1)
        dctOperators[i] <- mkDCTOperator();
        
    //Start Computation at execution Cmd
    rule startComputation (topLevelStatus==Configuration && executeCmd);
        $display("Start Computation numberBlocks:%d, inputImageAddress:%d outputImageAddress:%d topLevelStatus:%d",numberBlocks,inputImageAddress,outputImageAddress,topLevelStatus);
        executeCmd <= False;
        topLevelStatus <= Execution;
        reader.configure(inputImageAddress,numberBlocks);
        writer.configure(outputImageAddress,numberBlocks);
    endrule
    
    //Continuously feed blocks into dctOperators 
    rule insertData(topLevelStatus==Execution);
        Vector#(SIMULTBLOCKS,Vector#(8,Vector#(8,Bit#(8)))) multiBlocks <- reader.getMultiBlock();
        Vector#(SIMULTBLOCKS,Vector#(8,Vector#(8,UInt#(8)))) multiBlocksInt = newVector;
        for(Integer i=0; i<valueOf(SIMULTBLOCKS); i=i+1)
            for(Integer j=0; j<8; j=j+1)
                for(Integer k=0; k<8; k=k+1)
                    multiBlocksInt[i][j][k] = unpack(multiBlocks[i][j][k]);
        for(Integer i=0; i<valueOf(SIMULTBLOCKS); i=i+1)
            dctOperators[i].setBlock(multiBlocksInt[i]);
    endrule
    
    //Continuously pull blocks out of dctOperators 
    rule extractData(topLevelStatus==Execution);
        Vector#(SIMULTBLOCKS,Vector#(8,Vector#(8,Int#(16)))) multiBlocksInt = newVector;
        for(Integer i=0; i<valueOf(SIMULTBLOCKS); i=i+1)
            multiBlocksInt[i] <- dctOperators[i].getBlock();        
        Vector#(SIMULTBLOCKS,Vector#(8,Vector#(8,Bit#(16)))) multiBlocks = newVector;
        for(Integer i=0; i<valueOf(SIMULTBLOCKS); i=i+1)
            for(Integer j=0; j<8; j=j+1)
                for(Integer k=0; k<8; k=k+1)
                    multiBlocks[i][j][k] = pack(multiBlocksInt[i][j][k]);
        writer.setBlock(multiBlocks);
    endrule
    
    rule finishExec(topLevelStatus==Execution && writer.done());
        topLevelStatus <= Configuration;
        $display("---------------------------------Completed DCT----------------------------------");
    endrule
    
/*********************************** Interface definition********************************************/
    interface axiC_rd  = configAXISlave.s_rd;
    interface axiC_wr  = configAXISlave.s_wr;    

    interface axiD_rd = reader.axi4Fab;
    interface axiD_wr = writer.axi4Fab;
endmodule

endpackage
