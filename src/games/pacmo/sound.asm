; Pacmo-local sound engine and event cues.
; These routines are generic enough to promote later, but remain local while
; Pacmo and TETRO are being harmonised carefully.

; SOUND_START
; Input:
;   A = duration in scan ticks
;   C = divider reload / half-period
; Output:
;   speaker state machine restarted
; Clobbers:
;   A
SOUND_START:
        LD      (SOUND_TIMER),A
        LD      A,C
        LD      (SOUND_DIVIDER_RELOAD),A
        LD      (SOUND_DIVIDER_COUNT),A
        XOR     A
        LD      (SPEAKER_PORT_STATE),A
        RET

; PACMO_SOUND_POWER
; Input:
;   none
; Output:
;   starts the Pacmo power-pill eaten sound cue
; Clobbers:
;   A, C
PACMO_SOUND_POWER:
        LD      A,PACMO_SOUND_POWER_LEN
        LD      C,PACMO_SOUND_POWER_DIV
        JP      SOUND_START

; PACMO_SOUND_EAT_ENEMY
; Input:
;   none
; Output:
;   starts the Pacmo fleeing-enemy eaten sound cue
; Clobbers:
;   A, C
PACMO_SOUND_EAT_ENEMY:
        LD      A,PACMO_SOUND_EAT_ENEMY_LEN
        LD      C,PACMO_SOUND_EAT_ENEMY_DIV
        JP      SOUND_START

; PACMO_SOUND_CAUGHT
; Input:
;   none
; Output:
;   starts the longer Pacmo caught/game-over sound cue
; Clobbers:
;   A, C
PACMO_SOUND_CAUGHT:
        LD      A,PACMO_SOUND_CAUGHT_LEN
        LD      C,PACMO_SOUND_CAUGHT_DIV
        JP      SOUND_START

; PACMO_SOUND_LEVEL_COMPLETE
; Input:
;   none
; Output:
;   starts the Pacmo level-complete sound cue
; Clobbers:
;   A, C
PACMO_SOUND_LEVEL_COMPLETE:
        LD      A,PACMO_SOUND_LEVEL_COMPLETE_LEN
        LD      C,PACMO_SOUND_LEVEL_COMPLETE_DIV
        JP      SOUND_START

; SERVICE_SOUND
; Input:
;   SOUND_TIMER / SOUND_DIVIDER_RELOAD / SOUND_DIVIDER_COUNT
; Output:
;   SPEAKER_PORT_STATE toggled while the active Pacmo sound cue is running
; Clobbers:
;   A
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
