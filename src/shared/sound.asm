; Generic speaker divider state machine.
; Game-local sound event wrappers load
; duration and divider values then tail-call
; SndStart.

; SndStart —
; (Re)start a sound cue.
; Duration is in scan ticks; smaller divider C
; means a shorter half-period (higher pitch).
; Resets SpeakerPort to off before the new cue.
; ========================== AZM
; in        A,C
; out       carry,zero
; clobbers  A
; ========================== AZM
@SndStart:
        LD      (SoundTimer),A
        LD      A,C
        LD      (SndDivReload),A
        LD      (SndDivCount),A
        XOR     A
        LD      (SpeakerPort),A
        RET

; SndService —
; Tick the speaker state machine once per scan.
; Decrements SoundTimer; silences when it hits
; zero. While active, counts SndDivCount down
; and toggles SpeakerBit on each reload.
; ========================== AZM
; out       carry,zero
; clobbers  A
; ========================== AZM
@SndService:
        LD      A,(SoundTimer)
        OR      A
        RET     Z
        DEC     A
        LD      (SoundTimer),A
        JR      NZ,SndActive
        XOR     A
        LD      (SpeakerPort),A
        LD      (SndDivCount),A
        RET
SndActive:
        LD      A,(SndDivCount)
        DEC     A
        LD      (SndDivCount),A
        RET     NZ
        LD      A,(SndDivReload)
        LD      (SndDivCount),A
        LD      A,(SpeakerPort)
        XOR     SpeakerBit
        LD      (SpeakerPort),A
        RET
