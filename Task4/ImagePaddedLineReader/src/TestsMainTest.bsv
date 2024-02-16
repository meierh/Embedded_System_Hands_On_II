package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import AXI4_Slave :: *;
    import Connectable :: *;
    import AXIGrayscaleReader :: *;
    import AXIGrayscaleWriter :: *;
    import BlueAXIBRAM :: *;
    import BRAM :: *;
    import ClientServer :: *;
    import Vector :: *;
    import FIFO :: * ;

    (* synthesize *)
    module [Module] mkTestsMainTest(TestHelper::TestHandler);
        
        AXIGrayscaleReader#(32,128,6,3,4,2000,16,16) read <- mkAXIGrayscaleReader();
        AXIGrayscaleWriter#(32,128,4,4,4,4,2000) write <- mkAXIGrayscaleWriter(16);
    
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
                action
                    let _window <- read.getWindow();
                    $display("Valid x %d -- valid y %d",tpl_1(_window),tpl_2(_window),$time);
                    for(Integer y=0; y<3; y=y+1)
                        begin
                        for(Integer x=0; x<6; x=x+1)
                            $write("%d ",tpl_3(_window)[y][x]);
                        $display(" ");
                        end
                endaction
                
                /*
                $display("Put request bram hexImage!");
                action
                    bram.portA.request.put(BRAMRequestBE {writeen: 0, responseOnWrite: False, address: 0, datain: 0});
                endaction
                action
                    let data <- bram.portA.response.get();
                    $display("Data: %b",data);
                endaction
                */
                delay(1000);
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
