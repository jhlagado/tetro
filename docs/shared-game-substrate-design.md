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
- `shared/sound.asm`: speaker divider state machine
- `shared/hud.asm`: seven-segment digit scan and blanking
- `shared/lcd.asm`: HD44780 primitives and script renderer

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

This is the clearest duplication.

TETRO and Pacmo both format a 16-bit score into six seven-segment digits by repeated subtraction. The routines differ only in the score variable name and glyph table name. The digit mask table and seven-segment glyph table are also duplicated.

Design:

- Move the seven-segment glyph table and digit mask table into shared data.
- Add a shared decimal formatter such as `HUD_WRITE_U16_DECIMAL`.
- Keep game-local `UPDATE_SCORE_DISPLAY` wrappers.
- Let each wrapper load the game score into `HL`, point `BC` at `HUD_SEG_BUFFER`, and tail-call the shared formatter.

The shared formatter should not know `SCORE_LO`, `PACMO_SCORE`, line clears, paths, pills, or enemies. It should only know how to turn a 16-bit value into segment bytes.

Expected result:

- no duplicated score conversion loop
- one shared display language for decimal scores
- game-local score events remain local

---

## Priority 2: Move TETRO-shaped files out of `shared`

Two files are currently shared in location but not in contract.

`shared/input.asm` is TETRO-specific. It calls labels such as `MOVE_LEFT`, `MOVE_RIGHT`, `ROTATE_CW`, `ROTATE_LEFT`, and `SOFT_DROP`. Those are not reusable concepts for a third game.

`shared/framebuffer.asm` is also TETRO-specific. It renders the TETRO board and active piece. It depends on TETRO labels such as `BOARD_ROWS`, `CURRENT_PIECE_PTR`, `CURRENT_PIECE_COLOR`, `CLEAR_MASK`, and `GAME_OVER`.

Design:

- Move `shared/input.asm` to `games/tetro/input.asm`, or rename it so its TETRO contract is explicit.
- Move `shared/framebuffer.asm` to `games/tetro/render.asm`, or split it so only genuine framebuffer primitives remain shared.
- Keep `shared/framebuffer_core.asm` where it is.

This does not reduce code size, but it improves the architecture. The `shared` directory should mean “usable by another game.”

Expected result:

- clearer shared/local boundary
- less accidental coupling for a third game
- shared docs match source layout more honestly

---

## Priority 3: LCD row helpers

Both games use the shared LCD script runner, then patch a dynamic row.

TETRO writes `NEXT: ` and appends a piece letter. Pacmo writes `LEVEL ` and appends a level character. The screen names and dynamic data are game-specific, but the row positioning and table-character append pattern are generic.

Design:

- Add a shared helper to position the LCD cursor and write a string, for example `LCD_WRITE_ROW_STRING`.
- Add a small helper to append a table-indexed character, for example `LCD_PUTC_FROM_TABLE`.
- Keep all screen-selection wrappers local.

The shared helper should not know about `NEXT_PIECE_INDEX`, `PIECE_NAME_TABLE`, `PACMO_LEVEL`, or `PACMO_LEVEL_CHAR_TABLE`. Those values should be loaded by local wrappers.

Expected result:

- less repeated LCD row-update code
- no shared knowledge of TETRO preview or Pacmo level state

---

## Priority 4: Framebuffer colour and mask primitives

Pacmo has a useful generic cell writer. TETRO has useful row-mask colour writers. Both speak the same RGB framebuffer language, but they are still embedded in game files.

Design:

- Add a shared `MATRIX_X_TO_MASK` helper for screen x coordinates, documenting that x 0 maps to the most significant bit.
- Add a shared `FB_SET_CELL_COLOR` helper that sets one RGB cell to an exact colour, replacing previous colour bits.
- Add a shared `FB_OR_ROW_COLOR_MASK` helper that ORs a row mask into selected RGB planes.
- Keep Pacmo world rendering and TETRO piece rendering local.

This is a good place to standardise names around “matrix”, “framebuffer”, “cell”, “row mask”, and “colour.”

Expected result:

- shared RGB write vocabulary
- future games can draw simple cells without writing plane logic
- game renderers remain local and readable

---

## Priority 5: Shared colour names

The hardware constants already expose `COLOR_RED`, `COLOR_GREEN`, and `COLOR_BLUE`. Games then compose cyan, magenta, yellow, and white inline.

Design:

- Add standard composite colour constants to `shared/inc/constants.asm`:
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
3. Move TETRO-shaped `input.asm` and `framebuffer.asm` out of `src/shared`, or split them so only generic pieces remain shared.
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
