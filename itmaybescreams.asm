; -------------------- Revised Reflow Oven Controller --------------------
; This version uses 5 ADC–read pushbuttons for functions: 
;  RST, NEXT, UP, DOWN, and START/STOP.
;
; In the selecting FSM the LCD displays the current parameter,
; then the user can change values (soak time, soak temp, reflow time,
; and reflow temp). When the S_S (start/stop) button is pressed, the 
; oven FSM (starting at state0) is invoked.
;
;
; -------------------------------------------------------------------------

$NOLIST
$MODN76E003
$LIST

;--------------------------
; N76E003 Pinout (summary)
;--------------------------
; Refer to your pinout diagram in the original file.
;
;--------------------------
; Constants & Timer Definitions
;--------------------------
CLK               EQU 16600000       ; System clock (Hz)
BAUD              EQU 115200         ; UART baud rate
TIMER1_RATE       EQU 100            ; Timer1 rate (100Hz / 10ms)
TIMER1_RELOAD     EQU (65536-(CLK/(16*TIMER2_RATE)))  ; (Not used in our code)
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))
TIMER2_RATE       EQU 1000           ; Timer2: 1ms tick
TIMER2_RELOAD     EQU (65536-(CLK/TIMER2_RATE))

;--------------------------
; Data messages for LCD (16 characters per line)
;--------------------------
title:            db '  here we go!  ', 0
blank:            db '                ', 0
swait_message1:   db 'Set your values ', 0   ; for state0
swait_message2:   db 'Press next      ', 0
sstime_message1:  db 'Select soak time', 0   ; state1 (soak time)
sstime_message2:  db 'Soak time:      ', 0
sstemp_message1:  db 'Select soak temp', 0   ; state2 (soak temp)
sstemp_message2:  db 'Soak temp:      ', 0
srtime_message1:  db 'Select refl time', 0   ; state3 (reflow time)
srtime_message2:  db 'Refl time:      ', 0
srtemp_message1:  db 'Select refl temp', 0   ; state4 (reflow temp)
srtemp_message2:  db 'Refl temp:      ', 0
too_high_message: db 'max!     ', 0
too_low_message:  db 'min!     ', 0
done_message:     db 'done!',0
stop_message:     db 'stopped!',0
reset_state_message: db 'Settings Reset! ', 0

;--------------------------
; Hardware pin definitions
;--------------------------
cseg
LCD_RS    EQU P1.3
LCD_E     EQU P1.4
LCD_D4    EQU P0.0
LCD_D5    EQU P0.1
LCD_D6    EQU P0.2
LCD_D7    EQU P0.3
SOUND_OUT EQU P1.5
PWM_OUT   EQU P1.0  ; Logic 1 = oven on

$NOLIST
$include(LCD_4bit.inc)       ; LCD routines
$include(state_machine.inc)   ; (Assumed to include state_init and reset_state routines)
$LIST

;--------------------------
; Bit Segment: Button bits (from ADC result)
;--------------------------
BSEG
; Button bit assignment (active low when pressed)
S_S:       dbit 1   ; PB3: Start/Stop button
DOWN:      dbit 1   ; PB4: Down button
UP:        dbit 1   ; PB5: Up button
NXT:       dbit 1   ; PB6: Next button
RST:       dbit 1   ; PB7: Reset button
mf:        dbit 1
seconds_flag: dbit 1
s_flag:     dbit 1   ; Set to 1 every second

;--------------------------
; Data Segment
;--------------------------
DSEG at 30H
x:                ds 4
y:                ds 4
BCD:              ds 5
selecting_state:  ds 1   ; Parameter selection state: 0,1,2,3,4
oven_state:       ds 1   ; (Used in oven FSM from oven_fsm.inc)
soak_time:        ds 2
soak_temp:        ds 2
reflow_time:      ds 2
reflow_temp:      ds 2
Count1ms:         ds 2   ; 16-bit millisecond counter for Timer2
sec:              ds 1   ; Seconds counter (oven FSM)
temp:             ds 1   ; Measured temperature (from read_temp.inc)
pwm_counter:      ds 1   ; Free-running counter (0 to 1000 ms)
pwm:              ds 1   ; PWM duty-cycle (0 to 100)
seconds:          ds 1   ; (Alternate seconds counter – may be redundant)

$NOLIST
$include(math32.inc)   ; 32-bit math routines (x_gt_y, x_lt_y, x_eq_y, etc.)
$include(oven_fsm.inc)  ; Contains oven FSM (state0, reset_state, etc.)
$include(read_temp.inc) ; Contains Read_Temperature routine
$LIST

