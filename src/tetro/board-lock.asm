; LockActPiece —
; Commit the active piece to the landed board.
; Top-out check runs first: if any occupied row
; is above the visible field, merges the piece
; then branches to EnterGameOver.
; On a completed row: triggers clear sound,
; disables the active piece, and sets ClearPending
; and ClearTimer for the hold delay.
; On no clear: triggers lock sound, spawns next.
.routine out carry,zero clobbers A,BC,DE,HL,sign,parity,halfCarry
LockActPiece:
        CALL    CheckTopOut
        JR      C,_LockGameOver
        CALL    MergeActBoard
        CALL    CheckFullRows
        JR      NC,_LockActNoClear
        CALL    SndTrigClear
        XOR     A
        LD      (ActPieceEnabled),A
        LD      A,1
        LD      (ClearPending),A
        LD      A,LineClearHold
        LD      (ClearTimer),A
        RET
_LockActNoClear:
        CALL    SndTrigLock
        CALL    SpawnActPiece
        RET

_LockGameOver:
        CALL    MergeActBoard
        LD      A,4
        CALL    EnterGameOver
        RET

; EnterGameOver —
; Latch game-over state and show the game-over
; screen.
; Disables active piece, sets GameOver, arms
; GOverKeyGateLo for the restart-input delay.
; Plays the game-over sound, rebuilds the Framebuffer,
; then jumps to LcdShowGOver.
.routine out carry clobbers A,BC,DE,HL,zero,sign,parity,halfCarry
EnterGameOver:
        PUSH    AF
        XOR     A
        LD      (ActPieceEnabled),A
        LD      A,1
        LD      (GameOver),A
        LD      HL,GOverGateTicks
        LD      (GOverKeyGateLo),HL
        POP     AF
        CALL    SndTrigGOver
        CALL    RebuildFb
        JP      LcdShowGOver

; SplashState —
; Wait for a fresh key press on the splash screen.
; Seeds RngSeed from FramePhase (0 replaced with
; RngSeedInit), draws the first NextPiece, locks
; input, and starts the game via SpawnActPiece
; then jumps to RebuildFb.
.routine clobbers A,BC,DE,HL,IX,IY,F
SplashState:
        LD      C,ApiScanKeys
        RST     0x10
        RET     NC
        XOR     A
        LD      (SplashTimer),A
        LD      A,(FramePhase)
        OR      A
        JR      NZ,_SplashSeedReady
        LD      A,RngSeedInit
_SplashSeedReady:
        LD      (RngSeed),A
        CALL    RngNextPiece
        LD      (NextPieceIndex),A
        LD      A,1
        LD      (InputLockout),A
        CALL    SpawnActPiece
        CALL    UpdScoreDisplay
        CALL    LcdShowRunning
        JP      RebuildFb

; LineClearState —
; Manage the post-clear hold delay.
; Advances once per frame. On ClearTimer expiry:
; collapses filled rows, awards score, clears
; ClearPending, then jumps to SpawnActPiece.
.routine out carry clobbers A,zero,sign,parity,halfCarry,BC,DE,HL
LineClearState:
        LD      A,(ClearTimer)
        DEC     A
        LD      (ClearTimer),A
        RET     NZ
        CALL    CollapseRows
        CALL    ApplyClearScore
        XOR     A
        LD      (ClearPending),A
        CALL    BoardEmptyScan
        JP      SpawnActPiece

; CheckFullRows —
; Scan BoardRows for 0xFF (completely full) rows.
; Builds ClearMask: bit N set when row N is full.
; Carry set means at least one row is full; carry
; clear means no rows are full.
.routine out carry,zero clobbers A,BC,E,HL,sign,parity,halfCarry
CheckFullRows:
        LD      HL,BoardRows
        LD      B,RowCount
        LD      C,1
        XOR     A
        LD      E,A
_CheckRowsLoop:
        LD      A,(HL)
        CP      0xFF
        JR      NZ,_CheckRowsNext
        LD      A,E
        OR      C
        LD      E,A
_CheckRowsNext:
        INC     HL
        SLA     C
        DJNZ    _CheckRowsLoop
        LD      A,E
        LD      (ClearMask),A
        OR      A
        JR      Z,_CheckRowsNone
        SCF
        RET
_CheckRowsNone:
        OR      A
        RET

; CountClearRows —
; Count the set bits in ClearMask.
; The count is returned in A (0..8).
.routine out A,carry,C clobbers B,zero,sign,parity,halfCarry
CountClearRows:
        LD      A,(ClearMask)
        LD      C,A
        LD      B,0
