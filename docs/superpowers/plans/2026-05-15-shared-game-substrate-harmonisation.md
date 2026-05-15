# Shared Game Substrate Harmonisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract game-neutral runtime helpers from Tetro and Pacmo while moving game-specific behaviour back to local game files and preserving both binaries' intended behaviour.

**Architecture:** Treat `src/shared` as a contract boundary, not a convenience folder. Promote only hardware-shaped, buffer-shaped, or small pure helpers with explicit Input / Output / Clobbers comments; keep Tetro piece/input rules and Pacmo maze/entity rules local. Each assembly refactor is a small commit with both games built immediately afterward, plus register-contract review before moving to the next step.

**Tech Stack:** Z80 assembly, `asm80`, TEC-1G MON-3 ports, Git/GitHub, documentation in Markdown.

---

## Guardrails

- Do not change gameplay behaviour, sound meanings, LCD screen meanings, score events, or input action semantics.
- Do not move labels such as `MOVE_LEFT`, `ROTATE_CW`, `SOFT_DROP`, `PACMO_POWER_TIMER`, `MONSTER0`, `CURRENT_PIECE_PTR`, or `BOARD_ROWS` into `src/shared`.
- Every shared routine must have an explicit `Input`, `Output`, and `Clobbers` comment.
- Keep game-local wrappers where variable names are game-specific, especially score variables and LCD dynamic rows.
- Build Tetro and Pacmo after every meaningful assembly change.
- Prefer subagents for read-only contract audits and post-change review. Avoid parallel code-writing subagents for Z80 assembly unless their write sets are completely disjoint.
- If a helper needs a behaviour change, a callback framework, or a broad naming rewrite, stop and document the deferral instead of extracting it.

## File Structure

Expected final source shape:

```text
src/shared/inc/constants.asm          hardware constants and shared colour names
src/shared/scan_tick.asm              scanout loop support
src/shared/sound.asm                  speaker divider service
src/shared/hud.asm                    HUD scan, shared segment tables, decimal formatter
src/shared/lcd.asm                    LCD primitives plus row/table-character helpers
src/shared/framebuffer_core.asm       clear/copy buffer primitives
src/shared/framebuffer_draw.asm       generic RGB matrix drawing primitives
src/games/tetro/input.asm             Tetro keypad-to-action mapping
src/games/tetro/render.asm            Tetro board and active-piece rendering
src/games/pacmo/render.asm            Pacmo world/entity rendering
```

Documentation updated at the end of each affected step:

```text
README.md
docs/shared-codebase.md
docs/shared-game-substrate-design.md
docs/tetro-codebase.md
docs/pacmo-codebase.md
```

## Standard Verification Block

Run this after every assembly task:

```bash
git diff --check
(cd src && asm80 -m Z80 -t hex -o ../build/tetro.hex tetro.asm)
(cd src && asm80 -m Z80 -t bin -o ../build/tetro.bin tetro.asm)
(cd src && asm80 -m Z80 -t hex -o ../build/pacmo.hex pacmo.asm)
(cd src && asm80 -m Z80 -t bin -o ../build/pacmo.bin pacmo.asm)
```

Expected result: all commands exit 0. `git diff --check` prints no whitespace errors. `asm80` prints no assembler errors.

For tasks that should only rename files or replace constants with equivalent values, also compare before/after binaries:

```bash
cmp -s build/tetro.before-task.bin build/tetro.bin && echo "tetro unchanged"
cmp -s build/pacmo.before-task.bin build/pacmo.bin && echo "pacmo unchanged"
```

Expected result when a byte-identical comparison is required: the corresponding `echo` line is printed. If it is not printed, inspect the diff before continuing. Some extractions can legitimately change addresses or instruction bytes; those tasks call this out explicitly.

## Subagent Strategy

Use parallel subagents for independent read-only reviews, not for overlapping assembly edits.

Recommended read-only subagents before coding:

```text
Subagent A: Audit Tetro and Pacmo HUD routines. Confirm the score conversion loops, segment glyph tables, digit mask tables, RAM labels, and register clobber contracts are equivalent enough for a shared formatter plus game-local wrappers. Do not edit files. Report any contract mismatch with file/line references.

Subagent B: Audit Tetro and Pacmo LCD UI wrappers. Confirm which row-writing and table-indexed character append logic is generic, and identify registers callers rely on being preserved. Do not edit files. Report exact helper contracts that would be safe.

Subagent C: Audit framebuffer colour and matrix bit-mask helpers. Confirm Pacmo's `SCREEN_X_TO_MASK` coordinate convention and `WRITE_CELL_COLOR_C_A` contract, and compare Tetro's `WRITE_COLORED_ROW_MASK` with a possible shared `FB_OR_ROW_COLOR_MASK`. Do not edit files. Report unsafe cases.
```

Use post-task review subagents after each assembly commit:

```text
Review only the last commit. Focus on Z80 register contracts, include order, label resolution, and behaviour preservation for Tetro and Pacmo. Do not suggest broad style refactors. Findings must include file/line references.
```

