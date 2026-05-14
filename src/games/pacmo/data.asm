PACMO_WORLD_MAX: EQU    14
PACMO_VIEW_MAX:  EQU    7
PACMO_MOVE_PERIOD: EQU   16
PACMO_EATEN_BYTES: EQU  30
PACMO_POWER_PILL_COUNT: EQU 4
PACMO_POWER_TIMER_START: EQU 0x0C00
PACMO_POWER_WARNING_BLINK_MASK: EQU 0x20
PACMO_GAME_OVER_GATE_TICKS: EQU 0x0C00
PACMO_LEVEL_COMPLETE_GATE_TICKS: EQU 0x0300
PACMO_SCORE_PATH: EQU 1
PACMO_SCORE_POWER: EQU 10
PACMO_SCORE_ENEMY: EQU 50
PACMO_COLOR_WALL: EQU COLOR_BLUE
PACMO_COLOR_PATH: EQU COLOR_GREEN
PACMO_COLOR_PLAYER: EQU COLOR_RED+COLOR_GREEN
PACMO_COLOR_POWER_PILL: EQU COLOR_RED+COLOR_GREEN+COLOR_BLUE
PACMO_COLOR_ENEMY_ATTACK: EQU COLOR_RED
PACMO_COLOR_ENEMY_FLEE: EQU COLOR_RED+COLOR_BLUE
PACMO_COLOR_GAME_OVER: EQU COLOR_RED
PACMO_COLOR_CAUGHT_WALL: EQU COLOR_RED
PACMO_COLOR_COMPLETE_WALL: EQU COLOR_RED+COLOR_GREEN+COLOR_BLUE
PACMO_COLOR_ROUND_COMPLETE: EQU COLOR_RED+COLOR_GREEN+COLOR_BLUE
PACMO_ENEMY_Y: EQU 13
PACMO_ENEMY_MIN_X: EQU 1
PACMO_ENEMY_MAX_X: EQU 13
PACMO_ENEMY_PERIOD: EQU 64
PACMO_ENEMY_PERIOD_MIN: EQU 28
PACMO_ENEMY_PERIOD_STEP: EQU 4
PACMO_ENEMY_RESPAWN_PERIOD: EQU 96
PACMO_DIR_UP:    EQU    1
PACMO_DIR_DOWN:  EQU    2
PACMO_DIR_LEFT:  EQU    3
PACMO_DIR_RIGHT: EQU    4

PACMO_KRIGHT: EQU 0x10
PACMO_KLEFT:  EQU 0x11
PACMO_KEY_5: EQU 0x05
PACMO_KEY_8: EQU 0x08
PACMO_KEY_0: EQU 0x00

LCD_TEXT_PACMO_TITLE:
        DB      "PACMO",0

LCD_TEXT_PACMO_START:
        DB      "PRESS ANY KEY",0

LCD_TEXT_PACMO_KEYS1:
        DB      "ARROWS OR 8/5/0",0

LCD_TEXT_PACMO_KEYS2:
        DB      "ADD UP  GO DOWN",0

LCD_TEXT_PACMO_RUNNING:
        DB      "PACMO RUNNING",0

LCD_TEXT_PACMO_POWER:
        DB      "POWER MODE",0

LCD_TEXT_PACMO_ENEMY_EATEN:
        DB      "ENEMY EATEN",0

LCD_TEXT_PACMO_LEVEL:
        DB      "LEVEL ",0

LCD_TEXT_PACMO_CAUGHT:
        DB      "PACMO CAUGHT",0

LCD_TEXT_PACMO_COMPLETE:
        DB      "LEVEL COMPLETE",0

LCD_TEXT_PACMO_WAIT:
        DB      "WAIT...",0

PACMO_LEVEL_CHAR_TABLE:
        DB      "0123456789ABCDEF"

SCRIPT_PACMO_SPLASH:
        DB      LCD_ROW1
        DW      LCD_TEXT_PACMO_TITLE
        DB      LCD_ROW2
        DW      LCD_TEXT_PACMO_START
        DB      LCD_ROW3
        DW      LCD_TEXT_PACMO_KEYS1
        DB      LCD_ROW4
        DW      LCD_TEXT_PACMO_KEYS2
        DB      0

SCRIPT_PACMO_RUNNING:
        DB      LCD_ROW1
        DW      LCD_TEXT_PACMO_RUNNING
        DB      LCD_ROW2
        DW      LCD_TEXT_PACMO_LEVEL
        DB      0

SCRIPT_PACMO_POWER:
        DB      LCD_ROW1
        DW      LCD_TEXT_PACMO_POWER
        DB      LCD_ROW2
        DW      LCD_TEXT_PACMO_LEVEL
        DB      0

SCRIPT_PACMO_ENEMY_EATEN:
        DB      LCD_ROW1
        DW      LCD_TEXT_PACMO_ENEMY_EATEN
        DB      LCD_ROW2
        DW      LCD_TEXT_PACMO_LEVEL
        DB      0

SCRIPT_PACMO_CAUGHT:
        DB      LCD_ROW1
        DW      LCD_TEXT_PACMO_CAUGHT
        DB      LCD_ROW2
        DW      LCD_TEXT_PACMO_START
        DB      0

SCRIPT_PACMO_COMPLETE:
        DB      LCD_ROW1
        DW      LCD_TEXT_PACMO_COMPLETE
        DB      LCD_ROW2
        DW      LCD_TEXT_PACMO_WAIT
        DB      0

DIGIT_MASK_TABLE:
        DB      0x20
        DB      0x10
        DB      0x08
        DB      0x04
        DB      0x02
        DB      0x01

PACMO_HEX_SEG_TABLE:
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
