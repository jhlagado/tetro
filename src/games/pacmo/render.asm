; REBUILD_FRAMEBUFFER
; Input:
;   current viewport and player state in RAM
; Output:
;   FRAMEBUFFER rebuilt from scratch
; Clobbers:
;   A, BC, DE, HL, IX
REBUILD_FRAMEBUFFER:
        CALL    CLEAR_BACK_ALL
        CALL    RENDER_WORLD_TO_BACK
        CALL    RENDER_POWER_PILLS_TO_BACK
        LD      IX,MONSTER0
        CALL    RENDER_ENEMY_TO_BACK
        LD      IX,MONSTER1
        CALL    RENDER_ENEMY_TO_BACK
        LD      A,(PACMO_LEVEL)
        CP      2
        JR      C,REBUILD_FRAMEBUFFER_MONSTERS_DONE
        LD      IX,MONSTER2
        CALL    RENDER_ENEMY_TO_BACK
REBUILD_FRAMEBUFFER_MONSTERS_DONE:
        CALL    RENDER_PLAYER_TO_BACK
        JP      COPY_BACK_TO_FRONT

; RENDER_GAME_OVER_TO_BACK
; Input:
;   none
; Output:
;   FRAMEBUFFER_BACK filled with PACMO_COLOR_GAME_OVER as a dramatic cue
; Clobbers:
;   A, B, HL
RENDER_GAME_OVER_TO_BACK:
        LD      HL,FRAMEBUFFER_BACK
        LD      B,ROW_COUNT
RENDER_GAME_OVER_ROW:
        LD      A,PACMO_COLOR_GAME_OVER
        AND     COLOR_RED
        JR      Z,RENDER_GAME_OVER_RED_OFF
        LD      A,0xFF
RENDER_GAME_OVER_RED_OFF:
        LD      (HL),A
        INC     HL
        LD      A,PACMO_COLOR_GAME_OVER
        AND     COLOR_GREEN
        JR      Z,RENDER_GAME_OVER_GREEN_OFF
        LD      A,0xFF
RENDER_GAME_OVER_GREEN_OFF:
        LD      (HL),A
        INC     HL
        LD      A,PACMO_COLOR_GAME_OVER
        AND     COLOR_BLUE
        JR      Z,RENDER_GAME_OVER_BLUE_OFF
        LD      A,0xFF
RENDER_GAME_OVER_BLUE_OFF:
        LD      (HL),A
        INC     HL
        XOR     A
        LD      (HL),A                  ; aux off
        INC     HL
        DJNZ    RENDER_GAME_OVER_ROW
        RET

; RENDER_LEVEL_COMPLETE_TO_BACK
; Input:
;   none
; Output:
;   FRAMEBUFFER_BACK filled with PACMO_COLOR_ROUND_COMPLETE
; Clobbers:
;   A, B, HL
RENDER_LEVEL_COMPLETE_TO_BACK:
        LD      HL,FRAMEBUFFER_BACK
        LD      B,ROW_COUNT
RENDER_LEVEL_COMPLETE_ROW:
        LD      A,PACMO_COLOR_ROUND_COMPLETE
        AND     COLOR_RED
        JR      Z,RENDER_LEVEL_COMPLETE_RED_OFF
        LD      A,0xFF
RENDER_LEVEL_COMPLETE_RED_OFF:
        LD      (HL),A
        INC     HL
        LD      A,PACMO_COLOR_ROUND_COMPLETE
        AND     COLOR_GREEN
        JR      Z,RENDER_LEVEL_COMPLETE_GREEN_OFF
        LD      A,0xFF
RENDER_LEVEL_COMPLETE_GREEN_OFF:
        LD      (HL),A
        INC     HL
        LD      A,PACMO_COLOR_ROUND_COMPLETE
        AND     COLOR_BLUE
        JR      Z,RENDER_LEVEL_COMPLETE_BLUE_OFF
        LD      A,0xFF
RENDER_LEVEL_COMPLETE_BLUE_OFF:
        LD      (HL),A
        INC     HL
        XOR     A
        LD      (HL),A                  ; aux off
        INC     HL
        DJNZ    RENDER_LEVEL_COMPLETE_ROW
        RET

