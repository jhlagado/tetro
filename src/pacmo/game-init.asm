; InitState —
; Cold-start: reset Score, level, and lives.
; Sets PacLevel=1 and PacLives=PacLivesStart.
; Calls InitLevelState then shows the splash.
; ========================== AZM
; in        IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
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

; InitLevelState —
; Start one Pacmo level without touching Score
; or level counter.
; Resets all transient flags, scan state, and
; power-pill and enemy state. Clears eaten paths,
; marks the player start cell eaten, and rebuilds
; the Framebuffer (JP RebuildFb).
; ========================== AZM
; in        IX
; clobbers  IX,A,BC,DE,HL
; ========================== AZM
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

; InitPlyMons —
; Reset player, all three Monsters, and viewport.
; Places player at (7,7); Monster0 at its ROM
; start position moving right; Monster1 at (1,1)
; moving left; Monster2 at (13,1) moving down.
; Viewport origin set to (3,3).
; Resets movement cooldown and all transient
; caught and power flags.
; ========================== AZM
; clobbers  A
; ========================== AZM
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

; ClearFrontBack —
; Zero both Framebuffer and FramebufferBack.
; Clears FramebufferBytes*2 bytes from
; Framebuffer base.
; ========================== AZM
; clobbers  A,B,HL
; ========================== AZM
ClearFrontBack:
        LD      HL,Framebuffer
        LD      B,FramebufferBytes * 2
        XOR     A
ClearFrontBackLp:
        LD      (HL),A
        INC     HL
        DJNZ    ClearFrontBackLp
        RET

; ClearEatenPaths —
; Zero PacEatenRows (PacEatenBytes bytes).
; Call at level start; MarkEatenBc sets bits.
; ========================== AZM
; clobbers  A,B,HL
; ========================== AZM
ClearEatenPaths:
        LD      HL,PacEatenRows
        LD      B,PacEatenBytes
        XOR     A
ClearEatenLp:
        LD      (HL),A
        INC     HL
        DJNZ    ClearEatenLp
        RET
