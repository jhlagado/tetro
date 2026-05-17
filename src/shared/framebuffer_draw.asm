; MATRIX_X_TO_MASK
; @in A matrix x coordinate, expected 0..7.
; @out A a bit mask with column 0 as MSB.
; @clobbers B,C while shifting.
MATRIX_X_TO_MASK:
        LD      C,A
        OR      A
        LD      A,0x80
        JR      Z,MATRIX_X_TO_MASK_DONE
        LD      B,C
MATRIX_X_TO_MASK_LOOP:
        SRL     A
        DJNZ    MATRIX_X_TO_MASK_LOOP
MATRIX_X_TO_MASK_DONE:
        RET

; FB_SET_CELL_COLOR
; @in HL red plane byte for the target row.
; @in C target cell bit mask.
; @in A COLOR_* bitfield.
; @out HL blue plane byte for the target row.
; Target cell set to the requested color, replacing previous RGB bits.
; @clobbers A,B,D,HL.
FB_SET_CELL_COLOR:
        LD      B,A
        LD      A,C
        CPL
        LD      D,A
        LD      A,B
        AND     COLOR_RED
        JR      Z,FB_SET_CELL_RED_OFF
        LD      A,(HL)
        OR      C
        JR      FB_SET_CELL_RED_STORE
FB_SET_CELL_RED_OFF:
        LD      A,(HL)
        AND     D
FB_SET_CELL_RED_STORE:
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     COLOR_GREEN
        JR      Z,FB_SET_CELL_GREEN_OFF
        LD      A,(HL)
        OR      C
        JR      FB_SET_CELL_GREEN_STORE
FB_SET_CELL_GREEN_OFF:
        LD      A,(HL)
        AND     D
FB_SET_CELL_GREEN_STORE:
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     COLOR_BLUE
        JR      Z,FB_SET_CELL_BLUE_OFF
        LD      A,(HL)
        OR      C
        JR      FB_SET_CELL_BLUE_STORE
FB_SET_CELL_BLUE_OFF:
        LD      A,(HL)
        AND     D
FB_SET_CELL_BLUE_STORE:
        LD      (HL),A
        RET

; FB_OR_ROW_COLOR_MASK
; @in HL framebuffer row red-byte address.
; @in C row mask.
; @in A COLOR_* bitfield.
; ORs the mask into enabled red, green, and blue bytes.
; @out HL the blue-byte address.
; @clobbers A while applying colour planes.
FB_OR_ROW_COLOR_MASK:
        PUSH    BC
        LD      B,3                     ; 3 planes: R, G, B
FB_OR_ROW_COLOR_MASK_LOOP:
        RRCA                            ; low bit (red/green/blue per iter) -> carry
        JR      NC,FB_OR_ROW_COLOR_MASK_SKIP
        PUSH    AF
        LD      A,(HL)
        OR      C
        LD      (HL),A
        POP     AF
FB_OR_ROW_COLOR_MASK_SKIP:
        DEC     B
        JR      Z,FB_OR_ROW_COLOR_MASK_EXIT
        INC     HL                      ; advance to next plane byte (between iters only)
        JR      FB_OR_ROW_COLOR_MASK_LOOP
FB_OR_ROW_COLOR_MASK_EXIT:
        POP     BC
        RET
