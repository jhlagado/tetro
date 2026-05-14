# TETRO

TETRO is a 7-piece falling-block game for the TEC-1G single-board Z80 computer, running under MON-3.

The game draws an 8x8 RGB LED matrix, uses the MON-3 keypad for controls, shows status on an HD44780 LCD, and scans a six-digit seven-segment score display. All of that runs from one cooperative loop: one matrix row is emitted per pass, sound and score scan from the same tick, and game logic is spread across eight slices.

The full code tour is in [docs/tetro-codebase.md](docs/tetro-codebase.md). It is the source-of-truth document for the architecture, state machine, collision path, rendering path, and lock/clear flow.

## Hardware

- TEC-1G single-board computer with MON-3.
- 8x8 RGB LED matrix wired as red, green, and blue bit planes plus row select.
- HD44780-compatible LCD on `PORT_LCD_INST` / `PORT_LCD_DATA`.
- Six-digit seven-segment display on `PORT_DIGITS` / `PORT_SEGS`.
- Speaker driven from bit 7 of `PORT_DIGITS`.

Port assignments and shared gameplay tuning constants live in [src/shared/inc/constants.asm](src/shared/inc/constants.asm).

## Controls

| Key | Code | Action |
| --- | ---: | --- |
| `<` | `0x11` | Move left |
| `>` | `0x10` | Move right |
| `GO` | `0x12` | Soft drop |
| `AD` | `0x13` | Rotate counter-clockwise |
| `C` | `0x0C` | Rotate clockwise |
| `0` | `0x00` | Pause or resume |
| any key | | Start from splash, or restart after the game-over gate opens |

Movement and soft drop repeat while held. Rotation is edge-triggered.

## Gameplay

- Pieces: `I`, `O`, `T`, `S`, `Z`, `J`, `L`.
- Piece colours: `I` cyan, `O` white, `T` magenta, `S` green, `Z` red, `J` blue, `L` yellow.
- Rotations are precomputed row bitmaps in ROM.
- Placement, movement, rotation, gravity, and spawn all use the same collision routine.
- Completed rows flash white, collapse, and score 100 / 300 / 500 / 800 for 1 / 2 / 3 / 4 rows.
- Gravity starts at `GRAVITY_PERIOD` and drops to `GRAVITY_PERIOD_STEP1` once the score reaches 2000.
- Game over occurs when a spawn collides immediately or a locked piece still occupies rows above the visible field.

## Build

Requires [asm80](https://www.npmjs.com/package/asm80). Assemble from `src/`, because `.include` paths are relative to the main source file.

```bash
mkdir -p build
(cd src && asm80 -m Z80 -t hex -o ../build/tetro.hex tetro.asm)
(cd src && asm80 -m Z80 -t bin -o ../build/tetro.bin tetro.asm)
```

The generated files under `build/` are outputs, not source.

## Run

Load the assembled program at `$4000`, matching the `ORG` in [src/tetro.asm](src/tetro.asm), then run:

```text
GO 4000
```

The LCD shows the splash screen. Press any key to start.

## Source Layout

```text
src/
|-- tetro.asm                  ; Debug80 target entry point and include order
|-- shared/
|   |-- inc/
|   |   `-- constants.asm      ; ports, key codes, shared tuning constants
|   |-- framebuffer.asm        ; back/front framebuffer rendering helpers
|   |-- input.asm              ; keypad polling and repeat handling
|   |-- scan_tick.asm          ; matrix row scan and scan-state advance
|   `-- ui.asm                 ; older shared UI routines retained for other targets
`-- games/
    `-- tetro/
        |-- geometry_helpers.asm
        |-- collision.asm
        |-- piece_active.asm
        |-- board_lock.asm
        |-- game_init.asm
        |-- logic_dispatch.asm
        |-- sound.asm
        |-- hud.asm
        |-- lcd.asm
        |-- ui.asm
        |-- data.asm
        `-- ram.asm
```

## Documentation

[docs/tetro-codebase.md](docs/tetro-codebase.md) explains how the loop, scan tick, RAM layout, collision, movement, locking, rendering, pieces, LCD, score display, and game-over path fit together. Keep detailed architectural explanation there so the README stays short.

## License

This repository uses the permissive hobby license in [LICENSE](LICENSE). The main source carries the same SPDX marker.
