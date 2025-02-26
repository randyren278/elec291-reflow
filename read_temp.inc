;
cseg
Temp_Init_All:
    ; Configure all the pins for biderectional I/O
    mov P3M1, #0x00
    mov P3M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P0M1, #0x00
    mov P0M2, #0x00
   
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
    ret
temp_into_x:
    push_y
    ; Set ADC to read channel 7 (Temperature Sensor Chip)
    anl ADCCON1, #0b11111101
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x07 ; Select channel 7
    ; AINDIDS select if some pins are analog inputs or digital I/O:
    mov AINDIDS, #0x00 ; Ensure only the necessary bits change
    orl AINDIDS, #0b10000000 ; Set correct analog input
    
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
    Load_y(1420)
    lcall mul32

    Load_y(3200000)
    lcall sub32

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
    
    Load_y(100000)
    lcall mul32

    load_y(111)
    lcall div32

    pop AR6
    pop AR5
    pop AR1
    pop AR0

    mov y+0, R0
    mov y+1, R1
    mov y+2, R5
    mov y+3, R6
    lcall add32
    pop_y
    ret
temp_into_y:
    push_x
    lcall temp_into_x
    mov y+0, x+0
    mov y+1, x+1
    mov y+2, x+2
    mov y+3, x+3
    pop_x
    ret
    ;
