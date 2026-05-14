; Poll keypad and move the Pacmo cursor at a controlled repeat rate.
;
; Direction mapping for this first scrolling experiment:
;   PACMO_KLEFT  (0x11) = left
;   PACMO_KRIGHT (0x10) = right
;   ADD     (0x13) = up
;   GO      (0x12) = down
;   key 5   (0x05) = right
;   key 8   (0x08) = up
;   key 0   (0x00) = down
;
; Raw keypad codes are normalized into PACMO_DIR_* intents before movement
; dispatch. Later game logic should consume directions, not physical keys.
;
; POLL_INPUT_AND_UPDATE
; Input:
;   none
; Output:
;   may update PLAYER_X/Y, VIEW_X/Y, MOVE_COOLDOWN, LAST_KEY
; Clobbers:
;   A, BC, DE, HL
POLL_INPUT_AND_UPDATE:
        LD      A,(PACMO_PLAYER_CAUGHT)
        OR      A
        JP      NZ,POLL_CAUGHT_RESTART
        LD      C,API_SCANKEYS
        RST     0x10
        JP      NZ,CLEAR_INPUT_REPEAT_STATE

        CALL    NORMALIZE_INPUT_TO_DIRECTION
        JR      C,HANDLE_DIRECTION_KEY
        JR      CLEAR_INPUT_REPEAT_STATE

; POLL_CAUGHT_RESTART
; Input:
;   PACMO_PLAYER_CAUGHT is nonzero
; Output:
;   waits for PACMO_GAME_OVER_GATE, then restarts Pacmo through INIT_STATE
;   when any key is pressed
; Clobbers:
;   A, BC, DE, HL when restarting; A, C, HL otherwise
POLL_CAUGHT_RESTART:
        LD      HL,(PACMO_GAME_OVER_GATE_LO)
        LD      A,H
        OR      L
        JR      Z,POLL_CAUGHT_RESTART_KEY
        DEC     HL
        LD      (PACMO_GAME_OVER_GATE_LO),HL
        RET
POLL_CAUGHT_RESTART_KEY:
        LD      C,API_SCANKEYS
        RST     0x10
        RET     NZ
        JP      INIT_STATE

HANDLE_DIRECTION_KEY:
        LD      A,(LAST_KEY)
        CP      E
        JR      Z,HELD_SAME_KEY

        LD      A,E
        LD      (LAST_KEY),A
        LD      A,1
        LD      (MOVE_COOLDOWN),A

HELD_SAME_KEY:
        LD      A,(MOVE_COOLDOWN)
        DEC     A
        LD      (MOVE_COOLDOWN),A
        RET     NZ

        LD      A,PACMO_MOVE_PERIOD
        LD      (MOVE_COOLDOWN),A

        LD      A,E
        CP      PACMO_DIR_LEFT
        JR      Z,MOVE_PLAYER_LEFT
        CP      PACMO_DIR_RIGHT
        JR      Z,MOVE_PLAYER_RIGHT
        CP      PACMO_DIR_UP
        JR      Z,MOVE_PLAYER_UP
        CP      PACMO_DIR_DOWN
        JR      Z,MOVE_PLAYER_DOWN
        RET

; NORMALIZE_INPUT_TO_DIRECTION
; Input:
;   A = raw MON-3 keypad code from API_SCANKEYS
; Output:
;   Carry set and E = PACMO_DIR_* for accepted movement keys
;   Carry clear if the key is not a Pacmo movement key
; Clobbers:
;   A, E
NORMALIZE_INPUT_TO_DIRECTION:
        CP      PACMO_KLEFT
        JR      Z,NORMALIZE_LEFT
        CP      PACMO_KRIGHT
        JR      Z,NORMALIZE_RIGHT
        CP      PACMO_KEY_5
        JR      Z,NORMALIZE_RIGHT
        CP      K_ROTATE_CCW
        JR      Z,NORMALIZE_UP
        CP      PACMO_KEY_8
        JR      Z,NORMALIZE_UP
        CP      K_ROTATE
        JR      Z,NORMALIZE_DOWN
        CP      PACMO_KEY_0
        JR      Z,NORMALIZE_DOWN
        OR      A
        RET
NORMALIZE_LEFT:
        LD      E,PACMO_DIR_LEFT
        SCF
        RET
NORMALIZE_RIGHT:
        LD      E,PACMO_DIR_RIGHT
        SCF
        RET
