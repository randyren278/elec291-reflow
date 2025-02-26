cseg
init_characters:
    ; Create custom character 100%
    WriteCommand(#0x40)
    WriteData(#11111B)
    WriteData(#11111B)
    WriteData(#11111B)
    WriteData(#11111B)
    WriteData(#11111B)
    WriteData(#11111B)
    WriteData(#11111B)
    WriteData(#11111B)

    ; Create custom character 75%
    WriteCommand(#0x48)
    WriteData(#11100B)
    WriteData(#11110B)
    WriteData(#11110B)
    WriteData(#11110B)
    WriteData(#11110B)
    WriteData(#11110B)
    WriteData(#11110B)
    WriteData(#11100B)

    ; Create custom character 50%
    WriteCommand(#0x50)
    WriteData(#11000B)
    WriteData(#11000B)
    WriteData(#11100B)
    WriteData(#11100B)
    WriteData(#11100B)
    WriteData(#11100B)
    WriteData(#11000B)
    WriteData(#11000B)

    ; Create custom character 25%
    WriteCommand(#0x58)
    WriteData(#10000B)
    WriteData(#10000B)
    WriteData(#10000B)
    WriteData(#11000B)
    WriteData(#11000B)
    WriteData(#10000B)
    WriteData(#10000B)
    WriteData(#10000B)

ret
print_progress_bar:
Set_Cursor(2, 1)
print_progress_bar_loop:
    cjne a, #0, progress_bar_low
    ljmp end_print_progress_bar

progress_bar_low:
    cjne a, #1, progress_bar_med
    WriteData(#3)
    ljmp end_print_progress_bar

progress_bar_med:
    cjne a, #2, progress_bar_high
    WriteData(#2)
    ljmp end_print_progress_bar

progress_bar_high:
    cjne a, #3, progress_bar_full
    WriteData(#1)
    ljmp end_print_progress_bar

progress_bar_full:
    push acc
    WriteData(#0)
    pop acc
    clr c
    subb a, #4
    jc end_print_progress_bar
    ljmp print_progress_bar_loop
end_print_progress_bar:
ret

; CURRENT HEAT IN X, TARGET HEAT IN Y, CHANGES BOTH
heating_progress MAC
push psw
push acc
push_x
push_y
load_y(40)
lcall mul32
pop_y
lcall div32
Set_Cursor(2, 1)
Send_Constant_String(#blank)
; Loop to print out progressbar
mov a, x+0
lcall print_progress_bar

set_cursor(2, 11)
pop_x
lcall hex2bcd
display_bcd(bcd+3)
display_bcd(bcd+2)
display_char(#'o')
display_char(#'C')

pop acc
pop psw
ENDMAC
;Comment bc CrossIDE loves erroring if the last line is empty

; CURRENT TIME IN X, TARGET TIME IN Y, CHANGES BOTH
time_progress MAC
push psw
push acc
push_y
push_x
push_y
load_y(40)
lcall mul32
pop_y
lcall div32
Set_Cursor(2, 1)
Send_Constant_String(#blank)
; Loop to print out progressbar
mov a, x+0
lcall print_progress_bar

pop_y
pop_x
lcall sub32 ;Get remaining time
push_x ;1
load_y(60)
lcall div32 ;x now contains quotient (minutes)
load_y(60)
lcall mul32 ;x now contains minutes left * 60
push_x ;2
pop_y ;y now contains minutes left * 60 (2)
pop_x ;x now contains remaining time (1)
lcall sub32
push_x ;remaining seconds (1)
push_y ; minutes left * 60 (2)
pop_x ;minutes left * 60 (2)
load_y(60)
lcall div32
load_y(100)
lcall mul32 ; x = minutes left * 100
pop_y ;remaining seconds
lcall add32
lcall hex2bcd
set_cursor(2, 12)
display_bcd(bcd+1)
display_char(#':')
display_bcd(bcd+0)
mov R2, #20
lcall waitms
pop acc
pop psw
ENDMAC

; TARGET TEMP IN X, CURRENT TEMP IN Y, CHANGES BOTH
cool_progress MAC
push psw
push acc
push_y
push_y
load_y(40)
lcall mul32
pop_y
lcall div32
Set_Cursor(2, 1)
Send_Constant_String(#blank)
; Loop to print out progressbar
mov a, x+0
lcall print_progress_bar

set_cursor(2, 11)
pop_x
lcall hex2bcd
display_bcd(bcd+3)
display_bcd(bcd+2)
display_char(#'o')
display_char(#'C')

pop acc
pop psw
ENDMAC
;Comment bc CrossIDE loves erroring if the last line is empty