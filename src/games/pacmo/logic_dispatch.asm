; Run one Pacmo logic slice per main-loop pass.
; LOGIC_TICK
; Input:
;   uses LOGIC_SLICE from RAM
; Output:
;   slice 0 polls movement; slices 0..7 clear/render/copy the framebuffer
; Clobbers:
;   A, HL, and registers clobbered by called slice routines
LOGIC_TICK:
        LD      A,(LOGIC_SLICE)
        AND     7
        JR      Z,LOGIC_SL0
        CP      1
        JP      Z,LOGIC_SL1
        CP      7
        JP      Z,LOGIC_SL7
        ADD     A,A
        ADD     A,A
        CALL    CLEAR_BACK_4
        JR      LOGIC_SLICE_NEXT

LOGIC_SL0:
        CALL    POLL_INPUT_AND_UPDATE
        CALL    TICK_LEVEL_COMPLETE_GATE
        CALL    TICK_POWER_TIMER
        XOR     A
        CALL    CLEAR_BACK_4
        JR      LOGIC_SLICE_NEXT

LOGIC_SL1:
        CALL    TICK_ENEMY
        CALL    PACMO_CHECK_PLAYER_CAUGHT
        LD      A,4
        CALL    CLEAR_BACK_4
        JR      LOGIC_SLICE_NEXT

LOGIC_SL7:
        LD      A,28
        CALL    CLEAR_BACK_4
        CALL    RENDER_WORLD_TO_BACK
        CALL    RENDER_POWER_PILLS_TO_BACK
        CALL    RENDER_ENEMY_TO_BACK
        CALL    RENDER_PLAYER_TO_BACK
        CALL    COPY_BACK_TO_FRONT
        JR      LOGIC_SLICE_NEXT

LOGIC_SLICE_NEXT:
        LD      HL,LOGIC_SLICE
        LD      A,(HL)
        INC     A
        AND     7
        LD      (HL),A
        RET

; TICK_LEVEL_COMPLETE_GATE
; Input:
;   PACMO_ROUND_COMPLETE, PACMO_LEVEL_COMPLETE_GATE_LO/HI
; Output:
;   when a completed-level delay expires, advances and initializes next level
; Clobbers:
;   A, HL while waiting; A, BC, DE, HL when advancing the level
TICK_LEVEL_COMPLETE_GATE:
        LD      A,(PACMO_ROUND_COMPLETE)
        OR      A
        RET     Z
        LD      HL,(PACMO_LEVEL_COMPLETE_GATE_LO)
        LD      A,H
        OR      L
        JP      Z,PACMO_ADVANCE_LEVEL
        DEC     HL
        LD      (PACMO_LEVEL_COMPLETE_GATE_LO),HL
        RET

; TICK_POWER_TIMER
; Input:
;   PACMO_POWER_TIMER_LO/HI
; Output:
;   decrements 16-bit PACMO_POWER_TIMER by one when nonzero; restores
;   running LCD status when power mode expires
; Clobbers:
;   A, DE, HL
TICK_POWER_TIMER:
        LD      HL,(PACMO_POWER_TIMER_LO)
        LD      A,H
        OR      L
        RET     Z
        DEC     HL
        LD      (PACMO_POWER_TIMER_LO),HL
        LD      A,H
        OR      L
        RET     NZ
        LD      A,PACMO_ENEMY_STATE_ATTACK
        LD      (ENEMY_STATE),A
        JP      LCD_SHOW_PACMO_RUNNING

; TICK_ENEMY
; Input:
;   ENEMY_X, ENEMY_DIR, ENEMY_TIMER, ENEMY_RESPAWN_TIMER
; Output:
;   enemy roams to an open adjacent cell when ENEMY_TIMER reaches zero;
;   respawning enemy counts down, then returns to the patrol start
; Clobbers:
;   A, BC, DE, HL
TICK_ENEMY:
        LD      A,(PACMO_SPLASH_ACTIVE)
        OR      A
        RET     NZ
        LD      A,(PACMO_PLAYER_CAUGHT)
        OR      A
        RET     NZ
        LD      A,(PACMO_ROUND_COMPLETE)
        OR      A
        RET     NZ
        CALL    TICK_ENEMY_RESPAWN
        RET     C
        LD      HL,ENEMY_TIMER
        LD      A,(HL)
        DEC     A
        LD      (HL),A
        RET     NZ
        LD      A,(ENEMY_PERIOD_CURRENT)
        LD      (HL),A
        JP      ENEMY_ROAM_STEP

