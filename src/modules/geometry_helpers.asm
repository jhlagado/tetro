; LOAD_DE_FROM_PENDING
; Output: D = PENDING_X, E = PENDING_Y (arguments for CHECK_COLLISION_AT_DE)
; Clobbers: A
LOAD_DE_FROM_PENDING:
        LD      A,(PENDING_X)
        LD      D,A
        LD      A,(PENDING_Y)
        LD      E,A
        RET
; SHIFT_ROW_MASK
; Input:
;   A = unshifted row mask
;   SHIFT_COUNT = logical x placement
; Output:
;   A = shifted row mask
; Clobbers:
;   A, C
SHIFT_ROW_MASK:
        LD      C,A
        LD      A,(SHIFT_COUNT)
        OR      A
        JR      Z,SHIFT_ROW_DONE
SHIFT_ROW_LOOP:
        SRL     C
        DEC     A
        JR      NZ,SHIFT_ROW_LOOP
SHIFT_ROW_DONE:
        LD      A,C
        RET
