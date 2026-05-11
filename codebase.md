# TETRO: a tour of the code

Tetris, on an 8×8 RGB matrix, with a six-digit seven-segment score readout, an LCD HUD, and a beeper — all driven by a single Z80 with no interrupts. The hardware doesn't really want to run a game like this. The matrix only exists when the CPU is actively scanning it, no timer will tap us on the shoulder when something needs doing, and there is no second thread to put the slow work on. Everything shares one loop, and nothing is allowed to stop and think.

The rest of this document follows that constraint into the code. Loop first, then scan, slices, collision, the lock chain, rendering, and the path one piece takes from spawn to game over.

---

## The loop

```asm
MAIN_LOOP:
    CALL    SCAN_TICK
    CALL    LOGIC_TICK
    JR      MAIN_LOOP
```

Three lines. The whole program runs underneath them.

The 8×8 matrix is row-multiplexed: at any moment exactly one row is driven, and the other seven sit dark. To fake a steady image the program has to step through all eight rows fast enough that your eye averages them into a frame. Late `SCAN_TICK` means uneven brightness. Very late `SCAN_TICK` means flicker. Anything else the program wants to do — gravity, input, line clears — has to fit between scanouts.

So `LOGIC_TICK` doesn't compute a frame. It computes one-eighth of a frame. The work of each logical frame is sliced across eight passes through the loop, with a `SCAN_TICK` riding alongside each slice keeping the matrix alive. Sound runs the same way: no timers anywhere, just a counter decremented once per scan. The display, the speaker, and the score digits are all side effects of holding the CPU in this loop.

---

## SCAN_TICK

`SCAN_TICK` is the program's clock. Each call drives one matrix row, advances one step of the sound generator, refreshes one digit of the score readout, and returns.

The matrix part is straight out of an MCU sketchbook. Three bytes from the framebuffer go to the red, green, and blue ports; one bit from `SCAN_MASK` selects which row sees those colours. `SCAN_MASK` rotates left every call, so eight calls light all eight rows in turn. The row select is cleared *before* the new colours are written, because if you don't, the previous row briefly catches the new row's data and ghost images bleed across the panel.

`SERVICE_SOUND` is the rest of the speaker. A divider counts down to zero and toggles the speaker bit; a duration counts down to zero and stops the note. Both decrement once per scan tick, which is also the only thing on this machine that measures time. Sound effects — the lock thud, the rotate chirp, the game-over groan — write a divider and a duration and walk away. The next dozen scan ticks turn that into a square wave.

`SCAN_SCORE_DIGIT` does the seven-segment readout the same way the matrix does the colour panel. Six digits, one lit at a time, indexed by `HUD_SCAN_INDEX` and stepped through six successive ticks. The segment patterns were already encoded into `HUD_SEG_BUFFER` the last time the score changed; the scanner just reads bytes and pushes them at the digit and segment ports.

When all three are done, `ADVANCE_SCAN_STATE` walks `SCAN_PTR` to the next framebuffer row and rotates `SCAN_MASK`. Wrapping back to row 0 also bumps `FRAME_PHASE`, a counter that does nothing during gameplay but quietly accumulates entropy while the splash screen is up — more on that when we get there.

---

## LOGIC_TICK

`LOGIC_TICK` decides what kind of game state we're in before any actual gameplay runs. Game over takes priority, then splash, then a line-clear hold, then pause, then input lockout, then normal play. Each of these is a one-byte flag in RAM; the dispatcher reads them top to bottom and the first one set takes the call.

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

The waterfall is deliberate. The order of those checks is the priority hierarchy of the game's modal state. While the line-clear timer is running, you can't move the next piece, because the next piece doesn't exist yet. While the game is over, all that matters is the restart gate. The dispatcher encodes those rules as flow control and gets out of the way.

`SANITIZE_ACTIVE_POSITION` is a guard rail rather than a behaviour. It clamps `PLAYER_X` against the right edge in case rotation widened the piece off-screen, and it clamps `PLAYER_Y` against the bottom. Negative `PLAYER_Y` it leaves alone — pieces spawn above the visible field and need to fall into it.

In normal play, `LOGIC_SLICE` (a counter mod 8) selects which slice of the frame's work runs this pass. Slice 0 polls the keypad. Slice 1 ticks gravity. Slices 2 through 6 each blank four bytes of the back framebuffer, one row at a time, spreading the cost. Slice 7 blanks the last row and then composes the frame: the landed board first, the falling piece on top, then a `LDIR` from `FRAMEBUFFER_BACK` to `FRAMEBUFFER`. Until that copy lands, `SCAN_TICK` keeps reading the previous frame. It's a poor man's vsync — by the time slice 7 writes, the matrix has just finished walking out of the old frame and is wrapping back to row 0.