; ENEMY_ROAM_STEP
; Input:
;   ENEMY_X/Y, ENEMY_DIR, PACMO_LEVEL
; Output:
;   ENEMY_X/Y updated to one open adjacent cell; ENEMY_DIR set to movement
;   direction. Immediate reversal is used only when no other direction is open.
; Clobbers:
;   A, BC, DE, HL
ENEMY_ROAM_STEP:
        LD      A,(ENEMY_X)
        LD      B,A
        LD      A,(ENEMY_Y)
        LD      C,A
        LD      A,(ENEMY_DIR)
        CALL    ENEMY_OPPOSITE_DIR
        LD      D,A                     ; D = reverse direction fallback
        LD      A,B
        ADD     A,C
        LD      E,A
        LD      A,(PACMO_LEVEL)
        ADD     A,E
        LD      E,A
        LD      A,(ENEMY_DIR)
        ADD     A,E
        AND     0x03
        INC     A                       ; A = first candidate direction, 1..4
        LD      E,A
        LD      H,4
ENEMY_ROAM_TRY_LOOP:
        LD      A,E
        CP      D
        JR      Z,ENEMY_ROAM_NEXT_CANDIDATE
        PUSH    DE
        PUSH    HL
        CALL    ENEMY_TRY_MOVE_DIR
        POP     HL
        POP     DE
        RET     C
ENEMY_ROAM_NEXT_CANDIDATE:
        INC     E
        LD      A,E
        CP      5
        JR      C,ENEMY_ROAM_CANDIDATE_READY
        LD      E,1
ENEMY_ROAM_CANDIDATE_READY:
        DEC     H
        JR      NZ,ENEMY_ROAM_TRY_LOOP
        LD      A,D
        CALL    ENEMY_TRY_MOVE_DIR
        RET

; ENEMY_OPPOSITE_DIR
; Input:
;   A = PACMO_DIR_*
; Output:
;   A = opposite PACMO_DIR_*
; Clobbers:
;   A
ENEMY_OPPOSITE_DIR:
        CP      PACMO_DIR_UP
        JR      Z,ENEMY_OPPOSITE_DOWN
        CP      PACMO_DIR_DOWN
        JR      Z,ENEMY_OPPOSITE_UP
        CP      PACMO_DIR_LEFT
        JR      Z,ENEMY_OPPOSITE_RIGHT
        LD      A,PACMO_DIR_LEFT
        RET
ENEMY_OPPOSITE_DOWN:
        LD      A,PACMO_DIR_DOWN
        RET
ENEMY_OPPOSITE_UP:
        LD      A,PACMO_DIR_UP
        RET
ENEMY_OPPOSITE_RIGHT:
        LD      A,PACMO_DIR_RIGHT
        RET

; ENEMY_TRY_MOVE_DIR
; Input:
;   A = PACMO_DIR_* candidate
; Output:
;   Carry set when move succeeds; ENEMY_X/Y and ENEMY_DIR committed.
;   Carry clear when candidate is out of bounds or a wall.
; Clobbers:
;   A, BC, DE, HL
ENEMY_TRY_MOVE_DIR:
        LD      E,A
        LD      A,(ENEMY_X)
        LD      B,A
        LD      A,(ENEMY_Y)
        LD      C,A
        LD      A,E
        CP      PACMO_DIR_LEFT
        JR      Z,ENEMY_TRY_LEFT
        CP      PACMO_DIR_RIGHT
        JR      Z,ENEMY_TRY_RIGHT
        CP      PACMO_DIR_UP
        JR      Z,ENEMY_TRY_UP
        CP      PACMO_DIR_DOWN
        JR      Z,ENEMY_TRY_DOWN
        OR      A
        RET
