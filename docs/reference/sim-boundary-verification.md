# Sim boundary SB1-SB2 verification

Plan: [sim boundary SB1-SB2](../superpowers/plans/2026-11-15-sim-boundary-sb1-sb2.md). Resume record below is overwritten at each checkpoint; evidence rows are append-only.

```text
Resume record (updated 2026-11-15 night, stop gate 2 done)
Branch / base commit / working-tree state: sim-boundary-sb1-sb2 / f838f793a0cfccfbbba7ce70d3a59fcaddeb3f2a (P2.2 merged, ee2f353 is an ancestor) / clean at 5696065
Last green task / next incomplete task: Tasks 1-8 committed; gates 1 and 2 done / gate 3 (owner playtest)
Changed paths since last commit: docs/reference/sim-boundary-verification.md
Last command / cases / checks / failures / exit / marker: full suite with traces into build/sb/final/, 980 cases, 146452 checks, 0 failures, exit 0, TESTS PASSED 146452; REPLAYS MATCHED x4 vs base; netplay match and team match exit 0; run_checks CHECKS PASSED 5
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: local commits per task pre-authorized (night run); IC1 row 19 inspected-enemy HP/order text may change (user, 2026-11-15); S3 and OV11 fixture changes accepted (user, 2026-11-15); no rendered benchmark rerun, world_view.gd is not touched; the benchmark is not rerun after the gate fixes (input code only)
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: all gates done up to 2; gate 3 (owner playtest) and gate 4 (push/PR/merge) wait for the owner.
```

## Evidence

| Date | Command | Result | Tree |
|---|---|---|---|
| 2026-11-15 | `sh tools/run_tests.sh` with the four `WARGRID_*_REPLAY_TRACE` variables into `build/sb/base/` | exit 0, CASES 955 CHECKS 146367 FAILURES 0, `TESTS PASSED 146367` | base f838f79, clean |
| 2026-11-15 | `NETPLAY_OUT=build/sb/base/netplay sh tools/run_netplay.sh match` | exit 0, `NETPLAY PASSED match 10.6 s`; `s1.tsv` kept | base f838f79, clean |
| 2026-11-15 | `sh tools/run_team_match.sh` | exit 0, `TEAM MATCH won tick=38786 winner=2 units_peak=268` (pin at `tools/run_team_match.sh:13`), `TEAM PATHS PASS` | base f838f79, clean |
| 2026-11-15 | `WARGRID_TEST_ONLY=sb1_` (red first: `RB3 ... got 3`, exit 1; then green) | exit 0, CASES 1 CHECKS 2 FAILURES 0 | Task 2, uncommitted |
| 2026-11-15 | `WARGRID_TEST_ONLY=scene` (red first: 11 failures, "Sequence must increase") | exit 0, CASES 114 CHECKS 3536 FAILURES 0, `TESTS PASSED 3536` | Task 2, uncommitted |
| 2026-11-15 | `=order_voice` / `=playtest` / `=announcer` | exit 0 each: 14/97, 44/930, 21/68 cases/checks | Task 2, uncommitted |
| 2026-11-15 | `run_lint.sh`, `run_warnings.sh`, `test_sim_boundary.py` | exit 0, 0, 0 | Task 2, uncommitted |
| 2026-11-15 | Task 2 review merge rerun: `sb1_`, `scene`, `order_voice`, `playtest`, `announcer`, `run_lint.sh`, `run_warnings.sh` (Sonnet and Codex reviews: no critical or important findings) | exit 0 each; 2/3536/97/930/68 checks, 0 failures | Task 2, uncommitted |
| 2026-11-15 | `WARGRID_TEST_ONLY=sb1_` (red first: RB1 11 snapshots, RB2 6, RB4 script error, RB6, RB9 missing `shown_over`; then green) | exit 0, CASES 6 CHECKS 15 FAILURES 0 | Task 3, uncommitted |
| 2026-11-15 | `WARGRID_TEST_ONLY=scene` (one red setup: N1 swapped the simulation without `_refresh()`; fixed with `main._refresh()`) | exit 0, CASES 119 CHECKS 3549 FAILURES 0 | Task 3, uncommitted |
| 2026-11-15 | full `sh tools/run_tests.sh`, `run_lint.sh`, `run_warnings.sh`, `test_sim_boundary.py` | exit 0 each; CASES 961 CHECKS 146374 FAILURES 0, `TESTS PASSED 146374` | Task 3, uncommitted |

