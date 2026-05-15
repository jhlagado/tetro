; Pacmo-local score formatting helpers. Seven-segment scan helpers live in
; shared/hud.asm.

; UPDATE_SCORE_DISPLAY
; Input:
;   PACMO_SCORE
; Output:
;   HUD_SEG_BUFFER updated with a six-digit decimal score display
; Clobbers:
;   A, BC, DE, HL
UPDATE_SCORE_DISPLAY:
        LD      HL,(PACMO_SCORE)
        JP      HUD_WRITE_U16_DECIMAL
