; Tetro cooperative logic dispatcher.

; LogicTick —
; Run one logic slice per main-loop pass.
; Slices 2–6 each clear one FramebufferBack row.
; Slice 0: poll input, clear row 0.
; Slice 1: apply gravity, clear row 4.
; Slice 7: clear row 28, render board and piece,
;   copy back-buffer to live Framebuffer.
; LogicSlice wraps 0..7 at the end of each call.
; ========================== AZM
; out       carry,zero
; clobbers  A,BC,DE,HL
; ========================== AZM
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
        CP      7
        JP      Z,LogicSl7
        SUB     2
        ADD     A,A
        ADD     A,A
        ADD     A,8
        CALL    FbClearRow
        JR      LogicSliceNext

; LogicSl7 —
; Clear row 28, render board and active piece to
; the back-buffer, then copy to live Framebuffer.
; ========================== AZM
; clobbers  A,BC,DE,HL
; ========================== AZM
@LogicSl7:
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
