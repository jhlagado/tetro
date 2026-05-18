; Tetro gameplay tuning constants.
; These are intentionally game-local so new games
; can share hardware/display
; constants without inheriting Tetro's movement,
; gravity, scoring, or sounds.
MovePeriod:    EQU     128
DropPeriod:    EQU     1
TetKeyLeftAlt: EQU 0x01
TetKeyDropAlt: EQU 0x02
TetKeyRightAlt: EQU 0x03
TetKeyRotAlt: EQU 0x06
; Decremented once per full 8-slice pass (in slice
; 1). Larger = slower fall.
GravityPeriod: EQU     160
GravPeriodStep1: EQU 148
GravScore1Hi: EQU 0x07       ; 2000 decimal
GravScore1Lo: EQU 0xD0
LineClearHold: EQU    24
; Logic passes (one per main loop) before PRESS
; ANY KEY during GameOver - tune for wall time.
GOverGateTicks: EQU  0x0C00

RngSeedInit:  EQU     0x5A
XMin:          EQU     0
YMax:          EQU     7
SpawnY:        EQU     0xFD
PieceCount:    EQU     7

SoundRotateLen: EQU   24
SoundRotateDiv: EQU   2
SoundLockLen: EQU     32
SoundLockDiv: EQU     4
SoundClearLen: EQU    72
SoundClearDiv: EQU    2
; Game over: noticeably longer tone than clears;
; DIV sets half-period in scan ticks.
SndGOverLen: EQU 232
SndGOverDiv: EQU 8
; When key gate opens (PRESS ANY KEY window
; starts); short higher chirp.
SndReadyLen: EQU    36
SndReadyDiv: EQU    3
