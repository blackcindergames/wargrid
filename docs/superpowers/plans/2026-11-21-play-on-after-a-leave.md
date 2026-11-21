# Play on after a leave (night 8): Implementation Plan

**Status:** ready for the night run (agent, 2026-11-21): owner answers applied, cites refreshed at `main` `6bd58ff3`; readiness review applied (table at the end). The run starts from its handoff (private, `play-on-prompt.txt`), never from approval.

History: the 2026-11-18 draft, its review rounds, its `9f1ae41` refresh and its Pump hardening collision list stay at `~/projects/wargrid-overnight-work/benchmark-pair-gate/backups/night8/plan.md` (private). Backup "Rate the bot" dropped (user, 2026-11-20), with Q13-Q18.

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development, task by task. Run rules: [milestone prompt](../../milestone-prompt.md), [night run](../../night-run.md#coordinator-rules). One fresh subagent per task, each starting from the resume record in [play-on-after-a-leave verification](../../reference/play-on-after-a-leave-verification.md). Every task subagent also reads "Global Constraints", "Commands", "Determinism notes", "Same-tick cases" and "Stop conditions" (`rg -n '^## ' <plan>`). The per-task review loop under Model routing replaces the skill's reviewers (one reviewer per diff).

**Goal:** a seat that leaves an online match after it is already defeated no longer ends the match for the others. Any other leave ends it as today, so a 1v1 leave keeps P2.2's opponent-left panel. Lockstep tracks a set of left seats and never hangs on two leaves. No pinned trace moves.

**Architecture:** `Lockstep` keeps a seat → `after_tick` dictionary and decides each leave once, at `after_tick + 1`, from a survivors list (match players owning a victory building after `step(after_tick)`): defeated plays on, anything else ends as `ended_left`. The list comes from a new read-only `Simulation.survivors()`, copied into every pump `Note` (Q2 a); the online driver passes the `after_tick` job's note, `advance(sim)` asks its sim. Relay and protocol untouched.

**Spec:** [packages](../../packages.md) night lane item 8 (`:57`); [online teams design](../specs/2026-11-16-online-teams-design.md) `:20`, `:22`, `:66` (acceptance, proposed), `:67`, `:88`; [critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18) (the rider). Research (private): `~/projects/wargrid-overnight-work/play-on/research/q2-alive-source.md`, `q10-q11-tests.md`; SB4's `~/projects/wargrid-overnight-work/sb4/backups/play-on-after-leave/research.md`.

## Run paths

| Name | Path |
|---|---|
| `$W` worktree | `~/projects/wargrid-wt-playon`, branch `play-on-after-a-leave` from `main` (the prep session creates both, Q19 a; never at night) |
| `<base>` | `main` `6bd58ff3`; the prep commit (this plan, the resume record) is the one commit on top |
| Plan, resume record (tracked) | `docs/superpowers/plans/2026-11-21-play-on-after-a-leave.md`, `docs/reference/play-on-after-a-leave-verification.md` |
| `$P` private run folder | `~/projects/wargrid-overnight-work/play-on`: `ledger.md`, `morning-summary.md`, `logs/` = `$L`, `backups/` |

Commands use absolute paths (`<abs $L>`); tracked files use `~/...` only. The handoff spells each `<abs …>` out once (allow rules match the literal path, never `~`); its start line begins `cd ~/projects/wargrid-wt-playon &&`; the coordinator checks the branch (`git rev-parse --abbrev-ref HEAD`) before each commit.

## Global Constraints

- **Run from `$W`:** a shell that starts elsewhere prefixes `cd <abs $W> && `; file tools use absolute paths under `<abs $W>/`.
- **Nothing pinned moves:** the four suite traces (replay, economy, combat, team); `run_netplay.sh match` and `rematch` terminal tick 9013 (`run_netplay.sh:161`, `:179`) with `s1.tsv`, `s1.cmd`; `TEAM MATCH won tick=38786 winner=2 units_peak=268` (`run_team_match.sh:13`); IC1, IC2, OD1, S3, RB8 and every Pump hardening pin Task 1 records. A moved pin is a stop; never re-pin.
- **Allowed test edits (exactly these):**
  - `test_lockstep.gd` `Net.add` (`:31`) gains `seats: Array[int] = [1, 2]` and `sim: RefCounted = null` (defaults as today: `Skirmish.create(true, "human")`).
  - New `test_pal_*` cases, appended to `cases()` (`test_lockstep.gd:82`, `test_sim_pump.gd:43`, `test_online_scene.gd:67`; only listed cases run). No suite file or existing case contains `test_pal_`.
  - Helpers `_trio_sim`, `_defeat` (one copy each in `test_lockstep.gd`, `test_sim_pump.gd`), `_quad_sim` (`test_lockstep.gd`).
  - In `test_sim_pump.gd`: `TrioRelay` plus a per-seat `TrioEnd` transport (`poll`, `send_text`, `closed`, `silent`, `close`, `rtt_samples`, `patient`), one `RelayFrameOrder` (`game/tests/relay_frame_order.gd`) each.
  - New top-level `const` preloads in the three suites for `MapData`, `Registry`, `MatchSettings` (or `Skirmish.MapData`, `Skirmish.Registry`).
  - No existing assertion changes; L7, L10, L14-L17, N16, N28, N29 and the SB4 leave cases stay as they are (Q8 a).
- **Untouched paths:** those in `UNTOUCHED` (empty at every gate), and in `game/scripts/simulation/` all but `simulation.gd` `survivors()` and `skirmish.gd` `create`.
- **Contract:** `docs/reference/sim-interface.md` gains exactly `survivors() -> Array[int]`, `Note.survivors`, `Skirmish.create(..., seat_count)`, plus "and tests" on the `begin_setup` callers line (`:14`). More is a stop.
- **No player-facing text (Q9 a).** `opponent_left()` keeps its rule (`ended_left`, after the start, two lockstep seats).
- **Keep from Pump hardening:** `take` order `_ended()`, in-order check (`lockstep.gd:110-112`), leave loop (today `:113-115`), `can_step`, hashes; the driver's `last` flag and `_stopped` break (`online_driver.gd:115`); `test_ph_*` cases green, unchanged; repeated-left checked by `end_reason()`, never HUD text (`online_driver.gd:339`); doc footers keep their entries.
- **Tests** use the [simulation interface](../../reference/sim-interface.md) and the drivers; `driver.pump.live()` only to build or check state. Typed GDScript (tests exempt from `untyped_declaration` only); comments one line, WHY only; Edit tool only.
- **Red is a failed named check.** New members first go in bare and behaviour-neutral (Step 0). A load, parse or `SCRIPT ERROR` red is not red: fix Step 0 or the test, rerun.
- **Mutation proofs:** `git add <file>`; mutate with Edit; run the named `ONLY`/`TRIO` (must fail); revert with Edit; `REVERT` exits 0. An equivalent mutation (no behaviour change inline) goes in the ledger with its reason, not a stop.
- **Benchmarks run alone** after `uptime` and `pgrep` (none of this run's processes; another session's Godot does not stop it: Start step 4 override, user, 2026-11-21, carried by the handoff). Load (the 1-minute average, first `uptime` figure) above 2.5: run, label `night 8 play on after a leave (host under load)`, owe an evening rerun. Exit 1 only from a combat ceiling (`hordes300`, `open`, `dense`): rerun alone up to twice, loads in the ledger; three failures are an owner noise item. Any other failed line is a stop. Never loosen a budget.
- **Never:** push, merge, `gh`, `fly`, deploy, `run_game.sh`, a window or sound, `git worktree`, `git branch -D`, `git reset --hard`, `git checkout --`, `git stash` other than the park form, `git merge-base` (an ask rule matches it), `rm -rf`, settings edits, `AskUserQuestion`. Subagents never commit; the coordinator commits once per GREEN task (pre-authorized).

## Commands

Every suite, netplay, lint, warnings, checks, team-match, conformance and benchmark call passes Bash `timeout: 600000`, writes to a file in `$L`, and is judged by exit code plus marker (`TESTS PASSED <n>`, `CHECKS PASSED 5`, `NETPLAY PASSED`, `REPLAYS MATCHED`, `PYTHON TESTS PASSED`, `PUBLIC CHECK PASSED`). On failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:|NETPLAY FAILED' <log>`.

| Form | Command (from `$W`) |
|---|---|
| `SUITE(t)` | `WARGRID_REPLAY_TRACE=<abs $L>/replay-t.tsv WARGRID_ECONOMY_REPLAY_TRACE=<abs $L>/economy-t.tsv WARGRID_COMBAT_REPLAY_TRACE=<abs $L>/combat-t.tsv WARGRID_TEAM_REPLAY_TRACE=<abs $L>/team-t.tsv sh tools/run_tests.sh > <abs $L>/t-suite.log 2>&1; echo "exit=$?"` |
| `ONLY(t, f)` | `WARGRID_TEST_ONLY=f sh tools/run_tests.sh > <abs $L>/t-only.log 2>&1; echo "exit=$?"` |
| `NET(t, s)`, `TRIO(t, s)` | `NETPLAY_OUT=<abs $L>/t-np-s sh tools/run_netplay.sh s > <abs $L>/t-np-s.log 2>&1; echo "exit=$?"` |
| `TRACES(t)` | `python3 tools/compare_replays.py <abs $L>/replay-base.tsv <abs $L>/replay-t.tsv`, same for `economy-`, `combat-`; `python3 tools/compare_replays.py --interval 200 --rows 100 <abs $L>/team-base.tsv <abs $L>/team-t.tsv`; each `REPLAYS MATCHED` |
| `NETEQ(t)` | for s = `match`, `rematch`: `python3 tools/compare_replays.py --interval 30 --rows 0 <abs $L>/base-np-s/s1.tsv <abs $L>/t-np-s/s1.tsv` (`REPLAYS MATCHED`), then `cmp <abs $L>/base-np-s/s1.cmd <abs $L>/t-np-s/s1.cmd` (silent) |
| `STATIC(t)` | `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_python_tests.sh`, each `> <abs $L>/t-<lint\|warnings\|py>.log 2>&1; echo "exit=$?"` |
| `CHECKS(t)`, `TEAM(t)` | `sh tools/run_checks.sh > <abs $L>/t-checks.log 2>&1; echo "exit=$?"`; `sh tools/run_team_match.sh > <abs $L>/t-team.log 2>&1; echo "exit=$?"` |
| `REVERT(t, file)` | `git diff --exit-code -- file > <abs $L>/t-revert.log 2>&1; echo "exit=$?"` |
| `UNTOUCHED(t)` | `git diff <base> --stat -- relay protocol game/scripts/presentation game/scripts/lab game/scripts/playtest game/scripts/match/match_screen.gd game/scripts/match/hud.gd game/scripts/match/hud_model.gd game/scripts/match/result_panel.gd game/scripts/match/offline_driver.gd game/scripts/launcher.gd > <abs $L>/t-untouched.log 2>&1; echo "exit=$?"` (log empty) |
| Other checks | `sh tools/run_shell_checks.sh`, `actionlint .github/workflows/ci.yml`, `sh tools/check_public.sh`, `sh tools/run_conformance.sh`, each `> <abs $L>/t-<name>.log 2>&1; echo "exit=$?"` |
| Benchmark | `PERF_LABEL="night 8 play on after a leave" sh tools/run_benchmark.sh > <abs $L>/gate-bench.log 2>&1; echo "exit=$?"` (foreground, about 7 min; background only past 9 min) |
| Line map | `rg -n '^(static )?(func\|var\|const\|class) <name>\b' <file>` |
| Host | `uptime`; `pgrep -fl 'godot\|generalszh'`; `mkdir -p <abs $L>/grok-gate`; `mkdir -p <abs $P>/backups/f42` |
| Git | `git status --short`; `git log --oneline -3`; `git rev-parse --abbrev-ref HEAD`; `git rev-list HEAD \| rg -q '^<base>'`; `git diff -U30 HEAD`; `git diff --name-only HEAD`; `git diff --no-color <base>...HEAD > <abs $L>/gate.diff`; `git diff --name-only <base>...HEAD > <abs $L>/gate-paths.txt`; `git add <paths>`; `git commit -m <subject> -m <reason>`; `git diff HEAD > <abs $L>/t<N>-parked.patch`; `git stash push --include-untracked -m park-t<N>-playon`; `git stash list --format='%H %gs'` |
| Grok gate | `GROK_MEMORY=0 grok --prompt-file <abs $L>/grok-gate/prompt.md --cwd <abs $W> -m grok-4.7 --effort high --output-format json --sandbox read-only --always-approve --no-subagents --disable-web-search --disallowed-tools "write,search_replace,run_terminal_cmd,workflow" --no-auto-update > <abs $L>/grok-gate/result.json 2> <abs $L>/grok-gate/stderr.log; echo "exit=$?"`, then `jq -r .text <abs $L>/grok-gate/result.json > <abs $L>/gate-grok.md`; valid only with exit 0, non-empty `.text`, `stopReason` `end_turn` (recipe: private `grok-handoff.md`) |
| F42, usage | B1 "Commands"; `python3 tools/session_usage.py <session files>` |

Added in the proposed night settings (`night-settings.proposed.json` in `$P`, private): `NETPLAY_OUT=<abs $L>/*`, `Edit(//<abs $W>/**)`, `cd <abs $W>*`, `mkdir -p <abs $P>*`, `git stash list:*`, `python3 -I <abs $P>/*`, `git show:*` (reviewers), `<abs $W>` in `additionalDirectories`. Every other form matches an allow rule.

## Model routing

| Stage | Model, effort |
|---|---|
| Task 1; 9a-9c (runs and digests) | Sonnet low |
| Implementers, Tasks 2-8; backup B1 | Sonnet high |
| Per-task review (3-7), fix rounds, Task 10, docs review (8), diagnosis and unblock | Opus high |
| Gate 9d | Opus high whole-branch; Grok 4.7 high, not fast (else a second Opus high pass); `silent-failure-hunter` and `pr-test-analyzer` (Opus); `/ponytail-review` in a Sonnet subagent. No player-experience reviewer (Q9 a: no UI or text). |

**Per-task review loop (the handoff copies it):** `GREEN`, uncommitted → a fresh Opus reviewer with paths only (plan, task heading, "Same-tick cases"; `git diff -U30 HEAD`, `git diff --name-only HEAD`, `git status --short`) names per new test the killing production change and writes P1/P2/P3 to `<abs $L>/t<N>-review.md` → one Opus fix subagent for P1/P2, test-first, verify step rerun → the rest to the ledger → the coordinator commits. The handoff also copies the Model routing table, the Parking dependencies line, the park procedure under Stop conditions, and Task 7's "6b parked" line.

## Review Focus

1. **Verdict paired with the wrong state.** It reads the state after `step(A)`. Driver: `_last.tick == _next_tick`, else `null` (ends, never plays on silently; inline the guard always holds, kept for SB5a). Advance: `sim.survivors()` before the step. A hook or `--defeat` at A + 1 looks like a removal in `step(A)`: no test uses one.
2. **`[]` means "everyone defeated":** a caller passing it by mistake plays on. Two callers only; tests cover `null`; every note is filled.
3. **The check stays "L is not in survivors".** Filtering to relay seats or requiring two remaining seats ends P7's host-alone match wrongly (`test_pal_bot_players_play_on`).
4. **Played-on seat in the packet loops:** `can_step`, `waiting_for_tick`, collection and `_verify_hashes` (`lockstep.gd:271`) skip it, else a hang or a crash on a missing packet.
5. **FRC holes** count for victory (`rebuild_holes.gd:23`): an FRC leaver is rarely defeated.
6. **Room after a play-on:** `left_seat() != 0`, so `_room_gone` closes the room at the end and Play again never shows; the relay never parks a room after a leave (`room.go:382-385`). Pinned by a test.
7. **SB5a only:** a `left` while waiting can empty `waiting_for()` before `notice()` indexes `[0]`; the preview may wait one frame at A.
8. **Known gap (owner item):** a match still in `setup` after the delay (refused `choose_faction`, `simulation.gd:312-322`; needs a modified client) reads the leaver as defeated. `survivors()` stays `[]` in setup.

## Determinism notes

- Every remaining client gets the same `left` and `after_tick` (`room.go` `leave`, `:438-450`), queued behind that seat's frames (`sender.go:42`), so all decide at the same tick from the same state.
- A left seat's commands are never due past A (stamp check), so "count as empty" drops nothing applied; a played-on match replays from its commands.
- `survivors()` is never hashed or stored. Each seat is decided once.
- Cost (Q2): about 6 µs per job on dev, 0.7 % of the 0.91 ms plumbing budget, below the 0.02 ms A/A spread (research).

## Same-tick cases

L leaves with `after_tick` A; decision at A + 1 on the state after `step(A)`; "defeated" = L not in `survivors()`. No new sim command (Q5 a); leftovers stay (Q4 a).

| Case | Expected | Test (task) |
|---|---|---|
| L's last victory building removed before `step(A)` (hook at A) | defeated, play on | `test_pal_removed_in_step_a_plays_on` (4b) |
| L alive at A, three seats | `ended_left` at A + 1, `left_seat() == L`, no `opponent_left()` | `test_pal_alive_leave_ends` (4a) |
| L's accepted `build` at A (a worker places a site) | site counts: `ended_left` | `test_pal_build_site_at_a_ends` (4b) |
| L's `build` at A refused (no credits) | defeated, play on | `test_pal_refused_build_at_a_plays_on` (4b) |
| L's `cancel_build` of its last site at A | defeated, play on | `test_pal_cancel_last_site_at_a_plays_on` (4b) |
| L's other commands at A (`move`, `stop`, `attack_move`, `gather`, `attack`, `defence_attack`, `produce`, `cancel_production`, `set_rally`, `resume_build`, `enter`, `unload`) | no-command verdict | `test_pal_other_commands_keep_verdict` (4b, characterization) |
| FRC leaver's last completed victory building dies at A | hole counts: `ended_left` | `test_pal_frc_hole_counts_ends` (4b) |
| L's defeat at A ends the match (one team left) | normal end, `take` never reached | `test_pal_match_end_at_a_is_normal` (4b) |
| leave before the start (A < delay), any seat count (Q3 a) | `ended_left`, `left_before_start()` | L14, `test_pal_before_start_ends` (4a) |
| two leaves with the same A, one alive | `ended_left` naming the lower alive seat (Q6 a) | `test_pal_same_after_tick_ends` (4a) |
| overwrite: seat 2 defeated A = 20, seat 3 alive B = 25, both `left` before 21 | play on 21-25, `ended_left` "player 3" at 26, never `waiting` | `test_pal_two_leaves_never_hang` (2 red, 4a) |
| seat 3's `left` arrives first | as above | `test_pal_arrival_order_irrelevant` (4a) |
| undefeated leave first, defeated later | `ended_left` at the first A + 1 | `test_pal_undefeated_first_ends` (4a) |
| second `left` for a seat (Q7 b) | `ended_protocol`, `end_reason()` "repeated left for seat N" | `test_pal_repeated_left_protocol_error` (4a) |
| L's packet at or before A never arrives | `ended_left`, as today | L10, L16 unchanged |
| hash tick past A (30, A = 20) | checked on remaining seats, no crash | `test_pal_hash_tick_after_play_on` (4a) |
| decision due, no fact (`null`) | `ended_left` | `test_pal_no_fact_ends` (4a) |
| **P7 shape (Q2, Q20):** relay seats [1, 2]; sim players 1-4, teams {1, 2} v {3, 4} (3, 4 idle bot stand-ins); guest 2 defeated before `step(A)`, leaves at A | survivors [1, 3, 4]; seat 1 plays on alone; `left_seat()` 2, no `opponent_left()` | `test_pal_bot_players_play_on` (4a) |
| driver: quiet take while a tick is in flight | no change; the next loud take decides from A's note | `test_pal_driver_quiet_defers_verdict` (5) |
| driver: three seats, seat 2 defeated, leaves | others play on, equal digests; seat 3 leaving later ends | `test_pal_three_drivers_play_on` (5) |
| driver: play on, then a normal end | room closed, no Play again, "Your friend left" | `test_pal_driver_play_on_then_end_closes_room` (5) |
| netplay, real driver on s1: defeated leave, then undefeated leave | s1 `ended_left` "player 3 disconnected" at ≥ 900 | `trio-play-on` (7) |
| leave on the normal end tick; `left` after the end | normal outcome | L17, `test_sb4_leave_on_end_tick_catch_up`, N16 |

Parking dependencies: 4a needs 3; 4b needs 4a; 5 needs 3, 4a, 4c; 6a needs 4c; 6b needs 5, 6a; 7 needs 4a, 6a (its `--pump` parts 6b); 8-10 run on what is committed and name parked tasks. Order: 1, 2, 3, 4a, 4b, 4c, 5, 6a, 6b, 7, 8, 9, 10, backup B1.

---

### Task 1: Base and line map

**Files:** the resume record only (Base counts, Line map).

- [ ] **Step 1:** `mkdir -p <abs $L> <abs $P>/backups/f42` (no-op when present). `git rev-parse --abbrev-ref HEAD` is `play-on-after-a-leave`; `git log --oneline -3` matches the record: exactly one commit above `6bd58ff3`, touching only the plan and the record (`git diff --name-only 6bd58ff3 HEAD`); `git rev-list HEAD | rg -q '^<base>'` and `git rev-list <base> | rg -q '^ec74a23'` (Pump hardening) exit 0, else stop. Record `uptime`.
- [ ] **Step 2:** One after another: `SUITE(base)`; `ONLY(base-lock, test_lockstep)`, `ONLY(base-online, test_online_scene)`, `ONLY(base-pump, test_sim_pump)`; `NET(base, s)` for `match`, `rematch`, `left-mid`, `kill`, `perturb`; `TEAM(base)`; `STATIC(base)`. Record the `CASES n CHECKS n FAILURES n` line (`run_tests.gd:122`), markers, terminal ticks. A red base is a stop.
- [ ] **Step 3:** Line map (missing symbol: stop): `lockstep.gd` `_left_seat`, `_left_after`, `take`, `advance`, `can_step`, `waiting_for_tick`, `_verify_hashes`, `_receive_left`, `left_seat`, `left_before_start`; `online_driver.gd` `step`, `_room_gone`, `rematch_line`, `notice`, `_finish`, `CATCH_UP_STEPS`; `sim_pump.gd` `Note`, `run_job`; `simulation.gd` `_survives`, `match_over`; `skirmish.gd` `create`; `match_settings.gd` `starts`; `headless_client.gd` `_start`, `_match_sim`, `_test_hooks`, `_run_steps`, `_parse`. `rg -n 'func survivors' game/scripts/simulation/simulation.gd` finds nothing (exit 1 is the pass). Record `PUMP_COUNTS` (`tools/test_sim_boundary.py:101-105`: offline 10, online 9).
- [ ] **Step 4:** `check_public` passes; `GREEN`; the coordinator commits.

### Task 2: Reproduce the overwrite

**Files:** test only, `test_lockstep.gd`: `Net.add` defaults, `_trio_sim()`, `_defeat()`, one case.
- `_trio_sim()`: `MapData.create(MapData.load("res://data/maps/broken_crown.json"), seats)`, seats 1-3 on teams 1-3, faction `usa`, controller `human`, `Skirmish.START_CREDITS`; `start_match([1, 2, 3] as Array[int])` (typed literals wherever the receiver is untyped; the `MapData.create` seat list is `Array[Dictionary]`).
- `_defeat(sim, seat)`: remove every building the seat owns (`snapshot().buildings`, `remove_object`), as L17 does.

- [ ] **Step 1:** `test_pal_two_leaves_never_hang`: three clients on `_trio_sim()`, seats `[1, 2, 3]`, `_defeat(c.sim, 2)` in all before `connect_all`. Client 2 stops at 16 (packets to 20), client 3 at 21 (packets to 25). Client 1's inbox gets `left` 2 `after_tick` 20, then `left` 3 `after_tick` 25, both due before tick 21. Check "PAL two leaves never hang: ended_left by seat 3 at 26 (status %s, seat %d, tick %d)" with the actual values (format as L10, `test_lockstep.gd:336`).
- [ ] **Step 2:** `ONLY(t2red, test_pal_two_leaves)` exits 1 with `waiting` at tick 21: "reproduced" in the ledger. A different red: "not reproduced as read", recorded; the test stays the spec.
- [ ] **Step 3:** `sh tools/run_lint.sh` only. `GREEN` = red as specified; no review; the coordinator commits `test only, red by design until Task 4a`.

### Task 3: `Simulation.survivors()` and `Note.survivors` (Q2 a)

**Files:** `simulation.gd` (after `match_over`, `:192`), `sim_pump.gd`. Test: `test_sim_pump.gd`.
```gdscript
func survivors() -> Array[int]:
	var found: Array[int] = []
	if _match == null: return found
	for player: int in _match.players:
		if _survives(player): found.append(player)
	return found
```
`Note` (`:23`) gains `var survivors: Array[int] = []`; `run_job` sets `note.survivors = sim.survivors()` beside `note.over` (`:169`), for every job.

- [ ] **Step 0:** `survivors()` returning `[]`, and the field; `ONLY(t3s0, test_sim_pump)` exits 0.
- [ ] **Step 1:** `test_pal_survivors_query`: "PAL every seat with a victory building survives" (`_trio_sim()`: `[1, 2, 3]`; after `_defeat(sim, 2)`: `[1, 3]`; no match: `[]`); the digest is unchanged by the call. `test_pal_note_carries_survivors`: a setup sim (Broken Crown, seats 1-3 `defer: true`, `begin_setup([1, 2, 3])`), `SimPump.new(sim)`, `start()`, `post` one job with three `choose_faction` (`usa`, players 1-3, `tick` 0, `sequence` 0), `drain()`; "PAL the job's note carries the survivors after its step" `[1, 2, 3]` (before the step it is `[]`: `choose_faction` applies in `step`, `simulation.gd:422`).
- [ ] **Step 2:** `ONLY(t3red, test_pal_)` exits 1 on the new checks (plus the Task 2 case).
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `SUITE(t3)` exits 1 with exactly one failed check: `rg -c '^FAIL: ' <log>` is 1, that line has "PAL two leaves never hang", the summary has `FAILURES 1`; anything else is a stop. `TRACES(t3)`, `STATIC(t3)`.
- [ ] **Step 5:** Mutation: fill `note.survivors` above `if job.step: sim.step()` (`sim_pump.gd:153`) → `ONLY(t3m1, test_pal_note_carries)`; revert; `REVERT(t3m1, game/scripts/match/sim_pump.gd)`.

### Task 4a: Lockstep left-seat set and the decision

**Files:** `lockstep.gd`. Test: `test_lockstep.gd`. Before: fields `:32-33`; leave rule in `take` `:113-115` (`if _left_seat != 0 and (tick > _left_after or not _packets[_left_seat].has(tick))`).

**After:**
```gdscript
var _left: Dictionary = {}      # seat -> after_tick
var _played_on: Dictionary = {}
var _ended_by: int = 0
...
# survivors: match players owning a victory building after step(tick - 1); null means the caller cannot tell, so a leave ends the match.
func take(tick: int, quiet: bool = false, survivors: Variant = null) -> Variant:
	if _ended(): return null
	if tick != _next_tick: ...unchanged
	for s in _seats:
		if not _left.has(s) or _played_on.has(s) or (tick <= _left[s] and _packets[s].has(tick)): continue
		if quiet: return null
		if _defeated(s, tick, survivors):
			_played_on[s] = true
			continue
		_ended_by = s
		_end("ended_left", "player %d disconnected" % s)
		return null
	...can_step, _verify_hashes unchanged...
	for s in _seats:
		if not _counts(s, tick): continue
		...collect and erase as today...

func _counts(s: int, tick: int) -> bool:
	return not _left.has(s) or tick <= _left[s]

func _defeated(s: int, tick: int, survivors: Variant) -> bool:
	return tick == _left[s] + 1 and _left[s] >= _delay and survivors is Array and not (survivors as Array).has(s)
```
Also: `waiting_for_tick` uses `_counts(s, sim_tick) and not _packets[s].has(sim_tick)`; `_verify_hashes` skips `not _counts(s, tick)` before indexing; `_receive_left` keeps the bad-seat check, then ends `ended_protocol` "repeated left for seat %d" if `_left.has(seat)`, else `_left[seat] = message.after_tick` (Q7 b); `left_seat()` is `_ended_by`, else the lowest key of `_left`, else 0 (Q6 a); `left_before_start()` is `left_seat() != 0 and _left[left_seat()] < _delay`; `opponent_left()` unchanged; `advance(sim)` (`:138-149`) calls `take(tick, false, sim.survivors() if _left.values().has(tick - 1) else null)` (no cost off decision ticks). Don't touch `finish_tick`, `record`, `submit`, `receive`, `MAX_QUEUED_TICKS`, the stamp check.

- [ ] **Step 0:** `survivors: Variant = null` on `take`, unused; `ONLY(t4as0, test_lockstep)` exits 0.
- [ ] **Step 1: Tests** on the Net harness (`_defeat` before `connect_all`, or `Client.hook(c, tick)` at a tick ≤ A); every message starts "PAL" and states the outcome: the Task 2 case, `test_pal_same_after_tick_ends`, `test_pal_arrival_order_irrelevant`, `test_pal_undefeated_first_ends`, `test_pal_repeated_left_protocol_error` (`end_reason()`), `test_pal_hash_tick_after_play_on`, `test_pal_no_fact_ends`, `test_pal_alive_leave_ends`, `test_pal_before_start_ends` (setup sim: seats `defer: true`, no `faction`, `begin_setup`; Task 8 adds "and tests" to the `begin_setup` line), and `test_pal_bot_players_play_on` (Q20):
  - `_quad_sim()`: Broken Crown, seats 1-4 on teams 1, 1, 2, 2, `usa`, `human`, `START_CREDITS`, `start_match([1, 2, 3, 4] as Array[int])`.
  - Two clients via `Net.add(seat, "human", Time.get_ticks_usec, [1, 2], _quad_sim())`; `_defeat(c.sim, 2)` in both before `connect_all`; client 2 stops at 16; client 1 gets `left` 2 `after_tick` 20 and runs to target 60.
  - Checks "PAL P7 shape: survivors include the sim-only players" (`[1, 3, 4]`) and "PAL P7 shape: the host plays on alone after a defeated guest leaves" (`running`, tick 60, `left_seat() == 2`, `opponent_left()` false).
  - `test_pal_no_fact_ends`: `_pair(runner)`, `_defeat(c.sim, 2)` in both, client 2 `target` 16, client 1 `target` 21, `left` 2 `after_tick` 20; after `run()`, `a.ls.take(21)` with no third argument; checks `ended_left`, `left_seat() == 2` (with survivors it would play on, so m4 kills it).
- [ ] **Step 2:** `ONLY(t4ared, test_pal_)` exits 1 on the new checks; `ONLY(t4aold, test_left)` and `ONLY(t4aopp, test_opponent)` exit 0.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `SUITE(t4a)` exit 0, `TRACES(t4a)`, `STATIC(t4a)`; `NET(t4a, s)` for `match`, `rematch`, `left-mid`, `kill`, `perturb`; `NETEQ(t4a)`.
- [ ] **Step 5:** Mutations (each `ONLY` exits 1, then revert, `REVERT`): drop `_counts` in `_verify_hashes` → `ONLY(t4am1, test_pal_hash_tick_after)`; drop `_left[s] >= _delay` → `ONLY(t4am2, test_pal_before_start)`; clear `_left` before the insert → `ONLY(t4am3, test_pal_two_leaves)`; treat `null` as `[]` → `ONLY(t4am4, test_pal_no_fact)`; `_defeated` also requires `_seats.size() - _left.size() >= 2` → `ONLY(t4am5, test_pal_bot_players)`.

### Task 4b: Command and removal rows (tests only)

**Files:** test only, `test_lockstep.gd`, against 4a: `test_pal_removed_in_step_a_plays_on`, `test_pal_build_site_at_a_ends`, `test_pal_refused_build_at_a_plays_on`, `test_pal_cancel_last_site_at_a_plays_on`, `test_pal_other_commands_keep_verdict`, `test_pal_frc_hole_counts_ends`, `test_pal_match_end_at_a_is_normal`.
- Removal at A: `Client.hook(c, A)`. Build or cancel at A: a seat 2 worker (`_defeat` keeps units), origin from `preview_build`, kind `usa_power_plant` (no prerequisite, `counts_for_victory`, the site appears at once and counts). Refused build: seat 2 `credits` 0 (the plant costs 800). FRC row: seat 2 `frc`.
- `_trio_sim(seat_two: Dictionary = {})` merges into seat 2's row (`{"credits": 0}`, `{"faction": "frc"}`), one helper. The leaver's command due at A is submitted from its `hook` at tick A - delay - 1 (15 for A = 20; check `command.tick == A`). FRC row: no `_defeat` (FRC holes count); remove only its last completed victory building at A.
- `test_pal_other_commands_keep_verdict` is a characterization test: no killing mutation is a ledger line, not a stop.

- [ ] Write the cases; each passes on 4a. A red case is a 4a finding: test-first to the Opus fix subagent. `SUITE(t4b)`, `TRACES(t4b)`, `STATIC(t4b)`.

### Task 4c: Three-seat `Skirmish.create` and starts

**Files:** `skirmish.gd` `create` (`:53`), `match_settings.gd` `starts` (`:30`). Test: `test_online_scene.gd`. `create` gains trailing `seat_count: int = 2`: seat n on team n, `"human"` for seat 1 and `second_controller` for the others, today's keys in today's order, `begin_setup`/`start_match` get the ids. `starts` gains `teams: Array[int] = [1, 2]`, `chosen` zeros of that size.

- [ ] **Step 0:** both parameters, unused; `ONLY(t4cs0, test_online_scene)` exits 0.
- [ ] **Step 1:** `test_pal_two_seat_create_unchanged` (guard: `Skirmish.create()` digest equals `Skirmish.create(true, "ai", DEFAULT_SKIRMISH, MAP_PATH, [], 2)`); `test_pal_three_seat_create` (teams 1-3, `setup` with factions `{}`); `test_pal_three_seat_starts` (`MatchSettings.starts("broken_crown", 7, [1, 2, 3])`: three distinct starts, stable).
- [ ] **Step 2:** `ONLY(t4cred, test_pal_three_seat)` exits 1. **Step 3:** Implement.
- [ ] **Step 4:** `SUITE(t4c)`, `TRACES(t4c)`, `STATIC(t4c)`; `NET(t4c, match)` (9013), `NET(t4c, maps)`, `NETEQ(t4c)`.

### Task 5: Online driver passes the `after_tick` job's note

**Files:** `online_driver.gd` `step`, one line (`:116`; the `_stopped` break `:115` stays). Test: `test_sim_pump.gd`.
```gdscript
		var commands: Variant = _lockstep.take(_next_tick, not _taken.is_empty(), _last.survivors if _last.tick == _next_tick else null)
```
Don't touch `_tick_job`, `_finish_job`, `_settle`, `_room_gone`, `rematch_line`, `notice`, `stop`, `take_rematch`, `create`, or the pump access count (online 9).

Helpers: `TrioEnd.send_text` forwards a tick to the other two inboxes and refuses an out-of-order frame via its `RelayFrameOrder` (as `PairTransport`, `:24`); `TrioRelay.leave(seat, after_tick)` appends `left` to the others. Drivers adopt `Skirmish.create(true, "human", {1: "usa", 2: "usa", 3: "usa"}, <broken_crown path>, starts, 3)`, seat 2's buildings removed before `adopt`; one `step` and `drain` per driver per frame, round-robin (as `_frames`, `:455`).

- [ ] **Step 1:**
  - `test_pal_three_drivers_play_on`: to tick 40; seat 2 stops (last packet 44), `leave(2, 44)`; drivers 1 and 3 run 400 frames: "PAL a defeated seat's leave lets the others play on" (`running`, tick > 45), "PAL digests stay equal" (`hash_rows`), "PAL seat 3 leaving later ends the match" (driver 3 stops, B its last sent tick, `leave(3, B)`; driver 1 `ended_left`, `left_seat() == 3`).
  - `test_pal_driver_quiet_defers_verdict`: seat 2 leaves with A; driver 1 has credit ≥ 2 and every counted packet for A + 1 before one `step()` (lag driver 3). Assert the call took A, the A + 1 packets of seats 1 and 3 were in hand with credit ≥ 2, the status is unchanged, and the next loud take plays on at exactly A + 1. Never assert A + 1 was taken in that call.
  - `test_pal_driver_play_on_then_end_closes_room`: play on after seat 2; then seat 3's buildings removed in drivers 1 and 3 when each `current().tick == T` after a drain (no lag: one tick per call; fail loudly past T). Driver 1: phase `done`, `can_play_again()` false, `rematch_line()` "Your friend left".
- [ ] **Step 2:** `ONLY(t5red, test_pal_)` exits 1 on the driver checks. **Step 3:** Implement.
- [ ] **Step 4:** `SUITE(t5)`, `TRACES(t5)`, `STATIC(t5)` (`PUMP_COUNTS` 10 and 9).
- [ ] **Step 5:** Mutations: (a) `lockstep.gd` drop `if quiet: return null` → `ONLY(t5m1, test_pal_driver_quiet)`; (b) drop the third argument → `ONLY(t5m2, test_pal_three_drivers)`; (c) pass `[] as Array[int]` → `ONLY(t5m3, test_pal_three_drivers)`. The `_last.tick == _next_tick` guard is equivalent inline: ledger line, kept for SB5a.

### Task 6a: Three seats and a defeat hook in the headless client

**Files:** `headless_client.gd` only. `_start` (`:113`): seat count `message.seats.size()`, `_match_sim(id, chosen, count)` (`:141`), `MatchSettings.starts(id, seed, <1..count>)`. `_test_hooks` (`:195`): `--defeat 2@300[,3@1200]` removes every building of seat P before the step of tick T and prints `NETCLIENT DEFEAT P AT T` (pokes the sim as `--perturb-at-tick` does, `:196`). The oracle stays two-seat; trio scenarios skip it (a recorded limit).

- [ ] Implement; `STATIC(t6a)`, `NET(t6a, match)` (9013), `NET(t6a, left-mid)`, `NETEQ(t6a)`.

### Task 6b: Headless client on an inline pump (`--pump`, the rider, Q11 b)

**Files:** `headless_client.gd` only; `online_driver.gd` untouched.
- `--pump`: `_start` builds `_driver = OnlineDriver.new(_transport, _lockstep, faction, _seat)`, `adopt(_sim)`, `start()` (the driver submits `choose_faction` and starts lockstep, replacing the client's own lines on that path). `_run_steps` (`:151`) per iteration: hooks and seat script when `_lockstep.can_step(_sim.tick())`; `_driver.step()`, `_driver.drain()`; finish on `_driver.over()` with the lockstep status if it ended, else `match_over`. Messages reach lockstep once whoever polls first (`poll` drains); `_receive` keeps `welcome` and `start`.
- **Credit clamp:** `step` can take two ticks per call (`online_driver.gd:10-11`, `:110-127`), so a hook could miss its tick. With a pending `--defeat P@T`: when `_sim.tick() == T - 1` after a drain, set `_driver._credit = 0` before `step()` (that call takes at most one tick); apply the hook at `_sim.tick() == T`, before the next `step()`. `--defeat` with `--pump` is allowed (P7 needs both). `headless_client.gd` is outside the static scan (`SCAN_EXCLUDED`).
- Recorded limit: the driver's `_finish` overwrites `user://netplay-latency.txt` (`online_driver.gd:277`).

- [ ] **Step 1:** No GDScript test (Task 7's `left-mid-pump`, `trio-play-on` are). Ledger the transport members `step`, `drain`, `_finish` use (`RelayTransport` has all seven).
- [ ] **Step 2:** Implement; `STATIC(t6b)`. If `run_warnings.sh` flags the `_credit` poke (unverified), record the line and use the narrowest `@warning_ignore` on it.
- [ ] **Step 3:** `NET(t6b, left-mid)`, `NET(t6b, match)` unchanged. Ledger: the clamp acts only on hook ticks.

### Task 7: Netplay scenarios

**Files:** `tools/run_netplay.sh` (and its `:2` usage line); `ci.yml` netplay list (`:156`, Q12 a). `start_trio "F1" "F2" "F3"` is `start_pair` (`:107-121`) plus `s3` on the same code, after `start_relay WARGRID_SEATS=3` (`relay/main.go:216`). Every trio client gets `--map broken_crown --seat-script idle` (later flags win in `_parse` over `human`/`opponent`, `:110`, `:118`; `TEST_MAP` has no starts; attacks could end a match before 1200).

- `trio-play-on`: all `--defeat 2@300`; **s1 `--pump`** (Q11 b); seat 2 `--faction usa --stop-at-tick 320`; seat 3 `--stop-at-tick 900`. Expect s1 `ended_left` "player 3 disconnected" at ≥ 900; s2, s3 `stopped`; pairwise `same_prefix`; no ` DESYNC ` or `lead bound` in `relay.log`.
- `trio-left-first`: seat 3 `--stop-at-tick 300`, seat 2 `--stop-at-tick 600`. Expect s1, s2 `ended_left` "player 3 disconnected" at 300-310, `same_prefix`.
- `trio-result`: all `--defeat 2@300,3@1200`; seat 2 `--stop-at-tick 320`. Expect s1, s3 `match_over` at 1201 with equal hashes (Q10 b).
- `left-mid-pump`: `left-mid` with `--pump` on s1; the same lines, including `NETCLIENT VICTORY left`.

- [ ] **Step 1:** `TRIO(t7, trio-play-on)`, `TRIO(t7, trio-left-first)`, `TRIO(t7, trio-result)`, `NET(t7, left-mid-pump)`, each `NETPLAY PASSED`. Record each wall time and the sum (export job limit 25 min, `ci.yml:97`; CI times wait for the owner's push).
- [ ] **Step 2:** Mutations (revert, `REVERT` each): (m1) `_defeated` returns false → `TRIO(t7m1, trio-play-on)` fails (s1 ends near 325); (m2) the driver's `take` loses its third argument (always `null`) → `TRIO(t7m2, trio-play-on)` fails near 325.
- [ ] **Step 3:** shell checks pass; `actionlint` exits 0.

6b parked: s1 of `trio-play-on` runs without `--pump`; `left-mid-pump` and m2 are dropped (ledger); the rider stays open.

### Task 8: Docs

Each chapter touched moves its `Checked against` footer to the task tip.
- `docs/guide/11-multiplayer.md`: "Advancing" (`:80-85`) gets the left-seat set and decision; "Ending" (`:95`); "Opponent left" (`:182`) unchanged rule, three seats now in tests; "`left` ends the match" (`:215`) becomes "A leave: end or play on", payoff first; code list (`:243` headless client hooks `--defeat`, `--pump`; `:244`; `:254`); scenario count.
- `docs/guide/13-testing-and-tooling.md`: trio scenarios, hooks, CI count (`:242`, "fifteen" → nineteen). `01-big-picture.md` note fields (`:100-106`). `03-entities.md` `counts_for_victory` row (`:179`) names `survivors()`.
- `docs/development.md:125` "fifteen" → nineteen. `docs/reference/sim-interface.md`: the three items (`:41`, `:61`) and "and tests" (`:14`). `docs/STATUS.md`: the night 8 row. The resume record: the evidence. The teams design's night numbers are not touched (owner item).

- [ ] Opus docs review, one fix round; `check_public` passes; `python3 tools/roadmap.py` only if a package name or state changed.

### Task 9: Gate (short subagents, in order)

- [ ] **9a:** `CHECKS(gate)`; `SUITE(gate)` (cases = base + new `test_pal_*`, minus parked); `TEAM(gate)`; `TRACES(gate)`; `UNTOUCHED(gate)` empty; `run_conformance.sh` (`ci.yml` changed).
- [ ] **9b:** `NET(gate, s)` for the CI list (`match`, `rematch`, `left-mid`, `perturb`, `relay-down`, `maps`, `map-mismatch`, `kill`, `stall`, `spike`, `version`, `proxy-clean`, `proxy-burst`, `proxy-reset`, `proxy-blackhole`), `silent`, and the four new ones; `NETEQ(gate)`. `relay-term` skipped as at SB4.
- [ ] **9c (alone):** `uptime`, `pgrep`, the benchmark form. Exit 0 or the retry rule; the row records itself. Ledger: the `PROFILE_PUMP` line, the `team_match_pump:profile` row (already over 0.91 ms on `main`: 1.115-1.147, `perf-history.csv` rows 1465, 1489, 1521; record beside them, never loosen), `uptime` at start and end. A 9c stop does not block 9d or 10. Rendered rerun owed after a merge (`game/scripts/match/` changed; owner item).
- [ ] **9d:** write `gate.diff` and `gate-paths.txt`; the 9d reviewers run in parallel, read-only, with the [gate review](../../milestone-prompt.md#gate-review) brief (scope `<base>...HEAD`, plan, resume record, ledger, earlier findings), each writing `<abs $L>/gate-<reviewer>.md`; Grok's prompt names `gate.diff` (no shell). An empty or one-line report is a failed review: dispatch a narrower one.

### Task 10: Review fixes, then the stop gate

- [ ] P1/P2 test-first (Opus high), rulings for the rest. Rerun the touched `ONLY`, `SUITE(fix)`, `TRACES(fix)`, `STATIC(fix)`, `CHECKS(fix)`; 9b if `lockstep.gd`, `online_driver.gd`, `headless_client.gd` or `run_netplay.sh` changed; 9c if `sim_pump.gd`, `simulation.gd` or `lockstep.gd` (`run_lockstep.gd`) changed. Footers to the final tip, resume record final; the coordinator commits.
- [ ] **Stop gate:** report implemented, verified, pending; `PushNotification`; then backup B1.

---

## Backup B1: F42 spike (evidence only)

**Why:** STATUS F42: on the Mac the paced match benchmark reads 2.5-2.9x the unpaced numbers in every zone (`view_state` 1.123, `view.batch` 2.534, `step` 5.80 ms); cause unchecked (suspect: macOS clocking down between ticks, inference). Sources (private): `~/projects/wargrid-overnight-work/lowend-deck/followup-2026-11-20/results.md:101`, tooling night `morning-summary.md` item 5.

**Rules:** after the main task's stop gate or park; one Sonnet (high) agent; headless; writes only under `<abs $P>/backups/`; changes no repository, worktree or scratch-tree file.

**Where the commands are:** `tools/` on `main` has no paced runner (`run_profile.sh`, `run_benchmark.sh` run `run_profile.gd` unpaced). Both sides are scratch worktrees at `9f1ae41` in `$F` = `~/projects/wargrid-overnight-work/lowend-deck/followup-2026-11-20`: paced `$F/tree-match` (`match-f3.patch`: `res://scenes/match_bench.tscn`, args in `game/scripts/debug/match_bench.gd` `_params()`), unpaced `$F/tree-mac` (`zones-mac.patch`: `game/benchmarks/run_handoff_followup.gd`, same window 6600-8400, profiled). The F42 log header (`$F/logs/mac-handoff-1.log`): `load=team arms=inline`, `smooth=off hud=on overlay=on cull=off`, `"profile":true`; the command line was not recorded.

**Commands** (`$O` = `<abs $P>/backups/f42`; each `timeout: 600000`, `uptime` before and after into `$O/loads.txt`):
- `A` unpaced: `godot --headless --path <abs $F>/tree-mac/game --script res://benchmarks/run_handoff_followup.gd > <abs $O>/unpaced-<i>.log 2>&1; echo "exit=$?"`
- `B` paced: `godot --headless --path <abs $F>/tree-match/game res://scenes/match_bench.tscn -- --load=team --smooth=off --profile=on > <abs $O>/paced-<i>.log 2>&1; echo "exit=$?"`
- `C` no idle gaps: as `B` with `--fixed-fps 30` before `--path` (real-time sync off, frames back to back), to `fixed-<i>.log`
- `D` presentation off: as `B` plus `--hud=off --overlay=off`, to `knockout-<i>.log`
- Extract: `python3 -I <abs $O>/extract_f42.py <abs $O>` (scratch script): medians of 3 per arm for `step`, `view_state`, `view.batch` (paced: `PROFILE` lines inside the `WORKER RUN` JSON `profile_lines`; unpaced: plain `PROFILE` lines).

**Steps:** (1) `test -f` both entry scripts, else note "not run: tree missing" and stop. (2) Check `B`'s flags against `_params()` and the header; fix flags, never the script. (3) Smoke `B`: `WORKER BENCH DONE`, exit 0, `DIGEST tick=6600` as in `mac-handoff-1.log`, else note and stop. (4) `A B C D` three times interleaved; 1-minute load above 2.5: run, tag, rerun that arm once at the end. (5) Extract; ratios against `A`.

**Verdicts (these rules only):** reproduced if `B`/`A` `step` ≥ 2.0, not reproduced below 1.5, partly between. Idle gaps supported if `C`/`A` ≤ 1.3 while `B`/`A` ≥ 2.0, ruled out if `C`/`A` ≥ 2.0. Presentation work ruled out if `D`/`A` ≥ 2.0, supported if ≤ 1.3. Else "inconclusive" with numbers.

**Deliverable:** `<abs $P>/backups/f42-spike.md`, one page: trees and revisions, exact commands, load table, medians and ratios, one verdict line per rule, a proposed STATUS F42 line (not applied), what stays unchecked; one morning line.

**Stops:** any change to a budget, benchmark, ledger row, `perf-history.csv`, STATUS or tracked file; any `PERF_LABEL` or `run_benchmark.sh` run; a window; a modified or recreated tree.

## Stop conditions

Never ruled on; each parks the task (one Opus high unblock attempt first, which may only find an existing approval):
- a trace, digest or pin moves (9013, the `TEAM MATCH` line);
- an existing assertion changed, a leave test rewritten, or a test edit outside "Allowed test edits";
- a contract change beyond the three items;
- a budget exceeded outside the retry rule, or `run_benchmark.sh` exit 1 for another reason;
- `PUMP_COUNTS` changes (10, 9);
- a non-equivalent mutation still green after one strengthening round (add checks once; never remove one or swap the mutation);
- a check red twice under host load (one rerun above 2.5; red at or below 2.5 is an ordinary red: Opus diagnosis first);
- a Task 4b case red on 4a after one fix round;
- `trio-result` not ending at 1201 on both clients (record ticks, park the scenario, never widen);
- Task 6b failing `left-mid-pump` or `trio-play-on` twice (6b parks; Task 7 runs without its `--pump` parts);
- the resume record disagreeing with the tree.

To park: `t<N>-parked.patch`, then `git stash push --include-untracked -m park-t<N>-playon`, the SHA (`git stash list --format='%H %gs'`) into ledger and morning summary, never popped. Only dependants park too (list under "Same-tick cases").

## Owner answers

Questions `~/projects/wargrid-overnight-work/benchmark-pair-gate/backups/night8/questions.md`, answers `~/projects/wargrid-overnight-work/play-on/answers.md` (private), all applied where the tasks name them: Q2 a, Q3 a, Q4 a, Q5 a, Q6 a, Q7 b, Q8 a, Q9 a, Q10 b, Q11 b, Q12 a, Q20 a (user, 2026-11-21); Q19 a (user, 2026-11-19); Q1 and Q13-Q18 moot. Backups: B1 only (user, 2026-11-21).

Owner items: the teams design's night numbers lag STATUS (`:31-39`, `:49`, `:59`, `:66`, `:70`, `:88-94`); Review Focus 8; no reference engine ends a match when an undefeated player leaves (research Q2), so Wargrid's rule is stricter.

## Refresh at main 6bd58ff3

Every cite re-read with `git show main:<path>` (agent, 2026-11-21; 50 commits since `9f1ae41`). Unchanged: `lockstep.gd`, `headless_client.gd`, `skirmish.gd`, `match_settings.gd`, `run_netplay.sh`, `run_team_match.sh`, `ci.yml`, `rebuild_holes.gd`, `relay/*.go`, the teams design, guide 03 and 11 cites.

| Cite at `9f1ae41` | At `6bd58ff3` |
|---|---|
| `PUMP_COUNTS` `test_sim_boundary.py:101-104`, offline 9 | `:101-105`, offline **10** (P2.3a1), online 9 |
| `packages.md:54`; guide 13 `:210`; guide 01 `:100` | `:57`; `:242`; `:100-106` |
| `cases()` `test_online_scene.gd:66` (tail `test_ph_*`), `test_sim_pump.gd:48`; advance-peer test `:772+` | `:67` (tail `test_view_player_after_the_online_seat`), `:43`; `:768` |
| `run_tests.gd:109` summary, `:86-87` filter | `:122`, `:94`; three new suites |
| `sim_pump.gd` `_failed` | `_failure`/`failure()`; `Note.tick_hash` added; `note.over` `:169` |
| `simulation.gd`, `test_lockstep.gd`, `online_driver.gd` | lines added (`tick_hash()` `:718`; TH1-TH2 `:450-481`; `take_rematch` `:258`); every cite here re-read at `6bd58ff3` |
| leave rule "`lockstep.gd:110-112`" | that is the in-order check; the rule is `:113-115` |
| `start_trio ARGS1 -- ARGS2 -- ARGS3` | `start_pair` takes quoted flag strings: `start_trio "F1" "F2" "F3"` |
| untouched `match/` files | changed by P2.3a1, still untouched; new `hud_model.gd` added |

## Not checked

Nothing run for this plan. Open: trio wall times (Task 7 records local ones), whether `run_warnings.sh` flags the `_credit` poke, base counts and pins (Task 1), and F42's rebuilt `B` flags (checked by digest) and `--fixed-fps` effect on the bench's pacing.

## Readiness review applied

At `6bd58ff3` (agent, 2026-11-21); review private.

| Finding | Result |
|---|---|
| P1-1 log folder | applied |
| P1-2 allow rules | applied (proposed settings) |
| P2-1 preloads | applied (Allowed test edits) |
| P2-2 Start step 4 | applied (user, 2026-11-21) |
| P2-3 resume record | applied |
| P2-4 worktree start | applied |
| P2-5 4b variants, timing | applied |
| P2-6 no-fact recipe | applied (m4 dies with or without the defeat) |
| P2-7 handoff copies | applied |
| P3-1 typed arrays | applied |
| P3-2 lint on test tasks | applied |
| P3-3 guide 11 `:243` | applied |
| P3-4 two count places | applied |
| P3-5 9c trigger | `lockstep.gd` added; `online_driver.gd` rejected: no benchmark uses it |
| P3-6 load figure | applied |
| P3-7 exit 1 pass | applied |
| P3-8 foreground bench | applied |
| P3-9 skill reviewers | applied |
| P3-10 absolute paths | applied (handoff rule) |
| P3-11 red baseline | applied |
| P3-12 `git show` | applied |