Do not run two code-writing subagents against `src/tetro.asm`, `src/pacmo.asm`, `src/shared/*.asm`, or game data files at the same time. Those files are coupled by include order and shared labels.

---

### Task 1: Start From Latest Main And Capture Baselines

**Files:**
- No source edits.
- Produces local, untracked baseline artifacts in `build/`.

- [ ] **Step 1: Synchronise `main` and create the implementation branch**

```bash
git switch main
git pull --ff-only origin main
git switch -c codex/shared-game-substrate-harmonisation
mkdir -p build
```

Expected: `git pull` fast-forwards or reports "Already up to date"; new branch is created from current `main`.

- [ ] **Step 2: Build both games before edits**

```bash
git diff --check
(cd src && asm80 -m Z80 -t hex -o ../build/tetro.hex tetro.asm)
(cd src && asm80 -m Z80 -t bin -o ../build/tetro.bin tetro.asm)
(cd src && asm80 -m Z80 -t hex -o ../build/pacmo.hex pacmo.asm)
(cd src && asm80 -m Z80 -t bin -o ../build/pacmo.bin pacmo.asm)
```

Expected: all commands exit 0.

- [ ] **Step 3: Save baseline binaries and hashes**

```bash
cp build/tetro.bin build/tetro.baseline.bin
cp build/pacmo.bin build/pacmo.baseline.bin
shasum -a 256 build/tetro.baseline.bin build/pacmo.baseline.bin
```

Expected: two SHA-256 lines are printed. Paste those hashes into the PR description later.

- [ ] **Step 4: Dispatch read-only contract audit subagents in parallel**

Use the three prompts in "Subagent Strategy" for HUD, LCD, and framebuffer/color. Do not wait for all of them before reading source locally, but do not implement a task until the relevant audit has either reported no blocker or identified a blocker that is handled in the task.

Expected: each subagent returns either "no findings" or a short list of concrete contract risks.

---

### Task 2: Share HUD Segment Tables And Decimal Score Formatting

**Files:**
- Modify: `src/shared/hud.asm`
- Modify: `src/games/tetro/hud.asm`
- Modify: `src/games/pacmo/hud.asm`
- Modify: `src/games/tetro/data.asm`
- Modify: `src/games/pacmo/data.asm`

- [ ] **Step 1: Save pre-task binaries**

```bash
cp build/tetro.bin build/tetro.before-hud.bin
cp build/pacmo.bin build/pacmo.before-hud.bin
```

Expected: both files are copied.

- [ ] **Step 2: Add shared HUD tables and formatter to `src/shared/hud.asm`**

Add neutral tables and a 16-bit formatter after `BLANK_HUD_SCORE_DIGITS`. Update `SCAN_SCORE_DIGIT` to use `HUD_DIGIT_MASK_TABLE`.

```asm
        LD      DE,HUD_DIGIT_MASK_TABLE
```

Add this formatter and data:

```asm
; HUD_WRITE_U16_DECIMAL
; Input:
;   HL = unsigned 16-bit value
; Output:
;   HUD_SEG_BUFFER[0] = '0' glyph
;   HUD_SEG_BUFFER[1..5] = five decimal digits for HL
; Clobbers:
;   A, BC, DE, HL
HUD_WRITE_U16_DECIMAL:
        LD      A,(HUD_SEG_GLYPH_TABLE)
        LD      (HUD_SEG_BUFFER),A
        LD      BC,HUD_SEG_BUFFER+1

        LD      DE,0x2710              ; 10000
        CALL    HUD_WRITE_DECIMAL_DIGIT
        LD      DE,0x03E8              ; 1000
        CALL    HUD_WRITE_DECIMAL_DIGIT
        LD      DE,0x0064              ; 100
        CALL    HUD_WRITE_DECIMAL_DIGIT
        LD      DE,0x000A              ; 10
        CALL    HUD_WRITE_DECIMAL_DIGIT
        LD      DE,0x0001              ; 1
        CALL    HUD_WRITE_DECIMAL_DIGIT
        RET

; HUD_WRITE_DECIMAL_DIGIT
; Input:
;   HL = score/value remainder
;   DE = decimal divisor
;   BC = destination byte in HUD_SEG_BUFFER
; Output:
;   HL = updated remainder
;   BC = advanced to next destination
; Clobbers:
;   A, DE
HUD_WRITE_DECIMAL_DIGIT:
        XOR     A
HUD_WRITE_DECIMAL_DIGIT_LOOP:
        PUSH    AF
        LD      A,H
        CP      D
        JR      C,HUD_WRITE_DECIMAL_DIGIT_DONE
        JR      NZ,HUD_WRITE_DECIMAL_DIGIT_SUB
        LD      A,L
        CP      E
        JR      C,HUD_WRITE_DECIMAL_DIGIT_DONE
HUD_WRITE_DECIMAL_DIGIT_SUB:
        POP     AF
        OR      A
        SBC     HL,DE
        INC     A
        JR      HUD_WRITE_DECIMAL_DIGIT_LOOP
HUD_WRITE_DECIMAL_DIGIT_DONE:
        POP     AF
        PUSH    HL
        PUSH    BC
        LD      L,A
        LD      H,0
        LD      DE,HUD_SEG_GLYPH_TABLE
        ADD     HL,DE
        LD      A,(HL)
        POP     BC
        LD      (BC),A
        INC     BC
        POP     HL
        RET

HUD_DIGIT_MASK_TABLE:
        DB      0x20
        DB      0x10
        DB      0x08
        DB      0x04
        DB      0x02
        DB      0x01

HUD_SEG_GLYPH_TABLE:
        DB      0xEB
        DB      0x28
        DB      0xCD
        DB      0xAD
        DB      0x2E
        DB      0xA7
        DB      0xE7
        DB      0x29
        DB      0xEF
        DB      0x2F
        DB      0x6F
        DB      0xE6
        DB      0xC3
        DB      0xEC
        DB      0xC7
        DB      0x47
```

