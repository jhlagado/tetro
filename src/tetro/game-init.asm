; InitState
; Input:
;   none
; Output:
;   initialized runtime state in RAM
; Clobbers:
;   A, BC, DE, HL
InitState:
        CALL    InitStateBase
        LD      A,1
        LD      (SplashTimer),A
        CALL    LcdShowSplash
        JP      RebuildFb

; InitRestart
; Input:
;   none
; Output:
;   initialized runtime state for immediate post-game restart
; Clobbers:
;   A, BC, DE, HL
InitRestart:
        CALL    InitStateBase
        XOR     A
        LD      (SplashTimer),A
        CALL    RngNextPiece
        LD      (NextPieceIndex),A
        CALL    SpawnActPiece
        CALL    UpdScoreDisplay
        CALL    LcdShowRunning
        JP      RebuildFb

; InitStateBase
; Input:
;   none
; Output:
;   common runtime state initialized in RAM
; Clobbers:
;   A, B, HL
InitStateBase:
        LD      A,MovePeriod
        LD      (MoveCooldown),A
        LD      A,GravityPeriod
        LD      (CurGravPeriod),A
        LD      (GravityCooldown),A

        XOR     A
        LD      (GameOver),A
        LD      HL,0
        LD      (GOverKeyGateLo),HL
        LD      (ActPieceEnabled),A
        LD      (ClearPending),A
        LD      (ClearMask),A
        LD      (ClearTimer),A
        LD      (DropLockout),A
        LD      (FramePhase),A
        LD      (LogicSlice),A
        LD      (Paused),A
        LD      (CurrentRotation),A
        LD      (CurPieceIndex),A
        LD      (NextPieceIndex),A
        LD      (LinesClearTotal),A
        LD      (ScoreLo),A
        LD      (ScoreHi),A
        LD      A,1
        LD      (InputLockout),A
        LD      A,NoKey
        LD      (LastKey),A
        XOR     A
        LD      (HudScanIndex),A
        LD      (SpeakerPort),A
        LD      (SoundTimer),A
        LD      (SndDivReload),A
        LD      (SndDivCount),A

        LD      A,ScanMaskStart
        LD      (ScanMask),A

        LD      HL,Framebuffer
        LD      (ScanPtr),HL

        CALL    ClearBoard
        CALL    HudBlankDig
        RET
