; HORIZONTAL_PROBE_APPLY_PENDING_X
; Input:
;   PENDING_X/Y set for candidate lateral move (PLAYER_Y echoed into PENDING_Y)
; Output:
;   on success, PLAYER_X := PENDING_X
; Clobbers:
;   A, DE
HORIZONTAL_PROBE_APPLY_PENDING_X:
        LD      A,(PLAYER_Y)
        LD      (PENDING_Y),A
        CALL    LOAD_DE_FROM_PENDING
        CALL    CHECK_COLLISION_AT_DE
        JR      NC,HORIZONTAL_COMMIT_PLAYER_X
        RET
HORIZONTAL_COMMIT_PLAYER_X:
        LD      A,(PENDING_X)
        LD      (PLAYER_X),A
        RET

; MOVE_RIGHT
; Input:
;   none
; Output:
;   may increment PLAYER_X if candidate placement is legal
; Clobbers:
;   A, DE
MOVE_RIGHT:
        LD      A,(PLAYER_X)
        INC     A
        LD      (PENDING_X),A
        JP      HORIZONTAL_PROBE_APPLY_PENDING_X

; MOVE_LEFT
; Input:
;   none
; Output:
;   may decrement PLAYER_X if candidate placement is legal
; Clobbers:
;   A, DE
MOVE_LEFT:
        LD      A,(PLAYER_X)
        OR      A
        RET     Z
        DEC     A
        LD      (PENDING_X),A
        JP      HORIZONTAL_PROBE_APPLY_PENDING_X

; STEP_ACTIVE_DOWN_ONE_CELL
; Input:
;   PLAYER_X / PLAYER_Y
; Output:
;   pending one row down; Carry from CHECK_COLLISION_AT_DE (CY = collision/block)
; Clobbers:
;   A, DE
STEP_ACTIVE_DOWN_ONE_CELL:
        LD      A,(PLAYER_X)
        LD      (PENDING_X),A
        LD      A,(PLAYER_Y)
        INC     A
        LD      (PENDING_Y),A
        CALL    LOAD_DE_FROM_PENDING
        CALL    CHECK_COLLISION_AT_DE
        RET

; APPLY_GRAVITY
; Input:
;   none
; Output:
;   may update PLAYER_Y, or lock and respawn active piece on collision
; Clobbers:
;   A, DE on commit; A, BC, DE, HL on lock (tail-calls LOCK_ACTIVE_PIECE)
APPLY_GRAVITY:
        LD      A,(GRAVITY_COOLDOWN)
        DEC     A
        LD      (GRAVITY_COOLDOWN),A
        RET     NZ

        LD      A,(CURRENT_GRAVITY_PERIOD)
        LD      (GRAVITY_COOLDOWN),A

        CALL    STEP_ACTIVE_DOWN_ONE_CELL
        JR      NC,GRAVITY_COMMIT
        JP      LOCK_ACTIVE_PIECE
GRAVITY_COMMIT:
        LD      A,(PENDING_Y)
        LD      (PLAYER_Y),A
        RET

; SOFT_DROP
; Input:
;   none
; Output:
;   may update PLAYER_Y, or lock and respawn active piece on collision
; Clobbers:
;   A, DE on commit; A, BC, DE, HL on lock (tail-calls LOCK_ACTIVE_PIECE)
SOFT_DROP:
        CALL    STEP_ACTIVE_DOWN_ONE_CELL
        JR      NC,SOFT_DROP_COMMIT
        LD      A,1
        LD      (DROP_LOCKOUT),A
        JP      LOCK_ACTIVE_PIECE
SOFT_DROP_COMMIT:
        LD      A,(PENDING_Y)
        LD      (PLAYER_Y),A
        LD      A,(CURRENT_GRAVITY_PERIOD)
        LD      (GRAVITY_COOLDOWN),A
        RET
