module dryerCtrl(
    CLK,
    mainDial,
    heatDial,
    ON,
    OFF,
    RESET,
    HTR,
    MTR);

	//Input Types
input wire CLK, ON, OFF, RESET;
input wire [0:3] mainDial;
input wire [0:1] heatDial;

	//Output Types
output reg MTR;
output reg [0:1] HTR;

    // Dial Position Definitions
parameter DIAL_OFF = 4'h0;
parameter DIAL_STD = 4'h1;
parameter DIAL_TWL = 4'h2;
parameter DIAL_DEL = 4'h4;
parameter DIAL_TCH = 4'h8;
parameter DIAL_15 = 4'hA;
parameter DIAL_30 = 4'hB;
parameter DIAL_45 = 4'hC;
parameter DIAL_60 = 4'hD;
parameter DIAL_75 = 4'hE;
parameter DIAL_90 = 4'hF;

	//Internal State Definitions
parameter IDLE = 8'h00;
parameter STRD = 8'h15;
parameter TWLS = 8'h25;
parameter DELC = 8'h42;
parameter MAN_HI = 8'hA5;
parameter MAN_MD = 8'hB5;
parameter MAN_LO = 8'hC5;
parameter MAN_OF = 8'hD5;

	//Internal Mechanisms
reg [0:7] state;
reg [0:7] next;

reg [0:15] clk_counter;  
                            // @ 50kHz / 20us clock period (between posedges)
                            // 50000 clock cycles ~ 1 second
                            // when clk_counter reaches 50000,
                            // increment sec_counter
reg [0:9] sec_counter;
                            // 900 seconds = 15 minutes
                            // 15 minutes per state change
                            // for timed cycles
                            //
                            // !!! Using 3 seconds for debugging !!!
reg decrementSuccessFlag;
reg resetTimerFlag;
//reg Timer_15minutes;

task ResetButton;
begin
    state = IDLE;
    clk_counter <= 'b0;
    sec_counter = 'b0;
    decrementSuccessFlag <= 0;
    resetTimerFlag <= 0;
end
endtask

task OffButton;
begin
   next = IDLE;
   resetTimerFlag = 'b1; 
end
endtask

