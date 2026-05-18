; SndTrigRotate —
; Start the short rotate-key sound cue.
; ========================== AZM
; clobbers  A,C
; ========================== AZM
SndTrigRotate:
        LD      A,SoundRotateLen
        LD      C,SoundRotateDiv
        JP      SndStart

; SndTrigLock —
; Start the short piece-lock sound cue.
; ========================== AZM
; clobbers  A,C
; ========================== AZM
SndTrigLock:
        LD      A,SoundLockLen
        LD      C,SoundLockDiv
        JP      SndStart

; SndTrigClear —
; Start the line-clear sound cue.
; ========================== AZM
; clobbers  A,C
; ========================== AZM
SndTrigClear:
        LD      A,SoundClearLen
        LD      C,SoundClearDiv
        JP      SndStart

; SndTrigGOver —
; Start the game-over sound cue.
; ========================== AZM
; clobbers  A,C
; ========================== AZM
SndTrigGOver:
        LD      A,SndGOverLen
        LD      C,SndGOverDiv
        JP      SndStart

; SndTrigReady —
; Start the short ready-chirp when the game-over
; key-delay expires and input is accepted again.
; ========================== AZM
; clobbers  A,C
; ========================== AZM
SndTrigReady:
        LD      A,SndReadyLen
        LD      C,SndReadyDiv
        JP      SndStart
