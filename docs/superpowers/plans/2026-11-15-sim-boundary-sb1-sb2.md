# Sim boundary SB1 and SB2: Implementation Plan

**Status:** draft for the owner's review (2026-11-15), revised after two independent reviews and eight owner answers the same day. Nothing here starts implementation; the night run starts only after P2.2 is merged to `main` and the owner starts it.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md): one fresh subagent per task, each starting from the resume record in `docs/reference/sim-boundary-verification.md`.

**Goal:** Match and presentation code stop reading the live simulation per input event (SB1 "Reads on request"), and offline answers to orders and to the placement preview arrive with the next tick through one answer path shared with online (SB2 "Answers one tick later"), with digests, traces and netplay pins unchanged.

**Architecture:** The match screen keeps the view it last showed (`shown_state`); input reads that view instead of `snapshot()` and repaints it instead of building a new `view_state()`. The offline driver stamps sequences from its own counter. In SB2 both drivers return their own commands' answers (`{command, ok, error}`) from `step()`; the screen turns refusals into the `Rejected:` note and beep, accepted orders into playtest checklist ticks, and a build's answer into the placement decision. The offline driver still issues at `submit` (same tick, same order: no trace moves) and only holds the answer; both drivers answer a placement-preview request after their next step. No pump, no thread, no simulation change: those are SB3 to SB5.

**Tech Stack:** Godot 4.7.2 typed GDScript, suite runner `game/tests/run_tests.gd`, POSIX sh tools.

**Spec:** [sim boundary design](../specs/2026-11-15-sim-boundary-design.md) (package rows SB1 and SB2, "Offline", "Snapshot, digest, ring", owner answers 7 and 13-16, agent calls). Read with it: [simulation interface](../../reference/sim-interface.md), [determinism rules](../../reference/determinism-rules.md).

## Global Constraints

