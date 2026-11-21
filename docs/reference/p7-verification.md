# P7 part 1 verification: enemy bot rules

Plan: [P7 part 1](../superpowers/plans/2026-11-21-p7-enemy-bots.md). Raw probe rows are private (`~/projects/wargrid-private/docs/better-bots/probe/p7/`).

```text
Resume record (updated 2026-11-21 15:58)
Branch / base commit / working-tree state: p7-enemy-bots / 70dc9873 (T1-5b) / T1-6 uncommitted: skirmish.gd, test_bot_rules.gd, test_skirmish.gd, test_skirmish_waves.gd, sim-interface.md, this file
Last green task / next incomplete task: T1-5b green on the re-pin list; T1-6 fix round done, awaiting re-review / T1-7 (needs the commit-rule kill check first)
Changed paths since last commit: game/scripts/simulation/skirmish.gd, game/tests/test_bot_rules.gd, game/tests/test_skirmish.gd, game/tests/test_skirmish_waves.gd, docs/reference/sim-interface.md, docs/reference/p7-verification.md
Last command / cases / checks / failures / exit / marker: full suite on the T1-6 fix-round tree: CASES 1287 CHECKS 152842 FAILURES 9 / exit 1 / no TESTS PASSED (expected red, re-pin list only); lint exit 0, warnings exit 0 (190 files)
Known red case or blocker: the names in the red ledger (re-pin at T1-10); p2_playtest_match.json report-only drift since main 56cfcb2c (see T1-3 evidence)
Approved decisions, pre-authorizations used, deferred gates: plan approved (user, 2026-11-21); T1-5 owner decisions 1-4 (user, 2026-11-21, T1-5 section); (a) local commit per green task, (b) one branch push at the gate; open: commit-rule kill check before T1-7, wave growth at T1-8, 1v2 floor after T1-6
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: re-review the T1-6 fix round, commit T1-6, then the clean kill check of the "commit" wave rule before T1-7
```

## Red ledger

| Task | `FAIL:` names left red | On the re-pin list |
|---|---|---|
| T1-2 | TB3 final digest (tick 20000); TB4 team core series; S1 core series; Fm1 pinned outcome (27098, winner 2); Cs1 pinned outcome (10343, winner 2); VR1 view reads digest and VR1 same digest through set_view; S1 pinned outcome (-1 ongoing); S1 terminal inside the six-minute window; S1 economy, production and combat | yes, all (T1-10) |
| T1-3 | TB3 final digest (tick 20000); TB4 team core series; S1 core series; Fm1 pinned outcome (27098, winner 2); Cs1 pinned outcome (10343, winner 2); VR1 view reads digest and VR1 same digest through set_view; S1 pinned outcome (9958, winner 1); HUD1 pinned panel and collector texts. Left the list: S1 terminal inside the six-minute window, S1 economy, production and combat (green again under human unit rules). | yes, all (T1-10) |
| T1-4 | Same nine names as T1-3. Values moved: TB3 final digest (ee11652fc94fa901 to d149879bbdb5e517); TB4 team core series (3893643193399489437 to 6523963049782461399); S1 core series (523144223445027603 to 5372631221812398523); S1 pinned outcome (9958 to 9320, winner 1, inside 7000-17999); Fm1 (27098 to 20553, winner 2); Cs1 (10343 to 20812, winner 2). Unchanged: VR1 digest (both checks), HUD1 texts. | yes, all (T1-10) |
| T1-5b | as T1-4; moved: TB3 digest 8ab8cdf6cc4aa01c, TB4 core series, S1 core series, S1 pinned outcome (9062, winner 1), Fm1 (29710, winner 2), Cs1 (29359, winner 2), VR1 digest, HUD1 texts | yes, all (T1-10) |
| T1-6 | Same nine names as T1-5b. Values moved: TB3 digest 8ab8cdf6cc4aa01c to db6f45719f3a69db; TB4 team core series to 7390405388462874494; S1 core series to 8473958222776080914; S1 pinned outcome unchanged (9062, winner 1); Fm1 (29710, winner 2 to 35503, winner 1); Cs1 (29359 to 29516, winner 2); VR1 digest to 0f6f0648eca07d66c16ddcf173c5dd075e978d4fd5c56ecea7209147c18e1370 (both checks); HUD1 texts. Fix round moved none of them. T1-10: Fm1's winner flips 2 to 1. | yes, all (T1-10) |

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

