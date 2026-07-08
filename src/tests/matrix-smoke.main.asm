; TEC-1G 8x8 matrix smoke test.
; Directly scans the RGB matrix without MON-3 input,
; framebuffer logic, HUD, sound, or game state.

        .org     0x4000

        .include "../shared/constants.asm"

@Start:
MainLoop:
        LD      HL,MatrixRows
        LD      C,ScanMaskStart
        LD      E,RowCount

RowLoop:
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

        LD      A,C
        OUT     (PortRow),A

        LD      B,255
DwellLoop:
        DJNZ    DwellLoop

        LD      A,C
        RLC     A
        LD      C,A
        DEC     E
        JR      NZ,RowLoop

        XOR     A
        OUT     (PortRow),A
        JR      MainLoop

MatrixRows:
        .db     0xFF,0x00,0x00
        .db     0x00,0xFF,0x00
        .db     0x00,0x00,0xFF
        .db     0xFF,0xFF,0x00
        .db     0x00,0xFF,0xFF
        .db     0xFF,0x00,0xFF
        .db     0x81,0x81,0x81
        .db     0xFF,0xFF,0xFF