NORMALIZE_UP:
        LD      E,PACMO_DIR_UP
        SCF
        RET
NORMALIZE_DOWN:
        LD      E,PACMO_DIR_DOWN
        SCF
        RET

; CLEAR_INPUT_REPEAT_STATE
; Input:
;   none
; Output:
;   resets repeat timing so the next valid key moves promptly
; Clobbers:
;   A
CLEAR_INPUT_REPEAT_STATE:
        LD      A,PACMO_MOVE_PERIOD
        LD      (MOVE_COOLDOWN),A
        LD      A,NO_KEY
        LD      (LAST_KEY),A
        RET

; MOVE_PLAYER_LEFT
; Input:
;   PLAYER_X
; Output:
;   moves visually left unless already at the mirrored horizontal edge or target is a wall
; Clobbers:
;   A, BC, DE, HL
MOVE_PLAYER_LEFT:
        LD      A,(PLAYER_X)
        CP      PACMO_WORLD_MAX
        RET     NC
        INC     A
        LD      B,A
        LD      A,(PLAYER_Y)
        LD      C,A
        JP      TRY_MOVE_PLAYER_TO_BC

; MOVE_PLAYER_RIGHT
; Input:
;   PLAYER_X
; Output:
;   moves visually right unless already at the mirrored horizontal edge or target is a wall
; Clobbers:
;   A, BC, DE, HL
MOVE_PLAYER_RIGHT:
        LD      A,(PLAYER_X)
        OR      A
        RET     Z
        DEC     A
        LD      B,A
        LD      A,(PLAYER_Y)
        LD      C,A
        JP      TRY_MOVE_PLAYER_TO_BC

; MOVE_PLAYER_UP
; Input:
;   PLAYER_Y
; Output:
;   decrements PLAYER_Y unless already at world row 0 or target is a wall
; Clobbers:
;   A, BC, DE, HL
MOVE_PLAYER_UP:
        LD      A,(PLAYER_Y)
        OR      A
        RET     Z
        DEC     A
        LD      C,A
        LD      A,(PLAYER_X)
        LD      B,A
        JP      TRY_MOVE_PLAYER_TO_BC

; MOVE_PLAYER_DOWN
; Input:
;   PLAYER_Y
; Output:
;   increments PLAYER_Y unless already at world row 14 or target is a wall
; Clobbers:
;   A, BC, DE, HL
MOVE_PLAYER_DOWN:
        LD      A,(PLAYER_Y)
        CP      PACMO_WORLD_MAX
        RET     NC
        INC     A
        LD      C,A
        LD      A,(PLAYER_X)
        LD      B,A
        JP      TRY_MOVE_PLAYER_TO_BC

; TRY_MOVE_PLAYER_TO_BC
; Input:
;   B = candidate world x
;   C = candidate world y
; Output:
;   if target is open, PLAYER_X/Y committed and viewport adjusted
;   if target is a wall, PLAYER_X/Y unchanged
; Clobbers:
;   A, BC, DE, HL
TRY_MOVE_PLAYER_TO_BC:
        CALL    PACMO_IS_WALL_AT_BC
        RET     C
        LD      A,B
        LD      (PLAYER_X),A
        LD      A,C
        LD      (PLAYER_Y),A
        CALL    PACMO_CONSUME_POWER_PILL_AT_BC
        CALL    PACMO_MARK_EATEN_AT_BC
        CALL    PACMO_CHECK_ROUND_COMPLETE
        CALL    PACMO_CHECK_PLAYER_CAUGHT
        JP      UPDATE_VIEWPORT_FOR_PLAYER

; PACMO_CHECK_PLAYER_CAUGHT
; Input:
;   PLAYER_X/Y, ENEMY_X/Y, PACMO_POWER_TIMER, ENEMY_RESPAWN_TIMER
; Output:
;   PACMO_PLAYER_CAUGHT = 1 when player and active enemy occupy the same world cell
;   outside power mode; in power mode, enemy is consumed and starts respawning
; Clobbers:
;   A, BC, DE, HL when the enemy is consumed or game-over is entered;
;   A, B otherwise
PACMO_CHECK_PLAYER_CAUGHT:
        LD      A,(PACMO_PLAYER_CAUGHT)
        OR      A
        RET     NZ
        LD      A,(ENEMY_RESPAWN_TIMER)
        OR      A
        RET     NZ
        LD      A,(PLAYER_X)
        LD      B,A
        LD      A,(ENEMY_X)
        CP      B
        RET     NZ
        LD      A,(PLAYER_Y)
        LD      B,A
        LD      A,(ENEMY_Y)
        CP      B
        RET     NZ
        LD      A,(PACMO_POWER_TIMER)
        OR      A
        JR      NZ,PACMO_CONSUME_ENEMY
        JP      PACMO_ENTER_GAME_OVER

