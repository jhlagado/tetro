# TETRO

A 7-piece falling-block game for the **TEC-1G** single-board Z80 computer, running under **MON-3**. Seven tetromino shapes drift down an **8×8 RGB LED matrix**, and the player nudges them around with the MON-3 keypad while a **16×4 HD44780 LCD** carries the status banner and a **6-digit 7-segment display** scores every landed line.

All I/O is driven from one cooperative scan-tick main loop — no interrupts, no **`HALT`**, no `delay()`. One display row is emitted per tick, game logic runs in eight slices across each frame, and the sound engine toggles the speaker bit from the same loop. That structure is the point of the project: prove that a coherent interactive game fits into the TEC-1G's software-scan budget without anything fancy.

> **Not affiliated with or derived from any Tetris® product.** TETRO is a hobby falling-block implementation for education and experimentation on retro hardware. _All wrongs reserved._

---

## Hardware requirements

- **TEC-1G** single-board computer (Z80 CPU + RAM + MON-3 monitor firmware in ROM).
- **8×8 RGB LED matrix** panel wired to TEC-1G expansion ports. The panel is driven as three bit-planes (`PORT_RED`, `PORT_GREEN`, `PORT_BLUE`) with row-select on `PORT_ROW` — one row at a time, software-multiplexed.
- **HD44780 character LCD** (16×2 or 20×4) on `PORT_LCD_INST` / `PORT_LCD_DATA`.
- **6-digit 7-segment display** multiplexed across `PORT_DIGITS` / `PORT_SEGS`.
- **Speaker** driven from bit 7 of `PORT_DIGITS` (shared latch, time-sliced with the digit select).

All port assignments are collected in [`src/inc/constants.asm`](src/inc/constants.asm); change them there if your board has a different layout.

---

## Controls

TETRO uses the MON-3 key codes, which are available to any MON-3 program via `RST 0x10 / API_SCANKEYS`.

| Key       | Code   | Action                                                       |
| --------- | ------ | ------------------------------------------------------------ |
| `<`       | `0x10` | Move piece left (held-repeat at `MOVE_PERIOD`)               |
| `>`       | `0x11` | Move piece right (held-repeat at `MOVE_PERIOD`)              |
| `GO`      | `0x12` | Rotate clockwise                                             |
| `AD`      | `0x13` | Rotate counter-clockwise                                     |
| `3`       | `0x03` | Rotate clockwise (alternate)                                 |
| `2`       | `0x02` | Rotate counter-clockwise (alternate)                         |
| `0`       | `0x00` | Soft drop (held-repeat at `DROP_PERIOD`)                     |
| `F`       | `0x0F` | Pause / resume                                               |
| _any key_ | —      | Start game from splash, or restart after the Game-Over delay |

Holding a direction key auto-repeats every `MOVE_PERIOD` scan ticks; rotation is edge-triggered (press again to rotate again — no auto-rotate).

---

## Gameplay

- **Seven pieces** — the classic falling-block set (`I`, `O`, `T`, `S`, `Z`, `J`, `L`), each with its own colour on the matrix:
  - `I` cyan, `O` white, `T` magenta, `S` green, `Z` red, `J` blue, `L` yellow.
