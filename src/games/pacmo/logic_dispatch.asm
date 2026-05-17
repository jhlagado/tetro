; Run one Pacmo logic slice per main-loop pass.
; LOGIC_TICK
; Input:
;   uses LOGIC_SLICE from RAM
; Output:
;   slices 0..7 copy and rebuild one framebuffer row; after row 7, the
;   matrix is blanked and frame-wide Pacmo duties run
; Clobbers:
;   A, BC, DE, HL, IX, and registers clobbered by called slice routines
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
; Input:
;   current Pacmo state
; Output:
;   input, timers, enemy ticks, and collision checks updated once per frame
;   while the matrix rows are blanked
; Clobbers:
;   A, BC, DE, HL, IX
; Uses @clobbers A,BC,DE,HL,IX,carry,zero,sign,parity,halfCarry while running frame duties.
; Keeps @preserves IY stable for the caller.
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
; Input:
;   A = screen row 0..7
; Output:
;   matching completed back row copied to the front framebuffer, then that
;   back row rebuilt from the current Pacmo world/entity state
; Clobbers:
;   A, BC, DE, HL, IX
; Accepts @in A as the screen row.
; Uses @clobbers A,BC,DE,HL,IX,carry,zero,sign,parity,halfCarry while rebuilding the row.
; Keeps @preserves IY stable for the caller.
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
; Uses @clobbers A,DE,HL,carry,zero,sign,parity,halfCarry while ticking power mode.
; Keeps @preserves BC,IX,IY stable for the caller.
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
; Returns @out carry set when level < 2, clear otherwise.
; Uses @clobbers A,zero,sign,parity,halfCarry while comparing PACMO_LEVEL.
; Keeps @preserves BC,DE,HL,IX,IY stable for the caller.
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
; Accepts @in IX as the monster record base.
; Uses @clobbers A,BC,DE,HL,carry,zero,sign,parity,halfCarry while ticking the enemy.
; Keeps @preserves IX,IY stable for the caller.
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
; Input:
;   A = candidate PACMO_DIR_* or 0
;   L = immediate reverse direction to avoid
; Output:
;   Carry set when candidate moves the enemy; carry clear otherwise
; Clobbers:
;   A, BC, DE, HL
; Accepts @in A as candidate PACMO_DIR_* or 0.
; Accepts @in L as immediate reverse direction to avoid.
; Returns @out carry set when candidate moves the enemy.
; Uses @clobbers A,BC,DE,HL,zero,sign,parity,halfCarry while testing the move.
; Keeps @preserves IX,IY stable for the caller.
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
; Returns @out D as the preferred chase direction.
; Returns @out E as the secondary chase direction.
; Uses @clobbers A,BC,HL,carry,zero,sign,parity,halfCarry while comparing chase axes.
; Keeps @preserves IX,IY stable for the caller.
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
; Accepts @in IX as the monster record base.
; Returns @out A as the absolute horizontal distance.
; Returns @out B as the horizontal reducing direction.
; Uses @clobbers C,carry,zero,sign,parity,halfCarry while comparing positions.
; Keeps @preserves DE,HL,IX,IY stable for the caller.
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
; Accepts @in IX as the monster record base.
; Returns @out A as the absolute vertical distance.
; Returns @out B as the vertical reducing direction.
; Uses @clobbers C,carry,zero,sign,parity,halfCarry while comparing positions.
; Keeps @preserves DE,HL,IX,IY stable for the caller.
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
; Accepts @in A as a PACMO_DIR_* value.
; Returns @out A as the opposite PACMO_DIR_* value.
; Uses @clobbers carry,zero,sign,parity,halfCarry while matching the direction.
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
;   A, BC, E
; Accepts @in A as the PACMO_DIR_* candidate.
; Accepts @in IX as the monster record base.
; Returns @out carry set when the move succeeds.
; Uses @clobbers A,BC,E,zero,sign,parity,halfCarry while testing and committing the move.
; Keeps @preserves D,HL,IX,IY stable for the caller.
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
; Input:
;   IX = monster record base
; Output:
;   Carry set while enemy is respawning; when the timer reaches zero,
;   enemy position and direction are reset and carry is cleared
; Clobbers:
;   A, BC, DE, HL
; Accepts @in IX as the monster record base.
; Returns @out carry set while the enemy is still respawning.
; Uses @clobbers A,BC,DE,HL,zero,sign,parity,halfCarry while ticking respawn state.
; Keeps @preserves IX,IY stable for the caller.
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
; Input:
;   IX = respawning monster record base
;   PLAYER_X/Y, PACMO_ENEMY_SPAWNS, MONSTERS
; Output:
;   monster X/Y set to the unoccupied spawn candidate with the highest score:
;   distance from player plus distance from the other non-respawning monsters.
;   Ties keep the earlier table entry.
; Clobbers:
;   A, BC, DE, HL
; Accepts @in IX as the respawning monster record base.
; Uses @clobbers A,BC,DE,HL,carry,zero,sign,parity,halfCarry while selecting the spawn.
; Keeps @preserves IX,IY stable for the caller.
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
; Input:
;   L = candidate x
;   H = candidate y
;   IX = respawning monster record base
; Output:
;   A = candidate score.  Higher is better.
; Clobbers:
;   A, BC
; Accepts @in L as candidate x.
; Accepts @in H as candidate y.
; Accepts @in IX as the respawning monster record base.
; Returns @out A as the candidate score.
; Uses @clobbers BC,carry,zero,sign,parity,halfCarry while scoring the spawn.
; Keeps @preserves DE,HL,IX,IY stable for the caller.
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
; Input:
;   L = candidate x
;   H = candidate y
; Output:
;   carry set when candidate is currently visible in the 8x8 viewport,
;   carry clear otherwise
; Clobbers:
;   A, C
; Accepts @in L as candidate x.
; Accepts @in H as candidate y.
; Returns @out carry set when the candidate is visible.
; Uses @clobbers A,C,zero,sign,parity,halfCarry while testing the viewport.
; Keeps @preserves B,DE,HL,IX,IY stable for the caller.
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
; Input:
;   L = candidate x
;   H = candidate y
;   IX = respawning monster record base
; Output:
;   carry set when another non-respawning monster already occupies candidate
;   carry clear otherwise
; Clobbers:
;   A, DE
; Accepts @in L as candidate x.
; Accepts @in H as candidate y.
; Accepts @in IX as the respawning monster record base.
; Returns @out carry set when another monster occupies the candidate.
; Uses @clobbers A,DE,zero,sign,parity,halfCarry while checking monsters.
; Keeps @preserves BC,HL,IX,IY stable for the caller.
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
; Input:
;   L = candidate x
;   H = candidate y
;   DE = monster record pointer
;   IX = respawning monster record base
; Output:
;   carry set when DE points to a different non-respawning monster at candidate
;   carry clear otherwise
; Clobbers:
;   A, DE
; Accepts @in L as candidate x.
; Accepts @in H as candidate y.
; Accepts @in DE as monster record pointer.
; Accepts @in IX as respawning monster record base.
; Returns @out carry set when the candidate is occupied.
; Uses @clobbers A,DE,zero,sign,parity,halfCarry while testing the monster record.
; Keeps @preserves BC,HL,IX,IY stable for the caller.
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
; Input:
;   L = candidate x
;   H = candidate y
;   IX = respawning monster record base
; Output:
;   A = summed distance to other active monsters.  Respawning monsters, the
;   current IX monster, and level-2 monster before level 2 are ignored.
; Clobbers:
;   A, BC, DE
; Accepts @in L as candidate x.
; Accepts @in H as candidate y.
; Accepts @in IX as the respawning monster record base.
; Returns @out A as the summed distance to other active monsters.
; Uses @clobbers BC,DE,carry,zero,sign,parity,halfCarry while accumulating distance.
; Keeps @preserves HL,IX,IY stable for the caller.
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
; Accepts @in B as the accumulated distance score.
; Accepts @in L as candidate x.
; Accepts @in H as candidate y.
; Accepts @in DE as the monster record pointer.
; Accepts @in IX as the respawning monster record base.
; Returns @out B as the updated accumulated distance score.
; Uses @clobbers A,C,DE,carry,zero,sign,parity,halfCarry while testing the monster.
; Keeps @preserves HL,IX,IY stable for the caller.
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
; Accepts @in L as candidate x.
; Accepts @in H as candidate y.
; Returns @out A as the Manhattan distance to the player.
; Uses @clobbers C,carry,zero,sign,parity,halfCarry while computing distance.
; Keeps @preserves B,DE,HL,IX,IY stable for the caller.
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
; Accepts @in L as candidate x.
; Accepts @in H as candidate y.
; Accepts @in E as target x.
; Accepts @in D as target y.
; Returns @out A as the Manhattan distance.
; Uses @clobbers C,carry,zero,sign,parity,halfCarry while computing distance.
; Keeps @preserves B,DE,HL,IX,IY stable for the caller.
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
