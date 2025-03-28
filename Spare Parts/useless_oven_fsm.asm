;just a rough little draft

cseg
oven_state_init:
    ;initialize vars, start at lowest?
    mov pwm_power, #0x00 ;0x00??
    mov pwm_period_counter, #0
    mov period , #0
    mov oven_status, #0
	mov oven_state, #0x00 ;60 does this need to be like #60??????

	;mov soak_temp, #0x96 ;150 decimal
    ;mov soak_time
	;mov reflow_time, #0x2D ;45
	;mov reflow_temp, #0xD9 ;217
    ret
;oven fsm  
FSM_Init:
    mov seconds, #0
    setb oven_flag ; TODO - Reset oven_flag when we leave oven FSM
;power = 0, if button pressed go to state 1

;-------------------------------------
; Ramp to Soak State - DONT YOU DARE TOUCH ANYTHING, EVERYTHING WORKS OTHER THAN LOADING SOAK_TEMP INTO X
;-------------------------------------
ramp_to_soak:
    ; Displays a message
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_0)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    
    lcall temp_into_x
    lcall hex2bcd
    Send_Constant_String(#blank)
    Set_Cursor(2, 1)
    display_Bcd(bcd+4)
    display_Bcd(bcd+3)
    display_Bcd(bcd+2)
    display_Bcd(bcd+1)
    display_Bcd(bcd+0)
	;lcall rst_check
    ; Do state duties
    mov pwm_power, #10
    ; Move to next state if condition is met
    mov x+0, #150
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    Load_y(10000)
    lcall mul32
    push x+0
    push x+1
    push x+2
    push x+3
    lcall temp_into_y
    pop x+3
    pop x+2
    pop x+1
    pop x+0
    clr mf
    lcall x_lteq_y
    
    jb mf, $+6
    ljmp ramp_to_soak
;-------------------------------------
; Soak_state
;-------------------------------------
mov seconds, #0
soak_state:
    ; Displays a message
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_1)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    ; Does state duties
    mov pwm_power, #2
    ; Transitions to next state
    clr c
    mov a, #60
    subb a, seconds
    jnc soak_state
;-------------------------------------
; Ramp to peak
;-------------------------------------
mov seconds, #0
ramp_to_peak:
    ; Displays a message
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_2)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    
    lcall temp_into_x
    lcall hex2bcd
    Send_Constant_String(#blank)
    Set_Cursor(2, 1)
    display_Bcd(bcd+4)
    display_Bcd(bcd+3)
    display_Bcd(bcd+2)
    display_Bcd(bcd+1)
    display_Bcd(bcd+0)
	;lcall rst_check
    ; Do state duties
    mov pwm_power, #10
    ; Move to next state if condition is met
    mov x+0, #220
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    Load_y(10000)
    lcall mul32
    push x+0
    push x+1
    push x+2
    push x+3
    lcall temp_into_y
    pop x+3
    pop x+2
    pop x+1
    pop x+0
    clr mf
    lcall x_lteq_y
    
    jb mf, $+6
    ljmp ramp_to_peak
;-------------------------------------
; Reflow
;-------------------------------------
mov seconds, #0
reflow_state:
    ; Displays a message
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_3)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    ; Does state duties
    mov pwm_power, #2
    ; Transitions to next state
    clr c
    mov a, #45
    subb a, seconds
    jnc reflow_state
;-------------------------------------
; Cool down
;-------------------------------------
; Displays a message
mov seconds, #0
cooldown_state:
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_4)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    
    lcall temp_into_x
    lcall hex2bcd
    Send_Constant_String(#blank)
    Set_Cursor(2, 1)
    display_Bcd(bcd+4)
    display_Bcd(bcd+3)
    display_Bcd(bcd+2)
    display_Bcd(bcd+1)
    display_Bcd(bcd+0)
	;lcall rst_check
    ; Do state duties
    mov pwm_power, #0 ; idk if this is needed
    
    ; Move to next state if condition is met
    mov x+0, #60
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    Load_y(10000)
    lcall mul32
    push x+0
    push x+1
    push x+2
    push x+3
    lcall temp_into_y
    pop x+3
    pop x+2
    pop x+1
    pop x+0
    clr mf
    lcall x_gteq_y
    
    jb mf, $+6
    ljmp cooldown_state
;-------------------------------------
; Finished - Returns to main when next is pressed
;-------------------------------------
mov seconds, #0
finished_state:
    Set_Cursor(1, 1)
    Send_Constant_String(#done_message)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    MOV R2, #255
    lcall waitms
    lcall waitms
    ;