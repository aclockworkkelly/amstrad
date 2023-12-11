printchar equ &BDD3
screenstart equ &C000

org &8000
jr printmessage
jp drawgrid

printmessage:
    ld hl, message
    call newline
    jp printer ; let its ret return us to basic

newline:
    ld a, 13
    call printchar ; prints what is a 
    ld a, 10
    jp printchar ; Its ret will exit newline


; takes address of whats to be printed in hl
printer: 
    ld a, (hl)
    cp 0
    ret z
    call printchar ; prints what is a 
    jr printer

message:
db "hello world!", 0

; ------------------------------------
drawgrid:
ld a, &FF
