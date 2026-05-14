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
        LD      A,C
        LD      (SOUND_DIVIDER_RELOAD),A
        LD      (SOUND_DIVIDER_COUNT),A
        XOR     A
        LD      (SPEAKER_PORT_STATE),A
        RET

; PACMO_SOUND_POWER
; Input:
;   none
; Output:
;   starts the Pacmo power-pill eaten sound cue
; Clobbers:
;   A, C
PACMO_SOUND_POWER:
        LD      A,PACMO_SOUND_POWER_LEN
        LD      C,PACMO_SOUND_POWER_DIV
        JP      SOUND_START

; PACMO_SOUND_EAT_ENEMY
; Input:
;   none
; Output:
;   starts the Pacmo fleeing-enemy eaten sound cue
; Clobbers:
;   A, C
PACMO_SOUND_EAT_ENEMY:
        LD      A,PACMO_SOUND_EAT_ENEMY_LEN
        LD      C,PACMO_SOUND_EAT_ENEMY_DIV
        JP      SOUND_START

; PACMO_SOUND_CAUGHT
; Input:
;   none
; Output:
;   starts the longer Pacmo caught/game-over sound cue
; Clobbers:
;   A, C
PACMO_SOUND_CAUGHT:
        LD      A,PACMO_SOUND_CAUGHT_LEN
        LD      C,PACMO_SOUND_CAUGHT_DIV
        JP      SOUND_START

; PACMO_SOUND_LEVEL_COMPLETE
; Input:
;   none
; Output:
;   starts the Pacmo level-complete sound cue
; Clobbers:
;   A, C
PACMO_SOUND_LEVEL_COMPLETE:
        LD      A,PACMO_SOUND_LEVEL_COMPLETE_LEN
        LD      C,PACMO_SOUND_LEVEL_COMPLETE_DIV
        JP      SOUND_START

; SERVICE_SOUND
; Input:
;   SOUND_TIMER
; Output:
;   SPEAKER_PORT_STATE toggled while the active Pacmo sound cue is running
; Clobbers:
;   A
SERVICE_SOUND:
        LD      A,(SOUND_TIMER)
        OR      A
        RET     Z
        DEC     A
        LD      (SOUND_TIMER),A
        JR      NZ,SERVICE_SOUND_ACTIVE
        XOR     A
        LD      (SPEAKER_PORT_STATE),A
        LD      (SOUND_DIVIDER_COUNT),A
        RET
SERVICE_SOUND_ACTIVE:
        LD      A,(SOUND_DIVIDER_COUNT)
        DEC     A
        LD      (SOUND_DIVIDER_COUNT),A
        RET     NZ
        LD      A,(SOUND_DIVIDER_RELOAD)
        LD      (SOUND_DIVIDER_COUNT),A
        LD      A,(SPEAKER_PORT_STATE)
        XOR     SPEAKER_BIT
        LD      (SPEAKER_PORT_STATE),A
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

; LCD_BUSY
; Input:
;   none
; Output:
;   waits until LCD busy flag clears
; Clobbers:
;   none
LCD_BUSY:
        PUSH    AF
LCD_BUSY_LOOP:
        IN      A,(PORT_LCD_INST)
        RLCA
        JR      C,LCD_BUSY_LOOP
        POP     AF
        RET

; LCD_COMMAND
; Input:
;   B = LCD instruction byte
; Output:
;   instruction sent to LCD
; Clobbers:
;   none
LCD_COMMAND:
        PUSH    AF
        CALL    LCD_BUSY
        LD      A,B
        OUT     (PORT_LCD_INST),A
        POP     AF
        RET

; LCD_CLEAR_DISPLAY
; Input:
;   none
; Output:
;   LCD cleared, cursor home
; Clobbers:
;   B
LCD_CLEAR_DISPLAY:
        LD      B,0x01
        JP      LCD_COMMAND

; LCD_STRING
; Input:
;   HL = zero-terminated ASCII string
; Output:
;   string written at current LCD cursor position
; Clobbers:
;   A, HL
LCD_STRING:
        LD      A,(HL)
        INC     HL
        OR      A
        RET     Z
        CALL    LCD_BUSY
        OUT     (PORT_LCD_DATA),A
        JR      LCD_STRING

