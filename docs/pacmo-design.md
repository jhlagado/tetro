````markdown
# Mini Pac-Style Game Design Plan for a Z80-Based 8×8 RGB LED System

## 1. Project Goal

Build a Pacmo-inspired maze game for a Z80-based system using an 8×8 RGB LED display as the main game viewport.

The physical display is extremely low resolution, so the game should not attempt to reproduce Pacmo directly. Instead, it should capture the core gameplay ideas:

- Navigate a maze.
- Eat pills.
- Avoid moving enemies.
- Use power pills to temporarily reverse the predator/prey relationship.
- Gradually learn the maze through repeated play.
- Increase difficulty over time by adding enemies and changing enemy behaviour.

The key design decision is that the visible 8×8 LED grid is only a viewport into a larger maze, rather than the entire game board.

The proposed initial world size is:

- Logical maze: 15×15 cells.
- Visible viewport: 8×8 cells.
- Display: 8×8 RGB LEDs.
- Controls: hexadecimal keypad.
- Score/status: six-digit seven-segment display and/or LCD.

This gives enough maze complexity to feel like a real game, while keeping the world small enough that the player can gradually memorise it.

---

## 2. Hardware Assumptions

The system has:

- A Z80 processor.
- An 8×8 RGB LED matrix.
- LED scanning driven through latches.
- Four latches available for display output or related control.
- A hexadecimal keypad for player input.
- An LCD for status, instructions, level text, or debugging.
- A six-digit seven-segment display for score, lives, level number, or counters.

The 8×8 RGB LED matrix is the main playfield. The LCD and seven-segment display should be used to remove non-essential information from the main display.

The LED matrix should only show immediate game state:

- Maze walls.
- Pills.
- Power pills.
- Player.
- Enemies.

The score, lives, level number, and messages should be displayed elsewhere.

---

## 3. Core Design Decision

The game should use a larger logical maze with a scrolling 8×8 viewport.

Avoid making the whole game fit inside a single static 8×8 maze.

A static 8×8 maze is possible, but it is too constrained:

- The maze feels more like a small puzzle box than a Pacmo-style maze.
- Only one enemy is likely to be viable.
- There is little room for enemy behaviour.
- There is little chance for the player to develop spatial memory.
- Most encounters become immediate and unavoidable.

A 15×15 maze with an 8×8 viewport gives a better balance:

- The player sees only part of the maze.
- The player gradually learns the layout.
- The world is large enough for meaningful navigation.
- Enemies can exist outside the current view.
- The game becomes tense without being completely chaotic.
- The maze is still small enough to fit comfortably in memory.

This gives the game a claustrophobic, exploratory feel that is closer to Pacmo than a pure 8×8 arena.

---

## 4. World Model

The game world is a 15×15 logical grid.

Each cell in the grid represents one possible position in the maze.

A cell may contain:

- A wall.
- Empty path.
- A regular pill.
- A power pill.

The moving objects are not stored directly in the board map. Instead, they are separate entities with coordinates.

The board is the playing surface.

The entities are drawn over the top of the board.

This means the game has two conceptual layers:

1. Board layer:
   - Walls.
   - Empty floor.
   - Uneaten pills.
   - Uneaten power pills.

2. Entity layer:
   - Player.
   - Enemies.

During rendering, draw the board first, then draw the entities on top.

This avoids the problem where an enemy moving over a pill accidentally consumes or erases the pill. Only the player consumes pills.

---

## 5. Maze Size

Start with a 15×15 maze.

The outer edge of the maze should be solid wall:

- Row 0 is wall.
- Row 14 is wall.
- Column 0 is wall.
- Column 14 is wall.

The playable interior is therefore 13×13.

This gives enough room for:

- Outer corridors.
- Internal walls.
- Intersections.
- Loops.
- Dead ends, if desired.
- Enemy movement.
- Power pill placement.

A 15×15 grid gives a useful internal rhythm:

- Seven possible path columns if using alternating wall/path structure.
- Six possible internal wall columns between them.
- The same applies vertically.

