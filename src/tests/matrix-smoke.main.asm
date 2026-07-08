; TEC-1G 8x8 matrix smoke test.
; Holds one red LED on without MON-3 input,
; framebuffer logic, HUD, sound, scan timing, or stack.

        .org     0x4000

        .include "../shared/constants.asm"

@Start:
        XOR     A
        OUT     (PortRow),A
        OUT     (PortGreen),A
        OUT     (PortBlue),A

        LD      A,0x80
        OUT     (PortRed),A

        LD      A,ScanMaskStart
        OUT     (PortRow),A

Hold:
        JR      Hold
