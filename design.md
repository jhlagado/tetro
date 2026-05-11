# Falling-Block Data Model for TEC-1G / Z80

This note extracts the useful game-logic ideas from the Arduino WS2812 implementation and rewrites them for the real TEC-1G constraints.

The Arduino version is **not** a timing model for this project. It assumes a self-refreshing LED strip and uses `millis()` / `delay()`. On the TEC-1G RGB matrix, the display must be scanned continuously, so game logic must fit around the scan loop instead of blocking it.

## Scope

This is a data-model and update-model note only. It does **not** define:

- the final matrix scan implementation
- keypad driver internals
- LCD / 7-seg HUD routines
- sound

It does define:

- board representation
- piece representation
- update phases
- framebuffer rendering contract

## Core rule

The raster is the metronome.

That means:

- one frame = one full 8-row matrix refresh
- input polling happens at a frame boundary
- game logic runs at a frame boundary
- delays are counted in frames, not blind busy-waits

The thin top-level `src/tetro.asm` (`ORG`, `START`, `MAIN_LOOP`, and `.include` lines) plus the gameplay-facing modules (**`geometry_helpers.asm`**, **`collision.asm`**, **`piece_active.asm`**, etc.—alongside **`ui.asm`**, **`data.asm`**, **`ram.asm`**) already prove that loop shape at the simplest playable-object level.

## Memory layout

Keep the program split into two logical memory classes:

- ROM region:
  - code
  - immutable piece tables
  - lookup tables
  - constant metadata

- RAM region:
  - mutable runtime state
  - scan state
  - framebuffers
  - later board state and counters

Do not hard-code a RAM base yet. Instead, define a named RAM block at the end of the program, beginning at `RAM_START`, and let the assembler place it. That keeps the source relocatable for future RAM-loaded or ROM-based layouts.

Any runtime value that must start defined should be initialized by startup code. Do not rely on embedded mutable `DB` values in the code/data region as if they were ROM constants.

The source is now also split structurally with `.include`:

- constants include
- top-level entry file for constants and `START` / `MAIN_LOOP`
- gameplay-related modules (**`geometry_helpers.asm`**, **`board_lock.asm`**, … plus **`ui.asm`** / **`data.asm`** / **`ram.asm`**), all under **`src/modules/`**
- UI/service module
- data/table module
- RAM layout module

That split is organizational only. It should not change the scheduling or gameplay model.

## Logical layers

The game should stay split into three layers:

1. **Board state**
   Fixed occupied cells already landed.

2. **Active piece state**
   Current tetromino type, rotation, and position.

3. **Render projection**
   Convert board + active piece into the 32-byte RGB+Aux scan framebuffer.

That separation is the main reusable architectural idea from the Arduino code.

## Board representation

For an 8x8 display, the simplest useful board is:

- width: 8
- height: 8
- each cell stores either empty or occupied
- optional second plane stores colour

Recommended first representation:

```text
board_rows[8] : 1 byte per row
```

Each byte uses one bit per column:

- bit 7 = x 0
- bit 6 = x 1
- ...
- bit 0 = x 7

This gives:

- cheap collision checks
- cheap line-full tests
- cheap line clears and row shifts

If colour is needed, add parallel colour planes:

```text
board_red[8]
board_green[8]
board_blue[8]
```

That matches the scan-native framebuffer model directly.

## Active piece representation

The Arduino `Tetromino` struct is conceptually good, but for this 8x8 board the playable pieces fit a tighter footprint than guideline Tetris sprites. The engine should stay general: every piece still rotates through four stored masks in one uniform **`4×4`** local frame even when some masks are sparse.

The default gameplay piece set is:

- `I`
- `O`
- `T`
- `S`
- `Z`
- `J`
- `L`

The straight piece **`I`** is SRS lettering for the skinny bar; here it occupies **three** cells—a short horizontal/vertical line scaled for this board.

The intended default rotation geometry is:

```text
I:
  rot0: (0,0) (1,0) (2,0)
  rot1: (0,0) (0,1) (0,2)
  rot2: (0,0) (1,0) (2,0)
  rot3: (0,0) (0,1) (0,2)

O:
  rot0..3: (0,0) (1,0) (0,1) (1,1)

T:
  rot0: (0,0) (1,0) (2,0) (1,1)
  rot1: (1,0) (0,1) (1,1) (1,2)
  rot2: (1,0) (0,1) (1,1) (2,1)
  rot3: (0,0) (0,1) (0,2) (1,1)

S:
  rot0: (1,0) (2,0) (0,1) (1,1)
  rot1: (0,0) (0,1) (1,1) (1,2)
  rot2: (1,0) (2,0) (0,1) (1,1)
  rot3: (0,0) (0,1) (1,1) (1,2)

Z:
  rot0: (0,0) (1,0) (1,1) (2,1)
  rot1: (1,0) (0,1) (1,1) (0,2)
  rot2: (0,0) (1,0) (1,1) (2,1)
  rot3: (1,0) (0,1) (1,1) (0,2)

J:
  rot0: (0,0) (0,1) (1,1) (2,1)
  rot1: (1,0) (2,0) (1,1) (1,2)
  rot2: (0,0) (1,0) (2,0) (2,1)
  rot3: (0,0) (0,1) (0,2) (1,0)

L:
  rot0: (2,0) (0,1) (1,1) (2,1)
  rot1: (0,0) (1,0) (1,1) (1,2)
  rot2: (0,0) (1,0) (2,0) (0,1)
  rot3: (0,0) (0,1) (0,2) (1,2)
```

For Z80, the cleaner representation is a packed bitmap per rotation rather than a list of four coordinate pairs.

Keep the logical piece footprint at `4x4`, not `3x3`.

Reason:

- the default gameplay set is mostly `3x3`-scale, but a uniform `4×4` engine footprint still keeps rendering, collision, and rotation logic simple
- sparse masks (fewer than four occupied cells) are fine inside that footprint—**`I`** is the canonical example here

Recommended shape:

```text
piece_table[7][4]
```

Each entry is a 16-bit 4x4 bitmap:

- bits represent a 4x4 local cell grid
- top nibble = local row 0
- next nibble = local row 1
- next nibble = local row 2
- bottom nibble = local row 3

Example idea:

```text
I (stored as row bytes in asm; three cells horizontal or vertical inside the 4×4 frame — see `PIECE_I_R*` in data.asm)
O piece      = 1100 1100 0000 0000
```

Rotations should be precomputed and stored explicitly. Do not rotate the bitmap on the fly.

Reason:

- only 7 pieces x 4 rotations exist
- stored rotations keep render and collision using the same source data
- on-the-fly rotation adds avoidable complexity and risk on the Z80

Horizontal placement is a different concern and should be applied at render time by shifting the row mask in registers. Do not store a separate copy of each rotation for every horizontal position.

For the default `3x3`-scale piece family, rotations should now be thought of as centered around the local `3x3` pivot at `(1,1)`.

That means:

- the meaningful gameplay geometry is a centered `3x3` local frame
- each default rotation is precomputed from that centered local model
- the engine may still store the result in a uniform `4x4` row format

This is better than bottom-left packing once rotation becomes a real gameplay feature because:

- the local pivot stays conceptually stable across rotations
- rotations do not have to be interpreted as different packed offsets of the same shape
- the precomputed bitmaps read more naturally as rotated versions of the same local form

The practical rotation origin is therefore still virtual, but it is now a virtual centered origin for the default piece family rather than a bottom-left-normalized one.

Per-rotation extents are still required:

- right extent
- bottom extent
- and later, if useful, left/top extents as well

These extents should be treated as metadata derived from the occupied cells of each stored rotation, not from the size of the container itself.

Collision still does **not** come from the container. It comes from testing occupied cells. The decisive rule remains occupied-bit overlap against landed rows.

Why this is better for Z80:

- fixed-size data
- fixed-cost row extraction
- easier clipping and collision loops
- avoids coordinate-table chasing in hot code
- keeps shape definition separate from placement

## Active piece state

Keep the current falling piece state minimal:

```text
current_piece      ; 0..6
current_rotation   ; 0..3
current_x          ; board x of the local shape frame
current_y          ; board y of the local shape frame
```

Optional later:

```text
next_piece
score
level
lines_cleared
```

## Update phases

The Arduino loop had the right high-level phases but the wrong timing source. For TEC-1G the phases should be driven by frame counts.

Recommended outer structure:

1. refresh matrix for one frame
2. poll keypad
3. update per-frame timers
4. process player action
5. process gravity tick if due
6. rebuild framebuffer
7. repeat

## Top entry and clipping

Active pieces should not be required to start fully visible.

They should be allowed to begin partially above the visible `8x8` playfield and enter from the top as gravity advances them downward.

That means the renderer must support partial visibility:

- for each local bitmap row
- compute the corresponding screen row
- if the row is above the visible field, skip drawing it
- if the row is inside the visible field, draw it