That is already enough to create a recognisable maze.

A larger maze such as 23×23 can be considered later, but it should not be the starting point. A maze that is too large relative to the 8×8 viewport may become confusing rather than interesting.

---

## 6. Viewport Model

The visible display is an 8×8 viewport into the larger 15×15 maze.

The viewport has an origin:

- `viewX`
- `viewY`

These represent the top-left logical cell currently visible on the LED matrix.

The player has a world position:

- `playerX`
- `playerY`

To render the player on the LED matrix:

- `screenX = playerX - viewX`
- `screenY = playerY - viewY`

Only draw the player if:

- `0 <= screenX < 8`
- `0 <= screenY < 8`

The same conversion is used for enemies.

---

## 7. Camera / Scrolling Behaviour

The preferred camera model is a scrolling viewport over a finite maze with hard outer walls.

This should feel similar to moving through a document or text editor with a cursor, but with the camera trying to keep the player away from the edge of the viewport.

The player should not be allowed to wrap around the world. The 15×15 maze has hard walls.

This choice is closer to Pacmo-style maze learning than a toroidal world.

### Recommended camera rule

Try to keep the player near the centre of the 8×8 display.

Because 8×8 has no exact centre cell, choose a comfortable central zone rather than a single fixed centre.

Suggested central comfort zone:

- X positions 3 and 4.
- Y positions 3 and 4.

When the player moves:

1. Update the player position if the target cell is not a wall.
2. Adjust the viewport so the player remains near the centre where possible.
3. Clamp the viewport so it does not scroll outside the maze.

For a 15×15 maze and 8×8 viewport:

- `viewX` may range from 0 to 7.
- `viewY` may range from 0 to 7.

Because:

- `15 - 8 = 7`

So the viewport can show:

- Columns 0–7 through 7–14.
- Rows 0–7 through 7–14.

### Camera clamping

After movement:

- If `playerX - viewX < 3`, shift view left if possible.
- If `playerX - viewX > 4`, shift view right if possible.
- If `playerY - viewY < 3`, shift view up if possible.
- If `playerY - viewY > 4`, shift view down if possible.

Then clamp:

- `viewX = max(0, min(viewX, 7))`
- `viewY = max(0, min(viewY, 7))`

This means:

- In the middle of the maze, the player stays near the centre.
- Near world edges, the viewport stops scrolling and the player moves within the visible window.

This should give the player enough visibility ahead without making the world feel detached from the character.

---

## 8. Why Not Use a Toroidal World?

A toroidal world would wrap left/right and top/bottom. If the player exits one side of the maze, they re-enter from the opposite side.

That is interesting, but it creates a different game feel.

A toroidal maze with the player fixed in the centre of the display would feel more like:

- A space exploration game.
- A radar/crosshair navigation game.
- A wraparound arena.
- Something closer to Spacewar or Galaxian than Pacmo.

It would reduce the feeling of being trapped in a maze with hard walls.

For this project, the finite scrolling maze is probably the better first version because:

- It is closer to Pacmo.
- It supports maze memorisation.
- It gives clearer level boundaries.
- It makes corners and edges meaningful.
- It makes enemy encounters more legible.
- It works well with gradual difficulty progression.

A toroidal mode could be explored later as an alternate game mode.

---

## 9. Board Representation

The board can be stored as a 15×15 array.

Each cell should encode the static board state.

Recommended logical cell types:

- `WALL`
- `EMPTY`
- `PILL`
- `POWER_PILL`

This may be stored compactly using two bits per cell:

| Bits | Meaning |
|---|---|
| 00 | Empty path |
| 01 | Wall |
| 10 | Regular pill |
| 11 | Power pill |

For 15×15:

- 225 cells.
- Two bits per cell.
- 450 bits.
- About 57 bytes.

That is compact enough for a Z80 system.

However, for simpler implementation, especially early on, one byte per cell is acceptable:

- 225 bytes per maze.

If storing multiple mazes, compact encoding may become more useful.

---

## 10. Pill Representation

