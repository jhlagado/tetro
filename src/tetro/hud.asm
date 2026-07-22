; UpdScoreDisplay —
; Format the current Score into HudSegBuffer.
; ScoreLo/Hi is passed to HudWriteU16 in HL.
.routine out BC,HL clobbers A,DE,F
UpdScoreDisplay:
        LD      HL,(ScoreLo)
        JP      HudWriteU16
