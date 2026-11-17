# Relay Guards Implementation Plan

**Status:** done: run on night 7 (2026-11-16), merged to local `main` 2026-11-17 with a fix round (user, 2026-11-17: proxy-burst setup accepted, blackhole window 5500-7500, a rate-limited warning for an unusable client-IP header, zero limit lines asserted in `run_conformance.sh`); evidence in the [verification file](../../reference/relay-guards-verification.md). History: draft, written 2026-11-15 at night as backup 5 of the Flatter worst ticks night run (docs only, nothing run, nothing committed; outside the repository). Revised 2026-11-15 after one fresh review (`review-grok.md`, in `~/projects/wargrid-overnight-work/flatter-worst-ticks/backups/relay-guards-plan/`). Rebased 2026-11-15 onto `main` `ee2f353` (P2.2 slice 1). Questionnaire answered by the user 2026-11-15 (design answers "Relay guards questionnaire (user, 2026-11-15)"). **Fixed 2026-11-16** after the readiness review (`~/projects/wargrid-overnight-work/sim-boundary/backups/1-relay-guards/review.md`, 13 findings, verdict not ready; see "Readiness fix 2026-11-16" at the end) and **rebased onto `main` `52017fd`** (section "Rebase onto `52017fd`" below). Questions: `questions.md` beside this file; Q1-Q30 answered (user, 2026-11-15), Q31-Q33 answered A, A, A (user, 2026-11-16, design answers "Readiness round"). Second readiness round applied 2026-11-16 (`~/projects/wargrid-overnight-work/relay-guards/reviews/grok.md`, `fable.md`; "Readiness round 2" in `changes.md`). Not approved yet as a plan; the run needs the user's go and the copied night settings. Resume record: `verification.md` beside this file. Proposed night settings: `night-settings.proposed.json` beside this file (the user copies it; never edited in place).

## Rebase onto `52017fd` (2026-11-16)

Read on `main` `52017fd` (read-only). `git diff fd8671b..52017fd -- relay protocol tools/run_netplay.sh tools/run_conformance.sh game/scripts/net .github`: `relay/main.go` (1 line), `relay/sender.go`, `relay/reject_test.go` (new), `game/scripts/net/lockstep.gd` (+3), `headless_client.gd` (+1), `run_netplay.sh` (`left-mid`), `ci.yml` (loop). `room.go`, `envelope.go`, every other relay test, `protocol/` and `run_conformance.sh` are unchanged, so their anchors stand; the line numbers in task bodies below are on `52017fd`. The "Rebase onto P2.2" section further down is history: its line numbers are on `ee2f353`.

- **`29724db` "Send nothing after a relay reject error":** `conn.reject` (`main.go:74-81`) now calls `sender.sendLast` (`sender.go:34-39`), which flushes a waiting batch, writes the error and sets `sealed`; `enqueue` (`:42-61`) and `addBatch` (`:63-69`) drop every later frame. `TestNoPongAfterReject` (`reject_test.go`) pins it.
- **`4b1accb` / `b0fe44c` (P2.2 slice 2, released 0.13.0):** `Lockstep.opponent_left()` (`lockstep.gd:158-159`: `ended_left`, not before start, two seats); the headless client prints `NETCLIENT VICTORY left` in `_finish` (`headless_client.gd:215`); the online driver shows "Your opponent left" (`rematch_line`); new netplay scenario `left-mid` (`run_netplay.sh:124-129`: seat 2 stops at tick 600, seat 1 `ended_left` with `VICTORY left`). **13 netplay scenarios**; CI loop `match rematch left-mid perturb relay-down maps map-mismatch` (`ci.yml:151`).
- **SB3 (Sim boundary, merged `6333249`):** `online_driver.gd` runs on `SimPump`; `step()` takes no argument and returns nothing; answers to own orders come from `_new_answers` (command log plus rejections) through `take_answers()`. `match_screen._submit` (`match_screen.gd:310-315`) calls `driver.submit(payload)` and **ignores its result**; refusals reach the HUD only through `_take_answers` (`:149-156`: `hud.note = "Rejected: " + answer.error`, reject sound, `orders.answered`). `tools/test_sim_boundary.py` gained a live-read rule for `game/scripts/match/` and `presentation/`; `online_driver.gd` is on its `LIVE_ALLOWLIST` until SB4. `lockstep.gd` `submit` (`:63-70`) and `finish_tick` (`:124-140`) are unchanged.
- **Night lane:** Relay guards is night-lane item 7 (was 8), between P12 and P2.3a (user, 2026-11-16; `docs/packages.md:51`, `docs/STATUS.md:35` row "night 7"). Before it comes only P12 (playtest form, no net or relay code); P2.3a, night 8 Play on after a leave and P7 follow it. Cheaper step moved after it (night 11).

Collisions with the two relay commits, slice 2 and SB3 (each folded into a task):