- **Base:** `main` after the P2.2 quick rematch merge (plan `~/projects/wargrid-wt-rematch/docs/superpowers/plans/2026-11-15-p2.2-quick-rematch-slice-1.md`: online `_seat`, `_phase`, `take_rematch`, `create` re-entered with its reset list, `_restart_world`, `ResultPanel` replacing the HUD's `Result` label and `Restart` button, `Lockstep.for_start`, `Lockstep.session_handler`). Every path:line below is `main` 32748c8, before P2.2; Task 1 refreshes them on the real base and records the map. Branch `sim-boundary-sb1-sb2`.
- **Simulation untouched:** `git diff <base> -- game/scripts/simulation protocol` stays empty. No digest, replay trace, team-match pin or netplay trace changes. The only pinned rows allowed to change are the IC1 input rows, in the fields Task 5 lists (owner answer 17); IC2 stays as it is (answer 18); anything else that moves is a stop.
- **Keep `driver.sim`:** it is removed in SB3.
- **Exact behaviour (spec, owner answers 7, 13-20):** offline refusal text is online's `"Rejected: " + error` (`match_screen.gd:146`), the beep is `_sound.rejected(error)` one tick after submit, the order voice plays at submit; offline, after a placement click placement mode stays until that build's answer arrives and stays on after a refusal; online, the click closes placement at once and a refusal reopens it with the same building (answer 18); while a build answer is pending further placement clicks are ignored (answer 19); an accepted result no longer clears a refusal note, which stays until the next own message, offline and online (answer 20); only accepted orders tick the playtest checklist; the placement ghost moves at once in the colour of the last preview answer, refused before a placement's first answer.
- **Agent call this plan adds (owner may overrule):** a repaint on input never updates sound and never consumes `stepped_results` (review fix for `sound_director.gd:57`).
- **Tests:** new cases are named `test_sb1_*` / `test_sb2_*` so `WARGRID_TEST_ONLY=sb1_` or `=sb2_` selects them; they go into existing suites and use only the [simulation interface](../../reference/sim-interface.md) (`python3 tools/test_sim_boundary.py`, in `sh tools/run_checks.sh`). An existing assertion changes only where this plan names it; record the selected case count of every filtered run.
- **Test setup rule:** a scene test that edits or swaps `driver.sim` calls `main._refresh()` before the input it tests; one that issues local-player commands straight into the driver's simulation (`Fixture.send`, `Fixture.build`) calls `BaseScene.sync_sequence(main)` (Task 2) before input that submits. Neither changes an expected value.
- Typed GDScript; comments one line, WHY only; `shortcut: <limit>, <when to upgrade>`. Edits with the Edit tool or asserted replacements only.
- **Subagents never commit, push, merge, deploy or open a window.** Commit steps are the coordinator's local commits (milestone prompt). Drawing code (`world_view.gd`) is not touched, so no rendered benchmark rerun (say so in the verification file); if a task must touch it, stop and ask.
- Every suite, netplay, lint, warnings and benchmark call: `timeout: 600000`, output to a file under `build/sb/`, judged by exit code and marker (`TESTS PASSED <n>`, `CHECKS PASSED 5`, `NETPLAY PASSED match`, `REPLAYS MATCHED <n>`); on failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:' <log>`. Full suite (about 78 s) at Tasks 4, 5, 6 and 8.
- Per GDScript task: `sh tools/run_lint.sh > build/sb/lint.log 2>&1; echo exit=$?` and `sh tools/run_warnings.sh > build/sb/warn.log 2>&1; echo exit=$?` → both 0.

## Review Focus

1. **Picks from a view one tick old** (split frame, `presentation_clock.gd:26-33`): today `_matching_ids` mixes a shown pick with live `kinds` and errors on a unit that died in between (`orders.gd:232-236`); after SB1 every lookup uses the shown view. Test RB4 (Task 3).
2. **A repaint between a step and its deferred refresh** must leave that step's sound events pending and its results unconsumed, so each sound plays once, at the new rows. Test RB5 (Task 4).
3. **A refusal next to an accepted command in one step:** the accepted result must not wipe the `Rejected:` note, in either submission order. Test RA3 (Task 5).
4. **A held answer or preview request across pause, restart, rematch or leave-with-form:** nothing from before shows after; nothing is lost or doubled across a pause. Tests RA4, RA5, RA7 (Task 5), RP5, RP7 (Task 6).
5. **Online stall or catch-up while placing:** no preview answer during `waiting`; one answer after a two-tick frame, computed after its last tick. Tests RP4, RP8 (Task 6).

## Same-tick interactions

"Shown" is `match_screen.shown_state`; "next step" is the driver's next `step()` (offline one per physics frame; online up to `CATCH_UP_STEPS` = 2, `online_driver.gd:8`). "Answer" is the driver's `{command, ok, error}` for an own command.

| Command or case | SB1: what input reads | SB2: when the answer acts | Pinned by |
|---|---|---|---|
| `move` | selection; hint at the shown tick | refusal next step; accepted → checklist | RB2, RA1 |
| `stop` | selection | same | RB2, RB4 |
| `attack` | world-view pick (unchanged) | refusal next step; worker attack has no voice line | OV8 |
| `attack_move` | selection | same | RB2 |
| `build` | `_builder()` from shown rows; ghost cells at once | offline: placement stays until the build's answer, accepted → exits, refused → stays; online: closes at the click, a refusal reopens it with the same kind; placement clicks ignored while the answer is pending; ghost colour next step | RB1, RA6, RA8, RP1-RP3, Bs2, IC1 step 11 (re-pinned), IC2 step 11 (unchanged) |
| `resume_build` | shown building, `_builder()`, hint at shown origin | refusal next step | RB1, Bs4 |
| `cancel_build`, `cancel_production` | shown building (HUD) | same | Bs3 |
| `produce` | shown building, `_production_kind(shown)` | "Insufficient credits" next step, funds line unchanged | RB1, AN20 |
| `set_rally` | shown building | same | RB1 |
| `choose_faction` | online `start` only | excluded from answers (not an order) | N tests |
| `gather` | shown sources, `_unit` kinds | refused gather never ticks the checklist; accepted ticks it next step (online when applied) | RB1, PO6, RA2 |
| `enter`, `unload` | `_container` on shown building or unit row | same | TU1 |
| `defence_attack` | shown building | "Target out of range" next step | DA5 |
| actor or target removed after the shown tick | command built from shown; the simulation validates | refusal next step; id leaves the selection at the next refresh | RB4 |
| accepted and refused in one step, either order | n/a | note keeps the refusal (an accepted result no longer clears it) | RA3 |
| cancel and re-enter placement before an answer | request cleared on cancel | old answer never colours the new placement; a still-pending build answer keeps the new placement's clicks ignored until it arrives | RP6, RA8 |
| setup → ongoing while shown lags | `shown_over()` false in setup; input passes | unchanged | RB9 |
| restart (offline) | `create` resets counter, held answers, preview; `orders.reset`; `_refresh` before input | nothing old shown at the first new step | RA4, RP5, K4 |
| leave with the playtest form open | offline: paused behind the form; online: keeps stepping (`test_playtest_overlay.gd:377-379`) | offline nothing delivered; online answers delivered without error | RA7 |
| rematch (P2.2, online) | `create` resets preview and answer bookkeeping; `_restart_world` refreshes before input | no old answer at the first new step | RP5 |
| two-tick frame | input between reads shown (one or two ticks behind) | answers of both ticks, in order; preview answered once after the last tick | RF8, RB5, RP8 |
| offline pause (menu) | menu takes input | answers and preview wait; delivered once on resume | RA5, RP7 |
| match over (shown) | `orders.handle` ignores input | a direct `_submit` gets `Rejected: Match ended` next step | K4 |

## Files

- `game/scripts/match/match_screen.gd`: `shown_state`, `shown_over()`, `_reshow()`, `_show(state, fresh)`, marker and hint tick, `_submit`, `_step_simulation` (answers), `_show` passes the preview answer.
- `game/scripts/match/orders.gd`: shown-view reads, `_unit(id)`, repaint calls, build awaiting, preview request and answer.
- `game/scripts/match/hud.gd`: `_result_text` team from the shown view; `_refresh_hud(state, with_sound)`; note precedence.
- `game/scripts/match/offline_driver.gd`: counter; held answers; preview.
- `game/scripts/match/online_driver.gd`: answers from the lockstep log and rejections; preview.
- Tests: `test_base_scene.gd`, `test_skirmish_scene.gd`, `test_online_scene.gd`, `test_order_voice.gd`, `test_playtest_overlay.gd`, `test_announcer.gd`, `input_script_rows.gd`.
- Docs: `docs/reference/sim-boundary-verification.md` (new), guide chapters 01, 04, 05, 07, 11, `docs/reference/sim-interface.md`.

---

### Task 1: Base, verification file and base evidence

**Files:** Create `docs/reference/sim-boundary-verification.md`; nothing else changes.

**Interfaces:** Produces `build/sb/base/{replay,economy,combat,team}.tsv`, `build/sb/base/netplay/s1.tsv`, the base `TEAM MATCH` line, and a path:line map from this plan's 32748c8 lines to the base tree.

```text
Task: record the base so later tasks can prove "unchanged"
Owns: docs/reference/sim-boundary-verification.md, build/sb/base/
Invariant: no source file changes
Boundary: P2.2 moved match_screen.gd, online_driver.gd, hud.gd and test_online_scene.gd lines
Green: every base command exits 0 with its marker
Stop: P2.2 not merged, or a base command fails
```

- [ ] **Step 1:** `git log --oneline -3`, `git status --short`; confirm P2.2 is on `main`; create the branch.
- [ ] **Step 2:** Map every cited line (`rg -n "driver\.sim" game/scripts/match game/scripts/presentation`, `rg -n "_refresh\(\)" game/scripts/match/orders.gd`, the test lines this plan cites) to the base. Also record: where `_result_text` / `team_of` now live and whether `ResultPanel` reads `driver.sim` (a new reader joins Task 3's list); the online driver's seat field; P2.2's `create` reset list; the post-P2.2 form of N3's layout check (`test_online_scene.gd:73-77` loses `HUD/Restart`); the P2.2 rematch fixture name (`test_rematch_builds_new_match`).
- [ ] **Step 3:** `mkdir -p build/sb/base && WARGRID_REPLAY_TRACE="$PWD/build/sb/base/replay.tsv" WARGRID_ECONOMY_REPLAY_TRACE="$PWD/build/sb/base/economy.tsv" WARGRID_COMBAT_REPLAY_TRACE="$PWD/build/sb/base/combat.tsv" WARGRID_TEAM_REPLAY_TRACE="$PWD/build/sb/base/team.tsv" sh tools/run_tests.sh > build/sb/base/tests.log 2>&1; echo exit=$?` → `TESTS PASSED <n>`.
- [ ] **Step 4:** `NETPLAY_OUT="$PWD/build/sb/base/netplay" sh tools/run_netplay.sh match > build/sb/base/netplay.log 2>&1; echo exit=$?` → `NETPLAY PASSED match`. `sh tools/run_team_match.sh > build/sb/base/team_match.log 2>&1; echo exit=$?` → exit 0 (pin at `tools/run_team_match.sh:13`).
- [ ] **Step 5:** Resume record (milestone prompt block) and a dated evidence row per command with its tree. Commit `Record the sim boundary base`.

### Task 2: Offline submit without a snapshot (SB1)

**Files:**
- Modify: `game/scripts/match/offline_driver.gd` (`submit` :40-50, comment :26)
- Test: `game/tests/test_skirmish_scene.gd`, `game/tests/test_base_scene.gd` (helper), scene tests that need `sync_sequence` (known: K13 `test_skirmish_scene.gd:579`)

**Interfaces:**
- Produces in `offline_driver.gd`: `submit` stamps `tick = payload.get("tick", sim.tick())`, `player`, `sequence = _sequence`, still calls `_recording().issue_command` and still adds 1 to `_sequence` only when that result is `ok`; no `snapshot()`, no `last_sequences` read.
- Produces in `test_base_scene.gd`: `func sync_sequence(main) -> void`: `main.driver._sequence = maxi(main.driver._sequence, entry.sequence + 1)` for the local player's entry in `main.driver.sim.snapshot().last_sequences` (the sync the driver drops, kept for tests that inject commands).

```text
Task: an offline command costs no snapshot
Owns: offline_driver.gd submit, sync_sequence, setup lines of tests that inject local commands
Invariant: OD1 stamps [[t,1,0],[t,1,1]]; IC1 sequences unchanged
Red: RB3 snapshot count 3
Green: RB3, OD1, all scene suites
Stop: an IC row or a trace changes
```

- [ ] **Step 1:** `test_skirmish_scene.gd` `test_sb1_submit_takes_no_snapshot` (RB3): `OfflineDriver.new(1)` with `Skirmish.create(false)`, one rifleman, `start_match`; `Profiler.reset(); Profiler.enabled = true` around three `driver.submit` calls (stop, attack on 999999, stop). Assert `Profiler.calls(&"snapshot") == 0` and OD1's stamps.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=sb1_ sh tools/run_tests.sh > build/sb/t2.log 2>&1; echo exit=$?` → exit 1, RB3 reports 3 snapshots.
- [ ] **Step 3:** Implement per Interfaces.
- [ ] **Step 4:** Step 2's command → exit 0. `WARGRID_TEST_ONLY=scene sh tools/run_tests.sh > build/sb/t2s.log 2>&1; echo exit=$?` → exit 0; a red "Sequence must increase" case gets `sync_sequence(main)` after its direct sends (list each in the verification file). Also `=order_voice`, `=playtest`, `=announcer` → exit 0.
- [ ] **Step 5:** Lint, warnings; resume record; commit `Stamp offline orders from the driver's counter`.

### Task 3: Input reads the shown view (SB1)

**Files:**
- Modify: `game/scripts/match/match_screen.gd` (`_show` :248-259, `playtest_context` :131, `_escape_pending` :152, `_show_hint` :263), `game/scripts/match/orders.gd` (:31, :151, :232-238, :247, :259-261, :283, :291-301, :314-319, :322, :332, :339, :359-361, :364), `game/scripts/match/hud.gd` (:163)
- Test: `game/tests/test_skirmish_scene.gd`

**Interfaces:**
- Consumes: Task 2's snapshot-free `submit`.
- Produces in `match_screen.gd`: `var shown_state: Dictionary = {}`, set first in `_show(state)`; `func shown_over() -> bool` (`shown_state.match` non-null with `status` in `["won", "draw"]`; false while empty).
- Produces in `orders.gd`: `func _unit(id: int) -> Dictionary`: `{}` when `shown_state.units.index_of(id) == -1`, else `_screen.hud._unit_record(rows, i)` plus `"inside": (rows.flags[i] & ViewRows.CONTAINED) != 0` (`ViewRows` = `res://scripts/simulation/view_rows.gd`).
- Produces in `hud.gd`: `_result_text(match_state: Dictionary) -> String` keeps its signature; the local team is `team` of the `shown_state.players` entry whose `id` is `local_player`, 0 when absent (as `simulation.gd:91-92`).

```text
Task: orders, HUD result, marker and hint read the shown view, never driver.sim
Owns: the lines above, test_skirmish_scene.gd
Invariant: every order payload equal to today's for the same shown view; IC1/IC2 rows unchanged
Boundary: a picked or selected id absent from the shown rows or the live sim
Red: RB1, RB2 snapshot count > 0; RB4 script error; RB6 live team
Green: RB1, RB2, RB4, RB6, RB9; scene suites
Stop: an order payload or an IC row would change
```

- [ ] **Step 1: Write the failing tests** (`test_skirmish_scene.gd`; profiler windows exclude every `_refresh()` the fixture needs):
  - `test_sb1_economy_input_reads_shown` (RB1): RF2's fixture (`Skirmish.create()` plus `Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))`, `test_skirmish_scene.gd:601-605`), `sync_sequence(main)`, builder 1 selected, `_refresh()`; then under the profiler: key 1, hover and click a free cell (build); right-click the first pile; key U; left-click the barracks (selects it through input); key E (produce); right-click ground (set_rally). Assert `snapshot` calls 0 (`"RB1 … got %d snapshots"`); afterwards pending holds one `build`, one `produce`, one `set_rally`.
  - `test_sb1_combat_input_reads_shown` (RB2): `_arena(main)`; under the profiler: right-click ground (move), right-click the enemy (attack), A then left click (attack_move), S (stop), double-click the tank. Assert `snapshot` 0; pending `move`, `attack`, `attack_move`, `stop` one each; selection `[ids.tank]`.
  - `test_sb1_pick_of_unit_dead_since_shown` (RB4): `_arena`, `remove_object(ids.infantry)` in the live simulation without refresh, double-click the infantry's shown position → no script error, selection from the shown view (on 32748c8 this errors in `_matching_ids`). Then select `[ids.infantry]` only, key S → the simulation refuses it with its normal error in the note (fully dead actor); and selection `[ids.infantry, ids.tank]`, S → one pending stop (compatibility: the live tank keeps it valid).
  - `test_sb1_result_uses_shown_team` (RB6): two public simulations, `Simulation.new()` with `add_player(1, 0, "human", 1)` and `add_player(1, 0, "human", 7)` respectively; show the first (`driver.sim = a; _refresh()`), swap to the second without refresh → `_result_text({"status": "won", "winner": 7}) == "Defeat"`; `_refresh()` → `"Victory"`. K4's team line (`test_skirmish_scene.gd:135-136`) gains `main._refresh()` after its edit.
  - `test_sb1_setup_shown_allows_input` (RB9): `_arena`, `main._show(view)` with a copy of `main.shown_state` whose `match.status` is `"setup"` → `shown_over()` false and a box selection still selects.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=sb1_ sh tools/run_tests.sh > build/sb/t3.log 2>&1; echo exit=$?` → exit 1: RB1/RB2 snapshot counts above 0, RB4 script error, RB6 first check, RB9 (missing `shown_over`).
- [ ] **Step 3: Implement.** Replace each `_screen.driver.sim.snapshot()` in `orders.gd` with `_screen.shown_state`, entity loops with `_unit(id)` over the ids the code already iterates, :31 with `_screen.shown_over()`, :283's tick with `_screen.shown_state.tick`; `match_screen.gd` :131 and :263 tick from `shown_state.tick`, :152 `shown_over()`; `hud.gd` :163 as in Interfaces. Leave `match_screen.gd:117,121,138,182-191,281-282` and `orders.gd:286` (SB2, SB3).
- [ ] **Step 4:** Step 2's command → exit 0. `WARGRID_TEST_ONLY=scene` → exit 0; fix red setup per the Global Constraints rule only.
- [ ] **Step 5:** Lint, warnings; resume record; commit `Read the shown view on input`.

### Task 4: Input repaints the shown view (SB1)

**Files:**
- Modify: `game/scripts/match/match_screen.gd` (`_show` :248-259, `_submit` :265-272, new `_reshow`), `game/scripts/match/hud.gd` (`_refresh_hud` :40-47), `game/scripts/match/orders.gd` (`_screen._refresh()` at :108, 157, 169, 224, 227, 267, 273, 279, 300, 310, 327, 343)
- Test: `game/tests/test_skirmish_scene.gd`, `game/tests/test_base_scene.gd`, `game/tests/test_online_scene.gd`

**Interfaces:**
- Consumes: `shown_state` (Task 3).
- Produces in `match_screen.gd`: `func _show(state: Dictionary, fresh: bool = true) -> void`: only when `fresh` does it clear `stepped_results` and let the HUD update sound; `func _reshow() -> void`: `_show(shown_state, false)` then `hud.place_economy()`. `_refresh()` stays the only builder of a new `view_state()`.
- Produces in `hud.gd`: `_refresh_hud(state: Dictionary, with_sound: bool = true) -> void` (skips `_screen._sound.update(state)` when false; `_economy_hud` still reads `stepped_results`, which is idempotent through `_last_result_tick/sequence`).

```text
Task: no view_state() per input event, and a repaint never touches sound or step results
Owns: the lines above
Invariant: the HUD text after input equals a fresh refresh of the same tick; every sound event of a step plays once, against that step's rows
Boundary: input between a step and its deferred refresh (RB5)
Red: RB1/RB2 view_state count > 0; RB5 director consumed the step during the hover
Green: RB1, RB2, RB5, RB7, RB8, RF1, RF2, RF5, RF6, RF8; full suite
Stop: an expected HUD text or sound test would change
```

- [ ] **Step 1: Write the failing tests.**
  - RB1 and RB2 gain `Profiler.calls(&"view_state") == 0`.
  - `test_base_scene.gd` `test_sb1_repaint_keeps_step_pending` (RB5): RF8's setup (`test_base_scene.gd:307-318`, processing on, two tick-0 builds, the second short of credits), two `_physics_process` calls, then a `hover` that changes the hovered object (so `orders.gd:108` repaints). Assert `main._sound.director.collected_ticks()` still holds both ticks and `consumed_ticks()` neither; after two `await runner.process_frame`: the status contains `"Insufficient credits"`, each tick appears once in `consumed_ticks()`, and `main._view._state.tick == main.driver.sim.tick()`.
  - `test_skirmish_scene.gd` `test_sb1_idle_offline_ticks_take_no_snapshot` (RB7): `Skirmish.create()` in the scene (bot seat 2), 300 direct `_physics_process(0.0)` calls under the profiler: `snapshot` 0, `view_state` 300 (bots read `bot_state()`, its own zone).
  - `test_online_scene.gd` `test_sb1_online_snapshot_per_hash_tick` (RB8): online seat 1, peer packets to tick 64, profiler on after `start`, run until the simulation passes tick 60 → `snapshot` calls == 2. A count guard; exact hash ticks stay covered by `test_lockstep.gd`.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=sb1_ sh tools/run_tests.sh > build/sb/t4.log 2>&1; echo exit=$?` → exit 1 on RB1/RB2 view counts and RB5's pending check; RB7 and RB8 may already pass (guards; record it).
- [ ] **Step 3:** Implement per Interfaces; the twelve orders call sites and `_submit` call `_reshow()`.
- [ ] **Step 4:** Step 2's command → exit 0; full suite `sh tools/run_tests.sh > build/sb/full4.log 2>&1; echo exit=$?` → exit 0.
- [ ] **Step 5: SB1 evidence.** Traces as Task 1 Step 3 into `build/sb/sb1/`; `python3 tools/compare_replays.py build/sb/base/replay.tsv build/sb/sb1/replay.tsv`, the same for `economy` and `combat`, `--interval 200 --rows 100` for `team` → `REPLAYS MATCHED` each; `git diff <base> --stat -- game/scripts/simulation protocol` → empty. Lint, warnings; resume record; commit `Repaint the shown view on input`.

### Task 5: Answers arrive with the next step (SB2)

**Files:**
- Modify: `game/scripts/match/offline_driver.gd` (`create`, `submit`, `step`), `game/scripts/match/online_driver.gd` (`step` :52-66, `_new_rejections` :71-77, `create` reset list), `game/scripts/match/match_screen.gd` (`_step_simulation` :141-146, `_submit`), `game/scripts/match/hud.gd` (`_economy_hud` :50-54), `game/scripts/match/orders.gd` (`reset`, `_placement_input` :135-138, `_clear_placement`)
- Test: `test_skirmish_scene.gd` (OD1 :827-839, K4 :137-140, DA5 :487, IC1 :735-823), `test_base_scene.gd` (Bs2 :87-95, Bs5 :199-218), `test_order_voice.gd` (OV8 :147-160), `test_playtest_overlay.gd` (PO6 :216-219), `test_announcer.gd` (AN20 :291-297), `test_online_scene.gd` (IC2 :928-980, H5), `input_script_rows.gd`

**Interfaces:**
- Produces in both drivers: `step(after_tick: Callable) -> Array[Dictionary]`: answers to own commands settled in this call, in order, each `{"command": Dictionary, "ok": bool, "error": String}` (the design's `Note.issued` shape). Offline: `submit` still issues at once (Task 2's stamping and `ok`-only counter), returns `{"ok": true, "error": ""}`, and appends the answer to a held list that the next `step` returns after stepping; `create` clears it. Online: new own entries of `_lockstep.command_log()` since a `_log_seen` index (seat from P2.2's driver field; `choose_faction` excluded) are accepted unless their sequence is in this call's new rejections; each new rejection is a refused answer whose `command` is the logged own command with that sequence, or `{}` when none (H5 and OV9 inject rejections without a log entry); `create` resets `_log_seen`.
- Produces in `match_screen.gd`: `_submit(payload)`: `_show_hint`, `driver.submit`, `hud.note = ""`, `_reshow()`, `_sound.order(payload)` (no checklist call). `_step_simulation()`: for each answer: refused → `_sound.rejected(error)` and `hud.note = "Rejected: " + error`; accepted → `_playtest.observe_command(answer.command)`; every answer → `orders.answered(answer)`.
- Produces in `hud.gd`: a local result updates `_last_result_tick/sequence` as today but sets `note` only when `ok` is false.
- Produces in both drivers: `func closes_placement_on_click() -> bool` (offline `false`, online `true`; answer 18).
- Produces in `orders.gd`: `var _awaiting_build: String` (the kind of the build whose answer is pending, `""` for none); a placement release while it is set does nothing; otherwise it submits the build, sets it, and calls `_clear_placement()` at once when `driver.closes_placement_on_click()`. `func answered(answer: Dictionary) -> void`: when set and `answer.command.get("type") == "build"`: accepted → `_clear_placement()` (a no-op online); refused → offline nothing (placement stays), online, when not placing and `_builder() != -1`, `_enter_placement(<that kind>)` (when the builder is gone, nothing, so the `Rejected:` note stays); then clear it. Only `answered` and `reset` clear it.

```text
Task: an own command's answer reaches the screen with the next step, offline and online, through one path
Owns: the lines above and the listed tests
Invariant: the same commands enter the simulation on the same tick in the same order (traces equal)
Boundary: pause, restart, leave with the form; accepted and refused in one step
Red: RA1 note set at submit; RA2 checklist ticked by a refusal; RA6 placement exits on a refused click; RA8 no reopen after an online refusal
Green: RA1-RA8, the rewrites below, IC1 re-pinned, IC2 unchanged; full suite
Stop: a trace, the team pin or netplay changes; an IC1 row changes outside the allowed fields; any IC2 row changes
```

- [ ] **Step 1: Write the failing tests** (`test_skirmish_scene.gd` unless named):
  - RA1 `test_sb2_refusal_next_step`: `_arena`; `_submit({"type": "move", "entity_ids": [ids.tank], "target": [-5.0, -5.0]})` → `hud.note == ""`, no pending move; after `_physics_process(0.0)` `hud.note == "Rejected: Target outside map"` (`simulation.gd:305`), one `error` cue (`_cues`, `test_order_voice.gd:108`), and the layout half of N3 (economy below every status line; post-P2.2 form from Task 1's map).
  - RA2 `test_playtest_overlay.gd` `test_sb2_checklist_waits_for_answer`: PO6's fixture; refused gather (`[999999]`) then a physics call → `collect` not ticked; accepted gather → not ticked before the physics call, ticked after it.
  - RA3 `test_sb2_refusal_survives_accepted_result`: valid stop then refused move in one frame, and in a second case the reverse order; each with processing off (physics call) and on (physics, two process frames) → the note is the `Rejected:` line after the refresh.
  - RA4 `test_sb2_restart_drops_held_answer`: refused submit, `_restart()`, one physics call → no `Rejected:` line, no `error` cue.
  - RA5 `test_sb2_answer_waits_for_unpause`: refused submit, `main._pause.open()`, assert `menu_open()`, two physics calls → note empty; close, one physics call → the note once; one more physics call → still one `error` cue in total.
  - RA6 `test_base_scene.gd` `test_sb2_placement_waits_for_build_answer`: key 1, click the builder's own cell (Bs2's invalid spot) → placement kept; a second click before the physics call is ignored (the step returns exactly one answer); physics call → placement kept, `Rejected:` note; click a free cell → kept until the physics call, then cleared.
  - RA8 `test_online_scene.gd` `test_sb2_online_placement_closes_and_reopens` (answer 18): an accepted build click closes placement in the same frame, before any answer; a refused build click closes it, and once the rejection arrives placement is open again with the same kind; after a click, key 1 and a second placement click before the first answer are ignored (no second build in the own commands).
  - RA7 `test_playtest_overlay.gd` `test_sb2_leave_with_form_and_pending_answer`: PO9's online fixture with a build awaiting and a refused order pending, Leave → physics behind the form delivers them without a script error; offline variant: nothing delivered while the form holds the match.
  - Rewrites (named assertions only): OD1 `refused.ok` is true at submit and `driver.step(func() -> void: pass)` returns `[{command: stop 0, ok: true}, {attack, ok: false, error}, {stop 1, ok: true}]` in order; K4 "terminal match accepts no orders" checks no new pending command and `"Rejected: Match ended"` after one physics call; Bs2 compares credits, buildings and pending commands (not whole snapshots) around the click, asserts the tick advance separately, and expects placement kept and the `Rejected:` note after one physics call; its "release exactly one build" checks one pending build right after the release and placement cleared only after the next physics call; Bs5 "immediate error persists refresh" reads the note after one physics call; OV8: the builder's attack stays silent (workers have no attack line, `unit_voice.gd:5`), the blocked build speaks `worker_work_` at submit, the beep follows one physics call, the line stays; PO6 keeps "a rejected gather ticks nothing" and its accepted case gains a physics call; AN20 and DA5 compare the note after one physics call with the `Rejected: ` prefix; RB4's fully-dead-actor check (Task 3) reads its note after one physics call.
  - IC1 re-pin (owner answer 17, approved): IC1 gains one `_physics_process(0.0)` after the step-11 check and resets `seen[0] = 0` after it. IC2 is not touched and must match its pinned rows (online closes at the click). Allowed IC1 row changes, recorded old and new in the verification file: row 11's `place=` and command list, and from step 11 on the command `tick` stamps, the `Tick:` and `Credits:` values in status text and row 21's `tick=`. Selections, ids, sequences and command order stay.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=sb2_ sh tools/run_tests.sh > build/sb/t5.log 2>&1; echo exit=$?` → exit 1: RA1 note at submit, RA2 refusal ticks, RA3 note cleared, RA6 placement exits, RA8 no reopen.
- [ ] **Step 3:** Implement per Interfaces.
- [ ] **Step 4:** Step 2's command → exit 0; `WARGRID_TEST_ONLY=scene`, `=order_voice`, `=playtest`, `=announcer`, `=input_script` → exit 0; full suite → exit 0.
- [ ] **Step 5:** Lint, warnings; resume record; commit `Answer orders one tick later`.

### Task 6: Placement preview answered after the next step (SB2)

**Files:**
- Modify: `game/scripts/match/orders.gd` (`reset`, `_enter_placement` :263-273, `_clear_placement` :275-279, `_update_preview` :281-287), `game/scripts/match/match_screen.gd` (`_show`), both drivers
- Test: `test_base_scene.gd` (Bs6 :221-236), `test_online_scene.gd`

**Interfaces:**
- Produces in both drivers: `func request_preview(request: Dictionary) -> void` (`{player, builder_id, kind, origin: Vector2i}`; `{}` cancels and clears the answer); `func preview_answer() -> Dictionary` (`{kind, origin, ok}` of the last answered request, `{}` when none). After a call of `step` that stepped at least once (offline after `after_tick`; online after the catch-up loop), a pending request is answered once with `sim.preview_build(...).ok` and cleared. `create` clears request and answer. One `shortcut: duplicated in both drivers, SB3's run_job takes it over` line above each copy.
- Produces in `orders.gd`: `var _answer: Dictionary`; `func show_preview(answer: Dictionary) -> void` (called by `_show` after `orders.prune`, also on repaint): when placing and `answer.kind == _placement_kind`, store it; when also `answer.origin == _preview_origin`, redraw the ghost with `answer.ok`. `_update_preview` keeps its key `[kind, origin, shown tick]`, draws the cells at once with `_answer.get("ok", false)` and calls `request_preview` instead of `preview_build`. `_enter_placement` and `reset` clear `_answer`; `_clear_placement` calls `request_preview({})`.

```text
Task: the ghost's colour comes from the driver's answer after the next step, in both modes
Owns: the lines above
Invariant: preview_build is pure (test_construction.gd Cn1); at most one preview per (kind, origin, shown tick)
Boundary: online stall and catch-up; pause; cancel and re-enter; restart and rematch
Red: RP1 colour from a synchronous preview
Green: RP1-RP8, Bs6; full suite
Stop: an IC row changes beyond Task 5's re-pin
```

- [ ] **Step 1: Write the failing tests** (`test_base_scene.gd` unless named):
  - RP1 `test_sb2_ghost_colour_after_step`: builder 1 selected; key 1, hover a free cell → cells set at once, `_preview_valid == false`; one physics call → `true`; hover the builder's own cell `(4.25, 4.25)` → cells moved, still `true`; one physics call → `false`.
  - RP3 Bs6 rewritten as `test_sb2_preview_cost`: five hovers across one cell, then one physics call → `navigation_builds()` grows by exactly 1 and `preview_answer().ok` equals `sim.preview_build(1, 1, kind, origin).ok` on the post-step state; a new cell and a physics call → one more; hovers without a physics call → 0.
  - RP4 `test_online_scene.gd` `test_sb2_online_preview_waits_for_step`: online seat 1, peer packets to tick 12, select the builder explicitly (`_builder(main, 1)`), key 1, hover; run until `_lockstep.status() == "waiting"` and the tick stops; one more frame → tick unchanged, `preview_answer()` from before the stall only, ghost colour unchanged; add packets, one frame → a new answer for the current origin.
  - RP5 `test_sb2_restart_drops_pending_preview`: request pending (no physics yet), `_restart()`, first physics call of the new match → `preview_answer()` empty and no ghost; online: P2.2's rematch fixture (`start` plus peer tick 4 in one poll through `_restart_world`) with a request pending → nothing applied at the first new step.
  - RP6 `test_sb2_reenter_placement_ignores_old_answer`: hover, Esc, key 1 again at the same spot before a physics call → after the physics call only the new request's answer colours the ghost (one `navigation_builds` increment).
  - RP7 `test_sb2_preview_waits_for_unpause`: hover, `_pause.open()`, physics calls → no answer; close, one physics call → answer.
  - RP8 `test_online_scene.gd` `test_sb2_preview_after_catch_up`: credit for two steps, request pending, one frame advances two ticks → `navigation_builds()` +1 and the answer arrives in that frame.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=sb2_ sh tools/run_tests.sh > build/sb/t6.log 2>&1; echo exit=$?` → exit 1, RP1 fails on its first `_preview_valid` check.
- [ ] **Step 3:** Implement per Interfaces.
- [ ] **Step 4:** Step 2's command → exit 0; `=input_script` → exit 0 with Task 5's rows; full suite → exit 0.
- [ ] **Step 5:** Lint, warnings; resume record; commit `Answer the placement preview one tick later`.

### Task 7: Docs

**Files:** `docs/guide/01-big-picture.md` (:23, flows :37 and :50, :100, :114-116, footer :135), `docs/guide/04-the-tick.md` (offline submit steps :61-66: the answer one tick later; footer :180), `docs/guide/05-presentation.md` (hand-off :43-44, `shown_state` and repaint; HUD and input :157-158; playtest helper :159: only accepted orders tick the checklist; footer :229), `docs/guide/07-economy.md` (:108 preview flow), `docs/guide/11-multiplayer.md` (`online_driver.gd` line: answers and `request_preview`; footer :221), `docs/reference/sim-interface.md` (:45 who calls `snapshot()`, :57 `preview_build` caller), the verification file.

- [ ] **Step 1:** Update each passage (payoff first, terms explained where they appear); set each `Checked against` footer to the branch head.
- [ ] **Step 2:** `sh tools/check_public.sh > build/sb/public.log 2>&1; echo exit=$?` → exit 0; check every link and path:line the edits cite with `rg -n`.
- [ ] **Step 3:** A fresh docs reviewer (diff plus the code files named in the footers, no repo-wide search) checks every code claim; fix findings.
- [ ] **Step 4:** Resume record; commit `Document reads on request and next-tick answers`.

### Task 8: Gate checks

- [ ] **Step 1:** `sh tools/run_checks.sh > build/sb/checks.log 2>&1; echo exit=$?` → `CHECKS PASSED 5`.
- [ ] **Step 2:** Full suite with traces into `build/sb/sb2/` (Task 1 Step 3 command); `compare_replays.py` base against sb2 for replay, economy, combat, team → `REPLAYS MATCHED` each.
- [ ] **Step 3:** `NETPLAY_OUT="$PWD/build/sb/sb2/netplay" sh tools/run_netplay.sh match > build/sb/sb2/netplay.log 2>&1; echo exit=$?` → `NETPLAY PASSED match`; `python3 tools/compare_replays.py --interval 30 --rows 0 build/sb/base/netplay/s1.tsv build/sb/sb2/netplay/s1.tsv` → matched; `sh tools/run_team_match.sh > build/sb/sb2/team_match.log 2>&1; echo exit=$?` → exit 0.
- [ ] **Step 4:** `git diff <base> --stat -- game/scripts/simulation protocol` → empty.
- [ ] **Step 5: Benchmark**, alone, `uptime` at start and end (load above 2.5: say so and wait): `PERF_LABEL="Sim boundary SB1-SB2" sh tools/run_benchmark.sh > build/sb/bench.log 2>&1; echo exit=$?`; record the row per the [ledger](../../reference/performance.md); never loosen a budget. No rendered rerun (drawing code untouched; state it).
- [ ] **Step 6:** Resume record with every result and its tree; commit `Record the SB1-SB2 gate`.

## Stop gates (each waits for the owner)

1. **Whole-branch review** by one fresh-context reviewer on the strongest available model: diff since the base, the design, this plan, the verification file; it names per new test the production change that makes it fail and checks the interaction table row by row. Fix critical and important findings test-first; record rulings for the rest.
2. **`/ponytail-review`** on the diff (over-engineering only); apply cuts; rerun the touched checks and the full suite.
3. **Owner's playtest** offline and online: refusal one tick later, order voice before the beep, offline placement kept after a refused click, online placement closing at the click and reopening on a refusal, checklist ticks only on accepted orders, ghost colour lag.
4. Push, PR, merge and any deploy wait for the owner.

## Later packages (outline; each gets its own plan on its night)

- **SB3 Pump inline, offline.** Scope: `game/scripts/match/sim_pump.gd` (Job, Note, Slot, `run_job`); the offline driver posts one job per physics frame and drains in `_process`; issue moves into the job, so `submit` must stamp a sequence before the answer is known: either per submit (a refused command leaves a gap, `simulation.gd:210`, and the recorded commands and digests of a session with refusals then differ from SB2's for the same input) or a scheme that keeps accepted numbering; SB3's plan decides and pins it. Runs without refused local commands (all traces, bots) stay digest-equal. Also: `Job.bots = [2]` through `Skirmish.issue_opponents`; job 0's note with `starts` for `_reset_camera` (`match_screen.gd:117,121`); match record as a query job (`:138`); cache freeze with `add_test_kind` resets and a `Combat._reach_by_kind` reset; ring off offline; `tools/test_sim_boundary.py` check for `.sim` / `live()`; tests move to `pump.live()`, `sync_sequence` to the pump's helper, and tests reading `pending_commands` after a submit to the driver's queued commands. Exit: pump against direct digests over 900 ticks; skirmish and team traces equal; slot invariants; ledger row; Deck view-build split.
- **SB4 Online on the pump.** `Lockstep.take` / `record`, `finish_tick(tick, state, digest := "")`, commands logged on drain, ring and desync report by query job (asynchronous in worker mode), `match_log` from CURRENT (`online_driver.gd:96`), P2.2 rematch re-creates the pump. Exit: `test_lockstep.gd` and `run_lockstep.gd` untouched and green; loopback test of two drivers; `run_netplay.sh` match and rematch; `run_conformance.sh`; vectors untouched.
- **SB5 Worker mode, flag off.** Thread, `WARGRID_SIM_THREAD` and the pause-menu toggle ("Takes effect after a restart", remembered, offline and online) with a headless layout test; release Web preset threaded with COOP/COEP in `web/sws.toml`; both-mode pump tests, fault and stall; `worker_ab.py` into `tools/` with its test; `determinism-rules.md:14` reworded. Exit: digests equal on four loads in both modes; scene suite green under the flag; a fault ends the match within 5 s; loopback online with one worker client.
- **SB6 Decision rows (attended).** Deck Firefox, three or more interleaved runs per arm; a mixed online match; a fault probe in the release web build. Exit: the go rule as decided.

## Self-review notes

- Each task reaches its own green gate in order: Task 2 removes the submit snapshot before Task 3 asserts zero snapshots; Task 3 asserts snapshots only, Task 4 adds the view-state counts; Task 5 changes the answer path and the placement rule together, so Bs2 never goes through a state where an invalid click exits placement; Task 6 touches only the ghost colour.
- Spec coverage: SB1 read list (Tasks 2-4; per-match and step-path reads in the SB3/SB4 outline), exit counts (RB1-RB3, RB7, RB8), traces (Tasks 4, 8); SB2 answers, checklist, placement (Task 5), preview (Task 6).
- Not planned here: slice-2 bot work, the fork-join experiment, anything needing a pump.
- Owner answers 17-20 settled the IC1 re-pin, online placement, the ignored second click and the HUD note; nothing is open before the night.
