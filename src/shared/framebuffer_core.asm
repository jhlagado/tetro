; Generic double-buffer helpers for the 8x8 RGB matrix framebuffer.

; CLEAR_BACK_ALL
; FRAMEBUFFER_BACK cleared to zero.
; @clobbers A,B,HL while clearing the back buffer.
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
; @in A byte offset into FRAMEBUFFER_BACK, expected 0,4,8,...,28.
; Selected 4-byte row cleared.
; @clobbers A,DE,HL while clearing the row.
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
; FRAMEBUFFER_BACK contains completed image.
; FRAMEBUFFER overwritten from FRAMEBUFFER_BACK.
; @clobbers BC,DE,HL while copying the whole back buffer.
COPY_BACK_TO_FRONT:
        LD      HL,FRAMEBUFFER_BACK
        LD      DE,FRAMEBUFFER
        LD      BC,FRAMEBUFFER_BYTES
        LDIR
        RET

; COPY_BACK_4_TO_FRONT
; @in A byte offset into both framebuffers, expected 0,4,8,...,28.
; Selected 4-byte row copied from FRAMEBUFFER_BACK to FRAMEBUFFER.
; @clobbers A,DE,HL while copying the selected row.
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
