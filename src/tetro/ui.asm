; LcdShowGOver
; Input:
;   none
; Output:
;   game-over screen rendered; no NEXT preview is appended
; Clobbers:
;   A, HL
LcdShowGOver:
        LD      HL,ScriptGameOver
        JP      LcdScript

; LcdShowPaused
; Input:
;   none
; Output:
;   Paused HUD rendered with NEXT preview
; Clobbers:
;   A, HL
LcdShowPaused:
        LD      HL,ScriptPaused
        JR      LcdShowHud

; LcdShowSplash
; Input:
;   none
; Output:
;   splash screen + key mapping written to LCD
; Clobbers:
;   A, HL
LcdShowSplash:
        LD      HL,ScriptSplash
        JP      LcdScript

; LcdAppendPrev
; Prerequisites:
;   LCD cursor positioned after trailing space of NEXT: banner.
; Input:
;   NextPieceIndex
; Output:
;   one-character piece preview written
; Clobbers:
;   A, DE, HL
LcdAppendPrev:
        LD      A,(NextPieceIndex)
        LD      DE,PieceNameTable
        JP      LcdPutcTbl

; LcdRefNextPrev
; Rewrites HUD row 2 with NEXT: banner + letter. Does not clear the display;
; "NEXT: X" is always 7 chars so it overwrites cleanly, preserving row 1.
; Input:
;   NextPieceIndex
; Output:
;   LCD row 2 rewritten
; Clobbers:
;   A, DE
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

; LcdShowRunning
; Input:
;   none
; Output:
;   running HUD rendered with NEXT preview
; Clobbers:
;   A, HL
LcdShowRunning:
        LD      HL,ScriptRunning
        ; fall through

; LcdShowHud
; Input:
;   HL = script pointer (row1 banner, row2 "NEXT: ")
; Output:
;   LCD cleared, script rendered, preview letter appended on row 2
; Clobbers:
;   A (BC/DE/HL pushed/popped)
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
