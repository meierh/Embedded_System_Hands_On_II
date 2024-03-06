package AXIGrayscaleReader;

import List :: * ;
import Vector :: * ;
import FIFOF :: * ;
import Real :: * ;
import AXI4_Types :: * ;
import AXI4_Master :: * ;
import GetPut :: *;
import BRAMFIFO :: * ;

typedef enum {
    Request = 2'b00,
    Read = 2'b01,
    Shift = 2'b10
    } AXIBurstStoragePhase deriving (Bits,Eq);
    
(* always_ready, always_enabled *)
interface AXIGrayscaleReader#(numeric type addrwidth, numeric type datawidth, numeric type maxBurstLen);
    method Action configure (Bit#(addrwidth) _imageAddress, Bit#(addrwidth) _chunksNumberX, Bit#(addrwidth) _resolutionY);
    method ActionValue#(Vector#(7,Vector#(TDiv#(datawidth,8),Bit#(8)))) getWindow ();
    interface AXI4_Master_Rd_Fab#(addrwidth,datawidth,1,0) axi4Fab;
endinterface

module mkAXIGrayscaleReader(AXIGrayscaleReader#(addrwidth,datawidth,maxBurstLen))
                                                provisos(Add#(a__, 8, addrwidth));

// Configuration registers
    Reg#(Bit#(addrwidth)) inputImageAddress <- mkReg(0);
    Reg#(Bit#(addrwidth)) chunksNumberX <- mkReg(0);
    Reg#(Bit#(addrwidth)) resolutionY <- mkReg(0);
    //Reg#(Bit#(addrwidth)) rowNumber <- mkReg(0);
    Reg#(Bit#(addrwidth)) chunkNumber <- mkReg(0);
    Reg#(Bool) validConfig <- mkReg(False);

// AXI connect
    AXI4_Master_Rd#(addrwidth,datawidth,1,0) axiDataRd <- mkAXI4_Master_Rd(1,1,False);
    
    FIFOF#(Tuple2#(Vector#(TDiv#(datawidth,8),Bit#(8)),Bool)) chunkFIFO <- mkSizedBRAMFIFOF(valueOf(maxBurstLen));
    
// Load data from AXI slave
    Reg#(Bit#(addrwidth)) chunkCounter <- mkReg(0);
    Reg#(Bit#(addrwidth)) addrOffset <- mkReg(0);
    Reg#(AXIBurstStoragePhase) axiLoadPhase <- mkReg(Request);

    rule requestData (validConfig && axiLoadPhase==Request /*&& !chunkFIFO.notEmpty*/);
        if(chunkCounter < chunkNumber)
            begin
            Bit#(addrwidth) reqAddr = inputImageAddress + addrOffset;
            Bit#(addrwidth) _remainigChunks = chunkNumber - chunkCounter;
            Bit#(addrwidth) _requestedChunks = fromInteger(valueOf(maxBurstLen));
            if(_remainigChunks < _requestedChunks)
                _requestedChunks = _remainigChunks;
            Bit#(addrwidth) _requestedChunks_Min1 = _requestedChunks-1;
            Bit#(8) _requestedChunks_Min1_Trunc = truncate(_requestedChunks_Min1);
            axi4_read_data(axiDataRd,reqAddr,unpack(_requestedChunks_Min1_Trunc));
            //$display("Request from %d with %d chunks of %d remaining",reqAddr,_requestedChunks,_remainigChunks);
            axiLoadPhase <= Read;
            chunkCounter <= chunkCounter + _requestedChunks;
            addrOffset <= addrOffset + _requestedChunks * 16;
            end
        else
            begin
            //$display("Reader invalid");
            validConfig <= False;
            end
    endrule

    Reg#(Bit#(addrwidth)) readRowCount <- mkReg(0);
    Reg#(Bit#(addrwidth)) chunksCountX <- mkReg(0);
    
    rule readData (axiLoadPhase==Read);
        let readResponse <- axiDataRd.response.get();
        Bit#(datawidth) responseData  = readResponse.data;
        Bool responseLast = readResponse.last;
        Bool lastRow;
        if(readRowCount == resolutionY-1)
            begin
            lastRow = True;
            readRowCount <= 0;
            chunksCountX <= chunksCountX + 1;
            end
        else
            begin
            lastRow = False;
            readRowCount <= readRowCount + 1;
            end
        
        Integer pixelBitStart = fromInteger(valueOf(datawidth))-1;
        Vector#(TDiv#(datawidth,8),Bit#(8)) oneChunk = newVector;
        for(Integer i=0; i<valueOf(datawidth)/8; i=i+1)
            begin
            oneChunk[i] = responseData[pixelBitStart:pixelBitStart-7];
            pixelBitStart = pixelBitStart - 8;
            end
        //$display("In Chunk %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d last %b",oneChunk[0],oneChunk[1],oneChunk[2],oneChunk[3],oneChunk[4],oneChunk[5],oneChunk[6],oneChunk[7],oneChunk[8],oneChunk[9],oneChunk[10],oneChunk[11],oneChunk[12],oneChunk[13],oneChunk[14],oneChunk[15],lastRow);

        chunkFIFO.enq(tuple2(oneChunk,lastRow));

        if(responseLast)
            axiLoadPhase <= Request;
    endrule

    Vector#(7,Vector#(TDiv#(datawidth,8),Reg#(Bit#(8)))) window = newVector;
    for(Integer i=0; i<7; i=i+1)
        for(Integer j=0; j<valueOf(datawidth)/8; j=j+1)
            window[i][j] <- mkRegU;
    Reg#(Bit#(addrwidth)) insertionRow <- mkReg(0);
    FIFOF#(Vector#(7,Vector#(TDiv#(datawidth,8),Bit#(8)))) windowFIFO <- mkSizedFIFOF(valueOf(maxBurstLen));
    
    rule constructWindow;
        Tuple2#(Vector#(TDiv#(datawidth,8),Bit#(8)),Bool) oneRow = chunkFIFO.first;
        chunkFIFO.deq;
        if(insertionRow==6)
            begin
            Vector#(7,Vector#(TDiv#(datawidth,8),Bit#(8))) _window = newVector;
            for(Integer j=0; j<valueOf(datawidth)/8; j=j+1)
                for(Integer i=1; i<7; i=i+1)    
                    _window[i][j] = window[i][j];
            windowFIFO.enq(_window);
            for(Integer j=0; j<valueOf(datawidth)/8; j=j+1)
                begin
                for(Integer i=1; i<7; i=i+1)
                    window[i-1][j] <= window[i][j];
                window[6][j] <= tpl_1(oneRow)[j];
                end
            if(tpl_2(oneRow))
                insertionRow <= 0;
            end
        else
            begin
            for(Integer j=0; j<valueOf(datawidth)/8; j=j+1)
                window[insertionRow][j] <= tpl_1(oneRow)[j];
            insertionRow <= insertionRow + 1;
            end
    endrule
    
    method ActionValue#(Vector#(7,Vector#(TDiv#(datawidth,8),Bit#(8)))) getWindow ();
        Vector#(7,Vector#(TDiv#(datawidth,8),Bit#(8))) _window = windowFIFO.first;
        windowFIFO.deq;
        return _window;
    endmethod
    
    method Action configure (Bit#(addrwidth) _imageAddress, Bit#(addrwidth) _chunksNumberX, Bit#(addrwidth) _resolutionY) if(!validConfig);
        inputImageAddress <= _imageAddress;
        chunksNumberX <= _chunksNumberX;
        resolutionY <= _resolutionY;
        //rowNumber <= resolutionY;
        chunkNumber <= _chunksNumberX*_resolutionY;
        readRowCount <= 0;
        chunksCountX <= 0;
        insertionRow <= 0;
        chunkCounter <= 0;
        axiLoadPhase <= Request;
        addrOffset <= 0;
        windowFIFO.clear;
        validConfig <= True;
        chunkFIFO.clear;
        //$display("Configured Reader");
    endmethod
    
    interface axi4Fab = axiDataRd.fab;
    
endmodule

endpackage
