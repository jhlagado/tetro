; CheckCollAtDe —
; Test candidate piece placement at (D, E).
; Checks X bounds against XMin and CurPieceRight.
; Checks each occupied piece row against BoardRows
; using the MSB-left column convention.
; Carry set means collision or out-of-bounds; carry
; clear means the placement is legal.
; BC, DE, and HL are preserved.
.routine in DE out carry,zero clobbers A,sign,parity,halfCarry
CheckCollAtDe:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A,D
        CP      XMin
        JR      C,_CollXBound
        LD      C,A
        LD      A,(CurPieceRight)
        ADD     A,C
        CP      RowCount
        JR      NC,_CollXBound
        LD      A,D
        LD      (ShiftCount),A
        LD      A,E
        LD      L,A
        LD      H,0
        LD      B,4
        LD      DE,(CurPiecePtr)
        ; Empty-board fast path removed:
        ; CheckCollRow handles it correctly
        ; (BoardRows=0 -> AND yields 0 -> no
        ; overlap), at the cost of ~12 cycles
        ; per collision on an empty board (only at
        ; first spawn after reset).
_CheckCollRow:
        LD      A,(DE)
        CALL    ShiftRowMask
        LD      C,A
        OR      A
        JR      Z,_CollNextRow
        BIT     7,L
        JR      NZ,_CollNextRow
        LD      A,L
        CP      RowCount
        JR      NC,_CollRowBottom
        PUSH    HL
        PUSH    DE
        LD      H,0
        LD      DE,BoardRows
        ADD     HL,DE
        LD      A,(HL)
        AND     C
        POP     DE
        POP     HL
        JR      NZ,_CollRowOverlap
_CollNextRow:
        INC     DE
        INC     HL
        DJNZ    _CheckCollRow
        OR      A
        JR      _CollExitOk

_CollXBound:
        SCF
        JR      _CollExitOk

_CollRowBottom:
        SCF
        JR      _CollExitOk

_CollRowOverlap:
        SCF
_CollExitOk:
        POP     HL
        POP     DE
        POP     BC
        RET

; CheckTopOut —
; Detect an above-field lock that causes game-over.
; Scans the active piece's 4 rows; if any occupied
; row has bit 7 set in L (Y is negative, meaning
; the row is above the visible playfield), carry
; is set. Carry clear means the piece is in-bounds.
.routine out carry,zero clobbers A,sign,parity,halfCarry
CheckTopOut:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A,(PlayerY)
        LD      L,A
        LD      H,0
        LD      DE,(CurPiecePtr)
        LD      B,4
_TopOutRowLoop:
        LD      A,(DE)
        OR      A
        JR      Z,_TopOutNextRow
        BIT     7,L
        JR      NZ,_TopOutTrue
_TopOutNextRow:
        INC     DE
        INC     HL
        DJNZ    _TopOutRowLoop
        OR      A
        JR      _TopOutExit
_TopOutTrue:
        SCF
_TopOutExit:
        POP     HL
        POP     DE
        POP     BC
        RET
