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

; SOUND_TRIGGER_ROTATE
; Input:
;   none
; Output:
;   short rotate buzz started
; Clobbers:
;   A, C
SOUND_TRIGGER_ROTATE:
        LD      A,SOUND_ROTATE_LEN
        LD      C,SOUND_ROTATE_DIV
        JP      SOUND_START

; SOUND_TRIGGER_LOCK
; Input:
;   none
; Output:
;   short lock buzz started
; Clobbers:
;   A, C
SOUND_TRIGGER_LOCK:
        LD      A,SOUND_LOCK_LEN
        LD      C,SOUND_LOCK_DIV
        JP      SOUND_START

; SOUND_TRIGGER_CLEAR
; Input:
;   none
; Output:
;   line-clear buzz started
; Clobbers:
;   A, C
SOUND_TRIGGER_CLEAR:
        LD      A,SOUND_CLEAR_LEN
        LD      C,SOUND_CLEAR_DIV
        JP      SOUND_START

; SOUND_TRIGGER_GAME_OVER
; Input:
;   none
; Output:
;   game-over buzz started
; Clobbers:
;   A, C
SOUND_TRIGGER_GAME_OVER:
        LD      A,SOUND_GAME_OVER_LEN
        LD      C,SOUND_GAME_OVER_DIV
        JP      SOUND_START

; SOUND_TRIGGER_GAME_OVER_RESTART_READY
; Input:
;   none
; Output:
;   short chirp once key-delay finishes (speaker restarts PWM)
; Clobbers:
;   A, C
SOUND_TRIGGER_GAME_OVER_RESTART_READY:
        LD      A,SOUND_GAME_OVER_READY_LEN
        LD      C,SOUND_GAME_OVER_READY_DIV
        JP      SOUND_START

; SERVICE_SOUND
; Input:
;   SOUND_TIMER / SOUND_DIVIDER_RELOAD / SOUND_DIVIDER_COUNT
; Output:
;   SPEAKER_PORT_STATE updated for current scan pass
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

; SCAN_SCORE_DIGIT — time-multiplex HUD + PWM speaker on PORT_DIGITS (invoked once per SCAN_TICK cycle so all six digits + speaker share bandwidth across scan passes).
; Brief: HUD_SCAN_INDEX runs 0..5 then wraps. First OUT publishes segment data on PORT_SEGS with digit driver showing
; only SPEAKER_PORT_STATE on PORT_DIGITS; second OUT ORs DIGIT_MASK_TABLE[C] into
; PORT_DIGITS so one cathode/anode selects the active digit without clobbering
; the speaker line (speaker + digit select share the latch).
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
; Sets all six multiplexed score segments to off (pattern 0). Used while the
; splash screen waits for a key so numerals do not appear until play starts
; (HANDLE_SPLASH_STATE then calls UPDATE_SCORE_DISPLAY).
; Input: none  Output: HUD_SEG_BUFFER[0..5] = 0  Clobbers: A, B, HL
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
;   SCORE_LO / SCORE_HI
; Output:
;   HUD_SEG_BUFFER updated with a six-digit score display
; Note:
;   DIAG_SEG_TABLE is reused for two purposes — its first byte (glyph for '0')
;   pre-fills the leading HUD digit every refresh (blanks stale score); later
;   SCORE_WRITE_DIGIT indexes the same table for per-digit glyph lookup.
; Clobbers:
;   A, BC, DE, HL
UPDATE_SCORE_DISPLAY:
        LD      A,(DIAG_SEG_TABLE)
        LD      (HUD_SEG_BUFFER),A
        LD      HL,(SCORE_LO)
        LD      BC,HUD_SEG_BUFFER+1

        LD      DE,0x2710      ; 10000
        CALL    SCORE_WRITE_DIGIT
        LD      DE,0x03E8      ; 1000
        CALL    SCORE_WRITE_DIGIT
        LD      DE,0x0064      ; 100
        CALL    SCORE_WRITE_DIGIT
        LD      DE,0x000A      ; 10
        CALL    SCORE_WRITE_DIGIT
        LD      DE,0x0001      ; 1
        CALL    SCORE_WRITE_DIGIT
        RET

; SCORE_WRITE_DIGIT
; Input:
;   HL = score remainder
;   DE = divisor
;   BC = destination digit in HUD_SEG_BUFFER
; Output:
;   HL = updated score remainder
;   BC = advanced to next destination
; Clobbers:
;   A, DE (DE reloaded mid-routine for glyph lookup)
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
        LD      DE,DIAG_SEG_TABLE
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
; HD44780 function 0x01 — clears DDRAM and returns cursor home.
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

