cseg
state_init:
    ;initialize vars, start at lowest?
    mov selecting_state, #0 ;0x00??
	mov soak_time, #0x3C ;60 does this need to be like #60??????
	mov soak_temp, #0x96 ;150 decimal
	mov reflow_time, #0x2D ;45
	mov reflow_temp, #0xD9 ;217
    ret

reset_state:
	Set_Cursor(1, 1)
    Send_Constant_String(#reset_state_message)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
	mov R2, #250
    lcall state_init
	lcall waitms
	ljmp forever  
;
;                     1234567890123456    <- This helps determine the location of the counter