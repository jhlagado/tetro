; Generic double-buffer helpers for the 8x8 RGB matrix Framebuffer.

; FbClearAll
; Input:
;   none
; Output:
;   FramebufferBack cleared to zero
; Clobbers:
;   A, B, HL
FbClearAll:
        LD      HL,FramebufferBack
        LD      B,FramebufferBytes
        XOR     A
FbClrLoop:
        LD      (HL),A
        INC     HL
        DJNZ    FbClrLoop
        RET

; FbClearRow
; Input:
;   A = byte offset into FramebufferBack, expected 0,4,8,...,28
; Output:
;   selected 4-byte row cleared
; Clobbers:
;   A, DE, HL
FbClearRow:
        LD      E,A
        LD      D,0
        LD      HL,FramebufferBack
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

; FbCopyAll
; Input:
;   FramebufferBack contains completed image
; Output:
;   Framebuffer overwritten from FramebufferBack
; Clobbers:
;   BC, DE, HL
FbCopyAll:
        LD      HL,FramebufferBack
        LD      DE,Framebuffer
        LD      BC,FramebufferBytes
        LDIR
        RET

; FbCopyRow
; Input:
;   A = byte offset into both framebuffers, expected 0,4,8,...,28
; Output:
;   selected 4-byte row copied from FramebufferBack to Framebuffer
; Clobbers:
;   A, DE, HL
FbCopyRow:
        LD      E,A
        LD      D,0
        LD      HL,FramebufferBack
        ADD     HL,DE
        PUSH    HL
        LD      HL,Framebuffer
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
