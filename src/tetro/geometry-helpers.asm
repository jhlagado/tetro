; LoadDePending —
; Load PendingX/Y into DE for collision probes.
; ========================== AZM
; out       DE
; clobbers  A
; ========================== AZM
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
; ========================== AZM
; out       A,carry
; clobbers  C
; ========================== AZM
ShiftRowMask:
        LD      C,A
        LD      A,(ShiftCount)
        OR      A
        JR      Z,ShiftRowDone
ShiftRowLoop:
        SRL     C
        DEC     A
        JR      NZ,ShiftRowLoop
ShiftRowDone:
        LD      A,C
        RET
