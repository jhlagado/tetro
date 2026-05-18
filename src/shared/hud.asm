; Generic seven-segment HUD scan helpers.

; HudScanDig
; Input:
;   HudSegBuffer / HudScanIndex / SpeakerPort
; Output:
;   one seven-segment digit refreshed
; Clobbers:
;   A, BC, DE, HL
; Uses @clobbers A,BC,DE,HL,F while refreshing one HUD digit.
; Keeps @preserves IX,IY stable for the caller.
HudScanDig:
        LD      A,(HudScanIndex)
        LD      C,A
        LD      A,(SpeakerPort)
        OUT     (PortDigits),A
        LD      A,C
        LD      L,A
        LD      H,0
        LD      DE,HudSegBuffer
        ADD     HL,DE
        LD      A,(HL)
        OUT     (PortSegs),A

        LD      A,C
        LD      L,A
        LD      H,0
        LD      DE,HudMaskTbl
        ADD     HL,DE
        LD      A,(HL)
        LD      B,A
        LD      A,(SpeakerPort)
        OR      B
        OUT     (PortDigits),A

        LD      A,C
        INC     A
        CP      6
        JR      C,HudScanSave
        XOR     A
HudScanSave:
        LD      (HudScanIndex),A
        RET

; HudBlankDig
; Input:
;   none
; Output:
;   HudSegBuffer[0..5] = 0
; Clobbers:
;   A, B, HL
; Uses @clobbers A,B,HL,F while clearing the HUD digit buffer.
; Keeps @preserves C,DE,IX,IY stable for the caller.
HudBlankDig:
        LD      HL,HudSegBuffer
        LD      B,6
        XOR     A
HudBlankLp:
        LD      (HL),A
        INC     HL
        DJNZ    HudBlankLp
        RET

; HudWriteU16
; Input:
;   HL = unsigned 16-bit value
; Output:
;   HudSegBuffer[0] = zero glyph
;   HudSegBuffer[1..5] = decimal digits for 10000,1000,100,10,1
; Clobbers:
;   A, BC, DE, HL
; Accepts @in HL as the unsigned value.
; Uses @clobbers A,BC,DE,HL,F while formatting the decimal display.
; Keeps @preserves IX,IY stable for the caller.
HudWriteU16:
        LD      A,(HudGlyphTbl)
        LD      (HudSegBuffer),A
        LD      BC,HudSegBuffer + 1

        LD      DE,0x2710      ; 10000
        CALL    HudDecDigit
        LD      DE,0x03E8      ; 1000
        CALL    HudDecDigit
        LD      DE,0x0064      ; 100
        CALL    HudDecDigit
        LD      DE,0x000A      ; 10
        CALL    HudDecDigit
        LD      DE,0x0001      ; 1
        CALL    HudDecDigit
        RET

; HudDecDigit
; Accepts @in HL as the value remainder.
; Accepts @in DE as the decimal divisor.
; Accepts @in BC as destination digit in HudSegBuffer.
; Returns @out HL as the updated value remainder.
; Returns @out BC advanced to the next destination.
; Uses @clobbers A,DE,F while subtracting and formatting.
HudDecDigit:
        XOR     A
HudDecLp:
        PUSH    AF
        LD      A,H
        CP      D
        JR      C,HudDecDone
        JR      NZ,HudDecSub
        LD      A,L
        CP      E
        JR      C,HudDecDone
HudDecSub:
        POP     AF
        OR      A
        SBC     HL,DE
        INC     A
        JR      HudDecLp
HudDecDone:
        POP     AF
        PUSH    HL
        PUSH    BC
        LD      L,A
        LD      H,0
        LD      DE,HudGlyphTbl
        ADD     HL,DE
        LD      A,(HL)
        POP     BC
        LD      (BC),A
        INC     BC
        POP     HL
        RET

HudMaskTbl:
        DB      0x20
        DB      0x10
        DB      0x08
        DB      0x04
        DB      0x02
        DB      0x01

HudGlyphTbl:
        DB      0xEB
        DB      0x28
        DB      0xCD
        DB      0xAD
        DB      0x2E
        DB      0xA7
        DB      0xE7
        DB      0x29
        DB      0xEF
        DB      0x2F
        DB      0x6F
        DB      0xE6
        DB      0xC3
        DB      0xEC
        DB      0xC7
        DB      0x47
