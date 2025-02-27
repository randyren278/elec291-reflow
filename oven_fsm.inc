;Great file that always works

cseg
oven_state_init:
    ;initialize vars, start at lowest?
    mov soak_temp, #150 ;150 decimal
    mov soak_time, #60 ;60 decimal
	mov reflow_time, #45 ;45
	mov reflow_temp+0, #217 ;217
    mov reflow_temp+1, #0
    mov pwm, #0x00 ;0x00??
	mov oven_state, #0x00 ;60 does this need to be like #60??????
    ret
;oven fsm  
FSM_Init:
    mov seconds, #0
    setb s_s_flag
    setb oven_flag ; TODO - Reset oven_flag when we leave oven FSM
;power = 0, if button pressed go to state 1

;-------------------------------------
; Ramp to Soak State - DONT YOU DARE TOUCH ANYTHING, EVERYTHING WORKS OTHER THAN LOADING SOAK_TEMP INTO X
;-------------------------------------
Set_Cursor(1, 1)
Send_Constant_String(#oven_fsm_message_0)
Set_Cursor(2, 1)
Send_Constant_String(#blank)
lcall init_characters
ramp_to_soak:
    lcall ADC_to_PB
    mov c, S_S
    jc $+8
    jb s_s_flag, $+8
    ljmp stop_start
    clr s_s_flag
    ; Displays a message
    mov x+0, soak_temp
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    load_y(10000)
    lcall mul32
    push_x
    lcall temp_into_y
    push_y
    pop_x
    pop_y
    heating_progress
    mov R2, #255
    lcall waitms
	;lcall rst_check
    ; Do state duties

    ;checking for temp < 30 for 60 secs then abort

    mov a, #60 ;is this right :(
    subb a, seconds
    jnc dont_abort

    load_y(600000)
    lcall temp_into_x
    clr mf
    lcall x_lteq_y
    jnb mf, dont_abort
    ljmp abort_state

dont_abort:
    mov pwm, #100
    ; Move to next state if condition is met
    mov x+0, soak_temp
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
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
    lcall ADC_to_PB
    mov c, S_S
    jc $+8
    jb s_s_flag, $+8
    ljmp stop_start
    clr s_s_flag
    ; Displays a message
    mov x+0, seconds
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    mov y+0, soak_time
    mov y+1, #0
    mov y+2, #0
    mov y+3, #0
    time_progress
    ; Does state duties
    mov pwm, #20
    ; Transitions to next state
    clr c
    mov a, soak_time
    subb a, seconds
    jnc $+4
    sjmp $+5
    ljmp soak_state
    mov R2, #2
    lcall Beep_Seconds

;-------------------------------------
; Ramp to peak
;-------------------------------------
mov seconds, #0
Set_Cursor(1, 1)
Send_Constant_String(#oven_fsm_message_2)
Set_Cursor(2, 1)
Send_Constant_String(#blank)
ramp_to_peak:
    lcall ADC_to_PB
    mov c, S_S
    jc $+8
    jb s_s_flag, $+8
    ljmp stop_start
    clr s_s_flag
    ; Displays a message
    mov x+0, reflow_temp+0
    mov x+1, reflow_temp+1
    mov x+2, #0
    mov x+3, #0
    load_y(10000)
    lcall mul32
    push_x
    lcall temp_into_y
    push_y
    pop_x
    pop_y
    heating_progress
    mov R2, #255
    lcall waitms
	;lcall rst_check
    ; Do state duties
    mov pwm, #100
    ; Move to next state if condition is met
    mov x+0, reflow_temp+0
    mov x+1, reflow_temp+1
    mov x+2, #0
    mov x+3, #0
    Load_y(10000)
    lcall mul32
    push_x
    lcall temp_into_y
    pop_x
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
    lcall ADC_to_PB
    mov c, S_S
    jc $+8
    jb s_s_flag, $+8
    ljmp stop_start
    clr s_s_flag
    ; Displays a message
    mov x+0, seconds
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0
    mov y+0, reflow_time
    mov y+1, #0
    mov y+2, #0
    mov y+3, #0
    time_progress
    ; Does state duties
    mov pwm, #20
    ; Transitions to next state
    clr c
    mov a, reflow_time
    subb a, seconds
    jnc $+4
    sjmp $+5
    ljmp reflow_state
    mov R2, #2
    lcall Beep_Seconds

;-------------------------------------
; Cool down
;-------------------------------------
; Displays a message
mov seconds, #0
Set_Cursor(1, 1)
Send_Constant_String(#oven_fsm_message_4)
Set_Cursor(2, 1)
Send_Constant_String(#blank)
cooldown_state:
    
    ; Displays a message
    load_x(600000)
    lcall temp_into_y
    push_y
    push_x
    cool_progress
    mov R2, #255
    lcall waitms
    ; Do state duties
    mov pwm, #0
    ; Move to next state if condition is met
    pop_y
    pop_x
    clr mf
    lcall x_lteq_y
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

mov R2, #5
lcall Beep_Seconds


finished_state:
    MOV R2, #255
    lcall waitms
    lcall waitms
    ret
stop_start:
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_stop_message1)
    Set_Cursor(2, 1)
    Send_Constant_String(#oven_stop_message2)
    mov pwm, #0
    mov R2, #255
    lcall waitms
    ljmp cooldown_state
abort_state:
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_abort_message1)
    Set_Cursor(2, 1)
    Send_Constant_String(#oven_abort_message2)
    mov pwm, #0
    ljmp finished_state

Beep_Seconds:
    lcall Speaker_Init      
beep_loop:
    mov a, R2
    jz beep_done
    dec R2
    mov R3, #1000
    lcall waitms            
    sjmp beep_loop

beep_done:
    clr TR1               
    clr ET1
    clr SOUND_OUT
    ret
