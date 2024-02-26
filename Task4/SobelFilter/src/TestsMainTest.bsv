package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import SobelFilter :: *;
    import AXI4_Lite_Master :: *;
    import AXI4_Lite_Types :: *;
    import AXI4_Slave :: *;
    import Connectable :: *;
    import GetPut :: *;
    import AXIGrayscaleReader :: *;
    import AXIGrayscaleWriter :: *;
    import BlueAXIBRAM :: *;
    import BRAM :: *;
    
    typedef 8 AXICONFIGADDRWIDTH;
    typedef 64 AXICONFIGDATAWIDTH;
    
    typedef 64 AXIIMAGEADDRWIDTH;
    typedef 8 AXIIMAGEDATAWIDTH;
    
    typedef  0  RSTATUS;
    typedef  8  WIMAGEADDR;
    typedef  16 WOUTPUTADDR;
    typedef  24 WRESX;
    typedef  32 WRESY;    
    typedef  40 WKERNELS;
    typedef  48 WEXEC;
    
    (* synthesize *)
    module [Module] mkTestsMainTest(TestHelper::TestHandler);
            
        Stmt s = {
            seq
                $display("Hello world!");
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
