
cseg
oven_state_init:
    ; Initialize variables
    mov pwm_power_factor+0, #0
    mov pwm_power_factor+1, #0
    mov oven_state, #0x00         ; Start in state 0 (idle)
    mov soak_temp,  #150          ; Soak temperature: 150°C
    mov soak_time,  #60           ; Soak duration: 60 secondsonds
    mov reflow_temp, #217         ; Reflow temperature: 217°C
    mov reflow_time, #45          ; Reflow duration: 45 secondsonds
    ret

; Finite State Machine (FSM) for oven control
FSM1:
    mov a, oven_state

; State 0: Idle (0% power, wait for start)
state0:
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_0)  ; Display "Idle"
    Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    lcall rst_check
    cjne a, #0, state1
    mov pwm_power_factor+0, #0
    mov pwm_power_factor+1, #0
    lcall ADC_to_PB
    mov c, S_S
    jc state0
    mov oven_state, #1

; State 1: Ramp to soak temp (100% power)
state1:
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_1)  ; "Heating to Soak"
    Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    lcall rst_check
    cjne a, #1, state2
    mov pwm_power_factor+0, #low(1000)
    mov pwm_power_factor+1, #high(1000)
    mov seconds, #0
    mov a, soak_temp
    clr c
    subb a, temp
    jnc state1
    mov oven_state, #2

; State 2: Soak phase (20% power for 60 secondsonds)
state2:
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_2)  ; "Soak Phase"
    Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    lcall rst_check
    mov pwm_power_factor+0, #low(200)
    mov pwm_power_factor+1, #high(200)
    ; Check soak time
    mov a, soak_time
    clr c
    subb a, seconds
    jnc state2
    ; Time elapsed: play sound & transition
    cpl SOUND_OUT       ; Beep
    clr SOUND_OUT
    mov oven_state, #3

; State 3: Ramp to reflow temp (100% power)
state3:
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_3)  ; "Heating to Reflow"
    Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    lcall rst_check
    cjne a, #3, state4
    mov pwm_power_factor+0, #low(1000)
    mov pwm_power_factor+1, #high(1000)
    mov seconds, #0
    mov a, reflow_temp
    clr c
    subb a, temp
    jnc state3
    mov oven_state, #4

; State 4: Reflow phase (20% power for 45 secondsonds)
state4:
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_4)  ; "Reflow Phase"
    Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    lcall rst_check
    mov pwm_power_factor+0, #low(200)
    mov pwm_power_factor+1, #high(200)
    ; Check reflow time
    mov a, reflow_time
    clr c
    subb a, seconds
    jnc state4
    ; Time elapsed: play sound & transition
    cpl SOUND_OUT       ; Beep
    clr SOUND_OUT
    mov oven_state, #5

; State 5: Cooldown (0% power until temp <= 60°C)
state5:
    Set_Cursor(1, 1)
    Send_Constant_String(#oven_fsm_message_5)  ; "Cooldown"
    Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    lcall rst_check
    mov pwm_power_factor+0, #0
    mov pwm_power_factor+1, #0
    mov a, temp
    clr c
    subb a, #60
    jc state5_done
    ljmp state5

state5_done:
    ; Cooldown complete: play sound
    cpl SOUND_OUT       ; Beep
    clr SOUND_OUT
    Set_Cursor(1, 1)
    Send_Constant_String(#done_message)  ; "Done"
    mov oven_state, #0
    ljmp forever

; Emergency stop with sound
state_stop:
    mov pwm_power_factor+0, #0
    mov pwm_power_factor+1, #0
    cpl SOUND_OUT       ; Alert beep
    clr SOUND_OUT
    Set_Cursor(1, 1)
    Send_Constant_String(#stop_message)  ; "STOPPED"
    ljmp forever

    