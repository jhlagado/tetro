; UpdScoreDisplay
; Input:
;   ScoreLo / ScoreHi
; Output:
;   HudSegBuffer updated with a six-digit Score display
; Clobbers:
;   A, BC, DE, HL
UpdScoreDisplay:
        LD      HL,(ScoreLo)
        JP      HudWriteU16
