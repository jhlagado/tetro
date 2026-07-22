; TEC-1G 8x8 matrix duty-cycle staircase test.
; Direct entry at $4000. No MON-3 calls, no stack,
; no framebuffer, no HUD, no sound.
;
; Same scan structure as matrix-smoke, but each row's lit
; dwell shrinks down the display while the total row period
; stays constant. On real hardware (and on a duty-faithful
; display) the rows form a brightness staircase from near-full
; at the top to faint at the bottom. A duty-blind display
; renders all eight rows at identical brightness.

        .org     0x4000

        .include "../shared/constants.asm"

; Constant per-row period, in DJNZ counts: lit + dark = DwellTotal.
; Full display brightness corresponds to duty 1/8 of the scan, i.e.
; a lit count of DwellTotal (36) out of 8*36; the top row's 32/36
; of that is ~89% and each row steps down ~11% from there.
DwellTotal      .equ    0x24

.routine
Start:
        XOR     A
        OUT     (PortRow),A
        OUT     (PortRed),A
        OUT     (PortGreen),A
        OUT     (PortBlue),A

_ScanFrame:
        LD      HL,RowTable
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

        LD      A,(HL)
        LD      E,A
        INC     HL

        LD      A,D
        OUT     (PortRow),A

        LD      B,E
_LitLoop:
        DJNZ    _LitLoop

        XOR     A
        OUT     (PortRow),A

        LD      A,DwellTotal
        SUB     E
        LD      B,A
_DarkLoop:
        DJNZ    _DarkLoop

        LD      A,D
        RLC     A
        LD      D,A
        DEC     C
        JP      NZ,_ScanRow
        JP      _ScanFrame

; Per-row records: red, green, blue, lit dwell count.
RowTable:
        .db     0xff,0x00,0x00,0x20    ; red,     lit 32/36
        .db     0x00,0xff,0x00,0x1c    ; green,   lit 28/36
        .db     0x00,0x00,0xff,0x18    ; blue,    lit 24/36
        .db     0xff,0xff,0x00,0x14    ; yellow,  lit 20/36
        .db     0xff,0x00,0xff,0x10    ; magenta, lit 16/36
        .db     0x00,0xff,0xff,0x0c    ; cyan,    lit 12/36
        .db     0xff,0xff,0xff,0x08    ; white,   lit  8/36
        .db     0x55,0x55,0x55,0x04    ; grey,    lit  4/36
