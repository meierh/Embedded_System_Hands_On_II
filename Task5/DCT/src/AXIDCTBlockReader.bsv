package AXIDCTBlockReader;

import List :: * ;
import Vector :: * ;
import FIFOF :: * ;
import Real :: * ;
import AXI4_Types :: * ;
import AXI4_Master :: * ;
import GetPut :: *;

typedef enum {
    Request = 2'b00,
    Read = 2'b01,
    Move = 2'b10
    } AXIBurstStoragePhase deriving (Bits,Eq);

(* always_ready, always_enabled *)
interface AXIDCTBlockReader#(numeric type addrwidth, numeric type simultBlocks);
    method ActionValue#(Vector#(simultBlocks,Vector#(8,Vector#(8,Bit#(8))))) getMultiBlock ();
    method Action configure (Bit#(addrwidth) _imageAddress, Bit#(addrwidth) _numberBlocks);
    interface AXI4_Master_Rd_Fab#(addrwidth,128,1,0) axi4Fab;
endinterface

module mkAXIDCTBlockReader(AXIDCTBlockReader#(addrwidth,simultBlocks))
                                provisos(Max#(addrwidth,8,addrwidth),
                                         Max#(simultBlocks,64,64),
                                         Add#(a__, 8, addrwidth)); // 8 <= addrwidth

// Configuration registers
    Reg#(Bit#(addrwidth)) inputImageAddress <- mkReg(0);
    Reg#(Bit#(addrwidth)) numberBlocks <- mkReg(0);
    Reg#(Bool) validConfig <- mkReg(False);

// AXI connect
    AXI4_Master_Rd#(addrwidth,128,1,0) axiDataRd <- mkAXI4_Master_Rd(1,1,False);
    
// Load data from AXI slave
    Reg#(Bit#(addrwidth)) blockCounter <- mkReg(0);
    Reg#(Bit#(addrwidth)) addrOffset <- mkReg(0);
    Reg#(AXIBurstStoragePhase) axiLoadPhase <- mkReg(Request);
    
    rule requestData (validConfig && axiLoadPhase==Request);
        if(blockCounter < numberBlocks)
            begin
            Bit#(addrwidth) reqAddr = inputImageAddress + addrOffset;
            Bit#(addrwidth) _remainigBlocks = numberBlocks - blockCounter;
            Bit#(addrwidth) _requestedBlocks = fromInteger(valueOf(simultBlocks));
            if(_remainigBlocks < _requestedBlocks)
                _requestedBlocks = _remainigBlocks;
            Bit#(addrwidth) _requestedBeats = _requestedBlocks*4;
            Bit#(addrwidth) _requestedBeats_Min1 = _requestedBeats-1;
            Bit#(8) _requestedBeats_Min1_Trunc = truncate(_requestedBeats_Min1);
            axi4_read_data(axiDataRd,reqAddr,unpack(_requestedBeats_Min1_Trunc));
            axiLoadPhase <= Read;
            blockCounter <= blockCounter + _requestedBlocks;
            addrOffset <= addrOffset + _requestedBlocks * 64;
            end
        else
            validConfig <= False;
    endrule
    
    Vector#(simultBlocks,Vector#(8,Vector#(8,Reg#(Bit#(8))))) axiReadRegisters = newVector;    
    for(Integer i=0; i<valueOf(simultBlocks); i=i+1)
        for(Integer j=0; j<8; j=j+1)
            for(Integer k=0; k<8; k=k+1)
                axiReadRegisters[i][j][k] <- mkRegU();

    Reg#(Bit#(addrwidth)) readBlockCount <- mkReg(0);
    Reg#(Bit#(addrwidth)) readRowCount <- mkReg(0);
    
    rule readData (axiLoadPhase==Read);
        let readResponse <- axiDataRd.response.get();
        Bit#(128) responseData  = readResponse.data;
        Bool responseLast = readResponse.last;
        
        Integer pixelBitStart = 127;
        for(Integer i=0; i<8; i=i+1)
            begin
            axiReadRegisters[readBlockCount][readRowCount][i] <= responseData[pixelBitStart:pixelBitStart-7];
            pixelBitStart = pixelBitStart - 8;
            end
        for(Integer i=0; i<8; i=i+1)
            begin
            axiReadRegisters[readBlockCount][readRowCount+1][i] <= responseData[pixelBitStart:pixelBitStart-7];
            pixelBitStart = pixelBitStart - 8;
            end
           
        if(!responseLast)
            begin
            if(readRowCount<6)
                readRowCount <= readRowCount + 2;
            else
                begin
                readRowCount <= 0;
                readBlockCount <= readBlockCount + 1;
                end
            end
        else
            begin
            axiLoadPhase <= Move;
            readBlockCount <= 0;
            readRowCount <= 0;
            end
    endrule
    
    FIFOF#(Vector#(simultBlocks,Vector#(8,Vector#(8,Bit#(8))))) outputBlocks <- mkFIFOF();    
    
    rule moveData (axiLoadPhase==Move);
        Vector#(simultBlocks,Vector#(8,Vector#(8,Bit#(8)))) multiBlock = newVector;
        for(Integer i=0; i<valueOf(simultBlocks); i=i+1)
            for(Integer j=0; j<8; j=j+1)
                for(Integer k=0; k<8; k=k+1)
                    multiBlock[i][j][k] = axiReadRegisters[i][j][k];
        outputBlocks.enq(multiBlock);
        axiLoadPhase <= Request;
    endrule
    
    method ActionValue#(Vector#(simultBlocks,Vector#(8,Vector#(8,Bit#(8))))) getMultiBlock();
        Vector#(simultBlocks,Vector#(8,Vector#(8,Bit#(8)))) multiBlock = outputBlocks.first();
        outputBlocks.deq();
        return multiBlock;
    endmethod
    
    method Action configure (Bit#(addrwidth) _imageAddress, Bit#(addrwidth) _numberBlocks) if(!validConfig);
        inputImageAddress <= _imageAddress;
        numberBlocks <= _numberBlocks;
        validConfig <= True;
    endmethod
    
    interface axi4Fab = axiDataRd.fab;
endmodule

endpackage
