; Pacmo cooperative logic dispatcher.

; LogicTick —
; Run one Pacmo logic slice per main-loop pass.
; Slices 0..6: copy the completed back row to the
; live Framebuffer, then rebuild that back row.
; Slice 7: render row 7, blank the matrix, run
; PacFrameDuties, then reset LogicSlice to 0.
; ========================== AZM
; in        BC,IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
LogicTick:
        LD      A,(LogicSlice)
        AND     7
        CP      7
        JP      Z,LogicSl7
        CALL    PacRenderRowA
        JP      LogicSliceNext

LogicSl7:
        LD      A,7
        CALL    PacRenderRowA
        XOR     A
        OUT     (PortRow),A
        CALL    PacFrameDuties
        XOR     A
        LD      (LogicSlice),A
        RET

; PacFrameDuties —
; Per-frame Pacmo logic while the matrix is off.
; Polls input; if not paused: ticks the level-done
; gate, power timer, and each active Monster.
; Checks player-caught collision for each Monster.
; Monster2 is skipped before level 2.
; ========================== AZM
; in        B,D,IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
PacFrameDuties:
        CALL    PollInput
        LD      A,(PacPaused)
        OR      A
        RET     NZ
        CALL    TickLvlDoneGate
        CALL    TickPowerTimer
        LD      IX,Monster0
        CALL    TickEnemy
        LD      IX,Monster1
        CALL    TickEnemy
        CALL    PacIsLevel2Plus
        JR      C,PacFrameTickDone
        LD      IX,Monster2
        CALL    TickEnemy
PacFrameTickDone:
        LD      IX,Monster0
        CALL    CheckPlyCaught
        LD      IX,Monster1
        CALL    CheckPlyCaught
        CALL    PacIsLevel2Plus
        JR      C,PacFrameCollDone
        LD      IX,Monster2
        CALL    CheckPlyCaught
PacFrameCollDone:
        RET

; PacRenderRowA —
; Update one screen row in the live Framebuffer.
; Copies the completed back row to the front FB,
; clears the back row, then rebuilds it from
; world, power pills, Monsters, and player.
; Final step tail-calls RendPlyRow (JP).
; ========================== AZM
; in        A,BC,IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
PacRenderRowA:
        PUSH    AF
        ADD     A,A
        ADD     A,A
        CALL    FbCopyRow
        POP     AF
        PUSH    AF
        ADD     A,A
        ADD     A,A
        CALL    FbClearRow
        POP     AF
        PUSH    AF
        CALL    RendWorldRow
        POP     AF
        PUSH    AF
        CALL    RendPwrPillRow
        POP     AF
        PUSH    AF
        CALL    RendMonsRow
        POP     AF
        JP      RendPlyRow

LogicSliceNext:
        LD      HL,LogicSlice
        LD      A,(HL)
        INC     A
        AND     7
        LD      (HL),A
        RET

; TickLvlDoneGate —
; Count down the level-completion delay.
; Active only when PacRoundDone is set.
; On expiry (counter reaches 0): tail-calls
; PacAdvanceLevel (JP).
; ========================== AZM
; clobbers  A,HL
; ========================== AZM
TickLvlDoneGate:
        LD      A,(PacRoundDone)
        OR      A
        RET     Z
        LD      HL,(PacLvlDoneLo)
        LD      A,H
        OR      L
        JP      Z,PacAdvanceLevel
        DEC     HL
        LD      (PacLvlDoneLo),HL
        RET

; TickPowerTimer —
; Decrement the 16-bit PacPowerTimer each frame.
; On expiry: sets all three Monster states to
; PacEnemyAtk and calls LcdShowPacRun.
; ========================== AZM
; in        BC,DE,IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
TickPowerTimer:
        LD      HL,(PacPowerTimerLo)
        LD      A,H
        OR      L
        RET     Z
        DEC     HL
        LD      (PacPowerTimerLo),HL
        LD      A,H
        OR      L
        RET     NZ
        LD      A,PacEnemyAtk
        LD      (EnemyState),A
        LD      (Enemy2State),A
        LD      (Enemy3State),A
        JP      LcdShowPacRun

