;please work

;with 5 adc push buttons
;to think about:
	;adding another state for when start is pressed so that in forever if it gets sent back to FSM_select
	;it will know not to ask for input/go through it
	;making the checks into macros

;button functions: rst, next, up, down, start/stop
;display which you're in 
;start-> in the selecting fsm
;stop-> after reset_state in the oven fsm

; 76E003 ADC_Pushbuttons.asm: Reads push buttons using the ADC, AIN0 in P1.7

$NOLIST
$MODN76E003
$LIST

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
;

CLK               EQU 16600000 ; Microcontroller system frequency in Hz
BAUD              EQU 115200 ; Baud rate of UART in bps
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))

ORG 0x0000
	ljmp main

;                     1234567890123456    <- This helps determine the location of the counter
title:            db '  here we go!  ', 0
blank:            db '                ', 0
swait_message1:   db 'Set your values ', 0   ;s->select fsm, wait->state
swait_message2:   db 'Press next      ', 0
sstime_message1:  db 'Select soak time', 0   ;s->soak
sstime_message2:  db 'Soak time:      ', 0
sstemp_message1:  db 'Select soak temp', 0   ;s->soak
sstemp_message2:  db 'Soak temp:      ', 0
srtime_message1:  db 'Select refl time', 0   ;r->reflow
srtime_message2:  db 'Refl time:      ', 0
srtemp_message1:  db 'Select refl temp', 0   ;r->reflow
srtemp_message2:  db 'Refl temp:      ', 0
too_high_message: db 'max!     ', 0
too_low_message:  db 'min!     ', 0
forever_message:  db 'hello please', 0
its_works:        db 'die',0
;						   1234567890123456
reset_state_message:   db 'Settings Reset! ', 0 ;for testing
state1_message:   db 'state1          ', 0 ;for testing

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(state_machine.inc)
$LIST

BSEG
; These eight bit variables store the value of the pushbuttons after calling 'ADC_to_PB' below
;PB0: dbit 1 
;PB1: dbit 1     pretty sure left-right is 7-0
;PB2: dbit 1
S_S: dbit 1 ;PB3
DOWN: dbit 1 ;PB4
UP: dbit 1 ;PB5
NXT: dbit 1 ;PB6
RST: dbit 1 ;PB7
mf: dbit 1

;TODO: check if one is enough
DSEG at 30H
x: ds 4
y: ds 4
BCD: ds 5
selecting_state: ds 1
soak_time: ds 2
soak_temp: ds 2
reflow_time: ds 2
reflow_temp: ds 2

$NOLIST
$include(math32.inc)
$LIST

CSEG
Init_All:
	; Configure all the pins for biderectional I/O
	mov	P3M1, #0x00
	mov	P3M2, #0x00
	mov	P1M1, #0x00
	mov	P1M2, #0x00
	mov	P0M1, #0x00
	mov	P0M2, #0x00
	
	orl	CKCON, #0x10 ; CLK is the input for timer 1
	orl	PCON, #0x80 ; Bit SMOD=1, double baud rate
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0F ; Clear the configuration bits for timer 1
	orl	TMOD, #0x20 ; Timer 1 Mode 2
	mov	TH1, #TIMER1_RELOAD ; TH1=TIMER1_RELOAD;
	setb TR1
	
	; Using timer 0 for delay functions.  Initialize here:
	clr	TR0 ; Stop timer 0
	orl	CKCON,#0x08 ; CLK is the input for timer 0
	anl	TMOD,#0xF0 ; Clear the configuration bits for timer 0
	orl	TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer
	
	; Initialize and start the ADC:
	
	; AIN0 is connected to P1.7.  Configure P1.7 as input.
	orl	P1M1, #0b10000000
	anl	P1M2, #0b01111111
	
	; AINDIDS select if some pins are analog inputs or digital I/O:
	mov AINDIDS, #0x00 ; Disable all analog inputs
	orl AINDIDS, #0b00000001 ; Using AIN0
	orl ADCCON1, #0x01 ; Enable ADC
	
	ret
	
wait_1ms:
	clr	TR0 ; Stop timer 0
	clr	TF0 ; Clear overflow flag
	mov	TH0, #high(TIMER0_RELOAD_1MS)
	mov	TL0,#low(TIMER0_RELOAD_1MS)
	setb TR0
	jnb	TF0, $ ; Wait for overflow
	ret

; Wait the number of miliseconds in R2
waitms:
	lcall wait_1ms
	djnz R2, waitms
	ret

;set cursor before, also might have to change format	
Display_formated_BCD:  
    ;Display_BCD(bcd+4) 
    ;Display_BCD(bcd+3) 
    Display_BCD(bcd+2) 
    Display_BCD(bcd+1) 
    Display_BCD(bcd+0)  
    ret

