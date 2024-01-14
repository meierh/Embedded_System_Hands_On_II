package SobelTypes;

    typedef enum {
        Sobel3 = 4'b0011,
        Sobel5 = 4'b0101,
        Sobel7 = 4'b0111,
        Sobel9 = 4'b1001
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
            Sobel9: return (y+4)*9 + (x+4);
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
            Sobel9:
            begin
                Integer x = (ind%9)-1;
                Integer y = (ind/9)-1;
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
