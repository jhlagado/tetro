; Pacmo-specific LCD status screens.
; Shared LCD primitives live in src/shared/lcd.asm; this file selects Pacmo
; status scripts and writes Pacmo-specific dynamic LCD rows.

; LcdShowPacSplash
; Input:
;   none
; Output:
;   Pacmo splash and control hint shown on LCD
; Clobbers:
;   A, HL
LcdShowPacSplash:
        LD      HL,ScriptPacSplash
        JP      LcdScript

; LcdShowPacRun
; Input:
;   none
; Output:
;   Pacmo running status shown on LCD
; Clobbers:
;   A, DE, HL
LcdShowPacRun:
        LD      HL,ScriptPacRun
        CALL    LcdScript
        JP      LcdRefStatus

; LcdShowPacPause
; Input:
;   none
; Output:
;   Pacmo Paused status shown on LCD
; Clobbers:
;   A, DE, HL
LcdShowPacPause:
        LD      HL,ScriptPacPause
        CALL    LcdScript
        JP      LcdRefStatus

; LcdShowPower
; Input:
;   none
; Output:
;   Pacmo power-mode status shown on LCD
; Clobbers:
;   A, DE, HL
LcdShowPower:
        LD      HL,ScriptPacPower
        CALL    LcdScript
        JP      LcdRefStatus

; LcdShowEatEnemy
; Input:
;   none
; Output:
;   Pacmo enemy-eaten status shown on LCD
; Clobbers:
;   A, DE, HL
LcdShowEatEnemy:
        LD      HL,ScriptPacEaten
        CALL    LcdScript
        JP      LcdRefStatus

; LcdShowCaught
; Input:
;   none
; Output:
;   Pacmo caught status shown on LCD
; Clobbers:
;   A, DE, HL
LcdShowCaught:
        LD      HL,ScriptPacCaught
        CALL    LcdScript
        JP      LcdRefLives

; LcdShowPacOver
; Input:
;   none
; Output:
;   Pacmo game-over status shown on LCD
; Clobbers:
;   A, HL
LcdShowPacOver:
        LD      HL,ScriptPacOver
        JP      LcdScript

; LcdShowComplete
; Input:
;   none
; Output:
;   Pacmo level-complete status shown on LCD
; Clobbers:
;   A, HL
LcdShowComplete:
        LD      HL,ScriptPacDone
        JP      LcdScript

; LcdRefStatus
; Input:
;   PacLevel, PacLives
; Output:
;   row 2 rewritten as LEVEL X; row 3 rewritten as LIVES N
; Clobbers:
;   A, DE, HL
LcdRefStatus:
        CALL    LcdRefLevel
        JP      LcdRefLives

; LcdRefLevel
; Input:
;   PacLevel
; Output:
;   row 2 rewritten as LEVEL X
; Clobbers:
;   A, DE, HL
LcdRefLevel:
        PUSH    BC
        LD      B,LcdRow2
        LD      HL,LcdTextPacLevel
        CALL    LcdRowStr
        LD      A,(PacLevel)
        AND     0x0F
        LD      DE,PacLevelChars
        CALL    LcdPutcTbl
        POP     BC
        RET

; LcdRefLives
; Input:
;   PacLives
; Output:
;   row 3 rewritten as LIVES N
; Clobbers:
;   A, DE, HL
LcdRefLives:
        PUSH    BC
        LD      B,LcdRow3
        LD      HL,LcdTextPacLives
        CALL    LcdRowStr
        LD      A,(PacLives)
        AND     0x0F
        LD      DE,PacLevelChars
        CALL    LcdPutcTbl
        POP     BC
        RET
