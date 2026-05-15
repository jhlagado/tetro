# Pacmo: a tour of the code

Pacmo is a maze game for the TEC-1G 8x8 RGB matrix. The visible display is not the whole world; it is an 8x8 window into a 15x15 maze. The player is a single bright pixel, the maze scrolls under that pixel where possible, and enemies move through the same world on their own timers.

The implementation follows the same hard constraint as TETRO: there are no interrupts and no background thread. Matrix scanout, speaker timing, score display, input, enemy movement, collision, and rendering all share one loop. Pacmo therefore uses the same scan/slice architecture, but its game logic is about a scrolling world, consumable paths, power mode, and monster records rather than falling pieces.

This document describes the current Pacmo code. The shared loop, scan tick, LCD, HUD, sound, and framebuffer contracts are covered in [shared-codebase.md](shared-codebase.md).

---

## Source layout

The Debug80 target is still the top-level file:

```text
src/pacmo.asm
```

That file owns the `ORG`, the reset entry, the main loop, and the include order. Debug80 can treat it as the Pacmo target without needing to know how the internal files are arranged.

The current Pacmo include order is:

```asm
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
.include "shared/framebuffer_core.asm"
.include "shared/framebuffer_draw.asm"
.include "games/pacmo/render.asm"
.include "shared/sound.asm"
.include "games/pacmo/sound.asm"
.include "shared/hud.asm"
.include "games/pacmo/hud.asm"
.include "shared/lcd.asm"
.include "games/pacmo/ui.asm"
.include "games/pacmo/data.asm"
.include "games/pacmo/ram.asm"
```

The include order is deliberate. `shared/scan_tick.asm` calls `SERVICE_SOUND` and `SCAN_SCORE_DIGIT` before their labels appear in the include stream. `asm80` resolves those forward references. The pattern keeps scanout generic while letting Pacmo decide which sound and HUD services satisfy the calls.

The split is intentional. Files under `src/shared/` are generic hardware or buffer routines that can serve more than one game. Files under `src/games/pacmo/` contain Pacmo's rules, state, tables, and game-specific wrappers.

This is still a careful harmonisation, not a large engine abstraction. Shared files are the small, stable pieces: scan tick, LCD primitives, score digit scanning, sound state machine, and framebuffer core helpers. Pacmo keeps its own maze rules, monster behaviour, rendering, score events, and presentation choices.

---

## Runtime model

```asm
MAIN_LOOP:
    CALL    SCAN_TICK
    CALL    LOGIC_TICK
    JR      MAIN_LOOP
```

Those three instructions in `src/pacmo.asm` are the whole runtime. Pacmo uses the shared cooperative loop described in [shared-codebase.md](shared-codebase.md): `SCAN_TICK` keeps the hardware alive, and `LOGIC_TICK` performs one slice of game work.

This means the display, score digits, speaker, keypad, scrolling, monster movement, rendering, and level timing all share the same cooperative clock.

---

## Logic dispatch

Pacmo's `LOGIC_TICK` is a slice dispatcher. It spreads game work across eight passes through the main loop so scanout keeps happening between chunks of logic.

Slice 0:
- polls movement input
- ticks the level-complete gate
- ticks the power-mode timer
- clears framebuffer row 0 in the back buffer

Slice 1:
- ticks each active monster
- checks whether any active monster now shares the player's cell
- clears framebuffer row 1

Slices 2 through 6:
- clear one row of `FRAMEBUFFER_BACK`

Slice 7:
- clears the final row
- renders the maze window
- renders visible power pills
- renders monsters
- renders the player
- copies `FRAMEBUFFER_BACK` to `FRAMEBUFFER`

The generic helpers for clearing and copying live in `src/shared/framebuffer_core.asm`: `CLEAR_BACK_ALL`, `CLEAR_BACK_4`, and `COPY_BACK_TO_FRONT`. Pacmo still owns the actual rendering because the maze, eaten-path mask, power pills, player state, and monster state are game-specific.

