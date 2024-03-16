package SobelTypes;
    import Vector :: *;

    function Action printVector_20 (Vector#(7,Int#(22)) vec);
        action
        $display("----------------------------------------------------------------");
        for(Integer y=0; y<7; y=y+1)
            $write("%d ",vec[y]);
        $display(" ");
        $display("----------------------------------------------------------------");
        endaction
    endfunction    
    
    function Action printStencil_8 (Vector#(7,Vector#(7,UInt#(8))) stencil);
        action
        $display("----------------------------------------------------------------");
        for(Integer y=0; y<7; y=y+1)
            begin
            for(Integer x=0; x<7; x=x+1)
                $write("%d ",stencil[y][x]);
            $display(" ");
            end
        $display("----------------------------------------------------------------");
        endaction
    endfunction    

    function Action printStencil_20 (Vector#(7,Vector#(7,Int#(22))) stencil);
        action
        $display("----------------------------------------------------------------");
        for(Integer y=0; y<7; y=y+1)
            begin
            for(Integer x=0; x<7; x=x+1)
                $write("%d ",stencil[y][x]);
            $display(" ");
            end
        $display("----------------------------------------------------------------");
        endaction
    endfunction
    
    function Action printStencil_32 (Vector#(7,Vector#(7,Int#(32))) stencil);
        action
        $display("----------------------------------------------------------------");
        for(Integer y=0; y<7; y=y+1)
            begin
            for(Integer x=0; x<7; x=x+1)
                $write("%d ",stencil[y][x]);
            $display(" ");
            end
        $display("----------------------------------------------------------------");
        endaction
    endfunction
    
    function Action printStencil_22 (Vector#(7,Vector#(7,Int#(22))) stencil);
        action
        $display("----------------------------------------------------------------");
        for(Integer y=0; y<7; y=y+1)
            begin
            for(Integer x=0; x<7; x=x+1)
                $write("%d ",stencil[y][x]);
            $display(" ");
            end
        $display("----------------------------------------------------------------");
        endaction
    endfunction
    
    function Action printSum2_22 (Vector#(2,Vector#(2,Int#(22))) stencil);
        action
        $display("----------------------------------------------------------------");
        for(Integer y=0; y<2; y=y+1)
            begin
            for(Integer x=0; x<2; x=x+1)
                $write("%d ",stencil[y][x]);
            $display(" ");
            end
        $display("----------------------------------------------------------------");
        endaction
    endfunction
    
    function Action printChunks (Vector#(7,Vector#(16,Bit#(8))) matrix);
        action
        $display("----------------------------------------------------------------",$time);
        for(Integer y=0; y<7; y=y+1)
            begin
            for(Integer x=0; x<16; x=x+1)
                $write("%d ",matrix[y][x]);
            $display(" ");
            end
        $display("----------------------------------------------------------------");
        endaction
    endfunction

    typedef enum {
        Sobel3 = 2'b00,
        Sobel5 = 2'b01,
        Sobel7 = 2'b10
        } FilterType deriving (Bits,Eq);
        
    typedef enum {
        Idle = 3'b000,
        Prepared = 3'b001
        } FilterStatus deriving (Bits,Eq);

    typedef enum {
        Configuration = 3'b000,
        Execution = 3'b001,
        Finished = 3'b010
        } TopLevelStatusInfo deriving (Bits,Eq);
    
    typedef struct {
        UInt#(16) x0;
        UInt#(16) y0;
        } ImageCoord;
        
    typedef enum {
        Strategize = 3'b000,
        FillUp = 3'b001,
        NextLines = 3'b010
        } ExecutionZoneInfo deriving (Bits);

    typedef enum {
        DataMovement = 3'b000,
        Compute = 3'b001
        } ExecutionPhaseInfo deriving (Bits);
        
    function Integer xy_to_ind(Integer x, Integer y, FilterType ft);
        case(ft)
            Sobel3: return (y+1)*3 + (x+1);
            Sobel5: return (y+2)*5 + (x+2);
            Sobel7: return (y+3)*7 + (x+3);
        endcase
    endfunction
    
    function Tuple2#(Integer,Integer) ind_to_xy(Integer ind, FilterType ft);
        case(ft)
            Sobel3:
            begin
                Integer x = (ind%3)-1;
                Integer y = (ind/3)-1;
                return tuple2(x,y);
            end
            Sobel5:
            begin
                Integer x = (ind%5)-1;
                Integer y = (ind/5)-1;
                return tuple2(x,y);
            end
            Sobel7:
            begin
                Integer x = (ind%7)-1;
                Integer y = (ind/7)-1;
                return tuple2(x,y);
            end
        endcase
    endfunction
    
    typedef enum {
        PutAddr = 1'b0,
        PutData = 1'b1
        } SendPhase deriving (Bits,Eq);
        
    typedef enum {
        LoadAndFilter = 1'b0,
        ShiftAndSend = 1'b1
        } Computephase deriving (Bits,Eq);

    typedef enum {
        Request = 1'b0,
        Read = 1'b1
        } Loadphase deriving (Bits,Eq);
        
    typedef enum {
        Request = 1'b0,
        Write = 1'b1
        } Sendphase deriving (Bits,Eq);
                
endpackage
