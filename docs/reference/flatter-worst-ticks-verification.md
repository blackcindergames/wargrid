# Flatter worst ticks verification

```text
Resume record (updated 2026-11-14 night, Task 5 done)
Branch / base commit / working-tree state: flatter-worst-ticks in ~/projects/wargrid-wt-flatter / base 9c8c505 (main 4c21d1a + prep) / only this file modified
Last green task / next incomplete task: Task 6 (measured, uncommitted) / Task 7
Changed paths since last commit: none on the branch (this file and the plan are new in ~/projects/wargrid, uncommitted)
Last command / cases / checks / failures / exit / marker: none on the branch (the review's measurements ran on scratch copies of 74950e5; evidence rows below)
Known red case or blocker: plan approval pending (external readiness review applied 2026-11-14, evidence row below). All 21 Questions decided (user, 2026-11-14). Night settings re-checked at the refresh: worktree folder and Edit rule, compare_replays.py, python3 -I for $L scripts, mkdir -p under flatter-worst-ticks, ssh/scp to the Deck present; $L exists; git status, diff, log, add, commit and archive not named (the handoff's proposed copy adds them; scp fallback in Task D0 Step 4)
Approved decisions, pre-authorizations used, deferred gates: package note "Flatter worst ticks" (user, 2026-11-13); local commits per GREEN task only if the night handoff grants them; benchmark only if the handoff pre-approves it; no budget, ceiling or ASSUMED_SLOWDOWN touched; budget 384 route cells (user, 2026-11-14, round 1); X2 built, erase-and-append kept under the Task 4 Step 6 criterion, worst ticks measured then gated where deterministic (user, 2026-11-14, round 2); Steam Deck rows D0 and D7 report-only, a window on the Deck approved for tonight, Firefox fallback to native rows only (user, 2026-11-14 evening)
Usage so far (python3 tools/session_usage.py <session files>): n/a
Task 3 (2026-11-14 night): GREEN with only R red. Suite `CASES 917 CHECKS 146289 FAILURES 9` (TB3, TB4, Fm1, Cs1, S1 x2, HUD1, VR1 x2), exit 1, logs t3-suite.log; team match won tick=29762 winner=2; profile PROFILE COMPLETE 10; lint 0, warnings 0. Changed: skirmish.gd, test_skirmish.gd, test_skirmish_waves.gd, test_factions.gd, test_playtest_replay.gd, test_skirmish_scene.gd, this file. One unlisted T3-class edit (OD2), see Stagger table.
Task 4 (2026-11-14 night): GREEN with only R red. Suite `CASES 922 CHECKS 146175 FAILURES 10` (TB3, TB4, Fm1, Cs1, S1 x2, HUD1, H1, VR1 x2; all in R), exit 1, logs t4-suite.log; PB1-PB4, X2, X2r/X2m new; budget 384; queue-place criterion met, erase-and-append kept (no fallback); lint 0, warnings 0, run_checks CHECKS PASSED 5, test_sim_boundary 0; profile PROFILE COMPLETE 10; benchmark exit 0, accepted line only; team match `won tick=38786 winner=2 units_peak=268` (exit 1 on the pin line). Changed: simulation.gd, test_groups.gd, test_combat_navigation.gd, test_benchmark.gd, run_movement.gd, run_profile.gd, sim-interface.md, this file. No CASE_SECONDS entry (X2 cases under 1 s). Probe tree left at $L/probe-tree (morning item: git worktree remove).
Next exact action: coordinator commits Task 4; then Task 5 (the one re-pin)
```

Plan: [Flatter worst ticks plan](../superpowers/plans/2026-11-14-flatter-worst-ticks.md) (refreshed onto `4c21d1a`). Spec: `docs/packages.md` night lane item 4 and package note "Flatter worst ticks"; `docs/reference/simulation-reference-review.md` §5.2, §5.8, "Review 2026-11-13"; `docs/reference/hordes300-combat-fire.md`. Logs: `~/projects/wargrid-overnight-work/flatter-worst-ticks/logs/` (outside the repository). Deck logs: `$L/deck/`.

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 0 | Baseline: worktree, import, suite and traces, pins and R census, profile, benchmark, team match, netplay match | Sonnet | GREEN (uncommitted) |
| D0 | Steam Deck rows on the base (start; fetch when done), report-only | Sonnet | PARTIAL 23:40: FETCHED; native rows 3/3 complete, Firefox 1/3 (grep bug stopped the job after run 1); table filled; Deck folder kept for D7 |
| 1 | Retaliators sent home through one reservation map (RS1-RS3), hordes300 benchmark mechanics check | Sonnet | GREEN (uncommitted) |
| 2 | Bot state, old gate (BS1, BS2), cost probe | Sonnet | GREEN (uncommitted) |
| 3 | Bot seats on their own tick (BT1), test edits T1-T4 | Sonnet | GREEN (uncommitted; only R red) |
| 4 | Path budget by route cells (PB1-PB4, X2), movement benchmark mechanics check, queue-place criterion (Question 8) | Sonnet | GREEN (uncommitted; only R red) |
| 5 | The one re-pin | Sonnet | not started |
| 6 | Worst ticks after the changes: count lines, five measured runs | Sonnet | done (uncommitted) |
| 7 | Count gates from Task 6's numbers, red by mutation | Sonnet | GREEN (uncommitted) |
| D7 | Steam Deck rows on the branch head (start; fetch and clean up when done), report-only | Sonnet | not started |
| 8 | Docs and package gate (ledger row) | Sonnet | not started |
| 9 | Fresh-context branch review, one fix round, `/ponytail-review` | Opus (high) | not started |

## Baseline (Task 0)

