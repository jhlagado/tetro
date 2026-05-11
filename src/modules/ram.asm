; RAM layout.
; These bytes are mutable program state. INIT_STATE sets explicit defaults
; and clears the buffers that need a known startup value.
RAM_START:
PLAYER_X:
        DS      1

PLAYER_Y:
        DS      1

MOVE_COOLDOWN:
        DS      1

GRAVITY_COOLDOWN:
        DS      1

CURRENT_GRAVITY_PERIOD:
        DS      1

LAST_KEY:
        DS      1

PENDING_X:
        DS      1

PENDING_Y:
        DS      1

SHIFT_COUNT:
        DS      1

CURRENT_PIECE_PTR:
        DS      2

CURRENT_PIECE_INDEX:
        DS      1

CURRENT_ROTATION:
        DS      1

CURRENT_PIECE_RIGHT:
        DS      1

CURRENT_PIECE_COLOR:
        DS      1

NEXT_PIECE_INDEX:
        DS      1

PENDING_ROTATION:
        DS      1

PAUSED:
        DS      1

DROP_LOCKOUT:
        DS      1

GAME_OVER:
        DS      1

; 16-bit restart-delay countdown; LO is the 16-bit address used by
; LD HL,(GAME_OVER_KEY_GATE_LO) and written back as HL.
GAME_OVER_KEY_GATE:
        DS      2
GAME_OVER_KEY_GATE_LO   EQU     GAME_OVER_KEY_GATE
GAME_OVER_KEY_GATE_HI   EQU     GAME_OVER_KEY_GATE+1

ACTIVE_PIECE_ENABLED:
        DS      1

CLEAR_PENDING:
        DS      1

CLEAR_MASK:
        DS      1

CLEAR_TIMER:
        DS      1

LINES_CLEARED_TOTAL:
        DS      1

; 16-bit score (SCORE_LO is the low-byte address used by LD HL,(SCORE_LO);
; SCORE_HI is the high byte, cleared by INIT_STATE_BASE).
SCORE:
        DS      2
SCORE_LO        EQU     SCORE
SCORE_HI        EQU     SCORE+1

SPLASH_TIMER:
        DS      1

RNG_SEED:
        DS      1

INPUT_LOCKOUT:
        DS      1

HUD_SCAN_INDEX:
        DS      1

SPEAKER_PORT_STATE:
        DS      1

SOUND_TIMER:
        DS      1

SOUND_DIVIDER_RELOAD:
        DS      1

SOUND_DIVIDER_COUNT:
        DS      1

HUD_SEG_BUFFER:
        DS      6

; Full-matrix wrap counter: advanced in ADVANCE_SCAN_STATE when scan wraps to top of FRAMEBUFFER.
; Splash RNG seed helper only — not gravity / input / pacing (those use dedicated RAM timers).
FRAME_PHASE:
        DS      1

LOGIC_SLICE:
        DS      1

SCAN_MASK:
        DS      1

SCAN_PTR:
        DS      2

BOARD_ROWS:
        DS      ROW_COUNT

BOARD_RED:
        DS      ROW_COUNT

BOARD_GREEN:
        DS      ROW_COUNT

BOARD_BLUE:
        DS      ROW_COUNT

BOARD_EMPTY:
        DS      1

FRAMEBUFFER:
        DS      FRAMEBUFFER_BYTES

; Off-screen compose buffer; visible FB is updated atomically from here in slice 7.
FRAMEBUFFER_BACK:
        DS      FRAMEBUFFER_BYTES

RAM_END:
