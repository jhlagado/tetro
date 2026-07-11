; Pacmo cooperative frame dispatcher.

; LogicTick —
; Run one Pacmo logic frame while the matrix is
; blank. Game duties update input, timers, Monsters,
; and collision state; then the full Framebuffer is
; rebuilt for the next visible ScanFrame. The final
; flags are not a caller status convention.
.routine out carry,zero clobbers A,BC,DE,HL,IX,IY,sign,parity,halfCarry
LogicTick:
        CALL    PacFrameDuties
        JP      RebuildFb

; PacFrameDuties —
; Per-frame Pacmo logic while the matrix is off.
; Polls input; if not paused: ticks the level-done
; gate, power timer, and each active Monster.
; Then checks player collision against each active
; monster. Monster2 is skipped before level 2.
.routine clobbers BC,DE,HL,IX,IY,A,F
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
        JR      C,_PacFrameTickDone
        LD      IX,Monster2
        CALL    TickEnemy
_PacFrameTickDone:
        LD      IX,Monster0
        CALL    CheckPlyCaught
        LD      IX,Monster1
        CALL    CheckPlyCaught
        CALL    PacIsLevel2Plus
        JR      C,_PacFrameCollDone
        LD      IX,Monster2
        CALL    CheckPlyCaught
_PacFrameCollDone:
        RET

; PacRenderRowA —
; Update screen row A in the live Framebuffer.
; Copies the completed back row to the front FB,
; clears the back row, then rebuilds it from
; world, power pills, Monsters, and player.
; A is expected to be 0..7.
.routine in A clobbers A,BC,DE,HL,IX,F
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

; TickLvlDoneGate —
; Count down the level-completion delay.
; Active only when PacRoundDone is set.
; On expiry, advances to the next level. Otherwise it
; only decrements PacLvlDoneLo/Hi.
.routine clobbers A,BC,DE,HL,IX,F
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
; PacEnemyAtk and restores the running LCD.
.routine clobbers HL,A,DE,F
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
; carry set when PacLevel < 2. A contains PacLevel
; after the comparison.
.routine out A,carry,zero clobbers sign,parity,halfCarry
PacIsLevel2Plus:
        LD      A,(PacLevel)
        CP      2
        RET

; TickEnemy —
; Drive the monster record at IX for this frame.
; Returns immediately on splash, caught, or
; round-done. Delegates to TickEnemyResp when
; the Monster is respawning.
; When timer expires: attack state calls
; EnemyAttackStep; roam calls EnemyRoamStep. Carry is
; inherited from respawn/move paths and is not used by
; the frame dispatcher as a public result.
.routine in IX out BC,A,H,carry,zero clobbers sign,parity,halfCarry,DE,L
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
; Take one greedy chase step for the monster at IX.
; Tries the preferred then secondary chase
; direction from EnemyChaseDirs, skipping the
; immediate reverse direction.
; Falls through to EnemyRoamStep when both chase
; directions are blocked. Carry set means a step was
; committed by the chosen movement path.
.routine in IX out BC,A,zero,H,carry clobbers sign,parity,halfCarry,DE,L
EnemyAttackStep:
        CALL    EnemyChaseDirs
        LD      A,(IX + MonsterDir)
        .expectout A
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
; Try chase direction A for the monster at IX.
; L holds the immediate reverse direction to forbid.
; Returns carry clear when A is zero, when A equals L,
; or when the resulting move is blocked; carry set
; means EnemyTryMove committed the step.
.routine in A,L,IX out carry,BC,A,zero clobbers sign,parity,halfCarry,E,HL
EnemyTryChase:
        OR      A
        RET     Z
        CP      L
        JR      Z,_EnemyChaseBlock
        CALL    EnemyTryMove
        RET
_EnemyChaseBlock:
        OR      A
        RET

; EnemyChaseDirs —
; Compute chase directions for the monster at IX.
; Returns D as the preferred reducing direction and E
; as the secondary direction, ordered by the larger
; Manhattan distance axis. Either direction may be 0
; when already aligned on that axis.
.routine in IX out DE,zero,HL clobbers BC,carry,sign,parity,halfCarry,A
EnemyChaseDirs:
        .expectout A,B
        CALL    EnemyHorizChase
        LD      H,A                     ; H = horizontal distance
        LD      D,B                     ; D = horizontal reducing direction
        .expectout A,B
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
; Compare monster X from IX with PlayerX.
; Returns A as the absolute horizontal distance and B
; as the reducing direction, or B=0 when aligned.
.routine in IX out A,B,carry,zero clobbers C,sign,parity,halfCarry
EnemyHorizChase:
        LD      A,(IX + MonsterX)
        LD      C,A
        LD      A,(PlayerX)
        CP      C
        JR      Z,_EnemyHorizAlign
        JR      C,_EnemyHorizRight
        SUB     C
        LD      B,PacDirLeft
        RET
