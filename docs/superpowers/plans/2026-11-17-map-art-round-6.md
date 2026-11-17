# Map art round 6: Implementation Plan

**Status:** approved (user, 2026-11-17), run not started. Attended run by day in one session (user, 2026-11-17): a coordinator with one fresh subagent per task, each starting from the resume record in `docs/reference/map-art-round-6-verification.md`. Not a night run.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md) (resume record, session start, stop conditions); local commits at the five commit points (Tasks 0, 6, 10, 26, 31) are pre-approved (user, 2026-11-17): the coordinator commits with the task's message and shows the summary afterwards; nothing is pushed. Reviewed before the run by Codex (gpt-6-astra, high; user, 2026-11-17); its 16 findings are worked in.

**Goal:** The map art of rounds 1 to 5 becomes re-makeable from the repository at 2x, its picked shapes become one export proven through the game's own bake, the user picks the open looks on a short A/B round, and the documents state the result.

**Architecture:** A trimmed copy of the private art-spike page set lives in `docs/images/map-art/source/` (one page `round6.html`, the bake port `draw.js`, merged picked data, the today export), modelled on `docs/images/hud-v5/source/`. The HUD v5 drawing moves out of `round1.html` into `hud.js` + `hud.css` that both pages load. The page writes `docs/images/map-art/shapes-picked.json` through a small server; a headless Godot scratch script seeds the picked parts into `Shapes._parts_cache` and bakes them with `ShapeBake.mesh`, and the page compares the triangles. Pictures are Firefox headless screenshots encoded with `cwebp -lossless`.

**Tech Stack:** HTML/CSS/canvas JavaScript (classic scripts, no build), Python 3 stdlib server, POSIX sh, Godot 4.7.2 headless (`${GODOT_BIN:-godot}`), Firefox at `/Applications/Firefox.app/Contents/MacOS/firefox`, `cwebp`/`dwebp`, ImageMagick `magick compare`.

