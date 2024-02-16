package SobelOperator;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import SobelTypes :: * ;

typedef 22 FIXEDWIDTH;

Integer fifoDepth = 50;

(* always_ready, always_enabled *)
interface SobelOperator;
// Add custom interface definitions
    method Action configure (FilterType kernelType);
    method Action insertStencil (Tuple2#(Vector#(7,Vector#(7,UInt#(8))),Bool) stencil);
    method ActionValue#(Tuple2#(UInt#(8),Bool)) getGradMag ();
endinterface

module mkSobelOperator(SobelOperator);

// Kernels 
    // Bitpattern[Sign:1, Nonfraction:7, Fraction:14]
    Int#(FIXEDWIDTH) fx3[7][7] =   {{0 ,0 ,   0, 0,    0, 0, 0},
                                    {0 ,0 ,   0, 0,    0, 0, 0},
                                    {0 ,0 , 512, 0, -512, 0, 0},
                                    {0 ,0 ,1024, 0,-1024, 0, 0},
                                    {0 ,0 , 512, 0, -512, 0, 0},
                                    {0 ,0 ,   0, 0,    0, 0, 0},
                                    {0 ,0 ,   0, 0,    0, 0, 0}};
    
    Int#(FIXEDWIDTH) fx5[7][7] =   {{0 ,   0,   0, 0,    0,    0, 0},
                                    {0 , 171, 341, 0, -341, -171, 0},
                                    {0 , 683,1365, 0,-1365, -683, 0},
                                    {0 ,1024,2048, 0,-2048,-1024, 0},
                                    {0 , 683,1365, 0,-1365, -683, 0},
                                    {0 , 171, 341, 0, -341, -171, 0},
                                    {0 ,   0,   0, 0,    0,    0, 0}};
    
    Int#(FIXEDWIDTH) fx7[7][7] =   {{ 3, 13, 16, 0, -16, -13, -3},
                                    {19, 77, 96, 0, -96, -77,-19},
                                    {48,192,240, 0,-240, 192, 48},
                                    {64,256,320, 0,-320,-256,-64},
                                    {48,192,240, 0,-240, 192, 48},
                                    {19, 77, 96, 0, -96, -77,-19},
                                    { 3, 13, 16, 0, -16, -13, -3}};
    
    Reg#(Vector#(7,Vector#(7,Int#(FIXEDWIDTH)))) kernel <- mkRegU();
    
    FIFO#(Vector#(7,Vector#(7,Int#(FIXEDWIDTH)))) imageStencil <- mkSizedFIFO(fifoDepth);
    FIFO#(Bool) imageStencil_valid <- mkSizedFIFO(fifoDepth);

// Multiply kernel with pixel stencil    
    FIFO#(Vector#(7,Vector#(7,Int#(FIXEDWIDTH)))) multipled_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Vector#(7,Vector#(7,Int#(FIXEDWIDTH)))) multipled_y <- mkSizedFIFO(fifoDepth);
    FIFO#(Bool) multipled_valid <- mkSizedFIFO(fifoDepth);

    rule multiply;
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _imageStencil = imageStencil.first;
        $display("imageStencil:");
        printStencil_20(_imageStencil);
        $display("kernel:");
        printStencil_20(kernel);
        imageStencil.deq;
        Bool valid = imageStencil_valid.first;
        imageStencil_valid.deq;
        
        Vector#(7,Vector#(7,Int#(32))) extStencil = newVector;
        Vector#(7,Vector#(7,Int#(32))) extKernelX = newVector;
        Vector#(7,Vector#(7,Int#(32))) extKernelY = newVector;
        for(Integer y=0; y<7; y=y+1)
            for(Integer x=0; x<7; x=x+1)
                begin
                extStencil[y][x] = signExtend(_imageStencil[y][x]);
                extKernelX[y][x] = signExtend(kernel[y][x]);
                extKernelY[y][x] = signExtend(kernel[x][y]);
                end
        /*
        $display("extStencil:");
        printStencil_32(extStencil);
        $display("extKernelX:");
        printStencil_32(extKernelX);
        $display("extKernelY:");
        printStencil_32(extKernelY);
        */
          
        Vector#(7,Vector#(7,Int#(32))) extMultX = newVector;
        Vector#(7,Vector#(7,Int#(32))) extMultY = newVector;
        for(Integer y=0; y<7; y=y+1)
            for(Integer x=0; x<7; x=x+1)
                begin
                extMultX[y][x] = extStencil[y][x]*extKernelX[y][x];
                extMultY[y][x] = extStencil[y][x]*extKernelY[y][x];
                end
            
        /*
        $display("extMultX:");
        printStencil_32(extMultX);
        $display("extMultY:");
        printStencil_32(extMultY);
        */
        
        /*
        for(Integer y=0; y<7; y=y+1)
            for(Integer x=0; x<7; x=x+1)
                begin
                extMultX[y][x] = extMultX[y][x] >> 12;
                extMultY[y][x] = extMultY[y][x] >> 12;
                end
        */
                
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _multipled_x = newVector;
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _multipled_y = newVector;
        for(Integer y=0; y<7; y=y+1)
            for(Integer x=0; x<7; x=x+1)
                begin
                Int#(FIXEDWIDTH) multX = truncate(extMultX[y][x]);
                Int#(FIXEDWIDTH) multY = truncate(extMultY[y][x]);
                _multipled_x[y][x] = multX;
                _multipled_y[y][x] = multY;
                end
        
        $display("_multipled_x:");
        printStencil_20(_multipled_x);
        $display("_multipled_y:");
        printStencil_20(_multipled_y);
                
        multipled_x.enq(_multipled_x);
        multipled_y.enq(_multipled_y);
        multipled_valid.enq(valid);
    endrule

