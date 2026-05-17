; LOAD_DE_FROM_PENDING
; Returns @out D as PENDING_X.
; Returns @out E as PENDING_Y.
; Uses @clobbers A as scratch.
; Keeps @preserves BC,HL stable for the caller.
LOAD_DE_FROM_PENDING:
        LD      A,(PENDING_X)
        LD      D,A
        LD      A,(PENDING_Y)
        LD      E,A
        RET
; SHIFT_ROW_MASK
; Accepts @in A as the unshifted row mask.
;   SHIFT_COUNT = logical x placement
; Returns @out A as the shifted row mask.
; Uses @clobbers C,carry,zero,sign,parity,halfCarry while shifting.
; Keeps @preserves B,DE,HL stable for the caller.
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
