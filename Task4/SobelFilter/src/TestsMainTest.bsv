package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import SobelFilter :: *;

    (* synthesize *)
    module [Module] mkTestsMainTest(TestHelper::TestHandler);

        SobelFilter dut <- mkSobelFilter();

        Stmt s = {
            seq
                $display("Hello World from the testbench.");
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
