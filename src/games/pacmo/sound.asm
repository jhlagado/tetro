; Pacmo-local sound event cues. Generic speaker service lives in shared/sound.asm.

; PACMO_SOUND_POWER
; Starts the Pacmo power-pill eaten sound cue.
; @clobbers A,C while starting the sound cue.
PACMO_SOUND_POWER:
        LD      A,PACMO_SOUND_POWER_LEN
        LD      C,PACMO_SOUND_POWER_DIV
        JP      SOUND_START

; PACMO_SOUND_EAT_ENEMY
; Starts the Pacmo fleeing-enemy eaten sound cue.
; @clobbers A,C while starting the sound cue.
PACMO_SOUND_EAT_ENEMY:
        LD      A,PACMO_SOUND_EAT_ENEMY_LEN
        LD      C,PACMO_SOUND_EAT_ENEMY_DIV
        JP      SOUND_START

; PACMO_SOUND_CAUGHT
; Starts the longer Pacmo caught/game-over sound cue.
; @clobbers A,C while starting the sound cue.
PACMO_SOUND_CAUGHT:
        LD      A,PACMO_SOUND_CAUGHT_LEN
        LD      C,PACMO_SOUND_CAUGHT_DIV
        JP      SOUND_START

; PACMO_SOUND_LEVEL_COMPLETE
; Starts the Pacmo level-complete sound cue.
; @clobbers A,C while starting the sound cue.
PACMO_SOUND_LEVEL_COMPLETE:
        LD      A,PACMO_SOUND_LEVEL_COMPLETE_LEN
        LD      C,PACMO_SOUND_LEVEL_COMPLETE_DIV
        JP      SOUND_START
