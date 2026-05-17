; Generic seven-segment HUD scan helpers.

; SCAN_SCORE_DIGIT
; Input:
;   HUD_SEG_BUFFER / HUD_SCAN_INDEX / SPEAKER_PORT_STATE
; Output:
;   one seven-segment digit refreshed
; Clobbers:
;   A, BC, DE, HL
; Uses @clobbers A,BC,DE,HL,F while refreshing one HUD digit.
; Keeps @preserves IX,IY stable for the caller.
SCAN_SCORE_DIGIT:
        LD      A,(HUD_SCAN_INDEX)
        LD      C,A
        LD      A,(SPEAKER_PORT_STATE)
        OUT     (PORT_DIGITS),A
        LD      A,C
        LD      L,A
        LD      H,0
        LD      DE,HUD_SEG_BUFFER
        ADD     HL,DE
        LD      A,(HL)
        OUT     (PORT_SEGS),A

        LD      A,C
        LD      L,A
        LD      H,0
        LD      DE,HUD_DIGIT_MASK_TABLE
        ADD     HL,DE
        LD      A,(HL)
        LD      B,A
        LD      A,(SPEAKER_PORT_STATE)
        OR      B
        OUT     (PORT_DIGITS),A

        LD      A,C
        INC     A
        CP      6
        JR      C,SCAN_SCORE_DIGIT_SAVE
        XOR     A
SCAN_SCORE_DIGIT_SAVE:
        LD      (HUD_SCAN_INDEX),A
        RET

; BLANK_HUD_SCORE_DIGITS
; Input:
;   none
; Output:
;   HUD_SEG_BUFFER[0..5] = 0
; Clobbers:
;   A, B, HL
; Uses @clobbers A,B,HL,F while clearing the HUD digit buffer.
; Keeps @preserves C,DE,IX,IY stable for the caller.
BLANK_HUD_SCORE_DIGITS:
        LD      HL,HUD_SEG_BUFFER
        LD      B,6
        XOR     A
BLANK_HUD_SCORE_DIGITS_LOOP:
        LD      (HL),A
        INC     HL
        DJNZ    BLANK_HUD_SCORE_DIGITS_LOOP
        RET

; HUD_WRITE_U16_DECIMAL
; Input:
;   HL = unsigned 16-bit value
; Output:
;   HUD_SEG_BUFFER[0] = zero glyph
;   HUD_SEG_BUFFER[1..5] = decimal digits for 10000,1000,100,10,1
; Clobbers:
;   A, BC, DE, HL
; Accepts @in HL as the unsigned value.
; Uses @clobbers A,BC,DE,HL,F while formatting the decimal display.
; Keeps @preserves IX,IY stable for the caller.
HUD_WRITE_U16_DECIMAL:
        LD      A,(HUD_SEG_GLYPH_TABLE)
        LD      (HUD_SEG_BUFFER),A
        LD      BC,HUD_SEG_BUFFER+1

        LD      DE,0x2710      ; 10000
        CALL    HUD_WRITE_DECIMAL_DIGIT
        LD      DE,0x03E8      ; 1000
        CALL    HUD_WRITE_DECIMAL_DIGIT
        LD      DE,0x0064      ; 100
        CALL    HUD_WRITE_DECIMAL_DIGIT
        LD      DE,0x000A      ; 10
        CALL    HUD_WRITE_DECIMAL_DIGIT
        LD      DE,0x0001      ; 1
        CALL    HUD_WRITE_DECIMAL_DIGIT
        RET

; HUD_WRITE_DECIMAL_DIGIT
; Accepts @in HL as the value remainder.
; Accepts @in DE as the decimal divisor.
; Accepts @in BC as destination digit in HUD_SEG_BUFFER.
; Returns @out HL as the updated value remainder.
; Returns @out BC advanced to the next destination.
; Uses @clobbers A,DE,F while subtracting and formatting.
HUD_WRITE_DECIMAL_DIGIT:
        XOR     A
HUD_WRITE_DECIMAL_DIGIT_LOOP:
        PUSH    AF
        LD      A,H
        CP      D
        JR      C,HUD_WRITE_DECIMAL_DIGIT_DONE
        JR      NZ,HUD_WRITE_DECIMAL_DIGIT_SUB
        LD      A,L
        CP      E
        JR      C,HUD_WRITE_DECIMAL_DIGIT_DONE
HUD_WRITE_DECIMAL_DIGIT_SUB:
        POP     AF
        OR      A
        SBC     HL,DE
        INC     A
        JR      HUD_WRITE_DECIMAL_DIGIT_LOOP
HUD_WRITE_DECIMAL_DIGIT_DONE:
        POP     AF
        PUSH    HL
        PUSH    BC
        LD      L,A
        LD      H,0
        LD      DE,HUD_SEG_GLYPH_TABLE
        ADD     HL,DE
        LD      A,(HL)
        POP     BC
        LD      (BC),A
        INC     BC
        POP     HL
        RET

HUD_DIGIT_MASK_TABLE:
        DB      0x20
        DB      0x10
        DB      0x08
        DB      0x04
        DB      0x02
        DB      0x01

HUD_SEG_GLYPH_TABLE:
        DB      0xEB
        DB      0x28
        DB      0xCD
        DB      0xAD
        DB      0x2E
        DB      0xA7
        DB      0xE7
        DB      0x29
        DB      0xEF
        DB      0x2F
        DB      0x6F
        DB      0xE6
        DB      0xC3
        DB      0xEC
        DB      0xC7
        DB      0x47
