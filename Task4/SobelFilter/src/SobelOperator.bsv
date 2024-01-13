package SobelOperator;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;

Integer fifoDepth = 50;

(* always_ready, always_enabled *)
interface SobelOperator;
// Add custom interface definitions
    method Action configure (UInt#(8) kernelLen);
    method Action insertPixel (UInt#(8) px);
    method ActionValue#(UInt#(8)) getGradMag ();
endinterface

module mkSobelOperator(SobelOperator);

    //Vector#(9,Int#(16)) Fx3; Fx3[0]=1; Fx3[1]=0; Fx3[2]=-1; Fx3[3]=2; Fx3[4]=0; Fx3[5]=-2; Fx3[6]=1; Fx3[7]=0; Fx3[8]=-1;
    //Vector#(9,Int#(16)) Fy3; Fy3[0]=1; Fy3[1]=2; Fy3[2]=1; Fy3[3]=0; Fy3[4]=0; Fy3[5]=0; Fy3[6]=-1; Fy3[7]=-2; Fy3[8]=-1;
    Int#(32) fx3[3][3] = {{1,0,-1},{2,0,-2},{1,0,-1}};
    Int#(32) fy3[3][3] = {{1,2,1},{0,0,0},{-1,-2,-1}};    
    Int#(32) fxy3Div = 8;
    
    Reg#(UInt#(8)) kernelSize <- mkReg(9);

    FIFO#(UInt#(8)) imageStencil <- mkSizedFIFO(fifoDepth);
    
    Reg#(Int#(32)) gx <- mkReg(0);
    Reg#(Int#(32)) gy <- mkReg(0);
    Reg#(UInt#(8)) index <- mkReg(0);
    
    FIFO#(UInt#(8)) g <- mkSizedFIFO(5);
    
    rule fold;
        if(index<kernelSize)
            begin
                Bit#(32) bpx = pack(extend(imageStencil.first));
                Int#(32) px = unpack(bpx);
                imageStencil.deq;
                UInt#(8) ind = index;
                if(kernelSize == 9)
                    begin
                        gx <= gx + fx3[ind][0] * px;
                        gy <= gy + fy3[ind][0] * px;
                    end
                //else if(kernelSize == 25)
                //else if(kernelSize == 49)
                index <= index + 1;
            end
        else
            begin
                //UInt#(32) gpx = abs(sqrt(pow(gx,2)+pow(gy,2)));
                Bit#(32) bgpx = pack(gx*gx+gy*gy);
                UInt#(32) gpx = unpack(bgpx);
                g.enq(truncate(gpx));
                index <= 0;
            end
    endrule
    
    method Action configure (UInt#(8) kernelLen);
        if(kernelLen == 3) kernelSize <= 9;
        else if(kernelLen == 5) kernelSize <= 25;
        else if(kernelLen == 7) kernelSize <= 49;
    endmethod
    
    method Action insertPixel (UInt#(8) px);
        imageStencil.enq(px);
    endmethod
    
    method ActionValue#(UInt#(8)) getGradMag ();
        UInt#(8) px = g.first;
        g.deq;
        return px;
    endmethod
    
endmodule

endpackage
