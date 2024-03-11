package SobelOperator;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import SobelTypes :: * ;
import BRAMFIFO :: * ;
import FIFOF :: * ;

typedef 22 FIXEDWIDTH;

Integer fifoDepth = 1;

(* always_ready, always_enabled *)
interface SobelOperator;
// Add custom interface definitions
    method Action configure (FilterType kernelType);
    method Action insertStencil (Vector#(7,Vector#(7,UInt#(8))) stencil);
    method ActionValue#(UInt#(8)) getGradMag ();
endinterface

module mkSobelOperator(SobelOperator);

// Kernels 
    // Bitpattern[Sign:1, Nonfraction:9, Fraction:12]
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
    
    FIFOF#(Vector#(7,Vector#(7,Int#(FIXEDWIDTH)))) imageStencil <- mkSizedBRAMFIFOF(fifoDepth*10);

// Multiply kernel with pixel stencil    
    FIFOF#(Vector#(7,Vector#(7,Int#(FIXEDWIDTH)))) multipled_x <- mkSizedBRAMFIFOF(fifoDepth);
    FIFOF#(Vector#(7,Vector#(7,Int#(FIXEDWIDTH)))) multipled_y <- mkSizedBRAMFIFOF(fifoDepth);

    rule multiply;
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _imageStencil = imageStencil.first;
        imageStencil.deq;
                
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _multipled_x = newVector;
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _multipled_y = newVector;
        for(Integer y=0; y<7; y=y+1)
            for(Integer x=0; x<7; x=x+1)
                begin
                _multipled_x[y][x] = _imageStencil[y][x]*kernel[y][x];
                _multipled_y[y][x] = _imageStencil[y][x]*kernel[x][y];
                end
                
        multipled_x.enq(_multipled_x);
        multipled_y.enq(_multipled_y);
    endrule

// Sum rows of multiplied stencil

// Summation 1
    FIFOF#(Vector#(7,Vector#(2,Int#(FIXEDWIDTH)))) summed_rows1_x <- mkSizedFIFOF(fifoDepth);
    FIFOF#(Vector#(2,Vector#(7,Int#(FIXEDWIDTH)))) summed_rows1_y <- mkSizedFIFOF(fifoDepth);
    
    rule sum_rows1;
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _multipled_x = multipled_x.first;
        Vector#(7,Vector#(7,Int#(FIXEDWIDTH))) _multipled_y = multipled_y.first;
        multipled_x.deq;
        multipled_y.deq;
        
        Vector#(7,Vector#(2,Int#(FIXEDWIDTH))) _sum_Row1_x = newVector;
        Vector#(2,Vector#(7,Int#(FIXEDWIDTH))) _sum_Row1_y = newVector;
        
        for(Integer i=0; i<7; i=i+1)
            begin
            _sum_Row1_x[i][0] = _multipled_x[i][0] + _multipled_x[i][1] + _multipled_x[i][2] + _multipled_x[i][3];
            _sum_Row1_x[i][1] = _multipled_x[i][4] + _multipled_x[i][5] + _multipled_x[i][6];
            _sum_Row1_y[0][i] = _multipled_y[0][i] + _multipled_y[1][i] + _multipled_y[2][i] + _multipled_y[3][i];
            _sum_Row1_y[1][i] = _multipled_y[1][i] + _multipled_y[5][i] + _multipled_y[6][i];
            end
            
        summed_rows1_x.enq(_sum_Row1_x);
        summed_rows1_y.enq(_sum_Row1_y);
    endrule
    
// Summation 2
    FIFOF#(Vector#(2,Vector#(2,Int#(FIXEDWIDTH)))) summed_cols1_x <- mkSizedFIFOF(fifoDepth);
    FIFOF#(Vector#(2,Vector#(2,Int#(FIXEDWIDTH)))) summed_cols1_y <- mkSizedFIFOF(fifoDepth);
    
    rule sum_cols1;
        Vector#(7,Vector#(2,Int#(FIXEDWIDTH))) _sum_Row1_x = summed_rows1_x.first;
        Vector#(2,Vector#(7,Int#(FIXEDWIDTH))) _sum_Row1_y = summed_rows1_y.first;
        summed_rows1_x.deq;
        summed_rows1_y.deq;
        
        Vector#(2,Vector#(2,Int#(FIXEDWIDTH))) _sum_Col1_x = newVector;
        Vector#(2,Vector#(2,Int#(FIXEDWIDTH))) _sum_Col1_y = newVector;
        
        for(Integer i=0; i<2; i=i+1)
            begin
            _sum_Col1_x[0][i] = _sum_Row1_x[0][i] + _sum_Row1_x[1][i] + _sum_Row1_x[2][i] + _sum_Row1_x[3][i];
            _sum_Col1_x[1][i] = _sum_Row1_x[4][i] + _sum_Row1_x[5][i] + _sum_Row1_x[6][i];
            _sum_Col1_y[i][0] = _sum_Row1_y[i][0] + _sum_Row1_y[i][1] + _sum_Row1_y[i][2] + _sum_Row1_y[i][3];
            _sum_Col1_y[i][1] = _sum_Row1_y[i][4] + _sum_Row1_y[i][5] + _sum_Row1_y[i][6];
            end
            
        summed_cols1_x.enq(_sum_Col1_x);
        summed_cols1_y.enq(_sum_Col1_y);
    endrule
        
// Summation 5
    FIFO#(Int#(FIXEDWIDTH)) summed_cols3_x <- mkSizedFIFO(fifoDepth);
    FIFO#(Int#(FIXEDWIDTH)) summed_cols3_y <- mkSizedFIFO(fifoDepth);
    
    rule sum_rows3;
        Vector#(2,Vector#(2,Int#(FIXEDWIDTH))) _sum_Col1_x = summed_cols1_x.first;
        Vector#(2,Vector#(2,Int#(FIXEDWIDTH))) _sum_Col1_y = summed_cols1_y.first;
        summed_cols1_x.deq;
        summed_cols1_y.deq;
        
        Int#(FIXEDWIDTH) _sum_Row3_x = _sum_Col1_x[0][0] + _sum_Col1_x[1][0] + _sum_Col1_x[0][1] + _sum_Col1_x[1][1];
        Int#(FIXEDWIDTH) _sum_Row3_y = _sum_Col1_y[0][0] + _sum_Col1_y[1][0] + _sum_Col1_y[0][1] + _sum_Col1_y[1][1];
        
        summed_cols3_x.enq(_sum_Row3_x);
        summed_cols3_y.enq(_sum_Row3_y);
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
        bSobel = bSobel >> 12;
        Bit#(8) truncBSobel = truncate(bSobel);
        UInt#(8) _sobel = unpack(truncBSobel);
        sobel_full.enq(_sobel);
        
        $display("sobel: %d  sobel_x: %d  sobel_y %d  || extSobel: %d",_sobel,_sobel_x,_sobel_y,extSobel);
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
