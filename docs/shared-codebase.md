# Shared codebase

Tetro and Pacmo are different games, but they run on the same tight hardware loop.

There are no interrupts and no background task. The CPU has to keep the RGB matrix visible, scan the six-digit seven-segment display, service the speaker, poll input, and run game logic from one cooperative loop. The shared codebase is the small set of routines that make that possible without turning either game into a generic engine.

This document describes the shared contract used by both game targets. The game-specific tours explain what each game does on top of it.

---

## Target structure

Each game has its own top-level assembly file:

```text
src/tetro.z80
src/pacmo.z80
```

Those files own the `ORG`, reset entry, main loop, and include order. Debug80 can load either target directly without knowing how the internal helper files are split.

Both targets use the same basic runtime shape:

```asm
START:
    CALL    INIT_STATE

MAIN_LOOP:
    CALL    SCAN_TICK
    CALL    LOGIC_TICK
    JR      MAIN_LOOP
```

`SCAN_TICK` keeps the hardware alive. `LOGIC_TICK` does one slice of game work. The loop repeats forever.

The include order matters because `asm80` resolves forward references. `shared/scan_tick.asm` calls `SERVICE_SOUND` and `SCAN_SCORE_DIGIT`, but those labels are supplied later by the shared sound and HUD files. This keeps scanout generic while allowing each target to include its own game wrappers after the generic services.

---

## Shared and local code

The shared layer is deliberately low-level. It contains hardware facts and buffer operations that are true for Tetro, Pacmo, and future 8x8 games.

Currently shared and generic:

- `src/shared/inc/constants.asm`: hardware ports, MON-3 API constants, key codes, matrix dimensions, colour bits, composite colour names, and speaker bit
- `src/shared/scan_tick.asm`: matrix row scanout and scan-state advance
- `src/shared/framebuffer_core.asm`: back-buffer clear and copy helpers
- `src/shared/framebuffer_draw.asm`: matrix x-to-mask conversion and RGB framebuffer drawing primitives
- `src/shared/sound.asm`: speaker divider state machine
- `src/shared/hud.asm`: seven-segment digit scan, blanking, shared digit/glyph tables, and decimal score formatting
- `src/shared/lcd.asm`: HD44780 primitive operations, script renderer, row string writer, and table-character writer

The games keep their own rules, state, tuning, display text, score events, and presentation wrappers. A routine belongs in `src/shared` only when its contract is hardware-shaped or buffer-shaped rather than game-shaped.

There are no transitional Tetro-shaped input or rendering files in `src/shared`. Tetro input lives in `src/games/tetro/input.asm`, and Tetro rendering lives in `src/games/tetro/render.asm`.

---

## Scan tick

`SCAN_TICK` lives in `src/shared/scan_tick.asm`.

Each call:

1. Clears the active row select.
2. Reads three bytes from `FRAMEBUFFER` through `SCAN_PTR`.
3. Writes those bytes to the red, green, and blue matrix ports.
4. Enables the row selected by `SCAN_MASK`.
5. Calls `SERVICE_SOUND`.
6. Calls `SCAN_SCORE_DIGIT`.
7. Calls `ADVANCE_SCAN_STATE`.

Clearing the row before changing colour data matters. If the row stayed enabled while new colour bytes were written, the previous row could briefly show the next row's colour data.

`ADVANCE_SCAN_STATE` rotates `SCAN_MASK` and moves `SCAN_PTR` to the next four-byte framebuffer row. When the scan wraps back to row zero, it resets the pointer and increments `FRAME_PHASE`.

`FRAME_PHASE` is just a shared scan-state counter. Tetro uses it as splash-screen entropy. Pacmo currently does not use it for randomness, but it still gets the same counter because it uses the same scan state.

---

## Logic slices

The runtime does not compute a whole game frame in one pass. Each game spreads a logical frame across eight passes through `MAIN_LOOP`, matching the eight display rows.

That keeps scanout frequent enough to avoid visible flicker. If game logic monopolized the CPU for too long, matrix brightness would become uneven, the seven-segment display would dim or flicker, and speaker timing would become rough.

The exact slice schedule is game-specific:

- Tetro uses slices for input, gravity, row clearing, rendering, and line-clear timing.
- Pacmo uses slices for movement, power timing, monster updates, row clearing, rendering, and level gates.

The shared codebase only provides the clocking pattern and buffer helpers. It does not decide what the slices mean.

---

## Framebuffer contract

The front framebuffer is the buffer read by `SCAN_TICK`:

```text
FRAMEBUFFER
```

The back framebuffer is where game logic composes the next image:

```text
FRAMEBUFFER_BACK
```

Both buffers are 32 bytes:

```text
8 rows x 4 bytes per row
```

For each row:

```text
byte 0 = red plane
byte 1 = green plane
byte 2 = blue plane
byte 3 = aux / padding
```

The scanout emits only the red, green, and blue bytes. The fourth byte keeps row stride simple and leaves room for local scratch conventions.

`shared/framebuffer_core.asm` provides:

- `CLEAR_BACK_ALL`
- `CLEAR_BACK_4`
- `COPY_BACK_4_TO_FRONT`
- `COPY_BACK_TO_FRONT`

Those routines know the buffer shape, but not the game meaning of the pixels.

`src/shared/framebuffer_draw.asm` provides small drawing primitives over the same RGB row layout:

- `MATRIX_X_TO_MASK`
- `FB_SET_CELL_COLOR`
- `FB_OR_ROW_COLOR_MASK`

`MATRIX_X_TO_MASK` converts a screen x coordinate to the matrix bit convention where x 0 maps to the most significant bit. `FB_SET_CELL_COLOR` writes one RGB cell to an exact colour, clearing planes that are not part of that colour. `FB_OR_ROW_COLOR_MASK` ORs a row mask into the selected colour planes. Game renderers decide what to draw; these helpers only implement the shared framebuffer mechanics.

---

## Speaker service

`shared/sound.asm` contains the generic speaker state machine.

`SOUND_START` takes:

```text
A = duration in scan ticks
C = divider reload / half-period
```

It initializes `SOUND_TIMER`, `SOUND_DIVIDER_RELOAD`, `SOUND_DIVIDER_COUNT`, and clears `SPEAKER_PORT_STATE`.

`SERVICE_SOUND` runs once per scan tick. It decrements the sound timer and toggles `SPEAKER_PORT_STATE` whenever the divider expires. When the timer reaches zero, it silences the speaker state.

The shared service does not know what a sound means. Tetro and Pacmo keep local event wrappers that load their own duration and divider constants, then tail-call `SOUND_START`.

---

## Seven-segment HUD

`src/shared/hud.asm` owns multiplexing and common formatting for the six seven-segment digits.

`SCAN_SCORE_DIGIT` reads one byte from `HUD_SEG_BUFFER`, writes it to `PORT_SEGS`, combines the selected digit mask with `SPEAKER_PORT_STATE`, and writes the result to `PORT_DIGITS`. This is why the speaker and digit display share timing: both use the digit latch.

`HUD_SCAN_INDEX` advances modulo six so each scan tick refreshes one digit.

`BLANK_HUD_SCORE_DIGITS` clears the six-byte segment buffer.

The shared HUD file also owns:

- `HUD_DIGIT_MASK_TABLE`
- `HUD_SEG_GLYPH_TABLE`
- `HUD_WRITE_U16_DECIMAL`
- `HUD_WRITE_DECIMAL_DIGIT`

Game-local score wrappers load their game score into `HL` and tail-call the shared formatter. The shared formatter owns the `HUD_SEG_BUFFER` destination, including the leading zero glyph and the five decimal digits. This keeps scoring events local while sharing the decimal-to-seven-segment conversion.

---

## LCD primitives

`shared/lcd.asm` contains the generic HD44780 operations:

- `LCD_BUSY`
- `LCD_COMMAND`
- `LCD_CLEAR_DISPLAY`
- `LCD_STRING`
- `LCD_SHOW_SCRIPT`
- `LCD_PUTC`
- `LCD_WRITE_ROW_STRING`
- `LCD_PUTC_FROM_TABLE`

`LCD_SHOW_SCRIPT` reads a simple table:

```text
DB row_command
DW text_pointer
...
DB 0
```

The shared LCD layer knows how to execute that table, position a row before writing a string, and append a table-indexed character. It does not decide which screens exist. Tetro and Pacmo keep their own LCD text, script tables, and wrapper routines.

---

## Boundary rule

A helper is a good shared candidate when it can be documented without naming Tetro pieces, Pacmo monsters, scores, levels, walls, pills, or LCD states.

Good shared candidates:

- hardware port operations
- LCD primitive operations
- matrix scanout
- seven-segment multiplexing
- speaker divider timing
- framebuffer clear/copy operations
- small pure bit helpers after coordinate semantics are confirmed

Code should stay game-local when it encodes:

- Tetro piece, collision, gravity, rotation, lock, line-clear, or next-preview behaviour
- Pacmo maze, viewport, player, monster, pill, power-mode, respawn, or level behaviour
- game-specific sound event names and tuning
- game-specific LCD screen names and text
- game-specific score variable names unless wrapped behind a clear shared contract

The goal is reuse without hiding game logic. Shared code should make the hardware easier to use; it should not make the games harder to understand.
