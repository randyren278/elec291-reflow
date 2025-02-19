
;oven fsm  
FSM1:
    mov a, state
;power = 0, if button pressed go to state 1
state0:
    cjne a, #0, state1
    mov pwm, #0
    lcall ADC_to_PB
    mov c, S_S
    jc state0
    mov state, #0x01
state0_done:
    ljmp forever
   
;power = 100, sec = 0
state1:
	lcall rst_check
    cjne a, #1, state2
    mov pwm, #100
    mov sec, #0
    mov a, temp_soak
    clr c
    subb a, temp
    jnc state1_done
    mov state, #2
state1_done:
    ljmp forever

;power = 20, check time = soak time
state2:
	lcall rst_check
    cjne a, #2, state3
    mov pwm, #20
    mov a, time_soak
    clr c
    subb a, sec
    jnc state2_done
    mov state, #3
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
    mov a, temp_reflow
    clr c
    subb a, temp
    jnc state3_done
    mov state, #4
   
state3_done:
    ljmp forever

;sec <= reflow, power = 20
state4:
	lcall rst_check
    cjne a, #4, state5
    mov pwm, #20
    mov a, time_reflow
    clr c
    subb a, sec
    jnc state4_done
    mov state, #5

state4_done:
    cpl SOUND_OUT ; speaker
    clr SOUND_OUT ;
    ljmp forever
;power = 0, temp >= 60
state5:
	lcall rst_check
    cjne a, #5, state0
    mov pwm, #0
    mov a, #60
    clr c
    subb a, temp
    jnc state5_done
    mov state, #0
    Set_Cursor(1, 1)  ;set later
    Send_Constant_String(#done_message)
state5_done:
    cpl SOUND_OUT ; connect speaker to
        ljmp forever

state_stop: ;check if stop button is pressed, and display the word 'STOPPED' on lcd display
    mov pwm, #0 ;power to 0
    Set_Cursor(1, 1)  ;set later
    Send_Constant_String(#stop_message)
    ;go where?
    ljmp forever