| Item | Value |
|---|---|
| Tree | main 4c21d1a + prep commit 9c8c505; worktree ~/projects/wargrid-wt-flatter, branch flatter-worst-ticks, clean |
| `uptime` at start / end (suite, profile, benchmark) | suite 1.47 -> (see t0-uptime.txt); profile 2.52 -> 1.33; benchmark 1.20 -> 1.11 (1-min load); alone, no godot/generalszh processes |
| Full suite: wall seconds, CASES, CHECKS, exit | 56 s, CASES 911, CHECKS 146267, FAILURES 0, exit 0, TESTS PASSED 146267 |
| Trace files (`replay`, `economy`, `combat`, `team` `-before.tsv`), line counts | replay 1200, economy 1200, combat 1200, team 100 (in $L) |
| Anchor drift against the plan | none: every symbol of Step 5 found once or as expected; all pin files and lines as in the plan (K2 test_skirmish_scene.gd:41, HUD_TEXTS :646/:676, IC rows :3/:27) |
| `issue_opponent(s)` callers (count, files) | 59 hits of `issue_opponents?(` in game/ = 2 definitions + 1 internal delegate + 56 callers; 15 files: scripts/debug/team_match.gd, benchmarks/run_profile.gd, scripts/net/headless_client.gd, scripts/match/offline_driver.gd, scripts/simulation/scripted_human.gd, skirmish.gd (3), tests: test_defences 1, test_view_rows 3, test_factions 5, test_skirmish_waves 2, test_team_match 2, test_skirmish_match 5, test_skirmish 28, test_playtest_replay 1, test_lockstep 4 |
| Profile: team match `step` mean / max | 1.344 / 10.640 ms (t0-profile.log, exit 0, PROFILE COMPLETE 10) |
| Profile: team match `opponent.decide` max, calls per tick; `snapshot` mean / max | decide max 7.749 ms, 0.03 calls/tick (mean 0.142); snapshot 0.021 / 1.034 ms |
| Profile: team match `step.service_paths` max, `route` max; top `PROFILE_SLOW` lines | service_paths max 9.512, route max 9.506 ms; PROFILE_SLOW: tick 0 step 8.500 (apply_orders 8.386), 30492 step 10.640 (service_paths 9.512), 30480 10.506, 29130 9.948, 30478 9.774, 30490 9.661 |
| Profile: hordes300 `step.combat_fire` max, `assign_move.unavailable` max, `allocation.assign` max, `step` max | combat_fire 5.594, assign_move.unavailable 4.241, allocation.assign 0.970, step 7.868 ms |
| Benchmark: `WORST TICK` lines; combat p95 / p99 per row | WORST TICK ms: movement open 3.535 (t1262), dense 3.675 (t1281); combat open 2.662, dense 3.218, contact 3.625, skirmish3v3 1.635, transports 1.772, defences 2.562, docks 0.640, hordes300 7.605 (t776), ramp 1.658, frc 2.518, lockstep 0.166. p95/p99: open 1.845/2.145, dense 1.829/2.124, contact 1.183/1.553, skirmish3v3 1.352/1.451, transports 1.11/1.2, defences 0.787/2.123, docks 0.586/0.605, hordes300 2.911/3.403, ramp 0.666/1.233, frc 0.856/1.143. exit 0; BENCHMARK PASSED 2, COMBAT BENCHMARK PASSED 10, LOCKSTEP BENCHMARK PASSED 1; `BUDGET EXCEEDED open dense hordes300 (regression ceilings held)` (accepted line) |
| Benchmark: movement open / dense `queue_peak`, `queue_drain_ticks` (Task 7's drain ceiling = 2 × these) | open 292 / 38; dense 292 / 38 (ceiling 76 each) |
| Benchmark: hordes300 `allocation_calls` max (every allocation a full scan before Task 1; Task 7 mutation (e) reference) | max 20.0 (n 1800, p50 0, p95 0, p99 3.0); retaliations_window=159 |
| `run_team_match.sh` line; `TEAM TIMING` max and p99; `team_match` profile `opponent.decide`, `step.service_paths`, `step` max (one run) | `TEAM MATCH won tick=39497 winner=2 units_peak=271` (exit 0); TEAM TIMING p50 1.359 p95 2.384 p99 7.943 max 30.119 ms; profile decide max 8.047, service_paths max 17.867, step max 21.880 ms (host load varies between runs) |
| `run_netplay.sh match` terminal tick | 9129 (NETPLAY PASSED match 13.0 s, exit 0) |

## Pinned values and Re-pin list

Final R (Task 0 Step 4; fixed afterwards):

| # | Pin | Expected (on `4c21d1a`, same as on `74950e5`) | Task 0 | In R | Task 1 | Task 2 | Task 3 | Task 4 | Task 5 new value | Tasks 6-8 |
|---|---|---|---|---|---|---|---|---|---|---|
| V1 | `FINAL_DIGEST` | `3958ceaab11986af` | present, equal | yes | | | red: TB3 `4a8649bd8771d81e` at tick 20000 | red: TB3 `d2f386fa273a0048` at tick 20000 | | |
| V2 | `TEAM_CORE_SERIES` | `8513092129969516499` | present, equal | yes | | | red: TB4 `2358232358664745134` | red: TB4 `7092199221456895974` | | |
| V3 | `S1_CORE_SERIES`, `TERMINAL_TICK`, `WINNER` | `4004499097874677431`, `8753`, `1` | present, equal | yes | | | red: core `3669587849112293937`, tick 8564, winner 1 (inside window) | red: core `8224641749915322152`, tick 8626, winner 1 | | |
| V4 | `CHINA_TERMINAL_TICK`, `CHINA_WINNER`; `FRC_TERMINAL_TICK`, `FRC_WINNER` | `11578`, `2`; `48321`, `1` | present, equal | yes | | | red: China 24423 / winner 2 (Cs1); FRC 37214 / winner 1 (Fm1); both inside caps | red: China 24757 / winner 1 (Cs1); FRC 37178 / winner 1 (Fm1); both inside caps | | |
| V5 | `test_state_hash.gd` `PINNED` | `01e256834bdd4dfb` | present, equal | yes | | | green (moves with the budget only, as in the review) | red (H1): `8248d9c74bdd4dfb` | | |
| V6 | `test_view_rows.gd` `EXPECTED_DIGEST` | `7c7fbc8d…48a9e7` | present, equal | yes | | | red: VR1 x2, `9b513ac33f0caa2fbc3ea79df22860258ffbd4e4db4716120403d06bb9172e85` | red: VR1 x2, `5dce6afed36f1c8b57c590308ff8c067a37e5883fd707499e341b277d37ecb65` | | |
| V7 | `SS6_PINNED` | unchanged | present, unchanged | **no** | | | | | | |
| V8 | four traces | `*-before.tsv` through Task 2; `*-t5.tsv` from Task 5 | saved: 4 `*-before.tsv` | yes | | | traces written as `*-t3.tsv` (differ by design) | | | |
| V9 | netplay match terminal tick | `9129` | present, equal | yes | | | | | | |
| V10 | `run_team_match.sh` | `won tick=39497 winner=2 units_peak=271` | present, equal | yes | | | `won tick=29762 winner=2 units_peak=273` (exit 1, pin line) | `won tick=38786 winner=2 units_peak=268` (exit 1, pin line) | | |
| V11 | `git diff … -- game/tests \| rg '^-\s*const'` | empty before Task 5; R lines only after | n/a | — | | | | | | |
| V12 | `test_skirmish_scene.gd` `HUD_TEXTS` (HUD1, `:646`) | as on the base | present (HUD_TEXTS :646, checked :676) | yes (moves with the stagger, review) | | | red: HUD1 | red: HUD1 (text moved) | | |
| V13 | `input_script_rows.gd` `IC1_ROWS`, `IC2_ROWS` | as on the base | present (IC1_ROWS :3, IC2_ROWS :27) | yes by the census rule (expected not to move, derived) | | | | | | |
| (census) | pins added by the Task 0 rule (`test_dock_lock.gd` `COMMAND_ROWS` is a command-name list, outside R) | | none added: regex hits are exactly V1-V7, V12, V13 and `test_dock_lock.gd:29` COMMAND_ROWS (outside R); tools: 9129 (run_netplay.sh:91) and `won tick` (run_team_match.sh:13) as V9, V10 | | | | | | | |

Task 5 re-pin (2026-11-14 night, old -> new; Re-pin list only). Diagnosis evidence (coordinator Opus high, `$L/d5-*`): GO; every moved value on the Re-pin list, inside caps and windows, equal to the plan's Expected values at budget 384 (S1 8626/1, China 24757/1, FRC 37178/1, team 38786/2/268); V5/H1 moved by the budget alone; V13 did not move; V9 left to the probe below.

| Pin | Old | New |
|---|---|---|
| V1 `FINAL_DIGEST` | `3958ceaab11986af` | `d2f386fa273a0048` |
| V2 `TEAM_CORE_SERIES` | `8513092129969516499` | `7092199221456895974` |
| V3 `TERMINAL_TICK` / `WINNER` | `8753` / `1` | `8626` / `1` (inside 7000-17999) |
| V3 `S1_CORE_SERIES` | `4004499097874677431` | `1304276675012125868` (series loops over `TERMINAL_TICK + 1`, so it is not the Task 4 `got` value `8224641749915322152`; the Task 4 value was measured over the old length; two runs agree on the new one) |
| V4 China tick / winner | `11578` / `2` | `24757` / `1` (cap 45000) |
| V4 FRC tick / winner | `48321` / `1` | `37178` / `1` (cap 50000) |
| V5 `PINNED` | `01e256834bdd4dfb` | `8248d9c74bdd4dfb` |
| V6 `EXPECTED_DIGEST` | `7c7fbc8d...48a9e7` | `5dce6afe...ecb65` |
| V9 netplay terminal tick | `9129` | `9013` (probe: seats compared `REPLAYS MATCHED 301`; rerun `same_hashes` incl. oracle passed) |
| V10 team match | `won tick=39497 winner=2 units_peak=271` | `won tick=38786 winner=2 units_peak=268` (cap 45000) |
| V12 `HUD_TEXTS` | `Rifleman #50`, `Rifleman #20` | `Rifleman #49`, `Rifleman #19` |
| V13 `IC1_ROWS`, `IC2_ROWS` | | did not move, left alone |

Task 5 checks: `SUITE(t5)` and `SUITE(t5b)` each `CASES 922 CHECKS 146175 FAILURES 0`, exit 0, `TESTS PASSED 146175`; four traces `cmp` silent t5 vs t5b (new reference `*-t5.tsv`); team match exit 0 `won tick=38786 winner=2 units_peak=268`; netplay match/perturb/relay-down/relay-term `NETPLAY PASSED`; `CONFORMANCE PASSED 41`; run_checks `CHECKS PASSED 5`, lint 0, warnings 0. Logs `t5-*` in `$L`.

Final R = V1-V6, V9, V10, V12, V13 (as planned; no census additions). Splash index (evidence only, `PROFILE` lines in t0-profile.log): calls per tick 0.00-0.34 with mean 0.001-0.044 ms in contact, skirmish3v3, open, dense, team_match (0.18/tick, 0.034 ms); no zone line in hordes300 or large_196 at mean level; no growth with workload size beyond calls/tick.

Bounds that never move (checked at Task 5): `CHINA_TICK_CAP` 45000, `FRC_TICK_CAP` 50000, S1 window 7000-17999, team match cap 45000. Any winner inside them (plan Questions 11, 20).

Non-pin checks that go red and their allowed edit (review, measured on `74950e5`): 21 bot cases in `test_skirmish.gd`, `test_skirmish_waves.gd`, `test_factions.gd`, `test_playtest_replay.gd` (T1-T3); K2 `test_skirmish_scene.gd:48` on `4c21d1a` (`:45` on `74950e5`) (T4); G7, G8, BM5 per-unit (P1). A2 stays green (rewritten anyway). Converted by census although green: `test_skirmish.gd:195`, `:258` (checks; calls `:194`, `:257`), `test_factions.gd:248` (vacuous under the stagger).

## Reservation map (Task 1)

| Item | Value |
|---|---|
| Red (stub counters) | `t1-red.log`: RS1 (0 checks), RS1 opens-once, RS2 first half, RS3 (0 checks) fail by name; CASES 85, FAILURES 4 |
| Green: `test_combat` cases / checks / failures | 85 / 2648 / 0 |
| RS1 checks / mismatches; RS3 checks / mismatches and seconds | RS1 4 / 0; RS3 40 / 0; RS3 not timed separately (whole `test_combat` run is seconds), no CASE_SECONDS entry |
| Mutations (a)-(c) | (a) drop attack-branch -1: RS1 3 mismatches (needed A2 spawned between retaliators; with A2 last it stayed green); (b) drop trailing +1: RS1 3 mismatches, RS3 37; (c) drop end: RS1 closed, RS3 20; (d) end inside loop: RS1 opens-once; (e) no begin: 4 red. All reverted, diff stat = Owns paths |
| Combat benchmark red with the fix reverted (`no retaliator was sent home through the reservation map inside the timed window`, exit 1) | exit 1, error line hit, `reserved_window=0` (`t1-combat-red.log`, load 4.10 at start) |
| Combat benchmark green: `COMBAT BENCHMARK PASSED 10`, hordes300 `reserved_window` | exit 0, PASSED 10, `reserved_window=154`; open/dense p95 over budget as on base (accepted); hordes300 p95 2.903 p99 3.314; WORST TICK hordes300 4.256 ms (t1080) vs 7.605 base; load 3.20 at start |
| hordes300 `step.combat_fire` max before / after (probe: 5.403 → 1.067 ms) | 5.594 -> 1.059 ms |
| hordes300 `allocation.reserved` max and calls; `assign_move.unavailable` max; `step` max | reserved max 0.435 ms, 0.09 calls/tick; unavailable max 0.739 (was 4.241); allocation.assign max 0.190 (was 0.970); step max 4.308 (was 7.868); profile exit 0, PROFILE COMPLETE 10 |
| Digest script (`$L/t1-digest.gd`) `main` against branch | 105 DIGEST lines each, diff identical; ALLOC lines identical |
| Suite and traces | `SUITE(t1)` exit 0, CASES 914, CHECKS 146276, FAILURES 0, TESTS PASSED 146276; four traces cmp silent against `*-before.tsv`; lint exit 0, warnings exit 0 (167 files), run_checks CHECKS PASSED 5 |

## Bot state (Task 2)

| Item | Value |
|---|---|
| Field census (fields `skirmish.gd` reads from the state) | As expected: `tick`, `last_sequences`, `players` id/credits/team/faction, `buildings`, `entities` id/owner/kind/position/combat mode+target_id, `hole_id`, `container_id`; nothing extra |
| Red on the stub | 5 named failures (BS1 x4, BS2), `CASES 3 CHECKS 7 FAILURES 5` |
| BS1 comparisons per world; contained and hole rows seen | team match 10, contained 1, rebuild hole up to 180 (every 10 ticks); both row kinds seen (green) |
| Cost probe: µs per `snapshot()` / per `bot_state()` at team match tick 6000 (best of three rounds of 100), ratio, entities; `PROBE DONE` seen | 724.7 / 180.3, ratio 0.249, 205 entities; `PROBE DONE` seen (load average about 1.9) |
| Gate (ratio at most 0.5; review measured 0.25): met / not met | met |
| Mutations | drop `container_id` line: BS1 contained and row-seen checks fail; `_buildings.values()`: BS2 fails; both reverted (`cmp` against backup silent) |
| Suite, traces `cmp` against `*-before.tsv`, team match and netplay match lines | Suite exit 0, `CASES 916 CHECKS 146281 FAILURES 0`, `TESTS PASSED`; four traces `cmp` silent; team `won tick=39497 winner=2 units_peak=271` (V10); netplay `match terminal tick 9129`, `NETPLAY PASSED` (V9); lint exit 0, warnings exit 0 (167 files); tree: Task 1 commit plus Task 2 edits |

## Stagger (Task 3)

| Item | Value |
|---|---|
| BT1 red on Task 2 code; green | red: `CASES 1 CHECKS 7 FAILURES 7` (6 commands, all 6 off; first ticks 1,2,8,4,5,6 instead of tick 0); green after `decides`/`next_decision`/`decide`: `CHECKS 7 FAILURES 0` |
| Allowed test edits applied (file:line, kind T1 / T2 / T3 / T4); T1 census count | T1 (single-shot to `decide`): test_skirmish.gd 10 calls (O1 `:167`/`:195`, A3 `:246` `:251` `:258`, B4 `:99` `:105`, W2 `:292`, W3 `:308` `:314`) + `_decide_now` `:339` + SK-S3 rally `:663` (now `Skirmish.decide(sim, 1, 0)`) + `_decide` helper `:79` gated with `Skirmish.decides`; test_skirmish_waves.gd `_decide` helper; test_factions.gd 3 (B1 x2, B2); test_playtest_replay.gd RP2. T2: 5 `_to_tick(... next_decision(sim.tick(), 2))` + `_decide_now` + waves 2 (`:66`, `:80`). T3: waves W1 two bounds `+ 2`. T4: K2 as specified. One unlisted edit, T3 class: `test_skirmish_scene.gd` OD2 `test_offline_driver_bot_memory_on_simulation` loop bound `Skirmish.ATTACK_TICK` -> `Skirmish.next_decision(Skirmish.ATTACK_TICK, 2)` (the single `driver.step` must land on seat 2's tick; red otherwise, not in the plan's measured list; flagged to the coordinator) |
| `decide` no-op mutation: O1, A3, B1 positive checks red | yes: O1 "first decision places the mirrored..." red (case then incomplete), A3 7 checks red, B1 "trains a builder" and "trained builder exists" red; reverted (`cmp` against backup silent) |
| Red checks after the edits (must all be R; value reported) | `CASES 917 CHECKS 146289 FAILURES 9`, all R: TB3, TB4 (V1, V2), Fm1 and Cs1 (V4), S1 pinned outcome and core series (V3), HUD1 (V12), VR1 x2 (V6); values in the pin table above |
| Team match line (exit 1 expected on the pin; `won` below 45000) | `TEAM MATCH won tick=29762 winner=2 units_peak=273`, exit 1; `TEAM TIMING` p50 1.806 p95 3.259 p99 4.673 max 11.791 ms |
| team match `opponent.decide` max and calls per tick; `bot_state` mean / max; `step` mean / max | decide max 3.362 ms (was 7.749), 0.20 calls/tick (seat decisions; was 0.03 shared, so 0.18 per seat-tick of 6 seats = 0.03 x 6); `bot_state` mean 0.0354 / max 0.549 ms; `step` mean 1.693 / max 10.770 ms (was 1.344 / 10.640; the match runs 10k fewer ticks, so denser per tick). `PROFILE COMPLETE 10`, exit 0, load about 2 during the team match and the profile |

## Route cells (Task 4)

Expected from the review (today's cap; `verify-copy/logs/p-*-b0.tsv`): team match 14726 requests, route 7 / 185 / 280, searched 20 / 3759 / 16397, searched ÷ route 20.3, per-tick searched max 102413, max queue 153; movement searched ÷ route 3.00 (open), 4.54 (dense).

| Scenario | requests | route cells per request p50 / p95 / max | searched cells per request p50 / p95 / max | searched ÷ route | per-tick route sum p99 / max | per-tick searched max | ticks with more than 8 requests | max queue length |
|---|---|---|---|---|---|---|---|---|
| team match (V10 line unchanged by the probe: yes, `won tick=29762 winner=2`) | 14972 | 10 / 192 / 284 | 27 / 7399 / 15052 | 21.81 | 1557 / 2157 | 110835 | 0 (cap 8 never exceeded) | 233 |
| movement open (one leg) | 300 | 81 / 94 / 99 | 244 / 283 / 298 | 3.01 | 738 / 738 | 2222 | 0 | 300 |
| movement dense (one leg) | 300 | 81 / 94 / 99 | 227 / 267 / 281 | 2.82 | 738 / 738 | 2046 | 0 | 300 |
| combat open | 1309 | 6 / 54 / 64 | 16 / 163 / 193 | 2.93 | 440 / 443 | 1337 | 0 | 300 |
| combat dense | 1134 | 6 / 55 / 64 | 17 / 252 / 372 | 3.69 | 441 / 443 | 2224 | 0 | 300 |
| combat hordes300 | 1814 | 8 / 61 / 73 | 22 / 181 / 220 | 2.92 | 502 / 538 | 1622 | 0 | 300 |

| Item | Value |
|---|---|
| PB1-PB4 red on today's cap (stub `path_cells`) | `t4-red-test_groups.log`: PB1 phases 0 and 1, PB2, PB3, PB4 and X2 / X2m per-tick budget rule fail by name (`CASES 15 FAILURES 7`); every other X2 check passes on today's code |
| Rewritten checks (G7 → PB1, G8, A2, snapshot ceiling step: drain step, totals, busiest unit) | all green at 384; BM5 per-unit and total ceilings held at the drain step (`test_benchmark` CASES 27 FAILURES 0); A2 green on the stub too (pins the rule, trivially met there) |
| Mutations (a)-(c) | (a) empty route not charged: PB3 red; (b) skip a search that would cross the budget (scratch form with a Manhattan estimate, first request always served, so PB2 itself stayed green): PB1 x6, X2 full-budget rule, X2 and X2m drain bound red; (c) no reset: PB1 x9, PB2, PB3, PB4, X2, X2m, G8, G3 red (23 failures); (d) budget 1000000: PB1 bound, PB2, X2 bound red; all reverted (`git diff --stat` = Owns paths) |
| Movement benchmark red on the stub (`path budget never bound`, exit 1); green `path_capped_window` open / dense | red: exit 1, error hit for `open` (`t4-movement-red.log`); green: 60 / 60 |
| `PROFILE_PATHS team_match` (capped ticks, max cells; review: 847 at 384) | `capped_ticks=853 max_cells=643 budget=384` |
| team match `step.service_paths` max, `route` max, `step` max, `opponent.decide` max | 3.435, 3.433, 5.170, 2.127 ms (Task 3: 9.5, 9.5, 10.77, 3.362); `PROFILE COMPLETE 10`, exit 0, load 2.72 -> 1.87 |
| Movement `queue_peak` / `queue_drain_ticks` open, dense (Task 0 → Task 4; stop if more than double; review: dense 38 → 60 at 384) | open 292 / 38 -> 295 / 60; dense 292 / 38 -> 295 / 60 (1.58x, under 2x; one-leg WAIT drain 56 each, the benchmark's max over legs 60 is at least that) |
| Combat p95 / p99 per row; `WORST TICK` lines | p95 / p99: open 1.874 / 2.221, dense 1.833 / 2.138, contact 1.174 / 1.531, skirmish3v3 1.339 / 1.442, transports 1.121 / 1.216, defences 0.774 / 2.154, docks 0.584 / 0.602, hordes300 2.903 / 3.392, ramp 0.65 / 1.227, frc 0.884 / 1.07. WORST TICK ms: movement open 3.489 dense 3.544; combat open 2.584, dense 2.901, contact 3.576, skirmish3v3 1.696, transports 1.758, defences 2.590, docks 0.618, hordes300 3.993, ramp 1.798, frc 1.768, lockstep 0.161. exit 0; BENCHMARK PASSED 2, COMBAT BENCHMARK PASSED 10, LOCKSTEP BENCHMARK PASSED 1; only the accepted `BUDGET EXCEEDED open dense hordes300 (regression ceilings held)`; load 1.96 -> 1.49, nothing else running |
| Red checks in the suite (must all be R; value reported) | `CASES 922 CHECKS 146175 FAILURES 10`, all R: TB3, TB4, Fm1, Cs1, S1 x2, HUD1, H1 (V5), VR1 x2; values in the pin table; traces `*-t4.tsv` in $L (not compared: V8 moves at Task 5) |
| Team match line | `TEAM MATCH won tick=38786 winner=2 units_peak=268` (exit 1 on the pin line, as the review's model); `TEAM TIMING` p50 1.414 p95 2.832 p99 3.855 max 6.468 ms |

X2 (derived expectation, plan "Expected values": today 23 ticks; at 384 about 90, between 89 and 132; at least about 34200 route cells):

| Item | Today (Step 2, 8-request cap) | Task 4 (384) |
|---|---|---|
| `X2 ashfall` `drain_ticks` / `route_cells` / `max_queue` / `capped_ticks` / `searches` | 23 / 42390 / 172 / 22 / 180 | 88 / 42390 / 178 / 87 / 180 |
| X2 checks red on today's code (only the per-tick budget rule expected) | only `X2 each tick starts no search…` and `X2m the re-queued burst…` | — |
| X2r / X2m checks | all green except X2m budget rule (red as expected) | all green |
| Mutation (d) `PATH_CELLS_PER_TICK` 1000000: "X2 the budget bound" red | — | red (0 ticks), as designed |
| Case seconds (both X2 cases; `CASE_SECONDS` entries added) | — | each run ends in 1.2 s wall including Godot start (a trivial case also 1.2 s): under 1 s, no entries |
| Drain ratio against today (morning feel item) | — | 88 / 23 = 3.8x (beyond the 2x rule, which was set on the 64 x 64 rows; the work bound holds); route cells 42390 vs the derived 34200 |

## Queue place (Task 4, Question 8)

| Scenario | requests | drain | max_queue | max_wait | p99_wait | max_reappends | units_reappended |
|---|---|---|---|---|---|---|---|
| team match, probe tree (today's cap) | 5962 | — | 225 | 30 | 28 | 2 | 148 |
| team match, `$W` | 3287 | — | 146 | 47 | 36 | 1 | 9 |
| movement open (one leg) | 295 | 56 | 295 | 56 | 56 | 0 | 0 |
| movement dense (one leg) | 295 | 56 | 295 | 56 | 56 | 0 | 0 |
| X2 | 178 | 88 | 178 | 88 | 87 | 0 | 0 |

| Criterion | Value | Met |
|---|---|---|
| (a) movement and X2: `max_reappends == 0`, `max_wait == drain` | 0 and 56 / 56 / 88 (X2 = `X2 ashfall` drain 88) | yes |
| (b) team: `max_reappends <= max(2, today's)` | 1 <= max(2, 2) | yes |
| (c) team: `max_wait <= 3 × X2 drain_ticks` | 47 <= 264 | yes |
| Fallback (keep the chaser's slot): not needed / applied (PB5 red first, then green; suite red only on R and P1) / reverted and Task 4 parked (why) | not needed (erase-and-append kept; no PB5, `combat.gd` untouched) | — |

## Re-pin (Task 5)

| Pin | Old | New | Read from |
|---|---|---|---|
| | | | |

Sanity row (review, measured on scratch copies with stagger plus budget; a different number means the change differs from the review's model, for example a field missing from `bot_state`): at 384: S1 8626 / 1, China 24757 / **1**, FRC 37178 / 1, team `won` 38786 / 2 (`units_peak` 268), netplay match not run, HUD1 not recorded; at 256: S1 9685 / 1, China 12085 / 2, FRC 17372 / 1, team 34412 / 2, netplay 8782.

| Item | Value |
|---|---|
| Bounds (China, FRC, S1 window, team cap) | |
| `SUITE(t5)` and `SUITE(t5b)`: cases / checks / failures; trace `cmp` t5 against t5b | |
| Netplay probe on the old literal: terminal tick N; `compare_replays.py` s1 against s2 (`REPLAYS MATCHED`, or refused) | |
| Team match; netplay `match` (seats and oracle agree), `perturb`, `relay-down`, `relay-term`; conformance | |
| `git diff --stat <Task 4 commit>`; V11 | |
| Re-pin commit hash | |

## Worst ticks after the changes (Task 6)

Tree: flatter-worst-ticks at the Task 5 re-pin commit 12fd911 plus the three report-only count lines (uncommitted). Runs alone; `uptime` at start / end per run; tagged runs ("host under load") rerun once.

| Run | benchmark load start / end, exit | team match load, exit | profile load, exit |
|---|---|---|---|
| 1 | 3.75 / 3.08, exit 0, host under load; rerun 1b 1.58 / 1.32, exit 0 | 1.31 / 1.33, exit 0 | 1.54 / 1.20, exit 0 |
| 2 | 2.99 / 2.67, exit 0, host under load; rerun 2b 1.32 / 1.62, exit 0 | 1.31 / 1.36, exit 0 | 1.18 / 1.35, exit 0 |
| 3 | 2.53 / 1.92, exit 0, host under load; rerun 3b 1.57 / 1.38, exit 0 | 1.33 / 1.18, exit 0 | 1.33 / 1.73, exit 0 |
| 4 | 1.84 / 1.47, exit 0 | 1.18 / 1.24, exit 0 | — |
| 5 | 1.51 / 1.34, exit 0 | 1.54 / 1.50, exit 0 | — |

All five benchmark runs print `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`; team runs `TEAM MATCH won tick=38786 winner=2 units_peak=268`; profiles `PROFILE COMPLETE 10`. Wall-clock below uses the five untagged benchmark runs (1b, 2b, 3b, 4, 5). Logs `$L/t6-*.log`. SUITE(t6): exit 0, CASES 922, CHECKS 146175, FAILURES 0, `TESTS PASSED 146175`; the four traces `cmp` silent against `*-t5.tsv`; `run_checks.sh` `CHECKS PASSED 5`.

Deterministic counts (must be identical in every run; a difference is a stop):

| Count | Row | Value (all runs) |
|---|---|---|
| movement open / dense `queue_drain_ticks` | `run_movement.gd` | 60 / 60 (Task 0: 38 / 38) |
| movement open / dense `path_cells_peak_window`, `path_capped_window` | `run_movement.gd` | 400 / 400, 60 / 60 |
| hordes300 `full_scans_peak_window`, `reserved_window` | `run_combat.gd` | 3, 160 (Task 0 allocation_calls max 20) |
| team `capped_ticks`, `max_cells`, `max_queue`, `max_decisions` | `run_team_match.gd` | 853, 643, 146, 1 |
| `X2 ashfall` line (SUITE(t6)) | `test_groups.gd` | drain_ticks=88 route_cells=42390 max_queue=178 capped_ticks=87 searches=180 |

Wall-clock (untagged runs; report-only):

| Figure | Task 0 | min / median / max | spread | proposed ceiling (worst + 5 %, not installed) |
|---|---|---|---|---|
| `WORST TICK` movement open / dense | 3.535 / 3.675 | 3.413 / 3.455 / 3.472; 3.495 / 3.528 / 3.641 | 1.7 % / 4.1 % | 3.646 / 3.823 |
| `WORST TICK` combat hordes300, contact (and the other 9 lines) | hordes300 7.605; open 2.662, dense 3.218, contact 3.625, skirmish3v3 1.635, transports 1.772, defences 2.562, docks 0.640, ramp 1.658, frc 2.518, lockstep 0.166 | hordes300 3.944 / 3.961 / 3.986 (1.1 %, ceil 4.185); contact 3.558 / 3.590 / 3.617 (1.6 %, 3.798); open 2.573 / 2.583 / 2.620 (1.8 %, 2.751); dense 2.885 / 2.898 / 4.662 (61 %, one spike run, 4.895); skirmish3v3 1.679 / 1.693 / 1.711 (1.9 %, 1.797); transports 1.748 / 1.759 / 1.771 (1.3 %, 1.860); defences 2.573 / 2.590 / 2.605 (1.2 %, 2.735); docks 0.623 / 0.632 / 0.654 (4.9 %, 0.687); ramp 1.769 / 1.777 / 1.811 (2.4 %, 1.902); frc 1.770 / 1.782 / 1.804 (1.9 %, 1.894); lockstep 0.160 / 0.166 / 0.176 (9.6 %, 0.185) | see cell | see cell |
| `TEAM TIMING` max / p99 | 30.119 / 7.943 | max 6.344 / 6.377 / 6.419; p99 3.832 / 3.840 / 3.862 | 1.2 % / 0.8 % | 6.740 / 4.055 |
| team `opponent.decide` max | 8.047 | 2.109 / 2.135 / 2.145 | 1.7 % | 2.252 |
| team `step.service_paths` max | 9.512 (profile run) | 3.381 / 3.416 / 3.454 | 2.1 % | 3.627 |
| team `step` max | 10.640 (profile run) | 5.144 / 5.190 / 5.230 | 1.7 % | 5.492 |
| hordes300 `step.combat_fire` max (`run_profile.sh`) | 5.594 | 1.501 / 1.514 / 1.516 (3 runs) | 1.0 % | 1.592 |

## Count gates (Task 7)

| Figure | Row and file | Task 6 value | Threshold (rule) | Mutation | Red seen | Installed |
|---|---|---|---|---|---|---|
| `queue_drain_ticks` open / dense | `run_movement.gd` | 60 / 60 | 76 / 76 (2 x Task 0's 38; 60 sits under it) | (a) budget 128 | yes: `over the ceiling for open` (t7-red-a.log) | yes |
| `path_cells_peak_window` open / dense | `run_movement.gd` | 400 / 400 | 500 / 500 | (b) budget 768 | yes: movement `over the ceiling for open`; (t7-red-b.log) | yes |
| `max_decisions` | `run_team_match.gd` | 1 | exactly 1 | (c) shared tick | yes: `TEAM PATHS FAIL ... max_decisions=6` (t7-red-c3-team.log; first tries failed to compile or ran no bots, discarded) | yes |
| `max_cells` | `run_team_match.gd` | 643 | 804 (ceil 803.75) | (b) budget 768 | yes: `TEAM PATHS FAIL max_cells=1027 ceiling=804` | yes |
| `capped_ticks` | `run_team_match.gd` | 853 | > 0 | (d) budget 1000000 | yes: `TEAM PATHS FAIL capped_ticks=0` | yes |
| `full_scans_peak_window` | `run_combat.gd` | 3 | 4 (max(ceil 3.75, 3+1)) | (e) Task 1 Step 5 reverted (+ reserved block deleted) | yes: full_scans_peak_window=38, `full-scan allocations ... over the ceiling` | yes |
| Green: `SUITE(t7)` exit 0, CASES 922 CHECKS 146175, `TESTS PASSED 146175`, four traces `cmp` silent against `*-t5.tsv`; `run_benchmark.sh` exit 0 with its markers (`path_cells_peak_window=400`, `queue_drain_ticks=60`, `full_scans_peak_window=3`); `run_team_match.sh` exit 0, `TEAM PATHS PASS capped_ticks=853 max_cells=643 ceiling=804 max_decisions=1`; `run_checks.sh` `CHECKS PASSED 5`. All mutations reverted (`git diff --stat` shows only benchmark, script and doc files). | | | | | | |

## Deck rows (Tasks D0 and D7, report-only)

Never a gate (user, 2026-11-14). Deck address: night handoff only. Logs: `$L/deck/logs-base/`, `$L/deck/logs-after/`.

| Item | Base (Task D0) | After (Task D7) |
|---|---|---|
| Tree | `4c21d1a` (git archive; scratch worktree under $L/deck) | |
| Preflight (ACAD, Desktop Mode, Firefox version, load) | OK: ACAD 1, Desktop Mode, Firefox 160.0, load 0.07, no leftover units or folder | |
| Godot install: SHA-256 checked (`install.log`) | installed 4.7.2 via `install_godot.py` against the CI SHA-256 (empty log, script exits on failure; no `INSTALL FAILED`) | (reused or installed) |
| ACAD at every edge; Deck load range (`edges.txt`) | ACAD 1 at all edges; 1-min load 0.03-1.26 (22:40-23:28) | |
| `FAILED` / `SKIPPED` edge lines | `WEB FAILED run 1` at 23:28:45, then `DONE`: the job stopped after one Firefox run. Cause: its check greps `cross_origin_isolated=true`, the bench prints `cross_origin_isolated=1`; the run itself is complete (below). Morning item: fix the grep to `=1`/`=true` for Task D7 | |
| Native profile x3: `PROFILE COMPLETE 10` each; hand-off sum per tick per workload, median [range] | 3/3 `PROFILE COMPLETE 10`, exit=0. view_state+copy+sort+batch ms: movement open 4.731 [4.718-4.741], dense 4.667 [4.661-4.672]; team match 4.510 [4.505-4.516]; large_196 6.088 [6.078-6.090]; combat hordes300 6.366 [6.282-6.372], open 3.152 [3.140-3.184], dense 2.753 [2.749-2.760], skirmish3v3 1.848, contact 1.081, skirmish match 0.886. Team match `step` mean 5.26-5.29, max 31.6-32.0 | |
| Native combat x3: ten `COMBAT` lines each; p95 median [range] / p99 per layout | 3/3 logs, 26 `COMBAT` lines each (more than ten layouts), exit=1 (expected). p95 [range] / p99 / max ms: open 6.760 [6.748-6.781] / 7.756 / 9.618; dense 6.674 [6.643-6.699] / 7.561 / 11.173; contact 4.075 / 5.385 / 12.322; skirmish3v3 4.684 / 5.006 / 5.549; hordes300 10.632 [10.599-10.663] / 12.357 / 26.754 (`$L/deck/base-combat.txt` has all) | |
| Web Bench export (exit, files); `hordes300` added in the scratch copy | import 0, export 0; index.html/wasm/pck present; copied to Deck | |
| Firefox runs: `cross_origin_isolated=true`, `BENCH DONE`, UA version | 1 of 3 runs: `cross_origin_isolated=1`, `BENCH DONE`, Firefox 160.0. Runs 2 and 3 not run (job stopped, see FAILED line); the 1-run row has no range | |
| Firefox: team match (end tick) p50 / p95 [range] / p99 / max | won tick 39497: 7.52 / 12.92 / 43.4 / 73.9 (n=1; mean 8.245; worst tick 9540) | |
| Firefox: combat open, dense, hordes300 p50 / p95 [range] / p99 | open 6.74 / 9.94 / 11.26; dense 5.52 / 9.88 / 11.30; hordes300 11.04 / 15.58 / 18.02 (n=1); also contact 1.40 / 6.20 / 8.18, skirmish3v3 3.12 / 7.14 / 7.58; movement open p95 4.24, dense 4.52 | |
| After ÷ base per row | — | |
| Deck cleaned up (folder, units, profiles, no Godot process) | — | |

## Task 8 gates

| Gate | Result |
|---|---|
| Docs (chapters and references changed, footers) | |
| `roadmap.py` and `--check`; `check_public.sh`; link check | |
| `SUITE(final)`, `cmp` against `*-t5.tsv` | |
| `run_checks.sh`; conformance; netplay four scenarios; team match; profile | |
| `git diff --stat main -- game/scripts/presentation game/scenes relay protocol game/data .github` | |
| Benchmark `PERF_LABEL="Flatter worst ticks"`, alone, `uptime` | |
| Deck History rows (native, Firefox 160): written by Task 8 / by Task D7 Step 4 | |

| Worst tick (single runs; Task 6 holds the spread) | Task 0 | Task 8 |
|---|---|---|
| team match `step` max (profile) | | |
| team match `opponent.decide` max | | |
| team match `step.service_paths` max | | |
| hordes300 `step.combat_fire` max (profile) | | |
| combat hordes300 `WORST TICK` (benchmark) | | |

## Unverifiable at night (for the morning)

- CI on Linux and Windows with the re-pinned values and traces (`godot-replays`), and `sh tools/compare_local_traces.sh <run id>` for macOS: need a pushed branch (push needs approval). A re-pin makes this the most important morning check.
- Browser: digests of the stagger and path budget on wasm against native (no new float maths, so expected equal; unmeasured). Deck Firefox timing is Task D0 / D7's report-only row; if either fell back to native only, the Firefox rows are a morning item (user, 2026-11-14).
- Rendered benchmark: not needed (presentation unchanged); confirm Task 8 Step 3's diff is empty.
- Bot play after the stagger: the bots act two to eight ticks later than before; no attended match is required by the package, one short offline match is optional.
- X2: cross-map group starts on Ashfall drain about 3.9× slower than today (derived; measured value in "Route cells"): one short attended check whether a large cross-map order feels late; Question 15's 2× rule covers only the 64 × 64 rows.
- Wall-clock worst-tick ceilings: Task 6's proposals (worst + 5 %) are the user's decision; none installed at night.
- If Task 4 parked on Question 8: back of the queue with the measured starvation, or keep-slot with its fallout (the user's call).
- Remove the scratch worktrees `$L/probe-tree` (Task 4), `$L/deck/web-tree-base` and `$L/deck/web-tree-after` (Tasks D0, D7) with `git worktree remove`; not in the night allow list.
- If Task D7 did not run its Step 4: remove `~/wargrid-flatter` on the Deck and check no `wargrid-flatter*` unit or Firefox profile is left.
- Proposed night allow rule `Bash(git archive:*)` (Tasks D0, D7 have a fallback without it).
- Task 9 fixes that change `game/` after Task D7 make the Deck after rows one commit stale.
- Commands the night permissions refused, each with its exact text (filled in by the run).

## Evidence rows (append-only)

- 2026-11-14, plan writing (backup 1 of the One controller night run), tree `~/projects/wargrid` `main` `74950e5` clean, read-only (no suite, no benchmark, no profile, no Godot run). Read: `AGENTS.md`; `docs/packages.md` night lane and package note; simulation review §5.2, §5.8, "Review 2026-11-13"; `docs/reference/hordes300-combat-fire.md` and its probe diffs and digest script in `~/projects/wargrid-overnight-work/tighter-gates/`; design answers "Simulation reference review" and "Package review, second pass"; `docs/reference/performance.md` status table and budgets; `docs/reference/perf-history.csv` (last rows `ae09473`: combat open 1.834 / 2.113, dense 1.806 / 2.117, hordes300 2.884 / 3.372 ms p95 / p99); `docs/reference/determinism-rules.md`; `docs/reference/sim-interface.md`; the Sim quick wins plan and verification file (format); the One controller plan's pins (V8-V11). Code anchors on `74950e5`: `simulation.gd` `PATH_REQUESTS_PER_TICK` `:21`, `_allocation_calls` `:46`, `_unavailable_cells` `:322-335`, `_assign_move` `:422-450`, `_stop_unit` `:461-466`, `_service_paths` `:468-473`, `step` `:507-585` (`_service_paths` call `:550`), `_assign_route` `:627-638`, `_snapshot` `:707-724` (`last_sequences` `:715-719`), `_sorted_copies` `:784`, `issue_command` `:159-171`, `remove_object` `:827-847`; `combat.gd` `object_removed` `:612-622`, `_go_home` `:674-679`, `_plan_retaliate` `:681-696`, `_approach` `:207-229`; `destination_allocation.gd` `assign` `:5-50` (`has` at `:69`); `grid_navigation.gd` `route` `:108-127`; `skirmish.gd` `DECISION_TICKS` `:11`, `issue_opponents` `:67-72`, `_decide` `:74-89`, `_bot` `:161-164`; `team_match.gd` `SEATS` (1, 2, 8, 4, 5, 6) and `step`; `run_profile.gd` `_fixed` `:84-95`, `_team_match` `:129-141`; `test_groups.gd` `:149-234`; `test_combat_navigation.gd` A2 `:112-129`; `test_benchmark.gd` `:103-112`; `test_playtest_replay.gd` RP2 `:40-46`. Findings: (1) the tests that assume 8 requests per tick are G7, G8, A2 and the fixed step 38 of the snapshot ceiling test, so Task 4 rewrites them by rule; (2) about 25 bot test call sites assume a decision on `tick % 30 == 0`, hence the ungated `decide()` and the Allowed test edits; (3) pins beyond the Sim quick wins list move: the three skirmish match outcomes (`TERMINAL_TICK`, `CHINA_TERMINAL_TICK`, `FRC_TERMINAL_TICK` with winners) and `test_state_hash.gd` `PINNED` (12 requests on tick 0 of the replay world); `FRC_TERMINAL_TICK` 48321 sits 1679 ticks under its 50000 cap; (4) a per-seat bot state on the same tick decides exactly as the shared snapshot, because `issue_command` changes only `_pending` and that seat's `_last_sequences` entry; (5) the hordes300 probe diff applies to today's `_assign_move` and `object_removed` (the hash ring and `advance` split did not touch them); (6) Zero Hour sources at `0a05454`: `PATHFIND_CELLS_PER_FRAME=5000` (`AIPathfind.cpp:1103`), reset and loop (`:5923`, `:5927`), cells counted in `cleanOpenAndClosedLists` (`:4812-4822`), queued requests keep their slot (`:5663-5667`), `LOGICFRAMES_PER_SECOND = 30` (`GameCommon.h:72`), `PATHFIND_CELL_SIZE 10` (`AIPathfind.h:439`); AI players read live objects (`AIPlayer.cpp:2195`, `:3039`) and keep per-player countdowns (`:2916-2922`), with no shared decision tick found (corrected by the review row below: the countdowns all start at 0 and only drift apart; no deliberate stagger). Not verified: the route-cell to searched-cell ratio behind the 256 value (assumed 3); the bot state's cost (Task 2 probe); which tests break beyond the census; whether the budget binds in the team match (expected, Task 4 profile check); the new pinned values and whether the FRC match stays under its cap; the pins One controller adds (`IC1_ROWS`, `IC2_ROWS`, HUD summaries) and whether their scripts run a bot; Zero Hour's AI cadence beyond the two timers read.
- 2026-11-14, plan revision after the fresh-context review (Opus), docs only; nothing re-measured in this revision. Source: `~/projects/wargrid-overnight-work/one-controller/flatter-worst-ticks/review.md` (tree `main` `74950e5` exported into scratch copies under `verify-copy/`; host under load, load average 1.8 to 5.7, so its µs numbers are ratios; logs in `verify-copy/logs/`: `p-<scenario>-b<budget>.tsv` and `.log` from `scripts/path_probe.gd` and `analyze.py`, `budget-suite.log`, `stagger-suite.log`, `both-suite.log`, `both-team.log`, `both384-team.log`, `both384-skirmish-match.log`, `both-netplay.log` and `both-netplay/`, `botprobe-1.log`, `ceiling-tree.log`, `ceiling-budget.log`). Applied: (1) budget 256 → 384 route cells: searched ÷ route 20.3 on Ashfall (per-request p95 28.6) against about 3 on the synthetic maps; 256 binds on 1653 of 6220 team-match service ticks and drains movement dense in 81 ticks against 38 (Question 15 fires); 384 drains in 60, worst per-tick search 102413 → 31739 cells; (2) winners: China flips to 1 at 384, FRC flips with the 256 budget alone, so "any winner" covers all three skirmish pins and the team match (Questions 11, 20); (3) HUD1 `HUD_TEXTS` added to R as V12 (red under the stagger; the census regex missed it); K2 `test_skirmish_scene.gd:45` red under the stagger with no allowed edit: new T4 (Question 18); A2 green before and after (rewritten anyway); P1's snapshot-ceiling failure is BM5 per-unit (342 > 336 at step 38); 21 bot cases red under the stagger listed in Task 3; three negative checks vacuous under the stagger, so T1 converts by census; (4) Zero Hour Question 3: `m_teamDelay` starts at 0 for every AI player (`AIPlayer.cpp:80`, `:120`) and is reset by events, so players start in step and drift apart, no deliberate stagger (`0a05454`, read in the fork, content identical); (5) night settings lack `wargrid-wt-flatter` (folder and Edit), `mkdir` for `$L` and `python3` for `compare_replays.py` and `$L` scripts: plan "Night-run preparation" with the proposed rules and the user's `! cp` line; (6) mechanics checks moved from `run_profile.gd` (report-only, `docs/development.md:85`) to `run_combat.gd` hordes300 (`reserved_allocations` counter) and `run_movement.gd` (`path_cells`), profile prints only (Question 19); (7) same-tick rows for map-change re-queues (PB4) and collector, transport and chaser re-queues (G8 plus queue-length measurement); (8) Questions 17-21; (9) Task 2 probe gated on the ratio, best of three rounds (measured 0.25 at tick 6000); scratch scripts judged by marker (Godot exits 0 on a `--script` parse error); Task 4 probe counts searched cells with the review's `_estimate_cost` grid in a scratch worktree; Task 5 compares netplay seats by hand because `run_netplay.sh` checks the pin (`:91`) before `same_hashes` (`:92`). Added beyond the review: PB1 runs on the 64 × 64 variant because twenty routes of about 20 cells nearly fit one 384 budget on the 16 × 16 default (derived from `DIAGONAL_MODE_NEVER`, not measured). Not verified: movement open drain at 384; snapshot ceilings at the drain step at 384; netplay terminal tick at 384; `reserved_window` and `path_capped_window` > 0 inside the benchmark windows (derived); HUD1's new value; RS3's "checks ≥ 20"; the stagger-only team match line; One controller's `IC1_ROWS` / `IC2_ROWS`.
- 2026-11-14, plan revision after the user's round-2 answers (attended), docs only; nothing run (a package-gate benchmark was running on the host, so no Godot, suite, benchmark or profile run). Read: `AGENTS.md`, the plan, `review.md`, the night settings and the user-wide and repository settings, and on `~/projects/wargrid` `main` `74950e5`: `tools/run_benchmark.sh`, `tools/run_team_match.sh`, `game/benchmarks/run_movement.gd`, `run_combat.gd` (`:60-200`), `run_team_match.gd`, `run_profile.gd` `_team_match`, `game/scripts/debug/team_match.gd`, `movement_workload.gd`, `combat_workload.gd` `_building`, `simulation.gd` (`spawn`, `_validate`, `_assign_move`, `_service_paths`, `_assign_route`, `replace_blocked_cells`, `_replace_union`, `remove_object`, `_remove_building`), `combat.gd` (`:125-146`, `_approach` `:207-229`, `object_removed`), `map_data.gd`, `grid_navigation.gd` (`component_at`, `snapshot`), `test_groups.gd` (`:140-230`), `test_combat_navigation.gd` A2, `run_tests.gd` runner, `tools/perf_record.py` `auto_label`, `game/data/maps/ashfall.json` (194 × 187, start cells, 12 sources), guide ch. 12 gate table, `performance.md` gate proposals. Applied: Questions decided (round 1 and round 2, user, 2026-11-14); Q13 X2 and X2r / X2m in Task 4 with the work bound ceil(route cells ÷ budget) (2× cannot hold for cross-map routes: derived about 90 ticks against 23 today); Q8 criterion (re-appends per unit, max wait, max queue; thresholds from `REPATH_TICKS` 8 × 384 and X2's drain) with the pre-written keep-the-slot fallback in `combat.gd` `_approach` and PB5; Q14 as Task 6 (count lines, five runs) and Task 7 (gates by rule C or a requirement, red by mutation, wall-clock report-only with proposed ceilings), docs task now 8, review 9; ch. 13 added to the guide list. Double-check fixes: the Task 4 probe tree (at Task 3's commit) was checked against V10, which Task 3 already moves; PB tests named `PATH_CELLS_PER_TICK` before it existed (parse failure, not named failures); the movement red step used a stub Step 3 had already replaced; `cp` (not allowed at night) for the digest script and probe copies; PB4's untyped array argument; a Task 4 step that used a later step's output; park scope of Tasks 3-5 left Tasks 6-9 undefined; the review gate lacked a mechanics floor for bot decisions. Not verified: every X2, PB5, Q8 and Task 6 / 7 number (derived, nothing run); that `CountingNavigation` built from `_union_cells()` equals the Ashfall navigation (the case checks it); that PB5's setup triggers a re-request while queued (the case checks it); X2's runtime; that rule C's 25 % sits below each mutation's effect (Task 7 Step 3 checks it).
- 2026-11-14, plan refresh onto `main` `4c21d1a` (docs only; no suite, benchmark, profile or Godot run; nothing committed). Read: `AGENTS.md`, `docs/night-run.md`, `docs/milestone-prompt.md`, the draft plan, this file's draft and `review.md`; `git log 74950e5..main` (74 commits: One controller, P2.1 launcher, release 0.12.0) and `git diff 74950e5..main` on `game/scripts/simulation`, `game/scripts/debug`, `game/benchmarks`, the pinned test files, `tools/run_team_match.sh` and `tools/run_netplay.sh`. Findings: simulation drift is the builder-in-transport rejection (`simulation.gd:242`, `construction.gd:72-74`), so `simulation.gd` anchors from `:242` moved by one and `construction.gd` ones after `:71` by three; `combat.gd`, `skirmish.gd`, `destination_allocation.gd`, every benchmark script, `test_groups.gd`, `test_combat_navigation.gd`, `test_benchmark.gd`, `test_factions.gd`, `test_skirmish_waves.gd` and every pinned value are unchanged; `test_skirmish.gd` moved up one line (the `OnlineMain` / `SkirmishMain` preloads became `OnlineDriver`); K2 now reads `main.driver.sim` at `test_skirmish_scene.gd:46-51` and the scene's bot call is `offline_driver.gd:32`; HUD1 at `:646` / `:676`; `IC1_ROWS` / `IC2_ROWS` (`input_script_rows.gd:3`, `:27`) added to R by the census rule as V13 (derived: expected not to move); guide anchors re-read (ch. 1 `:103`, ch. 12 rows `:47-50`, ch. 13 `:82`, ch. 4 `:104` and ch. 6 `:14`, `:39`, `:84` also name the 8-request cap); `performance.md` "Mechanics inside the window" `:161`; `docs/development.md:86`. Night settings re-checked (folder, Edit, `compare_replays.py`, `python3 -I` for `$L`, `mkdir -p` for the run folder, `ssh` / `scp` to the Deck, `godot`, `export_build.sh`, `git worktree add`; `git archive` not named). Steam Deck probed read-only over ssh: Desktop Mode, ACAD 1, load 0.0, Firefox flatpak 160.0, the user manager's environment has `DISPLAY=:0` and `WAYLAND_DISPLAY=wayland-0`, `systemd-inhibit`, `kde-inhibit`, `python3` and `curl` present. Added Tasks D0 and D7 (user, 2026-11-14 evening). Not verified: the Deck job script (never run), Deck profile length, the Firefox flow on 160, the expected values on `4c21d1a` (carried over from `74950e5`).
- 2026-11-14, external readiness review applied (fresh context, a different model family; docs only, nothing run, tree `main` `4c21d1a`). 9 findings checked against the code: 7 applied, 2 rejected. Applied: (1) Task 7 mutation (e) also deletes the `window_reserved == 0` return for its run, which otherwise returns before the full-scan check; Task 1 Step 6's "the script stops at the first failing row" corrected (`run_combat.gd:14-36` measures every row; only hordes300's own stress ceiling, checked first in its block, can hide the line); (2) the new cases are appended to `cases()` (PB2-PB4, X2, X2r in `test_groups.gd`; PB5 in `test_combat_navigation.gd`; also BT1 in `test_skirmish.gd`, found while checking), since `run_tests.gd:82` runs only `cases()`; (3) Task 5 Step 1: a differing in-bound value returns `BLOCKED`, the coordinator dispatches the Opus diagnosis and continues the task by `SendMessage` (`docs/night-run.md` Coordinator rules); (4) RS1 checks `_reservation_opens == 1`, with mutation (d), because `_end_reservations` inside the loop kept every other check green; (5) the Deck `user.js` seeds `termsofuse.acceptedVersion` 4 before the copied lines and also reads `.mozilla/firefox` (hardening: `deck.sh:46` found the pref under `config/mozilla/firefox`, so the path claim itself did not hold); `bench_runner.gd` combat loop cited as `:29`; (6) Global Constraints and the preparation section name the git commands the night file lacks and the proposed copy adds; (7) the `combat.splash_index` record moved into Task 0 Step 6. Rejected: Task 6's `deciding` placement (the plan already puts it before `var started`, inside the loop, and only `paths` next to `units_peak`; `TeamMatch.SEATS` is `Array[Dictionary]` with a `seat` key, `game/scripts/debug/team_match.gd:9-11`, so the plan's lambda is right); the typed `[]` for `MapData.create` (an untyped literal there already runs in every movement benchmark, `movement_workload.gd:31`).
