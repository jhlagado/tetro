; INIT_STATE
; Input:
;   none
; Output:
;   initializes Pacmo cursor, viewport, scan state, display buffers, and HUD
; Clobbers:
;   A, BC, DE, HL
INIT_STATE:
        LD      A,7
        LD      (PLAYER_X),A
        LD      (PLAYER_Y),A

        LD      A,3
        LD      (VIEW_X),A
        LD      (VIEW_Y),A

        LD      A,PACMO_MOVE_PERIOD
        LD      (MOVE_COOLDOWN),A
        LD      A,NO_KEY
        LD      (LAST_KEY),A

        XOR     A
        LD      (LOGIC_SLICE),A
        LD      (FRAME_PHASE),A
        LD      (HUD_SCAN_INDEX),A
        LD      (SPEAKER_PORT_STATE),A
        LD      (SOUND_TIMER),A

        LD      A,SCAN_MASK_START
        LD      (SCAN_MASK),A
        LD      HL,FRAMEBUFFER
        LD      (SCAN_PTR),HL

        CALL    CLEAR_FRONT_AND_BACK
        CALL    BLANK_HUD_SCORE_DIGITS
        JP      REBUILD_FRAMEBUFFER

; CLEAR_FRONT_AND_BACK
; Input:
;   none
; Output:
;   FRAMEBUFFER and FRAMEBUFFER_BACK cleared to zero
; Clobbers:
;   A, B, HL
CLEAR_FRONT_AND_BACK:
        LD      HL,FRAMEBUFFER
        LD      B,FRAMEBUFFER_BYTES*2
        XOR     A
CLEAR_FRONT_AND_BACK_LOOP:
        LD      (HL),A
        INC     HL
        DJNZ    CLEAR_FRONT_AND_BACK_LOOP
        RET