// Sum rows of multiplied stencil
    Vector#(7,Int#(FIXEDWIDTH)) nulVec = newVector;
    for(Integer i=0; i<7; i=i+1)
        nulVec[i] = 0;
    Reg#(Vector#(7,Int#(FIXEDWIDTH))) sum_Row_x <- mkReg(nulVec);    
    Reg#(Vector#(7,Int#(FIXEDWIDTH))) sum_Row_y <- mkReg(nulVec);
    Reg#(UInt#(3)) sum_ind_x <- mkReg(0);
    
    FIFO#(Vector#(7,Int#(FIXEDWIDTH))) summed_row_mult_x <- mkSizedFIFO(fifoDepth*7);
    FIFO#(Vector#(7,Int#(FIXEDWIDTH))) summed_row_mult_y <- mkSizedFIFO(fifoDepth*7);
    FIFO#(Bool) summed_row_mult_valid <- mkSizedFIFO(fifoDepth);
    
    rule sum_rows;
        if(sum_ind_x<7)
            begin
            Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _multipled_x = multipled_x.first;
            Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _multipled_y = multipled_y.first;
            /*
            $display("_multipled_x:");
            printStencil_20(_multipled_x);
            $display("_multipled_y:");
            printStencil_20(_multipled_y);
            */
            Vector#(7,Int#(FIXEDWIDTH)) _sum_Row_x = sum_Row_x;
            Vector#(7,Int#(FIXEDWIDTH)) _sum_Row_y = sum_Row_y;
            for(Integer y=0; y<7; y=y+1)
                begin
                _sum_Row_x[y] = _sum_Row_x[y] + _multipled_x[y][sum_ind_x];
                _sum_Row_y[y] = _sum_Row_y[y] + _multipled_y[y][sum_ind_x];
                end
            sum_ind_x <= sum_ind_x + 1;
            sum_Row_x <= _sum_Row_x;
            sum_Row_y <= _sum_Row_y;
            
            /*
            $display("%d : sum_Row_x:",sum_ind_x);
            printVector_20(sum_Row_x);
            $display("%d : sum_Row_y:",sum_ind_x);
            printVector_20(sum_Row_y);
            */
            end
        else
            begin
            multipled_x.deq;
            multipled_y.deq;
            Bool valid = multipled_valid.first;
            multipled_valid.deq;
            summed_row_mult_x.enq(sum_Row_x);
            summed_row_mult_y.enq(sum_Row_y);
            summed_row_mult_valid.enq(valid);
            sum_ind_x <= 0;
            Vector#(7,Int#(FIXEDWIDTH)) nul = newVector;
            for(Integer i=0; i<7; i=i+1)
                nul[i] = 0;
            sum_Row_x <= nul;
            sum_Row_y <= nul;
            
            $display("sum_Row_x:");
            printVector_20(sum_Row_x);
            $display("sum_Row_y:");
            printVector_20(sum_Row_y);
            
            end
    endrule
    
