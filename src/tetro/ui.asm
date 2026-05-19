; LcdShowGOver —
; Show the game-over LCD script.
; No NEXT preview row is appended.
; ========================== AZM
; out       carry
; clobbers  A,HL
; ========================== AZM
@LcdShowGOver:
        LD      HL,ScriptGameOver
        JP      LcdScript

; LcdShowPaused —
; Show the PAUSED HUD; falls into LcdShowHud
; which appends the NEXT preview on row 2.
; ========================== AZM
; out       HL
; ========================== AZM
@LcdShowPaused:
        LD      HL,ScriptPaused
        JR      LcdShowHud

; LcdShowSplash —
; Show the splash screen with control hints.
; LcdScript's carry result is not Tetro status.
; ========================== AZM
; out       carry
; clobbers  A,HL
; ========================== AZM
@LcdShowSplash:
        LD      HL,ScriptSplash
        JP      LcdScript

; LcdAppendPrev —
; Emit the NextPieceIndex letter glyph to the LCD.
; The LCD cursor is positioned after the NEXT: banner.
; ========================== AZM
; clobbers  A,DE,HL
; ========================== AZM
@LcdAppendPrev:
        LD      A,(NextPieceIndex)
        LD      DE,PieceNameTable
        JP      LcdPutcTbl

; LcdRefNextPrev —
; Rewrite row 2 NEXT: label plus preview letter.
; Row 1 is left untouched.
; ========================== AZM
; clobbers  A,DE
; ========================== AZM
@LcdRefNextPrev:
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
; clobbers  A
; ========================== AZM
@LcdShowRunning:
        LD      HL,ScriptRunning
        ; fall through

; LcdShowHud —
; Shared tail: run LcdScript then append NEXT
; preview letter on row 2.
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
