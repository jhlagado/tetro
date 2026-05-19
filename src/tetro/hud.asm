; UpdScoreDisplay —
; Format the current Score into HudSegBuffer.
; Tail-calls HudWriteU16 with ScoreLo as HL (JP).
; ========================== AZM
; out       BC,HL
; clobbers  A,DE
; ========================== AZM
@UpdScoreDisplay:
        LD      HL,(ScoreLo)
        JP      HudWriteU16
