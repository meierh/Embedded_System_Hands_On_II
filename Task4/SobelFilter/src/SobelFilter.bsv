package SobelFilter;

import List :: * ;
import Vector :: * ;
import BlueAXI :: * ;
import AXI4_Types :: * ;

Integer AXIConfigAddrWidth = 8;
Integer AXIConfigDataWidth = 64;

Integer batchSquareLen = 64;
Integer maxAdmisKernelSize = 12;
Integer simultLineProcessed = 2;

Integer AXIImageAddrWidth = 8;
Integer AXIImageRdDataWidth = 8;
Integer AXIImageWrDataWidth = 8;
Integer AXIImageIDWidth = 8;
Integer AXIImageUserWidth = 8;

(* always_ready, always_enabled *)
interface SobelFilter;
// Add custom interface definitions
    (*prefix = "AXI_Config"*) interface AXI4_Lite_Slave_Rd_Fab#(AXIConfigAddrWidth, AXIConfigDataWidth) axiC_rd;
    (*prefix = "AXI_Config"*) interface AXI4_Lite_Slave_Wr_Fab#(AXIConfigAddrWidth, AXIConfigDataWidth) axiC_wr;
    
    (*prefix = "AXI_Image"*) interface AXI4_Master_Rd_Fab#(AXIImageAddrWidth,AXIImageRdDataWidth,AXIImageIDWidth,
                                                           AXIImageUserWidth);
    (*prefix = "AXI_Image"*) interface AXI4_Master_Wr_Fab#(AXIImageAddrWidth,AXIImageWrDataWidth,AXIImageIDWidth,
                                                           AXIImageUserWidth);
endinterface

module mkSobelFilter(SobelFilter);