_CountClearLoop:
        LD      A,C
        OR      A
        JR      Z,_CountClearDone
        SRL     C
        JR      NC,_CountClearLoop
        INC     B
        JR      _CountClearLoop
_CountClearDone:
        LD      A,B
        RET

; ApplyClearScore —
; Award score for a completed-row event.
; Increments LinesClearTotal by the cleared count.
; Score delta is looked up in ClearScoreTbl:
; 100, 300, 500, or 800 for 1, 2, 3, or 4+ rows.
; Updates gravity after changing Score, then refreshes
; the score HUD.
.routine out BC,HL clobbers A,DE,F
ApplyClearScore:
        CALL    CountClearRows
        OR      A
        RET     Z
        LD      E,A
        LD      A,(LinesClearTotal)
        ADD     A,E
        LD      (LinesClearTotal),A

        LD      A,E                     ; A = clear count (1..RowCount)
        CP      4
        JR      C,_ApplyClearLookup    ; 4+ -> clamp to 4 (table entry for 'tetris')
        LD      A,4
_ApplyClearLookup:
        ADD     A,A                     ; *2 for DW stride
        LD      L,A
        LD      H,0
        LD      DE,ClearScoreTbl
        ADD     HL,DE
        LD      E,(HL)                  ; DE = table entry (Score delta)
        INC     HL
        LD      D,(HL)
        LD      HL,(ScoreLo)
        ADD     HL,DE
        LD      (ScoreLo),HL
        CALL    UpdGravByScore
        JP      UpdScoreDisplay

; UpdGravByScore —
; Increase gravity when Score crosses a threshold.
; Updates CurGravPeriod: GravityPeriod below the
; threshold, GravPeriodStep1 at or above it.
.routine out zero clobbers A,HL,carry,sign,parity,halfCarry
UpdGravByScore:
        LD      HL,(ScoreLo)
        LD      A,H
        CP      GravScore1Hi
        JR      C,_UpdateGpBase
        JR      NZ,_UpdateGpStep1
        LD      A,L
        CP      GravScore1Lo
        JR      C,_UpdateGpBase
_UpdateGpStep1:
        LD      A,GravPeriodStep1
        JR      _UpdateGpStore
_UpdateGpBase:
        LD      A,GravityPeriod
_UpdateGpStore:
        LD      (CurGravPeriod),A
        RET

; CollapseRows —
; Remove cleared rows and compact the board.
; Scans bottom-to-top; rows not in ClearMask are
; copied downward into the vacated slots.
; Top rows left vacant are zeroed in BoardRows
; and all three landed colour planes.
.routine clobbers B,DE,HL,A,F
CollapseRows:
        LD      B,RowCount
        LD      D,RowCount - 1
        LD      E,RowCount - 1
_CollapseScanLp:
        LD      A,D
        LD      L,A
        LD      H,0
        PUSH    BC
        LD      BC,RowBitTable
        ADD     HL,BC
        LD      A,(ClearMask)
        AND     (HL)
        POP     BC
        JR      NZ,_CollapseSkipRow
        LD      A,D
        CP      E
        JR      Z,_CollapseRowDone
        PUSH    BC
        PUSH    DE
        CALL    CopyBoardRow
        POP     DE
        POP     BC
_CollapseRowDone:
        DEC     E
_CollapseSkipRow:
        DEC     D
        DJNZ    _CollapseScanLp

        LD      A,E
        INC     A
        RET     Z
        LD      B,A
        XOR     A
        LD      D,A
_CollapseTopLoop:
        PUSH    BC
        CALL    ClearBoardRow
        POP     BC
        INC     D
        DJNZ    _CollapseTopLoop
        RET

; CopyBoardRow —
; Copy one row across all four board arrays.
; D contains the source row; E contains the
; destination row. Copies occupancy (BoardRows) then
; the three colour planes (BoardRed, BoardGreen,
; BoardBlue). Each array is RowCount
; bytes wide; the stride between arrays is
; RowCount bytes.
.routine in DE clobbers A,F
CopyBoardRow:
        PUSH    HL
        PUSH    BC
        LD      HL,BoardRows
        LD      C,4
_CopyBrNext:
        PUSH    HL
        LD      A,L
        ADD     A,D
        LD      L,A
        JR      NC,_CopyBrSrcNc
        INC     H
_CopyBrSrcNc:
        LD      A,(HL)
        LD      B,A
        POP     HL
        PUSH    HL
        LD      A,L
        ADD     A,E
        LD      L,A
        JR      NC,_CopyBrDstNc
        INC     H
