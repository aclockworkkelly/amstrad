; Firmware for the Amstrac CPC
SETMODE     EQU     #BC0E            ;A=00,01,02; Sets the screen mode
KEYWAIT     EQU     #BB06            ;Wait for a key press
SCREENWAIT  EQU     #BD19            ;Wait for a screen refresh
TEXTOUTPUT  EQU     #BB5A            ;Output a text string

; Memory addresses of screen
SCREEN      EQU     #C000             ;Start of Screen memeory location
CLMOFFSET   EQU     #50               ;Offset to start of screen
ROWOFFSET   EQU     #800              ;Offset to next row of pixels

; Hardware addresses and ports
GATEARRAY   EQU     #7F00             ;Port for controlling the gate array

; Keyboard matrix address limits
KEYSTART    EQU     #40                   ;Start of keyboard matrix
KEYEND      EQU     #4a                   ;End of keyboard matrix; 

; Character values
CR          EQU     #0D               ;Carriage return
LEFT        EQU     #08               ;Left arrow
RIGHT       EQU     #09               ;Right arrow
DOWN        EQU     #0A               ;Down arrow
UP          EQU     #0B               ;Up arrow
DEL         EQU     #7F               ;Delete
ESC         EQU     #1B               ;Escape (no effect in this program)

;Screen starts at #C000 and ends at #FFFF.  In Mode 1 each row is 80 bytes
;and eight pixels across uses two bytes.

    ORG     #8000
        LD      A,#01             ;Set
        CALL    SETMODE           ;Mode 1
MAINLOOP:
        CALL    SCREENWAIT         ;Wait for screen refresh
        CALL    ONEKEY
        CP      #FF         ; If no key were pressed A would be #FF
        JR      Z,MAINLOOP
                            ; If we get here, a key was pressed, A has code and C has line number
                            ; Faster than decoding the keymap, just compare A,C with the key codes
                            ; A+C for 'W','A','S','D'
                            ; 'A' : %11100111 = #E7  (A=%11011111, C=#08)
                            ; 'D' : %00100111 = #E6  (A=%11011111, C=#07)
                            ; 'S' : %11110110 = #F6  (A=%11101111, C=#07)
                            ; 'W' : %11111110 = #FE  (A=%11110111, C=#07)
        LD      HL,(SPRITEPOSITION) ;Save HL with current Screen address
        ADD     A,C
        CP      A,#FE
        JR      Z,GO_UP
        CP      A,#E7
        JR      Z,GO_LEFT
        CP      A,#F6
        JR      Z,GO_DOWN
        CP      A,#E6
        JR      Z,GO_RIGHT
        JR      MAINLOOP

GO_UP:  
        LD A,H ; Check if we are below #C800, if so subtracting #800 will be too great and we need to wrap
        CP #C8
        JR      C,CORRECTION_UP ; If Carry==0 Jump, i.e. if A < #C8

        LD      BC,-ROWOFFSET
        ADD     HL,BC           ; Move up by one row
        JR      MAINDRAW  
GO_LEFT:
        DEC     HL
        LD A,H                  ; If H has become less than #C0 then we are at the top of the screen
        CP #C0
        JR      NC,MAINDRAW     ; If Carry!=0 Jump, i.e. if A >= #C0
        JR      CORRECTION
GO_DOWN:
        ; LD A,H                  ; If H has become less than #C0 then we are at the top of the screen
        ; CP #FF
        ; JR  NC,CORRECTION_DOWN          ; If Carry!=0 Jump, i.e. if A >= #FF
        LD      BC,ROWOFFSET
        ADD     HL,BC           ;Move down by one row
        JR      NC,MAINDRAW     ;If Carry then passed #FFFF, so wrap around to start
                                    ; the following two lines are if we at the bottom of the screen
        JR      CORRECTION
GO_RIGHT:
        INC     HL
        JR      NC,MAINDRAW     ;If Carry then passed #FFFF, so wrap around to start
                                    ; the following two lines are if we at the bottom of the screen
        ;JR      CORRECTION     ***FALL THROUGH**

CORRECTION:
        LD      BC,SCREEN+CLMOFFSET          ;Start address plus column offset
        ADD     HL,BC             ;Update screen location to correction plus offset
        JR  MAINDRAW

CORRECTION_DOWN:
        ; LD      A,L
        ; CP      #80
        ; JR      NC,MAINDRAW     ; If Carry!=0 Jump, i.e. if A >= #80
        LD      BC,#3F80
        OR      A ; clear the carry as SBC is HL <- HL - BC - carry 
        SBC     HL,BC
        JR      MAINDRAW

