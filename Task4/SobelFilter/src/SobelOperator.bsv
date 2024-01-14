package SobelOperator;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import SobelTypes :: * ;

Integer fifoDepth = 50;

(* always_ready, always_enabled *)
interface SobelOperator;
// Add custom interface definitions
    method Action configure (FilterType kernelType);
    method Action insertStencil (Vector#(9,Vector#(9,UInt#(8))) stencil);
    method ActionValue#(UInt#(8)) getGradMag ();
endinterface

module mkSobelOperator(SobelOperator);

    //Vector#(9,Int#(16)) Fx3; Fx3[0]=1; Fx3[1]=0; Fx3[2]=-1; Fx3[3]=2; Fx3[4]=0; Fx3[5]=-2; Fx3[6]=1; Fx3[7]=0; Fx3[8]=-1;
    //Vector#(9,Int#(16)) Fy3; Fy3[0]=1; Fy3[1]=2; Fy3[2]=1; Fy3[3]=0; Fy3[4]=0; Fy3[5]=0; Fy3[6]=-1; Fy3[7]=-2; Fy3[8]=-1;
    Int#(32) fx3[3][3] = {{1,0,-1},{2,0,-2},{1,0,-1}};
    Int#(32) fy3[3][3] = {{1,2,1},{0,0,0},{-1,-2,-1}};    
    Int#(32) fxy3Div = 8;
    
    Reg#(FilterType) _kernelType <- mkReg(Sobel3);
    Reg#(Vector#(9,Vector#(9,Int#(32)))) kernel_x <- mkRegU();
    Reg#(Vector#(9,Vector#(9,Int#(32)))) kernel_y <- mkRegU();
    Reg#(Int#(32)) div <- mkRegU();

    FIFO#(Vector#(9,Vector#(9,Int#(32)))) imageStencil <- mkSizedFIFO(fifoDepth);
    
    FIFO#(Vector#(9,Vector#(9,Int#(32)))) mult_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Vector#(9,Vector#(9,Int#(32)))) mult_y <- mkSizedFIFO(fifoDepth);

    rule multiply;
        Vector#(9,Vector#(9,Int#(32))) stencil = imageStencil.first;
        imageStencil.deq;
        Vector#(9,Vector#(9,Int#(32))) stencil_x = newVector;
        Vector#(9,Vector#(9,Int#(32))) stencil_y = newVector;
        for(Integer x=0; x<9; x=x+1)
            for(Integer y=0; y<9; y=y+1)
                begin
                    stencil_x[y][x] = stencil[y][x]*kernel_x[y][x];
                    stencil_y[y][x] = stencil[y][x]*kernel_y[y][x];
                end
        mult_x.enq(stencil_x);
        mult_y.enq(stencil_y);
    endrule
    
    FIFO#(Int#(32)) gx <- mkSizedFIFO(fifoDepth);
    FIFO#(Int#(32)) gy <- mkSizedFIFO(fifoDepth);
    
    rule sumStencil;
        Vector#(9,Vector#(9,Int#(32))) stencil_x = mult_x.first;
        mult_x.deq;
        Vector#(9,Vector#(9,Int#(32))) stencil_y = mult_y.first;
        mult_y.deq;
        Int#(32) gx_sum = 0;
        Int#(32) gy_sum = 0;
        for(Integer x=0; x<9; x=x+1)
            for(Integer y=0; y<9; y=y+1)
                begin
                    gx_sum = gx_sum + stencil_x[y][x];
                    gy_sum = gy_sum + stencil_y[y][x];
                end
        gx.enq(gx_sum);
        gy.enq(gy_sum);
    endrule
    
    FIFO#(UInt#(8)) g <- mkSizedFIFO(fifoDepth);
    
    rule combineDims;
        Int#(32) _gx = gx.first;
        gx.deq;
        Int#(32) _gy = gy.first;
        gy.deq;
        Int#(32) _g = _gx*_gx+_gy*_gy;
        Bit#(32) unsigned_g_b = pack(_g);
        UInt#(32) unsigned_g = unpack(unsigned_g_b);
        UInt#(8) unsigned_g_tr = truncate(unsigned_g);
        g.enq(unsigned_g_tr);
    endrule
    
    method Action configure (FilterType kernelType);
        _kernelType <= kernelType;
        Integer offset = case(kernelType)
                        Sobel3 : return 3;
                        Sobel5 : return 2;
                        Sobel7 : return 1;
                        Sobel9 : return 0;
                        endcase;
        for(Integer x=0; x<9; x=x+1)
            for(Integer y=0; y<9; y=y+1)
                begin
                    kernel_x[y][x] <= 0;
                    kernel_y[y][x] <= 0;
                    Integer locX = x-offset;
                    Integer locY = y-offset;
                    if(kernelType==Sobel3)
                        begin
                        div <= fxy3Div;
                        if(locX>=0 && locX<offset && locY>=0 && locY<offset)
                            begin
                            kernel_x[y][x] <= fx3[locY][locX];
                            kernel_y[y][x] <= fy3[locY][locX];
                            end
                        end
                end
    endmethod
    
    method Action insertStencil (Vector#(9,Vector#(9,UInt#(8))) stencil);
        Vector#(9,Vector#(9,Int#(32))) signedStencil;
        for(Integer i=0; i<9; i=i+1)
            for(Integer j=0; j<9; j=j+1)
                begin
                Bit#(8) stencil_b = pack(stencil[i][j]);
                Bit#(32) stencil_b_large = extend(stencil_b);
                signedStencil[i][j] = unpack(stencil_b_large);
                end
        imageStencil.enq(signedStencil);
    endmethod
    
    method ActionValue#(UInt#(8)) getGradMag ();
        UInt#(8) px = g.first;
        g.deq;
        return px;
    endmethod
    
endmodule

endpackage
