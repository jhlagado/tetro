; MATRIX_X_TO_MASK
; Accepts @in A as matrix x coordinate, expected 0..7.
; Returns @out A as a bit mask with column 0 as MSB.
; Uses @clobbers B,C,F while shifting.
; Keeps @preserves DE,HL stable for the caller.
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
; Input:
;   HL = red plane byte for the target row
;   C  = target cell bit mask
;   A  = COLOR_* bitfield
; Output:
;   target cell set to the requested color, replacing previous RGB bits
;   HL = blue plane byte for the target row
; Clobbers:
;   A, B, D, HL
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
; Accepts @in HL as framebuffer row red-byte address.
; Accepts @in C as row mask.
; Accepts @in A as COLOR_* bitfield.
;   mask ORed into enabled red, green, blue bytes
; Returns @out HL as the blue-byte address.
; Uses @clobbers A,F while applying colour planes.
; Keeps @preserves BC,DE stable for the caller.
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