; PacIsLevel2Plus —
; Check whether the third Monster is active.
; Returns carry clear when PacLevel >= 2,
; carry set when PacLevel < 2.
; ========================== AZM
; clobbers  A
; ========================== AZM
PacIsLevel2Plus:
        LD      A,(PacLevel)
        CP      2
        RET

; TickEnemy —
; Drive one Monster for this frame.
; Returns immediately on splash, caught, or
; round-done. Delegates to TickEnemyResp when
; the Monster is respawning.
; When timer expires: attack state calls
; EnemyAttackStep; roam calls EnemyRoamStep.
; ========================== AZM
; in        IX
; clobbers  A,BC,DE,H
; ========================== AZM
TickEnemy:
        LD      A,(PacSplashActive)
        OR      A
        RET     NZ
        LD      A,(PacPlayerCaught)
        OR      A
        RET     NZ
        LD      A,(PacRoundDone)
        OR      A
        RET     NZ
        CALL    TickEnemyResp
        RET     C
        LD      A,(IX + MonsterTimer)
        DEC     A
        LD      (IX + MonsterTimer),A
        RET     NZ
        LD      A,(EnemyPeriodCur)
        LD      (IX + MonsterTimer),A
        LD      A,(IX + MonsterState)
        CP      PacEnemyAtk
        JP      Z,EnemyAttackStep
        JP      EnemyRoamStep

; EnemyAttackStep —
; Greedy chase step toward the player.
; Tries the preferred then secondary chase
; direction from EnemyChaseDirs, skipping the
; immediate reverse direction.
; Falls through to EnemyRoamStep when both are
; blocked.
; ========================== AZM
; in        IX
; clobbers  A,BC,DE,HL
; ========================== AZM
EnemyAttackStep:
        CALL    EnemyChaseDirs
        LD      A,(IX + MonsterDir)
        CALL    EnemyOpposite
        LD      L,A                     ; L = immediate reverse direction
        LD      A,D
        PUSH    DE
        PUSH    HL
        CALL    EnemyTryChase
        POP     HL
        POP     DE
        RET     C
        LD      A,E
        CALL    EnemyTryChase
        RET     C
        JP      EnemyRoamStep

; EnemyTryChase —
; Attempt one chase-direction step.
; Returns carry clear (no move) when A is zero
; or when A equals the immediate reverse in L.
; Otherwise delegates to EnemyTryMove.
; ========================== AZM
; in        A,L,IX
; clobbers  A,BC,E
; ========================== AZM
EnemyTryChase:
        OR      A
        RET     Z
        CP      L
        JR      Z,EnemyChaseBlock
        CALL    EnemyTryMove
        RET
EnemyChaseBlock:
        OR      A
        RET

; EnemyChaseDirs —
; Compute the two best directions toward player
; using Manhattan distance.
; D = direction on the larger distance axis;
; E = direction on the smaller axis.
; Either may be 0 when already aligned on that
; axis.
; ========================== AZM
; in        IX
; clobbers  A,BC,DE,HL
; ========================== AZM
EnemyChaseDirs:
        CALL    EnemyHorizChase
        LD      H,A                     ; H = horizontal distance
        LD      D,B                     ; D = horizontal reducing direction
        CALL    EnemyVertChase
        LD      L,A                     ; L = vertical distance
        LD      E,B                     ; E = vertical reducing direction
        LD      A,H
        CP      L
        RET     NC
        LD      A,D
        LD      D,E
        LD      E,A
        RET