### T1-4 BR2, BR3

Tree: `p7-enemy-bots` at `0fbb4838` (T1-3 committed) plus the uncommitted T1-4 changes. Baseline skipped: the T1-3 full suite ran on the T1-3 tree and only a test positive control and docs followed, so the T1-3 red set is the starting point (the resume record named `0e2e613f` and an uncommitted tree; the commit `0fbb4838` is that tree).

Red first, on behaviour: `skirmish.gd` got the new constants and stub accessors (`unit_cost`, `faction_unit_cost`, `team_memory`) first, so every new test failed on a check, not a parse error (`test_bot_rules` CASES 17 CHECKS 47 FAILURES 30; `test_pump_bot_first_wave_at_4500` 1 failure, no attack before the old 5400). `test_wave_leaves_at_wait_cap` first passed by chance with three tanks (the old timeout is also 1800), so it was changed to seven riflemen, which the old count rule released at once. Change: `ATTACK_TICK`, `WAVE_MIN`, `WAVE_TIMEOUT` and the per-bot `since` are gone; `FIRST_WAVE_TICK` 4500, `WAVE_GAPS` [2700, 2700, 1800], `WAVE_WAIT` 1800, `WAVE_SIZES`, `WAVE0_UNITS` 16, `BOT_TEAM_META` entry per team with the BR4 layout; a seat is a live bot after its first `decide` and while it owns a `counts_for_victory` building; `_gather` ends in `_launch`: target = size x live bots x team unit cost, a launching bot takes its own ready units (highest unit cost first, ties lowest id) up to its share, wave 0 up to `16 / live bots`.

Rewrites (R2): `test_skirmish_waves.gd` (W1, W2, W4 and the `FULL` wave as five tanks, 4,500 against the 4,248 target; W2 now asserts the cost target, W4 the next wave's wait cap), `test_skirmish.gd` (A3, W1-W4, D2, D3 constants; bot worlds got a victory building for seat 2 because a seat without one is not live, placed at (0, 28) or (0, 29) so `_defend` never fires; A3's `lone` removes the headquarters too), `test_team_match.gd` TB1 (`WAVE_WAIT`), `test_skirmish_scene.gd` OD2 (`FIRST_WAVE_TICK`). All green.

Results: `test_bot_rules` CASES 18 CHECKS 49 FAILURES 0; `test_skirmish*` green but for the re-pin names; `test_pump_bot_first_wave_at_4500` 1/2/0. Mutation checks on the final code (each made a named test fail, then reverted): no wave-0 cap, tie by highest id, `>` instead of `>=` at the take and at the release gate (the last two needed `test_wave_stops_at_exact_target`, added because the first version survived). Full suite: CASES 1271 CHECKS 152809 FAILURES 9, exit 1 (no `TESTS PASSED`), the T1-3 names, all on the re-pin list (values above). `sh tools/run_lint.sh` exit 0; `sh tools/run_warnings.sh` exit 0, 190 files; `tools/test_sim_boundary.py` and `tools/test_sim_math.py` OK.

Interpretations taken: (1) `released_by` is "timer", "size" or "wait_cap"; "timer" means the bot's previous decision was before `due` (per bot memory `prev`, not a team field); a target met at or after the cap decision counts as "size" when it is not the first decision from due. (2) Tests read the team entry through `Skirmish.team_memory(sim, team)` (a copy), not `get_meta`, because `released_by` and `due` are in no snapshot. (3) Until BR4 (T1-6) the team clock is shared but each bot judges only its own ready units against its share `target / live bots` and a teammate's units wait for a launch of their own: in a team of two or more a later wave is launched by whichever bot decides first after `due`, normally the same one. (4) A seat that is not live (no victory building) neither gathers a wave nor launches one. (5) Unit cost per unit is `cost / quantity` with integer division, also for units outside the build list.