; SANITIZE_ACTIVE_POSITION
; Input:
;   PLAYER_X, PLAYER_Y in RAM
; Output:
;   PLAYER_X clamped to X_MIN..X_MAX
;   PLAYER_Y clamped to Y_MAX (negative spawn rows preserved)
; Clobbers:
;   A, HL
SANITIZE_ACTIVE_POSITION:
        LD      A,(PLAYER_X)
        LD      HL,CURRENT_PIECE_RIGHT
        ADD     A,(HL)
        CP      ROW_COUNT
        JR      C,SANITIZE_X_DONE
        LD      A,ROW_COUNT-1
        SUB     (HL)
        LD      (PLAYER_X),A
SANITIZE_X_DONE:
        LD      A,(PLAYER_Y)
        BIT     7,A
        JR      NZ,SANITIZE_Y_DONE
        CP      Y_MAX+1
        JR      C,SANITIZE_Y_DONE
        LD      A,Y_MAX
        LD      (PLAYER_Y),A
SANITIZE_Y_DONE:
        RET

; SELECT_NEXT_PIECE
; Input:
;   NEXT_PIECE_INDEX in RAM
; Output:
;   CURRENT_PIECE_INDEX / CURRENT_ROTATION updated
;   CURRENT_PIECE_PTR / CURRENT_PIECE_RIGHT / CURRENT_PIECE_COLOR updated
;   NEXT_PIECE_INDEX advanced modulo PIECE_COUNT
; Clobbers:
;   A, BC, DE, HL
SELECT_NEXT_PIECE:
        LD      A,(NEXT_PIECE_INDEX)
        LD      (CURRENT_PIECE_INDEX),A
        XOR     A
        LD      (CURRENT_ROTATION),A
        CALL    LOAD_CURRENT_ROTATION_STATE

        CALL    RNG_NEXT_PIECE
        LD      (NEXT_PIECE_INDEX),A
        RET

; RNG_NEXT_PIECE
; Input:
;   RNG_SEED
; Output:
;   A = next piece index 0..6
;   RNG_SEED advanced
; Clobbers:
;   A, B
RNG_NEXT_PIECE:
        CALL    RNG_NEXT8
        LD      B,A
        SRL     A
        SRL     A
        SRL     A
        XOR     B                       ; fold high bits into sticky low bits
        AND     0x07
        CP      PIECE_COUNT
        JR      NC,RNG_NEXT_PIECE
        RET

; RNG_NEXT8
; Input:
;   RNG_SEED
; Output:
;   A = next pseudo-random byte
;   RNG_SEED advanced
; Clobbers:
;   A
RNG_NEXT8:
        LD      A,(RNG_SEED)
        OR      A
        JR      NZ,RNG_NEXT8_STEP
        LD      A,RNG_SEED_INIT
RNG_NEXT8_STEP:
        SRL     A
        JR      NC,RNG_NEXT8_SAVE
        XOR     0xB8
RNG_NEXT8_SAVE:
        LD      (RNG_SEED),A
        RET

; LOAD_CURRENT_ROTATION_STATE
; Input:
;   CURRENT_PIECE_INDEX / CURRENT_ROTATION in RAM
; Output:
;   CURRENT_PIECE_PTR / CURRENT_PIECE_RIGHT / CURRENT_PIECE_COLOR updated
; Clobbers:
;   A, C, DE, HL
LOAD_CURRENT_ROTATION_STATE:
        ; COLOR lookup first (indexed by piece only) so DE is still free.
        LD      A,(CURRENT_PIECE_INDEX)
        LD      E,A
        LD      D,0
        LD      HL,PIECE_COLOR_TABLE
        ADD     HL,DE
        LD      A,(HL)
        LD      (CURRENT_PIECE_COLOR),A

        ; Now DE = piece_index*4 + rotation for the remaining tables.
        LD      A,(CURRENT_PIECE_INDEX)
        ADD     A,A
        ADD     A,A
        LD      C,A
        LD      A,(CURRENT_ROTATION)
        ADD     A,C
        LD      E,A
        LD      D,0

        LD      HL,PIECE_RIGHT_TABLE
        ADD     HL,DE
        LD      A,(HL)
        LD      (CURRENT_PIECE_RIGHT),A

        LD      HL,PIECE_PTR_TABLE
        ADD     HL,DE
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      HL,CURRENT_PIECE_PTR
        LD      (HL),E
        INC     HL
        LD      (HL),D
        RET

