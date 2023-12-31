package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import Adder :: *;
    import AXI4_Lite_Master :: *;
    import AXI4_Lite_Types :: *;
    import Connectable :: *;
    import GetPut :: *;

    (* synthesize *)
    module [Module] mkTestsMainTest(TestHelper::TestHandler);

        Adder testedModule <- mkAdder();
        
        AXI4_Lite_Master_Wr#(8,32) masterWrite <- mkAXI4_Lite_Master_Wr(1);
        mkConnection(masterWrite.fab, testedModule.s_wr);
        
        AXI4_Lite_Master_Rd#(8,32) masterRead <- mkAXI4_Lite_Master_Rd(1);
        mkConnection(masterRead.fab, testedModule.s_rd);
        
        Stmt s = {
            seq
                $display("Writing value to a: 13");
                action
                    let reqA = AXI4_Lite_Write_Rq_Pkg {addr:8'b00000000, data:13, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(reqA);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respA <- masterWrite.response.get();
                endaction
                
                $display("Writing value to b: 87");
                action
                    let reqB = AXI4_Lite_Write_Rq_Pkg {addr:8'b00000100, data:87, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(reqB);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respB <- masterWrite.response.get();
                endaction
                
                action
                    let reqC = AXI4_Lite_Read_Rq_Pkg {addr:8'b00001000, prot:UNPRIV_SECURE_DATA};
                    masterRead.request.put(reqC);
                endaction
                action
                    let respC <- masterRead.response.get();
                    Int#(32) result = unpack(respC.data);
                    $display("Result response: %d", result);
                endaction
                
                action
                    let reqC = AXI4_Lite_Read_Rq_Pkg {addr:8'b00001000, prot:UNPRIV_SECURE_DATA};
                    masterRead.request.put(reqC);
                endaction
                action
                    let respC <- masterRead.response.get();
                    Int#(32) result = unpack(respC.data);
                    $display("Result response: %d", result);
                endaction
                
                $display("Writing value to a: 33");
                action
                    let reqA = AXI4_Lite_Write_Rq_Pkg {addr:8'b00000000, data:33, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(reqA);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respA <- masterWrite.response.get();
                endaction
                
                action
                    let reqC = AXI4_Lite_Read_Rq_Pkg {addr:8'b00001000, prot:UNPRIV_SECURE_DATA};
                    masterRead.request.put(reqC);
                endaction
                action
                    let respC <- masterRead.response.get();
                    Int#(32) result = unpack(respC.data);
                    $display("Result response: %d", result);
                endaction
                
                $display("Writing value to b: 57");
                action
                    let reqB = AXI4_Lite_Write_Rq_Pkg {addr:8'b00000100, data:57, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(reqB);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respB <- masterWrite.response.get();
                endaction
                
                action
                    let reqC = AXI4_Lite_Read_Rq_Pkg {addr:8'b00001000, prot:UNPRIV_SECURE_DATA};
                    masterRead.request.put(reqC);
                endaction
                action
                    let respC <- masterRead.response.get();
                    Int#(32) result = unpack(respC.data);
                    $display("Result response: %d", result);
                endaction
                
                $display("Writing value to b: 27");
                action
                    let reqB = AXI4_Lite_Write_Rq_Pkg {addr:8'b00000100, data:27, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(reqB);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respB <- masterWrite.response.get();
                endaction
            
                $display("Writing value to b: -43");
                action
                    let reqB = AXI4_Lite_Write_Rq_Pkg {addr:8'b00000100, data:-43, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    masterWrite.request.put(reqB);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respB <- masterWrite.response.get();
                endaction
                
                action
                    let reqC = AXI4_Lite_Read_Rq_Pkg {addr:8'b00001000, prot:UNPRIV_SECURE_DATA};
                    masterRead.request.put(reqC);
                endaction
                action
                    let respC <- masterRead.response.get();
                    Int#(32) result = unpack(respC.data);
                    $display("Result response: %d", result);
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
