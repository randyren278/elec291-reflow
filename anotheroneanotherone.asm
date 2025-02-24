$NOLIST
$MODN76E003
$LIST
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
done_message: 	  db 'done!',0
stop_message: 	  db 'stopped!',0
oven_fsm_message_0: db 'Oven State 0!   ',0
oven_fsm_message_1: db 'Oven State 1!   ',0
oven_fsm_message_2: db 'Oven State 2!   ',0
oven_fsm_message_3: db 'Oven State 3!   ',0
oven_fsm_message_4: db 'Oven State 4!   ',0
oven_fsm_message_5: db 'Oven State 5!   ',0
reset_state_message:   db 'Settings Reset! ', 0
state1_message:   db 'state1          ', 0
cseg
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3
SOUND_OUT equ P1.5
PWM_OUT   EQU P1.0
$NOLIST
$include(LCD_4bit.inc)
$include(state_machine.inc)
$LIST
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
Count1ms:     ds 2 
sec: ds 1
temp: ds 1
pwm_counter:  ds 1
pwm:          ds 1
seconds:      ds 1
$NOLIST
$include(math32.inc)
$include(read_temp.inc)
$include(new_oven_fsm.inc)
$LIST
CSEG
Init_All:
	mov	P3M1, #0x00
	mov	P3M2, #0x00
	mov	P1M1, #0x00
	mov	P1M2, #0x00
	mov	P0M1, #0x00
	mov	P0M2, #0x00
	orl	CKCON, #0x10
	orl	PCON, #0x80
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0F
	orl	TMOD, #0x20
	clr	TR0
	orl	CKCON,#0x08
	anl	TMOD,#0xF0
	orl	TMOD,#0x01
	orl	P1M1, #0b10000000
	anl	P1M2, #0b01111111
    mov pwm_counter, #0
	mov AINDIDS, #0x00
	orl AINDIDS, #0b00000001
	orl ADCCON1, #0x01
	lcall Timer2_Init
	setb EA
	ret
wait_1ms:
	clr	TR0
	clr	TF0
	mov	TH0, #high(TIMER0_RELOAD_1MS)
	mov	TL0,#low(TIMER0_RELOAD_1MS)
	setb TR0
	jnb	TF0, $
	ret
waitms:
	lcall wait_1ms
	djnz R2, waitms
	ret
Display_formated_BCD:  
    Display_BCD(bcd+2) 
    Display_BCD(bcd+1) 
    Display_BCD(bcd+0)  
    ret
Timer2_Init:
	mov T2CON, #0
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	mov T2MOD, #1000_0000b 
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	mov seconds, #0
	clr seconds_flag
	orl EIE, #0x80
    setb TR2
	ret
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
	inc seconds
	setb seconds_flag
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
main:
	mov sp, #0x7f
	lcall Temp_Init_All
	lcall Init_All
    lcall LCD_4BIT
    lcall state_init
	Set_Cursor(1, 1)
    Send_Constant_String(#Title)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
	mov R2, #250
	lcall waitms
Forever:
	mov R2, #50
	lcall waitms
	jnb seconds_flag, no_second
	clr seconds_flag
	cpl P1.5
no_second:
	mov R2, #50
	lcall waitms
	ljmp FSM_select
FSM_select:
	mov a, selecting_state
select_wait:
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
    ljmp forever
select_soak_temp_ah:
	ljmp select_soak_temp
select_soak_time:
	cjne a, #1, select_soak_temp_ah
	Set_Cursor(1, 1)
    Send_Constant_String(#sstime_message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#sstime_message2)
    push AR5
    mov R5, x
    mov x+0, soak_time
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	Set_Cursor(2, 11)
    lcall hex2bcd
    lcall Display_formated_BCD
    mov x, R5
    pop AR5
    lcall rst_check
    push AR3
    push AR4
    push AR5
    mov R3, #0x3C
    mov R4, #0x78
    mov R5, soak_time
    lcall up_check
    lcall down_check
    mov soak_time, R5
    pop AR5
    pop AR4
    pop AR3
    lcall s_s_check
    lcall nxt_check
    ljmp forever
select_soak_temp:
	cjne a, #2, $+6
	ljmp $+6
	ljmp select_reflow_time
	Set_Cursor(1, 1)
    Send_Constant_String(#sstemp_message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#sstemp_message2)
    Set_Cursor(2, 11)
    push AR5
	push_x
	mov x+0, soak_temp
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
    lcall hex2bcd
    lcall Display_formated_BCD
	pop_x
    lcall rst_check
    push AR3
    push AR4
    push AR5
    mov R3, #0x96
    mov R4, #0xC8
    mov R5, soak_temp
    lcall up_check
    lcall down_check
    mov soak_temp, R5
    pop AR5
    pop AR4
    pop AR3
    lcall s_s_check
    lcall nxt_check
    ljmp forever
select_reflow_time:
	cjne a, #3, select_reflow_temp
	Set_Cursor(1, 1)
    Send_Constant_String(#srtime_message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#srtime_message2)
    Set_Cursor(2, 11)
    push AR5
    mov R5, x
    mov x, reflow_time
    lcall hex2bcd
    lcall Display_formated_BCD
    mov x, R5
    pop AR5
    lcall rst_check
    push AR3
    push AR4
    push AR5
    mov R3, #0x00
    mov R4, #0x2D
    mov R5, reflow_time
    lcall up_check
    lcall down_check
    mov reflow_time, R5
    pop AR5
    pop AR4
    pop AR3
    lcall s_s_check
    lcall nxt_check
    ljmp forever
select_reflow_temp:
	Set_Cursor(1, 1)
    Send_Constant_String(#srtemp_message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#srtemp_message2)
    Set_Cursor(2, 11)
    push AR5
    mov R5, x
    mov x, reflow_temp
    lcall hex2bcd
    lcall Display_formated_BCD
    mov x, R5
    pop AR5
    lcall rst_check
    push AR3
    push AR4
    push AR5
    mov R3, #0xD9
    mov R4, #0xF0
    mov R5, reflow_temp
    lcall up_check
    lcall down_check
    mov reflow_temp, R5
    pop AR5
    pop AR4
    pop AR3
    lcall s_s_check
    lcall nxt_check
    ljmp forever
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
	Send_Constant_string(#too_high_message)
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
	Send_Constant_string(#too_low_message)
	ret
s_s_check:
	lcall ADC_to_PB
	mov c, S_S
	jnc s_s_check_done
	ret
s_s_check_done:
	ljmp FSM_Init
END