Reviewer notes for later tasks: (a) T1-6 must move `prev` (the "timer" release test) to a team-level field, since the spec means the first decision of any team bot; (b) a target-sized group arriving after due + `WAVE_WAIT` when nothing was ready at the cap is labelled "size" (the spec has no label for it); T1-5 reads the 150 s rule count with that in mind.

Fix round: `test_wave_capped_by_cost_rest_guards_home` now plays on to the next `due` (three tanks added, 7,200 against 6,372) and asserts wave 1 leaves at `due` with the five home tanks; mutation (wave records all ready units, so the extras are never re-gathered) failed it: `FAIL: BR3 the five home tanks leave with wave 1 (6372), got [{ "tick": 2, "ids": [4, 5, 6, 7, 8] }, { "tick": 32, "ids": [9, 10, 11, 12, 13] }]`, then reverted. SK20 writes `prev` (the removed `since` was still written). `sim-interface.md` lists `Skirmish.team_memory`.

### T1-5 kill check B

Result: BLOCKED. Two stop conditions fired (the 7-13 floor on every map, night-12 columns 1 and 2); wave 0 held. No source in this worktree changed; nothing run from a scratch export.

Tree: `p7-enemy-bots` at `91a32827` (T1-4 committed), clean. No variant, `ctrl=human`. Probe `p7_probe.gd` updated to read the team entry through `Skirmish.team_memory` (per wave: `wave_index`, `released_by`, `due`, launch tick, units, cost; the T1-1 version is kept as `p7_probe_t11.gd`). Matrix, 603 matches, all rows parsed: `BL` sets (Dry Wells 1,2; Ashfall 2,6; Ashfall 3,7; 9 faction pairs, bot vs bot 5 seeds, idle seat both slots 3 seeds) 297; Broken Crown 2v2 teams [1,1,2,2], both slot orders, 5 seeds, 90 plus 1v1 idle 135 = 225; Broken Crown 1v2 idle 81. Compared with T1-1's stock `ctrl=human` rows (522). Raw rows, `t15.py`, `an-t15.txt`: `~/projects/wargrid-private/docs/better-bots/probe/p7/` (`out-t14-{bl,bc,bc12}.jsonl`).

**Minute 6 (tick 10,800) fighting units, median (mean), stock to T1-4 tip:** `BL` seat 1 25 (24.4) to 44 (38.9); `BL` seat 2 34.5 (33.2) to 46 (43.3); Broken Crown 2v2 team 1 14 (16.2) to 49.5 (45.2); team 2 16 (16.8) to 50 (45.0).

**Wave 0 per team (hard bar 16):** max 12 units (Ashfall 3,7 idle row; Broken Crown 1v1 12; Dry Wells 9; Broken Crown 2v2 team 8, since the second bot does not join before T1-6); wave 0 cost median 3,900 (max 4,375). Holds. Stock first waves summed 24 median, 47 max.

**Waves (team waves, all rows):** launch-to-launch gap after wave 0 median 2,700 (max 3,150), after wave 1 3,210, from wave 2 on 3,600 (min 1,800, max 6,000). `released_by`, wave 0: timer 765, size 63. Wave 1: timer 586, size 200. Wave 2: wait cap 219, timer 201, size 81. Waves 3 to 13: wait cap dominates (wave 3 292 of 449, wave 6 386 of 416, wave 8 273 of 275). Unit and cost medians: wave 0 8 and 3,900; wave 1 22 and 6,200; wave 2 28 and 7,100; wave 5 21 and 5,150; wave 8 8 and 1,800 (later waves shrink because the army is spent). **Timer share of waves 1 on: 977 of 4,285 = 0.228** (excluding Broken Crown 2v2: 449 of 2,498). Not above half: the 150 s rerun was not run. The "size" label caveat of T1-4 (a group arriving after the cap with nothing ready) is in these counts.

