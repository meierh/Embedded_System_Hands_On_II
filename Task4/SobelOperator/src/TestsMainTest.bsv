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
                    dut.configure(Sobel3);
                endaction
                action
                    $display("Insert stencil");
                    Vector#(7,Vector#(7,UInt#(8))) stencil = newVector;
                    for(Integer y=0; y<7; y=y+1)
                        for(Integer x=0; x<7; x=x+1)
                            if(x > 3)
                                stencil[y][x] = 255;//fromInteger(y*x*5);
                            else
                                stencil[y][x] = 0;
                    dut.insertStencil(stencil);
                endaction
                delay(1000);
                action
                    UInt#(8) res <- dut.getGradMag;
                    $display("Got value %d",(res));
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