Expected: `SCAN_SCORE_DIGIT` no longer references game-local `DIGIT_MASK_TABLE`.

- [ ] **Step 3: Replace Tetro score formatter with a wrapper**

Replace `src/games/tetro/hud.asm` with:

```asm
; UPDATE_SCORE_DISPLAY
; Input:
;   SCORE_LO / SCORE_HI
; Output:
;   HUD_SEG_BUFFER updated with a six-digit decimal score display
; Clobbers:
;   A, BC, DE, HL
UPDATE_SCORE_DISPLAY:
        LD      HL,(SCORE_LO)
        JP      HUD_WRITE_U16_DECIMAL
```

Expected: Tetro keeps the public `UPDATE_SCORE_DISPLAY` label and game-local score variable names.

- [ ] **Step 4: Replace Pacmo score formatter with a wrapper**

Replace `src/games/pacmo/hud.asm` with:

```asm
; Pacmo-local score display wrapper. Seven-segment scan and decimal
; formatting helpers live in shared/hud.asm.

; UPDATE_SCORE_DISPLAY
; Input:
;   PACMO_SCORE
; Output:
;   HUD_SEG_BUFFER updated with a six-digit decimal score display
; Clobbers:
;   A, BC, DE, HL
UPDATE_SCORE_DISPLAY:
        LD      HL,(PACMO_SCORE)
        JP      HUD_WRITE_U16_DECIMAL
```

Expected: Pacmo keeps the public `UPDATE_SCORE_DISPLAY` label and `PACMO_SCORE` remains local.

- [ ] **Step 5: Remove duplicated HUD tables from game data**

Delete `DIAG_SEG_TABLE` and `DIGIT_MASK_TABLE` from `src/games/tetro/data.asm`.

Delete `PACMO_HEX_SEG_TABLE` and `DIGIT_MASK_TABLE` from `src/games/pacmo/data.asm`.

Expected: these labels are absent from game data:

```bash
rg -n "DIAG_SEG_TABLE|PACMO_HEX_SEG_TABLE|^DIGIT_MASK_TABLE:" src/games
```

Expected output: no matches.

- [ ] **Step 6: Build both games**

Run the Standard Verification Block.

Expected: both games build. Binary identity is not required because code and data moved into a shared include location, but review any unexpectedly large binary-size change.

- [ ] **Step 7: Review register contracts**

Check every `CALL UPDATE_SCORE_DISPLAY` and verify callers already allow `A, BC, DE, HL` to be clobbered:

```bash
rg -n "CALL\\s+UPDATE_SCORE_DISPLAY|JP\\s+UPDATE_SCORE_DISPLAY" src/games src/*.asm
```

Expected: all call sites are in score update or init paths that do not rely on those registers afterward.

- [ ] **Step 8: Commit**

```bash
git add src/shared/hud.asm src/games/tetro/hud.asm src/games/pacmo/hud.asm src/games/tetro/data.asm src/games/pacmo/data.asm
git commit -m "refactor: share HUD decimal formatting"
```

Expected: one focused commit.

---

### Task 3: Move Tetro-Shaped Helpers Out Of `src/shared`

**Files:**
- Move: `src/shared/input.asm` to `src/games/tetro/input.asm`
- Move: `src/shared/framebuffer.asm` to `src/games/tetro/render.asm`
- Modify: `src/tetro.asm`

- [ ] **Step 1: Save pre-task binaries**

```bash
cp build/tetro.bin build/tetro.before-tetro-local-move.bin
cp build/pacmo.bin build/pacmo.before-tetro-local-move.bin
```

Expected: both files are copied.

- [ ] **Step 2: Move the files with Git**

```bash
git mv src/shared/input.asm src/games/tetro/input.asm
git mv src/shared/framebuffer.asm src/games/tetro/render.asm
```

Expected: Git records two renames.

- [ ] **Step 3: Update `src/tetro.asm` include paths**

Change:

```asm
        .include "shared/framebuffer.asm"
...
        .include "shared/input.asm"
```

To:

```asm
        .include "games/tetro/render.asm"
...
        .include "games/tetro/input.asm"
```

Expected: include order is otherwise unchanged.

