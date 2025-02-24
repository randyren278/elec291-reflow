cseg
init_characters:
    ; Create custom character 100%
    mov A, #0x40 ; Memory location for first byte of custom character 0
    lcall WriteCommand
    mov A, #11111B
    lcall WriteData
    mov A, #11111B
    lcall WriteData
    mov A, #11111B
    lcall WriteData
    mov A, #11111B
    lcall WriteData
    mov A, #11111B
    lcall WriteData
    mov A, #11111B
    lcall WriteData
    mov A, #11111B
    lcall WriteData
    mov A, #11111B
    lcall WriteData

    ; Create custom character 75%
    mov A, #0x40 ; Memory location for first byte of custom character 0
    lcall WriteCommand
    mov A, #11100B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11100B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData

    ; Create custom character 50%
    mov A, #0x40 ; Memory location for first byte of custom character 0
    lcall WriteCommand
    mov A, #11000B
    lcall WriteData
    mov A, #11100B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
    mov A, #11100B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
    mov A, #11100B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
    mov A, #11100B
    lcall WriteData

    ; Create custom character 25%
    mov A, #0x40 ; Memory location for first byte of custom character 0
    lcall WriteCommand
    mov A, #10000B
    lcall WriteData
    mov A, #10000B
    lcall WriteData
    mov A, #10000B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
    mov A, #10000B
    lcall WriteData
    mov A, #10000B
    lcall WriteData
    mov A, #10000B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
ret
print_progress_bar:
    cjne a, #0, progress_bar_low
    ljmp end_print_progress_bar

progress_bar_low:
    cjne a, #1, progress_bar_med
    mov a, #1
    lcall WriteData
    ljmp end_print_progress_bar

progress_bar_med:
    cjne a, #2, progress_bar_high
    mov a, #2
    lcall WriteData
    ljmp end_print_progress_bar

progress_bar_high:
    cjne a, #3, progress_bar_full
    mov a, #3
    lcall WriteData
    ljmp end_print_progress_bar

progress_bar_full:
    push acc
    mov a, #4
    lcall WriteData
    pop acc
    clr c
    subb a, #4
    ljmp print_progress_bar
end_print_progress_bar:
ret

heating_progress MAC
push psw
push acc
push_x
push_y
mov x+0, #low(%0)
mov x+1, #high(%0)
mov x+2, #0
mov x+3, #0
push_x
load_y(100)
lcall mul32
mov y+0, #low(%1)
mov y+1, #high(%1)
mov y+2, #0
mov y+3, #0
lcall div32
set_cursor(%2, 1)
mov a, x+0

; Loop to print out progressbar
lcall print_progress_bar

set_cursor(%2, 11)
pop_x
lcall hex2bcd
display_bcd(bcd+3)
display_bcd(bcd+2)
display_char('°')
display_char('C')
set_cursor(%2, 10)
display_char(' ')

pop_y
pop_x
pop acc
pop psw
ENDMAC
;Comment bc CrossIDE loves erroring if the last line is empty