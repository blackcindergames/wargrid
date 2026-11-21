# README Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A scripted, reproducible README still and 10 s fight clip from a real Dry Wells USA-vs-China bot match in the HUD v5 look.

**Architecture:** `readme_capture.gd` (a `SceneTree` script like `hud_capture.gd`) runs both bots headless to the first big clash, adopts that sim into the skirmish screen inside a 1280×720 SubViewport, selects player 1's units at the clash, saves a still, then steps one tick per frame for 300 frames and saves each as a PNG. ffmpeg encodes the clip; `cwebp`/ImageMagick converts the still.

**Tech Stack:** Godot 4 typed GDScript, ffmpeg (`/opt/homebrew/bin/ffmpeg`, `libwebp`).

**Spec:** `docs/superpowers/specs/2026-11-21-readme-capture-design.md`

## Global Constraints

- Map `res://data/maps/dry_wells.json`; factions `{1: "usa", 2: "china"}`; view player 1.
- Port 1280×720, logical 1280×720 (`BaseScene.sized_port(self, Vector2i(1280, 720), Vector2i(1280, 720))`), `UPDATE_ALWAYS`.
- Clash: at least 8 units of each owner within 8.0 cells of one point; checked every 30 ticks; tick cap 20000.
- Clip: 300 frames, run with `--fixed-fps 30`; output 960 px wide animated lossy WebP, `-loop 0`; 15 fps if 30 fps exceeds about 4 MB.
- Still: `docs/images/skirmish.webp`, lossless; `docs/images/skirmish.png` removed. Clip: `docs/images/skirmish-fight.webp`.
- Don't touch simulation, HUD or match code (`game/scripts/simulation/`, `game/scripts/match/`, `game/scripts/presentation/`).
- No commit or push without the user's approval.

## Review Focus

- Clash found but the camera shows the fight under the slab or strip: the selected units must be in the visible battlefield, not behind HUD (judged on the still by the PX reviewer).
- Interpolation reads the wall clock (`world_view.gd:283` `advance_frame`): frames must show each tick at alpha 1, or the clip jitters between runs.
- All selected units die mid-clip: the slab empties; acceptable, but the still must have a non-empty selection (script check).
- Clash at a base (defence fight) instead of the field: acceptable if the fight is readable; PX reviewer judges.
- Output folder relative path lands under `game/`: script refuses a non-absolute path.

---

### Task 1: Clash finder

**Files:**
- Create: `game/scripts/lab/readme_capture.gd` (only the static function this task)
- Modify: `game/tests/test_art_lab.gd` (one case, added to its `cases()`)

**Interfaces:**
- Produces: `static func clash_point(entities: Array, need: int, radius: float) -> Variant` in `readme_capture.gd`: returns a `Vector2` (the mean position of the units within `radius` of the best centre) or `null`. Entities are snapshot rows (`owner: int`, `position: [x, y]`). A centre is each unit's position; a centre qualifies when owners 1 and 2 each have at least `need` units within `radius`; pick the qualifying centre with the most units in total.

- [ ] **Step 1: Write the failing test** `test_readme_clash_point` in `test_art_lab.gd`:
  - 8 owner-1 and 8 owner-2 units scattered within 3 cells of (40, 40) → result is a `Vector2` within 3.0 of (40, 40).
  - Same armies but owner 2 moved to (80, 80) → `null`.
  - 7 owner-2 units at (40, 40) → `null`.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=readme_clash sh tools/run_tests.sh > build/t.log 2>&1; echo "exit=$?"` → exit non-zero (missing function).
- [ ] **Step 3:** Implement `clash_point` (O(n²) over units is fine; checked every 30 ticks).
- [ ] **Step 4:** Same command → exit 0, case passes.

### Task 2: Capture script

**Files:**
- Modify: `game/scripts/lab/readme_capture.gd`

**Interfaces:**
- Consumes: `clash_point`; `Skirmish.create(true, "ai", {1: "usa", 2: "china"}, "res://data/maps/dry_wells.json")`, `Skirmish.issue_opponents(sim, [1, 2])`, `sim.step()`, `sim.snapshot().entities`; `OverlayTests._scene/_camera/_begin/_end`, `BaseScene.sized_port`, `BaseScene.tick`, `HudTests._select`, `LabCapture._blank`, `main.driver.adopt`, `main._refresh`, `main._camera`, `main._view.advance_frame`, `Iso.world_to_plane` (as `hud_capture.gd` and `match_screen.gd:162-169` use them).
- Produces: CLI `sh tools/run_game.sh --audio-driver Dummy --windowed --resolution 1280x720 --fixed-fps 30 --script res://scripts/lab/readme_capture.gd -- /ABSOLUTE/OUTPUT_DIR`; writes `OUTPUT_DIR/still.png` and `OUTPUT_DIR/clip/0001.png … 0300.png`; last line `CAPTURE DONE tick <T> selected <N> frames 300`, exit 0; any failure `printerr("readme_capture: …")` and exit 1.

