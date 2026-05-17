; LOCK_ACTIVE_PIECE
; Active piece state (PLAYER_X/Y, CURRENT_PIECE_*), BOARD_ROWS / BOARD_*.
; Active piece merged into board; line-clear queued, next piece spawned.
; Top-out enters ENTER_GAME_OVER.
; @clobbers A,BC,DE,HL.
LOCK_ACTIVE_PIECE:
        CALL    CHECK_TOP_OUT_ON_LOCK
        JR      C,LOCK_GAME_OVER
        CALL    MERGE_ACTIVE_TO_BOARD
        CALL    CHECK_FULL_ROWS
        JR      NC,LOCK_ACTIVE_NO_CLEAR
        CALL    SOUND_TRIGGER_CLEAR
        XOR     A
        LD      (ACTIVE_PIECE_ENABLED),A
        LD      A,1
        LD      (CLEAR_PENDING),A
        LD      A,LINE_CLEAR_HOLD
        LD      (CLEAR_TIMER),A
        RET
LOCK_ACTIVE_NO_CLEAR:
        CALL    SOUND_TRIGGER_LOCK
        CALL    SPAWN_ACTIVE_PIECE
        RET

LOCK_GAME_OVER:
        CALL    MERGE_ACTIVE_TO_BOARD
        LD      A,4
        CALL    ENTER_GAME_OVER
        RET

; ENTER_GAME_OVER
; @in A game-over reason code.
; GAME_OVER latched, active piece disabled, framebuffer rebuilt, LCD updated.
; @clobbers A,BC,DE,HL.
ENTER_GAME_OVER:
        PUSH    AF
        XOR     A
        LD      (ACTIVE_PIECE_ENABLED),A
        LD      A,1
        LD      (GAME_OVER),A
        LD      HL,GAME_OVER_KEY_GATE_TICKS
        LD      (GAME_OVER_KEY_GATE_LO),HL
        POP     AF
        CALL    SOUND_TRIGGER_GAME_OVER
        CALL    REBUILD_FRAMEBUFFER
        JP      LCD_SHOW_GAME_OVER

; HANDLE_SPLASH_STATE
; SPLASH_TIMER / FRAME_PHASE.
; Waits for a fresh key press, then seeds the RNG and starts a new game.
; @clobbers A,BC,DE,HL.
HANDLE_SPLASH_STATE:
        LD      C,API_SCANKEYS
        RST     0x10
        RET     NC
        XOR     A
        LD      (SPLASH_TIMER),A
        LD      A,(FRAME_PHASE)
        OR      A
        JR      NZ,HANDLE_SPLASH_SEED_READY
        LD      A,RNG_SEED_INIT
HANDLE_SPLASH_SEED_READY:
        LD      (RNG_SEED),A
        CALL    RNG_NEXT_PIECE
        LD      (NEXT_PIECE_INDEX),A
        LD      A,1
        LD      (INPUT_LOCKOUT),A
        CALL    SPAWN_ACTIVE_PIECE
        CALL    UPDATE_SCORE_DISPLAY
        CALL    LCD_SHOW_RUNNING
        JP      REBUILD_FRAMEBUFFER

; HANDLE_LINE_CLEAR_STATE
; CLEAR_PENDING / CLEAR_TIMER / LOGIC_SLICE in RAM.
; Advances clear-hold countdown once per full logic cycle.
; Collapses full rows and spawns next piece when timer expires.
; @clobbers A,BC,DE,HL.
HANDLE_LINE_CLEAR_STATE:
        LD      A,(LOGIC_SLICE)
        OR      A
        RET     NZ
        LD      A,(CLEAR_TIMER)
        DEC     A
        LD      (CLEAR_TIMER),A
        RET     NZ
        CALL    COLLAPSE_FULL_ROWS
        CALL    APPLY_CLEAR_SCORE
        XOR     A
        LD      (CLEAR_PENDING),A
        CALL    RECOMPUTE_BOARD_EMPTY
        JP      SPAWN_ACTIVE_PIECE