; EnemyHorizChase —
; Compute horizontal distance and chase direction.
; Returns A = |MonsterX - PlayerX|,
; B = reducing direction, or 0 if aligned.
; ========================== AZM
; in        IX
; clobbers  A,BC
; ========================== AZM
EnemyHorizChase:
        LD      A,(IX + MonsterX)
        LD      C,A
        LD      A,(PlayerX)
        CP      C
        JR      Z,EnemyHorizAlign
        JR      C,EnemyHorizRight
        SUB     C
        LD      B,PacDirLeft
        RET
EnemyHorizRight:
        LD      A,C
        LD      B,A
        LD      A,(PlayerX)
        LD      C,A
        LD      A,B
        SUB     C
        LD      B,PacDirRight
        RET
EnemyHorizAlign:
        LD      B,0
        XOR     A
        RET

; EnemyVertChase —
; Compute vertical distance and chase direction.
; Returns A = |MonsterY - PlayerY|,
; B = reducing direction, or 0 if aligned.
; ========================== AZM
; in        IX
; clobbers  A,BC
; ========================== AZM
EnemyVertChase:
        LD      A,(IX + MonsterY)
        LD      C,A
        LD      A,(PlayerY)
        CP      C
        JR      Z,EnemyVertAlign
        JR      C,EnemyVertUp
        SUB     C
        LD      B,PacDirDown
        RET
EnemyVertUp:
        LD      A,C
        LD      B,A
        LD      A,(PlayerY)
        LD      C,A
        LD      A,B
        SUB     C
        LD      B,PacDirUp
        RET
EnemyVertAlign:
        LD      B,0
        XOR     A
        RET

; EnemyRoamStep —
; Move Monster to an adjacent open cell.
; Start direction offset is derived from level,
; position, and current direction for varied
; routing. Avoids the immediate reverse unless
; all other directions are blocked.
; ========================== AZM
; in        IX
; clobbers  A,BC,DE,H
; ========================== AZM
EnemyRoamStep:
        LD      A,(IX + MonsterX)
        LD      B,A
        LD      A,(IX + MonsterY)
        LD      C,A
        LD      A,(IX + MonsterDir)
        CALL    EnemyOpposite
        LD      D,A                     ; D = reverse direction fallback
        LD      A,B
        ADD     A,C
        LD      E,A
        LD      A,(PacLevel)
        ADD     A,E
        LD      E,A
        LD      A,(IX + MonsterDir)
        ADD     A,E
        AND     0x03
        INC     A                       ; A = first candidate direction, 1..4
        LD      E,A
        LD      H,4
EnemyRoamLoop:
        LD      A,E
        CP      D
        JR      Z,EnemyRoamNext
        PUSH    DE
        PUSH    HL
        CALL    EnemyTryMove
        POP     HL
        POP     DE
        RET     C
EnemyRoamNext:
        INC     E
        LD      A,E
        CP      5
        JR      C,EnemyRoamReady
        LD      E,1
EnemyRoamReady:
        DEC     H
        JR      NZ,EnemyRoamLoop
        LD      A,D
        CALL    EnemyTryMove
        RET

; EnemyOpposite —
; Return the direction opposite to A.
; Up↔Down, Left↔Right.
; ========================== AZM
; in        A
; clobbers  A
; ========================== AZM
EnemyOpposite:
        CP      PacDirUp
        JR      Z,EnemyOppDown
        CP      PacDirDown
        JR      Z,EnemyOppUp
        CP      PacDirLeft
        JR      Z,EnemyOppRight
        LD      A,PacDirLeft
        RET
EnemyOppDown:
        LD      A,PacDirDown
        RET
EnemyOppUp:
        LD      A,PacDirUp
        RET
EnemyOppRight:
        LD      A,PacDirRight
        RET

