; REBUILD_FRAMEBUFFER
; Input:
;   current viewport and player state in RAM
; Output:
;   FRAMEBUFFER rebuilt from scratch
; Clobbers:
;   A, BC, DE, HL
REBUILD_FRAMEBUFFER:
        CALL    CLEAR_BACK_ALL
        CALL    RENDER_WORLD_TO_BACK
        CALL    RENDER_POWER_PILLS_TO_BACK
        CALL    RENDER_ENEMY_TO_BACK
        CALL    RENDER_PLAYER_TO_BACK
        JP      COPY_BACK_TO_FRONT

; CLEAR_BACK_ALL
; Input:
;   none
; Output:
;   FRAMEBUFFER_BACK cleared to zero
; Clobbers:
;   A, B, HL
CLEAR_BACK_ALL:
        LD      HL,FRAMEBUFFER_BACK
        LD      B,FRAMEBUFFER_BYTES
        XOR     A
CLEAR_BACK_ALL_LOOP:
        LD      (HL),A
        INC     HL
        DJNZ    CLEAR_BACK_ALL_LOOP
        RET

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

; Clear 4 bytes at FRAMEBUFFER_BACK + A.
; CLEAR_BACK_4
; Input:
;   A = byte offset into FRAMEBUFFER_BACK, expected 0,4,8,...,28
; Output:
;   selected 4-byte row cleared
; Clobbers:
;   A, DE, HL
CLEAR_BACK_4:
        LD      E,A
        LD      D,0
        LD      HL,FRAMEBUFFER_BACK
        ADD     HL,DE
        XOR     A
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (HL),A
        RET

; COPY_BACK_TO_FRONT
; Input:
;   FRAMEBUFFER_BACK contains completed image
; Output:
;   FRAMEBUFFER overwritten from FRAMEBUFFER_BACK
; Clobbers:
;   BC, DE, HL
COPY_BACK_TO_FRONT:
        LD      HL,FRAMEBUFFER_BACK
        LD      DE,FRAMEBUFFER
        LD      BC,FRAMEBUFFER_BYTES
        LDIR
        RET

; RENDER_WORLD_TO_BACK
; Input:
;   VIEW_X/Y and PACMO_WORLD_ROWS
; Output:
;   visible 8x8 viewport rendered with PACMO_COLOR_PATH and PACMO_COLOR_WALL
; Clobbers:
;   A, BC, DE, HL
RENDER_WORLD_TO_BACK:
        LD      HL,FRAMEBUFFER_BACK
        LD      A,(VIEW_Y)
        ADD     A,A
        LD      E,A
        LD      D,0
        PUSH    HL
        LD      HL,PACMO_WORLD_ROWS
        ADD     HL,DE
        EX      DE,HL                   ; DE = source world row pointer
        POP     HL                      ; HL = framebuffer row pointer
        PUSH    HL
        LD      A,(VIEW_Y)
        ADD     A,A
        LD      L,A
        LD      H,0
        LD      BC,PACMO_EATEN_ROWS
        ADD     HL,BC
        LD      (RENDER_EATEN_PTR),HL
        POP     HL
        LD      B,ROW_COUNT
RENDER_WORLD_ROW:
        PUSH    BC
        LD      A,(DE)
        LD      B,A                     ; B = high byte of 15-bit row
        INC     DE
        LD      A,(DE)
        LD      C,A                     ; C = low byte of 15-bit row
        INC     DE
        LD      A,(VIEW_X)
        PUSH    DE
        CALL    WINDOW_BYTE_FROM_BC
        POP     DE
        LD      C,A                     ; C = visible wall mask
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      HL,(RENDER_EATEN_PTR)
        LD      B,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      (RENDER_EATEN_PTR),HL
        LD      A,(VIEW_X)
        CALL    WINDOW_BYTE_FROM_BC
        POP     HL
        POP     DE
        POP     BC
        LD      B,A                     ; B = visible eaten mask
        LD      A,C
        OR      B
        CPL                             ; A = visible uneaten open path mask
        PUSH    DE
        LD      D,A
        CALL    WRITE_WORLD_ROW_COLORS
        POP     DE
        INC     HL                      ; aux byte
        POP     BC
        DJNZ    RENDER_WORLD_ROW
        RET

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
        CALL    SCREEN_X_TO_MASK
        LD      C,A

        LD      A,PACMO_COLOR_POWER_PILL
        JP      WRITE_CELL_COLOR_C_A