; CHECK_FULL_ROWS
; Reads BOARD_ROWS.
; @out carry set when one or more rows are full.
; CLEAR_MASK updated.
; @clobbers A,BC,E,HL while building CLEAR_MASK.
CHECK_FULL_ROWS:
        LD      HL,BOARD_ROWS
        LD      B,ROW_COUNT
        LD      C,1
        XOR     A
        LD      E,A
CHECK_FULL_ROWS_LOOP:
        LD      A,(HL)
        CP      0xFF
        JR      NZ,CHECK_FULL_ROWS_NEXT
        LD      A,E
        OR      C
        LD      E,A
CHECK_FULL_ROWS_NEXT:
        INC     HL
        SLA     C
        DJNZ    CHECK_FULL_ROWS_LOOP
        LD      A,E
        LD      (CLEAR_MASK),A
        OR      A
        JR      Z,CHECK_FULL_ROWS_NONE
        SCF
        RET
CHECK_FULL_ROWS_NONE:
        OR      A
        RET

; COUNT_CLEAR_ROWS
; Reads CLEAR_MASK.
; @out A the number of rows marked in CLEAR_MASK.
; @clobbers BC while counting the mask bits.
COUNT_CLEAR_ROWS:
        LD      A,(CLEAR_MASK)
        LD      C,A
        LD      B,0
COUNT_CLEAR_ROWS_LOOP:
        LD      A,C
        OR      A
        JR      Z,COUNT_CLEAR_ROWS_DONE
        SRL     C
        JR      NC,COUNT_CLEAR_ROWS_LOOP
        INC     B
        JR      COUNT_CLEAR_ROWS_LOOP
COUNT_CLEAR_ROWS_DONE:
        LD      A,B
        RET

; APPLY_CLEAR_SCORE
; Reads CLEAR_MASK.
; LINES_CLEARED_TOTAL incremented by number of cleared rows.
; SCORE updated using 100/300/500/800 for 1/2/3/4+ rows (from CLEAR_SCORE_TABLE).
; @clobbers A,BC,DE,HL while applying the clear-score update.
APPLY_CLEAR_SCORE:
        CALL    COUNT_CLEAR_ROWS
        OR      A
        RET     Z
        LD      E,A
        LD      A,(LINES_CLEARED_TOTAL)
        ADD     A,E
        LD      (LINES_CLEARED_TOTAL),A

        LD      A,E                     ; A = clear count (1..ROW_COUNT)
        CP      4
        JR      C,APPLY_CLEAR_LOOKUP    ; 4+ -> clamp to 4 (table entry for 'tetris')
        LD      A,4
APPLY_CLEAR_LOOKUP:
        ADD     A,A                     ; *2 for DW stride
        LD      L,A
        LD      H,0
        LD      DE,CLEAR_SCORE_TABLE
        ADD     HL,DE
        LD      E,(HL)                  ; DE = table entry (score delta)
        INC     HL
        LD      D,(HL)
        LD      HL,(SCORE_LO)
        ADD     HL,DE
        LD      (SCORE_LO),HL
        CALL    UPDATE_GRAVITY_PERIOD_FROM_SCORE
        JP      UPDATE_SCORE_DISPLAY

; UPDATE_GRAVITY_PERIOD_FROM_SCORE
; SCORE_LO / SCORE_HI.
; CURRENT_GRAVITY_PERIOD updated from score threshold(s).
; @clobbers A,HL.
UPDATE_GRAVITY_PERIOD_FROM_SCORE:
        LD      HL,(SCORE_LO)
        LD      A,H
        CP      GRAVITY_SCORE_STEP1_HI
        JR      C,UPDATE_GP_BASE
        JR      NZ,UPDATE_GP_STEP1
        LD      A,L
        CP      GRAVITY_SCORE_STEP1_LO
        JR      C,UPDATE_GP_BASE
