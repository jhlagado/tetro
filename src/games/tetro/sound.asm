; SOUND_TRIGGER_ROTATE
; Input:
;   none
; Output:
;   short rotate buzz started
; Clobbers:
;   A, C
; Uses @clobbers A,C while starting the rotate sound cue.
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
; Uses @clobbers A,C while starting the lock sound cue.
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
; Uses @clobbers A,C while starting the clear sound cue.
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
