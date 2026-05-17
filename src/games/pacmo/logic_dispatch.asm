; Run one Pacmo logic slice per main-loop pass.
; LOGIC_TICK
; Uses LOGIC_SLICE from RAM.
; Slices 0..7 copy and rebuild one framebuffer row.
; After row 7, the matrix is blanked and frame-wide Pacmo duties run.
; @clobbers A,BC,DE,HL,IX.
LOGIC_TICK:
        LD      A,(LOGIC_SLICE)
        AND     7
        CP      7
        JP      Z,LOGIC_SL7
        CALL    PACMO_RENDER_LOGIC_ROW_A
        JP      LOGIC_SLICE_NEXT

LOGIC_SL7:
        LD      A,7
        CALL    PACMO_RENDER_LOGIC_ROW_A
        XOR     A
        OUT     (PORT_ROW),A
        CALL    PACMO_FRAME_DUTIES
        XOR     A
        LD      (LOGIC_SLICE),A
        RET

; PACMO_FRAME_DUTIES
; Current Pacmo state.
; Input, timers, enemy ticks, and collision checks updated once per frame.
; While the matrix rows are blanked.
; @clobbers A,BC,DE,HL,IX while running frame duties.
PACMO_FRAME_DUTIES:
        CALL    POLL_INPUT_AND_UPDATE
        LD      A,(PACMO_PAUSED)
        OR      A
        RET     NZ
        CALL    TICK_LEVEL_COMPLETE_GATE
        CALL    TICK_POWER_TIMER
        LD      IX,MONSTER0
        CALL    TICK_ENEMY
        LD      IX,MONSTER1
        CALL    TICK_ENEMY
        CALL    PACMO_IS_LEVEL2_PLUS
        JR      C,PACMO_FRAME_TICK_DONE
        LD      IX,MONSTER2
        CALL    TICK_ENEMY
PACMO_FRAME_TICK_DONE:
        LD      IX,MONSTER0
        CALL    PACMO_CHECK_PLAYER_CAUGHT
        LD      IX,MONSTER1
        CALL    PACMO_CHECK_PLAYER_CAUGHT
        CALL    PACMO_IS_LEVEL2_PLUS
        JR      C,PACMO_FRAME_COLLISION_DONE
        LD      IX,MONSTER2
        CALL    PACMO_CHECK_PLAYER_CAUGHT
PACMO_FRAME_COLLISION_DONE:
        RET

; PACMO_RENDER_LOGIC_ROW_A
; @in A screen row 0..7.
; Matching completed back row copied to the front framebuffer.
; That back row is rebuilt from the current Pacmo world/entity state.
; @clobbers A,BC,DE,HL,IX while rebuilding the row.
PACMO_RENDER_LOGIC_ROW_A:
        PUSH    AF
        ADD     A,A
        ADD     A,A
        CALL    COPY_BACK_4_TO_FRONT
        POP     AF
        PUSH    AF
        ADD     A,A
        ADD     A,A
        CALL    CLEAR_BACK_4
        POP     AF
        PUSH    AF
        CALL    RENDER_WORLD_ROW_TO_BACK
        POP     AF
        PUSH    AF
        CALL    RENDER_POWER_PILLS_ROW_TO_BACK
        POP     AF
        PUSH    AF
        CALL    RENDER_MONSTERS_ROW_TO_BACK
        POP     AF
        JP      RENDER_PLAYER_ROW_TO_BACK

LOGIC_SLICE_NEXT:
        LD      HL,LOGIC_SLICE
        LD      A,(HL)
        INC     A
        AND     7
        LD      (HL),A
        RET

; TICK_LEVEL_COMPLETE_GATE
; Reads PACMO_ROUND_COMPLETE, PACMO_LEVEL_COMPLETE_GATE_LO/HI.
; When a completed-level delay expires, advances and initializes next level.
; @clobbers A,BC,DE,HL.
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
; Reads PACMO_POWER_TIMER_LO/HI.
; Decrements 16-bit PACMO_POWER_TIMER by one when nonzero.
; Restores running LCD status when power mode expires.
; @clobbers A,DE,HL while ticking power mode.
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
; Reads PACMO_LEVEL.
; @out carry set when level < 2, clear otherwise.
; @clobbers A while comparing PACMO_LEVEL.
PACMO_IS_LEVEL2_PLUS:
        LD      A,(PACMO_LEVEL)
        CP      2
        RET

