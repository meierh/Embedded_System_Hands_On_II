package DCTOperator;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import SystolicArray :: *;

Integer fifoDepth = 50;

typedef 22 FIXEDWIDTH;
typedef Vector#(8,Vector#(8,UInt#(8))) BLOCK;

(* always_ready, always_enabled *)
interface DCTOperator;
    method Action setBlock (BLOCK block);
    method ActionValue#(Vector#(8,Vector#(8,Int#(FIXEDWIDTH)))) getBlock ();
endinterface

module mkDCTOperator(DCTOperator);

    // Bitpattern[Sign:1, Nonfraction:14, Fraction:7]
    //cos[x][u] = cos(((2*x+1)*u*pi)/16)[x][u]
    Int#(FIXEDWIDTH) cosinus[8][8] =   {{128, 126, 118, 106,  91,  71,  49,  25},
                                        {128, 106,  49, -25, -91,-126,-118, -71},
                                        {128,  71, -49,-126, -91,  25, 118, 106},
                                        {128,  25,-118, -71,  91, 106, -49,-126},
                                        {128, -25, 118,  71,  91,-106, -49, 126},
                                        {128, -71, -49, 126, -91, -25, 118,-106},
                                        {128,-106,  49,  25, -91, 126,-118,  71},
                                        {128,-126, 118,-106,  91, -71,  49, -25}};
                                        
    Int#(FIXEDWIDTH) c[8] =   {91, 128, 128, 128, 128, 128, 128, 128};
        
    FIFO#(BLOCK) imageBlock <- mkSizedFIFO(fifoDepth);
   
    SystolicArray#(FIXEDWIDTH) matrixMulti_Mod1 <- mkSystolicArray;
    
    rule matrixMult_S_Cos;
        BLOCK oneBlock = imageBlock.first;
        imageBlock.deq;
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) syx = newVector;
        for(Integer x=0; x<8; x=x+1)
            for(Integer y=0; y<8; y=y+1)
                begin
                Bit#(8) bPixel = pack(oneBlock[y][x]);
                Bit#(FIXEDWIDTH) lbPixel = extend(bPixel);
                syx[y][x] = unpack(lbPixel);
                end
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) cosyv = newVector;
        for(Integer v=0; v<8; v=v+1)
            for(Integer y=0; y<8; y=y+1)
                begin
                cosyv[y][v] = cosinus[y][v];
                end
        matrixMulti_Mod1.setMatrix(syx,cosyv);
    endrule
    
    SystolicArray#(FIXEDWIDTH) matrixMulti_Mod2 <- mkSystolicArray;
    
    rule matrixMult_Cos_SCos;    
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) sCos <- matrixMulti_Mod1.getResult();
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) cosxu = newVector;
        for(Integer u=0; u<8; u=u+1)
            for(Integer y=0; y<8; y=y+1)
                begin
                cosxu[y][u] = cosinus[y][u];
                end
        matrixMulti_Mod2.setMatrix(cosxu,sCos);
    endrule
    
    FIFO#(Vector#(8,Vector#(8,Int#(FIXEDWIDTH)))) dctBlock <- mkSizedFIFO(fifoDepth);
    
    rule normalizeDCT;
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) cosSCos <- matrixMulti_Mod2.getResult();
        for(Integer u=0; u<8; u=u+1)
            for(Integer v=0; v<8; v=v+1)
                begin
                cosSCos[v][u] = c[u]*c[v]*cosSCos[v][u];
                cosSCos[v][u] = cosSCos[v][u] >> 2;
                end
        dctBlock.enq(cosSCos);
    endrule
   
// Interface methods    
    method Action setBlock (Vector#(8,Vector#(8,UInt#(8))) block);
        imageBlock.enq(block);
    endmethod
    
    method ActionValue#(Vector#(8,Vector#(8,Int#(FIXEDWIDTH)))) getBlock ();
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) bl = dctBlock.first;
        dctBlock.deq;
        return bl;
    endmethod
    
endmodule

/*
module mkDCTPassthrough(DCTOperator);

    FIFO#(BLOCK) blockFIFO <- mkSizedFIFO(fifoDepth);

    method Action setBlock (Vector#(8,Vector#(8,UInt#(8))) block);
        blockFIFO.enq(block);
    endmethod
    
    method ActionValue#(Vector#(8,Vector#(8,Int#(FIXEDWIDTH)))) getBlock ();
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) bl = dctBlock.first;
        blockFIFO.deq;
        return bl;
    endmethod
endmodule
*/

endpackage