;--------------------------
; Code: Initialization Routines
;--------------------------
CSEG
Init_All:
    ; Configure I/O pins
    mov   P3M1, #0x00
    mov   P3M2, #0x00
    mov   P1M1, #0x00
    mov   P1M2, #0x00
    mov   P0M1, #0x00
    mov   P0M2, #0x00

    orl   CKCON, #0x10       ; Timer1 clock source select
    orl   PCON,  #0x80       ; Set SMOD = 1 for double baud rate
    mov   SCON,  #0x52
    anl   T3CON, #0b11011111
    anl   TMOD,  #0x0F       ; Clear Timer1 config bits
    orl   TMOD,  #0x20       ; Timer1 Mode2

    ; Initialize Timer0 for wait routines
    clr   TR0
    orl   CKCON, #0x08
    anl   TMOD,  #0xF0
    orl   TMOD,  #0x01       ; Timer0 Mode1: 16-bit

    ; ADC initialization:
    orl   P1M1, #0b10000000  ; Configure P1.7 as input (AIN0)
    anl   P1M2, #0b01111111
    mov   AINDIDS, #0x00     ; Disable all analog inputs
    orl   AINDIDS, #0b00000001 ; Enable AIN0
    orl   ADCCON1, #0x01     ; Enable ADC

    ; Initialize Timer2 for 1ms tick and PWM generation:
    lcall Timer2_Init

    setb  EA                ; Enable global interrupts
    ret

;--------------------------
; Wait routines (using Timer0)
;--------------------------
wait_1ms:
    clr   TR0
    clr   TF0
    mov   TH0, #high(TIMER0_RELOAD_1MS)
    mov   TL0, #low(TIMER0_RELOAD_1MS)
    setb  TR0
    jnb   TF0, $          ; Wait until TF0 set
    ret

waitms:
    lcall wait_1ms
    djnz  R2, waitms
    ret

;--------------------------
; Display Formatted BCD (for showing numbers)
;--------------------------
Display_formated_BCD:
    Display_BCD(bcd+2)  ; Display the 4-digit value (using lower 4 bytes)
    Display_BCD(bcd+1)
    Display_BCD(bcd+0)
    ret

;--------------------------
; Timer2 Initialization
;--------------------------
Timer2_Init:
    mov   T2CON, #0       ; Stop timer/counter. (Auto-reload mode)
    mov   TH2, #high(TIMER2_RELOAD)
    mov   TL2, #low(TIMER2_RELOAD)
    ; Set reload value and auto-reload with clock divider 16:
    mov   T2MOD, #1000_0000b   ; (0x80)
    mov   RCMP2H, #high(TIMER2_RELOAD)
    mov   RCMP2L, #low(TIMER2_RELOAD)
    ; Initialize 1ms counter:
    clr   a
    mov   Count1ms+0, a
    mov   Count1ms+1, a
    mov   sec, #0
    clr   seconds_flag
    orl   EIE, #0x80     ; Enable Timer2 interrupt
    setb  TR2           ; Start Timer2
    ret

;--------------------------
; Timer2 Interrupt Service Routine
;--------------------------
Timer2_ISR:
    clr   TF2           ; Clear Timer2 overflow flag
    push  acc
    push  psw
    push  y
    push  x

    ; Increment the 16-bit millisecond counter:
    inc   Count1ms+0
    mov   a, Count1ms+0
    jnz   Inc_Done
    inc   Count1ms+1
Inc_Done:

    ; --- PWM Generation ---
    ; Multiply pwm by 10 to get a 16-bit threshold (period = 1000 ms)
    clr   c
    load_x(pwm)
    load_y(10)
    lcall mul32        ; Now x contains (pwm * 10)
    ; Compare low 8-bits of product with Count1ms low byte:
    clr   c
    mov   a, x+0
    subb  a, Count1ms+0
    jnc   pwm_test2
    jmp   pwm_set
pwm_test2:
    clr   c
    mov   a, x+1
    subb  a, Count1ms+1
    jnc   pwm_set
pwm_set:
    cpl   c            ; Invert the comparison result
    mov   PWM_OUT, c

    ; Check if 1000ms have passed:
    mov   a, Count1ms+0
    cjne  a, #low(1000), Time_done
    mov   a, Count1ms+1
    cjne  a, #high(1000), Time_done

    ; 1000ms have passed: reset counter and set seconds flag
    clr   a
    mov   Count1ms+0, a
    mov   Count1ms+1, a
    setb  seconds_flag
    mov   a, sec
    add   a, #1
    da    a
    mov   sec, a
Time_done:
    pop   x
    pop   y
    pop   psw
    pop   acc
    reti