; LCD_SHOW_GAME_OVER / _PAUSED / _RUNNING share the HUD wrapper:
; each selects its SCRIPT_* and falls into LCD_SHOW_HUD, which runs the
; script and appends the dynamic NEXT: piece letter.
; Clobbers: A
LCD_SHOW_GAME_OVER:
        LD      HL,SCRIPT_GAME_OVER
        JP      LCD_SHOW_SCRIPT          ; no NEXT preview — PRESS ANY KEY on row 2

LCD_SHOW_PAUSED:
        LD      HL,SCRIPT_PAUSED
        JR      LCD_SHOW_HUD

; LCD_SHOW_SPLASH
; Input:
;   none
; Output:
;   splash screen + key mapping written to LCD (no NEXT: row; rows 2-4 are controls)
; Clobbers:
;   A
LCD_SHOW_SPLASH:
        LD      HL,SCRIPT_SPLASH
        JP      LCD_SHOW_SCRIPT

; LCD_APPEND_NEXT_PREVIEW_LETTER
; Prerequisites: LCD cursor positioned after trailing space of NEXT: banner.
; Reads NEXT_PIECE_INDEX / PIECE_NAME_TABLE.
; Output: one-character piece preview written
; Clobbers: A, L, DE; H cleared
LCD_APPEND_NEXT_PREVIEW_LETTER:
        LD      A,(NEXT_PIECE_INDEX)
        LD      L,A
        LD      H,0
        LD      DE,PIECE_NAME_TABLE
        ADD     HL,DE
        LD      A,(HL)
        JP      LCD_PUTC

; LCD_REFRESH_NEXT_PREVIEW_ROW
; Rewrites HUD row 2 with NEXT: banner + letter. Does NOT clear the display;
; "NEXT: X" is always 7 chars so it overwrites cleanly, preserving row 1
; banner set by the last LCD_SHOW_* state transition.
; Input:
;   NEXT_PIECE_INDEX
; Output:
;   LCD row 2 rewritten (row 1 banner preserved)
; Clobbers:
;   A, DE
LCD_REFRESH_NEXT_PREVIEW_ROW:
        PUSH    BC
        PUSH    HL
        LD      B,LCD_ROW2
        CALL    LCD_COMMAND
        LD      HL,LCD_TEXT_NEXT
        CALL    LCD_STRING
        CALL    LCD_APPEND_NEXT_PREVIEW_LETTER
        POP     HL
        POP     BC
        RET

; LCD_SHOW_RUNNING falls into LCD_SHOW_HUD; shared with _PAUSED / _GAME_OVER.
LCD_SHOW_RUNNING:
        LD      HL,SCRIPT_RUNNING
        ; fall through

; LCD_SHOW_HUD
; Input:
;   HL = script pointer (row1 banner, row2 "NEXT: ")
; Output:
;   LCD cleared, script rendered, preview letter appended on row 2
; Clobbers:
;   A (BC/DE/HL pushed/popped)
LCD_SHOW_HUD:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    LCD_SHOW_SCRIPT
        CALL    LCD_APPEND_NEXT_PREVIEW_LETTER
        POP     HL
        POP     DE
        POP     BC
        RET

; LCD_SHOW_SCRIPT
; Input:
;   HL = pointer to script table (DB row_cmd, DW text_ptr, ..., DB 0)
; Output:
;   LCD cleared, then each (row_cmd, text_ptr) pair rendered in order
; Clobbers:
;   A  (BC, DE, HL pushed/popped)
LCD_SHOW_SCRIPT:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        EX      DE,HL                   ; DE = script cursor
        CALL    LCD_CLEAR_DISPLAY
LCD_SCRIPT_LOOP:
        LD      A,(DE)                  ; row cmd (0 = end of script)
        OR      A
        JR      Z,LCD_SCRIPT_DONE
        LD      B,A
        INC     DE
        CALL    LCD_COMMAND
        LD      A,(DE)                  ; text ptr lo
        LD      L,A
        INC     DE
        LD      A,(DE)                  ; text ptr hi
        LD      H,A
        INC     DE
        CALL    LCD_STRING
        JR      LCD_SCRIPT_LOOP
LCD_SCRIPT_DONE:
        POP     HL
        POP     DE
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

; Seven-segment patterns for 0..F, copied from MON-3 hexToSegmentTable.