; TICK_ENEMY
; @in IX monster record base; monster X/Y, direction, timer, state, respawn timer.
; Active enemy moves when its timer reaches zero.
; Respawning enemy counts down, then respawns at the selected candidate cell.
; @clobbers A,BC,DE,HL while ticking the enemy.
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
; @in IX monster record base; monster X/Y and direction, PLAYER_X/Y.
; Enemy tries a greedy move that reduces distance to the player.
; Falls back to roaming if both chase directions are blocked or reverse-only.
; @clobbers A,BC,DE,HL.
ENEMY_ATTACK_STEP:
        CALL    ENEMY_CHASE_DIRS
        LD      A,(IX+MONSTER_DIR)
        CALL    ENEMY_OPPOSITE_DIR
        LD      L,A                     ; L = immediate reverse direction
        LD      A,D
        LD      H,0                     ; H is stack padding; only L is restored later.
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
; @in A candidate PACMO_DIR_* or 0.
; @in L immediate reverse direction to avoid.
; @out carry set when candidate moves the enemy.
; @clobbers A,BC,DE,HL while testing the move.
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
; @in IX monster record base; monster X/Y, PLAYER_X/Y.
; @out D the preferred chase direction.
; @out E the secondary chase direction.
; @clobbers A,BC,HL while comparing chase axes.
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
; @in IX monster record base; monster X, PLAYER_X.
; @out A the absolute horizontal distance.
; @out B the horizontal reducing direction.
; @clobbers C while comparing positions.
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
; @in IX monster record base; monster Y, PLAYER_Y.
; @out A the absolute vertical distance.
; @out B the vertical reducing direction.
; @clobbers C while comparing positions.
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
; @in IX monster record base; monster X/Y and direction, PACMO_LEVEL.
; ENEMY_X/Y updated to one open adjacent cell; ENEMY_DIR set to movement direction.
; Immediate reversal is used only when no other direction is open.
; @clobbers A,BC,DE,HL.
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
; @in A PACMO_DIR_*.
; @out A the opposite PACMO_DIR_* value.
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
; @in IX monster record base.
; @in A PACMO_DIR_* candidate.
; @out carry set when the move succeeds.
; @clobbers A,BC,E while testing and committing the move.
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
        PUSH    HL
        CALL    PACMO_IS_WALL_AT_BC
        POP     HL
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
; @in IX monster record base.
; @out carry set while the enemy is still respawning.
; Enemy position and direction are reset and carry is cleared.
; @clobbers A,BC,DE,HL while ticking respawn state.
TICK_ENEMY_RESPAWN:
        LD      A,(IX+MONSTER_RESPAWN_TIMER)
        OR      A
        RET     Z
        LD      A,(IX+MONSTER_TIMER)
        OR      A
        JR      Z,TICK_ENEMY_RESPAWN_DEC_TIMER
        DEC     A
        LD      (IX+MONSTER_TIMER),A
        JR      Z,TICK_ENEMY_RESPAWN_DEC_TIMER
        SCF
        RET
TICK_ENEMY_RESPAWN_DEC_TIMER:
        LD      A,PACMO_ENEMY_RESPAWN_DIV
        LD      (IX+MONSTER_TIMER),A
        LD      A,(IX+MONSTER_RESPAWN_TIMER)
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
        XOR     A
        RET