; RENDER_WORLD_TO_BACK
; Input:
;   VIEW_X/Y and PACMO_WORLD_ROWS
; Output:
;   visible 8x8 viewport rendered with PACMO_COLOR_PATH and PACMO_COLOR_WALL
; Clobbers:
;   A, BC, DE, HL
RENDER_WORLD_TO_BACK:
        LD      B,0
RENDER_WORLD_TO_BACK_ROW_LOOP:
        LD      A,B
        PUSH    BC
        CALL    RENDER_WORLD_ROW_TO_BACK
        POP     BC
        INC     B
        LD      A,B
        CP      ROW_COUNT
        JR      C,RENDER_WORLD_TO_BACK_ROW_LOOP
        RET

; RENDER_WORLD_ROW_TO_BACK
; Input:
;   A = screen row 0..7
; Output:
;   selected FRAMEBUFFER_BACK row rendered from the corresponding world/eaten row
; Clobbers:
;   A, BC, DE, HL
; Accepts @in A as the screen row.
; Uses @clobbers A,BC,DE,HL while rendering the world row.
; Keeps @preserves IX,IY stable for the caller.
RENDER_WORLD_ROW_TO_BACK:
        LD      C,A                     ; C = screen row
        ADD     A,A
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,FRAMEBUFFER_BACK
        ADD     HL,DE
        PUSH    HL                      ; target framebuffer row

        LD      A,(VIEW_Y)
        ADD     A,C                     ; A = world row
        ADD     A,A
        LD      E,A
        LD      D,0
        PUSH    DE                      ; source byte offset

        LD      HL,PACMO_WORLD_ROWS
        ADD     HL,DE
        LD      A,(HL)
        LD      B,A                     ; B = high byte of 15-bit row
        INC     HL
        LD      A,(HL)
        LD      C,A                     ; C = low byte of 15-bit row
        LD      A,(VIEW_X)
        CALL    WINDOW_BYTE_FROM_BC
        POP     DE

        LD      HL,PACMO_EATEN_ROWS
        ADD     HL,DE
        LD      E,A                     ; E = visible wall mask
        LD      A,(HL)
        LD      B,A
        INC     HL
        LD      A,(HL)
        LD      C,A
        LD      A,(VIEW_X)
        CALL    WINDOW_BYTE_FROM_BC
        LD      B,A                     ; B = visible eaten mask
        LD      C,E                     ; C = visible wall mask
        OR      B
        CPL                             ; A = visible uneaten open path mask
        LD      D,A
        POP     HL                      ; target framebuffer row
        JP      WRITE_WORLD_ROW_COLORS

; WRITE_WORLD_ROW_COLORS
; Input:
;   HL = red plane byte for the target framebuffer row
;   C  = visible wall mask
;   D  = visible uneaten path mask
; Output:
;   red/green/blue plane bytes written from PACMO_COLOR_WALL/PATH;
;   caught state renders walls with PACMO_COLOR_CAUGHT_WALL;
;   complete state renders walls with PACMO_COLOR_COMPLETE_WALL
;   HL points to the aux byte after the blue plane
; Clobbers:
;   A, B, HL
WRITE_WORLD_ROW_COLORS:
        XOR     A
        LD      B,A
        CALL    GET_CURRENT_WALL_COLOR
        AND     COLOR_RED
        JR      Z,WRITE_WORLD_RED_PATH
        LD      B,C
WRITE_WORLD_RED_PATH:
        LD      A,PACMO_COLOR_PATH
        AND     COLOR_RED
        JR      Z,WRITE_WORLD_RED_STORE
        LD      A,B
        OR      D
        LD      B,A
WRITE_WORLD_RED_STORE:
        LD      (HL),B
        INC     HL

        XOR     A
        LD      B,A
        CALL    GET_CURRENT_WALL_COLOR
        AND     COLOR_GREEN
        JR      Z,WRITE_WORLD_GREEN_PATH
        LD      B,C
