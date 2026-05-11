# TETRO: a tour of the code

A falling-block puzzle game, on an 8×8 RGB matrix, with a six-digit seven-segment score readout, an LCD HUD, and a beeper — all driven by a single Z80 with no interrupts. The matrix only exists when the CPU is actively scanning it, no timer fires when something needs doing, and there is no second thread for background work. Everything shares one loop.

This document follows that constraint into the code. Loop first, then scan, slices, collision, the lock chain, rendering, and the path one piece takes from spawn to game over.

---

## The loop

```asm
MAIN_LOOP:
    CALL    SCAN_TICK
    CALL    LOGIC_TICK
    JR      MAIN_LOOP
```

Three lines. The whole program runs underneath them.

The 8×8 matrix is row-multiplexed: at any moment exactly one row is driven and the other seven sit dark. To produce a steady image the program steps through all eight rows fast enough that the eye averages them into a frame. A late `SCAN_TICK` means uneven brightness. A very late `SCAN_TICK` means flicker. Anything else — gravity, input, line clears — has to fit between scanouts.

`LOGIC_TICK` doesn't compute a full frame. It computes one-eighth of a frame. Each logical frame's work is spread across eight passes through the loop, with a `SCAN_TICK` on each pass to keep the matrix running. Sound works the same way: no timers, just a counter decremented once per scan. The display, the speaker, and the score digits are all maintained by keeping the CPU in this loop.

---

## SCAN_TICK

`SCAN_TICK` is the program's clock. Each call drives one matrix row, advances one step of the sound generator, refreshes one digit of the score readout, and returns.

Three bytes from the framebuffer go to the red, green, and blue ports; one bit from `SCAN_MASK` selects the row. `SCAN_MASK` rotates left every call, so eight calls light all eight rows in turn. The row select clears *before* the new colours are written — otherwise the previous row briefly receives the new row's data and ghost images appear across the panel.

`SERVICE_SOUND` handles the speaker. A divider counts down to zero and toggles the speaker bit; a duration counts down to zero and stops the note. Both decrement once per scan tick. Sound effects — the lock thud, the rotate chirp, the game-over groan — set a divider and a duration. The following scan ticks produce the square wave.

`SCAN_SCORE_DIGIT` drives the seven-segment readout the same way: six digits, one lit at a time, indexed by `HUD_SCAN_INDEX` and stepped through six successive ticks. The segment patterns were written into `HUD_SEG_BUFFER` the last time the score changed; the scanner reads bytes and sends them to the digit and segment ports.

When all three are done, `ADVANCE_SCAN_STATE` moves `SCAN_PTR` to the next framebuffer row and rotates `SCAN_MASK`. Wrapping back to row 0 also increments `FRAME_PHASE`, a counter used only during the splash screen to seed the RNG — more on that later.

---

## LOGIC_TICK

Before any gameplay runs, `LOGIC_TICK` checks the current game state. Game over takes priority, then splash, then a line-clear hold, then pause, then input lockout, then normal play. Each is a one-byte flag in RAM; the dispatcher reads top to bottom and the first flag set takes the call.

```asm
LOGIC_TICK:
    CALL    SANITIZE_ACTIVE_POSITION
    LD      A,(GAME_OVER)
    OR      A
    JR      Z,LOGIC_TICK_GAME_OVER_DONE
    CALL    WAIT_GAME_OVER_KEY_GATE
    RET
LOGIC_TICK_GAME_OVER_DONE:
    LD      A,(SPLASH_TIMER)
    ...
```

The order encodes priority. While the line-clear timer runs, the next piece doesn't exist yet. While the game is over, only the restart gate matters. Each state blocks the ones below it.

`SANITIZE_ACTIVE_POSITION` clamps `PLAYER_X` back from the right edge if rotation widened the piece off-screen, and clamps `PLAYER_Y` against the bottom. Negative `PLAYER_Y` is left alone — pieces spawn above the visible field and fall into it.