- [ ] **Step 4: Build both games and compare binaries**

Run the Standard Verification Block, then:

```bash
cmp -s build/tetro.before-tetro-local-move.bin build/tetro.bin && echo "tetro unchanged"
cmp -s build/pacmo.before-tetro-local-move.bin build/pacmo.bin && echo "pacmo unchanged"
```

Expected: both `echo` lines are printed. This task is only a file relocation and include-path update; binary output should be identical.

- [ ] **Step 5: Commit**

```bash
git add src/tetro.asm src/games/tetro/input.asm src/games/tetro/render.asm src/shared/input.asm src/shared/framebuffer.asm
git commit -m "refactor: keep Tetro-specific helpers local"
```

Expected: one focused commit with two renames and one include-path edit.

---

### Task 4: Add Generic LCD Row And Table Character Helpers

**Files:**
- Modify: `src/shared/lcd.asm`
- Modify: `src/games/tetro/ui.asm`
- Modify: `src/games/pacmo/ui.asm`

- [ ] **Step 1: Save pre-task binaries**

```bash
cp build/tetro.bin build/tetro.before-lcd-helpers.bin
cp build/pacmo.bin build/pacmo.before-lcd-helpers.bin
```

Expected: both files are copied.

- [ ] **Step 2: Add `LCD_WRITE_ROW_STRING` and `LCD_PUTC_FROM_TABLE`**

Append these helpers to `src/shared/lcd.asm` after `LCD_PUTC`:

```asm
; LCD_WRITE_ROW_STRING
; Input:
;   B  = LCD row command
;   HL = zero-terminated ASCII string
; Output:
;   LCD cursor moved to row and string written
; Clobbers:
;   A, HL
LCD_WRITE_ROW_STRING:
        CALL    LCD_COMMAND
        JP      LCD_STRING

; LCD_PUTC_FROM_TABLE
; Input:
;   A  = table index
;   DE = table base
; Output:
;   indexed character written at current LCD cursor position
; Clobbers:
;   A, HL
LCD_PUTC_FROM_TABLE:
        LD      L,A
        LD      H,0
        ADD     HL,DE
        LD      A,(HL)
        JP      LCD_PUTC
```

Expected: neither helper names Tetro or Pacmo state.

- [ ] **Step 3: Use the table helper in Tetro's preview letter wrapper**

Change `LCD_APPEND_NEXT_PREVIEW_LETTER` in `src/games/tetro/ui.asm` to:

```asm
LCD_APPEND_NEXT_PREVIEW_LETTER:
        LD      A,(NEXT_PIECE_INDEX)
        LD      DE,PIECE_NAME_TABLE
        JP      LCD_PUTC_FROM_TABLE
```

Expected: wrapper still owns `NEXT_PIECE_INDEX` and `PIECE_NAME_TABLE`.

- [ ] **Step 4: Use the row helper in Tetro's preview row refresh**

Change the row setup in `LCD_REFRESH_NEXT_PREVIEW_ROW` to:

```asm
        LD      B,LCD_ROW2
        LD      HL,LCD_TEXT_NEXT
        CALL    LCD_WRITE_ROW_STRING
        CALL    LCD_APPEND_NEXT_PREVIEW_LETTER
```

Expected: existing `PUSH BC`, `PUSH HL`, `POP HL`, and `POP BC` remain, preserving the wrapper's public contract.

- [ ] **Step 5: Use both helpers in Pacmo's level row refresh**

Change `LCD_REFRESH_LEVEL_ROW` in `src/games/pacmo/ui.asm` to:

```asm
        PUSH    BC
        LD      B,LCD_ROW2
        LD      HL,LCD_TEXT_PACMO_LEVEL
        CALL    LCD_WRITE_ROW_STRING
        LD      A,(PACMO_LEVEL)
        AND     0x0F
        LD      DE,PACMO_LEVEL_CHAR_TABLE
        CALL    LCD_PUTC_FROM_TABLE
        POP     BC
        RET
```

Expected: Pacmo still owns `PACMO_LEVEL` and `PACMO_LEVEL_CHAR_TABLE`.

- [ ] **Step 6: Build both games**

Run the Standard Verification Block.

Expected: both games build. Binary identity is not required because call sequences change, but LCD output should remain the same by inspection.

- [ ] **Step 7: Review caller register assumptions**

Check callers of the changed LCD wrappers:

```bash
rg -n "LCD_REFRESH_NEXT_PREVIEW_ROW|LCD_APPEND_NEXT_PREVIEW_LETTER|LCD_REFRESH_LEVEL_ROW" src
```

Expected: callers do not depend on registers beyond each wrapper's documented contract.

- [ ] **Step 8: Commit**

```bash
git add src/shared/lcd.asm src/games/tetro/ui.asm src/games/pacmo/ui.asm
git commit -m "refactor: share LCD row helper primitives"
```

Expected: one focused commit.

---

### Task 5: Add Generic Framebuffer Draw Primitives

