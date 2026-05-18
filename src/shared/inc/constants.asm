; TEC-1G matrix ports
PortDigits:    EQU     0x01
PortSegs:      EQU     0x02
PortLcdInst:  EQU     0x04
PortRow:       EQU     0x05
PortRed:       EQU     0x06
PortLcdData:  EQU     0x84
PortGreen:     EQU     0xF8
PortBlue:      EQU     0xF9

LcdRow1:       EQU     0x80
LcdRow2:       EQU     0xC0
LcdRow3:       EQU     0x94
LcdRow4:       EQU     0xD4

; MON-3 API / keypad constants
ApiScanKeys:   EQU     16
KeyLeft:         EQU     0x11
KeyRight:        EQU     0x10
KeyRotate:       EQU     0x12
KeyRotateCcw:   EQU     0x13
KeyRotateCw:    EQU     0x0C
KeyDrop:         EQU     0x00
KeyPause:        EQU     0x00
NoKey:         EQU     0xFF

; Matrix / display constants. RowCount is the 8x8 matrix dimension; the name
; is historical from Tetro's original single-game source layout.
RowCount:      EQU     8
BytesPerRow:  EQU     4
FramebufferBytes: EQU  32
ScanMaskStart: EQU    0x01
ColorBlack:    EQU     0x00
ColorRed:      EQU     0x01
ColorGreen:    EQU     0x02
ColorBlue:     EQU     0x04
ColorYellow:   EQU     ColorRed + ColorGreen
ColorCyan:     EQU     ColorGreen + ColorBlue
ColorMagenta:  EQU     ColorRed + ColorBlue
ColorWhite:    EQU     ColorRed + ColorGreen + ColorBlue
SpeakerBit:    EQU     0x80