task OnButton;
begin
    if (mainDial == DIAL_STD) next = STRD;
    else if (mainDial == DIAL_TCH) next = (STRD - 3'b100);
    else if (mainDial == DIAL_TWL) next = TWLS;
    else if (mainDial == DIAL_DEL) next = DELC;
    else if (mainDial >= 'hA)
    begin
        if (heatDial == 2'b00) next = MAN_OF + (mainDial - 4'hA - 5);
        else if (heatDial == 2'b01) next = MAN_LO + (mainDial - 4'hA - 5);
        else if (heatDial == 2'b10) next = MAN_MD + (mainDial - 4'hA - 5);
        else if (heatDial == 2'b11) next = MAN_HI + (mainDial - 4'hA - 5);
    end
end
endtask

///////////////////
//  TrackTime
//
//  This task is responsible for modifying the clk_counter
//  and sec_counter values with each clock cycle, or when 
//  they need to be reset.
//
///////////////////
task TrackTime;
begin
    if (resetTimerFlag) 
    // This flag pops up if the RESET button has been pressed recently.
    begin
        clk_counter <= 'b0;
        sec_counter = 'b0;
        decrementSuccessFlag <= 'b0;
        resetTimerFlag <= 'b0;
    end
    else if (state)
    // Only increment on clock cycles if not IDLE
    begin
        if (clk_counter == 50000)
        begin
            sec_counter = sec_counter + 'b1;
            clk_counter <= 'b0;
        end
        else clk_counter <= clk_counter + 'b1;
    end
    if (sec_counter >= 3 
        && decrementSuccessFlag)
    //  IF the second counter is longer than the minimum cycle length 
    //  (15 minutes = 900 seconds for production / 3 seconds for testing) 
    //  AND the DSF is active, indicating that the state has successfully
    //  been decremented, reset to count for the next decrement.
    begin
        sec_counter = 'b0;
        decrementSuccessFlag <= 'b0;
        $display ("ln 114: reset sec_counter and DSF");
    end
end
endtask

////////////////////////
//  Decrement State
//
//  This task is responsible for decrementing the current state
//  to account for the passage of time as measured by TrackTime().
//
//  This task is called when sec_counter has reached the minimum
//  cycle length, at which time the DSF is driven high until
//  TrackTime() acks the DSF, resetting the DSF and its' counters.
//
///////////////////////
task DecrementState;
begin
    $display ("ln 132: decrementing state");
    if (state[4:7] > 4'b0000) next = (state - 'b1);
    else next = IDLE;
    decrementSuccessFlag <= 'b1;
end
endtask

/////////////////////////
//  Assign Outputs
//
//  This task is responsible solely for setting the outputs
//  in accordance with the current state.
//
//////////////////////////
task AssignOutputs;
begin
    
    if (state == IDLE)
    begin
        MTR = 0;
        HTR = 2'b00;
    end
    else if (state >= 'h10 && state <= 'h1F)
    begin
        MTR = 1;
        HTR = 2'b01;
    end
    else if (state >= 'h20 && state <= 'h2F)
    begin
        MTR = 1;
        HTR = 2'b11;
    end
    else if (state >= 'h40 && state <= 'h4F)
    begin
        MTR = 1;
        HTR = 2'b00;
    end
    else if (state >= 'hA0 && state <= 'hAF)
    begin
        MTR = 1;
        HTR = 2'b11;
    end
    else if (state >= 'hB0 && state <= 'hBF)
    begin
        MTR = 1;
        HTR = 2'b10;
    end
    else if (state >= 'hC0 && state <= 'hCF)
    begin
        MTR = 1;
        HTR = 2'b01;
    end
    else if (state >= 'hD0 && state <= 'hDF)
    begin
        MTR = 1;
        HTR = 2'b00;
    end
end
endtask

//////////////////////////
//  Master Always Block
//
//  1)  First, the current 'state' is determined from 'next',
//          or is immediately set to IDLE if OFF is detected.
//  2)  Time is tracked, and outputs are assigned.
//  3)  Control flow routes behavior to a set of responses
//          appropriate to current state.
//  4)  Inputs are read and 'next' is assigned.
//
///////////////////////////
always @ (posedge CLK)
begin
    begin
        //State Assignment Block
        // "Sequential Logic"
        if (OFF) 
        begin
            state = IDLE;
        end
        else
        begin
            state = next;
        end
        TrackTime();
        AssignOutputs();
    end
    begin
        // Input Handling Block
        // "Combinational Logic"
        if (RESET) ResetButton();
        if (state == IDLE) 
        begin
            if (ON) OnButton();
            else next = IDLE;
        end
        else if // STATE == STANDARD
            (state >= 'h10 && state <= 'h1F)
        begin
            if (OFF) OffButton();
            else if (ON) OnButton();
            else if (sec_counter >= 3) begin
                DecrementState();
            end
            else begin
                next = state;
            end
        end
        else if // STATE == TOWELS
            (state >= 'h20 && state <= 'h2F)
        begin
            if (OFF) OffButton();
            else if (ON) OnButton();
            else if (sec_counter >= 3) DecrementState();
            else next = state;
        end
        else if // STATE == DELICATES
            (state >= 'h40 && state <= 'h4F)
        begin
            if (OFF) OffButton();
            else if (ON) OnButton();
            else if (sec_counter >= 3) DecrementState();
            else next = state;
        end
        else if // STATE == MAN_HI
            (state >= 'hA0 && state <= 'hAF)
        begin
            if (OFF) OffButton();
            else if (ON) OnButton();
            else if (sec_counter >= 3) DecrementState();
            else next = state;
        end
        else if // STATE == MAN_MED
            (state >= 'hB0 && state <= 'hBF)
        begin
            if (OFF) OffButton();
            else if (ON) OnButton();
            else if (sec_counter >= 3) DecrementState();
            else next = state;    
        end
        else if // STATE == MAN_LO
            (state >= 'hC0 && state <= 'hCF)
        begin
            if (OFF) OffButton();
            else if (ON) OnButton();
            else if (sec_counter >= 3) DecrementState();
            else next = state;
        end
        else if // STATE == MAN_OFF
            (state >= 'hD0 && state <= 'hDF)
        begin
            if (OFF) OffButton();
            else if (ON) OnButton();
            else if (sec_counter >= 3) DecrementState();
            else next = state; 
        end
    end 
end
endmodule
