; Tetro cooperative logic dispatcher.

; LogicTick —
; Run one logic slice per main-loop pass.
; Every slice copies, clears, and rebuilds one
; FramebufferBack row. This keeps scanline dwell
; much more even than doing a full render/copy on
; one slice.
; Slice 0 also polls input before row work.
; Slice 1 also applies gravity before row work.
; LogicSlice wraps 0..7 at the end of each call.
;!      out       carry,zero
;!      clobbers  A,BC,DE,HL,IX,IY
@LogicTick:
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
        JR      LogicRowWork

LogicSl0:
        LD      A,(ClearPending)
        OR      A
        JR      NZ,LogicSl0NoInput
        CALL    PollInput
LogicSl0NoInput:
        JR      LogicRowWork

LogicSl1:
        LD      A,(ClearPending)
        OR      A
        JR      NZ,LogicSl1NoGrav
        CALL    ApplyGravity
LogicSl1NoGrav:
        JR      LogicRowWork

; LogicRowWork —
; Copy the row completed on the previous pass,
; then rebuild that same back-buffer row for the
; next frame.
;!      clobbers  A,BC,DE,HL
LogicRowWork:
        LD      A,(LogicSlice)
        AND     7
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
        CALL    RendBoardRowBack
        POP     AF
        CALL    RendActRowBack
        JR      LogicSliceNext

LogicSliceNext:
        LD      HL,LogicSlice
        LD      A,(HL)
        INC     A
        AND     7
        LD      (HL),A
        RET
