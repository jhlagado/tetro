; RebuildFb
; Input:
;   current viewport and player state in RAM
; Output:
;   Framebuffer rebuilt from scratch
; Clobbers:
;   A, BC, DE, HL, IX
RebuildFb:
        CALL    FbClearAll
        CALL    RendWorldBack
        CALL    RendPwrPills
        LD      IX,Monster0
        CALL    RendEnemyBack
        LD      IX,Monster1
        CALL    RendEnemyBack
        LD      A,(PacLevel)
        CP      2
        JR      C,RebuildMonsDone
        LD      IX,Monster2
        CALL    RendEnemyBack
RebuildMonsDone:
        CALL    RendPlyBack
        JP      FbCopyAll

; RendGOverBack
; Input:
;   none
; Output:
;   FramebufferBack filled with PacColorGOver as a dramatic cue
; Clobbers:
;   A, B, HL
RendGOverBack:
        LD      HL,FramebufferBack
        LD      B,RowCount
RendGOverRow:
        LD      A,PacColorGOver
        AND     ColorRed
        JR      Z,RendGOverRedOff
        LD      A,0xFF
RendGOverRedOff:
        LD      (HL),A
        INC     HL
        LD      A,PacColorGOver
        AND     ColorGreen
        JR      Z,RendGOverGrnOff
        LD      A,0xFF
RendGOverGrnOff:
        LD      (HL),A
        INC     HL
        LD      A,PacColorGOver
        AND     ColorBlue
        JR      Z,RendGOverBluOff
        LD      A,0xFF
RendGOverBluOff:
        LD      (HL),A
        INC     HL
        XOR     A
        LD      (HL),A                  ; aux off
        INC     HL
        DJNZ    RendGOverRow
        RET

; RendLvlDoneBack
; Input:
;   none
; Output:
;   FramebufferBack filled with PacColorRound
; Clobbers:
;   A, B, HL
RendLvlDoneBack:
        LD      HL,FramebufferBack
        LD      B,RowCount
RendLvlDoneRow:
        LD      A,PacColorRound
        AND     ColorRed
        JR      Z,RendLvlRedOff
        LD      A,0xFF
RendLvlRedOff:
        LD      (HL),A
        INC     HL
        LD      A,PacColorRound
        AND     ColorGreen
        JR      Z,RendLvlGrnOff
        LD      A,0xFF
RendLvlGrnOff:
        LD      (HL),A
        INC     HL
        LD      A,PacColorRound
        AND     ColorBlue
        JR      Z,RendLvlBluOff
        LD      A,0xFF
RendLvlBluOff:
        LD      (HL),A
        INC     HL
        XOR     A
        LD      (HL),A                  ; aux off
        INC     HL
        DJNZ    RendLvlDoneRow
        RET

; RendWorldBack
; Input:
;   ViewX/Y and PacWorldRows
; Output:
;   visible 8x8 viewport rendered with PacColorPath and PacColorWall
; Clobbers:
;   A, BC, DE, HL
RendWorldBack:
        LD      B,0
RendWorldBackLp:
        LD      A,B
        PUSH    BC
        CALL    RendWorldRow
        POP     BC
        INC     B
        LD      A,B
        CP      RowCount
        JR      C,RendWorldBackLp
        RET

; RendWorldRow
; Input:
;   A = screen row 0..7
; Output:
;   selected FramebufferBack row rendered from the corresponding world/eaten row
; Clobbers:
;   A, BC, DE, HL
RendWorldRow:
        LD      C,A                     ; C = screen row
        ADD     A,A
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,FramebufferBack
        ADD     HL,DE
        PUSH    HL                      ; target Framebuffer row

        LD      A,(ViewY)
        ADD     A,C                     ; A = world row
        ADD     A,A
        LD      E,A
        LD      D,0
        PUSH    DE                      ; source byte offset

        LD      HL,PacWorldRows
        ADD     HL,DE
        LD      A,(HL)
        LD      B,A                     ; B = high byte of 15-bit row
        INC     HL
        LD      A,(HL)
        LD      C,A                     ; C = low byte of 15-bit row
        LD      A,(ViewX)
        CALL    WindowByteBc
        POP     DE
        PUSH    AF                      ; visible wall mask

        LD      HL,PacEatenRows
        ADD     HL,DE
        LD      A,(HL)
        LD      B,A
        INC     HL
        LD      A,(HL)
        LD      C,A
        LD      A,(ViewX)
        CALL    WindowByteBc
        LD      B,A                     ; B = visible eaten mask
        POP     AF
        LD      C,A                     ; C = visible wall mask
        OR      B
        CPL                             ; A = visible uneaten open path mask
        LD      D,A
        POP     HL                      ; target Framebuffer row
        JP      WrWorldColors