Pills should be part of the board layer.

A pill is not an entity.

A pill remains in its cell until the player enters that cell.

When the player moves into a cell:

- If the cell contains a regular pill:
  - Increase score.
  - Change the cell to `EMPTY`.
  - Decrease remaining pill count.

- If the cell contains a power pill:
  - Increase score.
  - Change the cell to `EMPTY`.
  - Decrease remaining pill count.
  - Trigger frightened mode for enemies.

Enemies do not affect pills.

If an enemy passes over a pill, the pill remains in the board data and will reappear when the enemy leaves that cell.

This is why enemies must be drawn as overlays rather than written into the board.

---

## 11. Entity Representation

The player and enemies should be stored as separate coordinate-based entities.

### Player state

The player needs:

- `x`
- `y`
- Current direction, optional.
- Requested direction, optional.
- Alive/dead state.

The player is rendered as a yellow LED.

### Enemy state

Each enemy needs:

- `x`
- `y`
- Current direction.
- Mode:
  - normal
  - frightened
  - returning, optional later
- Movement timer or speed counter.
- Optional personality type.

Enemies are rendered over the board.

Suggested colours:

| Entity | Colour |
|---|---|
| Player | Yellow |
| Normal enemy | Red |
| Frightened enemy | Cyan or magenta |
| Returning enemy, optional | Dim blue or white |

On an 8×8 RGB matrix, strong colour contrast is more important than graphical fidelity.

---

## 12. Rendering Pipeline

Each frame should be rendered to an 8×8 display buffer.

Do not write directly to the LED hardware while computing game state.

Use a small RGB framebuffer:

- 8×8 cells.
- Each cell stores a colour code.

Possible colour codes:

| Code | Meaning |
|---|---|
| 0 | Black/off |
| 1 | Blue wall |
| 2 | Green or white regular pill |
| 3 | White or green power pill |
| 4 | Yellow player |
| 5 | Red enemy |
| 6 | Cyan frightened enemy |
| 7 | Magenta frightened enemy or bonus |

The exact colour mapping can be adjusted depending on LED visibility.

### Render order

1. Clear the 8×8 framebuffer to black.
2. Draw the visible section of the board:
   - Walls.
   - Pills.
   - Power pills.
3. Draw enemies that are inside the viewport.
4. Draw the player if inside the viewport.
5. Push the framebuffer to the LED scanning system.

The player may be drawn last so that the player remains visible if overlapping an enemy during collision handling.

However, collision should normally be resolved before rendering.

---

## 13. Suggested Colour Scheme

A possible colour scheme:

| Object | Colour |
|---|---|
| Empty path | Black |
| Wall | Deep blue |
| Regular pill | Green |
| Power pill | White |
| Player | Yellow |
| Normal enemy | Red |
| Frightened enemy | Cyan |
| Bonus item, later | Magenta |

Alternative:

| Object | Colour |
|---|---|
| Regular pill | White |
| Power pill | Green |

The choice depends on visual clarity. On a tiny LED grid, power pills must stand out strongly.

---

## 14. Input Model

Use the hexadecimal keypad for direction control.

Possible mapping:

| Key | Direction |
|---|---|
| 2 | Up |
| 8 | Down |
| 4 | Left |
| 6 | Right |

Alternative mapping:

| Key | Direction |
|---|---|
| 5 | Up |
| 0 | Down |
| 7 | Left |
| 9 | Right |

The exact mapping should match keypad layout.

The game should allow buffered directional input.

For example:

- The player is moving left.
- The player presses up before reaching an intersection.
- The requested direction becomes up.
- When the player reaches a cell where up is possible, the player turns up.

This is important because low-resolution movement may otherwise feel stiff.

For an early version, movement can be one cell per tick with immediate direction changes.

---

## 15. Movement Model

The game is grid-based.

Each movement step moves an entity by one cell.

No sub-cell movement is required.

Each game tick:

1. Read input.
2. Determine requested player direction.
3. Move player if the target cell is open.
4. Check pill consumption.
5. Move enemies according to their timers and behaviour.
6. Check collisions.
7. Update camera.
8. Render.

