; LoadDePending
; Returns @out D as PendingX.
; Returns @out E as PendingY.
; Uses @clobbers A as scratch.
; Keeps @preserves BC,HL stable for the caller.
LoadDePending:
        LD      A,(PendingX)
        LD      D,A
        LD      A,(PendingY)
        LD      E,A
        RET
; ShiftRowMask
; Accepts @in A as the unshifted row mask.
;   ShiftCount = logical x placement
; Returns @out A as the shifted row mask.
; Uses @clobbers C,F while shifting.
; Keeps @preserves B,DE,HL stable for the caller.
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
