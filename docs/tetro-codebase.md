# TETRO: a tour of the code

TETRO is a falling-block game for the TEC-1G single-board Z80 computer. It runs under MON-3, draws an 8x8 RGB LED matrix, scans a six-digit seven-segment score display, writes an HD44780 LCD, reads the MON-3 keypad, and drives a speaker.

The important constraint is that there are no interrupts. The matrix is visible only because the CPU keeps scanning it. Sound and score display only continue because the same loop keeps servicing them. Game logic has to fit around that hardware maintenance.

This tour follows the TETRO code as it now stands. The shared loop, scan tick, LCD, HUD, sound, and framebuffer contracts are covered in [shared-codebase.md](shared-codebase.md).

---

## Source layout

The Debug80 target is still the top-level file:

```text
src/tetro.asm
```

That file owns the `ORG`, the reset entry, the main loop, and the include order. Debug80 can treat it as the TETRO target without needing to know how the internal files are arranged.

The current TETRO include order is:

```asm
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
```

The include order is deliberate. `shared/scan_tick.asm` calls `SERVICE_SOUND` and `SCAN_SCORE_DIGIT` before their labels appear in the include stream. `asm80` resolves those forward references. The pattern keeps scanout generic while letting the program decide which sound and HUD services satisfy the calls.

The split is intentional. Files under `src/shared/` are generic hardware or buffer routines that can serve more than one game. Files under `src/games/tetro/` contain TETRO's rules, state, tables, and game-specific wrappers.

This is still a careful harmonisation, not a large engine abstraction. Shared files are the small, stable pieces: scan tick, LCD primitives, score digit scanning, sound state machine, and framebuffer core helpers. TETRO keeps its own rules, board representation, scoring events, piece data, and presentation choices.

---

## Runtime model

```asm
MAIN_LOOP:
    CALL    SCAN_TICK
    CALL    LOGIC_TICK
    JR      MAIN_LOOP
```

Those three instructions in `src/tetro.asm` are the whole runtime. TETRO uses the shared cooperative loop described in [shared-codebase.md](shared-codebase.md): `SCAN_TICK` keeps the hardware alive, and `LOGIC_TICK` performs one slice of game work.

This means the display, score digits, speaker, keypad, gravity, rendering, and line-clear timing all share the same cooperative clock.

---

## Logic dispatch

`LOGIC_TICK` lives in `games/tetro/logic_dispatch.asm`. It starts by sanitizing the active piece position, then chooses the highest-priority game mode.

The priority is:

1. Game over.
2. Splash.
3. Line-clear hold.
4. Pause.
5. Input lockout.
6. Active play.

The order is part of the design. During game over, only restart gating matters. During a line-clear hold, the active piece is disabled and the next spawn waits. During input lockout, the key that dismissed the splash or restarted the game is not allowed to become a gameplay move.

In active play, `LOGIC_SLICE` selects one of eight slices:

```text
slice 0      poll input, clear framebuffer-back row 0
slice 1      apply gravity, clear row 1
slices 2-6   clear one back-buffer row each
slice 7      clear row 7, render board, render active piece, copy back to front
```

The back buffer is cleared gradually so no single loop pass does all the work. Slice 7 composes the finished frame and copies it to `FRAMEBUFFER`, which the next scan pass reads.

---

## RAM layout

TETRO's mutable state is in `games/tetro/ram.asm`.

The RAM file is arranged around the systems that mutate it:

- active-piece state
- pending movement and rotation state
- input repeat state
- pause, splash, game-over, and line-clear flags
- score and line counters
- HUD and speaker state
- frame/slice counters
- scan state and framebuffers
- landed board occupancy and colour planes

The active piece state includes:

- `PLAYER_X`, `PLAYER_Y`
- `CURRENT_PIECE_PTR`
- `CURRENT_PIECE_INDEX`
- `CURRENT_ROTATION`
- `CURRENT_PIECE_RIGHT`
- `CURRENT_PIECE_COLOR`
- `ACTIVE_PIECE_ENABLED`

The pending fields are a small transaction buffer:

- `PENDING_X`
- `PENDING_Y`
- `PENDING_ROTATION`
- `SHIFT_COUNT`

Movement and rotation write candidates into pending state, run collision, and commit only if the placement is legal. That keeps failed moves invisible.

The board is split into four planes:

- `BOARD_ROWS` is the occupancy plane.
- `BOARD_RED`, `BOARD_GREEN`, and `BOARD_BLUE` are colour planes.

Collision reads only `BOARD_ROWS`. Rendering reads colour planes directly. This avoids unpacking colour data during collision and avoids reconstructing colour during rendering.

The framebuffer is double-buffered:

