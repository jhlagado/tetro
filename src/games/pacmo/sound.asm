; Pacmo-local sound event cues. Generic speaker service lives in shared/sound.asm.

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
