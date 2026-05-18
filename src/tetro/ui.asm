; LcdShowGOver —
; Show the game-over LCD script.
; Tail-calls LcdScript (JP); no NEXT preview row.
; ========================== AZM
; in        DE
; clobbers  B,DE,HL
; ========================== AZM
LcdShowGOver:
        LD      HL,ScriptGameOver
        JP      LcdScript

; LcdShowPaused —
; Show the PAUSED HUD; falls into LcdShowHud
; which appends the NEXT preview on row 2.
; ========================== AZM
; out       HL
; ========================== AZM
LcdShowPaused:
        LD      HL,ScriptPaused
        JR      LcdShowHud

; LcdShowSplash —
; Show the splash screen with control hints.
; Tail-calls LcdScript (JP).
; ========================== AZM
; in        DE
; clobbers  B,DE,HL
; ========================== AZM
LcdShowSplash:
        LD      HL,ScriptSplash
        JP      LcdScript

; LcdAppendPrev —
; Emit the NextPieceIndex letter glyph to the LCD.
; Cursor must already sit after the NEXT: banner.
; ========================== AZM
; clobbers  A,DE,HL
; ========================== AZM
LcdAppendPrev:
        LD      A,(NextPieceIndex)
        LD      DE,PieceNameTable
        JP      LcdPutcTbl

; LcdRefNextPrev —
; Rewrite row 2 NEXT: label plus preview letter.
; Row 1 is left untouched.
; ========================== AZM
; clobbers  A,DE
; ========================== AZM
LcdRefNextPrev:
        PUSH    BC
        PUSH    HL
        LD      B,LcdRow2
        LD      HL,LcdTextNext
        CALL    LcdRowStr
        CALL    LcdAppendPrev
        POP     HL
        POP     BC
        RET

; LcdShowRunning —
; Show the running HUD; falls through to
; LcdShowHud, which appends the NEXT preview.
; ========================== AZM
; out       HL
; ========================== AZM
LcdShowRunning:
        LD      HL,ScriptRunning
        ; fall through

; LcdShowHud —
; Shared tail: run LcdScript then append NEXT
; preview letter on row 2.
; ========================== AZM
; in        HL,DE
; clobbers  A
; ========================== AZM
LcdShowHud:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    LcdScript
        CALL    LcdAppendPrev
        POP     HL
        POP     DE
        POP     BC
        RET
