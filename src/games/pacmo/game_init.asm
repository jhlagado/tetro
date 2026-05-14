; INIT_STATE
; Input:
;   none
; Output:
;   initializes Pacmo cursor, viewport, scan state, display buffers, and HUD
; Clobbers:
;   A, BC, DE, HL
INIT_STATE:
        XOR     A
        LD      (PACMO_SCORE),A
        LD      (PACMO_SCORE+1),A
        LD      A,1
        LD      (PACMO_LEVEL),A
        LD      A,PACMO_ENEMY_PERIOD
        LD      (ENEMY_PERIOD_CURRENT),A
        CALL    INIT_LEVEL_STATE
        LD      A,1
        LD      (PACMO_SPLASH_ACTIVE),A
        JP      LCD_SHOW_PACMO_SPLASH

; INIT_LEVEL_STATE
; Input:
;   PACMO_SCORE, PACMO_LEVEL, ENEMY_PERIOD_CURRENT
; Output:
;   initializes one Pacmo level without resetting score or level
; Clobbers:
;   A, BC, DE, HL
INIT_LEVEL_STATE:
        LD      A,7
        LD      (PLAYER_X),A
        LD      (PLAYER_Y),A
        LD      A,PACMO_ENEMY_MAX_X
        LD      (ENEMY_X),A
        LD      A,PACMO_ENEMY_Y
        LD      (ENEMY_Y),A
        LD      A,PACMO_ENEMY_DIR_RIGHT
        LD      (ENEMY_DIR),A
        LD      A,(ENEMY_PERIOD_CURRENT)
        LD      (ENEMY_TIMER),A

        LD      A,3
        LD      (VIEW_X),A
        LD      (VIEW_Y),A

        LD      A,PACMO_MOVE_PERIOD
        LD      (MOVE_COOLDOWN),A
        LD      A,NO_KEY
        LD      (LAST_KEY),A

        XOR     A
        LD      (PACMO_SPLASH_ACTIVE),A
        LD      (LOGIC_SLICE),A
        LD      (FRAME_PHASE),A
        LD      (HUD_SCAN_INDEX),A
        LD      (SPEAKER_PORT_STATE),A
        LD      (SOUND_TIMER),A
        LD      (PACMO_POWER_PILLS_EATEN),A
        LD      (PACMO_POWER_TIMER_LO),A
        LD      (PACMO_POWER_TIMER_HI),A
        LD      (ENEMY_RESPAWN_TIMER),A
        LD      (PACMO_ROUND_COMPLETE),A
        LD      (PACMO_PLAYER_CAUGHT),A
        LD      (PACMO_LEVEL_COMPLETE_GATE_LO),A
        LD      (PACMO_LEVEL_COMPLETE_GATE_HI),A
        LD      (PACMO_GAME_OVER_GATE_LO),A
        LD      (PACMO_GAME_OVER_GATE_HI),A

        LD      A,SCAN_MASK_START
        LD      (SCAN_MASK),A
        LD      HL,FRAMEBUFFER
        LD      (SCAN_PTR),HL

        CALL    CLEAR_FRONT_AND_BACK
        CALL    CLEAR_EATEN_PATHS
        LD      HL,(PACMO_SCORE)
        PUSH    HL
        LD      A,(PLAYER_X)
        LD      B,A
        LD      A,(PLAYER_Y)
        LD      C,A
        CALL    PACMO_MARK_EATEN_AT_BC
        POP     HL
        LD      (PACMO_SCORE),HL
        CALL    UPDATE_SCORE_DISPLAY
        JP      REBUILD_FRAMEBUFFER

; CLEAR_FRONT_AND_BACK
; Input:
;   none
; Output:
;   FRAMEBUFFER and FRAMEBUFFER_BACK cleared to zero
; Clobbers:
;   A, B, HL
CLEAR_FRONT_AND_BACK:
        LD      HL,FRAMEBUFFER
        LD      B,FRAMEBUFFER_BYTES*2
        XOR     A
CLEAR_FRONT_AND_BACK_LOOP:
        LD      (HL),A
        INC     HL
        DJNZ    CLEAR_FRONT_AND_BACK_LOOP
        RET

; CLEAR_EATEN_PATHS
; Input:
;   none
; Output:
;   PACMO_EATEN_ROWS cleared to zero
; Clobbers:
;   A, B, HL
CLEAR_EATEN_PATHS:
        LD      HL,PACMO_EATEN_ROWS
        LD      B,PACMO_EATEN_BYTES
        XOR     A
CLEAR_EATEN_PATHS_LOOP:
        LD      (HL),A
        INC     HL
        DJNZ    CLEAR_EATEN_PATHS_LOOP
        RET
