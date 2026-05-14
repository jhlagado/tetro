; Run one Pacmo logic slice per main-loop pass.
; LOGIC_TICK
; Input:
;   uses LOGIC_SLICE from RAM
; Output:
;   slice 0 polls movement; slices 0..7 clear/render/copy the framebuffer
; Clobbers:
;   A, BC, DE, HL, IX, and registers clobbered by called slice routines
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
        LD      IX,MONSTER0
        CALL    TICK_ENEMY
        LD      IX,MONSTER1
        CALL    TICK_ENEMY
        CALL    PACMO_IS_LEVEL2_PLUS
        JR      C,LOGIC_SL1_TICK_DONE
        LD      IX,MONSTER2
        CALL    TICK_ENEMY
LOGIC_SL1_TICK_DONE:
        LD      IX,MONSTER0
        CALL    PACMO_CHECK_PLAYER_CAUGHT
        LD      IX,MONSTER1
        CALL    PACMO_CHECK_PLAYER_CAUGHT
        CALL    PACMO_IS_LEVEL2_PLUS
        JR      C,LOGIC_SL1_COLLISION_DONE
        LD      IX,MONSTER2
        CALL    PACMO_CHECK_PLAYER_CAUGHT
LOGIC_SL1_COLLISION_DONE:
        LD      A,4
        CALL    CLEAR_BACK_4
        JR      LOGIC_SLICE_NEXT

LOGIC_SL7:
        LD      A,28
        CALL    CLEAR_BACK_4
        CALL    RENDER_WORLD_TO_BACK
        CALL    RENDER_POWER_PILLS_TO_BACK
        LD      IX,MONSTER0
        CALL    RENDER_ENEMY_TO_BACK
        LD      IX,MONSTER1
        CALL    RENDER_ENEMY_TO_BACK
        CALL    PACMO_IS_LEVEL2_PLUS
        JR      C,LOGIC_SL7_MONSTERS_DONE
        LD      IX,MONSTER2
        CALL    RENDER_ENEMY_TO_BACK
LOGIC_SL7_MONSTERS_DONE:
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
        LD      (ENEMY2_STATE),A
        LD      (ENEMY3_STATE),A
        JP      LCD_SHOW_PACMO_RUNNING

; PACMO_IS_LEVEL2_PLUS
; Input:
;   PACMO_LEVEL
; Output:
;   carry clear when level >= 2, carry set when level < 2
; Clobbers:
;   A
PACMO_IS_LEVEL2_PLUS:
        LD      A,(PACMO_LEVEL)
        CP      2
        RET

; TICK_ENEMY
; Input:
;   IX = monster record base
;   monster X/Y, direction, timer, state, respawn timer
; Output:
;   active enemy moves when its timer reaches zero; respawning enemy counts
;   down, then respawns at the selected candidate cell
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
        LD      A,(IX+MONSTER_TIMER)
        DEC     A
        LD      (IX+MONSTER_TIMER),A
        RET     NZ
        LD      A,(ENEMY_PERIOD_CURRENT)
        LD      (IX+MONSTER_TIMER),A
        LD      A,(IX+MONSTER_STATE)
        CP      PACMO_ENEMY_STATE_ATTACK
        JP      Z,ENEMY_ATTACK_STEP
        JP      ENEMY_ROAM_STEP

; ENEMY_ATTACK_STEP
; Input:
;   IX = monster record base
;   monster X/Y and direction, PLAYER_X/Y
; Output:
;   enemy tries a greedy move that reduces distance to the player, then falls
;   back to roaming if both chase directions are blocked or reverse-only.
; Clobbers:
;   A, BC, DE, HL
ENEMY_ATTACK_STEP:
        CALL    ENEMY_CHASE_DIRS
        LD      A,(IX+MONSTER_DIR)
        CALL    ENEMY_OPPOSITE_DIR
        LD      L,A                     ; L = immediate reverse direction
        LD      A,D
        PUSH    DE
        PUSH    HL
        CALL    ENEMY_TRY_CHASE_DIR
        POP     HL
        POP     DE
        RET     C
        LD      A,E
        CALL    ENEMY_TRY_CHASE_DIR
        RET     C
        JP      ENEMY_ROAM_STEP

; ENEMY_TRY_CHASE_DIR
; Input:
;   A = candidate PACMO_DIR_* or 0
;   L = immediate reverse direction to avoid
; Output:
;   Carry set when candidate moves the enemy; carry clear otherwise
; Clobbers:
;   A, BC, DE, HL
ENEMY_TRY_CHASE_DIR:
        OR      A
        RET     Z
        CP      L
        JR      Z,ENEMY_TRY_CHASE_BLOCKED
        CALL    ENEMY_TRY_MOVE_DIR
        RET