; WrWorldColors
; Input:
;   HL = red plane byte for the target Framebuffer row
;   C  = visible wall mask
;   D  = visible uneaten path mask
; Output:
;   red/green/blue plane bytes written from PacColorWall/PATH;
;   caught state renders walls with PacColorCaught;
;   complete state renders walls with PacColorDone
;   HL points to the aux byte after the blue plane
; Clobbers:
;   A, B, HL
WrWorldColors:
        XOR     A
        LD      B,A
        CALL    GetWallColor
        AND     ColorRed
        JR      Z,WrWorldRedPath
        LD      B,C
WrWorldRedPath:
        LD      A,PacColorPath
        AND     ColorRed
        JR      Z,WrWorldRedSet
        LD      A,B
        OR      D
        LD      B,A
WrWorldRedSet:
        LD      (HL),B
        INC     HL

        XOR     A
        LD      B,A
        CALL    GetWallColor
        AND     ColorGreen
        JR      Z,WrWorldGrnPath
        LD      B,C
WrWorldGrnPath:
        LD      A,PacColorPath
        AND     ColorGreen
        JR      Z,WrWorldGrnSet
        LD      A,B
        OR      D
        LD      B,A
WrWorldGrnSet:
        LD      (HL),B
        INC     HL

        XOR     A
        LD      B,A
        CALL    GetWallColor
        AND     ColorBlue
        JR      Z,WrWorldBluPath
        LD      B,C
WrWorldBluPath:
        LD      A,PacColorPath
        AND     ColorBlue
        JR      Z,WrWorldBluSet
        LD      A,B
        OR      D
        LD      B,A
WrWorldBluSet:
        LD      (HL),B
        INC     HL
        RET

; GetWallColor
; Input:
;   PacPlayerCaught, PacRoundDone
; Output:
;   A = wall color for the current render state
; Clobbers:
;   A
GetWallColor:
        LD      A,(PacPlayerCaught)
        OR      A
        JR      NZ,GetWallCaught
        LD      A,(PacRoundDone)
        OR      A
        JR      NZ,GetWallDone
        LD      A,PacColorWall
        RET
GetWallCaught:
        LD      A,PacColorCaught
        RET
GetWallDone:
        LD      A,PacColorDone
        RET

; WindowByteBc
; Input:
;   BC = 16-bit world row, bit 15 is world column 0
;   A  = viewport X origin, expected 0..7
; Output:
;   A = 8 visible bits for columns ViewX..ViewX+7
; Clobbers:
;   B, C, D
; Accepts @in BC as the 16-bit world row.
; Accepts @in A as viewport X origin.
; Returns @out A as the visible window byte.
; Uses @clobbers B,C,D,F while shifting the world row.
; Keeps @preserves E,HL,IX,IY stable for the caller.
WindowByteBc:
        LD      D,A
        LD      A,D
        OR      A
        JR      Z,WindowByteDone
WindowShiftLoop:
        SLA     C
        RL      B
        DEC     D
        JR      NZ,WindowShiftLoop
WindowByteDone:
        LD      A,B
        RET

; RendPwrPills
; Input:
;   ViewX/Y and PacPowerPills
; Output:
;   visible power pills rendered with PacColorPwrPill
; Clobbers:
;   A, BC, DE, HL
RendPwrPills:
        LD      HL,PacPowerPills
        LD      D,1
RendPwrPillLp:
        LD      A,(HL)
        CP      0xFF
        RET     Z
        LD      B,A                     ; B = world x
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      C,A                     ; C = world y
        LD      A,(PacPwrPillsEat)
        AND     D
        JR      NZ,RendPwrPillNext
        PUSH    HL
        PUSH    DE
        CALL    RendPwrPillBc
        POP     DE
        POP     HL
RendPwrPillNext:
        SLA     D
        JR      RendPwrPillLp

; RendPwrPillRow
; Input:
;   A = screen row 0..7
; Output:
;   visible power pills on that row rendered into FramebufferBack
; Clobbers:
;   A, BC, DE, HL
RendPwrPillRow:
        LD      E,A                     ; E = target screen row
        LD      HL,PacPowerPills
        LD      D,1
RendPwrRowLoop:
        LD      A,(HL)
        CP      0xFF
        RET     Z
        LD      B,A                     ; B = world x
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      C,A                     ; C = world y
        LD      A,(PacPwrPillsEat)
        AND     D
        JR      NZ,RendPwrRowNext
        LD      A,(ViewY)
        ADD     A,E
        CP      C
        JR      NZ,RendPwrRowNext
        PUSH    HL
        PUSH    DE
        CALL    RendPwrPillBc
        POP     DE
        POP     HL
RendPwrRowNext:
        SLA     D
        JR      RendPwrRowLoop

; RendPwrPillBc
; Input:
;   B = world x
;   C = world y
; Output:
;   if the cell is in the viewport, its Framebuffer cell is set to power-pill color
; Clobbers:
;   A, B, C, DE, HL
RendPwrPillBc:
        LD      A,(ViewY)
        LD      E,A
        LD      A,C
        SUB     E                       ; A = screenY
        CP      RowCount
        RET     NC
        ADD     A,A
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,FramebufferBack
        ADD     HL,DE

        LD      A,(ViewX)
        LD      E,A
        LD      A,B
        SUB     E                       ; A = screenX
        CP      RowCount
        RET     NC
        CALL    MxMask
        LD      C,A

        LD      A,PacColorPwrPill
        JP      FbSetCell

