DIAG_SEG_TABLE:
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

DIGIT_MASK_TABLE:
        DB      0x20
        DB      0x10
        DB      0x08
        DB      0x04
        DB      0x02
        DB      0x01

; Score delta per line-clear count. Index 0 unused (early-exit on count=0);
; counts >=4 clamp to entry 4 ('tetris').
CLEAR_SCORE_TABLE:
        DW      0, 100, 300, 500, 800

ROW_BIT_TABLE:
        DB      0x01
        DB      0x02
        DB      0x04
        DB      0x08
        DB      0x10
        DB      0x20
        DB      0x40
        DB      0x80

LCD_TEXT_RESET:
        DB      "PRESS ANY KEY",0

LCD_TEXT_NEXT:
        DB      "NEXT: ",0

LCD_TEXT_TETRO_RUNNING:
        DB      "TETRO RUNNING",0

LCD_TEXT_TETRO_PAUSED:
        DB      "TETRO PAUSED",0

LCD_TEXT_TETRO_GAME_OVER:
        DB      "TETRO GAME OVER",0

; LCD_SHOW_SCRIPT tables: null-terminated (DB row_cmd, DW text_ptr)+ DB 0
; HUD scripts leave the cursor at end of "NEXT: " on row 2 so the wrapper
; can append the dynamic preview letter via LCD_APPEND_NEXT_PREVIEW_LETTER.
SCRIPT_GAME_OVER:
        DB      LCD_ROW1
        DW      LCD_TEXT_TETRO_GAME_OVER
        DB      LCD_ROW2
        DW      LCD_TEXT_RESET
        DB      0

SCRIPT_PAUSED:
        DB      LCD_ROW1
        DW      LCD_TEXT_TETRO_PAUSED
        DB      LCD_ROW2
        DW      LCD_TEXT_NEXT
        DB      0

SCRIPT_SPLASH:
        DB      LCD_ROW1
        DW      LCD_TEXT_SPLASH_TITLE
        DB      LCD_ROW2
        DW      LCD_TEXT_SPLASH_MOVE
        DB      LCD_ROW3
        DW      LCD_TEXT_SPLASH_ROTATE
        DB      LCD_ROW4
        DW      LCD_TEXT_SPLASH_DROP
        DB      0

SCRIPT_RUNNING:
        DB      LCD_ROW1
        DW      LCD_TEXT_TETRO_RUNNING
        DB      LCD_ROW2
        DW      LCD_TEXT_NEXT
        DB      0

PIECE_NAME_TABLE:
        DB      'I','O','T','S','Z','J','L'

LCD_TEXT_SPLASH_TITLE:
        DB      "TETRO (PRESS A KEY)",0

LCD_TEXT_SPLASH_MOVE:
        DB      "< > MOVE",0

LCD_TEXT_SPLASH_ROTATE:
        DB      "AD/C ROTATE",0

LCD_TEXT_SPLASH_DROP:
        DB      "GO DROP 0 PAUSE",0

; Default 3x3-scale piece set with precomputed clockwise rotations.
; Shapes are centered in a 3x3 local frame where practical; the engine still
; stores them as 4 row bytes and shifts them horizontally at runtime.
PIECE_I_R0:
        DB      %00000000
        DB      %11100000
        DB      %00000000
        DB      %00000000
PIECE_I_R1:
        DB      %10000000
        DB      %10000000
        DB      %10000000
        DB      %00000000
PIECE_I_R2             EQU PIECE_I_R0
PIECE_I_R3             EQU PIECE_I_R1

PIECE_O_R0:
        DB      %11000000
        DB      %11000000
        DB      %00000000
        DB      %00000000
PIECE_O_R1            EQU PIECE_O_R0
PIECE_O_R2            EQU PIECE_O_R0
PIECE_O_R3            EQU PIECE_O_R0

PIECE_T_R0:
        DB      %11100000
        DB      %01000000
        DB      %00000000
        DB      %00000000