In normal play, `LOGIC_SLICE` (a counter mod 8) selects which portion of the frame's work runs this pass. Slice 0 polls the keypad. Slice 1 ticks gravity. Slices 2 through 6 each blank four bytes of the back framebuffer, one row at a time. Slice 7 blanks the last row, then composes the frame: landed board first, falling piece on top, then an `LDIR` from `FRAMEBUFFER_BACK` to `FRAMEBUFFER`. Until that copy completes, `SCAN_TICK` reads the previous frame. By the time slice 7 writes, the matrix has just finished its pass and is wrapping back to row 0, so the new frame is ready as the display starts again.

Eight slices, eight matrix rows. A logical frame and a full matrix scan take exactly the same number of loop iterations, so the two stay in step automatically.

---

## What's in RAM

The layout in `ram.asm` mirrors the code that touches it.

The active piece is a small cluster of bytes: `PLAYER_X`, `PLAYER_Y`, a pointer to the bitmap in ROM, the current rotation, the rightmost occupied column (so collision can clamp without scanning the bitmap), the colour, and an enable flag. The enable flag is used during line clears and game over, when the board still needs to render but the active piece should not appear.

Adjacent to that is a parallel set of *pending* fields: `PENDING_X`, `PENDING_Y`, `PENDING_ROTATION`, plus a scratch byte called `SHIFT_COUNT`. Every move writes a candidate position into the pending fields, runs the collision test, and only on a pass copies the result back to the live fields. Nothing visible changes until the position is confirmed valid.

The board splits across four parallel planes. `BOARD_ROWS` is a one-bit-per-cell occupancy map: eight bytes for eight rows. Collision reads only this plane. Colour is stored separately in `BOARD_RED`, `BOARD_GREEN`, `BOARD_BLUE`. Collision walks one byte per row and ANDs against a shifted piece mask — no unpacking needed. Render walks three bytes per row straight into the framebuffer — no masking needed. A combined representation would require one or the other to do extra work on every slice.

The framebuffer is doubled: `FRAMEBUFFER_BACK` is composed by the slices; `FRAMEBUFFER` is read by `SCAN_TICK`. Both are thirty-two bytes — eight rows of four — where the first three bytes per row are red, green, and blue, and the fourth pads the stride to four for simpler address arithmetic.

---

## Cold start and restart

`INIT_STATE` zeros everything via `INIT_STATE_BASE`, sets `SPLASH_TIMER`, draws the splash on the LCD, and rebuilds the framebuffer. Then it returns to the main loop with the splash flag set.

While the splash is displayed, the loop keeps running. `SCAN_TICK` increments `FRAME_PHASE` every time the matrix scan wraps. The number of increments before the player presses a key depends on how long they wait — anywhere from nearly zero to several seconds, at tens of thousands of loop iterations per second. When the splash ends, `FRAME_PHASE` becomes `RNG_SEED`.

A fallback handles the case where a key is pressed before the matrix has wrapped even once: a hardcoded seed is used instead.

After seeding, `HANDLE_SPLASH_STATE` generates the first upcoming piece, spawns the first active piece, and sets `INPUT_LOCKOUT` so the keypress that dismissed the splash is not also treated as a game move. The lockout clears when the player releases the key.

`INIT_STATE_RESTART` is the post-game-over path. It clears game state but leaves the RNG alone, so successive games continue from the same pseudo-random stream. No splash, no `FRAME_PHASE` accumulation — just a fresh board and a new piece.

---

## Collision

`CHECK_COLLISION_AT_DE` is the only placement test in the program. Spawn, movement, rotation, and gravity all call it. It takes the candidate position in `D` (x) and `E` (y), and returns carry set if the placement is illegal.

Horizontal bounds are checked first. If `D` is less than `X_MIN`, the piece is past the left wall. If `D + CURRENT_PIECE_RIGHT` reaches `ROW_COUNT`, it is past the right wall. Both return immediately — there is no need to examine the piece bitmap if it is already out of bounds.

