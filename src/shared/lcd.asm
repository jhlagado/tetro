; Generic HD44780 LCD primitives for the TEC-1G MON-3 hardware mapping.

; LCD_BUSY
; Input:
;   none
; Output:
;   waits until LCD busy flag clears
; Clobbers:
;   none
LCD_BUSY:
        PUSH    AF
LCD_BUSY_LOOP:
        IN      A,(PORT_LCD_INST)
        RLCA
        JR      C,LCD_BUSY_LOOP
        POP     AF
        RET

; LCD_COMMAND
; Input:
;   B = LCD instruction byte
; Output:
;   instruction sent to LCD
; Clobbers:
;   none
LCD_COMMAND:
        PUSH    AF
        CALL    LCD_BUSY
        LD      A,B
        OUT     (PORT_LCD_INST),A
        POP     AF
        RET

; LCD_CLEAR_DISPLAY
; Input:
;   none
; Output:
;   LCD cleared, cursor home
; Clobbers:
;   B
LCD_CLEAR_DISPLAY:
        LD      B,0x01
        JP      LCD_COMMAND

; LCD_STRING
; Input:
;   HL = zero-terminated ASCII string
; Output:
;   string written at current LCD cursor position
; Clobbers:
;   A, HL
LCD_STRING:
        LD      A,(HL)
        INC     HL
        OR      A
        RET     Z
        CALL    LCD_BUSY
        OUT     (PORT_LCD_DATA),A
        JR      LCD_STRING

; LCD_SHOW_SCRIPT
; Input:
;   HL = pointer to script table (DB row_cmd, DW text_ptr, ..., DB 0)
; Output:
;   LCD cleared, then each (row_cmd, text_ptr) pair rendered in order
; Clobbers:
;   A  (BC, DE, HL pushed/popped)
LCD_SHOW_SCRIPT:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        EX      DE,HL                   ; DE = script cursor
        CALL    LCD_CLEAR_DISPLAY
LCD_SCRIPT_LOOP:
        LD      A,(DE)                  ; row cmd (0 = end of script)
        OR      A
        JR      Z,LCD_SCRIPT_DONE
        LD      B,A
        INC     DE
        CALL    LCD_COMMAND
        LD      A,(DE)                  ; text ptr lo
        LD      L,A
        INC     DE
        LD      A,(DE)                  ; text ptr hi
        LD      H,A
        INC     DE
        CALL    LCD_STRING
        JR      LCD_SCRIPT_LOOP
LCD_SCRIPT_DONE:
        POP     HL
        POP     DE
        POP     BC
        RET

; LCD_PUTC
; Input:
;   A = ASCII character
; Output:
;   character written at current LCD cursor position
; Clobbers:
;   none
LCD_PUTC:
        PUSH    AF
        CALL    LCD_BUSY
        POP     AF
        OUT     (PORT_LCD_DATA),A
        RET

; LCD_WRITE_ROW_STRING
; Input:
;   B = row DDRAM command
;   HL = zero-terminated string
; Output:
;   cursor moved and string written
; Clobbers:
;   A, HL
LCD_WRITE_ROW_STRING:
        CALL    LCD_COMMAND
        JP      LCD_STRING

; LCD_PUTC_FROM_TABLE
; Input:
;   A = unsigned table index
;   DE = byte table base
; Output:
;   table byte at DE+A written
; Clobbers:
;   A, HL
; Notes:
;   no bounds check
LCD_PUTC_FROM_TABLE:
        LD      L,A
        LD      H,0
        ADD     HL,DE
        LD      A,(HL)
        JP      LCD_PUTC