; PACMO_ENTER_GAME_OVER
; Input:
;   none
; Output:
;   PACMO_PLAYER_CAUGHT latched; restart gate loaded; framebuffer rebuilt
; Clobbers:
;   A, BC, DE, HL
PACMO_ENTER_GAME_OVER:
        LD      A,1
        LD      (PACMO_PLAYER_CAUGHT),A
        LD      HL,PACMO_GAME_OVER_GATE_TICKS
        LD      (PACMO_GAME_OVER_GATE_LO),HL
        JP      REBUILD_FRAMEBUFFER

; PACMO_CONSUME_ENEMY
; Input:
;   player and enemy occupy the same world cell while power mode is active
; Output:
;   enemy hidden until ENEMY_RESPAWN_TIMER expires; score increased
; Clobbers:
;   A, BC, DE, HL
PACMO_CONSUME_ENEMY:
        LD      A,PACMO_ENEMY_RESPAWN_PERIOD
        LD      (ENEMY_RESPAWN_TIMER),A
        LD      A,PACMO_SCORE_ENEMY
        JP      PACMO_ADD_SCORE_A

; PACMO_CONSUME_POWER_PILL_AT_BC
; Input:
;   B = world x coordinate
;   C = world y coordinate
; Output:
;   matching bit set in PACMO_POWER_PILLS_EATEN when B/C is a power-pill cell
; Clobbers:
;   A, D, E, HL
PACMO_CONSUME_POWER_PILL_AT_BC:
        LD      HL,PACMO_POWER_PILLS
        LD      D,1
PACMO_CONSUME_POWER_PILL_LOOP:
        LD      A,(HL)
        CP      0xFF
        RET     Z
        CP      B
        INC     HL
        JR      NZ,PACMO_CONSUME_POWER_PILL_NEXT
        LD      A,(HL)
        CP      C
        JR      NZ,PACMO_CONSUME_POWER_PILL_NEXT
        LD      A,(PACMO_POWER_PILLS_EATEN)
        AND     D
        RET     NZ
        LD      A,(PACMO_POWER_PILLS_EATEN)
        OR      D
        LD      (PACMO_POWER_PILLS_EATEN),A
        PUSH    BC
        LD      A,PACMO_SCORE_POWER
        CALL    PACMO_ADD_SCORE_A
        POP     BC
        LD      A,PACMO_POWER_TIMER_START
        LD      (PACMO_POWER_TIMER),A
        RET
PACMO_CONSUME_POWER_PILL_NEXT:
        INC     HL
        SLA     D
        JR      PACMO_CONSUME_POWER_PILL_LOOP

; PACMO_MARK_EATEN_AT_BC
; Input:
;   B = world x coordinate, expected 0..14
;   C = world y coordinate, expected 0..14
; Output:
;   corresponding bit set in PACMO_EATEN_ROWS
; Clobbers:
;   A, BC, DE, HL
PACMO_MARK_EATEN_AT_BC:
        LD      A,C
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,PACMO_EATEN_ROWS
        ADD     HL,DE

        LD      A,B
        CP      8
        JR      NC,PACMO_MARK_EATEN_LOW_BYTE
        CALL    SCREEN_X_TO_MASK
        LD      E,A
        LD      A,(HL)
        AND     E
        RET     NZ
        PUSH    HL
        PUSH    DE
        LD      A,PACMO_SCORE_PATH
        CALL    PACMO_ADD_SCORE_A
        POP     DE
        POP     HL
        LD      A,E
        OR      (HL)
        LD      (HL),A
        RET
PACMO_MARK_EATEN_LOW_BYTE:
        SUB     8
        INC     HL
        CALL    SCREEN_X_TO_MASK
        LD      E,A
        LD      A,(HL)
        AND     E
        RET     NZ
        PUSH    HL
        PUSH    DE
        LD      A,PACMO_SCORE_PATH
        CALL    PACMO_ADD_SCORE_A
        POP     DE
        POP     HL
        LD      A,E
        OR      (HL)
        LD      (HL),A
        RET

