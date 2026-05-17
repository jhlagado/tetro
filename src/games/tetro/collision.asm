; Candidate placement test (same MSB-left column convention per SHIFT_ROW_MASK / boarded occupancy nibbles).
; Accepts @in D as candidate x.
; Accepts @in E as candidate y.
; Returns @out carry set if placement collides or is out of bounds.
;   carry clear if placement is legal
; Uses @clobbers A,zero,sign,parity,halfCarry as scratch and result flags.
; Keeps @preserves BC,DE,HL stable for the caller.
CHECK_COLLISION_AT_DE:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A,D
        CP      X_MIN
        JR      C,COLLISION_TRUE_XBOUND
        LD      C,A
        LD      A,(CURRENT_PIECE_RIGHT)
        ADD     A,C
        CP      ROW_COUNT
        JR      NC,COLLISION_TRUE_XBOUND
        LD      A,D
        LD      (SHIFT_COUNT),A
        LD      A,E
        LD      L,A
        LD      H,0
        LD      B,4
        LD      DE,(CURRENT_PIECE_PTR)
        ; Empty-board fast path removed: CHECK_COLLISION_ROW handles it correctly
        ; (BOARD_ROWS=0 -> AND yields 0 -> no overlap), at the cost of ~12 cycles
        ; per collision on an empty board (only at first spawn after reset).
CHECK_COLLISION_ROW:
        LD      A,(DE)
        CALL    SHIFT_ROW_MASK
        LD      C,A
        OR      A
        JR      Z,COLLISION_NEXT_ROW
        BIT     7,L
        JR      NZ,COLLISION_NEXT_ROW
        LD      A,L
        CP      ROW_COUNT
        JR      NC,COLLISION_TRUE_ROW_BOTTOM
        PUSH    HL
        PUSH    DE
        LD      H,0
        LD      DE,BOARD_ROWS
        ADD     HL,DE
        LD      A,(HL)
        AND     C
        POP     DE
        POP     HL
        JR      NZ,COLLISION_TRUE_ROW_OVERLAP
COLLISION_NEXT_ROW:
        INC     DE
        INC     HL
        DJNZ    CHECK_COLLISION_ROW
        OR      A
        JR      COLLISION_EXIT_OK

COLLISION_TRUE_XBOUND:
        SCF
        JR      COLLISION_EXIT_OK

COLLISION_TRUE_ROW_BOTTOM:
        SCF
        JR      COLLISION_EXIT_OK

COLLISION_TRUE_ROW_OVERLAP:
        SCF
COLLISION_EXIT_OK:
        POP     HL
        POP     DE
        POP     BC
        RET

; CHECK_TOP_OUT_ON_LOCK
; Input:
;   PLAYER_Y, CURRENT_PIECE_PTR
; Output:
;   carry set if any occupied row of the active piece is still above the
;   visible field when the piece is about to lock
;   carry clear otherwise
; Clobbers:
;   A
; Returns @out carry set when locking would top out.
; Uses @clobbers A while scanning the active piece rows.
; Keeps @preserves BC,DE,HL stable for the caller.
CHECK_TOP_OUT_ON_LOCK:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A,(PLAYER_Y)
        LD      L,A
        LD      H,0
        LD      DE,(CURRENT_PIECE_PTR)
        LD      B,4
TOP_OUT_ROW_LOOP:
        LD      A,(DE)
        OR      A
        JR      Z,TOP_OUT_NEXT_ROW
        BIT     7,L
        JR      NZ,TOP_OUT_TRUE
TOP_OUT_NEXT_ROW:
        INC     DE
        INC     HL
        DJNZ    TOP_OUT_ROW_LOOP
        OR      A
        JR      TOP_OUT_EXIT
TOP_OUT_TRUE:
        SCF
TOP_OUT_EXIT:
        POP     HL
        POP     DE
        POP     BC
        RET
