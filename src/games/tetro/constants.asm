; TETRO gameplay tuning constants.
; These are intentionally game-local so new games can share hardware/display
; constants without inheriting TETRO's movement, gravity, scoring, or sounds.
MOVE_PERIOD:    EQU     16
DROP_PERIOD:    EQU     1
; Decremented once per full 8-slice pass (in slice 1). Larger = slower fall.
GRAVITY_PERIOD: EQU     160
GRAVITY_PERIOD_STEP1: EQU 148
GRAVITY_SCORE_STEP1_HI: EQU 0x07       ; 2000 decimal
GRAVITY_SCORE_STEP1_LO: EQU 0xD0
LINE_CLEAR_HOLD: EQU    24
; Logic passes (one per main loop) before PRESS ANY KEY during GAME_OVER - tune for wall time.
GAME_OVER_KEY_GATE_TICKS: EQU  0x0C00

RNG_SEED_INIT:  EQU     0x5A
X_MIN:          EQU     0
Y_MAX:          EQU     7
SPAWN_Y:        EQU     0xFD
PIECE_COUNT:    EQU     7

SOUND_ROTATE_LEN: EQU   24
SOUND_ROTATE_DIV: EQU   2
SOUND_LOCK_LEN: EQU     32
SOUND_LOCK_DIV: EQU     4
SOUND_CLEAR_LEN: EQU    72
SOUND_CLEAR_DIV: EQU    2
; Game over: noticeably longer tone than clears; DIV sets half-period in scan ticks.
SOUND_GAME_OVER_LEN: EQU 232
SOUND_GAME_OVER_DIV: EQU 8
; When key gate opens (PRESS ANY KEY window starts); short higher chirp.
SOUND_GAME_OVER_READY_LEN: EQU    36
SOUND_GAME_OVER_READY_DIV: EQU    3
