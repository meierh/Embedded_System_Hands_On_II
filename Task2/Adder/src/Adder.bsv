package Adder;

import List :: * ;
import BlueAXI :: *;
import AXI4_Types :: *;

(* always_ready, always_enabled *)
interface Adder;
    (*prefix = "AXI"*) interface AXI4_Lite_Slave_Rd_Fab#(8, 32) s_rd;
    (*prefix = "AXI"*) interface AXI4_Lite_Slave_Wr_Fab#(8, 32) s_wr;
endinterface

module mkAdder(Adder);

    Reg#(Int#(32)) a <- mkReg(0);
    Reg#(Bool) aValid <- mkReg(False);
    
    Reg#(Int#(32)) b <- mkReg(0);
    Reg#(Bool) bValid <- mkReg(False);

    Reg#(Int#(32)) c <- mkReg(0);
    Reg#(Bool) cValid <- mkReg(False);

    rule add (!cValid && aValid && bValid);
        c <= a+b;
        cValid <= True;
    endrule
    
    List#(RegisterOperator#(8,32)) moduleOperations;
    
// Write a operation
    RegisterOperator#(8,32) writeAOperation;
    
    function Action writeA (Bit#(32) d, Bit#(TDiv#(32, 8)) s, AXI4_Lite_Prot p);
              action
                    a <= unpack(d);
                    aValid <= True;
                    cValid <= False;
                    Int#(32) aVar = unpack(d);
               endaction
    endfunction : writeA
    WriteOperation#(8,32) writeAStruct;
    writeAStruct = WriteOperation { index : 8'b00000000 , fun : writeA };
    writeAOperation = tagged Write writeAStruct;
    
    moduleOperations = replicate(1,writeAOperation);    
    
// Write b operation
    RegisterOperator#(8,32) writeBOperation;
    
    function Action writeB (Bit#(32) d, Bit#(TDiv#(32, 8)) s, AXI4_Lite_Prot p);
              action
                    b <= unpack(d);
                    bValid <= True;
                    cValid <= False;
                    Int#(32) bVar = unpack(d);
               endaction
    endfunction : writeB
    WriteOperation#(8,32) writeBStruct;
    writeBStruct = WriteOperation { index : 8'b00000100 , fun : writeB };
    writeBOperation = tagged Write writeBStruct;
    
    moduleOperations = List::cons(writeBOperation,moduleOperations);
    
// Read c operation
    RegisterOperator#(8,32) readCOperation;

    function ActionValue#(Bit#(32)) readC (AXI4_Lite_Prot p);
              actionvalue
                    return pack(c);
               endactionvalue
    endfunction : readC
    ReadOperation#(8,32) readCStruct;
    readCStruct = ReadOperation { index : 8'b00001000 , fun : readC };
    readCOperation = tagged Read readCStruct;
    
     moduleOperations = List::cons(readCOperation,moduleOperations);
    
    // Construct AXI Slave  
    GenericAxi4LiteSlave#(8,32) axiLiteSlave <- mkGenericAxi4LiteSlave(moduleOperations,1,1);
    
    interface s_rd  = axiLiteSlave.s_rd;
    interface s_wr  = axiLiteSlave.s_wr;

endmodule

endpackage