// Sum columns of multipled stencil
    Reg#(Int#(FIXEDWIDTH)) sum_Col_x <- mkReg(0);
    Reg#(Int#(FIXEDWIDTH)) sum_Col_y <- mkReg(0);
    Reg#(UInt#(3)) sum_ind_y <- mkReg(0);
    
    FIFO#(Int#(FIXEDWIDTH)) sobel_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Int#(FIXEDWIDTH)) sobel_y <- mkSizedFIFO(fifoDepth);
    FIFO#(Bool) sobel_valid <- mkSizedFIFO(fifoDepth);
    
    rule sum_cols;
        if(sum_ind_y<7)
            begin
            Vector#(7,Int#(FIXEDWIDTH)) _summed_row_mult_x = summed_row_mult_x.first;
            Vector#(7,Int#(FIXEDWIDTH)) _summed_row_mult_y = summed_row_mult_y.first;            
            sum_Col_x <= sum_Col_x + _summed_row_mult_x[sum_ind_y];
            sum_Col_y <= sum_Col_y + _summed_row_mult_y[sum_ind_y];
            sum_ind_y <= sum_ind_y + 1;
            end
        else
            begin
            Bool valid = summed_row_mult_valid.first;
            summed_row_mult_x.deq;
            summed_row_mult_y.deq;
            summed_row_mult_valid.deq;
            sobel_x.enq(sum_Col_x);
            sobel_y.enq(sum_Col_y);
            sobel_valid.enq(valid);
            sum_ind_y <= 0;
            sum_Col_x <= 0;
            sum_Col_y <= 0;
            
            $display("sobel_X: %d",sum_Col_x);
            $display("sobel_Y: %d",sum_Col_y);
            end
    endrule
    
// Take norm of sobel filter x and y
    FIFO#(UInt#(8)) sobel_full <- mkSizedFIFO(fifoDepth);
    FIFO#(Bool) sobel_full_valid <- mkSizedFIFO(fifoDepth);
    
    rule norm;
        Int#(FIXEDWIDTH) _sobel_x = sobel_x.first;
        sobel_x.deq;
        Int#(FIXEDWIDTH) _sobel_y = sobel_y.first;
        sobel_y.deq;
        Bool valid = sobel_valid.first;
        sobel_valid.deq;
        
        Int#(32) extSobelX = signExtend(_sobel_x);
        Int#(32) extSobelY = signExtend(_sobel_y);
        Int#(32) extSobel = extSobelX+extSobelY;
        if(extSobel<0)
            extSobel = -1*extSobel;
        Bit#(32) bSobel = pack(extSobel);
        bSobel = bSobel >> 14;
        Bit#(8) truncBSobel = truncate(bSobel);
        UInt#(8) _sobel = unpack(truncBSobel);
        sobel_full.enq(_sobel);
        sobel_full_valid.enq(valid);
        
        $display("sobel: %d",_sobel);
    endrule
    
// Interface methods
    method Action configure (FilterType kernelType);
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) k = newVector;
        for(Integer x=0; x<7; x=x+1)
            for(Integer y=0; y<7; y=y+1)
                begin
                    if(kernelType==Sobel3)
                        k[y][x] = fx3[y][x];
                    else if(kernelType==Sobel5)
                        k[y][x] = fx5[y][x];
                    else
                        k[y][x] = fx7[y][x];
                end
        kernel <= k;
    endmethod
    
    method Action insertStencil (Tuple2#(Vector#(7,Vector#(7,UInt#(8))),Bool) stencil);
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) signedStencil = newVector;
        for(Integer i=0; i<7; i=i+1)
            for(Integer j=0; j<7; j=j+1)
                begin
                Bit#(8) stencil_b = pack(tpl_1(stencil)[i][j]);
                Bit#(FIXEDWIDTH) stencil_b_large = extend(stencil_b);
                signedStencil[i][j] = unpack(stencil_b_large);
                end
        imageStencil.enq(signedStencil);
        imageStencil_valid.enq(tpl_2(stencil));
    endmethod
    
    method ActionValue#(Tuple2#(UInt#(8),Bool)) getGradMag ();
        UInt#(8) px = sobel_full.first;
        sobel_full.deq;
        Bool valid = sobel_full_valid.first;
        sobel_full_valid.deq;
        return tuple2(px,valid);
    endmethod
    
endmodule

module mkSobelPassthrough(SobelOperator);

    FIFO#(Tuple2#(UInt#(8),Bool)) sobel <- mkSizedFIFO(fifoDepth);

    method Action configure (FilterType kernelType);

    endmethod

    method Action insertStencil (Tuple2#(Vector#(7,Vector#(7,UInt#(8))),Bool) stencil);
        Vector#(7,Vector#(7,UInt#(8))) stencilData = tpl_1(stencil);
        Bool stencilValid = tpl_2(stencil);
        sobel.enq(tuple2(stencilData[3][3],stencilValid));
    endmethod
    
    method ActionValue#(Tuple2#(UInt#(8),Bool)) getGradMag ();
        Tuple2#(UInt#(8),Bool) px = sobel.first;
        sobel.deq;
        return px;
    endmethod
endmodule 
endpackage