; ENEMY_SELECT_RESPAWN
; @in IX respawning monster record base; PLAYER_X/Y, PACMO_ENEMY_SPAWNS, MONSTERS.
; Monster X/Y set to the unoccupied spawn candidate with the highest score:
; Distance from player plus distance from the other non-respawning monsters.
; Ties keep the earlier table entry.
; @clobbers A,BC,DE,HL while selecting the spawn.
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
        PUSH    DE
        CALL    ENEMY_IS_LH_OCCUPIED_BY_OTHER_MONSTER
        POP     DE
        JR      C,ENEMY_SELECT_RESPAWN_KEEP_BEST
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
; @in L candidate x.
; @in H candidate y.
; @in IX respawning monster record base.
; @out A the candidate score.
; @clobbers BC while scoring the spawn.
ENEMY_RESPAWN_SCORE_LH:
        PUSH    DE
        CALL    ENEMY_IS_LH_IN_VIEWPORT
        JR      C,ENEMY_RESPAWN_SCORE_ZERO
        CALL    ENEMY_DISTANCE_LH_TO_PLAYER
        CP      8
        JR      C,ENEMY_RESPAWN_SCORE_ZERO
        LD      C,A
        PUSH    BC
        CALL    ENEMY_DISTANCE_LH_TO_OTHER_MONSTER
        POP     BC
        ADD     A,C
        POP     DE
        RET
ENEMY_RESPAWN_SCORE_ZERO:
        XOR     A
        POP     DE
        RET

; ENEMY_IS_LH_IN_VIEWPORT
; @in L candidate x.
; @in H candidate y.
; @out carry set when the candidate is visible.
; @clobbers A,C while testing the viewport.
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

; ENEMY_IS_LH_OCCUPIED_BY_OTHER_MONSTER
; @in L candidate x.
; @in H candidate y.
; @in IX respawning monster record base.
; @out carry set when another monster occupies the candidate.
; @clobbers A,DE while checking monsters.
ENEMY_IS_LH_OCCUPIED_BY_OTHER_MONSTER:
        LD      DE,MONSTER0
        CALL    ENEMY_IS_LH_OCCUPIED_BY_MONSTER_DE
        RET     C
        LD      DE,MONSTER1
        CALL    ENEMY_IS_LH_OCCUPIED_BY_MONSTER_DE
        RET     C
        CALL    PACMO_IS_LEVEL2_PLUS
        JR      C,ENEMY_OCCUPIED_NO
        LD      DE,MONSTER2
        JP      ENEMY_IS_LH_OCCUPIED_BY_MONSTER_DE

; ENEMY_IS_LH_OCCUPIED_BY_MONSTER_DE
; @in L candidate x.
; @in H candidate y.
; @in DE monster record pointer.
; @in IX respawning monster record base.
; @out carry set when the candidate is occupied.
; @clobbers A,DE while testing the monster record.
ENEMY_IS_LH_OCCUPIED_BY_MONSTER_DE:
        PUSH    HL
        PUSH    DE
        PUSH    IX
        POP     HL
        OR      A
        SBC     HL,DE
        POP     DE
        POP     HL
        JR      Z,ENEMY_OCCUPIED_NO
        PUSH    HL
        LD      H,D
        LD      L,E
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        LD      A,(HL)
        POP     HL
        CP      PACMO_ENEMY_STATE_RESPAWN
        JR      Z,ENEMY_OCCUPIED_NO
        LD      A,(DE)
        CP      L
        JR      NZ,ENEMY_OCCUPIED_NO
        INC     DE
        LD      A,(DE)
        CP      H
        JR      NZ,ENEMY_OCCUPIED_NO
        SCF
        RET
ENEMY_OCCUPIED_NO:
        OR      A
        RET

; ENEMY_DISTANCE_LH_TO_OTHER_MONSTER
; @in L candidate x.
; @in H candidate y.
; @in IX respawning monster record base.
; @out A the summed distance to other active monsters.
; Current IX monster is ignored; level-2 monster is ignored before level 2.
; @clobbers BC,DE while accumulating distance.
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
; @in B accumulated distance score.
; @in L candidate x.
; @in H candidate y.
; @in DE monster record pointer.
; @in IX respawning monster record base.
; @out B the updated accumulated distance score.
; @clobbers A,C,DE while testing the monster.
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
; @in L candidate x.
; @in H candidate y.
; @out A the Manhattan distance to the player.
; @clobbers C while computing distance.
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
; @in L candidate x.
; @in H candidate y.
; @in E target x.
; @in D target y.
; @out A the Manhattan distance.
; @clobbers C while computing distance.
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
; Reads PACMO_LEVEL, ENEMY_PERIOD_CURRENT.
; Level count incremented, enemy period reduced to its minimum, level restarted.
; @clobbers A,BC,DE,HL.
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
