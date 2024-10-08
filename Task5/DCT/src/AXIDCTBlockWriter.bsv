package AXIDCTBlockWriter;

import Vector :: * ;
import FIFOF :: * ;
import Real :: * ;
import AXI4_Types :: * ;
import AXI4_Master :: * ;
import GetPut :: *;
import BRAMFIFO :: * ;

typedef enum {
    Request = 2'b00,
    Send = 2'b01,
    Response = 2'b10
    } AXIBurstStoragePhase deriving (Bits,Eq);
    
Integer fifoDepth = 10;
    
(* always_ready, always_enabled *)
interface AXIDCTBlockWriter#(numeric type addrwidth, numeric type simultBlocks);
    method Action setBlock (Vector#(simultBlocks,Vector#(8,Vector#(8,Bit#(16)))) multiBlock);
    method Action configure (Bit#(addrwidth) _outputAddress, Bit#(addrwidth) _numberBlocks);
    method Bool done ();
    interface AXI4_Master_Wr_Fab#(addrwidth,128,1,0) axi4Fab;
endinterface

module mkAXIDCTBlockWriter(AXIDCTBlockWriter#(addrwidth,simultBlocks))
                                provisos(Max#(addrwidth,8,addrwidth),
                                         Max#(simultBlocks,64,64),
                                         Add#(a__, 8, addrwidth),
                                         Add#(1, b__, TMul#(simultBlocks, 1024))); // 8 <= addrwidth

// Configuration registers
    Reg#(Bit#(addrwidth)) outputAddress <- mkReg(0);
    Reg#(Bit#(addrwidth)) numberBlocks <- mkReg(0);
    Reg#(Bool) validConfig <- mkReg(False);

// AXI connect
    AXI4_Master_Wr#(addrwidth,128,1,0) axiDataWr <- mkAXI4_Master_Wr(1,1,1,False);
    
    FIFOF#(Vector#(simultBlocks,Vector#(8,Vector#(8,Bit#(16))))) inputBlocks <- mkSizedBRAMFIFOF(fifoDepth);    

// Load data from AXI slave
    Reg#(Bit#(addrwidth)) blockCounter <- mkReg(0);
    Reg#(Bit#(addrwidth)) addrOffset <- mkReg(0);
    Reg#(AXIBurstStoragePhase) axiWritePhase <- mkReg(Request);
    Reg#(Bit#(addrwidth)) announcedBeats <- mkReg(0);
    
    rule announceData (validConfig /*&& inputBlocks.notEmpty()*/ && axiWritePhase==Request);
        if(blockCounter < numberBlocks)
            begin
            Bit#(addrwidth) reqAddr = outputAddress + addrOffset;
            Bit#(addrwidth) _remainigBlocks = numberBlocks - blockCounter;
            Bit#(addrwidth) _announcedBlocks = fromInteger(valueOf(simultBlocks));
            if(_remainigBlocks < _announcedBlocks)
                _announcedBlocks = _remainigBlocks;
            Bit#(addrwidth) _announcedBeats = _announcedBlocks*8;
            announcedBeats <= _announcedBeats;
            Bit#(addrwidth) _announcedBeats_Min1 = _announcedBeats-1;
            Bit#(8) _announcedBeats_Min1_Trunc = truncate(_announcedBeats_Min1);
            axi4_write_addr(axiDataWr,reqAddr,unpack(_announcedBeats_Min1_Trunc));
            //$display("Announce from %d with %d beats and %d blocks of %d remaining",reqAddr,_announcedBeats,_announcedBlocks,_remainigBlocks);
            axiWritePhase <= Send;
            blockCounter <= blockCounter + _announcedBlocks;
            addrOffset <= addrOffset + _announcedBlocks * 64 * 2;
            end
        else
            begin
            validConfig <= False;
            //$display("Announcation done");
            end
    endrule

    Reg#(Bit#(addrwidth)) sendBeatCount <- mkReg(0);
    Reg#(Bit#(addrwidth)) sendRowCount <- mkReg(0);
    Reg#(Bit#(addrwidth)) sendBlockCount <- mkReg(0);
    
    rule sendData (axiWritePhase==Send);
        if(sendBeatCount<announcedBeats)
            begin
            Bool lastBeat = False;
            if(sendBeatCount==(announcedBeats-1))
                lastBeat = True;
            Vector#(simultBlocks,Vector#(8,Vector#(8,Bit#(16)))) multiBlock = inputBlocks.first;
            Vector#(8,Bit#(16)) beat = multiBlock[sendBlockCount][sendRowCount];
            Integer pixelBitStart = 127;
            Bit#(128) sendDataBlock = 0;
            for(Integer i=0; i<8; i=i+1)
                begin
                sendDataBlock[pixelBitStart:pixelBitStart-15] = beat[i];
                pixelBitStart = pixelBitStart - 16;
                end
            //$display("Out Beat %d %d %d %d %d %d %d %d",beat[0],beat[1],beat[2],beat[3],beat[4],beat[5],beat[6],beat[7]);
            axi4_write_data(axiDataWr,sendDataBlock,16'b1111111111111111,lastBeat);
            sendBeatCount <= sendBeatCount + 1;
            if(sendRowCount==7)
                begin
                sendRowCount <= 0;
                sendBlockCount <= sendBlockCount + 1;
                end
            else
                sendRowCount <= sendRowCount + 1;
            end
        else
            begin
            sendBeatCount <= 0;
            sendRowCount <= 0;
            sendBlockCount <= 0;
            axiWritePhase <= Response;
            inputBlocks.deq;
            end
    endrule
    
    rule responseData (axiWritePhase==Response);
        AXI4_Write_Rs#(1,0) resp <- axi4_write_response(axiDataWr);
        axiWritePhase <= Request;
    endrule

    method Action setBlock (Vector#(simultBlocks,Vector#(8,Vector#(8,Bit#(16)))) multiBlock);
        inputBlocks.enq(multiBlock);
    endmethod
    
    method Action configure (Bit#(addrwidth) _outputAddress, Bit#(addrwidth) _numberBlocks) if(!validConfig && (axiWritePhase==Request));
        outputAddress <= _outputAddress;
        numberBlocks <= _numberBlocks;
        validConfig <= True;
        blockCounter <= 0;
        addrOffset <= 0;
        axiWritePhase <= Request;
        announcedBeats <= 0;
        inputBlocks.clear();
        sendBeatCount <= 0;
        sendRowCount <= 0;
        sendBlockCount <= 0;
    endmethod
    
    method Bool done();
        return !validConfig && (axiWritePhase==Request);
    endmethod

    interface axi4Fab = axiDataWr.fab;
    
endmodule

endpackage
