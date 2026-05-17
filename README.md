# TEC-1G Game Suite

This repository contains small 8x8 RGB matrix games for the TEC-1G single-board Z80 computer running under MON-3.

The suite currently includes:

- **Tetro**: a 7-piece falling-block game.
- **Pacmo**: a scrolling maze game with consumable paths, power pills, and monsters.

Both games draw the 8x8 RGB LED matrix, use the MON-3 keypad for controls, show status on an HD44780 LCD, scan a six-digit seven-segment score display, and drive the speaker from the same cooperative loop. One matrix row is emitted per pass, sound and score scan from the same tick, and game logic is spread across eight slices.

The shared codebase is described in [docs/shared-codebase.md](docs/shared-codebase.md). The game-specific tours are in [docs/tetro-codebase.md](docs/tetro-codebase.md) and [docs/pacmo-codebase.md](docs/pacmo-codebase.md).

## Hardware

- TEC-1G single-board computer with MON-3.
- 8x8 RGB LED matrix wired as red, green, and blue bit planes plus row select.
- HD44780-compatible LCD on `PORT_LCD_INST` / `PORT_LCD_DATA`.
- Six-digit seven-segment display on `PORT_DIGITS` / `PORT_SEGS`.
- Speaker driven from bit 7 of `PORT_DIGITS`.

Port assignments and shared hardware/display constants live in [src/shared/inc/constants.asm](src/shared/inc/constants.asm).

## Tetro

Tetro is a compact falling-block game built around precomputed piece rotations, collision checks against an 8x8 landed board, row clears, scoring, gravity, pause, and restart flow.

### Tetro Controls

| Key | Code | Action |
| --- | ---: | --- |
| `<` | `0x11` | Move left |
| `>` | `0x10` | Move right |
| `GO` | `0x12` | Soft drop |
| `AD` | `0x13` | Rotate counter-clockwise |
| `C` | `0x0C` | Rotate clockwise |
| `1` | `0x01` | Move left |
| `3` | `0x03` | Move right |
| `2` | `0x02` | Soft drop |
| `6` | `0x06` | Rotate clockwise |
| `0` | `0x00` | Pause or resume |
| any key | | Start from splash, or restart after the game-over gate opens |

Movement repeats slowly while held. Soft drop repeats while held. Rotation is edge-triggered.

### Tetro Gameplay

- Pieces: `I`, `O`, `T`, `S`, `Z`, `J`, `L`.
- Piece colours: `I` cyan, `O` white, `T` magenta, `S` green, `Z` red, `J` blue, `L` yellow.
- Rotations are precomputed row bitmaps in ROM.
- Placement, movement, rotation, gravity, and spawn all use the same collision routine.
- Completed rows flash white, collapse, and score 100 / 300 / 500 / 800 for 1 / 2 / 3 / 4 rows.
- Gravity starts at `GRAVITY_PERIOD` and drops to `GRAVITY_PERIOD_STEP1` once the score reaches 2000.
- Game over occurs when a spawn collides immediately or a locked piece still occupies rows above the visible field.

## Pacmo

Pacmo is an 8x8 window into a larger 15x15 maze. The player consumes open paths, collects power pills, avoids attacking monsters, and can eat fleeing monsters during power mode. A new game starts with three lives; losing the final life shows `GAME OVER` on the LCD.

### Pacmo Controls

| Key | Code | Action |
| --- | ---: | --- |
| `<` | `0x11` | Move left |
| `>` | `0x10` | Move right |
| `AD` | `0x13` | Move up |
| `GO` | `0x12` | Move down |
| `1` | `0x01` | Move left |
| `3` | `0x03` | Move right |
| `5` | `0x05` | Move left |
| `6` | `0x06` | Move up |
| `7` | `0x07` | Move right |
| `A` | `0x0A` | Move up |
| `2` | `0x02` | Move down |
| `0` | `0x00` | Pause |
| any key | | Resume from pause |
| any key | | Start from splash, or restart after the caught gate opens |

Alternative inverted-T controls:

