; Pacmo-local Score formatting helpers.
; Seven-segment scan helpers live in
; shared/hud.asm.

; UpdScoreDisplay —
; Format PacScore into HudSegBuffer.
; Tail-calls HudWriteU16 (JP).
; ========================== AZM
; clobbers  A,BC,DE,HL
; ========================== AZM
UpdScoreDisplay:
        LD      HL,(PacScore)
        JP      HudWriteU16