WRITE_WORLD_GREEN_PATH:
        LD      A,PACMO_COLOR_PATH
        AND     COLOR_GREEN
        JR      Z,WRITE_WORLD_GREEN_STORE
        LD      A,B
        OR      D
        LD      B,A
WRITE_WORLD_GREEN_STORE:
        LD      (HL),B
        INC     HL

        XOR     A
        LD      B,A
        CALL    GET_CURRENT_WALL_COLOR
        AND     COLOR_BLUE
        JR      Z,WRITE_WORLD_BLUE_PATH
        LD      B,C
WRITE_WORLD_BLUE_PATH:
        LD      A,PACMO_COLOR_PATH
        AND     COLOR_BLUE
        JR      Z,WRITE_WORLD_BLUE_STORE
        LD      A,B
        OR      D
        LD      B,A
WRITE_WORLD_BLUE_STORE:
        LD      (HL),B
        INC     HL
        RET

; GET_CURRENT_WALL_COLOR
; Input:
;   PACMO_PLAYER_CAUGHT, PACMO_ROUND_COMPLETE
; Output:
;   A = wall color for the current render state
; Clobbers:
;   A
; Returns @out A as the current wall color.
; Uses @clobbers zero,sign,parity,halfCarry while checking render state.
; Keeps @preserves BC,DE,HL,IX,IY stable for the caller.
GET_CURRENT_WALL_COLOR:
        LD      A,(PACMO_PLAYER_CAUGHT)
        OR      A
        JR      NZ,GET_CURRENT_WALL_COLOR_CAUGHT
        LD      A,(PACMO_ROUND_COMPLETE)
        OR      A
        JR      NZ,GET_CURRENT_WALL_COLOR_COMPLETE
        LD      A,PACMO_COLOR_WALL
        RET
GET_CURRENT_WALL_COLOR_CAUGHT:
        LD      A,PACMO_COLOR_CAUGHT_WALL
        RET
GET_CURRENT_WALL_COLOR_COMPLETE:
        LD      A,PACMO_COLOR_COMPLETE_WALL
        RET

; WINDOW_BYTE_FROM_BC
; Input:
;   BC = 16-bit world row, bit 15 is world column 0
;   A  = viewport X origin, expected 0..7
; Output:
;   A = 8 visible bits for columns VIEW_X..VIEW_X+7
; Clobbers:
;   B, C, D
; Accepts @in BC as the 16-bit world row.
; Accepts @in A as viewport X origin.
; Returns @out A as the visible window byte.
; Uses @clobbers B,C,D,carry,zero,sign,parity,halfCarry while shifting the world row.
; Keeps @preserves E,HL,IX,IY stable for the caller.
WINDOW_BYTE_FROM_BC:
        LD      D,A
        LD      A,D
        OR      A
        JR      Z,WINDOW_BYTE_DONE
WINDOW_SHIFT_LOOP:
        SLA     C
        RL      B
        DEC     D
        JR      NZ,WINDOW_SHIFT_LOOP
WINDOW_BYTE_DONE:
        LD      A,B
        RET

; RENDER_POWER_PILLS_TO_BACK
; Input:
;   VIEW_X/Y and PACMO_POWER_PILLS
; Output:
;   visible power pills rendered with PACMO_COLOR_POWER_PILL
; Clobbers:
;   A, BC, DE, HL
RENDER_POWER_PILLS_TO_BACK:
        LD      HL,PACMO_POWER_PILLS
        LD      D,1
RENDER_POWER_PILL_LOOP:
        LD      A,(HL)
        CP      0xFF
        RET     Z
        LD      B,A                     ; B = world x
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      C,A                     ; C = world y
        LD      A,(PACMO_POWER_PILLS_EATEN)
        AND     D
        JR      NZ,RENDER_POWER_PILL_NEXT
        PUSH    HL
        PUSH    DE
        CALL    RENDER_POWER_PILL_BC
        POP     DE
        POP     HL
RENDER_POWER_PILL_NEXT:
        SLA     D
        JR      RENDER_POWER_PILL_LOOP