**Reach** (waves whose units hit an enemy building): stock 3,660 of 12,862 = 0.285 (excluding Broken Crown 2v2 0.246); T1-4 tip 1,952 of 5,113 = 0.382 (excluding Broken Crown 2v2 1,056 of 3,146 = 0.336; Broken Crown 2v2 0.456). By wave index 0 to 5: 504/828, 305/786, 122/501, 185/449, 190/444, 203/437. Correction (diagnosis): the "excluding Broken Crown 2v2" figures include idle rows; on bot-vs-bot rows reach is flat, 0.225 stock to 0.224.

**Idle seat defeat tick, min (stock 1v1 min = floor), first building lost min in brackets:**

| Map | Floor | T1-4 tip 1v1 | T1-4 tip 1v2 |
|---|---|---|---|
| Dry Wells 1,2 | 7,414 | 6,783 (4,937) | none run |
| Ashfall 2,6 | 10,698 | 10,241 (6,528) | none run |
| Ashfall 3,7 | 10,314 | 9,682 (6,446) | none run |
| Broken Crown | 7,887 | 7,406 (5,084) | 7,583 (5,106) |

Every row is below the floor (by 631, 457, 632, 481 and 304 ticks). Stock first building lost mins were 5,839, 7,428, 7,348, 5,964; the new rules lose a building 0.6 to 0.9 minutes earlier. All idle matches end with a winner (0 of 378 not won). The stock set has no 1v2 row (the floor is the 1v1 minimum), and the 1v2 set exists on Broken Crown only.

**No-winner (status other than won):** `BL` bot vs bot 31 of 135 (stock 34); Broken Crown 2v2 37 of 90 (stock 12); idle 0.

**Night 12 against stock `human`** (hard bars; both fail):

| | Column 1: seats failing under stock that damage a building now | Column 2: stock-ended matches that still end | Seats that damaged under stock and no longer do |
|---|---|---|---|
| Whole matrix | 125 of 190 | 131 of 179 (lost 48) | 25 |
| Excluding Broken Crown 2v2 (pre-T1-6 team behaviour) | 46 of 107 | 81 of 101 (lost 20) | 16 |

Excluding Broken Crown 2v2, column 2 losses by map: Ashfall 2,6 8, Dry Wells 6, Ashfall 3,7 6; column 1 seats still failing: Ashfall 3,7 36, Ashfall 2,6 16, Dry Wells 9. By group (stock ended to T1-4 ended; no-damage seats stock to T1-4): Dry Wells 38 to 39 and 27 to 14; Ashfall 2,6 30 to 33 and 36 to 21; Ashfall 3,7 33 to 32 and 44 to 42; Broken Crown 2v2 1,2,3,4 39 to 23 and 43 to 6; 2v2 3,4,1,2 39 to 30 and 40 to 7.

Reading: the first wave is now the bar's 8 to 12 units at 4,500 and the idle seat falls 0.3 to 0.6 minutes earlier than stock everywhere, so BR2 and BR3 as built shift the idle-defeat time below the 7-13 floor before BR4 to BR6 or any constant tuning exist. Column 1 stays open on Ashfall 3,7 (42 of 44 seats still never damage a building). The Broken Crown 2v2 rows (37 of 90 not ending) carry the stranded second-bot units until T1-6 and are not a fair read of the final rules. Per the stop rule nothing was widened or tuned; the owner decides (T1-6 to T1-8 order, constants, or the floor).

