; Candidate placement test (same MSB-left column convention per ShiftRowMask / boarded occupancy nibbles).
; Accepts @in D as candidate x.
; Accepts @in E as candidate y.
; Returns @out carry set if placement collides or is out of bounds.
;   carry clear if placement is legal
; Uses @clobbers A,F as scratch and result flags.
; Keeps @preserves BC,DE,HL stable for the caller.
CheckCollAtDe:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A,D
        CP      XMin
        JR      C,CollXBound
        LD      C,A
        LD      A,(CurPieceRight)
        ADD     A,C
        CP      RowCount
        JR      NC,CollXBound
        LD      A,D
        LD      (ShiftCount),A
        LD      A,E
        LD      L,A
        LD      H,0
        LD      B,4
        LD      DE,(CurPiecePtr)
        ; Empty-board fast path removed: CheckCollRow handles it correctly
        ; (BoardRows=0 -> AND yields 0 -> no overlap), at the cost of ~12 cycles
        ; per collision on an empty board (only at first spawn after reset).
CheckCollRow:
        LD      A,(DE)
        CALL    ShiftRowMask
        LD      C,A
        OR      A
        JR      Z,CollNextRow
        BIT     7,L
        JR      NZ,CollNextRow
        LD      A,L
        CP      RowCount
        JR      NC,CollRowBottom
        PUSH    HL
        PUSH    DE
        LD      H,0
        LD      DE,BoardRows
        ADD     HL,DE
        LD      A,(HL)
        AND     C
        POP     DE
        POP     HL
        JR      NZ,CollRowOverlap
CollNextRow:
        INC     DE
        INC     HL
        DJNZ    CheckCollRow
        OR      A
        JR      CollExitOk

CollXBound:
        SCF
        JR      CollExitOk

CollRowBottom:
        SCF
        JR      CollExitOk

CollRowOverlap:
        SCF
CollExitOk:
        POP     HL
        POP     DE
        POP     BC
        RET

; CheckTopOut
; Input:
;   PlayerY, CurPiecePtr
; Output:
;   carry set if any occupied row of the active piece is still above the
;   visible field when the piece is about to lock
;   carry clear otherwise
; Clobbers:
;   A
CheckTopOut:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A,(PlayerY)
        LD      L,A
        LD      H,0
        LD      DE,(CurPiecePtr)
        LD      B,4
TopOutRowLoop:
        LD      A,(DE)
        OR      A
        JR      Z,TopOutNextRow
        BIT     7,L
        JR      NZ,TopOutTrue
TopOutNextRow:
        INC     DE
        INC     HL
        DJNZ    TopOutRowLoop
        OR      A
        JR      TopOutExit
TopOutTrue:
        SCF
TopOutExit:
        POP     HL
        POP     DE
        POP     BC
        RET
