; LCD_SHOW_GAME_OVER
; Input:
;   none
; Output:
;   game-over screen rendered; no NEXT preview is appended
; Clobbers:
;   A, HL
LCD_SHOW_GAME_OVER:
        LD      HL,SCRIPT_GAME_OVER
        JP      LCD_SHOW_SCRIPT

; LCD_SHOW_PAUSED
; Input:
;   none
; Output:
;   paused HUD rendered with NEXT preview
; Clobbers:
;   A, HL
LCD_SHOW_PAUSED:
        LD      HL,SCRIPT_PAUSED
        JR      LCD_SHOW_HUD

; LCD_SHOW_SPLASH
; Input:
;   none
; Output:
;   splash screen + key mapping written to LCD
; Clobbers:
;   A, HL
LCD_SHOW_SPLASH:
        LD      HL,SCRIPT_SPLASH
        JP      LCD_SHOW_SCRIPT

; LCD_APPEND_NEXT_PREVIEW_LETTER
; Prerequisites:
;   LCD cursor positioned after trailing space of NEXT: banner.
; Input:
;   NEXT_PIECE_INDEX
; Output:
;   one-character piece preview written
; Clobbers:
;   A, DE, HL
LCD_APPEND_NEXT_PREVIEW_LETTER:
        LD      A,(NEXT_PIECE_INDEX)
        LD      DE,PIECE_NAME_TABLE
        JP      LCD_PUTC_FROM_TABLE

; LCD_REFRESH_NEXT_PREVIEW_ROW
; Rewrites HUD row 2 with NEXT: banner + letter. Does not clear the display;
; "NEXT: X" is always 7 chars so it overwrites cleanly, preserving row 1.
; Input:
;   NEXT_PIECE_INDEX
; Output:
;   LCD row 2 rewritten
; Clobbers:
;   A, DE
LCD_REFRESH_NEXT_PREVIEW_ROW:
        PUSH    BC
        PUSH    HL
        LD      B,LCD_ROW2
        LD      HL,LCD_TEXT_NEXT
        CALL    LCD_WRITE_ROW_STRING
        CALL    LCD_APPEND_NEXT_PREVIEW_LETTER
        POP     HL
        POP     BC
        RET

; LCD_SHOW_RUNNING
; Input:
;   none
; Output:
;   running HUD rendered with NEXT preview
; Clobbers:
;   A, HL
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
