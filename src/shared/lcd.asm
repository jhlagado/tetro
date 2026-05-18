; Generic HD44780 LCD primitives for the TEC-1G MON-3 hardware mapping.

; LcdBusy
;   waits until LCD busy flag clears
; Keeps @preserves AF,BC,DE,HL,IX,IY stable for the caller.
LcdBusy:
        PUSH    AF
LcdBusyLp:
        IN      A,(PortLcdInst)
        RLCA
        JR      C,LcdBusyLp
        POP     AF
        RET

; LcdCmd
; Accepts @in B as LCD instruction byte.
;   instruction sent to LCD
; Keeps @preserves AF,BC,DE,HL,IX,IY stable for the caller.
LcdCmd:
        PUSH    AF
        CALL    LcdBusy
        LD      A,B
        OUT     (PortLcdInst),A
        POP     AF
        RET

; LcdClear
; Input:
;   none
; Output:
;   LCD cleared, cursor home
; Clobbers:
;   B
LcdClear:
        LD      B,0x01
        JP      LcdCmd

; LcdString
; Input:
;   HL = zero-terminated ASCII string
; Output:
;   string written at current LCD cursor position
; Clobbers:
;   A, HL
LcdString:
        LD      A,(HL)
        INC     HL
        OR      A
        RET     Z
        CALL    LcdBusy
        OUT     (PortLcdData),A
        JR      LcdString

; LcdScript
; Input:
;   HL = pointer to script table (DB row_cmd, DW text_ptr, ..., DB 0)
; Output:
;   LCD cleared, then each (row_cmd, text_ptr) pair rendered in order
; Clobbers:
;   A  (BC, DE, HL pushed/popped)
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

; LcdPutc
; Input:
;   A = ASCII character
; Output:
;   character written at current LCD cursor position
; Clobbers:
;   none
LcdPutc:
        PUSH    AF
        CALL    LcdBusy
        POP     AF
        OUT     (PortLcdData),A
        RET

; LcdRowStr
; Input:
;   B = row DDRAM command
;   HL = zero-terminated string
; Output:
;   cursor moved and string written
; Clobbers:
;   A, HL
LcdRowStr:
        CALL    LcdCmd
        JP      LcdString

; LcdPutcTbl
; Input:
;   A = unsigned table index
;   DE = byte table base
; Output:
;   table byte at DE+A written
; Clobbers:
;   A, HL
; Notes:
;   no bounds check
LcdPutcTbl:
        LD      L,A
        LD      H,0
        ADD     HL,DE
        LD      A,(HL)
        JP      LcdPutc