```text
      6 = up
1 = left   3 = right
      2 = down
```

Movement repeats slowly while held; tapping moves faster than waiting for repeat. The arrow keys and inverted-T keys normalize to the same Pacmo movement directions.

### Pacmo Display Legend

| Colour | Meaning |
| --- | --- |
| blue | Wall |
| green | Uneaten path |
| black | Eaten path |
| yellow | Player |
| white | Power pill, or round-complete state |
| red | Attacking monster, caught state, or game-over cue |
| magenta | Fleeing monster during power mode |

### Pacmo Gameplay

- The visible matrix is an 8x8 viewport into a 15x15 maze.
- Eaten paths disappear to black.
- Power pills turn monsters magenta and make them edible for a limited time.
- Eating a fleeing monster hides it until a respawn timer places it away from the player and visible viewport.
- Level 1 uses two monsters; level 2 and later add a third.
- Completing all open paths advances the level and speeds up monsters down to a minimum period.

## Build

Requires [asm80](https://www.npmjs.com/package/asm80). Assemble from `src/`, because `.include` paths are relative to the main source file.

```bash
mkdir -p build
(cd src && asm80 -m Z80 -t hex -o ../build/tetro.hex tetro.z80)
(cd src && asm80 -m Z80 -t bin -o ../build/tetro.bin tetro.z80)
(cd src && asm80 -m Z80 -t hex -o ../build/pacmo.hex pacmo.z80)
(cd src && asm80 -m Z80 -t bin -o ../build/pacmo.bin pacmo.z80)
```

The generated files under `build/` are outputs, not source.

## Run

Load the assembled program at `$4000`, matching the `ORG` in [src/tetro.z80](src/tetro.z80) or [src/pacmo.z80](src/pacmo.z80), then run:

```text
GO 4000
```

The LCD shows the selected game's splash screen. Press any key to start.

## Source Layout

```text
src/
|-- tetro.z80                  ; Debug80 target entry point and include order
|-- pacmo.z80                  ; Debug80 target entry point and include order
|-- shared/
|   |-- inc/
|   |   `-- constants.asm      ; ports, key codes, shared colour constants
|   |-- framebuffer_core.asm   ; generic back-buffer clear/copy helpers
|   |-- framebuffer_draw.asm   ; matrix masks and RGB draw primitives
|   |-- hud.asm                ; seven-segment scan and decimal formatting
|   |-- lcd.asm                ; HD44780 primitive operations and scripts
|   |-- scan_tick.asm          ; matrix row scan and scan-state advance
|   `-- sound.asm              ; speaker divider service
`-- games/
    |-- tetro/
    |   |-- constants.asm       ; Tetro tuning constants
    |   |-- geometry_helpers.asm
    |   |-- collision.asm
    |   |-- render.asm
    |   |-- piece_active.asm
    |   |-- board_lock.asm
    |   |-- game_init.asm
    |   |-- logic_dispatch.asm
    |   |-- input.asm
    |   |-- sound.asm
    |   |-- hud.asm
    |   |-- ui.asm
    |   |-- data.asm
    |   `-- ram.asm
    `-- pacmo/
        |-- game_init.asm
        |-- logic_dispatch.asm
        |-- movement.asm
        |-- render.asm
        |-- sound.asm
        |-- hud.asm
        |-- ui.asm
        |-- data.asm
        `-- ram.asm
```

## Documentation

- [docs/shared-codebase.md](docs/shared-codebase.md) explains the cooperative loop, scan tick, shared LCD/HUD/sound helpers, framebuffer contract, and shared/local boundary.
- [docs/tetro-codebase.md](docs/tetro-codebase.md) explains Tetro's state machine, collision path, movement, locking, rendering, pieces, LCD wrappers, score path, and game-over flow.
- [docs/pacmo-codebase.md](docs/pacmo-codebase.md) explains Pacmo's viewport, movement, maze consumption, power mode, monsters, rendering, scoring, and level progression.

## License

This repository uses the permissive hobby license in [LICENSE](LICENSE). The main source carries the same SPDX marker.
