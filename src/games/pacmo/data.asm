PACMO_WORLD_MAX: EQU    14
PACMO_VIEW_MAX:  EQU    7
PACMO_MOVE_PERIOD: EQU   16

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
