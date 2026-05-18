; Run one Pacmo logic slice per main-loop pass.
; LogicTick
; Input:
;   uses LogicSlice from RAM
; Output:
;   slices 0..7 copy and rebuild one Framebuffer row; after row 7, the
;   matrix is blanked and frame-wide Pacmo duties run
; Clobbers:
;   A, BC, DE, HL, IX, and registers clobbered by called slice routines
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

; PacFrameDuties
; Input:
;   current Pacmo state
; Output:
;   input, timers, enemy ticks, and collision checks updated once per frame
;   while the matrix rows are blanked
; Clobbers:
;   A, BC, DE, HL, IX
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

; PacRenderRowA
; Input:
;   A = screen row 0..7
; Output:
;   matching completed back row copied to the front Framebuffer, then that
;   back row rebuilt from the current Pacmo world/entity state
; Clobbers:
;   A, BC, DE, HL, IX
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

; TickLvlDoneGate
; Input:
;   PacRoundDone, PacLvlDoneLo/HI
; Output:
;   when a completed-level delay expires, advances and initializes next level
; Clobbers:
;   A, HL while waiting; A, BC, DE, HL when advancing the level
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

; TickPowerTimer
; Input:
;   PacPowerTimerLo/HI
; Output:
;   decrements 16-bit PacPowerTimer by one when nonzero; restores
;   running LCD status when power mode expires
; Clobbers:
;   A, DE, HL
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

; PacIsLevel2Plus
; Input:
;   PacLevel
; Output:
;   carry clear when level >= 2, carry set when level < 2
; Clobbers:
;   A
; Returns @out carry set when level < 2, clear otherwise.
; Uses @clobbers A,F while comparing PacLevel.
; Keeps @preserves BC,DE,HL,IX,IY stable for the caller.
PacIsLevel2Plus:
        LD      A,(PacLevel)
        CP      2
        RET

; TickEnemy
; Input:
;   IX = monster record base
;   monster X/Y, direction, timer, state, respawn timer
; Output:
;   active enemy moves when its timer reaches zero; respawning enemy counts
;   down, then respawns at the selected candidate cell
; Clobbers:
;   A, BC, DE, HL
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

; EnemyAttackStep
; Input:
;   IX = monster record base
;   monster X/Y and direction, PlayerX/Y
; Output:
;   enemy tries a greedy move that reduces distance to the player, then falls
;   back to roaming if both chase directions are blocked or reverse-only.
; Clobbers:
;   A, BC, DE, HL
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

; EnemyTryChase
; Input:
;   A = candidate PACMO_DIR_* or 0
;   L = immediate reverse direction to avoid
; Output:
;   Carry set when candidate moves the enemy; carry clear otherwise
; Clobbers:
;   A, BC, DE, HL
; Accepts @in A as candidate PACMO_DIR_* or 0.
; Accepts @in L as immediate reverse direction to avoid.
; Returns @out carry set when candidate moves the enemy.
; Uses @clobbers A,BC,DE,HL,F while testing the move.
; Keeps @preserves IX,IY stable for the caller.
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

; EnemyChaseDirs
; Input:
;   IX = monster record base
;   monster X/Y, PlayerX/Y
; Output:
;   D = preferred direction on the larger distance axis, or 0 when aligned
;   E = secondary reducing direction, or 0 when aligned
; Clobbers:
;   A, B, C, H, L
; Returns @out D as the preferred chase direction.
; Returns @out E as the secondary chase direction.
; Uses @clobbers A,BC,HL,F while comparing chase axes.
; Keeps @preserves IX,IY stable for the caller.
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

; EnemyHorizChase
; Input:
;   IX = monster record base
;   monster X, PlayerX
; Output:
;   A = absolute horizontal distance
;   B = PacDirLeft/RIGHT reducing that distance, or 0 when aligned
; Clobbers:
;   A, B, C
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

; EnemyVertChase
; Input:
;   IX = monster record base
;   monster Y, PlayerY
; Output:
;   A = absolute vertical distance
;   B = PacDirUp/DOWN reducing that distance, or 0 when aligned
; Clobbers:
;   A, B, C
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