UPDATE_GP_STEP1:
        LD      A,GRAVITY_PERIOD_STEP1
        JR      UPDATE_GP_STORE
UPDATE_GP_BASE:
        LD      A,GRAVITY_PERIOD
UPDATE_GP_STORE:
        LD      (CURRENT_GRAVITY_PERIOD),A
        RET

; COLLAPSE_FULL_ROWS
; Reads CLEAR_MASK, BOARD_ROWS, BOARD_RED, BOARD_GREEN, BOARD_BLUE.
; Completed rows removed, rows above collapsed downward.
; @clobbers A,BC,DE,HL while compacting non-cleared rows.
COLLAPSE_FULL_ROWS:
        LD      B,ROW_COUNT
        LD      D,ROW_COUNT-1
        LD      E,ROW_COUNT-1
COLLAPSE_SCAN_LOOP:
        LD      A,D
        LD      L,A
        LD      H,0
        PUSH    BC
        LD      BC,ROW_BIT_TABLE
        ADD     HL,BC
        LD      A,(CLEAR_MASK)
        AND     (HL)
        POP     BC
        JR      NZ,COLLAPSE_SKIP_ROW
        LD      A,D
        CP      E
        JR      Z,COLLAPSE_ROW_DONE
        PUSH    BC
        PUSH    DE
        CALL    COPY_BOARD_ROW_DE_TO_E
        POP     DE
        POP     BC
COLLAPSE_ROW_DONE:
        DEC     E
COLLAPSE_SKIP_ROW:
        DEC     D
        DJNZ    COLLAPSE_SCAN_LOOP

        LD      A,E
        INC     A
        RET     Z
        LD      B,A
        XOR     A
        LD      D,A
COLLAPSE_CLEAR_TOP_LOOP:
        PUSH    BC
        CALL    CLEAR_BOARD_ROW_D
        POP     BC
        INC     D
        DJNZ    COLLAPSE_CLEAR_TOP_LOOP
        RET

; COPY_BOARD_ROW_DE_TO_E
; @in D source row index.
; @in E destination row index.
; BOARD_ROWS and landed RGB planes copied from D to E.
; @clobbers A.
COPY_BOARD_ROW_DE_TO_E:
        PUSH    HL
        PUSH    BC
        LD      HL,BOARD_ROWS
        LD      C,4
COPY_BR_NEXT:
        PUSH    HL
        LD      A,L
        ADD     A,D
        LD      L,A
        JR      NC,COPY_BR_SRCNC
        INC     H
COPY_BR_SRCNC:
        LD      A,(HL)
        LD      B,A
        POP     HL
        PUSH    HL
        LD      A,L
        ADD     A,E
        LD      L,A
        JR      NC,COPY_BR_DSTNC
        INC     H
COPY_BR_DSTNC:
        LD      (HL),B
        POP     HL
        LD      A,L
        ADD     A,ROW_COUNT
        LD      L,A
        JR      NC,COPY_BR_ADVNC
        INC     H
COPY_BR_ADVNC:
        DEC     C
        JR      NZ,COPY_BR_NEXT
        POP     BC
        POP     HL
        RET

; CLEAR_BOARD_ROW_D
; @in D row index.
; Row cleared in occupancy and RGB planes.
; @clobbers A,BC,HL.
CLEAR_BOARD_ROW_D:
        XOR     A
        LD      B,A
        LD      HL,BOARD_ROWS
        LD      C,4
CLEAR_BR_NEXT:
        PUSH    HL
        LD      A,L
        ADD     A,D
        LD      L,A
        JR      NC,CLEAR_BR_NC
        INC     H
CLEAR_BR_NC:
        LD      (HL),B
        POP     HL
        LD      A,L
        ADD     A,ROW_COUNT
        LD      L,A
        JR      NC,CLEAR_BR_ADVNC
        INC     H