(Why eight slices? Because the matrix has eight rows. A logical frame and a full matrix scan take exactly the same number of loop iterations, so the slice cycle and the scanout cycle stay locked together for free.)

---

## What's in RAM

The layout in `ram.asm` mirrors the code that touches it.

The active piece — the one that's currently falling — is a small cluster of bytes: `PLAYER_X`, `PLAYER_Y`, a pointer to the bitmap in ROM, the current rotation, the rightmost occupied column (so collision can clamp without scanning), the colour, and an enable flag. The enable flag earns its keep during line clears and game over, when the board still needs to render but the active piece must vanish.

Right next to that lives a parallel set of *pending* fields: `PENDING_X`, `PENDING_Y`, `PENDING_ROTATION`, plus a scratch byte called `SHIFT_COUNT`. They exist because the program is paranoid about half-applied moves. Every move — left, right, gravity, soft drop, rotation — works the same way: write the candidate position into the pending fields, run the collision test against those fields, and only then, if the test passes, commit the candidate back to the live fields. Nothing about the visible game state changes until it's known good.

The board itself splits across four parallel planes. `BOARD_ROWS` is a one-bit-per-cell occupancy map: eight bytes for an eight-row board. The collision test reads only this plane. Colour is held separately, in `BOARD_RED`, `BOARD_GREEN`, `BOARD_BLUE`. Splitting them isn't an aesthetic choice, it's a speed one. Collision walks one byte per row and ANDs against a shifted piece mask, no unpacking. Render walks three bytes per row straight to the framebuffer, no masking. A combined representation would force one or the other to do extra work eight times per slice, which is exactly the kind of hidden cost you can't afford here.

The framebuffer uses the same trick: one composed by the slices (`FRAMEBUFFER_BACK`), one read by `SCAN_TICK` (`FRAMEBUFFER`). Both are thirty-two bytes — eight rows of four — where the first three bytes per row are red, green, and blue, and the fourth keeps the row stride at four for cleaner address arithmetic.

---

## Cold start and restart

`INIT_STATE` zeros everything via `INIT_STATE_BASE`, raises `SPLASH_TIMER`, draws the splash on the LCD, and rebuilds the framebuffer. Then it returns to the main loop and lets `LOGIC_TICK` find the splash flag set.

While the splash sits there, the loop keeps spinning. `SCAN_TICK` is still bumping `FRAME_PHASE` every time the matrix scan wraps around. The number of times that happens before the player presses a key is, for all practical purposes, random — somewhere between "instantly" and "a few seconds", measured in iterations of a loop running tens of thousands of times per second. When the splash ends, `FRAME_PHASE` becomes `RNG_SEED`. That's where the piece sequence is born.

A fallback covers the impossibly-fast case where someone presses a key before the matrix has wrapped even once: a hardcoded seed kicks in. It's a paranoid net more than anything else.

After seeding, `HANDLE_SPLASH_STATE` rolls the first upcoming piece, spawns the first active piece, and arms `INPUT_LOCKOUT` so the keypress that dismissed the splash doesn't *also* try to be a game move. The lockout clears as soon as the player lets go.

`INIT_STATE_RESTART` is the post-game-over path, and it's deliberately leaner. It clears game state but leaves the RNG alone, so successive games keep walking down the same pseudo-random stream. No splash, no `FRAME_PHASE` dance — just a fresh board and a new piece.

---

## Collision

`CHECK_COLLISION_AT_DE` is the only placement test in the program. Spawn calls it. Movement calls it. Rotation calls it. Gravity calls it. If a piece is going to occupy a position, this routine has the only opinion that matters about whether that's allowed.

It takes the candidate position in `D` (x) and `E` (y), and returns carry set on illegal placement.

Horizontal bounds first. If `D` is less than `X_MIN`, that's the left wall. If `D + CURRENT_PIECE_RIGHT` reaches `ROW_COUNT`, that's the right wall. Both fail immediately — there's no point looking at piece geometry if the piece has already wandered off the side of the world.

If the bounds pass, the test walks the four rows of the piece bitmap. Each row is an 8-bit mask, and `SHIFT_ROW_MASK` slides it left by `SHIFT_COUNT` (the candidate x) so the bits land in the columns the board uses. An empty shifted row is skipped — three of the four bitmap rows are usually empty. A row whose corresponding board y is negative is also skipped, because the top of the playfield is invisible and pieces are allowed to spawn there. A row whose y is past the bottom of the board is an immediate wall hit.

