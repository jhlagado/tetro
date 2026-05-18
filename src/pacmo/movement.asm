; Poll keypad and move the Pacmo cursor at a controlled repeat rate.
;
; Direction mapping for this first scrolling experiment:
;   KeyLeft  (0x11) = PacDirRight
;   KeyRight (0x10) = PacDirLeft
;   ADD     (0x13) = up
;   GO      (0x12) = down
;   key 6   (0x06) = up
;   key 2   (0x02) = down
;   key 1   (0x01) = PacDirRight
;   key 3   (0x03) = PacDirLeft
;   key 0   (0x00) = pause
;
; Raw keypad codes are normalized into PACMO_DIR_* intents before movement
; dispatch. Later game logic should consume directions, not physical keys.
;
; PollInput
; Input:
;   none
; Output:
;   may update PlayerX/Y, ViewX/Y, MoveCooldown, LastKey
; Clobbers:
;   A, BC, DE, HL, IX
PollInput:
        LD      A,(PacSplashActive)
        OR      A
        JP      NZ,PollSplashStart
        LD      A,(PacPlayerCaught)
        OR      A
        JP      NZ,CaughtRestart
        LD      A,(PacRoundDone)
        OR      A
        RET     NZ
        LD      C,ApiScanKeys
        RST     0x10
        JP      NZ,ClearInputRpt
        LD      E,A
        JR      NC,PollNoNewKey
        LD      A,(PacPaused)
        OR      A
        JP      NZ,HandleUnpause
        LD      A,E
        CP      KeyPause
        JP      Z,HandlePauseKey
PollNoNewKey:
        LD      A,(PacPaused)
        OR      A
        JP      NZ,ClearInputRpt

        LD      A,E
        CALL    NormInputDir
        JR      C,HandleDirKey
        JP      ClearInputRpt

; PollSplashStart
; Input:
;   PacSplashActive is nonzero
; Output:
;   starts Pacmo on any key press
; Clobbers:
;   A, BC, DE, HL when starting; A, C otherwise
PollSplashStart:
        LD      C,ApiScanKeys
        RST     0x10
        RET     NZ
        XOR     A
        LD      (PacSplashActive),A
        JP      LcdShowPacRun

; CaughtRestart
; Input:
;   PacPlayerCaught is nonzero
; Output:
;   waits for PacGOverGate, then restarts or resumes when any key is pressed
; Clobbers:
;   A, BC, DE, HL, IX when restarting; A, C, HL otherwise
CaughtRestart:
        LD      HL,(PacGOverGateLo)
        LD      A,H
        OR      L
        JR      Z,CaughtRestartKey
        DEC     HL
        LD      (PacGOverGateLo),HL
        RET
CaughtRestartKey:
        LD      C,ApiScanKeys
        RST     0x10
        RET     NZ
        LD      A,(PacGameOver)
        OR      A
        JP      Z,ResumeCaught
        JP      InitState

; ResumeCaught
; Input:
;   PacLives is nonzero and caught gate has opened
; Output:
;   player and Monsters reset; level progress, Score, eaten paths, and lives preserved
; Clobbers:
;   A, BC, DE, HL, IX
ResumeCaught:
        CALL    InitPlyMons
        XOR     A
        LD      (PacGOverGateLo),A
        LD      (PacGOverGateHi),A
        CALL    LcdShowPacRun
        JP      RebuildFb

; HandlePauseKey
; Input:
;   new KeyPause press has been detected
; Output:
;   PacPaused set; LCD status updated; input repeat state reset
; Clobbers:
;   A
HandlePauseKey:
        LD      A,1
        LD      (PacPaused),A
        CALL    LcdShowPacPause
        JP      ClearInputRpt

; HandleUnpause
; Input:
;   PacPaused is nonzero and a new key press has been detected
; Output:
;   PacPaused cleared; LCD status restored; input repeat state reset
; Clobbers:
;   A, DE, HL
HandleUnpause:
        XOR     A
        LD      (PacPaused),A
        LD      A,(PacPowerTimerLo)
        LD      E,A
        LD      A,(PacPowerTimerHi)
        OR      E
        JR      Z,UnpauseShowRun
        CALL    LcdShowPower
        JP      ClearInputRpt
UnpauseShowRun:
        CALL    LcdShowPacRun
        JP      ClearInputRpt

HandleDirKey:
        LD      A,(LastKey)
        CP      E
        JR      Z,HeldSameKey

        LD      A,E
        LD      (LastKey),A
        LD      A,1
        LD      (MoveCooldown),A

