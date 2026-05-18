; Generic HD44780 LCD primitives for the TEC-1G
; MON-3 hardware mapping.

; LcdBusy —
; Spin until the HD44780 busy flag clears.
; Fully preserves all registers (PUSH/POP AF).
LcdBusy:
        PUSH    AF
LcdBusyLp:
        IN      A,(PortLcdInst)
        RLCA
        JR      C,LcdBusyLp
        POP     AF
        RET

; LcdCmd —
; Wait for LCD ready then send B as an
; instruction byte to PortLcdInst.
; ========================== AZM
; in        B
; ========================== AZM
LcdCmd:
        PUSH    AF
        CALL    LcdBusy
        LD      A,B
        OUT     (PortLcdInst),A
        POP     AF
        RET

; LcdClear —
; Send the clear-display command (0x01).
; Cursor homes to position 0 after the command.
; Tail-calls LcdCmd (JP).
; ========================== AZM
; clobbers  B
; ========================== AZM
LcdClear:
        LD      B,0x01
        JP      LcdCmd

; LcdString —
; Write a zero-terminated string to the LCD.
; Starts at the current cursor position and
; returns when the NUL terminator is consumed.
; ========================== AZM
; in        HL
; out       HL,carry
; clobbers  A
; ========================== AZM
LcdString:
        LD      A,(HL)
        INC     HL
        OR      A
        RET     Z
        CALL    LcdBusy
        OUT     (PortLcdData),A
        JR      LcdString

; LcdScript —
; Execute an LCD screen script from ROM.
; Script format: DB row_cmd, DW text_ptr, …,
; terminated by DB 0.
; Clears the display first, then for each entry
; positions the cursor and writes the string.
; ========================== AZM
; in        HL,DE
; out       DE,HL
; clobbers  B
; ========================== AZM
LcdScript:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        EX      DE,HL                   ; DE = script cursor
        CALL    LcdClear
LcdScrLp:
        LD      A,(DE)                  ; row cmd (0 = end of script)
        OR      A
        JR      Z,LcdScrDone
        LD      B,A
        INC     DE
        CALL    LcdCmd
        LD      A,(DE)                  ; text ptr lo
        LD      L,A
        INC     DE
        LD      A,(DE)                  ; text ptr hi
        LD      H,A
        INC     DE
        CALL    LcdString
        JR      LcdScrLp
LcdScrDone:
        POP     HL
        POP     DE
        POP     BC
        RET

; LcdPutc —
; Write one character to the LCD at the current
; cursor position.
; ========================== AZM
; in        A
; ========================== AZM
LcdPutc:
        PUSH    AF
        CALL    LcdBusy
        POP     AF
        OUT     (PortLcdData),A
        RET

; LcdRowStr —
; Position cursor via DDRAM command in B then
; write the zero-terminated string from HL.
; Tail-calls LcdString (JP).
; ========================== AZM
; in        B,HL
; out       HL
; clobbers  A
; ========================== AZM
LcdRowStr:
        CALL    LcdCmd
        JP      LcdString

; LcdPutcTbl —
; Write the byte at DE+A to the LCD cursor.
; No bounds check on A.
; Tail-calls LcdPutc (JP).
; ========================== AZM
; in        A,DE
; clobbers  A,HL
; ========================== AZM
LcdPutcTbl:
        LD      L,A
        LD      H,0
        ADD     HL,DE
        LD      A,(HL)
        JP      LcdPutc
