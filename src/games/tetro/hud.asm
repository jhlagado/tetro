; UPDATE_SCORE_DISPLAY
; SCORE_LO / SCORE_HI.
; HUD_SEG_BUFFER updated with a six-digit score display.
; @clobbers A,BC,DE,HL.
UPDATE_SCORE_DISPLAY:
        LD      HL,(SCORE_LO)
        JP      HUD_WRITE_U16_DECIMAL
