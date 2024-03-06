package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import DCT :: *;
    import BlueAXIBRAM :: *;
    import BRAM :: *;
    import AXIDCTBlockReader :: *;
    import AXIDCTBlockWriter :: *;
    import AXI4_Slave :: *;
    import AXI4_Types :: *;
    import AXI4_Lite_Master :: *;
    import AXI4_Lite_Types :: *;
    import AXI4_Master :: * ;
    import Connectable :: *;
    import Vector :: *;

    typedef enum {
        ReqAddr = 1'b0,
        ReqData = 1'b1
        } ResultReceiverStatus deriving (Bits,Eq);
    
    (* synthesize *)
    module [Module] mkTestsMainTest(TestHelper::TestHandler);

        DCT dctCore <- mkDCT();

        //Configuration AXIs
        AXI4_Lite_Master_Wr#(8,32) configWrite <- mkAXI4_Lite_Master_Wr(1);
        AXI4_Lite_Master_Rd#(8,32) configRead <- mkAXI4_Lite_Master_Rd(1);
        mkConnection(configWrite.fab, dctCore.axiC_wr);
        mkConnection(configRead.fab, dctCore.axiC_rd);

        AXI4_Master_Wr#(32,128,1,0) dummy <- mkAXI4_Master_Wr(1,1,1,False);

        //Data AXIs
        BRAM_Configure cfg = defaultValue;
        cfg.memorySize = 2048;
        cfg.loadFormat = tagged Hex "hexImage.hex";
        BRAM1PortBE #(Bit#(32), Bit#(128), TDiv#(128,8)) bram <- mkBRAM1ServerBE(cfg);
        BlueAXIBRAM#(32,128,1) memory <- mkBlueAXIBRAM(bram.portA);
        mkConnection(memory.wr, dummy.fab);
        mkConnection(memory.rd, dctCore.axiD_rd);
        
        AXI4_Slave_Wr#(32,128,1,0) resultReceiver <- mkAXI4_Slave_Wr(1,1,1);
        mkConnection(resultReceiver.fab, dctCore.axiD_wr);
        Reg#(ResultReceiverStatus) resRecStat <- mkReg(ReqAddr);
        
        Reg#(UInt#(8)) burstLength <- mkRegU;
        Reg#(Bit#(32)) burstAddr <- mkRegU;
        rule reqAddrRule (resRecStat==ReqAddr);
            AXI4_Write_Rq_Addr#(32,1,0) reqA <- resultReceiver.request_addr.get();
            burstLength <= reqA.burst_length;
            burstAddr <= reqA.addr;
            resRecStat <= ReqData;
            $display("Receive Burst to addr:%d with len: %d",reqA.addr,reqA.burst_length);
        endrule
        rule reqDataRule (resRecStat==ReqData);
            AXI4_Write_Rq_Data#(128,0) reqD <- resultReceiver.request_data.get();
            Bit#(128) reqData = reqD.data;
            Bool reqLast = reqD.last;
            
            Vector#(8,Bit#(16)) beat = newVector;
            Integer pixelBitStart = 127;
            for(Integer i=0; i<8; i=i+1)
                begin
                beat[i] = reqData[pixelBitStart:pixelBitStart-15];
                pixelBitStart = pixelBitStart - 16;
                end
            $display("Beat %d %d %d %d %d %d %d %d",beat[0],beat[1],beat[2],beat[3],beat[4],beat[5],beat[6],beat[7]);
            if(reqLast==True)
                resRecStat <= ReqAddr;
        endrule

        Stmt s = {
            seq
                action
                    let reqC = AXI4_Lite_Read_Rq_Pkg {addr:8'b00000000, prot:UNPRIV_SECURE_DATA};
                    configRead.request.put(reqC);
                endaction
                action
                    let respC <- configRead.response.get();
                    Int#(32) result = unpack(respC.data);
                    $display("Status response: %d", result);
                endaction
                
                action
                    let reqA = AXI4_Lite_Write_Rq_Pkg {addr:8'b00001000, data:0, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    configWrite.request.put(reqA);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respA <- configWrite.response.get();
                endaction

                action
                    let reqA = AXI4_Lite_Write_Rq_Pkg {addr:8'b00010000, data:1024, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    configWrite.request.put(reqA);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respA <- configWrite.response.get();
                endaction
                
                action
                    let reqA = AXI4_Lite_Write_Rq_Pkg {addr:8'b00011000, data:8, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    configWrite.request.put(reqA);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respA <- configWrite.response.get();
                endaction              
                
                action
                    let reqA = AXI4_Lite_Write_Rq_Pkg {addr:8'b00100000, data:1, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    configWrite.request.put(reqA);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respA <- configWrite.response.get();
                endaction
                
                action
                    let reqC = AXI4_Lite_Read_Rq_Pkg {addr:8'b00000000, prot:UNPRIV_SECURE_DATA};
                    configRead.request.put(reqC);
                endaction
                action
                    let respC <- configRead.response.get();
                    Int#(32) result = unpack(respC.data);
                    $display("Status response: %d", result);
                endaction
                
                delay(10000);
                //$display("Next try");
                action
                    let reqC = AXI4_Lite_Read_Rq_Pkg {addr:8'b00000000, prot:UNPRIV_SECURE_DATA};
                    configRead.request.put(reqC);
                endaction
                action
                    let respC <- configRead.response.get();
                    Int#(32) result = unpack(respC.data);
                    $display("Status response: %d", result);
                endaction

                action
                    let reqA = AXI4_Lite_Write_Rq_Pkg {addr:8'b00100000, data:1, strb:4'b1111, prot:UNPRIV_SECURE_DATA};
                    configWrite.request.put(reqA);
                endaction
                action
                    AXI4_Lite_Write_Rs_Pkg respA <- configWrite.response.get();
                endaction
                
                delay(10000);

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
