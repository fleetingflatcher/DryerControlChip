`timescale 10us / 10us

module bench;
    reg CLK;
    reg ON;
    reg OFF;
    reg RESET;
    reg [0:3] mainDial;
    reg [0:1] heatDial;
    wire MTR;
    wire [0:1] HTR;
    
    dryerCtrl DUT (
    .CLK        (CLK),
    .mainDial   (mainDial),
    .heatDial   (heatDial),
    .ON         (ON),
    .OFF        (OFF),
    .RESET      (RESET),
    .HTR        (HTR),
    .MTR        (MTR)
    );
    integer i;
    integer num;
    initial
    begin
        CLK = 0;
        ON = 0;
        OFF = 0;
        heatDial = 'b0;
        
        #25
        RESET = 1;
        #10 
        RESET = 0;
        // Start up the device with a clock reset/state initializer
        
        
        if (i == 0)
        begin
            //////////////////
            // ON/OFF TEST
            //////////////////
            mainDial = 4'b0001;
            repeat (4)
            begin
                #5 ON = 1'b1;
                #5 ON = 1'b0;
                #25
                #5 OFF = 1'b1;
                #5 OFF = 1'b0;
                mainDial = mainDial << 1;
            end
            mainDial = 4'b1010;
            repeat (6)
            begin
                repeat (4)
                begin
                    #5 ON = 1'b1;
                    #5 ON = 1'b0;
                    #25
                    #5 OFF = 1'b1;
                    #5 OFF = 1'b0;
                    heatDial = heatDial + 'b1;
                end
                mainDial = mainDial + 'b1;
            end
        end
        if (i == 1)
        begin
            //////////////////
            // AUTOMATIC CYCLES TIMER TEST
            //////////////////
            #25 mainDial = 0'b0001;
            repeat (4)
            begin
                ON = 1'b1;
                #5 ON = 1'b0;
                #2000000
                mainDial = mainDial << 1;
            end 
        end
        if (i == 2)
        begin
            //////////////////
            // MANUAL CYCLES TIMER TEST
            //////////////////
            num = 1;
            #25 mainDial = 0'b1010;
            #50000
            repeat (6)
            begin
                ON = 1'b1;
                #5 ON = 1'b0;
                #(400000*num)
                mainDial = mainDial + 'b1;
                num = num + 'b1;
            end
        end
        
        //$finish;
    end
    
    always #1 assign CLK = ~CLK;
endmodule
