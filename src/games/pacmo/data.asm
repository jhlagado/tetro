PACMO_WORLD_MAX: EQU    14
PACMO_VIEW_MAX:  EQU    7
PACMO_MOVE_PERIOD: EQU   16
PACMO_EATEN_BYTES: EQU  30
PACMO_DIR_UP:    EQU    1
PACMO_DIR_DOWN:  EQU    2
PACMO_DIR_LEFT:  EQU    3
PACMO_DIR_RIGHT: EQU    4

PACMO_KEY_5_NUMERIC: EQU 0x05
PACMO_KEY_5_RAW:     EQU 0x15
PACMO_KEY_5_ASCII:   EQU 0x35

DIGIT_MASK_TABLE:
        DB      0x20
        DB      0x10
        DB      0x08
        DB      0x04
        DB      0x02
        DB      0x01

; 15-bit scrolling test bitmap.  Bit 15 is world column 0; bit 1 is column 14.
; This is deliberately a visual pattern, not a colliding maze yet.
; Each row is stored high byte first, low byte second for RENDER_WORLD_TO_BACK.
PACMO_WORLD_ROWS:
        DB      %11111111,%11111110
        DB      %10000010,%00000010
        DB      %10111010,%11101010
        DB      %10001000,%00100010
        DB      %11101011,%10101110
        DB      %10000000,%10000010
        DB      %10111110,%10111010
        DB      %10000010,%00001010
        DB      %10111011,%11101010
        DB      %10001000,%00000010
        DB      %11101110,%11101110
        DB      %10000010,%00000010
        DB      %10111010,%11101010
        DB      %10000000,%00000010
        DB      %11111111,%11111110

; Power-pill coordinates, stored as x,y pairs and terminated by 0xFF.
; These are placed on open cells away from the player start and near broad
; maze regions so they are visible test landmarks before consumption exists.
PACMO_POWER_PILLS:
        DB      1,3
        DB      13,3
        DB      1,11
        DB      13,11
        DB      0xFF
