P
; LIVESHARE LINK: https://prod.liveshare.vsengsaas.visualstudio.com/join?CF8BCEBE62F72B5A7754B00AA6AA6AE78AA4
; Requirements:
; 1. Controls must be capable of measuring temperatures between 25C and 240C with max error of 3C
; 2. Use LM335 to measure the temperature at the cold junction, and add it to the temperature measured at the hot junction.
; Thermocouple wire measures temperature as 41uV/C
; 255C*41uV/C = 10.455mv
; Max Gain: 3.5V/10.455mv = 334.768 V/V
; r1/r2 < 334.768V/V
; 3. Selectable reflow profile parameters
; a) Soak temperature, soak time, reflow temperature and reflow time
; b) Selectable using pushbuttons
; 4. Temperature is controlled using PWM
; 5. User interface and feedback (output to python for wandy)
; To-Do:
; 1. Check for temperature once per second
;  a. Read thermocouple voltage
;  b. Convert thermocouple voltage to temperature
;  c. Read cold junction voltage
;  d. Convert cold junction to temperature
;  e. Add cold junction temperature to thermocouple temperature
;  f. Display temperature
; 2. Make reflow profile parameters selectable
;  a. Soak Temperature
;  b. Soak time
;  c. Reflow temperature
;  d. Reflow time
; 19.79mV - 22.1C
; 252.32mV - 350C
; 252.32mV-19.79 = A
; 350-22.1 = B
; B/A
; 1410.14062702
; - - - - - - - [ ACTUAL CODE ] - - - - - - - -
; 76E003 ADC test program: Reads channel 7 on P1.1, pin 14
; This version uses the LM4040 voltage reference connected to pin 6 (P1.7/AIN0)


$NOLIST
$MODN76E003
$LIST


; -------------------------------------------------------------
;   N76E003 pinout reference (for convenience):
; -------------------------------------------------------------
;                               _______
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
TIMER2_RATE EQU 100 ; 100Hz or 10ms
TIMER2_RELOAD EQU (65536-(CLK/(16*TIMER2_RATE)))

    org 0x0000
    ljmp main

    org 0x0023
    reti

    org 0x002B
    ljmp Timer2_ISR

;                     1234567890123456 <- Letter Placement
test_message:     DB '** TEMP TEST  **', 0
value_message:    DB '   Temp=        ', 0
reset_message:    DB '   reset        ', 0
done_message:    DB '    done        ', 0
abort_message:    DB 'Aborted, no input', 0

; library defintions


LCD_RS EQU P1.3
LCD_E  EQU P1.4
LCD_D4 EQU P0.0
LCD_D5 EQU P0.1
LCD_D6 EQU P0.2
LCD_D7 EQU P0.3

NEXT_SETTING         EQU P1.0 ;PIN 15 (SECOND) !!!change these pin assignments
RESET                EQU P1.3 ;PIN 12 (FIRST)
UP                   EQU P0.1 ;PIN 17 (THIRD)
DOWN                 EQU P0.2 ;PIN 18 (FOURTH)
START_STOP           EQU P0.3 ;PIN 19 (FIFTH)
SOUND_OUT            EQU P1.7 ;PIN 6
                          ;1234567890123456
stop_message:          DB 'you pressed stop', 0
soak_time_message:     DB 'Soak Time:      ', 0
soak_temp_message:     DB 'Soak Temp:      ', 0
reflow_time_message:   DB 'Reflow Time:    ', 0
reflow_temp_message:   DB 'Reflow Temp:    ', 0
state0_message:        DB 'state0', 0
state1_message:        DB 'state1', 0
state2_message:        DB 'state2', 0
state3_message:        DB 'state3', 0
state4_message:        DB 'state4', 0
state5_message:        DB 'state5', 0
statewait_message:     DB 'Press start', 0
statewait_message2:    DB 'or select inputs', 0
state1st_message:      DB 'state first', 0
state2nd_message:      DB 'state second', 0
state3rd_message:      DB 'state third', 0
state4th_message:      DB 'state fourth', 0
blank_message:         DB '                ', 0

PWM_out EQU P1.2 ;PWM output to send pulses to the oven

$NOLIST
; Include your 4-bit LCD library here:
$INCLUDE (LCD_4bit.inc)
$LIST

DSEG AT 30H
x:   DS 4
y:   DS 4
bcd: DS 5       ; To hold the BCD result after hex2bcd
pwm_counter: ds 1
pwm: ds 1
seconds: ds 1