- [ ] **Step 1:** `_initialize`: one absolute path argument (else usage, exit 1); frame cap guard as `hud_capture.gd` (`FRAME_CAP` 2000).
- [ ] **Step 2:** Headless run: create sim, loop issue/step; every 30 ticks `clash_point(snapshot.entities, 8, 8.0)`; stop at the first hit; fail at tick 20000. Await a `process_frame` every 600 ticks (as `test_skirmish_match.gd`) so the window stays responsive; at most 34 yields, well under `FRAME_CAP`.
- [ ] **Step 3:** Scratch session (`_overlays._begin(true, …)` as `hud_capture.gd` does) so the owner's settings are untouched; port; `_scene()`; close the checklist; `driver.adopt(sim)`; `_reset_camera()`; set `main._camera.position = Iso.world_to_plane(clash)`; select player-1 units within 8.0 of the clash via `HudTests._select(main, ids)`; fail if none.
- [ ] **Step 4:** Settle 3 frames; force alpha 1 with `main._view.advance_frame(Time.get_ticks_usec() + 1000000)`; fail on `_blank`; save `still.png`.
- [ ] **Step 5:** Clip loop, 300 iterations: `BaseScene.tick(main)`, `main._present_if_due()`, `main._view.advance_frame(Time.get_ticks_usec() + 1000000)`, await `process_frame`, save `clip/%04d.png`. Selection stays as the match screen keeps it (dead ids drop out). If effects (shots, deaths) do not animate this way, call `main._process(1.0 / 30.0)` in place of the two present calls, then the `advance_frame` line.
- [ ] **Step 6:** `_overlays._end(saved)` on every exit path, port freed; `quit()` on every path.
- [ ] **Step 7:** `sh tools/run_lint.sh > build/lint.log 2>&1; echo "exit=$?"` and `sh tools/run_warnings.sh > build/warn.log 2>&1; echo "exit=$?"` → both 0.
- [ ] **Step 8:** Run (window approved for today, user 2026-11-21): `OUT=/private/tmp/…/scratchpad/readme; sh tools/run_game.sh --audio-driver Dummy --windowed --resolution 1280x720 --fixed-fps 30 --script res://scripts/lab/readme_capture.gd -- $OUT > build/readme-capture.log 2>&1; echo "exit=$?"` → exit 0, `CAPTURE DONE` line, 301 PNGs. Run twice; `cmp` `still.png` of both runs to prove reproducibility (report if they differ, do not hide).
- [ ] **Step 9:** Encode (as built: Homebrew ffmpeg has no libwebp, so ffmpeg crops and scales and `img2webp`/`cwebp` encode; see guide 13):
  ```
  ffmpeg -v error -y -framerate 30 -i "$OUT/clip/%04d.png" -vf scale=960:-1:flags=lanczos -c:v libwebp -lossless 0 -q:v 70 -loop 0 -an docs/images/skirmish-fight.webp
  ffmpeg -v error -y -i "$OUT/still.png" -c:v libwebp -lossless 1 docs/images/skirmish.webp
  git rm -q docs/images/skirmish.png
  ```
  Size check: clip over ~4 MB → re-encode with `-vf fps=15,scale=960:-1:flags=lanczos`.
- [ ] **Step 10:** Look at the still and a few clip frames yourself (Read the PNGs); then the player-experience reviewer gets the still, frames 1/100/200/300 and the clip path; the correctness reviewer gets the script diff. Fix rounds as needed (clash `need`/`radius`, camera offset), rerun steps 8–9.

### Task 3: Docs

**Files:**
- Modify: `README.md:22-24`, `docs/guide/13-testing-and-tooling.md` (offscreen captures section, `Checked against` footer)

- [ ] **Step 1:** README: image → `docs/images/skirmish.webp`, alt text describing what the still actually shows (map, factions, the fight, the selected army in the HUD); caption names Dry Wells, USA vs China, the tick, and that `readme_capture.gd` makes it; clip below as `![…](docs/images/skirmish-fight.webp)` with its own alt text.
- [ ] **Step 2:** Guide 13: a `readme_capture.gd` bullet after `hud_capture.gd` (what it does, the run command, the ffmpeg lines, the run time, the done line and file count, the BOTS=[2] limit after adoption); "Two scripts … and a third" → count updated; window paragraph "all three scripts" → four; footer: add `readme_capture.gd` passage against the working tree over the current `main` sha, and the file to the Files list.
- [ ] **Step 3:** `rg -n 'skirmish\.png' . --glob '!build/**'` → no tracked reference left (fix any); `sh tools/run_checks.sh > build/checks.log 2>&1; echo "exit=$?"` → 0; full suite `sh tools/run_tests.sh > build/tests.log 2>&1; echo "exit=$?"` → 0.
- [ ] **Step 4:** `/ponytail-review` on the diff; apply cuts, re-verify. Stop for the user's commit approval.
