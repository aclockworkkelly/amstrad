;Print All printable ASCII characters to the Screen
;
;To Use, load in memeory and CALL 40000
            ORG    #8000    

SETMODE     EQU     #BC0E   ;A=00,01,02; Sets the screen mode
PRINT       EQU     #BB5A   ;A=ASCII character to print to screen at current cursor location
COUNT       EQU     223     ;223 Printable characters (255-32)
START       EQU     32      ;Start Charcacter (SPACE)

            LD      A,#01   ;Mode 1
            CALL    SETMODE ;Clear screen

            LD      B,COUNT ;Load B with Counter
            LD      C,START ;Load C with first character
LOOP:                
            ;Print all characters to the screen sequentially using firmware Print Char call
            LD      A,C     ;Load A with current character
            CALL    PRINT   ;Print Character to screen   
            INC     C       ;Next character
            DJNZ    LOOP    ;Do until all characters are printed
            RET             ;Exit to Basic