;--------------------------
; ADC_to_PB: Read pushbuttons via ADC (AIN0)
;--------------------------
ADC_to_PB:
    anl   ADCCON0, #0xF0
    orl   ADCCON0, #0x00    ; Select AIN0
    clr   ADCF
    setb  ADCS            ; Start conversion
    jnb   ADCF, $         ; Wait for conversion complete

    ; Set all button bits high (not pressed)
    setb  RST     ; PB7
    setb  NXT     ; PB6
    setb  UP      ; PB5
    setb  DOWN    ; PB4
    setb  S_S     ; PB3

    ; Now check ADC result (ADCRH) against thresholds:
    ; Check PB5 (RST): if ADCRH >= 0xB0, then clear RST.
    clr   c
    mov   a, ADCRH
    subb  a, #0xB0
    jc    ADC_to_PB_L4
    clr   RST
    ret
ADC_to_PB_L4:
    ; Check PB4 (NXT)
    clr   c
    mov   a, ADCRH
    subb  a, #0x90
    jc    ADC_to_PB_L3
    clr   NXT
    ret
ADC_to_PB_L3:
    ; Check PB3 (UP)
    clr   c
    mov   a, ADCRH
    subb  a, #0x70
    jc    ADC_to_PB_L2
    clr   UP
    ret
ADC_to_PB_L2:
    ; Check PB2 (DOWN)
    clr   c
    mov   a, ADCRH
    subb  a, #0x50
    jc    ADC_to_PB_L1
    clr   DOWN
    ret
ADC_to_PB_L1:
    ; Check PB1 (S_S)
    clr   c
    mov   a, ADCRH
    subb  a, #0x30
    jc    ADC_to_PB_L0
    clr   S_S
    ret
ADC_to_PB_L0:
    ; Check PB0 (unused) – do nothing
    ret

