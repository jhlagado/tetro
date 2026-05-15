; Pacmo-specific LCD status screens.
; Shared LCD primitives live in src/shared/lcd.asm; this file selects Pacmo
; status scripts and writes Pacmo-specific dynamic LCD rows.

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
        JP      LCD_REFRESH_STATUS_ROWS

; LCD_SHOW_PACMO_PAUSED
; Input:
;   none
; Output:
;   Pacmo paused status shown on LCD
; Clobbers:
;   A, DE, HL
LCD_SHOW_PACMO_PAUSED:
        LD      HL,SCRIPT_PACMO_PAUSED
        CALL    LCD_SHOW_SCRIPT
        JP      LCD_REFRESH_STATUS_ROWS

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
        JP      LCD_REFRESH_STATUS_ROWS

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
        JP      LCD_REFRESH_STATUS_ROWS

; LCD_SHOW_PACMO_CAUGHT
; Input:
;   none
; Output:
;   Pacmo caught status shown on LCD
; Clobbers:
;   A, DE, HL
LCD_SHOW_PACMO_CAUGHT:
        LD      HL,SCRIPT_PACMO_CAUGHT
        CALL    LCD_SHOW_SCRIPT
        JP      LCD_REFRESH_LIVES_ROW

; LCD_SHOW_PACMO_GAME_OVER
; Input:
;   none
; Output:
;   Pacmo game-over status shown on LCD
; Clobbers:
;   A, HL
LCD_SHOW_PACMO_GAME_OVER:
        LD      HL,SCRIPT_PACMO_GAME_OVER
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

; LCD_REFRESH_STATUS_ROWS
; Input:
;   PACMO_LEVEL, PACMO_LIVES
; Output:
;   row 2 rewritten as LEVEL X; row 3 rewritten as LIVES N
; Clobbers:
;   A, DE, HL
LCD_REFRESH_STATUS_ROWS:
        CALL    LCD_REFRESH_LEVEL_ROW
        JP      LCD_REFRESH_LIVES_ROW

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
        LD      HL,LCD_TEXT_PACMO_LEVEL
        CALL    LCD_WRITE_ROW_STRING
        LD      A,(PACMO_LEVEL)
        AND     0x0F
        LD      DE,PACMO_LEVEL_CHAR_TABLE
        CALL    LCD_PUTC_FROM_TABLE
        POP     BC
        RET

; LCD_REFRESH_LIVES_ROW
; Input:
;   PACMO_LIVES
; Output:
;   row 3 rewritten as LIVES N
; Clobbers:
;   A, DE, HL
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