**Diagnosis** (two independent fresh-context runs, Opus high and Fable high, same brief; full numbers private: `~/projects/wargrid-overnight-work/p7-enemy-bots/t1-5-diagnosis.md` and `t1-5-diagnosis-b.md`; scratch exports of `91a32827` with one constant changed, both reproduced the T1-5 rows):
- Floor: caused by `FIRST_WAVE_TICK` 4,500 alone; the first building falls exactly 900 ticks earlier on every map, walk times unchanged, and on Dry Wells wave 0 alone ends the match. `FIRST_WAVE_TICK` 5,400 restores every row (378 idle rows, both runs identical): Dry Wells 7,683, Ashfall 2,6 11,141, Ashfall 3,7 10,582, Broken Crown 1v1 8,128, 1v2 8,483. `WAVE_SIZES[0]` 4 at 4,500 still fails Dry Wells and Broken Crown 1v1.
- Column 1: waves die to enemy wave units before reaching a building (Ashfall 3,7: every loss to enemy wave units, about 1:1 trades); 29 of the 42 failing seats are losers of decided matches. Offsetting one team's clock does not help (42 to 44 failing seats). BR4/BR5 change nothing in 1v1 and BR6 counts only FRC's defence. A confounded variant (`DEFENCE_RADIUS` 0, waves never stop for units, home defence also off) moved Ashfall 3,7 from 8 of 28 to 25 of 28.
- Column 2: the unchanged stock bot on shifted seeds keeps only 87-88 of 101 ended rows (Broken Crown 2v2 71-72 of 78), so the column as worded cannot pass for any rule set. Excluding Broken Crown 2v2, losses are mostly same-faction stalemates (`usa,usa` 13 ended on stock, 2 now).
- BR3 growth: from wave 3 on, 0 of 1,357 waves met their target (income about 3,770 per 3,600 ticks against targets of 10,620-16,992); waves from wave 2 on leave at the wait cap, a 3,600-tick cycle.
- 5,400 on bot-vs-bot rows: minute-6 units 47/48, reach 0.209, column 1 39 of 107, column 2 80 of 101.

