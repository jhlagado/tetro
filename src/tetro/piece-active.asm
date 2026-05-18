; HorizProbeX
; Input:
;   PendingX/Y set for candidate lateral move (PlayerY echoed into PendingY)
; Output:
;   on success, PlayerX := PendingX
; Clobbers:
;   A, DE
HorizProbeX:
        LD      A,(PlayerY)
        LD      (PendingY),A
        CALL    LoadDePending
        CALL    CheckCollAtDe
        JR      NC,HorizCommitX
        RET
HorizCommitX:
        LD      A,(PendingX)
        LD      (PlayerX),A
        RET

; MoveRight
; Input:
;   none
; Output:
;   may increment PlayerX if candidate placement is legal
; Clobbers:
;   A, DE
MoveRight:
        LD      A,(PlayerX)
        INC     A
        LD      (PendingX),A
        JP      HorizProbeX

; MoveLeft
; Input:
;   none
; Output:
;   may decrement PlayerX if candidate placement is legal
; Clobbers:
;   A, DE
MoveLeft:
        LD      A,(PlayerX)
        OR      A
        RET     Z
        DEC     A
        LD      (PendingX),A
        JP      HorizProbeX

; StepActDown
; Input:
;   PlayerX / PlayerY
; Output:
;   pending one row down; Carry from CheckCollAtDe (CY = collision/block)
; Clobbers:
;   A, DE
StepActDown:
        LD      A,(PlayerX)
        LD      (PendingX),A
        LD      A,(PlayerY)
        INC     A
        LD      (PendingY),A
        CALL    LoadDePending
        CALL    CheckCollAtDe
        RET

; ApplyGravity
; Input:
;   none
; Output:
;   may update PlayerY, or lock and respawn active piece on collision
; Clobbers:
;   A, DE on commit; A, BC, DE, HL on lock (tail-calls LockActPiece)
ApplyGravity:
        LD      A,(GravityCooldown)
        DEC     A
        LD      (GravityCooldown),A
        RET     NZ

        LD      A,(CurGravPeriod)
        LD      (GravityCooldown),A

        CALL    StepActDown
        JR      NC,GravityCommit
        JP      LockActPiece
GravityCommit:
        LD      A,(PendingY)
        LD      (PlayerY),A
        RET

; SoftDrop
; Input:
;   none
; Output:
;   may update PlayerY, or lock and respawn active piece on collision
; Clobbers:
;   A, DE on commit; A, BC, DE, HL on lock (tail-calls LockActPiece)
SoftDrop:
        CALL    StepActDown
        JR      NC,SoftDropCommit
        LD      A,1
        LD      (DropLockout),A
        JP      LockActPiece
SoftDropCommit:
        LD      A,(PendingY)
        LD      (PlayerY),A
        LD      A,(CurGravPeriod)
        LD      (GravityCooldown),A
        RET
; SanitizeActPos
; Input:
;   PlayerX, PlayerY in RAM
; Output:
;   PlayerX clamped to XMin..X_MAX
;   PlayerY clamped to YMax (negative spawn rows preserved)
; Clobbers:
;   A, HL
SanitizeActPos:
        LD      A,(PlayerX)
        LD      HL,CurPieceRight
        ADD     A,(HL)
        CP      RowCount
        JR      C,SanitizeXDone
        LD      A,RowCount - 1
        SUB     (HL)
        LD      (PlayerX),A
SanitizeXDone:
        LD      A,(PlayerY)
        BIT     7,A
        JR      NZ,SanitizeYDone
        CP      YMax + 1
        JR      C,SanitizeYDone
        LD      A,YMax
        LD      (PlayerY),A
SanitizeYDone:
        RET

; SelectNextPiece
; Input:
;   NextPieceIndex in RAM
; Output:
;   CurPieceIndex / CurrentRotation updated
;   CurPiecePtr / CurPieceRight / CurPieceColor updated
;   NextPieceIndex advanced modulo PieceCount
; Clobbers:
;   A, BC, DE, HL
SelectNextPiece:
        LD      A,(NextPieceIndex)
        LD      (CurPieceIndex),A
        XOR     A
        LD      (CurrentRotation),A
        CALL    LoadCurRot

        CALL    RngNextPiece
        LD      (NextPieceIndex),A
        RET

; RngNextPiece
; Input:
;   RngSeed
; Output:
;   A = next piece index 0..6
;   RngSeed advanced
; Clobbers:
;   A, B
RngNextPiece:
        CALL    RngNext8
        LD      B,A
        SRL     A
        SRL     A
        SRL     A
        XOR     B                       ; fold high bits into sticky low bits
        AND     0x07
        CP      PieceCount
        JR      NC,RngNextPiece
        RET