; RENDER_POWER_PILLS_ROW_TO_BACK
; Input:
;   A = screen row 0..7
; Output:
;   visible power pills on that row rendered into FRAMEBUFFER_BACK
; Clobbers:
;   A, BC, DE, HL
RENDER_POWER_PILLS_ROW_TO_BACK:
        LD      E,A                     ; E = target screen row
        LD      HL,PACMO_POWER_PILLS
        LD      D,1
RENDER_POWER_PILL_ROW_LOOP:
        LD      A,(HL)
        CP      0xFF
        RET     Z
        LD      B,A                     ; B = world x
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      C,A                     ; C = world y
        LD      A,(PACMO_POWER_PILLS_EATEN)
        AND     D
        JR      NZ,RENDER_POWER_PILL_ROW_NEXT
        LD      A,(VIEW_Y)
        ADD     A,E
        CP      C
        JR      NZ,RENDER_POWER_PILL_ROW_NEXT
        PUSH    HL
        PUSH    DE
        CALL    RENDER_POWER_PILL_BC
        POP     DE
        POP     HL
RENDER_POWER_PILL_ROW_NEXT:
        SLA     D
        JR      RENDER_POWER_PILL_ROW_LOOP

; RENDER_POWER_PILL_BC
; Input:
;   B = world x
;   C = world y
; Output:
;   if the cell is in the viewport, its framebuffer cell is set to power-pill color
; Clobbers:
;   A, B, C, DE, HL
RENDER_POWER_PILL_BC:
        LD      A,(VIEW_Y)
        LD      E,A
        LD      A,C
        SUB     E                       ; A = screenY
        CP      ROW_COUNT
        RET     NC
        ADD     A,A
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,FRAMEBUFFER_BACK
        ADD     HL,DE

        LD      A,(VIEW_X)
        LD      E,A
        LD      A,B
        SUB     E                       ; A = screenX
        CP      ROW_COUNT
        RET     NC
        CALL    MATRIX_X_TO_MASK
        LD      C,A

        LD      A,PACMO_COLOR_POWER_PILL
        JP      FB_SET_CELL_COLOR

; RENDER_ENEMY_TO_BACK
; Input:
;   IX = monster record base
;   monster X/Y, VIEW_X/Y, monster state, PACMO_POWER_TIMER_LO/HI, respawn timer
; Output:
;   enemy pixel rendered as attack color normally or flee color when enemy state is flee,
;   replacing any path color at that cell; respawning enemy is not rendered
; Clobbers:
;   A, B, C, DE, HL
RENDER_ENEMY_TO_BACK:
        LD      A,(IX+MONSTER_RESPAWN_TIMER)
        OR      A
        RET     NZ
        LD      A,(IX+MONSTER_Y)
        LD      B,A
        LD      A,(VIEW_Y)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenY
        CP      ROW_COUNT
        RET     NC
        ADD     A,A
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,FRAMEBUFFER_BACK
        ADD     HL,DE

        LD      A,(IX+MONSTER_X)
        LD      B,A
        LD      A,(VIEW_X)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenX
        CP      ROW_COUNT
        RET     NC
        CALL    MATRIX_X_TO_MASK
        LD      C,A

        PUSH    HL
        LD      A,(IX+MONSTER_STATE)
        CP      PACMO_ENEMY_STATE_FLEE
        JR      NZ,RENDER_ENEMY_TIMER_ATTACK
        LD      HL,(PACMO_POWER_TIMER_LO)
        LD      A,H
        OR      L
        JR      Z,RENDER_ENEMY_TIMER_ATTACK
        LD      A,H
        OR      A
        JR      NZ,RENDER_ENEMY_TIMER_FLEE
        LD      A,L
        AND     PACMO_POWER_WARNING_BLINK_MASK
        JR      Z,RENDER_ENEMY_TIMER_ATTACK
RENDER_ENEMY_TIMER_FLEE:
        POP     HL
        JR      RENDER_ENEMY_FLEE
RENDER_ENEMY_TIMER_ATTACK:
        POP     HL
        LD      A,PACMO_COLOR_ENEMY_ATTACK
        JP      FB_SET_CELL_COLOR
