;just a rough little draft

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
;oven fsm  
FSM1:
    mov a, oven_state
;power = 0, if button pressed go to state 1
state0:
    lcall rst_check
    cjne a, #0, state1
    mov pwm, #0
    lcall ADC_to_PB
    mov c, S_S
    jc state0
    mov oven_state, #1
state0_done:
    ljmp forever
   
   ; state 0 looks good
;power = 100, sec = 0
state1:
	lcall rst_check
    cjne a, #1, state2
    mov pwm, #100
    mov sec, #0
    mov a, soak_temp
    clr c
    subb a, temp
    jnc state1_done
    mov oven_state, #2
state1_done:
    ljmp forever

;power = 20, check time = soak time
state2:
	lcall rst_check
    cjne a, #2, state3
    mov pwm, #20
    mov a, soak_time
    clr c
    subb a, sec
    jnc state2_done
    mov oven_state, #3
state2_done:
    cpl SOUND_OUT
    clr SOUND_OUT
    ljmp forever
   
;power = 100, sec = 0  
state3:
	lcall rst_check
    cjne a, #3, state4
    mov pwm, #100
    mov sec, #0
    mov a, reflow_temp
    clr c
    subb a, temp
    jnc state3_done
    mov oven_state, #4
   
state3_done:
    ljmp forever

;sec <= reflow, power = 20
state4:
	lcall rst_check
    cjne a, #4, state5
    mov pwm, #20
    mov a, reflow_time
    clr c
    subb a, sec
    jnc state4_done
    mov oven_state, #5

state4_done:
    cpl SOUND_OUT ; speaker
    clr SOUND_OUT ;
    ljmp forever
;power = 0, temp >= 60
state5:
	lcall rst_check
    mov a,#5
    cjne a, #5, state0_epic
    mov pwm, #0
    mov a, temp
    clr c
    subb a, #60
    jnc state5_transition
state5_transition:
    Set_Cursor(1, 1)  ;set later
    Send_Constant_String(#done_message)
    mov oven_state, #0
    ljmp forever
state5_done:
    cpl SOUND_OUT ; connect speaker to
    ljmp forever
state0_epic:
ljmp state0

state_stop: ;check if stop button is pressed, and display the word 'STOPPED' on lcd display
    mov pwm, #0 ;power to 0
    Set_Cursor(1, 1)  ;set later
    Send_Constant_String(#stop_message)
    ;go where?
    ljmp forever
    ;
