package VectorDelayer;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import MIMO :: *;

Integer fifoDepth = 2;

(* always_ready, always_enabled *)
interface VectorDelayer#(numeric type scalarType);
    method Action setVector (Vector#(8,Int#(scalarType)) vec, Int#(6) delay);
    method ActionValue#(Int#(scalarType)) getElement ();
    method Action close();
endinterface

module mkVectorDelayer(VectorDelayer#(scalarType))
                                provisos(
                                    Add#(1, a__, scalarType),
                                    Add#(b__, scalarType, TMul#(scalarType, 8))
                                    );
 
    MIMOConfiguration cfg;
    cfg.unguarded = True;
    cfg.bram_based = False;
    MIMO#(8,1,8,Int#(scalarType)) _vec <- mkMIMO(cfg);
    Reg#(Int#(6)) offset <- mkRegU;
    Reg#(Bool) valid <- mkReg(False);

// Interface methods    
    method Action setVector (Vector#(8,Int#(scalarType)) vec, Int#(6) delay) if(!valid);
        offset <= delay;
        LUInt#(8) count = 8;
        _vec.enq(count,vec);
        valid <= True;
    endmethod
    
    method ActionValue#(Int#(scalarType)) getElement () if(valid);
        Vector#(1,Int#(scalarType)) value;
        if(offset>0)
            value[0] = 0;
        else
            begin
            if(_vec.deqReady)
                begin
                value = _vec.first;
                LUInt#(1) count = 1;
                _vec.deq(count);
                end
            else
                value[0] = 0;
            end
        if(offset < (-30))
            begin
            offset <= 0;
            valid <= False;
            end
        else
            offset <= offset - 1;
        return value[0];
    endmethod
    
    method Action close() if(valid);
        valid <= False;
        _vec.clear;
    endmethod
    
endmodule

endpackage