state: ds 1
soak_temp: ds 2
soak_time: ds 1
reflow_temp: ds 2
reflow_time: ds 1
sec:       ds 1
setting_state: ds 1
temp: ds 4


BSEG
mf:  DBIT 1
s_flag: dbit 1
;'ADC_to_PB' below
PB0: dbit 1
PB1: dbit 1
PB2: dbit 1
PB3: dbit 1
PB4: dbit 1
PBW1: dbit 1
PBW2: dbit 1
PBW3: dbit 1

make_sound: dbit 1

;ORG 0x0000
;ljmp main
; 1234567890123456 <- This helps determine the location of the counter
cseg
title: db 'LCD PUSH BUTTONS', 0
blank: db ' ', 0

$NOLIST
$INCLUDE (math32.inc)
;$include (fsm.asm)
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
    orl CKCON, #0x10 ; CLK is the input for timer 1
    orl PCON, #0x80 ; Bit SMOD=1, double baud rate
    mov SCON, #0x52
    anl T3CON, #0b11011111
    anl TMOD, #0x0F ; Clear the configuration bits for timer 1
    orl TMOD, #0x20 ; Timer 1 Mode 2
    mov TH1, #TIMER1_RELOAD
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

Send_BCD mac
	push ar0
	mov r0, #0
	lcall ?Send_BCD
	
	pop ar0
endmac


?Send_BCD:
	push acc
	; Write most significant digit
	mov a, r0
	swap a
	anl a, #0fh
	orl a, #30h
	lcall putchar
	; write least significant digit
	mov a, r0
	anl a, #0fh
	orl a, #30h
	lcall putchar
	pop acc
ret
   
Serial_formatted_BCD:

	;hundreds place
    mov a,bcd+3
    anl a,#0x0f
    add a, #0x30
    lcall putchar
   
    ;tens place
    mov a,bcd+2
    anl a,#0xf0
    swap a
    add a, #0x30
    lcall putchar
   
	;ones place
    mov a,bcd+2
    anl a,#0x0f
    add a, #0x30
    lcall putchar
   
    ;decimal point
    mov a,#'.'
    lcall putchar
   
    ;tenths place
    mov a,bcd+1
    swap a
    anl a,#0x0f
    add a, #0x30
    lcall putchar
   
    ;hundredths place
    mov a, bcd+1
    anl a,#0x0f
    add a,#0x30
    lcall putchar
   
    ;thousandths place
    mov a, bcd+0
    swap a
    anl a ,#0x0f
    add a ,#0x30
    lcall putchar
   
    ;ten thousandths place
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
    mov P3M1, #0x00
    mov P3M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P0M1, #0x00
    mov P0M2, #0x00
   
    orl CKCON, #0x10 ; CLK is the input for timer 1
    orl PCON, #0x80 ; Bit SMOD=1, double baud rate
    mov SCON, #0x52
    anl T3CON, #0b11011111
    anl TMOD, #0x0F ; Clear the configuration bits for timer 1
    orl TMOD, #0x20 ; Timer 1 Mode 2
    mov TH1, #TIMER1_RELOAD ; TH1=TIMER1_RELOAD;
    setb TR1
   
    ; Using timer 0 for delay functions.  Initialize here:
    clr TR0 ; Stop timer 0
    orl CKCON,#0x08 ; CLK is the input for timer 0
    anl TMOD,#0xF0 ; Clear the configuration bits for timer 0
    orl TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer
   
    ; Initialize the pin used by the ADC (P1.1) as input.
    orl P1M1, #0b00000010
    anl P1M2, #0b11111101
    anl ADCCON1, #0b11111101
   
    ; Initialize the pin used by the ADC (P0.4) as input.
    orl P0M2, #0b00010000
    anl P0M2, #0b11101111

    ; Initialize and start the ADC:
    anl ADCCON0, #0xF0
    ;orl ADCCON0, #0x07 ; Select channel 7
    orl ADCCON0, #0x05 ; Select channel 5 WIP
    ; AINDIDS select if some pins are analog inputs or digital I/O:
    anl AINDIDS, #0b11011111 ; Disable all analog inputs
    ;orl AINDIDS, #0b10000000 ; P1.1 is analog input
    orl AINDIDS, #0b00100000 ; 
    orl ADCCON1, #0x01 ; Enable ADC

    ;timer 2 initialization for pwm
    mov P3M1, #0x00
    mov P3M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P0M1, #0x00
    mov P0M2, #0x00
    ; Initialize timer 2 for periodic interrupts
    mov T2CON, #0 ; Stop timer/counter. Autoreload mode.
    mov TH2, #high(TIMER2_RELOAD)
    mov TL2, #low(TIMER2_RELOAD)
    ; Set the reload value
    mov T2MOD, #0b1010_0000 ; Enable timer 2 autoreload, and clock divider is 16
    mov RCMP2H, #high(TIMER2_RELOAD)
    mov RCMP2L, #low(TIMER2_RELOAD)
    ; Init the free running 10 ms counter to zero
    mov pwm_counter, #0
    ; Enable the timer and interrupts
    orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2 ; Enable timer 2
    setb EA ; Enable global interrupts

    ; Configure all the pins for biderectional I/O
    mov P3M1, #0x00
    mov P3M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P0M1, #0x00
    mov P0M2, #0x00
    orl CKCON, #0x10 ; CLK is the input for timer 1
    orl PCON, #0x80 ; Bit SMOD=1, double baud rate
    mov SCON, #0x52
    anl T3CON, #0b11011111
    anl TMOD, #0x0F ; Clear the configuration bits for timer 1
    orl TMOD, #0x20 ; Timer 1 Mode 2
    mov TH1, #TIMER1_RELOAD ; TH1=TIMER1_RELOAD;
    setb TR1
    ; Using timer 0 for delay functions. Initialize here:
    clr TR0 ; Stop timer 0
    orl CKCON,#0x08 ; CLK is the input for timer 0
    anl TMOD,#0xF0 ; Clear the configuration bits for timer 0
    orl TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer

    mov setting_state, #0
    mov state, #0
    mov soak_temp, #150    ;
    mov soak_time, #80     ;
    mov reflow_temp, #230  ;
    mov reflow_time, #55   ;
    clr PBW1
    clr PBW2
    clr PBW3


    clr make_sound
    ret
   
