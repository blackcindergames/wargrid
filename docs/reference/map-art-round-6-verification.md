```text
Resume record (updated 2026-11-17, commit point A)
Branch / base commit / working-tree state: spike-art-6 / commit point A (Task 6) / clean after the commit
Last green task / next incomplete task: Task 4 (shared HUD file, review approved) / Task 7 and Task 8 in parallel
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: Task 4 proof: 26 HUD pictures and layout.json unchanged, 8 size shots AE 0, 25 map pictures AE 0 with &font=arial; check_public PUBLIC CHECK PASSED
Known red case or blocker: none; docs/images/hud-v5/source/export_layout.sh can report "not rewritten" by chance (whole-second -nt check), a rerun passes
Approved decisions, pre-authorizations used, deferred gates: stop gate 1 accepted (user, 2026-11-17, Task 2 row); local commit at commit point A (pre-approved); Tasks 3 and 5 not needed; full suite and run_checks.sh deferred to Task 31
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: dispatch Task 7 (export and round trip) and Task 8 (Zero Hour defaults) in parallel
```

## Evidence rows (append-only)

### 2026-11-17 Task 1: Base and verification file (tree: spike-art-6 52f0a06 plus this file)

- `git status --short` empty at start; `git log --oneline -3`: 52f0a06 (Task 0), 9b21db3, 895d615. Exit 0.
- Presentation files unchanged since 10b9423 (`git log --oneline 10b9423..HEAD -- shapes.gd palette.gd shape_bake.gd world_batch.gd world_view.gd isometric.gd graphics_settings.gd`): empty, exit 0.
- Environment: Firefox 160.0; cwebp 1.6.0; dwebp 1.6.0; ImageMagick 7.1.2-36 Q16-HDRI aarch64; Godot 4.7.2.stable.official.ed1daf0bf; Zero Hour `~/projects/CnC_Generals_Zero_Hour` 0a05454; fork `~/projects/GeneralsGameCode` afc2a103f.
- `ls docs/images/hud-v5/source/picks.json`: no such file (expected).
- Baseline `WARGRID_TEST_ONLY=test_shapes sh tools/run_tests.sh`: 22 cases, 1374 checks, 0 failures, TESTS PASSED 1374, exit 0 (log `build/map-art/logs/1-shapes.log`).
- Counts for later proofs: `docs/images/map-art/*.webp` 25; `docs/images/hud-v5/*.webp` 26; `docs/images/hud-v5/layout.json` sha256 `19eb6e1fb5d6c0686761f24728b7dc79ec20d8cb028e327be1351bb0f61ef977`.

### 2026-11-17 Task 2: Move and trim the source, shoot script, first shoot (tree: spike-art-6 52f0a06 plus `docs/images/map-art/source/` untracked)

- `report=fonts` (Firefox headless, server on 8769): `400 ok / 600 ok / 700 ok / 800 ok / PASS 4`, exit 0. `report=pics`: 25 names, `PASS 25`, exit 0.
- First shoot, 1x, `AS=shot`, 25 files each, exit 0, sizes 1280x720; 2x run 25 files 2560x1440, exit 0 (logs `build/map-art/logs/2-shoot-*.log`).
- Count of differing pixels against the committed picture (`magick compare -metric AE`), Inter (`&font=inter`): 21 pictures 0; `damage-today-z05` 2170, `damage-picked-z05` 2170, `placeholders-today-z1` 2381 (text only). `base-usa-china-z05`: 0 against the private page shot with the HUD layer hidden, whole frame (against the committed `-hud` picture 85200, the HUD v4 layer). `base-usa-z1`, `base-china-z1`, `base-frc-z1` carry no HUD layer: 0.
- The three text pictures with `&font=arial` (the fallback face): 0 each. The private pages shoot them 0 against the committed files in the same way: the committed text was drawn before Inter had loaded.
- Public Sans (1x) against Inter (1x): only those three differ (2062, 2062, 2434 px, text); the rest 0.
- 2x beside 1x (`units-picked-z2`, `world-picked-z05`): same layout, edges sharper.
- `sh tools/check_public.sh`: `PUBLIC CHECK PASSED`; `sh tools/run_shell_checks.sh`: exit 0; ruff format, ruff check, mypy on `server.py`: exit 0. `git status --short game tools`: empty. Server stopped.
- Stop gate 1: with Inter `damage-today-z05` 2170, `damage-picked-z05` 2170, `placeholders-today-z1` 2381; with `&font=arial` 0 each. Accepted (user, 2026-11-17): the first-shoot proof baseline for these three is `&font=arial`, because the committed captions were drawn in the fallback face; kept pictures stay Public Sans.
- Decisions:
  - `legacy` is part of the selection (`{steps, fix4b, fix6, legacy}`): the `shot` selections of the rounds 1 to 4 pictures set it, and the old ground shade, shadow and owner table and no China tank mix follow. Task 24's `final` selections must set it false.
  - A step left out of a selection does not apply; `'0'` means today. Why: `damage: '0'` turns bodies back to today's shapes, while the other round 4 pictures leave damage unset.
  - `&font=arial` beside `&font=inter` (proofs only, both kept and documented), per the stop gate 1 acceptance above.
  - `world-picked-z05`, `world-picked-dark-z05` and `world-cliff-decor-z1` use fog `'0'` (the old page never applied fog outside its own step); `world-today-z05` has every round 5 step `'0'`.
  - `dmg` (damage levels spread over the bases) is on only in `world-today-z05`, `world-picked-z05` and `world-picked-dark-z05`.
  - `shoot.sh` runs `report=fonts` first and exits 1 when it fails; the page throws when a Public Sans weight does not load (`&font=arial` is the explicit exception). Negative test on a scratch copy with a missing face: `shoot.sh` exit 1, no file written.
  - `meta.export_command` in `shapes-current.*` is the plan's contract string with literal `<repo>` and `<file>`.

