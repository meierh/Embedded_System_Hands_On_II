package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import SobelFilter :: *;
    import AXI4_Lite_Master :: *;
    import AXI4_Lite_Types :: *;
    import AXI4_Slave :: *;
    import Connectable :: *;
    import GetPut :: *;
    
    typedef 8 AXICONFIGADDRWIDTH;
    typedef 64 AXICONFIGDATAWIDTH;
    
    typedef 64 AXIIMAGEADDRWIDTH;
    typedef 8 AXIIMAGEDATAWIDTH;
    typedef 1 AXIIMAGEIDWIDTH;
    typedef 1 AXIIMAGEUSERWIDTH;
    
    typedef  0  RSTATUS;
    typedef  8  WIMAGEADDR;
    typedef  16 WOUTPUTADDR;
    typedef  24 WRESX;
    typedef  32 WRESY;    
    typedef  40 WKERNELS;
    typedef  48 WEXEC;
    
    (* synthesize *)
    module [Module] mkTestsMainTest(TestHelper::TestHandler);

        SobelFilter testedModule <- mkSobelFilter();
        
        AXI4_Lite_Master_Wr#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) masterWrite <- mkAXI4_Lite_Master_Wr(1);
        mkConnection(masterWrite.fab, testedModule.axiC_wr);
        AXI4_Lite_Master_Rd#(AXICONFIGADDRWIDTH,AXICONFIGDATAWIDTH) masterRead <- mkAXI4_Lite_Master_Rd(1);
        mkConnection(masterRead.fab, testedModule.axiC_rd);
        
        AXI4_Slave_Wr#(AXIIMAGEADDRWIDTH,AXIIMAGEDATAWIDTH,AXIIMAGEIDWIDTH,AXIIMAGEUSERWIDTH) slaveWrite <- mkAXI4_Slave_Wr(1,1,1);
        mkConnection(slaveWrite.fab, testedModule.axiD_wr);
        AXI4_Slave_Rd#(AXIIMAGEADDRWIDTH,AXIIMAGEDATAWIDTH,AXIIMAGEIDWIDTH,AXIIMAGEUSERWIDTH) slaveRead <- mkAXI4_Slave_Rd(1,1);
        mkConnection(slaveRead.fab, testedModule.axiD_rd);

        Stmt s = {
            seq
                action
                    let reqC = AXI4_Lite_Read_Rq_Pkg {addr:0, prot:UNPRIV_SECURE_DATA};
                    masterRead.request.put(reqC);
                endaction
                action
                    let respC <- masterRead.response.get();
                    Bit#(64) result = unpack(respC.data);
                    $display("RSTATUS     %h", result);
                endaction

                action
                    Bit#(64) addrIn = 256;
                    let req = AXI4_Lite_Write_Rq_Pkg {addr:8, data:addrIn, strb:8'b11111111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(req);
                    $display("WIMAGEADDR  %h",addrIn);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg resp <- masterWrite.response.get();
                    $display("W Resp      %b",resp.resp);
                endaction
                
                action
                    Bit#(64) addrOut = 4096;
                    let req = AXI4_Lite_Write_Rq_Pkg {addr:16, data:addrOut, strb:8'b11111111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(req);
                    $display("WOUTPUTADDR %h",addrOut);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg resp <- masterWrite.response.get();
                    $display("W Resp      %b",resp.resp);
                endaction
                
                action
                    Bit#(64) addrOut = 1920;
                    let req = AXI4_Lite_Write_Rq_Pkg {addr:24, data:addrOut, strb:8'b11111111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(req);
                    $display("WRESX       %h",addrOut);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg resp <- masterWrite.response.get();
                    $display("W Resp      %b",resp.resp);
                endaction
                
                action
                    Bit#(64) addrOut = 1080;
                    let req = AXI4_Lite_Write_Rq_Pkg {addr:32, data:addrOut, strb:8'b11111111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(req);
                    $display("WRESY       %h",addrOut);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg resp <- masterWrite.response.get();
                    $display("W Resp      %b",resp.resp);
                endaction
                
                action
                    Bit#(64) addrOut = 6;
                    let req = AXI4_Lite_Write_Rq_Pkg {addr:40, data:addrOut, strb:8'b11111111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(req);
                    $display("WKERNELS    %h",addrOut);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg resp <- masterWrite.response.get();
                    $display("W Resp      %b",resp.resp);
                endaction
                
                action
                    //Bit#(64) addrOut = 9;
                    let req = AXI4_Lite_Write_Rq_Pkg {addr:48, data:0, strb:8'b11111111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(req);
                    $display("WEXEC");
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg resp <- masterWrite.response.get();
                    $display("W Resp      %b",resp.resp);
                endaction
                
                action
                    let reqC = AXI4_Lite_Read_Rq_Pkg {addr:0, prot:UNPRIV_SECURE_DATA};
                    masterRead.request.put(reqC);
                endaction
                action
                    let respC <- masterRead.response.get();
                    Bit#(64) result = unpack(respC.data);
                    $display("RSTATUS     %h", result);
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
