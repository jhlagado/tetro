PacWorldMax: EQU    14
PacViewMax:  EQU    7
PacMovePeriod: EQU   128
PacEatenBytes: EQU  30
PacPwrPillCount: EQU 4
PacPwrTimerSet: EQU 0x0600
PacPwrWarnMask: EQU 0x20
PacGOverTicks: EQU 0x0266
PacLvlDoneTicks: EQU 0x0300
PacLivesStart: EQU 3
PacScorePath: EQU 10
PacScorePower: EQU 50
PacScoreEnemy: EQU 200
PacSndPowerLen: EQU 64
PacSndPowerDiv: EQU 1
PacSndEatEnLen: EQU 96
PacSndEatEnDiv: EQU 4
PacSndCaughtLen: EQU 240
PacSndCaughtDiv: EQU 10
PacSndDoneLen: EQU 112
PacSndDoneDiv: EQU 2
PacColorWall: EQU ColorBlue
PacColorPath: EQU ColorGreen
PacColorPlayer: EQU ColorYellow
PacColorPwrPill: EQU ColorWhite
PacColorEnAtk: EQU ColorRed
PacColorEnFlee: EQU ColorMagenta
PacColorGOver: EQU ColorRed
PacColorCaught: EQU ColorRed
PacColorDone: EQU ColorWhite
PacColorRound: EQU ColorWhite
PacEnemyY: EQU 13
PacEnemyMinX: EQU 1
PacEnemyMaxX: EQU 13
PacEnemyPeriod: EQU 128
PacEnemyPerMin: EQU 56
PacEnemyPerStep: EQU 8
PacEnemyRespPer: EQU 192
PacEnemyRespDiv: EQU 3
PacEnemyAtk: EQU 0
PacEnemyFlee: EQU 1
PacEnemyRespawn: EQU 2
PacMonsterCount: EQU 3
MonsterX: EQU 0
MonsterY: EQU 1
MonsterDir: EQU 2
MonsterTimer: EQU 3
MonRespTimer: EQU 4
MonsterState: EQU 5
MonsterSize: EQU 6
PacDirUp:    EQU    1
PacDirDown:  EQU    2
PacDirLeft:  EQU    3
PacDirRight: EQU    4

PacKey1: EQU 0x01
PacKey2: EQU 0x02
PacKey3: EQU 0x03
PacKey6: EQU 0x06

LcdTextPacTitle:
        DB      "PACMO",0

LcdTextPacStart:
        DB      "PRESS ANY KEY",0

LcdTextPacKeys1:
        DB      "ARROWS OR 6/1/2/3",0

LcdTextPacKeys2:
        DB      "6 UP  2 DOWN",0

LcdTextPacRun:
        DB      "PACMO RUNNING",0

LcdTextPacPause:
        DB      "PACMO PAUSED",0

LcdTextPacPower:
        DB      "POWER MODE",0

LcdTextPacEaten:
        DB      "ENEMY EATEN",0

LcdTextPacLevel:
        DB      "LEVEL ",0

LcdTextPacLives:
        DB      "LIVES ",0

LcdTextPacCaught:
        DB      "PACMO CAUGHT",0

LcdTextPacOver:
        DB      "GAME OVER",0

LcdTextPacDone:
        DB      "LEVEL COMPLETE",0

LcdTextPacWait:
        DB      "WAIT...",0

PacLevelChars:
        DB      "0123456789ABCDEF"

ScriptPacSplash:
        DB      LcdRow1
        DW      LcdTextPacTitle
        DB      LcdRow2
        DW      LcdTextPacStart
        DB      LcdRow3
        DW      LcdTextPacKeys1
        DB      LcdRow4
        DW      LcdTextPacKeys2
        DB      0

ScriptPacRun:
        DB      LcdRow1
        DW      LcdTextPacRun
        DB      LcdRow2
        DW      LcdTextPacLevel
        DB      0

ScriptPacPause:
        DB      LcdRow1
        DW      LcdTextPacPause
        DB      LcdRow2
        DW      LcdTextPacLevel
        DB      0

ScriptPacPower:
        DB      LcdRow1
        DW      LcdTextPacPower
        DB      LcdRow2
        DW      LcdTextPacLevel
        DB      0

ScriptPacEaten:
        DB      LcdRow1
        DW      LcdTextPacEaten
        DB      LcdRow2
        DW      LcdTextPacLevel
        DB      0

ScriptPacCaught:
        DB      LcdRow1
        DW      LcdTextPacCaught
        DB      0

ScriptPacOver:
        DB      LcdRow1
        DW      LcdTextPacOver
        DB      LcdRow2
        DW      LcdTextPacStart
        DB      0

ScriptPacDone:
        DB      LcdRow1
        DW      LcdTextPacDone
        DB      LcdRow2
        DW      LcdTextPacWait
        DB      0

; 15-bit scrolling test bitmap.  Bit 15 is world column 0; bit 1 is column 14.
; This is deliberately a visual pattern, not a colliding maze yet.
; Each row is stored high byte first, low byte second for RendWorldBack.
PacWorldRows:
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
; These are placed on open cells away from the player Start and near broad
; maze regions so they are visible test landmarks before consumption exists.
PacPowerPills:
        DB      1,3
        DB      13,3
        DB      1,11
        DB      13,11
        DB      0xFF

; Enemy respawn candidates, stored as x,y pairs and terminated by 0xFF.
; All entries must be open maze cells.  The respawn routine picks the entry
; with the largest Manhattan distance from the current player position.
PacEnemySpawns:
        DB      1,3
        DB      13,3
        DB      1,11
        DB      13,11
        DB      7,1
        DB      7,13
        DB      0xFF
