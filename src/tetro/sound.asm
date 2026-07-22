; SndTrigRotate —
; Start the short rotate-key sound cue.
.routine out carry,zero clobbers A,C,sign,parity,halfCarry
SndTrigRotate:
        LD      A,SoundRotateLen
        LD      C,SoundRotateDiv
        JP      SndStart

; SndTrigLock —
; Start the short piece-lock sound cue.
.routine out carry,zero clobbers A,C,sign,parity,halfCarry
SndTrigLock:
        LD      A,SoundLockLen
        LD      C,SoundLockDiv
        JP      SndStart

; SndTrigClear —
; Start the line-clear sound cue.
.routine out carry,zero clobbers A,C,sign,parity,halfCarry
SndTrigClear:
        LD      A,SoundClearLen
        LD      C,SoundClearDiv
        JP      SndStart

; SndTrigGOver —
; Start the game-over sound cue.
.routine out carry,zero clobbers A,C,sign,parity,halfCarry
SndTrigGOver:
        LD      A,SndGOverLen
        LD      C,SndGOverDiv
        JP      SndStart

; SndTrigReady —
; Start the short ready-chirp when the game-over
; key-delay expires and input is accepted again.
.routine out carry,zero clobbers A,C,sign,parity,halfCarry
SndTrigReady:
        LD      A,SndReadyLen
        LD      C,SndReadyDiv
        JP      SndStart
