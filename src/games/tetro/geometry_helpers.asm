; LOAD_DE_FROM_PENDING
; @out D PENDING_X.
; @out E PENDING_Y.
; @clobbers A.
LOAD_DE_FROM_PENDING:
        LD      A,(PENDING_X)
        LD      D,A
        LD      A,(PENDING_Y)
        LD      E,A
        RET
; SHIFT_ROW_MASK
; @in A the unshifted row mask.
; Reads SHIFT_COUNT as logical x placement.
; @out A the shifted row mask.
; @clobbers C while shifting.
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