_EnemyHorizRight:
        LD      A,C
        LD      B,A
        LD      A,(PlayerX)
        LD      C,A
        LD      A,B
        SUB     C
        LD      B,PacDirRight
        RET
_EnemyHorizAlign:
        LD      B,0
        XOR     A
        RET

; EnemyVertChase —
; Compare monster Y from IX with PlayerY.
; Returns A as the absolute vertical distance and B
; as the reducing direction, or B=0 when aligned.
.routine in IX out A,B,carry,zero clobbers C,sign,parity,halfCarry
EnemyVertChase:
        LD      A,(IX + MonsterY)
        LD      C,A
        LD      A,(PlayerY)
        CP      C
        JR      Z,_EnemyVertAlign
        JR      C,_EnemyVertUp
        SUB     C
        LD      B,PacDirDown
        RET
_EnemyVertUp:
        LD      A,C
        LD      B,A
        LD      A,(PlayerY)
        LD      C,A
        LD      A,B
        SUB     C
        LD      B,PacDirUp
        RET
_EnemyVertAlign:
        LD      B,0
        XOR     A
        RET

; EnemyRoamStep —
; Roam the monster at IX into an adjacent open cell.
; The first candidate direction is derived from level,
; position, and current direction for varied routing.
; Avoids the immediate reverse unless all other
; directions are blocked. Carry set means a move was
; committed.
.routine in IX out BC,A,zero,H,carry clobbers sign,parity,halfCarry,DE,L
EnemyRoamStep:
        LD      A,(IX + MonsterX)
        LD      B,A
        LD      A,(IX + MonsterY)
        LD      C,A
        LD      A,(IX + MonsterDir)
        .expectout A
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
_EnemyRoamLoop:
        LD      A,E
        CP      D
        JR      Z,_EnemyRoamNext
        PUSH    DE
        PUSH    HL
        CALL    EnemyTryMove
        POP     HL
        POP     DE
        RET     C
_EnemyRoamNext:
        INC     E
        LD      A,E
        CP      5
        JR      C,_EnemyRoamReady
        LD      E,1
_EnemyRoamReady:
        DEC     H
        JR      NZ,_EnemyRoamLoop
        LD      A,D
        CALL    EnemyTryMove
        RET

; EnemyOpposite —
; A contains a PacDir value. The opposite direction is
; returned in A: up/down or left/right. Flags are
; incidental.
.routine in A out A,carry clobbers zero,sign,parity,halfCarry
EnemyOpposite:
        CP      PacDirUp
        JR      Z,_EnemyOppDown
        CP      PacDirDown
        JR      Z,_EnemyOppUp
        CP      PacDirLeft
        JR      Z,_EnemyOppRight
        LD      A,PacDirLeft
        RET
_EnemyOppDown:
        LD      A,PacDirDown
        RET
_EnemyOppUp:
        LD      A,PacDirUp
        RET
_EnemyOppRight:
        LD      A,PacDirRight
        RET

; EnemyTryMove —
; Try one step in direction A for the monster at IX.
; Builds candidate B=x, C=y, checks bounds and walls,
; then commits MonsterX/Y and MonsterDir on success.
; Returns carry set for a committed move, carry clear
; when blocked, out of bounds, or passed no direction.
.routine in IX,A out carry,zero,A,BC clobbers E,sign,parity,halfCarry,HL
EnemyTryMove:
        LD      E,A
        LD      A,(IX + MonsterX)
        LD      B,A
        LD      A,(IX + MonsterY)
        LD      C,A
        LD      A,E
        CP      PacDirLeft
        JR      Z,_EnemyTryLeft
        CP      PacDirRight
        JR      Z,_EnemyTryRight
        CP      PacDirUp
        JR      Z,_EnemyTryUp
        CP      PacDirDown
        JR      Z,_EnemyTryDown
        OR      A
        RET