; EnemyTryMove —
; Try one step in direction A for the Monster.
; Checks world bounds and IsWallAtBc; on success
; commits monster X/Y and direction, sets carry.
; Returns carry clear when blocked or at an edge.
; ========================== AZM
; in        A,IX
; clobbers  A,BC,E
; ========================== AZM
EnemyTryMove:
        LD      E,A
        LD      A,(IX + MonsterX)
        LD      B,A
        LD      A,(IX + MonsterY)
        LD      C,A
        LD      A,E
        CP      PacDirLeft
        JR      Z,EnemyTryLeft
        CP      PacDirRight
        JR      Z,EnemyTryRight
        CP      PacDirUp
        JR      Z,EnemyTryUp
        CP      PacDirDown
        JR      Z,EnemyTryDown
        OR      A
        RET
EnemyTryLeft:
        LD      A,B
        CP      PacWorldMax
        JR      NC,EnemyTryBlocked
        INC     B
        JR      EnemyCommitOpen
EnemyTryRight:
        LD      A,B
        OR      A
        JR      Z,EnemyTryBlocked
        DEC     B
        JR      EnemyCommitOpen
EnemyTryUp:
        LD      A,C
        OR      A
        JR      Z,EnemyTryBlocked
        DEC     C
        JR      EnemyCommitOpen
EnemyTryDown:
        LD      A,C
        CP      PacWorldMax
        JR      NC,EnemyTryBlocked
        INC     C
EnemyCommitOpen:
        PUSH    DE
        CALL    IsWallAtBc
        POP     DE
        JR      C,EnemyTryBlocked
        LD      A,B
        LD      (IX + MonsterX),A
        LD      A,C
        LD      (IX + MonsterY),A
        LD      A,E
        LD      (IX + MonsterDir),A
        SCF
        RET
EnemyTryBlocked:
        OR      A
        RET

; TickEnemyResp —
; Manage Monster respawn countdown.
; Returns carry set while the respawn timer is
; active. On expiry: selects a new spawn position
; via EnemySelectResp, resets direction and timer,
; and calls LcdShowPacRun.
; ========================== AZM
; in        IX
; clobbers  A
; ========================== AZM
TickEnemyResp:
        LD      A,(IX + MonRespTimer)
        OR      A
        RET     Z
        LD      A,(IX + MonsterTimer)
        OR      A
        JR      Z,TickEnemyRespDec
        DEC     A
        LD      (IX + MonsterTimer),A
        JR      Z,TickEnemyRespDec
        SCF
        RET
TickEnemyRespDec:
        LD      A,PacEnemyRespDiv
        LD      (IX + MonsterTimer),A
        LD      A,(IX + MonRespTimer)
        DEC     A
        LD      (IX + MonRespTimer),A
        JR      Z,TickEnemyDone
        SCF
        RET
TickEnemyDone:
        LD      A,PacEnemyAtk
        LD      (IX + MonsterState),A
        CALL    EnemySelectResp
        LD      A,PacDirRight
        LD      (IX + MonsterDir),A
        LD      A,(EnemyPeriodCur)
        LD      (IX + MonsterTimer),A
        CALL    LcdShowPacRun
        OR      A
        RET

; EnemySelectResp —
; Pick the best spawn cell for a respawning
; Monster.
; Scores each PacEnemySpawns entry as distance
; from the player plus distance from other active
; Monsters. Rejects occupied or in-view cells.
; Ties favour the earlier table entry.
; ========================== AZM
; clobbers  B,DE,HL
; ========================== AZM
EnemySelectResp:
        LD      HL,PacEnemySpawns
        LD      B,0xFF                  ; B = best distance; 0xFF means no best yet
        LD      DE,0                    ; D = best x, E = best y
EnemySelRespLp:
        LD      A,(HL)
        CP      0xFF
        JR      Z,EnemyRespCommit
        LD      C,A                     ; C = candidate x
        INC     HL
        LD      A,(HL)                  ; A = candidate y
        INC     HL
        PUSH    HL
        LD      H,A                     ; H = candidate y
        LD      L,C                     ; L = candidate x
        PUSH    DE
        CALL    EnemyOccOther
        POP     DE
        JR      C,EnemyRespKeep
        PUSH    BC
        CALL    EnemyRespScore
        POP     BC
        LD      C,A                     ; C = candidate distance
        LD      A,B
        CP      0xFF
        JR      Z,EnemyRespNewBest
        LD      A,C
        CP      B
        JR      Z,EnemyRespKeep
        JR      C,EnemyRespKeep