If the bounds pass, the test walks the four rows of the piece bitmap. Each row is an 8-bit mask; `SHIFT_ROW_MASK` slides it left by `SHIFT_COUNT` (the candidate x) so the bits align with board columns. Empty rows are skipped. Rows whose board y is negative are skipped — pieces may spawn above the visible field. A row whose y exceeds the bottom of the board is a wall collision.

For rows that remain, the shifted mask is ANDed against the matching byte in `BOARD_ROWS`. Non-zero means the piece overlaps a landed cell.

All failure modes — left wall, right wall, bottom, cell overlap — set carry and exit through the same epilogue. Each entry point has its own pushes; there is one place that pops them. A new failure path added later will not leave the stack unbalanced.

`SHIFT_ROW_MASK` is shared by collision, the active-piece renderer, and the board-merge routine. All three place an 8-bit mask at an x offset, and they must agree on how that is done. If they differed, pieces would collide differently from how they are drawn, or settle in a different position from where the collision test approved. Using a single shared routine avoids that problem.

---

## Movement, gravity, rotation

Every move follows the same pattern:

```
write candidate to PENDING_*
call CHECK_COLLISION_AT_DE
on success, commit candidate to PLAYER_*
```

`MOVE_LEFT` and `MOVE_RIGHT` use a shared helper, `HORIZONTAL_PROBE_APPLY_PENDING_X`. It writes `PENDING_X`, copies `PLAYER_Y` to `PENDING_Y`, runs the test, and on success writes back. On failure, nothing changes.

`STEP_ACTIVE_DOWN_ONE_CELL` is the shared downward probe used by both `APPLY_GRAVITY` and `SOFT_DROP`. Both call the same routine, so gravity and soft drop use identical collision rules.

`APPLY_GRAVITY` decrements `GRAVITY_COOLDOWN` and returns if it is not yet zero. When it fires, it reloads the cooldown from `CURRENT_GRAVITY_PERIOD`, probes one row down, and either commits the new y or calls `LOCK_ACTIVE_PIECE`. The cooldown controls fall speed. Reducing `CURRENT_GRAVITY_PERIOD` later in a session makes pieces fall faster.

`SOFT_DROP` skips the cooldown. When the probe finds the piece blocked, it sets `DROP_LOCKOUT` and locks the piece. Without the lockout, a player still holding the drop key when the next piece spawns would immediately push it to the floor.

Rotation does not change the position — only the bitmap. The routine saves the current rotation in `PENDING_ROTATION`, writes the new rotation into `CURRENT_ROTATION`, loads the corresponding bitmap and metadata via `LOAD_CURRENT_ROTATION_STATE`, and tests at `(PLAYER_X, PLAYER_Y)`. If the test fails, the old rotation and metadata are restored. There is no wall-kick; the rotation either fits or it does not. On success, the rotate sound plays and `GRAVITY_COOLDOWN` resets to a full period, giving the player one extra gravity cycle before the piece drops another row.

---

## Lock, clear, score

`LOCK_ACTIVE_PIECE` is called when gravity or a blocked soft drop determines the piece can go no further. It is the only path from active piece to the board.

The first check is for top-out. `CHECK_TOP_OUT_ON_LOCK` looks for any occupied row in the piece bitmap whose board y is still negative — meaning the piece is locking with part of itself above the visible field. That is the loss condition. `LOCK_GAME_OVER` merges the piece into the board so the final position is visible, then calls `ENTER_GAME_OVER`.

If top-out does not apply, `MERGE_ACTIVE_TO_BOARD` writes the piece into the board. The same `SHIFT_ROW_MASK` used by collision places the piece in exactly the cells the collision test approved. The shifted mask is ORed into `BOARD_ROWS` and into the colour planes for the channels set in `CURRENT_PIECE_COLOR`.

`CHECK_FULL_ROWS` scans `BOARD_ROWS` for bytes equal to 0xFF and records each in `CLEAR_MASK`. If nothing is full, the lock sound plays and `SPAWN_ACTIVE_PIECE` runs immediately. If one or more rows are full, the clear sound plays, `CLEAR_PENDING` is set, `CLEAR_TIMER` is loaded, and the active piece is disabled. Spawning waits.