- **Four rotations per piece**, stored as precomputed 4-row bitmaps in ROM. Rotationally-symmetric pieces (`I`, `O`, `S`, `Z`) alias their duplicates via `EQU`.
- **Gravity** is frame-gated by `CURRENT_GRAVITY_PERIOD` (default `160` scan cycles between steps). Each multi-line clear shaves `GRAVITY_PACE_DELTA` off the period down to a floor of `GRAVITY_PERIOD_MIN`, so the game accelerates for skilled play (see closed GitHub issue **#17**).
- **Soft drop** accelerates the active piece using a short `DROP_PERIOD`; a one-shot `DROP_LOCKOUT` stops the drop from immediately locking the next piece.
- **Rotation** is wall-tested via the same collision path used for lateral movement — a rotation that would overlap landed cells or leave the board is reverted (no SRS-style kick table).
- **Line clear** — completed rows flash white for `LINE_CLEAR_HOLD` scan cycles, then collapse. Scoring follows the classic 100 / 300 / 500 / 800 schedule for 1 / 2 / 3 / 4 rows cleared simultaneously (from [`CLEAR_SCORE_TABLE`](src/modules/data.asm)).
- **Top-out** — if a newly-spawned piece immediately collides, or a locked piece leaves landed cells above the visible field, the game ends.

---

## HUD layout

TETRO drives three independent displays simultaneously from the same scan-tick loop.

### 8×8 RGB matrix

- **Landed cells** are stored as monochrome occupancy (`BOARD_ROWS`) plus three RGB bit-planes (`BOARD_RED`, `BOARD_GREEN`, `BOARD_BLUE`). Every frame, the logic slices compose those planes into `FRAMEBUFFER_BACK` and copy to `FRAMEBUFFER` atomically in slice 7 — no tearing.
- **Active piece** is an OR-blit of a 4-row bitmap in the current piece colour.
- **Line-clear flash** — rows in `CLEAR_MASK` render solid white (`0xFF` on all three planes) for the duration of `CLEAR_TIMER`.
- **Game-over** — the playfield renders `BOARD_ROWS` occupancy into the **red plane only**, with green and blue cleared. Result: uniform red silhouette of the final board while the LCD banner declares `GAME OVER` and the speaker plays the death tone.

### HD44780 LCD

Four canonical screens, all driven by `LCD_SHOW_SCRIPT` against data tables in [`src/modules/data.asm`](src/modules/data.asm):

| State         | Row 1                 | Row 2           | Row 3          | Row 4            |
| ------------- | --------------------- | --------------- | -------------- | ---------------- |
| **Splash**    | `TETRO (PRESS A KEY)` | `< > MOVE`      | `AD/GO ROTATE` | `0 DROP F PAUSE` |
| **Running**   | `TETRO RUNNING`       | `NEXT: X`       | _(blank)_      | _(blank)_        |
| **Paused**    | `TETRO PAUSED`        | `NEXT: X`       | _(blank)_      | _(blank)_        |
| **Game Over** | `TETRO GAME OVER`     | `PRESS ANY KEY` | _(blank)_      | _(blank)_        |

The **NEXT piece letter** is refreshed on every successful spawn by `LCD_REFRESH_NEXT_PREVIEW_ROW`, which rewrites row 2 in place (no full-LCD clear) so the row-1 banner persists.

### 6-digit 7-segment score

`SCAN_SCORE_DIGIT` is called once per `SCAN_TICK`; it time-multiplexes the six HUD digits and the speaker output through the shared `PORT_DIGITS` latch. `UPDATE_SCORE_DISPLAY` refreshes `HUD_SEG_BUFFER` whenever `SCORE` changes, writing each decimal digit of the 16-bit score via a classic "subtract-until-below-divisor" loop.

### Speaker (PWM via `SERVICE_SOUND`)

Five distinct cues, each a `(length, divider)` pair:

| Cue           | Trigger                    | Feel                                          |
| ------------- | -------------------------- | --------------------------------------------- |
| Rotate        | successful rotation        | very short, high                              |
| Lock          | piece locks in place       | short, mid                                    |
| Clear         | one or more lines cleared  | longer, bright                                |
| Game over     | top-out                    | long, low "dying" drone                       |
| Restart ready | game-over key-gate expires | short, high chirp — permission to press a key |

All tuning constants live in [`src/inc/constants.asm`](src/inc/constants.asm) (`SOUND_*_LEN` / `SOUND_*_DIV`).

---

## Game-over flow

1. A piece locks but top-out is detected, **or** a newly-spawned piece immediately collides.
2. `ENTER_GAME_OVER` latches `GAME_OVER`, disables the active piece, loads the 16-bit `GAME_OVER_KEY_GATE` countdown from `GAME_OVER_KEY_GATE_TICKS`, triggers the game-over sound, and rebuilds the framebuffer so the red silhouette appears.
3. LCD switches to `TETRO GAME OVER` / `PRESS ANY KEY`.
4. During the countdown, `WAIT_GAME_OVER_KEY_GATE` decrements the gate once per `LOGIC_TICK`. **Key presses are ignored** — this is deliberate so that accidentally-held keys don't instantly restart the game.
5. When the gate reaches zero, `SOUND_TRIGGER_GAME_OVER_RESTART_READY` plays a short chirp and `POLL_GAME_OVER_RESTART` begins checking for a fresh key press.
6. On a key press, `INIT_STATE_RESTART` rebuilds state and spawns a new piece.

---

## Building

Requires **[asm80](https://www.npmjs.com/package/asm80)**. Paths in `.include` directives are resolved relative to the main source file, so assemble from `src/`:

```bash
mkdir -p build
(cd src && asm80 -m Z80 -t hex -o ../build/tetro.hex tetro.asm)
(cd src && asm80 -m Z80 -t bin -o ../build/tetro.bin tetro.asm)
```

The `build/` directory is intentionally untracked by git; `.hex` and `.bin` are rebuilt from source. The in-editor emulator metadata in the sibling [**`debug80`**](../debug80) project references `outputDir: build` and `mainFile: tetro.hex`.

---

## Running on hardware

1. Build a `.hex` or `.bin` as above.
2. Load into the TEC-1G at **`$4000`** (the `ORG` address in `src/tetro.asm`).
3. `GO 4000` from MON-3 — the splash screen appears on the LCD, the matrix is dark, digits are blank.
4. Press any key to start. The first piece spawns from the top-centre.

If you don't have a TEC-1G handy, the sibling `debug80` project provides an emulator target that loads `build/tetro.hex` directly.

---

## Source layout

```
src/
├── tetro.asm                  ; ORG, entry point, MAIN_LOOP, master .include list
├── inc/
│   └── constants.asm          ; ports, key codes, tuning EQUs
└── modules/
    ├── geometry_helpers.asm   ; LOAD_DE_FROM_PENDING, SHIFT_ROW_MASK
    ├── collision.asm          ; CHECK_COLLISION_AT_DE, CHECK_TOP_OUT_ON_LOCK
    ├── framebuffer.asm        ; CLEAR_/COPY_/RENDER_ for the 32-byte framebuffer
    ├── piece_active.asm       ; piece state machine, rotation tables, RNG, spawn
    ├── board_lock.asm         ; lock / merge / line-clear / collapse / score
    ├── game_init.asm          ; INIT_STATE*, one-shot RAM setup
    ├── scan_tick.asm          ; matrix scanline + advance state
    ├── logic_dispatch.asm     ; LOGIC_TICK slice dispatcher
    ├── input.asm              ; keypad poll, held-direction repeat, key-gate
    ├── ui.asm                 ; sound engine + 7-seg HUD + LCD driver + scripts
    ├── data.asm               ; piece bitmaps, LCD text / scripts, lookup tables
    └── ram.asm                ; RAM_START block, mutable state
```

The module order matches the `.include` order in [`src/tetro.asm`](src/tetro.asm); it was chosen so every `JR` falls within ±127 bytes of its target despite the split.

For a deeper walkthrough of the architecture (scan model, state machine, piece representation, collision contract, issue backlog), see [`design.md`](design.md).

For a routine-by-routine reference catalogue, see [`codebase.md`](codebase.md).

---

## Architecture in one page

```
MAIN_LOOP:
    CALL SCAN_TICK           ; 1 matrix row + 1 7-seg digit + service sound
    CALL LOGIC_TICK          ;   LOGIC_SLICE rotates 0..7; one slice per pass
    JR   MAIN_LOOP

LOGIC_TICK dispatch (per pass):
    if GAME_OVER:        WAIT_GAME_OVER_KEY_GATE  → POLL_GAME_OVER_RESTART
    elif SPLASH_TIMER:   HANDLE_SPLASH_STATE      ; wait for any-key
    elif CLEAR_PENDING:  HANDLE_LINE_CLEAR_STATE  ; flash hold, then collapse
    elif PAUSED:         POLL_INPUT_AND_UPDATE    ; accept F / unpause only
    elif INPUT_LOCKOUT:  WAIT_FOR_KEY_RELEASE
    else:                LOGIC_SL0..SL7           ; input, gravity, clear, render, copy
```

Each `LOGIC_SL*` slice does a small fixed amount of work plus clears 4 bytes of `FRAMEBUFFER_BACK`, so by the end of slice 7 the back buffer is fully cleared, the board and active piece are re-rendered into it, and it's copied to the live `FRAMEBUFFER` atomically. There are no interrupts, no `HALT`, and nothing that can tear mid-frame.

Gravity is also frame-gated in slice 1 via `GRAVITY_COOLDOWN` countdown; input polling runs every slice 0. Both can be disabled cleanly by the `CLEAR_PENDING` branch so line-clear flashes hold still while the timer runs.

---

## License

This repository is released under a permissive hobby license; details, attribution wording, and the _"all wrongs reserved"_ wordplay are in [`LICENSE`](LICENSE). The main source file [`src/tetro.asm`](src/tetro.asm) carries the same SPDX identifier.