ENEMY_TRY_CHASE_BLOCKED:
        OR      A
        RET

; ENEMY_CHASE_DIRS
; Input:
;   IX = monster record base
;   monster X/Y, PLAYER_X/Y
; Output:
;   D = preferred direction on the larger distance axis, or 0 when aligned
;   E = secondary reducing direction, or 0 when aligned
; Clobbers:
;   A, B, C, H, L
ENEMY_CHASE_DIRS:
        CALL    ENEMY_GET_HORIZONTAL_CHASE
        LD      H,A                     ; H = horizontal distance
        LD      D,B                     ; D = horizontal reducing direction
        CALL    ENEMY_GET_VERTICAL_CHASE
        LD      L,A                     ; L = vertical distance
        LD      E,B                     ; E = vertical reducing direction
        LD      A,H
        CP      L
        RET     NC
        LD      A,D
        LD      D,E
        LD      E,A
        RET

; ENEMY_GET_HORIZONTAL_CHASE
; Input:
;   IX = monster record base
;   monster X, PLAYER_X
; Output:
;   A = absolute horizontal distance
;   B = PACMO_DIR_LEFT/RIGHT reducing that distance, or 0 when aligned
; Clobbers:
;   A, B, C
ENEMY_GET_HORIZONTAL_CHASE:
        LD      A,(IX+MONSTER_X)
        LD      C,A
        LD      A,(PLAYER_X)
        CP      C
        JR      Z,ENEMY_GET_HORIZONTAL_ALIGNED
        JR      C,ENEMY_GET_HORIZONTAL_RIGHT
        SUB     C
        LD      B,PACMO_DIR_LEFT
        RET
ENEMY_GET_HORIZONTAL_RIGHT:
        LD      A,C
        LD      B,A
        LD      A,(PLAYER_X)
        LD      C,A
        LD      A,B
        SUB     C
        LD      B,PACMO_DIR_RIGHT
        RET
ENEMY_GET_HORIZONTAL_ALIGNED:
        LD      B,0
        XOR     A
        RET

; ENEMY_GET_VERTICAL_CHASE
; Input:
;   IX = monster record base
;   monster Y, PLAYER_Y
; Output:
;   A = absolute vertical distance
;   B = PACMO_DIR_UP/DOWN reducing that distance, or 0 when aligned
; Clobbers:
;   A, B, C
ENEMY_GET_VERTICAL_CHASE:
        LD      A,(IX+MONSTER_Y)
        LD      C,A
        LD      A,(PLAYER_Y)
        CP      C
        JR      Z,ENEMY_GET_VERTICAL_ALIGNED
        JR      C,ENEMY_GET_VERTICAL_UP
        SUB     C
        LD      B,PACMO_DIR_DOWN
        RET
ENEMY_GET_VERTICAL_UP:
        LD      A,C
        LD      B,A
        LD      A,(PLAYER_Y)
        LD      C,A
        LD      A,B
        SUB     C
        LD      B,PACMO_DIR_UP
        RET
ENEMY_GET_VERTICAL_ALIGNED:
        LD      B,0
        XOR     A
        RET

; ENEMY_ROAM_STEP
; Input:
;   IX = monster record base
;   monster X/Y and direction, PACMO_LEVEL
; Output:
;   ENEMY_X/Y updated to one open adjacent cell; ENEMY_DIR set to movement
;   direction. Immediate reversal is used only when no other direction is open.
; Clobbers:
;   A, BC, DE, HL
ENEMY_ROAM_STEP:
        LD      A,(IX+MONSTER_X)
        LD      B,A
        LD      A,(IX+MONSTER_Y)
        LD      C,A
        LD      A,(IX+MONSTER_DIR)
        CALL    ENEMY_OPPOSITE_DIR
        LD      D,A                     ; D = reverse direction fallback
        LD      A,B
        ADD     A,C
        LD      E,A
        LD      A,(PACMO_LEVEL)
        ADD     A,E
        LD      E,A
        LD      A,(IX+MONSTER_DIR)
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
;   IX = monster record base
;   A = PACMO_DIR_* candidate
; Output:
;   Carry set when move succeeds; monster X/Y and direction committed.
;   Carry clear when candidate is out of bounds or a wall.
; Clobbers:
;   A, BC, DE, HL
ENEMY_TRY_MOVE_DIR:
        LD      E,A
        LD      A,(IX+MONSTER_X)
        LD      B,A
        LD      A,(IX+MONSTER_Y)
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
        LD      (IX+MONSTER_X),A
        LD      A,C
        LD      (IX+MONSTER_Y),A
        LD      A,E
        LD      (IX+MONSTER_DIR),A
        SCF
        RET
