# P7 part 1 verification: enemy bot rules

Plan: [P7 part 1](../superpowers/plans/2026-11-21-p7-enemy-bots.md). Raw probe rows are private (`~/projects/wargrid-private/docs/better-bots/probe/p7/`).

```text
Resume record (updated 2026-11-21 13:09)
Branch / base commit / working-tree state: p7-enemy-bots / 0e2e613f / T1-3 changes uncommitted (see changed paths)
Last green task / next incomplete task: T1-3 (UR1, red set as expected, not committed) / T1-4
Changed paths since last commit: game/scripts/simulation/skirmish.gd, game/scripts/match/offline_driver.gd, game/scripts/match/match_screen.gd, game/scripts/debug/team_match.gd, game/scripts/lab/readme_capture.gd, game/scripts/net/headless_client.gd, game/tests/test_bot_rules.gd, game/tests/test_combat.gd, game/tests/test_playtest.gd, game/tests/test_playtest_replay.gd, game/tests/test_skirmish_scene.gd, tools/playtest_session.py, tools/replay_session.sh, tools/test_playtest_session.py, tools/test_no_production_create_passes_ai.py (new), this file
Last command / cases / checks / failures / exit / marker: full suite on the T1-3 tree: CASES 1254 CHECKS 152764 FAILURES 9 / exit 1 / no TESTS PASSED (expected red, 9 failing checks, all on the re-pin list); lint 0, warnings 0 (190 files); python checks and shell checks exit 0
Known red case or blocker: the names in the red ledger (re-pin at T1-10); p2_playtest_match.json report-only drift since main 56cfcb2c (see T1-3 evidence)
Approved decisions, pre-authorizations used, deferred gates: plan approved (user, 2026-11-21); (a) local commit per green task, (b) one branch push at the gate
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: review and commit T1-3, then T1-4
```

## Red ledger

| Task | `FAIL:` names left red | On the re-pin list |
|---|---|---|
| T1-2 | TB3 final digest (tick 20000); TB4 team core series; S1 core series; Fm1 pinned outcome (27098, winner 2); Cs1 pinned outcome (10343, winner 2); VR1 view reads digest and VR1 same digest through set_view; S1 pinned outcome (-1 ongoing); S1 terminal inside the six-minute window; S1 economy, production and combat | yes, all (T1-10) |
| T1-3 | TB3 final digest (tick 20000); TB4 team core series; S1 core series; Fm1 pinned outcome (27098, winner 2); Cs1 pinned outcome (10343, winner 2); VR1 view reads digest and VR1 same digest through set_view; S1 pinned outcome (9958, winner 1); HUD1 pinned panel and collector texts. Left the list: S1 terminal inside the six-minute window, S1 economy, production and combat (green again under human unit rules). | yes, all (T1-10) |

## Evidence

### T1-1 kill check A

Ran on `p7-enemy-bots` at `194048e0` (bot code = `main` `6bd58ff3`, `skirmish.gd` unchanged). Variant `collectors1` built by `make_variant.py` into a scratch file in the private probe folder; no source in this worktree changed. Probe `p7_probe.gd`, headless, 1,350 matches (stock `ctrl=human` 522, stock `ctrl=ai` Broken Crown 225 beside the old `BL` rows, `collectors1` `ctrl=human` 603), all rows parsed, 0 errors. Raw rows, job files, `t11.py`, `pooled.py`: `~/projects/wargrid-private/docs/better-bots/probe/p7/`. Matrix: `BL` sets (Dry Wells 1,2; Ashfall 2,6; Ashfall 3,7; 9 faction pairs; bot vs bot 5 seeds, idle seat both slots 3 seeds); Broken Crown 2v2 teams [1,1,2,2], faction per team, starts 1,2,3,4 and 3,4,1,2 ("slot orders"), 5 seeds; Broken Crown 1v1 idle (idle start 1, bot on 2, 3, 4; 5 seeds); Broken Crown 1v2 idle (idle start 1, two bots on 2,3 / 2,4 / 3,4, same faction; 3 seeds). The 1v2 rows and `collectors1` Broken Crown rows have no stock 1v2 counterpart (not asked).

**Minute 6 (tick 10,800), fighting units per slot, median (mean), seat rows still in a running match:**

| Slot | stock `ai` (`BL`) | stock `human` | `collectors1` `human` |
|---|---|---|---|
| Dry Wells and both Ashfall sets, seat 1 | 24 (24.2) | 25 (24.4) | 27 (25.5) |
| same, seat 2 | 31 (32.0) | 34.5 (33.2) | 38 (34.0) |
| Broken Crown 2v2, team 1 (seats 1,2) | 15 (15.4) | 14 (16.2) | 16 (16.9) |
| Broken Crown 2v2, team 2 (seats 3,4) | 15 (14.4) | 16 (16.8) | 15 (15.7) |

Medians rise in both 1v1 slots (the stop condition does not fire), means by only 0.8 to 1.1 units against stock `human`. Broken Crown is mixed per seat (seat 3 of 1,2,3,4: 6 to 9; seat 4 of 3,4,1,2: 23 to 15). Per map and seat in `t11.py` output.

**Night 12 columns** (`docs/packages.md:61`; `collectors1` against stock `human`; against stock `ai` in brackets): column 1, seats that never damage an enemy building under stock and do under `collectors1`: 61 of 190 (63 of 190); column 2, matches that end under stock and still end: 141 of 179 (123 of 150; lost 38 / 27). Both fail, as expected for BR1 alone; hard only at T1-5 and T1-8. By map (stock ended to `collectors1` ended): Dry Wells 38 to 36, Ashfall 2,6 30 to 21, Ashfall 3,7 33 to 29, Broken Crown 2v2 39 to 25 and 39 to 30; 46 seats that damaged a building under stock do not under `collectors1`.

