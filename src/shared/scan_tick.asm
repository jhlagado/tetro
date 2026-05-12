; Output one scanline, then advance persistent scan state.
; SCAN_TICK
; Input:
;   uses SCAN_PTR / SCAN_MASK from RAM
; Output:
;   one matrix row emitted to hardware ports
;   one seven-segment digit emitted to hardware ports
; Clobbers:
;   A, BC, DE, HL
SCAN_TICK:
        XOR     A
        OUT     (PORT_ROW),A

        LD      HL,(SCAN_PTR)

        LD      A,(HL)
        OUT     (PORT_RED),A
        INC     HL

        LD      A,(HL)
        OUT     (PORT_GREEN),A
        INC     HL

        LD      A,(HL)
        OUT     (PORT_BLUE),A

        LD      A,(SCAN_MASK)
        OUT     (PORT_ROW),A

        CALL    SERVICE_SOUND
        CALL    SCAN_SCORE_DIGIT
        CALL    ADVANCE_SCAN_STATE
        RET

; ADVANCE_SCAN_STATE
; Input:
;   uses SCAN_MASK / SCAN_PTR from RAM
; Output:
;   updated SCAN_MASK / SCAN_PTR
;   FRAME_PHASE: see ram.asm label — incremented once per full framebuffer wrap only.
; Clobbers:
;   A, DE, HL
ADVANCE_SCAN_STATE:
        LD      A,(SCAN_MASK)
        RLC     A
        LD      (SCAN_MASK),A

        LD      HL,(SCAN_PTR)
        LD      DE,BYTES_PER_ROW
        ADD     HL,DE

        CP      SCAN_MASK_START
        JR      NZ,SAVE_NEXT_SCAN_PTR

        LD      HL,FRAMEBUFFER
        LD      A,(FRAME_PHASE)
        INC     A
        LD      (FRAME_PHASE),A

SAVE_NEXT_SCAN_PTR:
        LD      (SCAN_PTR),HL
        RET