- `FRAMEBUFFER_BACK` is composed by the logic slices.
- `FRAMEBUFFER` is read by `SCAN_TICK`.

Both buffers are 32 bytes: eight rows, four bytes per row. The first three bytes are red, green, and blue. The fourth byte is padding.

The shared scanout does not know what these bytes represent as game state. It only emits the front buffer. TETRO owns the meaning of the board planes and active-piece state that produce those bytes.

---

## Initialization and restart

`games/tetro/game_init.asm` owns startup and restart.

`INIT_STATE` calls `INIT_STATE_BASE`, enables the splash state, shows the splash LCD script, and rebuilds the framebuffer.

`INIT_STATE_BASE` resets TETRO state: movement cooldown, gravity period, game-over flags, clear flags, score, LCD/HUD scan state, sound state, scan mask, scan pointer, board planes, and score digits.

The splash screen is not idle. The main loop keeps scanning the matrix, servicing sound, scanning the score display, and incrementing `FRAME_PHASE` once per full matrix wrap. When the player presses a key, `HANDLE_SPLASH_STATE` uses `FRAME_PHASE` as `RNG_SEED`. If the key arrives before any wrap, it falls back to `RNG_SEED_INIT`.

`INIT_STATE_RESTART` is the post-game-over path. It clears the board and score but does not reset the RNG seed. A restart continues the pseudo-random stream instead of returning to the same first pieces.

---

## Collision

`games/tetro/collision.asm` provides the placement test used by spawn, movement, rotation, gravity, and lock.

`CHECK_COLLISION_AT_DE` takes:

```text
D = candidate x
E = candidate y
```

It returns carry set if the placement is illegal.

The routine first checks horizontal bounds. `CURRENT_PIECE_RIGHT` lets it test the right edge without scanning the bitmap. If the piece is outside the left or right wall, it returns immediately.

If the horizontal bounds pass, it walks the four rows of the current piece bitmap. Each bitmap row is shifted by `SHIFT_ROW_MASK` using the candidate x. Empty rows are skipped. Rows above the visible field are allowed, because pieces spawn partly above the display. Rows below the field are collisions.

For visible rows, the shifted mask is ANDed with the matching row in `BOARD_ROWS`. A non-zero result means the active piece overlaps a landed cell.

`CHECK_TOP_OUT_ON_LOCK` is separate. It detects the loss condition where a piece locks while any occupied bitmap row is still above the visible field.

---

## Movement, gravity, and rotation

`games/tetro/piece_active.asm` owns active-piece movement, rotation, gravity, spawning, and random piece selection.

Every movement uses the same pattern:

```text
write candidate position
call CHECK_COLLISION_AT_DE
commit only if carry is clear
```

`MOVE_LEFT` and `MOVE_RIGHT` update `PENDING_X` and call `HORIZONTAL_PROBE_APPLY_PENDING_X`. That helper copies the current y into `PENDING_Y`, tests collision, and commits the candidate x only on success.

`STEP_ACTIVE_DOWN_ONE_CELL` is shared by gravity and soft drop. `APPLY_GRAVITY` waits for `GRAVITY_COOLDOWN` to expire, then probes one row down. If the probe fails, it calls `LOCK_ACTIVE_PIECE`. `SOFT_DROP` skips the cooldown and probes immediately. If soft drop locks a piece, it sets `DROP_LOCKOUT` so a held drop key does not immediately force the next piece down.

Rotation changes the bitmap, not the position. `ROTATE_CW` and `ROTATE_LEFT` save the previous rotation, load the candidate rotation state, then test collision at the current position. If the test fails, the old rotation and metadata are restored. There is no wall kick. On success, TETRO plays the rotate sound and resets the gravity cooldown.

`RNG_NEXT8` is an 8-bit shift-register generator. `RNG_NEXT_PIECE` folds higher bits into lower bits, masks to three bits, and retries when the value is 7. That gives piece indices 0 through 6.

---

## Lock, line clear, and score

`games/tetro/board_lock.asm` owns the transition from active piece to board.

`LOCK_ACTIVE_PIECE` first calls `CHECK_TOP_OUT_ON_LOCK`. If the active piece is still partly above the visible field, TETRO merges it into the board and enters game over.

Otherwise, `MERGE_ACTIVE_TO_BOARD` writes the shifted active piece into `BOARD_ROWS` and into the colour planes selected by `CURRENT_PIECE_COLOR`. It uses the same `SHIFT_ROW_MASK` routine as collision and rendering, so the cells that collide, draw, and merge are the same cells.

`CHECK_FULL_ROWS` scans `BOARD_ROWS` for `0xFF`. Full rows are recorded in `CLEAR_MASK`.

If no row is full, TETRO plays the lock sound and immediately spawns the next piece.

If one or more rows are full, TETRO plays the clear sound, sets `CLEAR_PENDING`, loads `CLEAR_TIMER`, and disables the active piece. Rendering draws rows in `CLEAR_MASK` as white while the timer counts down. When the timer expires, `COLLAPSE_FULL_ROWS` removes the rows, `APPLY_CLEAR_SCORE` updates score and gravity speed, and the next piece spawns.

The score table is data-driven:

```text
1 row  = 100
2 rows = 300
3 rows = 500
4+ rows = 800
```

When the score reaches the configured threshold, `CURRENT_GRAVITY_PERIOD` changes from `GRAVITY_PERIOD` to `GRAVITY_PERIOD_STEP1`.

---

## Rendering

Rendering is split between shared buffer helpers and TETRO-specific drawing.

`shared/framebuffer_core.asm` provides:

- `CLEAR_BACK_ALL`
- `CLEAR_BACK_4`
- `COPY_BACK_TO_FRONT`

Those routines know only about the 8x8 RGB framebuffer layout.

`shared/framebuffer.asm` currently contains TETRO-aware rendering:

- `REBUILD_FRAMEBUFFER`
- `CLEAR_BOARD`
- `RENDER_BOARD_TO_BACK`
- `RENDER_ACTIVE_TO_BACK`
- `WRITE_COLORED_ROW_MASK`

`RENDER_BOARD_TO_BACK` copies landed colour planes into the back buffer. During a line-clear hold, rows in `CLEAR_MASK` become white. During game over, occupied cells are rendered as a red silhouette.

`RENDER_ACTIVE_TO_BACK` draws the falling piece on top. It shifts each bitmap row by `PLAYER_X`, skips rows outside the visible field, and ORs the row mask into the selected colour channels.

The active piece is rendered after the board. Collision has already ensured it does not overlap landed cells, so the OR operation is safe.

---

## LCD, HUD, and sound

The LCD stack is split into shared primitives and TETRO screens.

`shared/lcd.asm` knows how to talk to the HD44780 and how to execute a simple script table. A script is a list of row-command bytes and string pointers, terminated by zero.

TETRO screen scripts live in `games/tetro/data.asm`:

- splash
- running
- paused
- game over

`games/tetro/ui.asm` selects those scripts. Running and paused screens go through `LCD_SHOW_HUD`, which appends the next-piece letter after the `NEXT: ` label. `LCD_REFRESH_NEXT_PREVIEW_ROW` updates only that preview row after a successful spawn.

The seven-segment path is split the same way. `shared/hud.asm` scans one digit per `SCAN_TICK`. `games/tetro/hud.asm` updates `HUD_SEG_BUFFER` when the score changes.

The sound path follows the same pattern. `shared/sound.asm` runs the speaker state machine. `games/tetro/sound.asm` names the TETRO events and loads their tuning constants.

---

## Shared versus TETRO-specific code

Currently shared and generic:

- `shared/inc/constants.asm`: hardware ports, MON-3 keys, colours, dimensions
- `shared/scan_tick.asm`: matrix scanout and scan-state advance
- `shared/framebuffer_core.asm`: back-buffer clear and copy
- `shared/sound.asm`: speaker divider service
- `shared/hud.asm`: seven-segment scan and blanking
- `shared/lcd.asm`: HD44780 primitive operations and script renderer

Currently TETRO-specific:

- `games/tetro/constants.asm`: movement, gravity, scoring, spawn, and sound tuning
- `games/tetro/game_init.asm`: cold start, restart, and state initialization
- `games/tetro/logic_dispatch.asm`: TETRO state priority and 8-slice schedule
- `games/tetro/piece_active.asm`: movement, gravity, rotation, RNG, and spawn
- `games/tetro/collision.asm`: active-piece placement and top-out checks
- `games/tetro/board_lock.asm`: merge, line clear, scoring, and game-over entry
- `games/tetro/geometry_helpers.asm`: pending-position and row-mask helpers
- `games/tetro/sound.asm`: TETRO sound event wrappers
- `games/tetro/hud.asm`: TETRO score formatting
- `games/tetro/ui.asm`: TETRO LCD screens and next-piece preview
- `games/tetro/data.asm`: pieces, colours, LCD scripts, score tables, glyphs
- `games/tetro/ram.asm`: TETRO state layout

Likely future shared candidates are the decimal score formatter, the row-mask shifting convention, and the colour-row writing helper. They remain local because their labels and assumptions still differ between games. Promoting them too early would couple TETRO and Pacmo to accidental details instead of a stable shared contract.

---

## Data tables

`games/tetro/data.asm` contains display tables and piece data.

