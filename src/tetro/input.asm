; PollInput —
; Read the keypad and dispatch to action handlers.
; scanKeys return contract:
;   Z  = key held, C = new press, NZ = no key.
; Rotation is edge-triggered (new press only).
; Left, right, and drop repeat via HandleHeldDir.
; Skips movement when paused but still allows
; un-pause via HandleUnpause.
; ========================== AZM
; out       carry,zero
; clobbers  A,BC,DE,HL
; ========================== AZM
@PollInput:
        LD      C,ApiScanKeys
        RST     0x10
        JR      NZ,ClearInputRpt
        LD      E,A
        JR      C,KeyNewPress
        LD      A,E
        CP      KeyPause
        JP      Z,ClearInputRpt
        LD      A,(Paused)
        OR      A
        JR      NZ,ClearInputRpt
        LD      A,E
        CP      KeyRotateCcw
        JR      Z,ClearInputRpt
        CP      KeyRotateCw
        JR      Z,ClearInputRpt
        JR      HandleDirKey

KeyNewPress:
        LD      A,(Paused)
        OR      A
        JP      NZ,HandleUnpause
        LD      A,E
        CP      KeyPause
        JP      Z,HandlePauseKey
        LD      A,E
        CP      KeyRotate
        JP      Z,HandleKeyDrop
        CP      KeyRotateCcw
        JP      Z,HandleCcwPress
        CP      KeyRotateCw
        JP      Z,HandleRotPress
        CP      TetKeyRotAlt
        JP      Z,HandleRotPress
        ; fall through

HandleDirKey:
        LD      A,E
        CP      KeyRight
        JP      Z,HandleKeyRight
        CP      TetKeyRightAlt
        JP      Z,HandleKeyRight
        CP      KeyLeft
        JP      Z,HandleKeyLeft
        CP      TetKeyLeftAlt
        JP      Z,HandleKeyLeft
        CP      KeyRotate
        JP      Z,HandleKeyDrop
        CP      KeyDrop
        JP      Z,HandleKeyDrop
        CP      TetKeyDropAlt
        JP      Z,HandleKeyDrop

; ClearInputRpt —
; Reset repeat state after a non-repeating event.
; Restores MoveCooldown to MovePeriod and clears
; both LastKey and DropLockout.
; ========================== AZM
; out       carry,zero
; clobbers  A
; ========================== AZM
@ClearInputRpt:
        LD      A,MovePeriod
        LD      (MoveCooldown),A
        LD      A,NoKey
        LD      (LastKey),A
        XOR     A
        LD      (DropLockout),A
        RET

; WaitGOverGate —
; Enforce a delay before accepting restart input.
; Counts down the 16-bit GOverKeyGateLo counter.
; Fires SndTrigReady exactly once when it reaches
; zero, then falls through to PollGOverRestart.
; ========================== AZM
; out       carry,zero
; clobbers  A,BC,DE,HL
; ========================== AZM
@WaitGOverGate:
        LD      HL,(GOverKeyGateLo)
        LD      A,H
        OR      L
        JP      Z,PollGOverRestart

        DEC     HL
        LD      (GOverKeyGateLo),HL
        LD      A,H
        OR      L
        RET     NZ

        CALL    SndTrigReady
        RET

; PollGOverRestart —
; Poll for a key press after game-over.
; A fresh key press (carry set) tail-calls
; InitRestart (JP).
; ========================== AZM
; clobbers  A,BC,DE,HL
; ========================== AZM
@PollGOverRestart:
        LD      C,ApiScanKeys
        RST     0x10
        RET     NC
        JP      InitRestart

; WaitKeyRelease —
; Clear InputLockout once no key is being held.
; Prevents accidental input at spawn and start.
; ========================== AZM
; out       carry,zero
; clobbers  A,BC,DE,HL
; ========================== AZM
@WaitKeyRelease:
        LD      C,ApiScanKeys
        RST     0x10
        RET     Z
        XOR     A
        LD      (InputLockout),A
        RET

; HandlePauseKey —
; Toggle pause state and update the LCD banner.
; Tail-calls ClearInputRpt (JP) when done.
; ========================== AZM
; out       HL,carry,zero
; clobbers  A
; ========================== AZM
@HandlePauseKey:
        LD      A,(Paused)
        XOR     1
        LD      (Paused),A
        OR      A
        JR      Z,PauseShowRun
        CALL    LcdShowPaused
        JP      ClearInputRpt
PauseShowRun:
        CALL    LcdShowRunning
        JP      ClearInputRpt

; HandleUnpause —
; Clear pause and restore the running LCD banner.
; Tail-calls ClearInputRpt (JP).
; ========================== AZM
; out       HL,carry,zero
; clobbers  A
; ========================== AZM
@HandleUnpause:
        XOR     A
        LD      (Paused),A
        CALL    LcdShowRunning
        JP      ClearInputRpt

; HandleRotPress —
; Dispatch clockwise rotation (CW).
; Calls RotateCw then tail-calls ClearInputRpt.
; ========================== AZM
; out       carry,zero
; clobbers  A,C,DE,HL
; ========================== AZM
@HandleRotPress:
        CALL    RotateCw
        JP      ClearInputRpt

; HandleCcwPress —
; Dispatch counter-clockwise rotation (CCW).
; Calls RotateLeft then tail-calls ClearInputRpt.
; ========================== AZM
; out       carry,zero
; clobbers  A,C,DE,HL
; ========================== AZM
@HandleCcwPress:
        CALL    RotateLeft
        JP      ClearInputRpt

; HandleKeyRight —
; Load KeyRight into A then tail-call HandleHeldDir.
; ========================== AZM
; out       carry,zero
; clobbers  A,BC,DE,HL
; ========================== AZM
@HandleKeyRight:
        LD      A,KeyRight
        JP      HandleHeldDir

; HandleKeyLeft —
; Load KeyLeft into A then tail-call HandleHeldDir.
; ========================== AZM
; out       carry,zero
; clobbers  A,BC,DE,HL
; ========================== AZM
@HandleKeyLeft:
        LD      A,KeyLeft
        JP      HandleHeldDir

; HandleKeyDrop —
; Gate soft-drop on DropLockout then dispatch.
; DropLockout prevents repeated locking on a held
; drop key; clears when ClearInputRpt is called.
; ========================== AZM
; out       carry,zero
; clobbers  A,BC,DE,HL
; ========================== AZM
@HandleKeyDrop:
        LD      A,(DropLockout)
        OR      A
        RET     NZ
        LD      A,KeyDrop
        JP      HandleHeldDir

; HandleHeldDir —
; Manage autorepeat for left, right, and drop.
; First press of a new key fires immediately then
; waits MovePeriod ticks before repeating.
; Drop uses DropPeriod; lateral uses MovePeriod.
; ========================== AZM
; in        A
; out       carry,zero
; clobbers  A,BC,DE,HL
; ========================== AZM
@HandleHeldDir:
        LD      E,A
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

        LD      A,E
        CP      KeyDrop
        JR      NZ,HeldDirNormal
        LD      A,DropPeriod
        JR      HeldDirRateSet
HeldDirNormal:
        LD      A,MovePeriod
HeldDirRateSet:
        LD      (MoveCooldown),A
        LD      A,E
        CP      KeyRight
        JP      Z,MoveRight
        CP      KeyLeft
        JP      Z,MoveLeft
        CP      KeyDrop
        JP      Z,SoftDrop
        RET
