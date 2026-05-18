; Score delta per line-clear count. Index 0 unused (early-exit on count=0);
; counts >=4 clamp to entry 4 ('tetris').
ClearScoreTbl:
        DW      0, 100, 300, 500, 800

RowBitTable:
        DB      0x01
        DB      0x02
        DB      0x04
        DB      0x08
        DB      0x10
        DB      0x20
        DB      0x40
        DB      0x80

LcdTextReset:
        DB      "PRESS ANY KEY",0

LcdTextNext:
        DB      "NEXT: ",0

LcdTextTetRun:
        DB      "TETRO RUNNING",0

LcdTextTetPause:
        DB      "TETRO PAUSED",0

LcdTextTetOver:
        DB      "TETRO GAME OVER",0

; LcdScript tables: null-terminated (DB row_cmd, DW text_ptr)+ DB 0
; HUD scripts leave the cursor at end of "NEXT: " on row 2 so the wrapper
; can append the dynamic preview letter via LcdAppendPrev.
ScriptGameOver:
        DB      LcdRow1
        DW      LcdTextTetOver
        DB      LcdRow2
        DW      LcdTextReset
        DB      0

ScriptPaused:
        DB      LcdRow1
        DW      LcdTextTetPause
        DB      LcdRow2
        DW      LcdTextNext
        DB      0

ScriptSplash:
        DB      LcdRow1
        DW      LcdTextSplash1
        DB      LcdRow2
        DW      LcdTextSplash2
        DB      LcdRow3
        DW      LcdTextSplash3
        DB      LcdRow4
        DW      LcdTextSplash4
        DB      0

ScriptRunning:
        DB      LcdRow1
        DW      LcdTextTetRun
        DB      LcdRow2
        DW      LcdTextNext
        DB      0

PieceNameTable:
        DB      'I','O','T','S','Z','J','L'

LcdTextSplash1:
        DB      "TETRO (PRESS A KEY)",0

LcdTextSplash2:
        DB      "< > MOVE",0

LcdTextSplash3:
        DB      "AD/C ROTATE",0

LcdTextSplash4:
        DB      "GO DROP 0 PAUSE",0

; Default 3x3-scale piece set with precomputed clockwise rotations.
; Shapes are centered in a 3x3 local frame where practical; the engine still
; stores them as 4 row bytes and shifts them horizontally at runtime.
PieceIR0:
        DB      %00000000
        DB      %11100000
        DB      %00000000
        DB      %00000000
PieceIR1:
        DB      %10000000
        DB      %10000000
        DB      %10000000
        DB      %00000000
PieceIR2             EQU PieceIR0
PieceIR3             EQU PieceIR1

PieceOR0:
        DB      %11000000
        DB      %11000000
        DB      %00000000
        DB      %00000000
PieceOR1            EQU PieceOR0
PieceOR2            EQU PieceOR0
PieceOR3            EQU PieceOR0

PieceTR0:
        DB      %11100000
        DB      %01000000
        DB      %00000000
        DB      %00000000
PieceTR1:
        DB      %10000000
        DB      %11000000
        DB      %10000000
        DB      %00000000
PieceTR2:
        DB      %00000000
        DB      %01000000
        DB      %11100000
        DB      %00000000
PieceTR3:
        DB      %01000000
        DB      %11000000
        DB      %01000000
        DB      %00000000

; S/Z and J/L were previously swapped vs SRS lettering (same MSB-left row bytes,
; but labels did not match the canonical shapes named on LCD / previews).
PieceSR0:
        DB      %11000000
        DB      %01100000
        DB      %00000000
        DB      %00000000
PieceSR1:
        DB      %01000000
        DB      %11000000
        DB      %10000000
        DB      %00000000
PieceSR2:
        DB      %00000000
        DB      %11000000
        DB      %01100000
        DB      %00000000
PieceSR3            EQU PieceSR1

PieceZR0:
        DB      %01100000
        DB      %11000000
        DB      %00000000
        DB      %00000000
PieceZR1:
        DB      %10000000
        DB      %11000000
        DB      %01000000
        DB      %00000000
PieceZR2:
        DB      %00000000
        DB      %01100000
        DB      %11000000
        DB      %00000000
PieceZR3            EQU PieceZR1

PieceJR0:
        DB      %00100000
        DB      %11100000
        DB      %00000000
        DB      %00000000
PieceJR1:
        DB      %10000000
        DB      %10000000
        DB      %11000000
        DB      %00000000
PieceJR2:
        DB      %00000000
        DB      %11100000
        DB      %10000000
        DB      %00000000
PieceJR3:
        DB      %11000000
        DB      %01000000
        DB      %01000000
        DB      %00000000

PieceLR0:
        DB      %10000000
        DB      %11100000
        DB      %00000000
        DB      %00000000
PieceLR1:
        DB      %11000000
        DB      %10000000
        DB      %10000000
        DB      %00000000
PieceLR2:
        DB      %00000000
        DB      %11100000
        DB      %00100000
        DB      %00000000
PieceLR3:
        DB      %01000000
        DB      %01000000
        DB      %11000000
        DB      %00000000

PiecePtrTable:
        DW      PieceIR0, PieceIR1, PieceIR2, PieceIR3
        DW      PieceOR0, PieceOR1, PieceOR2, PieceOR3
        DW      PieceTR0, PieceTR1, PieceTR2, PieceTR3
        DW      PieceSR0, PieceSR1, PieceSR2, PieceSR3
        DW      PieceZR0, PieceZR1, PieceZR2, PieceZR3
        DW      PieceJR0, PieceJR1, PieceJR2, PieceJR3
        DW      PieceLR0, PieceLR1, PieceLR2, PieceLR3

PieceRightTbl:
        DB      2,0,2,0
        DB      1,1,1,1
        DB      2,1,2,1
        DB      2,1,2,1
        DB      2,1,2,1
        DB      2,1,2,1
        DB      2,1,2,1

PieceColorTbl:
        DB      ColorCyan                         ; I = cyan
        DB      ColorWhite                        ; O  = white
        DB      ColorMagenta                      ; T  = magenta
        DB      ColorGreen                        ; S  = green
        DB      ColorRed                          ; Z  = red
        DB      ColorBlue                         ; J  = blue
        DB      ColorYellow                       ; L  = yellow
