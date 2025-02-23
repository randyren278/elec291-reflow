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
    
; Interrupt vectors
org 0x0003
    reti
org 0x000B
    reti
org 0x0013
    reti
org 0x001B
    reti
org 0x0023 
    reti
org 0x002B
    ljmp Timer2_ISR

; Constants
CLK  EQU 16600000
BAUD EQU 115200
TIMER1_RELOAD EQU (0x100-(CLK/(16*BAUD)))
TIMER2_RATE   EQU 100
TIMER2_RELOAD EQU (65536-(CLK/(16*TIMER2_RATE)))
RESISTOR_1 EQU 9990
RESISTOR_2 EQU 33
CONSTANT   EQU ((99900*RESISTOR_2)/RESISTOR_1)
COLD_TEMP  EQU 22
TIME_ERROR EQU 50
TEMP_ERROR EQU 60

; I/O Definitions
PWM_OUT     EQU P1.0
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

; Data Segment
DSEG at 0x30
x:   ds 4
y:   ds 4
bcd: ds 5
VAL_LM4040: ds 2
pwm_counter: ds 1
pwm:         ds 1
runtime_sec: ds 1
runtime_min: ds 1
FSM1_state: ds 1
temp:       ds 1
sec:        ds 1
temp_soak:  ds 1
time_soak:  ds 1
temp_refl:  ds 1
time_refl:  ds 1

; Bit Segment
BSEG
mf: dbit 1
s_flag: dbit 1
state_0_flag: dbit 1
active_flag:  dbit 1
error_flag:   dbit 1
done_flag:    dbit 1
PB0: dbit 1
PB1: dbit 1
PB2: dbit 1
PB3: dbit 1
PB4: dbit 1

; Code Segment
CSEG

; LCD Messages
setup_line1:  db 'Soak   XXXC XXXs', 0
setup_line2:  db 'Reflow XXXC XXXs', 0
active_line1: db 'State X     XXXC', 0
active_line2: db 'XX:XX       XXXs', 0
error_line1:  db 'Error! t = XX:XX', 0
error_line2:  db 'Oven Temp = XXXC', 0
done_line1:   db '  Oven Cooled!  ', 0
done_line2:   db 'Runtime  = XX:XX', 0

; Timer 2 ISR
Timer2_ISR:
    clr TF2
    push psw
    push acc
    inc pwm_counter
    clr c
    mov a, pwm
    subb a, pwm_counter
    cpl c
    mov PWM_OUT, c
    mov a, pwm_counter
    cjne a, #100, Timer2_ISR_done
    mov pwm_counter, #0
    inc sec
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

; Initialization
Init_All:
    lcall Init_Pins
    Wait_Milli_Seconds(#5)
    lcall Init_Timer2
    lcall Init_ADC
    lcall Init_Variables
    setb EA
    ret

Init_Pins:
    mov P3M1, #0x00
    mov P3M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P0M1, #0x00
    mov P0M2, #0x00
    ret

Init_Timer2:
    mov T2CON, #0
    mov TH2, #high(TIMER2_RELOAD)
    mov TL2, #low(TIMER2_RELOAD)
    mov T2MOD, #0b1010_0000
    mov RCMP2H, #high(TIMER2_RELOAD)
    mov RCMP2L, #low(TIMER2_RELOAD)
    mov pwm_counter, #0
    orl EIE, #0x80
    setb TR2
    ret

Init_ADC:
    orl P1M1, #0b10000010
    anl P1M2, #0b01111101
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x07
    mov AINDIDS, #0x00
    orl AINDIDS, #0b10000001
    orl ADCCON1, #0x01
    ret

Init_Variables:
    mov pwm_counter, #0
    mov pwm, #0
    mov runtime_sec, #0
    mov runtime_min, #0
    mov FSM1_state, #0
    mov sec, #0
    clr s_flag
    clr state_0_flag
    clr active_flag
    clr error_flag
    clr done_flag
    ret

; Main Program
main:
    mov sp, #07FH
    lcall Init_All
    lcall LCD_4BIT
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

; FSM Implementation
FSM1:
    mov A, FSM1_state
    cjne A, #0, FSM1_state1

FSM1_state0:
    mov pwm, #0
    mov sec, #0
    lcall Update_Variables
    jb state_0_flag, Not_First_Time
    lcall Display_Setup_Info
    setb state_0_flag
Not_First_Time:
    lcall Display_Setup_Info2
    jb PB0, FSM1_state0_done
    Wait_Milli_Seconds(#50)
    jb PB0, FSM1_state0_done
    mov FSM1_state, #1
    lcall Display_Active_Info
    mov sec, #0    
FSM1_state0_done:
    ljmp FSM2

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
    mov FSM1_state, #6
    ljmp FSM2
FSM1_error_checked:
    mov A, temp_soak
    clr C
    subb A, temp
    jnc FSM1_state1_done
    mov FSM1_state, #2
    mov sec, #0
FSM1_state1_done:
    ljmp FSM2

FSM1_state2:
    cjne A, #2, FSM1_state3
    mov pwm, #20
    mov A, time_soak
    clr C
    subb A, sec
    jnc FSM1_state2_done
    mov FSM1_state, #3
    mov sec, #0    
FSM1_state2_done:
    ljmp FSM2

FSM1_state3:
    cjne A, #3, FSM1_state4
    mov pwm, #100
    mov A, temp_refl
    clr C
    subb A, temp
    jnc FSM1_state3_done
    mov FSM1_state, #4
    mov sec, #0
FSM1_state3_done:
    ljmp FSM2

FSM1_state4:
    cjne A, #4, FSM1_state5
    mov pwm, #20
    mov A, time_refl
    clr C
    subb A, sec
    jnc FSM1_state4_done
    mov FSM1_state, #5
    mov sec, #0
FSM1_state4_done:
    ljmp FSM2

FSM1_state5:
    cjne A, #5, FSM1_state6
    mov pwm, #0
    mov A, temp
    clr C
    subb A, #60
    jnc FSM1_state5_done
    mov FSM1_state, #7
FSM1_state5_done:
    ljmp FSM2

FSM1_state6:
    cjne A, #6, FSM1_state7
    mov pwm, #0
    jb PB0, FSM1_state6_done
    Wait_Milli_Seconds(#50)
    jb PB0, FSM1_state6_done
    mov FSM1_state, #0
    clr state_0_flag
    clr active_flag
    clr error_flag
    clr done_flag
FSM1_state6_done:
    ljmp FSM2

FSM1_state7:
    mov pwm, #0
    jb PB0, FSM1_state7_done
    Wait_Milli_Seconds(#50)
    jb PB0, FSM1_state7_done
    mov FSM1_state, #0
    clr state_0_flag
    clr active_flag
    clr error_flag
    clr done_flag
FSM1_state7_done:
    ljmp FSM2

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
    jb PB0, FSM2_done
    Wait_Milli_Seconds(#50)
    jb PB0, FSM2_done
    mov FSM1_state, #0
    clr state_0_flag
    clr active_flag
    clr error_flag
    clr done_flag
FSM2_done:
    ret

; Display Functions
Display_Setup_Info:
    Set_Cursor(1, 1)
    Send_Constant_String(#setup_line1)
    Set_Cursor(2, 1)
    Send_Constant_String(#setup_line2)
    ret

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
    ret

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

; Temperature Measurement
Read_Temperature:
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x00
    lcall Average_ADC
    mov VAL_LM4040+0, R0 
    mov VAL_LM4040+1, R1
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x07
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

; System Functions
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

$NOLIST
$include(LCD_4bit.inc)
$include(math32.inc)
$include(macros.inc)
$LIST

END