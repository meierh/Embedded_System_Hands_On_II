package AXIDCTBlockReader;

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
    method ActionValue#(Bool) configure (Bit#(addrwidth) _imageAddress, Bit#(addrwidth) _numberBlocks);
    method ActionValue#(Vector#(8,Vector#(8,UInt#(8)))) getBlock ();
    interface AXI4_Master_Rd_Fab#(addrwidth,128,1,0) axi4Fab;
endinterface

module mkAXIDCTBlockReader(AXIDCTBlockReader#(addrwidth,maxBurstLen))
                                provisos(Max#(addrwidth,8,addrwidth),
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
    
    Vector#(TMul#(maxBurstLen,16),Reg#(UInt#(8))) axiBurstRegisters;
    for(Integer i=0; i<valueOf(maxBurstLen)*16; i=i+1)
        axiBurstRegisters[i] <- mkRegU();
    Reg#(Bit#(addrwidth)) axiBurstRegWriteIndex <- mkReg(0);
    
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
    
    Vector#(TMul#(maxBurstLen,16),Reg#(UInt#(8))) intermedBurstRegisters;
    for(Integer i=0; i<valueOf(maxBurstLen)*16; i=i+1)
        intermedBurstRegisters[i] <- mkRegU();
    Reg#(Bool) intermedBurstRegistersValid <- mkReg(False);
    Reg#(Bit#(addrwidth)) intermedBurstRegistersLimitIndex <- mkReg(0);
    Reg#(Bit#(addrwidth)) intermedBurstRegistersRead <- mkReg(0);
    
    rule axiBurst_to_IntermedBurst (axiLoadPhase==Move && !intermedBurstRegistersValid);
        for(Integer i=0; i<valueOf(maxBurstLen)*16; i=i+1)
            intermedBurstRegisters[i] <= axiBurstRegisters[i];
        intermedBurstRegistersValid <= True;
        intermedBurstRegistersLimitIndex <= axiBurstRegWriteIndex;
        intermedBurstRegistersRead <= 0;
        axiBurstRegWriteIndex <= 0;
        axiLoadPhase <= Request;
    endrule
    
    Vector#(8,Vector#(8,Reg#(UInt#(8)))) buildBlock = newVector;
    Reg#(Bit#(4)) buildBlockCounter <- mkReg(0); 
    
    FIFO#(Vector#(8,Vector#(8,UInt#(8)))) outputBlocks <- mkSizedBRAMFIFO(128);
    
    rule createDCTBlocks(intermedBurstRegistersValid);
        if(intermedBurstRegistersRead < intermedBurstRegistersLimitIndex)
            begin
            if(buildBlockCounter==6)
                begin
                Vector#(8,Vector#(8,UInt#(8))) block = newVector;
                for(Integer y=0; y<6; y=y+1)
                    for(Integer x=0; x<8; x=x+1)
                        block[y][x] = buildBlock[y][x];
                for(Integer y=0; y<2; y=y+1)
                    for(Integer x=0; x<8; x=x+1)
                        block[y+6][x] = intermedBurstRegisters[intermedBurstRegistersRead+fromInteger(y*8+x)];
                outputBlocks.enq(block);
                buildBlockCounter <= 0;
                end
            else
                begin
                for(Integer y=0; y<2; y=y+1)
                    for(Integer x=0; x<8; x=x+1)
                        buildBlock[fromInteger(y)+buildBlockCounter][x] <= intermedBurstRegisters[intermedBurstRegistersRead+fromInteger(y*8+x)];
                buildBlockCounter <= buildBlockCounter + 2;
                end
            intermedBurstRegistersRead <= intermedBurstRegistersRead + 16;
            end
        else
            begin
            intermedBurstRegistersValid <= False;
            end
    endrule
    
    method ActionValue#(Vector#(8,Vector#(8,UInt#(8)))) getBlock();
        Vector#(8,Vector#(8,UInt#(8))) block = outputBlocks.first();
        outputBlocks.deq();
        return block;
    endmethod
    
    method ActionValue#(Bool) configure (Bit#(addrwidth) _imageAddress, Bit#(addrwidth) _numberBlocks);
        inputImageAddress <= _imageAddress;
        numberBlocks <= _numberBlocks;
        return True;
    endmethod
    
    interface axi4Fab = axiDataRd.fab;
    
endmodule

endpackage