---

## World, viewport, and coordinates

The world is a 15x15 grid. It is stored in `PACMO_WORLD_ROWS` as two bytes per row: a high byte and a low byte. Bit 15 is world column 0. Bit 1 is world column 14. Bit 0 is outside the maze and is forced on during completion checks so the unused bit does not prevent the level from completing.

The viewport is 8x8. `VIEW_X` and `VIEW_Y` are the world coordinates of the visible top-left cell. `PLAYER_X` and `PLAYER_Y` are world coordinates. Rendering converts world to screen with subtraction:

```text
screenX = worldX - VIEW_X
screenY = worldY - VIEW_Y
```

Only cells whose screen coordinates are in `0..7` are drawn.

Horizontal movement looks inverted if you think in byte bit order. On the matrix, screen x 0 is the leftmost visible column and maps to the most significant bit. Pacmo therefore uses the display convention, not the usual "bit 0 is rightmost" mental model. The shared key constants now reflect the learned keypad truth:

- `K_LEFT  = 0x11`
- `K_RIGHT = 0x10`

The Pacmo movement directions then preserve visual meaning. `PACMO_DIR_LEFT` moves visually left, even though the underlying world x update increments in the current bit mapping; `PACMO_DIR_RIGHT` moves visually right and decrements x.

---

## Input and movement

`POLL_INPUT_AND_UPDATE` lives in `movement.asm`. It blocks movement while the splash screen is active, while the player is caught, and while the round-complete delay is active.

Input comes from MON-3 through:

```asm
LD      C,API_SCANKEYS
RST     0x10
```

Pacmo normalizes raw keys into movement intents. The game logic does not care whether "up" came from ADD or key 8. The current mappings are:

- `K_LEFT` -> `PACMO_DIR_LEFT`
- `K_RIGHT` -> `PACMO_DIR_RIGHT`
- key 5 -> `PACMO_DIR_RIGHT`
- ADD / `K_ROTATE_CCW` -> `PACMO_DIR_UP`
- key 8 -> `PACMO_DIR_UP`
- GO / `K_ROTATE` -> `PACMO_DIR_DOWN`
- key 0 -> `PACMO_DIR_DOWN`

Held-key movement is throttled by `MOVE_COOLDOWN` and `LAST_KEY`. A new direction gets a one-tick cooldown so it moves promptly; a held direction reloads from `PACMO_MOVE_PERIOD`.

Each move constructs a candidate coordinate in `B` and `C`, then calls `TRY_MOVE_PLAYER_TO_BC`. That routine rejects walls via `PACMO_IS_WALL_AT_BC`, commits `PLAYER_X/Y` on success, consumes a power pill if present, marks the path as eaten, checks for round completion, checks monster collision, and updates the viewport.

---

## Scrolling

`UPDATE_VIEWPORT_FOR_PLAYER` keeps the player near the middle of the visible 8x8 window. Because the window has no single centre cell, Pacmo uses a comfort band: screen positions 3 and 4. If the player moves outside that band, the corresponding view origin moves by one cell, unless it is already clamped at the world edge.

`ADJUST_VIEW_AXIS` implements the rule for one axis:

- if `player - view < 3`, decrement the view origin if possible
- if `player - view >= 5`, increment the view origin if possible
- otherwise leave it alone
- clamp to `0..PACMO_VIEW_MAX`

For a 15x15 world and an 8x8 viewport, `PACMO_VIEW_MAX` is 7. At the world edges the view stops scrolling and the player moves away from the centre. In the middle of the world, the viewport does most of the visible movement.

---

## Maze consumption and scoring

Pacmo treats every open path cell as something to consume. The maze initially renders walls and uneaten paths. When the player enters an open cell, `PACMO_MARK_EATEN_AT_BC` sets the corresponding bit in `PACMO_EATEN_ROWS`.

`PACMO_EATEN_ROWS` mirrors the world row format: two bytes per row for the 15 columns. The render path ORs the wall mask with the eaten mask, then inverts the result to get the visible uneaten path mask. Eaten paths render as black.

Scores are 16-bit and displayed on the six seven-segment digits. The event values are:

- path cell: 10
- power pill: 50
- fleeing monster: 200

`PACMO_ADD_SCORE_A` adds an 8-bit event value to `PACMO_SCORE`, then calls `UPDATE_SCORE_DISPLAY`.

`src/shared/hud.asm` handles scanning the six digits and owns the decimal formatter. `src/games/pacmo/hud.asm` is a local wrapper: it loads `PACMO_SCORE`, points at `HUD_SEG_BUFFER`, and tail-calls the shared HUD formatter.

---

## Power pills and power mode

Power pills are stored as x,y pairs in `PACMO_POWER_PILLS`, terminated by `0xFF`. The eaten state is a bit mask in `PACMO_POWER_PILLS_EATEN`, one bit per listed pill.

When the player enters a power-pill cell, `PACMO_CONSUME_POWER_PILL_AT_BC`:

- sets the corresponding eaten bit
- adds `PACMO_SCORE_POWER`
- starts the Pacmo power-pill sound
- loads `PACMO_POWER_TIMER`
- sets all monster states to `PACMO_ENEMY_STATE_FLEE`
- updates the LCD to the power-mode screen

Power mode is global for monsters that are already active. `TICK_POWER_TIMER` decrements the 16-bit timer once per slice-0 pass. When it reaches zero, all monster states return to attack and the LCD returns to the running screen.

Rendering uses the timer for a warning blink. A fleeing monster normally uses `PACMO_COLOR_ENEMY_FLEE`. Near the end of the timer, the low byte is masked with `PACMO_POWER_WARNING_BLINK_MASK`, and the monster alternates between flee and attack colour.

If the player eats a fleeing monster, that monster enters respawn state. Other monsters remain in their current state; eating one monster does not cancel the global power timer.

---

## Monsters

Monsters are records in RAM. `MONSTER_SIZE` is six bytes:

- x
- y
- direction
- timer
- respawn timer
- state

There are currently three records: `MONSTER0`, `MONSTER1`, and `MONSTER2`. Level 1 uses two monsters. Level 2 and above include the third.

`TICK_ENEMY` is passed a monster record in `IX`. It returns immediately during splash, caught, or round-complete states. If the monster is respawning, `TICK_ENEMY_RESPAWN` counts down and keeps the monster hidden. Otherwise, the movement timer decrements. When the timer reaches zero, it reloads from `ENEMY_PERIOD_CURRENT` and chooses movement based on state.

Attack mode uses a greedy chase. `ENEMY_CHASE_DIRS` compares horizontal and vertical distance to the player and returns a preferred direction and secondary direction. `ENEMY_ATTACK_STEP` tries the preferred direction, then the secondary direction, while avoiding immediate reversal. If both fail, it falls back to roam.

Flee mode uses `ENEMY_ROAM_STEP`. It is deterministic rather than random. The first candidate direction is derived from the monster's x, y, current direction, and current level; then it rotates through up to four directions, skipping the immediate reverse unless no other move works. This gives wandering behaviour without a PRNG.

Movement commits through `ENEMY_TRY_MOVE_DIR`, which checks bounds, probes walls with `PACMO_IS_WALL_AT_BC`, and writes the new x, y, and direction only when the move succeeds.

---

## Collision and respawn

Player/monster collision is checked by `PACMO_CHECK_PLAYER_CAUGHT`, again with the monster record in `IX`.

If the monster is respawning, it cannot collide. If x and y differ, there is no collision. If the monster is in flee state, `PACMO_CONSUME_ENEMY` hides it, starts its respawn timer, plays the eaten sound, updates the LCD, and adds score. Otherwise `PACMO_ENTER_GAME_OVER` latches the caught state, loads the restart gate, plays the caught sound, updates the LCD, and rebuilds the framebuffer.