ADC_to_PB:
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x00 ; Select AIN0
	
	clr ADCF
	setb ADCS   ; ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete

	setb RST;PB7
	setb NXT;PB6
	setb UP;PB5
	setb DOWN;PB4
	setb S_S;PB3
	;setb PB2
	;setb PB1
	;setb PB0
	
	; Check PB7
;ADC_to_PB_L7:
;	clr c
;	mov a, ADCRH
;	subb a, #0xf0
;	jc ADC_to_PB_L6
;	clr RST;PB7
;	ret
;
;	; Check PB6
;ADC_to_PB_L6:
;	clr c
;	mov a, ADCRH
;	subb a, #0xd0
;	jc ADC_to_PB_L5
;	clr NXT;PB6
;	ret

	; Check PB5
ADC_to_PB_L5:
	clr c
	mov a, ADCRH
	subb a, #0xb0
	jc ADC_to_PB_L4
	clr RST;PB5
	ret

	; Check PB4
ADC_to_PB_L4:
	clr c
	mov a, ADCRH
	subb a, #0x90
	jc ADC_to_PB_L3
	clr NXT;PB4
	ret

	; Check PB3
ADC_to_PB_L3:
	clr c
	mov a, ADCRH
	subb a, #0x70
	jc ADC_to_PB_L2
	clr UP;PB3
	ret

	; Check PB2
ADC_to_PB_L2:
	clr c
	mov a, ADCRH
	subb a, #0x50
	jc ADC_to_PB_L1
	clr DOWN
	ret

	; Check PB1
ADC_to_PB_L1:
	clr c
	mov a, ADCRH
	subb a, #0x30
	jc ADC_to_PB_L0
	clr S_S
	ret

	; Check PB0
ADC_to_PB_L0:
	clr c
	mov a, ADCRH
	subb a, #0x10
	jc ADC_to_PB_Done
	;clr PB0
	ret
	
ADC_to_PB_Done:
	; No pusbutton pressed	
	ret
	