Most static TETRO data lives here: piece bitmaps, rotation lookup tables, colour tables, LCD text, LCD scripts, score values, row masks, digit masks, and seven-segment glyphs.

The piece tables are parallel:

- `PIECE_PTR_TABLE` points to the 4-row bitmap for each piece and rotation.
- `PIECE_RIGHT_TABLE` stores the rightmost occupied column for bounds checks.
- `PIECE_COLOR_TABLE` stores the RGB colour mask for each piece.

Each bitmap row is an 8-bit mask. The occupied cells are in the high bits before shifting, and `SHIFT_ROW_MASK` moves them into the board position at runtime.

The same file also contains:

- seven-segment glyphs
- digit select masks
- row bit masks
- line-clear score values
- LCD strings
- LCD script tables
- piece preview letters

Changing a message, score value, colour, piece bitmap, preview letter, or LCD screen is usually a data edit rather than a logic edit.

---

## A piece from spawn to lock

On boot, `INIT_STATE` clears TETRO state, shows the splash, and rebuilds the framebuffer. The main loop starts immediately. `SCAN_TICK` keeps the matrix alive, score digits blank, and frame counter moving.

When the player presses a key on the splash screen, `HANDLE_SPLASH_STATE` seeds the RNG, generates the first next-piece index, sets `INPUT_LOCKOUT`, spawns the first active piece, initializes the score display, shows the running LCD screen, and rebuilds the framebuffer.

`SPAWN_ACTIVE_PIECE` promotes `NEXT_PIECE_INDEX` to `CURRENT_PIECE_INDEX`, generates a new upcoming piece, sets the spawn position, resets movement and gravity cooldowns, and tests collision at the spawn point. If spawn collides immediately, TETRO enters game over.

During play, slice 0 polls input. The keypad mapping is handled in `shared/input.asm`; TETRO supplies the movement and rotation routines that the input code calls. Left and right key codes are intentionally mirrored to match the physical display orientation:

```asm
K_LEFT:         EQU     0x11
K_RIGHT:        EQU     0x10
```

Slice 1 applies gravity. If the downward probe succeeds, the piece moves down. If it fails, `LOCK_ACTIVE_PIECE` merges or ends the game.

Slices 2 through 6 clear rows of the back buffer. Slice 7 finishes the clear, renders board and active piece, and copies the back buffer to the live framebuffer.

When a piece locks, TETRO checks top-out, merges into the board, checks full rows, and either spawns immediately or enters the line-clear hold. Completed rows flash white, collapse, update the score, and then the next piece spawns.

Game over leaves the loop running. The matrix, score display, LCD, and speaker are still serviced. After the key gate expires, a new key press calls `INIT_STATE_RESTART`.

---

## Map

```text
target
  src/tetro.asm
    ORG, START, MAIN_LOOP, include order

shared hardware helpers
  shared/scan_tick.asm
    SCAN_TICK -> SERVICE_SOUND, SCAN_SCORE_DIGIT, ADVANCE_SCAN_STATE
  shared/sound.asm
    SOUND_START, SERVICE_SOUND
  shared/hud.asm
    SCAN_SCORE_DIGIT, BLANK_HUD_SCORE_DIGITS
  shared/lcd.asm
    LCD_BUSY, LCD_COMMAND, LCD_STRING, LCD_SHOW_SCRIPT, LCD_PUTC
  shared/framebuffer_core.asm
    CLEAR_BACK_ALL, CLEAR_BACK_4, COPY_BACK_TO_FRONT

TETRO wrappers and presentation
  games/tetro/sound.asm
    SOUND_TRIGGER_ROTATE, LOCK, CLEAR, GAME_OVER
  games/tetro/hud.asm
    UPDATE_SCORE_DISPLAY
  games/tetro/ui.asm
    LCD_SHOW_SPLASH, RUNNING, PAUSED, GAME_OVER, NEXT preview

TETRO rules
  games/tetro/game_init.asm
    cold start, restart, and state initialization
  games/tetro/logic_dispatch.asm
    LOGIC_TICK and 8-slice scheduler
  games/tetro/piece_active.asm
    movement, gravity, rotation, RNG, spawn
  games/tetro/collision.asm
    CHECK_COLLISION_AT_DE, CHECK_TOP_OUT_ON_LOCK
  games/tetro/board_lock.asm
    lock, merge, line clear, score, game over
  games/tetro/geometry_helpers.asm
    pending-position loading and row-mask shifting
  shared/framebuffer.asm
    TETRO board/active rendering over shared framebuffer core

state and data
  games/tetro/ram.asm
    all mutable TETRO state
  games/tetro/data.asm
    pieces, colours, score table, LCD scripts, glyph tables
```