Respawn is deliberately not "return to a fixed home cell." When a respawn timer expires, `ENEMY_SELECT_RESPAWN` scans `PACMO_ENEMY_SPAWNS`. Each candidate is scored. A candidate currently visible in the viewport scores zero. A candidate less than eight cells from the player scores zero. Otherwise the score is:

```text
distance from player + distance from other active monsters
```

The best candidate wins, with ties keeping the earlier table entry. This keeps respawns off-screen, away from the player, and less likely to stack multiple monsters together.

When a monster respawns, its state is attack, its direction is right, and its movement timer reloads from `ENEMY_PERIOD_CURRENT`.

---

## Level completion and progression

The level is complete when every open cell in `PACMO_WORLD_ROWS` has been marked eaten in `PACMO_EATEN_ROWS`. `PACMO_CHECK_ROUND_COMPLETE` walks both byte streams row by row. It ORs world walls and eaten bits together. If both bytes in every row are effectively all ones, no uneaten open path remains.

On completion, Pacmo sets `PACMO_ROUND_COMPLETE`, loads `PACMO_LEVEL_COMPLETE_GATE`, plays the level-complete sound, and updates the LCD. During the gate the player cannot move. Rendering turns walls white and the player white, so completion is visible without destroying the maze display.

`TICK_LEVEL_COMPLETE_GATE` decrements the gate. When it expires, `PACMO_ADVANCE_LEVEL` increments `PACMO_LEVEL`, reduces `ENEMY_PERIOD_CURRENT` down toward `PACMO_ENEMY_PERIOD_MIN`, initializes a new level, and restores the running LCD.

Difficulty currently rises in two ways:

- level 2 enables the third monster
- later levels reduce the monster period by `PACMO_ENEMY_PERIOD_STEP` until the minimum is reached

---

## Rendering

Pacmo uses the shared double-buffer core and shared framebuffer draw primitives, but owns its renderers.

`REBUILD_FRAMEBUFFER` is a full redraw path used during initialization and state changes. The sliced render path in `LOGIC_TICK` is the normal steady-state path.

`RENDER_WORLD_TO_BACK` is the main maze renderer. It starts from `VIEW_Y`, reads eight world rows, and uses `WINDOW_BYTE_FROM_BC` to extract the visible eight bits from each 15-bit row. It also extracts the matching eaten bits from `PACMO_EATEN_ROWS`. Walls and uneaten paths are passed to `WRITE_WORLD_ROW_COLORS`, which writes red, green, and blue plane bytes according to the current palette.

Wall colour is state-dependent:

- normal: `PACMO_COLOR_WALL`
- player caught: `PACMO_COLOR_CAUGHT_WALL`
- round complete: `PACMO_COLOR_COMPLETE_WALL`

`RENDER_POWER_PILLS_TO_BACK` walks the power-pill table and draws only pills that are not eaten and are currently in the viewport.

`RENDER_ENEMY_TO_BACK` converts a monster's world x,y to screen x,y, skips off-screen and respawning monsters, chooses attack or flee colour, and writes one cell.

`RENDER_PLAYER_TO_BACK` draws the player last so it appears over paths, pills, and monsters. It is normally yellow. When the round is complete it is white. When caught it is red.

Single-cell overlays go through `FB_SET_CELL_COLOR`. The render path converts screen x coordinates with `MATRIX_X_TO_MASK`, then passes the framebuffer row pointer, cell bit mask, and colour bitfield to the shared cell writer. `FB_SET_CELL_COLOR` clears that bit from each RGB plane not present in the colour and sets it in each plane that is present. This matters because an enemy over a green path should render as red, not yellow from red plus green.

---

## LCD, score, and sound

LCD primitives are shared in `src/shared/lcd.asm`: busy wait, command write, string write, script runner, single-character output, row string writer, and table-character output. Pacmo-specific screens remain in `src/games/pacmo/ui.asm`.

