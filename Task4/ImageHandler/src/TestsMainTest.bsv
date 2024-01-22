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

        AXIGrayscaleReader#(64,128,6,6,4,4,2000,16) read <- mkAXIGrayscaleReader();
        AXIGrayscaleWriter#(64,128,4,4,4,4,2000) write <- mkAXIGrayscaleWriter(16);
        
        AXI4_Slave_Rd#(64,128,1,0) slaveRead <- mkAXI4_Slave_Rd(1,1);
        AXI4_Slave_Wr#(64,128,1,0) slaveWrite <- mkAXI4_Slave_Wr(1,1,1);
        mkConnection(slaveRead.fab, read.axi4Fab);
        mkConnection(slaveWrite.fab, write.axi4Fab);
    
        /*
        BRAM_Configure cfg = defaultValue;
        cfg.memorySize = 108;
        cfg.loadFormat = tagged Hex "hexImage.hex";
        BRAM1PortBE #(Bit#(8), Bit#(8), TDiv#(8,8)) bram <- mkBRAM1ServerBE(cfg);
        BlueAXIBRAM#(64,8,1) memory <- mkBlueAXIBRAM(bram.portA);
        mkConnection(memory.rd, read.axi4Fab);
        mkConnection(memory.wr, write.axi4Fab);
        */
        
        /*
        Vector#(9,Vector#(12,Bit#(8))) image;
        Integer count = 1;
        for(Integer y=0;y<9;y=y+1)
            for(Integer x=0;x<12;x=x+1)
                begin
                if(x==0) image[y][x] = 0;
                else if(x==11) image[y][x] = 0;
                else if(y==0) image[y][x] = 0;
                else if(y==8) image[y][x] = 0;
                else 
                    begin
                    image[y][x] = fromInteger(count);
                    count = count + 1;
                    end
                end
                
        Vector#(108,Bit#(8)) memory;
        count = 0;
        for(Integer y=0;y<9;y=y+1)
            for(Integer x=0;x<12;x=x+1)
                begin
                memory[count] = image[y][x];
                count = count + 1;
                end
        
        
        rule read
            slaveRead.request.get()
        endrule
        */
        
        Stmt s = {
            seq
                $display("Configure hexImage!");
                action
                    let valid <- read.configure(0,12,9);
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
