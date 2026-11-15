# Sim boundary SB1 and SB2: Implementation Plan

**Status:** draft for the owner's review (2026-11-15). Nothing here starts implementation; the night run starts only after P2.2 is merged to `main` and the owner starts it.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md): one fresh subagent per task, each starting from the resume record in `docs/reference/sim-boundary-verification.md`.

**Goal:** Match and presentation code stop reading the live simulation per input event (SB1 "Reads on request"), and offline refusals and the placement preview arrive with the next tick through the path online already uses (SB2 "Answers one tick later"), with digests, traces and pins unchanged.

**Architecture:** The match screen keeps the view it last showed (`shown_state`); input handling reads that view instead of `snapshot()`, and re-shows it instead of building a new `view_state()`. The offline driver stamps sequences from its own counter. In SB2 the offline driver still issues a command at `submit` but returns `{ok: true}` and hands the refusal back from its next `step()`, which the screen already routes to the sound and the `Rejected:` note; both drivers answer a placement-preview request after their next step. No pump, no thread, no simulation change: those are SB3 to SB5.

**Tech Stack:** Godot 4.7.2 typed GDScript, suite runner `game/tests/run_tests.gd`, POSIX sh tools.

**Spec:** [sim boundary design](../specs/2026-11-15-sim-boundary-design.md) (approved in substance 2026-11-15; package rows SB1 and SB2, "Offline", "Snapshot, digest, ring", agent calls 5 and 6). Read with it: [simulation interface](../../reference/sim-interface.md), [determinism rules](../../reference/determinism-rules.md).

## Global Constraints

