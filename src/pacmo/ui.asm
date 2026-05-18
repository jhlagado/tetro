; Pacmo-specific LCD status screens.
; Shared LCD primitives live in src/shared/lcd.asm;
; this file selects Pacmo scripts and writes
; Pacmo-specific dynamic LCD rows.

; LcdShowPacSplash —
; Show the Pacmo splash and control-hint screen.
; Tail-calls LcdScript (JP).
; ========================== AZM
; in        A,BC,DE,IX,IY,SP,carry,zero,sign,parity,halfCarry
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
LcdShowPacSplash:
        LD      HL,ScriptPacSplash
        JP      LcdScript

; LcdShowPacRun —
; Show the running HUD script (ScriptPacRun).
; Refreshes LEVEL and LIVES rows after.
; ========================== AZM
; in        A,BC,DE,IX,IY,SP,carry,zero,sign,parity,halfCarry
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
LcdShowPacRun:
        LD      HL,ScriptPacRun
        CALL    LcdScript
        JP      LcdRefStatus

; LcdShowPacPause —
; Show the paused HUD script (ScriptPacPause).
; Refreshes LEVEL and LIVES rows after.
; ========================== AZM
; in        A,BC,DE,IX,IY,SP,carry,zero,sign,parity,halfCarry
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
LcdShowPacPause:
        LD      HL,ScriptPacPause
        CALL    LcdScript
        JP      LcdRefStatus

; LcdShowPower —
; Show the power-mode HUD script during pill timer.
; Refreshes LEVEL and LIVES rows after.
; ========================== AZM
; in        A,BC,DE,IX,IY,SP,carry,zero,sign,parity,halfCarry
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
LcdShowPower:
        LD      HL,ScriptPacPower
        CALL    LcdScript
        JP      LcdRefStatus

; LcdShowEatEnemy —
; Show the Monster-eaten scripted cue.
; Refreshes LEVEL and LIVES rows after.
; ========================== AZM
; in        A,BC,DE,IX,IY,SP,carry,zero,sign,parity,halfCarry
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
LcdShowEatEnemy:
        LD      HL,ScriptPacEaten
        CALL    LcdScript
        JP      LcdRefStatus

; LcdShowCaught —
; Show the life-loss script (ScriptPacCaught).
; Refreshes the LIVES row only (JP LcdRefLives).
; ========================== AZM
; in        A,BC,DE,IX,IY,SP,carry,zero,sign,parity,halfCarry
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
LcdShowCaught:
        LD      HL,ScriptPacCaught
        CALL    LcdScript
        JP      LcdRefLives

; LcdShowPacOver —
; Show the Pacmo game-over screen.
; Tail-calls LcdScript (JP).
; ========================== AZM
; in        A,BC,DE,IX,IY,SP,carry,zero,sign,parity,halfCarry
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
LcdShowPacOver:
        LD      HL,ScriptPacOver
        JP      LcdScript

; LcdShowComplete —
; Show the round-complete / maze-clear screen.
; Tail-calls LcdScript (JP).
; ========================== AZM
; in        A,BC,DE,IX,IY,SP,carry,zero,sign,parity,halfCarry
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
LcdShowComplete:
        LD      HL,ScriptPacDone
        JP      LcdScript

; LcdRefStatus —
; Refresh rows 2–3 LEVEL and LIVES from
; PacLevel and PacLives.
; ========================== AZM
; clobbers  A,DE,HL
; ========================== AZM
LcdRefStatus:
        CALL    LcdRefLevel
        JP      LcdRefLives

; LcdRefLevel —
; Write row 2 LEVEL banner plus PacLevel digit.
; Uses PacLevelChars table for the nybble glyph.
; ========================== AZM
; clobbers  A,DE,HL
; ========================== AZM
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

; LcdRefLives —
; Write row 3 LIVES banner plus PacLives digit.
; Uses PacLevelChars table for the nybble glyph.
; ========================== AZM
; clobbers  A,DE,HL
; ========================== AZM
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
