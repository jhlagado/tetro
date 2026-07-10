; LoadDePending —
; Load PendingX/Y into DE for collision probes.
.routine out DE clobbers A
LoadDePending:
        LD      A,(PendingX)
        LD      D,A
        LD      A,(PendingY)
        LD      E,A
        RET

; ShiftRowMask —
; Shift a piece-row bitmask A right by ShiftCount
; positions, placing the piece at column PlayerX.
; The MSB-left convention means SRL moves bits
; toward lower-numbered matrix columns.
.routine in A out A clobbers C
ShiftRowMask:
        LD      C,A
        LD      A,(ShiftCount)
        OR      A
        JR      Z,_ShiftRowDone
_ShiftRowLoop:
        SRL     C
        DEC     A
        JR      NZ,_ShiftRowLoop
_ShiftRowDone:
        LD      A,C
        RET
