; Pacmo-local Score formatting helpers. Seven-segment scan helpers live in
; shared/hud.asm.

; UpdScoreDisplay
; Input:
;   PacScore
; Output:
;   HudSegBuffer updated with a six-digit decimal Score display
; Clobbers:
;   A, BC, DE, HL
UpdScoreDisplay:
        LD      HL,(PacScore)
        JP      HudWriteU16
