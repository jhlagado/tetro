; Generic double-buffer helpers for the
; 8x8 RGB matrix Framebuffer.

; FbClearAll —
; Zero all of FramebufferBack.
; ========================== AZM
; out       HL,A,B,carry,zero
; ========================== AZM
FbClearAll:
        LD      HL,FramebufferBack
        LD      B,FramebufferBytes
        XOR     A
FbClrLoop:
        LD      (HL),A
        INC     HL
        DJNZ    FbClrLoop
        RET

; FbClearRow —
; Clear one RGB row in FramebufferBack.
; Row offset is 4 bytes per row: 0, 4, 8 … 28.
; ========================== AZM
; in        A
; out       carry
; clobbers  A,DE,HL
; ========================== AZM
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

; FbCopyAll —
; Copy FramebufferBack to the live Framebuffer.
; LDIR copies the full FramebufferBytes block.
; ========================== AZM
; clobbers  BC,DE,HL
; ========================== AZM
FbCopyAll:
        LD      HL,FramebufferBack
        LD      DE,Framebuffer
        LD      BC,FramebufferBytes
        LDIR
        RET

; FbCopyRow —
; Copy one RGB row from back to live Framebuffer.
; Row offset A is 4 bytes per row: 0, 4, 8 … 28.
; ========================== AZM
; in        A
; clobbers  A,DE,HL
; ========================== AZM
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