**Stock Broken Crown rows (`ctrl=human`; `ai` idle rows equal within 2 ticks, 2v2 differs):** 2v2 ended 78 of 90 (starts 1,2,3,4 39 of 45, 3,4,1,2 39 of 45; `ai` 61 of 90). Idle seat defeat tick, 1v1, min / median / max: bot on start 2 8,033 / 8,170 / 8,220; start 3 9,558 / 9,738 / 10,031; start 4 7,887 / 7,966 / 8,046. **Broken Crown stock idle defeat minimum: 7,887** (the 7-13 floor for that map). First idle building lost: min 5,964.

**Idle defeat floor under `collectors1`** (min tick; stock 1v1 min in brackets): Dry Wells 7,428 (7,414), Ashfall 2,6 10,701 (10,698), Ashfall 3,7 10,314 (10,314), Broken Crown 1v1 7,775 (7,887), Broken Crown 1v2 7,365 (7,887). BR1 alone already falls below the floor on Broken Crown; BR2 and BR3 must hold it back (T1-5).

Not run here: the 150 s rule, wave-level rows (the variant's waves are not logged; stock `BL` waves unchanged).

### T1-2 BR1

Tree: `p7-enemy-bots` at `3e074b6d` plus the uncommitted T1-2 changes. Red first: `test_bot_collector_quota_per_supply_centre` (new `test_bot_rules.gd`, in `run_tests.gd` `SUITES`) failed 3 of 3 checks before the change (quota 2/3/5, USA 2 and China 3 collectors). Then `factions.gd` quota 3/4/6; SK-C1 to SK-C5 rewritten to 3/4/6 (two supply centres: USA 6, China 8). `test_bot_rules`: CASES 1 CHECKS 3 FAILURES 0. `test_skirmish*`: CASES 131 CHECKS 958 FAILURES 6 (S1 x3 plus core series, Cs1, Fm1). Full suite: CASES 1251 CHECKS 152757 FAILURES 10, exit 1 (no `TESTS PASSED`); R4's 16 minus the 6 SK-C checks is 10. `sh tools/run_lint.sh` exit 0; `sh tools/run_warnings.sh` exit 0, 190 files. Baseline skipped, passed on `194048e0`; `3e074b6d` only adds docs.

### T1-3 UR1

Tree: `p7-enemy-bots` at `0e2e613f` plus the uncommitted T1-3 changes. Baseline skipped: the T1-2 full suite ran on the T1-2 tree and only a test rename followed, so the T1-2 red set is the starting point. Red first (each failed before any production change): `tools/test_no_production_create_passes_ai.py` (`skirmish.gd` default `"ai"`); `test_bot_seat_idle_unit_ignores_enemy_beyond_reach` (2 checks: default seat was `ai`, guard acquired target 8); RP4 record `controller` missing; RP10 `test_oracle_controller_arg`; `tools/test_playtest_session.py` `test_replay_rows_carry_controller`, `test_replay_wrapper_passes_controller` and the shifted `build` column. `test_old_record_replays_as_ai` (RP9) passed before the change: it guards the oracle default, so it is not red-first. Change: `Skirmish.create` default and the four create paths pass `"human"`; `match_screen.gd` `_header` writes `controller: "human"`; the oracle reads `--controller` (missing: `"ai"`); `playtest_session.py` emits a `controller` column (`-` when absent) and `replay_session.sh` passes `--controller`. Tests that replay offline matches or assert the replaced rule were switched in the same task: RP4 and RH5 pass `controller: human`, SB3 oracle `_replayed_digest` creates `"human"`, C2/C3 `Skirmish.create(true, "ai")`, `test_playtest.gd` key list and `_record`. `benchmarks/run_recorded_match.gd` keeps `"ai"`.

Results: `test_bot_rules` CASES 2 CHECKS 6 FAILURES 0; `test_playtest*` CASES 91 CHECKS 682 FAILURES 0; `test_sim_pump` 29/134/0; `test_combat` 85/2649/0. Full suite: CASES 1254 CHECKS 152764 FAILURES 9, exit 1 (no `TESTS PASSED`), 9 failing checks, all on the re-pin list; S1 now ends at tick 9958 (winner 1), inside the 7000-17999 window. HUD1 joined; K2 did not. `sh tools/run_lint.sh` exit 0; `sh tools/run_warnings.sh` exit 0, 190 files; `sh tools/run_python_checks.sh` exit 0 (`PYTHON TESTS PASSED`); `sh tools/run_shell_checks.sh` exit 0.

Found, not fixed: `godot --headless --path game --script res://benchmarks/run_recorded_match.gd` reports `RECORDED MATCH DIFFERS tick=6694 recorded=972a057c40053661 replayed=7aa31eab0a71558b` identically on `main` `194048e0` and `0e2e613f`; it matched at `278480b2` (the fixture commit), and the first differing commit on `main` is `56cfcb2c` ("Budget path searches by route cells"). Nothing runs it (no tool or CI step; `performance.md` labels it report-only), so it fails no gate. Not re-recorded in P7: re-pinning would no longer replay the owner's match; re-pin or a new fixture is an owner choice for a separate commit on `main`.

UR1 also reaches `benchmarks/run_profile.gd:104` (`Skirmish.create()` default): the `skirmish_match` profile in `run_benchmark.sh` now runs human unit rules, so the gate's profile row is not comparable to earlier rows. Review fix: the UR1 test gained a positive control (an enemy 3 cells away, inside reach, is acquired); `test_bot_rules` CASES 2 CHECKS 7 FAILURES 0.
