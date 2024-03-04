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
    method Action insertStencil (Vector#(7,Vector#(7,UInt#(8))) stencil);
    method ActionValue#(UInt#(8)) getGradMag ();
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
        
        Vector#(7,Vector#(7,Int#(32))) extStencil = newVector;
        Vector#(7,Vector#(7,Int#(32))) extKernel = newVector;
        for(Integer y=0; y<7; y=y+1)
            for(Integer x=0; x<7; x=x+1)
                begin
                extStencil[y][x] = signExtend(_imageStencil[y][x]);
                extKernel[y][x] = signExtend(kernel[y][x]);
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
                extMultX[y][x] = extStencil[y][x]*extKernel[y][x];
                extMultY[y][x] = extStencil[y][x]*extKernel[x][y];
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
    endrule

// Sum rows of multiplied stencil

// Summation 1
    FIFO#(Vector#(7,Vector#(4,Int#(FIXEDWIDTH)))) summed_rows1_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Vector#(4,Vector#(7,Int#(FIXEDWIDTH)))) summed_rows1_y <- mkSizedFIFO(fifoDepth);
    
    rule sum_rows1;
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _multipled_x = multipled_x.first;
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _multipled_y = multipled_y.first;
        multipled_x.deq;
        multipled_y.deq;
        
        Vector#(7,Vector#(4,Int#(FIXEDWIDTH))) _sum_Row1_x = newVector;
        Vector#(4,Vector#(7,Int#(FIXEDWIDTH))) _sum_Row1_y = newVector;
        
        for(Integer i=0; i<7; i=i+1)
            begin
            _sum_Row1_x[i][0] = _multipled_x[i][0] + _multipled_x[i][6];
            _sum_Row1_x[i][1] = _multipled_x[i][1] + _multipled_x[i][5];
            _sum_Row1_x[i][2] = _multipled_x[i][2] + _multipled_x[i][4]; 
            _sum_Row1_x[i][3] = _multipled_x[i][3]; 
            _sum_Row1_y[0][i] = _multipled_y[0][i] + _multipled_y[6][i];
            _sum_Row1_y[1][i] = _multipled_y[1][i] + _multipled_y[5][i];
            _sum_Row1_y[2][i] = _multipled_y[2][i] + _multipled_y[4][i]; 
            _sum_Row1_y[3][i] = _multipled_y[3][i]; 
            end
            
        summed_rows1_x.enq(_sum_Row1_x);
        summed_rows1_y.enq(_sum_Row1_y);
    endrule
    
// Summation 2
    FIFO#(Vector#(4,Vector#(4,Int#(FIXEDWIDTH)))) summed_cols1_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Vector#(4,Vector#(4,Int#(FIXEDWIDTH)))) summed_cols1_y <- mkSizedFIFO(fifoDepth);
    
    rule sum_cols1;
        Vector#(7,Vector#(4,Int#(FIXEDWIDTH))) _sum_Row1_x = summed_rows1_x.first;
        Vector#(4,Vector#(7,Int#(FIXEDWIDTH))) _sum_Row1_y = summed_rows1_y.first;
        summed_rows1_x.deq;
        summed_rows1_y.deq;
        
        Vector#(4,Vector#(4,Int#(FIXEDWIDTH))) _sum_Col1_x = newVector;
        Vector#(4,Vector#(4,Int#(FIXEDWIDTH))) _sum_Col1_y = newVector;
        
        for(Integer i=0; i<4; i=i+1)
            begin
            _sum_Col1_x[0][i] = _sum_Row1_x[0][i] + _sum_Row1_x[6][i];
            _sum_Col1_x[1][i] = _sum_Row1_x[1][i] + _sum_Row1_x[5][i];
            _sum_Col1_x[2][i] = _sum_Row1_x[2][i] + _sum_Row1_x[4][i]; 
            _sum_Col1_x[3][i] = _sum_Row1_x[3][i]; 
            _sum_Col1_y[i][0] = _sum_Row1_y[i][0] + _sum_Row1_y[i][6];
            _sum_Col1_y[i][1] = _sum_Row1_y[i][1] + _sum_Row1_y[i][5];
            _sum_Col1_y[i][2] = _sum_Row1_y[i][2] + _sum_Row1_y[i][4]; 
            _sum_Col1_y[i][3] = _sum_Row1_y[i][3]; 
            end
            
        summed_cols1_x.enq(_sum_Col1_x);
        summed_cols1_y.enq(_sum_Col1_y);
    endrule
    
// Summation 3
    FIFO#(Vector#(4,Vector#(2,Int#(FIXEDWIDTH)))) summed_rows2_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Vector#(2,Vector#(4,Int#(FIXEDWIDTH)))) summed_rows2_y <- mkSizedFIFO(fifoDepth);
    
    rule sum_rows2;
        Vector#(4,Vector#(4,Int#(FIXEDWIDTH))) _sum_Col1_x = summed_cols1_x.first;
        Vector#(4,Vector#(4,Int#(FIXEDWIDTH))) _sum_Col1_y = summed_cols1_y.first;
        summed_cols1_x.deq;
        summed_cols1_y.deq;
        
        Vector#(4,Vector#(2,Int#(FIXEDWIDTH))) _sum_Row2_x = newVector;
        Vector#(2,Vector#(4,Int#(FIXEDWIDTH))) _sum_Row2_y = newVector;
        
        for(Integer i=0; i<4; i=i+1)
            begin
            _sum_Row2_x[i][0] = _sum_Col1_x[i][0] + _sum_Col1_x[i][2];
            _sum_Row2_x[i][1] = _sum_Col1_x[i][1] + _sum_Col1_x[i][3];
            _sum_Row2_y[0][i] = _sum_Col1_y[0][i] + _sum_Col1_y[2][i];
            _sum_Row2_y[1][i] = _sum_Col1_y[1][i] + _sum_Col1_y[3][i];
            end
            
        summed_rows2_x.enq(_sum_Row2_x);
        summed_rows2_y.enq(_sum_Row2_y);
    endrule
    
// Summation 4
    FIFO#(Vector#(2,Vector#(2,Int#(FIXEDWIDTH)))) summed_cols2_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Vector#(2,Vector#(2,Int#(FIXEDWIDTH)))) summed_cols2_y <- mkSizedFIFO(fifoDepth);
    
    rule sum_cols2;
        Vector#(4,Vector#(2,Int#(FIXEDWIDTH))) _sum_Row2_x = summed_rows2_x.first;
        Vector#(2,Vector#(4,Int#(FIXEDWIDTH))) _sum_Row2_y = summed_rows2_y.first;
        summed_rows2_x.deq;
        summed_rows2_y.deq;
        
        Vector#(2,Vector#(2,Int#(FIXEDWIDTH))) _sum_Col2_x = newVector;
        Vector#(2,Vector#(2,Int#(FIXEDWIDTH))) _sum_Col2_y = newVector;
        
        for(Integer i=0; i<2; i=i+1)
            begin
            _sum_Col2_x[0][i] = _sum_Row2_x[0][i] + _sum_Row2_x[2][i];
            _sum_Col2_x[1][i] = _sum_Row2_x[1][i] + _sum_Row2_x[3][i];
            _sum_Col2_y[i][0] = _sum_Row2_y[i][0] + _sum_Row2_y[i][2];
            _sum_Col2_y[i][1] = _sum_Row2_y[i][1] + _sum_Row2_y[i][3];
            end
            
        summed_cols2_x.enq(_sum_Col2_x);
        summed_cols2_y.enq(_sum_Col2_y);
    endrule
    
// Summation 5
    FIFO#(Vector#(2,Int#(FIXEDWIDTH))) summed_rows3_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Vector#(2,Int#(FIXEDWIDTH))) summed_rows3_y <- mkSizedFIFO(fifoDepth);
    
    rule sum_rows3;
        Vector#(2,Vector#(2,Int#(FIXEDWIDTH))) _sum_Col2_x = summed_cols2_x.first;
        Vector#(2,Vector#(2,Int#(FIXEDWIDTH))) _sum_Col2_y = summed_cols2_y.first;
        summed_cols2_x.deq;
        summed_cols2_y.deq;
        
        Vector#(2,Int#(FIXEDWIDTH)) _sum_Row3_x = newVector;
        Vector#(2,Int#(FIXEDWIDTH)) _sum_Row3_y = newVector;
        
        for(Integer i=0; i<2; i=i+1)
            begin
            _sum_Row3_x[i] = _sum_Col2_x[i][0] + _sum_Col2_x[i][1];
            _sum_Row3_y[i] = _sum_Col2_y[0][i] + _sum_Col2_y[1][i];
            end
            
        summed_rows3_x.enq(_sum_Row3_x);
        summed_rows3_y.enq(_sum_Row3_y);
    endrule
    
    FIFO#(Int#(FIXEDWIDTH)) summed_cols3_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Int#(FIXEDWIDTH)) summed_cols3_y <- mkSizedFIFO(fifoDepth);
    
// Summation 6
    rule sum_cols3;
        Vector#(2,Int#(FIXEDWIDTH)) _sum_Row3_x = summed_rows3_x.first;
        Vector#(2,Int#(FIXEDWIDTH)) _sum_Row3_y = summed_rows3_y.first;
        summed_rows3_x.deq;
        summed_rows3_y.deq;
        
        Int#(FIXEDWIDTH) _sum_Col3_x = _sum_Row3_x[0]+_sum_Row3_x[1];
        Int#(FIXEDWIDTH) _sum_Col3_y = _sum_Row3_y[0]+_sum_Row3_y[1];
            
        summed_cols3_x.enq(_sum_Col3_x);
        summed_cols3_y.enq(_sum_Col3_y);
    endrule
        
// Take norm of sobel filter x and y
    FIFO#(UInt#(8)) sobel_full <- mkSizedFIFO(fifoDepth);
    
    rule norm;
        Int#(FIXEDWIDTH) _sobel_x = summed_cols3_x.first;
        summed_cols3_x.deq;
        Int#(FIXEDWIDTH) _sobel_y = summed_cols3_y.first;
        summed_cols3_y.deq;
        
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
    
    method Action insertStencil(Vector#(7,Vector#(7,UInt#(8))) stencil);
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) signedStencil = newVector;
        for(Integer i=0; i<7; i=i+1)
            for(Integer j=0; j<7; j=j+1)
                begin
                Bit#(8) stencil_b = pack(stencil[i][j]);
                Bit#(FIXEDWIDTH) stencil_b_large = extend(stencil_b);
                signedStencil[i][j] = unpack(stencil_b_large);
                end
        imageStencil.enq(signedStencil);
    endmethod
    
    method ActionValue#(UInt#(8)) getGradMag ();
        UInt#(8) px = sobel_full.first;
        sobel_full.deq;
        return px;
    endmethod
    
endmodule

module mkSobelPassthrough(SobelOperator);

    FIFO#(UInt#(8)) sobel <- mkSizedFIFO(fifoDepth);

    method Action configure (FilterType kernelType);

    endmethod

    method Action insertStencil (Vector#(7,Vector#(7,UInt#(8))) stencil);
        sobel.enq(stencil[3][3]);
    endmethod
    
    method ActionValue#(UInt#(8)) getGradMag ();
        UInt#(8) px = sobel.first;
        sobel.deq;
        return px;
    endmethod
endmodule 
endpackage
