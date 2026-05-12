; TEC-1G matrix ports
PORT_DIGITS:    EQU     0x01
PORT_SEGS:      EQU     0x02
PORT_LCD_INST:  EQU     0x04
PORT_ROW:       EQU     0x05
PORT_RED:       EQU     0x06
PORT_LCD_DATA:  EQU     0x84
PORT_GREEN:     EQU     0xF8
PORT_BLUE:      EQU     0xF9

LCD_ROW1:       EQU     0x80
LCD_ROW2:       EQU     0xC0
LCD_ROW3:       EQU     0x94
LCD_ROW4:       EQU     0xD4

; MON-3 API / keypad constants
API_SCANKEYS:   EQU     16
K_LEFT:         EQU     0x10
K_RIGHT:        EQU     0x11
K_ROTATE:       EQU     0x12
K_ROTATE_CCW:   EQU     0x13
K_ROTATE_ALT:   EQU     0x03
K_ROTATE_CCW_ALT: EQU   0x02
K_DROP:         EQU     0x00
K_PAUSE:        EQU     0x0F
NO_KEY:         EQU     0xFF

; Matrix / display constants. ROW_COUNT is the 8x8 matrix dimension; the name
; is historical from TETRO's original single-game source layout.
ROW_COUNT:      EQU     8
BYTES_PER_ROW:  EQU     4
FRAMEBUFFER_BYTES: EQU  32
SCAN_MASK_START: EQU    0x01
COLOR_RED:      EQU     0x01
COLOR_GREEN:    EQU     0x02
COLOR_BLUE:     EQU     0x04
SPEAKER_BIT:    EQU     0x80
