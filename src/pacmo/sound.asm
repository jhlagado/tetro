; Pacmo-local sound event cues. Generic speaker service lives in shared/sound.asm.

; PacSndPower
; Input:
;   none
; Output:
;   starts the Pacmo power-pill eaten sound cue
; Clobbers:
;   A, C
PacSndPower:
        LD      A,PacSndPowerLen
        LD      C,PacSndPowerDiv
        JP      SndStart

; PacSndEatEnemy
; Input:
;   none
; Output:
;   starts the Pacmo fleeing-enemy eaten sound cue
; Clobbers:
;   A, C
PacSndEatEnemy:
        LD      A,PacSndEatEnLen
        LD      C,PacSndEatEnDiv
        JP      SndStart

; PacSndCaught
; Input:
;   none
; Output:
;   starts the longer Pacmo caught/game-over sound cue
; Clobbers:
;   A, C
PacSndCaught:
        LD      A,PacSndCaughtLen
        LD      C,PacSndCaughtDiv
        JP      SndStart

; PacSndLvlDone
; Input:
;   none
; Output:
;   starts the Pacmo level-complete sound cue
; Clobbers:
;   A, C
PacSndLvlDone:
        LD      A,PacSndDoneLen
        LD      C,PacSndDoneDiv
        JP      SndStart
