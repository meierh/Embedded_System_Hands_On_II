package SobelTypes;
    import Vector :: *;

    /*
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
    */
    
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

endpackage