ENEMY_TRY_BLOCKED:
        OR      A
        RET

; TICK_ENEMY_RESPAWN
; Input:
;   IX = monster record base
; Output:
;   Carry set while enemy is respawning; when the timer reaches zero,
;   enemy position and direction are reset and carry is cleared
; Clobbers:
;   A, DE, HL
TICK_ENEMY_RESPAWN:
        LD      A,(IX+MONSTER_RESPAWN_TIMER)
        OR      A
        RET     Z
        DEC     A
        LD      (IX+MONSTER_RESPAWN_TIMER),A
        JR      Z,TICK_ENEMY_RESPAWN_DONE
        SCF
        RET
TICK_ENEMY_RESPAWN_DONE:
        LD      A,PACMO_ENEMY_STATE_ATTACK
        LD      (IX+MONSTER_STATE),A
        CALL    ENEMY_SELECT_RESPAWN
        LD      A,PACMO_DIR_RIGHT
        LD      (IX+MONSTER_DIR),A
        LD      A,(ENEMY_PERIOD_CURRENT)
        LD      (IX+MONSTER_TIMER),A
        CALL    LCD_SHOW_PACMO_RUNNING
        OR      A
        RET

; ENEMY_SELECT_RESPAWN
; Input:
;   IX = respawning monster record base
;   PLAYER_X/Y, PACMO_ENEMY_SPAWNS, MONSTERS
; Output:
;   monster X/Y set to the spawn candidate with the highest score:
;   distance from player plus distance from the other active monster.
;   Ties keep the earlier table entry.
; Clobbers:
;   A, BC, DE, HL
ENEMY_SELECT_RESPAWN:
        LD      HL,PACMO_ENEMY_SPAWNS
        LD      B,0xFF                  ; B = best distance; 0xFF means no best yet
        LD      DE,0                    ; D = best x, E = best y
ENEMY_SELECT_RESPAWN_LOOP:
        LD      A,(HL)
        CP      0xFF
        JR      Z,ENEMY_SELECT_RESPAWN_COMMIT
        LD      C,A                     ; C = candidate x
        INC     HL
        LD      A,(HL)                  ; A = candidate y
        INC     HL
        PUSH    HL
        LD      H,A                     ; H = candidate y
        LD      L,C                     ; L = candidate x
        PUSH    BC
        CALL    ENEMY_RESPAWN_SCORE_LH
        POP     BC
        LD      C,A                     ; C = candidate distance
        LD      A,B
        CP      0xFF
        JR      Z,ENEMY_SELECT_RESPAWN_NEW_BEST
        LD      A,C
        CP      B
        JR      Z,ENEMY_SELECT_RESPAWN_KEEP_BEST
        JR      C,ENEMY_SELECT_RESPAWN_KEEP_BEST
ENEMY_SELECT_RESPAWN_NEW_BEST:
        LD      B,C
        LD      D,L
        LD      E,H
ENEMY_SELECT_RESPAWN_KEEP_BEST:
        POP     HL
        JR      ENEMY_SELECT_RESPAWN_LOOP
ENEMY_SELECT_RESPAWN_COMMIT:
        LD      A,D
        LD      (IX+MONSTER_X),A
        LD      A,E
        LD      (IX+MONSTER_Y),A
        RET

; ENEMY_RESPAWN_SCORE_LH
; Input:
;   L = candidate x
;   H = candidate y
;   IX = respawning monster record base
; Output:
;   A = candidate score.  Higher is better.
; Clobbers:
;   A, B, C
ENEMY_RESPAWN_SCORE_LH:
        PUSH    DE
        CALL    ENEMY_IS_LH_IN_VIEWPORT
        JR      C,ENEMY_RESPAWN_SCORE_ZERO
        CALL    ENEMY_DISTANCE_LH_TO_PLAYER
        CP      8
        JR      C,ENEMY_RESPAWN_SCORE_ZERO
        LD      B,A
        CALL    ENEMY_DISTANCE_LH_TO_OTHER_MONSTER
        ADD     A,B
        POP     DE
        RET
ENEMY_RESPAWN_SCORE_ZERO:
        XOR     A
        POP     DE
        RET