**Files:**
- Create: `src/shared/framebuffer_draw.asm`
- Modify: `src/tetro.asm`
- Modify: `src/pacmo.asm`
- Modify: `src/games/tetro/render.asm`
- Modify: `src/games/pacmo/render.asm`
- Modify: `src/games/pacmo/movement.asm`

- [ ] **Step 1: Save pre-task binaries**

```bash
cp build/tetro.bin build/tetro.before-framebuffer-draw.bin
cp build/pacmo.bin build/pacmo.before-framebuffer-draw.bin
```

Expected: both files are copied.

- [ ] **Step 2: Create `src/shared/framebuffer_draw.asm`**

Add:

```asm
; Generic RGB framebuffer drawing helpers.

; MATRIX_X_TO_MASK
; Input:
;   A = screen x coordinate, expected 0..7
; Output:
;   A = bit mask with column 0 as the most significant bit
; Clobbers:
;   B, C
MATRIX_X_TO_MASK:
        LD      C,A
        OR      A
        LD      A,0x80
        JR      Z,MATRIX_X_TO_MASK_DONE
        LD      B,C
MATRIX_X_TO_MASK_LOOP:
        SRL     A
        DJNZ    MATRIX_X_TO_MASK_LOOP
MATRIX_X_TO_MASK_DONE:
        RET

; FB_SET_CELL_COLOR
; Input:
;   HL = red plane byte for target row
;   C  = target cell bit mask
;   A  = COLOR_* bitfield
; Output:
;   target cell set to requested color, replacing previous RGB bits
;   HL = blue plane byte for target row
; Clobbers:
;   A, B, D, HL
FB_SET_CELL_COLOR:
        LD      B,A
        LD      A,C
        CPL
        LD      D,A
        LD      A,B
        AND     COLOR_RED
        JR      Z,FB_SET_CELL_RED_OFF
        LD      A,(HL)
        OR      C
        JR      FB_SET_CELL_RED_STORE
FB_SET_CELL_RED_OFF:
        LD      A,(HL)
        AND     D
FB_SET_CELL_RED_STORE:
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     COLOR_GREEN
        JR      Z,FB_SET_CELL_GREEN_OFF
        LD      A,(HL)
        OR      C
        JR      FB_SET_CELL_GREEN_STORE
FB_SET_CELL_GREEN_OFF:
        LD      A,(HL)
        AND     D
FB_SET_CELL_GREEN_STORE:
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     COLOR_BLUE
        JR      Z,FB_SET_CELL_BLUE_OFF
        LD      A,(HL)
        OR      C
        JR      FB_SET_CELL_BLUE_STORE
FB_SET_CELL_BLUE_OFF:
        LD      A,(HL)
        AND     D
FB_SET_CELL_BLUE_STORE:
        LD      (HL),A
        RET

; FB_OR_ROW_COLOR_MASK
; Input:
;   HL = framebuffer row red-byte address
;   C  = row mask
;   A  = COLOR_* bitfield
; Output:
;   mask ORed into enabled red, green, blue bytes
;   HL = blue plane byte for target row
; Clobbers:
;   A, HL
; Preserves:
;   BC
FB_OR_ROW_COLOR_MASK:
        PUSH    BC
        LD      B,3
FB_OR_ROW_COLOR_MASK_LOOP:
        RRCA
        JR      NC,FB_OR_ROW_COLOR_MASK_SKIP
        PUSH    AF
        LD      A,(HL)
        OR      C
        LD      (HL),A
        POP     AF
FB_OR_ROW_COLOR_MASK_SKIP:
        DEC     B
        JR      Z,FB_OR_ROW_COLOR_MASK_EXIT
        INC     HL
        JR      FB_OR_ROW_COLOR_MASK_LOOP
FB_OR_ROW_COLOR_MASK_EXIT:
        POP     BC
        RET
```

Expected: all names are matrix/framebuffer/colour-neutral.

- [ ] **Step 3: Include the new shared draw helpers in both targets**

In `src/tetro.asm`, include the new file after `shared/framebuffer_core.asm` and before `games/tetro/render.asm`:

```asm
        .include "shared/framebuffer_core.asm"
        .include "shared/framebuffer_draw.asm"
        .include "games/tetro/render.asm"
```

In `src/pacmo.asm`, include the new file after `shared/framebuffer_core.asm`:

```asm
        .include "shared/framebuffer_core.asm"
        .include "shared/framebuffer_draw.asm"
        .include "games/pacmo/render.asm"
```

Expected: Pacmo movement can still forward-reference `MATRIX_X_TO_MASK` because `asm80` resolves forward labels.

- [ ] **Step 4: Update Tetro render to use `FB_OR_ROW_COLOR_MASK`**

In `src/games/tetro/render.asm`, replace:

```asm
        CALL    WRITE_COLORED_ROW_MASK
```

With:

```asm
        LD      A,(CURRENT_PIECE_COLOR)
        CALL    FB_OR_ROW_COLOR_MASK
```

Then delete the local `WRITE_COLORED_ROW_MASK` routine.

Expected: `RENDER_ACTIVE_TO_BACK` still preserves its caller's `BC`, `DE`, and `HL` by using its existing pushes around the call.