EnemyRespNewBest:
        LD      B,C
        LD      D,L
        LD      E,H
EnemyRespKeep:
        POP     HL
        JR      EnemySelRespLp
EnemyRespCommit:
        LD      A,D
        LD      (IX + MonsterX),A
        LD      A,E
        LD      (IX + MonsterY),A
        RET

; EnemyRespScore —
; Score a spawn candidate cell (L=x, H=y).
; Returns 0 when the cell is in the viewport or
; within 8 tiles of the player.
; Otherwise returns player distance +
; summed distance to other active Monsters.
; ========================== AZM
; in        HL
; clobbers  A,C
; ========================== AZM
EnemyRespScore:
        PUSH    DE
        CALL    EnemyIsInView
        JR      C,EnemyRespZero
        CALL    EnemyDistPlayer
        CP      8
        JR      C,EnemyRespZero
        LD      C,A
        PUSH    BC
        CALL    EnemyDistOther
        POP     BC
        ADD     A,C
        POP     DE
        RET
EnemyRespZero:
        XOR     A
        POP     DE
        RET

; EnemyIsInView —
; Test whether a world cell (L=x, H=y) is visible
; in the current 8x8 viewport.
; Returns carry set when in view, clear otherwise.
; ========================== AZM
; in        HL
; clobbers  A,C
; ========================== AZM
EnemyIsInView:
        LD      A,(ViewX)
        LD      C,A
        LD      A,L
        CP      C
        JR      C,EnemyNotVisible
        SUB     C
        CP      RowCount
        JR      NC,EnemyNotVisible
        LD      A,(ViewY)
        LD      C,A
        LD      A,H
        CP      C
        JR      C,EnemyNotVisible
        SUB     C
        CP      RowCount
        JR      NC,EnemyNotVisible
        SCF
        RET
EnemyNotVisible:
        OR      A
        RET

; EnemyOccOther —
; Check if a spawn cell is occupied by another
; active (non-respawning) Monster.
; Skips IX itself and any Monster with a nonzero
; RespTimer. Returns carry set when occupied.
; ========================== AZM
; in        A,HL
; clobbers  A,DE
; ========================== AZM
EnemyOccOther:
        LD      DE,Monster0
        CALL    EnemyOccByDe
        RET     C
        LD      DE,Monster1
        CALL    EnemyOccByDe
        RET     C
        CALL    PacIsLevel2Plus
        JR      C,EnemyOccNo
        LD      DE,Monster2
        JP      EnemyOccByDe

; EnemyOccByDe —
; Test one Monster record against a candidate.
; Returns carry clear when DE == IX (same Monster),
; when the Monster is respawning, or when its
; position differs from (L=x, H=y).
; ========================== AZM
; in        A,DE,HL
; clobbers  A,DE
; ========================== AZM
EnemyOccByDe:
        PUSH    HL
        PUSH    DE
        PUSH    IX
        POP     HL
        OR      A
        SBC     HL,DE
        POP     DE
        POP     HL
        JR      Z,EnemyOccNo
        PUSH    HL
        LD      H,D
        LD      L,E
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        LD      A,(HL)
        POP     HL
        CP      PacEnemyRespawn
        JR      Z,EnemyOccNo
        LD      A,(DE)
        CP      L
        JR      NZ,EnemyOccNo
        INC     DE
        LD      A,(DE)
        CP      H
        JR      NZ,EnemyOccNo
        SCF
        RET
EnemyOccNo:
        OR      A
        RET