; ENEMY_IS_LH_IN_VIEWPORT
; Input:
;   L = candidate x
;   H = candidate y
; Output:
;   carry set when candidate is currently visible in the 8x8 viewport,
;   carry clear otherwise
; Clobbers:
;   A, C
ENEMY_IS_LH_IN_VIEWPORT:
        LD      A,(VIEW_X)
        LD      C,A
        LD      A,L
        CP      C
        JR      C,ENEMY_IS_LH_NOT_VISIBLE
        SUB     C
        CP      ROW_COUNT
        JR      NC,ENEMY_IS_LH_NOT_VISIBLE
        LD      A,(VIEW_Y)
        LD      C,A
        LD      A,H
        CP      C
        JR      C,ENEMY_IS_LH_NOT_VISIBLE
        SUB     C
        CP      ROW_COUNT
        JR      NC,ENEMY_IS_LH_NOT_VISIBLE
        SCF
        RET
ENEMY_IS_LH_NOT_VISIBLE:
        OR      A
        RET

; ENEMY_DISTANCE_LH_TO_OTHER_MONSTER
; Input:
;   L = candidate x
;   H = candidate y
;   IX = respawning monster record base
; Output:
;   A = summed distance to other active monsters.  Respawning monsters, the
;   current IX monster, and level-2 monster before level 2 are ignored.
; Clobbers:
;   A, BC, DE
ENEMY_DISTANCE_LH_TO_OTHER_MONSTER:
        LD      B,0                     ; B = accumulated distance score
        LD      DE,MONSTER0
        CALL    ENEMY_ADD_DISTANCE_TO_MONSTER_DE
        LD      DE,MONSTER1
        CALL    ENEMY_ADD_DISTANCE_TO_MONSTER_DE
        LD      A,B
        LD      C,A
        CALL    PACMO_IS_LEVEL2_PLUS
        LD      B,C
        LD      A,B
        RET     C
        LD      DE,MONSTER2
        CALL    ENEMY_ADD_DISTANCE_TO_MONSTER_DE
        LD      A,B
        RET

; ENEMY_ADD_DISTANCE_TO_MONSTER_DE
; Input:
;   B = accumulated distance score
;   L = candidate x
;   H = candidate y
;   DE = monster record pointer
;   IX = respawning monster record base
; Output:
;   B = updated accumulated distance score
; Clobbers:
;   A, C, DE
ENEMY_ADD_DISTANCE_TO_MONSTER_DE:
        PUSH    HL
        PUSH    DE
        PUSH    IX
        POP     HL
        OR      A
        SBC     HL,DE
        POP     DE
        POP     HL
        RET     Z
        PUSH    HL
        LD      H,D
        LD      L,E
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        LD      A,(HL)
        POP     HL
        OR      A
        RET     NZ
        LD      A,(DE)
        LD      C,A
        INC     DE
        LD      A,(DE)
        LD      D,A
        LD      E,C
        CALL    ENEMY_DISTANCE_LH_TO_DE
        ADD     A,B
        LD      B,A
        RET

; ENEMY_DISTANCE_LH_TO_PLAYER
; Input:
;   L = candidate x
;   H = candidate y
; Output:
;   A = |candidate x - PLAYER_X| + |candidate y - PLAYER_Y|
; Clobbers:
;   A, C
ENEMY_DISTANCE_LH_TO_PLAYER:
        PUSH    DE
        LD      A,(PLAYER_X)
        LD      E,A
        LD      A,(PLAYER_Y)
        LD      D,A
        CALL    ENEMY_DISTANCE_LH_TO_DE
        POP     DE
        RET

; ENEMY_DISTANCE_LH_TO_DE
; Input:
;   L = candidate x
;   H = candidate y
;   E = target x
;   D = target y
; Output:
;   A = |candidate x - target x| + |candidate y - target y|
; Clobbers:
;   A, C
ENEMY_DISTANCE_LH_TO_DE:
        LD      A,L
        LD      C,A
        LD      A,E
        CP      C
        JR      NC,ENEMY_DISTANCE_X_PLAYER_HIGHER
        LD      A,C
        LD      C,A
        LD      A,E
        SUB     C
        NEG
        LD      C,A
        JR      ENEMY_DISTANCE_Y
ENEMY_DISTANCE_X_PLAYER_HIGHER:
        SUB     C
        LD      C,A
ENEMY_DISTANCE_Y:
        LD      A,H
        PUSH    BC
        LD      C,A
        LD      A,D
        CP      C
        JR      NC,ENEMY_DISTANCE_Y_PLAYER_HIGHER
        LD      A,C
        LD      C,A
        LD      A,D
        SUB     C
        NEG
        JR      ENEMY_DISTANCE_SUM
ENEMY_DISTANCE_Y_PLAYER_HIGHER:
        SUB     C
ENEMY_DISTANCE_SUM:
        POP     BC
        ADD     A,C
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
