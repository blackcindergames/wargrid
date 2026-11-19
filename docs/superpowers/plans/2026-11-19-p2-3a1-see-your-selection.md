# P2.3a1 See your selection: Implementation Plan

**Status:** approved by the user 2026-11-19 (implementation not started; the user starts it), written in a fresh session from the handoff `p2-3a1-plan-prompt.txt` (private). Plan reviews done (player-experience, a fresh Opus correctness reviewer, Codex, two code-reference checks) and one fix round applied (2026-11-19); a closure check found four gaps, fixed the same day; the eight owner questions are answered. Writing or approving this plan does not start implementation.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md): one fresh subagent per task, each starting from the resume record in `docs/reference/p2.3a1-verification.md`.

**Goal:** The match HUD stops being a debug readout. One theme, a stretched view with caps, a top strip with the build forecast, the Menu and Playtest chips, top-centre notices (with the offline freeze notice), an interim bottom-right slab, the selection panel for every state, the amber refusal line with today's words, one click resolver, `view_player`, and palette A on the bodies.

**Architecture:**
- `game/scripts/match/hud.gd` becomes a `Control` node with one input, `update_hud(view, selection, view_player, seat)`, signals out and no side effects. Pure display arithmetic lives in a new static helper, `game/scripts/match/hud_model.gd`, which orders also use.
- One static `ViewCaps` (`game/scripts/presentation/view_caps.gd`) decides the stretch: `expand`, capped at 2.4:1 and 16:10, applied by the match and the benchmark, released by the launcher.
- Tests move off the HUD's text first (`hud_text()`, `hud.refusal`). The old `HUD/Status` label then loses one piece per task and is deleted in Task 12.

**Tech Stack:** Godot 4.7.2 typed GDScript; suite runner `game/tests/run_tests.gd`; Python 3 tools (`tools/perf_record.py`, `tools/test_sim_boundary.py`); the HUD v5 HTML source with headless Firefox for the pictures. No simulation, net, relay or protocol change.

