; Poll MON-3 keypad state and update PLAYER_X at a controlled rate.
;
; scanKeys return contract:
;   Z  = key is pressed
;   C  = new key press
;   NZ = no key / invalid key
;   A  = key code
; POLL_INPUT_AND_UPDATE
; Input:
;   none
; Output:
;   may update PLAYER_X / MOVE_COOLDOWN / LAST_KEY / SOFT_DROP via keyed handlers, or JR to CLEAR_INPUT_REPEAT_STATE when no key is pressed (idle / repeat reset path).
; Clobbers:
;   A, BC, DE, HL (rotate/soft-drop paths cascade through LOAD_CURRENT_ROTATION_STATE / LOCK_ACTIVE_PIECE)
POLL_INPUT_AND_UPDATE:
        LD      C,API_SCANKEYS
        RST     0x10
        JR      NZ,CLEAR_INPUT_REPEAT_STATE
        LD      E,A
        JR      C,KEY_NEW_PRESS
        LD      A,E
        CP      K_PAUSE
        JP      Z,CLEAR_INPUT_REPEAT_STATE
        LD      A,(PAUSED)
        OR      A
        JR      NZ,CLEAR_INPUT_REPEAT_STATE
        LD      A,E
        CP      K_ROTATE_CCW
        JR      Z,CLEAR_INPUT_REPEAT_STATE
        CP      K_ROTATE_CW
        JR      Z,CLEAR_INPUT_REPEAT_STATE
        JR      HANDLE_DIRECTION_KEY

KEY_NEW_PRESS:
        LD      A,(PAUSED)
        OR      A
        JP      NZ,HANDLE_UNPAUSE_KEY
        LD      A,E
        CP      K_PAUSE
        JP      Z,HANDLE_PAUSE_KEY
        LD      A,E
        CP      K_ROTATE
        JP      Z,HANDLE_KEY_DROP
        CP      K_ROTATE_CCW
        JP      Z,HANDLE_ROTATE_CCW_PRESS
        CP      K_ROTATE_CW
        JP      Z,HANDLE_ROTATE_PRESS
        ; fall through

HANDLE_DIRECTION_KEY:
        LD      A,E
        CP      K_RIGHT
        JP      Z,HANDLE_KEY_LEFT
        CP      K_LEFT
        JP      Z,HANDLE_KEY_RIGHT
        CP      K_ROTATE
        JP      Z,HANDLE_KEY_DROP
        CP      K_DROP
        JP      Z,HANDLE_KEY_DROP

; CLEAR_INPUT_REPEAT_STATE
; Restores MOVE_COOLDOWN full period, clears LAST_KEY and soft-drop latch.
; Used when leaving held-autorepeat path (invalid/no key, pause, rotate presses, etc.).
; Input:
;   none
; Output:
;   MOVE_COOLDOWN = MOVE_PERIOD; LAST_KEY = NO_KEY; DROP_LOCKOUT = 0
; Clobbers:
;   A
CLEAR_INPUT_REPEAT_STATE:
        LD      A,MOVE_PERIOD
        LD      (MOVE_COOLDOWN),A
        LD      A,NO_KEY
        LD      (LAST_KEY),A
        XOR     A
        LD      (DROP_LOCKOUT),A
        RET

; WAIT_GAME_OVER_KEY_GATE
; Count down main-loop iterations before POLL_GAME_OVER_RESTART (PRESS ANY KEY) during GAME_OVER.
; Chirps SOUND_TRIGGER_GAME_OVER_RESTART_READY exactly when the counter reaches zero.
; Input:
;   GAME_OVER_KEY_GATE_LO/HI
; Output:
;   GAME_OVER_KEY_GATE_LO decremented; tail-calls POLL_GAME_OVER_RESTART once gate = 0
; Clobbers:
;   A, C, HL
WAIT_GAME_OVER_KEY_GATE:
        LD      HL,(GAME_OVER_KEY_GATE_LO)
        LD      A,H
        OR      L
        JP      Z,POLL_GAME_OVER_RESTART

        DEC     HL
        LD      (GAME_OVER_KEY_GATE_LO),HL
        LD      A,H
        OR      L
        RET     NZ

        CALL    SOUND_TRIGGER_GAME_OVER_RESTART_READY
        RET

; POLL_GAME_OVER_RESTART
; Input:
;   none
; Output:
;   restarts the game on a fresh key press
; Clobbers:
;   A, C
POLL_GAME_OVER_RESTART:
        LD      C,API_SCANKEYS
        RST     0x10
        RET     NC
        JP      INIT_STATE_RESTART