HeldSameKey:
        LD      A,(MoveCooldown)
        DEC     A
        LD      (MoveCooldown),A
        RET     NZ

        LD      A,PacMovePeriod
        LD      (MoveCooldown),A

        LD      A,E
        CP      PacDirLeft
        JR      Z,MovePlayerLeft
        CP      PacDirRight
        JR      Z,MovePlyRight
        CP      PacDirUp
        JR      Z,MovePlayerUp
        CP      PacDirDown
        JR      Z,MovePlayerDown
        RET

; NormInputDir
; Input:
;   A = raw MON-3 keypad code from ApiScanKeys
; Output:
;   Carry set and E = PACMO_DIR_* for accepted movement keys
;   Carry clear if the key is not a Pacmo movement key
; Clobbers:
;   A, E
NormInputDir:
        CP      KeyLeft
        JR      Z,NormalizeLeft
        CP      KeyRight
        JR      Z,NormalizeRight
        CP      PacKey1
        JR      Z,NormalizeLeft
        CP      PacKey3
        JR      Z,NormalizeRight
        CP      KeyRotateCcw
        JR      Z,NormalizeUp
        CP      PacKey6
        JR      Z,NormalizeUp
        CP      KeyRotate
        JR      Z,NormalizeDown
        CP      PacKey2
        JR      Z,NormalizeDown
        OR      A
        RET
NormalizeLeft:
        LD      E,PacDirRight
        SCF
        RET
NormalizeRight:
        LD      E,PacDirLeft
        SCF
        RET
NormalizeUp:
        LD      E,PacDirUp
        SCF
        RET
NormalizeDown:
        LD      E,PacDirDown
        SCF
        RET

; ClearInputRpt
; Input:
;   none
; Output:
;   resets repeat timing so the next valid key moves promptly
; Clobbers:
;   A
ClearInputRpt:
        LD      A,PacMovePeriod
        LD      (MoveCooldown),A
        LD      A,NoKey
        LD      (LastKey),A
        RET

; MovePlayerLeft
; Input:
;   PlayerX
; Output:
;   applies the PacDirLeft world-step unless already at the horizontal edge or target is a wall
; Clobbers:
;   A, BC, DE, HL, IX
MovePlayerLeft:
        LD      A,(PlayerX)
        CP      PacWorldMax
        RET     NC
        INC     A
        LD      B,A
        LD      A,(PlayerY)
        LD      C,A
        JP      TryMovePlyBc

; MovePlyRight
; Input:
;   PlayerX
; Output:
;   applies the PacDirRight world-step unless already at the horizontal edge or target is a wall
; Clobbers:
;   A, BC, DE, HL, IX
MovePlyRight:
        LD      A,(PlayerX)
        OR      A
        RET     Z
        DEC     A
        LD      B,A
        LD      A,(PlayerY)
        LD      C,A
        JP      TryMovePlyBc

; MovePlayerUp
; Input:
;   PlayerY
; Output:
;   decrements PlayerY unless already at world row 0 or target is a wall
; Clobbers:
;   A, BC, DE, HL, IX
MovePlayerUp:
        LD      A,(PlayerY)
        OR      A
        RET     Z
        DEC     A
        LD      C,A
        LD      A,(PlayerX)
        LD      B,A
        JP      TryMovePlyBc

; MovePlayerDown
; Input:
;   PlayerY
; Output:
;   increments PlayerY unless already at world row 14 or target is a wall
; Clobbers:
;   A, BC, DE, HL, IX
MovePlayerDown:
        LD      A,(PlayerY)
        CP      PacWorldMax
        RET     NC
        INC     A
        LD      C,A
        LD      A,(PlayerX)
        LD      B,A
        JP      TryMovePlyBc

; TryMovePlyBc
; Input:
;   B = candidate world x
;   C = candidate world y
; Output:
;   if target is open, PlayerX/Y committed and viewport adjusted
;   if target is a wall, PlayerX/Y unchanged
; Clobbers:
;   A, BC, DE, HL, IX
TryMovePlyBc:
        CALL    IsWallAtBc
        RET     C
        LD      A,B
        LD      (PlayerX),A
        LD      A,C
        LD      (PlayerY),A
        CALL    EatPwrPillBc
        CALL    MarkEatenBc
        CALL    CheckRoundDone
        LD      IX,Monster0
        CALL    CheckPlyCaught
        LD      IX,Monster1
        CALL    CheckPlyCaught
        CALL    PacIsLevel2Plus
        JP      C,UpdViewPly
        LD      IX,Monster2
        CALL    CheckPlyCaught
        JP      UpdViewPly