### 2026-11-17 Task 4: One shared HUD file and its no-difference proof (tree: spike-art-6 52f0a06 plus `docs/images/hud-v5/source/{hud.js,hud.css}` untracked, `round1.html` modified, `docs/images/map-art/source/` untracked)

- Step 1: `docs/images/hud-v5/source/picks.json` absent; `git status --short docs/images/hud-v5` empty.
- Step 2 baseline on the unedited source: `shoot_final.sh` exit 0, `export_layout.sh` exit 0 ("78 screens, coverage sums match"), `git status --short docs/images/hud-v5` empty (no drift). 8 size shots (`#shot=<none|many|factory|build>&size=<720|1920>&tier=full&scale=2`, 2560x1440 and 3840x2160) in `build/map-art/hud-before/`.
- `export_layout.sh` failed with "layout.json was not rewritten" on 3 of 5 runs in this task (before and after the move), each time on the `-nt` whole-second check (Firefox writes it within about 1 s of the stamp); rerun once or twice passed, every time with an identical file. Script not edited.
- Step 3: `hud.js` (334 lines, `window.HUDV5`, one global; exports SIZES, STATES, FONT, BG, FLAT, OWNERS, HEALTH, CELL, CELL_PAD, DATA, BASE, KINDS, luminance, contrast, mix, lifted, isCore, pinnedShown, glyph, glyphFor, unitGlyph, layout, dock, hud, hudScale, updateCard, placeRefusal, placeCards, shown), `hud.css` (96 lines: four `@font-face`, `.hud .cur`, every `.hud` rule), `round1.html` 960 to 535 lines (`<link>` and `<script src="hud.js">`, one `const {...} = HUDV5;` line; page-only names stay: size and state labels, keys, name-fit widths, stage, backdrops, coverage, audit, picks). `node --check` on `hud.js` and the page script: ok.
- Step 4 proof: `shoot_final.sh` exit 0 (26 files rewritten, all newer than `hud.js`); `export_layout.sh` exit 0 on a rerun; `git status --short docs/images/hud-v5` shows only `round1.html`, `hud.css`, `hud.js`; `cmp docs/images/hud-v5/layout.json <(git show HEAD:...)` exit 0 (sha256 `19eb6e1f...f977`, as Task 1); 8 size shots in `build/map-art/hud-after/`: AE 0 for all 8 against `hud-before/`. The default (interactive) HUD page renders with no error banner.
- Step 5, map page: `report.sh 'report=fonts' fonts` exit 0, `PASS 4`. Hash `&hud=<state>` (optional `&tier=`) adds the layer from `layout.json` meta values plus `HUDV5.hud` and `placeCards`; layout.json is fetched together with the font load (a fetch after the draw lost the race with the headless screenshot, the page showed no layer). `[hidden]{display:none!important}` added to `page.css` (the HUD page has it in its own style; without it the hidden cursor showed). `page.css` no longer has `@font-face`. Screenshots read by eye: `build/map-art/hud-check/base-usa-z1-hud-none.png` (dock, strip, Team/Menu, minimap, Public Sans) and `base-usa-z1-hud-factory.png` (selection panel, card, hover card).
- Task 2 proof rerun: `SCALE=1 AS=shot EXTRA='&font=arial' OUT=build/map-art/t4-arial sh docs/images/map-art/source/shoot.sh` exit 0, 25 files; `magick compare -metric AE` against `docs/images/map-art/<name>.webp` (`base-usa-china-z05` against `build/map-art/ref-nohud/`): 25 of 25 are 0, 0 differ. Control: `base-usa-z1` against `base-china-z1` AE 72899.8.
- `sh tools/check_public.sh`: `PUBLIC CHECK PASSED`; `sh tools/run_shell_checks.sh`: exit 0; `rg -n 'wargrid-private|wargrid-wt-|/Users/'` over the touched files: no hit. `git status --short game tools`: empty. Both servers (8767, 8769) stopped.