ENEMY_TRY_LEFT:
        LD      A,B
        CP      PACMO_WORLD_MAX
        JR      NC,ENEMY_TRY_BLOCKED
        INC     B
        JR      ENEMY_TRY_COMMIT_IF_OPEN
ENEMY_TRY_RIGHT:
        LD      A,B
        OR      A
        JR      Z,ENEMY_TRY_BLOCKED
        DEC     B
        JR      ENEMY_TRY_COMMIT_IF_OPEN
ENEMY_TRY_UP:
        LD      A,C
        OR      A
        JR      Z,ENEMY_TRY_BLOCKED
        DEC     C
        JR      ENEMY_TRY_COMMIT_IF_OPEN
ENEMY_TRY_DOWN:
        LD      A,C
        CP      PACMO_WORLD_MAX
        JR      NC,ENEMY_TRY_BLOCKED
        INC     C
ENEMY_TRY_COMMIT_IF_OPEN:
        PUSH    DE
        CALL    PACMO_IS_WALL_AT_BC
        POP     DE
        JR      C,ENEMY_TRY_BLOCKED
        LD      A,B
        LD      (ENEMY_X),A
        LD      A,C
        LD      (ENEMY_Y),A
        LD      A,E
        LD      (ENEMY_DIR),A
        SCF
        RET
ENEMY_TRY_BLOCKED:
        OR      A
        RET

; TICK_ENEMY_RESPAWN
; Input:
;   ENEMY_RESPAWN_TIMER
; Output:
;   Carry set while enemy is respawning; when the timer reaches zero,
;   enemy position and direction are reset and carry is cleared
; Clobbers:
;   A, DE, HL
TICK_ENEMY_RESPAWN:
        LD      HL,ENEMY_RESPAWN_TIMER
        LD      A,(HL)
        OR      A
        RET     Z
        DEC     A
        LD      (HL),A
        JR      Z,TICK_ENEMY_RESPAWN_DONE
        SCF
        RET
TICK_ENEMY_RESPAWN_DONE:
        LD      A,PACMO_ENEMY_STATE_ATTACK
        LD      (ENEMY_STATE),A
        LD      A,PACMO_ENEMY_MAX_X
        LD      (ENEMY_X),A
        LD      A,PACMO_ENEMY_Y
        LD      (ENEMY_Y),A
        LD      A,PACMO_DIR_RIGHT
        LD      (ENEMY_DIR),A
        LD      A,(ENEMY_PERIOD_CURRENT)
        LD      (ENEMY_TIMER),A
        CALL    LCD_SHOW_PACMO_RUNNING
        OR      A
        RET

; PACMO_ADVANCE_LEVEL
; Input:
;   PACMO_LEVEL, ENEMY_PERIOD_CURRENT
; Output:
;   level count incremented, enemy period reduced to its minimum, level restarted
; Clobbers:
;   A, BC, DE, HL
PACMO_ADVANCE_LEVEL:
        LD      HL,PACMO_LEVEL
        INC     (HL)
        LD      A,(ENEMY_PERIOD_CURRENT)
        CP      PACMO_ENEMY_PERIOD_MIN+PACMO_ENEMY_PERIOD_STEP
        JR      C,PACMO_ADVANCE_LEVEL_MIN
        SUB     PACMO_ENEMY_PERIOD_STEP
        LD      (ENEMY_PERIOD_CURRENT),A
        CALL    INIT_LEVEL_STATE
        JP      LCD_SHOW_PACMO_RUNNING
PACMO_ADVANCE_LEVEL_MIN:
        LD      A,PACMO_ENEMY_PERIOD_MIN
        LD      (ENEMY_PERIOD_CURRENT),A
        CALL    INIT_LEVEL_STATE
        JP      LCD_SHOW_PACMO_RUNNING