CORRECTION_UP:
        LD      BC,#37B0       ;Start address plus column offset
        ADD     HL,BC             ;Update screen location to correction plus offset
        ; JR  MAINDRAW          ***FALL THROUGH**

MAINDRAW:  
        ; At this point HL already containes the new player position
        LD      DE,SPRITE         ;Save DE with start of Sprite (Pixels) address
        LD      BC,#0208          ;B=2 bytes wide (8 pixles) and C=8 pixels down
        CALL    MOVESPRITE
        JR      MAINLOOP          ;Loop back to wait for next key press

;Draw the 8x8 Pixels.  Each new row of pixels is #800 bytes in memory down!  If passed the
;end of the screen, set row to the top of the screen plus column offset.  Uses XOR on
;the current screen,  This will preserve the background if the sprite moves by just
;re drawing the pixel on the screen again at the same location.  Clever
; USAGE:   
;       LD      HL,SCREENSTARTLOCATION
;       LD      DE,SPRITE
;       LD      BC,WIDTHBYTES_high-HEIGHTLINES_low ; e.g #0208
;       CALL    PLOT   ; corrupts HL, DE, BC, A    
PLOT:                
        PUSH    BC                ;Save Registers
DO_ROW:              
        LD      A,(DE)            ;Load A with 4 pixels data
        ;XOR     (HL) ;XOR with the current byte on the screen
        LD      (HL),A            ;Update screen with new (XOR) value
        INC     HL                ;Move 4 pixels to the right (one byte)
        INC     DE                ;Get next 4 pixels of data
        DJNZ    DO_ROW            ;Repeat the pixle display (do twice as B=2)   (decrement B, if B is non zero: Jump relative)
        DEC HL 
        DEC HL                    ; 2 from HL instead of push and pop to Restore left most pixel location
        LD      BC,ROWOFFSET          ;Load BC with next ROW down (#800 bytes!)
        ADD     HL,BC             ;Move screen address down one pixle ROW
        JR      NC,NO_COR         ;If Carry then passed #FFFF, so wrap around to start
        ; the following two lines are if we at the bottom of the screen
        LD      BC,SCREEN+CLMOFFSET          ;Start address plus column offset
        ADD     HL,BC             ;Update screen location to correction plus offset
NO_COR:      
        POP     BC                ;Restore pixel row count (8 pixels)
        DEC     C                 ;Decrease pixel row
        JR      NZ,PLOT           ;Move to next pixel row until 0
        RET                       ; return

; Move sprite to new location
; USAGE:
;       SPRITEPOSITION contains the current screen location
;       LD      HL,NEWLOCATION
;       LD      DE,SPRITE    ; Assumes SHADOW directly follows SPRITE
;       LD      BC,WIDTHBYTES_high-HEIGHTLINES_low ; e.g #0208
;
;       CALL    MOVESPRITE   ; corrupts HL, DE, BC, A
MOVESPRITE:
        PUSH    HL                ;Save Registers
        PUSH    DE                ;Save Registers
        PUSH    BC                ;Save Registers
        PUSH    BC                 ; push BC twice so we can recover after we have used it to calculate the sprite size
        LD      HL,(SPRITEPOSITION) ;Save HL with current Screen address
        XOR     A
CALC_SPRITE_SIZE:             ; After this A will contain the sprites size in bytes
        ADD     A,C
        DJNZ    CALC_SPRITE_SIZE
        POP     BC                  ; Recover BC after sprite size calculation
        ADD     A,E    ; A = A+E                ADD A to DE (unsigned addition)
        LD      E,A    ; E = A+E                    .
        ADC     A,D    ; A = A+E+D+carry            .
        SUB     E      ; A = D+carry                .
        LD      D,A    ; D = D+carry                .
        CALL    PLOT
        POP     BC
        POP     DE
        POP     HL
        LD      (SPRITEPOSITION),HL ; Store new player postion, before calling PLOT again
        CALL    PLOT
        RET

;Key input on the CPC goes through the 8255 PPI and AY soundchip, we need to use the PPI to talk to the AY, and tell it to read input through reg 14
; USAGE:
;       CALL    KEYSCAN   ; corrupts HL, BC, DE, A and populates KEYMAP 
KEYSCAN:
        XOR     A                   ;A=0
        LD      HL,KEYMAP           ;Load the destination memory of the map of key status bits
        LD      BC,#f782            ;Select PPI port direction... A out /C out   
        DI
        OUT     (C),C               ;Out port direction

        LD      BC,#f40e            ;Select Ay reg 14 on ppi port A  (KEYBOARD read through sound chip)
        LD      E,B                 ; e=#f4 
        OUT     (C),C               ;Out to AY
        LD      BC,#f6c0            ;This value is an AY index (R14)
        LD      D,B                 ; d=#f6
        OUT     (C),C
        OUT     (C),C               ;F600 - set to inactive (needed)
        LD      BC,#f792            ;Set PPI port direction A in/C out 
        OUT     (C),C
        LD      A,KEYSTART          ;First line is at &40, last is at &4A
        LD      C,KEYEND   
KEYSCANLOOP:    
        LD      B,D                 ; b=#f6 
        OUT     (C),A
        LD      B,E                 ; b=#f4
        INI                         ; read bits and write into KEYMAP {(HL)<-(C), B<-B-1, HL<-HL+1}
        INC     A   
        CP      C                   ;Have we got to the end?
        JR      C,KEYSCANLOOP              ; If Carry=1 Jump
        LD      BC,#f782            ;Reset PPI port direction - PPI port A out / C out 
        OUT     (C),C
        EI
        RET


;   This routine scans for a pressed key to and returns the key code in A (of the first one found) C is the key index (A = #FF if none found).
; USAGE:
;       CALL    ONEKEY   ; corrupts HL, BC, DE, A and populates KEYMAP 
ONEKEY:
	    CALL    KEYSCAN

        LD      BC,#0a00 ; B=10 and C=0
	    LD      HL,KEYMAP ; reset HL as the loop in KEYSCAN has moved it to the end of KEYMAP
WAITKEYCHECKINTERNAL:
	    LD      A,(HL) ;Load first chaacter from KEYMAP to A
	    CP      #ff ; If no key pressed, the value is #FF for all 10 bytes in KEYMAP
	    RET     NZ ; If we found the first isnt #FF, Return with the key code in A
	
        INC     HL ; Move to the next address in KEYMAP
	    INC     C ; Increment the key index
	    DJNZ    WAITKEYCHECKINTERNAL ;   (decrement B, if B is non zero: Jump relative) Bstarts as size of KEYMAP
	    RET     ; If we get here, no key was pressed, so return with A=#FF


; This routine will wait until a Key has been pressed, Key pressed in A, C is the key index KEYMAP populated
; USAGE:
;       CALL    WAITKEY   ; corrupts HL, BC, DE, A and populates KEYMAP 
WAITKEY:
	    CALL    ONEKEY
	    CP      #ff
	    JR      Z,WAITKEY
	    RET


;Sprite Data is two bytes across (8 pixles) and 8 pixels down. Each byte contain information for
;four pixels,  The four bits used are a combination of the High and low nibble
;Four Pixels are coded as:
; 
; Nibble |     HIGH      |      LOW      |
; Bits   | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;--------|---|---|---|---|---|---|---|---|

; In default pallette mode (1) the following colours are used:
; Colour | Blue | Yellow | Cyan | RED |
;         L0 H0   L0 H1    L1 H0  L1 H1

; Group B3B7,B2B6,B1B5,B0B4  as the four pixels in a mode 1 byte by colour

; So four consecutive pixels as blue yellow cyan red would be:
; 01010011 = #53

;This sprite uses only one colour (Yellow) will look like the following:
;   8x8         Byte 1   Byte 2      B1  B2
; OOOOOOOO     00000000 00000000    #00 #00
; OYYYYYYO     01110000 11100000    #70 #E0
; OYYYYYYO     01110000 11100000    #70 #E0
; OYYYYYYO     01110000 11100000    #70 #E0
; OYYYYYYO     01110000 11100000    #70 #E0
; OYYYYYYO     01110000 11100000    #70 #E0
; OYYYYYYO     01110000 11100000    #70 #E0
; OOOOOOOO     00000000 00000000    #00 #00
; 
; KEY: O=NO COLOUR, Y=YELLOW
;SPRITE:     DB      %01010011,%11110000,#53,#F0,#53,#F0,#53,#F0,#53,#F0,#53,#F0,#53,#F0,#53,#F0 ;Cell
SPRITEPOSITION:
        DW     SCREEN
SPRITE:     
        DB      #30,#c0, #70,#e0, #f2,#f4, #f0,#f0, #f0,#f0, #d2,#b4, #61,#68, #30,#c0 ;smiley
SHADOW:     
        DB      #00,00, #00,#00, #00,#00, #00,#00, #00,#00, #00,#00, #00,#00, #00,#00 ;smiley


; Convert what is in A and C from KEYSCAN to a printable character in A
; USAGE:
;       LD      A,<KEYMAP_byte>
;       LD      C,<ROW>
;       CALL    KEYASCII    ; corrupts A, HL, BC
KEYASCII:
        BIT    7,A
        JR     Z,KEYASCII_7
        BIT    6,A
        JR     Z,KEYASCII_6
        BIT    5,A
        JR     Z,KEYASCII_5
        BIT    4,A
        JR     Z,KEYASCII_4
        BIT    3,A
        JR     Z,KEYASCII_3
        BIT    2,A
        JR     Z,KEYASCII_2
        BIT    1,A
        JR     Z,KEYASCII_1
        BIT    0,A
        JR     Z,KEYASCII_0

        LD      A,ESC   ; if no bits are set just return A=#1b (ESC)
        RET                     
        
       ; Do something for fall off end
ADD_A_AND_C_MULTIPLIED_BY_8_INTO_HL:
        SLA    C
        SLA    C
        SLA    C
        ADD    A,C
        LD     B,#00
        LD     C,A
        LD     HL,KEYBOARDMATRIX
        ADD    HL,BC
        LD     A,(HL)
        RET

KEYASCII_7:
        LD     A,0
        JR     ADD_A_AND_C_MULTIPLIED_BY_8_INTO_HL
KEYASCII_6:
        LD     A,1
        JR     ADD_A_AND_C_MULTIPLIED_BY_8_INTO_HL
KEYASCII_5:
        LD     A,2
        JR     ADD_A_AND_C_MULTIPLIED_BY_8_INTO_HL
KEYASCII_4:
        LD     A,3
        JR     ADD_A_AND_C_MULTIPLIED_BY_8_INTO_HL
KEYASCII_3:
        LD     A,4
        JR     ADD_A_AND_C_MULTIPLIED_BY_8_INTO_HL
KEYASCII_2:
        LD     A,5
        JR     ADD_A_AND_C_MULTIPLIED_BY_8_INTO_HL
KEYASCII_1:
        LD     A,6
        JR     ADD_A_AND_C_MULTIPLIED_BY_8_INTO_HL
KEYASCII_0:
        LD     A,7
        JR     ADD_A_AND_C_MULTIPLIED_BY_8_INTO_HL



;KEYBOARD MATRIX
;Bit:
;Line	7	    6	        5	        4	        3	        2	        1	        0
;
;&40	FDot	ENTER	    F3	        F6	        F9	        CURDOWN	    CURRIGHT	CURUP
;&41	F0	    F2	        F1	        F5	        F8	        F7	        COPY	    CURLEFT
;&42	CONTROL	\	        SHIFT	    F4	        ]	        RETURN	    [	        CLR
;&43	.	    /	        :	        ;	        P	        @	        -	        ^
;&44	,	    M	        K	        L	        I	        O	        9	        0
;&45	SPACE	N	        J	        H	        Y	        U	        7	        8
;&46	V	    B	        F	        G(J2fire)	T(J2right)	R(J2left)	5(J2down)	6(J2up)
;&47	X	    C	        D	        S	        W	        E	        3	        4
;&48	Z	    CAPSLOCK	A	        TAB	        Q	        ESC	        2	        1
;&49	DEL	    Joy1Fire3	Joy1Fire2	Joy1Fire1	Joy1right	Joy1left	Joy1down	Joy1up
KEYBOARDMATRIX:
        DB      0,0,0,0,0,DOWN,RIGHT,UP
        DB       0,0,0,0,0,0,0,LEFT
        DB      0,"\",0,0,"]",CR,"[",0
        DB      ".","/",":",";","P","@","-","^"
        DB      ",","M","K","L","I","O","9","0"
        DB      " ","N","J","H","Y","U","7","8"
        DB      "V","B","F","G","T","R","5","6"
        DB      "X","C","D","S","W","E","3","4"
        DB      "Z",0,"A",0,"Q",0,"2","1"
        DB       DEL,0,0,0,0,0,0,0

KEYMAP:
        DS      10  ;map with 10*8 = 80 key status bits (bit=0 key is pressed)
