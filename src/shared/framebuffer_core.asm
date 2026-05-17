; Generic double-buffer helpers for the 8x8 RGB matrix framebuffer.

; CLEAR_BACK_ALL
; Input:
;   none
; Output:
;   FRAMEBUFFER_BACK cleared to zero
; Clobbers:
;   A, B, HL
; Uses @clobbers A,B,HL while clearing the back buffer.
CLEAR_BACK_ALL:
        LD      HL,FRAMEBUFFER_BACK
        LD      B,FRAMEBUFFER_BYTES
        XOR     A
CLEAR_BACK_ALL_LOOP:
        LD      (HL),A
        INC     HL
        DJNZ    CLEAR_BACK_ALL_LOOP
        RET

; CLEAR_BACK_4
; Input:
;   A = byte offset into FRAMEBUFFER_BACK, expected 0,4,8,...,28
; Output:
;   selected 4-byte row cleared
; Clobbers:
;   A, DE, HL
; Accepts @in A as the 4-byte row offset.
; Uses @clobbers A,DE,HL while clearing the row.
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
; Uses @clobbers BC,DE,HL while copying the whole back buffer.
COPY_BACK_TO_FRONT:
        LD      HL,FRAMEBUFFER_BACK
        LD      DE,FRAMEBUFFER
        LD      BC,FRAMEBUFFER_BYTES
        LDIR
        RET

; COPY_BACK_4_TO_FRONT
; Input:
;   A = byte offset into both framebuffers, expected 0,4,8,...,28
; Output:
;   selected 4-byte row copied from FRAMEBUFFER_BACK to FRAMEBUFFER
; Clobbers:
;   A, DE, HL
; Accepts @in A as the framebuffer byte offset.
; Uses @clobbers A,DE,HL while copying the selected row.
; Keeps @preserves BC,IX,IY stable for the caller.
COPY_BACK_4_TO_FRONT:
        LD      E,A
        LD      D,0
        LD      HL,FRAMEBUFFER_BACK
        ADD     HL,DE
        PUSH    HL
        LD      HL,FRAMEBUFFER
        ADD     HL,DE
        EX      DE,HL
        POP     HL
        LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE
        LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE
        LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE
        LD      A,(HL)
        LD      (DE),A
        RET
