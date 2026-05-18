; Poll MON-3 keypad state and update PlayerX at a controlled rate.
;
; scanKeys return contract:
;   Z  = key is pressed
;   C  = new key press
;   NZ = no key / invalid key
;   A  = key code
; PollInput
; Input:
;   none
; Output:
;   may update PlayerX / MoveCooldown / LastKey / SoftDrop via keyed handlers, or JR to ClearInputRpt when no key is pressed (idle / repeat reset path).
; Clobbers:
;   A, BC, DE, HL (rotate/soft-drop paths cascade through LoadCurRot / LockActPiece)
PollInput:
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

; ClearInputRpt
; Restores MoveCooldown full period, clears LastKey and soft-drop latch.
; Used when leaving held-autorepeat path (invalid/no key, pause, rotate presses, etc.).
; Input:
;   none
; Output:
;   MoveCooldown = MovePeriod; LastKey = NoKey; DropLockout = 0
; Clobbers:
;   A
ClearInputRpt:
        LD      A,MovePeriod
        LD      (MoveCooldown),A
        LD      A,NoKey
        LD      (LastKey),A
        XOR     A
        LD      (DropLockout),A
        RET

; WaitGOverGate
; Count down main-loop iterations before PollGOverRestart (PRESS ANY KEY) during GameOver.
; Chirps SndTrigReady exactly when the counter reaches zero.
; Input:
;   GOverKeyGateLo/HI
; Output:
;   GOverKeyGateLo decremented; tail-calls PollGOverRestart once gate = 0
; Clobbers:
;   A, C, HL
WaitGOverGate:
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

; PollGOverRestart
; Input:
;   none
; Output:
;   restarts the game on a fresh key press
; Clobbers:
;   A, C
PollGOverRestart:
        LD      C,ApiScanKeys
        RST     0x10
        RET     NC
        JP      InitRestart

; WaitKeyRelease
; Input:
;   InputLockout
; Output:
;   clears InputLockout once no key is pressed
; Clobbers:
;   A, C
WaitKeyRelease:
        LD      C,ApiScanKeys
        RST     0x10
        RET     Z
        XOR     A
        LD      (InputLockout),A
        RET

; HandlePauseKey
; Toggles Paused; swaps LCD between RUNNING/Paused banner.
; Clobbers:
;   A
HandlePauseKey:
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

; HandleUnpause
; Clears Paused, restores RUNNING banner.
; Clobbers:
;   A
HandleUnpause:
        XOR     A
        LD      (Paused),A
        CALL    LcdShowRunning
        JP      ClearInputRpt

; HandleRotPress
; Keyboard dispatch for clockwise rotation with collision check.
; Clobbers:
;   A, C, DE, HL
HandleRotPress:
        CALL    RotateCw
        JP      ClearInputRpt

; HandleCcwPress
; Keyboard dispatch for counter-clockwise rotation with collision check.
; Clobbers:
;   A, C, DE, HL
HandleCcwPress:
        CALL    RotateLeft
        JP      ClearInputRpt

; HandleKeyRight
; Tail-calls HandleHeldDir with A = KeyRight.
; Clobbers:
;   A, DE
HandleKeyRight:
        LD      A,KeyRight
        JP      HandleHeldDir

; HandleKeyLeft
; Tail-calls HandleHeldDir with A = KeyLeft.
; Clobbers:
;   A, DE
HandleKeyLeft:
        LD      A,KeyLeft
        JP      HandleHeldDir

; HandleKeyDrop
; Input:
;   none (DropLockout gates repeat firing)
; Output:
;   tail-calls HandleHeldDir with A = KeyDrop once lockout clears
; Clobbers:
;   A, DE
HandleKeyDrop:
        LD      A,(DropLockout)
        OR      A
        RET     NZ
        LD      A,KeyDrop
        JP      HandleHeldDir

; HandleHeldDir
; Input:
;   A = KeyLeft, KeyRight, or KeyDrop (held/repeat timing path via LastKey/MoveCooldown)
; Output:
;   may update PlayerX / PlayerY / MoveCooldown / LastKey
; Clobbers:
;   A, DE on MoveLeft/RIGHT; A, BC, DE, HL on SoftDrop lock-path
HandleHeldDir:
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