; CheckPlyCaught
; Input:
;   IX = monster record base
;   PlayerX/Y, monster X/Y, state, respawn timer
; Output:
;   PacPlayerCaught = 1 when player and active enemy occupy the same world cell
;   outside enemy flee mode; in enemy flee mode, enemy is consumed and starts respawning
; Clobbers:
;   A, BC, DE, HL, IX when the enemy is consumed or caught state is entered;
;   A, B otherwise
CheckPlyCaught:
        LD      A,(PacPlayerCaught)
        OR      A
        RET     NZ
        LD      A,(IX + MonRespTimer)
        OR      A
        RET     NZ
        LD      A,(PlayerX)
        LD      B,A
        LD      A,(IX + MonsterX)
        CP      B
        RET     NZ
        LD      A,(PlayerY)
        LD      B,A
        LD      A,(IX + MonsterY)
        CP      B
        RET     NZ
        LD      A,(IX + MonsterState)
        CP      PacEnemyFlee
        JR      Z,EatEnemy
        JP      EnterCaught

; EnterCaught
; Input:
;   player has collided with an attacking monster
; Output:
;   life count reduced; caught or game-over state entered; Framebuffer rebuilt
; Clobbers:
;   A, BC, DE, HL, IX
EnterCaught:
        LD      A,1
        LD      (PacPlayerCaught),A
        LD      HL,PacGOverTicks
        LD      (PacGOverGateLo),HL
        LD      HL,PacLives
        LD      A,(HL)
        OR      A
        JR      Z,EnterFinalOver
        DEC     (HL)
        LD      A,(HL)
        OR      A
        JR      Z,EnterFinalOver
        CALL    PacSndCaught
        CALL    LcdShowCaught
        JP      RebuildFb
EnterFinalOver:
        LD      A,1
        LD      (PacGameOver),A
        CALL    PacSndCaught
        CALL    LcdShowPacOver
        JP      RebuildFb

; EatEnemy
; Input:
;   IX = monster record base
;   player and enemy occupy the same world cell while power mode is active
; Output:
;   enemy hidden until EnemyRespTimer expires; Score increased
; Clobbers:
;   A, BC, DE, HL
EatEnemy:
        LD      A,PacEnemyRespawn
        LD      (IX + MonsterState),A
        LD      A,PacEnemyRespDiv
        LD      (IX + MonsterTimer),A
        LD      A,PacEnemyRespPer
        LD      (IX + MonRespTimer),A
        CALL    PacSndEatEnemy
        CALL    LcdShowEatEnemy
        LD      A,PacScoreEnemy
        JP      AddScoreA

; EatPwrPillBc
; Input:
;   B = world x coordinate
;   C = world y coordinate
; Output:
;   matching bit set in PacPwrPillsEat when B/C is a power-pill cell
; Clobbers:
;   A, DE, HL; B and C are preserved
EatPwrPillBc:
        LD      HL,PacPowerPills
        LD      D,1
EatPwrPillLoop:
        LD      A,(HL)
        CP      0xFF
        RET     Z
        CP      B
        INC     HL
        JR      NZ,EatPwrPillNext
        LD      A,(HL)
        CP      C
        JR      NZ,EatPwrPillNext
        LD      A,(PacPwrPillsEat)
        AND     D
        RET     NZ
        LD      A,(PacPwrPillsEat)
        OR      D
        LD      (PacPwrPillsEat),A
        PUSH    BC
        LD      A,PacScorePower
        CALL    AddScoreA
        CALL    PacSndPower
        POP     BC
        LD      HL,PacPwrTimerSet
        LD      (PacPowerTimerLo),HL
        LD      A,PacEnemyFlee
        LD      (EnemyState),A
        LD      (Enemy2State),A
        LD      (Enemy3State),A
        CALL    LcdShowPower
        RET
EatPwrPillNext:
        INC     HL
        SLA     D
        JR      EatPwrPillLoop

; MarkEatenBc
; Input:
;   B = world x coordinate, expected 0..14
;   C = world y coordinate, expected 0..14
; Output:
;   corresponding bit set in PacEatenRows
; Clobbers:
;   A, BC, DE, HL
MarkEatenBc:
        LD      A,C
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,PacEatenRows
        ADD     HL,DE

        LD      A,B
        CP      8
        JR      NC,MarkEatenLow
        CALL    MxMask
        LD      E,A
        LD      A,(HL)
        AND     E
        RET     NZ
        PUSH    HL
        PUSH    DE
        LD      A,PacScorePath
        CALL    AddScoreA
        POP     DE
        POP     HL
        LD      A,E
        OR      (HL)
        LD      (HL),A
        RET
