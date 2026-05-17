; LCD_SHOW_GAME_OVER
; Game-over screen rendered; no NEXT preview is appended.
; @clobbers A,HL while rendering the game-over screen.
LCD_SHOW_GAME_OVER:
        LD      HL,SCRIPT_GAME_OVER
        JP      LCD_SHOW_SCRIPT

; LCD_SHOW_PAUSED
; Paused HUD rendered with NEXT preview.
; @clobbers A,HL while rendering the paused HUD.
LCD_SHOW_PAUSED:
        LD      HL,SCRIPT_PAUSED
        JR      LCD_SHOW_HUD

; LCD_SHOW_SPLASH
; Splash screen + key mapping written to LCD.
; @clobbers A,HL while rendering the splash screen.
LCD_SHOW_SPLASH:
        LD      HL,SCRIPT_SPLASH
        JP      LCD_SHOW_SCRIPT

; LCD_APPEND_NEXT_PREVIEW_LETTER
; LCD cursor positioned after trailing space of NEXT: banner.
; Reads NEXT_PIECE_INDEX.
; One-character piece preview written.
; @clobbers A,DE,HL while writing the preview letter.
LCD_APPEND_NEXT_PREVIEW_LETTER:
        LD      A,(NEXT_PIECE_INDEX)
        LD      DE,PIECE_NAME_TABLE
        JP      LCD_PUTC_FROM_TABLE

; LCD_REFRESH_NEXT_PREVIEW_ROW
; Rewrites HUD row 2 with NEXT: banner + letter. Does not clear the display;
; "NEXT: X" is always 7 chars so it overwrites cleanly, preserving row 1.
; Reads NEXT_PIECE_INDEX.
; LCD row 2 rewritten.
; @clobbers A,DE while refreshing the next-piece preview row.
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
; Running HUD rendered with NEXT preview.
; @clobbers A,HL while rendering the running HUD.
LCD_SHOW_RUNNING:
        LD      HL,SCRIPT_RUNNING
        ; fall through

; LCD_SHOW_HUD
; @in HL script pointer (row1 banner, row2 "NEXT: ").
; LCD cleared, script rendered, preview letter appended on row 2.
; @clobbers A while rendering the HUD.
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
