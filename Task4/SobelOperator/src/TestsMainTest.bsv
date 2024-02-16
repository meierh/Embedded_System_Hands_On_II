package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import SobelOperator :: *;
    import SobelTypes :: *;
    import Vector :: *;

    (* synthesize *)
    module [Module] mkTestsMainTest(TestHelper::TestHandler);   
    
        SobelOperator dut <- mkSobelOperator();

        Stmt s = {
            seq
                action
                    $display("Sobel Operator configure");
                    dut.configure(Sobel5);
                endaction
                action
                    $display("Insert stencil");
                    Vector#(7,Vector#(7,UInt#(8))) stencil = newVector;
                    for(Integer y=0; y<7; y=y+1)
                        for(Integer x=0; x<7; x=x+1)
                            stencil[y][x] = fromInteger(y*x*5);
                    dut.insertStencil(tuple2(stencil,True));
                endaction
                delay(1000);
                action
                    Tuple2#(UInt#(8),Bool) res <- dut.getGradMag;
                    $display("Got value %d being valid %b",tpl_1(res),tpl_2(res));
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
