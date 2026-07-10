; Tetro frame-time logic dispatcher.

; LogicTick —
; Run one complete game update while the matrix is
; blank between scanned frames. Rendering is rebuilt
; as a full back-buffer pass, then copied to the live
; Framebuffer before the next ScanFrame.
.routine out carry,zero clobbers A,BC,DE,HL,IX,IY
LogicTick:
        CALL    SanitizeActPos
        LD      A,(GameOver)
        OR      A
        JR      Z,_LogicGOverDone
        CALL    WaitGOverGate
        RET

_LogicGOverDone:
        LD      A,(SplashTimer)
        OR      A
        JR      Z,_LogicSplashDone
        CALL    SplashState
        RET

_LogicSplashDone:
        LD      A,(ClearPending)
        OR      A
        JR      Z,_LogicPauseCheck
        CALL    LineClearState
        CALL    RebuildFb
        RET

_LogicPauseCheck:
        LD      A,(Paused)
        OR      A
        JR      Z,_LogicActive
        CALL    PollInput
        RET

_LogicActive:
        LD      A,(InputLockout)
        OR      A
        JR      Z,_LogicRunFrame
        CALL    WaitKeyRelease
        RET

_LogicRunFrame:
        CALL    PollInput
        LD      A,(Paused)
        OR      A
        RET     NZ
        LD      A,(GameOver)
        OR      A
        RET     NZ
        LD      A,(ClearPending)
        OR      A
        JR      NZ,_LogicRenderFrame
        CALL    ApplyGravity
        LD      A,(GameOver)
        OR      A
        RET     NZ

_LogicRenderFrame:
        CALL    RebuildFb
        RET
