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
TIMER1_RATE         EQU 100      ; 100Hz or 10ms
TIMER1_RELOAD       EQU (65536-(CLK/(16*TIMER2_RATE))) ; Need to change timer 1 input divide to 16 in T2MOD
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

ORG 0x0000
	ljmp main
ORG 0x002B
	ljmp Timer2_ISR

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
done_message: 	  db 'done!',0
stop_message: 	  db 'stopped!',0
					   ;1234567890123456
oven_fsm_message_0: db 'Oven State 0!   ',0
oven_fsm_message_1: db 'Oven State 1!   ',0
oven_fsm_message_2: db 'Oven State 2!   ',0
oven_fsm_message_3: db 'Oven State 3!   ',0
oven_fsm_message_4: db 'Oven State 4!   ',0
oven_fsm_message_5: db 'Oven State 5!   ',0
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
SOUND_OUT equ P1.5
PWM_OUT    EQU P1.0 ; Logic 1=oven on

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
seconds_flag: dbit 1
s_flag: dbit 1 ; set to 1 every time a second has passed
oven_flag: dbit 1

;TODO: check if one is enough
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
pwm_counter:  ds 1 ; Free running counter 0, 1, 2, ..., 100, 0
pwm:          ds 1 ; pwm percentage
seconds:      ds 1 ; a seconds counter attached to Timer 2 ISR

$NOLIST
$include(math32.inc)
$include(read_temp.inc)
$include(new_oven_fsm.inc)
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

    mov soak_temp, #150
    mov reflow_temp, #270
	; timer 2 ?? 
	lcall Timer2_Init
	setb EA

	
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

Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov T2MOD, #1000_0000b 
	;orl T2MOD, #0x80 ; Enable timer 2 autoreload this was it before
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	mov seconds, #0
	clr seconds_flag
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2  ; Enable timer 2
	ret
;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	push_y
	push_x
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done_randys_version
	inc Count1ms+1

Inc_Done_randys_version: ; pwm control 

	; CODE TO MAKE THE PWM WORK
	clr c

	load_x(pwm)
	load_y(10)
	lcall mul32

	clr c
	mov a, x+0
	subb a, Count1ms+0
	jnc pwm_output
	clr c 
	mov a, x+1
	subb a, Count1ms+1 ; If pwm_counter <= pwm then c=1

pwm_output:
	cpl c
	mov PWM_OUT, c

	;check if 1000 ms has passed 
	mov a, Count1ms+0
	cjne a, #low(1000), Time_increment_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), Time_increment_done

	; if1000 ms has passed 

	clr A
	mov Count1ms+0, A
	mov Count1ms+1, A

	mov c, oven_flag
	;addc seconds, #0 ; It is super easy to keep a seconds count here
	mov  A, seconds   ; Load seconds into A
	addc A, #0       ; Add the carry to A
	mov  seconds, A   ; Store the result back in seconds

	setb seconds_flag

	;increment second flag 

	;mov a, seconds
	;add a, #1
	;da A
	;mov seconds, A


;Inc_Done:
	; Check if second has passed
;	mov a, Count1ms+0
;	cjne a, #low(1000), Time_increment_done ; Warning: this instruction changes the carry flag!
;	mov a, Count1ms+1
;	cjne a, #high(1000), Time_increment_done
	
	; 1000 milliseconds have passed.  Set a flag so the main program knows
;	setb seconds_flag ; Let the main program know a second had passed
	;cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
;	clr a
;	mov Count1ms+0, a
;	mov Count1ms+1, a
	; Increment the time only when state flag is on
	;jnb state, Time_increment_done
	
;	mov a, sec
;	add a, #0x01
;	da a
;	mov sec, a
;	
;	cjne a, #0x60, Time_increment_done

		
Time_increment_done:
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







ADC_to_PB:
	push acc
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
	pop acc
	ret

	; Check PB4
ADC_to_PB_L4:
	clr c
	mov a, ADCRH
	subb a, #0x90
	jc ADC_to_PB_L3
	clr NXT;PB4
	pop acc
	ret

	; Check PB3
ADC_to_PB_L3:
	clr c
	mov a, ADCRH
	subb a, #0x70
	jc ADC_to_PB_L2
	clr UP;PB3
	pop acc
	ret

	; Check PB2
ADC_to_PB_L2:
	clr c
	mov a, ADCRH
	subb a, #0x50
	jc ADC_to_PB_L1
	clr DOWN
	pop acc
	ret

	; Check PB1
ADC_to_PB_L1:
	clr c
	mov a, ADCRH
	subb a, #0x30
	jc ADC_to_PB_L0
	clr S_S
	pop acc
	ret

	; Check PB0
ADC_to_PB_L0:
	clr c
	mov a, ADCRH
	subb a, #0x10
	jc ADC_to_PB_Done
	;clr PB0
	pop acc
	ret
	
ADC_to_PB_Done:
	; No pusbutton pressed	
	pop acc
	ret
	
main:
	mov sp, #0x7f
	lcall Temp_Init_All
	lcall Init_All
    lcall LCD_4BIT
    
    lcall state_init ;From State_Machine.inc
    
    ; initial messages in LCD

    load_x(soak_temp)

	Set_Cursor(1, 1)
    Send_Constant_String(#Title)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
	mov R2, #250
	lcall waitms