Because the display is very small, movement speed should be slow enough for the player to understand what happened.

The game should probably run logic slower than the LED scan refresh.

For example:

- LED refresh: continuous, high frequency.
- Game logic tick: perhaps 4–8 moves per second, adjustable by level.

---

## 16. Collision Rules

A collision occurs when the player and an enemy occupy the same cell.

If an enemy is in normal mode:

- Player loses a life.
- Reset player position.
- Reset enemy positions.
- Optionally pause briefly.

If an enemy is in frightened mode:

- Enemy is defeated.
- Award score.
- Enemy returns to spawn or is temporarily removed.
- In a very simple version, the enemy can immediately respawn at its start position after a delay.

Because the display is low resolution, avoid overly complex collision timing. Cell overlap is enough.

---

## 17. Enemy Behaviour

Enemy behaviour should start simple and become more sophisticated over levels.

The original Pacmo used different ghost personalities, target tiles, scatter modes, chase modes, and frightened behaviour. This project does not need that level of sophistication.

However, the same basic idea can be adapted.

### Enemy modes

Use at least two modes:

1. Hunt mode:
   - Enemy tends to move toward the player.

2. Frightened mode:
   - Enemy tends to move away from the player.
   - Enemy changes colour.
   - Enemy may move slower.

Optional later mode:

3. Scatter mode:
   - Enemy heads toward a fixed corner or region.

### Basic enemy decision rule

At each intersection or decision point, an enemy chooses a direction.

It should not reverse direction unless forced, except in frightened mode or when a mode change occurs.

For each possible move:

- Ignore moves that hit walls.
- Optionally ignore the reverse of the current direction.
- Compute distance from the resulting cell to the player.

In hunt mode:

- Choose the move that minimises distance to the player.

In frightened mode:

- Choose the move that maximises distance from the player.

For distance, use Manhattan distance rather than Pythagorean distance:

- `distance = abs(enemyX - playerX) + abs(enemyY - playerY)`

Manhattan distance is better for grid movement because movement occurs horizontally and vertically.

It is also cheaper to compute on a Z80.

### Add randomness

Pure minimisation may become too predictable.

Add a small amount of randomness:

- In hunt mode, choose the best move most of the time.
- Occasionally choose a random legal move.
- In frightened mode, choose the move away from the player most of the time.
- Occasionally choose a random legal move.

Example:

- 75% best move.
- 25% random legal move.

This makes enemies feel alive without requiring complex artificial intelligence.

---

## 18. Enemy Difficulty Ramp

The game should ramp slowly.

Suggested progression:

### Level 1

- No enemies.
- Player simply learns maze and eats all pills.
- This teaches movement and scrolling.

### Level 2

- One enemy.
- Enemy moves randomly.
- Enemy may be slower than player.

### Level 3

- One enemy.
- Enemy uses simple hunt behaviour at intersections.

### Level 4

- Two enemies.
- One random.
- One hunter.

### Level 5

- Two enemies.
- Both hunt, but with randomness.

### Later levels

Increase difficulty by:

- Increasing enemy speed.
- Reducing frightened duration.
- Adding another enemy.
- Making enemies choose better paths.
- Reducing randomness in hunt mode.
- Increasing randomness in frightened mode.

The original Pacmo did not change the maze between levels. It increased difficulty through speed and enemy behaviour. This project should probably follow that pattern at first.

The maze should remain familiar so the player can develop mastery.

---

## 19. Power Pills

Power pills temporarily change the enemy mode.

When the player eats a power pill:

- All enemies enter frightened mode.
- Enemies change colour.
- A frightened timer starts.
- Enemies may slow down.
- Player can defeat enemies by colliding with them.

When the timer expires:

- Enemies return to normal mode.
- Enemies return to red.
- Hunt behaviour resumes.

On a tiny display, frightened mode must be visually obvious.

Use cyan or magenta for frightened enemies.

Optional warning:

- During the last few ticks of frightened mode, enemies could blink between cyan and red.
- This may be visually useful but is not required in the first version.

---

## 20. Maze Design

Use hand-designed mazes initially.

Do not generate random mazes at runtime for the first version.

Reason:

- The maze is small.
- Hand-designed mazes allow better control.
- Pacmo itself used a fixed maze.
- A familiar maze improves player learning.
- Runtime generation can be added later.

Store several mazes as data if desired, but begin with one good maze.

The maze should satisfy:

- All path cells are connected.
- No isolated pill pockets.
- No unreachable pills.
- Enough loops to avoid trivial trapping.
- A few narrow corridors to create tension.
- Power pills placed where they create interesting risk/reward decisions.
- Enemy spawn area placed away from the player start.

Avoid too many dead ends. Dead ends are dangerous in a game with limited visibility.

---

## 21. Example 15×15 Maze

Legend:

- `X` = wall
- `.` = regular pill/path
- `o` = power pill
- space = empty path without pill, if desired later

Initial version can treat every open path as containing a pill except the player spawn and enemy spawn cells.

Example:

```text
XXXXXXXXXXXXXXX
X.....X.......X
X.XXX.X.XXX.X.X
XoX.......X.XoX
X.X.XXX.X.X.X.X
X...X...X...X.X
XXX.X.X.XXX.X.X
X.....X.....X.X
X.XXX.XXX.X.X.X
X.X.....X.X...X
X.X.XXX.X.XXX.X
Xo..X.......XoX
X.XXX.X.XXX.X.X
X.....X.......X
XXXXXXXXXXXXXXX
````

This should be reviewed for connectivity and adjusted during implementation.

The goal is not symmetry for its own sake. The goal is readable movement and interesting choices within a small scrolling viewport.

---

## 22. Entity Starting Positions

Suggested starting positions for a 15×15 maze:

* Player:

  * Near lower-left or lower-middle.
  * Example: `(1, 13)` or `(7, 13)` if open.

* Enemy spawn:

  * Near upper-middle or centre.
  * Example: `(7, 7)` if open.

For early levels, enemies can spawn far enough away that the player has time to orient themselves.

The first level should have no enemy.

---

## 23. Game Loop

Basic loop:

1. Scan keypad.
2. Update requested player direction.
3. On movement tick:

   * Move player if possible.
   * Consume pill if present.
   * Check power pill.
   * Move enemies.
   * Check collisions.
   * Update timers.
   * Update viewport.
4. Render board and entities to framebuffer.
5. Refresh display.
6. Update seven-segment display or LCD as needed.

The LED matrix refresh should be independent of the game tick.

---

## 24. Data Structures

Suggested high-level data structures:

### Board

```text
board[15][15]
```

Each cell contains:

* wall
* empty
* pill
* power pill

### Player

```text
playerX
playerY
playerDir
playerRequestedDir
lives
```

### Enemy

For each enemy:

```text
enemyX
enemyY
enemyDir
enemyMode
enemyMoveCounter
enemySpawnX
enemySpawnY
```

### Camera

```text
viewX
viewY
```

### Game State

```text
score
level
remainingPills
frightenedTimer
gameMode
```

Possible game modes:

* title
* playing
* level complete
* player dead
* game over

---

## 25. Display Buffer

Use an 8×8 colour buffer:

```text
display[8][8]
```

Each cell stores a small colour index.

Rendering should be separate from game state.

This makes it easier to:

* Draw the board.
* Overlay entities.
* Blink objects.
* Debug rendering.
* Avoid corrupting the board state.

---

## 26. Scoring

Simple scoring model:

| Event        | Score          |
| ------------ | -------------- |
| Regular pill | 10             |
| Power pill   | 50             |
| Defeat enemy | 100            |
| Clear level  | Bonus optional |

The six-digit seven-segment display can show the score.

The LCD can show:

* Level number.
* Lives.
* Ready message.
* Game over message.
* Debug coordinates during development.

---

## 27. Implementation Phases

### Phase 1: Static board rendering

* Define a 15×15 maze.
* Define an 8×8 viewport.
* Render the visible part of the maze to the LED matrix.
* Allow manual adjustment of `viewX` and `viewY` for testing.

Success condition:

* The 8×8 display shows the correct window into the larger maze.

---

### Phase 2: Player movement

* Add player coordinates.
* Read keypad input.
* Move player one cell at a time.
* Block movement into walls.
* Scroll the viewport to keep player near the centre.
* Render player over the board.

Success condition:

* Player can move through the maze and the camera follows correctly.

---

### Phase 3: Pills

* Add pills to board.
* Render pills.
* Let player consume pills.
* Update score.
* Track remaining pills.
* Detect level completion.

Success condition:

* Player can clear the maze by eating all pills.

---

### Phase 4: One random enemy

* Add one enemy.
* Enemy moves through open cells.
* Enemy chooses random legal direction at intersections.
* Enemy does not consume pills.
* Collision with player causes life loss.

Success condition:

* Game is playable with one simple enemy.

---

### Phase 5: Hunt behaviour

* Add enemy hunt mode.
* Enemy chooses legal moves that reduce Manhattan distance to player.
* Add randomness so behaviour is not perfect.
* Tune speed.

Success condition:

* Enemy appears to chase the player without becoming impossibly efficient.

---

### Phase 6: Power pills and frightened mode

* Add power pills.
* Eating power pill changes enemy colour.
* Enemy movement switches to flee behaviour.
* Player can defeat frightened enemy.
* Frightened mode expires after timer.

Success condition:

* Predator/prey reversal works clearly.

---

### Phase 7: Difficulty progression

* Add levels.
* Level 1: no enemy.
* Level 2: one random enemy.
* Level 3: one hunting enemy.
* Later: more enemies, faster enemies, shorter frightened time.

Success condition:

* Game ramps gradually and remains playable.

---

### Phase 8: Maze refinement

* Tune the 15×15 maze.
* Ensure all path cells are connected.
* Remove unfair dead ends.
* Place power pills thoughtfully.
* Consider adding alternate mazes later.

Success condition:

* The maze is learnable, fair, and interesting.

---

## 28. Connectivity Checking

Even if mazes are hand-designed, add a small offline or development-time check to ensure:

* All non-wall cells are connected.
* All pills are reachable from the player start.
* Enemy spawn positions are valid.
* Power pills are reachable.

This can be done using flood fill:

1. Start from player start.
2. Visit all neighbouring non-wall cells.
3. Count reachable cells.
4. Compare with total non-wall cells.

For a 15×15 board this is trivial and could be done manually, in a tool, or even on the Z80 if desired.

Runtime checking is not required if mazes are prevalidated.

---

## 29. Why This Design Should Work

This design preserves the key Pacmo ideas while respecting the display constraints.

The 8×8 display alone is too small for a satisfying maze, but it is good as a viewport.

The 15×15 board gives enough space for:

* Maze learning.
* Exploration.
* Enemy pursuit.
* Tension.
* Level progression.

The use of separate board and entity layers keeps the implementation clean:

* Pills remain part of the world.
* Enemies move over pills without altering them.
* The player consumes pills.
* Rendering is deterministic and simple.

The camera system gives the player enough visibility without revealing the whole maze.

The game should start simple and ramp slowly, because the limited field of view already makes the game challenging.

---

## 30. Core Recommendation

Build the first version as:

* 15×15 finite maze.
* Hard outer walls.
* 8×8 scrolling viewport.
* Player kept near centre where possible.
* Board layer containing walls and pills.
* Entity layer containing player and enemies.
* One fixed maze at first.
* Gradual difficulty progression.
* Enemy behaviour based on simple Manhattan-distance attraction and repulsion.

Do not start with:

* Full toroidal wrapping.
* Runtime random maze generation.
* Complex enemy personalities.
* Large 23×23 or 31×31 mazes.
* Fully static 8×8 maze gameplay.

Those may be interesting later, but the 15×15 scrolling maze is the strongest first design.

```
```
