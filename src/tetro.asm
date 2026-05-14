; TEC-1G tetro
; ------------------
; John Hardy, 2026. All wrongs reserved.
; Attribution is informational only; no proprietary ownership asserted.
; "Copyleft" in the Tiny Basic hobby sense (sharing listings); not GPL.
; SPDX-License-Identifier: 0BSD (grant text: repository root LICENSE)
;
; Minimal interactive 8x8 RGB matrix example for the MON-3 layout.
;
; Goal:
;   Prove the scanline-tick architecture with the smallest visible program:
;   a 4x4 bitmap shape moved left/right and down by frame-driven gravity while
;   the display is scanned one row at a time, freezing into a landed board on
;   collision and respawning a new active piece.
;
; Controls (MON-3 key codes):
;   left  (0x11) = move left
;   right (0x10) = move right
;   GO     (0x12) = soft drop
;   AD     (0x13) = counter-clockwise rotate
;   C      (0x0C) = clockwise rotate
;   0      (0x00) = pause
;
; Design:
;   - One scanline is output per main-loop iteration.
;   - Game work is split across 8 slices (LOGIC_SLICE 0-7 on each pass).
;   - The framebuffer is 8 rows x 4 bytes (R/G/B/Aux).
;   - The landed board is stored as RGB bitplanes plus monochrome occupancy.
;   - The active object is a 4x4 bitmap blitted in its piece colour over the board.
;   - Pieces are selected from a PRNG-driven 7-piece stream with preview.

        ORG     0x4000

        .include "shared/inc/constants.asm"
        .include "games/tetro/constants.asm"

START:
        CALL    INIT_STATE

MAIN_LOOP:
        CALL    SCAN_TICK
        CALL    LOGIC_TICK
        JR      MAIN_LOOP

        .include "games/tetro/geometry_helpers.asm"
        .include "games/tetro/collision.asm"
        .include "shared/framebuffer_core.asm"
        .include "shared/framebuffer.asm"
        .include "games/tetro/piece_active.asm"
        .include "games/tetro/board_lock.asm"
        .include "games/tetro/game_init.asm"
        .include "shared/scan_tick.asm"
        .include "shared/sound.asm"
        .include "games/tetro/sound.asm"
        .include "shared/hud.asm"
        .include "games/tetro/hud.asm"
        .include "shared/lcd.asm"
        .include "games/tetro/ui.asm"
        .include "games/tetro/logic_dispatch.asm"
        .include "shared/input.asm"
        .include "games/tetro/data.asm"
        .include "games/tetro/ram.asm"
