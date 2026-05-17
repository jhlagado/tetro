; Full rebuild (used at init). Build in back buffer, then copy to live FB.
; REBUILD_FRAMEBUFFER
; Input:
;   current board and active-piece state in RAM
; Output:
;   FRAMEBUFFER rebuilt from scratch
; Clobbers:
;   A, BC, DE, HL
REBUILD_FRAMEBUFFER:
        CALL    CLEAR_BACK_ALL
        CALL    RENDER_BOARD_TO_BACK
        CALL    RENDER_ACTIVE_TO_BACK
        JP      COPY_BACK_TO_FRONT

; CLEAR_BOARD
; Input:
;   none
; Output:
;   BOARD_ROWS and landed RGB planes cleared to zero
; Clobbers:
;   A, B, HL
CLEAR_BOARD:
        LD      HL,BOARD_ROWS
        LD      B,ROW_COUNT*4
        XOR     A
CLEAR_BOARD_LOOP:
        LD      (HL),A
        INC     HL
        DJNZ    CLEAR_BOARD_LOOP
        LD      A,1
        LD      (BOARD_EMPTY),A
        RET
; RENDER_BOARD_TO_BACK
; Input:
;   BOARD_RED / BOARD_GREEN / BOARD_BLUE / BOARD_ROWS, FRAMEBUFFER_BACK, GAME_OVER
; Output:
;   landed board copied into FRAMEBUFFER_BACK in native RGB, except during GAME_OVER
;   landed cells shown as occupancy on red only (G/B cleared) — uniform red silhouette.
; Clobbers:
;   A
; Uses @clobbers A while copying board state into the back buffer.
; Keeps @preserves BC,DE,HL stable for the caller.
RENDER_BOARD_TO_BACK:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      HL,FRAMEBUFFER_BACK
        LD      B,ROW_COUNT
        LD      C,0
RENDER_BOARD_ROW:
        LD      E,C
        LD      D,0
        LD      A,(GAME_OVER)
        OR      A
        JR      NZ,RENDER_BOARD_GAME_OVER_ROW

        PUSH    HL
        LD      HL,BOARD_RED
        ADD     HL,DE
        LD      A,(HL)
        POP     HL
        LD      (HL),A
        INC     HL

        PUSH    HL
        LD      HL,BOARD_GREEN
        ADD     HL,DE
        LD      A,(HL)
        POP     HL
        LD      (HL),A
        INC     HL

        PUSH    HL
        LD      HL,BOARD_BLUE
        ADD     HL,DE
        LD      A,(HL)
        POP     HL
        LD      (HL),A
        INC     HL
        INC     HL
        JR      RENDER_BOARD_ROW_EFFECTS

RENDER_BOARD_GAME_OVER_ROW:
        PUSH    HL
        LD      HL,BOARD_ROWS
        ADD     HL,DE
        LD      A,(HL)
        POP     HL
        LD      (HL),A
        INC     HL
        XOR     A
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        INC     HL

RENDER_BOARD_ROW_EFFECTS:
        LD      A,(CLEAR_PENDING)
        OR      A
        JR      Z,RENDER_BOARD_ROW_NEXT
        PUSH    HL
        LD      H,0
        LD      L,C
        LD      DE,ROW_BIT_TABLE
        ADD     HL,DE
        LD      A,(CLEAR_MASK)
        AND     (HL)
        POP     HL
        JR      Z,RENDER_BOARD_ROW_NEXT
        DEC     HL
        DEC     HL
        DEC     HL
        DEC     HL
        LD      A,0xFF
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        INC     HL
RENDER_BOARD_ROW_NEXT:
        INC     C
        DJNZ    RENDER_BOARD_ROW
RENDER_BOARD_TO_BACK_EXIT:
        POP     HL
        POP     DE
        POP     BC
        RET

; Draw the active 4x4 bitmap into the back buffer (same layout as live FB).
; RENDER_ACTIVE_TO_BACK
; Input:
;   PLAYER_X, PLAYER_Y, CURRENT_PIECE_PTR, CURRENT_PIECE_COLOR
; Output:
;   active piece ORed into FRAMEBUFFER_BACK in piece colour
; Clobbers:
;   A
; Uses @clobbers A while drawing the active piece.
; Keeps @preserves BC,DE,HL stable for the caller.
RENDER_ACTIVE_TO_BACK:
        LD      A,(ACTIVE_PIECE_ENABLED)
        OR      A
        RET     Z
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A,(PLAYER_X)
        LD      (SHIFT_COUNT),A
        LD      A,(PLAYER_Y)
        LD      L,A
        LD      H,0
        LD      DE,(CURRENT_PIECE_PTR)
        LD      B,4

RENDER_SHAPE_ROW:
        LD      A,(DE)
        CALL    SHIFT_ROW_MASK          ; returns A = shifted mask
        LD      C,A
        OR      A                       ; test A; C retains mask for FB_OR_ROW_COLOR_MASK
        JR      Z,RENDER_SHAPE_NEXT_ROW
        BIT     7,L
        JR      NZ,RENDER_SHAPE_NEXT_ROW
        LD      A,L
        CP      ROW_COUNT
        JR      NC,RENDER_SHAPE_NEXT_ROW
        PUSH    HL
        PUSH    DE
        ADD     A,A
        ADD     A,A
        LD      E,A
        LD      D,0
        LD      HL,FRAMEBUFFER_BACK
        ADD     HL,DE
        LD      A,(CURRENT_PIECE_COLOR)
        CALL    FB_OR_ROW_COLOR_MASK
        POP     DE
        POP     HL
RENDER_SHAPE_NEXT_ROW:
        INC     DE
        INC     HL
        DJNZ    RENDER_SHAPE_ROW
RENDER_ACTIVE_TO_BACK_EXIT:
        POP     HL
        POP     DE
        POP     BC
        RET
