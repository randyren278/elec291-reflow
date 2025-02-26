;Great file that always works

cseg
oven_state_init:
    ;initialize vars, start at lowest?
    mov pwm, #0x00 ;0x00??
	mov oven_state, #0x00 ;60 does this need to be like #60??????
	;mov soak_temp, #0x96 ;150 decimal
    ;mov soak_time
	;mov reflow_time, #0x2D ;45
	;mov reflow_temp, #0xD9 ;217
    ret
    
abort_state:
	mov pwm, #0
	Set_Cursor(1, 1)
	Send_Constant_String(#oven_abort_message1)
	Set_Cursor(2, 1)
	Send_Constant_String(#oven_abort_message2)
	ljmp finished_state
    
;oven fsm  
FSM_Init:
    mov seconds, #0
    setb oven_flag 
    ; TODO - Reset oven_flag when we leave oven FSM
;power = 0, if button pressed go to state 1

;-------------------------------------
; Ramp to Soak State - DONT YOU DARE TOUCH ANYTHING, EVERYTHING WORKS OTHER THAN LOADING SOAK_TEMP INTO X
;-------------------------------------
mov seconds, #0
Set_Cursor(1, 1)
Send_Constant_String(#oven_fsm_message_0)
Set_Cursor(2, 1)
Send_Constant_String(#blank)
lcall init_characters
ramp_to_soak:
    ; Displays a message
    lcall temp_into_x
    ;mov y+0, soak_temp
    ;mov y+1, #0
    ;mov y+2, #0
    ;mov y+3, #0
    ;heating_progress
    lcall hex2bcd
    Set_Cursor(2, 1)
    display_Bcd(bcd+4)
    display_Bcd(bcd+3)
    display_Bcd(bcd+2)
    display_Bcd(bcd+1)
    display_Bcd(bcd+0)
	;lcall rst_check
    ; Do state duties
    mov pwm, #100
    ;checking for temp < 30 for 60 secs then abort
    mov ye+0, #0x1E ;30
    mov y+1, #0
    mov y+2, #0
    mov y+3, #0
    mov y+4, #0
    Load_x(10000)
    lcall mul32
    push_y
    lcall temp_into_x
    pop_y
    clr mf
    lcall x_lteq_y
    ;2+3+2+1(perhaps 2)+2
    jnb mf, $+10 ;please i dont know if i added enough or too much (should go to mov x+0, soak_temp)
    mov a, #60 ;is this right :(
    subb a, seconds
    ;if sec > then abort
    jnc $+4
    sjmp $+5
    ljmp abort_state
    
    ; Move to next state if condition is met
    mov x+0, soak_temp
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    mov x+4, #0
  	
  	Load_y(10000)
    lcall mul32
    push_x
    lcall temp_into_y
    pop_x
    clr mf
    lcall x_lteq_y
    
    jb mf, $+6
    ljmp ramp_to_soak
;-------------------------------------
; Soak_state
;-------------------------------------
mov seconds, #0
Set_Cursor(1, 1)
Send_Constant_String(#oven_fsm_message_1)
Set_Cursor(2, 1)
Send_Constant_String(#blank)
soak_state:
    ; Displays a message
    ; Does state duties
    mov x+0, seconds
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    lcall hex2bcd
    Set_Cursor(2, 1)
    display_Bcd(bcd+4)
    display_Bcd(bcd+3)
    display_Bcd(bcd+2)
    display_Bcd(bcd+1)
    display_Bcd(bcd+0)

    mov pwm, #20
    ; Transitions to next state
    clr c
    ;mov a, #60
    mov a, soak_time
    subb a, seconds
    jnc $+4
    sjmp $+5
    ljmp soak_state
;-------------------------------------
; Ramp to peak
;-------------------------------------
mov seconds, #0
Set_Cursor(1, 1)
Send_Constant_String(#oven_fsm_message_2)
Set_Cursor(2, 1)
Send_Constant_String(#blank)
ramp_to_peak:
    ; Displays a message
    
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
    mov pwm, #100
    ; Move to next state if condition is met
    mov x+0, reflow_temp
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    mov x+4, #0
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
Set_Cursor(1, 1)
Send_Constant_String(#oven_fsm_message_3)
Set_Cursor(2, 1)
Send_Constant_String(#blank)
reflow_state:
    ; Displays a message
    ; Does state duties
    mov x+0, seconds
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    lcall hex2bcd
    Set_Cursor(2, 1)
    display_Bcd(bcd+4)
    display_Bcd(bcd+3)
    display_Bcd(bcd+2)
    display_Bcd(bcd+1)
    display_Bcd(bcd+0)

    mov pwm, #20
    ; Transitions to next state
    clr c
    ;mov a, #45
    mov a, reflow_time
    subb a, seconds
    jnc $+4
    sjmp $+5
    ljmp reflow_state
;-------------------------------------
; Cool down
;-------------------------------------
; Displays a message
mov seconds, #0
mov pwm, #0
Set_Cursor(1, 1)
Send_Constant_String(#oven_fsm_message_4)
Set_Cursor(2, 1)
Send_Constant_String(#blank)
cooldown_state:
    
    lcall temp_into_x
    lcall hex2bcd
    Set_Cursor(2, 1)
    display_Bcd(bcd+4)
    display_Bcd(bcd+3)
    display_Bcd(bcd+2)
    display_Bcd(bcd+1)
    display_Bcd(bcd+0)
	;lcall rst_check
    ; Do state duties
    
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
Set_Cursor(1, 1)
Send_Constant_String(#done_message)
Set_Cursor(2, 1)
Send_Constant_String(#blank)
finished_state:
    MOV R2, #255
    lcall waitms
    lcall waitms
    ;