; EnemyDistOther —
; Sum Manhattan distances from (L=x, H=y) to all
; other active Monsters.
; Skips the IX Monster, respawning Monsters, and
; Monster2 before level 2.
; ========================== AZM
; in        A,L
; clobbers  A,BC,DE
; ========================== AZM
EnemyDistOther:
        LD      B,0                     ; B = accumulated distance Score
        LD      DE,Monster0
        CALL    EnemyAddDistDe
        LD      DE,Monster1
        CALL    EnemyAddDistDe
        LD      A,B
        LD      C,A
        CALL    PacIsLevel2Plus
        LD      B,C
        LD      A,B
        RET     C
        LD      DE,Monster2
        CALL    EnemyAddDistDe
        LD      A,B
        RET

; EnemyAddDistDe —
; Add one Monster's distance to accumulator B.
; Skips when DE == IX or when the Monster is
; respawning (RespTimer nonzero).
; ========================== AZM
; in        A,DE,L,B
; clobbers  A,BC,DE
; ========================== AZM
EnemyAddDistDe:
        PUSH    HL
        PUSH    DE
        PUSH    IX
        POP     HL
        OR      A
        SBC     HL,DE
        POP     DE
        POP     HL
        RET     Z
        PUSH    HL
        LD      H,D
        LD      L,E
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        LD      A,(HL)
        POP     HL
        OR      A
        RET     NZ
        LD      A,(DE)
        LD      C,A
        INC     DE
        LD      A,(DE)
        LD      D,A
        LD      E,C
        CALL    EnemyDistDe
        ADD     A,B
        LD      B,A
        RET

; EnemyDistPlayer —
; Manhattan distance from (L=x, H=y) to player.
; ========================== AZM
; in        L
; clobbers  A,C
; ========================== AZM
EnemyDistPlayer:
        PUSH    DE
        LD      A,(PlayerX)
        LD      E,A
        LD      A,(PlayerY)
        LD      D,A
        CALL    EnemyDistDe
        POP     DE
        RET

; EnemyDistDe —
; Manhattan distance from (L=x, H=y) to (E=x,
; D=y).
; ========================== AZM
; in        L,E
; clobbers  A,C
; ========================== AZM
EnemyDistDe:
        LD      A,L
        LD      C,A
        LD      A,E
        CP      C
        JR      NC,EnemyDistXHigh
        LD      A,C
        LD      C,A
        LD      A,E
        SUB     C
        NEG
        LD      C,A
        JR      EnemyDistanceY
EnemyDistXHigh:
        SUB     C
        LD      C,A
EnemyDistanceY:
        LD      A,H
        PUSH    BC
        LD      C,A
        LD      A,D
        CP      C
        JR      NC,EnemyDistYHigh
        LD      A,C
        LD      C,A
        LD      A,D
        SUB     C
        NEG
        JR      EnemyDistSum
EnemyDistYHigh:
        SUB     C
EnemyDistSum:
        POP     BC
        ADD     A,C
        RET

; PacAdvanceLevel —
; Increment PacLevel and speed up the Monsters.
; Reduces EnemyPeriodCur by PacEnemyPerStep down
; to PacEnemyPerMin, then restarts the level via
; InitLevelState and shows the running screen.
; ========================== AZM
; in        IX,IY,SP
; clobbers  IX,IY,A,BC,DE,HL
; ========================== AZM
PacAdvanceLevel:
        LD      HL,PacLevel
        INC     (HL)
        LD      A,(EnemyPeriodCur)
        CP      PacEnemyPerMin + PacEnemyPerStep
        JR      C,PacAdvanceMin
        SUB     PacEnemyPerStep
        LD      (EnemyPeriodCur),A
        CALL    InitLevelState
        JP      LcdShowPacRun
PacAdvanceMin:
        LD      A,PacEnemyPerMin
        LD      (EnemyPeriodCur),A
        CALL    InitLevelState
        JP      LcdShowPacRun