| 2026-11-15 | Task 3 review merge rerun: RB4 test tightened (shown view picks the dead unit before input, `_refresh()` before the prune check); `sb1_`, `scene`, `run_lint.sh`, `run_warnings.sh` (Sonnet: none; Codex: one P2 test fix) | exit 0 each; 16 and 3550 checks, 0 failures | Task 3, uncommitted |
| 2026-11-15 | `WARGRID_TEST_ONLY=sb1_` (red first: RB1 8 view states, RB2 6, RB5 director consumed ticks 1 and 2 during the hover; RB7 and RB8 already green as guards; then green) | exit 0, CASES 9 CHECKS 26 FAILURES 0, `TESTS PASSED 26` | Task 4, uncommitted |
| 2026-11-15 | full `sh tools/run_tests.sh` | exit 0, CASES 964 CHECKS 146388 FAILURES 0, `TESTS PASSED 146388`; no expected value changed | Task 4, uncommitted |
| 2026-11-15 | SB1 evidence: full suite with the four trace variables into `build/sb/sb1/`; `compare_replays.py` base vs sb1 for replay, economy, combat, team (`--interval 200 --rows 100`); `git diff f838f79 --stat -- game/scripts/simulation protocol` | exit 0, `TESTS PASSED 146395`; `REPLAYS MATCHED` 1200, 1200, 1200, 100; diff empty | Task 4, uncommitted |
| 2026-11-15 | `run_lint.sh`, `run_warnings.sh`, `test_sim_boundary.py` | exit 0, 0, 0 | Task 4, uncommitted |
| 2026-11-15 | `WARGRID_TEST_ONLY=sb2_` (red first: RA1 note at submit, RA2 refusal not prefixed and accepted gather ticked at submit, RA3 x4 note cleared, RA5, RA6 fixture then missing `_held`, RA7/RA8 missing `_awaiting_build`; then green) | exit 0, CASES 8 CHECKS 28 FAILURES 0 | Task 5, uncommitted |
| 2026-11-15 | `=order_voice` / `=playtest` / `=announcer` after the named rewrites | exit 0 each: 14/98, 46/937, 21/68 cases/checks | Task 5, uncommitted |
| 2026-11-15 | `=scene` / `=input_script` | exit 1 each, only IC1 red (128/3589, 2/34 cases/checks, 1 failure); IC2 unchanged and green | Task 5, uncommitted |
| 2026-11-15 | full `sh tools/run_tests.sh`; `run_lint.sh`, `run_warnings.sh`, `test_sim_boundary.py`; `git diff f838f79 --stat -- game/scripts/simulation protocol` | exit 1, CASES 972 CHECKS 146422 FAILURES 1 (IC1); 0, 0, 0; diff empty | Task 5, uncommitted |
| 2026-11-15 | IC1 re-pinned (row 19 allowed, user 2026-11-15), OV11 also appends its older rejection to `stepped_results`; `=input_script`, `=order_voice` | exit 0: 2/34, 14/98 cases/checks | Task 5, uncommitted |
| 2026-11-15 | SB2 evidence: full suite with the four trace variables into `build/sb/sb2/`; `compare_replays.py` base vs sb2 for replay, economy, combat, team (`--interval 200 --rows 100`); `git diff f838f79 --stat -- game/scripts/simulation protocol`; `run_lint.sh`, `run_warnings.sh`, `test_sim_boundary.py` | exit 0, CASES 972 CHECKS 146429 FAILURES 0, `TESTS PASSED 146429`; `REPLAYS MATCHED` 1200, 1200, 1200, 100; diff empty; 0, 0, 0 | Task 5, uncommitted |
| 2026-11-15 | `WARGRID_TEST_ONLY=sb2_` (red first: RP1 first `_preview_valid` check, the rest missing `preview_answer`/`request_preview`; then green) | exit 0, CASES 16 CHECKS 52 FAILURES 0, `TESTS PASSED 52` | Task 6, uncommitted |
| 2026-11-15 | Mutation: `create` in both drivers without the preview reset; `WARGRID_TEST_ONLY=drops_pending` | exit 1, both RP5 checks fail (offline restart, online rematch); restored | Task 6, uncommitted |
| 2026-11-15 | `=input_script`; `run_lint.sh`, `run_warnings.sh`, `test_sim_boundary.py` | exit 0, 2/34 cases/checks (Task 5's rows); 0, 0, 0 | Task 6, uncommitted |
| 2026-11-15 | full `sh tools/run_tests.sh`; `git diff f838f79 --stat -- game/scripts/simulation protocol` | exit 0, CASES 979 CHECKS 146443 FAILURES 0, `TESTS PASSED 146443`; diff empty (baseline on 60d9a5c: 972/146423) | Task 6, uncommitted |
| 2026-11-15 | Task 6 review merge: RP8 strengthened (peer builds on the spot in the second tick); mutation `_answer_preview()` inside the catch-up loop; then `sb2_`, `=input_script`, full suite, lint, warnings | mutation exit 1 (RP8 fails), restored; 16/52 exit 0; 2/34 exit 0; CASES 979 CHECKS 146443 FAILURES 0 exit 0; 0, 0 | Task 6, uncommitted (production code unchanged by the merge) |
| 2026-11-15 | Task 8 gate: `sh tools/run_checks.sh` | exit 0, `CHECKS PASSED 5` | 0addc23, clean |
| 2026-11-15 | Task 8 gate: full suite with traces into `build/sb/sb2/`; `compare_replays.py` base vs sb2 (replay, economy, combat; team with `--interval 200 --rows 100`) | exit 0, `TESTS PASSED 146450`; `REPLAYS MATCHED` 1200, 1200, 1200, 100 | 0addc23, clean |
| 2026-11-15 | Task 8 gate: `NETPLAY_OUT=build/sb/sb2/netplay sh tools/run_netplay.sh match`; `compare_replays.py --interval 30 --rows 0` base vs sb2 `s1.tsv`; `sh tools/run_team_match.sh` | exit 0, `NETPLAY PASSED match 14.6 s`; `REPLAYS MATCHED 301`; exit 0, `TEAM MATCH won tick=38786 winner=2 units_peak=268`, `TEAM PATHS PASS` | 0addc23, clean |
| 2026-11-15 | Task 8 gate: `git diff f838f79 --stat -- game/scripts/simulation protocol` | empty | 0addc23, clean |
| 2026-11-15 | Task 8 gate: `PERF_LABEL="Sim boundary SB1-SB2" sh tools/run_benchmark.sh` alone (load 1.49 at start, 1.27 at end; no other Godot) | exit 0, `BENCHMARK PASSED 2`, `LOCKSTEP BENCHMARK PASSED 1`; movement open p95 0.765 / dense 0.743 PASS; combat `open` p95 1.875, `dense` 1.836, `hordes300` 2.899 OVER BUDGET 1.82 (already marked exceeded in the ledger on d90f41a, regression ceilings held, no budget changed); other combat rows PASS; 13 rows recorded in `perf-history.csv`, status blocks regenerated (uncommitted). No rendered rerun: drawing code untouched | 0addc23, clean before the run |
| 2026-11-15 | Gate 1 (Opus pass): RA9 `test_sb2_online_refusal_keeps_new_gesture`, `WARGRID_TEST_ONLY=refusal_keeps_new_gesture` (red first: both checks, the selection release and the attack-move click each sent a build); then `orders.answered` reopens only when not `busy()` and not in attack-move; `=sb2_` | red exit 1, 2 failures; green exit 0, CASES 17 CHECKS 54 FAILURES 0 | a7cd946 plus gate 1 fix, uncommitted |
| 2026-11-15 | Gate 1: full suite with traces into `build/sb/sb4/`; `compare_replays.py` base vs sb4 (replay, economy, combat; team `--interval 200 --rows 100`); `run_lint.sh`, `run_warnings.sh`, `check_public.sh`; `git diff f838f79 --stat -- game/scripts/simulation protocol` | exit 0, CASES 980 CHECKS 146452 FAILURES 0, `TESTS PASSED 146452`; `REPLAYS MATCHED` 1200, 1200, 1200, 100; 0, 0, 0; empty | a7cd946 plus gate 1 fix, uncommitted |

`sync_sequence(main)` added after direct sends in: `test_production_ui` (Bs3, after the builds), `test_base_scene.gd` CancelBuild case (after the foundation send), M3 case (after the factory build), `test_rally_input_and_marker` (R1), `test_hud_strings_use_display_names` (N1), `test_frc_laborer_right_click_pile` (K13). Task 3 added `main._refresh()` after the sim swap in N1 and before K4's team line. Expected values unchanged.

Base traces: `build/sb/base/{replay,economy,combat,team}.tsv`, `build/sb/base/netplay/s1.tsv` (untracked). No rendered benchmark rerun: drawing code (`world_view.gd`) is not touched.

## Line map

Plan lines are `main` 32748c8 (before P2.2); right column is the base f838f79. A function name is the stable anchor. Files not listed (`orders.gd`, `offline_driver.gd` lines before :60, `simulation.gd`, `presentation_clock.gd`, `sound_director.gd`, all docs except `11-multiplayer.md`) are unchanged since 32748c8 and keep the plan's numbers.

| Plan cite | Base location |
|---|---|
| `match_screen.gd` `playtest_context` :131 | :135 |
| `match_screen.gd` `_step_simulation` :141-146 (refusal text :146) | `_step_simulation` :147; the `"Rejected: "` text is at :152 |
| `match_screen.gd` `_escape_pending` :152 | :157 (`driver.sim.match_over()` :158) |
| `match_screen.gd` `_show` :248-259 | :265 (`driver.sim.view_state()` :257 in `_refresh` :256) |
| `match_screen.gd` `_show_hint` :263 | :278 (`driver.sim.tick()` :280) |
| `match_screen.gd` `_submit` :265-272 | :282 |
| `match_screen.gd` other `driver.sim` readers | :123, :127, :137, :144, :194, :202, :204, :207, :257, :298, :299 (the lines cited in the plan shift by 0-16; use `rg -n 'driver\.sim' game/scripts/match`) |
| `hud.gd` `_result_text` / :163 | `_result_text` :155-158; `team_of` read at :158 |
| `hud.gd` `_refresh_hud` :40-47 | :38 (the `Result` label and `Restart` button are gone; `ResultPanel` replaces them) |
| `hud.gd` `_economy_hud` :50-54 | :46 |
| `hud.gd` `_unit_record` | :125 |
| `offline_driver.gd` `submit` :40-50, comment :26 | unchanged (:40, :26); `step` :31 |
| `online_driver.gd` `step` :52-66 | :77 |
| `online_driver.gd` `_new_rejections` :71-77 | :109 |
| `online_driver.gd` `submit` | :117 |
| `online_driver.gd` `create` | :53-61 |
| `orders.gd` all cites (:31, :151, :232-238, :247, :259-261, :283, :291-301, :314-322, :332, :339, :359-364, `_refresh()` at :108, 157, 169, 224, 227, 267, 273, 279, 300, 310, 327, 343) | unchanged: `rg -n 'driver\.sim' game/scripts/match/orders.gd` and `rg -n '_refresh\(\)' game/scripts/match/orders.gd` list the same lines; `_matching_ids` :229, `_placement_input` :125, `_clear_placement` :275, `_update_preview` :281, `reset` :53 |

Findings that change later tasks:

- `_result_text` is still in `hud.gd` (:155) and still reads `_screen.driver.sim.team_of(local_player)`; `match_screen.gd:145` (session record) also calls `hud._result_text(state.match)`, which stays a caller with its own `state`.
- `ResultPanel` (`game/scripts/match/result_panel.gd`) reads no `driver.sim`. `hud.gd:70` hands it `driver.rematch_line()` and `driver.can_play_again()`, which are driver calls, not simulation reads. No new reader joins Task 3's list.
- Online driver seat field: `_seat` (`online_driver.gd:28`), set at :36; also `_phase`/`take_rematch` (:144) exist.
- `OnlineDriver.create` reset list (:53-61): `_map_path`, `_starts`, `_seed`, `_finished = false`, `_friend_again = false`, `_rejections_seen = 0`, `_credit = 0`, then a new `sim`.
- N3 layout check after P2.2 (`test_online_scene.gd:77-78`): the economy-below-status check stays at :77; the second line is now `not main.get_node("HUD/ResultPanel").visible` (:78), so `HUD/Restart` is gone.
- P2.2 rematch fixture: `test_rematch_builds_new_match` (`test_online_scene.gd:377`).

Test map by check label (plan line to base line):

| Label | Base location |
|---|---|
| K4 team line (plan `test_skirmish_scene.gd:135-136`) | `test_skirmish_scene.gd:141-142` (`_players[main.local_player].team = 7`, then `_result_text` check) in `test_match_hud_and_restart` :125 |
| K13 (plan :579) | `test_skirmish_scene.gd:769-787` (`Fixture.send` build for the laborer :769, gather check :776) |
| RF2 fixture (plan :601-605) | `test_one_snapshot_per_refresh`, `test_skirmish_scene.gd:791-795` |
| RF8 (plan `test_base_scene.gd:307-318`) | `test_rejection_survives_two_steps`, `test_base_scene.gd:307-319` (label at :318) |
| Bs2, Bs5, Bs6 | `test_base_scene.gd` :80-104, :206-217, :229-234 |
| OV8 | `test_order_voice.gd:152-158` |
| AN20 | `test_announcer.gd:295-297` |
| PO6, PO9 | `test_playtest_overlay.gd:212-239`, `:354-383` |
| H5 (online rejection) | `test_online_scene.gd:679` |
| IC1 / OD1 | `test_skirmish_scene.gd:936-1013` / `:1028` |
| IC2 | `test_online_scene.gd:1245-1300` |
| N3 | `test_online_scene.gd:77-78` (the `test_navigation.gd` and `test_horde.gd` hits are unrelated labels) |
| RF5 | `test_base_scene.gd` just above `test_rejection_survives_two_steps` |
| `sync_sequence` | not yet present (Task 2 adds it to `test_base_scene.gd`) |

Task 7 doc lines (no doc changed since 32748c8 except `11-multiplayer.md`, which P2.2 grew by 55 lines): `01-big-picture.md` :23, :37, :50, :100, :114, footer :135; `04-the-tick.md` :61, :66, footer :180; `05-presentation.md` :43, :157, :158, :159, footer :229; `07-economy.md` :108; `sim-interface.md` :45, :57 all hold the text the plan cites. `11-multiplayer.md`: the plan's "footer :221" is stale; the footer is at :248 and ":221" is now the `## Where in the code` heading. Re-locate the `online_driver.gd` line with `rg -n 'online_driver' docs/guide/11-multiplayer.md` in Task 7.

Task 4 review merge (2026-11-15): Sonnet and Codex both found one test gap (P2/P3): RB5 did not guard pending-result retention. Added `main.stepped_results.size() > 0` after the hover; with `_show`'s clear made unconditional the check fails (mutation run, restored). No production change. Minor rulings: unreached `_refresh()` sites (placement, unload, context rejection) unguarded - cost if wrong: one extra snapshot per rare click; stale `hud.note` on step error - pre-existing, same as the old path; RB7/RB8 already-green guards - kept as count guards. After the fix: `sb1_` 9 cases / 27 checks exit 0; scene filter 122 cases / 3564 checks exit 0; lint 0; warnings 0.

Task 5 IC1 re-pin (2026-11-15; applied after the owner allowed row 19, user 2026-11-15): with the plan's physics call after step 11 the rows differ from IC1_ROWS in row 11 `place=` (empty -> `frc_supply_center`), command `tick` 0 -> 1 in rows 12-16 and 20, `Credits: 10000 | ... | Tick: 0` -> `Credits: 8500 | ... | Tick: 1` in rows 12 and 19, row 21 `tick=1` -> `tick=2` (all allowed), and row 19's inspected line `Enemy (P2) Battle Tank #9 HP 480/480 | guard` -> `HP 360/480 | guard -> #8` (not in answer 17's list: the step lets the tanks trade fire). Selections, ids, sequences and command order unchanged.
Row 19's HP text depends on cannon damage and delay (`shared.gd:16`, `usa.gd:11`), so a combat tuning change re-pins IC1 the same way.

Task 5 tests outside the plan's named list: `test_scene.gd` S3 gains one physics call before its "HUD rejection reason" check; OV11 (`test_order_voice.gd`) feeds its older rejection through `_sound.collect_step` instead of `stepped_results`, since the beep it checked came from `_submit` re-reading the note. Assertions unchanged.

Task 6 test measure: `navigation_builds()` counts only previews that need a full grid (`construction.gd:91`, skipped when `blocks_locally`), so it stays 0 on the Bs6 fixture world. RP3 (Bs6 rewritten as `test_sb2_preview_cost`) counts answers by identity of `preview_answer()` instead (unchanged object = no answer; it cannot see a discarded synchronous `preview_build`, ruled minor). RP6 and RP8 assert the answer's content and colour. RP5's online half lives in `test_online_scene.gd` as `test_sb2_rematch_drops_pending_preview`; RP8 builds its catch-up credit after tick 8: at tick 4 the faction commands have not yet created the builders (they appear in step 4 to 5), so `_place` cannot enter placement; a fixture timing, not a bug. After review RP8 also has the peer place a building on the spot in the frame's second tick, so the answer must be refused (computed after the last tick); moving `_answer_preview` into the catch-up loop fails it (mutation run, restored). `_enter_placement` also sends `request_preview({})`, so re-entering the same kind without Esc never stores an old answer.

Task 7 docs (2026-11-15, tree `314f487` plus uncommitted doc edits): edited `docs/guide/01-big-picture.md` (steps 2, 4, 6, file list; footer `314f487`), `04-the-tick.md` (submit steps, one-tick-later answer; footer `314f487`), `05-presentation.md` (hand-off with `shown_state`/`_reshow`, input and order answers, playtest checklist; footer extended), `07-economy.md` (preview via `request_preview`; footer extended), `11-multiplayer.md` (`online_driver.gd` line; footer extended) and `docs/reference/sim-interface.md` (`snapshot()` callers, `preview_build` caller). Code cited by the footers for these passages: `match_screen.gd`, `orders.gd`, `offline_driver.gd`, `online_driver.gd`, `hud.gd`, `playtest_overlay.gd`. `sh tools/check_public.sh` exit 0. The two-reviewer docs check (plan Step 3) is run by the coordinator.

Task 7 review merge (2026-11-15): fixed in the docs: online answers arrive after the scheduled command tick, not one tick later (01, 04, 05); rejections come from the local lockstep simulation, not the relay (11); snapshot also at the end for the playtest match record, preview at most once per step for the latest request (sim-interface); only the build click is guarded against a second click, the order voice plays at the click for every order, a repaint keeps the result buffer but the note may show a buffered refusal (05); lost trailing double space in 07. Not changed: the sim-interface Status line (e3a4b2b/d20d827) predates this task. `sh tools/check_public.sh` exit 0.

Stop gate 2 over-engineering review (2026-11-15, ponytail): no cuts, so no reruns. Rulings: `Orders.show_preview` kind and placing guards - plan Task interface pins them; a drop saves 2 lines, risks a stale answer drawn after a kind switch. Duplicated preview request/answer code in both drivers - already marked `shortcut:` for SB3's run_job; a shared base class now is a new layer SB3 deletes. `closes_placement_on_click` driver hook - two-valued behaviour pinned by owner answer 18; a flag on the driver is the smallest form. `HUD._local_team` - replaces `driver.sim.team_of`, needed to keep reads off the sim.

Final recheck after the gate fix rounds (2026-11-15, tree `5696065`, clean; outputs in `build/sb/final/`):

| Date | Command | Result | Tree |
|---|---|---|---|
| 2026-11-15 | `sh tools/run_checks.sh` | exit 0, `CHECKS PASSED 5` | 5696065, clean |
| 2026-11-15 | `sh tools/run_tests.sh` with the four replay trace variables | exit 0, CASES 980 CHECKS 146452 FAILURES 0, `TESTS PASSED 146452` | 5696065, clean |
| 2026-11-15 | `compare_replays.py` base vs final: replay, economy, combat (1200 rows), team (`--interval 200 --rows 100`) | `REPLAYS MATCHED` x4 (1200, 1200, 1200, 100) | 5696065, clean |
| 2026-11-15 | `NETPLAY_OUT=build/sb/final/netplay sh tools/run_netplay.sh match`; `compare_replays.py --interval 30 --rows 0` vs base `s1.tsv` | exit 0, `NETPLAY PASSED match 15.5 s`; `REPLAYS MATCHED 301` | 5696065, clean |
| 2026-11-15 | `sh tools/run_team_match.sh` | exit 0, `TEAM MATCH won tick=38786 winner=2 units_peak=268`, `TEAM PATHS PASS` | 5696065, clean |
| 2026-11-15 | `git diff f838f79 --stat -- game/scripts/simulation protocol` | empty | 5696065, clean |

Benchmark not rerun: the gate fixes touched input code only.

Night run review (2026-11-15): the gate 1 guard in `orders.answered` (reopen placement after an online refusal only when not `busy()` and not in attack-move mode) is kept (user, 2026-11-15). The unfixed reopen after the builder dies in the same step is STATUS F23 (user, 2026-11-15); the shared note for two refusals in one step is dropped, unchanged from before this branch (user, 2026-11-15).

Gate 3 offline and online playtest (user, 2026-11-15, late evening): online refusal reopen, accepted build and ghost colour pass; the mid-gesture case is covered by RA9 only (too short a window by hand). Finding: a refused build still played the order voice first. Fix A (user, 2026-11-15, after a Zero Hour and OpenRA read: both refuse a known bad spot locally and never send it, GeneralsGameCode `afc2a103f` `PlaceEventTranslator.cpp:227,285,294-305`, OpenRA `b4d95a5671` `PlaceBuildingOrderGenerator.cs:194-203`): a click on a spot whose preview for the shown tick is refused is not sent; the preview answer carries `error` and `tick`, and a still cursor re-asks every tick. Tests RL1, RL2 (red first: held 1, no note); Bs6 compares fields instead of the whole answer.

| Date | Command | Result | Tree |
|---|---|---|---|
| 2026-11-15 | `sh tools/run_tests.sh` with the four replay trace variables | exit 0, CASES 981 CHECKS 146455 FAILURES 0 | f3e1d52 + fix A, uncommitted |
| 2026-11-15 | `compare_replays.py` base vs fixa: replay, economy, combat, team (`--interval 200 --rows 100`) | `REPLAYS MATCHED` x4 (1200, 1200, 1200, 100) | same |
| 2026-11-15 | `sh tools/run_netplay.sh match`; compare `--interval 30 --rows 0` vs base | `NETPLAY PASSED match 15.6 s`; `REPLAYS MATCHED 301` | same |
| 2026-11-15 | `sh tools/run_checks.sh` | exit 0, `CHECKS PASSED 5` | same |
| 2026-11-15 | `git diff f838f79 --stat -- game/scripts/simulation protocol` | empty | same |

Fix A review (fresh Opus, 2026-11-15, diff `f3e1d52..7dbd1ec`): no P0-P1. Fixed: test gap for the origin check, RL3 added (mutation: dropping `_answer.origin == _preview_origin` turns RL3 red, held 0; restored). Left open, for the user: P2 a still cursor now asks for a preview every tick while placing, so a spot needing a full navigation grid builds it at tick rate (worst case unchanged: a moving cursor did so already; unmeasured); P3 the local refusal is skipped when the shown view is older than the simulation (the click is sent as before); P3 a refusal current for the shown tick can block a click a refund would allow one tick later (as Zero Hour and OpenRA); P3 `refuse` repeats three lines of `_step_simulation`.

| 2026-11-15 | `sh tools/run_tests.sh` (no trace variables) | exit 0, CASES 982 CHECKS 146449 FAILURES 0 | 7dbd1ec + RL3, uncommitted |
| 2026-11-15 | `sh tools/run_checks.sh` | exit 0, `CHECKS PASSED 5` | same |

Fix A review P2 accepted unmeasured (user, 2026-11-15): the per-tick preview while placing stays; worst case unchanged from a moving cursor.

Fix A listen check (user, 2026-11-15, desktop on `eab5cfc` plus this note; online two windows on the live relay): red spot offline and online passes (beep, no order voice); green spot builds.

Still open: gate 4.

## SB3

Plan: [sim boundary SB3](../superpowers/plans/2026-11-16-sim-boundary-sb3.md). Resume record below is overwritten at each checkpoint; ledger rows and the line map are append-only.

```text
Resume record (updated 2026-11-16, Task 2 done)
Branch / base commit / working-tree state: sim-boundary-sb3 (worktree ~/projects/wargrid-wt-sb3) / bad67c332820be5fb86d42a87af4a0dbcc436961 (main; wrapup-2026-11-16 merged), Task 1 at bef3fd1 / Task 2 uncommitted
Last green task / next incomplete task: Task 2 steps 1-4 done (pump, 8 `test_sb3_*` cases green; review test fixes with mutation proofs) / Task 3 (frozen caches and the offline ring switch)
Changed paths since last commit: game/scripts/match/sim_pump.gd (+ .uid), game/tests/test_sim_pump.gd (+ .uid), game/scripts/simulation/simulation.gd (`last_sequence`), game/tests/run_tests.gd (SUITES), docs/reference/sim-boundary-verification.md
Last command / cases / checks / failures / exit / marker: `WARGRID_TEST_ONLY=sb3_ sh tools/run_tests.sh`, CASES 8 CHECKS 39 FAILURES 0, exit 0, TESTS PASSED 39; lint exit 0; warnings exit 0 (171 files)
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: attended run, coordinator commits locally per task (user, 2026-11-16); Steam Deck row and rendered rerun at the SB3 gate (Task 8)
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: Task 3 Step 1 (failing freeze tests), after the coordinator commits Task 2.
```

### Evidence ledger

Base: `bad67c332820be5fb86d42a87af4a0dbcc436961` (`main`, tree `3762073acc71e04ba32fac89838d314740d6faad`), worktree clean. `git diff ad89a1c bad67c3 -- game tools protocol` is empty: the plan's `ad89a1c` lines hold unchanged on the base.

| Date | Command | Result | Tree |
|---|---|---|---|
| 2026-11-16 | `sh tools/run_tests.sh` with the four `WARGRID_*_REPLAY_TRACE` variables into `build/sb3/base/` | exit 0, CASES 1014 CHECKS 146678 FAILURES 0, `TESTS PASSED 146678` | base bad67c3, clean |
| 2026-11-16 | `NETPLAY_OUT=build/sb3/base/netplay sh tools/run_netplay.sh match` | exit 0, `NETPLAY PASSED match 16.1 s`; `s1.tsv` kept | base bad67c3, clean |
| 2026-11-16 | `sh tools/run_team_match.sh` | exit 0, `TEAM MATCH won tick=38786 winner=2 units_peak=268`, `TEAM PATHS PASS capped_ticks=853 max_cells=643` | base bad67c3, clean |
| 2026-11-16 | `sh tools/run_checks.sh` | exit 0, `CHECKS PASSED 5` | base bad67c3, clean |
| 2026-11-16 | `PERF_RECORD=0 sh tools/run_benchmark.sh` alone (load average 2.96 when it started, 2.24 after: above 2.5 at the start, host also had 6 sessions) | exit 0, `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`, `PROFILE COMPLETE 10`, `BUDGET EXCEEDED open dense hordes300 (regression ceilings held)` as in the ledger | base bad67c3, clean |
| 2026-11-16 | Task 2 Step 2: `WARGRID_TEST_ONLY=sb3_ sh tools/run_tests.sh` before `sim_pump.gd` | exit 1, `Preload file "res://scripts/match/sim_pump.gd" does not exist`, suite failed to load (red as planned) | bef3fd1 + Task 2 tests, uncommitted |
| 2026-11-16 | Task 2 Step 4: `WARGRID_TEST_ONLY=sb3_ sh tools/run_tests.sh` | exit 0, CASES 8 CHECKS 28 FAILURES 0, `TESTS PASSED 28` | bef3fd1 + Task 2, uncommitted |
| 2026-11-16 | Task 2: `sh tools/run_lint.sh`; `sh tools/run_warnings.sh`; `python3 tools/test_sim_boundary.py` | exit 0 each (`no problems found`, `WARNINGS CHECKED 171 FILES`, `OK`) | bef3fd1 + Task 2, uncommitted |
| 2026-11-16 | Task 2 review (Codex): mutation proofs, each applied to `sim_pump.gd`, `WARGRID_TEST_ONLY=sb3_ sh tools/run_tests.sh`, reverted (file byte-equal after) | view filled once: exit 1 (slot_invariant fresh view, post leaves slots, publish view); events/results not copied: exit 1 (two_notes pairs, publish job); copy not deep: exit 1 (each note's own ticks); query clears queue: exit 1 (queued note survives); preview before step: exit 1 (preview after the step) | bef3fd1 + Task 2, uncommitted |
| 2026-11-16 | Task 2 after review: `WARGRID_TEST_ONLY=sb3_ sh tools/run_tests.sh`; lint; warnings; `python3 tools/test_sim_boundary.py` | exit 0, CASES 8 CHECKS 39 FAILURES 0, `TESTS PASSED 39`; lint, warnings, boundary exit 0 | bef3fd1 + Task 2, uncommitted |

Benchmark comparison base (ms, `build/sb3/base/bench.log`): movement open p95 0.773 p99 0.846; movement dense p95 0.744 p99 0.897; combat open p95 1.893 p99 2.230; dense p95 1.847 p99 2.148; contact p95 1.179 p99 1.55; skirmish3v3 p95 1.348 p99 1.449; transports p95 1.13 p99 1.228; defences p95 0.784 p99 2.161; docks p95 0.591 p99 0.611; hordes300 p95 2.897 p99 3.381; ramp p95 0.651 p99 1.211; frc p95 0.889 p99 1.084; lockstep overhead p99 0.072 (limit 0.6); team_match profile `step` mean 1.355 p95 2.144, `view_state` mean 0.3022 (22.3 % of step, p95 0.403). Budget 1.82/3.64: open, dense and hordes300 exceed p95, as accepted before.

Base traces: `build/sb3/base/{replay,economy,combat,team}.tsv`, `build/sb3/base/netplay/s1.tsv` (untracked). "Traces equal" later: same commands into `build/sb3/<task>/`, then `python3 tools/compare_replays.py` base against branch (replay, economy, combat; team `--interval 200 --rows 100`; `netplay/s1.tsv` `--interval 30 --rows 0`) → `REPLAYS MATCHED`.

### Base counts (Step 4, worktree at bad67c3)

| Count | Command | Base | Plan |
|---|---|---|---|
| `driver.sim` uses in tests | `rg -c 'driver\.sim' game/tests` | 267 (overlay 19, base_scene 69, order_voice 9, skirmish_scene 90, online_scene 46, pause_menu 6, perf_overlay 4, scene 17, announcer 2, playtest_replay 3, sound 2) | not stated |
| `driver.sim =` assignments | `rg -c 'driver\.sim\s*=' game/tests` | 39 (overlay 3, base_scene 14, skirmish_scene 20, perf_overlay 1, scene 1) | not stated |
| `driver.recorder` | `rg -c 'driver\.recorder' game/tests` | 1 (skirmish_scene) | not stated |
| `sync_sequence` / `driver._sequence` / `driver._held` | `rg -n ...` | `sync_sequence`: definition `test_base_scene.gd:33` plus 7 call sites (base_scene :123, :167, :458; skirmish_scene :297, :749, :907, :1267) as the plan's "7"; `driver._sequence`: base_scene :35 (inside the helper), skirmish_scene :155, :164 (K4); `driver._held`: playtest_overlay :730, base_scene :283, :290, :300, :521 | 7 call sites |
| `pending_commands` | `rg -c 'pending_commands' game/tests` | 69 (defences 1, base_scene 11, skirmish_scene 18, economy 2, simulation 15, combat 1, scene 7, perf_overlay 2, skirmish 6, benchmark 3, factions 1, team_match 2) | not stated |
| `_physics_process(` / `_step_frame(` calls | `rg -c '\._physics_process\(\|\._step_frame\(' game/tests` | 95 (113 with `set_physics_process(` lines) | 95, 113: equal |
| `._refresh()` | `rg -c '\._refresh\(\)' game/tests` | 71 (overlay 3, base_scene 18, order_voice 1, skirmish_scene 37, online_scene 5, perf_overlay 1, scene 2, announcer 4) | 71: equal |

No count differs from the plan (95, 113, 71). Tasks 4-6 compare against this table.

### Line map

Plan cites are `ad89a1c`; right column is the base bad67c3. 79 cites (`file:line` and ranges, one row per file below) were resolved against the base: every cited line exists and holds the described content. No game or tools file changed between `ad89a1c` and the base, so the map is the identity except the two rows marked here. No cited line is gone (no stop). The 15 bare follow-up cites (`:1163-1167,1207-1210`, `:1189`, `:1074`, `:283,290,300,521`, `:155,164`, `:180-184`, `:203-207`, `:341-351`, `:664`, `:665`, `:63`) were also read and match.

| Plan cite | Base location |
|---|---|
| `offline_driver.gd:24` ("build sims with `Skirmish.create(...)` as") | wrong in the plan at `ad89a1c` too: the `Skirmish.create(true, "ai", factions, map_path, starts)` call is `:27` (`create` :20-27); `:24` is `_preview_request = {}` |
| `definitions.gd:117-122` (`_reset()`) | `_reset` is `:118-123` (`:117` is blank); the plan's range is off by one |
| `simulation.gd:664-665` | unchanged: `:664` opens the `step.hash_ring` zone, `:665` writes `_hash_ring[_tick % HASH_RING_SIZE]` |
| all other cites in `game/scripts/match/` (`match_screen.gd` x14, `hud.gd` x3, `offline_driver.gd` x3 others, `online_driver.gd` x7), `game/scripts/simulation/` (`combat.gd`, `definitions.gd` :19-20, `map_data.gd`, `skirmish.gd`, `simulation.gd` :589-591), `game/scripts/net/lockstep.gd`, `game/scripts/debug/team_match.gd`, `tools/test_sim_boundary.py` :52-82 | unchanged |
| all cites in `game/tests/` (`run_tests.gd`, `economy_fixture.gd`, `test_base_scene.gd`, `test_graphics_settings.gd`, `test_online_scene.gd`, `test_playtest_overlay.gd`, `test_scene.gd`, `test_skirmish_scene.gd`) | unchanged |
