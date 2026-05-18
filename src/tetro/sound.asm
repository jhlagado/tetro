; SndTrigRotate
; Input:
;   none
; Output:
;   short rotate buzz started
; Clobbers:
;   A, C
SndTrigRotate:
        LD      A,SoundRotateLen
        LD      C,SoundRotateDiv
        JP      SndStart

; SndTrigLock
; Input:
;   none
; Output:
;   short lock buzz started
; Clobbers:
;   A, C
SndTrigLock:
        LD      A,SoundLockLen
        LD      C,SoundLockDiv
        JP      SndStart

; SndTrigClear
; Input:
;   none
; Output:
;   line-clear buzz started
; Clobbers:
;   A, C
SndTrigClear:
        LD      A,SoundClearLen
        LD      C,SoundClearDiv
        JP      SndStart

; SndTrigGOver
; Input:
;   none
; Output:
;   game-over buzz started
; Clobbers:
;   A, C
SndTrigGOver:
        LD      A,SndGOverLen
        LD      C,SndGOverDiv
        JP      SndStart

; SndTrigReady
; Input:
;   none
; Output:
;   short chirp once key-delay finishes (speaker restarts PWM)
; Clobbers:
;   A, C
SndTrigReady:
        LD      A,SndReadyLen
        LD      C,SndReadyDiv
        JP      SndStart
