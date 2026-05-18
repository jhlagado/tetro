; LockActPiece
; Input:
;   active piece state (PlayerX/Y, CURRENT_PIECE_*), BoardRows / BOARD_*
; Output:
;   active piece merged into board; line-clear queued, next piece spawned,
;   or top-out -> EnterGameOver
; Clobbers:
;   A, BC, DE, HL
LockActPiece:
        CALL    CheckTopOut
        JR      C,LockGameOver
        CALL    MergeActBoard
        CALL    CheckFullRows
        JR      NC,LockActNoClear
        CALL    SndTrigClear
        XOR     A
        LD      (ActPieceEnabled),A
        LD      A,1
        LD      (ClearPending),A
        LD      A,LineClearHold
        LD      (ClearTimer),A
        RET
LockActNoClear:
        CALL    SndTrigLock
        CALL    SpawnActPiece
        RET

LockGameOver:
        CALL    MergeActBoard
        LD      A,4
        CALL    EnterGameOver
        RET

; EnterGameOver
; Input:
;   A = game-over reason code
; Output:
;   GameOver latched, active piece disabled, Framebuffer rebuilt, LCD updated
; Clobbers:
;   A, BC, DE, HL
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

; SplashState
; Input:
;   SplashTimer / FramePhase
; Output:
;   waits for a fresh key press, then seeds the RNG and starts a new game
; Clobbers:
;   A, BC, DE, HL
SplashState:
        LD      C,ApiScanKeys
        RST     0x10
        RET     NC
        XOR     A
        LD      (SplashTimer),A
        LD      A,(FramePhase)
        OR      A
        JR      NZ,SplashSeedReady
        LD      A,RngSeedInit
SplashSeedReady:
        LD      (RngSeed),A
        CALL    RngNextPiece
        LD      (NextPieceIndex),A
        LD      A,1
        LD      (InputLockout),A
        CALL    SpawnActPiece
        CALL    UpdScoreDisplay
        CALL    LcdShowRunning
        JP      RebuildFb

; LineClearState
; Input:
;   ClearPending / ClearTimer / LogicSlice in RAM
; Output:
;   advances clear-hold countdown once per full logic cycle
;   collapses full rows and spawns next piece when timer expires
; Clobbers:
;   A, BC, DE, HL
LineClearState:
        LD      A,(LogicSlice)
        OR      A
        RET     NZ
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

; CheckFullRows
; Input:
;   BoardRows
; Output:
;   ClearMask updated
;   carry set if one or more rows are full
; Clobbers:
;   A, BC, E, HL
CheckFullRows:
        LD      HL,BoardRows
        LD      B,RowCount
        LD      C,1
        XOR     A
        LD      E,A
CheckRowsLoop:
        LD      A,(HL)
        CP      0xFF
        JR      NZ,CheckRowsNext
        LD      A,E
        OR      C
        LD      E,A
CheckRowsNext:
        INC     HL
        SLA     C
        DJNZ    CheckRowsLoop
        LD      A,E
        LD      (ClearMask),A
        OR      A
        JR      Z,CheckRowsNone
        SCF
        RET
CheckRowsNone:
        OR      A
        RET

; CountClearRows
; Input:
;   ClearMask
; Output:
;   A = number of set bits in ClearMask (0..8)
; Clobbers:
;   A, BC
CountClearRows:
        LD      A,(ClearMask)
        LD      C,A
        LD      B,0
CountClearLoop:
        LD      A,C
        OR      A
        JR      Z,CountClearDone
        SRL     C
        JR      NC,CountClearLoop
        INC     B
        JR      CountClearLoop
CountClearDone:
        LD      A,B
        RET

; ApplyClearScore
; Input:
;   ClearMask
; Output:
;   LinesClearTotal incremented by number of cleared rows
;   Score updated using 100/300/500/800 for 1/2/3/4+ rows (from ClearScoreTbl)
; Clobbers:
;   A, BC, DE, HL
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
        JR      C,ApplyClearLookup    ; 4+ -> clamp to 4 (table entry for 'tetris')
        LD      A,4
ApplyClearLookup:
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

; UpdGravByScore
; Input:
;   ScoreLo / ScoreHi
; Output:
;   CurGravPeriod updated from Score threshold(s)
; Clobbers:
;   A, HL
UpdGravByScore:
        LD      HL,(ScoreLo)
        LD      A,H
        CP      GravScore1Hi
        JR      C,UpdateGpBase
        JR      NZ,UpdateGpStep1
        LD      A,L
        CP      GravScore1Lo
        JR      C,UpdateGpBase
UpdateGpStep1:
        LD      A,GravPeriodStep1
        JR      UpdateGpStore
UpdateGpBase:
        LD      A,GravityPeriod
UpdateGpStore:
        LD      (CurGravPeriod),A
        RET

; CollapseRows
; Input:
;   ClearMask, BoardRows, BoardRed, BoardGreen, BoardBlue
; Output:
;   completed rows removed, rows above collapsed downward
; Clobbers:
;   A, BC, DE, HL
CollapseRows:
        LD      B,RowCount
        LD      D,RowCount - 1
        LD      E,RowCount - 1