wait_1ms:
    clr TR0 ; Stop timer 0
    clr TF0 ; Clear overflow flag
    mov TH0, #high(TIMER0_RELOAD_1MS)
    mov TL0,#low(TIMER0_RELOAD_1MS)
    setb TR0
    jnb TF0, $ ; Wait for overflow
    ret

Timer2_ISR:
    clr TR2
    push psw
    push acc
    inc pwm_counter
    clr c
    mov a, pwm
    subb a, pwm_counter ; If pwm_counter <= pwm then c=1
    cpl c
    mov PWM_OUT, c
    mov a, pwm_counter
    cjne a, #100, Timer2_ISR_done
    mov pwm_counter, #0
    inc seconds ; It is super easy to keep a seconds count here
    setb s_flag

Timer2_ISR_done:
    pop acc
    pop psw
    reti

; Wait the number of miliseconds in R2
; Edited to preserve R2 register
waitms:
	push AR2
    lcall wait_1ms
    djnz R2, waitms
	pop AR2
    ret

; We can display a number any way we want.  In this case with four decimal places.
Display_formatted_BCD_one:
    Display_BCD(bcd+1)
    Display_BCD(bcd+0)
    ret
Display_formatted_BCD:
    Set_Cursor(1, 6)
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
    Display_BCD(bcd+2)
    Display_char(#'.')
    Display_BCD(bcd+1)
    Display_BCD(bcd+0)
    ;Set_Cursor(2, 10)
    ;Display_char(#'=')
    ret

ADC_to_PB:
    ; AIN0 is connected to P1.7.  Configure P1.7 as input.
	orl	P1M1, #0b10000000
	anl	P1M2, #0b01111111
	
	; AINDIDS select if some pins are analog inputs or digital I/O:
	mov AINDIDS, #0x00 ; Disable all analog inputs
	orl AINDIDS, #0b00000010 ; Using AIN0
	orl ADCCON1, #0x01 ; Enable ADC

	anl ADCCON0, #0xF0
	orl ADCCON0, #0x01 ; Select AIN0
	
	clr ADCF
	setb ADCS   ; ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete

	setb PB4
	setb PB3
	setb PB2
	setb PB1
	setb PB0

	; Check PB4
ADC_to_PB_L4:
	clr c
	mov a, ADCRH
	subb a, #0x90
	jc ADC_to_PB_L3
	clr PB4
	ret

	; Check PB3
ADC_to_PB_L3:
	clr c
	mov a, ADCRH
	subb a, #0x70
	jc ADC_to_PB_L2
	clr PB3
	ret

	; Check PB2
ADC_to_PB_L2:
	clr c
	mov a, ADCRH
	subb a, #0x50
	jc ADC_to_PB_L1
	clr PB2
	ret

	; Check PB1
ADC_to_PB_L1:
	clr c
	mov a, ADCRH
	subb a, #0x30
	jc ADC_to_PB_L0
	clr PB1
	ret

	; Check PB0
ADC_to_PB_L0:
	clr c
	mov a, ADCRH
	subb a, #0x10
	jc ADC_to_PB_Done
	clr PB0
	ret
	
ADC_to_PB_Done:
	; No pusbutton pressed	
	ret

Display_PushButtons_LCD:
    Set_Cursor(2, 1)
    mov a, #'0'
    mov c, PB4
    addc a, #0
    lcall ?WriteData
    mov a, #'0'
    mov c, PB3
    addc a, #0
    lcall ?WriteData
    mov a, #'0'
    mov c, PB2
    addc a, #0
    lcall ?WriteData
    mov a, #'0'
    mov c, PB1
    addc a, #0
    lcall ?WriteData
    mov a, #'0'
    mov c, PB0
    addc a, #0
    lcall ?WriteData
    ret

;Timer0_ISR:
 ;   jnb make_sound, no_sound  ; If make_sound is 0, skip toggling the speaker
;    clr TR0
;    mov TH0, #high(TIMER0_RELOAD_1MS)
;    mov TL0, #low(TIMER0_RELOAD_1MS)
;    setb TR0
;    cpl SOUND_OUT  ; Toggle the speaker output (P1.7)
;no_sound:
;    reti

main:
    mov soak_temp+0, #0x00
    mov soak_temp+1, #0x02
	;Initialize Stack Pointer
    mov sp, #0x7f

	;Call Initialization Function
    lcall Init_All
   
    ;Initialize Serial Port and LCD
    lcall InitSerialPort
    lcall LCD_4BIT

    ;FIX WIP
    ;Send initial messages in LCD
    ;Set_Cursor(1, 1)
    ;Send_Constant_String(#test_message)
    ;Set_Cursor(2, 1)
    ;Send_Constant_String(#value_message)
    mov sp, #0x7f
    ; initial messages in LCD
    ;Set_Cursor(1, 1)
    ;Send_Constant_String(#Title)
    ;Set_Cursor(2, 1)
    ;Send_Constant_String(#blank)
    
Forever:
    ; Set ADC to read channel 7 (Temperature Sensor Chip)
    anl ADCCON1, #0b11111101
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x07 ; Select channel 7
    ; AINDIDS select if some pins are analog inputs or digital I/O:
    mov AINDIDS, #0x00 ; Ensure only the necessary bits change
    orl AINDIDS, #0b10000000 ; Set correct analog input
    orl ADCCON1, #0x01 ; Enable ADC

    clr ADCF ; Clears the Analog Digital Converter (ADC) Flag
    setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
    ; Read the ADC result and store in [R1, R0]
    ;Set_Cursor(2, 1);
    ;Display_char(#'A')
    
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
    mov x+0, R0
    mov x+1, R1
    mov x+2, #0
    mov x+3, #0

    ;TODO: Calibrate Temperature Sensor
    Load_y(50300)
    lcall mul32

    Load_y(4096)
    lcall div32

    mov y+0, #low(27300)
    mov y+1, #high(27300)
    mov y+2, #0
    mov y+3, #0
    lcall sub32
   
    Load_y(100)
    lcall mul32
    ; Read the ADC
    ;Set_Cursor(2, 2);
    ;Display_char(#'B')
    mov R0, x+0
    mov R1, x+1
    mov R5, x+2
    mov R6, x+3

    push AR0
    push AR1
    push AR5
    push AR6
    
    ;Change ADC Settings to read from thermocouple wire
    anl ADCCON1, #0b11111101
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x05 ; Select channel 5 WIP
    ; AINDIDS select if some pins are analog inputs or digital I/O:
    mov AINDIDS, #0x00 ; Ensure only the necessary bits change
    orl AINDIDS, #0b00100000 ; Set correct analog input

    clr ADCF ; Clears the Analog Digital Converter (ADC) Flag
    setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
    ;;;; anl ADCCON1, #0xFE (from chat)
    
    ; Read the thermocouple wire temperature

    mov a, ADCRH  
    swap a
    push acc
    anl a, #0x0f
    mov R4, a 
    pop acc
    anl a, #0xf0
    orl a, ADCRL
    mov R3, A 

    ;convert to ray 12 bit for voltage
    mov x+0, R3 
    mov x+1, R4 
    mov x+2, #0
    mov x+3, #0
    
    Load_y(1000)
    lcall mul32

    load_y(100)
    lcall div32

    load_y(17647)
    lcall mul32

    load_y(41)
    lcall div32

    pop AR6
    pop AR5
    pop AR1
    pop AR0

    mov y+0, R0
    mov y+1, R1
    mov y+2, R5
    mov y+3, R6
    clr c
    lcall add32

    mov temp+0, x+0
    mov temp+1, x+1
    mov temp+2, x+2
    mov temp+3, x+3

    ; lcall hex2bcd
    ; lcall Display_formatted_BCD
    ; lcall Serial_formatted_BCD

    MOV A, BCD + 2 
	ANL A, #0xF0
	SWAP A 
	ADD A, #'0'
	LCALL PUTCHAR
	
	MOV A, BCD + 2
	ANL A, #0x0F 
	ADD A, # '0'
	LCALL PUTCHAR 
	
	MOV A, #'.'
	LCALL PUTCHAR
	
	MOV A, BCD + 1
	ANL A, #0xF0
	SWAP A
	ADD A, #0x30
	LCALL PUTCHAR
	
	MOV A, BCD + 1
	ANL A, #0x0F
	ADD A, #0x30
	LCALL PUTCHAR
	
	MOV A, BCD + 0
	ANL A, #0xF0
	SWAP A
	ADD A, #0x30
	LCALL PUTCHAR
	
	MOV A, BCD + 0
	ANL A, #0x0F
	ADD A, #0x30
	LCALL PUTCHAR
	
	MOV A, #'\r'
	LCALL PUTCHAR
	MOV A, #'\n'
	LCALL PUTCHAR
   
    ;/cpl P1.7
    ;lcall Display_PushButtons_LCD
    ; Wait 50 ms between readings
    ;mov R2, #50
    ;lcall waitms

    ;lcall find_state
    ;lcall Display_PushButtons_LCD
    ;lcall find_state
    mov x+0, temp+0
    mov x+1, temp+1
    mov x+2, temp+2
    mov x+3, temp+3
    lcall hex2bcd
    lcall Display_formatted_BCD
    ljmp FSM1

    ljmp forever

FSM1:
    mov a, state
;power = 0, if button pressed go to state 1
state0:
    clr make_sound
    cjne a, #0, state1
    Set_Cursor(2, 1)  ;set later
    Send_Constant_String(#state0_message)
	lcall ADC_to_PB
    mov pwm, #0
    ;jb PB6, state0_done
    ;jnb PB6, $ ; Wait for key release
    mov c, PB3 ;should be start_stop
    jnc state0_done
    mov setting_state, #5
    mov state, #1
state0_done:
    ljmp Forever
   
;power = 100, sec = 0
state1:
    cjne a, #1, state2
    mov setting_state, #5
    Set_Cursor(2, 1)  ;set later
    Send_Constant_String(#state1_message)
    ;cjne a, #0, state_stop
    mov pwm, #100
    mov sec, #0

    load_y(20000)

    mov x+0, temp+1
    mov x+1, temp+2
    mov x+2, temp+3
    mov x+3, temp+4

    clr mf
    lcall x_gt_y
    mov c, mf
    jnc state1_done
    mov state, #2
state1_done:
    ljmp Forever

;power = 20, check time = soak time
state2:
    cjne a, #2, state3
    Set_Cursor(2, 1)  ;set later
    Send_Constant_String(#state2_message)
    mov pwm, #20
    mov a, soak_time
    clr c
    subb a, sec
    jnc state2_done
    mov state, #3
state2_done:
    setb make_sound
    ljmp Forever
   
;power = 100, sec = 0  
state3:
    cjne a, #3, state4
    clr make_sound
    Set_Cursor(2, 1)  ;set later
    Send_Constant_String(#state3_message)
    mov pwm, #100
    mov sec, #0
    mov a, reflow_temp+1
    clr c
    subb a, temp+2
    jc state3_done
    mov a, reflow_temp+0
    subb a, temp+1
    jnc state3_done
    mov state, #4
   
state3_done:
    ljmp Forever

state_stop: ;check if stop button is pressed, and display the word 'STOPPED' on lcd display
    mov pwm, #0 ;power to 0
    Set_Cursor(1, 1)  ;set later
    Send_Constant_String(#stop_message)
    mov state, #0
    ;go where?
    ljmp Forever ;or FSM2

;sec <= reflow, power = 20
state4:
    cjne a, #4, state5
    Set_Cursor(2, 1)  ;set later
    Send_Constant_String(#state4_message)
    mov pwm, #20
    mov a, reflow_time
    clr c
    subb a, sec
    jnc state4_done
    mov state, #5

state4_done:
    setb make_sound
    ljmp Forever
;power = 0, temp >= 60
state5:
    clr make_sound
    Set_Cursor(2, 1)  ;set later
    Send_Constant_String(#state5_message)
    cjne a, #5, $+5
    sjmp $+7
    mov state, #0
    ljmp state0
    mov pwm, #0
    mov a, #60
    clr c
    subb a, temp+0
    jnc state5_done
    mov state, #0
    Set_Cursor(1, 1)  ;set later
    Send_Constant_String(#done_message)

    
state5_done:
    setb make_sound
    mov setting_state, #0
    mov state, #0
    ljmp Forever ;or FSM2?

find_state:
    mov x+0, state
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    ; Check if Wait
    load_y(0)
    clr mf
    lcall x_eq_y
    mov c, mf
    jnc $+5
    ljmp wait_state
    ; Check if soak time
    load_y(1)
    clr mf
    lcall x_eq_y
    mov c, mf
    jnc $+5
    ljmp soak_time_state
    ; Check if soak temp
    load_y(2)
    clr mf
    lcall x_eq_y
    mov c, mf
    jnc $+5
    ljmp soak_temp_state
    ; Check if reflow time
    load_y(3)
    clr mf
    lcall x_eq_y
    mov c, mf
    jnc $+5
    ljmp reflow_time_state
    ; Check if reflow temp
    load_y(4)
    clr mf
    lcall x_eq_y
    mov c, mf
    jnc $+5
    ljmp reflow_temp_state
    set_cursor(1,1)
    display_char(#'!')
    ret

change_state:
    mov c, PBW1
    jc skip_change_state
    lcall ADC_to_PB
    mov c, PB1
    cpl c
    jnc $+3
    setb PBW1
    mov a, state
    addc a, #0
    mov state, a
    ret
skip_change_state:
    lcall ADC_to_PB
    mov c, PB1
    cpl c
    mov PBW1, c
    ret
change_state_last:
    mov c, PBW1
    jc skip_change_state_last
    lcall ADC_to_PB
    mov c, PB1
    cpl c
    jnc $+6
    setb PBW1
    mov state, #0
    ret
skip_change_state_last:
    lcall ADC_to_PB
    mov c, PB1
    cpl c
    mov PBW1, c
    ret

wait_state:
    set_cursor(1,1)
    send_constant_string(#statewait_message)
    set_cursor(2,1)
    send_constant_string(#statewait_message2)

    lcall change_state
    ret
soak_time_state:
    set_cursor(1,1)
    send_constant_string(#soak_time_message)
    mov x+0, soak_time
    lcall hex2bcd
    set_cursor(2,1)
    lcall Display_formatted_BCD_one
    mov c, PBW3
    jc skip_move_soak_up
    lcall ADC_to_PB
    mov c, PB3
    jc skip_move_soak_up
    ; check
    mov x+0, soak_time
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
	Load_y(120)
	clr mf
	lcall x_lt_y
	mov c, mf ;not sure if mf has to go into a reg
    mov a, soak_time
	ADDC a, #0
    mov soak_time, a
skip_move_soak_up:
    lcall ADC_to_PB
    mov c, PB3
    cpl c
    mov PBW3, c

    ; PB2 Up
    ; PB3 Down
    lcall change_state
    ret
soak_temp_state:
    set_cursor(1,1)
    send_constant_string(#soak_temp_message)
    lcall change_state
    ret
reflow_time_state:
    set_cursor(1,1)
    send_constant_string(#reflow_time_message)
    lcall change_state
    ret
reflow_temp_state:
    set_cursor(1,1)
    send_constant_string(#reflow_temp_message)
    lcall change_state_last
    ret



END