PIECE_T_R1:
        DB      %10000000
        DB      %11000000
        DB      %10000000
        DB      %00000000
PIECE_T_R2:
        DB      %00000000
        DB      %01000000
        DB      %11100000
        DB      %00000000
PIECE_T_R3:
        DB      %01000000
        DB      %11000000
        DB      %01000000
        DB      %00000000

; S/Z and J/L were previously swapped vs SRS lettering (same MSB-left row bytes,
; but labels did not match the canonical shapes named on LCD / previews).
PIECE_S_R0:
        DB      %11000000
        DB      %01100000
        DB      %00000000
        DB      %00000000
PIECE_S_R1:
        DB      %01000000
        DB      %11000000
        DB      %10000000
        DB      %00000000
PIECE_S_R2:
        DB      %00000000
        DB      %11000000
        DB      %01100000
        DB      %00000000
PIECE_S_R3            EQU PIECE_S_R1

PIECE_Z_R0:
        DB      %01100000
        DB      %11000000
        DB      %00000000
        DB      %00000000
PIECE_Z_R1:
        DB      %10000000
        DB      %11000000
        DB      %01000000
        DB      %00000000
PIECE_Z_R2:
        DB      %00000000
        DB      %01100000
        DB      %11000000
        DB      %00000000
PIECE_Z_R3            EQU PIECE_Z_R1

PIECE_J_R0:
        DB      %00100000
        DB      %11100000
        DB      %00000000
        DB      %00000000
PIECE_J_R1:
        DB      %10000000
        DB      %10000000
        DB      %11000000
        DB      %00000000
PIECE_J_R2:
        DB      %00000000
        DB      %11100000
        DB      %10000000
        DB      %00000000
PIECE_J_R3:
        DB      %11000000
        DB      %01000000
        DB      %01000000
        DB      %00000000

PIECE_L_R0:
        DB      %10000000
        DB      %11100000
        DB      %00000000
        DB      %00000000
PIECE_L_R1:
        DB      %11000000
        DB      %10000000
        DB      %10000000
        DB      %00000000
PIECE_L_R2:
        DB      %00000000
        DB      %11100000
        DB      %00100000
        DB      %00000000
PIECE_L_R3:
        DB      %01000000
        DB      %01000000
        DB      %11000000
        DB      %00000000

PIECE_PTR_TABLE:
        DW      PIECE_I_R0, PIECE_I_R1, PIECE_I_R2, PIECE_I_R3
        DW      PIECE_O_R0, PIECE_O_R1, PIECE_O_R2, PIECE_O_R3
        DW      PIECE_T_R0, PIECE_T_R1, PIECE_T_R2, PIECE_T_R3
        DW      PIECE_S_R0, PIECE_S_R1, PIECE_S_R2, PIECE_S_R3
        DW      PIECE_Z_R0, PIECE_Z_R1, PIECE_Z_R2, PIECE_Z_R3
        DW      PIECE_J_R0, PIECE_J_R1, PIECE_J_R2, PIECE_J_R3
        DW      PIECE_L_R0, PIECE_L_R1, PIECE_L_R2, PIECE_L_R3

PIECE_RIGHT_TABLE:
        DB      2,0,2,0
        DB      1,1,1,1
        DB      2,1,2,1
        DB      2,1,2,1
        DB      2,1,2,1
        DB      2,1,2,1
        DB      2,1,2,1

PIECE_COLOR_TABLE:
        DB      COLOR_GREEN+COLOR_BLUE              ; I = cyan
        DB      COLOR_RED+COLOR_GREEN+COLOR_BLUE   ; O  = white
        DB      COLOR_RED+COLOR_BLUE               ; T  = magenta
        DB      COLOR_GREEN                        ; S  = green
        DB      COLOR_RED                          ; Z  = red
        DB      COLOR_BLUE                         ; J  = blue
        DB      COLOR_RED+COLOR_GREEN              ; L  = yellow