; RendEnemyBack
; Input:
;   IX = monster record base
;   monster X/Y, ViewX/Y, monster state, PacPowerTimerLo/HI, respawn timer
; Output:
;   enemy pixel rendered as attack color normally or flee color when enemy state is flee,
;   replacing any path color at that cell; respawning enemy is not rendered
; Clobbers:
;   A, B, C, DE, HL
RendEnemyBack:
        LD      A,(IX + MonRespTimer)
        OR      A
        RET     NZ
        LD      A,(IX + MonsterY)
        LD      B,A
        LD      A,(ViewY)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenY
        CP      RowCount
        RET     NC
        ADD     A,A
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,FramebufferBack
        ADD     HL,DE

        LD      A,(IX + MonsterX)
        LD      B,A
        LD      A,(ViewX)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenX
        CP      RowCount
        RET     NC
        CALL    MxMask
        LD      C,A

        PUSH    HL
        LD      A,(IX + MonsterState)
        CP      PacEnemyFlee
        JR      NZ,RendEnAtkTmr
        LD      HL,(PacPowerTimerLo)
        LD      A,H
        OR      L
        JR      Z,RendEnAtkTmr
        LD      A,H
        OR      A
        JR      NZ,RendEnFleeTmr
        LD      A,L
        AND     PacPwrWarnMask
        JR      Z,RendEnAtkTmr
RendEnFleeTmr:
        POP     HL
        JR      RendEnemyFlee
RendEnAtkTmr:
        POP     HL
        LD      A,PacColorEnAtk
        JP      FbSetCell
RendEnemyFlee:
        LD      A,PacColorEnFlee
        JP      FbSetCell

; RendMonsRow
; Input:
;   A = screen row 0..7
; Output:
;   visible Monsters on that row rendered into FramebufferBack
; Clobbers:
;   A, BC, DE, HL, IX
RendMonsRow:
        LD      C,A
        PUSH    BC
        LD      E,C
        LD      IX,Monster0
        CALL    RendEnemyIfRow
        POP     BC
        PUSH    BC
        LD      E,C
        LD      IX,Monster1
        CALL    RendEnemyIfRow
        POP     BC
        PUSH    BC
        CALL    PacIsLevel2Plus
        POP     BC
        RET     C
        LD      E,C
        LD      IX,Monster2
        JP      RendEnemyIfRow

; RendEnemyIfRow
; Input:
;   E = target screen row 0..7
;   IX = monster record base
; Output:
;   enemy rendered only when it is active and occupies target screen row
; Clobbers:
;   A, BC, DE, HL
RendEnemyIfRow:
        LD      A,(IX + MonRespTimer)
        OR      A
        RET     NZ
        LD      A,(IX + MonsterY)
        LD      B,A
        LD      A,(ViewY)
        LD      C,A
        LD      A,B
        SUB     C
        CP      RowCount
        RET     NC
        CP      E
        RET     NZ
        PUSH    DE
        CALL    RendEnemyBack
        POP     DE
        RET

; RendPlyBack
; Input:
;   PlayerX/Y, ViewX/Y
; Output:
;   player pixel rendered with palette colors; yellow normally, white when the
;   round is complete, red when caught
; Clobbers:
;   A, B, C, DE, HL
RendPlyBack:
        LD      A,(PlayerY)
        LD      B,A
        LD      A,(ViewY)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenY
        CP      RowCount
        RET     NC
        ADD     A,A
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,FramebufferBack
        ADD     HL,DE

        LD      A,(PlayerX)
        LD      B,A
        LD      A,(ViewX)
        LD      C,A
        LD      A,B
        SUB     C                       ; A = screenX
        CP      RowCount
        RET     NC
        CALL    MxMask
        LD      C,A

        LD      A,(PacPlayerCaught)
        OR      A
        JR      NZ,RendPlyCaught

        LD      A,(PacRoundDone)
        OR      A
        JR      NZ,RendPlyWhite
        LD      A,PacColorPlayer
        JP      FbSetCell
RendPlyWhite:
        LD      A,PacColorRound
        JP      FbSetCell
RendPlyCaught:
        LD      A,PacColorEnAtk
        JP      FbSetCell

; RendPlyRow
; Input:
;   A = screen row 0..7
; Output:
;   player rendered into FramebufferBack only when it occupies that row
; Clobbers:
;   A, BC, DE, HL
RendPlyRow:
        LD      E,A
        LD      A,(PlayerY)
        LD      B,A
        LD      A,(ViewY)
        LD      C,A
        LD      A,B
        SUB     C
        CP      RowCount
        RET     NC
        CP      E
        RET     NZ
        JP      RendPlyBack
