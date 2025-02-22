$NOLIST
$MODN76E003
$LIST

; -------------------------------------------------------------
;   N76E003 pinout reference (for convenience):
; -------------------------------------------------------------
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


CLK               EQU 16600000 ; System clock
BAUD              EQU 115200 ; Desired baud rate
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RELOAD_1MS EQU (0x10000 - (CLK/1000))


org 0x0000
	ljmp main 

; default lcd messages 

test_message:     DB '** TEMP TEST  **', 0
value_message:    DB '   Temp=        ', 0

; library defintions 

LCD_RS EQU P1.3
LCD_E  EQU P1.4
LCD_D4 EQU P0.0
LCD_D5 EQU P0.1
LCD_D6 EQU P0.2
LCD_D7 EQU P0.3

$NOLIST
; Include your 4-bit LCD library here:
$INCLUDE (LCD_4bit.inc)
$LIST

DSEG AT 30H
x:   DS 4
y:   DS 4
bcd: DS 5       ; To hold the BCD result after hex2bcd
BSEG
mf:  DBIT 1


$NOLIST
$INCLUDE (math32.inc)
$LIST

; intiliaze serial potr ** refer to hello.asm file 

InitSerialPort: 
	
    mov P3M1, #0x00
    mov P3M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P0M1, #0x00
    mov P0M2, #0x00
    
    mov R1, #200
    mov R0, #104
    djnz R0, $   ; 4 cycles->4*60.285ns*104=25us
    djnz R1, $-4 ; 25us*200=5.0ms
    
    ; Now we can proceed with the configuration of the serial port
	orl	CKCON, #0x10 ; CLK is the input for timer 1
	orl	PCON, #0x80 ; Bit SMOD=1, double baud rate
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0F ; Clear the configuration bits for timer 1
	orl	TMOD, #0x20 ; Timer 1 Mode 2
	mov	TH1, #TIMER1_RELOAD
	setb TR1
    ret
    
    
    ; send characters to serial port changed locig slightyl 
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret
    
    
Serial_formatted_BCD:

	mov a,bcd+3
	anl a,#0x0f
	add a, #0x30
	lcall putchar
	
	;hundreds tens and ones just in case sode iron gets hot 
	
	mov a,bcd+2
	anl a,#0xf0
	swap a
	add a, #0x30
	lcall putchar
	
	mov a,bcd+2
	anl a,#0x0f
	add a, #0x30
	lcall putchar
	
	mov a,#'.'
	lcall putchar
	
	; decimals now 
	
	
	mov a,bcd+1
	swap a
	anl a,#0x0f
	add a, #0x30
	lcall putchar
	
	mov a, bcd+1
	anl a,#0x0f
	add a,#0x30
	lcall putchar
	
	mov a, bcd+0
	swap a
	anl a ,#0x0f
	add a ,#0x30
	lcall putchar
	
	mov a, bcd+0
	anl a, #0x0f
	add a, #0x30
	lcall putchar
	
	mov a,#'C'
	
    ; Print newline
    mov  A, #0x0D  ; '\r'
    lcall putchar
    mov  A, #0x0A  ; '\n'
    lcall putchar

    ret
    
   ; intiliaze everything 
	
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
	
	; Initialize the pin used by the ADC (P1.1) as input.
	orl	P1M1, #0b00000010
	anl	P1M2, #0b11111101
	
	; Initialize and start the ADC:
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x07 ; Select channel 7
	; AINDIDS select if some pins are analog inputs or digital I/O:
	mov AINDIDS, #0x00 ; Disable all analog inputs
	orl AINDIDS, #0b10000000 ; P1.1 is analog input
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

; We can display a number any way we want.  In this case with
; four decimal places.
Display_formated_BCD:
	Set_Cursor(2, 10)
	Display_BCD(bcd+2)
	Display_char(#'.')
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	;Set_Cursor(2, 10)
	;Display_char(#'=')
	ret
	
main:
	mov sp, #0x7f
	lcall Init_All
	
	lcall InitSerialPort
    lcall LCD_4BIT
    
    ; initial messages in LCD
	Set_Cursor(1, 1)
    Send_Constant_String(#test_message)
	Set_Cursor(2, 1)
    Send_Constant_String(#value_message)
    
Forever:
	clr ADCF
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
    
    ; Read the ADC result and store in [R1, R0]
    mov a, ADCRH   
    swap a
    push acc
    anl a, #0x0f
    mov R1, a
    pop acc
    anl a, #0xf0
    orl a, ADCRL
    mov R0, A
    
    ;convert to ray 12 bit for voltage 
    
    mov x+0,R0
    mov x+1, R1
    mov x+2, #0
    mov x+3, #0
    
    Load_y(50300)
    lcall mul32
    
    Load_y(4095)
    lcall div32
    
    mov y+0, #low(27300)
    mov y+1, #high(27300)
    mov y+2, #0
    mov y+3, #0
    lcall sub32
    
    Load_y(100)
    
    lcall mul32
    
    lcall hex2bcd
    lcall Display_formated_BCD
    lcall Serial_formatted_BCD
    
    mov R2, #250
    lcall waitms
    mov R2, #250
    lcall waitms
    
    cpl P1.7
    
    sjmp Forever
    
END
	
	
    
    