; EnemyRoamStep
; Input:
;   IX = monster record base
;   monster X/Y and direction, PacLevel
; Output:
;   EnemyX/Y updated to one open adjacent cell; EnemyDir set to movement
;   direction. Immediate reversal is used only when no other direction is open.
; Clobbers:
;   A, BC, DE, HL
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

; EnemyOpposite
; Input:
;   A = PACMO_DIR_*
; Output:
;   A = opposite PACMO_DIR_*
; Clobbers:
;   A
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

; EnemyTryMove
; Input:
;   IX = monster record base
;   A = PACMO_DIR_* candidate
; Output:
;   Carry set when move succeeds; monster X/Y and direction committed.
;   Carry clear when candidate is out of bounds or a wall.
; Clobbers:
;   A, BC, DE, HL
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

; TickEnemyResp
; Input:
;   IX = monster record base
; Output:
;   Carry set while enemy is respawning; when the timer reaches zero,
;   enemy position and direction are reset and carry is cleared
; Clobbers:
;   A, BC, DE, HL
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

; EnemySelectResp
; Input:
;   IX = respawning monster record base
;   PlayerX/Y, PacEnemySpawns, Monsters
; Output:
;   monster X/Y set to the unoccupied spawn candidate with the highest Score:
;   distance from player plus distance from the other non-respawning Monsters.
;   Ties keep the earlier table entry.
; Clobbers:
;   A, BC, DE, HL
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

; EnemyRespScore
; Input:
;   L = candidate x
;   H = candidate y
;   IX = respawning monster record base
; Output:
;   A = candidate Score.  Higher is better.
; Clobbers:
;   A, BC
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

; EnemyIsInView
; Input:
;   L = candidate x
;   H = candidate y
; Output:
;   carry set when candidate is currently visible in the 8x8 viewport,
;   carry clear otherwise
; Clobbers:
;   A, C
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

; EnemyOccOther
; Input:
;   L = candidate x
;   H = candidate y
;   IX = respawning monster record base
; Output:
;   carry set when another non-respawning monster already occupies candidate
;   carry clear otherwise
; Clobbers:
;   A, DE
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

; EnemyOccByDe
; Input:
;   L = candidate x
;   H = candidate y
;   DE = monster record pointer
;   IX = respawning monster record base
; Output:
;   carry set when DE points to a different non-respawning monster at candidate
;   carry clear otherwise
; Clobbers:
;   A, DE
; Accepts @in L as candidate x.
; Accepts @in H as candidate y.
; Accepts @in DE as monster record pointer.
; Accepts @in IX as respawning monster record base.
; Returns @out carry set when the candidate is occupied.
; Uses @clobbers A,DE,F while testing the monster record.
; Keeps @preserves BC,HL,IX,IY stable for the caller.
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

; EnemyDistOther
; Input:
;   L = candidate x
;   H = candidate y
;   IX = respawning monster record base
; Output:
;   A = summed distance to other active Monsters.  Respawning Monsters, the
;   current IX monster, and level-2 monster before level 2 are ignored.
; Clobbers:
;   A, BC, DE
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

; EnemyAddDistDe
; Input:
;   B = accumulated distance Score
;   L = candidate x
;   H = candidate y
;   DE = monster record pointer
;   IX = respawning monster record base
; Output:
;   B = updated accumulated distance Score
; Clobbers:
;   A, C, DE
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

; EnemyDistPlayer
; Input:
;   L = candidate x
;   H = candidate y
; Output:
;   A = |candidate x - PlayerX| + |candidate y - PlayerY|
; Clobbers:
;   A, C
EnemyDistPlayer:
        PUSH    DE
        LD      A,(PlayerX)
        LD      E,A
        LD      A,(PlayerY)
        LD      D,A
        CALL    EnemyDistDe
        POP     DE
        RET

; EnemyDistDe
; Input:
;   L = candidate x
;   H = candidate y
;   E = target x
;   D = target y
; Output:
;   A = |candidate x - target x| + |candidate y - target y|
; Clobbers:
;   A, C
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

; PacAdvanceLevel
; Input:
;   PacLevel, EnemyPeriodCur
; Output:
;   level count incremented, enemy period reduced to its minimum, level restarted
; Clobbers:
;   A, BC, DE, HL
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
