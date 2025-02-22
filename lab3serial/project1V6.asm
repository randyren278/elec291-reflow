$NOLIST
$MODN76E003
$LIST

;===========================================================================
;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;===========================================================================

; Reset vector
org 0x0000
    ljmp main
    
; External interrupt 0 vector
org 0x0003
    reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
    reti

; External interrupt 1 vector
org 0x0013
    reti

; Timer/Counter 1 overflow interrupt vector
org 0x001B
    reti

; Serial port receive/transmit interrupt vector
org 0x0023 
    reti
    
; Timer/Counter 2 overflow interrupt vector
org 0x002B
    ljmp Timer2_ISR
    ;reti

CLK  EQU 16600000 ; Microcontroller system oscillator frequency in Hz
BAUD EQU 115200   ; Baud rate of UART in bps

; Timer 1 is used for Baud
TIMER1_RELOAD EQU (0x100-(CLK/(16*BAUD)))

; Timer 2 is used for the pwm and seconds counter
; From PWM_demo.asm
TIMER2_RATE   EQU 100                            ; 100 Hz or 10 ms
TIMER2_RELOAD EQU (65536-(CLK/(16*TIMER2_RATE))) ; Need to change timer 2 input divide to 16 in T2MOD

; Temperature Calculation
RESISTOR_1 EQU 9990 ; kilo-ohms ; R1 should be bigger than R2
RESISTOR_2 EQU 33   ; kilo-ohms ; What matters is the ratio R1/R2
CONSTANT   EQU ((99900*RESISTOR_2)/RESISTOR_1)
COLD_TEMP  EQU 22  ; Celsius

; Abort Condition Checking
TIME_ERROR EQU 50 ; seconds
TEMP_ERROR EQU 60 ; Celsius

; Inputs
SHIFT_BUTTON      EQU P1.6
TEMP_SOAK_BUTTON  EQU PB4
TIME_SOAK_BUTTON  EQU PB3
TEMP_REFL_BUTTON  EQU PB2
TIME_REFL_BUTTON  EQU PB1
START_STOP_BUTTON EQU PB0     

; Outputs
PWM_OUT     EQU P1.0 ; Logic 1 = oven on ; Pin 15

; These 'equ' must match the hardware wiring for the LCD
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

;===========================================================================
; DATA SEGMENT
;===========================================================================
DSEG at 0x30
; For math32.inc
x:   ds 4
y:   ds 4
bcd: ds 5

; For ADC Reading / Temperature Calculation
VAL_LM4040: ds 2

; FSM / LCD Variables
pwm_counter: ds 1 ; Free running counter 0, 1, 2, ..., 100, 0
pwm:         ds 1 ; pwm percentage

runtime_sec: ds 1 ; total runtime of the entire reflow process
runtime_min: ds 1

FSM1_state: ds 1
temp:       ds 1
sec:        ds 1
temp_soak:  ds 1
time_soak:  ds 1
temp_refl:  ds 1
time_refl:  ds 1

; bonus passcode entry variables
PASSCODE_LENGTH  EQU 4         ; require 4 digits for passcode

passcode_buffer: ds 4         ; buffer to hold entered digits
passcode_index:  ds 1         ; current number of digits entered
passcode_ptr:    ds 1         ; pointer to next location in passcode_buffer

correct_passcode: db '1','2','3','4'         ; The correct passcode (ASCII)

;===========================================================================
; BIT SEGMENT
;===========================================================================
BSEG
mf: dbit 1

; set to 1 every time a second has passed
s_flag: dbit 1

; set to 1 on first run through state 0
state_0_flag: dbit 1
active_flag:  dbit 1
error_flag:   dbit 1
done_flag:    dbit 1

; These five bit variables store the value of the pushbuttons after calling 'LCD_PB' below
PB0: dbit 1
PB1: dbit 1
PB2: dbit 1
PB3: dbit 1
PB4: dbit 1