CollapseScanLp:
        LD      A,D
        LD      L,A
        LD      H,0
        PUSH    BC
        LD      BC,RowBitTable
        ADD     HL,BC
        LD      A,(ClearMask)
        AND     (HL)
        POP     BC
        JR      NZ,CollapseSkipRow
        LD      A,D
        CP      E
        JR      Z,CollapseRowDone
        PUSH    BC
        PUSH    DE
        CALL    CopyBoardRow
        POP     DE
        POP     BC
CollapseRowDone:
        DEC     E
CollapseSkipRow:
        DEC     D
        DJNZ    CollapseScanLp

        LD      A,E
        INC     A
        RET     Z
        LD      B,A
        XOR     A
        LD      D,A
CollapseTopLoop:
        PUSH    BC
        CALL    ClearBoardRow
        POP     BC
        INC     D
        DJNZ    CollapseTopLoop
        RET

; CopyBoardRow
; Input:
;   D = source row index
;   E = destination row index
; Output:
;   BoardRows and landed RGB planes copied from D to E
; Clobbers:
;   A
CopyBoardRow:
        PUSH    HL
        PUSH    BC
        LD      HL,BoardRows
        LD      C,4
CopyBrNext:
        PUSH    HL
        LD      A,L
        ADD     A,D
        LD      L,A
        JR      NC,CopyBrSrcNc
        INC     H
CopyBrSrcNc:
        LD      A,(HL)
        LD      B,A
        POP     HL
        PUSH    HL
        LD      A,L
        ADD     A,E
        LD      L,A
        JR      NC,CopyBrDstNc
        INC     H
CopyBrDstNc:
        LD      (HL),B
        POP     HL
        LD      A,L
        ADD     A,RowCount
        LD      L,A
        JR      NC,CopyBrAdvNc
        INC     H
CopyBrAdvNc:
        DEC     C
        JR      NZ,CopyBrNext
        POP     BC
        POP     HL
        RET

; ClearBoardRow
; Input:
;   D = row index
; Output:
;   row cleared in occupancy and RGB planes
; Clobbers:
;   A, BC, HL
ClearBoardRow:
        XOR     A
        LD      B,A
        LD      HL,BoardRows
        LD      C,4
ClearBrNext:
        PUSH    HL
        LD      A,L
        ADD     A,D
        LD      L,A
        JR      NC,ClearBrNc
        INC     H
ClearBrNc:
        LD      (HL),B
        POP     HL
        LD      A,L
        ADD     A,RowCount
        LD      L,A
        JR      NC,ClearBrAdvNc
        INC     H
ClearBrAdvNc:
        DEC     C
        JR      NZ,ClearBrNext
        RET

; BoardEmptyScan
; Input:
;   BoardRows
; Output:
;   BoardEmpty updated from occupancy rows
; Clobbers:
;   A, B, HL
BoardEmptyScan:
        LD      HL,BoardRows
        LD      B,RowCount
BoardEmptyLoop:
        LD      A,(HL)
        OR      A
        JR      NZ,BoardNotEmpty
        INC     HL
        DJNZ    BoardEmptyLoop
        LD      A,1
        LD      (BoardEmpty),A
        RET
BoardNotEmpty:
        XOR     A
        LD      (BoardEmpty),A
        RET

; MergeRgbRow
; Input:
;   H = 0, L = landed row index within playfield (same cell row used for BoardRows)
;   C = shifted occupancy mask already ORed into BoardRows for this row
; Output:
;   colour planes optionally ORed — controlled by CurPieceColor bits
; Clobbers:
;   A; preserves HL, DE, BC (B is caller's DJNZ counter)
; Relies on BoardRed/GREEN/BLUE being contiguous RowCount-sized arrays.
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
MergeOrLoop:
        RRCA                            ; low bit (red/green/blue per iter) -> carry
        JR      NC,MergeOrSkip
        PUSH    AF
        LD      A,(HL)
        OR      C
        LD      (HL),A
        POP     AF
MergeOrSkip:
        DEC     B
        JR      Z,MergeOrExit
        ADD     HL,DE                   ; step HL +8 to next plane byte
        JR      MergeOrLoop
MergeOrExit:
        POP     HL
        POP     DE
        POP     BC
        RET

; MergeActBoard
; Input:
;   PlayerX, PlayerY, CurPiecePtr, CurPieceColor
; Output:
;   active piece ORed into BoardRows and landed RGB planes
; Clobbers:
;   A
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

MergeBoardRow:
        LD      A,(DE)
        CALL    ShiftRowMask          ; returns A = shifted mask
        LD      C,A
        OR      A                       ; test A; C retains mask for later writes
        JR      Z,MergeBoardNext
        BIT     7,L
        JR      NZ,MergeBoardNext
        LD      A,L
        CP      RowCount
        JR      NC,MergeBoardNext
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
MergeBoardNext:
        INC     DE
        INC     HL
        DJNZ    MergeBoardRow
MergeActExit:
        POP     HL
        POP     DE
        POP     BC
        RET