**Spec:** [map art round 6 design](../specs/2026-11-17-map-art-round-6-design.md). Decisions: "Round 6 scope questionnaire" in [design answers](../../reference/design-answers-2026-11-08.md#map-art-faction-shapes-m75-user-2026-11-13). Look rules drawn in: [visual and UX proposal, second pass](../../reference/design-answers-2026-11-08.md#visual-and-ux-proposal-second-pass-user-2026-11-15). Art work reads first: [blueprint §2](../../blueprint.md#2-visual-direction-geometric-25d), [art direction](../../art-direction/ART_DIRECTION.md) (§11 screenshot marks, §12), [integration note](../../reference/art-godot-integration.md).

## Global Constraints

- **Worktree and branch:** `~/projects/wargrid-wt-art-round-6`, branch `spike-art-6`; never `cd` to another checkout. Path:line below is `9b21db3`.
- **No file under `game/` changes,** nor tests, simulation, traces, benchmarks, the README roadmap block, `docs/images/hud-v4/`, any settings or permission file. `git status --short game tools` stays empty after every task; a non-empty result is a stop.
- **Private folder read-only:** `~/projects/wargrid-private/docs/art-spike/` and `~/projects/wargrid-private/docs/hud-v5/`. Copy only the files Task 2 and Task 23 name. Never copy `scratch*.html`, `passes/`, `gen/`, `shots/`, `ffprof-*`, `round1..3.html`, `brief.md`, `decided.md`, `inventory.md`, `page-mechanics.md`, `SPEC.md`, `picks-round*.json`, `fonts/`, `hud-layer.*`, `draw_check.*`. A scratch copy for a proof may go under the Git-ignored `build/map-art/` (Task 2: Inter and a reference copy of the private pages) and is never tracked.
- **Public repository:** no absolute home path (write `~/projects/...`), hostname, LAN address, name, pasted chat, recorded picks or build spec in tracked files. `source/picks.json` is Git-ignored. Exports carry no absolute path.
- **Pictures:** 2560x1440 lossless WebP (`cwebp -quiet -lossless -z 9 -exact`) for a 1280x720 layout, drawn at 2x by the page (vector redraw at `scale=2`, never an upscale). HUD v5 backdrops stay `docs/images/hud-v5/source/worlds/w-<state>.png` at 2560x1600. Public Sans from `game/fonts/` for every text, the page waits for `document.fonts.load` of each weight it uses before the first draw.
- **Ports:** map art server `127.0.0.1:8769`; HUD v5 server stays `127.0.0.1:8767`.
- **Firefox:** headless only, a fresh `mktemp -d` profile per run, never the user's profile; a 60 s per-picture limit as `docs/images/hud-v5/source/shoot_final.sh`. A visible Firefox window opens only at stop gate 4, for the user.
- **Godot:** headless only, `"${GODOT_BIN:-godot}" --headless --path game -s "$PWD/docs/images/map-art/source/<script>.gd" -- <args>` from the repository root. Scratch scripts call `quit(1)` first in `_init` and `quit(0)` only at the end (the `export_shapes.gd` pattern), so a script error ends the process.
- **Install:** a missing local tool may be installed with Homebrew or `uv` without asking; the task says so in its first step and in the source README's "Needs" line. Pillow only as `uv run --with pillow python3 ...`, never a global pip install. Picture proofs use `magick compare -metric AE <a> <b> null:` (exit 0 and pixel count 0 means identical).
- **Labels:** round 6 looks are page data; only geometry that passes the round trip is "proven in Godot"; pixels, motion, feel, the rendered benchmark and a Steam Deck stay "not run". Zero Hour defaults are cited path:line with revision (`~/projects/CnC_Generals_Zero_Hour` `0a05454`, `~/projects/GeneralsGameCode` `afc2a103f` at plan time; INI only via `python3 tools/zh_ini.py dump` and `build/zh_ini/inizh.jsonl`, cite entry:line).
- **Logs:** every check writes to `build/map-art/logs/<task>-<check>.log`, judged by exit code (`cmd > log 2>&1; echo "exit=$?"`), on failure only the failing lines are read. Pass `timeout: 600000` on every check, shoot, Godot and suite call; long shoots run in the background with the completion notice, no `sleep` polling.
- **Checks per task** (when the task changed that kind of file): `sh tools/check_public.sh` (`PUBLIC CHECK PASSED`); `sh tools/run_shell_checks.sh` (exit 0; it picks up every tracked or new `*.sh`, so scripts under `docs/images/map-art/source/` are covered and the root `.shellcheckrc` applies); for `*.py` under `docs/` (not covered by `tools/run_python_checks.sh`, which runs in `tools/` only): `sh tools/ensure_venv.sh && tools/.venv/bin/ruff format --check --config tools/pyproject.toml docs/images/map-art/source && tools/.venv/bin/ruff check --config tools/pyproject.toml docs/images/map-art/source && tools/.venv/bin/mypy --config-file tools/pyproject.toml docs/images/map-art/source/server.py`; for `*.gd` under `docs/` (not covered by `tools/run_lint.sh`, which lints `game` only): `tools/.venv/bin/gdlint docs/images/map-art/source`, all new code typed. `sh tools/run_checks.sh` (`CHECKS PASSED 5`) at Task 31.
- **Test suite:** no task changes `game/`, `tools/` or tests, so task subagents skip the milestone prompt's per-task baseline (step 3); the full suite (`sh tools/run_tests.sh`, `TESTS PASSED <n>`) runs at Task 31 only, and the `git status --short game tools` check above stands in for it before that. Task 1 runs one shape suite, which also imports the project for the later Godot runs.
- **Parallel tasks share nothing they write:** the coordinator runs the one map server and alone writes the verification file and resume record while tasks run in parallel; each parallel agent uses its own report name, output folder and Firefox profile.
- **Subagents never commit, push, merge, deploy or open a visible window.** The coordinator makes the local commits at the five commit points (pre-approved, user, 2026-11-17) and never pushes, merges or amends.
- Code comments: none by default, one line WHY only. Edits with the Edit tool or asserted replacements; agent shells use BSD `sed`.

## Model routing

From the design's "How the work runs" table (user, 2026-11-17); per task below.

- Sonnet medium: Tasks 2, 8, 18 (move, Zero Hour lookup, colour arithmetic). Sonnet high: Tasks 4, 7, 11, 24, 25 (shared HUD, export and round trip, page frame, final shoot, backdrops). Opus high, one agent per step: Tasks 12-17 and 23 (drawing). Opus high: Tasks 27, 28 (reference doc, art bible). Sonnet medium: Task 29 (other documents; agent call, the table names no row). Haiku low: Tasks 1 (environment part), 30.
- Reviews: `player-experience-reviewer` (`.claude/agents/player-experience-reviewer.md`) on screenshots of every pick step before the user sees the page (Task 20) and on the final pictures (Task 24). One fresh Opus high reviewer per code task (Tasks 2, 4, 7, 11, 24, 25: diff plus task text, no repo-wide search), the subagent-driven gate (kept, user, 2026-11-17). Fresh Opus high review of the documents against the code (Task 31). Then `/ponytail-review` on the branch diff.

## Review Focus

1. **Fonts not loaded before a canvas draw:** a picture silently drawn in a fallback face. Test in Task 2: `#report=fonts` posts `document.fonts.check('12px "Public Sans"')` for weights 400, 600, 700, 800 after the page's load wait; `fonts.txt` ends `PASS 4`.
2. **Server down or file not rewritten:** the page must never say "Recorded." without a 204, and `export.sh` / `report.sh` must fail when their file was not rewritten. Test in Task 7: run `sh export.sh` with the server stopped → exit 1, stderr `shapes-picked.json was not rewritten`; Task 11: Pick with the server stopped → page shows `Not recorded`.
3. **A stray `docs/images/hud-v5/source/picks.json`** changes every HUD picture and the `layout.json` meta. Test in Tasks 4 and 25: the step aborts with `picks.json present` when the file exists (it is the user's; never delete it).
4. **A Godot scratch script that errors or hangs:** Test in Task 7: `roundtrip.gd` with `--in=` a missing file exits 1 within the 60 s limit and prints `cannot read`.
5. **Private detail in an export or the source folder:** the old export's `export_command` names another worktree and a private path. Test in Task 7: `rg -n 'wargrid-private|wargrid-wt-|/Users/' docs/images/map-art` finds nothing; `git check-ignore docs/images/map-art/source/picks.json` prints the path.

## Files

| Path | Change |
|---|---|
| `docs/images/map-art/source/round6.html` | new: the page (from `round5.html`, merged with `final.html` and `round4.html`) |
| `docs/images/map-art/source/pics.js` | new: `PICS` registry, one entry per picture |
| `docs/images/map-art/source/draw.js`, `page.css`, `scenes.js`, `scenes5.js` | copied; `page.css` without Inter, `.hud*` rules dropped |
| `docs/images/map-art/source/picked.js` | new: the picked candidate data of rounds 1 to 5 plus the correction overlays |
| `docs/images/map-art/source/cand6-<key>.js` | new (Tasks 12-17), six files: round 6 options and step texts, one file per step |
| `docs/images/map-art/source/shapes-current.json`, `shapes-current.js`, `export_shapes.gd` | copied; `meta.export_command` rewritten, `--out=` required |
| `docs/images/map-art/source/roundtrip.gd` | new: seeds picked parts, bakes with `ShapeBake.mesh` |
| `docs/images/map-art/source/marks.js` | new (Task 23): white marks and the HUD v5 backdrop scenes |
| `docs/images/map-art/source/server.py`, `shoot.sh`, `shoot_worlds.sh`, `export.sh`, `report.sh`, `roundtrip.sh`, `README.md`, `.gitignore` | new |
| `docs/images/map-art/shapes-picked.json` | new: the export |
| `docs/images/map-art/*.webp` | all re-shot at 2x; `base-usa-china-z05-hud.webp` becomes `base-usa-china-z05.webp`; 15 new (17 with `clash`) |
| `docs/images/hud-v5/source/hud.js`, `hud.css` | new: the HUD drawing moved out of `round1.html` |
| `docs/images/hud-v5/source/round1.html` | loads `hud.js` / `hud.css`; inline HUD code removed |
| `docs/images/hud-v5/source/worlds/w-*.png`, `docs/images/hud-v5/*.webp` | re-made (Task 25); `layout.json` byte-identical |
| docs | `docs/reference/map-art-shapes.md` (new), `docs/reference/map-art-round-6-verification.md` (new), `docs/art-direction/ART_DIRECTION.md` (v2), `docs/images/map-art/notes.md`, `docs/reference/design-answers-2026-11-08.md`, `docs/packages.md`, `docs/STATUS.md`, `docs/images/hud-v5/notes.md`, `docs/images/hud-v5/source/README.md`, `docs/development.md` |

Codebase guide: no chapter is affected. `rg -n -i 'map-art|hud-v5|mock-up|shapes-current|layout\.json' docs/guide` finds no mention of the map art or HUD v5 sources at `9b21db3`, and no change touches simulation, presentation, netplay, relay, performance or tooling; Task 30 re-runs that search on the final tree and records the result.

---

### Task 0 (coordinator, before Task 1): commit the design

- [ ] **Step 1:** After the user's go for the run, commit `docs/superpowers/specs/2026-11-17-map-art-round-6-design.md`, the uncommitted "Round 6 scope questionnaire" block in `docs/reference/design-answers-2026-11-08.md` and this plan. Message: `Record the map art round 6 design and plan` / `Consolidates rounds 1 to 5 into the repository and adds a four-step pick round; no game code changes.`

### Task 1: Base and verification file

Model: Sonnet medium (the environment rows may go to Haiku low). Not parallel.

**Files:** Create `docs/reference/map-art-round-6-verification.md`.

**Interfaces:** Produces the resume record (block from the [milestone prompt](../../milestone-prompt.md#resume-record)) and `## Evidence rows (append-only)`, one `### <date> Task N: <title> (tree: spike-art-6 <hash> plus <diff summary>)` per task with command, result, exit, as `docs/reference/art-lab-verification.md`. Every later task appends its row and overwrites the resume record; a task that runs in parallel with another (7 and 8, 12 to 17, 28 and 29) returns its row in its report instead, and the coordinator appends it.

- [ ] **Step 1:** `git status --short`, `git log --oneline -3`; record. Only Task 0's files may differ from `9b21db3`.
- [ ] **Step 2:** `git log --oneline 10b9423..HEAD -- game/scripts/presentation/shapes.gd game/scripts/presentation/palette.gd game/scripts/presentation/shape_bake.gd game/scripts/presentation/world_batch.gd game/scripts/presentation/world_view.gd game/scripts/presentation/isometric.gd game/scripts/presentation/graphics_settings.gd` → empty. Non-empty is a stop (design "Constraints"). `game/scripts/simulation/definitions/` did change since `10b9423` (SB3 cache freeze); Task 7 proves the export values are unchanged by a re-export.
- [ ] **Step 3:** Environment row: `/Applications/Firefox.app/Contents/MacOS/firefox --version`, `cwebp -version`, `dwebp -version`, `magick -version | head -1`, `"${GODOT_BIN:-godot}" --version`, Zero Hour and fork `git rev-parse --short HEAD`. `ls docs/images/hud-v5/source/picks.json` → no such file (else a stop: Review Focus 3).
- [ ] **Step 4:** Baseline: `WARGRID_TEST_ONLY=test_shapes sh tools/run_tests.sh` (passes; it also imports the project for the Godot runs later). The full suite and `run_checks.sh` run at Task 31 only: nothing they cover changes before then.
- [ ] **Step 5:** Record the counts the later proofs use: `ls docs/images/map-art/*.webp | wc -l` (25 at `9b21db3`), `ls docs/images/hud-v5/*.webp | wc -l` (26), `shasum -a 256 docs/images/hud-v5/layout.json`.

### Task 2: Move and trim the source, shoot script, first shoot

Model: Sonnet medium. Not parallel. Review: fresh Opus high on the diff.

**Files:** Create in `docs/images/map-art/source/`: `round6.html`, `pics.js`, `picked.js`, `draw.js`, `page.css`, `scenes.js`, `scenes5.js`, `shapes-current.json`, `shapes-current.js` (the page loads the `.js` at start, private `round5.html:23`; copied with only `meta.export_command` replaced, as Task 7's Interfaces say), `server.py`, `shoot.sh`, `report.sh`, `README.md` (first version), `.gitignore` (`picks.json`).

**Interfaces:**
- Consumes the private pages read-only: `round5.html` is the base (rounds 1 to 4 baked in, round 5 options, the newest code); `final.html` supplies `PICS` and the grids `buildingsGrid`, `unitsGrid`, `placeholdersStage`, `baseCfg` (`final.html:456-509`) and its `TODAY` rule (`final.html:73,105,115`); `round4.html` supplies the row views of `damage`, `tanks`, `zoom_high`, `fix_bldg`, `fix_unit` (`round4.html:436-631`) and its `'0'` (today) handling. The recorded views in `picks-round4.json` and `picks-round5.json` show which hash showed each step; read them, do not copy them.
- Produces `picked.js`: `window.PICKED = {cand, cand2, cand3, cand3b, cand4, cand4b, cand5}` holding, from the private `cand*.js`, only the option keys that were picked (rounds 1 to 3 from `final.html`'s baked `PICKED`/`OLD`, round 4 `R4` at `round5.html:86`, round 5 `{band: A, owners: A, neon: 0, cliff: A, decor: B, fog: B}`), in the structure the page's resolve code already reads, so the compose code needs no rewrite. `cand4b` (FRC tank 0.68 hull / 0.7 tracks, Armed Pickup 0.65) stays a separate overlay key; Task 7 adds `fix6`.
- Produces in `round6.html` one selection object per picture, `sel = {steps: {<stepKey>: <optionKey>}, fix4b, fix6}`: one entry per step of rounds 1 to 6 under the step keys the private pages use, `'0'` meaning today, and each overlay `true | false`. Per step, not per round, because the committed pictures were shot with one step switched while the others kept their picks (private `round4.html:194` `selOf`; the `view` hashes in `picks-round4.json` and `picks-round5.json`). `shapeIn` / `palFor` read it in place of the baked constants `OLD`, `R4`, `R5`. Two helpers: `ALL_PICKED` (every step at its picked option) and `ALL_TODAY` (every step `'0'`).
- Produces `pics.js`: `const PICS = {<name>: {shot: sel, final: sel, draw: (cfg) => HTMLElement}}`. `shot` reproduces exactly the step combination the committed picture was shot with, read from the private shoot scripts and the recorded `view` hashes (rounds 1 to 3 today pictures: `ALL_TODAY`; a round 4 or 5 picture: earlier rounds picked, its own round's steps as that hash had them; `tanks-picked` without `fix4b`; world pictures with `fix4b`). `final` is filled in Task 24. The page also resolves the generic names `step<n>-<A|B>[-dark]` (Task 11).
- Produces hashes: `#pic=<name>&as=shot|final&scale=1|2` (stage only, 1280x720 x scale CSS px, canvas backing at the same size, `ctx.setTransform(scale, 0, 0, scale, 0, 0)`); `#report=fonts`; `#report=pics` (posts the `PICS` names, one per line, then `PASS <n>`). Every report hash takes `&name=<[a-z0-9-]+>` for its file name (default: the report's own name). `&font=inter` (proof only) uses Inter from `/build/map-art/proof-fonts/` instead of Public Sans. The HUD v4 layer and the glyph views (`HUDLayer.cellHtml`, `kindRowHtml`, `identityHtml`, `round5.html:692-714`, and `glyphHtml`/`galleryGlyphHtml`) are removed; until Task 4 a stage has no HUD layer.
- Produces `server.py` (stdlib, typed, modelled on `docs/images/hud-v5/source/server.py`, `Cache-Control: no-store`): serves the repository root on 127.0.0.1:8769; `POST /pick` merges `{key, pick, note}` into `source/picks.json`; `POST /export` writes `docs/images/map-art/shapes-picked.json`; `POST /report?name=<[a-z0-9-]+>` writes `build/map-art/<name>.txt` (other names → 400). Each 204 on success.
- Produces `report.sh <hash> <name>`: headless Firefox on `http://127.0.0.1:8769/docs/images/map-art/source/round6.html#<hash>`, waits until `build/map-art/<name>.txt` is newer than its start stamp (120 s limit, the `export_layout.sh` pattern), prints it, exits 0 only when its last line starts with `PASS`.
- Produces `shoot.sh [name ...]` with env `SCALE` (1 or 2, default 2), `AS` (`shot` or `final`, default `final`), `OUT` (default `docs/images/map-art`), `EXTRA` (appended to every hash, default empty): first runs `report.sh "report=pics&name=pics-$$" "pics-$$"` (a name of its own, so parallel shoots never read each other's list), fails on a name not in that list, then per name a `--window-size=$((1280*SCALE)),$((720*SCALE))` screenshot of `#pic=<name>&as=$AS&scale=$SCALE`, then `cwebp` to `$OUT/<name>.webp`. No names = every name in the list.

- [ ] **Step 1:** Copy and trim as in Interfaces; switch every font to Public Sans (`@font-face` lives in `hud.css` from Task 4; until then a copy of the four `@font-face` lines from `docs/images/hud-v5/source/round1.html:5-8` with the path `../../../../game/fonts/` sits in `page.css` and moves in Task 4). For the proof only, copy the private `fonts/Inter-*.woff2` to `build/map-art/proof-fonts/` and the private page set (`final.html`, `round4.html`, `round5.html` and what they load) to `build/map-art/private-ref/`, where one added style rule hides the HUD v4 layer of `final.html`; both folders are ignored and never tracked.
- [ ] **Step 2:** Start the server in the background; `sh report.sh 'report=fonts' fonts` → `PASS 4` (Review Focus 1); `sh report.sh 'report=pics' pics` → 25 names (the committed set with `base-usa-china-z05` in place of `base-usa-china-z05-hud`).
- [ ] **Step 3:** First shoot, not kept: `SCALE=1 AS=shot EXTRA='&font=inter' OUT=build/map-art/first sh docs/images/map-art/source/shoot.sh` (the committed pictures carry captions and labels in Inter, private `round4.html:382-394`), then `SCALE=1 AS=shot OUT=build/map-art/first-ps sh ...` and `SCALE=2 AS=shot OUT=build/map-art/first2x sh ...` in Public Sans, in the background. Exit 0, 25 files each, `magick identify` sizes 1280x720 and 2560x1440.
- [ ] **Step 4:** For each name `magick compare -metric AE build/map-art/first/<n>.webp docs/images/map-art/<n>.webp build/map-art/first/<n>-diff.png`; record the pixel count per picture. With Inter every count must be 0, with one exception: `base-usa-china-z05` has lost its HUD v4 layer. It is compared whole-frame, count 0, against a reference shot of the same scene from `build/map-art/private-ref/` (HUD layer hidden), so the world under the old dock is covered too. Then `first-ps` against `first`: the pictures that differ are listed with their counts and each is read by eye; only text may differ.
- [ ] **Step 5:** Read two 2x pictures (one grid, one world) beside their 1x: same layout, sharper edges. Record.
- [ ] **Step 6:** Checks: public, shell, Python (Global Constraints). Append the evidence row; stop the server.

### Task 3: Stop gate 1, first shoot

Runs only when Task 2 Step 4 found a count outside the known differences. Coordinator: show the user the diff pictures and the counts, ask whether to fix the merge, accept the difference (recorded as "accepted, user, <date>") or stop. Never widen the known list without that answer.

### Task 4: One shared HUD file and its no-difference proof

Model: Sonnet high. Not parallel. Review: fresh Opus high on the diff; no `player-experience-reviewer`, because the proof shows no visible change.

**Files:** Create `docs/images/hud-v5/source/hud.js`, `hud.css`. Modify `docs/images/hud-v5/source/round1.html` (CSS `:5-8` and `:63-153`, JS `:163-529` minus the page-only parts), `docs/images/map-art/source/round6.html`, `page.css`.

**Interfaces:**
- `hud.js` defines one global, `window.HUDV5`, holding everything `hud(o, v)` and `placeCards(root)` need (sizes, states, colour helpers `luminance`, `contrast`, `mix`, `lifted`, tokens `FLAT`, data `DATA`, `BASE`, `KINDS`, glyph helpers, `layout`, `dock`, `hud`, `updateCard`, `placeRefusal`, `placeCards`) and nothing that touches the stage, backdrops, steps, picks, coverage probe or audit. One global, because the map page has its own `BASE`, `contrast` and `mix`.
- `round1.html` opens its script with `const { SIZES, STATES, ... } = HUDV5;` listing exactly the names its remaining code uses, so the rest of the page is unchanged.
- `hud.css`: the four Public Sans `@font-face` rules (URLs relative to `hud.css`, same folder as today) and every `.hud` rule.
- The map page loads `../../hud-v5/source/glyphs.js`, `glyphs3.js`, `hud.js`, `hud.css`, and builds its layer with `HUDV5.hud(o, {state, size: '1280x720', tier})` then `HUDV5.placeCards(stage)`, where `o` is `{k: meta.picks[k].value}` read from `/docs/images/hud-v5/layout.json` (one source for the picked HUD options). `page.css` loses its `@font-face` copy.

- [ ] **Step 1:** `ls docs/images/hud-v5/source/picks.json` → absent, else stop (Review Focus 3); `git status --short docs/images/hud-v5` → empty.
- [ ] **Step 2: Baseline on the unedited source.** Start `python3 docs/images/hud-v5/source/server.py` in the background; `sh docs/images/hud-v5/source/shoot_final.sh` and `sh docs/images/hud-v5/source/export_layout.sh`, both with **no** picks argument (an explicit `A` list rewrites the meta from `A (default)` to `A`). The 26 pictures are all 1280x800 and `layout.json` holds rectangles, not drawings, so also shoot `#shot=<state>&size=<720|1920>&tier=full&scale=2` for the states `none`, `many`, `factory` and `build` into `build/map-art/hud-before/` (8 files). Then `git status --short docs/images/hud-v5` → empty. If it is not empty the environment drifted (Firefox or `cwebp` version): `magick compare -metric AE` per changed picture against `git show HEAD:<path>`, record, `git restore docs/images/hud-v5`, and stop at Task 5.
- [ ] **Step 3:** Move the code as in Interfaces.
- [ ] **Step 4: Proof.** The same two commands; `git status --short docs/images/hud-v5` shows only `round1.html`, `hud.js`, `hud.css`; `cmp docs/images/hud-v5/layout.json <(git show HEAD:docs/images/hud-v5/layout.json)` exit 0; the same 8 size shots into `build/map-art/hud-after/`, each `magick compare -metric AE` 0 against `hud-before/`. A changed picture or `layout.json` is a fail: `magick compare` counts, `git restore` the pictures and `layout.json`, stop at Task 5.
- [ ] **Step 5:** The map page with the layer: `sh report.sh 'report=fonts' fonts` still `PASS 4`; one screenshot of a base scene with `&hud=none` into `build/map-art/hud-check/`, read by eye: the HUD v5 dock at the bottom, Public Sans.
- [ ] **Step 6:** Checks: public. Evidence row (both proofs, counts). Stop both servers.

### Task 5: Stop gate 2, HUD proof

Runs only when Task 4 Step 2 or Step 4 failed. Coordinator: show the counts and diff pictures; ask whether to accept a new baseline (only for Step 2 drift, recorded with versions) or stop. A Step 4 failure is fixed in the moved code, never accepted.

### Task 6: Commit point A

- [ ] Coordinator commits (pre-approved) and shows `git status --short` and the summary. Message: `Move the map art source into the repository and share the HUD v5 drawing` / `The first shoot matched the committed pictures; the 26 HUD pictures and layout.json re-made unchanged.`

### Task 7: Today export, picked export and the Godot round trip

Model: Sonnet high. Parallel with Task 8. Review: fresh Opus high on the diff.

**Files:** Create in `docs/images/map-art/source/`: `export_shapes.gd`, `roundtrip.gd`, `export.sh`, `roundtrip.sh`. Modify `round6.html`, `picked.js` (`fix6`). Create `docs/images/map-art/shapes-picked.json`.

**Interfaces:**
- `export_shapes.gd`: the private script with `--out=<path>` required (missing → `push_error("--out= missing")`, exit 1) and `meta.export_command` = `"${GODOT_BIN:-godot}" --headless --path game -s <repo>/docs/images/map-art/source/export_shapes.gd -- --out=<file>`.
- `shapes-current.json` (copied in Task 2): the private file with only `meta.export_command` replaced by the string above; `git_revision` stays `10b9423…` (the commit it was taken at). `shapes-current.js` = `window.SHAPES = ` + the same JSON on one line + `;`.
- `picked.js` gains `fix6`: Armed Pickup (`frc_light_vehicle`) hull length exactly 0.65 cells, its parts following the shorter hull (the drawing agent's choice inside the page audit, agent call in the design); every id in `Shapes.TANK_ROLES` (`shapes.gd:15`: `usa_tank`, `china_tank`, `frc_tank`, `china_light_vehicle`) exactly 3.0 height units tall, meaning the highest `offset.z + size.z` over all prims at every detail is 3.0; FRC tank tracks 0.7 cells (from `fix4b`).
- `#export` (page) posts to `/export` the document `{meta, palette, shapes, extras}` in the game export's format (`shapes-current.json` field names: `id, faction, class, role, layer, footprint, has_turret, parts, parts_by_detail, damage_variants`; part `{name, angle, pivot, prims[{type, offset, size, slot}]}`), every picked shape per role and faction with all overlays, plus `palette` with only the changed values (side band, owner colours, cliff factors, cargo colour, later round 6's). `meta`: `{source: "docs/images/map-art/source/round6.html", git_revision, date_utc, picks, provisional: {missing_zoom2: [ids], note}, corrections: {...}}`. Zoom 2 versions that do not exist are listed in `missing_zoom2`, never invented.
- `export.sh`: as `docs/images/hud-v5/source/export_layout.sh`: headless `#export`, fails with `shapes-picked.json was not rewritten` (exit 1) when the file is not newer than its start stamp, then a `python3 -I` self-check that exits 1 on any miss: every shape has non-empty `parts`; `frc_light_vehicle` body length 0.65; the four tank ids 3.0 tall; `frc_tank` track length 0.7; every id in `missing_zoom2` has no `parts_by_detail["2"]`; the set of shape ids equals the id set of `shapes-current.json` (none lost, none invented); prints `<n> shapes, corrections hold`.
- `roundtrip.gd --in=<shapes-picked.json> --out=<json>`: for every shape, each damage variant and each extra variant, at details 0, 1, 2 and hull buckets 0, 8, …, 56 (turreted shapes also turret = hull + 11 mod 64), seeds `Shapes._parts_cache[&"rt:<id>:<variant>"] = {detail: parts}` as a typed `Array[Dictionary]` built with `Shapes._part` / `Shapes._prim` (so the dictionaries are the game's own), then concatenates `ShapeBake.mesh(role, part, part_bucket, detail, 0, hull)` over the parts (`part_bucket` = turret bucket for turret parts, else hull). If `gdlint` rejects the calls to `Shapes._part` / `Shapes._prim` from outside the class, the script builds the same dictionaries itself, field for field as those two functions do, and says so in one comment; no `gdlint` rule is switched off. Writes `[{shape, variant, detail, hull_bucket, turret_bucket, tris: [[x0, y0, x1, y1, x2, y2, slot], ...]}]`, prints `ROUNDTRIP BAKED <poses>`. Unreadable input → `cannot read <path>`, exit 1.
- `#roundtrip` (page): fetches `/build/map-art/roundtrip-godot.json`, runs `projectShape` (`draw.js:71`) per pose, first asserts coverage, which the private `draw_check.html` did not (it passes an empty pose list): the page computes the expected poses itself from the export (every shape, variant, detail and heading) and fails with `MISSING <pose>` or `EXTRA <pose>` when the Godot file's pose set differs; then compares as that page's `numericCheck`: same triangle count, same slot per triangle, max vertex difference < 1e-3 px; a pose equal only after reordering triangles of one equal sort key is a `TIE` (listed, not a pass). Posts the per-pose lines and last line `PASS <poses> max <d> px ties <t>` or `FAIL <n> of <poses>` to `/report?name=roundtrip`.
- `#audit` (page): runs the existing JS port of the shape audit's paint-order and size rules (round 4's `numbers` code) at eight headings, the footprint check, owner-colour share and the contrast and colour-vision tables over every shape in the merged data and every `CAND6` option; posts one line per failure and last line `PASS <checks> known <k>` or `FAIL <n>` to `/report?name=audit`. Findings that are accepted or owned elsewhere are not failures: they sit in a `KNOWN` list in `round6.html`, each with its source, and print as `KNOWN` lines. Task 7 fixes that list from its first run and records it in the evidence row; it may hold only what the design answers already record (no owner top reaches 3:1 on sand, round 5; the Neon blue and purple pair, F12, until step 2's pick is baked in Task 24, where its entry is removed; the paint-order samples P2.4 owns; the owner-share values at the audit's floor named in the P2.4 prep research). Anything else that fails is a stop, and no later task adds to the list without the user.
- `roundtrip.sh [shapes json]` (default `docs/images/map-art/shapes-picked.json`): removes `build/map-art/roundtrip-godot.json`, runs `roundtrip.gd` into it, exits 1 unless Godot exited 0 and the file exists again (a stale file from an earlier run must never be compared), then `report.sh 'roundtrip&set=<today|picked>' roundtrip` (`today` when the input is `shapes-current.json`); exit code of the latter.

- [ ] **Step 1: Today export unchanged.** `"${GODOT_BIN:-godot}" --headless --path game -s "$PWD/docs/images/map-art/source/export_shapes.gd" -- --out="$PWD/build/map-art/shapes-today-head.json"` → `EXPORT OK shapes=37 extras=14`; a `python3 -I` diff of it against `source/shapes-current.json` with `meta` removed → equal. Not equal is a stop (Task 9).
- [ ] **Step 2: Failing checks first.** With the server stopped: `sh export.sh` → exit 1, `shapes-picked.json was not rewritten` (Review Focus 2). `roundtrip.gd --in=/nonexistent` → exit 1, `cannot read` (Review Focus 4). After Step 3, three more that must fail: the Godot output with one shape's poses deleted → `FAIL`, `MISSING`; with one vertex moved by 0.01 px → `FAIL`; `roundtrip.sh` on a missing input while an old `roundtrip-godot.json` lies there → exit 1.
- [ ] **Step 3:** Implement `#export`, `fix6`, `roundtrip.gd`, `#roundtrip` as in Interfaces. The today counterpart: `sh roundtrip.sh docs/images/map-art/source/shapes-current.json` (page side `#roundtrip&set=today`, drawing from `shapes-current.js`) must give `PASS`, which proves the comparer against the game's own shapes before it judges the picked ones.
- [ ] **Step 4:** `sh export.sh` → exit 0, `<n> shapes, corrections hold`. `sh roundtrip.sh` → `PASS`. Record poses, max difference, ties (the earlier redraw had 3 ties in 555 poses, all one same-colour barrel pair). A `FAIL` or a tie on a picked shape whose triangles differ in slot → Task 9.
- [ ] **Step 5:** `#audit` (the page's existing paint-order, footprint, owner-share, contrast and colour-vision checks over every shape in the merged data) via `sh report.sh audit audit` → `PASS`. Review Focus 5: `rg -n 'wargrid-private|wargrid-wt-|/Users/' docs/images/map-art` → no match; `git check-ignore docs/images/map-art/source/picks.json` → the path; `git status --short docs/images/map-art/source` shows no `.uid` file (if Godot wrote one, add `*.gd.uid` to the source `.gitignore`).
- [ ] **Step 6:** Checks: public, shell, Python, gdlint. Evidence row.

### Task 8: Zero Hour defaults for low power, wrecks and paused construction

Model: Sonnet medium. Parallel with Task 7. Read-only in the reference engines.

**Files:** none. The section `## Zero Hour defaults` comes back in the report; the coordinator writes it into `docs/reference/map-art-round-6-verification.md` (Task 7 runs beside this one).

**Interfaces:** Produces, for each of three topics, the Zero Hour behaviour and look with path:line @ revision and INI entry:line from `build/zh_ini/inizh.jsonl` (`python3 tools/zh_ini.py dump` first): (a) a building and a defence without power (what stops, what the player sees: lights, animation, icon, tint); (b) vehicle wrecks (hulk object, look, lifetime; confirm or contradict Wargrid's 20 s tanks / 8 s light vehicles); (c) a construction site paused part-way (what shows, whether the scaffold differs from just-started). Each with "Wargrid today" (where the game decides it, path:line at `9b21db3`) and an uncertainty line. Tasks 15, 16, 17 consume it.

- [ ] **Step 1:** Look up, cite, write. A finding without a citation is labelled "not found".
- [ ] **Step 2:** Checks: public. Evidence row.

### Task 9: Stop gate 3, round trip

Runs only when Task 7 Step 1 or Step 4 failed. Coordinator: show the failing poses; the user decides between fixing the candidate data (then Task 7 Step 4 again) and listing the shape as failing. A failing shape is never dropped from the comparison.

### Task 10: Commit point B

- [ ] Coordinator commits (pre-approved) and shows the summary. Message: `Export the picked map art shapes and prove them in the game's bake` / `shapes-picked.json carries the FRC, Armed Pickup and tank height corrections; every picked shape baked headless matches the page.`

### Task 11: Round 6 page frame

Model: Sonnet high. Before Tasks 12-17. Review: fresh Opus high on the diff.

**Files:** Modify `round6.html`, `pics.js`, `page.css`, `README.md`.

**Interfaces:**
- Steps come from `window.CAND6` in this fixed order: `surfaces`, `neon`, `edge`, `power` (A/B), `paused`, `wrecks` (draw-and-confirm: options `yes`, `change` with a note), plus an optional `clash` (Task 20). Each step file (Tasks 12-17) sets `CAND6.<key> = {q, why, look, rec, numbers?, A: {name, data}, B: {name, data}}` (draw-and-confirm: one `A`). A missing step shows "[step missing: <key>]", never an error.
- An option's `data` has three optional fields, and the frame applies exactly these, in the page, the pictures and the export: `shapes: {<shape id>: <shape>}` replaces whole shapes, each in the export's shape format (Task 7); `palette: {<name>: <value>}` overrides palette values under the names `palFor` already uses plus the new `PILE_PAD`, `DOOR`, `BUILDING_SIDE_DARK`, `NEON` (the eight owner colours), `CANVAS`, `EDGE_SIDE` and `EDGE_HEIGHT`; `overlay: (ctx, scene, api) => void` draws what is neither (the map edge, a no-power cue) after the world, where `api` gives the page's projection and palette functions. The export carries `shapes` and `palette`; an `overlay` is described in the step's `look` text for the reference doc. Before Tasks 12-17 start, a throwaway `cand6-fixture.js` (not kept) exercises one of each on the page and in a screenshot.
- Opening state: step 1, sand, zoom 0.5, lifted owner colours (round 5 `owners: A`), HUD v5 layer off. Keys: `A`/`B` flip, `Enter` picks, `H` HUD v5 layer on/off (Full tier, state `none`, 1280x720), `G` sand/dark ground, `Z` zoom 0.5/1/2, `[`/`]` heading, `N`/`P` next/previous step. Pick posts `{key, pick, note}`; the page shows `Recorded.` only on a 204, else `Not recorded` (Review Focus 2). Without `picks.json` every step shows its `rec` option.
- `#step=<n>&show=A|B&ground=sand|dark&zoom=..&shot=1` renders the stage only; `PICS` resolves `step<n>-<A|B>[-dark]` to it, so `shoot.sh` shoots review screenshots.
- `PICS` gains the generated round 6 pairs from `CAND6.<key>.pics` (Tasks 12-17).
- New picture `old-shapes-check-z1` in `PICS`: the defences, the Laborer, the supply truck and rubble beside their faction's picked bodies, under the darker side band (today's shapes, picked palette).

- [ ] **Step 1:** With the server stopped, Pick → `Not recorded`. With the server up, Pick → `Recorded.` and `source/picks.json` holds the key.
- [ ] **Step 2:** Implement; `sh report.sh audit audit` → `PASS` still; `OUT=build/map-art/frame sh shoot.sh old-shapes-check-z1` → one 2560x1440 file.
- [ ] **Step 3:** Checks: public, shell, Python. Evidence row.

### Tasks 12-17: Drawing candidates, one Opus agent per step

Model: Opus high each. **Parallel:** all six at once after Task 11 (and Task 8 for 15-17). Each agent writes only its own file `docs/images/map-art/source/cand6-<key>.js` (loaded by `round6.html`, each adding its key to `window.CAND6`) and returns its evidence text in its report; the coordinator appends it, so no two agents edit one file. The coordinator runs the one map server for all six; agents never start or stop it. Each agent uses its own report name and output folder: `sh report.sh 'audit&name=audit-<key>' audit-<key>` and `OUT=build/map-art/review/<key>`. Reads: blueprint §2, art direction §11 and §12, the integration note, `map-art/notes.md`, the round 1 to 5 blocks in the design answers, the visual and UX second pass. Every option passes `#audit` (paint order at eight headings, footprint, owner share, contrast and colour-vision tables) with no failure in a recommended option; each writes `rec` with one line why. Its today/picked pair is declared in its own file as `CAND6.<key>.pics = {zoom, today: sel, picked: sel}`; `pics.js` turns that into `<stem>-today-z<zoom>` and `<stem>-picked-z<zoom>` (Task 11 builds that), so no agent edits `pics.js`.

| Task | Key | What | Fixed (do not offer) | Picture stem |
|---|---|---|---|---|
| 12 | `surfaces` | Supply pile pad, doors on building side faces, building sides at zoom 1 on the dark ground | the round 5 side band | `surfaces` |
| 13 | `neon` | Neon set (F12): a teal clear of the HUD cyan and a blue and purple pair that pass the colour-vision bar of 20; Neon stays opt-in | the HUD cyan | `neon` |
| 14 | `edge` | Map edge height and canvas colour | slate side faces on camera-facing edges, no lit top line | `edge` |
| 15 | `power` | How a building and a defence show no power (F21); favourite only, the art lab confirms; F21 stays open | — | `power` |
| 16 | `paused` | A construction site paused part-way; round 3's rule (posts alone mean just started or paused) | the rule | `paused` |
| 17 | `wrecks` | Vehicle wrecks on the picked hulls in the art lab's wreck look | 20 s tanks, 8 s light vehicles | `wrecks` |

- [ ] **Step 1 (15-17):** Read `## Zero Hour defaults`; the Zero Hour default is option A or named in `why` when not drawn.
- [ ] **Step 2:** Draw; `sh report.sh 'audit&name=audit-<key>' audit-<key>` → `PASS`; screenshots on sand and dark via `OUT=build/map-art/review/<key> sh shoot.sh step<n>-A step<n>-B step<n>-A-dark step<n>-B-dark` (Tasks 16 and 17 have one drawing: `step<n>-A` and `step<n>-A-dark` only).
- [ ] **Step 3:** Checks: public. Evidence row: options, recommendation, audit lines.

### Task 18: Colour arithmetic for steps 1 and 2

Model: Sonnet medium. After Tasks 12 and 13.

**Files:** Modify `docs/reference/map-art-round-6-verification.md`; `cand6-surfaces.js`, `cand6-neon.js` only to fill `numbers`.

- [ ] **Step 1:** With the page's own colour maths (`contrast`, `simulate`, `pairStats`, `round5.html:312-329` lineage), compute per option: contrast of the pad, doors and sides against sand, dark ground and the side band; for Neon every owner pair's colour-vision distance under the three simulations (bar 20) and the teal's distance to the HUD cyan. Write them into `numbers` so the page shows them under each option.
- [ ] **Step 2:** A recommended option below a bar goes back to its drawing agent (SendMessage), never into the round. Evidence row with the tables.

### Task 19: removed

Cut by the coordinator before the run (2026-11-17): merging the six step files into one `cand6.js` moved data without changing anything. The six `cand6-<key>.js` stay, one file per step. The number is kept so later task numbers do not shift.

### Task 20: Player-experience review before the user's look

Coordinator dispatches `player-experience-reviewer` with the review screenshots of every step (A and B, or the one drawing of steps 5 and 6; sand and dark), `old-shapes-check-z1`, the step texts and the numbers tables. Findings go back to the drawing agents; re-review only the changed steps.

- [ ] **Step 1:** Review, fix, record findings and rulings.
- [ ] **Step 2: Clash check.** If the reviewer or the coordinator sees a clear clash in `old-shapes-check-z1` (a defence, the Laborer, the supply truck or rubble that reads as another faction or as unowned under the darker sides), dispatch one more Opus high drawing agent for a `clash` A/B step for that shape only, then review it. Otherwise record "no clear clash" with the reviewer's line.

### Task 21: Stop gate 4, the pick round

- [ ] **Step 1:** Coordinator starts the server (background), tells the user the page is ready and, on the user's go, opens it: `open -a Firefox 'http://127.0.0.1:8769/docs/images/map-art/source/round6.html'`.
- [ ] **Step 2:** Wait for the user; read `source/picks.json` when the user says done. The evidence rows get the picked option per step and, where a note changes what is built, that as a reported statement; the raw `picks.json` with its notes and views is a working file: the coordinator copies it to the private notes repository as `art-spike/picks-round6.json`, never into a tracked file. Stop the server.

### Task 22: Stop gate 5, the questionnaire

- [ ] **Step 1 (coordinator):** Questionnaire style, rounds of several simple questions with a selector, each with a recommendation: what the picks leave open, and which package each pick lands in where none is named (wrecks are a backlog item, F21 "a later art package", P2.3a for edge, canvas and marks). Write every answer into the evidence rows; Task 27 writes them into the design answers.

### Task 23: Marks, gate reference and backdrop scenes

Model: Opus high. After Task 22.

- [ ] **Step 1:** Write `docs/images/map-art/source/marks.js`: the white marks as decided (selection, hover ticks, attack X, closing move ring, placement cells valid and blocked, range ring, rally pole and flag with its line, dashed target line; white with a dark under-stroke), ported from the private `~/projects/wargrid-private/docs/hud-v5/world/world.js` (read-only; it drives `round5.html` in an iframe through `eval`, the port calls the page's functions directly) and the 12 backdrop scenes `#world=<state>&scale=2` (states `none one many factory plant builder build place blocked enemy pile site`, 1280x800 at 2x, same compositions as `world.js`, with round 6's look). New `PICS`: `marks-z1` (left half sand, right half dark), `gate-reference-z<zoom>` (one composed scene under the HUD v5 layer with the picked map edge showing all five screenshot marks of art direction §11). Mark sizes are cited to their decision, so the reference doc can carry them.
- [ ] **Step 2:** Checks: public, shell. Evidence row.

### Task 24: Final export, round trip and pictures

Model: Sonnet high. After Task 23. Review: fresh Opus high on the diff; `player-experience-reviewer` on the final pictures.

**Files:** Modify `round6.html` (round 6 picks baked as a constant `R6`, as `round5.html` bakes `R4`, so the page shows them without `picks.json`), `pics.js` (`final` selections), `shapes-picked.json`, every `docs/images/map-art/*.webp`; `git rm docs/images/map-art/base-usa-china-z05-hud.webp`.

**Interfaces:** `final` = `ALL_PICKED`, both overlays, round 6 picks, the 2:1 unit shadow in picked pictures; today pictures keep their `shot` selection; base scenes picked colours, no HUD layer; the map edge only where a scene reaches the map border; marks only in `marks-z1` and the gate reference. Final set, 40 names (42 with `clash`; the count is taken from `#report=pics`, never typed in): the 25 of Task 2 (with `base-usa-china-z05`), `old-shapes-check-z1`, `marks-z1`, `gate-reference-z<zoom>`, and today/picked pairs `surfaces`, `neon`, `edge`, `power`, `paused`, `wrecks` (plus `clash` if Task 20 added it).

- [ ] **Step 1:** `sh export.sh` (now with round 6's palette and the paused-site and wreck shapes) → exit 0; `sh roundtrip.sh` → `PASS` (a fail → Task 9 rule); `sh report.sh audit audit` → `PASS`.
- [ ] **Step 2:** Move `source/picks.json` to `build/map-art/picks-recorded.json` first, so the pictures come from tracked files only and a pick that was not baked into `R6` shows as a wrong picture now. `sh shoot.sh` in the background → exit 0, as many files as `#report=pics` lists, all 2560x1440 (`magick identify`), 25 of them replacing the 1x ones. Record total size (`du -sh docs/images/map-art`). Then the same shoot once more into `build/map-art/final-again/`: every picture `magick compare -metric AE` 0 against the first, which proves the re-make is repeatable.
- [ ] **Step 3:** Reviewer on the gate reference, marks, the six pairs and three re-shot picked pictures; fixes, re-shoot only the changed names.
- [ ] **Step 4:** Checks: public, shell, Python. Evidence row.

### Task 25: HUD v5 backdrops and the HUD re-shoot

Model: Sonnet high. After Task 24. Review: fresh Opus high on the diff.

**Files:** Create `docs/images/map-art/source/shoot_worlds.sh`. Modify `docs/images/hud-v5/source/worlds/w-*.png` (12), `docs/images/hud-v5/*.webp` (26).

**Interfaces:** `shoot_worlds.sh [state ...]`: per state a `--window-size=2560,1600` headless screenshot of `#world=<state>&scale=2` straight to `docs/images/hud-v5/source/worlds/w-<state>.png` (PNG, the HUD page reads that name; `full` keeps using `w-factory.png`), fails on a hang or an empty file as `shoot_final.sh`.

- [ ] **Step 1:** `ls docs/images/hud-v5/source/picks.json` → absent, else stop (Review Focus 3).
- [ ] **Step 2:** Map server up; `sh shoot_worlds.sh` → 12 files, `magick identify` 2560x1600.
- [ ] **Step 3:** HUD server up; `sh docs/images/hud-v5/source/shoot_final.sh` and `sh docs/images/hud-v5/source/export_layout.sh`, no picks argument. `cmp` of `layout.json` against `HEAD` → exit 0 (stop if not: the backdrops must not move a rect). That file holds no world data, so two more checks: the top strip's rectangle (from `layout.json`, an opaque slab) cropped from each of the 26 pictures is `magick compare -metric AE` 0 against the same crop of `git show HEAD:<picture>`; and one `magick montage` contact sheet of all 26 in `build/map-art/hud-sheet.png` is read whole: each state over its own scene, the marks where that state has them.
- [ ] **Step 4:** Checks: public, shell. Evidence row. Stop both servers.

### Task 26: Commit point C

- [ ] Coordinator commits (pre-approved) and shows the summary. Message: `Re-shoot the map art at 2x with the round 6 picks` / `Adds the marks, gate reference and old-shapes pictures; the HUD v5 backdrops are now made from the map art source, layout.json unchanged.`

### Task 27: Reference doc and the design answers' Round 6 block

Model: Opus high. After Task 26.

**Files:** Create `docs/reference/map-art-shapes.md`. Modify `docs/reference/design-answers-2026-11-08.md` (a "Round 6" block after the scope questionnaire, form of rounds 1 to 5, with the Task 22 answers; research paragraphs keep their decisions and link to the reference doc where facts move).

- [ ] **Step 1:** Write `map-art-shapes.md`: how to read `shapes-picked.json` (fields as in Task 7, projection from `shapes-current.json` meta, what the round trip proves and what not); then one section each for P2.4, P2.5, P2.6 (shapes, sizes and heights to re-pin, palette values, the tests each pick touches, found with `rg` in `game/tests` and cited path:line, riders, art lab items); a P2.3a section (map edge, canvas, mark sizes); a section for picks not placed in a package yet; last "Not covered or not decided" (zoom 2 versions missing, F21 open, the art lab list from the design's non-goals). Payoff first; every value cited to the export or a decision.
- [ ] **Step 2:** Checks: public. Evidence row.

### Task 28: Art bible v2

Model: Opus high. After Task 27.

**Files:** Modify `docs/art-direction/ART_DIRECTION.md`.

- [ ] **Step 1:** Rewrite: header says v2, 2026-11-17, who wrote which part, decided rules carry their "(user, DATE)" tag and anything else is a proposal; opens with the gate reference picture (`../images/map-art/gate-reference-z<zoom>.webp`) in place of the north star; §3 kept and checked against `game/scripts/presentation/` (path:line); §4 to §9 become the look as decided, short, rules in words, every size, colour value and test only by link to `map-art-shapes.md` or `shapes-picked.json`, illustrated with map art pictures; superseded proposals go; §1 interview table, §11 and §12 stay, §12 gains one line that map art pictures follow the same source and resolution rule; §10 shrinks to its links; §13 word for word (`git diff` of §13 is empty); §2 and the eight sheets `references/00_north_star.png` to `07_palette.png` move to a closing section "Where it started (2026-11-09)", labelled as the starting proposals.
- [ ] **Step 2:** Checks: public. Evidence row.

### Task 29: Other documents

Model: Sonnet medium. Parallel with Task 28.

**Files:** `docs/images/map-art/notes.md` (new table of every picture `#report=pics` lists, what is real and what is not, the source folder and its one-command re-make, "not tested"), `docs/images/map-art/source/README.md` (final: run, keys, hashes, file table, "Needs: Firefox at /Applications, cwebp, ImageMagick for proofs, Godot for export and round trip"), `docs/packages.md` (links to the reference and export in the P2.3a and P2.4 to P2.6 rows, round 6 picks as riders where they land; no state change), `docs/STATUS.md` (F12 and F21 updated with what was picked, F21 stays open), `docs/images/hud-v5/notes.md` (drop the "not re-makeable" sentence, name the shared HUD file and the backdrops' source), `docs/images/hud-v5/source/README.md` (`hud.js`, `hud.css`, backdrops from `../../map-art/source/shoot_worlds.sh`), `docs/development.md` (one line under Start here).

- [ ] **Step 1:** Write. `python3 tools/roadmap.py` is **not** run (no package name or state changes); `git diff README.md` empty.
- [ ] **Step 2:** Checks: public. Evidence row.

### Task 30: Link, path and public checks

Model: Haiku low. After Tasks 28 and 29.

- [ ] **Step 1:** Every relative link and `path:line` in the touched documents resolves (a file exists, an anchor exists as a heading); every `*.webp` in `docs/images/map-art/` is linked from `notes.md` and every link there exists; `rg -n -i 'map-art|hud-v5|mock-up|shapes-current|layout\.json' docs/guide` → no match (the guide stays untouched; a match means a chapter must be named and updated: report it). `sh tools/check_public.sh` → `PUBLIC CHECK PASSED`. List failures only.

### Task 31: Documents review, ponytail review, final checks and commit point D

- [ ] **Step 1:** Fresh Opus high reviewer: the docs diff, `shapes-picked.json`, `game/scripts/presentation/shapes.gd`, `shape_bake.gd`, `palette.gd` and the test files the reference doc cites; checks every code claim and every number against its source. Fix, record rulings.
- [ ] **Step 2:** `/ponytail-review` on the branch diff (over-engineering only); apply cuts, re-run the checks they touch.
- [ ] **Step 3:** `sh tools/run_tests.sh` (`TESTS PASSED <n>`), `sh tools/run_checks.sh` (`CHECKS PASSED 5`), the Python and gdlint commands for `docs/images/map-art/source`; `git status --short game tools` empty. Record each with the tree.
- [ ] **Step 4 (commit point D):** subagents never commit; the coordinator commits (pre-approved), shows `git status --short` and the summary, never pushes. Message: `Write the map art reference and art bible v2` / `Every picked shape, size and colour now has a place in the repository per package; F21 stays open for the art lab.` Then stop: push, merge and the P2.3a design are the user's.

## Stop gates

1. Task 3: first shoot differs beyond the known differences.
2. Task 5: HUD no-difference proof fails (or the baseline drifted).
3. Task 9: a picked shape fails the round trip, or the today export changed.
4. Task 21: the pick round (user at the page in Firefox, picks recorded by the server).
5. Task 22: the questionnaire after the picks.
Commits (Tasks 0, 6, 10, 26, 31) are not stop gates: local commits on `spike-art-6` are pre-approved (user, 2026-11-17). Push, merge and anything on `main` stay the user's.

Plus the milestone prompt's stop conditions (a design contract would have to change, an assertion weakened, the resume record disagrees with the tree) and any change under `game/` or `tools/`.

## Self-review notes

- Spec coverage: Part 1 (Tasks 2, 4, 11), Part 2 export and round trip (Task 7, again in 24), Part 3 first shoot (2), final set (24), new pictures (11, 23, 12-17), backdrops (25), Part 4 pick round (11-22), Part 5 documents (27-29), verification bullets (2, 4, 7, 24, 25, 30, 31), Zero Hour lookup (8), "How the work runs" table (Model routing).
- Proportion: interfaces and commands only; no page code is written here.