;===========================================================================
; CODE SEGMENT
;===========================================================================
CSEG

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)   ; A library of math functions
$include(macros.inc)   ; Macros from lecture slides / macros we have created ourselves
$LIST

;                 1234567890123456
setup_line1:  db 'Soak   XXXC XXXs', 0
setup_line2:  db 'Reflow XXXC XXXs', 0

active_line1: db 'State X     XXXC', 0
active_line2: db 'XX:XX       XXXs', 0

error_line1:  db 'Error! t = XX:XX', 0
error_line2:  db 'Oven Temp = XXXC', 0

done_line1:   db '  Oven Cooled!  ', 0
done_line2:   db 'Runtime  = XX:XX', 0


;===========================================================================
; Interrupts
;===========================================================================
Timer0_ISR:
    reti

Timer1_ISR:
    reti

Timer2_ISR:
    clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.
    push psw
    push acc
	
    inc pwm_counter
    clr c
    mov a, pwm
    subb a, pwm_counter   ; If pwm_counter <= pwm then c=1
    cpl c
    mov PWM_OUT, c
	
    mov a, pwm_counter
    cjne a, #100, Timer2_ISR_done
    mov pwm_counter, #0
    inc sec             ; increment seconds counter
    setb s_flag

    inc runtime_sec
    mov a, runtime_sec
    cjne a, #60, Timer2_ISR_done
    mov runtime_sec, #0
    inc runtime_min

Timer2_ISR_done:
    pop acc
    pop psw
    reti

