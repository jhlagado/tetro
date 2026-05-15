; RAM layout.
; These bytes are mutable program state. INIT_STATE sets explicit defaults
; and clears the buffers that need a known startup value.
RAM_START:
PLAYER_X:
        DB      0

PLAYER_Y:
        DB      0

MOVE_COOLDOWN:
        DB      0

GRAVITY_COOLDOWN:
        DB      0

CURRENT_GRAVITY_PERIOD:
        DB      0

LAST_KEY:
        DB      0

PENDING_X:
        DB      0

PENDING_Y:
        DB      0

SHIFT_COUNT:
        DB      0

CURRENT_PIECE_PTR:
        DW      0

CURRENT_PIECE_INDEX:
        DB      0

CURRENT_ROTATION:
        DB      0

CURRENT_PIECE_RIGHT:
        DB      0

CURRENT_PIECE_COLOR:
        DB      0

NEXT_PIECE_INDEX:
        DB      0

PENDING_ROTATION:
        DB      0

PAUSED:
        DB      0

DROP_LOCKOUT:
        DB      0

GAME_OVER:
        DB      0

; 16-bit restart-delay countdown; LO is the 16-bit address used by
; LD HL,(GAME_OVER_KEY_GATE_LO) and written back as HL.
GAME_OVER_KEY_GATE:
        DW      0
GAME_OVER_KEY_GATE_LO   EQU     GAME_OVER_KEY_GATE
GAME_OVER_KEY_GATE_HI   EQU     GAME_OVER_KEY_GATE+1

ACTIVE_PIECE_ENABLED:
        DB      0

CLEAR_PENDING:
        DB      0

CLEAR_MASK:
        DB      0

CLEAR_TIMER:
        DB      0

LINES_CLEARED_TOTAL:
        DB      0

; 16-bit score (SCORE_LO is the low-byte address used by LD HL,(SCORE_LO);
; SCORE_HI is the high byte, cleared by INIT_STATE_BASE).
SCORE:
        DW      0
SCORE_LO        EQU     SCORE
SCORE_HI        EQU     SCORE+1

SPLASH_TIMER:
        DB      0

RNG_SEED:
        DB      0

INPUT_LOCKOUT:
        DB      0

HUD_SCAN_INDEX:
        DB      0

SPEAKER_PORT_STATE:
        DB      0

SOUND_TIMER:
        DB      0

SOUND_DIVIDER_RELOAD:
        DB      0

SOUND_DIVIDER_COUNT:
        DB      0

HUD_SEG_BUFFER:
        DS      6

; Full-matrix wrap counter: advanced in ADVANCE_SCAN_STATE when scan wraps to top of FRAMEBUFFER.
; Splash RNG seed helper only — not gravity / input / pacing (those use dedicated RAM timers).
FRAME_PHASE:
        DB      0

LOGIC_SLICE:
        DB      0

SCAN_MASK:
        DB      0

SCAN_PTR:
        DW      0

BOARD_ROWS:
        DS      ROW_COUNT

BOARD_RED:
        DS      ROW_COUNT

BOARD_GREEN:
        DS      ROW_COUNT

BOARD_BLUE:
        DS      ROW_COUNT

BOARD_EMPTY:
        DB      0

FRAMEBUFFER:
        DS      FRAMEBUFFER_BYTES

; Off-screen compose buffer; visible FB is updated atomically from here in slice 7.
FRAMEBUFFER_BACK:
        DS      FRAMEBUFFER_BYTES

RAM_END:
