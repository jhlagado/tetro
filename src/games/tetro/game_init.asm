; INIT_STATE
; Input:
;   none
; Output:
;   initialized runtime state in RAM
; Clobbers:
;   A, BC, DE, HL
INIT_STATE:
        CALL    INIT_STATE_BASE
        LD      A,1
        LD      (SPLASH_TIMER),A
        CALL    LCD_SHOW_SPLASH
        JP      REBUILD_FRAMEBUFFER

; INIT_STATE_RESTART
; Input:
;   none
; Output:
;   initialized runtime state for immediate post-game restart
; Clobbers:
;   A, BC, DE, HL
INIT_STATE_RESTART:
        CALL    INIT_STATE_BASE
        XOR     A
        LD      (SPLASH_TIMER),A
        CALL    RNG_NEXT_PIECE
        LD      (NEXT_PIECE_INDEX),A
        CALL    SPAWN_ACTIVE_PIECE
        CALL    UPDATE_SCORE_DISPLAY
        CALL    LCD_SHOW_RUNNING
        JP      REBUILD_FRAMEBUFFER

; INIT_STATE_BASE
; Input:
;   none
; Output:
;   common runtime state initialized in RAM
; Clobbers:
;   A, B, HL
; Uses @clobbers A,B,HL while resetting common runtime RAM state.
INIT_STATE_BASE:
        LD      A,MOVE_PERIOD
        LD      (MOVE_COOLDOWN),A
        LD      A,GRAVITY_PERIOD
        LD      (CURRENT_GRAVITY_PERIOD),A
        LD      (GRAVITY_COOLDOWN),A

        XOR     A
        LD      (GAME_OVER),A
        LD      HL,0
        LD      (GAME_OVER_KEY_GATE_LO),HL
        LD      (ACTIVE_PIECE_ENABLED),A
        LD      (CLEAR_PENDING),A
        LD      (CLEAR_MASK),A
        LD      (CLEAR_TIMER),A
        LD      (DROP_LOCKOUT),A
        LD      (FRAME_PHASE),A
        LD      (LOGIC_SLICE),A
        LD      (PAUSED),A
        LD      (CURRENT_ROTATION),A
        LD      (CURRENT_PIECE_INDEX),A
        LD      (NEXT_PIECE_INDEX),A
        LD      (LINES_CLEARED_TOTAL),A
        LD      (SCORE_LO),A
        LD      (SCORE_HI),A
        LD      A,1
        LD      (INPUT_LOCKOUT),A
        LD      A,NO_KEY
        LD      (LAST_KEY),A
        XOR     A
        LD      (HUD_SCAN_INDEX),A
        LD      (SPEAKER_PORT_STATE),A
        LD      (SOUND_TIMER),A
        LD      (SOUND_DIVIDER_RELOAD),A
        LD      (SOUND_DIVIDER_COUNT),A

        LD      A,SCAN_MASK_START
        LD      (SCAN_MASK),A

        LD      HL,FRAMEBUFFER
        LD      (SCAN_PTR),HL

        CALL    CLEAR_BOARD
        CALL    BLANK_HUD_SCORE_DIGITS
        RET