; LCD_SHOW_SCRIPT
; Input:
;   HL = pointer to script table (DB row_cmd, DW text_ptr, ..., DB 0)
; Output:
;   LCD cleared, then each row/text pair rendered
; Clobbers:
;   A, HL (BC, DE pushed/popped)
LCD_SHOW_SCRIPT:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        EX      DE,HL
        CALL    LCD_CLEAR_DISPLAY
LCD_SCRIPT_LOOP:
        LD      A,(DE)
        OR      A
        JR      Z,LCD_SCRIPT_DONE
        LD      B,A
        INC     DE
        CALL    LCD_COMMAND
        LD      A,(DE)
        LD      L,A
        INC     DE
        LD      A,(DE)
        LD      H,A
        INC     DE
        CALL    LCD_STRING
        JR      LCD_SCRIPT_LOOP
LCD_SCRIPT_DONE:
        POP     HL
        POP     DE
        POP     BC
        RET

; LCD_SHOW_PACMO_SPLASH
; Input:
;   none
; Output:
;   Pacmo splash and control hint shown on LCD
; Clobbers:
;   A, HL
LCD_SHOW_PACMO_SPLASH:
        LD      HL,SCRIPT_PACMO_SPLASH
        JP      LCD_SHOW_SCRIPT

; LCD_SHOW_PACMO_RUNNING
; Input:
;   none
; Output:
;   Pacmo running status shown on LCD
; Clobbers:
;   A, DE, HL
LCD_SHOW_PACMO_RUNNING:
        LD      HL,SCRIPT_PACMO_RUNNING
        CALL    LCD_SHOW_SCRIPT
        JP      LCD_REFRESH_LEVEL_ROW

; LCD_SHOW_PACMO_POWER
; Input:
;   none
; Output:
;   Pacmo power-mode status shown on LCD
; Clobbers:
;   A, DE, HL
LCD_SHOW_PACMO_POWER:
        LD      HL,SCRIPT_PACMO_POWER
        CALL    LCD_SHOW_SCRIPT
        JP      LCD_REFRESH_LEVEL_ROW

; LCD_SHOW_PACMO_ENEMY_EATEN
; Input:
;   none
; Output:
;   Pacmo enemy-eaten status shown on LCD
; Clobbers:
;   A, DE, HL
LCD_SHOW_PACMO_ENEMY_EATEN:
        LD      HL,SCRIPT_PACMO_ENEMY_EATEN
        CALL    LCD_SHOW_SCRIPT
        JP      LCD_REFRESH_LEVEL_ROW

; LCD_SHOW_PACMO_CAUGHT
; Input:
;   none
; Output:
;   Pacmo caught status shown on LCD
; Clobbers:
;   A, HL
LCD_SHOW_PACMO_CAUGHT:
        LD      HL,SCRIPT_PACMO_CAUGHT
        JP      LCD_SHOW_SCRIPT

; LCD_SHOW_PACMO_COMPLETE
; Input:
;   none
; Output:
;   Pacmo level-complete status shown on LCD
; Clobbers:
;   A, HL
LCD_SHOW_PACMO_COMPLETE:
        LD      HL,SCRIPT_PACMO_COMPLETE
        JP      LCD_SHOW_SCRIPT

; LCD_REFRESH_LEVEL_ROW
; Input:
;   PACMO_LEVEL
; Output:
;   row 2 rewritten as LEVEL X
; Clobbers:
;   A, DE, HL
LCD_REFRESH_LEVEL_ROW:
        PUSH    BC
        LD      B,LCD_ROW2
        CALL    LCD_COMMAND
        LD      HL,LCD_TEXT_PACMO_LEVEL
        CALL    LCD_STRING
        LD      A,(PACMO_LEVEL)
        AND     0x0F
        LD      L,A
        LD      H,0
        LD      DE,PACMO_LEVEL_CHAR_TABLE
        ADD     HL,DE
        LD      A,(HL)
        CALL    LCD_PUTC
        POP     BC
        RET

; LCD_PUTC
; Input:
;   A = ASCII character
; Output:
;   character written at current LCD cursor position
; Clobbers:
;   none
LCD_PUTC:
        PUSH    AF
        CALL    LCD_BUSY
        POP     AF
        OUT     (PORT_LCD_DATA),A
        RET
