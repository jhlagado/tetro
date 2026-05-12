; Poll keypad and move the Pacmo cursor at a controlled repeat rate.
;
; Direction mapping for this first scrolling experiment:
;   K_LEFT  (0x10) = left
;   K_RIGHT (0x11) = right
;   key 2   (0x02) = up
;   key 0   (0x00) = down
;
; POLL_INPUT_AND_UPDATE
; Input:
;   none
; Output:
;   may update PLAYER_X/Y, VIEW_X/Y, MOVE_COOLDOWN, LAST_KEY
; Clobbers:
;   A, B, C, E
POLL_INPUT_AND_UPDATE:
        LD      C,API_SCANKEYS
        RST     0x10
        JR      NZ,CLEAR_INPUT_REPEAT_STATE

        LD      E,A
        LD      A,E
        CP      K_LEFT
        JR      Z,HANDLE_DIRECTION_KEY
        CP      K_RIGHT
        JR      Z,HANDLE_DIRECTION_KEY
        CP      K_ROTATE_CCW_ALT
        JR      Z,HANDLE_DIRECTION_KEY
        CP      K_DROP
        JR      Z,HANDLE_DIRECTION_KEY
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
        CP      K_LEFT
        JR      Z,MOVE_PLAYER_LEFT
        CP      K_RIGHT
        JR      Z,MOVE_PLAYER_RIGHT
        CP      K_ROTATE_CCW_ALT
        JR      Z,MOVE_PLAYER_UP
        CP      K_DROP
        JR      Z,MOVE_PLAYER_DOWN
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
;   decrements PLAYER_X unless already at world column 0; viewport adjusted
; Clobbers:
;   A
MOVE_PLAYER_LEFT:
        LD      A,(PLAYER_X)
        OR      A
        RET     Z
        DEC     A
        LD      (PLAYER_X),A
        JP      UPDATE_VIEWPORT_FOR_PLAYER

; MOVE_PLAYER_RIGHT
; Input:
;   PLAYER_X
; Output:
;   increments PLAYER_X unless already at world column 14; viewport adjusted
; Clobbers:
;   A
MOVE_PLAYER_RIGHT:
        LD      A,(PLAYER_X)
        CP      PACMO_WORLD_MAX
        RET     NC
        INC     A
        LD      (PLAYER_X),A
        JP      UPDATE_VIEWPORT_FOR_PLAYER

; MOVE_PLAYER_UP
; Input:
;   PLAYER_Y
; Output:
;   decrements PLAYER_Y unless already at world row 0; viewport adjusted
; Clobbers:
;   A
MOVE_PLAYER_UP:
        LD      A,(PLAYER_Y)
        OR      A
        RET     Z
        DEC     A
        LD      (PLAYER_Y),A
        JP      UPDATE_VIEWPORT_FOR_PLAYER

; MOVE_PLAYER_DOWN
; Input:
;   PLAYER_Y
; Output:
;   increments PLAYER_Y unless already at world row 14; viewport adjusted
; Clobbers:
;   A
MOVE_PLAYER_DOWN:
        LD      A,(PLAYER_Y)
        CP      PACMO_WORLD_MAX
        RET     NC
        INC     A
        LD      (PLAYER_Y),A
        JP      UPDATE_VIEWPORT_FOR_PLAYER

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
