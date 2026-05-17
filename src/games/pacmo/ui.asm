; Pacmo-specific LCD status screens.
; Shared LCD primitives live in src/shared/lcd.asm; this file selects Pacmo
; status scripts and writes Pacmo-specific dynamic LCD rows.

; LCD_SHOW_PACMO_SPLASH
; Pacmo splash and control hint shown on LCD.
; @clobbers A,HL while rendering the splash status.
LCD_SHOW_PACMO_SPLASH:
        LD      HL,SCRIPT_PACMO_SPLASH
        JP      LCD_SHOW_SCRIPT

; LCD_SHOW_PACMO_RUNNING
; Pacmo running status shown on LCD.
; @clobbers A,DE,HL while rendering the running status.
LCD_SHOW_PACMO_RUNNING:
        LD      HL,SCRIPT_PACMO_RUNNING
        CALL    LCD_SHOW_SCRIPT
        JP      LCD_REFRESH_STATUS_ROWS

; LCD_SHOW_PACMO_PAUSED
; Pacmo paused status shown on LCD.
; @clobbers A,DE,HL while rendering the paused status.
LCD_SHOW_PACMO_PAUSED:
        LD      HL,SCRIPT_PACMO_PAUSED
        CALL    LCD_SHOW_SCRIPT
        JP      LCD_REFRESH_STATUS_ROWS

; LCD_SHOW_PACMO_POWER
; Pacmo power-mode status shown on LCD.
; @clobbers A,DE,HL while rendering the power-mode status.
LCD_SHOW_PACMO_POWER:
        LD      HL,SCRIPT_PACMO_POWER
        CALL    LCD_SHOW_SCRIPT
        JP      LCD_REFRESH_STATUS_ROWS

; LCD_SHOW_PACMO_ENEMY_EATEN
; Pacmo enemy-eaten status shown on LCD.
; @clobbers A,DE,HL while rendering the enemy-eaten status.
LCD_SHOW_PACMO_ENEMY_EATEN:
        LD      HL,SCRIPT_PACMO_ENEMY_EATEN
        CALL    LCD_SHOW_SCRIPT
        JP      LCD_REFRESH_STATUS_ROWS

; LCD_SHOW_PACMO_CAUGHT
; Pacmo caught status shown on LCD.
; @clobbers A,DE,HL while rendering the caught status.
LCD_SHOW_PACMO_CAUGHT:
        LD      HL,SCRIPT_PACMO_CAUGHT
        CALL    LCD_SHOW_SCRIPT
        JP      LCD_REFRESH_LIVES_ROW

; LCD_SHOW_PACMO_GAME_OVER
; Pacmo game-over status shown on LCD.
; @clobbers A,HL while rendering the game-over status.
LCD_SHOW_PACMO_GAME_OVER:
        LD      HL,SCRIPT_PACMO_GAME_OVER
        JP      LCD_SHOW_SCRIPT

; LCD_SHOW_PACMO_COMPLETE
; Pacmo level-complete status shown on LCD.
; @clobbers A,HL while rendering the level-complete status.
LCD_SHOW_PACMO_COMPLETE:
        LD      HL,SCRIPT_PACMO_COMPLETE
        JP      LCD_SHOW_SCRIPT

; LCD_REFRESH_STATUS_ROWS
; Reads PACMO_LEVEL, PACMO_LIVES.
; Row 2 rewritten as LEVEL X; row 3 rewritten as LIVES N.
; @clobbers A,DE,HL while refreshing Pacmo status rows.
LCD_REFRESH_STATUS_ROWS:
        CALL    LCD_REFRESH_LEVEL_ROW
        JP      LCD_REFRESH_LIVES_ROW

; LCD_REFRESH_LEVEL_ROW
; Reads PACMO_LEVEL.
; Row 2 rewritten as LEVEL X.
; @clobbers A,DE,HL while refreshing the level row.
LCD_REFRESH_LEVEL_ROW:
        PUSH    BC
        LD      B,LCD_ROW2
        LD      HL,LCD_TEXT_PACMO_LEVEL
        CALL    LCD_WRITE_ROW_STRING
        LD      A,(PACMO_LEVEL)
        AND     0x0F
        LD      DE,PACMO_LEVEL_CHAR_TABLE
        CALL    LCD_PUTC_FROM_TABLE
        POP     BC
        RET

; LCD_REFRESH_LIVES_ROW
; Reads PACMO_LIVES.
; Row 3 rewritten as LIVES N.
; @clobbers A,DE,HL while refreshing the lives row.
LCD_REFRESH_LIVES_ROW:
        PUSH    BC
        LD      B,LCD_ROW3
        LD      HL,LCD_TEXT_PACMO_LIVES
        CALL    LCD_WRITE_ROW_STRING
        LD      A,(PACMO_LIVES)
        AND     0x0F
        LD      DE,PACMO_LEVEL_CHAR_TABLE
        CALL    LCD_PUTC_FROM_TABLE
        POP     BC
        RET