/******************************* Configuration Registers **********************************************/
    Reg#(Bit#(AXIConfigDataWidth)) inputImageAddress <- mkReg(0);
    Reg#(Bool) inputImageAddressValid <- mkReg(False);
    
    Reg#(Bit#(AXIConfigDataWidth)) outputImageAddress <- mkReg(0);
    Reg#(Bool) outputImageAddressValid <- mkReg(False);
    
    Reg#(Bool) executeCmd <- mkReg(False);
    
    Reg#(UInt(AXIConfigDataWidth/2)) resolutionX <- mkReg(0);
    Reg#(Bool) resolutionXValid <- mkReg(False);
    Reg#(UInt(AXIConfigDataWidth/2)) resolutionY <- mkReg(0);
    Reg#(Bool) resolutionYValid <- mkReg(False);
    
    Reg#(UInt(AXIConfigDataWidth/2)) kernelSize <- mkReg(0);
    Reg#(Bool) kernelSizeValid <- mkReg(False);
    
    typedef enum {Unconfigured,Configured,Executed,Finished} TopLevelStatusInfo deriving (Bits);    
    Reg#(TopLevelStatusInfo) TopLevelStatus <- mkReg(Unconfigured);
    
    typedef struct {UInt#(32) x0; UInt#(32) y0;} ImageCoord;
    
/************************************ AXI Configuration ***********************************************/
    List#(RegisterOperator#(AXIConfigAddrWidth,AXIConfigDataWidth)) configurationOperations;
    
// Write input address operation
    RegisterOperator#(AXIConfigAddrWidth,AXIConfigDataWidth) writeInputAddress;    
    function Action writeInputAddr (Bit#(AXIConfigDataWidth) d, Bit#(TDiv#(AXIConfigDataWidth, 8)) s, AXI4_Lite_Prot p);
              action
                    inputImageAddress <= unpack(d);
                    inputImageAddressValid <= True;
                    //Int#(AXIConfigDataWidth) aVar = unpack(d);
                    //$display("Set a to: %d", aVar);
               endaction
    endfunction : writeInputAddr
    WriteOperation#(AXIConfigAddrWidth,AXIConfigDataWidth) writeInputAddrStruct;
    writeInputAddrStruct = WriteOperation { index : 8'b00000000 /* 0 */ , fun : writeInputAddr };
    writeInputAddress = tagged Write writeInputAddrStruct;
    configurationOperations = replicate(1,writeInputAddress);
    
// Write output address operation
    RegisterOperator#(AXIConfigAddrWidth,AXIConfigDataWidth) writeOutputAddress;    
    function Action writeOutputAddr (Bit#(AXIConfigDataWidth) d, Bit#(TDiv#(AXIConfigDataWidth, 8)) s, AXI4_Lite_Prot p);
              action
                    outputImageAddress <= unpack(d);
                    outputImageAddressValid <= True;
                    //Int#(AXIConfigDataWidth) aVar = unpack(d);
                    //$display("Set a to: %d", aVar);
               endaction
    endfunction : writeOutputAddr
    WriteOperation#(AXIConfigAddrWidth,AXIConfigDataWidth) writeOutputAddrStruct;
    writeOutputAddrStruct = WriteOperation { index : 8'b00001000 /* 8 */, fun : writeOutputAddr };
    writeOutputAddress = tagged Write writeOutputAddrStruct;
    configurationOperations = List::cons(writeOutputAddress,configurationOperations);
    
// Write execution command operation
    RegisterOperator#(AXIConfigAddrWidth,AXIConfigDataWidth) writeExecuteCommand;    
    function Action writeExecuteCmd (Bit#(AXIConfigDataWidth) d, Bit#(TDiv#(AXIConfigDataWidth, 8)) s, AXI4_Lite_Prot p);
              action
                    executeCmd <= True;
                    //Int#(AXIConfigDataWidth) aVar = unpack(d);
                    //$display("Set a to: %d", aVar);
               endaction
    endfunction : writeExecuteCmd
    WriteOperation#(AXIConfigAddrWidth,AXIConfigDataWidth) writeExecuteCmdStruct;
    writeExecuteCmdStruct = WriteOperation { index : 8'b00010000 /* 16 */, fun : writeExecuteCmd };
    writeExecuteCommand = tagged Write writeExecuteCmdStruct;
    configurationOperations = List::cons(writeExecuteCommand,configurationOperations);
    
// Write resolution command operation
    RegisterOperator#(AXIConfigAddrWidth,AXIConfigDataWidth) writeResolution;    
    function Action writeResolutionSize (Bit#(AXIConfigDataWidth) d, Bit#(TDiv#(AXIConfigDataWidth, 8)) s, AXI4_Lite_Prot p);
              action
                    Tuple2#(Bit#(AXIConfigDataWidth/2), Bit#(AXIConfigDataWidth/2)) resXY = split(d);
                    resolutionX <= unpack(tpl_1(resXY));
                    resolutionXValid <= True;
                    resolutionY <= unpack(tpl_2(resXY));
                    resolutionYValid <= True;
                    //Int#(AXIConfigDataWidth) aVar = unpack(d);
                    //$display("Set a to: %d", aVar);
               endaction
    endfunction : writeResolutionSize
    WriteOperation#(AXIConfigAddrWidth,AXIConfigDataWidth) writeResolutionStruct;
    writeResolutionStruct = WriteOperation { index : 8'b00011000 /* 24 */, fun : writeResolutionSize };
    writeResolution = tagged Write writeResolutionStruct;
    configurationOperations = List::cons(writeResolution,configurationOperations);    

// Write kernel size operation
    RegisterOperator#(AXIConfigAddrWidth,AXIConfigDataWidth) writeKernelSize;    
    function Action writeKernelSz (Bit#(AXIConfigDataWidth) d, Bit#(TDiv#(AXIConfigDataWidth, 8)) s, AXI4_Lite_Prot p);
              action
                    kernelSize <= unpack(d);
                    kernelSizeValid <= True;
                    //Int#(AXIConfigDataWidth) aVar = unpack(d);
                    //$display("Set a to: %d", aVar);
               endaction
    endfunction : writeKernelSz
    WriteOperation#(AXIConfigAddrWidth,AXIConfigDataWidth) writeKernelStruct;
    writeKernelStruct = WriteOperation { index : 8'b00100000 /* 32 */, fun : writeKernelSz };
    writeKernelSize = tagged Write writeKernelStruct;
    configurationOperations = List::cons(writeKernelSize,configurationOperations);
    
// Read status operation
    RegisterOperator#(AXIConfigAddrWidth,AXIConfigDataWidth) readStatus;
    function ActionValue#(Bit#(AXIConfigDataWidth)) readStat (AXI4_Lite_Prot p);
              actionvalue
                    //$display("Read c to: %d", c);
                    return pack(TopLevelStatus);
               endactionvalue
    endfunction : readStat
    ReadOperation#(AXIConfigAddrWidth,AXIConfigDataWidth) readStatStruct;
    readStatStruct = ReadOperation { index : 8'b00101000 /* 40 */, fun : readStat };
    readCOperation = tagged Read readStatStruct;
    configurationOperations = List::cons(readCOperation,configurationOperations);
    
    // Construct AXI Slave  
    GenericAxi4LiteSlave#(AXIConfigAddrWidth,AXIConfigDataWidth) axiLiteSlave <- mkGenericAxi4LiteSlave(configurationOperations,1,1);
    
    interface axiC_rd  = axiLiteSlave.s_rd;
    interface axiC_wr  = axiLiteSlave.s_wr;
/******************************************************************************************************/


/************************************** Image Registers ***********************************************/
    Integer batchSquareLenWithPad = batchSquareLen+maxAdmisKernelSize;
    Integer batchSquareWithPad = batchSquareLenWithPad*batchSquareLenWithPad;
    Vector#(batchSquareWithPad,Reg#(UInt#(8))) inputStorage;
    
    Vector#(simultLineProcessed,ImageCoord)) outputStorageCoords;
    Vector#(simultLineProcessed,Vector#(batchSquareLen,Reg#(UInt#(8)))) outputStorage;
    
    typedef enum {Strategize,FillUp,NextLines} ExecutionZoneInfo deriving (Bits);    
    Reg#(ExecutionStatusInfo) ExecutionZone <- mkReg(Strategize);
    
    typedef enum {DataMovement,Compute} ExecutionPhaseInfo deriving (Bits);    
    Reg#(ExecutionPhaseInfo) ExecutionPhase <- mkReg(Compute);
    
    function Integer squareToLinearCoord (Integer x, Integer y);
        return x + batchSquareLenWithPad * y;
    endfunction: squareToLinearCoord
    
    function Action shiftYPlusDir();
        action
            for(Integer batchX = 0 ;
                batchX < batchSquareLenWithPad-simultLineProcessed;
                batchX = batchX + 1)
                for(Integer batchY = 0;
                    batchY < batchSquareLenWithPad;
                    batchY = batchY + 1)
                    Integer linearCoordDest = squareToLinearCoord(batchX,batchY);
                    Integer linearCoordOrig = squareToLinearCoord(batchX,batchY+simultLineProcessed);
                    inputStorage[linearCoordDest] <= inputStorage[linearCoordOrig];
        endaction
    endfunction : shiftYPlusDir
    
    function Action compute(Integer y0);
        action
            for(Integer batchX = 0 ;
                batchX < simultLineProcessed;
                batchX = batchX + 1)
                for(Integer batchY = 0;
                    batchY < batchSquareLenWithPad;
                    batchY = batchY + 1)
                    Integer linearCoord = squareToLinearCoord(batchX,batchY);

                    inputStorage[linearCoordDest] <= inputStorage[linearCoordOrig];
        endaction
    endfunction : compute

/*************************************** Image Transfer************************************************/
    AXI4_Master_Rd#(AXIImageAddrWidth,AXIImageDataWidth,AXIImageIDWidth,AXIImageUserWidth) <- mkAXI4_Master_Rd(1,1,False);
    AXI4_Master_Wr#(AXIImageAddrWidth,AXIImageDataWidth,AXIImageIDWidth,AXIImageUserWidth) <- mkAXI4_Master_Wr(1,1,False);
    
endmodule

endpackage