_EnemyTryLeft:
        LD      A,B
        CP      PacWorldMax
        JR      NC,_EnemyTryBlocked
        INC     B
        JR      _EnemyCommitOpen
_EnemyTryRight:
        LD      A,B
        OR      A
        JR      Z,_EnemyTryBlocked
        DEC     B
        JR      _EnemyCommitOpen
_EnemyTryUp:
        LD      A,C
        OR      A
        JR      Z,_EnemyTryBlocked
        DEC     C
        JR      _EnemyCommitOpen
_EnemyTryDown:
        LD      A,C
        CP      PacWorldMax
        JR      NC,_EnemyTryBlocked
        INC     C
_EnemyCommitOpen:
        PUSH    DE
        CALL    IsWallAtBc
        POP     DE
        JR      C,_EnemyTryBlocked
        LD      A,B
        LD      (IX + MonsterX),A
        LD      A,C
        LD      (IX + MonsterY),A
        LD      A,E
        LD      (IX + MonsterDir),A
        SCF
        RET
_EnemyTryBlocked:
        OR      A
        RET

; TickEnemyResp —
; Manage respawn countdown for the monster at IX.
; Returns carry set while the monster remains hidden.
; When the countdown expires, selects a new spawn
; cell, restores attack state/direction/timer, refreshes
; the LCD, and returns carry clear.
.routine in IX out carry,B,zero clobbers sign,parity,halfCarry,A,C,DE,HL
TickEnemyResp:
        LD      A,(IX + MonRespTimer)
        OR      A
        RET     Z
        LD      A,(IX + MonsterTimer)
        OR      A
        JR      Z,_TickEnemyRespDec
        DEC     A
        LD      (IX + MonsterTimer),A
        JR      Z,_TickEnemyRespDec
        SCF
        RET
_TickEnemyRespDec:
        LD      A,PacEnemyRespDiv
        LD      (IX + MonsterTimer),A
        LD      A,(IX + MonRespTimer)
        DEC     A
        LD      (IX + MonRespTimer),A
        JR      Z,_TickEnemyDone
        SCF
        RET
_TickEnemyDone:
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
; Pick the best spawn cell for the monster at IX.
; Scores each PacEnemySpawns entry as distance
; from the player plus distance from other active
; monsters. Rejects occupied or in-view cells. Ties
; favour the earlier table entry. Writes the selected
; cell back to MonsterX/Y; no value is returned to the
; caller.
.routine in IX out carry,HL,B clobbers A,C,DE,zero,sign,parity,halfCarry
EnemySelectResp:
        LD      HL,PacEnemySpawns
        LD      B,0xFF                  ; B = best distance; 0xFF means no best yet
        LD      DE,0                    ; D = best x, E = best y
_EnemySelRespLp:
        LD      A,(HL)
        CP      0xFF
        JR      Z,_EnemyRespCommit
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
        JR      C,_EnemyRespKeep
        PUSH    BC
        .expectout A
        CALL    EnemyRespScore
        POP     BC
        LD      C,A                     ; C = candidate distance
        LD      A,B
        CP      0xFF
        JR      Z,_EnemyRespNewBest
        LD      A,C
        CP      B
        JR      Z,_EnemyRespKeep
        JR      C,_EnemyRespKeep
_EnemyRespNewBest:
        LD      B,C
        LD      D,L
        LD      E,H
_EnemyRespKeep:
        POP     HL
        JR      _EnemySelRespLp
_EnemyRespCommit:
        LD      A,D
        LD      (IX + MonsterX),A
        LD      A,E
        LD      (IX + MonsterY),A
        RET

; EnemyRespScore —
; Score spawn candidate cell L=x, H=y for the monster
; at IX.
; Returns 0 when the cell is in the viewport or
; within 8 tiles of the player.
; Otherwise returns player distance +
; summed distance to other active monsters in A.
.routine in HL,IX out A,carry,zero clobbers C,sign,parity,halfCarry
EnemyRespScore:
        PUSH    DE
        CALL    EnemyIsInView
        JR      C,_EnemyRespZero
        .expectout A
        CALL    EnemyDistPlayer
        CP      8
        JR      C,_EnemyRespZero
        LD      C,A
        PUSH    BC
        CALL    EnemyDistOther
        POP     BC
        ADD     A,C
        POP     DE
        RET
_EnemyRespZero:
        XOR     A
        POP     DE
        RET

