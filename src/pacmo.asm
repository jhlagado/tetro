; TEC-1G pacmo
; ------------------
; First Pacmo experiment: a yellow cursor moving through an 8x8 viewport
; over a larger 15x15 bitmap world.  This target is intentionally separate
; from TETRO so the finished TETRO game remains stable while Pacmo evolves.
; SPDX-License-Identifier: 0BSD

        ORG     0x4000

        .include "shared/inc/constants.asm"

START:
        CALL    INIT_STATE

MAIN_LOOP:
        CALL    SCAN_TICK
        CALL    LOGIC_TICK
        JR      MAIN_LOOP

        .include "shared/scan_tick.asm"
        .include "games/pacmo/game_init.asm"
        .include "games/pacmo/logic_dispatch.asm"
        .include "games/pacmo/movement.asm"
        .include "games/pacmo/render.asm"
        .include "games/pacmo/ui.asm"
        .include "games/pacmo/data.asm"
        .include "games/pacmo/ram.asm"
