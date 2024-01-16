package DCTBlock;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;

Integer fifoDepth = 50;

(* always_ready, always_enabled *)
interface DCTBlock;
// Add custom interface definitions
    method Action putBlock (Vector#(8,Vector#(8,UInt#(8))) block);
    method ActionValue#(Vector#(8,Vector#(8,UInt#(8)))) getBlock ();
endinterface

module mkDCTBlock(DCTBlock);

    Int#(32) cosBlock[8][8] = { { 1,  4,  5,   0,  -5, -4, -1},
                                { 6, 24, 30,   0, -30,-24, -6},
                                {15, 60, 75,   0, -75, 60, 15},
                                {20, 80,100,   0,-100,-80,-20},
                                {15, 60, 75,   0, -75, 60, 15},
                                { 6, 24, 30,   0, -30,-24, -6},
                                { 1,  4,  5,   0,  -5, -4, -1}};
    
    FIFO#(Vector#(8,Vector#(8,Int#(32)))) s_Block <- mkSizedFIFO(fifoDepth);
    
    Reg#(Vector#(8,Vector#(8,Int#(32)))) sum_S_Block <- mkReg(0);
    Reg#(UInt#(32)) sum_cout <-mkReg(64);
    
    FIFO#(Vector#(8,Vector#(8,Int#(32)))) S_Block <- mkSizedFIFO(fifoDepth);
    
    function Tuple2#(UInt#(32),UInt#(32)) ind_to_xy(UInt#(32) ind);
        UInt#(32) x = ind%8;
        UInt#(32) y = ind/8;
        return tuple2(x,y);
    endfunction
    
    rule sum;
        if(sum_cout<64)
            begin
            Vector#(8,Vector#(8,Int#(32))) sum_S_Block_CC = sum_S_Block;
            for(Integer y=0; y<8; y=y+1)
                for(Integer x=0; x<8; x=x+1)
                    begin
                    Int#(32) Cu = 1;
                    Int#(32) Cv = 1;
                    if(x==0)
                        Cu = 2;
                    if(y==0)
                        Cv = 2;
                    sum_S_Block_CC[y][x] = Cu*Cv*sum_S_Block_CC / 4;
                    sum_S_Block[y][x] <= 0;
                    end
            sum_cout <= 0;
            s_Block.deq;
            S_Block.enq(sum_S_Block_CC);
            end
        else
            begin
            Vector#(8,Vector#(8,Int#(32))) s = s_Block.first;
            for(Integer u=0; u<8; u=u+1)
                for(Integer v=0; v<8; v=v+1)
                    begin
                    Tuple2#(UInt#(32),UInt#(32)) xy = ind_to_xy(sum_cout);
                    UInt#(32) x = tpl_1(xy);
                    UInt#(32) y = tpl_2(xy);
                    sum_S_Block[u][v] <= sum_S_Block[u][v] + s[x][y]*cosBlock[x][u]*cosBlock[y][v];
                    end
            sum_cout <= sum_cout + 1;
            end
    endrule
    
    method Action putBlock (Vector#(8,Vector#(8,UInt#(8))) block);
        s_Block.enq(block);
    endmethod
    
    method ActionValue#(UInt#(8)) getBlock ();
        Vector#(8,Vector#(8,UInt#(8))) S = S_Block.first;
        S_Block.deq;
        return S;
    endmethod
    
endmodule

endpackage
