; TEC-1G 8x8 matrix persistence smoke test.
; Direct entry at $4000. No MON-3 calls, no stack,
; no framebuffer, no HUD, no sound.
;
; The test scans eight solid rows. Each row has a different
; RGB colour. If scan timing and Debug80 display sampling are
; usable, the matrix should settle into stable horizontal bands.

        .org     0x4000

        .include "../shared/constants.asm"

DwellOuter      .equ    0x01
DwellInner      .equ    0x20

.routine
Start:
        XOR     A
        OUT     (PortRow),A
        OUT     (PortRed),A
        OUT     (PortGreen),A
        OUT     (PortBlue),A

_ScanFrame:
        LD      HL,RowColours
        LD      D,ScanMaskStart
        LD      C,RowCount

_ScanRow:
        XOR     A
        OUT     (PortRow),A

        LD      A,(HL)
        OUT     (PortRed),A
        INC     HL

        LD      A,(HL)
        OUT     (PortGreen),A
        INC     HL

        LD      A,(HL)
        OUT     (PortBlue),A
        INC     HL

        LD      A,D
        OUT     (PortRow),A

        LD      E,DwellOuter
_DwellOuterLoop:
        LD      B,DwellInner
_DwellInnerLoop:
        DJNZ    _DwellInnerLoop
        DEC     E
        JP      NZ,_DwellOuterLoop

        XOR     A
        OUT     (PortRow),A

        LD      A,D
        RLC     A
        LD      D,A
        DEC     C
        JP      NZ,_ScanRow
        JP      _ScanFrame

RowColours:
        .db     0xff,0x00,0x00    ; red
        .db     0x00,0xff,0x00    ; green
        .db     0x00,0x00,0xff    ; blue
        .db     0xff,0xff,0x00    ; yellow
        .db     0xff,0x00,0xff    ; magenta
        .db     0x00,0xff,0xff    ; cyan
        .db     0xff,0xff,0xff    ; white
        .db     0x55,0x55,0x55    ; grey
