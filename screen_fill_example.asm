;Screen fill example
;-------------------
;First method uses firmware call to print an ascii character to the screen.  This is slower
;Second method plots pixels to the screen directly to screen memory. This is faster

            ORG     #8000

SETMODE     EQU     #BC0E             ;A=00,01,02; Sets the screen mode
KEYWAT      EQU     #BB06             ;Wait for a key press
CLEAR       EQU     #BB6C             ;Clear the current screen
PRINT       EQU     #BB5A             ;Print A to the screen, move cursor one to the right

SCREEN      EQU     #C000             ;Start of Screen memeory location
CR          EQU     #0D               ;Carriage Return
CELL        EQU     #E9               ;Cell ascii character

            LD      A,#01             ;Set
            CALL    SETMODE           ;Mode 1
START:               
            CALL    CLEAR             ;Clear the screen
            CALL    PRINTSLOW         ;Call Print Slow routine
            CALL    KEYWAT            ;Wait for key press
            CP      CR                ;If not CR then
            JR      NZ,START          ;Repeat Print Slow
START2:              
            CALL    CLEAR             ;Clear the screen
            CALL    PRINTFAST         ;Call Print Fast routine
            CALL    KEYWAT            ;Wait for key press
            CP      CR                ;If not CR then
            JR      NZ,START2         ;Repeat Print Fast

            RET                       ;Exit back to Basic

;Use the Firmware print command to display an ascii character to the screen.
PRINTSLOW:           
            LD      BC,1000           ;In Mode 1 there are 1000 8x8 character positions
            LD      A,CELL            ;Load A with the ascii character for a cell
SLOWLOOP:            
            PUSH    AF                ;Save Registers
            PUSH    BC 
            CALL    PRINT             ;Call Print routine from firmware
            POP     BC                ;Restore Registers
            DEC     BC                ;Reduce character count by 1
            LD      A,B 
            OR      C 
            JR      Z,SLOWEND         ;If its zero then all printed and finish routine
            POP     AF                ;Restore cell to print again
            JR      SLOWLOOP          ;print next character
SLOWEND:             
            POP     AF                ;Restore stack before exiting
            RET                       ;Exit back to main routine

;Use pixel data to display cell writing directly to the screen memory
;Screen starts at #C000 and ends at #FFFF.  In Mode 1 each row is 80 bytes
;and eight pixels across uses two bytes.
PRINTFAST:           
            LD      A,#01             ;Set
            CALL    SETMODE           ;Mode 1
AGAIN:               
            LD      HL,SCREEN         ;Save HL with start of Screen address
            LD      B,25              ;25 Rows
LOOP1:               
            PUSH    BC                ;Save Registers
            PUSH    HL 
            LD      B,40              ;40 Columns
LOOP2:               
            PUSH    BC                ;Save Registers
            PUSH    HL 
            LD      DE,SPRITE         ;Save DE with start of Sprite (Pixels) address
            LD      BC,#0208          ;B=2 bytes wide (8 pixles) and C=8 pixels down
            CALL    PLOT              ;Draw the Sprite (8x8)
            POP     HL                ;Restore starting pixel address
            INC     HL                ;Move 8 pixels to the right
            INC     HL 
            POP     BC                ;Restore Current Column count
            DJNZ    LOOP2             ;Loop until 40 columns have been printed
            POP     HL                ;Restore the left hand screen address
            LD      BC,#50            ;Load BC with next ROW down (8 pixels)
            ADD     HL,BC             ;Move screen address down one ROW
            POP     BC                ;Restore Current Row count
            DJNZ    LOOP1             ;Loop until 25 rows have been printed
            RET                       ;Exit to Basic

;Draw the 8x8 Pixels.  Each new row of pixels is #800 bytes in memory down!  If passed the
;end of the screen, set row to the top of the screen plus column offset.  Uses XOR on
;the current screen,  This will preserve the background if the sprite moves by just
;re drawing the pixel on the screen again at the same location.  Clever
PLOT:                
            PUSH    BC                ;Save Registers
            PUSH    HL 
DO_ROW:              
            LD      A,(DE)            ;Load A with 4 pixels data
;            XOR     (HL) ;XOR with the current byte on the screen
            LD      (HL),A            ;Update screen with new XOR value
            INC     HL                ;Move 4 pixels to the right (one byte)
            INC     DE                ;Get next 4 pixels of data
            DJNZ    DO_ROW            ;Repeat the pixle display (do twice as B=2)
            POP     HL                ;Restore left most pixel location
            LD      BC,&0800          ;Load BC with next ROW down (#800 bytes!)
            ADD     HL,BC             ;Move screen address down on pixle ROW
            JR      NC,NO_COR         ;If Carry then passed #FFFF, so wrap around to start
            LD      BC,#C050          ;Start address plus column offset
            ADD     HL,BC             ;Update screen location to correction plus offset
NO_COR:              
            POP     BC                ;Restore pixel row count (8 pixels)
            DEC     C                 ;Decrease pixel row
            JR      NZ,PLOT           ;Move to next pixel row until 0
            RET                       ;Exit

;Pixel Data is two bytes across (8 pixles) and 8 pixels down. Each byte contain information for
;four pixels,  The four bits used are a combination of the High and low nibble
;Four Pixels are coded as:
; 
; Nibble |     HIGH      |      LOW      |
; Bits   | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;--------|---|---|---|---|---|---|---|---|
; Data   | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 1 |
; Colour | Yellow|  Red  |  N/A  |  Blue |
; 
; A bit set in just the left hand (High) nibble of each byte defines color 1 (Yellow),
; A bit in the right hand (Low) nibble sets color 2 (Blue)
; A bit in both sides (High and Low) sets color 3 (Red)

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
SPRITE:     DB      #00,#00,#70,#E0,#70,#E0,#70,#E0,#70,#E0,#70,#E0,#70,#E0,#00,#00 ;Cell
