; Run one slice of logic per main-loop pass (1 slice per scanline, 0..7 then wrap).
; Distributes work so each inter-row interval is similar, helping even brightness/POV.
; LogicTick
; Input:
;   uses LogicSlice from RAM
; Output:
;   one logic slice executed, LogicSlice advanced
; Clobbers:
;   A, HL, and whatever the called slice routines clobber
LogicTick:
        CALL    SanitizeActPos
        LD      A,(GameOver)
        OR      A
        JR      Z,LogicGOverDone
        CALL    WaitGOverGate
        RET
LogicGOverDone:
        LD      A,(SplashTimer)
        OR      A
        JR      Z,LogicSplashDone
        CALL    SplashState
        RET
LogicSplashDone:
        LD      A,(ClearPending)
        OR      A
        JR      Z,LogicClearDone
        CALL    LineClearState
        JR      LogicActive
LogicClearDone:
        LD      A,(Paused)
        OR      A
        JR      Z,LogicActive
        CALL    PollInput
        RET
LogicActive:
        LD      A,(InputLockout)
        OR      A
        JR      Z,LogicLockDone
        CALL    WaitKeyRelease
        RET
LogicLockDone:
        LD      A,(LogicSlice)
        AND     7
        JR      Z,LogicSl0
        CP      1
        JR      Z,LogicSl1
        CP      7
        JP      Z,LogicSl7
        SUB     2
        ADD     A,A
        ADD     A,A
        ADD     A,8
        CALL    FbClearRow
        JR      LogicSliceNext
; --- slice 7: final 4B clear, render to back buffer, copy to live Framebuffer
LogicSl7:
        LD      A,28
        CALL    FbClearRow
        CALL    RendBoardBack
        CALL    RendActBack
        CALL    FbCopyAll
        JR      LogicSliceNext

LogicSl0:
        LD      A,(ClearPending)
        OR      A
        JR      NZ,LogicSl0NoInput
        CALL    PollInput
LogicSl0NoInput:
        XOR     A
        CALL    FbClearRow
        JR      LogicSliceNext

LogicSl1:
        LD      A,(ClearPending)
        OR      A
        JR      NZ,LogicSl1NoGrav
        CALL    ApplyGravity
LogicSl1NoGrav:
        LD      A,4
        CALL    FbClearRow
        JR      LogicSliceNext

LogicSliceNext:
        LD      HL,LogicSlice
        LD      A,(HL)
        INC     A
        AND     7
        LD      (HL),A
        RET