; RENDER_ENEMY_TO_BACK
; Input:
;   ENEMY_X/Y, VIEW_X/Y, ENEMY_STATE, PACMO_POWER_TIMER_LO/HI, ENEMY_RESPAWN_TIMER
; Output:
;   enemy pixel rendered as attack color normally or flee color when enemy state is flee,
;   replacing any path color at that cell; respawning enemy is not rendered
; Clobbers:
;   A, B, C, DE, HL
RENDER_ENEMY_TO_BACK:
        LD      A,(ENEMY_RESPAWN_TIMER)
        OR      A
        RET     NZ
        LD      A,(ENEMY_Y)
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

        LD      A,(ENEMY_X)
        LD      B,A
        LD      A,(VIEW_X)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenX
        CP      ROW_COUNT
        RET     NC
        CALL    SCREEN_X_TO_MASK
        LD      C,A

        PUSH    HL
        LD      A,(ENEMY_STATE)
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
        JP      WRITE_CELL_COLOR_C_A
RENDER_ENEMY_FLEE:
        LD      A,PACMO_COLOR_ENEMY_FLEE
        JP      WRITE_CELL_COLOR_C_A

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
        CALL    SCREEN_X_TO_MASK
        LD      C,A

        LD      A,(PACMO_PLAYER_CAUGHT)
        OR      A
        JR      NZ,RENDER_PLAYER_CAUGHT

        LD      A,(PACMO_ROUND_COMPLETE)
        OR      A
        JR      NZ,RENDER_PLAYER_WHITE
        LD      A,PACMO_COLOR_PLAYER
        JP      WRITE_CELL_COLOR_C_A
RENDER_PLAYER_WHITE:
        LD      A,PACMO_COLOR_ROUND_COMPLETE
        JP      WRITE_CELL_COLOR_C_A
RENDER_PLAYER_CAUGHT:
        LD      A,PACMO_COLOR_ENEMY_ATTACK
        JP      WRITE_CELL_COLOR_C_A

; WRITE_CELL_COLOR_C_A
; Input:
;   HL = red plane byte for the target row
;   C  = target cell bit mask
;   A  = COLOR_* bitfield
; Output:
;   target cell set to the requested color, replacing previous RGB bits
; Clobbers:
;   A, B, D, HL
WRITE_CELL_COLOR_C_A:
        LD      B,A
        LD      A,C
        CPL
        LD      D,A
        LD      A,B
        AND     COLOR_RED
        JR      Z,WRITE_CELL_RED_OFF
        LD      A,(HL)
        OR      C
        JR      WRITE_CELL_RED_STORE
WRITE_CELL_RED_OFF:
        LD      A,(HL)
        AND     D
WRITE_CELL_RED_STORE:
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     COLOR_GREEN
        JR      Z,WRITE_CELL_GREEN_OFF
        LD      A,(HL)
        OR      C
        JR      WRITE_CELL_GREEN_STORE
WRITE_CELL_GREEN_OFF:
        LD      A,(HL)
        AND     D
WRITE_CELL_GREEN_STORE:
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     COLOR_BLUE
        JR      Z,WRITE_CELL_BLUE_OFF
        LD      A,(HL)
        OR      C
        JR      WRITE_CELL_BLUE_STORE
WRITE_CELL_BLUE_OFF:
        LD      A,(HL)
        AND     D
WRITE_CELL_BLUE_STORE:
        LD      (HL),A
        RET

; SCREEN_X_TO_MASK
; Input:
;   A = screen x coordinate, expected 0..7
; Output:
;   A = bit mask with column 0 as MSB
; Clobbers:
;   B, C
SCREEN_X_TO_MASK:
        LD      C,A
        OR      A
        LD      A,0x80
        JR      Z,SCREEN_X_TO_MASK_DONE
        LD      B,C
SCREEN_X_TO_MASK_LOOP:
        SRL     A
        DJNZ    SCREEN_X_TO_MASK_LOOP
SCREEN_X_TO_MASK_DONE:
        RET