_CopyBrDstNc:
        LD      (HL),B
        POP     HL
        LD      A,L
        ADD     A,RowCount
        LD      L,A
        JR      NC,_CopyBrAdvNc
        INC     H
_CopyBrAdvNc:
        DEC     C
        JR      NZ,_CopyBrNext
        POP     BC
        POP     HL
        RET

; ClearBoardRow —
; Zero one row in BoardRows and all three colour
; planes. D contains the row index. Uses the same
; RowCount stride as CopyBoardRow.
.routine in D out HL,C clobbers A,B,F
ClearBoardRow:
        XOR     A
        LD      B,A
        LD      HL,BoardRows
        LD      C,4
_ClearBrNext:
        PUSH    HL
        LD      A,L
        ADD     A,D
        LD      L,A
        JR      NC,_ClearBrNc
        INC     H
_ClearBrNc:
        LD      (HL),B
        POP     HL
        LD      A,L
        ADD     A,RowCount
        LD      L,A
        JR      NC,_ClearBrAdvNc
        INC     H
_ClearBrAdvNc:
        DEC     C
        JR      NZ,_ClearBrNext
        RET

; BoardEmptyScan —
; Set BoardEmpty=1 when all BoardRows bytes are
; zero; set BoardEmpty=0 otherwise.
.routine out carry,zero clobbers A,B,HL,sign,parity,halfCarry
BoardEmptyScan:
        LD      HL,BoardRows
        LD      B,RowCount
_BoardEmptyLoop:
        LD      A,(HL)
        OR      A
        JR      NZ,_BoardNotEmpty
        INC     HL
        DJNZ    _BoardEmptyLoop
        LD      A,1
        LD      (BoardEmpty),A
        RET
_BoardNotEmpty:
        XOR     A
        LD      (BoardEmpty),A
        RET

; MergeRgbRow —
; OR column mask C into the landed colour planes
; for row index L.
; Only the planes enabled by CurPieceColor bits
; are touched; plane stride is RowCount bytes.
; Call after ORing C into BoardRows for this row.
.routine in L,C out A clobbers F
MergeRgbRow:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      D,0
        LD      E,L                     ; DE = row index (0..7)
        LD      HL,BoardRed
        ADD     HL,DE                   ; HL = BoardRed + row
        LD      DE,RowCount            ; DE = plane stride (8 bytes per plane)
        LD      A,(CurPieceColor)
        LD      B,3                     ; 3 planes: R, G, B
_MergeOrLoop:
        RRCA                            ; low bit (red/green/blue per iter) -> carry
        JR      NC,_MergeOrSkip
        PUSH    AF
        LD      A,(HL)
        OR      C
        LD      (HL),A
        POP     AF
_MergeOrSkip:
        DEC     B
        JR      Z,_MergeOrExit
        ADD     HL,DE                   ; step HL +8 to next plane byte
        JR      _MergeOrLoop
_MergeOrExit:
        POP     HL
        POP     DE
        POP     BC
        RET

; MergeActBoard —
; Stamp the active piece into the landed board.
; ORs each occupied row of the 4-row piece bitmap
; (shifted by PlayerX) into BoardRows, then calls
; MergeRgbRow to update the three colour planes.
; Clears BoardEmpty as a side effect.
.routine clobbers A,F
MergeActBoard:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        XOR     A
        LD      (BoardEmpty),A
        LD      A,(PlayerX)
        LD      (ShiftCount),A
        LD      A,(PlayerY)
        LD      L,A
        LD      H,0
        LD      DE,(CurPiecePtr)
        LD      B,4

_MergeBoardRow:
        LD      A,(DE)
        CALL    ShiftRowMask          ; returns A = shifted mask
        LD      C,A
        OR      A                       ; test A; C retains mask for later writes
        JR      Z,_MergeBoardNext
        BIT     7,L
        JR      NZ,_MergeBoardNext
        LD      A,L
        CP      RowCount
        JR      NC,_MergeBoardNext
        PUSH    HL
        PUSH    DE
        LD      H,0
        LD      DE,BoardRows
        ADD     HL,DE
        LD      A,(HL)
        OR      C
        LD      (HL),A
        POP     DE
        POP     HL
        CALL    MergeRgbRow
_MergeBoardNext:
        INC     DE
        INC     HL
        DJNZ    _MergeBoardRow
_MergeActExit:
        POP     HL
        POP     DE
        POP     BC
        RET
