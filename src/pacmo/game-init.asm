; InitState
; Input:
;   none
; Output:
;   initializes Pacmo cursor, viewport, scan state, display buffers, and HUD
; Clobbers:
;   A, BC, DE, HL
InitState:
        XOR     A
        LD      (PacScore),A
        LD      (PacScore + 1),A
        LD      A,1
        LD      (PacLevel),A
        LD      A,PacLivesStart
        LD      (PacLives),A
        LD      A,PacEnemyPeriod
        LD      (EnemyPeriodCur),A
        CALL    InitLevelState
        LD      A,1
        LD      (PacSplashActive),A
        JP      LcdShowPacSplash

; InitLevelState
; Input:
;   PacScore, PacLevel, EnemyPeriodCur
; Output:
;   initializes one Pacmo level without resetting Score or level
; Clobbers:
;   A, BC, DE, HL
InitLevelState:
        CALL    InitPlyMons

        XOR     A
        LD      (PacSplashActive),A
        LD      (PacPaused),A
        LD      (LogicSlice),A
        LD      (FramePhase),A
        LD      (HudScanIndex),A
        LD      (SpeakerPort),A
        LD      (SoundTimer),A
        LD      (SndDivReload),A
        LD      (SndDivCount),A
        LD      (PacPwrPillsEat),A
        LD      (PacPowerTimerLo),A
        LD      (PacPowerTimerHi),A
        LD      (EnemyRespTimer),A
        LD      (EnemyState),A
        LD      (Enemy2RespTimer),A
        LD      (Enemy2State),A
        LD      (Enemy3RespTimer),A
        LD      (Enemy3State),A
        LD      (PacRoundDone),A
        LD      (PacPlayerCaught),A
        LD      (PacGameOver),A
        LD      (PacLvlDoneLo),A
        LD      (PacLvlDoneHi),A
        LD      (PacGOverGateLo),A
        LD      (PacGOverGateHi),A

        LD      A,ScanMaskStart
        LD      (ScanMask),A
        LD      HL,Framebuffer
        LD      (ScanPtr),HL

        CALL    ClearFrontBack
        CALL    ClearEatenPaths
        LD      HL,(PacScore)
        PUSH    HL
        LD      A,(PlayerX)
        LD      B,A
        LD      A,(PlayerY)
        LD      C,A
        CALL    MarkEatenBc
        POP     HL
        LD      (PacScore),HL
        CALL    UpdScoreDisplay
        JP      RebuildFb

; InitPlyMons
; Input:
;   EnemyPeriodCur
; Output:
;   player, Monsters, viewport, input repeat, and transient play flags reset
; Clobbers:
;   A
InitPlyMons:
        LD      A,7
        LD      (PlayerX),A
        LD      (PlayerY),A
        LD      A,PacEnemyMaxX
        LD      (EnemyX),A
        LD      A,PacEnemyY
        LD      (EnemyY),A
        LD      A,PacDirRight
        LD      (EnemyDir),A
        LD      A,(EnemyPeriodCur)
        LD      (EnemyTimer),A
        LD      A,1
        LD      (Enemy2X),A
        LD      (Enemy2Y),A
        LD      A,PacDirLeft
        LD      (Enemy2Dir),A
        LD      A,(EnemyPeriodCur)
        LD      (Enemy2Timer),A
        LD      A,13
        LD      (Enemy3X),A
        LD      A,1
        LD      (Enemy3Y),A
        LD      A,PacDirDown
        LD      (Enemy3Dir),A
        LD      A,(EnemyPeriodCur)
        LD      (Enemy3Timer),A

        LD      A,3
        LD      (ViewX),A
        LD      (ViewY),A

        LD      A,PacMovePeriod
        LD      (MoveCooldown),A
        LD      A,NoKey
        LD      (LastKey),A

        XOR     A
        LD      (PacPaused),A
        LD      (SpeakerPort),A
        LD      (SoundTimer),A
        LD      (SndDivReload),A
        LD      (SndDivCount),A
        LD      (PacPowerTimerLo),A
        LD      (PacPowerTimerHi),A
        LD      (EnemyRespTimer),A
        LD      (EnemyState),A
        LD      (Enemy2RespTimer),A
        LD      (Enemy2State),A
        LD      (Enemy3RespTimer),A
        LD      (Enemy3State),A
        LD      (PacPlayerCaught),A
        RET

; ClearFrontBack
; Input:
;   none
; Output:
;   Framebuffer and FramebufferBack cleared to zero
; Clobbers:
;   A, B, HL
ClearFrontBack:
        LD      HL,Framebuffer
        LD      B,FramebufferBytes * 2
        XOR     A
ClearFrontBackLp:
        LD      (HL),A
        INC     HL
        DJNZ    ClearFrontBackLp
        RET

; ClearEatenPaths
; Input:
;   none
; Output:
;   PacEatenRows cleared to zero
; Clobbers:
;   A, B, HL
ClearEatenPaths:
        LD      HL,PacEatenRows
        LD      B,PacEatenBytes
        XOR     A
ClearEatenLp:
        LD      (HL),A
        INC     HL
        DJNZ    ClearEatenLp
        RET