For rows that survive the cull, the test ANDs the shifted piece mask against the matching byte in `BOARD_ROWS`. A non-zero result is overlap with a landed cell, which is collision.

All three failure modes — left/right wall, bottom wall, board overlap — set carry and exit through the same epilogue. Every entry has its own pushes; there is exactly one place that pops them. It's a small thing but it's the kind of small thing that prevents stack imbalances when somebody adds a fourth failure path two years from now.

`SHIFT_ROW_MASK` is interesting because collision uses it, and so does the active-piece renderer, and so does the board-merge routine. All three need the same definition of "place this 8-bit mask at this x offset", and any drift between the three would mean pieces collide differently than they're drawn or land somewhere other than where they're locked. Centralising the shift is a way of refusing to re-litigate the piece-on-board geometry three separate times.

---

## Movement, gravity, rotation

The shape of every move is the same:

```
write candidate to PENDING_*
call CHECK_COLLISION_AT_DE
on success, commit candidate to PLAYER_*
```

`MOVE_LEFT` and `MOVE_RIGHT` go through a shared helper, `HORIZONTAL_PROBE_APPLY_PENDING_X`. They write `PENDING_X`, the helper copies `PLAYER_Y` to `PENDING_Y` (a horizontal move doesn't change y), runs the test, and writes back if it passes. Failure is silent — the piece simply doesn't move.

`STEP_ACTIVE_DOWN_ONE_CELL` is the shared downward probe. Both `APPLY_GRAVITY` and `SOFT_DROP` call it. Sharing the probe means gravity and soft drop collide identically: every cell you can fall into via soft drop, you can fall into via gravity, and there is no surprise rule that one observes and the other doesn't.

`APPLY_GRAVITY` decrements `GRAVITY_COOLDOWN` and exits if it isn't zero yet. When it does fire, it reloads the cooldown from `CURRENT_GRAVITY_PERIOD`, probes one row down, and either commits the new y or jumps straight to `LOCK_ACTIVE_PIECE`. The cooldown is what makes pieces fall slowly. Speeding the game up later in a session is just lowering `CURRENT_GRAVITY_PERIOD`.

`SOFT_DROP` skips the cooldown — held drop should mean fast drop. When the probe blocks, it sets `DROP_LOCKOUT` and locks the piece. The lockout matters because the player is probably still holding the drop key when the next piece spawns, and without the lockout that key would immediately drive the new piece into the floor.

Rotation is a different shape from move and gravity, because the position doesn't change — only the bitmap does. The routine saves the old rotation in `PENDING_ROTATION`, writes the new one into `CURRENT_ROTATION`, loads its bitmap and metadata via `LOAD_CURRENT_ROTATION_STATE`, and tests at `(PLAYER_X, PLAYER_Y)`. If the test fails, it puts the old rotation back and reloads the old metadata. There is no wall-kicking. The rotation either fits or it doesn't. If it fits, the rotate sound fires and `GRAVITY_COOLDOWN` resets to a full period, buying the player a small grace window before the piece falls another row. Rotating a piece that's about to land gives you one extra cycle to nudge it sideways.

---

## Lock, clear, score

`LOCK_ACTIVE_PIECE` is what gravity, or a blocked soft drop, calls when the piece can go no further down. It's the only path from "active piece" back to "board".

The first check is for top-out. `CHECK_TOP_OUT_ON_LOCK` walks the piece bitmap looking for any occupied row whose board y is still negative — i.e., the piece is locking with part of itself above the visible field. That's the loss condition, and it short-circuits everything else: clearing lines doesn't matter once the game has already ended. `LOCK_GAME_OVER` merges the piece for the visual record (so the player sees the killing move land) and calls `ENTER_GAME_OVER`.

If top-out doesn't trigger, `MERGE_ACTIVE_TO_BOARD` paints the piece into the board. Same `SHIFT_ROW_MASK` as collision — the piece lands in exactly the cells the collision test said it could. The shifted mask gets ORed into `BOARD_ROWS` and into the colour planes whose bits are set in `CURRENT_PIECE_COLOR`. The active piece is now indistinguishable from any other landed cell; from the board's point of view, it never existed as a separate object.

`CHECK_FULL_ROWS` then sweeps `BOARD_ROWS` for bytes equal to 0xFF and records each match as a bit in `CLEAR_MASK`. If nothing's full, the lock sound plays and `SPAWN_ACTIVE_PIECE` brings in the next piece on the same loop iteration. If something is full, the program enters the line-clear hold: clear sound, `CLEAR_PENDING ← 1`, `CLEAR_TIMER` loaded with the hold duration, active piece disabled. The next spawn waits.

The hold has a visual side. While `CLEAR_PENDING` is set, the renderer treats the rows in `CLEAR_MASK` specially — it draws them solid white instead of in their stored colours, ignoring the colour planes for those rows. That's the clear flash. `LOGIC_TICK` routes to `HANDLE_LINE_CLEAR_STATE`, which counts the timer down once per logical frame (only when `LOGIC_SLICE == 0`, so the countdown is in frames not loop iterations). When it hits zero, `COLLAPSE_FULL_ROWS` finally runs the actual collapse.

The collapse has the rhythm of an in-place list compaction. Two pointers walk down the board: `D` reads, `E` writes. If the read row is in `CLEAR_MASK`, the read pointer skips it and keeps going, never copying it anywhere — that row is gone. Otherwise the read row's occupancy and colour bytes all move to the write row, and the write pointer advances. After the walk, any rows above the new top of the stack are zeroed. Occupancy and colour move together, by the way, so the picture and the simulation stay in step.

`APPLY_CLEAR_SCORE` then counts the bits in `CLEAR_MASK`, clamps at four, looks up the score delta in `CLEAR_SCORE_TABLE` — 100, 300, 500, 800 for one, two, three, four rows — and adds it to the 16-bit `SCORE`. The total line count goes up. If the score has crossed the difficulty threshold, `CURRENT_GRAVITY_PERIOD` drops to `GRAVITY_PERIOD_STEP1` and pieces start falling faster from the next gravity cycle onward. The HUD digits get refreshed and the next piece spawns. Play resumes.

---

## Rendering

Rendering is split between the slow slices (2–6) and the fast finish (7).

Slices 2 through 6 each blank one row of `FRAMEBUFFER_BACK`. By the time slice 7 fires, almost the whole back buffer is already zero; slice 7 blanks the last row and starts drawing.

`RENDER_BOARD_TO_BACK` is the floor of the scene. It walks each board row and copies the three colour bytes into the framebuffer. Two special cases live here. When `CLEAR_PENDING` is set, rows in `CLEAR_MASK` are written as 0xFF in all three channels — that's the white flash. When `GAME_OVER` is set, the colour planes are ignored entirely and the board is drawn in red on a single channel. The playfield turns into a tombstone silhouette.

`RENDER_ACTIVE_TO_BACK` draws the falling piece on top. It steps through the four rows of the piece bitmap, shifts each row by `PLAYER_X` (`SHIFT_ROW_MASK` again), skips rows that are above the field or below it, and ORs the shifted mask into the framebuffer through `WRITE_COLORED_ROW_MASK`. The active piece is layered, not composited — bits ORed on top of whatever the board put there, in the channels selected by `CURRENT_PIECE_COLOR`. Since collision has already made sure the active piece can't overlap a locked cell, the OR is safe.

`COPY_BACK_TO_FRONT` is two `LD` setups and an `LDIR`. The next `SCAN_TICK` reads the new frame.

---

## Pieces, rotations, randomness

Piece data lives in `data.asm`. Each rotation is a 4×4 bitmap stored as four bytes; the I piece has two rotations, the O piece one, the rest four. Three parallel tables key off (piece × rotation):

- `PIECE_PTR_TABLE` — pointer to the bitmap
- `PIECE_RIGHT_TABLE` — rightmost occupied column, for right-edge collision clamping
- `PIECE_COLOR_TABLE` — colour byte for `WRITE_COLORED_ROW_MASK`

`LOAD_CURRENT_ROTATION_STATE` reads all three at once and writes them into the live RAM fields. Collision, the renderer, and the merge routine read those fields without caring about the table layout. Adding a new piece is editing data, not code.

The RNG is an 8-bit Galois LFSR (`RNG_NEXT8`) advancing `RNG_SEED`. `RNG_NEXT_PIECE` masks the result to three bits, rejects 7, retries. The output is uniform over indices 0–6 — the seven tetrominoes — at the cost of throwing away one in eight RNG outputs. Cheap. The drawn piece sits in `NEXT_PIECE_INDEX` until the next spawn promotes it to `CURRENT_PIECE_INDEX`; the LCD reads `NEXT_PIECE_INDEX` through `PIECE_NAME_TABLE` to print the preview letter.

---

## LCD and score readout

The LCD is driven by tiny script tables. Each screen — running, paused, splash, game-over — is a list of (set-cursor command, string pointer) pairs ending in zero. `LCD_SHOW_SCRIPT` walks the list, sending each command and writing each string. The running and paused screens go through `LCD_SHOW_HUD`, which runs the script and then appends the next-piece preview letter as a final character. The script form means adding a screen, or moving a label, or rewording the game-over text, is a data change.

`LCD_REFRESH_NEXT_PREVIEW_ROW` is a faster variant that updates only the preview letter, used after each spawn so that piece-ahead changes don't require a full LCD redraw — and don't visibly flicker.

The score path is split between when-it-changes work and per-tick work. When the score changes, `UPDATE_SCORE_DISPLAY` divides it down by 10000, 1000, 100, 10, 1 (repeated subtraction; the Z80 has no DIV) and writes six segment patterns into `HUD_SEG_BUFFER`. Per scan tick, `SCAN_SCORE_DIGIT` lights one digit by reading one byte out of that buffer. The expensive part runs once per line clear; the cheap part runs once per matrix row. The seven-segment display stays solid even though no instruction holds it lit for more than a few microseconds at a time.

---

## A whole piece, beginning to end

Boot. `INIT_STATE` clears everything, raises `SPLASH_TIMER`, draws the splash. The loop starts spinning. `SCAN_TICK` keeps the matrix and the score lit. `FRAME_PHASE` climbs.

Eventually a key gets pressed.

`HANDLE_SPLASH_STATE` catches it. `RNG_SEED ← FRAME_PHASE`, generate the first upcoming piece, set `INPUT_LOCKOUT`, then `SPAWN_ACTIVE_PIECE`. Spawn promotes `NEXT_PIECE_INDEX` to current, generates a new upcoming piece, parks the active piece at `(3, SPAWN_Y)` above the visible field, resets cooldowns, and runs collision against the spawn position. Spawn-collision is the program's way of detecting a board so full there's no room for another piece — that lights `ENTER_GAME_OVER` immediately, before the player ever sees the new piece. Otherwise, `ACTIVE_PIECE_ENABLED` goes high and the LCD preview updates.

Now the loop is in regular play. Each iteration: one row of matrix scanned, one digit of score refreshed, one slice of game logic. Every eight iterations, one logical frame.

The player holds left. Slice 0 reads the keypress through `RST 0x10`, throttles repeats with `MOVE_COOLDOWN`, calls `MOVE_LEFT`, which writes `PENDING_X` and runs the collision probe. If the piece is at the wall, nothing happens — the test fails silently and `PLAYER_X` doesn't change. If not, the candidate commits.

In slice 1, eventually `GRAVITY_COOLDOWN` hits zero, `STEP_ACTIVE_DOWN_ONE_CELL` runs, the probe says yes, `PLAYER_Y` increments. A few logical frames later the probe says no — there's a board cell directly underneath the piece — and `LOCK_ACTIVE_PIECE` runs.

`CHECK_TOP_OUT_ON_LOCK` says the piece is in the field. `MERGE_ACTIVE_TO_BOARD` paints it into the board and colour planes. `CHECK_FULL_ROWS` scans for 0xFF rows. None: lock sound, immediate spawn, play continues. One or more: clear sound, the program drops into the hold state. The flash plays for a fixed number of logical frames. Then `COLLAPSE_FULL_ROWS` shoves the surviving rows down, the cleared rows vanish, `APPLY_CLEAR_SCORE` adds the score delta and possibly speeds up gravity, a new piece spawns.

That continues until eventually a piece locks above the top of the field. `CHECK_TOP_OUT_ON_LOCK` returns carry. `LOCK_GAME_OVER` merges the piece anyway, so the player sees the killing move land, then calls `ENTER_GAME_OVER`. The active piece disables, `GAME_OVER` latches, the game-over sound plays, the framebuffer rebuilds in red-silhouette mode, the LCD switches to its game-over message. The loop keeps spinning — `SCAN_TICK` is still drawing, the speaker is still finishing the groan, the score is still on the digits — but `LOGIC_TICK` is now stuck in the game-over branch. After a short gate (so the player can't accidentally insta-restart by still holding the drop key from the killing move), `POLL_GAME_OVER_RESTART` starts watching for a fresh keypress. When it sees one, `INIT_STATE_RESTART` resets the world without resetting the RNG, and another piece falls.

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

That's the shape of the program: a loop that never blocks, a state machine that knows what mode it's in, a single source of truth for collision, a back buffer cleared across the same slices it took to draw the previous frame. Everything else is bookkeeping.
