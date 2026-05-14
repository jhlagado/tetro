; SOUND_START
; Input:
;   A = duration in scan ticks
;   C = divider reload / half-period
; Output:
;   speaker state machine restarted
; Clobbers:
;   A
SOUND_START:
        LD      (SOUND_TIMER),A
        XOR     A
        LD      (SPEAKER_PORT_STATE),A
        RET

; SERVICE_SOUND
; Input:
;   SOUND_TIMER
; Output:
;   speaker remains silent in this first Pacmo scrolling experiment
; Clobbers:
;   A
SERVICE_SOUND:
        LD      A,(SOUND_TIMER)
        OR      A
        RET     Z
        DEC     A
        LD      (SOUND_TIMER),A
        RET

; SCAN_SCORE_DIGIT
; Input:
;   HUD_SEG_BUFFER / HUD_SCAN_INDEX / SPEAKER_PORT_STATE
; Output:
;   one seven-segment digit refreshed
; Clobbers:
;   A, BC, DE, HL
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
        LD      DE,DIGIT_MASK_TABLE
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
BLANK_HUD_SCORE_DIGITS:
        LD      HL,HUD_SEG_BUFFER
        LD      B,6
        XOR     A
BLANK_HUD_SCORE_DIGITS_LOOP:
        LD      (HL),A
        INC     HL
        DJNZ    BLANK_HUD_SCORE_DIGITS_LOOP
        RET

; UPDATE_SCORE_DISPLAY
; Input:
;   PACMO_SCORE, PACMO_LEVEL
; Output:
;   HUD_SEG_BUFFER updated with one level digit and five decimal score digits
; Clobbers:
;   A, BC, DE, HL
UPDATE_SCORE_DISPLAY:
        LD      A,(PACMO_LEVEL)
        AND     0x0F
        LD      L,A
        LD      H,0
        LD      DE,PACMO_HEX_SEG_TABLE
        ADD     HL,DE
        LD      A,(HL)
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
