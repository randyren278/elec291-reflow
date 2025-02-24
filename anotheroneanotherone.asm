$NOLIST
$MODN76E003
$LIST

; Define constants and equates
CLK               EQU 16600000 ; Microcontroller system frequency in Hz
BAUD              EQU 115200 ; Baud rate of UART in bps
TIMER1_RATE       EQU 1000     ; 1000Hz for 1ms interrupt
TIMER1_RELOAD     EQU (65536 - (CLK / TIMER1_RATE))
TIMER0_RELOAD_1MS EQU (0x10000 - (CLK / 1000))
TIMER2_RATE       EQU 100      ; 100Hz for 10ms interrupt
TIMER2_RELOAD     EQU (65536 - (CLK / (16 * TIMER2_RATE)))

; Define bit variables
BSEG
S_S: dbit 1
DOWN: dbit 1
UP: dbit 1
NXT: dbit 1
RST: dbit 1
mf: dbit 1
seconds_flag: dbit 1
s_flag: dbit 1
oven_flag: dbit 1

; Define data segment
DSEG at 30H
x: ds 4
y: ds 4
BCD: ds 5
selecting_state: ds 1
oven_state: ds 1
soak_time: ds 1
soak_temp: ds 1
reflow_time: ds 1
reflow_temp: ds 2
Count1ms: ds 2
sec: ds 1
temp: ds 1
pwm_counter: ds 1
pwm: ds 1
seconds: ds 1

; Include necessary libraries
$NOLIST
$include(LCD_4bit.inc)
$include(state_machine.inc)
$include(math32.inc)
$include(read_temp.inc)
$include(new_oven_fsm.inc)
$LIST

; Define LCD and other pin equates
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3
SOUND_OUT equ P1.5
PWM_OUT   EQU P1.0

; String constants for LCD display
title:            db '  here we go!  ', 0
blank:            db '                ', 0
swait_message1:   db 'Set your values ', 0
swait_message2:   db 'Press next      ', 0
sstime_message1:  db 'Select soak time', 0
sstime_message2:  db 'Soak time:      ', 0
sstemp_message1:  db 'Select soak temp', 0
sstemp_message2:  db 'Soak temp:      ', 0
srtime_message1:  db 'Select refl time', 0
srtime_message2:  db 'Refl time:      ', 0
srtemp_message1:  db 'Select refl temp', 0
srtemp_message2:  db 'Refl temp:      ', 0
too_high_message: db 'max!     ', 0
too_low_message:  db 'min!     ', 0
forever_message:  db 'hello please', 0
its_works:        db 'die',0
done_message:     db 'done!',0
stop_message:     db 'stopped!',0
oven_fsm_message_0: db 'Oven State 0!   ',0
oven_fsm_message_1: db 'Oven State 1!   ',0
oven_fsm_message_2: db 'Oven State 2!   ',0
oven_fsm_message_3: db 'Oven State 3!   ',0
oven_fsm_message_4: db 'Oven State 4!   ',0
oven_fsm_message_5: db 'Oven State 5!   ',0
reset_state_message: db 'Settings Reset! ', 0
state1_message:   db 'state1          ', 0

; Code segment starts here
CSEG

; Interrupt vectors must be defined in ascending order
ORG 0x0000
    ljmp main

ORG 0x001B  ; Timer 1 interrupt vector
    ljmp Timer1_ISR

ORG 0x002B  ; Timer 2 interrupt vector
    ljmp Timer2_ISR

