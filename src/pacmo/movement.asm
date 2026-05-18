; Pacmo player input and movement.
;
; Key-to-direction mapping (world coordinates
; are flipped: left key increases world X):
;   KeyLeft / key 1  → PacDirRight (X+1)
;   KeyRight / key 3 → PacDirLeft  (X-1)
;   ADD / key 6      → PacDirUp    (Y-1)
;   GO / key 2       → PacDirDown  (Y+1)
;   key 0            → pause
;
; Raw keypad codes are normalised into PACMO_DIR_*
; intents by NormInputDir before movement dispatch.

; PollInput —
; Read keypad and dispatch movement or game flow.
; On splash: routes to PollSplashStart.
; On caught: routes to CaughtRestart.
; On round-done: returns immediately.
; Otherwise: normalises key to direction and
; dispatches via HandleDirKey or ClearInputRpt.
; ========================== AZM
; clobbers  A,C,E
; ========================== AZM
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

; PollSplashStart —
; Wait for any key on the splash screen.
; Clears PacSplashActive and shows running HUD.
; ========================== AZM
; in        B,DE,IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
PollSplashStart:
        LD      C,ApiScanKeys
        RST     0x10
        RET     NZ
        XOR     A
        LD      (PacSplashActive),A
        JP      LcdShowPacRun

; CaughtRestart —
; Handle input while the player is caught.
; Counts down PacGOverGate before accepting keys.
; On game-over (PacGameOver set): tail-calls
; InitState (JP). Otherwise: tail-calls
; ResumeCaught (JP).
; ========================== AZM
; clobbers  A,HL
; ========================== AZM
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

; ResumeCaught —
; Resume after a life loss (lives remain).
; Resets player and Monsters via InitPlyMons;
; preserves Score, level, eaten paths, and lives.
; ========================== AZM
; in        BC,DE,IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
ResumeCaught:
        CALL    InitPlyMons
        XOR     A
        LD      (PacGOverGateLo),A
        LD      (PacGOverGateHi),A
        CALL    LcdShowPacRun
        JP      RebuildFb

; HandlePauseKey —
; Pause the game on a fresh pause-key press.
; Sets PacPaused, shows the pause screen, then
; tail-calls ClearInputRpt (JP).
; ========================== AZM
; in        BC,DE,IX,IY,SP,carry,zero,sign,parity,halfCarry
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
HandlePauseKey:
        LD      A,1
        LD      (PacPaused),A
        CALL    LcdShowPacPause
        JP      ClearInputRpt

; HandleUnpause —
; Resume from pause on any new key press.
; Restores power-mode LCD if PacPowerTimer is
; active; otherwise shows running HUD.
; Tail-calls ClearInputRpt (JP).
; ========================== AZM
; in        BC,D,IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
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

; NormInputDir —
; Map a raw keypad code to a PACMO_DIR_* intent.
; Returns carry set and E = direction for valid
; movement keys; carry clear for all others.
; ========================== AZM
; in        A
; clobbers  A
; ========================== AZM
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

; ClearInputRpt —
; Reset key-repeat state to a full period.
; Resets MoveCooldown to PacMovePeriod and
; sets LastKey to NoKey.
; ========================== AZM
; clobbers  A
; ========================== AZM
ClearInputRpt:
        LD      A,PacMovePeriod
        LD      (MoveCooldown),A
        LD      A,NoKey
        LD      (LastKey),A
        RET

; MovePlayerLeft —
; Step the player in the PacDirLeft direction.
; In world coordinates this increments X (moving
; left on screen increases world X).
; Returns immediately at the world boundary.
; Tail-calls TryMovePlyBc (JP).
; ========================== AZM
; in        IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
MovePlayerLeft:
        LD      A,(PlayerX)
        CP      PacWorldMax
        RET     NC
        INC     A
        LD      B,A
        LD      A,(PlayerY)
        LD      C,A
        JP      TryMovePlyBc

; MovePlyRight —
; Step the player in the PacDirRight direction.
; In world coordinates this decrements X (moving
; right on screen decreases world X).
; Returns immediately when PlayerX is 0.
; Tail-calls TryMovePlyBc (JP).
; ========================== AZM
; in        IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
MovePlyRight:
        LD      A,(PlayerX)
        OR      A
        RET     Z
        DEC     A
        LD      B,A
        LD      A,(PlayerY)
        LD      C,A
        JP      TryMovePlyBc