; PACMO_ADD_SCORE_A
; Input:
;   A = unsigned score increment
; Output:
;   PACMO_SCORE increased by A; HUD score display refreshed
; Clobbers:
;   A, BC, DE, HL
PACMO_ADD_SCORE_A:
        LD      E,A
        LD      D,0
        LD      HL,(PACMO_SCORE)
        ADD     HL,DE
        LD      (PACMO_SCORE),HL
        JP      UPDATE_SCORE_DISPLAY

; PACMO_CHECK_ROUND_COMPLETE
; Input:
;   PACMO_WORLD_ROWS / PACMO_EATEN_ROWS
; Output:
;   PACMO_ROUND_COMPLETE = 1 when every open cell has been consumed
; Clobbers:
;   A, B, DE, HL
PACMO_CHECK_ROUND_COMPLETE:
        LD      B,ROW_COUNT+7
        LD      DE,PACMO_WORLD_ROWS
        LD      HL,PACMO_EATEN_ROWS
PACMO_CHECK_ROUND_ROW:
        LD      A,(DE)
        OR      (HL)
        CP      0xFF
        RET     NZ
        INC     DE
        INC     HL
        LD      A,(DE)
        OR      (HL)
        OR      0x01                    ; bit 0 is outside the 15-column maze
        CP      0xFF
        RET     NZ
        INC     DE
        INC     HL
        DJNZ    PACMO_CHECK_ROUND_ROW
        LD      A,1
        LD      (PACMO_ROUND_COMPLETE),A
        RET

; PACMO_IS_WALL_AT_BC
; Input:
;   B = world x coordinate, expected 0..14
;   C = world y coordinate, expected 0..14
; Output:
;   Carry set if PACMO_WORLD_ROWS has a wall bit at (B,C)
;   Carry clear if the cell is open
; Clobbers:
;   A, DE, HL
PACMO_IS_WALL_AT_BC:
        LD      A,C
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,PACMO_WORLD_ROWS
        ADD     HL,DE
        LD      D,(HL)                  ; D = high byte, bit 7 is world column 0
        INC     HL
        LD      E,(HL)                  ; E = low byte, bit 1 is world column 14

        LD      A,B
        OR      A
        JR      Z,PACMO_WALL_TEST
PACMO_WALL_SHIFT_LOOP:
        SLA     E
        RL      D
        DEC     A
        JR      NZ,PACMO_WALL_SHIFT_LOOP
PACMO_WALL_TEST:
        BIT     7,D
        JR      Z,PACMO_WALL_OPEN
        SCF
        RET
PACMO_WALL_OPEN:
        OR      A
        RET

; UPDATE_VIEWPORT_FOR_PLAYER
; Input:
;   PLAYER_X/Y and VIEW_X/Y in RAM
; Output:
;   VIEW_X/Y adjusted so player screen position stays in cells 3..4 when
;   possible, then clamped to the 15x15 world / 8x8 viewport bounds.
; Clobbers:
;   A, B, C
UPDATE_VIEWPORT_FOR_PLAYER:
        LD      A,(PLAYER_X)
        LD      B,A
        LD      A,(VIEW_X)
        CALL    ADJUST_VIEW_AXIS
        LD      (VIEW_X),A

        LD      A,(PLAYER_Y)
        LD      B,A
        LD      A,(VIEW_Y)
        CALL    ADJUST_VIEW_AXIS
        LD      (VIEW_Y),A
        RET

; ADJUST_VIEW_AXIS
; Input:
;   A = current view origin for one axis
;   B = player coordinate on the same axis
; Output:
;   A = adjusted view origin, clamped to 0..7
; Clobbers:
;   C
ADJUST_VIEW_AXIS:
        LD      C,A
        LD      A,B
        SUB     C                       ; A = player screen coordinate
        CP      3
        JR      C,ADJUST_AXIS_SHIFT_LOW
        CP      5
        JR      NC,ADJUST_AXIS_SHIFT_HIGH
        LD      A,C
        RET
ADJUST_AXIS_SHIFT_LOW:
        LD      A,C
        OR      A
        RET     Z
        DEC     A
        RET
ADJUST_AXIS_SHIFT_HIGH:
        LD      A,C
        CP      PACMO_VIEW_MAX
        RET     NC
        INC     A
        RET
