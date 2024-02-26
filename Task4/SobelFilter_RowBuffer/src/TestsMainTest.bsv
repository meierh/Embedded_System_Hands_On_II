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
    
        AXIGrayscaleReader#(32,128,6,3,4,1100,16,16) read <- mkAXIGrayscaleReader();
        AXIGrayscaleWriter#(32,128,16,16,1100) write <- mkAXIGrayscaleWriter();
    
        BRAM_Configure cfg = defaultValue;
        cfg.memorySize = 2048;
        cfg.loadFormat = tagged Hex "hexImage.hex";
        BRAM1PortBE #(Bit#(32), Bit#(128), TDiv#(128,8)) bram <- mkBRAM1ServerBE(cfg);
        BlueAXIBRAM#(32,128,1) memory <- mkBlueAXIBRAM(bram.portA);
        mkConnection(memory.rd, read.axi4Fab);
        mkConnection(memory.wr, write.axi4Fab);
        
        Stmt s = {
            seq
                $display("Hex Image read!");
                action
                    let valid <- read.configure(0,17,9);
                endaction
                action
                    let _window <- read.getWindow();
                    $display("Valid x %d -- valid y %d",tpl_1(_window),tpl_2(_window),$time);
                    for(Integer y=0; y<3; y=y+1)
                        begin
                        for(Integer x=0; x<6; x=x+1)
                            $write("%d ",tpl_3(_window)[y][x]);
                        $display(" ");
                        end
                    $display("----------------------------------------------------------------");
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
