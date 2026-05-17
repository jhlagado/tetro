; Run one slice of logic per main-loop pass (1 slice per scanline, 0..7 then wrap).
; Distributes work so each inter-row interval is similar, helping even brightness/POV.
; LOGIC_TICK
; Uses LOGIC_SLICE from RAM.
; One logic slice executed, LOGIC_SLICE advanced.
; @clobbers A,BC,DE,HL while dispatching the current logic slice.
LOGIC_TICK:
        CALL    SANITIZE_ACTIVE_POSITION
        LD      A,(GAME_OVER)
        OR      A
        JR      Z,LOGIC_TICK_GAME_OVER_DONE
        CALL    WAIT_GAME_OVER_KEY_GATE
        RET
LOGIC_TICK_GAME_OVER_DONE:
        LD      A,(SPLASH_TIMER)
        OR      A
        JR      Z,LOGIC_TICK_SPLASH_DONE
        CALL    HANDLE_SPLASH_STATE
        RET
LOGIC_TICK_SPLASH_DONE:
        LD      A,(CLEAR_PENDING)
        OR      A
        JR      Z,LOGIC_TICK_CLEAR_DONE
        CALL    HANDLE_LINE_CLEAR_STATE
        JR      LOGIC_TICK_ACTIVE
LOGIC_TICK_CLEAR_DONE:
        LD      A,(PAUSED)
        OR      A
        JR      Z,LOGIC_TICK_ACTIVE
        CALL    POLL_INPUT_AND_UPDATE
        RET
LOGIC_TICK_ACTIVE:
        LD      A,(INPUT_LOCKOUT)
        OR      A
        JR      Z,LOGIC_TICK_LOCKOUT_DONE
        CALL    WAIT_FOR_KEY_RELEASE
        RET
LOGIC_TICK_LOCKOUT_DONE:
        LD      A,(LOGIC_SLICE)
        AND     7
        JR      Z,LOGIC_SL0
        CP      1
        JR      Z,LOGIC_SL1
        CP      7
        JP      Z,LOGIC_SL7
        SUB     2
        ADD     A,A
        ADD     A,A
        ADD     A,8
        CALL    CLEAR_BACK_4
        JR      LOGIC_SLICE_NEXT
; --- slice 7: final 4B clear, render to back buffer, copy to live framebuffer
LOGIC_SL7:
        LD      A,28
        CALL    CLEAR_BACK_4
        CALL    RENDER_BOARD_TO_BACK
        CALL    RENDER_ACTIVE_TO_BACK
        CALL    COPY_BACK_TO_FRONT
        JR      LOGIC_SLICE_NEXT

LOGIC_SL0:
        LD      A,(CLEAR_PENDING)
        OR      A
        JR      NZ,LOGIC_SL0_NO_INPUT
        CALL    POLL_INPUT_AND_UPDATE
LOGIC_SL0_NO_INPUT:
        XOR     A
        CALL    CLEAR_BACK_4
        JR      LOGIC_SLICE_NEXT

LOGIC_SL1:
        LD      A,(CLEAR_PENDING)
        OR      A
        JR      NZ,LOGIC_SL1_NO_GRAVITY
        CALL    APPLY_GRAVITY
LOGIC_SL1_NO_GRAVITY:
        LD      A,4
        CALL    CLEAR_BACK_4
        JR      LOGIC_SLICE_NEXT

LOGIC_SLICE_NEXT:
        LD      HL,LOGIC_SLICE
        LD      A,(HL)
        INC     A
        AND     7
        LD      (HL),A
        RET