During the hold, the renderer draws rows in `CLEAR_MASK` as solid white, overriding their stored colours. `LOGIC_TICK` routes to `HANDLE_LINE_CLEAR_STATE`, which decrements the timer once per logical frame (at `LOGIC_SLICE == 0`). When the timer reaches zero, `COLLAPSE_FULL_ROWS` runs.

The collapse uses two pointers walking down the board: `D` reads, `E` writes. A read row found in `CLEAR_MASK` is skipped — not copied. All other rows are copied to the write position, and the write pointer advances. After the pass, rows above the new top are zeroed. Occupancy and colour are moved together.

`APPLY_CLEAR_SCORE` counts the set bits in `CLEAR_MASK`, clamps at four, and adds the corresponding value from `CLEAR_SCORE_TABLE` — 100, 300, 500, or 800 — to the 16-bit `SCORE`. The total line count increments. If the score crosses the difficulty threshold, `CURRENT_GRAVITY_PERIOD` drops to `GRAVITY_PERIOD_STEP1`. The HUD updates and the next piece spawns.

---

## Rendering

Rendering is divided between slices 2–6 and slice 7.

Slices 2 through 6 each blank one row of `FRAMEBUFFER_BACK`. By the time slice 7 runs, all but the last row are already zeroed. Slice 7 blanks the final row and draws the frame.

`RENDER_BOARD_TO_BACK` walks each board row and copies the three colour bytes into the framebuffer. Two conditions alter this. When `CLEAR_PENDING` is set, rows in `CLEAR_MASK` are written as 0xFF on all three channels — the white flash. When `GAME_OVER` is set, colour data is ignored and all occupied cells are drawn red on one channel only.

`RENDER_ACTIVE_TO_BACK` draws the falling piece on top. It steps through the four bitmap rows, shifts each by `PLAYER_X` using `SHIFT_ROW_MASK`, skips rows outside the field, and ORs the result into the framebuffer via `WRITE_COLORED_ROW_MASK`. Because collision has already confirmed the piece does not overlap any landed cell, the OR cannot corrupt existing board data.

`COPY_BACK_TO_FRONT` is two `LD` setups and an `LDIR`. The next `SCAN_TICK` reads the new frame.

---

## Pieces, rotations, randomness

Piece data lives in `data.asm`. Each rotation is a 4×4 bitmap stored as four bytes; the I piece has two rotations, the O piece one, the rest four. Three parallel tables are indexed by piece × rotation:

- `PIECE_PTR_TABLE` — pointer to the bitmap
- `PIECE_RIGHT_TABLE` — rightmost occupied column, for right-edge clamping
- `PIECE_COLOR_TABLE` — colour byte for `WRITE_COLORED_ROW_MASK`

`LOAD_CURRENT_ROTATION_STATE` reads all three and writes them into the live RAM fields. Adding a new piece means adding data, not changing code.

The RNG is an 8-bit shift-register generator (`RNG_NEXT8`) that advances `RNG_SEED` on each call. `RNG_NEXT_PIECE` masks the result to three bits, discards 7, and retries. The output is uniform over indices 0–6 — the seven piece types — at the cost of discarding one in eight values. The selected piece sits in `NEXT_PIECE_INDEX` until the next spawn moves it to `CURRENT_PIECE_INDEX`. The LCD reads `NEXT_PIECE_INDEX` through `PIECE_NAME_TABLE` to show the preview letter.

---

## LCD and score readout

The LCD is driven by script tables. Each screen — running, paused, splash, game-over — is a list of (set-cursor command, string pointer) pairs terminated by zero. `LCD_SHOW_SCRIPT` walks the list, sending each command and writing each string. The running and paused screens go through `LCD_SHOW_HUD`, which runs the script and appends the next-piece preview letter. Screen layout changes are data edits.

`LCD_REFRESH_NEXT_PREVIEW_ROW` updates only the preview letter, used after each spawn to avoid a full LCD redraw.