- [ ] **Step 5: Update Pacmo render and movement to use shared draw labels**

Replace Pacmo calls:

```asm
CALL    SCREEN_X_TO_MASK
JP      WRITE_CELL_COLOR_C_A
```

With:

```asm
CALL    MATRIX_X_TO_MASK
JP      FB_SET_CELL_COLOR
```

Then delete local `WRITE_CELL_COLOR_C_A` and `SCREEN_X_TO_MASK` from `src/games/pacmo/render.asm`.

Run:

```bash
rg -n "SCREEN_X_TO_MASK|WRITE_CELL_COLOR_C_A|WRITE_COLORED_ROW_MASK" src
```

Expected output: no matches.

- [ ] **Step 6: Build both games**

Run the Standard Verification Block.

Expected: both games build. Binary identity is not required because helpers moved into a new include and Tetro's row-mask helper now takes the colour in `A`.

- [ ] **Step 7: Review register contracts at every new call site**

Check:

```bash
rg -n "MATRIX_X_TO_MASK|FB_SET_CELL_COLOR|FB_OR_ROW_COLOR_MASK" src
```

Expected:
- Pacmo callers tolerate `MATRIX_X_TO_MASK` clobbering `B, C`.
- Pacmo callers pass `HL`, `C`, and `A` exactly as `FB_SET_CELL_COLOR` requires.
- Tetro caller loads `CURRENT_PIECE_COLOR` into `A` after preserving row mask in `C`.
- Tetro caller's `B` loop counter survives `FB_OR_ROW_COLOR_MASK`.

- [ ] **Step 8: Commit**

```bash
git add src/shared/framebuffer_draw.asm src/tetro.asm src/pacmo.asm src/games/tetro/render.asm src/games/pacmo/render.asm src/games/pacmo/movement.asm
git commit -m "refactor: share framebuffer draw primitives"
```

Expected: one focused commit.

---

### Task 6: Add Shared Composite Colour Constants

**Files:**
- Modify: `src/shared/inc/constants.asm`
- Modify: `src/games/tetro/data.asm`
- Modify: `src/games/pacmo/data.asm`

- [ ] **Step 1: Save pre-task binaries**

```bash
cp build/tetro.bin build/tetro.before-colour-constants.bin
cp build/pacmo.bin build/pacmo.before-colour-constants.bin
```

Expected: both files are copied.

- [ ] **Step 2: Add colour constants**

In `src/shared/inc/constants.asm`, replace the colour block with:

```asm
COLOR_BLACK:    EQU     0x00
COLOR_RED:      EQU     0x01
COLOR_GREEN:    EQU     0x02
COLOR_BLUE:     EQU     0x04
COLOR_YELLOW:   EQU     COLOR_RED+COLOR_GREEN
COLOR_CYAN:     EQU     COLOR_GREEN+COLOR_BLUE
COLOR_MAGENTA:  EQU     COLOR_RED+COLOR_BLUE
COLOR_WHITE:    EQU     COLOR_RED+COLOR_GREEN+COLOR_BLUE
```

Expected: existing primary colour values do not change.

- [ ] **Step 3: Update Tetro palette language**

Change `PIECE_COLOR_TABLE` in `src/games/tetro/data.asm` to:

```asm
PIECE_COLOR_TABLE:
        DB      COLOR_CYAN                         ; I
        DB      COLOR_WHITE                        ; O
        DB      COLOR_MAGENTA                      ; T
        DB      COLOR_GREEN                        ; S
        DB      COLOR_RED                          ; Z
        DB      COLOR_BLUE                         ; J
        DB      COLOR_YELLOW                       ; L
```

Expected: emitted bytes are unchanged.

- [ ] **Step 4: Update Pacmo palette language**

Change Pacmo colour aliases in `src/games/pacmo/data.asm` to:

```asm
PACMO_COLOR_WALL: EQU COLOR_BLUE
PACMO_COLOR_PATH: EQU COLOR_GREEN
PACMO_COLOR_PLAYER: EQU COLOR_YELLOW
PACMO_COLOR_POWER_PILL: EQU COLOR_WHITE
PACMO_COLOR_ENEMY_ATTACK: EQU COLOR_RED
PACMO_COLOR_ENEMY_FLEE: EQU COLOR_MAGENTA
PACMO_COLOR_GAME_OVER: EQU COLOR_RED
PACMO_COLOR_CAUGHT_WALL: EQU COLOR_RED
PACMO_COLOR_COMPLETE_WALL: EQU COLOR_WHITE
PACMO_COLOR_ROUND_COMPLETE: EQU COLOR_WHITE
```

Expected: emitted bytes are unchanged.

- [ ] **Step 5: Build both games and compare binaries**

Run the Standard Verification Block, then:

```bash
cmp -s build/tetro.before-colour-constants.bin build/tetro.bin && echo "tetro unchanged"
cmp -s build/pacmo.before-colour-constants.bin build/pacmo.bin && echo "pacmo unchanged"
```

Expected: both `echo` lines are printed. This task only changes symbolic names for existing values.

