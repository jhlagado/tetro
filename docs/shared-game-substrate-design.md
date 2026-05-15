# Shared game substrate design

This document captures the next harmonisation pass for TETRO, Pacmo, and future 8x8 games.

The goal is to make a third game easier to write on top of the shared codebase without turning the shared code into a brittle game engine. The shared layer should contain stable hardware, display, timing, and small utility contracts. It should not absorb TETRO piece rules, Pacmo monster rules, or input meanings such as rotate, drop, or power mode.

The guiding principle is practical reuse, not maximum DRY. Some repetition is acceptable when it keeps game logic clear.

---

## Current substrate

The shared codebase already provides the low-level runtime:

- `shared/inc/constants.asm`: hardware ports, MON-3 API constants, matrix dimensions, colour bits, and speaker bit
- `shared/scan_tick.asm`: matrix scanout and scan-state advance
- `shared/framebuffer_core.asm`: generic back-buffer clear/copy helpers
- `shared/framebuffer_draw.asm`: matrix x-to-mask conversion and RGB framebuffer drawing primitives
- `shared/sound.asm`: speaker divider state machine
- `shared/hud.asm`: seven-segment digit scan, blanking, digit/glyph tables, and decimal formatting
- `shared/lcd.asm`: HD44780 primitives, script renderer, row string writer, and table-character writer

That split is working. The next step is to raise the shared layer slightly, but only where the contract remains game-neutral.

---

## Boundary rule

Shared code is appropriate when a future 8x8 game could use it without inheriting TETRO or Pacmo vocabulary.

Good shared code:

- talks to hardware
- scans or clears generic buffers
- formats generic display data
- converts coordinates to matrix bit masks
- writes RGB cells or row masks
- decrements timers or advances shared counters
- uses neutral names such as score, colour, row, cell, mask, timer, script, and framebuffer

Game-local code:

- names game actions such as rotate, drop, lock, power, flee, caught, or line clear
- encodes TETRO pieces, board collapse, gravity, rotation, collision, next preview, or scoring rules
- encodes Pacmo maze, viewport, player, monster, pill, power mode, respawn, or level progression rules
- maps keypad buttons directly to game-specific actions
- selects game-specific LCD screens and sound events

The shared layer should make common jobs quicker. It should not make either game harder to read.

---

## Priority 1: HUD and score formatting

This duplication has been removed.

TETRO and Pacmo both format a 16-bit score into six seven-segment digits by repeated subtraction. The shared HUD layer now owns the digit mask table, glyph table, and decimal writer.

Implemented shape:

- `src/shared/hud.asm` owns `HUD_DIGIT_MASK_TABLE` and `HUD_SEG_GLYPH_TABLE`.
- `src/shared/hud.asm` owns `HUD_WRITE_U16_DECIMAL` and `HUD_WRITE_DECIMAL_DIGIT`.
- Game-local `UPDATE_SCORE_DISPLAY` wrappers remain in place.
- Each wrapper loads the game score into `HL`, points `BC` at `HUD_SEG_BUFFER`, and tail-calls the shared formatter.

The shared formatter should not know `SCORE_LO`, `PACMO_SCORE`, line clears, paths, pills, or enemies. It should only know how to turn a 16-bit value into segment bytes.

Expected result:

- no duplicated score conversion loop
- one shared display language for decimal scores
- game-local score events remain local

---

## Priority 2: Move TETRO-shaped files out of `shared`

This boundary cleanup has been completed.

Before the move, the shared directory contained TETRO-specific input and rendering files. The input file called labels such as `MOVE_LEFT`, `MOVE_RIGHT`, `ROTATE_CW`, `ROTATE_LEFT`, and `SOFT_DROP`. The rendering file depended on labels such as `BOARD_ROWS`, `CURRENT_PIECE_PTR`, `CURRENT_PIECE_COLOR`, `CLEAR_MASK`, and `GAME_OVER`. Those were historical location problems, not reusable shared contracts.

Implemented shape:

- TETRO input lives in `src/games/tetro/input.asm`.
- TETRO rendering lives in `src/games/tetro/render.asm`.
- `src/shared/framebuffer_core.asm` remains shared for generic clear/copy helpers.
- `src/shared/framebuffer_draw.asm` contains only game-neutral framebuffer draw primitives.

This does not reduce code size, but it improves the architecture. The `shared` directory should mean “usable by another game.”

Expected result:

- clearer shared/local boundary
- less accidental coupling for a third game
- shared docs match source layout more honestly

---

## Priority 3: LCD row helpers

Both games use the shared LCD script runner, then patch a dynamic row.

TETRO writes `NEXT: ` and appends a piece letter. Pacmo writes `LEVEL ` and appends a level character. The screen names and dynamic data are game-specific, but the row positioning and table-character append pattern are generic.

Implemented shape:

- `src/shared/lcd.asm` owns `LCD_WRITE_ROW_STRING`.
- `src/shared/lcd.asm` owns `LCD_PUTC_FROM_TABLE`.
- All screen-selection wrappers stay local.

The shared helper should not know about `NEXT_PIECE_INDEX`, `PIECE_NAME_TABLE`, `PACMO_LEVEL`, or `PACMO_LEVEL_CHAR_TABLE`. Those values should be loaded by local wrappers.

Expected result:

- less repeated LCD row-update code
- no shared knowledge of TETRO preview or Pacmo level state

---

## Priority 4: Framebuffer colour and mask primitives

Pacmo has a useful generic cell writer. TETRO has useful row-mask colour writers. Both speak the same RGB framebuffer language, but they are still embedded in game files.

Implemented shape:

- `src/shared/framebuffer_draw.asm` owns `MATRIX_X_TO_MASK` for screen x coordinates, with x 0 mapped to the most significant bit.
- `src/shared/framebuffer_draw.asm` owns `FB_SET_CELL_COLOR`, which sets one RGB cell to an exact colour, replacing previous colour bits.
- `src/shared/framebuffer_draw.asm` owns `FB_OR_ROW_COLOR_MASK`, which ORs a row mask into selected RGB planes.
- Pacmo world rendering and TETRO piece rendering remain local.

This is a good place to standardise names around “matrix”, “framebuffer”, “cell”, “row mask”, and “colour.”

Expected result:

- shared RGB write vocabulary
- future games can draw simple cells without writing plane logic
- game renderers remain local and readable

---

## Priority 5: Shared colour names

The hardware constants already expose `COLOR_RED`, `COLOR_GREEN`, and `COLOR_BLUE`. Games then compose cyan, magenta, yellow, and white inline.

Implemented shape:

- `src/shared/inc/constants.asm` owns standard composite colour constants:
  - `COLOR_BLACK`
  - `COLOR_YELLOW`
  - `COLOR_CYAN`
  - `COLOR_MAGENTA`
  - `COLOR_WHITE`
- Keep game palettes local, but let them use the shared colour names.

This gives all games the same language for RGB colours without forcing the same palette choices.

Expected result:

- more readable palette definitions
- fewer ad hoc colour sums in game data
- no change to rendered colours

---

## Priority 6: Tiny timer and slice helpers

Both games use short countdowns and gates:

- TETRO game-over restart gate
- TETRO line-clear hold
- Pacmo game-over restart gate
- Pacmo level-complete gate
- Pacmo power timer
- Pacmo monster respawn timers

The side effects differ, so the state machines should stay local. A tiny shared decrement helper may still be useful.

Design:

- Consider a helper that decrements a 16-bit countdown at `HL` or at an address supplied by the caller.
- Return zero/nonzero status in flags.
- Do not encode what happens when the timer expires.

Likewise, both games advance `LOGIC_SLICE` in the same way. A shared `ADVANCE_LOGIC_SLICE` helper may be useful, but a callback-based scheduler is not recommended.

Implementation note: leave `LOGIC_SLICE_NEXT` local for now. Although the instruction sequence is duplicated, extracting it naively would either add a tail jump/call or move a `JR` target farther away. On this hardware, scan-loop timing and branch locality matter more than removing four duplicated instructions. Revisit only if a future assembler macro/include pattern can keep the emitted bytes and local branch shape equivalent.

Expected result:

- slightly less timer boilerplate
- no generic state-machine framework

---

## Things not to extract

Do not extract these in the next pass:

- TETRO collision, rotation, gravity, lock, line clear, board collapse, piece RNG, or next-piece preview
- Pacmo maze probing, viewport scrolling, path consumption, power mode, monster AI, respawn scoring, or level progression
- game-specific input action mapping
- game-specific LCD screen names and scripts
- game-specific sound event names and tuning
- a generic entity framework
- a generic state-machine framework

These areas may share design philosophy, but they do not yet share a clean game-neutral contract.

---

## Proposed development sequence

1. Rename the shared codebase documentation and update links.
2. Extract shared HUD segment tables and decimal score formatting.
3. Move TETRO-shaped input and rendering out of `src/shared`, keeping only generic framebuffer helpers shared.
4. Add LCD row/table-character helpers.
5. Add framebuffer colour and mask primitives.
6. Add shared composite colour constants and update palettes to use them.
7. Revisit timer and slice helpers after the simpler shared utilities are stable.

Each step should be small, build both games, and preserve behavior.

---

## Acceptance criteria

A future harmonisation step is successful when:

- TETRO and Pacmo both build after the change.
- No game-specific rule is moved into `src/shared`.
- Shared routines have clear input, output, and clobber contracts.
- The shared codebase documentation matches the actual source layout.
- A third 8x8 game could reasonably use the shared routine without adopting TETRO or Pacmo terminology.

The goal is a shared substrate that makes new games quicker to start, not an abstraction layer that hides how the games work.