; WAIT_FOR_KEY_RELEASE
; Input:
;   INPUT_LOCKOUT
; Output:
;   clears INPUT_LOCKOUT once no key is pressed
; Clobbers:
;   A, C
WAIT_FOR_KEY_RELEASE:
        LD      C,API_SCANKEYS
        RST     0x10
        RET     Z
        XOR     A
        LD      (INPUT_LOCKOUT),A
        RET

; HANDLE_PAUSE_KEY
; Toggles PAUSED; swaps LCD between RUNNING/PAUSED banner.
; Clobbers:
;   A
HANDLE_PAUSE_KEY:
        LD      A,(PAUSED)
        XOR     1
        LD      (PAUSED),A
        OR      A
        JR      Z,HANDLE_PAUSE_SHOW_RUNNING
        CALL    LCD_SHOW_PAUSED
        JP      CLEAR_INPUT_REPEAT_STATE
HANDLE_PAUSE_SHOW_RUNNING:
        CALL    LCD_SHOW_RUNNING
        JP      CLEAR_INPUT_REPEAT_STATE

; HANDLE_UNPAUSE_KEY
; Clears PAUSED, restores RUNNING banner.
; Clobbers:
;   A
HANDLE_UNPAUSE_KEY:
        XOR     A
        LD      (PAUSED),A
        CALL    LCD_SHOW_RUNNING
        JP      CLEAR_INPUT_REPEAT_STATE

; HANDLE_ROTATE_PRESS
; Keyboard dispatch for clockwise rotation with collision check.
; Clobbers:
;   A, C, DE, HL
HANDLE_ROTATE_PRESS:
        CALL    ROTATE_CW
        JP      CLEAR_INPUT_REPEAT_STATE

; HANDLE_ROTATE_CCW_PRESS
; Keyboard dispatch for counter-clockwise rotation with collision check.
; Clobbers:
;   A, C, DE, HL
HANDLE_ROTATE_CCW_PRESS:
        CALL    ROTATE_LEFT
        JP      CLEAR_INPUT_REPEAT_STATE

; HANDLE_KEY_RIGHT
; Tail-calls HANDLE_HELD_DIRECTION with A = K_LEFT.
; Clobbers:
;   A, DE
HANDLE_KEY_RIGHT:
        LD      A,K_LEFT
        JP      HANDLE_HELD_DIRECTION

; HANDLE_KEY_LEFT
; Tail-calls HANDLE_HELD_DIRECTION with A = K_RIGHT.
; Clobbers:
;   A, DE
HANDLE_KEY_LEFT:
        LD      A,K_RIGHT
        JP      HANDLE_HELD_DIRECTION

; HANDLE_KEY_DROP
; Input:
;   none (DROP_LOCKOUT gates repeat firing)
; Output:
;   tail-calls HANDLE_HELD_DIRECTION with A = K_DROP once lockout clears
; Clobbers:
;   A, DE
HANDLE_KEY_DROP:
        LD      A,(DROP_LOCKOUT)
        OR      A
        RET     NZ
        LD      A,K_DROP
        JP      HANDLE_HELD_DIRECTION

; HANDLE_HELD_DIRECTION
; Input:
;   A = K_LEFT, K_RIGHT, or K_DROP (held/repeat timing path via LAST_KEY/MOVE_COOLDOWN)
; Output:
;   may update PLAYER_X / PLAYER_Y / MOVE_COOLDOWN / LAST_KEY
; Clobbers:
;   A, DE on MOVE_LEFT/RIGHT; A, BC, DE, HL on SOFT_DROP lock-path
HANDLE_HELD_DIRECTION:
        LD      E,A
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

        LD      A,E
        CP      K_DROP
        JR      NZ,HELD_DIRECTION_NORMAL_RATE
        LD      A,DROP_PERIOD
        JR      HELD_DIRECTION_RATE_SET
HELD_DIRECTION_NORMAL_RATE:
        LD      A,MOVE_PERIOD
HELD_DIRECTION_RATE_SET:
        LD      (MOVE_COOLDOWN),A
        LD      A,E
        CP      K_RIGHT
        JP      Z,MOVE_LEFT
        CP      K_LEFT
        JP      Z,MOVE_RIGHT
        CP      K_DROP
        JP      Z,SOFT_DROP
        RET