MarkEatenLow:
        SUB     8
        INC     HL
        CALL    MxMask
        LD      E,A
        LD      A,(HL)
        AND     E
        RET     NZ
        PUSH    HL
        PUSH    DE
        LD      A,PacScorePath
        CALL    AddScoreA
        POP     DE
        POP     HL
        LD      A,E
        OR      (HL)
        LD      (HL),A
        RET

; AddScoreA
; Input:
;   A = unsigned Score increment
; Output:
;   PacScore increased by A; HUD Score display refreshed
; Clobbers:
;   A, BC, DE, HL
AddScoreA:
        LD      E,A
        LD      D,0
        LD      HL,(PacScore)
        ADD     HL,DE
        LD      (PacScore),HL
        JP      UpdScoreDisplay

; CheckRoundDone
; Input:
;   PacWorldRows / PacEatenRows
; Output:
;   PacRoundDone = 1 when every open cell has been consumed
; Clobbers:
;   A, BC, DE, HL
CheckRoundDone:
        LD      A,(PacRoundDone)
        OR      A
        RET     NZ
        LD      B,RowCount + 7
        LD      DE,PacWorldRows
        LD      HL,PacEatenRows
CheckRoundRow:
        LD      A,(DE)
        OR      (HL)
        CP      0xFF
        RET     NZ
        INC     DE
        INC     HL
        LD      A,(DE)
        OR      (HL)
        OR      0x01                    ; bit 0 is outside the 15-column maze
        CP      0xFF
        RET     NZ
        INC     DE
        INC     HL
        DJNZ    CheckRoundRow
        LD      A,1
        LD      (PacRoundDone),A
        LD      HL,PacLvlDoneTicks
        LD      (PacLvlDoneLo),HL
        CALL    PacSndLvlDone
        CALL    LcdShowComplete
        RET

; IsWallAtBc
; Input:
;   B = world x coordinate, expected 0..14
;   C = world y coordinate, expected 0..14
; Output:
;   Carry set if PacWorldRows has a wall bit at (B,C)
;   Carry clear if the cell is open
; Clobbers:
;   A, DE, HL
; Accepts @in B as world x coordinate.
; Accepts @in C as world y coordinate.
; Returns @out carry set when the target cell is a wall.
; Uses @clobbers A,DE,HL,F while reading the world map.
; Keeps @preserves BC,IX,IY stable for the caller.
IsWallAtBc:
        LD      A,C
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,PacWorldRows
        ADD     HL,DE
        LD      D,(HL)                  ; D = high byte, bit 7 is world column 0
        INC     HL
        LD      E,(HL)                  ; E = low byte, bit 1 is world column 14

        LD      A,B
        OR      A
        JR      Z,PacWallTest
WallShiftLoop:
        SLA     E
        RL      D
        DEC     A
        JR      NZ,WallShiftLoop
PacWallTest:
        BIT     7,D
        JR      Z,PacWallOpen
        SCF
        RET
PacWallOpen:
        OR      A
        RET

; UpdViewPly
; Input:
;   PlayerX/Y and ViewX/Y in RAM
; Output:
;   ViewX/Y adjusted so player screen position stays in cells 3..4 when
;   possible, then clamped to the 15x15 world / 8x8 viewport bounds.
; Clobbers:
;   A, B, C
UpdViewPly:
        LD      A,(PlayerX)
        LD      B,A
        LD      A,(ViewX)
        CALL    AdjustViewAxis
        LD      (ViewX),A

        LD      A,(PlayerY)
        LD      B,A
        LD      A,(ViewY)
        CALL    AdjustViewAxis
        LD      (ViewY),A
        RET

; AdjustViewAxis
; Input:
;   A = current view origin for one axis
;   B = player coordinate on the same axis
; Output:
;   A = adjusted view origin, clamped to 0..7
; Clobbers:
;   C
AdjustViewAxis:
        LD      C,A
        LD      A,B
        SUB     C                       ; A = player screen coordinate
        CP      3
        JR      C,AxisShiftLow
        CP      5
        JR      NC,AxisShiftHigh
        LD      A,C
        RET
AxisShiftLow:
        LD      A,C
        OR      A
        RET     Z
        DEC     A
        RET
AxisShiftHigh:
        LD      A,C
        CP      PacViewMax
        RET     NC
        INC     A
        RET