;===========================================================================
; Initializations
;===========================================================================
Init_All:
    lcall Init_Pins
    Wait_Milli_Seconds(#5)
    lcall Init_Timer0
    lcall Init_Timer1
    lcall Init_Timer2
    lcall Init_ADC
    lcall Init_Variables
    setb EA ; Enable global interrupts
    ret

Init_Pins:
    ; Configure all the pins for bidirectional I/O
    mov	P3M1, #0x00
    mov	P3M2, #0x00
    mov	P1M1, #0x00
    mov	P1M2, #0x00
    mov	P0M1, #0x00
    mov	P0M2, #0x00
    ret

Init_Timer0:
    ret

Init_Timer1:
	orl	CKCON, #0x10        ; CLK is the input for timer 1
	orl	PCON, #0x80         ; Bit SMOD = 1, double baud rate
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0F         ; Clear the configuration bits for timer 1
	orl	TMOD, #0x20         ; Timer 1 Mode 2
	mov	TH1, #TIMER1_RELOAD
	setb TR1
	ret

Init_Timer2:
    ; Initialize timer 2 for periodic interrupts
    mov T2CON, #0         ; Stop timer/counter, autoreload mode.
    mov TH2, #high(TIMER2_RELOAD)
    mov TL2, #low(TIMER2_RELOAD)
    mov T2MOD, #0b1010_0000 ; Enable timer 2 autoreload; clock divider = 16
    mov RCMP2H, #high(TIMER2_RELOAD)
    mov RCMP2L, #low(TIMER2_RELOAD)
    mov pwm_counter, #0
    orl EIE, #0x80       ; Enable timer 2 interrupt (ET2 = 1)
    setb TR2            ; Start timer 2
    ret

Init_ADC:
    ; Initialize the pins used by the ADC (P1.1, P1.7) as input.
    orl	P1M1, #0b10000010
    anl	P1M2, #0b01111101
    ; Initialize and start the ADC:
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x07   ; Select channel 7
    mov AINDIDS, #0x00   ; Disable all analog inputs
    orl AINDIDS, #0b10000001  ; Activate AIN0 and AIN7 analog inputs
    orl ADCCON1, #0x01   ; Enable ADC
    ret

Init_Variables:
    mov pwm_counter, #0
    mov pwm, #0
    mov runtime_sec, #0
    mov runtime_min, #0
    mov FSM1_state,  #8    ; <-- start in passcode entry state
    mov sec, #0
    clr s_flag
    clr state_0_flag
    clr active_flag
    clr error_flag
    clr done_flag
    mov passcode_index, #0      ; clear entered digit count
    mov passcode_ptr,  #passcode_buffer  ; initialize pointer to start of buffer
    ret

; --- Passcode & LCD Constants (define these only once) ---
; Note: Added a trailing space to the prompt so that the full 16-character line is overwritten.
passcode_prompt:  db 'Enter Passcode: ',0   ; 16 characters (includes the trailing space)
passcode_fail:    db 'Wrong Passcode',0
passcode_fail2:   db 'Try Again',0
blank_line:       db '                ',0   ; 16 spaces

; --- LCD Routines (if not already defined in your LCD_4bit.inc) ---
; LCD_Clear: Clears the LCD display (ensuring both lines are overwritten)
LCD_Clear:
    mov A, #0x01           ; Command to clear display (HD44780)
    lcall LCD_SendCommand
    ; Optionally, you can add extra delay or write spaces to both lines if needed:
    Wait_Milli_Seconds(#2) ; Wait ~2ms for clear command to complete
    ret

; --- Passcode Display Routine ---
Display_Passcode_Info:
    lcall LCD_Clear
    Set_Cursor(1,1)
    Send_Constant_String(#passcode_prompt)   ; Displays "Enter Passcode: " on line 1
    Set_Cursor(2,1)
    Send_Constant_String(#blank_line)         ; Clears line 2
    ret

; --- Passcode Entry FSM ---
; This routine is entered when FSM1_state equals 8.
FSM1_state_passcode:
    mov pwm, #0
    lcall Display_Passcode_Info   ; Always refresh the passcode prompt
Passcode_Wait:
    lcall LCD_PB                  ; Poll pushbuttons

    ; Check digit buttons (PB4-PB1) for digits '1' - '4'
    jnb PB4, Passcode_Button1     ; If PB4 pressed, load '1'
    jnb PB3, Passcode_Button2     ; If PB3 pressed, load '2'
    jnb PB2, Passcode_Button3     ; If PB2 pressed, load '3'
    jnb PB1, Passcode_Button4     ; If PB1 pressed, load '4'
    
    ; PB0 is the "return/confirm" button:
    jnb PB0, Passcode_Return      
    sjmp Passcode_Wait            ; Otherwise, keep polling

; --- Button Handlers for Passcode Entry ---
Passcode_Button1:
    mov A, #'1'
    lcall Save_Passcode_Digit
    sjmp Passcode_Wait

Passcode_Button2:
    mov A, #'2'
    lcall Save_Passcode_Digit
    sjmp Passcode_Wait

Passcode_Button3:
    mov A, #'3'
    lcall Save_Passcode_Digit
    sjmp Passcode_Wait

Passcode_Button4:
    mov A, #'4'
    lcall Save_Passcode_Digit
    sjmp Passcode_Wait

; --- Confirm (Return) Button Handler ---
Passcode_Return:
    Wait_Milli_Seconds(#200)     ; Debounce delay
    lcall Check_Passcode         ; Verify the entered code
    mov A, FSM1_state
    cjne A, #8, Exit_Passcode_Return  ; If FSM1_state changed (i.e. correct passcode entered), exit passcode mode.
    sjmp FSM1_state_passcode     ; Otherwise, remain in passcode mode.
Exit_Passcode_Return:
    ret



; --- Save a Digit into the Passcode Buffer ---
Save_Passcode_Digit:
    Wait_Milli_Seconds(#200)     ; Debounce delay
    push ACC                     ; Save current digit in A
    mov A, passcode_index
    cjne A, #PASSCODE_LENGTH, Save_Digit_OK
    pop ACC                      ; Buffer already full; discard extra digit
    ret
Save_Digit_OK:
    pop ACC                      ; Restore the digit
    mov R0, passcode_ptr         ; R0 points to next free location in buffer
    mov @R0, A
    inc passcode_ptr
    inc passcode_index
    lcall Update_Passcode_Display  ; Refresh the asterisk display on line 2
    ret

; --- Update the Passcode Display (Line 2) ---
Update_Passcode_Display:
    Set_Cursor(2,1)
    Send_Constant_String(#blank_line)  ; Overwrite line 2 with spaces
    Set_Cursor(2,1)
    mov R6, passcode_index
Update_Passcode_Display_Loop:
    cjne R6, #0, Display_Asterisk
    ret
Display_Asterisk:
    mov A, #'*'
    lcall ?WriteData              ; Call your LCD library’s WriteData routine
    djnz R6, Update_Passcode_Display_Loop
    ret

; --- Check the Entered Passcode ---
Check_Passcode:
    ; Verify exactly 4 digits have been stored.
    mov A, passcode_index
    cjne A, #PASSCODE_LENGTH, Passcode_Failed  ; If not 4, fail

    ; Load addresses
    mov R0, #passcode_buffer      ; R0 points to entered code
    mov DPTR, #correct_passcode   ; DPTR points to correct code in code memory
    mov R2, #PASSCODE_LENGTH      ; R2 = 4

Check_Loop:
    clr A                         ; Clear A for movc
    movc A, @A+DPTR               ; Load correct character from code memory
    mov B, @R0                    ; Load entered character from data memory
    cjne A, B, Passcode_Failed    ; Compare characters
    inc DPTR                      ; Move to next correct character
    inc R0                        ; Move to next entered character
    djnz R2, Check_Loop           ; Loop until all characters checked

    ; Correct passcode entered
    mov FSM1_state, #0            ; Transition to resting state
    mov passcode_index, #0        ; Reset buffer index
    mov passcode_ptr, #passcode_buffer
    lcall LCD_Clear
    lcall Display_Setup_Info
    ret


; --- Passcode Failed ---
Passcode_Failed:
    Set_Cursor(1,1)
    Send_Constant_String(#passcode_fail)   ; Display error message
    Set_Cursor(2,1)
    Send_Constant_String(#passcode_fail2)
    ; Clear the passcode buffer so the user can try again.
    mov passcode_index, #0
    mov passcode_ptr, #passcode_buffer
    Wait_Milli_Seconds(#200)  
    Wait_Milli_Seconds(#200)  
    Wait_Milli_Seconds(#200)  
    Wait_Milli_Seconds(#200)  
    Wait_Milli_Seconds(#200)  
    Wait_Milli_Seconds(#200)  
    Wait_Milli_Seconds(#200)  
    Wait_Milli_Seconds(#200)  
    Wait_Milli_Seconds(#200)  
    Wait_Milli_Seconds(#200)  
    Wait_Milli_Seconds(#200)  
    ret


    ;-----------------------------------------------------------
; LCD_SendCommand: Sends a command byte to the LCD in 4-bit mode.
; The command byte is in the accumulator (A).
; It splits the byte into its high nibble and low nibble and sends each.
;-----------------------------------------------------------
LCD_SendCommand:
    clr LCD_RS             ; RS = 0 for command mode
    mov B, A               ; Save the full command in B
    ; --- Send the high nibble ---
    swap A                 ; Swap nibbles so the high nibble is now in the low nibble
    anl A, #0x0F           ; Mask out the upper nibble, leaving the high nibble in the lower nibble
    mov P0, A              ; Output the nibble on P0.0-P0.3 (LCD_D4-D7)
    setb LCD_E             ; Set Enable high to latch the nibble
    nop                    ; Short delay
    nop
    clr LCD_E              ; Set Enable low
    ; --- Send the low nibble ---
    mov A, B               ; Restore the full command from B
    anl A, #0x0F           ; Isolate the low nibble (upper nibble is cleared)
    mov P0, A              ; Output the low nibble
    setb LCD_E             ; Pulse Enable high
    nop                    ; Short delay
    nop
    clr LCD_E              ; Pulse Enable low
    ret



;===========================================================================
; Main Function
;===========================================================================
main:
    mov sp, #07FH
    lcall Init_All
    lcall LCD_4BIT

    ; Loads variables from flash memory
    lcall Load_Variables
    lcall Display_Setup_Info

Forever:
    lcall LCD_PB
    lcall FSM1

    jnb s_flag, s_flag_check
    lcall Read_Temperature
    SendToSerialPort(temp)
    clr s_flag
s_flag_check:
    ljmp Forever

;===========================================================================
; Finite State Machine (FSM1) with Passcode Feature
;===========================================================================
FSM1:
    mov A, FSM1_state
    cjne A, #8, FSM1_not_passcode  ; If not passcode state, go to normal FSM
    ljmp FSM1_state_passcode      ; Else, jump to passcode entry

;----- Normal FSM (States 0 to 7)  -----
FSM1_not_passcode:
    cjne A, #0, FSM1_state1       ; If state is not 0, jump to state 1 code

;--- RESTING STATE (State 0) ---
FSM1_state0:
    mov pwm, #0                ; PWM off
    mov sec, #0
    mov runtime_sec, #0
    mov runtime_min, #0
    lcall Update_Variables     ; Update parameters from pushbuttons
    jb state_0_flag, Not_First_Time
    lcall Display_Setup_Info
    setb state_0_flag
Not_First_Time:
    lcall Display_Setup_Info2
    jb START_STOP_BUTTON, FSM1_state0_done
    Wait_Milli_Seconds(#50)
    jb START_STOP_BUTTON, FSM1_state0_done
check_release0:
    lcall LCD_PB
    jnb START_STOP_BUTTON, check_release0
    mov FSM1_state, #1         ; Advance to state 1
    lcall Display_Active_Info
    mov sec, #0    
FSM1_state0_done:
    ljmp FSM2                 ; Jump to common post-state code

;--- RAMP TO SOAK (State 1) ---
FSM1_state1:
    cjne A, #1, FSM1_state2
    mov pwm, #100
    mov A, #TIME_ERROR
    clr C
    subb A, runtime_sec
    jnc FSM1_error_checked
    mov A, #TEMP_ERROR
    clr C
    subb A, temp
    jc FSM1_error_checked
    mov FSM1_state, #6         ; Error condition: jump to state 6
    ljmp FSM2
FSM1_error_checked:
    mov A, temp_soak
    clr C
    subb A, temp
    jnc FSM1_state1_done
    mov FSM1_state, #2         ; Advance to state 2 if criteria met
    mov sec, #0
FSM1_state1_done:
    ljmp FSM2

;--- SOAK (State 2) ---
FSM1_state2:
    cjne A, #2, FSM1_state3
    mov pwm, #20
    mov A, time_soak
    clr C
    subb A, sec
    jnc FSM1_state2_done
    mov FSM1_state, #3         ; Advance to state 3 when time runs out
    mov sec, #0    
FSM1_state2_done:
    ljmp FSM2

;--- RAMP TO REFLOW (State 3) ---
FSM1_state3:
    cjne A, #3, FSM1_state4
    mov pwm, #100
    mov A, temp_refl
    clr C
    subb A, temp
    jnc FSM1_state3_done
    mov FSM1_state, #4         ; Advance to state 4 if criteria met
    mov sec, #0
FSM1_state3_done:
    ljmp FSM2

;--- REFLOW (State 4) ---
FSM1_state4:
    cjne A, #4, FSM1_state5
    mov pwm, #20
    mov A, time_refl
    clr C
    subb A, sec
    jnc FSM1_state4_done
    mov FSM1_state, #5         ; Advance to state 5 when time runs out
    mov sec, #0
FSM1_state4_done:
    ljmp FSM2

;--- COOL DOWN (State 5) ---
FSM1_state5:
    cjne A, #5, FSM1_state6
    mov pwm, #0
    mov A, temp
    clr C
    subb A, #60
    jnc FSM1_state5_done
    mov FSM1_state, #7         ; Advance to state 7 if temperature still high
FSM1_state5_done:
    ljmp FSM2

;--- ERROR (State 6) ---
FSM1_state6:
    cjne A, #6, FSM1_state7
    mov pwm, #0
    jb START_STOP_BUTTON, FSM1_state6_done
    Wait_Milli_Seconds(#50)
    jb START_STOP_BUTTON, FSM1_state6_done
check_release:
    lcall LCD_PB
    jnb START_STOP_BUTTON, check_release
    mov FSM1_state, #0         ; Reset to resting state
    clr state_0_flag
    clr active_flag
    clr error_flag
    clr done_flag
FSM1_state6_done:
    ljmp FSM2

;--- DONE (State 7) ---
FSM1_state7:
    mov pwm, #0
    jb START_STOP_BUTTON, FSM1_state7_done
    Wait_Milli_Seconds(#50)
    jb START_STOP_BUTTON, FSM1_state7_done
check_release1:
    lcall LCD_PB
    jnb START_STOP_BUTTON, check_release1 
    mov FSM1_state, #0         ; Reset to resting state
    clr state_0_flag
    clr active_flag
    clr error_flag
    clr done_flag
FSM1_state7_done:
    ljmp FSM2

;--- Common Post-State Code (FSM2) ---
FSM2:
    mov A, FSM1_state
    cjne A, #0, FSM2_not_state0
    ljmp FSM2_done
FSM2_not_state0:
    cjne A, #6, FSM2_no_error 
    jb error_flag, Not_First_Time1
    lcall Display_Error_Info
    setb error_flag
Not_First_Time1:
    lcall Display_Error_Info2
    ljmp FSM2_done
FSM2_no_error:
    cjne A, #7, FSM2_Not_Done
    jb done_flag, Not_First_Time2
    lcall Display_Done_Info
    setb done_flag
Not_First_Time2:
    ljmp FSM2_done
FSM2_Not_Done:
    jb active_flag, Not_First_Time3
    lcall Display_Active_Info
    setb active_flag
Not_First_Time3:
    lcall Display_Active_Info2
    jb START_STOP_BUTTON, FSM2_done
    Wait_Milli_Seconds(#50)
    jb START_STOP_BUTTON, FSM2_done
check_release2:
    lcall LCD_PB
    jnb START_STOP_BUTTON, check_release2 
    mov FSM1_state, #0         ; Reset to resting state
    clr state_0_flag
    clr active_flag
    clr error_flag
    clr done_flag
FSM2_done:
    ret


;===========================================================================
; Displays Information onto the LCD
;===========================================================================
Display_Setup_Info:
    Set_Cursor(1, 1)
    Send_Constant_String(#setup_line1)
    Set_Cursor(2, 1)
    Send_Constant_String(#setup_line2)
Display_Setup_Info2:
    Set_Cursor(1, 8)
    SendToLCD(temp_soak)
    Set_Cursor(1, 13)
    SendToLCD(time_soak)
    Set_Cursor(2, 8)
    SendToLCD(temp_refl)
    Set_Cursor(2, 13)
    SendToLCD(time_refl)
    ret

Display_Error_Info:
    Set_Cursor(1, 1)
    Send_Constant_String(#error_line1)
    Set_Cursor(2, 1)
    Send_Constant_String(#error_line2)
Display_Error_Info2:
    Set_Cursor(2, 13)
    SendToLCD(temp)
    Set_Cursor(1, 12)
    mov a, runtime_min
    mov b, #10
    div ab
    orl a, #0x30
    lcall ?WriteData
    mov a, b
    orl a, #0x30
    lcall ?WriteData
    Set_Cursor(1, 15)
    mov a, runtime_sec
    mov b, #10
    div ab
    orl a, #0x30
    lcall ?WriteData
    mov a, b
    orl a, #0x30
    lcall ?WriteData
    ret

Display_Done_Info:
    Set_Cursor(1, 1)
    Send_Constant_String(#done_line1)
    Set_Cursor(2, 1)
    Send_Constant_String(#done_line2)
    Set_Cursor(2, 12)
    mov a, runtime_min
    mov b, #10
    div ab
    orl a, #0x30
    lcall ?WriteData
    mov a, b
    orl a, #0x30
    lcall ?WriteData
    Set_Cursor(2, 15)
    mov a, runtime_sec
    mov b, #10
    div ab
    orl a, #0x30
    lcall ?WriteData
    mov a, b
    orl a, #0x30
    lcall ?WriteData
    ret

Display_Active_Info:
    Set_Cursor(1, 1)
    Send_Constant_String(#active_line1)
    Set_Cursor(2, 1)
    Send_Constant_String(#active_line2)
    ret

Display_Active_Info2:
    Set_Cursor(1, 7)
    mov a, FSM1_state
    orl a, #0x30
    lcall ?WriteData
    Set_Cursor(1, 13)
    SendToLCD(temp)
    Set_Cursor(2, 13)
    SendToLCD(sec)
    Set_Cursor(2, 1)
    mov a, runtime_min
    mov b, #10
    div ab
    orl a, #0x30
    lcall ?WriteData
    mov a, b
    orl a, #0x30
    lcall ?WriteData
    Set_Cursor(2, 4)
    mov a, runtime_sec
    mov b, #10
    div ab
    orl a, #0x30
    lcall ?WriteData
    mov a, b
    orl a, #0x30
    lcall ?WriteData
    ret

;===========================================================================
; Updates variables with Push Buttons (from macros)
;===========================================================================
Change_8bit_Variable MAC
    jb %0, %2
check%M:
    lcall LCD_PB
    jnb %0, check%M
    jb SHIFT_BUTTON, skip%Mb
    dec %1
    ljmp skip%Ma
skip%Mb:
    inc %1
skip%Ma:
ENDMAC

Update_Variables:
    Change_8bit_Variable(TEMP_SOAK_BUTTON, temp_soak, update_temp_soak)
    Set_Cursor(1, 8)
    SendToLCD(temp_soak)
    lcall Save_Variables
update_temp_soak:
    Change_8bit_Variable(TIME_SOAK_BUTTON, time_soak, update_time_soak)
    Set_Cursor(1, 13)
    SendToLCD(time_soak)
    lcall Save_Variables
update_time_soak:
    Change_8bit_Variable(TEMP_REFL_BUTTON, temp_refl, update_temp_refl)
    Set_Cursor(2, 8)
    SendToLCD(temp_refl)
    lcall Save_Variables
update_temp_refl:
    Change_8bit_Variable(TIME_REFL_BUTTON, time_refl, update_time_refl)
    Set_Cursor(2, 13)
    SendToLCD(time_refl)
    lcall Save_Variables
update_time_refl:
    ret

;===========================================================================
; Reads Push Buttons (LCD_PB routine)
;===========================================================================
LCD_PB:
    setb PB0
    setb PB1
    setb PB2
    setb PB3
    setb PB4
    setb P1.5
    clr P0.0
    clr P0.1
    clr P0.2
    clr P0.3
    clr P1.3
    jb P1.5, LCD_PB_Done
    Wait_Milli_Seconds(#50)
    jb P1.5, LCD_PB_Done
    setb P0.0
    setb P0.1
    setb P0.2
    setb P0.3
    setb P1.3
    clr P1.3
    mov c, P1.5
    mov PB4, c
    setb P1.3
    clr P0.0
    mov c, P1.5
    mov PB3, c
    setb P0.0
    clr P0.1
    mov c, P1.5
    mov PB2, c
    setb P0.1
    clr P0.2
    mov c, P1.5
    mov PB1, c
    setb P0.2
    clr P0.3
    mov c, P1.5
    mov PB0, c
    setb P0.3
LCD_PB_Done:
    ret

;===========================================================================
; Get the temperature from the ADC (Read_Temperature routine)
;===========================================================================
Read_Temperature:
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x00   ; Select channel 0
    lcall Average_ADC    ; Average 100 ADC Readings
    mov VAL_LM4040+0, R0 
    mov VAL_LM4040+1, R1
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x07   ; Select channel 7
    lcall Average_ADC
    mov x+0, R0
    mov x+1, R1
    mov x+2, #0
    mov x+3, #0
    Load_y(CONSTANT)
    lcall mul32
    mov y+0, VAL_LM4040+0
    mov y+1, VAL_LM4040+1
    mov y+2, #0
    mov y+3, #0
    lcall div32
    Load_y(COLD_TEMP)
    lcall add32
    mov temp, x+0
    ret

;===========================================================================
; Stores/Loads variables in Flash memory
;===========================================================================
PAGE_ERASE_AP   EQU 00100010b
BYTE_PROGRAM_AP EQU 00100001b

Save_Variables:
    CLR EA
    MOV TA, #0aah
    MOV TA, #55h
    ORL CHPCON, #00000001b
    MOV TA, #0aah
    MOV TA, #55h
    ORL IAPUEN, #00000001b
    MOV IAPCN, #PAGE_ERASE_AP
    MOV IAPAH, #3fh
    MOV IAPAL, #80h
    MOV IAPFD, #0FFh
    MOV TA, #0aah
    MOV TA, #55h
    ORL IAPTRG, #00000001b
    MOV IAPCN, #BYTE_PROGRAM_AP
    MOV IAPAH, #3fh
    MOV IAPAL, #80h
    MOV IAPFD, temp_soak
    MOV TA, #0aah
    MOV TA, #55h
    ORL IAPTRG,#00000001b
    MOV IAPAL, #81h
    MOV IAPFD, time_soak
    MOV TA, #0aah
    MOV TA, #55h
    ORL IAPTRG,#00000001b
    MOV IAPAL, #82h
    MOV IAPFD, temp_refl
    MOV TA, #0aah
    MOV TA, #55h
    ORL IAPTRG,#00000001b
    MOV IAPAL, #83h
    MOV IAPFD, time_refl
    MOV TA, #0aah
    MOV TA, #55h
    ORL IAPTRG,#00000001b
    MOV IAPAL,#84h
    MOV IAPFD, #55h
    MOV TA, #0aah
    MOV TA, #55h
    ORL IAPTRG, #00000001b
    MOV IAPAL, #85h
    MOV IAPFD, #0aah
    MOV TA, #0aah
    MOV TA, #55h
    ORL IAPTRG, #00000001b
    MOV TA, #0aah
    MOV TA, #55h
    ANL IAPUEN, #11111110b
    MOV TA, #0aah
    MOV TA, #55h
    ANL CHPCON, #11111110b
    setb EA
    ret

Load_Variables:
    mov dptr, #0x3f84
    clr a
    movc a, @a+dptr
    cjne a, #0x55, Load_Defaults
    inc dptr
    clr a
    movc a, @a+dptr
    cjne a, #0xaa, Load_Defaults
    mov dptr, #0x3f80
    clr a
    movc a, @a+dptr
    mov temp_soak, a
    inc dptr
    clr a
    movc a, @a+dptr
    mov time_soak, a
    inc dptr
    clr a
    movc a, @a+dptr
    mov temp_refl, a
    inc dptr
    clr a
    movc a, @a+dptr
    mov time_refl, a
    ret

Load_Defaults:
    mov temp_soak, #150
    mov time_soak, #60
    mov temp_refl, #230
    mov time_refl, #30
    ret

putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

END
