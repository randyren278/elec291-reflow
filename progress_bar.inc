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
    WriteData(#11100B)
    WriteData(#11110B)
    WriteData(#11110B)
    WriteData(#11110B)

    ; Create custom character 50%
    WriteCommand(#0x50)
    WriteData(#11000B)
    WriteData(#11100B)
    WriteData(#11000B)
    WriteData(#11100B)
    WriteData(#11000B)
    WriteData(#11100B)
    WriteData(#11000B)
    WriteData(#11100B)

    ; Create custom character 25%
    WriteCommand(#0x58)
    WriteData(#10000B)
    WriteData(#10000B)
    WriteData(#10000B)
    WriteData(#11000B)
    WriteData(#10000B)
    WriteData(#10000B)
    WriteData(#10000B)
    WriteData(#11000B)
ret
print_progress_bar:
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
    ljmp print_progress_bar
end_print_progress_bar:
ret

; CURRENT HEAT IN X, TARGET HEAT IN Y, CHANGES BOTH
heating_progress MAC
push psw
push acc
push_x
push_y
load_y(100)
lcall mul32
pop_y
lcall div32
set_cursor(2, 1)
mov a, x+0

; Loop to print out progressbar
lcall print_progress_bar

set_cursor(2, 11)
pop_x
lcall hex2bcd
display_bcd(bcd+3)
display_bcd(bcd+2)
display_char('o')
display_char('C')
set_cursor(2, 10)
display_char(' ')

pop acc
pop psw
ENDMAC
;Comment bc CrossIDE loves erroring if the last line is empty