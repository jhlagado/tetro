; Poll keypad and move the Pacmo cursor at a controlled repeat rate.
;
; Direction mapping for this first scrolling experiment:
;   K_LEFT  (0x10) = left
;   K_RIGHT (0x11) = right
;   ADD     (0x13) = up
;   GO      (0x12) = down
;   key 8   (0x08) = up
;   key 0   (0x00) = down
;   key 5   (0x05) = right
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
        LD      C,API_SCANKEYS
        RST     0x10
        JR      NZ,CLEAR_INPUT_REPEAT_STATE

        CALL    NORMALIZE_INPUT_TO_DIRECTION
        JR      C,HANDLE_DIRECTION_KEY
        JR      CLEAR_INPUT_REPEAT_STATE

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
        CP      K_LEFT
        JR      Z,NORMALIZE_LEFT
        CP      K_RIGHT
        JR      Z,NORMALIZE_RIGHT
        CP      0x05
        JR      Z,NORMALIZE_RIGHT
        CP      K_ROTATE_CCW
        JR      Z,NORMALIZE_UP
        CP      0x08
        JR      Z,NORMALIZE_UP
        CP      K_ROTATE
        JR      Z,NORMALIZE_DOWN
        CP      K_DROP
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
;   decrements PLAYER_X unless already at world column 0 or target is a wall
; Clobbers:
;   A, BC, DE, HL
MOVE_PLAYER_LEFT:
        LD      A,(PLAYER_X)
        OR      A
        RET     Z
        DEC     A
        LD      B,A
        LD      A,(PLAYER_Y)
        LD      C,A
        JP      TRY_MOVE_PLAYER_TO_BC

; MOVE_PLAYER_RIGHT
; Input:
;   PLAYER_X
; Output:
;   increments PLAYER_X unless already at world column 14 or target is a wall
; Clobbers:
;   A, BC, DE, HL
MOVE_PLAYER_RIGHT:
        LD      A,(PLAYER_X)
        CP      PACMO_WORLD_MAX
        RET     NC
        INC     A
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
        JP      UPDATE_VIEWPORT_FOR_PLAYER

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