The LCD screens are script tables in `data.asm`. Each script is a sequence of row command plus text pointer, terminated by zero. The running, power, and enemy-eaten screens call `LCD_REFRESH_LEVEL_ROW` after the script so row 2 shows the current level.

The score display is split. Shared `SCAN_SCORE_DIGIT` handles multiplexing, and shared `HUD_WRITE_U16_DECIMAL` converts the 16-bit score to segment patterns using repeated subtraction because the Z80 has no division instruction. Pacmo-local `UPDATE_SCORE_DISPLAY` is only the wrapper for `PACMO_SCORE`.

Sound is split the same way. Shared `SOUND_START` and `SERVICE_SOUND` implement the square-wave state machine. Pacmo-local sound wrappers in `src/games/pacmo/sound.asm` load event-specific duration and divider values:

- power pill
- fleeing monster eaten
- player caught
- level complete

There is no movement sound now; it was removed because it made the game noisier without adding useful information.

---

## Data layout

`data.asm` contains constants, LCD text, the world bitmap, power-pill positions, and respawn candidates. Most game tuning is here: move period, power timer, scoring, palette, monster speed, respawn delay, and level difficulty steps.

Most static Pacmo data lives here: the 15-row maze bitmap, power-pill table, enemy respawn table, colour constants, score values, sound durations, LCD strings, and LCD scripts. Changing a message, palette entry, score value, or respawn candidate is usually a data edit rather than a logic edit.

`ram.asm` is arranged around the systems that mutate it:

- player coordinates
- monster records
- viewport origin
- input repeat state
- splash flag
- HUD and speaker state
- score and HUD segment buffer
- frame/slice counters
- render scratch
- power-pill eaten mask and power timer
- round-complete and caught flags
- level and delay gates
- scan state and framebuffers
- eaten-path bitmap

`MONSTER0`, `MONSTER1`, and `MONSTER2` are contiguous records, and symbolic aliases such as `ENEMY_X` and `ENEMY2_TIMER` point into those records. New enemy code should prefer `IX` record access; the aliases exist mostly for initialization and readability.

The framebuffer is the same shape used by TETRO and the shared scanout: eight rows, four bytes per row. The first three bytes are red, green, and blue. The fourth is aux/padding and is cleared but not emitted by scanout.

---

## Shared versus Pacmo-specific code

Currently shared and generic:

- `shared/inc/constants.asm`: hardware ports, MON-3 keys, colours, dimensions
- `shared/scan_tick.asm`: matrix scanout and scan-state advance
- `shared/framebuffer_core.asm`: back-buffer clear and copy
- `shared/framebuffer_draw.asm`: matrix x-to-mask conversion and RGB framebuffer draw primitives
- `shared/sound.asm`: speaker divider service
- `shared/hud.asm`: seven-segment scan, blanking, digit/glyph tables, and decimal formatting
- `shared/lcd.asm`: HD44780 primitive operations, script renderer, row string writer, and table-character writer

Currently Pacmo-specific:

- `game_init.asm`: level/player/monster initialization
- `logic_dispatch.asm`: Pacmo slice schedule, power timer, monster AI, respawn, level progression
- `movement.asm`: input normalization, player movement, path/power consumption, game-over entry
- `render.asm`: maze, pills, monsters, player, and calls into shared cell-colour primitives
- `sound.asm`: Pacmo event sound names and durations
- `hud.asm`: Pacmo score display wrapper for the shared HUD formatter
- `ui.asm`: Pacmo LCD status screens
- `data.asm`: maze, palette, text, scoring, tuning, spawn tables
- `ram.asm`: Pacmo state layout

Pacmo score formatting goes through the shared HUD formatter via its local wrapper. Pacmo cell rendering uses `FB_SET_CELL_COLOR`, and Pacmo x-to-mask conversion uses `MATRIX_X_TO_MASK`.

---

## A complete play sequence