When the score changes, `UPDATE_SCORE_DISPLAY` extracts each digit by repeated subtraction (the Z80 has no division instruction) and writes six segment patterns into `HUD_SEG_BUFFER`. Each scan tick, `SCAN_SCORE_DIGIT` lights one digit by reading one byte from that buffer. The digit calculation runs once per line clear; the display update runs once per matrix row.

---

## A whole piece, beginning to end

On boot, `INIT_STATE` clears everything, sets `SPLASH_TIMER`, draws the splash. The loop runs. `SCAN_TICK` keeps the matrix and score active. `FRAME_PHASE` increments.

A key is pressed.

`HANDLE_SPLASH_STATE` reads it. `RNG_SEED` is set to `FRAME_PHASE`. The first upcoming piece is generated and `INPUT_LOCKOUT` is set, so the keypress does not also register as a game input. `SPAWN_ACTIVE_PIECE` runs: it promotes `NEXT_PIECE_INDEX` to current, generates a new upcoming piece, positions the active piece at `(3, SPAWN_Y)` above the visible field, resets cooldowns, and runs collision at the spawn position. If the board is too full to place the piece, `ENTER_GAME_OVER` is called before the piece is displayed. Otherwise `ACTIVE_PIECE_ENABLED` is set and the LCD preview updates.

The loop is now in regular play. Each iteration: one matrix row scanned, one score digit refreshed, one logic slice. Every eight iterations, one logical frame.

The player holds left. Slice 0 reads the keypress via `RST 0x10`, applies repeat throttling with `MOVE_COOLDOWN`, and calls `MOVE_LEFT`, which writes `PENDING_X` and runs the collision probe. At the wall, the test fails and `PLAYER_X` does not change. Otherwise the candidate is committed.

In slice 1, when `GRAVITY_COOLDOWN` reaches zero, `STEP_ACTIVE_DOWN_ONE_CELL` runs. If the probe passes, `PLAYER_Y` increments. When the probe fails — a cell is directly below — `LOCK_ACTIVE_PIECE` runs.

`CHECK_TOP_OUT_ON_LOCK` finds the piece in the field. `MERGE_ACTIVE_TO_BOARD` writes it to the board. `CHECK_FULL_ROWS` scans for 0xFF rows. Nothing full: lock sound, spawn, continue. Something full: clear sound, hold state, flash, collapse, score update, spawn.

Eventually a piece locks with part of itself above the top of the field. `CHECK_TOP_OUT_ON_LOCK` returns carry. `LOCK_GAME_OVER` merges the piece so its final position is visible, then calls `ENTER_GAME_OVER`. The active piece is disabled, `GAME_OVER` is set, the game-over sound plays, the framebuffer is redrawn in red, and the LCD shows the game-over screen. The loop continues — `SCAN_TICK` still drives the display, the speaker finishes the sound, the score stays on the digits — but `LOGIC_TICK` is now in the game-over branch. After a short delay to prevent an accidental restart from a key still held at game end, `POLL_GAME_OVER_RESTART` waits for a new keypress. On one, `INIT_STATE_RESTART` clears the board without resetting the RNG, and play begins again.

---

## Map

```
SCAN_TICK         drives matrix row, sound divider, score digit
LOGIC_TICK        dispatches by mode flag, then slices

slice 0           POLL_INPUT_AND_UPDATE
slice 1           APPLY_GRAVITY → STEP_ACTIVE_DOWN_ONE_CELL → CHECK_COLLISION_AT_DE
slices 2-6        CLEAR_BACK_4 (one row each)
slice 7           CLEAR_BACK_4, RENDER_BOARD_TO_BACK,
                  RENDER_ACTIVE_TO_BACK, COPY_BACK_TO_FRONT

movement / rotation pattern
  PENDING_* = candidate
  CHECK_COLLISION_AT_DE
  on success, PLAYER_* = PENDING_*

lock chain
  CHECK_TOP_OUT_ON_LOCK → MERGE_ACTIVE_TO_BOARD → CHECK_FULL_ROWS
  → SPAWN_ACTIVE_PIECE | enter line-clear hold
  → ENTER_GAME_OVER on top-out
```