; EnemyIsInView —
; Test whether world cell L=x, H=y is visible in the
; current 8x8 viewport.
; Returns carry set when in view, clear otherwise.
.routine in HL out carry,zero,A clobbers C,sign,parity,halfCarry
EnemyIsInView:
        LD      A,(ViewX)
        LD      C,A
        LD      A,L
        CP      C
        JR      C,_EnemyNotVisible
        SUB     C
        CP      RowCount
        JR      NC,_EnemyNotVisible
        LD      A,(ViewY)
        LD      C,A
        LD      A,H
        CP      C
        JR      C,_EnemyNotVisible
        SUB     C
        CP      RowCount
        JR      NC,_EnemyNotVisible
        SCF
        RET
_EnemyNotVisible:
        OR      A
        RET

; EnemyOccOther —
; Test whether spawn cell L=x, H=y is occupied by
; another active monster. IX identifies the monster to
; ignore. Respawning monsters do not count. Returns
; carry set when occupied.
.routine in IX,HL out A,zero,carry clobbers DE,sign,parity,halfCarry
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
; Test monster record DE against candidate cell
; L=x, H=y. IX identifies the current monster to
; ignore. Returns carry set when DE is another active
; monster at that cell; otherwise carry clear.
.routine in IX,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
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

; EnemyOccNo -
; Shared clear-carry return used by the occupancy tests.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry
EnemyOccNo:
        OR      A
        RET

; EnemyDistOther —
; Sum Manhattan distances from cell L=x, H=y to all
; other active monsters. IX identifies the monster to
; exclude. Respawning monsters and inactive Monster2
; are skipped. Returns the sum in A.
.routine in IX,HL out A clobbers BC,DE,F
EnemyDistOther:
        LD      B,0                     ; B = accumulated distance Score
        LD      DE,Monster0
        CALL    EnemyAddDistDe
        LD      DE,Monster1
        .expectout B
        CALL    EnemyAddDistDe
        LD      A,B
        LD      C,A
        CALL    PacIsLevel2Plus
        LD      B,C
        LD      A,B
        RET     C
        LD      DE,Monster2
        .expectout B
        CALL    EnemyAddDistDe
        LD      A,B
        RET

; EnemyAddDistDe —
; Add one candidate monster's distance into B.
; DE points to the candidate monster record, IX is the
; monster to exclude, and HL is the reference cell
; L=x, H=y. Respawning candidates are skipped.
.routine in IX,DE,HL,B out B clobbers A,C,DE,F
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
; Return in A the Manhattan distance from cell
; L=x, H=y to the player.
.routine in HL out A clobbers C,F
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
; Return in A the Manhattan distance from cell
; L=x, H=y to cell E=x, D=y.
.routine in DE,HL out A clobbers C,F
EnemyDistDe:
        LD      A,L
        LD      C,A
        LD      A,E
        CP      C
        JR      NC,_EnemyDistXHigh
        LD      A,C
        LD      C,A
        LD      A,E
        SUB     C
        NEG
        LD      C,A
        JR      _EnemyDistanceY
_EnemyDistXHigh:
        SUB     C
        LD      C,A
_EnemyDistanceY:
        LD      A,H
        PUSH    BC
        LD      C,A
        LD      A,D
        CP      C
        JR      NC,_EnemyDistYHigh
        LD      A,C
        LD      C,A
        LD      A,D
        SUB     C
        NEG
        JR      _EnemyDistSum
_EnemyDistYHigh:
        SUB     C
_EnemyDistSum:
        POP     BC
        ADD     A,C
        RET

; PacAdvanceLevel —
; Increment PacLevel and speed up the Monsters.
; Reduces EnemyPeriodCur by PacEnemyPerStep down
; to PacEnemyPerMin, then restarts the level via
; InitLevelState and shows the running screen.
.routine clobbers A,BC,DE,HL,IX,F
PacAdvanceLevel:
        LD      HL,PacLevel
        INC     (HL)
        LD      A,(EnemyPeriodCur)
        CP      PacEnemyPerMin + PacEnemyPerStep
        JR      C,_PacAdvanceMin
        SUB     PacEnemyPerStep
        LD      (EnemyPeriodCur),A
        CALL    InitLevelState
        JP      LcdShowPacRun
_PacAdvanceMin:
        LD      A,PacEnemyPerMin
        LD      (EnemyPeriodCur),A
        CALL    InitLevelState
        JP      LcdShowPacRun