Collision logic must make the same distinction:

- occupied cells above the visible top edge are allowed for the active falling piece
- occupied cells below the bottom edge are not allowed
- occupied cells overlapping landed board cells in visible space are not allowed

Spawn logic should therefore allow a piece to exist partially off-screen above the top. A top-out condition happens only when a newly spawned piece cannot legally enter because its visible occupied cells already collide with landed board state.

The current implementation target for top-out is basic state handling:

- latch a `game over` state
- stop movement / gravity / gameplay updates
- leave the final landed board visible
- prefer the LCD for user-facing game-over / status text rather than the `7`-seg (six multiplexed digits are a poor canvas for **`GAME OVER`**: nine letters, clumsy substitutions such as **V→U**, and the numeric HUD should stay readable).

Presentation on the **`8×8` RGB matrix** (implemented):

- **`LCD_SHOW_*`** carries full words (**`GAME OVER`**, **`PRESS ANY KEY`**). The HUD digits remain **decimal score only**.
- During **`GAME_OVER`**, **`RENDER_BOARD_TO_BACK`** skips per-cell hue: it renders **landed occupancy from `BOARD_ROWS` into red only**, with green and blue cleared (`src/modules/framebuffer.asm`). The whole stack reads as **uniform red silhouette**—a typography-free cue on the matrix without spelling **`GAME OVER`** on **7‑seg**. **`PRESS ANY KEY`** stays inert until **`GAME_OVER_KEY_GATE_*`** drains **`GAME_OVER_KEY_GATE_TICKS`** passes of **`LOGIC_TICK`** (`**`WAIT_GAME_OVER_KEY_GATE`**` in **`src/modules/input.asm`**; **`EQU`** in **`constants.asm`**). **`SOUND_TRIGGER_GAME_OVER`** on death and **`SOUND_TRIGGER_GAME_OVER_RESTART_READY`** when the key gate clears (PWM via **`SERVICE_SOUND`**).
- Additional matrix ideas if you revisit this: fullscreen wipe/pulse (**`CLEAR_BACK_*` / colour fill** only), XOR flicker overlay, perimeter trace—still inferior to LCD for spelled English.

Residual nice-to-have (unchanged architectural advice):

- add a tuned game-over flourish on **`SERVICE_SOUND`** (already triggered)

## Time-sliced peripherals

The same cooperative scan-sliced main loop that drives the `8x8` RGB matrix can also drive simple peripheral output without introducing a separate scheduler.

This is especially relevant for:

- the six-digit `7`-segment display on the TEC-1
- simple speaker output driven by a toggled bit

The intended model is the same as the matrix scan:

- do a small fixed amount of peripheral work each main-loop pass
- rely on persistence of vision for multiplexed visual hardware
- keep each task bounded so the overall row-to-row timing stays reasonably even

User-facing status and diagnostic text should prefer the LCD. The `7`-segment display is a better fit for compact score/HUD data once scoring exists.

Current control-state intent:

- `F` toggles pause
- while paused, gameplay updates stop and only the pause-toggle input should be honored
- pause and running state should be communicated on the LCD
- `0` is soft drop and should repeat faster than normal lateral movement

### Seven-segment scoring

The `7`-segment display is a good fit for score or small HUD data.

Recommended use:

- keep score/state as logical values in RAM
- maintain a small digit buffer for what should be shown
- scan one digit, or a very small number of digits, per loop pass
- let persistence of vision create the stable readout

This should be treated as another time-sliced display task, not as a blocking redraw routine.

It belongs naturally in the same main-loop scheduling model as the RGB matrix.

More concretely:

- the `8x8` scan remains the primary real-time display task
- the `7`-segment scan should be interleaved into the same cooperative loop
- a simple first approach is to advance one `7`-segment digit per matrix row tick
- this keeps the scoreboard visually alive without introducing a second timing model
- because the TEC-1G speaker shares the digit port, digit-select output should be treated as `digit_mask OR speaker_state`

Initial scoring baseline:

- `1` cleared row = `100`
- `2` cleared rows = `300`
- `3` cleared rows = `500`
- `4` cleared rows = `800`

Also track total cleared rows separately from score. Ordinary piece locks do not award score.

Current UI split:

- `7`-segment display: score
- LCD during normal play: explicit running-state plus total lines and next-piece indicator
- LCD during paused/game-over states: status/instruction text
- LCD on startup: splash/title plus key mappings, waiting for a key press to begin

### Piece selection

Piece selection should now be random rather than deterministic cycling.

Recommended baseline:

- maintain a small PRNG state byte in RAM
- use the splash-screen wait duration as the primary seed source
- keep a fixed nonzero fallback seed in code if the splash counter happens to be zero
- select the current piece from `NEXT_PIECE_INDEX`
- immediately generate the following `NEXT_PIECE_INDEX` for preview

For a 7-piece set, avoid naive modulo bias. A practical first approach is:

- generate 3 random bits
- reject value `7`
- accept `0..6`

Later enhancement:

- seed from runtime entropy such as user key timing, optionally mixed with `R`
- keep fixed-seed mode available for testing

### Simple speaker output

Simple sound effects can also fit the same model.

Recommended scope:

- short beeps or clicks when a piece locks
- short effects for line clear or state changes
- no assumption of rich music or complex waveform synthesis

A practical first model is:

- maintain a small sound state in RAM
- on each loop pass, update a divider or countdown
- when due, toggle the speaker control bit
- treat sound generation as just another very small service slice synchronized with the same main loop that scans the matrix

Initial sound hooks should be event-driven:

- successful rotate
- ordinary lock
- line clear
- game over

That keeps sound generation cooperative and bounded, just like the display scan tasks.

### Scheduling implications

Adding these peripherals does not change the architectural rule:

- the main loop remains a cooperative time-sliced scheduler
- every task must be small and predictable
- no task should block long enough to disturb matrix persistence noticeably

So the runtime should evolve toward:

- matrix row scan task
- game logic slice
- optional `7`-segment scan task
- optional speaker update task

all sharing the same loop budget.

## Piece source and PRNG

The next gameplay step should first use a deterministic piece source.

Reason:

- deterministic piece order is easier to debug than random selection
- geometry, collision, and rotation bugs are easier to reproduce with a known sequence
- randomness should be introduced only after the piece-table path is stable

Recommended progression:

1. fixed cycle or scripted sequence for development
2. add a small PRNG once multi-piece spawning is working
3. keep explicit seed control so tests remain reproducible

### PRNG shape

Recommended first PRNG:

- a very small `8`-bit LFSR or similar cheap byte-oriented generator
- one dedicated RAM byte of PRNG state
- one routine responsible for advancing and returning the next byte

### Seed policy

Recommended seed policy:

- test mode: fixed seed
- normal mode: runtime seed

Runtime seeding should prefer user-driven entropy over relying only on the `R` register.

Reason:

- the `R` register is only `7` bits and is not a strong source by itself
- user key timing is a better gameplay-facing entropy source
- a practical solution is to start from a simple base value and stir in keypress timing / key values as they occur

### Piece-count selection

Avoid naive `% 7` selection as the first implementation.

Preferred options:

- use a deterministic fixed cycle first
- or choose a power-of-two-friendly table size
- or add an explicit remapping / rejection strategy later once the base generator is stable

## Landed board storage

The first landed-board implementation may use monochrome occupancy only, but the intended game model should preserve piece colour after locking.

The preferred landed-board representation is separate RGB bitplanes, not packed per-cell colours.

Recommended shape:

- `board_red[8]`
- `board_green[8]`
- `board_blue[8]`

Optionally:

- `board_occupied[8]`

or derive occupancy from the union of the colour planes.

When a piece locks:

- load the piece's monochrome row mask
- apply its horizontal placement
- OR that row mask into each landed colour plane selected by the piece's 3-bit RGB colour mask

This keeps shape geometry independent from colour and matches the scan-native framebuffer model directly.

The current implementation keeps both:

- monochrome occupancy rows for collision
- landed RGB bitplanes for rendering

That is slightly redundant, but it keeps collision logic simple while the game is still under active development.

## Collision strategy

True collision detection should be done by occupied-bit overlap on each relevant scanline.

For a candidate placement:

1. select the rotation bitmap
2. take each occupied bitmap row
3. shift it horizontally into board position
4. compare it against the landed board row it would occupy

The decisive test is:

```text
shifted_piece_row AND landed_board_row != 0
```

If that result is nonzero, a collision has occurred.

## Line clear strategy

First implementation:

- detect all completed rows after a lock/merge
- latch a clear-pending state and a row mask
- suspend normal gameplay updates during clear pending
- render completed rows as solid white for a short hold
- collapse all completed rows together
- spawn the next piece only after collapse completes

Possible later enhancement:

- if multiple rows are completed together, remove them one at a time
- let the visible stack settle between removals so the downward motion reads more smoothly on the `8x8` board

This applies uniformly to:

- downward movement
- left movement
- right movement
- rotation

The engine should therefore think in terms of validating a candidate placement, not in terms of special-case floor contact.

Examples of what this catches correctly:

- a `T` wing landing on a cliff
- a hooked shape catching on an overhang
- lateral movement into an irregular wall of landed cells

## Bounds and extents

Per-rotation extents or bounding boxes may still be useful, but only as coarse helpers.

They are good for:

- quick rejection against walls or floor
- spawn and clipping rules
- avoiding unnecessary row-overlap work

They are not sufficient to decide collision on their own.

A bounding box intersection only says that overlap is possible. The real collision decision must still come from occupied-bit overlap on the bitmap rows.

That becomes two time domains:

- **frame domain**
  Runs every full matrix refresh.

- **game tick domain**
  Runs every `N` frames.

Example:

- poll input every frame
- horizontal move repeat every 4 frames
- gravity every 20 frames

This is much better than trying to run all gameplay every raw scan pass.

## State machine

The active game should be treated as a small explicit state machine:

1. `spawn`
2. `control`
3. `fall`
4. `lock`
5. `clear`
6. `game_over`

That matters because it keeps worst-case work bounded.

### Spawn

- choose piece
- reset rotation / position
- validate spawn position
- if invalid: `game_over`

### Control

- read one player intent from current input state
- try move left / right
- optionally try rotate

This should stay bounded:

- one lateral move attempt
- one rotation attempt

### Fall

- only when gravity timer expires
- try `y + 1`
- if valid: move piece down
- if invalid: transition to `lock`

### Lock

- merge active piece into board bitmaps
- transition to `clear`

### Clear

- check full rows
- compact board downward if needed
- update score / counters
- transition to `spawn`

This is the first place where multi-step handling may be useful if the line-clear animation becomes expensive. The initial version can do it in one pass because the board is only 8x8.

## Collision contract

The Arduino `isValidPosition()` abstraction is worth keeping.

On Z80 it should become something like:

```text
piece_fits(piece, rotation, x, y) -> carry clear/set or zero/nonzero
```

It must check:

- piece cells stay within board bounds
- piece cells do not overlap occupied board cells

Do not make this a variable-shape routine that walks sparse coordinates in different-length branches. Prefer a fixed 4-row loop over the 4x4 bitmap.

## Rendering contract

The scan loop should never know about tetromino rules.

Rendering should happen in two steps:

1. clear or rebuild a logical framebuffer from game state
2. scan that framebuffer to hardware

Current scan-native framebuffer:

```text
framebuffer[32]
row0: R,G,B,Aux
row1: R,G,B,Aux
...
row7: R,G,B,Aux
```

Recommended render flow:

1. clear framebuffer or compose into a back buffer
2. copy landed board colours into framebuffer
3. overlay active piece colour into framebuffer

For a first falling-block game, colour can stay simple:

- each piece type owns one RGB colour
- landed blocks keep their piece colour
- the original orange `L` reference colour is not available on 3-bit RGB hardware, so use white as the current substitute

Store shape bitmaps as monochrome occupancy masks, not as coloured bitmaps.

Colour should be separate piece metadata and should be applied at render time by selecting which RGB planes receive the row mask.

That means:

- the bitmap answers only: which cells are occupied
- the colour value answers: which of red/green/blue should be written

This keeps geometry and colour independent and avoids duplicating bitmap data for each colour.

## Colour model

The hardware supports 3-bit colour:

- red
- green
- blue

So the natural colour encoding is:

```text
0 = black
1 = red
2 = green
3 = yellow
4 = blue
5 = magenta
6 = cyan
7 = white
```

Store either:

- packed colour per board cell, then expand during render

or:

- separate landed colour bitplanes directly

For the smallest and fastest renderer on this machine, separate bitplanes are likely better once the game graduates from the single-pixel demo.

Recommended active-piece colour model:

- piece type owns a 3-bit RGB mask
- renderer loads monochrome row bits
- renderer shifts the row bits according to `x`
- renderer ORs that mask into the enabled colour planes only

## Input model

Do not copy the Arduino debounce approach.

Use MON-3 key services and express behavior in frame counters:

- new press
- held repeat
- repeat period in frames

That matches the current codebase direction (scan-sliced **`LOGIC_TICK`** and per-row **`CLEAR_BACK_*`** / **`RENDER_*`** / copy slicing in **`src/modules/logic_dispatch.asm`**), including optional hooks in **`ui.asm`** for LCD and score digit scanning.

## Maintainability and refactor notes

This section records **code-quality** observations on the current Z80 source (as of `main`, with gameplay split across sibling **`src/modules/*.asm`** files). It does not change the gameplay or timing model above; it is planning for clarity and less duplication.

### Module layout (actual build)

- **`src/tetro.asm`** — `ORG`, entry, `MAIN_LOOP` only; includes everything else.
- **`src/inc/constants.asm`** — ports, key codes, sizing `EQU`s, colour/sound timing constants.
- **`src/modules/geometry_helpers.asm`** — **`LOAD_DE_FROM_PENDING`** (pending placement → **`DE`** for collision); **`SHIFT_ROW_MASK`** shared by collision, merge, and active-piece render paths.
- **`src/modules/collision.asm`** — **`CHECK_COLLISION_AT_DE`**, **`CHECK_TOP_OUT_ON_LOCK`**.
- **`src/modules/framebuffer.asm`** — framebuffer rebuild/back-buffer maintenance, **`CLEAR_BOARD`**, **`RENDER_*`**, **`WRITE_COLORED_ROW_MASK`**.
- **`src/modules/piece_active.asm`** — lateral moves / gravity / soft drop / sanitize, RNG, **`SELECT_NEXT_PIECE`**, **`LOAD_CURRENT_ROTATION_STATE`**, rotates, **`SPAWN_ACTIVE_PIECE`**.
- **`src/modules/board_lock.asm`** — **`LOCK_ACTIVE_PIECE`**, merge/score/pacing helpers, **`ENTER_GAME_OVER`**, splash continuation, **`HANDLE_LINE_CLEAR_STATE`**, line-collapse path.
- **`src/modules/game_init.asm`** — **`INIT_STATE`**, **`INIT_STATE_RESTART`**, **`INIT_STATE_BASE`**.
- **`src/modules/scan_tick.asm`** — **`SCAN_TICK`** (matrix row + 7‑seg slice).
- **`src/modules/logic_dispatch.asm`** — **`LOGIC_TICK`** / per-slice **`LOGIC_SL*`** dispatcher.
- **`src/modules/input.asm`** — keypad poll (**`POLL_INPUT_AND_UPDATE`**), pause/unpause hooks, directional repeat (**`HANDLE_HELD_DIRECTION`**), etc.
- **`src/modules/ui.asm`** — LCD strings, digit buffer, `SCAN_SCORE_DIGIT`, related helpers.
- **`src/modules/data.asm`** — piece bitmaps, tables, LCD text blobs, `ROW_BIT_TABLE`, etc.
- **`src/modules/ram.asm`** — single `RAM_START` block (`DS`) for all mutable state.

Organizational split only: behaviour should stay identical to a monolithic file assembled to the same addresses.

### Naming and documentation nits

- **`ROW_COUNT`** is the logical **edge length** of the square playfield (8 cells); **`FIELD_WIDTH`** in `constants.asm` is an alias for the same value when stressing **column / X** semantics—**not** raster scan rows.
- **`FRAME_PHASE`** (see **`ram.asm`**) increments once per full **`FRAMEBUFFER`** wrap inside **`ADVANCE_SCAN_STATE`**; splash RNG consumes it—it is **not** the gameplay timer (movement, gravity, and line-clear hold use **`MOVE_COOLDOWN`**, **`CURRENT_GRAVITY_PERIOD`**, **`CLEAR_TIMER`**).

### Collision vs extent metadata (implementation discipline)

- **`PIECE_RIGHT_TABLE` / `PIECE_BOTTOM_TABLE`** remain valid as **coarse** bounds helpers (spawn, sanitize, quick X reject in `CHECK_COLLISION_AT_DE`).
- **Lateral movement** should treat **`CHECK_COLLISION_AT_DE`** (bitmask rows + board overlap) as the **authority** for “can this `(x,y)` placement exist?” Any separate fast path (e.g. `PLAYER_X + extent` only) can drift from rotation geometry; if a fast path exists, it must match the bitmap test or be removed.

### Repetition worth drying up (low risk refactors)

1. **`PENDING_*` → `DE`** — covered by **`LOAD_DE_FROM_PENDING`** in current sources.
2. **`LOGIC_SL2` … `LOGIC_SL6`** — consolidated to one offset calculation + **`CLEAR_BACK_4`** in **`LOGIC_TICK`**.
3. **`KEY_NEW_PRESS` vs `HANDLE_DIRECTION_KEY`** — optional if the input FSM grows (unchanged deliberate layout).

### Peripheral and data modules (review backlog)

- **`ui.asm`**: removed unused **`LCD_WRITE_DECIMAL3`** (nothing called it—re-add from history if HUD needs formatted decimal elsewhere).
- **`data.asm`** / **`ui.asm`** still carry distinct LCD string blobs (`TETRO`, status lines, splash copy); merging would save only a handful of ROM bytes versus readability loss—left as-is.

### HUD / splash behaviour (score digits)

During **splash** (waiting for the first key to leave the title screen), the **six-digit score multiplex buffer** **`HUD_SEG_BUFFER`** is held at **segment pattern 0** (all segments off via **`BLANK_HUD_SCORE_DIGITS`**) instead of **`UPDATE_SCORE_DISPLAY`**. **`HANDLE_SPLASH_STATE`** still calls **`UPDATE_SCORE_DISPLAY`** when the player starts the run so **`000000`** appears as play begins (while score RAM is reset). Restart-from-game-over (**`INIT_STATE_RESTART`**) skips splash and goes straight to **`UPDATE_SCORE_DISPLAY`** as before. If real hardware inverts segment polarity, replace the blank pattern with the appropriate “all off” code from **`DIAG_SEG_TABLE`** / bench test.

### Build artifacts

- Assembled **`.hex` / `.lst`** under **`build/`** (per `debug80.json`) are outputs, not source-of-truth; keep them out of git (already covered by `.gitignore`).

---

## What to build next

**Historical note:** the numbered list below tracked early bring-up milestones. **`tetro` on `main`** now covers board state, collision, lock/spawn, line clears and score, splash/pause paths, HUD (LCD + multiplexed digits + sound stubs), and the seven-piece ROM table stack. Follow **§GitHub-tracked refactor backlog** plus **§Future: difficulty pacing** for current actionable work—not this enumeration.

Recommended progression _(archived MVP sequence)_:

1. **4x4 solid test box**
   Prove the general blitter and scan-sliced rendering path.

2. **Single non-solid 4x4 bitmap**
   Swap in a recognizable shape such as `T` or `L`.

3. **Board collision**
   First real collision against landed board state.

4. **Spawn + lock**
   Introduce active-piece lifecycle.

5. **Board row clear**
   First scoring / clear behavior.

6. **Full 7-piece table**
   Add the full `I O T S Z J L` set with the reference rotation geometry above.

This sequence was the sane order to grow complexity while proving the raster metronome on hardware.

## GitHub-tracked refactor backlog

The **P1→P4** maintainability wave (issues **[#6](https://github.com/jhlagado/tetro/issues/6)** through **[#10](https://github.com/jhlagado/tetro/issues/10)**) is **done** on `main`; multiline pacing shipped as **[#17](https://github.com/jhlagado/tetro/issues/17)**. Umbrella **[#11](https://github.com/jhlagado/tetro/issues/11) is closed** — it only indexed this sequence.

Reference table _(historical scopes)_:

| Tier | Theme                              | Scope (files)                                                                                                                                                                                                                                                                                                                      | Issue                                                |
| ---- | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| P1   | Input/gameplay hygiene + LCD noise | Closed — [#6](https://github.com/jhlagado/tetro/issues/6): `LOAD_DE_FROM_PENDING`; `LCD_REFRESH_NEXT_PREVIEW_ROW` on spawn; `HANDLE_KEY_*` `JP` symmetry; `SCAN_SCORE_DIGIT` SCAN_TICK/`HUD_SCAN_INDEX` doc (+ earlier rename/comment churn).                                                                                      | [#6](https://github.com/jhlagado/tetro/issues/6) ✓   |
| P2   | ROM / table hygiene                | Closed — [#7](https://github.com/jhlagado/tetro/issues/7): redundant rotation frames removed from ROM via `EQU` aliases (`I`/`O`/`S`/`Z`); `PIECE_PTR_TABLE` unchanged logically.                                                                                                                                                  | [#7](https://github.com/jhlagado/tetro/issues/7) ✓   |
| P3   | Mechanical refactors               | Closed — [#8](https://github.com/jhlagado/tetro/issues/8): `COPY_BOARD_ROW_DE_TO_E` / `CLEAR_BOARD_ROW_D` use one loop over the four contiguous board planes.                                                                                                                                                                      | [#8](https://github.com/jhlagado/tetro/issues/8) ✓   |
| P3b  | LCD boilerplate collapse           | Closed — [#9](https://github.com/jhlagado/tetro/issues/9): `LCD_CLEAR_DISPLAY` (`0x01`) + shared home/row setup; `LCD_CURSOR_HOME_ROW1` wraps it; **`LCD_REFRESH_NEXT_PREVIEW_ROW`** shares the clear path before selecting row 3.                                                                                                 | [#9](https://github.com/jhlagado/tetro/issues/9) ✓   |
| P4   | Behaviour-preserving merges        | Closed — [#10](https://github.com/jhlagado/tetro/issues/10): gravity/soft-drop **`STEP_ACTIVE_DOWN_ONE_CELL`**; lateral **`HORIZONTAL_PROBE_APPLY_PENDING_X`**; rotations share **`ROTATE_FINISH_TEST`**; landed RGB merge **`MERGE_OR_RGB_AT_BOARD_ROW_L`**. framebuffer **`WRITE_COLORED_ROW_MASK`** remains separate scan path. | [#10](https://github.com/jhlagado/tetro/issues/10) ✓ |

**#7 / #8 acceptance (binary output):** Issue **#7** removes duplicate rotation **`DB`** bytes (`EQU` aliases for redundant **`I`/`O`/`S`/`Z`** frames), so assembled **`build/*.hex`** is **smaller** than pre-dedupe builds and is **not** expected to be byte-identical to them; gameplay masks and **`PIECE_PTR_TABLE`** behaviour match. Issue **#8** refactors plane copy/clear into loops; output size may differ slightly from the former unrolled sequence while RAM semantics stay the same. **#9** / **#10** refactor LCD + gameplay tails; **`build/*.hex`** may shift slightly vs older listings while behaviour stays the same — compare with emulator/hardware regressions rather than bitwise hex identity.

### Future: difficulty pacing (decision record)

Tracked as **[#17](https://github.com/jhlagado/tetro/issues/17)** (closed when multiline pacing shipped).

**Implemented (multiline-clear gate):** runtime **`CURRENT_GRAVITY_PERIOD`** (initialised from **`GRAVITY_PERIOD`**); when a resolved clear removes **≥ 2** lines at once, **`APPLY_GRAVITY_PACE_STEP`** subtracts **`GRAVITY_PACE_DELTA`** down to **`GRAVITY_PERIOD_MIN`**. Singles do not accelerate.

**Baseline gravity** remains the **`constants.asm`** init value (**`GRAVITY_PERIOD`**); tune on hardware before changing **`GRAVITY_PERIOD_MIN`** / **`GRAVITY_PACE_DELTA`**.

Optional **tenure metric** (**`FRAME_PHASE`** wraps, **`PLAY_TICK`**, etc.) remains a simpler alternative (#17 chose multiline mastery first); revisit if pacing feels wrong in playtests.

Historical design notes (preference drift):

- **Mastery metric (tenure)** — **How long the run has lasted** (wall-clock–free counters). Longer survival ⇒ linear acceleration (**archive idea** vs shipped multiline gate).
- **Alternatives** — stack-height stress; richer but not deployed.

### Reviewer checklist (historic)

The numbered list below reflected pre-refactor duplication concerns. **`#6`–`#10`** on GitHub absorbed the substantive work (pending→`DE`, plane loops, LCD boilerplate, shared move/rotate/gravity/merge paths, ROM aliases). Treat this section as archival context—not an open backlog.

**Optional elective polish** (no dedicated issue unless you reopen one):

- unify **`LOGIC_SL2` … `LOGIC_SL6`** slice scaffolding if it ever drifts
- **`SCAN_SCORE_DIGIT`** / header comments if scheduling intent confuses readers
- tenure-based pacing variant (alternative discussed under **§Future: difficulty pacing** vs shipped multiline **`#17`**)

## What not to copy from the Arduino code

Do not import these assumptions:

- `millis()` and `delay()` as primary timing
- redraw-then-idle display model
- matrix text as the main score UI
- long blocking flash / sound effects in gameplay path

Those are valid on WS2812 and wrong for the TEC-1G raster problem.

## Bottom line

The Arduino project is useful as a **game-logic reference**, not as a runtime model.

For the TEC-1G version:

- keep the board / piece / collision / state-machine ideas
- replace the timing, input, and display assumptions completely
- render into the 32-byte RGB+Aux framebuffer
- treat frame count as time

That is the correct bridge from the Arduino implementation to a Z80 / MON-3 / scan-driven design.