**Spec:** [P2.3a design](../specs/2026-11-19-p2-3a-see-your-selection-design.md) (approved by the owner 2026-11-19), sections for P2.3a1 only. Decisions: [design answers](../../reference/design-answers-2026-11-08.md#p23a-design-round-user-2026-11-19) and its "Advisor review" and "Spec review follow-ups" subsections. Values: [layout reference](../../reference/hud-v5-layout.md), [HUD v5 pictures](../../images/hud-v5/notes.md). Row: [packages](../../packages.md#day-lane) P2.3a.

**Verification file:** `docs/reference/p2.3a1-verification.md`. The coordinator creates it as the branch's first local commit, with the [p12 verification](../../reference/p12-verification.md) layout:

````markdown
# P2.3a1 See your selection: verification

Plan: [P2.3a1 plan](../superpowers/plans/2026-11-19-p2-3a1-see-your-selection.md). Spec: [P2.3a design](../superpowers/specs/2026-11-19-p2-3a-see-your-selection-design.md).

```text
Resume record (updated <date/time>)
Branch / base commit / working-tree state: p2-3a1-see-your-selection / <commit holding this plan> / clean
Last green task / next incomplete task: none / Task 1
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: none yet (baseline sh tools/run_tests.sh next)
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: plan approved by the owner <date>; local commits per green task (milestone prompt); stop gate A open
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: Task 1 Step 1
```

## Evidence

| Date | Task | Check | Tree | Result |
| --- | --- | --- | --- | --- |
````

## Global Constraints

- **Branch:** `p2-3a1-see-your-selection` in `~/projects/wargrid`, base = the commit holding this plan.
- **Scope:** P2.3a1 only. Out: the wording table, F29, F30, the N-cap rider, the Esc menu (P2.3a2); white marks, hover ticks, drag box and preview, rally and target line, map edge and canvas, the health-bar rule and size (P2.3a3); everything in the spec's Non-goals.
- **No command and no simulation change.** P2.3a1 adds no command type and changes no simulation code, so it needs no same-tick cases (the F29 list belongs to P2.3a2). The pair gate is the tripwire. `git diff <base> -- game/scripts/simulation game/scripts/net relay protocol` stays empty at every task.
- **Don't touch (whole run):** `game/scripts/simulation/`, `game/scripts/net/`, `relay/`, `protocol/`; command, replay and trace formats; pinned digests and traces (one exemption: Task 15 re-pins WB18's `GOLDEN_COLORS` after review; `GOLDEN_SHAPES` stays); `sound_*.gd`, `game/audio/`, `tools/audio/` (sound is P2.3a2's, with its doc-read rule); `view_state()` fields (aggregate in presentation, spec Anti-goals); any budget, ceiling or assertion loosened to pass.
- **Copy (spec, exact):** `CREDITS`, `POWER`, `LOW POWER`, `→`, `short` (as `700 short`), `Menu`, `Esc`, `PLAYTEST`, `UNDER CONSTRUCTION`, `PAUSED · NO BUILDER`, `POWER +n`, `Supply Pile`, `CREDITS LEFT`, `Empty`, `Right-click ground: rally point`, `N selected · K kinds` (`1 kind`), ` · n idle collector` / `collectors`, the collector labels of the spec table, `Rows: click narrows, Shift-click removes`, and the freeze notice `Match stopped: game error. Please report it. Esc: leave the match.` Numbers use comma thousands (`4,800`), health `cur / max` rounded up. Online notices and refusals keep today's words without the `Rejected: ` prefix.
- **Code style:** typed GDScript, one-line WHY comments only, no `class_name` on new scripts (preload as the codebase does). Edit with the Edit tool or asserted replacements. Scratch Godot scripts live under `build/`, are never tracked, and `quit()` on every path.
- **Subagents** never commit, push, merge, deploy or open a visible window. Commits are the coordinator's (local, pre-authorized by the milestone prompt).
- **Running checks:** every suite, lint, check and benchmark call gets `timeout: 600000`, writes to a file under `build/` and is judged by its exit code; on failure read only `rg -n 'FAIL:|SCRIPT ERROR|ERROR:' build/<log>`. Iterate with `WARGRID_TEST_ONLY=<substring> sh tools/run_tests.sh > build/<task>.log 2>&1; echo exit=$?`.
- **Per-task gate (code tasks):** the task's `WARGRID_TEST_ONLY` runs, then `sh tools/run_tests.sh > build/suite.log 2>&1; echo exit=$?` (the full suite, about 78 s), `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `python3 tools/test_sim_boundary.py`, the empty `git diff` above. Python changes add `sh tools/run_python_checks.sh`; shell changes add `sh tools/run_shell_checks.sh`. New suites are added to `SUITES` in `game/tests/run_tests.gd:6`.
- **Layout sizes** (spec Constraints), as `[window, logical]` pairs: `[1280x720, 1280x720]`, `[1280x800, 1280x800]`, `[1920x1080, 1280x720]`, `[3440x1440, 1720x720]`. Task 4 adds them as `BaseScene.HUD_SIZES`. Containment, anchors and visible-rect checks compare against the logical member; only the window fixture uses the physical one.
- **"No label cut" means containment, never `get_minimum_size() <= size`** (a Control's size is clamped to its minimum, and `Vector2 <=` is lexicographic): every visible Label's global rect lies inside its row's or panel's content rect on both axes, and in a kind row the name and count rects are disjoint.
- **Source scans live in Python** (`tools/test_hud_sources.py`, found by `tools/run_python_tests.sh`): CI runs the suite as an exported binary with compiled scripts, so a GDScript test cannot read `res://` sources.
- **Public repo:** home-relative paths, private files by name marked "(private)", no personal details; `sh tools/check_public.sh` at the docs task.

## Review Focus

1. **A window dragged across a cap during a match** (2.41:1 to 2.39:1, then 1.59:1): no 1 px bars, the HUD anchors follow, `size_changed` does not loop. Test ST2 and ST3 (Task 4).
2. **Back to the menu from a capped match** (1728x720 or 1280x800): the launcher is plain `expand` at 1280x720 and uncapped at any size. Test ST4 (Task 4).
3. **The last unit of a kind dies while the pointer is on its row:** the row stays, greyed with count 0, a click on it does nothing, and the panel reflows when the pointer leaves. Test KR4 (Task 11).
4. **Esc-leave after the offline pump failed, with the playtest helper on and units selected:** one Esc opens the menu, the launcher opens, the record is filed with `end` "sim pump failed: ...", no script error; also when the failure is first met while filing. Tests FN2, FN3 (Task 8).
5. **A drag that starts on the map and ends over a panel:** the box keeps up, the release arrives, units under the panel are skipped. Test MR3 (Task 13).

## Tasks at a glance

| Task | What | Model | Reviewer |
|---|---|---|---|
| 1 | State pictures at 2x, then STOP GATE A | Opus | player-experience |
| 2 | Tests read `hud_text()` and `hud.refusal` | Sonnet | fresh Opus |
| 3 | One theme | Opus | fresh Opus + player-experience |
| 4 | Stretch with caps | Opus | fresh Opus + player-experience |
| 5 | HUD node and `update_hud()` | Opus | fresh Opus |
| 6 | Top strip, forecast and swatch | Opus | fresh Opus + player-experience |
| 7 | Chip stack and online notice | Opus | fresh Opus + player-experience |
| 8 | Offline freeze notice | Sonnet | fresh Opus + player-experience |
| 9 | Interim slab | Opus | fresh Opus + player-experience |
| 10 | Selection panel: one object | Opus | fresh Opus + player-experience |
| 11 | Selection panel: kind rows, collector labels, rebuild count | Opus | fresh Opus + player-experience |
| 12 | Refusal line with today's words | Opus | fresh Opus + player-experience |
| 13 | Click resolver and HUD mouse routing | Opus | fresh Opus + player-experience |
| 14 | `view_player` | Sonnet | fresh Opus + player-experience |
| 15 | Palette A on the bodies (own commit) | Sonnet | fresh Opus + player-experience |
| 16 | Benchmark `--hud` rows | Sonnet | fresh Opus |
| 17 | Focus card and docs | Sonnet | fresh Opus; player-experience on the card |

## Coverage: spec item to task

| Spec item (P2.3a1) | Task |
|---|---|
| Pictures before the builders, owner look | 1 |
| Text pins moved first (behaviour checks; IC1 golden) | 2 |
| Pure text pins: Bs1, K4 | 6 (K4's kind and health part 10) |
| HUD1, E1, HU1 | 10 (HUD1's collector part 11; HU1's construction 5) |
| S1 collector phase | 11 |
| N1, K5, TU1, resume-status layout | 9 |
| FS1 (12 px) | 3 |
| H1 key hints stay | 2 (read through `hud_text()`), 9 (text moves into the slab) |
| No-overlap lists (PO8, perf overlay, pause menu) | 7, 12 |
| `test_scene.gd:67` click-through | 12, 13 |
| `test_benchmark.gd:84` | unaffected (16 keeps the benchmark's own label) |
| One theme, type scale, `tnum`, spacing, corners; theme effective sizes in the launcher | 3 |
| Stretch: `layout_for` unit test, root-window test, size pairs, L7, L13, N25, launcher round trip | 4 |
| HUD node, narrow input, side effects moved, `hud_text()` helper | 2, 5 |
| Top strip, swatch, power as used / available, forecast forms | 6 |
| Chips, F3 under the chip, Esc chip rule, online notice | 7 |
| Offline freeze notice, `failure()`, pin 9 to 10, leave-path fix | 8 |
| Interim slab, China menu and nine-entry queue with the overlays open, armed look | 9 |
| Selection panel per state at four sizes | 10 |
| Kind rows, largest roster, rows hold, collector labels, idle header, rebuild count | 11 |
| Refusal line rules with today's text | 12 |
| Click resolver table, hover equals click, kind-row and map shift rules, drag filter, pile kept, routing through the viewport | 11 (row clicks), 13 |
| `view_player` | 14 |
| Palette A on the bodies, goldens and SH15 in one commit | 15 |
| Benchmark `--hud`, `hud_select` at 1280x720 and 2560x1080, `window=` check, mechanics in the window, ceiling, `perf_record.py` marker | 16, gate B |
| Gate: suite, checks, headless benchmark with the pair gate, rendered rerun plus both HUD rows, reviews, playtest | Stop gates B and C |
| Docs: guide 01, 05, 12, 13; packages split, STATUS, roadmap; hud-v5-layout; map-art-shapes notes; development.md Start here; SB5a inherits | 17 |

---

### Task 1: State pictures at 2x (then STOP GATE A)

ART_DIRECTION §12 asks for every state drawn, in Public Sans, at 2x, with the source beside the pictures. Read §12, the layout reference and `docs/images/hud-v5/source/README.md` first.

**Files:**
- Create: `docs/images/hud-v5/source/p2-3a1-states.html` (loads `hud.css`; fonts from `game/fonts/`; a `#shot=<state>` hash like `round1.html`, plus a `#shot=collector` branch that draws the collector labels, so `collector-status.webp` is shot from this page too), `docs/images/hud-v5/source/shoot_p2_3a1.sh` (headless Firefox and `cwebp`, after `shoot_final.sh`, but with `--window-size=2560,1440` and the matching `size=`; like it, it needs `python3 server.py` running on 127.0.0.1:8767 first), pictures `docs/images/hud-v5/p2-3a1-<state>.webp`.
- Modify: `docs/images/hud-v5/source/collector-status.html` and `docs/images/hud-v5/collector-status.webp` (redrawn to the spec's label table: no place numbers, `TO SUPPLY DEPOT`, `BUILDING`, `MOVING`, the header idle count), `docs/images/hud-v5/notes.md` (a P2.3a1 section), `docs/images/hud-v5/source/README.md` (two rows).

**Pictures** (spec "Pictures before the builders"), a 1280x720 layout at 2x, so 2560x1440 (agent call: the first gate size). Each picture is the whole 1280x720 screen over a plain backdrop, with the strip, the chips, the slab and (where a state has one) the panel all present, because gate A is the owner's only look at the interim layout as a whole:
1. `slab`: the interim slab with its hint lines (today's key hints, the resume hint, the kind-row hint) and an armed build button (`panel2`, 2 px `sel` inset), China's build menu in as many columns as fit 432 px.
2. `notice`: the top-centre online notice (`Waiting for player 2`) and, as a second picture `freeze`, the freeze notice.
3. `forecast`: four strips: `CREDITS 4,800 → 3,600` `POWER 8 / 10 → 11 / 10 LOW POWER`; `CREDITS 4,800 → 4,000` `POWER 8 / 10 → 8 / 15`; `CREDITS 500 → 700 short` (the arrow stays, `700 short` replaces the after-value); an FRC strip in the form owner question 6 picks. Each with the swatch.
4. `sites`: your paused site (`PAUSED · NO BUILDER`, muted), an enemy site with its percent, and the interim factory panel with its footer (84 px).
5. `chips`: the stack closed; checklist open; checklist and note form open; F3 open with each; helper off; and the worst case: China factory with a nine-entry queue in the slab, the checklist at its height cap and the note form open, laid out by the rule of owner question 5.
6. `refusal`: the amber line with today's text (`Insufficient credits`).
7. `pile`: 62 px, `CREDITS LEFT 10,650`, and `Empty`.
8. `rows`: kind rows with one row hovered (`panel2`, pointing hand) and one held row (count `0`, muted, empty bar).
9. Collector labels and the idle header `9 selected · 2 kinds · 1 idle collector` (in `collector-status.webp`).

- [ ] **Step 1:** Draw the pages and shoot the pictures. Check each is 2560x1440 (`sips -g pixelWidth -g pixelHeight <file>`) and that every value comes from the layout reference or the spec. Headless Firefox only; no visible window.
- [ ] **Step 2:** The [player-experience reviewer](../../../.claude/agents/player-experience-reviewer.md) checks the pictures against the spec's P2.3a1 sections and the layout reference. Fix its findings in the source, reshoot.
- [ ] **Step 3:** Commit `Draw the P2.3a1 HUD states at 2x`.
- [ ] **STOP GATE A:** the owner looks once (Firefox, `open -a Firefox <file>`). Task 2 may run while the gate waits; Task 3 and later start after the look. Findings go into the pictures and, if they change a value, into the design answers before Task 6.

**Don't touch:** `round1.html`, `hud.js`, `layout.json`, the 26 existing pictures.

### Task 2: Tests read `hud_text()` and `hud.refusal`

About 119 test lines read `HUD/Status`, `hud.note`, `Economy/` or `Rejected` (`rg -c 'HUD/Status|hud\.note|Economy/|Rejected' game/tests` gives 119 at HEAD; the `HUD/Economy` paths alone are about 30 references in 6 test files and stay). Behaviour checks move off the label now, so the HUD can change under them. No visible change.

**Files:**
- Modify: `game/scripts/match/hud.gd` (a `refusal` field), `game/scripts/match/match_screen.gd` (`_take_answers` :160-167, `_submit` :333-338, `refuse` :340-344, `_restart_world` :393), `game/scripts/match/orders.gd` (the five hints :292, :342, :352, :368, :384).
- Test: `game/tests/test_base_scene.gd` (new `hud_text`), the ten files the count names, `game/tests/input_script_rows.gd` and both `_ic_row` helpers (`test_skirmish_scene.gd:1010-1017`, `test_online_scene.gd:1434-1440`).

**Interfaces (produces):**
- `hud.refusal: String`: the raw simulation text or local hint, without `Rejected: `; `""` when none. Set wherever `hud.note` is set today, cleared with it (`_submit`, `reset()`). `note` stays beside it until Task 12 and still builds the Status text.
- `static func hud_text(main: Node) -> String` in `test_base_scene.gd`: the `text` of every `Label` under `main.get_node("HUD")` that `is_visible_in_tree()`, in tree order, joined with `"\n"`. Inside `test_base_scene.gd` tests call `hud_text(main)` directly (that file has no `BaseScene` constant); other files use `BaseScene.hud_text(main)`.
- The IC rows' status column becomes `"|refusal=" + main.hud.refusal` in both helpers; `IC1_ROWS` and `IC2_ROWS` are regenerated once, and their diff changes only that column.

**Rules for the move:**
- `hud.note == "Rejected: X"` → `hud.refusal == "X"`; `hud.note.begins_with("Rejected: ")` → `not hud.refusal.is_empty()`; `hud.note.is_empty()` → `hud.refusal.is_empty()`; a local hint keeps its text.
- Writes: `hud.note = X` → `hud.refusal = X` (K4 `test_skirmish_scene.gd:157`, P4 `:730`; `reset()` clears both). Exempt until Task 12: HU1 `:1254,:1258`, which writes `note` and expects Status to show it.
- `get_node("HUD/Status").text.contains(X)` used as behaviour (notices, refusals, H1's key hints, H6's resume hint) → `BaseScene.hud_text(main).contains(X)` with any `Rejected: ` dropped; `.count("Rejected:") == 1` → `.count("<raw text>") == 1`.
- Pure pins stay on `HUD/Status` until the task that removes their text:

| Pin | Where | Rewritten in |
|---|---|---|
| Bs1 `Credits` | `test_base_scene.gd:75` | 6 |
| K4 | `test_skirmish_scene.gd:136-137` | 6 (credits), 10 (kind, health, mode) |
| HUD1 `HUD_TEXTS` | `test_skirmish_scene.gd:976-1006` | 10, 11 |
| E1 | `test_skirmish_scene.gd:268-271` | 10 |
| S1 phase | `test_skirmish_scene.gd:331-335` | 11 |
| N1 `Place:` | `test_skirmish_scene.gd:761` | 9 |
| HU1 | `test_skirmish_scene.gd:1250-1258` | 5, 10, 12 |
| FS1 | `test_skirmish_scene.gd:776-790` | 3 |
| "below the status" layout pins: K5 `:210-232`, TU1 `:850-851`, RA1 `:1409-1410`, H6 `test_base_scene.gd:362-363`, M5 and M6 `:490-512`, N3 `test_online_scene.gd:102-106`, N29 `:1109-1110` | | 9 |
| No-overlap lists: PO8 `test_playtest_overlay.gd:323`, `test_form_layout` `:734`, `test_perf_overlay.gd:59`, `test_pause_menu.gd:238` | | 7, 12 |
| Scene nodes and click-through: `test_scene.gd:64,67`, `test_skirmish_scene.gd:54` | | 12, 13 |
| `_hud_texts` helper `test_skirmish_scene.gd:738` (used by `:756-770`) | | 9 |
| The benchmark's own label `test_benchmark.gd:84` | | stays (unaffected) |

- [ ] **Step 1:** Add `refusal` and `hud_text`. Move the tests by the rules.
- [ ] **Step 2:** Prove the move with a temporary edit, then revert: stop `_take_answers` setting `refusal` (the path RA1, RA3, RA5 and SB3 use) → `WARGRID_TEST_ONLY=test_skirmish_scene` is red; then stop `refuse()` setting it → `WARGRID_TEST_ONLY=test_base_scene` is red (RL1, RA6). Record both.
- [ ] **Step 3:** `rg -n 'hud\.note' game/tests` → only HU1 `:1254,:1258`; `rg -n 'Rejected' game/tests` → nothing; `rg -n 'HUD/Status' game/tests` → only the lines in the table above. Per-task gate. Commit `Read HUD words through hud_text and hud.refusal in tests`.

**Don't touch:** OV7 to OV11's voice timing (P2.3a2 flips them); the driver `notice()` pins `test_online_scene.gd:1894,1916,1933`.

### Task 3: One theme

**Files:**
- Modify: `game/ui/launcher_theme.tres`; `game/project.godot` (`[gui]` `theme/custom="res://ui/launcher_theme.tres"`); delete the per-node themes `match_screen.gd:66-67`, `pause_menu.gd:34`, `perf_overlay.gd:22`, `playtest_overlay.gd:43`, `playtest/focus_card_view.gd:23`, `match/result_panel.gd:26` and `scenes/launcher.tscn:15` (the same file on the launcher root, with its now unused `ext_resource` id=2 at `:4` and the `load_steps` count); `launcher.tscn:316` join code 20 → 16 or 24, whichever fits the field at 1280x720; `game/scenes/skirmish.tscn` (`Status` gets `theme_type_variation = &"HudHint"`, so the interim label stays 12 px).
- Formerly 12 px surfaces (owner question 4, user 2026-11-19: today's 12 px): every control `hud.gd`, `pause_menu.gd`, `perf_overlay.gd`, `playtest_overlay.gd` and `focus_card_view.gd` build in code gets a `HudSmall*` variation at creation (`HudSmallLabel`, `HudSmallButton`, `HudSmallField` for `LineEdit` and `TextEdit`, `HudSmallCheck`): 12 px, today's Godot-default button and field styles copied into the theme with corner radius 0 (Godot's default is 3, `default_theme.cpp:55`; square corners in the match, and TH3 holds for `HudSmall*` too), so neither the size nor the launcher's `Button` stylebox (margins 15/13, radius 5) spills into the match. The slab buttons move to `HudButton` in Task 9.
- Local overrides in the files this task touches snap to the scale: `result_panel.gd:50` 15 → 16, `focus_card_view.gd:82` 28 → 30 (agent call: nearest step), result-panel corners per owner question 1.
- Delete: `game/scripts/presentation/ui_style.gd` and its `.uid`, and every `const UiStyle = preload(...)`: `match_screen.gd:17`, `pause_menu.gd:3`, `perf_overlay.gd:4`, `playtest/focus_card_view.gd:3`, `playtest_overlay.gd:3`, `world_view.gd:9`, `test_skirmish_scene.gd:13`. `world_view.gd:336,669` read `const MAP_LABEL_SIZE: int = 12` in `world_view.gd`; map labels keep `ThemeDB.fallback_font` until P2.5; `test_skirmish_scene.gd:328` and FS1 `:788-789` read `View.MAP_LABEL_SIZE` or the effective size instead of `UiStyle.FONT_SIZE`.
- Test: new `game/tests/test_hud.gd`, added to `SUITES` in `game/tests/run_tests.gd:6`; `test_launcher.gd` T1 and L27 (`:857-877`), L19c (`:687-689`), L30 (`:1377`); FS1.

**Interfaces (produces), in `launcher_theme.tres`:**
- Theme type `Tokens`, colours `bg`, `btn`, `panel2`, `quiet`, `well`, `line`, `text`, `muted`, `sel`, `amber` at the layout reference values. Drawing code reads `ThemeDB.get_project_theme().get_color(&"<token>", &"Tokens")`; no second copy. Owner colours are not tokens: they come from `WorldView.owner_color()` (Task 15 makes it palette A).
- Label variations: `HudTitle` 14/700, `HudRow` 13/600, `HudNumber` 13/700 `tnum`, `HudCredits` 16/700 `tnum`, `HudLabel` 12/700 with `spacing_glyph` 1 (text set in capitals by code), `HudHint` 12/400 muted, `HudKey` 12/700 muted. Button variations `HudButton` (`btn` fill, 1 px `line`, 32 high, 13/600), `HudButtonArmed` (`panel2` fill, 2 px `sel` inset) and `HudChip` (`btn`, 1 px `line`, with `normal`, `hover` and `pressed`; the Menu and Playtest chips are Buttons). Panel stylebox `HudSlab` (`bg`, 1 px `line`). Corner radius 0 on every `Hud*` stylebox.
- `tnum`: `FontVariation` sub-resources over Public Sans Bold with `opentype_features` `tnum` = 1, as `lab_look.gd:65-73` builds it (the key is the integer tag `TextServerManager.get_primary_interface().name_to_tag("tnum")`).
- Launcher sizes snap to the scale 12, 13, 14, 16, 24, 30: `default_font_size` and every 15 → 16 (`FooterLink`, `FieldLabel`, `PanelTitle`, `FooterStatus`, `Subtitle`, `FooterRich`), `PrimaryButton` 17 → 16, `Logo` 23 → 24; `Hint`, `HintRich` 13, `Tag` and `SidebarVersion` 12, `PageTitle` 30 unchanged.
- Corners and paddings: as the owner answers question 1; the default (recommendation) snaps the whole theme file: radii 5 → 2 (the focus ring too), content margins to the scale (15 → 16, 13 → 12, 14 → 16 or 12 by fit), no shadows. In `launcher.gd` and `launcher.tscn` only the lines this plan edits snap.

- [ ] **Step 1: Failing tests** in `test_hud.gd`:
  - **TH1 `test_theme_tokens`:** the project theme's path is `res://ui/launcher_theme.tres`; each of the ten `Tokens` colours equals its layout-reference value.
  - **TH2 `test_type_scale`:** every font size in the theme (default and each entry) is in `[12, 13, 14, 16, 24, 30]`; `HudNumber` and `HudCredits` fonts are `FontVariation`s whose `opentype_features` hold the `name_to_tag("tnum")` key at 1, and a Label with each variation measures `"111"` and `"888"` at the same width.
  - **TH3 `test_no_rounding_or_shadow`:** every `Hud*` `StyleBoxFlat` has radius 0; every other `StyleBoxFlat` (`StyleBoxEmpty` has no radius) has radius ≤ 2 (under the default answer) and `shadow_size` 0; the result panel's and focus card's effective styles after `_ready()` too.
  - **TH4 `test_launcher_effective_sizes`** (T1 and L27 rewrite, `test_launcher.gd:857-877`): the theme reads come from `ThemeDB.get_project_theme()` (`launcher.theme` is null now); the pins 15, 17 and 23 become 16, 16 and 24 in the same edit, weights, letter spacing and colours kept; at 1280x720 the launcher's `FieldLabel`, `PanelTitle` and `PrimaryButton` controls report `get_theme_font_size("font_size") == 16`, `Logo` 24, `PageTitle` 30, the join code 16 or 24, and the code field's text rect lies inside the field.
  - **L19c:** both footers report exactly 16 (the snapped `FooterStatus`, user 2026-11-19), and the footer fit checks stay. **L30:** the ring radius pin follows owner question 1 (≤ 2 under (a)); the 2 px width, 4 px float and focus-differs-from-hover checks stay.
  - **TH5 `test_match_surfaces_keep_their_size`:** at 1280x720 the pause menu, the checklist and note form, the F3 overlay, the focus card and the Economy buttons report font size 12 (owner question 4), sit inside the view and are pairwise disjoint where PO8 and the pause and perf tests already require it; R1 stays green.
  - **FS1 rewrite:** every HUD control's font size is ≥ 12, `HUD/Status` is 12, and the Economy buttons are 12 until Task 9.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=test_hud` → red; record.
- [ ] **Step 3:** Implement. Theme spill check (spec risk): run `WARGRID_TEST_ONLY=test_launcher`, `test_playtest`, `test_playtest_overlay`, `test_pause_menu`, `test_perf_overlay`, `test_skirmish_scene` (result panel cases) → exit 0.
- [ ] **Step 4:** Per-task gate. Commit `Make the launcher theme the one project theme`.

**Don't touch:** map labels' font; the launcher's grey look beyond sizes, corners and paddings. Docs: guide 05's file list (`:244`) drops `ui_style.gd` in Task 17.

### Task 4: Stretch with caps

**Files:**
- Create: `game/scripts/presentation/view_caps.gd`; `game/tests/test_view_caps.gd`.
- Modify: `game/project.godot` (`window/stretch/aspect="expand"`); `game/scripts/launcher.gd` (`_enter_tree` :57-58 calls `ViewCaps.release(get_tree().root)`; delete `_exit_tree` :60-61, because it runs after the match has entered (`:536-538`) and would undo its caps; delete the keep switch `:535`); `match_screen.gd` (`_enter_tree` applies, `_exit_tree` :117-118 also releases); `game/scripts/debug/movement_benchmark.gd` (`_ready` applies, `_exit_tree` releases).
- Test: `test_view_caps.gd` added to `SUITES` in `game/tests/run_tests.gd:6`; `test_base_scene.gd` (`HUD_SIZES`, `sized_port`); L7 `test_launcher.gd:122-129`, L13 `:345`, N25 `test_online_scene.gd:845-854`; the match layout tests PO8 `test_playtest_overlay.gd:303`, `test_form_layout` `:709`, `test_pause_menu.gd:181,225`, R1 `test_skirmish_scene.gd:408` move to `HUD_SIZES`; PO3 `test_perf_overlay.gd:50` (runner root, no size loop today) gains a `sized_port` loop.

**Interfaces (produces):**
```gdscript
# view_caps.gd
extends RefCounted
const BASE := Vector2i(1280, 720)
static func layout_for(window: Vector2i) -> Dictionary  # {"size": Vector2i, "aspect": Window.ContentScaleAspect}
static func apply(root: Window) -> void    # writes layout_for(root.size) now and connects root.size_changed once
static func release(root: Window) -> void  # disconnects, drops a pending write, writes BASE with EXPAND
```
- `layout_for`: aspect above 2.4 → `1728x720`, `KEEP`; below 1.6 → `1280x800`, `KEEP`; otherwise `1280x720`, `EXPAND` (exactly 2.4 and 1.6 are inside). No rounding to the window aspect inside the cap.
- Both write `content_scale_size` and `content_scale_aspect` only when the value differs.
- A resize never writes inside `size_changed`: the handler only marks a write pending and `call_deferred`s one coalesced write of `layout_for(root.size)` (the engine emits `size_changed` from inside `_set_size()` and re-attaches its own rect afterwards, so a nested write can be overwritten). `release()` clears the pending mark, so a write queued before the exit never lands.
- `BaseScene.HUD_SIZES: Array[Array]` (the Global Constraints pairs) and `static func sized_port(runner, window: Vector2i, logical: Vector2i) -> SubViewport` (`size`, `size_2d_override`, `size_2d_override_stretch = true`, as `test_launcher.gd:155-161`).

- [ ] **Step 1: Probe** (spec risk, not run yet): scratch `build/p2-3a1-root-probe.gd`, headless, sets the root window to 2560x1080 with `expand` and prints `get_visible_rect().size` after two frames, then the deferred cap write after a resize, counting `size_changed` emissions and writes over the next five frames. Record both in the verification file. If the headless root ignores its size, say so and stop for the coordinator: the code under test reads `get_tree().root`, so an embedded child `Window` does not exercise it, and the real cross-cap check moves to the gate B window batch; if the writes keep coming, stop and report.
- [ ] **Step 2: Failing tests** in `test_view_caps.gd`; each saves and restores the root's size, scale size and aspect (LB16, `test_selection_lab.gd:428-442`, saves the first two):
  - **ST1 `test_layout_for_table`:** 1280x720, 2560x1080, 3440x1440, 2880x1200 (2.4) and 1280x800 (1.6) give `1280x720 EXPAND`; 3840x1080 gives `1728x720 KEEP`; 1024x768 gives `1280x800 KEEP`.
  - **ST2 `test_caps_on_the_root_window`:** a match scene as the current scene; root 2560x1080 → after the deferred write settles, visible rect 1706x720; 3440x1440 → 1720x720; 3840x1080 → `1728x720 KEEP`; 1024x768 → `1280x800 KEEP`; freeing the scene → `1280x720 EXPAND`, and a later resize writes nothing. Task 6 adds the strip's anchor to it.
  - **ST3 `test_cap_writes_only_on_change`:** the same size twice writes once; crossing both caps and back gives one write per resize, and no further write over the next five frames.
  - **ST4 `test_launcher_uncapped_round_trip`:** the launcher at 1024x768 and at 3840x1080 → `1280x720 EXPAND`; then the offline Start path without its scene change: `_offline_setup()`, `skirmish.tscn` instantiated and made the current scene by the test (the Start lambda, `launcher.gd:82-84`, calls `change_scene_to_file` with no seam) → the match's `layout_for(root.size)`; the match freed and a launcher added back → `1280x720 EXPAND`.
  - **L7 rewrite:** `EXPAND` at 1280x720 at the fixture start and after the launcher leaves the tree. **L13:** unchanged. **N25 rewrite:** after `_start` the aspect and size equal `ViewCaps.layout_for(root.size)` at each of its sizes.
- [ ] **Step 3:** Implement; move the match layout tests to `HUD_SIZES`: what they assert stays, but the visible-rect, containment and anchor checks compare against the pair's logical size (today's loops use one `size` for both).
- [ ] **Step 4:** Per-task gate. Commit `Stretch the match to the window with 2.4:1 and 16:10 caps`.

**Don't touch:** the labs' own 1280x800 override (LB16); the camera clamp (`match_screen.gd:281`).

### Task 5: HUD node and `update_hud()`

A refactor: the HUD's text stays exactly as today (HUD1 and the IC rows stay green).

**Files:**
- Modify: `game/scripts/match/hud.gd` (`RefCounted` → `extends Control`); `game/scripts/match/match_screen.gd` (`var hud` :36 becomes `var hud: Hud` with `Hud` the preloaded script at :11; `_ready` :77 builds `Hud.new()`, `$HUD.add_child(hud)`, `$HUD.move_child(hud, $HUD/Status.get_index() + 1)`, then `hud.setup($HUD/Economy, $HUD/Status)`; `_show` :314-327, `_match_record` :158, `_restart_world` :385-402); `game/scripts/match/orders.gd` (:71, :263 use `HudModel`); `game/scripts/match/result_panel.gd` (static `result_text`).
- Create: `game/scripts/match/hud_model.gd`.
- Test: `test_hud.gd` (HN1, HN2); `tools/test_hud_sources.py` (HN1's source half); HU1 (`test_skirmish_scene.gd:1250-1258`); HUD1's two call sites (`:1001` `_selected_summary(view, ids)`, `:1005` `_enemy_summary(view, inspected_id)`, the six expected strings unchanged); K4's result marks (`:158-159` writes, `:165` reads) move to the screen's `_last_result_tick` and `_last_result_sequence`; the `hud._refresh_hud` callers (`:140`, `:709`) and the `hud._result_text` callers (`:148`, `:1372`, `:1374`, `:1602`).

**Interfaces (produces):**
```gdscript
# hud.gd
extends Control
signal menu_chosen(index: int)
signal entry_cancelled(entry_id: int)
signal produce_pressed()
signal cancel_build_pressed()
var refusal: String = ""
var note: String = ""     # goes in Task 12
var rebuilds: int = 0     # structural rebuilds only (Tasks 10 and 11 use it)
var menu_kinds: Array = []
func setup(economy: VBoxContainer, status: Label) -> void  # status goes in Task 12
func update_hud(view: Dictionary, selection: Dictionary, view_player: int, seat: int) -> void
func reset() -> void
func _refresh_menu(kinds: Array) -> void  # name kept: M5 and M6 call it
```
- The node is named `Hud`, full rect, `MOUSE_FILTER_IGNORE`, added under `$HUD` right after `Status`. `HUD/Economy` stays where it is (its test paths), and `setup` hands it in. `setup` accepts `null` for both (no build menu, no Status); Task 12 drops the `status` argument, so Task 16's benchmark row calls `setup(null)`.
- `selection` keys: `ids: Array[int]`, `building_id: int`, `inspected_id: int`, `placement_kind: String`, `resume_id: int` (`_view.resume_candidate()`), `notice: String` (`driver.notice()`), `production_kind: String` (`_production_kind(building, state)`, `match_screen.gd:356-358`, so the Produce label needs no screen read), `bright_owners: bool` (`_view.bright_owners`, so the HUD's owner colours follow Neon like the bodies). Task 7 adds `esc_opens_menu: bool`.
- `hud_model.gd` (`extends RefCounted`, statics): `unit_record(units: RefCounted, i: int) -> Dictionary` (from `hud.gd:140-144`), `inspected(view: Dictionary, id: int) -> Dictionary` (from `:155-160`), `building(view: Dictionary, id: int) -> Dictionary` (from `match_screen._building`), `player(view: Dictionary, id: int) -> Dictionary` (from `_local_state`, same `players[0]` fallback), `menu_kinds(view: Dictionary, building: Dictionary, ids: Array[int], faction: String) -> Array` (from `:87-94`), `menu_label(index: int, kind: String) -> String` (moved from `hud.gd:96`, so `HudModel` never preloads `hud.gd`). The screen keeps `_building` and `_local_state` as one-line calls into it. Display arithmetic of later tasks goes here too.
- Produce and Cancel construction connect inside the Hud and leave as `produce_pressed` and `cancel_build_pressed`; the screen wires them to the orders calls they reach today (`match_screen.gd:104`).
- `ResultPanel.result_text(match_state: Variant, team: int) -> String`; `match_screen._result_text(match_state: Variant) -> String` passes `_local_team()` (moved from `hud.gd:175-178`).
- `match_screen._show(state, fresh)`: `_ensure_sound()`; `_take_results(state)` (the due-time loop from `hud.gd:48-52` with its tick and sequence marks on the screen, reset in `_restart_world`); `hud.update_hud(state, _hud_selection(), local_player, local_player)`; `orders.menu = hud.menu_kinds`; `_view.set_inspected(orders.inspected_id)`; `_show_result(state)` (from `hud.gd:65-85`); `_sound.update(state)` when `fresh`. `menu_chosen` connects to `orders._menu_choose(i, false)`, `entry_cancelled` to `orders._cancel_entry`.

- [ ] **Step 1: Failing tests:**
  - **HN1 `test_hud_reads_only_its_input`:** the source half lives in `tools/test_hud_sources.py`: `hud.gd` contains none of `_screen`, `driver`, `orders`, `_sound`, `set_inspected`. The GDScript half loads the script untyped (`var script: GDScript = load("res://scripts/match/hud.gd")`, never the `Hud` const preload, whose two-argument `_init` at HEAD `hud.gd:21` makes a zero-argument `Hud.new()` a compile error that fails the whole runner, `run_tests.gd:6`), checks that `script.get_script_method_list()` names `update_hud` as a named check first (so the red is "HN1 ..."), then builds `var hud = script.new()` and calls `hud.setup(VBoxContainer.new(), Label.new())` under a bare `Control` and `update_hud(Fixture.make_world().view_state(), {...}, 1, 1)`: the Status fixture fills, no match screen, no script error.
  - **HN2 `test_side_effects_live_in_the_screen`:** after `_show` with `orders.inspected_id` set, the view's inspected id equals it; with a builder selected, `orders.menu` equals its `builds`; pressing build button 0 emits `menu_chosen(0)` and arms placement; pressing Produce on a selected barracks queues its unit and pressing Cancel construction on a site cancels it, both through the Hud's signals.
  - **HU1 rewrite:** through `main.hud.update_hud(...)`, keeping its `hud.note` write (Status still prints `note`) until Task 12 moves it to the refusal line; a stepped result of player 2 is ignored by `_take_results`.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=test_hud` → red on the named HN checks; `python3 tools/test_hud_sources.py` → red; record.
- [ ] **Step 3:** Implement. `rg -n '_screen|driver|orders\.' game/scripts/match/hud.gd` → nothing.
- [ ] **Step 4:** Per-task gate; HUD1's expected strings and the IC1/IC2 rows unchanged (only HUD1's two call sites change). Commit `Turn the HUD into a node with one update call`.

**Don't touch:** the Status text, `sound_director.gd`'s own `_unit_record`.

### Task 6: Top strip, forecast and swatch

**Files:** `hud.gd`, `hud_model.gd`; `HUD/Status` loses its first line (`Credits | Power | Tick`) and `You are %s (P%d)` (`hud.gd:59,71`). Test: `test_hud.gd` (TS1-TS5), ST2 (strip anchor), Bs1, K4's credits part.

**Interfaces (produces):**
- `HudModel.strip(view: Dictionary, player: int, placement_kind: String) -> Dictionary` with `credits`, `used` (`power_demand`), `available` (`power_supply`), and while a kind is armed `after_credits`, `after_used` (`used + max(0, -power)`), `after_available` (`available + max(0, power)`), `short` (`cost - credits` when positive, else 0); `power` and `cost` from `Registry.kind(kind)`.
- Node `HUD/Hud/TopStrip` (`HudSlab`, at (8, 8), 32 high, width hugs, padding 0 8, groups 24 apart, label to value 8): `Swatch` (8x8, `WorldView.owner_color(view_player, selection.bright_owners)`, 8 px before `CREDITS`), `CreditsLabel`, `Credits` (`HudCredits`), `CreditsAfter` (muted `→` and the after-value), `Short` (amber `700 short`; while short, `CreditsAfter` shows the arrow alone and `Short` takes the value's place), `PowerLabel`, `Power` (`8 / 10`), `PowerAfter` (`→ 11 / 10`), `LowPower` (amber, when used exceeds available, after the purchase while armed). FRC's power group follows owner question 6 (user, 2026-11-19: hiding the group for a faction with no kind whose `power` is non-zero, read from the definitions).

- [ ] **Step 1: Failing tests:**
  - **TS1 `test_power_reads_used_over_available`:** supply 10, demand 8 → `Power.text == "8 / 10"`, `LowPower` hidden; demand 11 → shown, amber.
  - **TS2 `test_forecast_forms`:** credits 4800, power 8 / 10: armed `china_defence` → `4,800`, `→ 3,600`, `→ 11 / 10`, `LOW POWER`; armed `usa_power_plant` → `→ 4,000`, `→ 8 / 15`, no `LOW POWER`; credits 500 with `china_defence` → `CreditsAfter.text == "→"` and `Short.text == "700 short"` in amber, no after-number; nothing armed → no arrows; an FRC player (no kind with non-zero `power`, read from the definitions) → `PowerLabel`, `Power`, `PowerAfter` and `LowPower` hidden, armed or not (owner question 6, user 2026-11-19).
  - **TS3 `test_swatch_slot_colour`:** 8x8, the colour of `owner_color(1)` for player 1 and `owner_color(2)` for player 2, 8 px left of `CreditsLabel`; with `bright_owners` on, the Neon colour.
  - **TS4 `test_strip_anchor_without_tick`:** at the four sizes the strip sits at (8, 8), 32 high, inside the view; `hud_text` holds no `Tick` and no `You are`.
  - **TS5 `test_strip_patches_values`:** a credits change updates `Credits.text` and leaves `rebuilds` unchanged.
- [ ] **Step 2:** Red; implement; rewrite Bs1 (`hud_text` contains `CREDITS`) and K4's credits part (`TopStrip` visible).
- [ ] **Step 3:** Per-task gate. Commit `Show credits, power and the build forecast in the top strip`.

### Task 7: Chip stack and online notice

**Files:** `hud.gd` (`MenuChip`, `Notice`); `game/scripts/playtest/playtest_overlay.gd` (`Chip`, `Checklist` and `MarkerDialog` placement :170, :245, `_corner_panel` :276-290 whose offset and grow lines :286-288 change, `_fit`, `stack_bottom`); `game/scripts/presentation/perf_overlay.gd` (:23-28, `place`); `match_screen.gd` (menu chip, F3 placement, `esc_opens_menu`); the notice leaves `HUD/Status` (`hud.gd:43-44`). Test: `test_hud.gd` (CH1-CH4), the no-overlap lists.

**Interfaces (produces):**
- Hud `signal menu_pressed()`; `HUD/Hud/MenuChip` (a `Button` with `theme_type_variation` `HudChip` at right 8, top 8, 32 high, padding 0 8; `Menu` 13/600; child `EscChip` (`HudKey` on `well`, at least 18x18) visible only while Esc would open the menu); `HUD/Hud/Notice` (`HudSlab`, centred, top 48, 28 high, muted 13/600, no square, `MOUSE_FILTER_IGNORE`), hidden when `selection.notice` is empty.
- Esc chip: derived from the same conditions as the real Esc dispatch (`match_screen._input` :194-205 and `playtest_overlay._input` :138-145): `esc_opens_menu = not _escape_pending() and not _playtest.holds_match() and not _typing() and not _pause.visible` (`_typing()`, `match_screen.gd:207`, covers the checklist field) (the note form cancels itself on Esc, a typed checklist field releases focus first). Because focus and the form change without a new view, the screen sets it each `_process` frame through `hud.set_esc_chip(flag: bool)`, which writes only on change; `selection.esc_opens_menu` carries the same value into `update_hud`.
- `PlaytestOverlay`: `Chip` (a `Button` with `HudChip` at right 8, top 48: `PLAYTEST` then `n / m`, ticked over total checklist items); pressing it toggles `Checklist` as the backquote key does (agent call); `Checklist` drops from right 8, top 88; `MarkerDialog` sits below `Checklist` when both show, at top 88 otherwise; `func stack_bottom() -> float` = the lowest bottom of the visible chip, checklist and dialog, or 40 (Menu's bottom) with the helper off; `signal stack_changed`.
- Right edge budget at 1280x720 (owner question 5, user 2026-11-19): `_fit` caps the checklist's height at the slab's top minus 8 minus 88 (its scroll container already scrolls), and the note form opens to the left of the checklist (right edge 8 px left of it) when the space below the checklist is shorter than the form. The screen hands `_playtest` the slab's top on every refresh (`_playtest.set_floor(y)`; the view height until Task 9 builds the slab), so the overlay reads no HUD node.
- `PerfOverlay.place(top: float) -> void`; right edge 8; the screen calls `_perf.place(_playtest.stack_bottom() + 8.0)` on `stack_changed` and at start.

- [ ] **Step 1: Failing tests:**
  - **CH1 `test_chip_stack`** at the four sizes, with the longest shipped focus card's checklist: Menu at right 8, top 8; Playtest at right 8, top 48; checklist top 88; checklist and note form both visible and disjoint, the form below (or to the left under the height rule); F3 top 88 with nothing open, below the checklist, below the form; helper off → chip hidden, F3 top 48; the form and F3 always inside the view.
  - **CH2 `test_esc_chip_only_when_esc_opens_the_menu`:** in each state a real Esc is sent through the viewport and the chip is shown exactly when the pause menu opened: nothing pending (shown); a selection, an armed placement, an inspected id, a drag (hidden); the note form open (hidden); focus in a checklist field (hidden); shown again after Esc backs out; shown after the match ends.
  - **CH3 `test_menu_chip_opens_the_menu`:** a press opens the pause menu.
  - **CH4 `test_online_notice_top_centre`:** the online waiting fixture (N2's): `Notice` visible with `Waiting for player 1`, centred within 1 px, top 48, 28 high, clear of the strip at its longest forecast (`700 short` plus `LOW POWER`) and of the chips at 1280x720; the same with the longest notice today's drivers give (`Opponent left before the start (a different map or version, or their game tab was hidden)`, `online_driver.gd:335-339`) and a realistic desync path; `HUD/Status` no longer holds it, `hud_text` does.
  - The no-overlap lists (PO8, `test_form_layout`, `test_perf_overlay.gd:59`, `test_pause_menu.gd:238`) add `HUD/Hud/TopStrip`, `HUD/Hud/MenuChip` and `HUD/Hud/Notice`. P12's PO20-PO28 stay green (F22: the form never blocks play or leaving).
- [ ] **Step 2:** Red; implement; per-task gate. Commit `Stack the Menu and Playtest chips top right and centre the notice`.

### Task 8: Offline freeze notice

Settled (user, 2026-11-19): spec "Offline freeze notice (P2.3a1)" and the Fable verdict (`verdict-fable.md`, private).

**Files:**
- Modify: `game/scripts/match/sim_pump.gd` (`_failed`, `post`, `query`, `record`); `game/scripts/match/offline_driver.gd` (`adopt`, `step`, `flush`, `record`, `notice`, `match_log`); `game/scripts/match/match_screen.gd` (`_escape_pending`); `tools/test_sim_boundary.py:102` (offline 9 → 10, with a one-line reason comment).
- Create: `game/tests/failing_pump.gd` (the `NullJobPump` of `test_sim_pump.gd:42-46`, shared; `test_sim_pump.gd` preloads it).
- Test: `test_sim_pump.gd` (`test_ph_null_job_fails_pump` :200), `test_skirmish_scene.gd` (FN1, FN2; `test_ph_refused_post_keeps_queue_and_preview` :1613).

**Interfaces (produces):**
```gdscript
# sim_pump.gd
var _failure: String = ""        # replaces _failed; first reason wins
func failure() -> String         # "" while healthy or stopped
func _fail(kind: String) -> void # "%s job returned no note after tick %d" % [kind, _current.tick]
# offline_driver.gd
const FREEZE_NOTICE := "Match stopped: game error. Please report it. Esc: leave the match."
var log_error: Callable = func(line: String) -> void: printerr(line)  # tests count calls
var _failure: String = ""        # reset in adopt()
```
- `post` refuses when `_stopped or not _failure.is_empty()`; a null note calls `_fail("post")`, a null query `_fail("query")`.
- `record()` on a failed pump skips its query, and when its own query returns null (the first failure found while filing) it fails the pump and falls back the same way: `{"tick": _current.tick, "digest": "", "match": _current.view.match, "commands": _recorder.commands().duplicate(true)}`.
- The driver's one read site is a helper `_read_failure()` that reads `pump.failure()`; when the result is new and not empty it sets `_failure` (first reason kept through `stop()` and filing) and calls `log_error` with `"SIM PUMP FAILED " + _failure` (`printerr`, never `push_error`: `tools/run_tests.sh:46` fails the suite on `ERROR:`). It runs after a refused post in `step()` (the queue is kept) and after `pump.record()` in `record()` and `match_log()`, so a failure first met while leaving still lands in `end`. `notice()` returns `FREEZE_NOTICE` while `_failure` is set. `match_log()` adds `"end": "sim pump failed: " + _failure` when failed.
- `flush()` (test-only hardening: no production caller, only `test_base_scene.gd:112,224` and `test_scene.gd:92,102`) returns before querying when `_failure` is set, and on a null note puts its commands back in the queue.
- `match_screen._escape_pending()` is false while `driver.notice() == OfflineDriver.FREEZE_NOTICE`, as it already is under `shown_over()`, so the first Esc opens the menu even with units selected or a placement armed, and the Esc chip shows (the notice promises it).
- The one new pump access is the `pump.failure()` read inside `_read_failure()`, so the pin is 10.
- Test seam: FN1 and FN2 swap the pump in place: `var pump = FailingPump.new(main.driver.pump.live())`, `main.driver.pump.stop()`, `main.driver._last = pump.start()`, `main.driver.pump = pump` (tests are not scanned, so the pin stays 10).

- [ ] **Step 1: Failing tests:**
  - **Extend `test_ph_null_job_fails_pump`:** `failure() == ""` before; after the refused post it begins with `post job returned no note after tick`; a later failure keeps it; the queried pump's begins with `query`; a healthy pump after `stop()` returns `""`; `record()` on the failed pump returns `digest == ""`, the kept commands and `tick == current().tick`.
  - **FN1 `test_freeze_notice_on_a_failed_pump`:** offline match, the failing pump swapped in by the seam above, `fail_next = true`, one physics frame → in that frame `HUD/Hud/Notice` shows `FREEZE_NOTICE` (top centre, Task 7's place); `log_error` called once, still once after three more frames; `driver.queued()` keeps a submitted move; `match_log().end == "sim pump failed: " + pump.failure()`.
  - **FN2 `test_freeze_esc_leave_reaches_the_launcher`:** as FN1 with the playtest helper on, units selected and a placement armed: one Esc opens the pause menu and the Esc chip was visible before it, Back to main menu → the stubbed `change_scene` gets the launcher path; the filed match's `end` reads `sim pump failed: ...`; no script error.
  - **FN3 `test_failure_first_met_while_leaving`:** a healthy pump with `fail_next` set just before leave (no earlier failed post) → `record()` returns the fallback (`digest == ""`), the filed `end` reads `sim pump failed: query ...`, no script error.
  - **Extend `test_ph_refused_post_keeps_queue_and_preview`** (a `stop()` from outside): `notice() == ""`, `log_error` never called.
- [ ] **Step 2:** Red; implement; `python3 tools/test_sim_boundary.py` → passes at 10.
- [ ] **Step 3: Mutation proofs** as temporary edits, then revert, recorded: drop the `failure()` read → FN1 red; revert the `record()` fallback → FN2, FN3 and the extended pump test red; drop the freeze clause in `_escape_pending` → FN2 red.
- [ ] **Step 4:** Per-task gate. Commit `Show a freeze notice when the offline pump fails`.

**Don't touch:** `online_driver.gd` (critique change 28 reads `failure()` in SB5a); the check after `drain()` (SB5a).

### Task 9: Interim slab

**Files:** `hud.gd` (slab fill, hints, armed look, columns; `place_economy` :36-37 goes); `game/scenes/skirmish.tscn` (`Economy` :30-34 anchored bottom right); `match_screen.gd` (`MENU_COLUMNS` :18 and the `place_economy` calls :300, :311 go). The key hints, the resume hint and `Place:` leave `HUD/Status`. Test: `test_hud.gd` (SL1-SL4) and the "below the status" pins of Task 2's table, N1.

**Contract:**
- `HUD/Economy` keeps its node and children paths. It anchors bottom right: x `W - 432`, 432 wide, bottom on `H`, growing up. The Hud draws its fill on the VBox's `draw` signal: `bg`, a 1 px `line` top border, a 4 px own edge in `owner_color(seat)`, padding 8 (12 on the left).
- Children, top to bottom: `Hints` (muted 12/400 lines: today's key hints from `hud.gd:59,71`, `Right-click: resume` while `resume_id != -1`, `Rows: click narrows, Shift-click removes`), `BuildMenu`, `Produce`, `CancelBuild`, `Queue`.
- Buttons are `HudButton`, 32 high (they leave Task 3's `HudSmallButton`; FS1's 12 px pin for them goes). The build button whose kind equals `placement_kind` is `HudButtonArmed`.
- `HudModel.menu_columns(font: Font, size: int) -> int`: the largest of 1 to 4 such that that many of the widest `HudModel.menu_label` over every faction's `builds`, plus button padding and 4 px gaps, fit 432 minus the slab padding.
- The slab's top (`HUD/Economy` global rect top) is what the screen hands `_playtest.set_floor()` (Task 7's height rule).

- [ ] **Step 1: Failing tests:**
  - **SL1 `test_slab_rect`:** at the four sizes, x `W - 432` within 1, width 432, bottom on `H`, inside the view, clear of the strip, chips and notice.
  - **SL2 `test_slab_china_with_overlays`** (1280x720, then the other three sizes): a China builder's menu and then a China factory with nine queued entries: every button inside the slab and the view, no label cut (containment); with the longest shipped card's checklist, the note form and F3 open, none intersects the slab, the form and F3 stay inside the view, and the last checklist item (scrolled to) and the last queue cancel button both take a click.
  - **SL3 `test_armed_button_look`:** for each faction's builder and each menu kind, arming it gives that button `HudButtonArmed` and the rest `HudButton`.
  - **SL4 `test_slab_hints`:** the hints hold `1-9: menu` and `U: unload` (H1 through `hud_text`); the resume hint while a paused site is hovered with a builder selected, gone off it (H6's text part); the rows hint.
  - Rewrites: K5, TU1, RA1, H6, M5, M6, N3 and N29 assert the slab inside the view and clear of the strip instead of "below the status"; the `_hud_texts` helper (`test_skirmish_scene.gd:738`) reads `hud_text`; N1 asserts the armed look instead of `Place: Power Plant`.
- [ ] **Step 2:** Red; implement; per-task gate. Commit `Move the button column into a bottom-right slab`.

### Task 10: Selection panel, one object

**Files:** `hud.gd`, `hud_model.gd`; `HUD/Status` loses `_selected_summary`, `_enemy_summary` and the building detail (`hud.gd:55-56,130-168`), except the collector phase: a one-line `_collection_suffix` output stays in Status for one commit, so S1 and HUD1's collector rows stay green until Task 11 replaces them. `HudModel.inspected` learns piles, so `orders.prune` keeps one (`orders.gd:71`). Test: `test_hud.gd` (SP1-SP3); E1, K4, HU1, HUD1's non-collector rows.

**Contract:**
- `HudModel.panel(view: Dictionary, selection: Dictionary, seat: int, faction: String) -> Dictionary` decides the state and its values. Order: `building_id`, then one id in `ids`, then `inspected_id`; several ids → Task 11; nothing → hidden.
- `HUD/Hud/SelectionPanel`: x 0, 408 wide, bottom on `H`, height hugs; `bg`, 1 px `line` top and right, a 4 px edge inside the left side, padding 12 top and bottom, 16 left and right, blocks 8 apart. Children: `Name` (`HudTitle`), `RightLabel` (`HudLabel`, muted), `HealthBar` (160x6, `well` track, `WorldView.health_color` fill), `Health` (`HudNumber`, muted), `Progress` (160x6 in the owner colour) with `Percent`, key-value rows (label column 112, value 13/700), `Footer` (`HudHint`).
- States and heights (spec table): one unit 62; own building 62; power plant (kind `power` above 0) 86 with `POWER +n`; factory (`Registry.can_rally(kind)`, own, completed) 84 with the footer; own site 86 (`UNDER CONSTRUCTION`, progress, `62 %`, health); own paused site (`builder_id == null`) 86 with `PAUSED · NO BUILDER` muted; enemy or allied unit or building 62; enemy or allied site 86, never paused; pile 62 (`Supply Pile`, `CREDITS LEFT`).
- Values: health `ceili(hp / 1000.0)` over `ceili(max_hp / 1000.0)` with comma thousands; percent floored as `world_view.gd:330-333`; credits left = `boxes ×` the `box_value` of the faction's unit kind that has `collects` (75 today), `Empty` at 0.
- Edge colour: `WorldView.owner_color(owner, selection.bright_owners)` for units, buildings and sites of any owner, so it matches the body with Neon on; `line` for a pile.
- An enemy or allied unit shows name and health only (no collector label); an enemy or allied site never reads `PAUSED · NO BUILDER`, also when its `builder_id` is null.

- [ ] **Step 1: Failing tests:**
  - **SP1 `test_panel_states_layout`:** for each of the fourteen cases (one unit, own building, power plant, factory, own site, own paused site, enemy unit, enemy building, enemy site, allied unit, allied building, allied site, pile, empty pile) at the four sizes: visible, x 0, width 408, bottom on `H` within 0.5, height as the table within 1, inside the view, clear of the strip, the slab and the refusal line's rectangle (centred, top `H - 204`, 28 high, 416 wide), no label cut (containment, Global Constraints). Nothing selected → hidden.
  - **SP2 `test_panel_values`:** a `china_light_vehicle` (Medium Tank, max 400000) at 179500 → `180 / 400`; `POWER +10` for `china_power_plant`; a site at 62 % → `62 %`; the paused label in `muted`, never `amber`; an enemy site with `builder_id == null` shows `UNDER CONSTRUCTION` and its percent, never the paused label; 142 boxes → `10,650`; 0 → `Empty`.
  - **SP3 `test_panel_edge_colours`:** own edge `owner_color(1)`, enemy `owner_color(2)`, an allied unit (team fixture) its slot colour, a pile the `line` token; with Neon toggled on live, the edge equals the body colour the batch draws for that unit.
  - Rewrites: E1, HU1 and HUD1's non-collector rows read the panel's `Name`, `Health` and edge; K4's kind and health part likewise.
- [ ] **Step 2:** Red; implement; per-task gate. Commit `Show one selected object in the selection panel`.

### Task 11: Selection panel: kind rows, collector labels, rebuild count

**Files:** `hud.gd`, `hud_model.gd`, `match_screen.gd` (row clicks); `HUD/Status` loses its `Units: [...]` line and Task 10's interim collector phase. Test: `test_hud.gd` (KR1-KR6, CL1, CL3, HN3, SP1's collector case); `tools/test_hud_sources.py` (CL2); S1 (`test_skirmish_scene.gd:329-335`); HUD1's collector rows.

**Contract:**
- Many: header `SelectionPanel/Header` (a Label): `N selected · K kinds` (`1 kind` for one), plus ` · n idle collector` (`collectors` above 1) when selected collectors read `IDLE`; header row 18 high. Rows `SelectionPanel/Rows/Row_<kind>` (Buttons, 186x26, two columns, 4 apart, roster order below): name `HudRow`, count right-aligned in 28 (`HudNumber`), a 3 px bar along the bottom on `well` at `sum(hp) / sum(max_hp)` in `health_color`. Heights 76, 106, 136 for 1-2, 3-4, 5-6 kinds.
- Roster order (agent call, matching the approved HUD v5 picture's `Medium Tank, Rotary Gun Tank, Militia, Anti-Tank Trooper, Supply Truck, Bulldozer`, `hud.js:44`): `HudModel.roster_key(kind)` groups combat vehicles and aircraft, then infantry, then kinds with `collects` and no `builds`, then kinds with `builds`; within a group by kind id. KR1 pins a literal order per faction.
- Row hover: `panel2` fill and `CURSOR_POINTING_HAND`. Hud `signal row_clicked(kind: String, shift: bool)`; rows read the modifier from `gui_input` (`InputEventMouseButton` left, released, `event.shift_pressed`); `pressed` is not connected. The screen narrows `orders.selected_ids` to that kind, or removes it with Shift.
- Rows hold: while the pointer is inside `SelectionPanel`'s global rect (`get_global_rect().has_point(get_global_mouse_position())`, tested on each update and on `mouse_exited`, because `mouse_exited` also fires when the pointer moves onto a child row), the row set is frozen; a kind with no units left keeps its row with count `0`, muted text, an empty bar, and its click does nothing; it reflows when the pointer is outside. The hold keeps the rows also when the selection drops to one unit, and the panel hides at zero (owner question 8, user 2026-11-19).
- `HudModel.collector_label(view: Dictionary, i: int, previous: String, faction: String) -> String` for a unit of the seat's own whose kind has `collects`, from the spec table; an enemy or allied collector gets no label. `<DROP-OFF>` is the uppercased `display_name` of the faction's building with `receives_supply` (`SUPPLY DEPOT`, FRC `SUPPLY CACHE`). Collecting is the `COLLECTING` flag; `seeking` returns `previous` (the Hud keeps the last label per id only while that id stays selected; an id that leaves the selection, and `reset()`, drop it, so a reselected collector or a restart that reuses the id starts at `""`); `idle` while collecting gives `WAITING AT PILE` when any view source has `boxes > 0`, else `IDLE`. Not collecting: status `moving` or `path_pending` → `MOVING`; named `builder_id` of an unfinished building → `BUILDING`; `CONTAINED` → `""`; else `IDLE`. The label sits in the one-unit panel's `RightLabel`, height 62.
- Rebuild on change: `rebuilds` counts structural rebuilds only (selection ids, the set of kinds, the panel state, `placement_kind`, the notice, the refusal); values patch labels and bars in place, only when they differ.

- [ ] **Step 1: Failing tests:**
  - **KR1 `test_kind_rows`:** three USA kinds → rows in the literal order the test names (not computed by `roster_key`), two columns, 186x26, header `N selected · 3 kinds`; each faction's full roster in its literal order; twelve of one kind → `12 selected · 1 kind`, one row, height 76.
  - **KR2 `test_roster_fits`:** for each of `usa`, `china` and `frc` (kinds whose id starts with the faction prefix, so `Registry.units()`'s test-only extras stay out): one unit of each, one kind at 120, two idle collectors → at the four sizes height as its kind count gives, inside the view, no label cut (containment), clear of the slab.
  - **KR3 `test_row_click_narrows_and_shift_removes`:** a left release on a row through the viewport emits `row_clicked(kind, false)` and leaves only that kind; with Shift held, `row_clicked(kind, true)` removes it.
  - **KR4 `test_rows_hold_under_the_pointer`:** pointer on a row (not empty panel area), the last unit of that kind removed (`Fixture`), published → the row stays with `0`, muted; its click changes nothing; moving across to the adjacent row keeps the hold; the selection dropping to one unit keeps the rows; pointer leaves → the row is gone and the height steps down (or the one-unit panel shows).
  - **KR5 `test_row_bar_is_the_health_sum`:** one damaged unit in a row moves the bar to `sum(hp) / sum(max_hp)`.
  - **KR6 `test_row_hover`:** a hovered row's fill is `panel2`, its cursor the pointing hand.
  - **CL1 `test_collector_label_table`:** every spec row on synthetic `ViewRows`: the ten phases, moving, path pending, building, contained, the busy-dock retry, `seeking` with and without a previous label, `seeking` after a deselect and reselect (no label); FRC reads `TO SUPPLY CACHE`; an inspected enemy collector → empty `RightLabel`.
  - **CL2 `test_every_phase_has_a_row`** (`tools/test_hud_sources.py`): every string literal on a line of `game/scripts/simulation/*.gd` that assigns `.phase` (both sides of a ternary; `production.gd:58,87` also sets `seeking`) gives exactly the ten spec phases, the set `hud_model.gd`'s label table names; a self-check proves an unknown phase on the `else` side fails.
  - **SP1's collector case:** one collector with the longest label per faction (`WAITING AT SUPPLY CACHE`, `WAITING AT SUPPLY DEPOT`) beside the longest collector name, at the four sizes, containment.
  - **CL3 `test_idle_header`:** `9 selected · 2 kinds · 1 idle collector`; two idle → `collectors`; none → no suffix.
  - **HN3 `test_rebuild_count`:** a fight fixture (`combat_fixture.gd`) over 60 ticks with an unchanged selection → `rebuilds` does not move after the first, and the panel's child instance ids are the same nodes; each selection change adds one; credit and health changes add none but update the text and the bars.
  - Rewrites: S1 reads `WAITING AT PILE` and `LOADING`; HUD1's collector rows read the label.
- [ ] **Step 2:** Red; implement; per-task gate. Commit `Show groups as kind rows and name what a collector is doing`.

### Task 12: Refusal line with today's words

**Files:** `game/scripts/match/match_screen.gd` (`refuse` :340-344, `_take_answers` :160-167, `_take_results` from Task 5, `_submit` :333-338, `_note` :302-304); `orders.gd` (the five hints); `hud.gd` (`RefusalLine`, `refuse`, `clear_refusal`; `note` and the `status` argument go); `game/scenes/skirmish.tscn` (`Status` :18-21 deleted). Test: `test_hud.gd` (RN1-RN3, RN5, RN6; HN1's `setup` call drops its `Label`), `test_skirmish_scene.gd` (RN4 beside RA1, which owns `_error_cues`; RA3 `:1414-1428` kept in both orders, its Status half read through `hud_text`), `test_base_scene.gd` Bs5 `:236-239`, `test_scene.gd` S3 `:126` and `:64,67`, HU1's `note` write, `test_skirmish_scene.gd:54`, the no-overlap lists.

**Interfaces (produces):**
```gdscript
# match_screen.gd: the one entry point for every refusal and local hint
func refuse(raw_error: String, sound: bool = true) -> void
# hud.gd
var now_msec: Callable = Time.get_ticks_msec  # tests stub it
func refuse(raw_error: String) -> void         # sets refusal, restarts the 3 s timer, shows the line
func clear_refusal() -> void
```
- Writers: an issue-time refusal (`_take_answers`), a local placement refusal (`orders.gd:143-145`), a due-time own failure (`_take_results`, with `sound = false`, because `sound_director.gd:133-136` already beeps for it), and the five local hints (`sound = false`: they are silent today, and P2.3a2's wording table decides their sound). `_submit` no longer clears the line.
- Drain precedence (spec: "the next accepted order's answer clears it"; F29 case 1 wants the refusal shown in both orders): `_take_answers` walks the drain once; when the drain holds any refusal, the last one is shown and nothing clears it; a drain with accepted answers and no refusal calls `hud.clear_refusal()`. RA3 stays green in both orders.
- One beep per drain: `_take_answers` calls `_sound.rejected` once, for the last refusal of the drain; `refuse()` from a click or hint is one call per input event. OV8's two refusals sit in two drains (two ticks), so both still beep. Due-time beeps stay in the sound director; a frame holding an issue-time and a due-time refusal still beeps twice (owner question 7, user 2026-11-19: deferred to P2.3a2).
- `HUD/Hud/RefusalLine`: `HudSlab`, centred on `W`, top `H - 204`, 28 high, padding 0 8, `Square` 8x8 amber, 8 gap, `Text` amber 13/600, width hugs, `MOUSE_FILTER_IGNORE` with its children (spec: only panels, the strip, chips and the slab stop the mouse). Hidden when `now_msec.call() - shown_at >= 3000`. `hud.refusal` keeps the raw text until replaced, cleared or reset; the timer only hides the line.

- [ ] **Step 1: Failing tests:**
  - **RN1 `test_refusal_line_place`:** a refused move at the four sizes → the line visible, centred within 1, top `H - 204`, 28 high, the 8x8 amber square, `Text.text == "Target outside map"`; then the longest command-path raw text (`Footprint covers ground unit or destination`) → width ≤ 416 at 1280, clear of the tallest panel (136) and the slab.
  - **RN2 `test_refusal_timer_and_replace`:** stubbed clock: refuse A at t → shown at t + 2999, hidden at t + 3000; refuse A at t, B at t + 2000 → B shown until t + 5000; the line expires on the stubbed clock also while ticks stall (offline menu open).
  - **RN3 `test_accepted_answer_clears`:** a refusal, then a drain with only an accepted answer → hidden and `refusal == ""`; a submit before its answer leaves the line; a drain with an accepted and a refused answer in either order keeps the refusal.
  - **RN4 `test_one_line_one_beep_per_drain`** (`test_skirmish_scene.gd`): two refused issue-time answers in one drain → the second text once, `_error_cues(main) == 1`.
  - Spec rewrites, not loosened: Bs5 `:239` submits, `tick(main)`, then `hud.refusal.is_empty()` and the line hidden ("cleared by the accepted answer"); S3 `:126` drains the accepted answer (`BaseScene.tick(main)`) before checking the line; HU1's `note` write becomes `hud.refuse("Choose one builder")` read on the line.
  - **RN5 `test_placement_refusal_after_the_click_only`:** hovering a refused spot → no line; the click → the line and the placement stays armed.
  - **RN6 `test_local_hints_on_the_line`:** placing without a builder → `Choose one builder` on the line, no sound request.
  - `test_scene.gd:64,67`: `HUD/Hud` exists with `MOUSE_FILTER_IGNORE`; `test_skirmish_scene.gd:54` drops `HUD/Status`; the no-overlap lists drop `HUD/Status` and add `HUD/Hud/RefusalLine`.
- [ ] **Step 2:** Red; implement; `rg -n 'HUD/Status|hud\.note' game` → only the benchmark's and the art lab's own labels (`movement_benchmark.gd`, `movement_benchmark.tscn`, `test_benchmark.gd:84`, `art_lab.gd:38`, `art_lab.tscn`, `lab_capture.gd:75`). Per-task gate. Commit `Show refusals on the amber line above the bottom edge`.

**Don't touch:** the wording, the `Rejected: ` prefix on any log (none exists yet; the raw list is P2.3a2's), sound files.

### Task 13: Click resolver and HUD mouse routing

**Files:** `game/scripts/presentation/world_view.gd` (`resolve_pick`; `pick_entities` :621-629 gains a filter); `game/scripts/match/orders.gd` (`_hover` :108-113, `_building_input` :168-178, `_finish_selection` :221-246; `_enemy_at` :398-402 goes); `game/scripts/match/match_screen.gd` (`_input` :194-205 forwards a drag, hover cleared on HUD entry); `game/scripts/match/hud.gd` (mouse filters, `pointer_entered`, `blocking_rects`); `game/scripts/playtest/playtest_overlay.gd` (the chip and checklist stop the mouse and the wheel). Test: `game/tests/test_view.gd` (PK1), `test_skirmish_scene.gd` (PK2-PK4, MR1-MR3), `test_scene.gd:67`.

**Interfaces (produces):**
```gdscript
# world_view.gd
func resolve_pick(plane_point: Vector2) -> Dictionary  # {"tier": "unit" | "building" | "pile" | "ground", "id": int}; ground id -1
func pick_entities(plane_rect: Rect2, blocked: Array[Rect2] = []) -> Array[int]  # skips anchors under a blocked screen rect
# hud.gd
signal pointer_entered()
func blocking_rects() -> Array[Rect2]  # global rects of the visible slabs, panel, strip and chips (never Notice or RefusalLine)
```
- `pick_entities` maps each anchor to the screen with `get_global_transform_with_canvas() * point` before the `Rect2` test, so it holds under camera pan and zoom; the one-argument callers (`orders.gd:253`, `selection_lab.gd:210,234`) keep compiling through the default.
- Order: tier first (units, buildings, piles, ground), then `local_player`'s before others, then front-most by `WorldBatch.sort_key(WorldBatch.kind_info(kind)[1], anchor, id)`, so an aircraft beats the ground unit under it. Units: not `HOLE`, not `CONTAINED`, `_pick_bounds` hit, any owner. Buildings and piles: their ground footprint, as `pick_object` (`world_view.gd:638-653`).
- Left release without a drag: own unit → select (Shift toggles it); other owner's unit, building or site, or any pile → `inspected_id`; own building → `selected_building_id`, clearing units, also with Shift; ground → deselect (Shift keeps the selection, as today). Double-click and Alt keep their own-kind rules. Hover sets the same id (ground → -1).
- Right-click context orders keep `pick_object` (`orders.gd:167`) until Order controls; V3, V13, V15 and TU1's `pick_object` checks stay.
- The Hud root stays `IGNORE`; `TopStrip`, `MenuChip`, `SelectionPanel` and `HUD/Economy` use `MOUSE_FILTER_STOP` (spec: panels, the strip, chips and the slab); `Notice` and `RefusalLine` stay `IGNORE`, so a click on a unit under a fresh refusal still lands. Blocking surfaces, the Playtest chip and the checklist set `mouse_force_pass_scroll_events = false`, so the wheel over them does not zoom the map (the checklist still scrolls itself). Each blocking surface emits `pointer_entered` on `mouse_entered`; the screen then calls `_view.set_hovered(-1)`.
- While `orders.is_selecting()`, `match_screen._input` hands mouse motion and the left release to `orders.handle` and marks them handled, so a drag over a panel keeps its box and its release. In that forwarded path `_hover` sets -1 while the pointer is inside a `blocking_rects()` rect, and a release under the 6 px drag threshold inside a blocking rect is dropped (no click). `_finish_selection` passes `hud.blocking_rects()` to `pick_entities`.

- [ ] **Step 1: Failing tests:**
  - **PK1 `test_resolve_pick_table`** (`test_view.gd`): own unit; enemy unit; allied unit; an own unit overlapping an enemy unit drawn in front of it → own; an own aircraft over an own ground unit → aircraft; a unit on a building footprint → unit; building; pile; ground → `{"ground", -1}`; a unit inside a hub → the hub.
  - **PK2 `test_hover_equals_click`:** at each PK1 point, the hovered id after a motion equals the id the click selects or inspects.
  - **PK3 `test_click_results`:** own unit selects; enemy unit inspects and clears the own selection (E1's rule); own building selects and clears units; enemy site inspects; pile inspects and stays inspected over three refreshes; ground deselects; a drag over a pile selects no pile.
  - **PK4 `test_shift_toggles_on_the_map`:** Shift-click on an unselected own unit adds, on a selected one removes; Shift-drag adds; Shift-click on an own building with units selected leaves the building only.
  - **MR1 `test_hud_blocks_the_map`:** events through `main.get_viewport().push_input(...)`, at `[1280x720, 1280x720]`, `[1920x1080, 1280x720]` and `[3440x1440, 1720x720]`: a click on the strip, the panel, the slab, the Menu chip, the Playtest chip (it toggles the checklist) and the open checklist changes no selection and sends no command; a click on open ground beside them deselects; with a refusal line shown, a right-click on ground under it sends a move and a left click there deselects; the wheel over the slab and the checklist leaves the camera zoom unchanged, over open ground it zooms. `test_scene.gd:67` becomes "panels stop clicks, the rest passes".
  - **MR2 `test_entering_the_hud_clears_hover`:** hover a unit, move onto the panel → hovered id -1; a unit just under the slab's edge is not hovered while the pointer is on the slab.
  - **MR3 `test_drag_across_a_panel`:** press on the map, move over the panel, release there → the box followed, the selection applied, units whose anchor is under the panel not picked; the same with the camera panned and zoomed to 2; a press on the map just outside the panel and a release inside it within 6 px selects nothing.
- [ ] **Step 2:** Red; implement; per-task gate. Commit `Pick clicks and hover through one resolver and let the HUD block the map`.

**Don't touch:** right-click orders, the drag tier rule (today's all-units rule stays), marks.

### Task 14: `view_player`

**Files:** `game/scripts/match/match_screen.gd` (`var view_player: int`, set in `setup` :60-62, in `_ready` offline, in `_restart_world`; `_local_state` :360-363 splits into `_view_state(state)` for the strip and `_seat_state(state)` for faction; `:99` and `:134`); `world_view.gd` (`var view_player: int = 1`; order marks `:375`, crate marks `:389`, rally flag `:556`); the Hud gets `view_player` for every display read (strip, swatch, credits left's faction, collector drop-off). Picks, orders, the seat, `_production_kind`, the build menu's faction and sound keep `local_player` (survey table). Test: `test_skirmish_scene.gd` and `test_online_scene.gd` (VP1, VP2).

- [ ] **Step 1: Failing tests:**
  - **VP1 `test_view_player_after_the_online_seat`:** a seat-2 join with credits and a start that differ from seat 1 → `view_player == 2`, the strip shows seat 2's credits, the camera starts on seat 2's start; after a rematch still 2.
  - **VP2 `test_view_player_changes_display_reads_only`:** offline, destination marks on (`order_marks()` returns nothing otherwise), both seats with a distinguishable order, `view_player = 2`, refresh → the strip shows player 2's credits and swatch, `order_marks()` shows player 2's ordered units and not player 1's; `resolve_pick` still puts player 1's units first, commands carry player 1, the build menu uses player 1's faction.
- [ ] **Step 2:** Red; implement; per-task gate. Commit `Add view_player beside local_player for display reads`.

### Task 15: Palette A on the bodies (own commit)

**Files:** `game/scripts/presentation/palette.gd` (`OWNER_BASE` :3-6 becomes palette A, `owner_colors` :28-34 uses the palette A sides for owners 1 to 8); `game/scripts/lab/lab_look.gd` (`PALETTE_A`, `SIDE_A`, `SIDE_DARK_A` :21-26 go; `owner_colors_a` goes); its other readers repoint to `Palette`: `lab_marks.gd:77` and `lab_panel.gd:224` read `Palette.OWNER_BASE`. The lab's palette A/off toggle goes (owner question 3, user 2026-11-19, because both branches now draw the same colours): in `lab_view.gd:5-42` the `LabBatch` class (its `_mesh_colors` override and `shortcut:` line), the `_batch = LabBatch.new()` in `_init`, `_palette_a`, `set_palette_a` and the `_tint` override; the calls `selection_lab.gd:87,149`. Test: `test_world_batch.gd` WB18 `GOLDEN_COLORS`; SH15 `test_shapes.gd:202-206`; LB2 `test_selection_lab.gd:48-59` (reads `Palette.owner_colors` instead of `owner_colors_a`, same expectations); LB5 `test_selection_lab.gd:95-112` (its toggle lines go) and LB17 `:456,:464` (its `palette_a` parts go); PA1, PA2 in `test_hud.gd`.

**Contract:** for owners 1 to 8, `owner_colors(owner)` is `[A, A.darkened(0.25), Color("1c2e39"), Color("0e1b23"), MACHINE, SMOKE, A, SKIN]` with A = `628ffa, d6120c, 4ad49b, f8e425, 0e92a7, 7242fe, ec8600, f79cef` (`lab_look.gd:21-26`, the look judged in the lab). Owner 0 and the fallback keep `SIDE` `3d515f` and `SIDE_DARK` `263842`. `OWNER_BRIGHT` (Neon) is unchanged until P2.4; with `bright`, slot 0 (and slot 6) swap to `OWNER_BRIGHT` and the sides stay the palette A sides. The HUD reads the same `bright` flag (Task 5's `selection.bright_owners`), so the panel edge matches the body with Neon on too.

- [ ] **Step 1:** Change the palette. Run `WARGRID_TEST_ONLY=test_world_batch` and read the printed `GOLDEN` line: only the colour digest may differ; every `GOLDEN_SHAPES` row must still match. Re-pin `GOLDEN_COLORS`.
- [ ] **Step 2:** SH15 asserts the palette A sides for owners 1 to 8 and today's for owner 0, machinery `8098a5` for all. LB5 asserts a plain `WorldView` draws `628ffa` and no longer `376eac`; its toggle lines and LB17's `palette_a` parts go with the toggle. **PA1 `test_owner_colours_contrast`:** each of the eight owner colours is at least 3:1 against `bg` (WCAG 2.x). **PA2 `test_panel_edge_is_the_body_colour`:** the panel edge of an owner-1 and an owner-2 unit equals the colour the batch draws for that body, with Neon off and after a live Neon toggle.
- [ ] **Step 3:** Per-task gate. `git diff --stat HEAD` lists only `palette.gd`, `lab_look.gd`, `lab_marks.gd`, `lab_view.gd`, `lab_panel.gd`, `selection_lab.gd`, `test_world_batch.gd`, `test_shapes.gd`, `test_selection_lab.gd`, `test_hud.gd`. Commit `Draw the bodies in palette A`.

**Don't touch:** Neon, shapes, `shows_health`, any other test's expectations.

### Task 16: Benchmark `--hud` rows

**Files:** `game/scripts/debug/movement_benchmark.gd` (flag, layout, workload, HUD, assertions, header, marker; `_layouts_to_run` :86 becomes `_layouts_from(args: Array)` and the flag `_hud_from(args: Array)`, as `_report_only_from` :275 already takes its args; `_sequence` :30 and a `_hud_mode` field read them from `OS.get_cmdline_user_args()`); `game/scripts/presentation/world_view.gd` (`drawn_selection_lines: int`, set where `_draw` submits the selection lines, before destination marks join them); `tools/perf_record.py` (`MARKERS` :32-38, `parse_log` :95-127); `tools/test_perf_charts.py`; `game/tests/test_benchmark.gd`.

**Contract:**
- `-- --hud` runs only `hud_select`; it is not in `_report_only_from`. Until stop gate B sets `DRAW_CALL_CEILINGS["hud_select"]`, `_report_draw_calls` would fail it with `No draw-call ceiling for layout hud_select` (BM12 pins that), so a plain `--hud` run is only possible in the report-only scratch form until then; BH1's "not report-only" checks the flag logic, not a full run.
- `hud_select`: `Workload.create("open")` plus `add_player(1, 10000)` so the strip has data; ids = the first 120 owner-1 unit ids. A `Hud` node under `$HUD` beside the benchmark's own `Status` (BM4 `test_benchmark.gd:84` stays), `setup(null)` (Task 12's one-argument form). Inside the timed `_physics_process` (`:151-180`): `_view.set_view(state, ids)` and `_hud.update_hud(state, {"ids": ids, "building_id": -1, "inspected_id": -1, "placement_kind": "", "resume_id": -1, "notice": "", "production_kind": "", "bright_owners": false, "esc_opens_menu": false}, 1, 1)`.
- Mechanics, checked each sampled tick after `elapsed` is taken (outside the timed span): `SelectionPanel/Header.text` begins with `120 selected` and `_view.drawn_selection_lines == 120 * 8` from the last drawn frame, else `_fail`; at least one sampled frame was drawn. The match must stay unstarted (`state.match` null) or the run fails.
- Header adds `window=<W>x<H>` from `DisplayServer.window_get_size()`. The expected size comes from a benchmark user arg, `-- --hud --expect-window=2560x1080` (Godot drops engine flags such as `--resolution` from `OS.get_cmdline_args()`), default 1280x720; with `--hud` the run fails when the two differ, in either direction.
- Lines: `RENDERED SAMPLE hud_select_<W>x<H> ...` (only `hud_select` appends the size; every other line keeps `_layout_name()`), `DRAW_CALLS hud_select ...`, `RENDERED COMPLETE hud_select ...`, then `RENDERED HUD PASSED <W>x<H>`; a report-only run prints `RENDERED HUD CALIBRATION <W>x<H>` instead, never `PASSED`.
- `DRAW_CALL_CEILINGS["hud_select"]` is added at stop gate B from the scratch measurement and never raised.
- `perf_record.py`: `RENDERED SAMPLE` scenarios starting `hud_` form a family `rendered_hud` whose marker is `RENDERED HUD PASSED <size>` with the scenario's size; a `CALIBRATION` log is refused; standard rows keep `RENDERED BENCHMARK PASSED 4`. Rows go to `perf-history.csv` and the ledger's history only; `perf_chart.py`'s lines take `open`, `dense` and `ashfall` (`:71-72`), so the README chart is unchanged.

- [ ] **Step 1: Failing tests:**
  - **BH1 `test_hud_flag_runs_one_layout`** (`test_benchmark.gd`): `_layouts_from(["--hud"]) == ["hud_select"]`, `_hud_from(["--hud"])` is true and `_report_only_from(["--hud"])` false; without the flag the four standard layouts.
  - **BH2 `test_hud_layout_in_the_window`:** a headless instance with `_hud_mode` and `_sequence = ["hud_select"]` set before `add_child`, stepped through a few ticks with a forced sample start: `SelectionPanel/Header` begins `120 selected`, `drawn_selection_lines` is 960 after a drawn frame, the `update_hud` call sits inside the timed tick; with the selection submission disabled the guard fails.
  - **BH3 `test_window_mismatch_fails`:** expected 2560x1080, actual 1280x720 → the failure line names both; expected 1280x720, actual 2560x1080 → fails too.
  - **`tools/test_perf_charts.py`:** a log with `RENDERED SAMPLE hud_select_2560x1080` and `RENDERED HUD PASSED 2560x1080` gives `frame_interval` and `tick_frame` samples for `hud_select_2560x1080`; the same log with `PASSED 1280x720` raises `missing marker`; with `RENDERED HUD CALIBRATION 2560x1080` it is refused; the four-layout log is unchanged.
- [ ] **Step 2:** Red; implement; `sh tools/run_python_checks.sh > build/py.log 2>&1; echo exit=$?` → 0; per-task gate. Commit `Add the HUD rows to the rendered benchmark`.

### Task 17: Focus card and docs

**Files:**
- `game/data/playtest/focus.json` (a new first card), `game/tests/test_playtest.gd` (`SHIPPED` :12; prepending shifts `SHIPPED[2]` and `SHIPPED[4]`, used at `:274, :279, :602, :629-630, :657, :666`: still valid, now other cards) and `game/tests/test_launcher.gd` L15b (`:517` pins the first card's title literal: it becomes `See your selection`). Card (agent wording after the player-experience review; it asks nothing about marks):

  ```json
  {"id": "p2.3a1-see-your-selection", "title": "See your selection", "new": ["Credits and power sit on the top edge; while you place a building they show the values after it.", "Select something and a panel at the bottom left shows it: one unit, a group by kind, a building, a site, a supply pile or an enemy.", "A refused order shows the game's reason on an amber line above the bottom edge (still in the game's own words; plainer words come next)."], "try": [{"id": "group", "text": "Select a mixed group, Shift-click a kind row to drop that kind, then click another row to keep only it"}, {"id": "enemy", "text": "Click an enemy unit and a supply pile"}, {"id": "forecast", "text": "Pick a building you cannot afford from the build menu, read the top strip, then try to place it"}], "questions": [{"id": "found_it", "text": "I could always tell what I had selected"}, {"id": "picked", "text": "Clicking picked the unit, building or pile I meant"}, {"id": "hud_clicks", "text": "The HUD never swallowed a click I meant for the battlefield"}, {"id": "numbers", "text": "Credits, power and health were easy to read"}, {"id": "wide", "text": "On a wide or 16:10 screen, the game filled it well"}]}
  ```
- Guide, each with its `Checked against` footer: `docs/guide/01-big-picture.md` (the match screen's HUD object), `05-presentation.md` (HUD node and input, stretch and window, the playtest helper's place, palette A as built, the file list at `:244` without `ui_style.gd`, the freeze notice), `12-performance-and-platforms.md` (HUD rows, the wider view), `13-testing-and-tooling.md` (`hud_text()`, id-based layout tests at the size pairs, resolver and routing tests, `--hud`, `tools/test_hud_sources.py`; the offline pin 10 with its reason at `:105`, `failure()` in the pump tests passage `:79-81`, FN1 to FN3).
- `docs/reference/sim-interface.md` (`:61`, the pump API): `failure() -> String` beside `post`, `query` and `record`.
- `docs/packages.md`: the P2.3a row becomes P2.3a1 See your selection, P2.3a2 Know why an order failed, P2.3a3 Read the battlefield (spec "Packages"); P2.3a1 implemented with plan and verification links; the stale clause "Before the camera package, so edge scrolling is built against the dock" goes; the note dialog's "place not decided" reads "under the Playtest chip"; the Now bullet (`:11`), the package note (`:96`), P2.5's "Needs P2.3a" (→ P2.3a1) and night 8's placement (`:54`, "between P2.3a and P7" → "the first free night gap after P2.3a1", user 2026-11-19) follow. `docs/STATUS.md`: the three package rows; F25 gets "`expand` draws more map with no culling: measured in the wide HUD row at gate B (pending)"; gate B replaces "pending" with the measured frame interval and CPU tick times (the benchmark does not isolate GPU fill), or with the owner's call when the wide row is waived. Then `python3 tools/roadmap.py` (names per `docs/roadmap-wording.md`).
- `docs/reference/hud-v5-layout.md`: the pile row (62 px, `CREDITS LEFT`; "redrawn with the P2.3a design" → "redrawn in P2.3a1's first task"), the places this plan adds (swatch, chip stack, notice, interim slab, refusal-line rules), the collector label, the forecast forms, the Menu bullet's Esc rule, the `expand` reading now tested (`:9`), the note dialog drawn.
- `docs/reference/map-art-shapes.md` P2.3a section (`:24-68`): palette A in `palette.gd` since P2.3a1; the `.` key cap handed to P2.3b; palette A green against `ally` moved to P3; the carried mark sizes decided (2026-11-19), the reticle and the bar step left to P2.3a3.
- `docs/development.md`: Start here entries for P2.2, P12, Sim boundary, the A/B lab and P2.3a (design, this plan, the verification file); the line that describes a rejected order's HUD message (`rg -n 'HUD message' docs/development.md`) names the amber line.
- `docs/superpowers/specs/2026-11-15-sim-boundary-design.md`: `failure()` in the pump API block ("Ownership and API", `:70-121`); the "SB5a inherits" list (`:212`) gains: every terminal cause (null result, owner-thread check, fault flag, stall, dead thread) writes the same main-side reason, never read across threads; queue-full and stopped keep `failure()` empty; the offline driver also checks after `drain()`; the online driver reads `failure()` for critique change 28 instead of treating every refused post as terminal (`online_driver.gd:121-122`).
- `docs/reference/p2.3a1-verification.md`: the resume record.

- [ ] **Step 1:** Card, `SHIPPED`, L15b; `WARGRID_TEST_ONLY=test_playtest` and `WARGRID_TEST_ONLY=test_launcher` → 0. Docs in the guide's style (payoff first, terms explained where they appear). `python3 tools/roadmap.py`, `sh tools/check_public.sh` → 0.
- [ ] **Step 2:** `sh tools/run_checks.sh > build/checks.log 2>&1; echo exit=$?` → 0; full suite; the empty `git diff`. Record each with its tree.
- [ ] **Step 3:** Commit `Document P2.3a1 and split the P2.3a row`.

## Model routing

- **Implementers:** Opus for the UI and HUD tasks (1, 3-7, 9-13; memory "UI/UX quality first"), Sonnet for 2, 8, 14, 15, 16, 17. The main session coordinates on Opus.
- **Per code task:** one fresh Opus (high) reviewer ([coordinator rules](../../night-run.md#coordinator-rules); no Codex per task, user 2026-11-19) with the diff, the task text and the file paths, asked to name for each new test the production change that turns it red. Findings are checked against the source and fixed test-first before the commit. UI and player-facing diffs (3, 4, 6-15) also get the [player-experience reviewer](../../../.claude/agents/player-experience-reviewer.md). Task 1 gets the player-experience reviewer only. Task 17: a fresh Opus (high) reviewer, and the player-experience reviewer on the card.
- **Gate, in this order:** (1) Grok 4.7 high plus an Opus whole-branch pass (Opus alone if Grok is missing), whose brief asks about cap writes inside `size_changed`, input that reaches the map through the HUD, and the leave path on a failed pump; beside it, the player-experience reviewer on the whole UI diff; (2) `/ponytail-review` (Sonnet) on the branch diff and its cuts; (3) the suite and `sh tools/run_checks.sh` on that tree; (4) stop gate B on that same tree; (5) stop gate C. A change after gate B that touches `game/scripts/presentation/`, `game/scripts/match/` or the benchmark reruns gate B's benchmark steps.
- Post the Task/What/Status table on every task state change.

## Stop conditions (park, record why, stop)

- A simulation, net, relay or protocol diff; a pinned digest or trace change; a `view_state()` field.
- The root-window probe shows a `size_changed` loop (Task 4).
- An assertion would have to be weakened, or a budget or ceiling exceeded (report, never loosen); `PAIR GATE FAILED` or `PAIR GATE INCONCLUSIVE`.
- A design contract would have to change (for example a spec height that cannot hold).
- A step needs a push, merge, deploy, `run_game.sh` or a visible window outside a stop gate.
- The resume record disagrees with the tree.

## Stop gates (not tasks)

- **A. State pictures** (Task 1): one owner look before Task 3.
- **B. Window batch** (after Task 17 and gate steps 1 to 3; one request; the owner present): first `uptime`. Benchmark runs need a host without another heavy job: another Claude session or the Codex app made an A/A pair gate go red at 1.03 on 2026-11-19; say so when asking. Then, in one sitting:
  1. Scratch (report only, `-- --hud --quality=high`, prints `RENDERED HUD CALIBRATION`, never recorded) at 1280x720 and `--resolution 2560x1080 ... -- --hud --quality=high --expect-window=2560x1080`: set `DRAW_CALL_CEILINGS["hud_select"]` per owner question 2, commit `Set the HUD layout draw-call ceiling`.
  2. `PERF_LABEL="P2.3a1" sh tools/run_benchmark.sh > build/bench.log 2>&1; echo exit=$?` (headless, with the pair gate at `MAX_RATIO` p95 1.020, p99 1.025, `tools/perf_pairs.py:17`).
  3. The rendered rerun `sh tools/run_game.sh res://scenes/movement_benchmark.tscn > build/rendered.log 2>&1` (four layouts), then `sh tools/run_game.sh res://scenes/movement_benchmark.tscn -- --hud > build/hud-720.log 2>&1` and `sh tools/run_game.sh --resolution 2560x1080 res://scenes/movement_benchmark.tscn -- --hud --expect-window=2560x1080 > build/hud-wide.log 2>&1`.
  4. `python3 tools/perf_record.py <log> --label "P2.3a1"` for each of the three logs, then `python3 tools/perf_chart.py`; `run_benchmark.sh` exits 0 even after a recording failure, so check `docs/reference/perf-history.csv` for the expected new rows (the headless rows, the four rendered layouts, `hud_select_1280x720` and `hud_select_2560x1080` with both metrics); a ledger history row in `docs/reference/performance.md` with both metrics for both HUD rows, time reported against the rendered 3.04 ms budget, never enforced. Report separately: hard failures (pair gate, draw-call ceilings), report-only HUD time, rows accepted as exceeded, and any `CEILING ALARM`; `uptime` at start and end.
  5. The real-window checks headless tests cannot make: drag the window across the 2.4:1 cap and back during a match (no 1 px bars, HUD anchors follow), then Back to the menu from a capped match (launcher plain `expand`).

  A missing or clamped 2560x1080 run (the `window=` check fails) leaves the gate pending for the owner: another host, an offscreen run labelled as such, or accepting it without the row. No fallback is swapped in silently.
- **C. Final gate:** gate steps 1 to 4 done on the final tree (Model routing, Gate); CI on Linux and Windows after the owner approves a branch push, plus `sh tools/compare_local_traces.sh <run id>`; the owner's playtest on the card. Push, merge (`git merge --squash`, tag `<branch>-tip` first) and release each wait for the owner. After the merge, `sh tools/run_benchmark.sh` on `main` (load rule) and the owed rendered rerun.

## Owner window batch (implementation round, not agent work)

- The Steam Deck session: numbers at 13/700 against 14/700; the uppercase 12 px labels raised to 13 only if they read poorly; the match-bench pair with the HUD off against on (low-end report §8.7, private).
- The P2.3a1 state pictures look (gate A).
- Carried from 2026-11-14: the Mac Firefox Web Render Bench row, the README screenshot and fight clip, one uncovered gated Ashfall run.

## Owner questions (answered: (a) for all eight, user, 2026-11-19; [design answers](../../reference/design-answers-2026-11-08.md#p23a1-plan-questions-user-2026-11-19))

1. **Launcher theme snap in Task 3.** The rule is "spacing snapped where a file is touched; square corners in the match, at most 2 px in the launcher" (design answers, 2026-11-15); the launcher theme has 5 px radii, a 9 px focus ring (L30 pins "button's 5 plus 4") and paddings of 15, 14, 13 and 10. Options: (a) snap the whole theme file now (radii 2, the focus ring 2 as well, paddings on the scale), `launcher.gd`, `launcher.tscn` and `result_panel.gd` only where edited; (b) only the type sizes now, corners and paddings with "One look from menu to match"; (c) also snap every value in `launcher.tscn`. Zero Hour: not applicable. Recommendation: (a), the decided rule applied to the file P2.3a1 rewrites, with the launcher layout tests as the check.
2. **HUD draw-call ceiling.** The spec sets it "from one scratch-window measurement". Options: (a) 1.5 times the higher of the two scratch maxima, rounded up to a multiple of 10; (b) 50, as `open`; (c) the scratch maximum plus 10. Zero Hour: not applicable. Recommendation: (a): tight enough to catch a batching regression, loose enough for text shaping between runs.
3. **The lab's palette A/off toggle after Task 15.** Once palette A is `Palette.OWNER_BASE`, both lab branches draw the same colours. Options: (a) delete the toggle and its test parts (LB5's toggle lines, LB17's `palette_a`); (b) keep a lab-local copy of today's palette so the toggle compares A with the old colours; (c) keep the toggle as a no-op. Zero Hour: not applicable. Recommendation: (a): the comparison was judged, and a kept toggle tests nothing.
4. **Size of the match surfaces that lose the 12 px HUD theme** (pause menu, playtest checklist and note form, F3 overlay, focus card, the slab buttons until Task 9). Options: (a) keep 12 px and today's control styles through `HudSmall*` variations; (b) 13 px; (c) the theme default 16 px and the launcher's control styles, layout re-checked. Zero Hour: not comparable (bitmap-font menus). Recommendation: (a): P2.3a1 does not design these surfaces, and P2.3a2 redraws the Esc menu.
5. **Right edge at 1280x720:** the checklist and note form drop from the top right and the interim slab grows from the bottom right; with a China factory's nine-entry queue they meet (code arithmetic, not rendered). Options: (a) cap the checklist's height to the space above the slab (it already scrolls) and open the note form to the left of the checklist when there is no room below; (b) let the note form sit over the slab (it already pauses an offline match), cap only the checklist; (c) no rule. Zero Hour: no playtest panel. Recommendation: (a): the helper never covers a usable button (F22's spirit), a small change to `_fit`; gate A's worst-case picture shows it.
6. **FRC's power group in the strip.** FRC has no kind with non-zero `power` (`frc.gd`). Options: (a) hide the POWER group for a faction with no power kinds (read from the definitions); (b) show `POWER 0 / 0`; (c) a muted `NO POWER`. Zero Hour: the power window exists in the shared control bar (`ControlBar.cpp:1227` @ `0a05454`); GLA's scheme keeps the power bar's rectangle (`data\ini\controlbarscheme.ini:205-206`, GLA8x6), so GLA shows an empty bar. Recommendation: (a): a permanent `0 / 0`, and `0 / 0 → 0 / 0` while placing, reads like a bug.
7. **One beep per frame across issue-time and due-time refusals.** The plan gives one beep per drain for issue-time answers; a due-time failure still beeps through the sound director, so a frame with both, or two due-time failures, beeps twice. Options: (a) defer the due-time part to P2.3a2, which reworks order sounds (F29) with the sound docs read, and record the rule as partly met; (b) a narrow `sound_director.gd` change in P2.3a1 (breaks the plan's no-sound-code rule). Zero Hour: not checked. Recommendation: (a).
8. **A hovered group that shrinks.** When the selection drops to one unit while the pointer is on the kind rows: (a) keep the rows until the pointer leaves, hide the panel at zero selected; (b) switch to the one-unit panel at once, hide at zero. Zero Hour: n/a. Recommendation: (a): the hold rule exists so the panel never reflows under the pointer (user, 2026-11-19), and the spec hides the panel when nothing is selected.

## Agent's calls

1. Pictures at a 1280x720 layout, 2560x1440 (the first gate size); the existing HUD v5 pictures stay at 1280x800. Each picture is a whole-screen composite.
2. Only Task 2 runs while gate A waits.
3. `HUD/Economy` stays a sibling of the `Hud` node, handed in by `setup`, so its paths hold; the benchmark passes `null`.
4. The refusal state lives on the `Hud` node (`hud.refusal`, `hud.refuse()`), not in `selection` as the spec lists it, because the moved tests read it there.
5. `refuse()` in P2.3a1 takes `(raw_error, sound)`, not the spec's `(raw_error, command)`: the command is unused until P2.3a2's table. `resolve_pick` takes no modifiers for the same reason.
6. Due-time refusals keep their beep in the sound director; local hints stay silent (P2.3a2's table decides their sound); P2.3a1 changes no sound code, but issue-time refusals now beep once per drain instead of once per answer.
7. The Playtest chip toggles the checklist on a click, as the backquote key does; `n / m` counts ticked checklist items.
8. Owner 0's neutral sides keep today's colours, as the lab's palette A look did.
9. Theme tokens are theme colours only (type `Tokens`); owner colours come from `WorldView.owner_color(owner, bright)`.
10. Credits left and the drop-off name read the viewer's faction; a building is a "factory" when `Registry.can_rally(kind)`.
11. The rows hold rule freezes the row set while the pointer is inside the panel's rect; a 0-count row's click is a no-op.
12. Roster order: combat vehicles and aircraft, infantry, collectors, builders, then kind id (the approved HUD v5 picture's order).
13. A drain's last refusal wins over its accepted answers; only a drain without refusals clears the line (the spec's "next accepted order" plus F29 case 1).
14. The focus card title's local 28 px snaps to 30, the result panel's 15 px to 16.
15. On the freeze notice, the first Esc opens the menu even with a selection (the notice promises Esc).

## Deferred (from the plan review)

- One beep per frame for due-time refusals (mixed with issue-time, or two due-time): P2.3a2 with F29 (owner question 7); the verification file records the rule as partly met.
- The F25 GPU-fill reading: the benchmark measures frame interval and CPU tick time only; a GPU split is not planned.

## Where the spec meets the code (followed the code)

- SH15 is `test_shapes.gd:202-206`, not `test_world_batch.gd`; LB5 (`test_selection_lab.gd:95-112`) also breaks when palette A moves into `palette.gd`.
- IC2 (`input_script_rows.gd:27`, used at `test_online_scene.gd:1521`) carries the Status text too.
- More pins assume "buttons below the status": H6, M5, M6, RA1, N3, N29, beside K5 and TU1.
- `launcher.tscn:15` is a seventh theme assignment, and T1 reads `launcher.theme`.
- The launcher's `_exit_tree` (`launcher.gd:60-61`) runs after the match has entered (`:536-538`); it must go, or it undoes the match's caps.
- Due-time refusals already beep through `sound_director.gd:133-136`; a beeping `refuse()` there would beep twice.
- Today `_submit` clears the line (`match_screen.gd:336`); the spec's rule is "the next accepted answer clears it", so the submit clear goes.
- Right-click context orders use `pick_object` (`orders.gd:167`); only hover and the left click move to the resolver.
- PO8's disjoint check is at `test_playtest_overlay.gd:326` (spec: `:319`).
- No refusal log exists yet, so "the `Rejected: ` prefix stays in logs" has nothing to keep in P2.3a1.
- The spec's benchmark `window=` check names the requested size; Godot drops engine flags such as `--resolution` from `OS.get_cmdline_args()` (Godot `doc/classes/OS.xml`), so the request travels as `--expect-window`.
- The CI suite runs as an exported binary, so the spec's source-scan tests (HN1's half, CL2) are Python checks.
- `mouse_exited` fires when the pointer moves onto a child row (probe at Godot 4.7.2 by the plan review), so "while the pointer is over the panel" is a rect test.
- Palette A has three more lab readers (`lab_marks.gd:77`, `lab_view.gd`, `lab_panel.gd:224`) and the lab's A/off toggle (owner question 3).
- RA3 (`test_skirmish_scene.gd:1414-1428`) pins that an accepted result in the same drain keeps the refusal, in both orders; Bs5 `:239` and S3 `:126` pin today's clear at submit. The drain precedence keeps RA3 and rewrites the two clear pins (agent's call 13).

## Self-review notes

- **Spec coverage:** the coverage table maps every P2.3a1 Goal, test and gate item to a task; Docs items assigned to P2.3a2 or P2.3a3 (guide 04 and 11, `playing-online.md`, ART_DIRECTION, `blueprint.md:672`) are left out on purpose.
- **Type consistency:** `update_hud(view, selection, view_player, seat)` in Tasks 5, 14 and 16; the `selection` keys of Task 5 (with `production_kind` and `bright_owners`) plus `esc_opens_menu` (Task 7) in Task 16's call; `SelectionPanel/Header` in Tasks 11 and 16; `hud.refusal` in Tasks 2, 12; `refuse(raw_error, sound)` in Task 12; `resolve_pick(plane_point)` and `pick_entities(rect, blocked)` in Task 13; `failure()` in Task 8 and the docs; `HudModel` names in Tasks 5, 6, 9, 10, 11.
- **Proportion:** contracts, test names and assertions; no bodies except the freeze-notice members the settled mechanism fixes.
