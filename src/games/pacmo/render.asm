; REBUILD_FRAMEBUFFER
; Input:
;   current viewport and player state in RAM
; Output:
;   FRAMEBUFFER rebuilt from scratch
; Clobbers:
;   A, BC, DE, HL
REBUILD_FRAMEBUFFER:
        CALL    CLEAR_BACK_ALL
        CALL    RENDER_WORLD_TO_BACK
        CALL    RENDER_PLAYER_TO_BACK
        JP      COPY_BACK_TO_FRONT

; CLEAR_BACK_ALL
; Input:
;   none
; Output:
;   FRAMEBUFFER_BACK cleared to zero
; Clobbers:
;   A, B, HL
CLEAR_BACK_ALL:
        LD      HL,FRAMEBUFFER_BACK
        LD      B,FRAMEBUFFER_BYTES
        XOR     A
CLEAR_BACK_ALL_LOOP:
        LD      (HL),A
        INC     HL
        DJNZ    CLEAR_BACK_ALL_LOOP
        RET

; Clear 4 bytes at FRAMEBUFFER_BACK + A.
; CLEAR_BACK_4
; Input:
;   A = byte offset into FRAMEBUFFER_BACK, expected 0,4,8,...,28
; Output:
;   selected 4-byte row cleared
; Clobbers:
;   A, DE, HL
CLEAR_BACK_4:
        LD      E,A
        LD      D,0
        LD      HL,FRAMEBUFFER_BACK
        ADD     HL,DE
        XOR     A
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (HL),A
        RET

; COPY_BACK_TO_FRONT
; Input:
;   FRAMEBUFFER_BACK contains completed image
; Output:
;   FRAMEBUFFER overwritten from FRAMEBUFFER_BACK
; Clobbers:
;   BC, DE, HL
COPY_BACK_TO_FRONT:
        LD      HL,FRAMEBUFFER_BACK
        LD      DE,FRAMEBUFFER
        LD      BC,FRAMEBUFFER_BYTES
        LDIR
        RET

; RENDER_WORLD_TO_BACK
; Input:
;   VIEW_X/Y and PACMO_WORLD_ROWS
; Output:
;   visible 8x8 viewport rendered into blue framebuffer plane
; Clobbers:
;   A, BC, DE, HL
RENDER_WORLD_TO_BACK:
        LD      HL,FRAMEBUFFER_BACK
        LD      A,(VIEW_Y)
        ADD     A,A
        LD      E,A
        LD      D,0
        PUSH    HL
        LD      HL,PACMO_WORLD_ROWS
        ADD     HL,DE
        EX      DE,HL                   ; DE = source world row pointer
        POP     HL                      ; HL = framebuffer row pointer
        LD      B,ROW_COUNT
RENDER_WORLD_ROW:
        PUSH    BC
        LD      A,(DE)
        LD      B,A                     ; B = high byte of 15-bit row
        INC     DE
        LD      A,(DE)
        LD      C,A                     ; C = low byte of 15-bit row
        INC     DE
        LD      A,(VIEW_X)
        CALL    WINDOW_BYTE_FROM_BC
        INC     HL                      ; red off
        INC     HL                      ; green off
        LD      (HL),A                  ; blue walls / pattern
        INC     HL
        INC     HL                      ; aux byte
        POP     BC
        DJNZ    RENDER_WORLD_ROW
        RET

; WINDOW_BYTE_FROM_BC
; Input:
;   BC = 16-bit world row, bit 15 is world column 0
;   A  = viewport X origin, expected 0..7
; Output:
;   A = 8 visible bits for columns VIEW_X..VIEW_X+7
; Clobbers:
;   B, C, D
WINDOW_BYTE_FROM_BC:
        LD      D,A
        LD      A,D
        OR      A
        JR      Z,WINDOW_BYTE_DONE
WINDOW_SHIFT_LOOP:
        SLA     C
        RL      B
        DEC     D
        JR      NZ,WINDOW_SHIFT_LOOP
WINDOW_BYTE_DONE:
        LD      A,B
        RET

; RENDER_PLAYER_TO_BACK
; Input:
;   PLAYER_X/Y, VIEW_X/Y
; Output:
;   player pixel ORed into red and green framebuffer planes (yellow)
; Clobbers:
;   A, B, C, DE, HL
RENDER_PLAYER_TO_BACK:
        LD      A,(PLAYER_Y)
        LD      B,A
        LD      A,(VIEW_Y)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenY
        CP      ROW_COUNT
        RET     NC
        ADD     A,A
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,FRAMEBUFFER_BACK
        ADD     HL,DE

        LD      A,(PLAYER_X)
        LD      B,A
        LD      A,(VIEW_X)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenX
        CP      ROW_COUNT
        RET     NC
        CALL    SCREEN_X_TO_MASK
        LD      C,A

        LD      A,(HL)
        OR      C
        LD      (HL),A                  ; red
        INC     HL
        LD      A,(HL)
        OR      C
        LD      (HL),A                  ; green
        RET

; SCREEN_X_TO_MASK
; Input:
;   A = screen x coordinate, expected 0..7
; Output:
;   A = bit mask with column 0 as MSB
; Clobbers:
;   B, C
SCREEN_X_TO_MASK:
        LD      C,A
        OR      A
        LD      A,0x80
        JR      Z,SCREEN_X_TO_MASK_DONE
        LD      B,C
SCREEN_X_TO_MASK_LOOP:
        SRL     A
        DJNZ    SCREEN_X_TO_MASK_LOOP
SCREEN_X_TO_MASK_DONE:
        RET
