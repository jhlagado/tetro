; Pacmo-local score formatting helpers. Seven-segment scan helpers live in
; shared/hud.asm.

; UPDATE_SCORE_DISPLAY
; Input:
;   PACMO_SCORE
; Output:
;   HUD_SEG_BUFFER updated with a six-digit decimal score display
; Clobbers:
;   A, BC, DE, HL
UPDATE_SCORE_DISPLAY:
        LD      A,(PACMO_HEX_SEG_TABLE)
        LD      (HUD_SEG_BUFFER),A
        LD      HL,(PACMO_SCORE)
        LD      BC,HUD_SEG_BUFFER+1

        LD      DE,0x2710              ; 10000
        CALL    SCORE_WRITE_DIGIT
        LD      DE,0x03E8              ; 1000
        CALL    SCORE_WRITE_DIGIT
        LD      DE,0x0064              ; 100
        CALL    SCORE_WRITE_DIGIT
        LD      DE,0x000A              ; 10
        CALL    SCORE_WRITE_DIGIT
        LD      DE,0x0001              ; 1
        CALL    SCORE_WRITE_DIGIT
        RET

; SCORE_WRITE_DIGIT
; Input:
;   HL = score remainder
;   DE = decimal divisor
;   BC = destination digit in HUD_SEG_BUFFER
; Output:
;   HL = updated score remainder
;   BC = advanced to next destination
; Clobbers:
;   A, DE
SCORE_WRITE_DIGIT:
        XOR     A
SCORE_WRITE_DIGIT_LOOP:
        PUSH    AF
        LD      A,H
        CP      D
        JR      C,SCORE_WRITE_DIGIT_DONE
        JR      NZ,SCORE_WRITE_DIGIT_SUB
        LD      A,L
        CP      E
        JR      C,SCORE_WRITE_DIGIT_DONE
SCORE_WRITE_DIGIT_SUB:
        POP     AF
        OR      A
        SBC     HL,DE
        INC     A
        JR      SCORE_WRITE_DIGIT_LOOP
SCORE_WRITE_DIGIT_DONE:
        POP     AF
        PUSH    HL
        PUSH    BC
        LD      L,A
        LD      H,0
        LD      DE,PACMO_HEX_SEG_TABLE
        ADD     HL,DE
        LD      A,(HL)
        POP     BC
        LD      (BC),A
        INC     BC
        POP     HL
        RET
