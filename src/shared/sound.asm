; Generic speaker divider state machine.
; Game-local sound event wrappers set duration/divider values and tail-call
; SOUND_START.

; SOUND_START
; @in A duration in scan ticks.
; @in C divider reload / half-period.
; Speaker state machine restarted.
; @clobbers A while restarting the state machine.
SOUND_START:
        LD      (SOUND_TIMER),A
        LD      A,C
        LD      (SOUND_DIVIDER_RELOAD),A
        LD      (SOUND_DIVIDER_COUNT),A
        XOR     A
        LD      (SPEAKER_PORT_STATE),A
        RET

; SERVICE_SOUND
; SOUND_TIMER / SOUND_DIVIDER_RELOAD / SOUND_DIVIDER_COUNT.
; SPEAKER_PORT_STATE toggled while the active sound cue is running.
; @clobbers A while updating the active sound cue.
SERVICE_SOUND:
        LD      A,(SOUND_TIMER)
        OR      A
        RET     Z
        DEC     A
        LD      (SOUND_TIMER),A
        JR      NZ,SERVICE_SOUND_ACTIVE
        XOR     A
        LD      (SPEAKER_PORT_STATE),A
        LD      (SOUND_DIVIDER_COUNT),A
        RET
SERVICE_SOUND_ACTIVE:
        LD      A,(SOUND_DIVIDER_COUNT)
        DEC     A
        LD      (SOUND_DIVIDER_COUNT),A
        RET     NZ
        LD      A,(SOUND_DIVIDER_RELOAD)
        LD      (SOUND_DIVIDER_COUNT),A
        LD      A,(SPEAKER_PORT_STATE)
        XOR     SPEAKER_BIT
        LD      (SPEAKER_PORT_STATE),A
        RET
