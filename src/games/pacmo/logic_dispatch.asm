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

; TICK_POWER_TIMER
; Input:
;   PACMO_POWER_TIMER
; Output:
;   decrements PACMO_POWER_TIMER by one when nonzero
; Clobbers:
;   A, HL
TICK_POWER_TIMER:
        LD      HL,PACMO_POWER_TIMER
        LD      A,(HL)
        OR      A
        RET     Z
        DEC     A
        LD      (HL),A
        RET

; TICK_ENEMY
; Input:
;   ENEMY_X, ENEMY_DIR, ENEMY_TIMER
; Output:
;   enemy patrol advances one world cell when ENEMY_TIMER reaches zero
; Clobbers:
;   A, HL
TICK_ENEMY:
        LD      A,(PACMO_PLAYER_CAUGHT)
        OR      A
        RET     NZ
        LD      HL,ENEMY_TIMER
        LD      A,(HL)
        DEC     A
        LD      (HL),A
        RET     NZ
        LD      A,PACMO_ENEMY_PERIOD
        LD      (HL),A

        LD      A,(ENEMY_DIR)
        OR      A
        JR      NZ,TICK_ENEMY_LEFT
TICK_ENEMY_RIGHT:
        LD      A,(ENEMY_X)
        CP      PACMO_ENEMY_MAX_X
        JR      NC,TICK_ENEMY_TURN_LEFT
        INC     A
        LD      (ENEMY_X),A
        RET
TICK_ENEMY_TURN_LEFT:
        LD      A,PACMO_ENEMY_DIR_LEFT
        LD      (ENEMY_DIR),A
        LD      A,(ENEMY_X)
        DEC     A
        LD      (ENEMY_X),A
        RET
TICK_ENEMY_LEFT:
        LD      A,(ENEMY_X)
        CP      PACMO_ENEMY_MIN_X
        JR      Z,TICK_ENEMY_TURN_RIGHT
        DEC     A
        LD      (ENEMY_X),A
        RET
TICK_ENEMY_TURN_RIGHT:
        LD      A,PACMO_ENEMY_DIR_RIGHT
        LD      (ENEMY_DIR),A
        LD      A,(ENEMY_X)
        INC     A
        LD      (ENEMY_X),A
        RET
