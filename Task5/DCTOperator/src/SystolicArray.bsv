package SystolicArray;

import List :: * ;
import Vector :: * ;
import FIFO :: * ;
import Real :: * ;
import VectorDelayer :: *;

typedef enum {
    Ready = 2'b00,
    Working = 2'b01,
    Done = 2'b10
    } SysArrayState deriving (Bits,Eq);
    
function Action printMatrix_16 (Vector#(8,Vector#(8,Int#(16))) matrix);
    action
    $display("----------------------------------------------------------------");
    for(Integer y=0; y<8; y=y+1)
        begin
        for(Integer x=0; x<8; x=x+1)
            $write("%d ",matrix[y][x]);
        $display(" ");
        end
    $display("----------------------------------------------------------------");
    endaction
endfunction  

Integer fifoDepth = 50;

(* always_ready, always_enabled *)
interface SystolicArray#(numeric type scalarType);
    method Action setMatrix (Vector#(8,Vector#(8,Int#(scalarType))) matA, Vector#(8,Vector#(8,Int#(scalarType))) matB);
    method ActionValue#(Vector#(8,Vector#(8,Int#(scalarType)))) getResult ();
endinterface

module mkSystolicArray(SystolicArray#(scalarType))
                                provisos(
                                    Add#(a__, scalarType, TMul#(scalarType, 8)),
                                    Add#(1, b__, scalarType)/*,
                                
                                    Add#(1, b__, scalarType),
                                    Add#(a__, scalarType, TMul#(scalarType, 8)),
                                    IsModule#(_m__, _c__),
                                    Bits#(Vector::Vector#(8, Vector::Vector#(8, Int#(scalarType))), c__),
                                    Add#(scalarType,0,16)
                                    */
                                    
                                    );

    Reg#(SysArrayState) status <- mkReg(Ready);
    
    FIFO#(Vector#(8,Vector#(8,Int#(scalarType)))) _matA <- mkSizedFIFO(fifoDepth);
    FIFO#(Vector#(8,Vector#(8,Int#(scalarType)))) _matB <- mkSizedFIFO(fifoDepth);
    
    Vector#(8,VectorDelayer#(scalarType)) _matA_vecs = newVector;
    Vector#(8,VectorDelayer#(scalarType)) _matB_vecs = newVector;
    for(Integer i=0; i<8; i=i+1)
        begin
        _matA_vecs[i] <- mkVectorDelayer;
        _matB_vecs[i] <- mkVectorDelayer;
        end
    
    Vector#(8,Vector#(8,Reg#(Int#(scalarType)))) sysArrSums = newVector;
    Vector#(8,Vector#(8,Reg#(Int#(scalarType)))) sysArrAValues = newVector;
    Vector#(8,Vector#(8,Reg#(Int#(scalarType)))) sysArrBValues = newVector;
    for(Integer y=0; y<8; y=y+1)
        for(Integer x=0; x<8; x=x+1)
            begin
            sysArrSums[y][x] <- mkRegU;
            sysArrAValues[y][x] <- mkRegU;
            sysArrBValues[y][x] <- mkRegU;
            end
            
    Reg#(UInt#(6)) counter <- mkRegU;
    
    rule fillVectorDelayers (status==Ready);
        Vector#(8,Vector#(8,Int#(scalarType))) matA = _matA.first;
        _matA.deq;
        Vector#(8,Vector#(8,Int#(scalarType))) matB = _matB.first;
        _matB.deq;
        
        //Process matA and enter in Vector delayer
        for(Integer y=0; y<8; y=y+1)
            begin
            Vector#(8,Int#(scalarType)) oneVec = newVector;
            for(Integer x=0; x<8; x=x+1)
                oneVec[x] = matA[y][x];
            _matA_vecs[y].setVector(oneVec,fromInteger(y));
            end
            
        //Process matB and enter in Vector delayer
        for(Integer x=0; x<8; x=x+1)
            begin
            Vector#(8,Int#(scalarType)) oneVec = newVector;
            for(Integer y=0; y<8; y=y+1)
                oneVec[y] = matB[y][x];
            _matB_vecs[x].setVector(oneVec,fromInteger(x));
            end
            
        // Initialize systolic array to zero
        for(Integer y=0; y<8; y=y+1)
            for(Integer x=0; x<8; x=x+1)
                begin
                sysArrSums[y][x] <= 0;
                sysArrAValues[y][x] <= 0;
                sysArrBValues[y][x] <= 0;
                end
                
        status <= Working;
        counter <= 0;
    endrule
    
    rule flowData (status==Working);
        if(counter < 24)
            begin
            // Insert values of matrix A on side and shift
            for(Integer y=0; y<8; y=y+1)
                begin
                Int#(scalarType) valA <- _matA_vecs[y].getElement();
                sysArrAValues[y][0] <= valA;
                for(Integer x=0; x<7; x=x+1)
                    sysArrAValues[y][x+1] <= sysArrAValues[y][x];
                end
            // Insert values of matrix B on side and shift
            for(Integer x=0; x<8; x=x+1)
                begin
                Int#(scalarType) valB <- _matB_vecs[x].getElement();
                sysArrBValues[0][x] <= valB;
                for(Integer y=0; y<7; y=y+1)
                    sysArrBValues[y+1][x] <= sysArrBValues[y][x];
                end
            // Muliply and add
            for(Integer y=0; y<8; y=y+1)
                for(Integer x=0; x<8; x=x+1)
                    begin
                    sysArrSums[y][x] <= sysArrSums[y][x] + sysArrAValues[y][x]*sysArrBValues[y][x];
                    end

            counter <= counter + 1;
            /*
            $display("Counter %d",counter);
            $display("sysArrSums:");
            Vector#(8,Vector#(8,Int#(16))) _sysArrSums = newVector;
            Vector#(8,Vector#(8,Int#(16))) _sysArrA = newVector;
            Vector#(8,Vector#(8,Int#(16))) _sysArrB = newVector;
            for(Integer y=0; y<8; y=y+1)
                for(Integer x=0; x<8; x=x+1)
                    begin
                    _sysArrSums[y][x] = sysArrSums[y][x];
                    _sysArrA[y][x] = sysArrAValues[y][x];
                    _sysArrB[y][x] = sysArrBValues[y][x];
                    end
            $display("_sysArrA:");
            printMatrix_16(_sysArrA);
            $display("_sysArrB:");
            printMatrix_16(_sysArrB);
            $display("_sysArrSums:");
            printMatrix_16(_sysArrSums);
            */
            end
        else
            begin
            status <= Done;
            for(Integer y=0; y<8; y=y+1)
                _matA_vecs[y].close();            
            for(Integer x=0; x<8; x=x+1)
                _matB_vecs[x].close();
            end
    endrule
    
    FIFO#(Vector#(8,Vector#(8,Int#(scalarType)))) _matC <- mkSizedFIFO(fifoDepth);

    rule pullResult(status==Done);
        Vector#(8,Vector#(8,Int#(scalarType))) result = newVector;
        for(Integer y=0; y<8; y=y+1)
            for(Integer x=0; x<8; x=x+1)
                begin
                result[y][x] = sysArrSums[y][x];
                end
        _matC.enq(result);
    endrule
    
// Interface methods    
    method Action setMatrix (Vector#(8,Vector#(8,Int#(scalarType))) matA, Vector#(8,Vector#(8,Int#(scalarType))) matB);
        _matA.enq(matA);
        _matB.enq(matB);
    endmethod
    
    method ActionValue#(Vector#(8,Vector#(8,Int#(scalarType)))) getResult ();
        Vector#(8,Vector#(8,Int#(scalarType))) matC = _matC.first;
        _matC.deq;
        return matC;
    endmethod
    
endmodule

endpackage