On boot, `INIT_STATE` clears the score, starts level 1, sets the base monster period, calls `INIT_LEVEL_STATE`, marks the splash active, and shows the Pacmo splash on the LCD.

`INIT_LEVEL_STATE` places the player at the centre of the 15x15 maze, initializes two or three monster records, sets the viewport origin to `(3,3)`, clears timers and flags, initializes scan state, clears the framebuffers and eaten-path map, marks the player's starting cell eaten without awarding score, updates the score display, and rebuilds the framebuffer.

The main loop runs. The matrix, HUD, and speaker are serviced continuously. While the splash flag is set, the first keypress clears it and shows the running LCD screen.

The player presses a movement key. `POLL_INPUT_AND_UPDATE` normalizes it into a direction and applies repeat timing. A move routine calculates a target cell. `TRY_MOVE_PLAYER_TO_BC` checks the wall map. If the target is a wall, nothing changes. If it is open, the player position is committed, power pills are consumed, the path is marked eaten, level completion is checked, monster collision is checked, and the viewport is adjusted.

Every logic frame, monsters tick. In attack mode they try to reduce distance to the player. In flee mode they roam. If a monster reaches the player in attack mode, Pacmo enters caught state. The walls turn red, the LCD says `PACMO CAUGHT`, the caught sound plays, and a restart gate prevents an immediate accidental restart.

If the player eats a power pill, all active monsters enter flee state for the timer duration. If the player catches a fleeing monster, that monster disappears and respawns later at the best off-screen candidate. Other monsters continue independently.

As the player eats paths, the green path cells turn black. When no open path cells remain uneaten, the level-complete flag is set. The walls turn white, the level-complete sound plays, the LCD reports completion, and a short gate runs. Then `PACMO_ADVANCE_LEVEL` increments the level, speeds monsters up within bounds, initializes the next level, and play resumes.

---

## Map

```text
target
  src/pacmo.asm
    ORG, START, MAIN_LOOP, include order

shared hardware helpers
  shared/scan_tick.asm
    SCAN_TICK -> SERVICE_SOUND, SCAN_SCORE_DIGIT, ADVANCE_SCAN_STATE
  shared/sound.asm
    SOUND_START, SERVICE_SOUND
  shared/hud.asm
    SCAN_SCORE_DIGIT, BLANK_HUD_SCORE_DIGITS
  shared/lcd.asm
    LCD_BUSY, LCD_COMMAND, LCD_STRING, LCD_SHOW_SCRIPT, LCD_PUTC, LCD_WRITE_ROW_STRING, LCD_PUTC_FROM_TABLE
  shared/framebuffer_core.asm
    CLEAR_BACK_ALL, CLEAR_BACK_4, COPY_BACK_TO_FRONT
  shared/framebuffer_draw.asm
    MATRIX_X_TO_MASK, FB_SET_CELL_COLOR, FB_OR_ROW_COLOR_MASK

Pacmo wrappers and presentation
  games/pacmo/sound.asm
    PACMO_SOUND_POWER, EAT_ENEMY, CAUGHT, LEVEL_COMPLETE
  games/pacmo/hud.asm
    UPDATE_SCORE_DISPLAY
  games/pacmo/ui.asm
    LCD_SHOW_PACMO_SPLASH, RUNNING, POWER, ENEMY_EATEN, CAUGHT, COMPLETE

Pacmo rules
  games/pacmo/logic_dispatch.asm
    LOGIC_TICK, power timer, monster AI, respawn, level progression
  games/pacmo/movement.asm
    input normalization, player movement, consumption, collision, scrolling
  games/pacmo/render.asm
    maze, pills, monsters, player, cell colour overlay
  games/pacmo/game_init.asm
    cold start, level initialization, framebuffer/eaten-path clearing

state and data
  games/pacmo/ram.asm
    all mutable Pacmo state
  games/pacmo/data.asm
    maze, palette, score values, LCD scripts, spawn tables
```