- [ ] **Step 6: Commit**

```bash
git add src/shared/inc/constants.asm src/games/tetro/data.asm src/games/pacmo/data.asm
git commit -m "refactor: standardise shared colour names"
```

Expected: one focused commit.

---

### Task 7: Defer Risky Logic-Slice And Timer Extraction Explicitly

**Files:**
- Modify: `docs/shared-game-substrate-design.md`

- [ ] **Step 1: Audit the exact duplicate logic-slice tail**

Compare:

```bash
sed -n '80,95p' src/games/tetro/logic_dispatch.asm
sed -n '68,80p' src/games/pacmo/logic_dispatch.asm
```

Expected: both games still increment `LOGIC_SLICE` modulo 8 with the same instruction sequence.

- [ ] **Step 2: Document the deferral**

Add a short note under "Priority 6: Tiny timer and slice helpers":

```markdown
Implementation note: leave `LOGIC_SLICE_NEXT` local for now. Although the instruction sequence is duplicated, extracting it naively would either add a tail jump/call or move a `JR` target farther away. On this hardware, scan-loop timing and branch locality matter more than removing four duplicated instructions. Revisit only if a future assembler macro/include pattern can keep the emitted bytes and local branch shape equivalent.
```

Expected: the document explains why this obvious duplication is intentionally not removed yet.

- [ ] **Step 3: Validate docs**

Run:

```bash
git diff --check
ruby -e 'ok=true; Dir["README.md","docs/**/*.md"].flatten.each { |f| text=File.read(f); text.scan(/\[[^\]]+\]\(([^)]+)\)/).flatten.each { |href| next if href =~ /\A(?:https?:|mailto:|#)/; path=href.split("#",2).first; next if path.empty?; target=File.expand_path(path, File.dirname(f)); unless File.exist?(target); warn "#{f}: missing #{href}"; ok=false; end } }; exit(ok ? 0 : 1)'
```

Expected: both commands exit 0.

- [ ] **Step 4: Commit**

```bash
git add docs/shared-game-substrate-design.md
git commit -m "docs: defer logic slice extraction"
```

Expected: one documentation-only commit.

---

### Task 8: Synchronise Codebase Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/shared-codebase.md`
- Modify: `docs/shared-game-substrate-design.md`
- Modify: `docs/tetro-codebase.md`
- Modify: `docs/pacmo-codebase.md`

- [ ] **Step 1: Update source layout references**

Update any references to the old transitional files:

```bash
rg -n "shared/framebuffer\\.asm|shared/input\\.asm|shared-runtime|DIAG_SEG_TABLE|PACMO_HEX_SEG_TABLE|SCREEN_X_TO_MASK|WRITE_CELL_COLOR_C_A|WRITE_COLORED_ROW_MASK" README.md docs
```

Expected after edits: no stale references remain, except when intentionally describing historical context in the design document.

- [ ] **Step 2: Update `docs/shared-codebase.md`**

Document:

- `src/shared/hud.asm` owns `HUD_DIGIT_MASK_TABLE`, `HUD_SEG_GLYPH_TABLE`, `HUD_WRITE_U16_DECIMAL`, and `HUD_WRITE_DECIMAL_DIGIT`.
- `src/shared/lcd.asm` owns `LCD_WRITE_ROW_STRING` and `LCD_PUTC_FROM_TABLE`.
- `src/shared/framebuffer_draw.asm` owns `MATRIX_X_TO_MASK`, `FB_SET_CELL_COLOR`, and `FB_OR_ROW_COLOR_MASK`.
- `shared/input.asm` and `shared/framebuffer.asm` no longer exist as transitional shared files.

Expected: shared docs match source layout.

- [ ] **Step 3: Update game codebase docs**

In `docs/tetro-codebase.md`, document that:

- Tetro input mapping is local in `src/games/tetro/input.asm`.
- Tetro rendering is local in `src/games/tetro/render.asm`.
- Tetro uses shared HUD formatting, LCD primitives, and framebuffer draw primitives.

In `docs/pacmo-codebase.md`, document that:

- Pacmo score formatting goes through the shared HUD formatter via a local wrapper.
- Pacmo cell rendering uses `FB_SET_CELL_COLOR`.
- Pacmo x-to-mask conversion uses `MATRIX_X_TO_MASK`.

Expected: no document describes game-specific Tetro action mapping as shared runtime.

- [ ] **Step 4: Validate docs and assembly one final time**

Run:

```bash
git diff --check
(cd src && asm80 -m Z80 -t hex -o ../build/tetro.hex tetro.asm)
(cd src && asm80 -m Z80 -t bin -o ../build/tetro.bin tetro.asm)
(cd src && asm80 -m Z80 -t hex -o ../build/pacmo.hex pacmo.asm)
(cd src && asm80 -m Z80 -t bin -o ../build/pacmo.bin pacmo.asm)
ruby -e 'ok=true; Dir["README.md","docs/**/*.md"].flatten.each { |f| text=File.read(f); text.scan(/\[[^\]]+\]\(([^)]+)\)/).flatten.each { |href| next if href =~ /\A(?:https?:|mailto:|#)/; path=href.split("#",2).first; next if path.empty?; target=File.expand_path(path, File.dirname(f)); unless File.exist?(target); warn "#{f}: missing #{href}"; ok=false; end } }; exit(ok ? 0 : 1)'
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/shared-codebase.md docs/shared-game-substrate-design.md docs/tetro-codebase.md docs/pacmo-codebase.md
git commit -m "docs: align shared substrate documentation"
```