;--------------------------
; Main Program
;--------------------------
main:
    mov   sp, #0x7F
    lcall Init_All
    lcall LCD_4BIT
    lcall state_init         ; Initialize state machine (from state_machine.inc)

    ; Display initial messages:
    Set_Cursor(1,1)
    Send_Constant_String(#Title)
    Set_Cursor(2,1)
    Send_Constant_String(#blank)
    mov   R2, #250
    lcall waitms

Forever:
    ; Wait 50ms between iterations
    mov   R2, #50
    lcall waitms

    ; (Optional) Toggle SOUND_OUT if seconds_flag set:
    jnb   seconds_flag, no_second
    clr   seconds_flag
    cpl   P1.5
no_second:
    mov   R2, #50
    lcall waitms

    ljmp FSM_select

;--------------------------
; FSM_select: Parameter Selection FSM
;--------------------------
FSM_select:
    mov   a, selecting_state
select_wait:
    cjne  a, #0, select_soak_time   ; If selecting_state ≠ 0, go to next states
    Set_Cursor(1,1)
    Send_Constant_String(#swait_message1)
    Set_Cursor(2,1)
    Send_Constant_String(#swait_message2)
    mov   R2, #250
    lcall waitms
    lcall rst_check     ; Check Reset button
    lcall nxt_check     ; Check Next button to advance state
    lcall s_s_check     ; Check Start/Stop button (if pressed, jump to oven FSM)
    ljmp forever        ; Otherwise, loop

; State 1: Select Soak Time
select_soak_time:
    cjne  a, #1, select_soak_temp_ah
    Set_Cursor(1,1)
    Send_Constant_String(#sstime_message1)
    Set_Cursor(2,1)
    Send_Constant_String(#sstime_message2)
    push  AR5            ; Save register for displaying current value
    mov   R5, x
    mov   x+0, soak_time
    mov   x+1, #0
    mov   x+2, #0
    mov   x+3, #0
    Set_Cursor(2,11)
    lcall hex2bcd
    lcall Display_formated_BCD
    mov   x, R5
    pop   AR5
    lcall rst_check
    push  AR3
    push  AR4
    push  AR5
    mov   R3, #0x3C     ; Minimum allowed (e.g., 60)
    mov   R4, #0x78     ; Maximum allowed (e.g., 120)
    mov   R5, soak_time
    lcall up_check
    lcall down_check
    mov   soak_time, R5
    pop   AR5
    pop   AR4
    pop   AR3
    lcall s_s_check
    lcall nxt_check
    ljmp forever

; State 2: Select Soak Temperature
select_soak_temp:
    cjne  a, #2, select_reflow_time
    Set_Cursor(1,1)
    Send_Constant_String(#sstemp_message1)
    Set_Cursor(2,1)
    Send_Constant_String(#sstemp_message2)
    Set_Cursor(2,11)
    push  AR5
    mov   R5, x
    mov   x, soak_temp
    lcall hex2bcd
    lcall Display_formated_BCD
    mov   x, R5
    pop   AR5
    lcall rst_check
    push  AR3
    push  AR4
    push  AR5
    mov   R3, #0x96    ; Minimum allowed (150 dec)
    mov   R4, #0xC8    ; Maximum allowed (200 dec)
    mov   R5, soak_temp
    lcall up_check
    lcall down_check
    mov   soak_temp, R5
    pop   AR5
    pop   AR4
    pop   AR3
    lcall s_s_check
    lcall nxt_check
    ljmp forever

; State 3: Select Reflow Time
select_reflow_time:
    cjne  a, #3, select_reflow_temp
    Set_Cursor(1,1)
    Send_Constant_String(#srtime_message1)
    Set_Cursor(2,1)
    Send_Constant_String(#srtime_message2)
    Set_Cursor(2,11)
    push  AR5
    mov   R5, x
    mov   x, reflow_time
    lcall hex2bcd
    lcall Display_formated_BCD
    mov   x, R5
    pop   AR5
    lcall rst_check
    push  AR3
    push  AR4
    push  AR5
    mov   R3, #0x2D    ; Minimum allowed (45 dec)
    mov   R4, #0x4B    ; Maximum allowed (75 dec)
    mov   R5, reflow_time
    lcall up_check
    lcall down_check
    mov   reflow_time, R5
    pop   AR5
    pop   AR4
    pop   AR3
    lcall s_s_check
    lcall nxt_check
    ljmp forever

; State 4: Select Reflow Temperature
select_reflow_temp:
    Set_Cursor(1,1)
    Send_Constant_String(#srtemp_message1)
    Set_Cursor(2,1)
    Send_Constant_String(#srtemp_message2)
    Set_Cursor(2,11)
    push  AR5
    mov   R5, x
    mov   x, reflow_temp
    lcall hex2bcd
    lcall Display_formated_BCD
    mov   x, R5
    pop   AR5
    lcall rst_check
    push  AR3
    push  AR4
    push  AR5
    mov   R3, #0xD9    ; Minimum allowed (217 dec)
    mov   R4, #0xFF    ; Maximum allowed (255 dec)
    mov   R5, reflow_temp
    lcall up_check
    lcall down_check
    mov   reflow_temp, R5
    pop   AR5
    pop   AR4
    pop   AR3
    lcall s_s_check
    lcall nxt_check
    ljmp forever

;--------------------------
; Button Check Macros/Subroutines
;--------------------------

; rst_check: If RST (reset) is pressed, jump to oven FSM reset state.
rst_check:
    lcall ADC_to_PB
    mov   c, RST
    jnc   rst_check_done   ; If RST is low (pressed) then jump...
    ret
rst_check_done:
    ljmp  reset_state      ; (reset_state routine from oven_fsm.inc)
    
; nxt_check: If NEXT button is pressed, increment selecting_state (wrap from 4 to 0).
nxt_check:
    lcall ADC_to_PB
    mov   c, NXT
    jnc   nxt_check_exit
    ; Read current state into A:
    mov   a, selecting_state
    ; If state equals 4, then wrap to 0; otherwise increment.
    cmp   a, #4
    jz    nxt_wrap
    inc   selecting_state
    ret
nxt_wrap:
    mov   selecting_state, #0
    ret
nxt_check_exit:
    ret

; up_check: If UP button is pressed, and current value is less than max (in R4), then increment R5.
up_check:
    lcall ADC_to_PB
    mov   c, UP
    jnc   up_check_exit
    ; Compare R5 with max in R4:
    mov   x, R4
    mov   y, R5
    lcall x_gt_y    ; mf = 1 if (R4 > R5)
    jb    mf, up_ok
    ; Otherwise, display "max!" message:
    clr   c
    Set_Cursor(2,11)
    Send_Constant_String(#too_high_message)
    ret
up_ok:
    inc   R5
up_check_exit:
    ret

; down_check: If DOWN button is pressed, and current value is greater than min (in R3), then decrement R5.
down_check:
    lcall ADC_to_PB
    mov   c, DOWN
    jnc   down_check_exit
    mov   x, R3
    mov   y, R5
    lcall x_lt_y    ; mf = 1 if (R3 < R5)
    jb    mf, down_ok
    clr   c
    Set_Cursor(2,11)
    Send_Constant_String(#too_low_message)
    ret
down_ok:
    dec   R5
down_check_exit:
    ret

; s_s_check: If S_S (start/stop) button is pressed, jump to oven FSM state0.
s_s_check:
    lcall ADC_to_PB
    mov   c, S_S
    jnc   s_s_check_exit
    ret
s_s_check_exit:
    ljmp  state0
    ; (state0 is defined in oven_fsm.inc)

; --------------------------
; END OF CODE
; --------------------------
END