| # | Rule | Piece | Effect | Fix in this plan |
|---|---|---|---|---|
| C20 | Every new refusal (`too far ahead`, `too many connections`, `too many joins`, `relay busy`) | sealed `reject` | The error is the socket's last frame, also against a racing pong; a batch waiting for that socket is flushed before it | rely on it: all new refusals go through `c.reject`, none writes after it; conformance "error, then close" expectations are race-free |
| C21 | Unknown-match silent close (Q13) | sealed `reject` | Not a reject: no frame. No room holds the socket and only its own reader writes to it (pong), and `rejected` stops that reader (`main.go:148`) | `c.rejected.Store(true); c.close()` as planned, no seal needed |
| C22 | Batch size guard (Task 7b) | `sealed` in `addBatch` | The guard must not flush or append for a sealed sender | the `sealed` check stays first in `addBatch` |
| C23 | Lead bound, any per-seat rejection | opponent-left result | In a 1v1 the rejected seat leaves after the start, so the other seat ends `ended_left` and wins ("Your opponent left", `NETCLIENT VICTORY left`). Accepted: the honest seat wins against a broken or cheating client | interaction row; no new assertion (`left-mid` owns the victory rule) |
| C24 | Hash comparison | `left-mid` | Seat 2 leaves at tick 600 with possibly one pending hash entry; `leave` clears it | `left-mid` gains the `! grep msg=DESYNC` relay-log check (Task 2 Step 4) |
| C25 | Pending-frame cap (Task 4) | SB3 `_submit` ignores `submit`'s result | A `{"ok": false}` return alone never reaches the HUD | `online_driver.submit` also queues `{"command": payload, "ok": false, "error": TOO_MANY_ORDERS}` into `_answers`; `match_screen.gd` untouched; the HUD reads "Rejected: Too many orders at once; wait a moment" (Question 33) |
| C26 | Pending-frame cap | P7 (bot orders in the host's frames), SB4 | If bot orders go through the host's `Lockstep.submit`, the cap applies to them (refused before stamping, so deterministic); SB4 may move `finish_tick` | Task 0 records both; Task 4 Stop if `submit` or `finish_tick` no longer exist by symbol |
| C27 | CI loop, pinned counts | `left-mid` | 13 scenarios, CI loop has 7; latest green `main` CI (`43863567341`, `d820773`, includes `left-mid`): export job Linux 4 min 4 s, Windows 6 min 25 s; netplay step 50 s and 71 s | Pinned values, Task 0 Step 5b, Task 6 Step 3, Task 8 counts (17 scenarios) |

## Rebase onto P2.2 (`ee2f353`, history)

What P2.2 changed under this plan (read on `ee2f353`, read-only; line numbers in this section are on `ee2f353`):

- Relay: `config` gains `hello`, `silence`, `lobby` (`room.go:24-31`; `WARGRID_HELLO_MS` 5000, `WARGRID_LOBBY_MS` 900000, `main.go:184-191`); `relay` is now `{reg *registry}` only (`main.go:83-85`), silence read from `h.reg.cfg.silence`. Each socket has a `deadline` (`main.go:30-63`): hello deadline at open (`main.go:127`), lobby hold until expiry (`room.go:222`), start window (`room.go:235-239`), silence renewal from the first tick (`room.go:251-253`), park hold (`room.go:303`). Room phases: lobby, start window, playing, `over` per seat, parked (every seat over, `park`, `room.go:298-308`), `again` echo (`room.go:310-328`), rematch (`room.go:331-338`: `lastTick`, `over`, `again` reset to zero, **frame and byte counts kept**, `start()` again with a new seed), expiry (`room.go:175-194`: `lobby expired` removes the room, `room expired` marks the parked seats dead). `forward` (`room.go:242-264`) now also refuses a tick after `over`. MATCH END stays one line per room (`room.go:352-356`), counters added up across rematches (design §"Leave").
- Tests: new helpers `loopConn`, `testConfig`, `seated`, `seatedWith`, `eventually`, `nop` (`shutdown_test.go:12-63`), `frames`, `recorder` (`deadline_test.go:10-51`), `pair`, `firstTick`, `park`, `ended`, `frames.count` (`rematch_test.go:13-50`). `TestRematchResetsTicksAndKeepsCounters` reads `r.stats[1]` as the string `"2f/<b>B"` (`rematch_test.go:73-75`). Positional `tickMsg{…}` literals in `deadline_test.go:105`, `rematch_test.go:33` (inside `firstTick`, `:32-34`), `shutdown_test.go:106` (corrected 2026-11-16; unchanged on `52017fd`). `stall_test.go:56-57` now sends seat 1's tick 4 first (to leave the start window).
- Conformance: 61 cases (default 49, silence 10, delay 2; recounted on `52017fd`); `run_conformance.sh:15` profiles `default:`, `delay:WARGRID_TEST_DELAY_MS=250`, `silence:WARGRID_SILENCE_MS=300,WARGRID_HELLO_MS=300,WARGRID_LOBBY_MS=1500`, and every profile run gets `-silence 300ms -hello 300ms -lobby 1500ms` (`:26`). New vectors `over.json`, `again.json`, `again_seat.json`: **19 vectors** now.
- Netplay: 12 scenarios (new `rematch`, `run_netplay.sh:94-118`); the `match` terminal tick is pinned **9013** (`:91`, also `:99`, `:102`); CI loop `match rematch perturb relay-down maps map-mismatch` (`ci.yml:151`).
- Client: `relay_transport.gd` gains `patient` (`:16`, `silent` `:60-62`: 900 s while patient, else 5 s); `online_driver.gd` has phases `playing`/`over`/`again`/`done`, sends `over` from `_finish` (`:160-170` on `ee2f353`; `:235` on `52017fd`) and `again` from `play_again` (`:139-142` on `ee2f353`; `:210` on `52017fd`), both through `_transport.send_text`; `headless_client.gd` `--rematch` sends `over` and `again` (`_rematch_step`, `:164-173`) and swaps in a new `Lockstep` on the second `start` (`_on_session`, `:132-139`). `Lockstep.submit` returns nothing (`lockstep.gd:63-70`). Go is pinned **1.27.4** in `relay/go.mod` and `protocol/conformance/go.mod` (`8d8c53e`).

Collisions, one per task (each folded into the task below):

| # | Rule | P2.2 piece | Effect | Fix in this plan |
|---|---|---|---|---|
| C1 | Lead bound | rematch resets `lastTick` to 0 | Safe: rematch runs only when every seat sent `over`, and `forward` refuses ticks after `over`, so no tick of match 1 is in flight; match 2 starts at the start bound 8 again | LB-U4 (new) pins it |
| C2 | Lead bound | `over` freezes a seat's `lastTick` while the others may still tick | Honest seats reach the same end tick, so the frozen value never binds them; counting the `over` seat keeps the bound (and the hash map) bounded against a seat that keeps ticking | rule: `over` seats still count; LB-U4 |
| C3 | Lead bound | existing conformance `start_window_ends` (silence profile, `conform.go:636-658`): seat 2 ticks every 100 ms from 4 while seat 1 sits in its 1.5 s start window | Seat 2 reaches tick 9 after about 500 ms and gets `too far ahead` instead of seeing `left(1, 3)`: an existing case goes red | allowed test edit A4 (Question 28) |
| C4 | Lead bound | `tick_after_over`, `tick_after_again` expect `invalid message` | The lead bound must run after the existing refusal (`room.go:247-250`), or the reason changes | rule: insert after `:250` |
| C5 | Hash comparison | rematch restarts hash ticks at 30 | A pending entry left from match 1 (a client that hashed and then sent `over`) completes against match 2's value at the same tick: a false `DESYNC` | `clear(r.hashes)` in `rematch()`; HC-U5; `! grep DESYNC` added to the `rematch` scenario |
| C6 | Hash comparison | over / parked | Ticks stop after `over`; at most one pending entry stays until rematch or leave (bounded by C2) | HC-U5 |
| C7 | Hash comparison | `tickMsg` gains hash fields | Three positional test literals stop compiling | allowed test edit A5 (Question 29) |
| C8 | Byte fields | `r.stats` read as `map[int]string` by `TestRematchResetsTicksAndKeepsCounters` | The plan's `stats map[int][]any` breaks that test | keep `stats` as is; new `r.peaks map[int][2]int` filled at leave |
| C9 | Byte fields / `DESYNC` | counters add up across rematches; MATCH END one line per room | `seatN_max_frame` and `seatN_peak_bps` become room-wide maxima; `desync` the first of the room (a desynced match never rematches: the client closes on `ended_desync`, `online_driver.gd` `_finish` `:229-238` on `52017fd` (`_ended()` is true, so `_transport.close()`), headless `_rematch_step` runs only on `match_over`) | Questions 4 and 5 reworded; BF-U2 |
| C10 | Per-IP limits | hello deadline 5 s (`main.go:127`) | An idle no-hello socket holds its per-IP slot at most 5 s; the socket cap now mainly bounds lobbies (15 min each) and parked rooms (15 min) per address | Question 10 reworded; `limits_conn_cap` must finish inside 5 s |
| C11 | Per-IP limits | `OnOpen` now sets the hello deadline and builds `conn` with `dl` | The plan's before/after `OnOpen` is stale | Task 3 Step 4 rewritten |
| C12 | Per-IP limits | `lobby expired` removes the room; `room expired` makes `join` answer `unknown match` (`room.go:198-199`) | A friend arriving after expiry draws from the unknown-match bucket; when it is empty the friend gets a silent close ("Connection to relay lost") instead of `unknown match` | Question 13 reworded |
| C13 | Per-IP limits | rematch needs no hello | Rematches never draw from any join bucket | LM-U6 (new) |
| C14 | Conformance profiles | profiles now carry env vars and every run passes `-silence/-hello/-lobby` | `limits` and `global` profiles run with the default 5 s hello and 15 min lobby; their flags are ignored by their cases | rule; profile strings in Task 3 Step 6 |
| C15 | Global bucket | the default profile grew from 38 to 49 cases | The hello count is about 97 now (read, not run; about 105 after Task 1) | Question 12 answered (fixed burst 20, refill 20 per s; the suite paces, Task 3 Step 1); Task 0 Step 4 measures as a check only |
| C16 | Client refused send | `over` and `again` go through `send_text` | A refused `over`/`again` closes the transport; the room is then gone (on `52017fd`: closed or silent sets relay-lost at `online_driver.gd:97`, the over/again room close is `:114`, `_room_gone` `:141-142`), which is what P2.2 already does for a closed socket | interaction row T7-over |
| C17 | Headless silence check | `patient` exists only in the online driver | The headless client keeps 5 s while waiting for `again`/`start` (`_rematch_step`); relay pongs refresh `_last_rx` (`relay_transport.gd:31-33`), so a live relay never trips it | Question 30; `rematch` scenario stays green |
| C18 | CI loop | `rematch` plays two matches | Netplay step and export job times from `f568e9b` are stale | Question 21 reworded; Task 0 Step 5b re-measures |
| C19 | Pinned values | terminal tick 9013, 19 vectors, 61 cases, 12 scenarios | N1, N4, N5 numbers changed | Pinned values updated |

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development, task by task. Run rules: `docs/night-run.md` (Coordinator rules) and `docs/milestone-prompt.md` (session start, stop conditions). Resume record: the verification file. Every task subagent also reads "Global Constraints", "Pinned values", "Allowed test edits", "Determinism notes" and "Same-tick and interaction cases" (`rg -n '^## ' <plan>`).

**Goal:** night-lane item 7 "Relay guards" ([packages](../../packages.md#night-lane), package note "Relay guards"; [design answers](../../reference/design-answers-2026-11-08.md) "Relay guards questionnaire (user, 2026-11-15)", including its batch size guard; [netplay review](../../reference/netplay-reference-review.md) §7 S1, S5, §5 P5.1, §8, "Review 2026-11-13"; [netplay stress](../../reference/netplay-stress.md) §4, "Review 2026-11-14"; [design answers](../../reference/design-answers-2026-11-08.md) "Netplay reference review", "Package review, second pass"). The relay gains: (1) a lead bound in `room.forward`; (2) a comparison of the `hash` values it already parses, logged as `DESYNC` with seat groups; (3) per-IP connection cap and join rate limit, a global join bucket, a bounded table that fails closed, and a global bucket for `unknown match` replies (ioq3 limiter); (4) max frame bytes and peak bytes per second per seat in `MATCH END`; (5) a batch size guard: with `WARGRID_BATCH_MS` on, the sender cuts a joined batch before it would pass the frame cap, so no message outgrows what a client buffer holds (Question 31). Around it: a Go fault proxy in `tools/netfault/` driven by `run_netplay.sh` with four CI scenarios (proxy-clean, proxy-burst, proxy-reset, proxy-blackhole), the headless client's 5 s silence check, the existing `kill stall spike version` scenarios in CI, a goroutine-churn Go test, `RelayTransport.send_text` closing on a refused send, and the client capping its pending frame at the 64 KiB frame limit. The hello deadline and the unstarted-lobby expiry are **not** in this package (moved to P2.2 Quick rematch, user 2026-11-13 night).

**Architecture:** all relay rules live where the state already is. The lead bound and the hash comparison are a few lines in the room goroutine (`room.forward`, `relay/room.go:242-264`), so they need no lock. The per-IP limits are a small `limiter` (one mutex, touched per connection open, close and hello, never per frame) in a new `relay/limits.go`, fed by gws's `Authorize` hook, which sees the HTTP request and shares the session with `OnOpen` (`gws@v1.10.2/upgrader.go:190-192`, `option.go:222`, `:226`, default hook `:271-272`). The batch size guard is three lines in `sender.addBatch` (`relay/sender.go:63-69`). The wire protocol stays protocol 2: the only wire additions are new `error` reasons, each with conformance cases; no vector changes. The fault proxy is a separate stdlib-only Go program (one process per seat), so faults stay out of process: no new relay knob for faults, and the only client hook is the silence check in `headless_client.gd`.

**Tech stack:** Go (relay and conformance `go 1.27.4`, gws v1.10.2; conformance uses coder/websocket), typed GDScript (Godot 4.7.2), POSIX `sh`, GitHub Actions YAML.

**Written against** `main` `9c8c505`, rebased onto `ee2f353`, **then onto `52017fd`** (read-only; anchors in task bodies are `file:line` on `52017fd`). Before this package the order runs P2.3a, night 7 Play on after a leave and P7 (packages night lane 7-8, day lane), maybe SB4: expect drift in `game/scripts/match/`, `game/scripts/net/lockstep.gd` and `headless_client.gd`; the relay and conformance tree has no planned change before it. Task 0 re-reads every anchor and records the `match` terminal tick on the real base (9013 on `52017fd`); every task re-anchors by symbol on drift.

**Rider settled before planning (WebSocketPeer no-delay):** backup 2 of the Flatter worst ticks night run measured it on a scratch worktree of `9c8c505` (`~/projects/wargrid-overnight-work/flatter-worst-ticks/backups/ws-nodelay/README.md`): `run_netplay.sh match` with timestamp prints, 18260 frames, native headless clients; client `send_text` to relay receive median 41 µs, p95 62 µs, max 547 µs; relay forward call to receiving client median 2158 µs, p95 8482 µs, max 10166 µs, bounded by the uncapped client's frame time (receive batches 3.9-5.1 ms apart at median), not by the network. No Nagle-style delay on native; loopback only. Web: closed 2026-11-15 (design answers "Pre-research follow-ups"): two Firefox windows through the live relay, 12,523 send-to-receive pairs end to end, p50 18 ms, p95 35 ms, p99 46 ms, one 314 ms outlier, no clusters near 40 or 200 ms; "no send delay found" (user, 2026-11-15); the per-leg split stays unmeasured. Fix: none. The package only records this (Task 8).

## Global Constraints

- Worktree `$W` = `~/projects/wargrid-wt-relay-guards`, branch `relay-guards` from `main` (Task 0 creates both). `$L` = `~/projects/wargrid-overnight-work/relay-guards/logs`. `$W`, `$L` and `~` are notation only: in every command type the absolute path; never `~` or a shell variable in a command. Agent shells reset their working directory to the session's, which is `$W` (the run starts inside its worktree, `docs/night-run.md` "Runs at the PC"): a command for the repository root starts with its allowed token (`sh tools/…`, `godot …`, `git …`, `NETPLAY_OUT=…`, `WARGRID_REPLAY_TRACE=…`); a command in a module folder (`relay/`, `protocol/conformance/`, `tools/netfault/`) starts with `cd <absolute path> && ` (the proposed night settings add `Bash(cd ~/projects/wargrid-wt-relay-guards*)`; whether the night permission check accepts the `cd … &&` form is unverified: the preparer tries it under the night settings before the run, and Task 0 Step 1 tries it again). **Fallback without `cd`** (from `$W`, matching the existing `go` rules): `go vet -C relay ./...`, `go test -C relay -race ./...`, `go build -C relay -o <abs $L>/relay-t<N> .`, `go run -C protocol/conformance . -url …`, and the same with `-C tools/netfault`; `-C` must be the first flag. Only `golangci-lint` has no such flag: if `cd … &&` is denied, the lint gates move to the morning list and the tasks go on. Logs go to `$L`, never into the repository.
- Every suite, conformance, netplay, lint, warnings, checks, Go test and benchmark call: Bash `timeout: 600000`, output to a file in `$L`, judged by exit code plus marker (`TESTS PASSED`, `CHECKS PASSED 5`, `CONFORMANCE PASSED <n>`, `NETPLAY PASSED <scenario>`, `ok  	wargrid/relay` and `ok  	wargrid/netfault` from `go test`, `0 issues.` from golangci-lint, `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`). On failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:|panic:|--- FAIL|NETPLAY FAILED|CONFORMANCE FAILED' <log>`.
- Relay gates (AGENTS.md "relay changes"): `cd <abs $W>/relay && go vet ./... && go test -race ./... > <abs $L>/<tag>-go.log 2>&1; echo "exit=$?"` (fallback: `go vet -C relay ./... > <abs $L>/<tag>-vet.log 2>&1; echo "exit=$?"` and `go test -C relay -race ./... > <abs $L>/<tag>-go.log 2>&1; echo "exit=$?"`); `cd <abs $W>/relay && golangci-lint run > <abs $L>/<tag>-lint.log 2>&1; echo "exit=$?"` (v2.15.0, as CI; config `relay/.golangci.yml`); `sh tools/run_conformance.sh > <abs $L>/<tag>-conf.log 2>&1; echo "exit=$?"`; the affected `run_netplay.sh` scenarios, each `NETPLAY_OUT=<abs $L>/<tag>-np-<scenario> sh tools/run_netplay.sh <scenario> > <abs $L>/<tag>-np-<scenario>.log 2>&1; echo "exit=$?"` (without `NETPLAY_OUT` the script deletes its folder). The proxy module has the same two Go gates in `tools/netfault`, linted with the relay's config: `cd <abs $W>/tools/netfault && golangci-lint run --config ../../relay/.golangci.yml`.
- Static gates for GDScript, Python and shell: `sh tools/run_checks.sh > <abs $L>/<tag>-checks.log 2>&1; echo "exit=$?"` (lint, warnings, Python, shell, public). New GDScript is typed.
- Suite with traces (written `SUITE(<tag>)`): `WARGRID_REPLAY_TRACE=<abs $L>/replay-<tag>.tsv WARGRID_ECONOMY_REPLAY_TRACE=<abs $L>/economy-<tag>.tsv WARGRID_COMBAT_REPLAY_TRACE=<abs $L>/combat-<tag>.tsv WARGRID_TEAM_REPLAY_TRACE=<abs $L>/team-<tag>.tsv sh tools/run_tests.sh > <abs $L>/<tag>-suite.log 2>&1; echo "exit=$?"`. While iterating: `WARGRID_TEST_ONLY=<suite file or case substring> sh tools/run_tests.sh`.
- **Never deploy.** No `fly`, `flyctl`, release workflow, `git push`, `gh pr`, `git merge`. `relay/fly.toml` stays unchanged (Question 27 answered: the variable lands with the approved deploy that runs Question 22's check).
- **Values from Questions:** every `(Qn)` mark in a snippet now carries the user's answer (Q1-Q30, user 2026-11-15, design answers "Relay guards questionnaire") and for Q31-Q33 (user, 2026-11-16, design answers "Readiness round": flush early at 65,536 bytes; pace dials 50 ms; keep the "Rejected: " prefix). A value marked `<from Task 0>` is never typed before that measurement exists.
- **Wire protocol:** protocol stays 2 (`relay/room.go:19`, `game/scripts/net/wire.gd:3`). No file in `protocol/vectors/` changes (19 vectors on `52017fd`, counted by the Godot wire test). Existing conformance cases keep their text and expectations; new rules only add cases and profiles. New `error` reasons are the only wire addition (Questions 2, 16).
- **Faults stay out of process:** no new relay environment variable for faults or tests (so the global bucket is never raised for the suite: the conformance suite paces itself, Task 3 Step 1, Question 32); the one new relay variable is `WARGRID_CLIENT_IP_HEADER` (package note). New client hooks only in `game/scripts/net/headless_client.gd` (it ships in exports, `launcher.gd`), and the only one this package adds is the silence check, which mirrors the online driver (`online_driver.gd:97`; without its `patient` switch, Question 30).
- **Privacy:** the relay logs no client IP, header value or hash of one (`docs/development.md` "Logs": "no client IPs"). Limit log lines name the rule and a count only. Test addresses are from the documentation ranges `203.0.113.0/24` and `2001:db8::/32`.
- New GDScript tests use only the simulation interface (`docs/reference/sim-interface.md`; `tools/test_sim_boundary.py`); tests that read private fields go into files already on that tool's allowlist (`test_lockstep.gd`, `test_wire.gd`) or into `test_relay_transport.gd`, which already reads transport privates (`:22`, `:39`) and holds no simulation privates.
- Subagents never commit. The coordinator makes one local commit per GREEN task if the night handoff pre-authorizes it; never push.
- Edit repository files with the Edit tool only; scratch files in `$L` with the Write tool. Scratch Godot scripts `quit()` on every path and end with a `<NAME> DONE` marker.
- Comments: why only, one line, no diff narration (user's code style). Go formatting by `gofumpt` and `goimports` (golangci-lint formatters in `relay/.golangci.yml`).
- A parked task parks the tasks that build on it: Task 1 parks 6 (proxy-burst is the lead bound's regression test); Task 4 parks 6's proxy-blackhole only; Task 5 parks 6. Tasks 2, 3, 7 and 7b park nothing else. A parked Task 6 leaves Task 8 to document what landed and say which scenarios are not in CI.
- **P2.2 behaviour is fixed:** the deadlines, phases, `over`/`again`/rematch rules, `lobby expired`/`room expired`, the `patient` switch, the sealed reject (`sendLast`) and the opponent-left result are not changed by this package; every P2.2 Go test (`deadline_test.go`, `rematch_test.go`, `reject_test.go`), conformance case and the `rematch` and `left-mid` scenarios stay green with only the allowed test edits.
- **Don't touch:** `game/scripts/simulation/`, `game/scripts/presentation/`, `game/scenes/`, `game/data/`, `game/scripts/match/` except `online_driver.gd` `submit` (Task 4), `game/scripts/launcher*.gd`, `protocol/vectors/`, the relay's existing knobs and their defaults (`WARGRID_SEATS`, `WARGRID_SILENCE_MS`, `WARGRID_HELLO_MS`, `WARGRID_LOBBY_MS`, `WARGRID_TEST_DELAY_MS`, `WARGRID_BATCH_MS` (stays off by default; Task 7b changes only where a batch is cut), `WARGRID_DRAIN_MS`), `sender.sendLast` and `enqueue` (`sender.go:34-61`), `inputDelay` and `expiryGrace` (`room.go:20-21`), the `deadline` type (`main.go:30-63`), `closeGrace` (`main.go:23`), `maxQueuedBytes` (`main.go:26`), `maxMessageBytes` (`envelope.go:12`), `MAX_QUEUED_TICKS` (`lockstep.gd:7`), `SILENCE_USEC`, `LOBBY_EXPIRY_SEC` and `patient` (`relay_transport.gd:6-7`, `:16`), `relay/Dockerfile`, every performance budget and `ASSUMED_SLOWDOWN`. `.claude/` and the night settings file are the user's.

## Night-run preparation (not done)

- The night allow list (`~/projects/wargrid-overnight-work/night-settings.json`, re-read 2026-11-16, `denyInsteadOfPrompting: true`) has `Bash(go test:*)`, `Bash(go build:*)`, `Bash(go vet:*)`, `Bash(golangci-lint run:*)` (`:109-112`), `Bash(git worktree add:*)` (`:62`), `sh tools/run_conformance.sh`, `sh tools/run_netplay.sh`, `actionlint`, `cmp`, `wc`, `uptime`, `pgrep`, `WARGRID_TEST_ONLY=*`, `PERF_LABEL=*`. Missing for this plan (Question 24), all in `night-settings.proposed.json` beside this file, for the user's `! cp`: the folder `~/projects/wargrid-wt-relay-guards` with `Edit(/~/projects/wargrid-wt-relay-guards/**)`; `mkdir -p ~/projects/wargrid-overnight-work/relay-guards*`; `cd ~/projects/wargrid-wt-relay-guards*`; `go run` (conformance by hand); `PORT=* ~/projects/wargrid-overnight-work/relay-guards/logs/relay-*` plus two rules spelling out the extra variables (`PORT=* WARGRID_SILENCE_MS=* WARGRID_HELLO_MS=* WARGRID_LOBBY_MS=* …/relay-*`, `PORT=* WARGRID_CLIENT_IP_HEADER=* …/relay-*`), since whether one `*` covers several assignments is unverified (hand-started relay binaries); `git rev-parse` (Task 8 footers); `cut`, `sort`, `uniq`, `head` (Task 0 Step 4's busiest-second pipeline); `kill` (stop that relay by the pid its start printed, never another process); `rg`; `NETPLAY_OUT=` and `WARGRID_REPLAY_TRACE=` for `~/projects/wargrid-overnight-work/relay-guards/` (the three sibling trace variables follow `WARGRID_REPLAY_TRACE` in the same command, so its prefix covers them); the `git -C … worktree add` line for this worktree. No `gh` at night: Task 0 Step 5b uses the CI numbers recorded in the verification file (C27). No `fly`, `flyctl`, `git push`, `gh pr`, `git merge`, `deploy_web.sh`, `run_game.sh`, `ssh`.
- Preparation smoke (attended, under the night settings, before the start line): `cd ~/projects/wargrid-wt-relay-guards/relay && go vet ./...` and one hand-started relay command with extra variables; a deny there switches the plan to the `-C` fallback before the run instead of during it.
- Every `ask` rule in `.claude/settings.json` and `~/.claude/settings.json` is a deny at night (`docs/night-run.md` "Before the night" step 6); the plan uses none.
- The worktree `$W` and `$L` are created at preparation (the run starts inside `$W`); Task 0 Step 1 creates either if missing.
- `golangci-lint` v2.15.0 and `actionlint` are installed on the Mac (`/opt/homebrew/bin/`, checked 2026-11-16); Go 1.27.4 local, relay and conformance pin 1.27.4 via `go.mod` (CI uses `go-version-file`). `tools/netfault/go.mod` pins the same.

## Pinned values

| # | Where | Value | Rule |
|---|---|---|---|
| N1 | `tools/run_netplay.sh` `match` terminal tick (`:91`) and `rematch` second match (`:99`, `:102`) | `9013` on `52017fd`; Task 0 records the base's value | never changes (no simulation change) |
| N2 | the four suite traces | byte-identical to Task 0's `*-before.tsv` | `cmp` silent at Tasks 4 and 8 |
| N3 | `perturb` scenario (`run_netplay.sh:149-172`): report tick 60 (`:157`), ring tick 41 (`:164`, `:168`) | unchanged | Task 2 adds a relay-log check, never edits these |
| N4 | conformance: the 61 existing cases (default 49, silence 10, delay 2) | text and expectations unchanged, except `start_window_ends` under A4 | new cases and profiles only (Task 3 Step 1's pacing changes timing, not text); Task 8 records the new total |
| N5 | `protocol/vectors/` | 19 files, unchanged | never edited |
| N6 | `startPrefix` delay 4 in conformance (`conform.go:46-52`) and `inputDelay` (`room.go:20`) | 4 | unchanged |
| N8 | netplay scenarios | 13 on `52017fd` (`run_netplay.sh:2` usage line); 17 after Task 6 | the 13 keep their assertions; Task 2 adds relay-log checks to `match`, `rematch`, `left-mid`, `perturb` |
| N7 | lockstep benchmark p99 budget 0.6 ms | unchanged | `submit` now encodes each command once; Task 8's row shows its cost |

## Allowed test edits

Only these; any other red existing test or conformance case is a stop (Opus diagnosis, park).

- **A0 (Task 1, helpers in `relay/stall_test.go`, appended after the `stalled` methods, `:15-30`):** the stalled seat's sends must not use `say` (`batch_test.go:31-36`, `t.Fatal` on a write error): the relay closes that socket once its write queue passes 1 MiB (`writeLater`, `main.go:104-120`, direct close `:112`, about 17 frames of 60 KB), and the next `say` would abort the test before any assertion. Seat 2's channel (capacity 50, `batch_test.go:22`) now also receives seat 1's ticks, so it is drained inside the send loop; a full channel would block seat 2's reader. Log capture needs a lock, since relay goroutines log while the test reads. (`frames` in `deadline_test.go:32-51` records writes of unit-test conns, not of a real socket; it does not replace `drain`.)

  ```go
  // drain reads c without blocking and notes which frame types arrived.
  func drain(c *cl, seen map[string]bool) {
  	for {
  		select {
  		case s := <-c.ch:
  			for _, k := range []string{"left", "error"} {
  				if strings.Contains(s, `"type":"`+k+`"`) {
  					seen[k] = true
  				}
  			}
  		default:
  			return
  		}
  	}
  }

  // untilPong pings over s and reads c until the pong, noting left and error frames on the way. The relay's reader
  // posts a tick to the room before it answers the next ping, so a tick sent after the pong is behind it in room order.
  func untilPong(t *testing.T, s *gws.Conn, c *cl, seen map[string]bool) {
  	say(t, s, `{"type":"ping","t":1}`)
  	deadline := time.After(2 * time.Second)
  	for {
  		select {
  		case m := <-c.ch:
  			if strings.Contains(m, `"type":"pong"`) {
  				return
  			}
  			for _, k := range []string{"left", "error"} {
  				if strings.Contains(m, `"type":"`+k+`"`) {
  					seen[k] = true
  				}
  			}
  		case <-deadline:
  			t.Fatal("no pong within 2 s")
  		}
  	}
  }

  type syncBuf struct {
  	mu sync.Mutex
  	b  bytes.Buffer
  }

  func (s *syncBuf) Write(p []byte) (int, error) { s.mu.Lock(); defer s.mu.Unlock(); return s.b.Write(p) }
  func (s *syncBuf) String() string            { s.mu.Lock(); defer s.mu.Unlock(); return s.b.String() }

  // captureLogs routes slog to a buffer for one test; relay goroutines log concurrently, hence the lock.
  func captureLogs(t *testing.T) *syncBuf {
  	buf := &syncBuf{}
  	prev := slog.Default()
  	slog.SetDefault(slog.New(slog.NewTextHandler(buf, nil)))
  	t.Cleanup(func() { slog.SetDefault(prev) })
  	return buf
  }
  ```

  (imports `bytes`, `log/slog`, `sync`; `untilPong` closes the skew review finding: a 50-byte tick from one seat can reach the room several 60 KB frames ahead of the other seat's, which alone could trip the bound.)
- **A1 (Task 1):** `relay/stall_test.go` `TestStalledPeerStillProducesLeft` (`:32-75`). On `52017fd` (unchanged since `ee2f353`) seat 1 sends one tick 4 (`:56-57`, P2.2: leaves the start window for the 500 ms silence rule), then seat 2 sends ticks 4..399 (`:59-61`); under the lead bound seat 2 is rejected at tick 10 (bound `max(4, 3) + 4 + 1 = 9`), so the test would pass for the wrong reason (a rejection). Seat 1 must keep sending, so its 500 ms read deadline is renewed by every frame (`deadline.touch`, `main.go:151`, renewal set at its first tick, `room.go:251-253`): what closes it is the write side (queue cap or write deadline, `main.go:117`). Keep `:56-57` (seat 1's tick 4); seat 1 continues at tick 5. Replace `:58-74` (from `pad :=` to the end of the `for` loop) with:

  ```go
  	logs := captureLogs(t)
  	pad := strings.Repeat("x", 60000)
  	seen := map[string]bool{}
  	for i := 4; i < 400 && !seen["left"]; i++ {
  		say(t, b, `{"type":"tick","seat":2,"tick":`+strconv.Itoa(i)+`,"commands":["`+pad+`"]}`)
  		untilPong(t, b, bc, seen)
  		// Seat 1 keeps sending so the lead bound never fires; only its reads are stalled.
  		if a.WriteString(`{"type":"tick","seat":1,"tick":`+strconv.Itoa(i+1)+`,"commands":[]}`) != nil {
  			break
  		}
  	}
  	deadline := time.After(4 * time.Second)
  	for !seen["left"] {
  		select {
  		case <-deadline:
  			t.Fatal("no left within 4 s although seat 1 stopped reading")
  		case <-time.After(200 * time.Millisecond):
  			say(t, b, `{"type":"ping","t":1}`)
  			drain(bc, seen)
  		}
  	}
  	if seen["error"] || strings.Contains(logs.String(), "lead bound") {
  		t.Fatal("the lead bound fired, so the stall is not what produced left")
  	}
  ```

  Fails if: the write-side close is removed (no `left` in 4 s), or the lead bound fires on either seat (the `error`/`lead bound` check).
- **A2 (Task 1):** `relay/queue_test.go` `TestSlowReaderBacklogIsCapped` (`:33-67`; seat 1 sends no tick on `52017fd`, so it sits in its start window, `testConfig` lobby 1 min, until the loop's first tick): same interleave for ticks 4..2003 (`:50-52`) with the A0 helpers; replace `:49-66` (from `pad :=` to the end of the `left` select) with:

  ```go
  	logs := captureLogs(t)
  	pad := strings.Repeat("x", 60000)
  	seen := map[string]bool{}
  	sent := 0
  	for i := 4; i < 2004 && !seen["left"]; i++ {
  		say(t, b, `{"type":"tick","seat":2,"tick":`+strconv.Itoa(i)+`,"commands":["`+pad+`"]}`)
  		sent++
  		untilPong(t, b, bc, seen)
  		if a.WriteString(`{"type":"tick","seat":1,"tick":`+strconv.Itoa(i)+`,"commands":[]}`) != nil {
  			break
  		}
  	}
  	runtime.GC()
  	var m runtime.MemStats
  	runtime.ReadMemStats(&m)
  	if m.HeapAlloc > 32<<20 {
  		t.Fatalf("heap %d MB after %d frames of 60 KB to a slow reader; the write queue is not capped", m.HeapAlloc>>20, sent)
  	}
  	deadline := time.After(3 * time.Second)
  	for !seen["left"] {
  		select {
  		case <-deadline:
  			t.Fatal("no left within 3 s; the slow reader was not cut off")
  		case <-time.After(50 * time.Millisecond):
  			drain(bc, seen)
  		}
  	}
  	if seen["error"] {
  		t.Fatal("seat 2 got an error frame; the lead bound fired")
  	}
  	if !strings.Contains(logs.String(), "write queue full") {
  		t.Fatal("seat 1 was not closed by the write-queue cap")
  	}
  ```

  Heap ceiling (32 MiB) and the 3 s limit unchanged. Fails if the cap is removed: seat 1 keeps reading (silence is 1 min), its writes keep succeeding, all 2000 frames (120 MB) queue, the heap check goes red; and the `write queue full` check names the mechanism.
- **A1/A2 race (accepted, not widened):** after the relay closes seat 1 at its tick L, seat 2 may still send up to L + 5 before the room processes seat 1's leave; one more frame would trip the bound on seat 2. Seat 1's next write fails within about one iteration (the relay's close resets the socket), so the margin is about four frames (five in A1, where seat 1 leads by one). If either test flakes in 3 `-race` runs, stop (Task 1 Stop); do not loosen the `error` check.
- **A3:** no other existing Go test is expected to change: `TestBatchJoinsTicks` sends ticks 4, 5 (`batch_test.go:67-69`); `TestRoomPanicEndsOnlyThatRoom` posts tick 4 (`shutdown_test.go:106`); `deadline_test.go` and `rematch_test.go` post only tick 4 per seat (`firstTick`, `rematch_test.go:32-34`); `TestNoPongAfterReject` (`reject_test.go`) sends no tick. Every default and delay conformance case sends at most tick 6 from a seat whose peer is silent (`non_contiguous_tick` `conform.go:203`, `test_delay_keeps_order_and_holds_left` `:661-675`), `rematch_round_trip` sends tick 5 against a peer at 4 (`:441-471`), all under the start bound of 8; `tick_after_over` and `tick_after_again` keep `invalid message` because the existing refusal runs first (C4). The one exception is A4. Task 1 Steps 3 and 4 confirm this with the unchanged suite.
- **A4 (Task 1, Question 28):** conformance `start_window_ends` (silence profile, `conform.go:636-658`): seat 2 sends a tick every 100 ms from 4 while seat 1 stays in its 1.5 s start window; under the lead bound seat 2 hears `too far ahead` at tick 9 instead of `left(1, 3)`. Seat 2 must stay active (its own silence rule runs from its first tick, 300 ms) without passing the bound: in the `case <-tk.C:` branch (`:645-647`), replace the two lines `cls[1].say(tick(2, t, ""))` and `t++` (`:646-647`) with: send `tick(2, t, "")` while `t <= 8`, else ``cls[1].say(fmt.Sprintf(`{"type":"ping","t":%d}`, t))``; `t++` either way. The relay answers each JSON ping with a pong to seat 2 (`main.go:178-179`), and the receive arm (`case s, ok := <-cls[1].in:`, `:648`) takes the first frame as the `left`, so right after that `case` line insert ``if ok && strings.HasPrefix(s, `{"type":"pong"`) { continue }`` (as `pingUntil`, `:494-513`, and `parked_room_expires` already skip pongs). `el := time.Since(start)` (`:649`) and the two `check` lines (`:650-651`) stay; search by the quoted text, not by the printed line. Pings renew seat 2's deadline as ticks did (`main.go:151`); without them seat 2 dies of its own 300 ms silence first. The `left(1, 3)` and elapsed-time checks are unchanged. Still fails if the start window is removed (left before `lobbyLimit − 200 ms`); it does not test the lead bound (seat 2 never sends tick 9; Step 2's cases do). A red A4 is repaired only by the pong skip; dropping the pings, the `left(1, 3)` check or the elapsed check is a stop, not a fix.
- **A5 (Task 2, Question 29):** `tickMsg` gains one field, `hash hashMsg` (`hashMsg{tick int; value string; ok bool}`), at the end. The three positional test literals `tickMsg{a.seat, 1, inputDelay, []byte(…)}` (`deadline_test.go:105`), `tickMsg{c.seat, c.seat.n, inputDelay, []byte(…)}` (`rematch_test.go:33`) and `tickMsg{a.seat, 1, inputDelay, []byte(…)}` (`shutdown_test.go:106`) gain `, hashMsg{}` (compile fix only, no expectation changes). `main.go:173` (`c.room.post(tickMsg{c.seat, e.seat, e.tick, bytes.Clone(msg.Bytes())})`, the fourth and last positional literal) becomes a keyed literal. Adding the field breaks all four; find them by `rg -n 'tickMsg\{' relay`, never by the printed line.

## Determinism notes (`docs/reference/determinism-rules.md`)

- No simulation file changes. The relay never reads commands; the hash comparison only reads the `hash` object the client already sends (`lockstep.gd:124-131`). Relay rules can end a session (error, close), never change a frame: forwarded bytes stay byte-exact (`forwards_byte_for_byte`, `spaced_json_forwarded_verbatim`).
- The client's pending-frame cap refuses an order **before** it is stamped into the queue: a refused order never gets a sequence number (`_sequence` advances only on accept), so sequences stay contiguous and no command log or replay changes. Under normal play the cap is never reached (scripted human and bots issue far below 64 KiB per tick), so N1 and N2 hold.
- `submit` encodes each command once to measure it (`Wire.encode`, sorted keys, full precision): the same function the frame uses, so the size is exact up to the separators, which the reserve covers. Encoding has no side effect on the command dictionary. The `sequence` field is written into the measured copy with the current `_sequence` value (so its digits are counted), but `_sequence`, `_submit_times` and `_queue` change only after the size check passes (Task 4 Step 3 gives the order).
- The headless silence check reads wall time only to end a session, never to decide a tick; seat scripts still run only when a tick can step (`_step_once`, `headless_client.gd:175-185`), so every fault that does not end the match keeps N1 and equal hashes (netplay stress §0 "Key property").
- Rematch: each match gets a new `Lockstep` (`headless_client.gd:126`, online driver `create`), so the pending-frame cap and `_queue_bytes` start at zero per match; the relay clears pending hashes at rematch (C5), so no value crosses matches.

## Same-tick and interaction cases

No new simulation command. Every new rule against every existing one; "room order" means the order the room goroutine processes events, which across sockets is arrival order.

| Rule | Case | Expected | Test |
|---|---|---|---|
| Lead bound | first frames, peer silent | seat sends ticks 4..8 (`(d−1) + d + 1 = 2d`) forwarded; tick 9 rejected | conformance `lead_bound_start_edge` |
| | steady state | after the peer's tick T reached the room, ticks up to `T + d + 1` forwarded, `T + d + 2` rejected | conformance `lead_bound_steady_edge` |
| | racing client (ticks 4..200 back to back, peer silent) | error `too far ahead` (Question 2), close, peer gets `left{1, 8}`; nothing past 8 forwarded | conformance `racing_ticks_rejected` |
| | max-size frames inside the bound | 65,536-byte frames forwarded as today | existing `frame_cap_boundary` plus `max_size_frames_inside_bound` |
| | peer's leave processed before the frame | leaver no longer in `r.seats`: skipped | LB-U1 |
| | peer's leave processed after the frame | leaver's frozen `lastTick` still counted: valid, honest seats cannot pass it anyway | LB-U1 |
| | peer dead (rejected, socket not yet closed) | frozen `lastTick` counted | LB-U2 |
| | no other seat left (or `WARGRID_SEATS=1`) | no bound | LB-U2 |
| | rejected frame | counts no frame, byte, peak or hash | LB-U3 |
| | `WARGRID_TEST_DELAY_MS` / `WARGRID_BATCH_MS` | bound computed on receipt, before the delayed or batched write: unaffected | `spike` scenario (now in CI); `TestBatchJoinsTicks` unchanged |
| | hold-and-burst on one seat (TCP loss) | burst after the hold never rejected | `proxy-burst` (relay log has no `lead bound` line) |
| | slow but alive peer | the fast seat stops at the bound instead of queueing up to 300 ticks | LB-U1 (bound value), `stall` scenario |
| Hash comparison | equal values, two seats | no `DESYNC`, no `desync` in `MATCH END` | HC-U1 |
| | different values, two seats | one `DESYNC` line `tick=60 groups=1|2`; `MATCH END` gains `desync=60 desync_groups=1|2` | HC-U1; `perturb` scenario relay-log check |
| | three seats, seat 2 odd | `groups=1,3|2` | HC-U2 |
| | hash tick not `tick − inputDelay` (e.g. tick 4 carrying hash 30) | forwarded byte-exact, not recorded | HC-U3; existing `forwards_byte_for_byte` stays green |
| | seat leaves with comparisons pending | pending entries cleared, no log | HC-U4 |
| | pending entries with one seat leading | at most 1 open (derived: a lead of at most `2d` = 8 ticks at the start and `d + 1` = 5 later is shorter than the 30 ticks between hashes, `lockstep.gd:37`, `:126`) | HC-U4 |
| | a seat puts an honest-offset hash on every frame (abusive or buggy client) | at most `maxDelay + 1` = 5 open entries (`pruneHashes`: an entry whose frame every seat already sent can never complete); a real mismatch still logs `DESYNC` | HC-U6 |
| | mismatch at hash tick 0 (frame 4) | logged once, `desync=0` in `MATCH END` (sentinel `desyncGroups == ""`) | HC-U1 third room |
| | second mismatch after the first | logged once per match (Question 4) | HC-U1 |
| Byte fields | frames of 100, 2000 and 65536 bytes in one second, then one more in the next | `seat1_max_frame=65536`; `seat1_peak_bps` = bytes of the busiest one-second window | BF-U1 |
| | seat rejected | its stats still logged at its leave | BF-U1 |
| Per-IP limits | 16 open sockets from one address held, the 17th refused (cap 16, Q10) | `too many connections` (the error is the socket's last frame, C20), close; a socket from another address works; after one of the 16 closes, a new one from the first address works within 1 s (retried: the refused socket counts until its server-side close) | conformance `limits_conn_cap` |
| | rejected-at-open socket closes | count decremented exactly once | LM-U2 |
| | key `""` (no header variable, no Authorize hook in a test server, or a missing header under Q26 "skip") | `open` never refuses and does not track; `join` checks only the global bucket | LM-U2, LM-U4; `TestStalledPeerStillProducesLeft`, `TestBatchJoinsTicks` (they build their own upgrader without `Authorize`, `stall_test.go:36-41`, `batch_test.go:52-57`: a plain type assertion on the session key panics there) |
| | 11th hello from one address within the burst (burst 10, 1 per s) | `too many joins`, close, no room created; another address unaffected | conformance `limits_join_rate` |
| | hello for an unknown code with the unknown-match bucket empty | closed without reply; a valid code from a new address still welcomed | conformance `limits_unknown_match` |
| | global join bucket empty (burst 20, refill 20 per s, Q12) | `relay busy` for any address | conformance profile `global` |
| | the paced default, delay and silence suites (dials at least 50 ms apart, Task 3 Step 1) | never trip the global bucket: hellos by any time are at most the dials by then, at most 1 + elapsed / 50 ms, below the bucket's 20 + elapsed / 50 ms | default profile relay log: zero `msg=limit` lines (Task 3 Step 7) |
| | table full, no idle entry | `relay busy`, connection untracked (no decrement at close) | LM-U3 |
| | idle entry (no socket, bucket drained) | reclaimed when the table is full | LM-U3 |
| | `WARGRID_CLIENT_IP_HEADER` unset | per-IP rules off, global rules on; start log says so | default profile (all from 127.0.0.1, passes); LM-U4 |
| | header missing or unparsable | Q26 (answered): per-IP rules skipped for that socket, global buckets still act (a missing header on fly means a misconfiguration, and a shared key would cap all such clients together at 16) | LM-U4 |
| | IPv6 | keyed by /64 (Question 9) | LM-U4 |
| | limit vs started match | limits act on open and hello only; frames of a seated socket never touch the limiter | LM-U5 |
| | refusal racing a pong on the same socket | the reader goroutine has set `rejected` or the sealed sender drops the pong; the error stays last (29724db) | existing `TestNoPongAfterReject`; conformance cases expect error then close |
| | drain (SIGTERM) | unchanged: the HTTP server stops accepting first | `relay-term` scenario |
| | relay process restart | the limiter table and buckets start empty (in memory only); accepted, no persistence | none (by design) |
| Batch guard (Task 7b, `WARGRID_BATCH_MS` on) | five 65,536-byte frames for one recipient inside one interval | five messages, none over 65,536 bytes (Question 31) | BG1 |
| | small frames inside one interval | one newline-joined message, as today | BG1; existing `TestBatchJoinsTicks` |
| | joined size exactly 65,536 | one message; one byte more: two | BG1 |
| | a reject while frames wait in the batch | `sendLast` flushes the batch, then the error; nothing after it (C20, C22) | `TestNoPongAfterReject` (unchanged), BG1 sealed half |
| | lead bound / limits with batching | refusals go through `reject`, unaffected by the cut | none new |
| Opponent left (P2.2 slice 2) | a seat rejected after the start (`too far ahead`, refused send closing the transport, 5 s silence) in a 1v1 | the other seat ends `ended_left` and wins: "Your opponent left", headless `NETCLIENT VICTORY left` (C23) | `left-mid` (unchanged); `proxy-reset`, `proxy-blackhole` seat 1 `ended_left` |
| | seat 2 leaves mid-match with one hash entry pending (`left-mid`) | entry cleared at leave, no `DESYNC`; `MATCH END` carries both seats' byte fields | `left-mid` relay-log check (Task 2 Step 4), HC-U4 |
| Late join | a hello for a started room after a seat left | `match full`, as today (`room.go:204-206`; a parked or rematched room stays `started`); no late-joiner path exists, so no lead-bound or hash case for one | existing `started_room_stays_full_after_leave` (`conform.go:334-343`), `rematch_round_trip` third socket (`:467-470`) |
| Client | refused `send_text` | transport reports closed; the match ends `ended_relay`, "connection to relay lost" | T7 (real socket whose reader stops) |
| | refused ping (the ping in `poll`, `relay_transport.gd:36`) | same as a refused frame: the ping goes through `send_text` | T7 second half |
| | refused order through the HUD | `driver.submit` queues a refused answer; the next frame's `_take_answers` shows "Rejected: Too many orders at once; wait a moment" with the reject sound (C25, Question 33) | `test_online_scene.gd` N-cap |
| | pending frame at the cap | the order is refused with the HUD note (Question 17); the next tick's frame is at most 65,536 bytes and decodes; the queue accepts again after the send | L19 |
| | refused order | no sequence consumed; no latency sample | L19 |
| | own frame fails to decode (cannot happen under the cap) | `ended_protocol` "own frame: …", nothing sent | L20 |
| | headless client, no frame for 5 s | `ended_relay` | `proxy-blackhole` |
| | headless client after a 3 s freeze (`stall`) | the 3 s gap is under the 5 s rule: no end. This does not prove that buffered frames refresh the receive time before the check (3 s stays under 5 s either way); `proxy-blackhole` proves the 5 s path exists | `stall` scenario (now in CI) |
| Proxy | 7-byte slices both seats; holds seat 1 3.5 s at 2 s, seat 2 3 s at 3 s (landed setup, accepted 2026-11-17) | match completes: N1, three-way hashes | `proxy-burst` |
| | reset at 4 s, seat 2 | s2 `ended_relay`, s1 `ended_left`, both within 2 s of the reset; shared hash prefix equal | `proxy-reset` |
| | blackhole 7 s at 3 s, seat 2 | s2 ends about 6 s after the blackhole begins (within 5.5 to 7.5 s since 2026-11-17), s1 `ended_left` after 10 s (within 9 to 12 s); the proxy keeps the relay side open and silent after seat 2 closes | `proxy-blackhole` |

### Against P2.2's messages and phases (rebase 2026-11-15)

Every new rule against `over`, `again` (client and relay echo), `error` `lobby expired` / `room expired`, and the phases lobby, start window, playing, parked (every seat sent `over`), rematch (all sent `again`, second `start`). "Same message" means the event the room goroutine handles right before or after; all are on one goroutine, so order is exact.

| Rule | Phase / message | Case | Expected | Test |
|---|---|---|---|---|
| Lead bound | lobby | a tick before `start` | `invalid message` as today (`!r.started`, `room.go:247`); the bound never runs | existing `tick_before_start` |
| | start window | seat 2 ticks while seat 1 sends nothing for the whole window | ticks 4..8 forwarded, 9 rejected `too far ahead`; seat 1's window still ends with `left(1, 3)` if seat 2 stays within the bound | `lead_bound_start_edge`; `start_window_ends` under A4 |
| | playing, `over` from seat 1 at tick T | seat 2 keeps ticking | seat 1's frozen `lastTick` T still counts: seat 2 forwarded up to `T + d + 1`, rejected after; honest seats end on the same tick and never get there | LB-U4 |
| | `over`, then a tick | same seat sends a tick after its `over` | `invalid message`, not `too far ahead` (the existing check runs first, C4) | existing `tick_after_over`, `tick_after_again` |
| | parked, then rematch | first frames of match 2 | `lastTick` 0 again: start bound 8 for match 2; tick 9 of match 2 before the peer's tick rejected; the old match's `lastTick` never counts | LB-U4; netplay `rematch` (no `lead bound` line) |
| | `again` while not parked | no tick involved | unchanged | existing `again_twice` |
| | `room expired` | seats `dead` | frames ignored (`s.dead`, `room.go:244`); the bound never runs | existing `parked_room_expires` |
| | `lobby expired` | room removed before start | the bound never runs | existing `lobby_expires_despite_pings` |
| Hash comparison | playing, `over` from seat 1 with an entry pending | seat 2's frame for that hash tick | completes and compares as usual | HC-U5 |
| | parked with one entry pending (a client hashed, then sent `over`) | rematch | `r.hashes` cleared in `rematch()`: match 2's same hash tick never compares with match 1's value; no `DESYNC` | HC-U5; `rematch` scenario `! grep msg=DESYNC` |
| | rematch | `desync` / `desync_groups` | first mismatch of the room; a desynced match ends the room (clients close on `ended_desync`), so in practice per match | HC-U1 (unchanged), BF-U2 |
| | `room expired` / `lobby expired` | pending entries | dropped with the room; no log | none (room ends) |
| Byte fields | rematch | frames of match 1 and match 2 | `seatN="<f>f/<b>B"` adds up (P2.2); `seatN_max_frame` and `seatN_peak_bps` are maxima over the room; one `MATCH END` | BF-U2; `rematch` scenario (one `MATCH END`, unchanged) |
| | parked | no frames | the one-second window ends; nothing counted | BF-U2 |
| Per-IP limits | socket open, no hello | hello deadline 5 s (`main.go:127`) | the socket holds its per-IP slot until the deadline closes it; `OnClose` decrements once | LM-U2; conformance `limits_conn_cap` finishes inside 5 s |
| | refused at open (`too many connections`) | hello deadline set too | `reject` closes after 200 ms (`closeGrace`), before the 5 s deadline; one decrement | LM-U2 |
| | lobby | the creator's socket | counts for its address for up to 15 min (lobby expiry), then `lobby expired` and close: one decrement | LM-U6 |
| | `lobby expired`, friend's hello for that code | room removed | `unknown match`, which draws from the unknown-match bucket; empty bucket: silent close (Question 13) | `limits_unknown_match` (unchanged); none for the expired variant (Question 13) |
| | `room expired`, a hello for the code | room still listed until its seats close (`r.expired`, `room.go:198-199`) | `unknown match`, same as above | none (same path) |
| | rematch | no hello | draws from no join bucket; seat sockets stay counted | LM-U6 |
| | `over` / `again` | per-seat messages | never touch the limiter | LM-U5 (limiter untouched by frames) |
| Client | `over` refused (`_finish`, `online_driver.gd:235`) or `again` refused (`play_again`, `:210`) | transport closed | the room counts as gone (`_room_gone`, `:141-142`): "The room closed", result kept; the same path P2.2 has for a closed socket | T7 covers `send_text`; no new scene test (the path is P2.2's `test_room_closed_after_end`) |
| | pending-frame cap across a rematch | new `Lockstep` per match | the cap starts empty in match 2 | none (new object) |
| | headless 5 s check while waiting for `again`/`start` (`_rematch_step`) | relay alive | pongs refresh `_last_rx` (`relay_transport.gd:31-33`), so no end; with the relay silent for 5 s, seat ends `ended_relay` | netplay `rematch` (green); Question 30 |

## Review focus

1. Lead bound: the formula and its `+ 1`, the sentinel when no other seat exists, no integer overflow, rejection before any stat or hash update.
2. Hash comparison: bounded memory on every path (leave, dead seat, wrong offset, `over`, rematch, a hash on every frame; at most one open entry for honest clients, at most `maxDelay + 1` against any client, without the relay knowing the hash interval), groups format, one log per room, cleared at rematch.
3. Limiter: every open increments once and every close decrements once (including rejected and untracked sockets); the table never grows past its size; no IP reaches a log; the header is read only when the variable is set.
4. Test edits A1, A2, A4, A5: assertions unchanged in intent; no weakened check.
5. Proxy: byte order kept in both directions; a blackhole never resumes a corrupted stream; the relay side stays open after the client side closes during or after a blackhole; the proxy exits on its own.
6. Client: the cap's arithmetic against the real frame, the refused send path (frames, pings, `over`, `again`), no sequence or submit time consumed by a refused order.
7. P2.2 untouched: no deadline, phase or reason changed; the sealed reject and the opponent-left result kept; every P2.2 test, conformance case and the `rematch` and `left-mid` scenarios green with only A4 and A5.
8. Batch guard: no joined message over 65,536 bytes, frame order kept, the `sealed` check first, `WARGRID_BATCH_MS` still off by default.
9. Conformance pacing: dials paced, bucket cases unpaced; no case text or expectation changed; no relay variable added for tests.

## Risks and model routing

Riskiest first: (1) per-IP limits cut real players behind one shared address: the cap is 16 sockets per address (Q10, user 2026-11-15), which covers a 3v3 from one house (6), M9 seat resume and a LAN party, but carrier-grade NAT (mobile and some home ISPs) can still put more unrelated players behind one IPv4; or trip on the edge if the header is spoofable on fly (unverified, docs do not say; Question 22 morning check after an approved deploy, 17 forged sockets); a missing header would cap the whole relay if it mapped to one shared key (Question 26), which is why `fly.toml` stays untouched until that check (Question 27); (2) the fixed global join bucket (burst 20, refill 20 per s, Q12) tripping a conformance suite: the default profile sends about 97 hellos, about 105 after Task 1 (read from `conform.go:175-515`, not counted by a run); Task 3 Step 1 paces the suite's dials (Question 32), so suite growth never moves the production limit; pacing adds at most about 5 s to the default profile; (3) CI wall time from eight more netplay scenarios per platform, `spike` alone about 45 s by the 4/L model, inside the export job's `timeout-minutes: 25` (`ci.yml:97`) and Question 21's 20 min line: the latest green `main` run (`43863567341`, with `rematch` and `left-mid`) took 4 min 4 s Linux and 6 min 25 s Windows, netplay step 50 s and 71 s, so twice the added local time must stay under about 13 min 35 s; (3b) the batch guard's cut at 65,536 bytes is below the client's 131,072-byte buffer on purpose (Godot's exact buffer boundary is not read; a 65,536-byte message is what every client must already read, a full frame, and `test_relay_transport.gd` T4 sizes the buffers for it); the Godot client still cannot read any joined message (`docs/development.md:116`), so batching stays a relay-side experiment; (3c) P7 and night 7 land first and touch `lockstep.gd` and the online driver: Task 4 re-anchors by symbol and stops if `submit` or `finish_tick` moved (C26); (4) Windows behaviour of the Go proxy's reset (`SetLinger(0)`) and of the headless silence check (CI only; not testable at night); (5) A1/A2 interleave racing across sockets under `-race`: `untilPong` orders each pair of ticks in the room, so only the after-close margin of "A1/A2 race" remains; if either flakes, stop, do not widen; (6) a P2.2 regression hidden by a relay change: every P2.2 Go test, conformance case and the `rematch` scenario run at every relay task's gate.

| Task | What | Model |
|---|---|---|
| 0 | Baseline: worktree, relay gates, conformance, all 13 netplay scenarios with times, hello count of the default conformance suite, anchors | Sonnet |
| 1 | Lead bound (LB-U1-U4), conformance edges and abusive rows, test edits A1, A2, A4 | Sonnet |
| 2 | Relay hash comparison and `MATCH END` byte fields (HC-U1-U6, BF-U1, BF-U2), test edit A5, perturb, match, rematch and left-mid relay-log checks | Sonnet |
| 3 | Conformance pacing, per-IP and global limits (LM-U1-U6), conformance profiles `limits` and `global` (`fly.toml` stays untouched, Question 27) | Sonnet |
| 4 | Client guards: refused send closes (T7), pending frame cap (L19, L20), headless silence check | Sonnet |
| 5 | Fault proxy `tools/netfault` (NF1-NF5) | Sonnet |
| 6 | Proxy scenarios in `run_netplay.sh`, CI loop and proxy build, lint and test jobs | Sonnet |
| 7 | Goroutine-churn Go test (GC1), red by a planted leak | Sonnet |
| 7b | Batch size guard in `sender.addBatch` (BG1), test-first | Sonnet |
| 8 | Docs and package gate (benchmark row) | Sonnet |
| 9 | Fresh-context branch review plus the player-experience reviewer on the client and player-text parts, one fix round, `/ponytail-review` | **Opus (high)**; `player-experience-reviewer` (AGENTS.md, user 2026-11-16); Grok is in the night allow list since P2.2 (`Bash(GROK_MEMORY=0 grok:*)`), so the handoff may add it as the gate's second reviewer |

Diagnosis of any unexpected red goes to an Opus (high) agent first.

---

### Task 0: Baseline

```text
Task: record the untouched tree's relay gates, conformance, netplay scenarios and timings, and the default conformance suite's hello count.
Owns: the verification file only.
Invariant: no repository file changes.
Boundary: load average above 2.5 delays timing records (note "host under load").
Red: n/a (measurement).
Green: go test exit 0; golangci-lint 0 issues; CONFORMANCE PASSED 61; NETPLAY PASSED for all 13 scenarios; SUITE(before) exit 0.
Stop: any of these red on the untouched tree; a command of this plan denied by the night settings and by its fallback (park, morning item: settings).
```

- [ ] **Step 1:** `mkdir -p <abs $L>` (no-op when the preparation made it). If `$W` is missing: `git -C ~/projects/wargrid worktree add ~/projects/wargrid-wt-relay-guards -b relay-guards main`. In `$W`: `git status --short` empty; `git log --oneline -1` recorded (expect `main`'s head; `52017fd` or later); `pgrep -fl 'godot|generalszh'` (list, kill nothing). Permission smoke, first command in a module folder: `cd <abs $W>/relay && go vet ./... > <abs $L>/t0-vet.log 2>&1; echo "exit=$?"`; if denied, rerun as `go vet -C relay ./...` and use the `-C` fallback (Global Constraints) for the rest of the run, lint gates to the morning list; Stop only if the fallback is denied too.
- [ ] **Step 2:** `godot --headless --path game --import > <abs $L>/t0-import.log 2>&1`; `SUITE(before)`; record CASES, CHECKS, `wc -l <abs $L>/*-before.tsv`.
- [ ] **Step 3 (relay gates):** the Go test and lint commands of Global Constraints with tag `t0`; `sh tools/run_conformance.sh` (expect `CONFORM default: 49 cases`, `delay: 2`, `silence: 10`, `CONFORMANCE PASSED 61` on `52017fd`).
- [ ] **Step 4 (hello count, a check, not an input):** `run_conformance.sh` deletes its relay logs on a pass, so run the default profile by hand once: `cd <abs $W>/relay && go build -o <abs $L>/relay-t0 .`; then start `PORT=18100 <abs $L>/relay-t0 > <abs $L>/t0-relay-default.log 2>&1` with Bash `run_in_background: true` (if the log says `listen failed`, add 50 to the port) and read its pid with `pgrep -x relay-t0` (process name only, so the wrapper shell of the background command does not match); `cd <abs $W>/protocol/conformance && go run . -url ws://127.0.0.1:18100/ws -profile default > <abs $L>/t0-conf-default.txt 2>&1; echo "exit=$?"`; `kill <pid>` (only that pid; this is the "start by hand" recipe every later step reuses, with its own binary name `relay-t<N>` and port `18100 + 100 × N`). Count `rg -c 'seat joined|join rejected' <abs $L>/t0-relay-default.log` (hellos that reached `join`), the log's first and last timestamps (suite wall time) and the most hellos in any one second (`rg -o 'time=\S+' … | cut -c6-24 | sort | uniq -c | sort -rn | head -1` on the joined/rejected lines). Record total and busiest second. The production burst is fixed (20, Q12); this count only shows how close the unpaced suite comes to it.
- [ ] **Step 5 (netplay, all 13):** `match rematch kill left-mid stall silent spike perturb version maps map-mismatch relay-down relay-term`, each with its own `NETPLAY_OUT`; record each `NETPLAY PASSED <s> s` and the `match` terminal tick (N1). The sum of `kill stall spike version` times is the CI cost Question 21 reports.
- [ ] **Step 5b (CI budget):** no `gh` at night. Use the numbers in the verification file's evidence rows (latest green `main` run `43863567341` on `d820773`, read 2026-11-16 with `gh run view`: export job Linux 4 min 4 s, Windows 6 min 25 s; "Exported netplay scenarios" 50 s and 71 s; it includes `rematch` and `left-mid`). Headroom to Question 21's line = 20 min minus the longer job (13 min 35 s); Task 6 Stop uses it. If the preparer recorded a newer run, use that one.
- [ ] **Step 6 (anchors, by symbol):** `room.go` `func (r *room) forward`, `func (r *room) refuse`, `func (r *room) leave`, `func (r *room) rematch`, `func (r *room) park`, `func (r *room) expire`, `inputDelay`, `type seat struct`, `type tickMsg struct`, `stats`; `envelope.go` `func validHash`, `case "tick":`; `sender.go` `func (s *sender) sendLast`, `func (s *sender) addBatch`, `sealed`, `func (s *sender) flushBatch`; `main.go` `type relay struct`, `func (c *conn) reject`, `func (h *relay) OnOpen`, `OnClose`, `OnMessage`, `case "hello":`, `c.room.post(tickMsg{`, `func newServer`, `gws.NewUpgrader`, `slog.Info("relay started"`; `stall_test.go` `say(t, a, \`{"type":"tick","seat":1,"tick":4`, `for i := 4; i < 400`; `queue_test.go` `for i := 4; i < 2004`, `case s := <-bc.ch:`; `rg -n 'tickMsg\{' relay` (four positional literals: three tests and `main.go`); `rematch_test.go` `r.stats[1]`; `conform.go` `func runConform`, `func defaultCases`, `func silenceCases`, `"start_window_ends"`, `startPrefix`; `client.go` `func dial`, `func (cl *client) say`; `run_conformance.sh` `for p in default:`; `run_netplay.sh` `start_client()`, `start_pair()`, `same_hashes()`, `match)`, `rematch)`, `left-mid)`, `perturb)`; `ci.yml` `for scenario in match rematch`, `Build relay for the netplay step`, `relay-test:`, `relay-lint:`; `lockstep.gd` `func submit`, `func finish_tick`, `_packets[_seat][packet_tick] = Wire.decode`, `func opponent_left`; `relay_transport.gd` `func poll`, `func send_text`, `func closed`, `func silent`; `headless_client.gd` `func _run_steps`, `func _rematch_step`, `func _finish`; `online_driver.gd` `func submit`, `func _new_answers`, `func take_answers`, `_transport.silent`, `func _finish`, `func play_again`; `match_screen.gd` `func _submit`, `func _take_answers`; `seat_sim.gd` `func issue_command`. Record drift, and whether P7 and SB4 have landed and how bot orders reach the host's frame (C26).
- [ ] **Step 7:** fill the verification file's Baseline; Task 0 GREEN.

---

### Task 1: Lead bound

```text
Task: room.forward rejects a tick beyond min over the other seats of max(lastTick, inputDelay − 1), plus maxDelay, plus 1.
Owns: relay/room.go (maxDelay, leadLimit, forward), relay/lead_test.go (new: LB-U1-U4), relay/stall_test.go and relay/queue_test.go (A0, A1, A2 only), protocol/conformance/conform.go (four default cases; `start_window_ends` under A4 only).
Invariant: N4, N5, N6; every existing Go test and conformance case green with only A1, A2, A4 edited; P2.2 behaviour unchanged.
Boundary: Lead bound rows of both same-tick tables.
Red: LB-U1-U4 and three of the four conformance cases fail on today's code (no rejection); `max_size_frames_inside_bound` is green before and after (it guards a bound that is too tight: red with the `+ 1` dropped).
Green: relay gates; CONFORMANCE PASSED 65; netplay match, rematch, left-mid, stall, spike.
Stop: an existing check red outside A1/A2/A4; A4 red for any reason the pong skip does not cure, or a fix that drops its pings, `left(1, 3)` or elapsed check; A1 or A2 flaky in 3 consecutive -race runs (report, do not widen).
```

- [ ] **Step 1 (Go unit tests, `relay/lead_test.go`, new):** two styles. Pure `forward`/`leave` cases (LB-U1-U3) drive the methods directly on one goroutine, no `run()`, so event order is exact and there is no race: a helper `testRoom(t, seats int) (*room, []*frames)` builds `&room{code: "TEST", cfg: testConfig(), reg: newRegistry(testConfig()), seats: map[int]*seat{}, stats: map[int]string{}, started: true}` with `cfg.seats = seats` (plus `hashes` and `peaks` after Task 2) and per seat a `&conn{sender: sender{write: f.write, shut: func() {}}}` with `f` a `frames` (`deadline_test.go:32-51`; its zero `dl` has `set == nil`, so `dl.every` in `forward` is a no-op; `reject`'s 200 ms close timer then only calls `shut`). Phase cases (LB-U4) need `over`, `park`, `rematch` and the expiry timer, so they use P2.2's `pair`, `firstTick`, `park`, `ended` helpers (`rematch_test.go:25-50`) and `r.post` from the test goroutine (one poster, so the room sees the posts in order), checked through `frames`. Cases:
  - **LB-U1 `TestLeadBoundFollowsOtherSeats`:** two seats; seat 1 frames 4..8 forwarded to seat 2; frame 9: seat 1's writes end with `{"type":"error","reason":"too far ahead"}`, seat 1 `dead`, nothing more forwarded. New room: seat 1 frames 4, 5 (limit 8); seat 2 frames 4..10 (limit `5 + 4 + 1` = 10); seat 1 frames 6..15 (limit `10 + 4 + 1` = 15) all forwarded, 16 rejected. (Seat 2 alone could not send 4..10 first: with seat 1 silent its limit is 8.) New room: seat 2 frames 4, 5, then `r.leave(seat2)`, then seat 1 frames 4..40 all forwarded (no other seat; seat 1's writes hold `left{2,5}` and no error). New room: seat 1 frames 4..8, frame 9 **before** `r.leave(seat2)`: rejected (seat 2's `lastTick` still counts as 3).
  - **LB-U2 `TestLeadBoundDeadAndSingleSeat`:** seat 2 frame 4, then a frame with seat field 1, so seat 2 is `dead` (still in `r.seats`); seat 1 frames 4..9 forwarded (`4 + 4 + 1`), 10 rejected. `testRoom(t, 1)`: frames 4..100 all forwarded to nobody and none rejected.
  - **LB-U3 `TestRejectedFrameCountsNothing`:** after a rejection the seat's `frames`, `bytes` (and, after Task 2, `maxFrame`, `peak`, `r.hashes`) equal their values before the rejected frame (read the struct fields; same goroutine).
  - **LB-U4 `TestLeadBoundAcrossOverAndRematch`** (P2.2 phases, `pair` with `testConfig()`): (a) both seats post tick 4, seat 1 posts ticks 5, 6 and `overMsg`; seat 2 posts ticks 5..11 (`6 + 4 + 1`): all forwarded to seat 1 (`fa.count`), then tick 12: seat 2 gets `too far ahead` (seat 1's frozen `lastTick` 6 counts after `over`). (b) new pair: `park(a, b)` (both at tick 4, both `over`), both post `againMsg`, wait for the second `start` on both (`fa.count("\"type\":\"start\"") == 2`); seat 1 posts ticks 4..8 of match 2: forwarded; tick 9: `too far ahead` (the bound restarts from `inputDelay − 1`, not from match 1's `lastTick`). Fails if `over` seats are skipped in `leadLimit` (a) or if `rematch` stops resetting `lastTick` (b: tick 4 refused as `invalid message`, which the test reads as a wrong reason).
  Run `cd <abs $W>/relay && go test -race -run 'LeadBound|RejectedFrame' ./...`: red (no rejection). Record.
- [ ] **Step 2 (conformance, `conform.go` `defaultCases`, appended at the end of the list):**
  - `lead_bound_start_edge`: `room(url, 2, "abc")`; seat 1 says ticks 4..8; seat 2 hears all five byte-exact; seat 1 says tick 9; `expect(cls[0], {"type":"error","reason":"too far ahead"})`, `expectClosed(cls[0])`, `expect(cls[1], left(1, 8))`.
  - `lead_bound_steady_edge`: seat 1 says ticks 4, 5; seat 2 **hears** both; seat 2 says 4..10 (its limit `5 + 4 + 1` = 10); seat 1 **hears** all seven (so the room processed them); seat 1 says 6..15 (limit `10 + 4 + 1` = 15); seat 2 hears all ten; seat 1 says 16; error, close, `left(1, 15)` to seat 2.
  - `racing_ticks_rejected`: seat 1 says ticks 4..200 without waiting; seat 1 gets the error then close (frames after the rejection are ignored, `s.dead`, `room.go:244-246`; the error is its last frame, sealed `reject`, C20); seat 2 hears exactly ticks 4..8, then `left(1, 8)`, then nothing for 300 ms.
  - `max_size_frames_inside_bound`: like `frame_cap_boundary` (`:277-283`) but five 65,536-byte frames ticks 4..8 from seat 1, all forwarded byte-exact; then seat 1 closes; seat 2 hears `left(1, 8)`.
  All four run in the start window (the default profile's lobby is 15 min), so no deadline fires during them. Then A4 (`start_window_ends`, silence profile). Build and run against today's relay (Task 0 Step 4's recipe, binary `relay-t1`, port 18200; `go run . -url ws://127.0.0.1:18200/ws -profile default`): `lead_bound_start_edge`, `lead_bound_steady_edge` and `racing_ticks_rejected` fail, `max_size_frames_inside_bound` and the 49 old ones pass; the silence profile (relay started as `PORT=18250 WARGRID_SILENCE_MS=300 WARGRID_HELLO_MS=300 WARGRID_LOBBY_MS=1500 <abs $L>/relay-t1`, suite with `-profile silence -silence 300ms -hello 300ms -lobby 1500ms`) passes 10 of 10 with A4 on today's relay. Record.
- [ ] **Step 3 (A0, A1, A2, A4, before any `room.go` change):** apply the Allowed test edits; A1, A2 and A4 as edited must pass on the base relay (they only add sends a seat is allowed to make); after Step 4 they pass again (relay gates `t1-base`, Go tests only).
- [ ] **Step 4 (`room.go`):** add next to `inputDelay`:

  ```go
  	// The highest delay a seat may use; the lead bound allows it. Adaptive input delay raises it.
  	maxDelay = inputDelay
  ```

  In `forward`, after the existing refusal (`:247-250`, which also refuses a tick after `over`; it must stay first, C4) and before the silence switch and stats update (`:251-254`):

  ```go
  	if t.tick > r.leadLimit(s) {
  		s.dead = true
  		slog.Info("lead bound", "code", r.code, "seat", s.n, "tick", t.tick)
  		s.c.reject("too far ahead")
  		return
  	}
  ```

  and the method:

  ```go
  // leadLimit is the last tick an honest seat can send: it sends T+1+delay only after running T, which needed
  // every other seat's frame for T, and those passed through this room first. The preloaded ticks below the
  // delay allow 2*delay before any peer frame, which is (delay-1)+delay+1.
  func (r *room) leadLimit(s *seat) int {
  	lowest := math.MaxInt
  	for _, o := range r.seats {
  		if o != s {
  			lowest = min(lowest, max(o.lastTick, inputDelay-1))
  		}
  	}
  	if lowest == math.MaxInt { // no other seat: nothing to stay behind
  		return lowest
  	}
  	return lowest + maxDelay + 1
  }
  ```

  (`math` import.) `over` seats stay in the loop on purpose (C2): their frozen `lastTick` bounds the others. `rematch()` needs no change: it already zeroes `lastTick` (`room.go:333`). The reason string is `too far ahead` (Q2, answered 2026-11-15; Q16 wording); `reject` seals the sender, so the error is the seat's last frame (C20). Then: LB-U1-U4 green; relay gates (`t1`) three times for `-race` stability; `CONFORMANCE PASSED 65`; netplay `match` (N1), `rematch` (N1, no `lead bound` line in its relay log), `left-mid` (no `lead bound` line), `stall`, `spike`. Static: `golangci-lint run` 0 issues.
- [ ] **Step 5:** verification file: red and green evidence, the three `-race` runs, scenario times.

---

### Task 2: Relay hash comparison and `MATCH END` byte fields

```text
Task: the room records hash values per hash tick, logs one DESYNC line with seat groups per room, and MATCH END gains max frame bytes, peak bytes per second per seat (room-wide, across rematches) and the desync tick and groups.
Owns: relay/envelope.go (hash fields), relay/envelope_test.go (parsed hash fields), relay/room.go (tickMsg hash field, seat stats, hashes and peaks maps, recordHash, hashGroups, leave, rematch: one clear), relay/main.go (the tickMsg literal in OnMessage, keyed), relay/deadline_test.go, relay/rematch_test.go, relay/shutdown_test.go (A5 only), relay/hash_test.go (new: HC-U1-U6, BF-U1, BF-U2), tools/run_netplay.sh (perturb, match, rematch and left-mid: one relay-log check each).
Invariant: forwarded bytes unchanged; N3, N4; the existing seatN="<f>f/<b>B" field keeps its format and `r.stats` stays `map[int]string` (TestRematchResetsTicksAndKeepsCounters reads it, `rematch_test.go:73-75`); a malformed hash still fails the envelope (conformance `bad_hash_value`, `hash_not_object`, `conform.go:208-211`).
Boundary: Hash comparison and Byte fields rows of both same-tick tables.
Red: HC-U1-U6, BF-U1, BF-U2 fail on Task 1's code.
Green: relay gates; CONFORMANCE PASSED 65; netplay perturb (with the new check), match, rematch, left-mid.
Stop: a forwarded byte changes; pending hash entries grow beyond 1 in HC-U4 or beyond `maxDelay + 1` (5) in HC-U6; a P2.2 test needs more than A5.
```

- [ ] **Step 1 (tests, `relay/hash_test.go`, new; `testRoom` from Task 1 for HC-U1-U4, HC-U6 and BF-U1, `pair`/`park` for HC-U5 and BF-U2; every two-seat case sends **interleaved, seat order per tick** (seat 1's tick T, then seat 2's tick T, unless the case says otherwise), since one seat alone stops at tick 8 under Task 1's bound; log captured with A0's `captureLogs(t)`; no test in this package calls `t.Parallel`, re-checked on `52017fd`):**
  - **HC-U1 `TestHashMismatchLogsGroups`:** two seats, interleaved ticks 4..34; tick 34 carries `"hash":{"tick":30,"value":…}`; equal values: no `DESYNC` line, `MATCH END` without `desync`. Second room: different values: exactly one line containing `msg=DESYNC` with `tick=30` and `groups="1|2"` (slog text quotes values containing `|`; match the `groups=` value with or without quotes), `MATCH END` with `desync=30` and `desync_groups`; then, interleaved on to 64, a second mismatch at hash tick 60 (frame 64): still one `DESYNC` line (Question 4: once per room). Third room: a mismatch at hash tick 0 (frame 4; honest clients hash tick 0, `lockstep.gd:59-61`): one `DESYNC` with `tick=0`, `MATCH END` with `desync=0`; a later mismatch at 30 logs nothing more (the sentinel is `desyncGroups == ""`, not `desyncTick == 0`).
  - **HC-U2 `TestHashGroupsNameOddSeat`:** `config{seats: 3}`; values a, b, a for seats 1, 2, 3: `groups="1,3|2"`.
  - **HC-U3 `TestHashOffOffsetIgnored`:** seat 1 frame tick 4 with hash tick 30 value `a` (as `forwards_byte_for_byte` sends): forwarded byte-exact; no entry recorded. Interleaved on to 34; seat 1's tick 34 has no hash, then seat 2's tick 34 carries hash 30 value `b`: no `DESYNC` (if the offset filter were missing, `b` would complete seat 1's stale `a`).
  - **HC-U4 `TestHashEntriesBounded`:** for 300 ticks seat 1 stays at the full lead (its frame `T + 4` goes in before seat 2's frame `T`: seat 2's `lastTick` is then `T − 1`, so seat 1's limit is `T + 4`), both hashing every 30 at the honest offset: after every call `len(r.hashes) <= 1` (the lead is far below the 30 ticks between hashes). Then seat 2 leaves with an entry pending: `len(r.hashes) == 0` after the leave, no `DESYNC`.
  - **HC-U6 `TestHashFloodBounded`:** same full-lead order for 300 ticks; seat 1 puts an honest-offset hash (`tick − 4`, value `a`) on **every** frame, seat 2 hashes every 30 with `a`, except hash tick 150 with `b`. After every call `len(r.hashes) <= maxDelay + 1` (5); exactly one `DESYNC` line, `tick=150`, `groups="1|2"`. Fails if `pruneHashes` is removed (the map grows by one entry per frame, about 290) and if `recordHash` is a no-op (no `DESYNC`).
  - **BF-U1 `TestMatchEndByteFields`:** seat 1 sends frames of 100, 2000 and 65,536 bytes within one second, sleeps 1.1 s, sends one 100-byte frame; `MATCH END` has `seat1_max_frame=65536`, `seat1_peak_bps=` the sum of the first three sizes, and the old `seat1="4f/<sum>B"` unchanged. A rejected seat's fields are still present (counts before its rejection).
  - **HC-U5 `TestHashesClearedAtRematch`** (`pair`): match 1: interleaved ticks 4..33; seat 1 posts tick 34 with hash 30 value `a`; seat 2 stays at 33 (so `{1: a}` stays pending: seat 2 never sent frame 34, so the prune keeps it); both post `overMsg`, then `againMsg`; wait for the second `start` on both. Match 2: interleaved 4..33; at tick 34 **seat 2 posts first** with hash 30 value `b`, then seat 1 with `b`; check through `frames` that both frames 34 were forwarded and no `error` frame arrived; close both, `ended`: no `DESYNC` line. Fails if `rematch()` does not clear `r.hashes`: seat 2's `b` completes the stale `{1: a}` and logs a false `DESYNC`.
  - **BF-U2 `TestByteFieldsAcrossRematch`** (`pair`): match 1: seat 1 posts tick 4 (100 bytes) and tick 5 (2000 bytes), seat 2 tick 4; both `overMsg`, both `againMsg`, second `start`; match 2: seat 1 posts tick 4 (500 bytes); close both, `ended`: one `MATCH END` line with `seat1="3f/2600B"` (P2.2's counters add up) and `seat1_max_frame=2000` (room-wide maximum).
  - `envelope_test.go` `TestParseRules` neighbour (`:35-74`): `parseEnvelope` of a tick with a hash returns `hash == hashMsg{tick: 1, value: "3a0ad3856b168044", ok: true}`; without hash `hash.ok == false`.
  Red on Task 1's code (compile failure counts as red for the new fields; record it).
- [ ] **Step 2 (`envelope.go`, `room.go` `tickMsg`, A5):** `validHash` (`envelope.go:45-57`) becomes `parseHash`, which returns the parsed values:

  ```go
  type hashMsg struct {
  	tick  int
  	value string
  	ok    bool // present and valid
  }

  // parseHash: valid is false only for a hash with the wrong shape; no hash is valid and zero.
  func parseHash(o map[string]any) (h hashMsg, valid bool) {
  	raw, present := o["hash"]
  	if !present {
  		return hashMsg{}, true
  	}
  	m, isMap := raw.(map[string]any)
  	if !isMap {
  		return hashMsg{}, false
  	}
  	tick, tickOK := asInt(m["tick"])
  	value, strOK := asString(m["value"])
  	valid = tickOK && strOK && hashRe.MatchString(value)
  	return hashMsg{tick, value, valid}, valid
  }
  ```

  `envelope` (`envelope.go:18-29`) gains `hash hashMsg`. In the tick case (`envelope.go:97-103`) replace exactly lines `:101-102`:

  ```go
  		if ok1 && ok2 && ok3 && validHash(o) {
  			return &envelope{typ: typ, seat: s, tick: t}
  ```

  with

  ```go
  		if h, ok4 := parseHash(o); ok1 && ok2 && ok3 && ok4 {
  			return &envelope{typ: typ, seat: s, tick: t, hash: h}
  ```

  so a missing hash stays valid with a zero `hashMsg`, and a malformed one still returns `nil` (`invalid message`). `validHash` (`:45-57`) is deleted (no other caller; lint `unused` would flag it). The `over`/`again` case (`:104-105`) and the `ping` case (`:106-111`) stay as they are. `tickMsg` (`room.go:56-61`) gains `hash hashMsg` as its last field; `OnMessage` (`main.go:173`) becomes `c.room.post(tickMsg{s: c.seat, seat: e.seat, tick: e.tick, data: bytes.Clone(msg.Bytes()), hash: e.hash})`; apply A5 to the three positional test literals.
- [ ] **Step 3 (`room.go`):** `seat` (`:33-43`) gains `maxFrame, peak, winBytes int` and `winStart time.Time`. `room` (`:70-88`) gains `hashes map[int]map[int]string` (made in `create`, `:443-447`), `peaks map[int][2]int` (made in `create`), `desyncTick int`, `desyncGroups string`; `stats map[int]string` stays as it is (C8). In `forward`, after the existing stats line (`:254`, so `s.lastTick` is this frame's tick) and before the forwarding loop (`:255`):

  ```go
  	now := time.Now()
  	if now.Sub(s.winStart) >= time.Second {
  		s.winStart, s.winBytes = now, 0
  	}
  	s.winBytes += len(t.data)
  	s.peak, s.maxFrame = max(s.peak, s.winBytes), max(s.maxFrame, len(t.data))
  	r.recordHash(s, t)
  ```

  ```go
  // recordHash compares a hash once every seat sent it. Honest clients hash tick T in the frame for T+delay
  // (lockstep.finish_tick); other offsets are forwarded but not recorded.
  func (r *room) recordHash(s *seat, t tickMsg) {
  	h := t.hash
  	if !h.ok || h.tick != t.tick-inputDelay {
  		return
  	}
  	m := r.hashes[h.tick]
  	if m == nil {
  		m = map[int]string{}
  		r.hashes[h.tick] = m
  	}
  	m[s.n] = h.value
  	if len(m) == len(r.seats) {
  		delete(r.hashes, h.tick)
  		if g := hashGroups(m); strings.Contains(g, "|") && r.desyncGroups == "" { // hash tick 0 is real
  			r.desyncTick, r.desyncGroups = h.tick, g
  			slog.Warn("DESYNC", "code", r.code, "tick", h.tick, "groups", g)
  		}
  	}
  	r.pruneHashes()
  }

  // pruneHashes drops comparisons that can no longer complete: once every seat sent the frame for h+delay, a
  // missing value never comes. With the lead bound at most maxDelay+1 entries stay open, whatever clients send.
  func (r *room) pruneHashes() {
  	low := math.MaxInt
  	for _, o := range r.seats {
  		low = min(low, o.lastTick)
  	}
  	for h := range r.hashes {
  		if h+inputDelay <= low {
  			delete(r.hashes, h)
  		}
  	}
  }

  // hashGroups lists seats with equal values, groups ordered by their lowest seat: "1,3|2".
  func hashGroups(m map[int]string) string {
  	seats := slices.Sorted(maps.Keys(m))
  	placed := map[int]bool{}
  	var groups []string
  	for _, n := range seats {
  		if placed[n] {
  			continue
  		}
  		var g []string
  		for _, o := range seats {
  			if m[o] == m[n] {
  				placed[o] = true
  				g = append(g, fmt.Sprint(o))
  			}
  		}
  		groups = append(groups, strings.Join(g, ","))
  	}
  	return strings.Join(groups, "|")
  }
  ```

  (`fmt`, `maps`, `slices`, `strings` are already imported by `room.go`, `:3-15`; `math` comes with Task 1. The bound: an open entry `h` needs a seat that has not yet sent frame `h + 4`, so `h + 4 > low`; every seat is at most `max(low, 3) + maxDelay + 1` by the lead bound, and `h + 4 >= 4` since frames start at tick 4, so `h + 4` takes at most 5 values: at most 5 keys. Dead and `over` seats keep their frozen `lastTick` in `r.seats`, as in `leadLimit`, so the bound holds for them too. The relay never learns the client's hash interval.) In `leave` (`:341-358`): `clear(r.hashes)` (a pending comparison cannot complete with the old seat count; losing one comparison at a leave is accepted), and next to the unchanged `r.stats[s.n]` line (`:347`) `r.peaks[s.n] = [2]int{s.maxFrame, s.peak}`; the `MATCH END` args (`:352-355`) append, per seat in seat order after `seatN`, `seatN_max_frame` and `seatN_peak_bps` from `r.peaks`, then `desync`, `desync_groups` when `desyncGroups != ""`. In `rematch` (`:331-338`): one `clear(r.hashes)` before `r.start()` (C5); `desyncTick` and the byte fields are not reset (room-wide, Questions 4 and 5). Peak per Question 6: tumbling one-second windows (a burst split across a window edge reads up to half low; acceptable for calibration).
- [ ] **Step 4 (`run_netplay.sh`):** `perturb` (`:149-172`), after the report checks: `grep -q 'msg=DESYNC .*tick=60' "$out/relay.log" || fail "relay logged no DESYNC at tick 60"` (both seats send hash 60 in their frame for tick 64 before either client can stop). `match` (`:86-93`), `rematch` (`:94-118`, after its `MATCH END` wait, `:111-115`) and `left-mid` (`:124-129`, after its `VICTORY` check): `! grep -q 'msg=DESYNC' "$out/relay.log" || fail "relay logged a DESYNC in a clean match"` (a smoke check that clean matches log no `DESYNC`; it cannot catch a missing clear, since a clean match leaves no stale entry: the clears are guarded by HC-U5 (rematch) and HC-U4 (leave), C5, C24). Run netplay `perturb`, `match`, `rematch`, `left-mid`. `sh tools/run_shell_checks.sh`.
- [ ] **Step 5:** relay gates (`t2`); conformance 65. Record.

---

### Task 3: Conformance pacing, per-IP and global limits

```text
Task: the conformance suite paces its dials; a limiter caps sockets and hellos per client address (from the header named by WARGRID_CLIENT_IP_HEADER), plus a fixed global join bucket, a bounded table that refuses when full, and a global bucket for unknown-match replies.
Owns: relay/limits.go (new), relay/limits_test.go (new: LM-U1-U6), relay/main.go (relay struct, OnOpen, OnClose, OnMessage hello path, newServer Authorize, main: env and start log), protocol/conformance/client.go (dial pacing, dialFrom), protocol/conformance/conform.go (limitsCases, globalCases, runConform map), protocol/conformance/main.go (profile flag help and package comment), tools/run_conformance.sh (two profiles).
Invariant: N4; default, delay and silence profiles unchanged and green with the variable unset; no IP in any log line; every existing Go test unchanged (no `relay{…}` literal edited); the hello deadline, lobby expiry and rematch untouched.
Boundary: Per-IP limits rows of both same-tick tables.
Red: LM-U1-U6 and the limits and global profiles fail on Task 2's code.
Green: relay gates; CONFORMANCE PASSED 65 after Step 1 (paced, no limiter), CONFORMANCE PASSED 69 after Step 7; default profile relay log zero `WARN limit rule=` lines; netplay match, rematch, version, relay-term.
Stop: the default profile trips a limit (zero `WARN limit rule=` lines required in its relay log; `run_conformance.sh` asserts it for the default, delay and silence profiles since 2026-11-17); any log line with an address; pacing turns an existing case red. Never raise the global burst (20, Q12) or add a relay variable to make a suite pass: report the hello timeline instead.
```

Answered values (user, 2026-11-15; written into `limits.go` and mirrored as conformance constants): Q10 `maxConnsPerIP = 16`; Q11 `joinBurst = 10`, `joinPeriod = time.Second`; Q12 `globalBurst = 20`, `globalPeriod = 50 * time.Millisecond` (20 per second), fixed in production; Q13 `unknownBurst = 10`, `unknownPeriod = time.Second`; Q14 `tableSize = 4096`; Q16 reasons `too many connections`, `too many joins`, `relay busy`; Q26 a missing or unparsable header skips per-IP rules (key `""`); Q27 `fly.toml` untouched; Q32 (user, 2026-11-16) the suite paces its dials, no test-only relay setting.

- [ ] **Step 1 (conformance pacing, Question 32, before the limiter exists):** the production global bucket is fixed (burst 20, refill one per 50 ms, Q12), so the suite paces itself instead of the relay loosening for it. `client.go`: `dial(url)` waits until 50 ms after the previous `dial` started, then dials (so the hellos sent by any time are at most the dials started by then, at most `1 + elapsed / 50 ms`, which the bucket's `20 + elapsed / 50 ms` always covers, whatever the hello timing inside a case). Deadline cases measure from after `dial` returns (`hello_deadline`, `conform.go:542-550`), so the wait never lands inside a measured window:

  ```go
  // helloGap matches the relay's global join refill (one per 50 ms), so the suite never drains that bucket.
  const helloGap = 50 * time.Millisecond

  var (
  	paceMu   sync.Mutex
  	lastDial time.Time
  )

  func dial(url string) (*client, error) {
  	paceMu.Lock()
  	time.Sleep(time.Until(lastDial.Add(helloGap)))
  	lastDial = time.Now()
  	paceMu.Unlock()
  	return dialFrom(url, "")
  }
  ```

  (`sync` joins `client.go`'s imports.) Today's `dial` body becomes `dialFrom(url, addr string)` (Step 6 adds the header; `dialFrom` never paces, so the bucket cases of Step 6 can burst). Run `sh tools/run_conformance.sh` on Task 2's tree: `CONFORMANCE PASSED 65`, every case text unchanged (N4). Then repeat Task 0 Step 4 (binary `relay-t3`, port 18400) on this tree: record hellos reaching `join`, wall seconds, the busiest second (at most 20 by construction) and the default profile's added wall time against Task 0's (expected under about 5 s). This count is a check; it sets no constant.
- [ ] **Step 2 (unit tests, `relay/limits_test.go`, new; fake clock `now func() time.Time` injected):**
  - **LM-U1 `TestBucketLeaksOnePerPeriod`:** burst 10, period 1 s: 10 allowed, 11th refused; after 1 s one more allowed; after 10 s ten more (ioq3 `SVC_RateLimit`, `sv_main.c:486-509`).
  - **LM-U2 `TestConnCountOpenClose`:** `open(key)` `maxConnsPerIP` times accepted, the next refused with `too many connections` but still counted; that many plus one `close(key)` calls bring the count to 0; one more `close` does not go negative (never called in production; guard). `open("")` returns `("", false)` 100 times (no per-IP key: never refused, never tracked). A nil `*limiter` returns `("", false)` from `open`, `""` from `join` and `true` from `unknown` (tests that build `&relay{…}` without one).
  - **LM-U3 `TestTableFullFailsClosed`:** table size 4 (constructor argument): 4 keys with open sockets fill it; a 5th key refused `relay busy` and `tracked == false`; after one key closes and its bucket drains (`burst × period` later), a 5th key is admitted (idle entry reclaimed, ioq3 `sv_main.c:436-450`).
  - **LM-U4 `TestClientKey`:** variable unset: key `""`; set: `203.0.113.7` → `203.0.113.7`; `2001:db8:1:2:3:4:5:6` and `2001:db8:1:2:ffff::1` → same key (/64, Question 9); header missing or `not-an-ip` → `""` (Q26 answered: skip per-IP rules).
  - **LM-U5 `TestUnknownAndGlobalBuckets`:** unknown-match bucket burst 10, 1 s: 11th `unknown()` false; global join bucket with the production constants (`globalBurst` 20, `globalPeriod` 50 ms): the 21st `join` in the same instant refused `relay busy` for any key, including `""`; 50 ms later one more allowed.
  - **LM-U6 `TestLimitsAcrossP2Phases`** (P2.2): `h := &relay{reg: newRegistry(cfg), lim: <limiter with global burst 2, period 1 h>, ipHeader: "X-Wargrid-Test-Ip"}` over `httptest.NewServer(newServer(h).Handler)`; clients dial with `gws.ClientOption{RequestHeader: http.Header{"X-Wargrid-Test-Ip": {"203.0.113.9"}}}`. (a) Two clients create and join (2 tokens used); both send tick 4, `over`, `again`; both hear the second `start` (no hello drawn); a third hello hears `relay busy`. Fails if `over`/`again`/rematch drew a token. (b) Fresh relay with `cfg.lobby` 50 ms and a roomy global bucket: one client creates a room and hears `lobby expired` then close; `eventually` the limiter's count for `203.0.113.9` is 0 (read under `l.mu`). Fails if the expiry close skipped `OnClose`'s decrement.
  Red (no `limits.go`). Record.
- [ ] **Step 3 (`relay/limits.go`):** one type, one mutex:

  ```go
  // limiter guards connection slots and joins per client address (ioq3 sv_main.c:363-561): a bounded table
  // that refuses when full, so a flood of addresses cannot grow memory; global buckets back up spoofed addresses.
  type limiter struct {
  	mu       sync.Mutex
  	now      func() time.Time
  	size     int
  	entries  map[string]*ipEntry
  	global   bucket
  	unknownB bucket
  	refused  map[string]int // per rule, for the log line
  }

  type ipEntry struct {
  	conns int
  	joins bucket
  }

  type bucket struct {
  	used int
  	last time.Time
  }
  ```

  Constructor `newLimiter(size, globalBurst int, globalPeriod time.Duration, unknownBurst int, unknownPeriod time.Duration, now func() time.Time) *limiter` (tests pass small tables, LM-U3, and odd buckets, LM-U6; `main` passes the constants and `time.Now`); the per-IP join bucket uses `joinBurst`/`joinPeriod`, so the struct also keeps the global and unknown burst and period beside its buckets. Methods: `open(key string) (reason string, tracked bool)`, `close(key string, tracked bool)`, `join(key string) string` (per-IP then global; key `""` skips the per-IP part), `unknown() bool`, `allow(b *bucket, burst int, period time.Duration) bool` (leak `elapsed / period` units, keep the remainder, as ioq3), `idle(e *ipEntry) bool` (no socket and bucket fully leaked), and a `refuse(rule string)` that logs `slog.Warn("limit", "rule", rule, "refused", n)` for n == 1 and every 100th (no key in the log). Every method starts `if l == nil { return <allow> }`, and `open`/`close` return at once for key `""` (no per-IP key: the variable is unset, the test server has no `Authorize`, or Q26 "skip"). Constants, each with its Question: `maxConnsPerIP = 16 // Q10`, `joinBurst = 10 // Q11`, `joinPeriod = time.Second // Q11`, `globalBurst = 20 // Q12, fixed: tests pace, never raise it`, `globalPeriod = 50 * time.Millisecond // Q12, 20 per s`, `unknownBurst = 10 // Q13`, `unknownPeriod = time.Second // Q13`, `tableSize = 4096 // Q14` (the `// Qn` notes are for this plan only; the code keeps one why-comment for the block). `clientKey(r *http.Request, header string) string` per LM-U4 (`""` when `header == ""`; `net.ParseIP`, IPv4 as `To4().String()`, IPv6 masked with `net.CIDRMask(64, 128)`; missing or unparsable: `""`, Q26).
- [ ] **Step 4 (`main.go`):** `relay` (`:83-85`, today `{reg *registry}`) gains `lim *limiter` and `ipHeader string`. `newServer`'s `gws.ServerOption` (`:226`) gains `Authorize: func(r *http.Request, s gws.SessionStorage) bool { s.Store("ip", clientKey(r, h.ipHeader)); return true }` (the session is the one `OnOpen` receives, `upgrader.go:191-192`). Tests that build their own upgrader (`stall_test.go:36-41`, `batch_test.go:52-57`) have no `Authorize`; gws still makes an empty session (`upgrader.go:191`, default hook `option.go:271-272`) and calls `OnOpen` (`conn.go:111`), so the key is read comma-ok. `conn` (`:65-72`) gains `ip string`, `tracked bool`. `OnOpen` before (`main.go:122-130`, P2.2's hello deadline):

  ```go
  func (h *relay) OnOpen(s *gws.Conn) {
  	c := &conn{sender: sender{
  		write: func(f []byte) { h.writeLater(s, len(f), func() error { return s.WriteMessage(gws.OpcodeText, f) }) },
  		shut:  func() { h.writeLater(s, 0, func() error { return s.WriteClose(1000, nil) }) },
  	}, dl: deadline{set: func(t time.Time) { _ = s.SetReadDeadline(t) }}}
  	c.dl.hold(time.Now().Add(h.reg.cfg.hello))
  	s.Session().Store("c", c)
  	slog.Info("connection opened")
  }
  ```

  after:

  ```go
  func (h *relay) OnOpen(s *gws.Conn) {
  	v, _ := s.Session().Load("ip")
  	ip, _ := v.(string) // no Authorize hook (test servers): "", no per-IP rules
  	c := &conn{ip: ip, sender: sender{
  		write: func(f []byte) { h.writeLater(s, len(f), func() error { return s.WriteMessage(gws.OpcodeText, f) }) },
  		shut:  func() { h.writeLater(s, 0, func() error { return s.WriteClose(1000, nil) }) },
  	}, dl: deadline{set: func(t time.Time) { _ = s.SetReadDeadline(t) }}}
  	c.dl.hold(time.Now().Add(h.reg.cfg.hello))
  	s.Session().Store("c", c)
  	slog.Info("connection opened")
  	var reason string
  	reason, c.tracked = h.lim.open(ip)
  	if reason != "" {
  		c.reject(reason)
  	}
  }
  ```

  (`reject` needs `"c"` in the session, since `writeLater` reads it through `getConn`, so the refusal comes after the `Store`; since `29724db` it seals the sender, so the error is the socket's last frame, C20. The refused socket is closed after the 200 ms `closeGrace`, well before the 5 s hello deadline; its close decrements only when tracked.) Fails if reverted to a plain `v.(string)`: `TestStalledPeerStillProducesLeft` and `TestBatchJoinsTicks` panic. `OnClose` (`:132-137`): `h.lim.close(c.ip, c.tracked)` first, for seated and unseated sockets alike (the hello deadline, `lobby expired`, `room expired` and a refusal all end there). `OnMessage` `case "hello":` (`:163-171`) first `if reason := h.lim.join(c.ip); reason != "" { slog.Info("join rejected", "reason", reason); c.reject(reason); return }`; after `h.reg.join` (`:164`), if `res.reason == "unknown match" && !h.lim.unknown()`: `c.rejected.Store(true); c.close(); return` (no reply, ioq3 `sv_main.c:727-733`; not a `reject`, so no seal is needed: no room holds this socket and `rejected` stops its own reader's pongs, `main.go:148`, C21; a valid code never draws from this bucket, as a correct rcon password bypasses ioq3's, `:737-738`). `over` and `again` (`:174-177`) never touch the limiter (LM-U6). `main` (`:183-208`): `ipHeader := os.Getenv("WARGRID_CLIENT_IP_HEADER")`; the `relay started` log line (`:203`) gains `"per_ip", ipHeader != ""` (the header name is config, not personal; still log only the boolean); `&relay{reg: reg}` (`:204`) gains `lim` and `ipHeader`. Tests that build `&relay{…}` directly (`stall_test.go:35`, `queue_test.go:34`, `batch_test.go:51`) leave `lim` nil; the nil-safe methods of Step 3 mean no existing test changes.
- [ ] **Step 5 (`fly.toml`): skipped.** Question 27 is answered "not in this branch" (user, 2026-11-15): `relay/fly.toml` stays unchanged (`:1-26`, no `[env]`); `WARGRID_CLIENT_IP_HEADER = "Fly-Client-IP"` lands with the approved deploy that runs Question 22's check (17 sockets, each with its own forged `Fly-Client-IP`, must hit the cap of 16), so a header problem cannot cap the public relay before the check. fly docs (docs.fly.io/networking/request-headers, read 2026-11-15): Fly-Client-IP is "The IP address of the client from the perspective of Fly Proxy"; the page does not say whether a client-sent value is overwritten. No deploy.
- [ ] **Step 6 (conformance):** `client.go`: `dialFrom(url, addr string)` (Step 1) passes `&websocket.DialOptions{HTTPHeader: http.Header{"X-Wargrid-Test-Ip": {addr}}}` when `addr != ""`, else `nil` as today; it never paces. The limits and global cases dial only through `dialFrom`, so their bursts are real. `conform.go`: `limitsCases()`, each case starting with `time.Sleep(time.Second)` (the profile's global bucket, burst 20, refills fully between cases; `limits_unknown_match` alone draws 13 tokens):
  - `limits_conn_cap` (Q10 cap 16; `maxConnsPerIP = 16` mirrored in `conform.go`): 16 `dialFrom(url, "203.0.113.1")` sockets stay open (no hello); the next hears `{"type":"error","reason":"too many connections"}` then close; `dialFrom(url, "203.0.113.2")` + `hello` gets a welcome; close one of the open sockets, then retry from `.1` sequentially for up to 1 s: dial, hello; on `too many connections` wait for its `expectClosed`, sleep 100 ms, try again; pass on the first welcome, fail if none within 1 s. The retry is needed because `expectClosed` (`conform.go:41-44`) returns when the client sees the close, before the relay's `OnClose` (`main.go:132-137`) decrements the count; each refused attempt counts until its own close, hence one attempt at a time. The held sockets send no hello, so the relay's 5 s hello deadline (`main.go:127`, profile default) closes them: `check` that the retry's welcome came within 3 s of the first dial (well under 1 s locally; a slow host fails here with a clear message, not in the count below). A last check after the retry: sleep until 5.5 s after the **last** held socket opened, then dial from `.1` until the first `too many connections`, each probe with a 150 ms quiet timeout instead of the default wait (15 probes, about 2.3 s, stay well inside the probes' own 5 s hello deadline): exactly 15 open (the hello deadline freed the 15 held slots; the welcomed lobby socket from the retry still holds the 16th, C10).
  - `limits_join_rate`: 10 times: dial from `203.0.113.3`, create a room (`hello("", "abc", 2)`), hear welcome, close; the 11th hello hears `{"type":"error","reason":"too many joins"}` and close; from `203.0.113.4` a hello is welcomed.
  - `limits_unknown_match`: from `203.0.113.10` .. `.19` (one each, back to back) `hello("ZZZZZZ", …)` hears `unknown match` (do not wait for each close: ten 200 ms `closeGrace` waits would let the 1-per-s bucket refill and `.20` would get a reply); from `.20` the same hello: `expectClosed` (no reply); a room created from `.21` is joined by a code hello from `.22` (welcome, start).
  `globalCases()`: `limits_global_join`: from addresses `203.0.113.100+i`, hellos back to back until the first `relay busy`; it comes after at least `globalBurst` and at most `globalBurst + 20` hellos (refill during the loop; `globalBurst = 20` mirrored in `conform.go` from `limits.go`, Q12), then a hello 200 ms later is welcomed (refill). `runConform` map (`conform.go:687`) gains `"limits"` and `"global"`; `main.go` (`:1-3` comment, `:13` flag help `default|silence|delay`) lists them. `run_conformance.sh:15` loop, after `silence:…`, gains `limits:WARGRID_CLIENT_IP_HEADER=X-Wargrid-Test-Ip global:WARGRID_CLIENT_IP_HEADER=X-Wargrid-Test-Ip` (each a fresh relay with the default 5 s hello and 15 min lobby; the `-silence 300ms -hello 300ms -lobby 1500ms` flags the loop passes to every profile, `:26`, are read only by silence cases, C14). Run the new profiles against Task 2's relay: red. Record.
- [ ] **Step 7:** relay gates (`t3`); `sh tools/run_conformance.sh`: `CONFORMANCE PASSED 69` (65 + 3 limits + 1 global); default profile relay log (run by hand with Task 0 Step 4's recipe, binary `relay-t3` rebuilt from this tree, port 18450) has zero `WARN limit rule=` lines (the pacing works against the real limiter; the relay's line is `WARN limit rule=<rule> refused=<n>`, no `msg=` key, corrected 2026-11-17); `rg -n '203\.0\.113|2001:db8' <the hand-run relay logs of Steps 1 and 7>` prints nothing (no address logged; `run_conformance.sh` deletes its own logs on a pass, so also run the `limits` profile by hand once: `PORT=18460 WARGRID_CLIENT_IP_HEADER=X-Wargrid-Test-Ip <abs $L>/relay-t3`, suite `-profile limits`, and check its log). `sh tools/run_shell_checks.sh`. Netplay `match`, `rematch`, `version`, `relay-term`.

---

### Task 4: Client guards

```text
Task: a refused WebSocket send closes the transport; Lockstep refuses an order that would push the pending frame past the 64 KiB frame cap and checks its own frame; the online driver shows the refusal; the headless client ends after 5 s without a frame, like the online driver.
Owns: game/scripts/net/relay_transport.gd (poll's ping, send_text, _check_sent, _refused, closed), game/scripts/net/lockstep.gd (FRAME_RESERVE_BYTES, _queue_bytes, submit, finish_tick), game/scripts/net/seat_sim.gd (issue_command), game/scripts/match/online_driver.gd (submit, TOO_MANY_ORDERS; the refusal goes into `_answers`), game/scripts/net/headless_client.gd (_run_steps), game/tests/test_relay_transport.gd (T7), game/tests/test_lockstep.gd (L19, L20), game/tests/test_online_scene.gd (N-cap, new case).
Invariant: N1, N2; frames byte-identical for every accepted order; match_screen.gd untouched (since SB3 `_submit`, `match_screen.gd:310-315`, ignores `submit`'s result; refusals reach the HUD only through `_take_answers`, `:149-156`, C25); `patient`, the `over`/`again` sends, the phases, `step`, `_new_answers` and the SimPump use of online_driver.gd untouched; no new live read (`tools/test_sim_boundary.py`).
Boundary: Client rows of both same-tick tables.
Red: T7, L19, L20, N-cap fail on Task 3's tree.
Green: WARGRID_TEST_ONLY=test_lockstep, =test_relay_transport, =test_online_scene; SUITE(t4) with traces cmp-identical to *-before.tsv; static checks; netplay match, rematch, left-mid, stall, kill, silent.
Stop: the lockstep benchmark newly exceeds its budget; any netplay scenario ends `ended_relay` before its first tick (the headless 5 s rule fired during the map load, `headless_client.gd:59-63`, `:125`; report the load time, do not add `patient`); `Lockstep.submit` or `finish_tick` no longer exist by symbol, or encode the frame elsewhere (SB4 drift, C26: park, Opus diagnosis); a trace or N1 change; any frame of the match scenario differs (compare s1.cmd against Task 0's); T7 cannot fill the socket within its bound locally (report; do not raise the bound past 2000 frames or drop the real socket).
```

- [ ] **Step 1 (tests):**
  - **T7 `test_refused_send_closes`** in `test_relay_transport.gd` (append to `cases()`, `:7-8`), against a real loopback socket whose reader stops: `var server := TCPServer.new()`; `runner.check(server.listen(0, "127.0.0.1") == OK, "T7 test server listens")`; `var now := [0]`; `var transport = RelayTransport.new(func() -> int: return now[0])`; `transport.connect_to("ws://127.0.0.1:%d/ws" % server.get_local_port())`; handshake loop, at most 400 rounds with `OS.delay_msec(5)`: `transport.poll()`; when `server.is_connection_available()`, `peer.accept_stream(server.take_connection())` on a `WebSocketPeer.new()`; `peer.poll()`; until `transport.is_open()` (`runner.check(transport.is_open(), "T7 handshake")`). From here `peer` is never polled again, so nothing reads the server side. First half: `var big := "x".repeat(60000)`; at most 2000 times: `transport.send_text(big)`, stop when `transport.closed()`; `runner.check(transport.closed(), "T7 a refused send marks the transport closed, so the match ends as relay lost")`. Second half, a fresh pair the same way: fill with raw sends that bypass `send_text` (`transport._peer.send_text(big)` until it returns non-`OK`, at most 2000; then `transport._peer.send_text(ping)` until non-`OK`, at most 10000, where `ping := Wire.encode({"type": "ping", "t": 2_000_000})`), check `not transport.closed()`, then `transport._sent_any = true`, `transport._last_ping = 0`, `now[0] = 2_000_000`, `transport.poll()`: `runner.check(transport.closed(), "T7 a refused ping closes the transport too")`. Around both fill loops and the refused ping set `Engine.print_error_messages = false` and restore `true` right after: Godot reports a refused send with an engine `ERROR:` line (`wsl_peer.cpp` `ERR_FAIL_COND_V`, not re-read for 4.7.2), and `tools/run_tests.sh:41` fails the whole suite on any `ERROR:` line. Clean up: `transport.close()`, `peer.close()`, `server.stop()`. Fails if: the `_check_sent(...)` call in `send_text` is removed (first half: `closed()` never turns true), or `poll` sends the ping with `_peer.send_text` again (second half). If `listen(0, …)` is refused on this Godot build, stop and report (no fixed port).
  - **L19 `test_pending_frame_cap`** in `test_lockstep.gd`: `Lockstep.new(1, [1, 2])`, `start(sim.snapshot())`; submit `{"type":"move","entity_ids":[1..300],"target":[10.5,10.5]}` until `submit` returns false (bounded loop of 200); then `finish_tick(1, null)` and check the sent text (capture `send`) is ≤ `Wire.MAX_FRAME_BYTES` bytes and `Wire.decode` succeeds (`"L19 a full pending frame still fits the 64 KiB cap"`); the refused order consumed no sequence (the next accepted command's sequence equals the count of accepted ones); after the send `submit` accepts again (`"L19 the queue accepts again after the frame is sent"`); boundary: one more accepted order would have passed `MAX_FRAME_BYTES − FRAME_RESERVE_BYTES` (compute from the encoded sizes).
  - **L20 `test_own_frame_checked`**: push an oversized command directly into `ls._queue` (allowlisted file) and call `finish_tick`: status `ended_protocol`, reason begins `own frame`, nothing sent.
  - **N-cap `test_too_many_orders_note`** in `test_online_scene.gd` (append to `cases()`, `:48-49`): `var online: Dictionary = await _online(runner, 1)` (FakeTransport, no relay, `:51-61`); `_run(online.main, 1)` (`:68-69`; creates the sound player the HUD path uses); `var order := {"type": "move", "entity_ids": range(1, 301), "target": [10.5, 10.5]}`; 200 times `online.main._submit(order)` (the HUD path, `match_screen.gd:310-315`; the cap is reached after about 40); then `_run(online.main, 1)` so `_take_answers` (`:149-156`) runs, as `test_rejection_line` (`:722-730`) does; `runner.check(online.main.get_node("HUD/Status").text.contains("Rejected: " + online.main.driver.TOO_MANY_ORDERS), "N-cap the HUD shows the refused order, got " + online.main.get_node("HUD/Status").text)` (Question 33 A, user 2026-11-16); `_layout_ok(runner, online.main, "too many orders")` (the HUD layout check `test_rejection_line` runs, `:728`; the line is longer than "Rejected: No units left"); `online.main.free()`. Seat 1 gets no peer packets, so no tick is sent and the queue only grows. Fails if `online_driver.submit` stops queuing the refusal as an answer (the HUD never hears of it, C25) or if `Lockstep.submit` never refuses.
  Run with `WARGRID_TEST_ONLY`: red. Record. After green, `rg -n 'ERROR:' <abs $L>/<the WARGRID_TEST_ONLY=test_relay_transport log>` must print nothing before the full suite runs (else T7's error silencing is missing).
- [ ] **Step 2 (`relay_transport.gd`):**

  In `poll`, line `:36` (the send; `:35` is `var ping: String = take_ping(...)`): `if ping != "": _peer.send_text(ping)` becomes `if ping != "": send_text(ping)` (same effect on an accepted ping: `take_ping`, `:64-67`, already requires `is_open()` and `_sent_any`). `send_text` is `:39-43`, `closed` `:48-49`; `over` and `again` already go through `send_text` (`online_driver.gd:210`, `:235`; `headless_client.gd:169-170`), so they get the check with no change there.

  ```gdscript
  var _refused: bool = false

  func send_text(text: String) -> void:
  	if not is_open(): return
  	if not _sent_any: _last_rx = _clock.call()
  	_sent_any = true
  	_check_sent(_peer.send_text(text))

  # A refused frame leaves a tick gap the relay would reject; closing ends the match as relay lost instead.
  func _check_sent(result: Error) -> void:
  	if result == OK: return
  	_refused = true
  	_peer.close()

  func closed() -> bool:
  	return _called and (_refused or _peer.get_ready_state() == WebSocketPeer.STATE_CLOSED)
  ```

  (Godot refuses a send once the 128 KiB outbound buffer is full, netplay stress §2.4, `wsl_peer.cpp:789-790` at 4.7.2-stable. The web peer also returns an error on a full buffer (`emws_peer.cpp:126`, Godot 4.7.2) and on a closed socket (user, 2026-11-15, design answers "Pre-research follow-ups"; not re-read at the rebase, no Godot source on this Mac), so `_check_sent` covers the web export too.)
- [ ] **Step 3 (`lockstep.gd`):** `const FRAME_RESERVE_BYTES: int = 256 # the tick envelope and hash around the commands, with room to spare`; `var _queue_bytes: int = 0`. `submit` (`:63-70`, returns nothing on `52017fd`) before stamps the sequence and the submit time before it appends; a refusal must do neither (Determinism notes, L19). After:

  ```gdscript
  func submit(payload: Dictionary) -> bool:
  	var command: Dictionary = payload.duplicate(true)
  	command.tick = _last_sent + 1
  	command.player = _seat
  	command.sequence = _sequence # measured with its digits; consumed only below
  	var size: int = Wire.encode(command).to_utf8_buffer().size() + 1
  	if _queue_bytes + size > Wire.MAX_FRAME_BYTES - FRAME_RESERVE_BYTES: return false
  	_submit_times[_sequence] = _clock.call()
  	_sequence += 1
  	_queue_bytes += size
  	_queue.append(command)
  	return true
  ```

  (`+ 1` is the `,` between commands.) `finish_tick` (`:124-140`): `_queue_bytes = 0` next to `_queue = []` (`:134`); replace `_packets[_seat][packet_tick] = Wire.decode(text).message` (`:137`) with a checked decode that, on failure, ends `ended_protocol` with `"own frame: " + error` and returns before `_last_sent` and `send` (Profiler zone closed on both paths).
- [ ] **Step 4 (callers):** `online_driver.gd` `submit` (`:173-175`) before:

  ```gdscript
  func submit(payload: Dictionary) -> Dictionary:
  	_lockstep.submit(payload)
  	return {"ok": true, "error": ""}
  ```

  after (Question 17's text; C25: the screen ignores the return since SB3, so the refusal also goes where `_take_answers` reads, in the shape `_new_answers` builds, `:156-171`):

  ```gdscript
  const TOO_MANY_ORDERS: String = "Too many orders at once; wait a moment"

  func submit(payload: Dictionary) -> Dictionary:
  	if _lockstep.submit(payload): return {"ok": true, "error": ""}
  	# The screen reads refusals from take_answers, not from this return.
  	_answers.append({"command": payload, "ok": false, "error": TOO_MANY_ORDERS})
  	return {"ok": false, "error": TOO_MANY_ORDERS}
  ```

  (`orders.answered`, `orders.gd:150-157`, then treats a refused `build` like any refused build: online it reopens placement.) `seat_sim.gd` `issue_command` (`:18-20`): return `{"ok": ok, "error": "" if ok else "too many orders"}`. `headless_client.gd:129` (the `choose_faction` order at each match's start, also after a rematch) ignores the bool (the first order of a match is never refused).
- [ ] **Step 5 (`headless_client.gd` `_run_steps`, `:151-162`):** line `:154` becomes `if _transport.closed() or _transport.silent(Time.get_ticks_usec()): _lockstep.set_relay_lost()` (the online driver's rule, `online_driver.gd:97`; before this the headless client never called `silent`, netplay stress §2.4). Per Question 30 (answered) the headless client does not set `patient`: the check runs before `_rematch_step` (`:155-157`, call at `:156`), so it also covers the wait for `again`/`start`, where relay pongs keep `_last_rx` fresh.
- [ ] **Step 6:** `SUITE(t4)`; `cmp` each trace against `*-before.tsv` (silent); `sh tools/run_checks.sh`; lockstep benchmark alone, so `submit`'s new encode shows before Task 8: `godot --headless --path game --script res://benchmarks/run_lockstep.gd > <abs $L>/t4-lockstep.log 2>&1; echo "exit=$?"` (`LOCKSTEP BENCHMARK PASSED 1`, one `LOCKSTEP BUDGET PASS`; a `LOCKSTEP BUDGET FAIL` is a Stop, never a budget change); netplay `match` (N1; `cmp <abs $L>/t4-np-match/s1.cmd <abs $L>/t0-np-match/s1.cmd` silent), `rematch` (N1 twice, the silence check during the wait for `again`), `stall`, `kill`, `silent` (seat 1 still `ended_left` within 12 s; seat 2 now also ends on its own 5 s rule when its 15 s stall returns, which the scenario does not check), `left-mid` (seat 2 `stopped`, seat 1 `VICTORY left`: the silence check does not fire first). Record.

---

### Task 5: Fault proxy `tools/netfault`

```text
Task: a stdlib-only Go TCP proxy for one seat: forwards both directions in order and applies a timeline of hold, slice, reset and blackhole faults counted from its accept; logs every applied fault.
Owns: tools/netfault/go.mod (module wargrid/netfault, go 1.27.4 as relay/go.mod, no requirements), tools/netfault/main.go, tools/netfault/proxy.go, tools/netfault/proxy_test.go (linted with relay/.golangci.yml via --config, no copy).
Invariant: bytes never reordered, duplicated or dropped except during a blackhole, after which nothing is forwarded again.
Boundary: Proxy rows.
Red: NF1-NF5 fail before the code exists (compile failure recorded as red).
Green: cd tools/netfault && go vet ./... && go test -race ./...; golangci-lint run 0 issues.
Stop: the module needs a non-stdlib dependency.
```

- [ ] **Step 1 (interface):** `netfault -listen 127.0.0.1:<port> -target 127.0.0.1:<relay port> -log <file> -faults '<list>'`; accepts **one** connection, dials the target, pipes both directions, exits when both sides are closed or 120 s after the accept (hard cap, so a failed scenario never hangs CI). Faults (comma-separated, times in milliseconds since the accept): `hold@<at>:<for>` (stop writing both directions for `for` ms, keep reading and buffering, then write everything in order), `slice:<n>` (every write split into chunks of at most `n` bytes), `reset@<at>` (`SetLinger(0)` on both sockets, close: an RST), `blackhole@<at>:<for>` (from `at`, read and discard both directions; after it the stream is never resumed, since discarded bytes broke the WebSocket framing; a close from either side during or after a blackhole is not passed on, so the relay side stays open and silent until the relay closes it). Question 19: delay and jitter are not built here (the Adaptive input delay package adds them with its paced mode). One connection per proxy is enough here; P8's drop scenarios (packages night-lane item 8: "its fault proxy runs P8's drop scenarios") need a reconnect through the proxy, which P8 adds. Log lines: `NETFAULT <unix ms> <ms since accept> <event> <detail>` (unix ms is the clock of the clients' `NETCLIENT TIME` lines, printed at `headless_client.gd:228` from `_now_ms`, `:311-312`), events `accept`, `hold-start`, `hold-end <bytes up> <bytes down>`, `slice <n>`, `reset`, `blackhole-start`, `blackhole-end <discarded up> <discarded down>`, `close <side>`, `exit`.
- [ ] **Step 2 (tests, `proxy_test.go`, against an in-test echo or recording TCP server on `127.0.0.1:0`):** **NF1** clean: 1 MiB of a counter pattern both ways arrives identical. **NF2** hold: bytes sent during a 300 ms hold arrive after at least 300 ms, in order, all of them; `hold-end` logs the counts. **NF3** slice 7: the server's reads are each at most 7 bytes and the stream is identical. **NF4** reset at 200 ms: the client's read returns a connection-reset error (`errors.Is(err, syscall.ECONNRESET)`; on Windows the Go error differs, so the test accepts any non-EOF error there and says so in a comment). **NF5** blackhole at 100 ms for 300 ms: nothing written after 100 ms is delivered; at 500 ms (after `blackhole-end`) both sides write a 4 KiB counter pattern and neither receives any byte within 300 ms (the stream never resumes after `for`); the client closes at 900 ms; the server side sees no EOF for at least 1 s after that (stays open and silent), then the test closes it and the proxy logs `exit`. Fails if the proxy forwards again when `for` elapses (the 500 ms pattern arrives) or passes the client's close on (EOF on the server side). `proxy-blackhole` cannot catch the resume, since seat 2 has closed before the hole ends, so this assert stays in NF5. Timelines are injected so the tests take under 5 s together (NF5 alone about 2.2 s).
- [ ] **Step 3 (code):** `proxy.go`: one goroutine per direction, each a loop `read → (fault state) → write`, guarded by one mutex-protected fault state driven by `time.AfterFunc` timers created at accept from the parsed list; a hold collects into a per-direction `bytes.Buffer` and flushes in order on release; slice wraps the writer. `main.go`: flag parsing, the log file, the 120 s cap. Go gates and lint (`--config ../../relay/.golangci.yml`) in `tools/netfault` (`t5`).
- [ ] **Step 4:** record test times and the lint result.

---

### Task 6: Proxy scenarios and CI

```text
Task: run_netplay.sh gains proxy-clean, proxy-burst, proxy-reset and proxy-blackhole (one netfault process per seat), a shared-prefix hash compare and a one-line repro on failure; CI builds netfault, tests and lints it, and runs kill, stall, spike, version and the four proxy scenarios on Linux and Windows.
Owns: tools/run_netplay.sh, .github/workflows/ci.yml (godot-export netplay steps, relay-test, relay-lint), docs none (Task 8).
Invariant: the 13 existing scenarios' assertions unchanged (plus Task 2's relay-log checks); WARGRID_RELAY_URL still allows only match.
Boundary: Proxy rows; Lead bound "hold-and-burst".
Red: the four names end "unknown scenario" before the change; proxy-blackhole fails with Task 4's silence line in headless_client.gd commented out (scratch Edit, reverted, git diff --stat clean); proxy-burst fails with leadLimit mutated to drop the + 1 (scratch, reverted).
Green: each new scenario NETPLAY PASSED 3 times in a row locally; every existing scenario still passes; sh tools/run_shell_checks.sh; `actionlint .github/workflows/ci.yml` exit 0 (installed, allowed at night); the branch CI run later (morning item).
Stop: a proxy scenario flaky in 3 runs; an existing scenario red; the new CI loop does not fit Question 21's budget (longer export job from Task 0 Step 5b, 6 min 25 s on `43863567341`, plus twice the local sum of the added scenarios above 20 min, Q21): then take Question 21's fallback answer, or park Step 3 if it has none.
```

- [ ] **Step 1 (`run_netplay.sh`):** usage line gains the four names. `netfault_bin=${WARGRID_NETFAULT_BIN:-}`; `start_proxies FAULTS1 FAULTS2`: build `"$out/netfault"` from `"$repo_root/tools/netfault"` unless the variable names a binary (as `start_relay` does for the relay, `:20-34`), pick two free ports like `:9`, start one `netfault` per seat with `-log "$out/proxy-seat<N>.log"`, append their pids to `$pids`, and set `url1`/`url2` to `ws://127.0.0.1:<proxy port>/ws`. `start_client` keeps using `$url`; `start_pair` sets `url=$url1` before seat 1 and `url=$url2` before seat 2 when proxies run (one line each, guarded by `[ -n "$url1" ]`). `fail` additionally prints `repro: NETPLAY_OUT=<new dir> sh tools/run_netplay.sh $scenario` and `grep -h 'NETFAULT' "$out"/proxy-seat*.log` lines when proxy logs exist (`grep`, as everywhere in the script: CI runners may lack `rg`). `same_prefix A B`: `n=$(min of wc -l)`; `[ "$n" -gt 0 ]`; `head -n "$n"` of each into `$out/prefix-*.tsv`; `same_hashes` on those.
- [ ] **Step 2 (scenarios):**
  - `proxy-clean`: `start_relay; start_proxies "" ""; start_pair "" ""`: the `match` assertions (N1, oracle, three-way hashes).
  - `proxy-burst` (**setup changed, assertion kept**, landed in Task 6 and accepted (user, 2026-11-17)): seat 1 faults `slice:7,hold@2000:3500`, seat 2 `slice:7,hold@3000:3000` (seat 2's margin to the 5 s client silence rule at least 0.95 s), plus a precondition that seat 2's hold starts before seat 1's ends; first written as seat 2 `slice:7,hold@3000:4000`, seat 1 `slice:7`: `match` assertions, plus `grep -q 'hold-end' "$out/proxy-seat2.log"` with nonzero byte counts, and `! grep -q 'lead bound' "$out/relay.log"` (the lead bound's regression test).
  - `proxy-reset`: seat 2 `reset@4000`: `wait_exit` both within 30 s; s2 `ended_relay`, s1 `ended_left`; both `NETCLIENT TIME` within 2000 ms of the unix ms on seat 2's `reset` proxy line; `same_prefix s1.tsv s2.tsv`.
  - `proxy-blackhole`: seat 2 `blackhole@3000:7000`: s2 `ended_relay` with reason `connection to relay lost` and `NETCLIENT TIME` 5500 to 7500 ms after the unix ms of seat 2's `blackhole-start` line (first 4500 to 6500; shifted (user, 2026-11-17) because the measured gap includes the 1 s close wait, about 6005 ms, so a 4 s silence mutant passed the old window; it now fails at 5012 ms); s1 `ended_left` 9000 to 12000 ms after it; `same_prefix`.
  - If the clean match ends before 3 s on a fast host (it took 12-15 s locally, netplay stress §4 F1), the fault never lands: each proxy scenario fails if its fault line is missing from the proxy log, so this shows as a red, not a silent pass.
  Run each three times locally (`t6-<scenario>-<n>`), plus all 13 existing once.
- [ ] **Step 3 (CI, `ci.yml`):** godot-export job: after "Build relay for the netplay step" (`:112-114`) add "Build fault proxy" (`working-directory: tools/netfault`, `CGO_ENABLED=0 go build -trimpath -o "../../relay-bin/netfault-${{ matrix.platform }}${{ … '.exe' }}" .`); `setup-go` there gains `tools/netfault/go.mod` only if caching complains (stdlib module, no `go.sum`); the netplay step exports `WARGRID_NETFAULT_BIN` like `WARGRID_RELAY_BIN` and its loop (`:151`, today `match rematch left-mid perturb relay-down maps map-mismatch`) becomes `match rematch left-mid perturb relay-down maps map-mismatch kill stall spike version proxy-clean proxy-burst proxy-reset proxy-blackhole` (Question 21). relay-test job: a step `go vet ./... && go test -race ./...` with `working-directory: tools/netfault`. relay-lint job: a second `golangci-lint-action` step with `working-directory: tools/netfault` and `args: --config ../../relay/.golangci.yml` (same version and install mode, Question 20).
- [ ] **Step 4:** `sh tools/run_shell_checks.sh`; `actionlint .github/workflows/ci.yml > <abs $L>/t6-actionlint.log 2>&1; echo "exit=$?"`; record per-scenario seconds, the added scenarios' local sum, and the budget check (Task 0 Step 5b's longer job + 2 × that sum, against Question 21's limit).

---

### Task 7: Goroutine churn

```text
Task: a relay Go test opens and closes many rooms and checks the goroutine count returns to its baseline.
Owns: relay/churn_test.go (new: GC1).
Invariant: no production change.
Boundary: none.
Red: GC1 fails with a planted leak (scratch, reverted): a `go func() { select {} }()` in room.run.
Green: relay gates; the planted leak reverted (git diff --stat shows only churn_test.go).
Stop: GC1 flaky in 3 -race runs.
```

- [ ] **Step 1:** `TestRoomsDoNotLeakGoroutines`: `cfg := testConfig(); cfg.silence = 2 * time.Second`; `h := &relay{reg: newRegistry(cfg)}` (P2.2 moved silence into `config`); `httptest.NewServer(newServer(h).Handler)`; besides the plain rooms, every tenth round parks and rematches once before closing (P2.2's `again` path, `rematch_test.go` style over sockets), so a goroutine left by park, rematch or the expiry timer shows too; `runtime.NumGoroutine()` baseline after one warm-up room; 50 times: two clients (`dial` of `batch_test.go:21-29`), create and join, both send ticks 4..6, both close; then `eventually` (extend to 5 s locally in the test) `runtime.NumGoroutine() <= baseline + 2` (slack for the HTTP server's idle goroutines; state why in one comment), with the count in the failure message.
- [ ] **Step 2:** red by the planted leak (record count), revert, green three times under `-race`. Lint.

---

### Task 7b: Batch size guard

```text
Task: with WARGRID_BATCH_MS on, the sender flushes the waiting batch before a frame would make the joined message longer than maxMessageBytes (65,536), so no batched message outgrows what a client already reads; the knob stays off by default.
Owns: relay/sender.go (addBatch only), relay/sender_test.go (new: BG1).
Invariant: frame order per socket; the sealed rule (C20, C22); TestBatchJoinsTicks, TestNoPongAfterReject and every other Go test unchanged; no relay variable added or changed.
Boundary: Batch guard rows of the interaction table.
Red: BG1 fails on the base sender (five max frames come out as one 327,684-byte message).
Green: relay gates (t7b); CONFORMANCE PASSED 69 (no batch profile; unchanged); netplay spike (WARGRID_TEST_DELAY_MS path untouched).
Stop: any existing Go test red; a change outside addBatch needed.
```

Decided by the user (design answers "Relay guards questionnaire", "Batch size guard", 2026-11-15): Relay guards adds a guard with a test, "cap the batch below the client buffer, or flush early". Which of the two, and the threshold, was **Question 31**: flush early at 65,536 bytes (user, 2026-11-16, design answers "Readiness round"). Why it matters: `flushBatch` (`sender.go:77-88`) joins every waiting frame with `\n`; five full frames in a 3v3 are 327,684 bytes, over the client's `BUFFER_BYTES = 1 << 17` (`relay_transport.gd:5`). What it does not fix: the Godot client does not split joined messages (`poll`, `relay_transport.gd:27-37`; `docs/development.md:116`), so batch mode stays unreadable for it; this guard only stops the overrun (a client that splits comes with night 10 Lighter relay frames).

- [ ] **Step 1 (test, `relay/sender_test.go`, new; `frames` from `deadline_test.go:32-51`):** **BG1 `TestBatchCutAtFrameCap`**: `f := &frames{}; s := &sender{write: f.write, shut: func() {}}`. (a) five `addBatch` calls with 65,536-byte frames (`bytes.Repeat([]byte("x"), maxMessageBytes)`), then `s.flushNow()`: `len(f.got) == 5`, each `len <= maxMessageBytes`, and their concatenation equals the five frames in order. (b) fresh sender: frames of 32,767 and 32,768 bytes, `flushNow`: one message of exactly 65,536 bytes (`32767 + 1 + 32768`); fresh sender: 32,767 and 32,769 bytes: two messages. (c) fresh sender: three 100-byte frames: one message, the three joined by `\n` (today's behaviour). (d) sealed: fresh sender, one 100-byte frame batched, `s.sendLast([]byte("err"))`, then `addBatch` of a 65,536-byte frame and `flushNow`: `f.got` is exactly the 100-byte frame then `err`. Run `cd <abs $W>/relay && go test -race -run TestBatchCutAtFrameCap ./... > <abs $L>/t7b-red.log 2>&1; echo "exit=$?"`: red on (a) and (b) second half. Record.
- [ ] **Step 2 (`sender.go` `addBatch`, `:63-69`):** before:

  ```go
  func (s *sender) addBatch(frame []byte) {
  	s.mu.Lock()
  	defer s.mu.Unlock()
  	if !s.sealed {
  		s.batch = append(s.batch, frame)
  	}
  }
  ```

  after:

  ```go
  func (s *sender) addBatch(frame []byte) {
  	s.mu.Lock()
  	defer s.mu.Unlock()
  	if s.sealed {
  		return
  	}
  	size := len(frame)
  	for _, f := range s.batch {
  		size += len(f) + 1
  	}
  	// A joined message over the frame cap may not fit a client's receive buffer, so cut the batch first.
  	if size > maxMessageBytes {
  		s.flushBatch()
  	}
  	s.batch = append(s.batch, frame)
  }
  ```

  (`maxMessageBytes`, `envelope.go:12`, is the relay's own inbound frame cap; a single frame never exceeds it, so every message stays at most 65,536 bytes.)
- [ ] **Step 3:** BG1 green; relay gates (`t7b`) three times under `-race`; `golangci-lint run` 0 issues; netplay `spike`. Record.

---

### Task 8: Docs and package gate

```text
Task: docs describe every new relay rule, the limits, the proxy scenarios and the client guards; the final tree passes every gate; one ledger row.
Owns: docs/guide/11-multiplayer.md, docs/guide/13-testing-and-tooling.md, docs/development.md (Relay section), docs/playing-online.md (Status lines), docs/reference/netplay-reference-review.md (gaps line and one review line), docs/reference/netplay-stress.md (one status line), docs/reference/performance.md (History row), docs/STATUS.md (night 7 row), README.md (generated only), docs/reference/perf-history.csv (benchmark record only), the verification file.
Invariant: N1-N7.
Boundary: load average above 2.5 at the benchmark (`uptime`): run anyway and tag the row "host under load" (morning item: rerun when quiet); no wait loop at night.
Red: n/a.
Green: every command below on the final tree, each recorded with the tree.
Stop: a trace, N1 or vector change; a budget newly exceeded.
```

- [ ] **Step 1 (guide; footers "Checked against" = `git rev-parse --short HEAD` (rule proposed; if denied, `git log -1 --format=%h`, already allowed); simple to complex kept):**
  - ch. 11 "The relay" (`:125-156`): the opening sentence (`:127`, "about 740 lines in four files"; already stale after P2.2 and `29724db`) counts `limits.go` (recount files and lines with `wc -l relay/*.go` minus tests); "Forwarding" gains the lead bound in two sentences (why it holds for honest clients, its numbers at delay 4); "What the relay does not look at" (`:149`) changes: the relay now compares hash values and logs `DESYNC` with seat groups, still never rules on a desync; a new short "Limits" paragraph (per-address sockets and joins, global buckets, bounded table, header from `WARGRID_CLIENT_IP_HEADER`, off without it; the hello deadline frees an idle slot after 5 s); "Leaving": `MATCH END` fields (room-wide across rematches); one sentence on the batch cut at 64 KiB. "One protocol, three checkers" (`:157-167`): conformance profile counts, the suite's dial pacing (why: the global bucket is fixed), the netplay scenario count (17) and the proxy. "Playing again" (`:168-177`): one sentence that the lead bound restarts with the second `start` and pending hashes are dropped at the rematch. "What a slow peer does" table (`:182-204`): the headless client now has the 5 s rule; the "Stops reading" row (`:196`) names what `TestStalledPeerStillProducesLeft` now shows (the stalled seat still sends, its socket is closed on the write side); a "Runs far ahead" row (lead bound) and a "Hold-and-burst" row (proxy-burst). "Trade-offs and limits": "Packet size is bounded by the frame cap" (`:215`) gains the client cap and the HUD note ("Rejected: Too many orders at once; wait a moment", reached through the driver's answers); WebSocketPeer no-delay measured (rider numbers above: native loopback, web end to end through the live relay). Files list (`:223-239`: `relay/limits.go`, `relay/sender.go` batch cut, `tools/netfault/`) and footer (`:250`).
  - ch. 13 (`:186-187`, `:240`, footer `:254`): CI netplay loop list (eleven scenarios plus four proxy ones), netfault build, test and lint steps, conformance profiles (five, the case total), the dial pacing.
- [ ] **Step 2 (references):** `development.md` Relay (`:104-123`): the new variable (Question 27: not set on fly yet; set with the approved deploy that runs the header check, 17 forged sockets; deploy needs approval), the four new error reasons, `DESYNC` and the `MATCH END` keys, "no client IPs" still true (`:122`), how to run the proxy scenarios; the knob line (`:116`) also names `WARGRID_HELLO_MS` and `WARGRID_LOBBY_MS` (P2.2, missing there today) next to `WARGRID_CLIENT_IP_HEADER`; the slow-peers line (`:118`, "With `WARGRID_BATCH_MS` one large batch can trip it alone") says batches are now cut at 64 KiB. `playing-online.md` Status lines (`:21-30`): the `Relay: <reason>` row lists the new reasons in player words (Question 16) and a row for the HUD note of Question 17. `netplay-reference-review.md`: "Gaps and unverified points" Nagle line (`:330`) and "Still unverified" (`:349`) say native measured (link the verification file) and web closed end to end (design answers "Pre-research follow-ups", 2026-11-15; per-leg split unmeasured); one line under "Review 2026-11-13" that S1, S5 and P5.1 are implemented on branch `relay-guards`. `netplay-stress.md` "Review 2026-11-14": one line that F1, F3, F4, F5 run in CI from branch `relay-guards`. `STATUS.md` night 7 row (`:35`): "implemented on branch `relay-guards` (local, not pushed, not deployed); no trace re-pin; CI, Windows, browser and fly header unverified". (The `packages.md` "Now" blurb already says P2.2 is merged on `52017fd`; no edit there.) `python3 tools/roadmap.py` and `--check` exit 0; `sh tools/check_public.sh` exit 0; relative links in changed docs resolve.
- [ ] **Step 3 (gates):** `SUITE(final)`, traces `cmp` against `*-before.tsv`; `sh tools/run_checks.sh`; relay and netfault Go gates and lint; `sh tools/run_conformance.sh` (record the total); all 17 netplay scenarios once; `git diff --stat main -- protocol/vectors game/scripts/simulation game/scripts/presentation game/scenes game/data` empty.
- [ ] **Step 4 (benchmark, alone, last):** `pgrep -fl 'godot|generalszh'` shows none of this run's processes; `uptime`; `PERF_LABEL="Relay guards" sh tools/run_benchmark.sh > <abs $L>/t8-bench.log 2>&1`: `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1` (the `submit` encode lands here), `recorded … rows`, only the accepted `BUDGET EXCEEDED` line. No rendered rerun: presentation unchanged.
- [ ] **Step 5:** resume record's "Unverifiable at night" names the morning items.

---

### Task 9: Fresh-context branch review (Opus, high, plus the player-experience reviewer)

- [ ] One fresh Opus (high) reviewer gets `git diff main...HEAD`, the changed paths, this plan's "Review focus", "Determinism notes", "Same-tick and interaction cases" and "Allowed test edits", the verification file, and the instruction to name, per new or rewritten test (LB-U1-U4, the four lead-bound conformance cases, HC-U1-U6, BF-U1, BF-U2, the perturb, match, rematch and left-mid relay-log checks, the paced default profile's zero `msg=limit`, LM-U1-U6, the limits and global profiles, T7 (both halves), L19, L20, N-cap, NF1-NF5, the four proxy scenarios, GC1, BG1, A1, A2, A4; A5 is a compile fix), the production change that would make it fail. It also gets "Rebase onto `52017fd`" and "Rebase onto P2.2" and checks that no P2.2 rule changed (sealed reject, opponent-left result included). No repo-wide search.
- [ ] The `player-experience-reviewer` (`.claude/agents/player-experience-reviewer.md`; AGENTS.md: diffs touching player-facing text get it beside the correctness reviewer, user 2026-11-16) gets only the client and text parts: Task 4's HUD refusal and its wording, the `playing-online.md` reason rows (Question 16) and the opponent-left interplay (C23). Read-only, same fix round.
- [ ] Fix critical and important findings of both reviewers in one round, test-first, by a Sonnet subagent; rerun the affected gates; minor findings go to the morning summary. Then one `/ponytail-review` pass on the diff (over-engineering only); apply cuts, re-verify.

## Questions

In `questions.md` beside this file (numbers kept as ids, so every `(Qn)` in this plan points at the same question). Q1-Q30 answered (user, 2026-11-15; Q18 dropped). Q31-Q33 (new 2026-11-16) answered A, A, A the same day (user, design answers "Readiness round"): flush early at 65,536; pace dials 50 ms; keep the "Rejected: " prefix. No question is open.

## Decisions this plan relies on

- Package scope (user, 2026-11-13, package note "Relay guards"; netplay review "Review 2026-11-13"); hello deadline and lobby expiry in P2.2 (user, 2026-11-13 night).
- ioq3 limiter parts: global join bucket, bounded table failing closed, global bucket for unknown-match replies (user, 2026-11-14, ioq3 research, package note).
- Fault proxy in Go in `tools/`, CI scenarios proxy-clean, proxy-burst, proxy-reset, proxy-blackhole, headless 5 s silence check, boundary outages, repro line and per-seat fault log, faults out of process; riders `kill stall spike version` in CI, goroutine-churn test, refused `send_text` closes (user, 2026-11-14, netplay stress review).
- Client caps its pending frame at 64 KB and refuses extra orders visibly (user, 2026-11-14, ponytail audit review).
- WebSocketPeer rider: one timestamp confirmation, fix only if it shows a delay (user, 2026-11-14); measured, no delay on native (backup 2, 2026-11-15); web closed end to end, no send delay found (user, 2026-11-15, design answers "Pre-research follow-ups").
- Task 4's `_check_sent` carries one citation line for the web peer (`emws_peer.cpp:126`, error on a full buffer and on a closed socket) (user, 2026-11-15, design answers "Pre-research follow-ups").
- P2.2 as merged (`ee2f353`): one `WARGRID_LOBBY_MS` for lobby expiry, start window and park limit; `WARGRID_HELLO_MS` 5 s; `MATCH END` per room with counters added up across rematches; "Connection to relay lost" stays for real losses (P2.2 design, user, 2026-11-15).
- Relay guards questionnaire (user, 2026-11-15, design answers "Relay guards questionnaire"): every question as recommended except Q10, 16 sockets per address; revised the same day after an independent review: Q12 a fixed production global bucket (burst 20, refill 20 per s) with the suite pacing or a test-only override; a batch size guard joins the package (cap the batch below the client buffer, or flush early, with a test); Q26 and Q22 follow Q10's 16 (the forged-header check needs 17 sockets). M9 notes in `docs/questions/next-m9-drops.md` "Notes from the Relay guards answers".
- P2.2 slice 2 (released 0.13.0, 2026-11-16): the opponent-left Victory result and `left-mid`; `29724db` sealed reject. Both stay as merged.
- Relay deploys need explicit approval (AGENTS.md).

## Review 2026-11-15 (Grok, history)

Fresh review in `review-grok.md` (flatter-worst-ticks backups); each finding checked against `main` `9c8c505` before applying. Superseded where "Readiness fix 2026-11-16" says so (items 6 and 9: the global burst is now fixed at 20 and Q10 answered 16).

1. Applied with a change: A0 helpers (`drain`, `captureLogs`), the stalled seat sends with a plain `WriteString` and stops on the first error, seat 2's channel drained in the loop, the "seat 1 was silent" claim dropped. A2 asserts `write queue full`; A1 asserts no `error` and no `lead bound` line instead, since its unwindowed socket may close by the cap or the write deadline and both are a valid `left`.
2. Applied as Questions 26 (missing header: skip per-IP, recommended) and 27 (`fly.toml` not in this branch, recommended); Task 3 Step 5 runs only on the other answer.
3. Applied: `OnOpen` before/after with a comma-ok session read; key `""` means no per-IP rules (verified `upgrader.go:191-192`, `conn.go:111`, `stall_test.go:34-38`, `batch_test.go:50-54`).
4. Applied: `limits_conn_cap` retries one attempt at a time for up to 1 s.
5. Applied: T7 uses a real loopback socket whose reader stops, plus a second half for the ping in `poll`, which now goes through `send_text`; N-cap in `test_online_scene.gd` is mandatory.
6. ~~Applied: `globalBurst` from Task 3 Step 1's measurement.~~ **Superseded (user, 2026-11-15, Q12): the burst is fixed at 20, refill 20 per s; Task 3 Step 1 now paces the suite and sets no constant.** (Hello count then: about 77, 85 after Task 1.)
7. Applied: NF5 writes a pattern after `blackhole-end` and asserts nothing arrives.
8. Applied: the `stall` row no longer claims to prove the refresh order.
9. Applied then: Question 10 offered 16 and "join rate only". **Superseded: answered 16 (user, 2026-11-15).**
10. Applied: Task 0 Step 5b records the export job budget (evidence: 4 min 38 s / 5 min 12 s of 25 at `f568e9b`); Task 6 Stop and Question 21 use it.
11. Applied: `submit` written out in order; the sequence value is measured but consumed only after the size check.
12. Applied: late-join and restart rows added.
13. Applied: all five slips checked and fixed (`:206`, `:39` and `:22`, `:55-57`, `:33`, guide `:123` in Task 8).
14. Applied: HC-U4 and its Stop use `<= 1`.
15. Applied: no task cut; Global Constraints "Values from Questions" and Task 0 Stop keep the night run from starting with open Questions.

## Readiness fix 2026-11-16

Readiness review `~/projects/wargrid-overnight-work/sim-boundary/backups/1-relay-guards/review.md` (Grok 4.7 high, against `main` `fd8671b`, 13 findings, not ready) plus its coordinator addendum; each finding checked against `52017fd` before applying. Details per finding: `changes.md` beside this file.

1. Applied: cap 16 everywhere (`maxConnsPerIP = 16`, interaction row 16 held / 17th refused, risks, `limits_conn_cap` final count 15, Q22 check 17 sockets).
2. Applied: `globalBurst = 20`, `globalPeriod = 50 ms` fixed; the measurement is a check only (Task 0 Step 4, Task 3 Step 1); the suite paces its dials (Task 3 Step 1, no relay variable); Stop forbids raising 20. Pacing sits in `dial`, not in the hello helper as the review proposed, because the deadline cases measure after `dial` and a wait before a hello could land inside a measured window. Mechanism open as Question 32 (the user named pacing or an override).
3. Applied: Task 7b, test-first, owns `sender.go` `addBatch` only; flush early, but at 65,536 bytes (`maxMessageBytes`) rather than the review's 131,072, since a 65,536-byte message is what every client must already read (a full frame; T4 sizes the buffers for it) and Godot's exact buffer boundary is not read; mechanism and threshold open as Question 31.
4. Applied: `start_window_ends` edit cites `:645-647`, replaces only the `say` / `t++` pair.
5. Applied: `parseHash` replaces `validHash` at `envelope.go:101-102` only; malformed hash still `nil`; `over`/`again`/`ping` untouched.
6. Applied: proposed night settings gain the worktree folder and `Edit` rule, `mkdir`, a `cd` rule, `go run`, `kill`, the relay binary rule, `rg`, and `NETPLAY_OUT` / `WARGRID_REPLAY_TRACE` for the relay-guards logs; no `gh` (CI numbers recorded now); `ls` not needed (Task 0 uses `mkdir -p`). Go rules cited at `:109-112`. `cd … &&` kept for module folders with a Task 0 smoke, since the review could not test either form.
7. Applied: night-lane item 8, Task 8 edits the night 8 row (`STATUS.md:36`).
8. Applied: `verification.md` beside this file refreshed (base `52017fd`, 13 scenarios, 61 cases, 9013, approved decisions, Q31-Q33 open, Task 7b row).
9. Applied: test literal lines `deadline_test.go:105`, `rematch_test.go:33`, `shutdown_test.go:106`, `r.stats` read `:73-75`, `startPrefix` `:46-52`; the four literals found by text.
10. Applied: the ping send is `relay_transport.gd:36`.
11. Applied: `hashGroups` written out.
12. Applied: Task 8 adds `WARGRID_HELLO_MS` and `WARGRID_LOBBY_MS` to the knob line (`development.md:116`).
13. Not needed on `52017fd`: `packages.md` "Now" already says P2.2 slice 1 and 2 are merged; Task 8 notes it, no edit.


## Readiness round 2 (2026-11-16)

Grok (`reviews/grok.md`, not ready) and Fable (`reviews/fable.md`, ready after fixes) against `52017fd`; every finding checked against the tree first. Details and line ranges: "Readiness round 2" in `changes.md`. Summary: A4 skips pongs (and a red A4 may only be cured that way); `lead_bound_steady_edge`, LB-U1 and the hash tests use interleaved, bound-respecting orders; `r.hashes` bounded by the lead through `pruneHashes` (coordinator's choice over a `% 30` filter or a clear-before-insert), with HC-U6; `desyncGroups` as the "none yet" sentinel; HC-U5 rebuilt so a missing rematch clear goes red; A1/A2 ordered by a pong per tick; T7 silences engine errors around the refused sends; test labels T7, L19, L20 (T6, L13, L14 are taken); `limits_conn_cap` timing assertions; allowlist union (extra-variable relay starts, `git rev-parse`, `cut`/`sort`/`uniq`/`head`, `until uptime`) plus the `go … -C <dir>` fallback; Q31-Q33 answered; stale history and client cites retargeted.