; RngNext8
; Input:
;   RngSeed
; Output:
;   A = next pseudo-random byte
;   RngSeed advanced
; Clobbers:
;   A
RngNext8:
        LD      A,(RngSeed)
        OR      A
        JR      NZ,RngNext8Step
        LD      A,RngSeedInit
RngNext8Step:
        SRL     A
        JR      NC,RngNext8Save
        XOR     0xB8
RngNext8Save:
        LD      (RngSeed),A
        RET

; LoadCurRot
; Input:
;   CurPieceIndex / CurrentRotation in RAM
; Output:
;   CurPiecePtr / CurPieceRight / CurPieceColor updated
; Clobbers:
;   A, C, DE, HL
LoadCurRot:
        ; COLOR lookup first (indexed by piece only) so DE is still free.
        LD      A,(CurPieceIndex)
        LD      E,A
        LD      D,0
        LD      HL,PieceColorTbl
        ADD     HL,DE
        LD      A,(HL)
        LD      (CurPieceColor),A

        ; Now DE = piece_index*4 + rotation for the remaining tables.
        LD      A,(CurPieceIndex)
        ADD     A,A
        ADD     A,A
        LD      C,A
        LD      A,(CurrentRotation)
        ADD     A,C
        LD      E,A
        LD      D,0

        LD      HL,PieceRightTbl
        ADD     HL,DE
        LD      A,(HL)
        LD      (CurPieceRight),A

        LD      HL,PiecePtrTable
        ADD     HL,DE
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      HL,CurPiecePtr
        LD      (HL),E
        INC     HL
        LD      (HL),D
        RET

; RotateTestDone
; Prerequisites: tentative rotation loaded via LoadCurRot,
; CurrentRotation = candidate; COLLISION_AT(PlayerX, PlayerY) decides accept.
; Rotates back (restore PendingRotation) + reload if illegal.
; Input:
;   CurrentRotation (candidate), PendingRotation (previous), PlayerX/Y
; Output:
;   commit on legal; revert + reload on collision
; Clobbers:
;   A, C, DE, HL
RotateTestDone:
        LD      A,(PlayerX)
        LD      D,A
        LD      A,(PlayerY)
        LD      E,A
        CALL    CheckCollAtDe
        JR      NC,RotateAccept
        LD      A,(PendingRotation)
        LD      (CurrentRotation),A
        JP      LoadCurRot
RotateAccept:
        CALL    SndTrigRotate
        LD      A,(CurGravPeriod)
        LD      (GravityCooldown),A
        RET

; RotateCw
; Input:
;   current active piece state in RAM
; Output:
;   may update CurrentRotation if rotated placement is legal
; Clobbers:
;   A, C, DE, HL
RotateCw:
        LD      A,(CurrentRotation)
        LD      (PendingRotation),A
        INC     A
        AND     3
        LD      (CurrentRotation),A
        CALL    LoadCurRot
        JP      RotateTestDone

; RotateLeft
; Input:
;   current active piece state in RAM
; Output:
;   may update CurrentRotation if rotated placement is legal
; Clobbers:
;   A, C, DE, HL
RotateLeft:
        LD      A,(CurrentRotation)
        LD      (PendingRotation),A
        DEC     A                       ; 0->0xFF; 1->0; 2->1; 3->2
        AND     3                       ; 0xFF -> 3 (wrap)
        LD      (CurrentRotation),A
        CALL    LoadCurRot
        JP      RotateTestDone

; SpawnActPiece
; Input:
;   none
; Output:
;   active-piece state reset to spawn position
;   returns fault if spawn collides immediately
;   (Full `LcdShowRunning` left to splash/restart; each successful spawn
;    refreshes row 3 next-piece preview via LcdRefNextPrev.)
; Clobbers:
;   A, BC, DE, HL
SpawnActPiece:
        CALL    SelectNextPiece
        LD      A,3
        LD      (PlayerX),A
        LD      (PendingX),A          ; PlayerX == PendingX at spawn
        LD      A,SpawnY
        LD      (PlayerY),A
        LD      (PendingY),A          ; PlayerY == PendingY at spawn
        LD      A,MovePeriod
        LD      (MoveCooldown),A
        LD      A,(CurGravPeriod)
        LD      (GravityCooldown),A
        LD      A,NoKey
        LD      (LastKey),A
        CALL    LoadDePending
        CALL    CheckCollAtDe
        JR      C,SpawnFailed
        LD      A,1
        LD      (ActPieceEnabled),A
        CALL    LcdRefNextPrev
        RET
SpawnFailed:
        XOR     A                      ; reason code 0 = immediate spawn collision
        JP      EnterGameOver        ; tail-call; EnterGameOver tail-calls LCD_SHOW_*
