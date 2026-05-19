; UpdScoreDisplay —
; Format the current Score into HudSegBuffer.
; ScoreLo/Hi is passed to HudWriteU16 in HL.
; ========================== AZM
; out       BC,HL
; clobbers  A,DE
; ========================== AZM
@UpdScoreDisplay:
        LD      HL,(ScoreLo)
        JP      HudWriteU16
