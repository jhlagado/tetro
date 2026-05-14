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

; SOUND_TRIGGER_ROTATE
; Input:
;   none
; Output:
;   short rotate buzz started
; Clobbers:
;   A, C
SOUND_TRIGGER_ROTATE:
        LD      A,SOUND_ROTATE_LEN
        LD      C,SOUND_ROTATE_DIV
        JP      SOUND_START

; SOUND_TRIGGER_LOCK
; Input:
;   none
; Output:
;   short lock buzz started
; Clobbers:
;   A, C
SOUND_TRIGGER_LOCK:
        LD      A,SOUND_LOCK_LEN
        LD      C,SOUND_LOCK_DIV
        JP      SOUND_START

; SOUND_TRIGGER_CLEAR
; Input:
;   none
; Output:
;   line-clear buzz started
; Clobbers:
;   A, C
SOUND_TRIGGER_CLEAR:
        LD      A,SOUND_CLEAR_LEN
        LD      C,SOUND_CLEAR_DIV
        JP      SOUND_START

; SOUND_TRIGGER_GAME_OVER
; Input:
;   none
; Output:
;   game-over buzz started
; Clobbers:
;   A, C
SOUND_TRIGGER_GAME_OVER:
        LD      A,SOUND_GAME_OVER_LEN
        LD      C,SOUND_GAME_OVER_DIV
        JP      SOUND_START

; SOUND_TRIGGER_GAME_OVER_RESTART_READY
; Input:
;   none
; Output:
;   short chirp once key-delay finishes (speaker restarts PWM)
; Clobbers:
;   A, C
SOUND_TRIGGER_GAME_OVER_RESTART_READY:
        LD      A,SOUND_GAME_OVER_READY_LEN
        LD      C,SOUND_GAME_OVER_READY_DIV
        JP      SOUND_START

; SERVICE_SOUND
; Input:
;   SOUND_TIMER / SOUND_DIVIDER_RELOAD / SOUND_DIVIDER_COUNT
; Output:
;   SPEAKER_PORT_STATE updated for current scan pass
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
