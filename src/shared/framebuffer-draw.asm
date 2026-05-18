; MxMask
; Accepts @in A as matrix x coordinate, expected 0..7.
; Returns @out A as a bit mask with column 0 as MSB.
; Uses @clobbers B,C,F while shifting.
; Keeps @preserves DE,HL stable for the caller.
MxMask:
        LD      C,A
        OR      A
        LD      A,0x80
        JR      Z,MxMaskDone
        LD      B,C
MxMaskLp:
        SRL     A
        DJNZ    MxMaskLp
MxMaskDone:
        RET

; FbSetCell
; Input:
;   HL = red plane byte for the target row
;   C  = target cell bit mask
;   A  = COLOR_* bitfield
; Output:
;   target cell set to the requested color, replacing previous RGB bits
;   HL = blue plane byte for the target row
; Clobbers:
;   A, B, D, HL
FbSetCell:
        LD      B,A
        LD      A,C
        CPL
        LD      D,A
        LD      A,B
        AND     ColorRed
        JR      Z,FbRedOff
        LD      A,(HL)
        OR      C
        JR      FbRedSet
FbRedOff:
        LD      A,(HL)
        AND     D
FbRedSet:
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     ColorGreen
        JR      Z,FbGrnOff
        LD      A,(HL)
        OR      C
        JR      FbGrnSet
FbGrnOff:
        LD      A,(HL)
        AND     D
FbGrnSet:
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     ColorBlue
        JR      Z,FbBluOff
        LD      A,(HL)
        OR      C
        JR      FbBluSet
FbBluOff:
        LD      A,(HL)
        AND     D
FbBluSet:
        LD      (HL),A
        RET

; FbOrRow
; Accepts @in HL as Framebuffer row red-byte address.
; Accepts @in C as row mask.
; Accepts @in A as COLOR_* bitfield.
;   mask ORed into enabled red, green, blue bytes
; Returns @out HL as the blue-byte address.
; Uses @clobbers A,F while applying colour planes.
; Keeps @preserves BC,DE stable for the caller.
FbOrRow:
        PUSH    BC
        LD      B,3                     ; 3 planes: R, G, B
FbOrLoop:
        RRCA                            ; low bit (red/green/blue per iter) -> carry
        JR      NC,FbOrSkip
        PUSH    AF
        LD      A,(HL)
        OR      C
        LD      (HL),A
        POP     AF
FbOrSkip:
        DEC     B
        JR      Z,FbOrExit
        INC     HL                      ; advance to next plane byte (between iters only)
        JR      FbOrLoop
FbOrExit:
        POP     BC
        RET
