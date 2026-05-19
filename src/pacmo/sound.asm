; Pacmo-local sound event cues.
; Generic speaker service lives in shared/sound.asm.

; PacSndPower —
; Start the power-pill pickup sound cue.
; Loads the Pacmo cue length/divider and delegates to
; SndStart. Flags are inherited from that helper.
; ========================== AZM
; out       carry,zero
; clobbers  A,C
; ========================== AZM
@PacSndPower:
        LD      A,PacSndPowerLen
        LD      C,PacSndPowerDiv
        JP      SndStart

; PacSndEatEnemy —
; Start the fleeing-enemy eaten sound cue.
; Loads the Pacmo cue length/divider and delegates to
; SndStart. Flags are inherited from that helper.
; ========================== AZM
; out       carry,zero
; clobbers  A,C
; ========================== AZM
@PacSndEatEnemy:
        LD      A,PacSndEatEnLen
        LD      C,PacSndEatEnDiv
        JP      SndStart

; PacSndCaught —
; Start the caught/game-over sound cue.
; Loads the Pacmo cue length/divider and delegates to
; SndStart. Flags are inherited from that helper.
; ========================== AZM
; out       carry,zero
; clobbers  A,C
; ========================== AZM
@PacSndCaught:
        LD      A,PacSndCaughtLen
        LD      C,PacSndCaughtDiv
        JP      SndStart

; PacSndLvlDone —
; Start the level-complete sound cue.
; Loads the Pacmo cue length/divider and delegates to
; SndStart. Flags are inherited from that helper.
; ========================== AZM
; out       carry,zero
; clobbers  A,C
; ========================== AZM
@PacSndLvlDone:
        LD      A,PacSndDoneLen
        LD      C,PacSndDoneDiv
        JP      SndStart
