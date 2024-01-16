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
    method Action insertStencil (Vector#(7,Vector#(7,UInt#(8))) stencil);
    method ActionValue#(UInt#(8)) getGradMag ();
endinterface

module mkSobelOperator(SobelOperator);

    Int#(32) fx3[3][3] = {{ 1, 0,-1},
                          { 2, 0,-2},
                          { 1, 0,-1}};
    Int#(32) fxy3Div = 8;
    
    Int#(32) fx5[5][5] = {{ 1, 2, 0, -2,-1},
                          { 4, 8, 0, -8,-4},
                          { 6,12, 0,-12,-6},
                          { 4, 8, 0, -8,-4},
                          { 1, 2, 0, -2,-1}};
    Int#(32) fxy5Div = 96;
    
    Int#(32) fx7[7][7] = {{ 1,  4,  5,   0,  -5, -4, -1},
                          { 6, 24, 30,   0, -30,-24, -6},
                          {15, 60, 75,   0, -75, 60, 15},
                          {20, 80,100,   0,-100,-80,-20},
                          {15, 60, 75,   0, -75, 60, 15},
                          { 6, 24, 30,   0, -30,-24, -6},
                          { 1,  4,  5,   0,  -5, -4, -1}};
    Int#(32) fxy7Div = 1280;
    
    Reg#(FilterType) _kernelType <- mkReg(Sobel3);
    Reg#(Vector#(7,Vector#(7,Int#(32)))) kernel <- mkRegU();

    FIFO#(Vector#(7,Vector#(7,Int#(32)))) imageStencil <- mkSizedFIFO(fifoDepth);
    
    FIFO#(Vector#(7,Vector#(7,Int#(32)))) multipled_x <- mkSizedFIFO(fifoDepth*7);
    FIFO#(Vector#(7,Vector#(7,Int#(32)))) multipled_y <- mkSizedFIFO(fifoDepth*7);
    
    rule multiply
        Vector#(7,Vector#(7,Int#(32))) _imageStencil = imageStencil.first;
        Vector#(7,Vector#(7,Int#(32))) _multipled_x;
        Vector#(7,Vector#(7,Int#(32))) _multipled_y;
        for(Integer y=0; y<7; y=y+1)
            for(Integer x=0; x<7; x=x+1)
                begin
                _multipled_x[y][x] = stencil[y][x]*kernel[y][x];
                _multipled_y[y][x] = stencil[y][x]*kernel[x][y];
                end
        multipled_x.enq(_multipled_x);
        multipled_y.enq(_multipled_y);
    endrule
    
    Reg#(Vector#(7,Int#(32))) sum_Row_x <- mkReg(0);
    Reg#(Vector#(7,Int#(32))) sum_Row_y <- mkReg(0);
    Reg#(UInt#(3)) sum_ind_x <- mkReg(0);
    
    FIFO#(Vector#(7,Int#(32))) summed_row_mult_x <- mkSizedFIFO(fifoDepth*7);
    FIFO#(Vector#(7,Int#(32))) summed_row_mult_y <- mkSizedFIFO(fifoDepth*7);
    
    rule sum_rows;
        if(sum_ind_x<7)
            begin
            Vector#(7,Vector#(7,Int#(32))) _multipled_x = multipled_x.first;
            Vector#(7,Vector#(7,Int#(32))) _multipled_y = multipled_y.first;
            for(Integer y=0; y<7; y=y+1)
                begin
                sum_Row_x[y] <= sum_Row_x[y] + _multipled_x[y][sum_ind_x];
                sum_Row_y[y] <= sum_Row_y[y] + _multipled_y[y][sum_ind_x];
                sum_ind_x <= sum_ind_x + 1;
                end
            end
        else
            begin
            multipled_x.deq;
            multipled_y.deq;
            summed_row_mult_x.enq(sum_Row_x);
            summed_row_mult_y.enq(sum_Row_y);
            sum_ind_x <= 0;
            sum_Row_x <= 0;
            sum_Row_y <= 0;
            end
    endrule
    
    Reg#(Int#(32)) sum_Col_x <- mkReg(0);
    Reg#(Int#(32)) sum_Col_y <- mkReg(0);
    Reg#(UInt#(3)) sum_ind_y <- mkReg(0);
    
    FIFO#(Int#(32) sobel_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Int#(32) sobel_y <- mkSizedFIFO(fifoDepth);
    
    rule sum_cols;
        if(sum_ind_y<7)
            begin
            Vector#(7,Int#(32)) _summed_row_mult_x = summed_row_mult_x.first;
            Vector#(7,Int#(32)) _summed_row_mult_y = summed_row_mult_y.first;            
            sum_Col_x <= sum_Col_x + _summed_row_mult_x[sum_ind_y];
            sum_Col_y <= sum_Col_y + _summed_row_mult_y[sum_ind_y];
            sum_ind_y <= sum_ind_y + 1;
            end
        else
            begin
            summed_row_mult_x.deq;
            summed_row_mult_y.deq;
            sobel_x.enq(sum_Col_x);
            sobel_y.enq(sum_Col_y);
            sum_ind_y <= 0;
            sum_Col_x <= 0;
            sum_Col_y <= 0;
            end
    endrule
    
    FIFO#(UInt#(8)) sobel <- mkSizedFIFO(fifoDepth);
    
    rule norm;
        Int#(32) _sobel_x = sobel_x.first;
        gx.deq;
        Int#(32) _sobel_y = sobel_y.first;
        gy.deq;
        Bit#(32) b_sobel_x = pack(_sobel_x);
        Bit#(32) b_sobel_y = pack(_sobel_y);
        UInt#(32) u_sobel_x = unpack(b_sobel_x);
        UInt#(32) u_sobel_y = unpack(b_sobel_y);
        UInt#(32) _sobel_large = u_sobel_x*u_sobel_y;
        UInt#(8) _sobel = truncate(_sobel_large);
        sobel.enq(_sobel);
    endrule
    
    method Action configure (FilterType kernelType);
        _kernelType <= kernelType;
        Integer offset = case(kernelType)
                        Sobel3 : return 2;
                        Sobel5 : return 1;
                        Sobel7 : return 0;
                        endcase;
        Vector#(7,Vector#(7,Int#(32))) k;
        for(Integer x=0; x<7; x=x+1)
            for(Integer y=0; y<7; y=y+1)
                begin
                    kx[y][x] = 0;
                    Integer locX = x-offset;
                    Integer locY = y-offset;
                    if(kernelType==Sobel3)
                        if(locX>=0 && locX<offset && locY>=0 && locY<offset)
                            k[y][x] = fx3[locY][locX];
                    else if(kernelType==Sobel5)
                        if(locX>=0 && locX<offset && locY>=0 && locY<offset)
                            k[y][x] = fx5[locY][locX];
                    else
                        if(locX>=0 && locX<offset && locY>=0 && locY<offset)
                            k[y][x] = fx7[locY][locX];
                end
        kernel <= k;
    endmethod
    
    method Action insertStencil (Vector#(7,Vector#(7,UInt#(8))) stencil);
        Vector#(7,Vector#(7,Int#(32))) signedStencil = newVector;
        for(Integer i=0; i<7; i=i+1)
            for(Integer j=0; j<7; j=j+1)
                begin
                Bit#(8) stencil_b = pack(stencil[i][j]);
                Bit#(32) stencil_b_large = extend(stencil_b);
                signedStencil[i][j] = unpack(stencil_b_large);
                end
        imageStencil.enq(signedStencil);
    endmethod
    
    method ActionValue#(UInt#(8)) getGradMag ();
        UInt#(8) px = sobel.first;
        sobel.deq;
        return px;
    endmethod
    
endmodule

endpackage