**Owner decisions (user, 2026-11-21):** (1) first wave at 180 s, `FIRST_WAVE_TICK` 5,400 (reopens 7-3; 7-13 floor kept); (2) night-12 column 2 is judged against stock seed noise: per map group, the new rules keep at least as many stock-ended matches ending as stock against itself on shifted seeds (widens 7-12's wording; column 1 unchanged); (3) T1-6 next; before T1-7 a clean kill check of a "commit" wave rule (home defence left on), then the owner decides whether it enters the design; (4) wave growth (targets never met from wave 3) is decided at T1-8 with the full probe and the window check.

### T1-5b First wave at 180 s

Tree: `91a32827` plus `FIRST_WAVE_TICK` 5,400 (`skirmish.gd:13`, the same one-constant change as the diagnosis exports, whose idle rows are this tree's floor evidence). Tests: `test_pump_bot_first_wave_at_4500` renamed `..._at_5400` and its loop runs to `FIRST_WAVE_TICK + DECISION_TICKS + 70` (it stopped at 4,600, before the first wave: `got []`); messages naming 4500 now name `FIRST_WAVE_TICK`. Full suite: CASES 1271 CHECKS 152810 FAILURES 9, exit 1 (no `TESTS PASSED`), the T1-4 names, all on the re-pin list; S1 ends at 9062 (winner 1), inside 7000-17999.

### T1-6 BR4, BR5

Tree: `p7-enemy-bots` at `70dc9873` (T1-5b committed) plus the uncommitted T1-6 changes. Baseline skipped: the T1-5b full suite ran on the `70dc9873` tree, so the T1-5b red set is the starting point.

Red first, on behaviour (`build/t16-red.log`, new tests against the unchanged `skirmish.gd`): `test_bot_rules` CASES 33 CHECKS 80 FAILURES 22, no parse error; 15 new cases, every one failed on a check (leaves at the cap instead of one round, share instead of left, objective null, per-bot labels). `test_teammate_without_first_decision_not_counted`, `test_dead_teammate_does_not_hold_clock` and `test_rally_units_sent_to_defend_skip_the_join` hold on T1-4 for their wave rules (live bots were built then); each failed on the new team objective field only. Change: `_launch` is replaced by `_form` (the first live bot that sees the team's ready cost, its own plus the live teammates' units at their rallies, reach the target, or the wait cap with any unit ready, sums it, picks the objective, takes its own share and stores `left_cost`, `left_units`, `joiners`) and `_add_to_wave` (a joiner takes `left / joiners still to come`, the last all of it, the unit cap of wave 0 likewise); the team entry gains `prev` (last team decision) and `_bot` loses its `prev`. Objective: `_victim` is the enemy with a building and the lowest `attacked_at` (never -1, ties lowest id), `_pick` among its buildings from the mean rally of the live bots; `_follow` keeps the objective while it stands and lets the first wave that notices its death store a new one; an engaged wave uses plain `_pick` and never writes it.

Results: `test_bot_rules` CASES 33 CHECKS 80 FAILURES 0; `test_skirmish*` red only on S1 (2), Cs1, Fm1, HUD1. Mutations on the final code, each failed named tests, then reverted: victim tie by highest id, last joiner share `/ 2`, no objective store, no teammate units in the sum, no joiners, no objective follow. Full suite: CASES 1286 CHECKS 152841 FAILURES 9, exit 1 (no `TESTS PASSED`), the T1-5b names, all on the re-pin list (values in the ledger row). `sh tools/run_lint.sh` exit 0; `sh tools/run_warnings.sh` exit 0, 190 files; `tools/test_sim_boundary.py` OK (a first `_join` collided with `test_launcher.gd`; renamed `_add_to_wave`), `tools/test_sim_math.py` OK.

Rewrites (R2, the replaced rule): `test_skirmish.gd` A3 and W1 and `test_skirmish_waves.gd` T5 check one decision after the launch, because a wave now leaves for a building of the objective and an enemy unit in reach is taken at the next decision; A3's first unit target is the nearer builder `second` (13), then `first` (12). `test_waves_deterministic` gained a four-seat team run (equal snapshot and equal team entry). `sim-interface.md` lists the team entry keys.

Interpretations taken: (1) a launching bot with no ready unit still forms the wave (it only sends nothing): the wave needs the team's cost or, at the cap, any team unit ready; (2) `released_by` "timer" is the first decision of any live-or-not team seat from `due` (`prev` is written at the end of every team decision); (3) `left_units` is -1 after wave 0 (no cap); (4) `joiners` are the other live bots in order of their next decision; a joiner that is no longer live is dropped and the last live one takes up to `left`; (5) the objective is a building: with no enemy building the wave does not leave (T1-4 would have picked a unit); (6) a launch always orders the objective, an enemy unit within `DEFENCE_RADIUS` of the wave is taken at the next decision (A3, W1, T5 rewritten for it); (7) a joiner whose objective died re-picks from its own take (`_follow`) and stores it.

Fix round (review findings 1-3): (1) `_victim` counts only owners of a building with `counts_for_victory`, so a defeated player left with a defence or Tunnel Hub is no victim; the objective pick still runs over all of the victim's buildings. Red first: `test_defeated_enemy_with_defence_is_no_victim` (`build/t16-fix-red.log`) failed with `FAIL: BR5 a player left with only a defence is not live; the wave goes to live player 2, got objective 19 owner 1`. (2) `_mates_ready` and `_gather` share `_at_rally` (squared distance on the `[x, y]` floats, no `Vector2` maths); `_gather`'s old `distance_to` site is gone. (3) SK20 checks memory identity through `waves` (the `prev` key left `_bot`). Results: `test_bot_rules` CASES 34 CHECKS 81 FAILURES 0; `test_skirmish*` CASES 131 FAILURES 5 (S1 2, Cs1, Fm1, HUD1); full suite CASES 1287 CHECKS 152842 FAILURES 9, exit 1, the same nine names with the same values (no pin moved); lint exit 0, warnings exit 0 (190 files), `tools/test_sim_math.py` and `tools/test_sim_boundary.py` OK.