Expected: one documentation-only commit.

---

### Task 9: Final Review, PR, And Merge Gate

**Files:**
- No planned source edits unless review finds a defect.

- [ ] **Step 1: Run final verification**

```bash
git diff --check
(cd src && asm80 -m Z80 -t hex -o ../build/tetro.hex tetro.asm)
(cd src && asm80 -m Z80 -t bin -o ../build/tetro.bin tetro.asm)
(cd src && asm80 -m Z80 -t hex -o ../build/pacmo.hex pacmo.asm)
(cd src && asm80 -m Z80 -t bin -o ../build/pacmo.bin pacmo.asm)
ruby -e 'ok=true; Dir["README.md","docs/**/*.md"].flatten.each { |f| text=File.read(f); text.scan(/\[[^\]]+\]\(([^)]+)\)/).flatten.each { |href| next if href =~ /\A(?:https?:|mailto:|#)/; path=href.split("#",2).first; next if path.empty?; target=File.expand_path(path, File.dirname(f)); unless File.exist?(target); warn "#{f}: missing #{href}"; ok=false; end } }; exit(ok ? 0 : 1)'
```

Expected: all commands exit 0.

- [ ] **Step 2: Ask for focused subagent review**

Use:

```text
Review the shared game substrate harmonisation branch. Focus on behaviour preservation, Z80 register clobber contracts, include order, and whether any Tetro or Pacmo game-specific logic was accidentally moved into `src/shared`. Verify both games still build. Report findings first with file/line references. If there are no findings, say so explicitly and list any residual risks.
```

Expected: no findings before merge. If there are findings, fix them in a new commit, rerun final verification, then repeat this review step.

- [ ] **Step 3: Create PR**

```bash
git push -u origin codex/shared-game-substrate-harmonisation
gh pr create --title "[codex] Harmonise shared game substrate" --body-file /tmp/shared-game-substrate-pr.md
```

The PR body must include:

```markdown
## Summary
- share HUD segment tables and decimal score formatting behind local wrappers
- move Tetro-specific input/render helpers out of `src/shared`
- add shared LCD row/table-character helpers
- add shared framebuffer draw primitives
- standardise shared composite colour names
- document deferred logic-slice/timer extraction

## Verification
- `git diff --check`
- `(cd src && asm80 -m Z80 -t hex -o ../build/tetro.hex tetro.asm)`
- `(cd src && asm80 -m Z80 -t bin -o ../build/tetro.bin tetro.asm)`
- `(cd src && asm80 -m Z80 -t hex -o ../build/pacmo.hex pacmo.asm)`
- `(cd src && asm80 -m Z80 -t bin -o ../build/pacmo.bin pacmo.asm)`
- local Markdown link check over `README.md` and `docs/**/*.md`

## Review Focus
- No behaviour change intended.
- Confirm all shared routines have correct Input / Output / Clobbers comments.
- Confirm no Tetro piece/input rules or Pacmo maze/entity rules moved into `src/shared`.
- Confirm `SCAN_TICK` still resolves `SERVICE_SOUND` and `SCAN_SCORE_DIGIT`.
- Confirm Tetro and Pacmo include orders remain valid for `asm80`.
```

Expected: PR opens against `main`.

- [ ] **Step 4: Merge only after clean review**

```bash
gh pr view --json mergeStateStatus,reviewDecision,statusCheckRollup
```

Expected before merge:

- `mergeStateStatus` is `CLEAN` or otherwise mergeable.
- `reviewDecision` is not `CHANGES_REQUESTED`.
- Any CI/status checks are passing or absent.
- The focused review subagent reports no findings.

Then:

```bash
gh pr merge --merge --delete-branch
```

Expected: PR merges and the remote branch is deleted.

---

## Non-Goals For This Pass

- No generic input intent system.
- No generic entity framework.
- No shared Tetro rotation/collision/gravity/line-clear logic.
- No shared Pacmo maze, monster, pill, power-mode, or level progression logic.
- No shared game-specific sound event names or durations.
- No callback-based scheduler.
- No logic-slice extraction unless a future approach can preserve branch locality and timing well enough to justify it.

## Completion Criteria

- Both games build after each assembly task and at the end.
- Shared helpers are documented with Input / Output / Clobbers.
- `src/shared` contains only game-neutral routines and constants.
- Tetro-specific input and rendering files live under `src/games/tetro`.
- Pacmo game logic remains under `src/games/pacmo`.
- Documentation matches actual source layout.
- A third 8x8 game can use the shared codebase without inheriting Tetro or Pacmo terminology.