; Main program starts here
main:
    mov sp, #0x7f
    lcall Temp_Init_All
    lcall Init_All
    lcall LCD_4BIT
    lcall state_init ; From State_Machine.inc

    ; Initial messages in LCD
    Set_Cursor(1, 1)
    Send_Constant_String(#title)
    Set_Cursor(2, 1)
    Send_Constant_String(#blank)

    mov R2, #250
    lcall waitms

Forever:
    ; Wait 50 ms between readings
    mov R2, #50
    lcall waitms

    ; Check if a second has passed
    jnb seconds_flag, no_second
    clr seconds_flag
    cpl P1.5

no_second:
    mov R2, #50
    lcall waitms

    ljmp FSM_select

; Timer 1 ISR
Timer1_ISR:
    clr TF1 ; Clear overflow flag
    ; Increment millisecond counter
    inc Count1ms+0
    mov a, Count1ms+0
    jnz Timer1_ISR_Done
    inc Count1ms+1
    ; If 1000ms has passed, increment seconds
    mov a, Count1ms+1
    cjne a, #high(1000), Timer1_ISR_Done
    mov a, Count1ms+0
    cjne a, #low(1000), Timer1_ISR_Done
    mov Count1ms+0, #0
    mov Count1ms+1, #0
    inc seconds
    setb seconds_flag
Timer1_ISR_Done:
    pop x+3
    pop x+2
    pop x+1
    pop x+0
    pop y+3
    pop y+2
    pop y+1
    pop y+0
    pop psw
    pop acc
    reti

; Timer 2 ISR
Timer2_ISR:
    clr TF2
    push acc
    push psw
    push y+0
    push y+1
    push y+2
    push y+3
    push x+0
    push x+1
    push x+2
    push x+3
    inc pwm_counter
    clr c
    mov a, pwm
    subb a, pwm_counter
    cpl c
    mov PWM_OUT, c
    mov a, pwm_counter
    cjne a, #100, Timer2_ISR_done
    mov pwm_counter, #0
Timer2_ISR_done:
    pop x+3
    pop x+2
    pop x+1
    pop x+0
    pop y+3
    pop y+2
    pop y+1
    pop y+0
    pop psw
    pop acc
    reti

; Initialization routine
Init_All:
    ; Configure pins for bidirectional I/O
    mov P3M1, #0x00
    mov P3M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P0M1, #0x00
    mov P0M2, #0x00

    ; Timer 1 setup
    clr TR1
    mov TMOD, #0x10 ; Timer 1 Mode 1 (16-bit)
    mov TH1, #high(TIMER1_RELOAD)
    mov TL1, #low(TIMER1_RELOAD)
    setb ET1 ; Enable Timer 1 interrupt
    setb TR1 ; Start Timer 1

    ; Timer 0 for delays
    clr TR0
    orl CKCON, #0x08 ; CLK for timer 0
    anl TMOD, #0xF0 ; Clear Timer 0 bits
    orl TMOD, #0x01 ; Timer 0 Mode 1 (16-bit)

    ; ADC setup
    orl P1M1, #0b10000000 ; P1.7 as input
    anl P1M2, #0b01111111
    mov pwm_counter, #0
    mov pwm, #0
    mov AINDIDS, #0x00
    orl AINDIDS, #0b00000001 ; Enable AIN0
    orl ADCCON1, #0x01 ; Enable ADC

    ; Timer 2 setup
    lcall Timer2_Init
    setb EA ; Enable global interrupts
    ret

; Wait 1ms using Timer 0
wait_1ms:
    clr TR0
    clr TF0
    mov TH0, #high(TIMER0_RELOAD_1MS)
    mov TL0, #low(TIMER0_RELOAD_1MS)
    setb TR0
    jnb TF0, $
    ret

; Wait for R2 milliseconds
waitms:
    lcall wait_1ms
    djnz R2, waitms
    ret

; Display formatted BCD
Display_formated_BCD:
    Display_BCD(bcd+2)
    Display_BCD(bcd+1)
    Display_BCD(bcd+0)
    ret

; Timer 2 initialization
Timer2_Init:
    mov T2CON, #0 ; Stop timer
    mov TH2, #high(TIMER2_RELOAD)
    mov TL2, #low(TIMER2_RELOAD)
    mov T2MOD, #0x80 ; Enable autoreload
    mov RCMP2H, #high(TIMER2_RELOAD)
    mov RCMP2L, #low(TIMER2_RELOAD)
    setb TR2 ; Start Timer 2
    ret

; ADC to pushbutton conversion
ADC_to_PB:
    push acc
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x00 ; Select AIN0
    clr ADCF
    setb ADCS
    jnb ADCF, $
    setb RST
    setb NXT
    setb UP
    setb DOWN
    setb S_S
    ; Check for button presses based on ADC value
    clr c
    mov a, ADCRH
    subb a, #0xb0
    jc ADC_to_PB_L4
    clr RST
    sjmp ADC_to_PB_Done
ADC_to_PB_L4:
    clr c
    mov a, ADCRH
    subb a, #0x90
    jc ADC_to_PB_L3
    clr NXT
    sjmp ADC_to_PB_Done
ADC_to_PB_L3:
    clr c
    mov a, ADCRH
    subb a, #0x70
    jc ADC_to_PB_L2
    clr UP
    sjmp ADC_to_PB_Done
ADC_to_PB_L2:
    clr c
    mov a, ADCRH
    subb a, #0x50
    jc ADC_to_PB_L1
    clr DOWN
    sjmp ADC_to_PB_Done
ADC_to_PB_L1:
    clr c
    mov a, ADCRH
    subb a, #0x30
    jc ADC_to_PB_Done
    clr S_S
ADC_to_PB_Done:
    pop acc
    ret

; FSM_select logic
FSM_select:
    mov a, selecting_state
    cjne a, #0, select_soak_time
    Set_Cursor(1, 1)
    Send_Constant_String(#swait_message1)
    Set_Cursor(2, 1)
    Send_Constant_String(#swait_message2)
    mov R2, #250
    lcall waitms
    lcall rst_check
    lcall nxt_check
    lcall s_s_check
    ljmp Forever

select_soak_time:
    cjne a, #1, select_soak_temp
    Set_Cursor(1, 1)
    Send_Constant_String(#sstime_message1)
    Set_Cursor(2, 1)
    Send_Constant_String(#sstime_message2)
    Set_Cursor(2, 11)
    mov x+0, soak_time
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    lcall hex2bcd
    lcall Display_formated_BCD
    lcall rst_check
    push AR3
    push AR4
    push AR5
    mov R3, #0x3C ; Min soak time
    mov R4, #0x78 ; Max soak time
    mov R5, soak_time
    lcall up_check
    lcall down_check
    mov soak_time, R5
    pop AR5
    pop AR4
    pop AR3
    lcall s_s_check
    lcall nxt_check
    ljmp Forever

select_soak_temp:
    cjne a, #2, select_reflow_time
    Set_Cursor(1, 1)
    Send_Constant_String(#sstemp_message1)
    Set_Cursor(2, 1)
    Send_Constant_String(#sstemp_message2)
    Set_Cursor(2, 11)
    mov x+0, soak_temp
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    lcall hex2bcd
    lcall Display_formated_BCD
    lcall rst_check
    push AR3
    push AR4
    push AR5
    mov R3, #0x96 ; Min soak temp
    mov R4, #0xC8 ; Max soak temp
    mov R5, soak_temp
    lcall up_check
    lcall down_check
    mov soak_temp, R5
    pop AR5
    pop AR4
    pop AR3
    lcall s_s_check
    lcall nxt_check
    ljmp Forever

select_reflow_time:
    cjne a, #3, select_reflow_temp
    Set_Cursor(1, 1)
    Send_Constant_String(#srtime_message1)
    Set_Cursor(2, 1)
    Send_Constant_String(#srtime_message2)
    Set_Cursor(2, 11)
    mov x+0, reflow_time
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    lcall hex2bcd
    lcall Display_formated_BCD
    lcall rst_check
    push AR3
    push AR4
    push AR5
    mov R3, #0x00 ; Min reflow time
    mov R4, #0x2D ; Max reflow time
    mov R5, reflow_time
    lcall up_check
    lcall down_check
    mov reflow_time, R5
    pop AR5
    pop AR4
    pop AR3
    lcall s_s_check
    lcall nxt_check
    ljmp Forever

select_reflow_temp:
    Set_Cursor(1, 1)
    Send_Constant_String(#srtemp_message1)
    Set_Cursor(2, 1)
    Send_Constant_String(#srtemp_message2)
    Set_Cursor(2, 11)
    mov x+0, reflow_temp
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    lcall hex2bcd
    lcall Display_formated_BCD
    lcall rst_check
    push AR3
    push AR4
    push AR5
    mov R3, #0xD9 ; Min reflow temp
    mov R4, #0xF0 ; Max reflow temp
    mov R5, reflow_temp
    lcall up_check
    lcall down_check
    mov reflow_temp, R5
    pop AR5
    pop AR4
    pop AR3
    lcall s_s_check
    lcall nxt_check
    ljmp Forever

; Button check routines
rst_check:
    lcall ADC_to_PB
    mov c, RST
    jnc rst_check_0
    ret
rst_check_0:
    ljmp reset_state

nxt_check:
    lcall ADC_to_PB
    mov c, NXT
    jnc next_check_1
    ret
next_check_1:
    mov x, selecting_state
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    mov y, #0x04
    mov y+1, #0
    mov y+2, #0
    mov y+3, #0
    lcall x_eq_y
    setb c
    jb mf, next_check_2
    mov a, selecting_state
    addc a, #0
    mov selecting_state, a
    ret
next_check_2:
    clr c
    mov selecting_state, #0
    ret

up_check:
    lcall ADC_to_PB
    mov c, UP
    jnc up_check_1
    ret
up_check_1:
    mov x, R4
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    mov y, R5
    mov y+1, #0
    mov y+2, #0
    mov y+3, #0
    lcall x_gt_y
    setb c
    jnb mf, up_check_2
    mov a, R5
    addc a, #0
    mov R5, a
    ret
up_check_2:
    clr c
    Set_Cursor(2, 11)
    Send_Constant_String(#too_high_message)
    ret

down_check:
    lcall ADC_to_PB
    mov c, DOWN
    jnc down_check_1
    ret
down_check_1:
    mov x, R3
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    mov y, R5
    mov y+1, #0
    mov y+2, #0
    mov y+3, #0
    lcall x_lt_y
    setb c
    jnb mf, down_check_2
    mov a, R5
    subb a, #0
    mov R5, a
    ret
down_check_2:
    clr c
    Set_Cursor(2, 11)
    Send_Constant_String(#too_low_message)
    ret

s_s_check:
    lcall ADC_to_PB
    mov c, S_S
    jnc s_s_check_done
    ret
s_s_check_done:
    ljmp FSM_Init

END