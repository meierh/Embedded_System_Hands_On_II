package AXIDCTBlockWriter;

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
interface AXIDCTBlockReader#(numeric type addrwidth, numeric type maxBurstLen);
    method ActionValue#(Bool) configure (Bit#(addrwidth) _outputAddress);
    method Action setBlock (Vector#(8,Vector#(8,UInt#(8))) block);
    interface AXI4_Master_Wr_Fab#(addrwidth,128,1,0) axi4Fab;
endinterface

module mkAXIDCTBlockWriter(AXIDCTBlockWriter#(addrwidth,maxBurstLen))
                                provisos(Max#(addrwidth,8,addrwidth),
                                         Add#(a__, 8, addrwidth)); // 8 <= addrwidth

// Configuration registers
    Reg#(Bit#(addrwidth)) outputAddress <- mkReg(0);
    Reg#(Bool) validConfig <- mkReg(False);

// AXI connect
    AXI4_Master_Rd#(addrwidth,128,1,0) axiDataRd <- mkAXI4_Master_Rd(1,1,False);
    
// Load data from AXI slave
    Reg#(Bit#(addrwidth)) blockCounter <- mkReg(0);
    Reg#(Bit#(addrwidth)) addrOffset <- mkReg(0);
    Reg#(AXIBurstStoragePhase) axiWritePhase <- mkReg(Request);
        
    FIFO#(Vector#(8,Vector#(8,UInt#(8)))) inputBlocks <- mkSizedBRAMFIFO(128);
    
    Vector#(TMul#(maxBurstLen,16),Reg#(UInt#(8))) axiBurstRegisters;
    for(Integer i=0; i<valueOf(maxBurstLen)*16; i=i+1)
        axiBurstRegisters[i] <- mkRegU();
    Reg#(Bit#(addrwidth)) axiBurstRegWriteIndex <- mkReg(0);
    
    rule writeToBurst;
        if(axiBurstRegWriteIndex+64<=fromInteger(valueOf(maxBurstLen))*16)
            begin
            Vector#(8,Vector#(8,UInt#(8))) block = inputBlocks.first;
            for(Integer y=0; y<8; y=y+1)
                for(Integer x=0; x<8; x=x+1)
                    axiBurstRegisters[axiBurstRegWriteIndex+fromInteger(y*8+x)] <= block[y][x];
            axiBurstRegWriteIndex <= axiBurstRegWriteIndex + 64;
            end
        else
            begin
            
            axiBurstRegWriteIndex <= 0;
            end
        
    endrule
    
    rule requestData (validConfig && axiLoadPhase==Request);
        if(blockCounter < numberBlocks)
            begin
            Bit#(addrwidth) reqAddr = inputImageAddress + addrOffset;
            Bit#(addrwidth) _remainigBlocks = numberBlocks - blockCounter;
            Bit#(addrwidth) _remainingBeats = _remainigBlocks * 4;
            Bit#(addrwidth) _requestedBeats;
            if(_remainingBeats < fromInteger(valueOf(maxBurstLen)))
                _requestedBeats = _remainingBeats;
            else
                _requestedBeats = fromInteger(valueOf(maxBurstLen));
            Bit#(addrwidth) _requestedBeats_Min1 = _requestedBeats-1;
            Bit#(8) _requestedBeats_Min1_Trunc = truncate(_requestedBeats_Min1);
            axi4_read_data(axiDataRd,reqAddr,unpack(_requestedBeats_Min1_Trunc));
            $display("_remainingBeats: %d",_remainingBeats);
            axiLoadPhase <= Read;
            end
        else
            validConfig <= False;
    endrule
    
    rule readData (axiLoadPhase==Read);
        let readResponse <- axiDataRd.response.get();
        Bit#(128) responseData  = readResponse.data;
        Bool responseLast = readResponse.last;
        
        Vector#(16,UInt#(8)) pixels;
        Integer pixelBitStart = 127;
        for(Integer i=0; i<16; i=i+1)
            begin
            pixels[i] = unpack(responseData[pixelBitStart:pixelBitStart-7]);
            pixelBitStart = pixelBitStart - 8;
            end
        for(Integer i=0; i<16; i=i+1)
            axiBurstRegisters[axiBurstRegWriteIndex+fromInteger(i)] <= pixels[i];
            
        if(responseLast)
            begin
            axiLoadPhase <= Move;
            axiBurstRegWriteIndex <= 0;
            end
        else
            axiBurstRegWriteIndex <= axiBurstRegWriteIndex + 16;
        addrOffset <= addrOffset + 16;
    endrule

    method Action setBlock (Vector#(8,Vector#(8,UInt#(8))) block);
        inputBlocks.enq(block);
    endmethod
    
    method ActionValue#(Bool) configure (Bit#(addrwidth) _outputAddress);
        outputAddress <= _outputAddress;
        return True;
    endmethod
    
    interface axi4Fab = axiDataRd.fab;
    
endmodule

endpackage