; MovePlayerUp —
; Step the player upward (decrement PlayerY).
; Returns immediately when PlayerY is 0.
; Tail-calls TryMovePlyBc (JP).
; ========================== AZM
; in        IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
MovePlayerUp:
        LD      A,(PlayerY)
        OR      A
        RET     Z
        DEC     A
        LD      C,A
        LD      A,(PlayerX)
        LD      B,A
        JP      TryMovePlyBc

; MovePlayerDown —
; Step the player downward (increment PlayerY).
; Returns immediately at PacWorldMax.
; Tail-calls TryMovePlyBc (JP).
; ========================== AZM
; in        IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
MovePlayerDown:
        LD      A,(PlayerY)
        CP      PacWorldMax
        RET     NC
        INC     A
        LD      C,A
        LD      A,(PlayerX)
        LD      B,A
        JP      TryMovePlyBc

; TryMovePlyBc —
; Commit a player move if the target is passable.
; Calls IsWallAtBc; returns on wall.
; On open cell: updates PlayerX/Y, eats path and
; power pills, checks round completion and caught
; state, then adjusts viewport via UpdViewPly.
; ========================== AZM
; in        BC,IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
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

; CheckPlyCaught —
; Test player-Monster collision at the same cell.
; Skips when the Monster is respawning.
; Flee state: eat the Monster and award score.
; Attack state: call EnterCaught.
; ========================== AZM
; in        IX,DE,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
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

; EnterCaught —
; Process a player-Monster collision.
; Decrements PacLives; if no lives remain, sets
; PacGameOver and shows the game-over screen.
; Always rebuilds the Framebuffer in caught colour.
; ========================== AZM
; in        B,DE,IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
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

; EatEnemy —
; Consume a fleeing Monster.
; Starts the respawn countdown, plays the eat
; sound, shows the eat-enemy LCD cue, and
; tail-calls AddScoreA with PacScoreEnemy (JP).
; ========================== AZM
; in        IX,B,DE,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
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

; EatPwrPillBc —
; Consume a power pill at (B=x, C=y) if present
; and not yet eaten.
; Sets the corresponding bit in PacPwrPillsEat,
; awards PacScorePower, starts power sound and
; timer, and sets all Monsters to flee mode.
; ========================== AZM
; clobbers  D,HL
; ========================== AZM
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

; MarkEatenBc —
; Record path consumption at world cell (B=x,
; C=y, both expected 0..14).
; Sets the column bit in PacEatenRows for row C.
; B < 8 maps to the high byte of the two-byte
; row; B >= 8 maps to the low byte (B minus 8).
; Awards PacScorePath on first visit.
; ========================== AZM
; in        BC
; clobbers  A,BC,DE,HL
; ========================== AZM
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

; AddScoreA —
; Add A to PacScore (16-bit) and refresh the HUD.
; Tail-calls UpdScoreDisplay (JP).
; ========================== AZM
; in        A
; clobbers  A,BC,DE,HL
; ========================== AZM
AddScoreA:
        LD      E,A
        LD      D,0
        LD      HL,(PacScore)
        ADD     HL,DE
        LD      (PacScore),HL
        JP      UpdScoreDisplay

; CheckRoundDone —
; Detect level completion.
; ORs each PacWorldRows pair with PacEatenRows;
; all rows must be 0xFF to pass (bit 0 of the
; low byte is masked out as it is outside the
; 15-column maze).
; On completion: sets PacRoundDone, starts the
; level-done timer and sound, and shows the
; complete LCD screen.
; ========================== AZM
; clobbers  A,B,DE,HL
; ========================== AZM
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

; IsWallAtBc —
; Test the wall bit at world cell (B=x, C=y).
; PacWorldRows stores each row as two bytes: 15
; bits with bit 15 = column 0 (MSB = left wall).
; Shifts the 16-bit pair left B times so column
; B lands in bit 7 of D; tests that bit.
; Returns carry set for wall, clear for open.
; ========================== AZM
; in        BC
; clobbers  A,DE,HL
; ========================== AZM
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

; UpdViewPly —
; Scroll the viewport to keep the player centred.
; Calls AdjustViewAxis for X and Y independently.
; ViewX/Y track so player stays near screen
; columns/rows 3–4 within the world boundary.
; ========================== AZM
; clobbers  A,BC
; ========================== AZM
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

; AdjustViewAxis —
; Adjust one viewport axis to follow the player.
; Player screen position = B - A (current view).
; Shifts view when position < 3 or > 4.
; Clamps to 0 at the low end and PacViewMax at
; the high end.
; ========================== AZM
; in        A,B
; clobbers  A,C
; ========================== AZM
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
