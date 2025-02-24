cseg
init_characters:
    ; Create custom character 20%
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

    ; Create custom character 40%
    mov A, #0x40 ; Memory location for first byte of custom character 0
    lcall WriteCommand
    mov A, #11000B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
    mov A, #11000B
    lcall WriteData
    mov A, #11000B
    lcall WriteData

    ; Create custom character 60%
    mov A, #0x40 ; Memory location for first byte of custom character 0
    lcall WriteCommand
    mov A, #11100B
    lcall WriteData
    mov A, #11100B
    lcall WriteData
    mov A, #11100B
    lcall WriteData
    mov A, #11100B
    lcall WriteData
    mov A, #11100B
    lcall WriteData
    mov A, #11100B
    lcall WriteData
    mov A, #11100B
    lcall WriteData
    mov A, #11100B
    lcall WriteData

    ; Create custom character 80%
    mov A, #0x40 ; Memory location for first byte of custom character 0
    lcall WriteCommand
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData
    mov A, #11110B
    lcall WriteData

heating_progress MAC
push acc
push_x
push_y
mov x+0, #low(%0)
mov x+1, #high(%0)
mov x+2, #0
mov x+3, #0
load_y(100)
lcall mul32
mov y+0, #low(%1)
mov y+1, #high(%1)
mov y+2, #0
mov y+3, #0
lcall div32
; Loop to print out progressbar
set_cursor(%2, %3)
mov a, x+0


pop_y
pop_x
pop acc
ENDMAC
;Comment bc CrossIDE loves erroring if the last line is empty