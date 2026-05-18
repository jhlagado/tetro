; Output one scanline, then advance persistent scan state.
; ScanTick
; Input:
;   uses ScanPtr / ScanMask from RAM
; Output:
;   one matrix row emitted to hardware ports
;   one seven-segment digit emitted to hardware ports
; Clobbers:
;   A, BC, DE, HL
; Uses @clobbers A,BC,DE,HL,F while scanning display and sound state.
; Keeps @preserves IX,IY stable for the caller.
ScanTick:
        XOR     A
        OUT     (PortRow),A

        LD      HL,(ScanPtr)

        LD      A,(HL)
        OUT     (PortRed),A
        INC     HL

        LD      A,(HL)
        OUT     (PortGreen),A
        INC     HL

        LD      A,(HL)
        OUT     (PortBlue),A

        LD      A,(ScanMask)
        OUT     (PortRow),A

        CALL    SndService
        CALL    HudScanDig
        CALL    ScanNext
        RET

; ScanNext
; Input:
;   uses ScanMask / ScanPtr from RAM
; Output:
;   updated ScanMask / ScanPtr
;   FramePhase: see ram.asm label — incremented once per full Framebuffer wrap only.
; Clobbers:
;   A, DE, HL
; Uses @clobbers A,DE,HL,F while advancing scan state.
; Keeps @preserves BC,IX,IY stable for the caller.
ScanNext:
        LD      A,(ScanMask)
        RLC     A
        LD      (ScanMask),A

        LD      HL,(ScanPtr)
        LD      DE,BytesPerRow
        ADD     HL,DE

        CP      ScanMaskStart
        JR      NZ,ScanSavePtr

        LD      HL,Framebuffer
        LD      A,(FramePhase)
        INC     A
        LD      (FramePhase),A

ScanSavePtr:
        LD      (ScanPtr),HL
        RET