CLEAR_BR_ADVNC:
        DEC     C
        JR      NZ,CLEAR_BR_NEXT
        RET

; RECOMPUTE_BOARD_EMPTY
; Reads BOARD_ROWS.
; BOARD_EMPTY updated from occupancy rows.
; @clobbers A,B,HL.
RECOMPUTE_BOARD_EMPTY:
        LD      HL,BOARD_ROWS
        LD      B,ROW_COUNT
RECOMPUTE_BOARD_EMPTY_LOOP:
        LD      A,(HL)
        OR      A
        JR      NZ,BOARD_NOT_EMPTY
        INC     HL
        DJNZ    RECOMPUTE_BOARD_EMPTY_LOOP
        LD      A,1
        LD      (BOARD_EMPTY),A
        RET
BOARD_NOT_EMPTY:
        XOR     A
        LD      (BOARD_EMPTY),A
        RET

; MERGE_OR_RGB_AT_BOARD_ROW_L
; @in L landed row index within playfield (same cell row used for BOARD_ROWS).
; @in C shifted occupancy mask already ORed into BOARD_ROWS for this row.
; Colour planes optionally ORed, controlled by CURRENT_PIECE_COLOR bits.
; @clobbers A.
MERGE_OR_RGB_AT_BOARD_ROW_L:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      D,0
        LD      E,L                     ; DE = row index (0..7)
        LD      HL,BOARD_RED
        ADD     HL,DE                   ; HL = BOARD_RED + row
        LD      DE,ROW_COUNT            ; DE = plane stride (8 bytes per plane)
        LD      A,(CURRENT_PIECE_COLOR)
        LD      B,3                     ; 3 planes: R, G, B
MERGE_OR_LOOP:
        RRCA                            ; low bit (red/green/blue per iter) -> carry
        JR      NC,MERGE_OR_SKIP
        PUSH    AF
        LD      A,(HL)
        OR      C
        LD      (HL),A
        POP     AF
MERGE_OR_SKIP:
        DEC     B
        JR      Z,MERGE_OR_EXIT
        ADD     HL,DE                   ; step HL +8 to next plane byte
        JR      MERGE_OR_LOOP
MERGE_OR_EXIT:
        POP     HL
        POP     DE
        POP     BC
        RET

; MERGE_ACTIVE_TO_BOARD
; Reads PLAYER_X, PLAYER_Y, CURRENT_PIECE_PTR, CURRENT_PIECE_COLOR.
; Active piece ORed into BOARD_ROWS and landed RGB planes.
; @clobbers A while merging active-piece cells into board RAM.
MERGE_ACTIVE_TO_BOARD:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        XOR     A
        LD      (BOARD_EMPTY),A
        LD      A,(PLAYER_X)
        LD      (SHIFT_COUNT),A
        LD      A,(PLAYER_Y)
        LD      L,A
        LD      H,0
        LD      DE,(CURRENT_PIECE_PTR)
        LD      B,4

MERGE_BOARD_ROW:
        LD      A,(DE)
        CALL    SHIFT_ROW_MASK          ; returns A = shifted mask
        LD      C,A
        OR      A                       ; test A; C retains mask for later writes
        JR      Z,MERGE_BOARD_NEXT
        BIT     7,L
        JR      NZ,MERGE_BOARD_NEXT
        LD      A,L
        CP      ROW_COUNT
        JR      NC,MERGE_BOARD_NEXT
        PUSH    HL
        PUSH    DE
        LD      H,0
        LD      DE,BOARD_ROWS
        ADD     HL,DE
        LD      A,(HL)
        OR      C
        LD      (HL),A
        POP     DE
        POP     HL
        CALL    MERGE_OR_RGB_AT_BOARD_ROW_L
MERGE_BOARD_NEXT:
        INC     DE
        INC     HL
        DJNZ    MERGE_BOARD_ROW
MERGE_ACTIVE_TO_BOARD_EXIT:
        POP     HL
        POP     DE
        POP     BC
        RET
