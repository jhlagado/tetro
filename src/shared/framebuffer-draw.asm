; MxMask —
; Produce a column bitmask for matrix column A and
; return the mask in A.
; Column 0 is bit 7 (MSB); column 7 is bit 0.
.routine in A out A clobbers BC,F
MxMask:
        LD      C,A
        OR      A
        LD      A,0x80
        JR      Z,_MxMaskDone
        LD      B,C
_MxMaskLp:
        SRL     A
        DJNZ    _MxMaskLp
_MxMaskDone:
        RET

; FbSetCell —
; Set or clear one column bit across the R/G/B
; plane bytes for a single row.
; HL points to the row's red plane byte. C is the
; column mask. Low bits of A select colour planes:
; selected planes OR in C; absent planes clear C with
; AND CPL(C).
.routine in C,A,HL clobbers A,B,HL,D,F
FbSetCell:
        LD      B,A
        LD      A,C
        CPL
        LD      D,A
        LD      A,B
        AND     ColorRed
        JR      Z,_FbRedOff
        LD      A,(HL)
        OR      C
        JR      _FbRedSet
_FbRedOff:
        LD      A,(HL)
        AND     D
_FbRedSet:
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     ColorGreen
        JR      Z,_FbGrnOff
        LD      A,(HL)
        OR      C
        JR      _FbGrnSet
_FbGrnOff:
        LD      A,(HL)
        AND     D
_FbGrnSet:
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     ColorBlue
        JR      Z,_FbBluOff
        LD      A,(HL)
        OR      C
        JR      _FbBluSet
_FbBluOff:
        LD      A,(HL)
        AND     D
_FbBluSet:
        LD      (HL),A
        RET

; FbOrRow —
; OR column mask C into selected R/G/B planes.
; Low 3 bits of A select planes: bit 0 = red,
; bit 1 = green, bit 2 = blue (RRCA each iter).
; HL points to the row's red plane byte. The final
; plane pointer is returned in HL.
.routine in A,HL,C out A,HL clobbers F
FbOrRow:
        PUSH    BC
        LD      B,3                     ; 3 planes: R, G, B
_FbOrLoop:
        RRCA                            ; low bit (red/green/blue per iter) -> carry
        JR      NC,_FbOrSkip
        PUSH    AF
        LD      A,(HL)
        OR      C
        LD      (HL),A
        POP     AF
_FbOrSkip:
        DEC     B
        JR      Z,_FbOrExit
        INC     HL                      ; advance to next plane byte (between iters only)
        JR      _FbOrLoop
_FbOrExit:
        POP     BC
        RET
