package DCTOperator;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import SystolicArray :: *;

Integer fifoDepth = 50;

typedef 32 FIXEDWIDTH;
typedef 16 NONFRACTION;
typedef Vector#(8,Vector#(8,UInt#(8))) BLOCK;

(* always_ready, always_enabled *)
interface DCTOperator;
    method Action setBlock (BLOCK block);
    method ActionValue#(Vector#(8,Vector#(8,Int#(16)))) getBlock ();
endinterface

module mkDCTOperator(DCTOperator);

    function Action printMatrix (Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) matrix);
        action
        $display("----------------------------------------------------------------",$time);
        for(Integer y=0; y<8; y=y+1)
            begin
            for(Integer x=0; x<8; x=x+1)
                $write("%d ",matrix[y][x]);
            $display(" ");
            end
        $display("----------------------------------------------------------------");
        endaction
    endfunction
    
    function Action printMatrix_16 (Vector#(8,Vector#(8,Int#(16))) matrix);
        action
        $display("----------------------------------------------------------------",$time);
        for(Integer y=0; y<8; y=y+1)
            begin
            for(Integer x=0; x<8; x=x+1)
                $write("%d ",matrix[y][x]);
            $display(" ");
            end
        $display("----------------------------------------------------------------");
        endaction
    endfunction  

    // Bitpattern[Sign:1, Nonfraction:15, Fraction:16]
    //cos[x][u] = cos(((2*x+1)*u*pi)/16)[x][u]
    Int#(FIXEDWIDTH) cosinus[8][8] =   {{65536, 64277, 60547, 54491, 46341, 36410, 25080, 12785},
                                        {65536, 54491, 25080,-12785,-46341,-64277,-60547,-36410},
                                        {65536, 36410,-25080,-64277,-46341, 12785, 60547, 54491},
                                        {65536, 12785,-60547,-36410, 46341, 54491,-25080,-64277},
                                        {65536,-12785,-60547, 36410, 46341,-54491,-25080, 64277},
                                        {65536,-36410,-25080, 64277,-46341,-12785, 60547,-54491},
                                        {65536,-54491, 25080, 12785,-46341, 64277,-60547, 36410},
                                        {65536,-64277, 60547,-54491, 46341,-36410, 25080,-12785}};
                                        
    Int#(FIXEDWIDTH) c[8] =   {46341, 65536, 65536, 65536, 65536, 65536, 65536, 65536};
        
    function Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) readCos();
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) cos = newVector;
        for(Integer y=0; y<8; y=y+1)
            for(Integer x=0; x<8; x=x+1)
                cos[y][x] = cosinus[y][x];
        return cos;
    endfunction
    
    function Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) rShift(Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) block, Integer len);
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) block_shifted = newVector;
        for(Integer y=0; y<8; y=y+1)
            for(Integer x=0; x<8; x=x+1)
                block_shifted[y][x] = block[y][x] >> len;
        return block_shifted;
    endfunction
    
    function Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) transpose(Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) block);
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) block_transposed = newVector;
        for(Integer y=0; y<8; y=y+1)
            for(Integer x=0; x<8; x=x+1)
                block_transposed[y][x] = block[x][y];
        return block_transposed;
    endfunction
        
    FIFO#(BLOCK) imageBlock <- mkFIFO;
   
    SystolicArray#(FIXEDWIDTH) matrixMulti_Mod1 <- mkSystolicArray;
    
    rule matrixMult_S_Cos;
        //$display("Compute s * Cos",$time);
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
        //printMatrix(syx);
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) cosyv = readCos();
        matrixMulti_Mod1.setMatrix(syx,cosyv);
    endrule
    
    SystolicArray#(FIXEDWIDTH) matrixMulti_Mod2 <- mkSystolicArray;
    
    rule matrixMult_Cos_SCos;
        //$display("Compute Cos * s * Cos",$time);
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) sCos <- matrixMulti_Mod1.getResult();
        sCos = rShift(sCos,valueOf(NONFRACTION));
        //printMatrix(sCos);
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) cosxu = readCos();
        cosxu = transpose(cosxu);
        //printMatrix(cosxu);
        matrixMulti_Mod2.setMatrix(cosxu,sCos);
    endrule
    
    FIFO#(Vector#(8,Vector#(8,Int#(FIXEDWIDTH)))) dctBlock <- mkFIFO;
    
    rule normalizeDCT;
        //$display("Compute CuCv * Cos * s * Cos",$time);
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) cosSCos <- matrixMulti_Mod2.getResult();
        //printMatrix(cosSCos);
        cosSCos = rShift(cosSCos,valueOf(NONFRACTION));
        //printMatrix(cosSCos);
        for(Integer u=0; u<8; u=u+1)
            for(Integer v=0; v<8; v=v+1)
                cosSCos[v][u] = c[v]*cosSCos[v][u];
        cosSCos = rShift(cosSCos,valueOf(NONFRACTION));
        //printMatrix(cosSCos);
        for(Integer u=0; u<8; u=u+1)
            for(Integer v=0; v<8; v=v+1)
                cosSCos[v][u] = c[u]*cosSCos[v][u];
        cosSCos = rShift(cosSCos,valueOf(NONFRACTION));
        //printMatrix(cosSCos);
        cosSCos = rShift(cosSCos,2);
        //printMatrix(cosSCos);
        dctBlock.enq(cosSCos);
    endrule
   
// Interface methods    
    method Action setBlock (Vector#(8,Vector#(8,UInt#(8))) block);
        imageBlock.enq(block);
    endmethod
    
    method ActionValue#(Vector#(8,Vector#(8,Int#(16)))) getBlock ();
        Vector#(8,Vector#(8,Int#(FIXEDWIDTH))) bl = dctBlock.first;
        //printMatrix(bl);
        Vector#(8,Vector#(8,Int#(16))) bl_trunc = newVector;
        for(Integer u=0; u<8; u=u+1)
            for(Integer v=0; v<8; v=v+1)
                begin
                Bit#(FIXEDWIDTH) bl_bit = pack(bl[u][v]);
                Bit#(16) bl_bit_sm = truncate(bl_bit);
                Int#(16) bl_Int_sm = unpack(bl_bit_sm);
                //if(bl[u][v]<0)
                  //  bl_Int_sm = -1*bl_Int_sm;
                bl_trunc[u][v] = bl_Int_sm;
                end
        dctBlock.deq;
        //printMatrix_16(bl_trunc);
        return bl_trunc;
    endmethod
    
endmodule

module mkDCTPassthrough(DCTOperator);

    FIFO#(BLOCK) blockFIFO <- mkSizedFIFO(fifoDepth);

    method Action setBlock (BLOCK block);
        blockFIFO.enq(block);
    endmethod
    
    method ActionValue#(Vector#(8,Vector#(8,Int#(16)))) getBlock ();
        BLOCK bl = blockFIFO.first;
        Vector#(8,Vector#(8,Int#(16))) outBlock = newVector;
        for(Integer i=0; i<8; i=i+1)
            for(Integer j=0; j<8; j=j+1)
                begin
                Bit#(8) pxBit = pack(bl[i][j]);
                Bit#(16) pxBitLa = extend(pxBit);
                outBlock[i][j] = unpack(pxBitLa);
                end
        blockFIFO.deq;
        return outBlock;
    endmethod
endmodule

endpackage
