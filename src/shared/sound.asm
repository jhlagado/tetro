; Generic speaker divider state machine.
; Game-local sound event wrappers set duration/divider values and tail-call
; SndStart.

; SndStart
; Input:
;   A = duration in scan ticks
;   C = divider reload / half-period
; Output:
;   speaker state machine restarted
; Clobbers:
;   A
; Accepts @in A as duration in scan ticks.
; Accepts @in C as divider reload / half-period.
; Uses @clobbers A,F while restarting the state machine.
; Keeps @preserves BC,DE,HL,IX,IY stable for the caller.
SndStart:
        LD      (SoundTimer),A
        LD      A,C
        LD      (SndDivReload),A
        LD      (SndDivCount),A
        XOR     A
        LD      (SpeakerPort),A
        RET

; SndService
; Input:
;   SoundTimer / SndDivReload / SndDivCount
; Output:
;   SpeakerPort toggled while the active sound cue is running
; Clobbers:
;   A
; Uses @clobbers A,F while updating the active sound cue.
; Keeps @preserves BC,DE,HL,IX,IY stable for the caller.
SndService:
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