RENDER_ENEMY_FLEE:
        LD      A,PACMO_COLOR_ENEMY_FLEE
        JP      FB_SET_CELL_COLOR

; RENDER_MONSTERS_ROW_TO_BACK
; Input:
;   A = screen row 0..7
; Output:
;   visible monsters on that row rendered into FRAMEBUFFER_BACK
; Clobbers:
;   A, BC, DE, HL, IX
RENDER_MONSTERS_ROW_TO_BACK:
        LD      C,A
        PUSH    BC
        LD      E,C
        LD      IX,MONSTER0
        CALL    RENDER_ENEMY_IF_SCREEN_ROW_E
        POP     BC
        PUSH    BC
        LD      E,C
        LD      IX,MONSTER1
        CALL    RENDER_ENEMY_IF_SCREEN_ROW_E
        POP     BC
        PUSH    BC
        CALL    PACMO_IS_LEVEL2_PLUS
        POP     BC
        RET     C
        LD      E,C
        LD      IX,MONSTER2
        JP      RENDER_ENEMY_IF_SCREEN_ROW_E

; RENDER_ENEMY_IF_SCREEN_ROW_E
; Input:
;   E = target screen row 0..7
;   IX = monster record base
; Output:
;   enemy rendered only when it is active and occupies target screen row
; Clobbers:
;   A, BC, DE, HL
RENDER_ENEMY_IF_SCREEN_ROW_E:
        LD      A,(IX+MONSTER_RESPAWN_TIMER)
        OR      A
        RET     NZ
        LD      A,(IX+MONSTER_Y)
        LD      B,A
        LD      A,(VIEW_Y)
        LD      C,A
        LD      A,B
        SUB     C
        CP      ROW_COUNT
        RET     NC
        CP      E
        RET     NZ
        PUSH    DE
        CALL    RENDER_ENEMY_TO_BACK
        POP     DE
        RET

; RENDER_PLAYER_TO_BACK
; Input:
;   PLAYER_X/Y, VIEW_X/Y
; Output:
;   player pixel rendered with palette colors; yellow normally, white when the
;   round is complete, red when caught
; Clobbers:
;   A, B, C, DE, HL
RENDER_PLAYER_TO_BACK:
        LD      A,(PLAYER_Y)
        LD      B,A
        LD      A,(VIEW_Y)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenY
        CP      ROW_COUNT
        RET     NC
        ADD     A,A
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,FRAMEBUFFER_BACK
        ADD     HL,DE

        LD      A,(PLAYER_X)
        LD      B,A
        LD      A,(VIEW_X)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenX
        CP      ROW_COUNT
        RET     NC
        CALL    MATRIX_X_TO_MASK
        LD      C,A

        LD      A,(PACMO_PLAYER_CAUGHT)
        OR      A
        JR      NZ,RENDER_PLAYER_CAUGHT

        LD      A,(PACMO_ROUND_COMPLETE)
        OR      A
        JR      NZ,RENDER_PLAYER_WHITE
        LD      A,PACMO_COLOR_PLAYER
        JP      FB_SET_CELL_COLOR
RENDER_PLAYER_WHITE:
        LD      A,PACMO_COLOR_ROUND_COMPLETE
        JP      FB_SET_CELL_COLOR
RENDER_PLAYER_CAUGHT:
        LD      A,PACMO_COLOR_ENEMY_ATTACK
        JP      FB_SET_CELL_COLOR

; RENDER_PLAYER_ROW_TO_BACK
; Input:
;   A = screen row 0..7
; Output:
;   player rendered into FRAMEBUFFER_BACK only when it occupies that row
; Clobbers:
;   A, BC, DE, HL
RENDER_PLAYER_ROW_TO_BACK:
        LD      E,A
        LD      A,(PLAYER_Y)
        LD      B,A
        LD      A,(VIEW_Y)
        LD      C,A
        LD      A,B
        SUB     C
        CP      ROW_COUNT
        RET     NC
        CP      E
        RET     NZ
        JP      RENDER_PLAYER_TO_BACK