; ROTATE_FINISH_TEST
; Prerequisites: tentative rotation loaded via LOAD_CURRENT_ROTATION_STATE,
; CURRENT_ROTATION = candidate; COLLISION_AT(PLAYER_X, PLAYER_Y) decides accept.
; Rotates back (restore PENDING_ROTATION) + reload if illegal.
; Input:
;   CURRENT_ROTATION (candidate), PENDING_ROTATION (previous), PLAYER_X/Y
; Output:
;   commit on legal; revert + reload on collision
; Clobbers:
;   A, C, DE, HL
ROTATE_FINISH_TEST:
        LD      A,(PLAYER_X)
        LD      D,A
        LD      A,(PLAYER_Y)
        LD      E,A
        CALL    CHECK_COLLISION_AT_DE
        JR      NC,ROTATE_ACCEPT_COMMIT
        LD      A,(PENDING_ROTATION)
        LD      (CURRENT_ROTATION),A
        JP      LOAD_CURRENT_ROTATION_STATE
ROTATE_ACCEPT_COMMIT:
        CALL    SOUND_TRIGGER_ROTATE
        LD      A,(CURRENT_GRAVITY_PERIOD)
        LD      (GRAVITY_COOLDOWN),A
        RET

; ROTATE_CW
; Input:
;   current active piece state in RAM
; Output:
;   may update CURRENT_ROTATION if rotated placement is legal
; Clobbers:
;   A, C, DE, HL
ROTATE_CW:
        LD      A,(CURRENT_ROTATION)
        LD      (PENDING_ROTATION),A
        INC     A
        AND     3
        LD      (CURRENT_ROTATION),A
        CALL    LOAD_CURRENT_ROTATION_STATE
        JP      ROTATE_FINISH_TEST

; ROTATE_LEFT
; Input:
;   current active piece state in RAM
; Output:
;   may update CURRENT_ROTATION if rotated placement is legal
; Clobbers:
;   A, C, DE, HL
ROTATE_LEFT:
        LD      A,(CURRENT_ROTATION)
        LD      (PENDING_ROTATION),A
        DEC     A                       ; 0->0xFF; 1->0; 2->1; 3->2
        AND     3                       ; 0xFF -> 3 (wrap)
        LD      (CURRENT_ROTATION),A
        CALL    LOAD_CURRENT_ROTATION_STATE
        JP      ROTATE_FINISH_TEST

; SPAWN_ACTIVE_PIECE
; Input:
;   none
; Output:
;   active-piece state reset to spawn position
;   returns fault if spawn collides immediately
;   (Full `LCD_SHOW_RUNNING` left to splash/restart; each successful spawn
;    refreshes row 3 next-piece preview via LCD_REFRESH_NEXT_PREVIEW_ROW.)
; Clobbers:
;   A, BC, DE, HL
SPAWN_ACTIVE_PIECE:
        CALL    SELECT_NEXT_PIECE
        LD      A,3
        LD      (PLAYER_X),A
        LD      (PENDING_X),A          ; PLAYER_X == PENDING_X at spawn
        LD      A,SPAWN_Y
        LD      (PLAYER_Y),A
        LD      (PENDING_Y),A          ; PLAYER_Y == PENDING_Y at spawn
        LD      A,MOVE_PERIOD
        LD      (MOVE_COOLDOWN),A
        LD      A,(CURRENT_GRAVITY_PERIOD)
        LD      (GRAVITY_COOLDOWN),A
        LD      A,NO_KEY
        LD      (LAST_KEY),A
        CALL    LOAD_DE_FROM_PENDING
        CALL    CHECK_COLLISION_AT_DE
        JR      C,SPAWN_FAILED
        LD      A,1
        LD      (ACTIVE_PIECE_ENABLED),A
        CALL    LCD_REFRESH_NEXT_PREVIEW_ROW
        RET
SPAWN_FAILED:
        XOR     A                      ; reason code 0 = immediate spawn collision
        JP      ENTER_GAME_OVER        ; tail-call; ENTER_GAME_OVER tail-calls LCD_SHOW_*