main:
	mov sp, #0x7f
	lcall Init_All
    lcall LCD_4BIT
    
    lcall state_init ;From State_Machine.inc
    
    ; initial messages in LCD
	Set_Cursor(1, 1)
    Send_Constant_String(#Title)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)

	mov R2, #250
	lcall waitms
	
Forever:
	; Wait 50 ms between readings
	mov R2, #50
	lcall waitms

	;Set_Cursor(2, 11)
	;mov r0, #80
	;mov x+0, r0
	;mov x+1, #0 
	;mov x+2, #0
	;mov x+3, #0
	;lcall hex2bcd
	;lcall Display_formated_BCD
	
	;check if reaches forever
	;Set_Cursor(1, 1)
	;Send_Constant_String(#forever_message)
	mov R2, #250
	lcall waitms
	ljmp FSM_select

;for testing since there's no other fsm right now

state1:
	Set_Cursor(1, 1)
    Send_Constant_String(#state1_message)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
	mov R2, #250
	lcall waitms
	ljmp forever

;begin select FSM
FSM_select:
	mov a, selecting_state

select_wait:
	cjne a, #0, select_soak_time ;checks the state
	Set_Cursor(1, 1)
    Send_Constant_String(#swait_message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#swait_message2)
	mov R2, #250
	lcall waitms
    ;lcall ADC_to_PB ;checks for button press
    lcall rst_check
    lcall nxt_check
    lcall s_s_check
    ljmp forever ;i believe 

select_soak_temp_ah:
	ljmp select_soak_temp

select_soak_time:
	cjne a, #1, select_soak_temp_ah ;checks the state
	Set_Cursor(1, 1)
    Send_Constant_String(#sstime_message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#sstime_message2)
    ;Set_Cursor(2, 11)
    push AR5  ;display the current soak_time
    mov R5, x
    mov x+0, soak_time
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	Set_Cursor(2, 11)
	;Send_Constant_String(#its_works)
    lcall hex2bcd
    lcall Display_formated_BCD
    mov x, R5
    pop AR5
    ;lcall ADC_to_PB ;checks for button press
    lcall rst_check
    push AR3 ;set the paramaters for up/down
    push AR4
    push AR5
    mov R3, #0x3C ;min value allowed for soak time !check it please
    mov R4, #0x78 ;120  ;max value, !check it please, also is the dec? hex?
    mov R5, soak_time
    lcall up_check
    lcall down_check
    mov soak_time, R5
    pop AR5
    pop AR4
    pop AR3  ;am i doing this right?
    lcall s_s_check
    lcall nxt_check
    ljmp forever ;i believe 

select_soak_temp:
	cjne a, #2, select_reflow_time ;checks the state
	Set_Cursor(1, 1)
    Send_Constant_String(#sstemp_message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#sstemp_message2)
    Set_Cursor(2, 11)
    push AR5  ;display current soak temp
    mov R5, x
    mov x, soak_temp
    lcall hex2bcd
    lcall Display_formated_BCD
    mov x, R5
    pop AR5
    ;lcall ADC_to_PB ;checks for button press
    lcall rst_check
    push AR3 ;set the paramaters for up/down
    push AR4
    push AR5
    mov R3, #0x96 ;min value allowed !check it please (150 decimal)
    mov R4, #0xC8 ;max value, !check it please, also is the dec? hex? (200 decimal)
    mov R5, soak_temp
    lcall up_check
    lcall down_check
    mov soak_temp, R5
    pop AR5
    pop AR4
    pop AR3  ;am i doing this right?
    lcall s_s_check
    lcall nxt_check
    ljmp forever ;i believe 

select_reflow_time:
	cjne a, #3, select_reflow_temp ;checks the state
	Set_Cursor(1, 1)
    Send_Constant_String(#srtime_message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#srtime_message2)
    Set_Cursor(2, 11)
    push AR5  ;display current reflow time
    mov R5, x
    mov x, reflow_time
    lcall hex2bcd
    lcall Display_formated_BCD
    mov x, R5
    pop AR5
    ;lcall ADC_to_PB ;checks for button press
    lcall rst_check
    push AR3 ;set the paramaters for up/down
    push AR4
    push AR5
    mov R3, #0x2D ;45 min value allowed !check it please
    mov R4, #0x4B ;75 max value, !check it please, also is the dec? hex?
    mov R5, reflow_time
    lcall up_check
    lcall down_check
    mov reflow_time, R5
    pop AR5
    pop AR4
    pop AR3  ;am i doing this right?
    lcall s_s_check
    lcall nxt_check
    ljmp forever ;i believe 

select_reflow_temp:
	;shouldn't need to check the state
	Set_Cursor(1, 1)
    Send_Constant_String(#srtemp_message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#srtemp_message2)
    Set_Cursor(2, 11)
    push AR5  ;display current reflow temp
    mov R5, x
    mov x, reflow_temp
    lcall hex2bcd
    lcall Display_formated_BCD
    mov x, R5
    pop AR5
    ;lcall ADC_to_PB ;checks for button press
    lcall rst_check
    push AR3  ;set the paramaters for up/down
    push AR4
    push AR5
    mov R3, #0xD9 ;217 DEC ;min value allowed !check it please
    mov R4, #0xFF ; 255 DEC ;max value, !check it please, also is the dec? hex?
    mov R5, reflow_temp
    lcall up_check
    lcall down_check
    mov reflow_temp, R5
    pop AR5
    pop AR4
    pop AR3  ;am i doing this right?
    lcall s_s_check
    lcall nxt_check
    ljmp forever ;i believe 

;maybe make these macros :(
;use R3 & R4 & R5 as parameters
rst_check:
	lcall ADC_to_PB
	mov c, RST
    jnc rst_check_0 ;!could be jc
    ret
rst_check_0:
    ljmp reset_state ;or whatever it's called, wait state of oven fsm

nxt_check:
	lcall ADC_to_PB
	mov c, NXT
    jnc next_check_1 
	ret
next_check_1: 
    ;load_x(selecting_state)
    ;load_y(4)
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
    addc a, #0 ;uh
    mov selecting_state, a
    ret
next_check_2:
	clr c
	mov selecting_state, #0 ;can't go above 4 (there are 5 states)

	ret

up_check: ;R4 max
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
	lcall x_gt_y ;max > value
	setb c
	jnb mf, up_check_2
	mov a, R5
	addc a, #0 ;dec? hex?
	mov R5, a
	ret
up_check_2:
	clr c
	Set_Cursor(2, 11)
	Send_Constant_string(#too_high_message)
	ret

down_check: ;R3 min
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
	lcall x_lt_y ;min < value
	setb c
	jnb mf, down_check_2
	mov a, R5
	subb a, #0 ;dec? hex?
	mov R5, a
	ret
down_check_2:
	clr c
	Set_Cursor(2, 11)
	Send_Constant_string(#too_low_message)
	ret

s_s_check:
	lcall ADC_to_PB
	mov c, S_S
	jnc s_s_check_done ;!could be jb
	ret
s_s_check_done:
	ljmp state1 ;or whatever it's called, 1st state of oven FSM

END