- **Base:** `main` after the P2.2 quick rematch merge (plan `~/projects/wargrid-wt-rematch/docs/superpowers/plans/2026-11-15-p2.2-quick-rematch-slice-1.md`: online `_phase`, `take_rematch`, `create` re-entered, `_restart_world`, `ResultPanel` replacing the HUD's `Result` label and `Restart` button, `Lockstep.for_start`, `Lockstep.session_handler`). Every path:line below is `main` 32748c8, before P2.2; Task 1 refreshes them on the real base and records the mapping. Branch `sim-boundary-sb1-sb2`.
- **Simulation untouched:** `git diff <base> -- game/scripts/simulation protocol` stays empty. No digest, replay trace, team-match pin, IC1/IC2 input row or netplay trace changes. A pinned outcome that moves is a stop condition, not a re-pin.
- **Keep `driver.sim`:** it is removed in SB3. SB1 and SB2 change who reads it, not who holds it.
- **Exact behaviour values (spec):** offline refusal text is online's `"Rejected: " + error` (`match_screen.gd:146`); the refusal sound is `_sound.rejected(error)` with the bare error, as today; a refused offline order is passed to `_playtest.observe_command` and plays `_sound.order`, as online; the placement ghost moves at once in the colour of the last answer, refused before a placement's first answer; a click keeps placement mode only when the answer already shown for that kind and origin is refused.
- **Tests:** new cases go into existing suites (`test_base_scene.gd`, `test_skirmish_scene.gd`, `test_online_scene.gd`, `test_order_voice.gd`) and use only the [simulation interface](../../reference/sim-interface.md) (`python3 tools/test_sim_boundary.py`, run by `sh tools/run_checks.sh`). An existing assertion changes only where this plan names it; any other red case is a defect in the change.
- **Test setup rule (SB1):** a scene test that edits or swaps `driver.sim` calls `main._refresh()` before the input it tests; one that issues local-player commands straight into the driver's simulation (`Fixture.send`, `Fixture.build`) calls `BaseScene.sync_sequence(main)` before input that submits. Neither changes an expected value.
- Typed GDScript; comments one line, WHY only; `shortcut:` comments in the `shortcut: <limit>, <when to upgrade>` form. Edits with the Edit tool or asserted replacements only.
- **Subagents never commit, push, merge, deploy or open a window.** Commit steps are the coordinator's local commits (pre-authorized by the milestone prompt). No visible window: the world view and drawing code are not touched, so no rendered benchmark rerun is needed (say so in the verification file); if a task must touch `world_view.gd`, stop and ask.
- Every suite, netplay, lint, warnings and benchmark call: `timeout: 600000`, output to a file under `build/sb/`, judged by exit code and its marker (`TESTS PASSED <n>`, `CHECKS PASSED 5`, `NETPLAY PASSED match`, `REPLAYS MATCHED <n>`); on failure read only the failing lines (`rg -n 'FAIL|SCRIPT ERROR|ERROR:' <log>`). While iterating: `WARGRID_TEST_ONLY=<substring> sh tools/run_tests.sh`; the full suite (about 78 s) at Tasks 3, 5, 6 and 7.
- Per GDScript task: `sh tools/run_lint.sh > build/sb/lint.log 2>&1; echo exit=$?` and `sh tools/run_warnings.sh > build/sb/warn.log 2>&1; echo exit=$?` → both exit 0.

## Review Focus

1. **An order built from a view one tick old** (split frame, `presentation_clock.gd:26-33`: the live simulation is one tick ahead of the shown view for one frame): a selected unit that died since must be refused by the simulation with the normal note, never crash the screen on `index_of == -1`. Test RB4 (Task 2).
2. **A hover in the frame between a step and its deferred refresh** re-shows the old view and consumes `stepped_results`: a rejection from that step must still reach the HUD once the refresh comes (the RF8 merge). Test RB5 (Task 3).
3. **An order refused while the offline match is paused** (menu open, no step): the refusal arrives once on resume, not lost, not doubled. Test RA5 (Task 4).
4. **Restart or rematch with a held refusal or preview answer:** nothing from the old match shows in the new one (no `Rejected:` line, no ghost colour). Tests RA4 (Task 4), RP5 (Task 5).
5. **Online stall while placing** (`waiting`, no step): no answer arrives, the ghost keeps its last colour, and the answer comes with the first step after the stall. Test RP4 (Task 5).

## Same-tick interactions

"Shown" is `match_screen.shown_state`, the view last passed to `_show`. "Next step" is the driver's next `step()` call (offline one per physics frame; online up to `CATCH_UP_STEPS` = 2, `online_driver.gd:8`).

| Command or case | SB1: what input reads | SB2: when the answer comes | Pinned by |
|---|---|---|---|
| `move` (right-click ground) | selection only; hint at the shown tick | refusal next step as `Rejected:` | RB2, RA1, IC1 step 2 |
| `stop` (S) | selection only | same | RB2, IC1 step 4 |
| `attack` (right-click enemy) | world view pick (unchanged) | "Attack requires armed units" next step; order voice at submit | OV8 (rewritten), IC1 step 5 |
| `attack_move` (A, click) | selection only | same | RB2, IC1 step 3 |
| `build` (1, hover, click) | `_builder()` from shown rows; ghost cells drawn at once | colour and refusal next step; click keeps mode only on a shown refused answer for that kind and origin | RB1, RP1-RP3, Bs2, Bs6, IC1/IC2 step 11 |
| `resume_build` (right-click own foundation) | shown building, `_builder()`; hint at the shown origin | refusal next step | RB1, Bs4, IC1 step 14 |
| `cancel_build` (button) | shown building (HUD) | same | Bs3 |
| `produce` (E, menu) | shown building, `_production_kind(shown)` | "Insufficient credits" next step, funds voice line unchanged | RB1, AN20 (note text), IC1 step 12 |
| `cancel_production` (queue button) | none | same | existing |
| `set_rally` (right-click, building selected) | shown building | same | RB1, IC1 step 13 |
| `choose_faction` | not an input path (online `start`) | untouched | N tests |
| `gather` (right-click pile) | shown sources, `_unit` kinds | refusal next step | RB1, K12, K13, IC1 step 20 |
| `enter` (right-click own container) | `_container` on shown building or unit row | same | TU1, IC1 step 16 |
| `unload` (U) | `_container` on shown | same | TU1, IC1 step 15 |
| `defence_attack` (right-click, defence selected) | shown building | "Target out of range" next step | DA5 (note text) |
| actor or target removed after the shown tick | command built from shown; the simulation validates | refused next step; the id leaves the selection at the next refresh | RB4 |
| two submits in one frame, one refused | both issued at submit, in order | one refusal returned by the next step; note is the last one | RA3 |
| restart (offline) | `create` resets counter, held refusals, preview; `orders.reset`; `_refresh` rebuilds `shown_state` before input | nothing old shown | RA4, RP5, K4 |
| leave | `driver.leave`; the scene and driver are freed | held refusals dropped with the driver | existing leave tests |
| rematch (P2.2, online) | `create` resets the preview request and answer; `_restart_world` refreshes before input | no old answer applied | RP5 |
| two-tick frame (online two steps, or two physics frames before one `_process`) | input between them reads shown (one or two ticks behind) | online rejections of both ticks via `_new_rejections` (unchanged); preview answered once after the last step; offline each step returns its own refusals | RF8, RB5, RP4 |
| offline pause (menu open) | menu takes input | refusals and preview wait for the next step | RA5 |
| match over (shown) | `orders.handle` ignores input; `_escape_pending` false | a direct `_submit` gets `Rejected: Match ended` next step | K4 (rewritten) |

## Files

- `game/scripts/match/match_screen.gd`: `shown_state`, `shown_over()`, `_reshow()`, marker and hint tick from the shown view, `_submit` (SB2), `_show` passes the preview answer.
- `game/scripts/match/orders.gd`: reads from `shown_state`; `_unit(id)`; re-shows; preview request and answer (SB2).
- `game/scripts/match/hud.gd`: `_result_text` team from the shown view (or P2.2's `ResultPanel` caller, whichever holds `team_of` after the merge).
- `game/scripts/match/offline_driver.gd`: counter, held refusals (SB2), preview (SB2).
- `game/scripts/match/online_driver.gd`: preview (SB2) only.
- Tests: `game/tests/test_base_scene.gd`, `test_skirmish_scene.gd`, `test_online_scene.gd`, `test_order_voice.gd`, `test_playtest_overlay.gd`, `test_announcer.gd`.
- Docs: `docs/reference/sim-boundary-verification.md` (new), guide chapters 01, 04, 05, 07, 11, `docs/reference/sim-interface.md`.

---

### Task 1: Base, verification file and base evidence

**Files:**
- Create: `docs/reference/sim-boundary-verification.md`
- Read only: everything else

**Interfaces:**
- Consumes: the merged P2.2 tree.
- Produces: `build/sb/base/{replay,economy,combat,team}.tsv`, `build/sb/base/netplay/s1.tsv`, the base `TEAM MATCH` line, and in the verification file a path:line map from this plan's 32748c8 lines to the base tree.

```text
Task: record the base so later tasks can prove "unchanged"
Owns: docs/reference/sim-boundary-verification.md, build/sb/base/
Invariant: no source file changes
Boundary: P2.2 moved match_screen.gd, online_driver.gd and hud.gd lines
Red: n/a (evidence task)
Green: every base command exits 0 with its marker
Stop: P2.2 not merged, or a base command fails
```

- [ ] **Step 1:** `git log --oneline -3`, `git status --short`; confirm P2.2 is on `main`; create the branch.
- [ ] **Step 2:** Re-locate every read this plan changes with `rg -n "driver\.sim" game/scripts/match game/scripts/presentation` and `rg -n "_refresh\(\)" game/scripts/match/orders.gd`; write the old-to-new line map into the verification file. Also note where P2.2 left `_result_text` / `team_of` and whether `ResultPanel` reads `driver.sim`; a new reader is added to Task 2's list, not left behind.
- [ ] **Step 3:** Base traces (absolute paths, `$PWD` works in zsh and fish):
  `mkdir -p build/sb/base && WARGRID_REPLAY_TRACE="$PWD/build/sb/base/replay.tsv" WARGRID_ECONOMY_REPLAY_TRACE="$PWD/build/sb/base/economy.tsv" WARGRID_COMBAT_REPLAY_TRACE="$PWD/build/sb/base/combat.tsv" WARGRID_TEAM_REPLAY_TRACE="$PWD/build/sb/base/team.tsv" sh tools/run_tests.sh > build/sb/base/tests.log 2>&1; echo exit=$?` → exit 0, `TESTS PASSED <n>` (record n).
- [ ] **Step 4:** `NETPLAY_OUT="$PWD/build/sb/base/netplay" sh tools/run_netplay.sh match > build/sb/base/netplay.log 2>&1; echo exit=$?` → `NETPLAY PASSED match`. `sh tools/run_team_match.sh > build/sb/base/team_match.log 2>&1; echo exit=$?` → exit 0 (pinned `TEAM MATCH won tick=38786 winner=2 units_peak=268`, `tools/run_team_match.sh:13`).
- [ ] **Step 5:** Write the resume record (block from the milestone prompt) and a dated evidence row per command with its tree. Commit `Record the sim boundary base`.

### Task 2: Input reads the shown view (SB1)

**Files:**
- Modify: `game/scripts/match/match_screen.gd` (`_show` :248-259, `playtest_context` :131, `_escape_pending` :152, `_show_hint` :263), `game/scripts/match/orders.gd` (:31, :151, :232-238, :247, :259-261, :283, :291-301, :314-319, :322, :332, :339, :359-361, :364), `game/scripts/match/hud.gd` (:163)
- Test: `game/tests/test_skirmish_scene.gd`

**Interfaces:**
- Produces in `match_screen.gd`: `var shown_state: Dictionary = {}`, set first thing in `_show(state)`; `func shown_over() -> bool` (`shown_state.match` non-null with `status` in `["won", "draw"]`, false while empty).
- Produces in `orders.gd`: `func _unit(id: int) -> Dictionary`: `{}` when `shown_state.units.index_of(id) == -1`, else `_screen.hud._unit_record(rows, i)` plus `"inside": (rows.flags[i] & ViewRows.CONTAINED) != 0` (`ViewRows` preloaded from `res://scripts/simulation/view_rows.gd`).
- Produces in `hud.gd`: `_result_text(match_state: Dictionary) -> String` keeps its signature; the local team is the `team` of the player in `_screen.shown_state.players` whose `id` is `_screen.local_player`, 0 when absent (as `Simulation.team_of`, `simulation.gd:91-92`).

```text
Task: orders, HUD result and marker read the shown view, never driver.sim
Owns: match_screen.gd, orders.gd, hud.gd (lines above), test_skirmish_scene.gd
Invariant: every order payload equal to today's for the same shown view; IC1/IC2 rows unchanged
Boundary: a selected id absent from the shown rows (dead, or never shown)
Red: RB1, RB2 snapshot count > 0; RB4 crash or wrong note
Green: RB1, RB2, RB4, RB6 plus test_base_scene, test_skirmish_scene, test_online_scene, test_scene
Stop: an order payload or an IC row would change
```

- [ ] **Step 1: Write the failing tests.**
  - `test_skirmish_scene.gd` `test_economy_input_takes_no_snapshot` (RB1): RF2's fixture (`Skirmish.create()` plus `Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))`, `test_skirmish_scene.gd:601-605`), builder 1 selected, `_refresh()`, then `Profiler.reset(); Profiler.enabled = true` around: key 1, hover and click a free cell (build); right-click the first pile (`gather` or a local note, either is fine); key U ("Select a container"); select the barracks, `_refresh()`, key E (produce), right-click ground (set_rally). Assert `Profiler.calls(&"snapshot") == 0`, message `"RB1 economy input reads the shown view, got %d snapshots"`; after disabling the profiler, pending holds one `build`, one `produce` and one `set_rally`.
  - `test_skirmish_scene.gd` `test_combat_input_takes_no_snapshot` (RB2): `_arena(main)`; profiler around: right-click ground (move), right-click the enemy (attack), A then left click (attack_move), S (stop), double-click the tank (same-kind select). Assert snapshot calls 0 (`"RB2 …"`), pending `move`, `attack`, `attack_move`, `stop` one each, and the double-click selection equals today's (`[ids.tank]`).
  - `test_skirmish_scene.gd` `test_order_for_unit_dead_since_shown` (RB4): `_arena(main)` (infantry and tank selected, shown), then `main.driver.sim.remove_object(ids.infantry)` without refresh, key S. Assert no script error, one pending `stop` naming `[ids.infantry, ids.tank]` (the simulation drops the dead id at apply), and after `main._physics_process(0.0)` the selection is `[ids.tank]`.
  - `test_skirmish_scene.gd` `test_result_uses_shown_team` (RB6): after `_arena`, set the local player's team to 7 in the live simulation; `_result_text({"status": "won", "winner": 7})` is `"Defeat"` until `main._refresh()`, then `"Victory"`. K4's team line (`test_skirmish_scene.gd:135-136`) gains `main._refresh()` after the team edit.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=input_takes_no_snapshot sh tools/run_tests.sh > build/sb/t2.log 2>&1; echo exit=$?` → exit 1, RB1 and RB2 report snapshot counts above 0; RB6 fails on its first check.
- [ ] **Step 3: Implement.** Replace each `_screen.driver.sim.snapshot()` in `orders.gd` with `_screen.shown_state`, entity loops with `_unit(id)` lookups over the ids the code already iterates (selected ids, picked ids), `match_over()` (:31) with `_screen.shown_over()`, `tick()` (:283) with `_screen.shown_state.tick`; `match_screen.gd` :131 and :263 tick from `shown_state.tick`, :152 `shown_over()`; `hud.gd` :163 as in Interfaces. `_matching_ids` compares `_unit(other).get("kind")` and skips `inside`. Leave `match_screen.gd:117,121,138,182-191,281-282` and `orders.gd:286` alone (SB2, SB3).
- [ ] **Step 4:** Rerun Step 2's command → exit 0. Then `WARGRID_TEST_ONLY=scene sh tools/run_tests.sh > build/sb/t2s.log 2>&1; echo exit=$?` → exit 0. Fix red setup per the Global Constraints rule only.
- [ ] **Step 5:** Lint and warnings exit 0; update the resume record; commit `Read the shown view on input`.

### Task 3: Input re-shows the view; offline submit without a snapshot (SB1)

**Files:**
- Modify: `game/scripts/match/match_screen.gd` (`_submit` :265-272, new `_reshow`), `game/scripts/match/orders.gd` (`_screen._refresh()` at :108, 157, 169, 224, 227, 267, 273, 279, 300, 310, 327, 343), `game/scripts/match/offline_driver.gd` (`submit` :40-50, comment :26)
- Test: `game/tests/test_base_scene.gd`, `game/tests/test_skirmish_scene.gd` (OD1 :827-839 unchanged), `game/tests/test_online_scene.gd`, tests that need `sync_sequence` (known: K13 `test_skirmish_scene.gd:579`; RB1, whose `Fixture.build` sends local-player commands)

**Interfaces:**
- Consumes: `shown_state` (Task 2).
- Produces in `test_base_scene.gd`: `func sync_sequence(main) -> void`: raises `main.driver._sequence` past the local player's entry in `main.driver.sim.snapshot().last_sequences` (the sync the driver drops, moved to the tests that inject commands).
- Produces in `match_screen.gd`: `func _reshow() -> void`: `_show(shown_state)` then `hud.place_economy()`. `_refresh()` stays the only builder of a new `view_state()` (tick path, `_ready`, `_restart`, tests).
- Produces in `offline_driver.gd`: `submit` stamps `tick` = `payload.get("tick", sim.tick())`, `player`, `sequence = _sequence`, and adds 1 to `_sequence` only on an accepted command (as today); no `snapshot()`, no `last_sequences` read.

```text
Task: no view_state() or snapshot() per input event
Owns: match_screen.gd _submit/_reshow, orders.gd refresh call sites, offline_driver.gd submit
Invariant: the HUD after any input equals what _refresh() would show for the same tick; OD1 stamps unchanged
Boundary: an input in the frame between a step and its deferred refresh (RB5)
Red: RB1/RB2 view_state count > 0; RB3 snapshot count > 0
Green: RB1, RB2, RB3, RB5, RB7, RF1, RF2, RF5, RF6, RF8, full suite
Stop: an expected HUD text would change
```

- [ ] **Step 1: Write the failing tests.**
  - RB1 and RB2 gain `Profiler.calls(&"view_state") == 0` (messages `"RB1 … view states"`, `"RB2 …"`).
  - `test_skirmish_scene.gd` `test_offline_submit_takes_no_snapshot` (RB3): `OfflineDriver.new(1)` with `Skirmish.create(false)`, one rifleman, `start_match`; profiler around three `driver.submit` calls (stop, refused attack on 999999, stop). Assert snapshot calls 0 and the OD1 stamps `[[tick, 1, 0], [tick, 1, 1]]`.
  - `test_base_scene.gd` `test_hover_before_deferred_refresh` (RB5): RF8's setup (`test_base_scene.gd:307-320`, two tick-0 builds, the second short of credits), then one `_physics_process`, a `hover` in the same frame, two `await runner.process_frame`. Assert the status contains `"Insufficient credits"` and `main._view._state.tick == main.driver.sim.tick()`.
  - `test_skirmish_scene.gd` `test_idle_offline_ticks_take_no_snapshot` (RB7): `Skirmish.create()` (bot seat 2) in the scene, 300 direct `_physics_process(0.0)` calls under the profiler: `snapshot` 0, `view_state` 300 (bots read `bot_state()`, its own zone).
  - `test_online_scene.gd` `test_online_snapshot_per_hash_tick` (RB8): online seat 1, peer packets to tick 64, the profiler on after `start`, run until the simulation passes tick 60 → `snapshot` calls == 2 (hash ticks 30 and 60).
- [ ] **Step 2:** `WARGRID_TEST_ONLY=snapshot sh tools/run_tests.sh > build/sb/t3.log 2>&1; echo exit=$?` → exit 1 on RB1/RB2 view-state counts and RB3; RB5, RB7 and RB8 may already pass (guards; record it).
- [ ] **Step 3: Implement** per Interfaces: the twelve orders call sites and `_submit` call `_reshow()`; `offline_driver.gd` drops the snapshot and the `last_sequences` loop; replace the `:26` comment's reason if it no longer holds.
- [ ] **Step 4:** Step 2's command → exit 0. Full suite: `sh tools/run_tests.sh > build/sb/full3.log 2>&1; echo exit=$?` → exit 0. A red case from a sequence clash ("Sequence must increase") gets `helper.sync_sequence(main)` after its direct sends; list every such case in the verification file.
- [ ] **Step 5: SB1 evidence.** Traces as Task 1 Step 3 into `build/sb/sb1/`, then `python3 tools/compare_replays.py build/sb/base/replay.tsv build/sb/sb1/replay.tsv`, the same for `economy` and `combat`, and `--interval 200 --rows 100` for `team` → `REPLAYS MATCHED` each. `git diff <base> --stat -- game/scripts/simulation protocol` → empty. Record all with the tree; lint, warnings; commit `Re-show the view on input`.

### Task 4: Offline refusals arrive with the next step (SB2)

**Files:**
- Modify: `game/scripts/match/offline_driver.gd` (`create` :17-21, `step` :31-35, `submit`), `game/scripts/match/match_screen.gd` (`_submit`)
- Test: `game/tests/test_skirmish_scene.gd` (OD1 :827-839, K4 :137-140), `game/tests/test_base_scene.gd` (Bs2 :87-90, Bs5 :199-218), `game/tests/test_order_voice.gd` (OV8 :147-160), `game/tests/test_playtest_overlay.gd` (PO6 :216-217), `game/tests/test_announcer.gd` (AN20 :291-297), `test_skirmish_scene.gd` DA5 :487

**Interfaces:**
- Produces in `offline_driver.gd`: `var _refusals := PackedStringArray()`; `submit` returns `{"ok": true, "error": ""}` always and appends a refused command's `error` to `_refusals`; `step(after_tick)` takes `_refusals`, clears it, runs today's body and returns the taken list; `create` clears it.
- Produces in `match_screen.gd`: `_submit(payload)`: `_show_hint`, `driver.submit`, `hud.note = ""`, `_reshow()`, `_playtest.observe_command(payload)`, `_sound.order(payload)` (the refusal branch goes: neither driver refuses at submit any more).

```text
Task: an offline refusal reaches the player one step later through _step_simulation, as online
Owns: offline_driver.gd submit/step/create, match_screen.gd _submit, the listed tests
Invariant: the same commands enter the simulation on the same tick in the same order (traces equal)
Boundary: refusal while paused (RA5); restart with a held refusal (RA4)
Red: RA1 note set at submit
Green: RA1-RA5, rewritten OD1, K4, Bs2, Bs5, OV8, PO6, AN20, DA5; full suite
Stop: a trace, pin or IC row moves
```

- [ ] **Step 1: Write the failing tests** (`test_skirmish_scene.gd` unless named):
  - RA1 `test_offline_refusal_next_step`: `_arena`; `_submit({"type": "move", "entity_ids": [ids.tank], "target": [-5.0, -5.0]})` → `hud.note == ""` and no pending `move`; after `_physics_process(0.0)` `hud.note == "Rejected: Target outside map"` (`simulation.gd:305`) and the sound director saw one rejection (`_cues` as in `test_order_voice.gd`); HUD layout: the economy buttons sit below every status line with the longer `Rejected:` note, the check of N3 (`test_online_scene.gd:73-77`).
  - RA3 `test_two_submits_one_refused`: a valid stop and a refused attack in one frame → one pending stop; the next step returns exactly one refusal; the note is that refusal.
  - RA4 `test_restart_drops_held_refusal`: refused submit, then the Restart path (`_restart`), then one physics call → no `Rejected:` in the status.
  - RA5 `test_refusal_waits_for_unpause`: refused submit, open the pause menu, two physics calls → note empty; close, one physics call → the refusal note, once (`_step_simulation` got one error).
  - Rewrites (named assertions only): OD1 `refused.ok` is now true and `driver.step(func() -> void: pass)` returns the refusal; K4 "terminal match accepts no orders" checks no new pending command and, after one physics call, `"Rejected: Match ended"`; Bs2 "invalid remains mode reason" gains a physics call after the hover (recapture `before` after it) and checks the `Rejected:` note after a second physics call; Bs5 "immediate error persists refresh" checks the note after one physics call; OV8 follows OV9 (`test_order_voice.gd:162-175`): the order speaks at submit, the refusal beeps after one physics call and the line stays; PO6 "a rejected gather ticks nothing" becomes "a refused gather is observed, as online" (collect ticked); AN20 and DA5 compare the note after one physics call with the `Rejected: ` prefix.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=refus sh tools/run_tests.sh > build/sb/t4.log 2>&1; echo exit=$?` → exit 1, RA1 fails on `hud.note == ""`.
- [ ] **Step 3: Implement** per Interfaces.
- [ ] **Step 4:** Step 2's command → exit 0; `WARGRID_TEST_ONLY=scene`, `=order_voice`, `=playtest`, `=announcer` → exit 0; then the full suite → exit 0.
- [ ] **Step 5:** Lint, warnings; resume record; commit `Answer offline orders one tick later`.

### Task 5: Placement preview answered after the next step (SB2)

**Files:**
- Modify: `game/scripts/match/orders.gd` (`reset` :53-61, `_placement_input` :135-138, `_enter_placement` :263-273, `_clear_placement` :275-279, `_update_preview` :281-287), `game/scripts/match/match_screen.gd` (`_show`), `game/scripts/match/offline_driver.gd`, `game/scripts/match/online_driver.gd` (`create` :33-37 plus P2.2's reset list, `step` :52-66)
- Test: `game/tests/test_base_scene.gd` (Bs2, Bs6 :221-236), `game/tests/test_online_scene.gd`

**Interfaces:**
- Produces in both drivers: `func request_preview(request: Dictionary) -> void` (`{player, builder_id, kind, origin: Vector2i}`; `{}` cancels and clears the answer); `func preview_answer() -> Dictionary` (`{kind, origin, ok}` of the last answered request, `{}` when none); after a frame that stepped (offline: after `after_tick`; online: after the catch-up loop when at least one tick ran), a pending request is answered once with `sim.preview_build(...).ok` and cleared. `create` clears request and answer. One line `shortcut: duplicated in both drivers, SB3's run_job takes it over` above each copy.
- Produces in `orders.gd`: `var _answer: Dictionary = {}`; `func show_preview(answer: Dictionary) -> void` (called by `_show` after `orders.prune`): when placing and `answer.kind == _placement_kind`, store it as `_answer`; when also `answer.origin == _preview_origin`, redraw the ghost with `answer.ok`. `_update_preview` keeps its key `[kind, origin, shown tick]`, draws the cells at once with `_answer.get("ok", false)` and calls `request_preview` instead of `preview_build`. `_enter_placement` and `reset` clear `_answer`; `_clear_placement` calls `request_preview({})`. Click (:137-138): keep placement only when `_answer` has this kind and origin and `ok == false`; otherwise clear.

```text
Task: the ghost's colour comes from the driver's answer after the next step, in both modes
Owns: orders.gd preview functions, match_screen.gd _show, both drivers' preview functions
Invariant: preview_build is pure (test_construction.gd Cn1), so traces and pins stay; at most one preview per (kind, origin, shown tick)
Boundary: online stall (RP4); restart and rematch (RP5)
Red: RP1 colour from a synchronous preview
Green: RP1-RP5, Bs2, Bs6, IC1, IC2; full suite
Stop: an IC row changes
```

- [ ] **Step 1: Write the failing tests** (`test_base_scene.gd` unless named):
  - RP1 `test_ghost_colour_after_step`: world with builder 1 selected; key 1 and hover a free cell → `_preview_cells` set at once and `_preview_valid == false`; one physics call → `_preview_valid == true`; hover the builder's own cell (Bs2's invalid spot, world `(4.25, 4.25)`) → cells moved, still `true`; one physics call → `false`.
  - RP2 `test_click_keeps_mode_on_shown_refusal`: hover a blocked cell, one physics call, click → placement kept; hover a free cell, click without a physics call → placement cleared and one pending `build`.
  - RP3 Bs6 rewritten: five hovers across one cell, one physics call → `navigation_builds()` grows by at most 1; a new cell and a physics call → at most 2; no physics call → 0 (the screen computes nothing).
  - RP4 `test_online_scene.gd` `test_online_preview_waits_for_step`: online seat 1 with peer packets to tick 12, run 8 frames; key 1, hover → `preview_answer()` empty; run with no further peer packets (waiting) → still empty and the ghost keeps its colour; add packets, run 1 → answer present and the ghost colour equals it.
  - RP5 `test_restart_clears_preview`: answer received, Restart → `preview_answer()` empty, `_answer` empty, `_preview_cells` empty (K4's restart line already checks the cells); online: `create` re-entered (P2.2 rematch fixture) → `preview_answer()` empty.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=preview sh tools/run_tests.sh > build/sb/t5.log 2>&1; echo exit=$?` → exit 1, RP1 fails on its first `_preview_valid` check.
- [ ] **Step 3: Implement** per Interfaces.
- [ ] **Step 4:** Step 2's command → exit 0; `WARGRID_TEST_ONLY=input_script` (IC1, IC2) → exit 0 with rows unchanged; full suite → exit 0.
- [ ] **Step 5:** Lint, warnings; resume record; commit `Answer the placement preview one tick later`.

### Task 6: Docs

**Files:**
- Modify: `docs/guide/01-big-picture.md` (:23 "None calls `snapshot()`…", the flows at :37 and :50, :100, "Where in the code" :114-116, footer :135), `docs/guide/04-the-tick.md` (offline submit steps 2-3 at :63-66: the answer one tick later; footer :180), `docs/guide/05-presentation.md` (hand-off :43-44 and `shown_state`; HUD and input :157-158: input reads the shown view, re-show; playtest helper :159: refused offline orders are observed; footer :229), `docs/guide/07-economy.md` (:108 preview flow), `docs/guide/11-multiplayer.md` ("Where in the code" `online_driver.gd` line: `request_preview`; footer), `docs/reference/sim-interface.md` (:45 who calls `snapshot()`, :57 `preview_build` caller), `docs/reference/sim-boundary-verification.md`

**Interfaces:** none.

- [ ] **Step 1:** Update each passage; keep the guide's order (payoff first, terms explained where they appear); set each `Checked against` footer to the branch head.
- [ ] **Step 2:** `sh tools/check_public.sh > build/sb/public.log 2>&1; echo exit=$?` → exit 0; check every link and path:line the edits cite with `rg -n`.
- [ ] **Step 3:** A fresh docs reviewer (diff plus the code files named in the footers, no repo-wide search) checks every code claim in the changed passages; fix findings.
- [ ] **Step 4:** Resume record; commit `Document reads on request and next-tick answers`.

### Task 7: Gate checks

**Files:** `docs/reference/sim-boundary-verification.md`, `docs/reference/perf-history.csv` and generated tables (by the tools only).

- [ ] **Step 1:** `sh tools/run_checks.sh > build/sb/checks.log 2>&1; echo exit=$?` → `CHECKS PASSED 5`.
- [ ] **Step 2:** Full suite with traces into `build/sb/sb2/` (Task 1 Step 3 command), then `compare_replays.py` base against sb2 for replay, economy, combat and team → `REPLAYS MATCHED` each.
- [ ] **Step 3:** `NETPLAY_OUT="$PWD/build/sb/sb2/netplay" sh tools/run_netplay.sh match > build/sb/sb2/netplay.log 2>&1; echo exit=$?` → `NETPLAY PASSED match`; `python3 tools/compare_replays.py --interval 30 --rows 0 build/sb/base/netplay/s1.tsv build/sb/sb2/netplay/s1.tsv` → matched. `sh tools/run_team_match.sh > build/sb/sb2/team_match.log 2>&1; echo exit=$?` → exit 0.
- [ ] **Step 4:** `git diff <base> --stat -- game/scripts/simulation protocol` → empty.
- [ ] **Step 5: Benchmark**, alone, `uptime` at start and end (load above 2.5: say so and wait): `PERF_LABEL="Sim boundary SB1-SB2" sh tools/run_benchmark.sh > build/sb/bench.log 2>&1; echo exit=$?`; record the row per the [ledger](../../reference/performance.md). Never loosen a budget; an accepted exceeded row is recorded with its numbers. No rendered rerun: drawing code untouched (state it).
- [ ] **Step 6:** Resume record with every result and its tree; commit `Record the SB1-SB2 gate`.

## Stop gates (each waits for the owner)

1. **Whole-branch review** by one fresh-context reviewer on the strongest available model: diff since the base, the design, this plan, the verification file; it names per new test the production change that makes it fail and checks the interaction table row by row. Fix critical and important findings test-first; record rulings for the rest.
2. **`/ponytail-review`** on the diff (over-engineering only); apply cuts; rerun the touched checks and the full suite.
3. **Owner's playtest** offline and online: refusal one tick later, order click before the refusal beep, ghost colour lag, placement kept on a red click.
4. Push, PR, merge and any deploy wait for the owner.

## Later packages (outline; each gets its own plan on its night)

- **SB3 Pump inline, offline.** Scope: `game/scripts/match/sim_pump.gd` (Job, Note, Slot, `run_job`), the offline driver posts one job per physics frame and drains in `_process`; issue moves into the job, so `submit` stamps the sequence per submit (OD1 stamps become `[t,1,0],[t,1,2]`, gaps legal, `simulation.gd:210`); `Job.bots = [2]` through `Skirmish.issue_opponents`; job 0 note with `starts` for `_reset_camera` (`match_screen.gd:117,121`); match record as a query job (`:138`); cache freeze with `add_test_kind` resets and a `Combat._reach_by_kind` reset; ring off offline; `tools/test_sim_boundary.py` check for `.sim` / `live()` in `match/` and `presentation/`; tests move to `pump.live()` and `sync_sequence` to the pump's helper; tests that read `pending_commands` after a submit read the driver's queued commands. Exit: pump against direct digests over 900 ticks; skirmish and team traces equal; slot invariant tests; ledger row; Deck view-build split reported. Gives P4 current and previous slots and P5/P6 a single owner.
- **SB4 Online on the pump.** Scope: `Lockstep.take` / `record`, `finish_tick(tick, state, digest := "")`, commands logged on drain, ring and desync report by query job (asynchronous in worker mode), `match_log` from CURRENT (`online_driver.gd:96`), P2.2 rematch re-creates the pump. Exit: `test_lockstep.gd` and `run_lockstep.gd` untouched and green; a loopback test of two drivers; `run_netplay.sh` match and rematch; `sh tools/run_conformance.sh`; vectors untouched. Gives fog and minimap online one source.
- **SB5 Worker mode, flag off.** Scope: thread, `WARGRID_SIM_THREAD` and the pause-menu toggle ("Takes effect after a restart", remembered, offline and online) with a headless layout test; release Web preset threaded and COOP/COEP in `web/sws.toml`; both-mode pump tests, fault and stall; `worker_ab.py` into `tools/` with its test; `determinism-rules.md:14` reworded. Exit: digests equal on four loads in both modes; the scene suite green under the flag; a fault ends the match within 5 s; loopback online with one worker client. Gives the decision row.
- **SB6 Decision rows (attended).** Deck Firefox, three or more interleaved runs per arm; a mixed online match; a fault probe in the release web build. Exit: the go rule as decided. Gives the day release that turns the worker on.

## Self-review notes

- Spec coverage: SB1 read list (Tasks 2, 3; per-match and step-path reads named as SB3/SB4 in the outline), counter (Task 3), exit counts (RB1, RB2, RB3, RB7, RB8), digests and traces (Tasks 3, 7); SB2 refusals (Task 4), preview and ghost rule (Task 5), same texts behind `Rejected: ` and same sounds (Task 4 rewrites), two-tick merge (RF8, RB5).
- Not planned here: slice-2 bot work, the fork-join experiment, anything needing a pump.
- Owner checks: the `Rejected: ` prefix offline, PO6's checklist change, the placement-click rule, and the `sync_sequence` test helper replacing the driver's old `last_sequences` sync.
