package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import Vector :: *;
    import VectorDelayer :: *;
    import SystolicArray :: *;
    import DCTOperator :: *;

    (* synthesize *)
    module [Module] mkTestsMainTest(TestHelper::TestHandler);

        DCTOperator dut <- mkDCTOperator();
        VectorDelayer#(8) vecDel <- mkVectorDelayer();
        SystolicArray#(16) sysArr <- mkSystolicArray();
        
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
        
        rule printOutVectorDelayer;
            Int#(8) out <- vecDel.getElement();
            $display("Out: %d",out);
        endrule

        Stmt s = {
            seq
                action
                    Vector#(8,Int#(8)) enter = newVector;
                    for(Integer i=0; i<8; i=i+1)
                        enter[i] = fromInteger(i+1);
                    vecDel.setVector(enter,8);
                    $display("Set vector");
                endaction
                delay(100);
                action
                    $display("Set matA and matB");
                    Vector#(8,Vector#(8,Int#(16))) matA = newVector;
                    Vector#(8,Vector#(8,Int#(16))) matB = newVector;
                    for(Integer y=0; y<8; y=y+1)
                        for(Integer x=0; x<8; x=x+1)
                            begin
                            matA[y][x] = fromInteger(y*8+x);
                            matB[y][x] = fromInteger((y-8)*8+(x-8));
                            end
                    sysArr.setMatrix(matA,matB);
                    printMatrix_16(matA);
                    printMatrix_16(matB);
                endaction
                delay(1000);
                action
                    Vector#(8,Vector#(8,Int#(16))) matC <- sysArr.getResult();
                    printMatrix_16(matC);
                endaction
            endseq
        };
        FSM testFSM <- mkFSM(s);

        method Action go();
            testFSM.start();
        endmethod

        method Bool done();
            return testFSM.done();
        endmethod
    endmodule

endpackage
