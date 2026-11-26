# Wargrid development notes

Development status, setup, commands and operations for Wargrid's agent-driven workflow; players start at the [README](../README.md).

## Overview

Status: early development; what exists and what is next lives in [STATUS](STATUS.md), the plan in [packages](packages.md). Plans and evidence per milestone: [Start here](#start-here).

Developed with AI coding agents (Claude Code). [AGENTS.md](../AGENTS.md), the [blueprint](blueprint.md) and `docs/superpowers/` are that workflow's plans, decisions and evidence. In these documents "the user" is the project owner: a tag such as "(user, 2026-11-05)" marks a decision the owner made on that date, as opposed to an agent's proposal or assessment.

## Start here

- [Codebase guide](guide/README.md): how Wargrid works and why, one-page TL;DR then 13 chapters from the big picture to testing.
- [Status](STATUS.md): package and milestone state, the findings list and finished work. [Packages](packages.md): the plan for P1 to P6 and the rough rest.
- [Kickoff](kickoff.md) and [wrap-up](wrapup.md): `/kickoff` and `/wrapup` in Claude Code; portable instructions for any agent.
- [War Room](../warroom/README.md): the owner's decision rounds (art, UI, sound), steps with options A to H; `cd warroom && go run .`, then `http://127.0.0.1:8780/`.
- Session notes and handoff prompts: working files, kept in a private notes repository. Documents here mention them by file name, marked "private".
- [Blueprint](blueprint.md): scope, architecture and milestone gates; the M0 task plan (old §7.1) is archived in [blueprint archive](reference/blueprint-archive.md).
- [Design questions](questions/README.md): researched wizard questions; answers go to the blueprint and the [design answers](reference/design-answers-2026-11-08.md).
- [Map art reference](reference/map-art-shapes.md) and [map art round 6 verification](reference/map-art-round-6-verification.md): picked shapes, colours and marks per package P2.3a to P2.6, with the checks behind them.
- [Agent instructions](../AGENTS.md): development and verification rules.
- [Installation reference](reference/installation.md): available game data, archive hashes and unresolved version questions.
- [Performance ledger](reference/performance.md): low-end and browser target, derived budgets, measurement history; every milestone adds a row.
- [Zero Hour verification plan](reference/zero-hour-verification.md), [parity harness](reference/zero-hour-parity-harness.md) and [parity harness spike](reference/zero-hour-parity-spike.md): how Wargrid's mechanics are measured against the original.
- [Relay scaling](reference/relay-scaling.md) and [Relay](#relay): the relay and its multi-machine proposal.
- Finished work, design, plan and evidence (state lives in [Status](STATUS.md)):
  - M0: [plan](superpowers/plans/2026-11-01-m0-foundation.md). M1: [plan](superpowers/plans/2026-11-01-m1-vehicle.md). M2: [plan](superpowers/plans/2026-11-01-m2-groups.md).
  - M3: [design](superpowers/specs/2026-11-02-m3-base-supplies-design.md), [plan](superpowers/plans/2026-11-02-m3-base-supplies.md), [evidence](reference/m3-economy.md).
  - M4: [design](superpowers/specs/2026-11-03-m4-combat-design.md), [plan](superpowers/plans/2026-11-03-m4-combat.md), [test appendix](superpowers/plans/2026-11-03-m4-tests-4-5.md), [evidence](reference/m4-combat.md), [scenario envelope](reference/m4-scenario-envelope.md), [verification](reference/m4-verification.md).
  - M4.1: [design](superpowers/specs/2026-11-03-m4.1-playtest-polish-design.md), [plan](superpowers/plans/2026-11-03-m4.1-playtest-polish.md).
  - M5: [design](superpowers/specs/2026-11-04-m5-online-spike-design.md), [plan](superpowers/plans/2026-11-04-m5-online-spike.md), [verification](reference/m5-verification.md).
  - M5.1: [design](superpowers/specs/2026-11-05-m5.1-playtest-findings-design.md), [plan](superpowers/plans/2026-11-05-m5.1-playtest-findings.md), [evidence](reference/m5.1-acquisition.md), [verification](reference/m5.1-verification.md).
  - M6: [design](superpowers/specs/2026-11-05-m6-teams-full-map-design.md), [plan](superpowers/plans/2026-11-05-m6-teams-full-map.md), [evidence](reference/m6-map-and-feel.md), [verification](reference/m6-verification.md).
  - M7: [design](superpowers/specs/2026-11-06-m7-factions-design.md), [plan](superpowers/plans/2026-11-06-m7-factions.md), [evidence](reference/m7-factions.md), [verification](reference/m7-verification.md).
  - Post-M7 performance spike (handoff `performance-spike-prompt.txt`, private): [note](reference/performance-spike.md), [verification](reference/perf-spike-verification.md). Performance next (done 2026-11-11; handoff `perf-next-prompt.txt`, private): [note](reference/performance-next.md), [plan](superpowers/plans/2026-11-11-performance-next.md), [verification](reference/performance-next-verification.md), [worker thread design](superpowers/specs/2026-11-12-worker-thread-design.md), [view rows design](superpowers/specs/2026-11-12-view-rows-design.md), [data layout decision](reference/data-layout-decision.md), [order of next work](reference/design-answers-2026-11-08.md#after-performance-next-user-2026-11-11-evening).
  - Converted maps (merged 2026-11-09; handoff `converted-maps-prompt.txt`, private): [design](superpowers/specs/2026-11-08-converted-maps-playable-design.md), [plan](superpowers/plans/2026-11-08-converted-maps-playable.md), [verification](reference/converted-maps-verification.md), [more maps](reference/more-maps.md) ([converted maps section](reference/more-maps.md#converted-maps-playable-2026-11-09)), small piles ([design](superpowers/specs/2026-11-08-small-supply-piles-design.md), [plan](superpowers/plans/2026-11-08-small-supply-piles.md)).
  - Sound spike: [design](superpowers/specs/2026-11-08-sound-spike-design.md), [plan](superpowers/plans/2026-11-08-sound-spike.md), [evidence](reference/sound-spike.md), [verification](reference/sound-spike-verification.md), [credits](../game/audio/CREDITS.md).
  - Art lab: [design](superpowers/specs/2026-11-10-art-lab-design.md), [plan](superpowers/plans/2026-11-10-art-lab-spike.md), [verification](reference/art-lab-verification.md). [Sim interface](reference/sim-interface.md) and [determinism rules](reference/determinism-rules.md). Native simulation core spike (done 2026-11-11, CONDITIONAL GO, whole port only; handoff `native-sim-spike-prompt.txt`, private): [plan](superpowers/plans/2026-11-10-native-sim-spike.md), [verification](reference/native-sim-spike-verification.md), [report](reference/native-sim-spike.md).
  - Unit avoidance spike, rounds 1 to 4 (evidence on tag `archive/spike-avoidance`; handoff `unit-avoidance-research-prompt.txt`, private): round 4 [plan](superpowers/plans/2026-11-10-avoidance-round4-spike.md). Pathing timing: [plan](superpowers/plans/2026-11-10-pathing-timing-spike.md).
  - Small tasks: [static checks plan](superpowers/plans/2026-11-05-gdscript-static-checks.md), [test environment plan](superpowers/plans/2026-11-07-test-environment.md), [logo plan](superpowers/plans/2026-11-07-logo.md).
  - P1: [design](superpowers/specs/2026-11-11-packages-and-playtest-helper-design.md), [plan](superpowers/plans/2026-11-11-packages-and-playtest-helper.md), [verification](reference/p1-playtest-helper-verification.md).
  - P2: [design](superpowers/specs/2026-11-13-p2-you-clicked-we-heard-design.md), [plan](superpowers/plans/2026-11-13-p2-you-clicked-we-heard.md), [F5 addendum](superpowers/plans/2026-11-13-p2-f5-paste-and-links.md), [verification](reference/p2-verification.md).
  - P2.1 (merged 2026-11-14): [design](superpowers/specs/2026-11-14-p2.1-new-launcher-design.md), [plan](superpowers/plans/2026-11-14-p2.1-new-launcher.md), [verification](reference/p2.1-verification.md).
  - P2.2 Quick rematch (released as 0.13.0): [slice 1 design](superpowers/specs/2026-11-15-p2.2-quick-rematch-design.md), [slice 1 plan](superpowers/plans/2026-11-15-p2.2-quick-rematch-slice-1.md), [slice 2 design](superpowers/specs/2026-11-16-p2.2-slice-2-design.md), [slice 2 plan](superpowers/plans/2026-11-16-p2.2-slice-2.md), [verification](reference/p2.2-verification.md).
  - P12 Notes that never block: [design](superpowers/specs/2026-11-17-p12-notes-that-never-block-design.md), [plan](superpowers/plans/2026-11-17-p12-notes-that-never-block.md), [verification](reference/p12-verification.md).
  - Sim boundary (the `SimPump` seam, SB1 to SB4 and Pump hardening): [design](superpowers/specs/2026-11-15-sim-boundary-design.md), plans [SB1-SB2](superpowers/plans/2026-11-15-sim-boundary-sb1-sb2.md), [SB3](superpowers/plans/2026-11-16-sim-boundary-sb3.md) and [SB4](superpowers/plans/2026-11-17-sim-boundary-sb4.md), [verification](reference/sim-boundary-verification.md).
  - P2.3a A/B lab (the four HUD questions): [design](superpowers/specs/2026-11-18-p2-3a-ab-lab-design.md), [plan](superpowers/plans/2026-11-18-p2-3a-ab-lab.md); its picks are in the [design answers](reference/design-answers-2026-11-08.md#p23a-ab-lab-picks-user-2026-11-18).
  - P2.3a See your selection (split into P2.3a1 to P2.3a3): [design](superpowers/specs/2026-11-19-p2-3a-see-your-selection-design.md), P2.3a1 [plan](superpowers/plans/2026-11-19-p2-3a1-see-your-selection.md) and [verification](reference/p2.3a1-verification.md).
  - HUD v5 (the mock-ups the HUD packages P2.3a and P2.3b build from; user, 2026-11-16): [pictures and source](images/hud-v5/notes.md), [layout reference](reference/hud-v5-layout.md), [decisions](reference/design-answers-2026-11-08.md#hud-m76). HUD v4 (the look and the rest of M7.6; history for the dock): [pictures](images/hud-v4/notes.md).
  - Map art spike (decisions for P2.4 to P2.6 and the rest of M7.5): [pictures](images/map-art/notes.md), [decisions](reference/design-answers-2026-11-08.md#map-art-faction-shapes-m75-user-2026-11-13).

The blueprint owns design and milestone decisions; milestone execution plans own their detailed implementation contracts. These development notes own current setup and runnable commands. Reference notes record evidence; original behavior does not override deliberate Wargrid fixes.

## Milestone history

Older milestone state paragraphs (M3, M4.1, M4): [development history](reference/development-history.md). Evidence per milestone is in the files listed in [Start here](#start-here).

## Working tree and controls

`game/` contains a custom-drawn desert scene, engine-light simulation and explicit test suites. `tools/` contains launch/test wrappers and replay comparison. Controls of the former M2 movement demo and M3 base scenes (deleted by the One controller package; the match scene took over their input): [development history](reference/development-history.md), history only.

Match controls since P2.3b (the Esc menu's Controls list shows them in the game): the command card sits on the Q W E R / A S D F / Z X C V keys, one role per key in every faction (with one builder selected `Q` opens the build cells, `V` or Esc goes back; a factory or Barracks card queues its units on `Q`, `W`); the digits 1-9 are control groups (`Ctrl+N` or `Cmd+N` saves, `Shift+Ctrl+N` too, `N` selects, a double tap centres); `H` centres on the Headquarters, `Space` jumps to the last base under attack, the arrow keys and a 3 px band at the picture's edge pan; a match starts with the start builder selected. Mouse and orders: right-click an enemy unit or building to attack with the selection (mixed infantry and tanks are one group; any unarmed member rejects the whole order with a message on the refusal line, `warn`, above the bottom edge); A then left-click ground attack-moves (only the armed units of the selection get the order); S stops; F unloads a transport or Tunnel Hub; Escape or right-click cancels attack-move mode. Victory, defeat or draw shows a Restart button, which rebuilds the whole match.

Shell keys (all scenes, M7 gate 2): F3 toggles the performance overlay (FPS, frame and sim step times, unit and building counts; online also command latency and RTT; offline against bots, one line per bot ([guide 09](guide/09-ai.md#reading-the-f3-bot-line))). Esc backs out one layer at a time (placement or attack move, the build cells, the selection) and opens the pause menu when nothing is pending (Resume / Settings / Controls / Leave match / Quit; Quit is absent in the web build); Settings and Controls are pages that replace the menu, and Esc on a page returns to it. Offline the match pauses while it is open; online the simulation keeps stepping and leaving disconnects this client (a forfeit message is deferred to M9). Not yet played by the user; evidence in [M7 verification](reference/m7-verification-archive-gate2.md#esc-menu-2026-11-07-tree-m7-factions-72b2ec7-plus-uncommitted-apple-m6).

## Setup and commands

Use Godot **4.7.2 stable**. Verified local build: `4.7.2.stable.official.ed1daf0bf`.
CI pins matching Linux archive and SHA-256 from [official release metadata](https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable), fetched 2026-11-01; `tools/install_godot.py` falls back to downloads.godotengine.org when GitHub fails. No extra dependencies.

```sh
godot --version
sh tools/run_tests.sh
WARGRID_TEST_ONLY=test_supply.gd sh tools/run_tests.sh   # only suites/cases whose file or name contains the text, one process, seconds; the full suite stays the gate. The editor import is skipped while nothing under game/ is newer than game/.godot/wargrid-imported (delete it to force one)
WARGRID_TEST_EXE=build/WargridTests.app/Contents/MacOS/Wargrid sh tools/run_tests.sh   # same suite, 4 shards, in an exported "macOS Tests" build (the binary, not the .app)
sh tools/run_lint.sh   # gdlint from the tools venv
sh tools/run_warnings.sh   # typing, shadowing, unused-parameter and integer-division warnings as errors
sh tools/run_checks.sh   # the five static gates at once, one PASS/FAIL line each
python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/zh_ini.py dump   # Zero Hour INI blocks to build/zh_ini/inizh.jsonl (gitignored, never committed); needs the local retail archive
python3 tools/zh_w3d.py dump   # Zero Hour model sizes (mesh boxes, body box, bone positions) to build/zh_w3d/w3d.jsonl (gitignored, never committed); needs the local retail archives
python3 tools/zh_generals.py report   # what each Zero Hour general adds, removes and changes, from the INI dump, to build/zh_generals/ (gitignored, never committed)
# In a worktree without its own dump: --dump ~/projects/wargrid/build/zh_ini/inizh.jsonl, and ZH_INI_DUMP=<same path> for tools/test_zh_generals.py, whose real-data test otherwise skips
sh tools/run_python_checks.sh   # ruff format + lint, mypy, Python tests; creates `tools/.venv` with uv on the first run and updates it when `tools/requirements-dev.txt` changes (`tools/ensure_venv.sh`)
sh tools/run_shell_checks.sh   # ShellCheck on every tracked *.sh (shellcheck-py from the same venv; .shellcheckrc)
sh warroom/tools/quality.sh   # War Room's gate (Go and island checks); cd warroom && go run . open lists unanswered rounds
python3 tools/roadmap.py   # regenerate the README roadmap from docs/packages.md and docs/STATUS.md (--check only verifies)
actionlint   # GitHub workflows, with shellcheck on run: blocks; needs: brew install actionlint shellcheck
sh tools/check_public.sh   # no home paths, hostnames, LAN addresses, session ids or working files in tracked files (AGENTS.md, public repository rule)
mkdir -p build && sh tools/run_benchmark.sh > build/bench.log 2>&1   # on a clean main it records itself in docs/reference/perf-history.csv (PERF_LABEL="…" forces a record on any branch, PERF_RECORD=0 disables; PERF_REF=<rev> forces the pair step against <rev>; without it the reference is the merge base with main and the step is skipped when game/ is unchanged against it; the step takes about 3 min); the status table in the ledger and README is regenerated after every passing run whose record step succeeds, unless PERF_RECORD=0
sh tools/run_team_match.sh   # three-faction 3v3 bots-only match on Ashfall, pinned cap line at tick 45000, about 2 min
sh tools/run_bot_lab.sh LABEL   # 150 headless bot matches (bots vs bots, idle seat, tower), one table; rows in build/bot_lab/LABEL/; BOT_LAB_GAME=<patched export of game/> measures a variant (see the guide chapter 13)
```

Python tooling: ruff and mypy are configured in `tools/pyproject.toml`, pinned in `tools/requirements-dev.txt` (CI installs from the same file). Once per clone, `git config blame.ignoreRevsFile .git-blame-ignore-revs` makes `git blame` skip the formatting-only commits listed there (GitHub reads the file by itself); add the SHA of any future repo-wide reformat.

Profiling (report-only, never gates): `sh tools/run_profile.sh` prints per-zone timings for the benchmark workloads, the scripted skirmish match and a synthetic 196×196 map; the rendered benchmark takes `-- --profile` for the same zones plus a 196×196 leg. Results: [performance spike](reference/performance-spike.md).

Milestone runs follow the reusable [milestone prompt](milestone-prompt.md) (resume record, session start, pre-authorized local commits, stop conditions). Reviewers: [How a package runs](../AGENTS.md#how-a-package-runs). Token usage per session for the resume record: `python3 tools/session_usage.py <Claude session or Codex rollout files>`; `--lanes` prints the kickoff lane table.

CI runs Linux and Windows and compares their replay traces. Workflow `CI` (`.github/workflows/ci.yml`) skips pushes that change only docs or Markdown; Dependabot (`.github/dependabot.yml`) proposes weekly updates for actions, Go modules, pip and Docker images, and `godot-release.yml` opens an issue when a newer Godot stable is out (Godot pins are bumped by hand). macOS was dropped from CI on 2026-11-03 because hosted macOS runners repeatedly failed to start within the job timeout; at each milestone gate compare this Mac against a CI run instead: `sh tools/compare_local_traces.sh RUN_ID` (runs the suite with all three trace paths, downloads that run's Linux and Windows traces with `gh`, prints `REPLAYS MATCHED 1200` per scenario).

Local reference check (needs the retail backup, never runs in CI): `python3 tools/check_reference.py "/path/Command & Conquer Generals - Zero Hour.tar.gz"` compares Wargrid's unit, building, weapon and armor values with the pinned Zero Hour INI data; see [Zero Hour verification](reference/zero-hour-verification.md).

Test wrapper imports headlessly before tests, checks exit codes and engine diagnostics, then requires positive completion marker. `GODOT_BIN` accepts one executable path, including spaces. Both wrappers resolve project path from script location.

For separately authorized play: `sh tools/run_game.sh` opens the launcher (sidebar pages Play, Join, Settings and Credits: pick factions and a map, then start a skirmish against the bot or create or join an online match; real play uses Dry Wells, while opening `skirmish.tscn` directly, tests and benchmarks use the 48 × 32 `skirmish.json`, see [more maps](reference/more-maps.md)); `sh tools/run_game.sh res://scenes/skirmish.tscn` opens the M4 match directly (blue is you; controls below). It opens a window. Routine checks stay headless. Test builds send their version and commit (`game/build_commit.txt`, written by `run_game.sh`) as the online build, so both windows of a local online test must come from the same tree state: a commit or an edit between the two launches makes the relay refuse the second as a different version.

The ordinary suite ends with `TESTS PASSED <checks>`; current case and check counts live in the resume record of [M7 verification](reference/m7-verification.md), not here.

Rendered benchmark, separately authorized (opens a window): `sh tools/run_game.sh res://scenes/movement_benchmark.tscn`. It disables vsync itself (header shows `vsync=off`), uses 10 seconds wall-clock warmup and 60 seconds samples per layout at 1280×720/zoom 0.5, and reports tick timing, frame intervals, engine draw calls and 10-second backlog windows. First valid run 2026-11-03: frame p95 4.1/6.5 ms, zero backlog. Results and budgets: [performance ledger](reference/performance.md). While iterating, `-- --layout=<name>` runs one layout (about 90 s); see the ledger's [while iterating](reference/performance.md#rule-per-milestone) rule. The default run's fifth layout, `team2v2` (`-- --layout=team2v2` alone), is a four-bot 2v2 on Ashfall (seats 1 and 2 against 4 and 5, built bases, armies in contact from the first tick, so most of the fight falls in the warmup, the camera following the units) that fails only when the bots issue no orders or no shot lands in the sample window or a team has no units at its end; it has no frame budget and no draw-call ceiling, reports its numbers and prints `RENDERED TEAM2V2 PASSED 1` when it completes; a team2v2-only log is not recordable (`perf_record.py` wants the default run's `RENDERED BENCHMARK PASSED 4`).

Historical M0-M3 suite counts, CI links and visible-check notes: [development history](reference/development-history.md).

## Relay

The relay is a Go program in `relay/` (net/http + [gws](https://github.com/lxzan/gws), one goroutine per room), protocol-compatible to the M5 Kotlin/Ktor relay it replaced on 2026-11-05 (user decision after the [relay stack spike](reference/relay-stack-spike.md)). Go version: `relay/go.mod`. `tools/run_netplay.sh` and `tools/run_conformance.sh` build it themselves unless `WARGRID_RELAY_BIN` names a binary. Known difference from the Kotlin relay: an invalid tick is checked in the room goroutine, so a reply to a message sent right after it (e.g. a `pong`) can arrive before its `error`; Godot is unaffected.

```sh
(cd relay && go test -race ./... && golangci-lint run)   # unit tests, protocol vectors, lint (config relay/.golangci.yml)
sh tools/run_conformance.sh                               # black-box protocol suite (protocol/conformance), prints CONFORMANCE PASSED <cases>
sh tools/run_netplay.sh match                             # two headless Godot clients through a local relay
sh tools/run_netplay.sh rematch                            # same pair plays twice in one room (over, again, new seed)
sh tools/run_netplay.sh left-mid                           # seat 2 leaves at tick 600; seat 1 prints NETCLIENT VICTORY left
sh tools/run_netplay.sh proxy-burst                         # each seat behind tools/netfault: writes cut to 7 bytes, both held and released in a burst
```

The four `proxy-*` scenarios (`proxy-clean`, `proxy-burst`, `proxy-reset`, `proxy-blackhole`) start one `tools/netfault` per seat; the script builds it unless `WARGRID_NETFAULT_BIN` names a binary, and a failed run prints a repro line and the `NETFAULT` lines. `tools/netfault` has its own Go module (`cd tools/netfault && go vet ./... && go test -race ./... && golangci-lint run --config ../../relay/.golangci.yml`). The conformance suite has five profiles and ends `CONFORMANCE PASSED 69`; the CI netplay loop runs nineteen scenarios.

Spike knobs, all off by default: `WARGRID_SEATS` (seats per room), `WARGRID_BATCH_MS` (one newline-joined message per recipient per interval; the current Godot client cannot read it), plus the test-only `WARGRID_TEST_DELAY_MS`. Deadlines: `WARGRID_HELLO_MS` (5 s from connect to hello), `WARGRID_LOBBY_MS` (15 min, lobby and park limit) and `WARGRID_SILENCE_MS` (10 s in a running match); the conformance silence profile sets all three small. A set but non-integer knob exits with status 2.

Limits (on `main` since 2026-11-17, not deployed): `WARGRID_CLIENT_IP_HEADER` names the request header that holds the client address (for example `Fly-Client-IP`). Unset, which is the default and what fly runs today, the relay counts no addresses and applies only its global buckets; set, it also counts sockets and joins per address (numbers in [chapter 11](guide/11-multiplayer.md#the-relay)). `relay/fly.toml` stays unchanged: the variable is set with the approved deploy that runs the header check, 17 sockets each with its own forged header value, which must hit the cap of 16 (unverified: whether fly overwrites a client-sent header). Known limit, kept (user, 2026-11-17; revisit at M9 hosting, and name it before any public announcement): with the variable unset, one client sending more than about 20 `hello` messages a second on new sockets can drain the global join bucket and make real joins fail with `relay busy`. With the variable set, a socket whose header is missing or unparsable skips the per-address rules (Q26), and the relay logs `client ip header unusable, per-IP limits skipped` at most once a minute. New error reasons: `too far ahead` (lead bound), `too many connections`, `too many joins`, `relay busy` (all in [chapter 11](guide/11-multiplayer.md#the-relay)); `unknown match` replies are a burst of 10 refilling one per second, and past that the socket is closed without a reply (`relay/limits.go:18-19`).

Slow peers: a connection with more than 1 MiB waiting to be written is closed at once (log `write queue full, closing`) and its seat leaves, so a peer that reads slower than the room sends cannot exhaust the 256 MB machine (2026-11-12). With `WARGRID_BATCH_MS` the sender cuts a batch before it passes 64 KiB, so one batch alone no longer trips it.

Shutdown: on SIGINT (fly's default `kill_signal`) or SIGTERM the relay stops accepting connections, closes lobbies that have not started, lets started matches run for `WARGRID_DRAIN_MS` (default 3500; plus 1 s close grace stays under fly's default 5 s `kill_timeout`), then closes the rest; every room logs `MATCH END`. A second signal exits immediately. Hour-long matches do not survive a deploy; that drain is M9 ([relay scaling](reference/relay-scaling.md)).

Logs (`fly logs -a wargrid-relay`): one line per connection open/close, room created, seat joined, match start and end; a `DESYNC code=… tick=… groups=1|2` line (once per room) when the seats' hashes differ, a `lead bound` line for a refused frame, `limit rule=… refused=<n>` for the first and every hundredth refusal of a rule (each refused `hello` also logs `join rejected reason=…`), `client ip header unusable, per-IP limits skipped` at most once a minute when the client-IP header is set but unusable, and a `MATCH END` line with frames and bytes per seat, `seatN_max_frame` and `seatN_peak_bps` (bytes in the busiest tumbling second; it can under-report the true worst second, see [chapter 11](guide/11-multiplayer.md#the-relay)). None of these new lines carries an address; the older `connection closed err=…` line prints the library's error text, which for a network error may name the TCP peer (not checked on fly, where the peer is fly's proxy). No metrics endpoint: Prometheus metrics were built and removed again on 2026-11-08 (the relay is plain WebSocket forwarding; they come back from git history if the game shows problems); fly's built-in machine and proxy metrics remain on [fly-metrics.net](https://fly-metrics.net). Suspend: the proxy suspends the machine when it sees no requests; internet scanners that found the new domain through Certificate Transparency (126 404s in its first 40 min) resume it, in about 0.2–0.3 s. A metrics scrape did not keep it awake. Details in the [relay metrics design](superpowers/specs/2026-11-08-relay-metrics-design.md#result-2026-11-08).

### Hosting

fly.io, region `fra`, one shared-cpu-1x 256 MB machine that suspends when idle. Rooms live in memory, so deploy exactly one machine (`--ha=false`; `fly machine list` must show one). App `wargrid-relay` behind `wss://relay.wargrid.blackcindergames.com/ws`, the default from 0.19.0 (CNAME at the DNS registrar, Let's Encrypt cert issued by fly). The same app also answers at `relay.pdstuber.dev`, the default from 2026-11-08 to 0.18.0: keep its cert and DNS record while those builds are in use, because a WebSocket cannot follow a redirect. The old app `wargrid-relay-jvm` (named before the Go port; fly apps cannot be renamed) was destroyed after the 0.7.0 release (2026-11-08), so v0.6.0 clients can no longer play online.

Status: 2026-11-08: deployed as `wargrid-relay`; `https://relay.pdstuber.dev/health` ok, probe `RELAY WELCOME 77`. Release 0.7.0 (run 42472020039) deployed it through the workflow with the new deploy token; probe `RELAY WELCOME 71`. Release 0.8.0 (run 42480130047) redeployed relay and web; both `/health` answer 200. 2026-11-12: relay redeployed by hand from `7ac65c7` (write-queue cap; CI run 43198963251 green), `/health` ok, one machine; no WebSocket probe. 2026-11-26: fly cert and CNAME for `relay.wargrid.blackcindergames.com` issued; `/health` 200 and probe `RELAY WELCOME` on both hostnames. First deploy log of the old `wargrid-relay-jvm` app: [development history](reference/development-history.md).

Capacity: a shared vCPU's 6.25 % baseline holds about one 3v3 room ([relay scaling](reference/relay-scaling.md#flyio-vs-railway-measured-2026-11-0405)).

Cost: the fly organisation is on fly's legacy Hobby plan (user, 2026-11-05). Per [discontinued plans](https://docs.fly.io/about/discontinued-plans) (read 2026-11-05) it has "no monthly subscription fee" and keeps free allowances of "Up to 3 shared-cpu-1x 256mb VMs" and "100 GB North America & Europe" outbound. So the one relay machine costs nothing even when it runs all the time, and 100 GB covers roughly 120 hours a month of 3v3 play (about 220 KiB/s per room in JSON, [M5 findings](reference/m5-online.md#m9-list)).

Without the allowances, list prices ([pricing](https://fly.io/pricing.md)) are $2.53 a month for a started shared-cpu-1x 256 MB in `fra`, and $0.15 per GB of rootfs per month while stopped or suspended. Its "invoices under $5 are waived" applies to new users.

The bill itself was not read.

```sh
fly deploy relay -c $PWD/relay/fly.toml -a wargrid-relay --dockerfile $PWD/relay/Dockerfile --ha=false
godot --headless --path game -- --probe-relay wss://relay.wargrid.blackcindergames.com/ws   # prints RELAY WELCOME <ms>
WARGRID_RELAY_URL=wss://relay.wargrid.blackcindergames.com/ws WARGRID_MATCH_WAIT=600 sh tools/run_netplay.sh match
```

## Browser build

Single-threaded Godot web export (preset `Web`), served by static-web-server as its own fly app `wargrid-web` (`web/`), live at `https://wargrid.blackcindergames.com` since 2026-11-26 (CNAME at the DNS registrar, Let's Encrypt cert issued by fly). The first address, `https://wargrid.pdstuber.dev` (2026-11-06; its apex CAA records allow only Let's Encrypt), keeps its cert and CNAME and, from the first release deployed after 2026-11-26, answers with a 301 to the new host, path and query kept (`web/sws.toml`); `/health` answers on both. The image carries brotli/gzip copies made at build time and `Cache-Control: no-cache` (SWS answers `If-Modified-Since` with 304), so a redeploy cannot pair a new `.wasm` with an old `.pck`. No cross-origin isolation headers: they are only needed with threads. The page talks to the same relay over `wss://`. Playtest builds go to the separate app `wargrid-web-test` and share that relay; the relay only puts equal build strings in one room, so `main` carries a `-dev` version between releases. Prerelease builds accept `?relay=wss://…` to point the launcher at an experimental relay app; the host's join link carries it when it differs from the default.

```sh
sh tools/deploy_web.sh                     # export, then fly deploy; needs a release version and explicit approval
sh tools/deploy_web.sh test                # same, to https://wargrid-web-test.fly.dev; needs a -dev version and explicit approval
fly certs add wargrid.blackcindergames.com -a wargrid-web   # then CNAME wargrid -> wargrid-web.fly.dev
container build -t wargrid-web web         # local image check, after exporting to web/site/
```

Verified by the user 2026-11-06: Safari loads the live site and plays a skirmish against the bot. Verified by the user 2026-11-08 (perf-spike branch, `b12e821`): a mixed match through the live relay, WASM build in a browser on a MacBook Air against the native macOS build on a Mac mini, about 10 minutes with fighting on both sides, no desync (floats in WASM versus native: closed for macOS arm64). Unverified: a browser-to-browser match through the relay, Chrome and Firefox on the live site, and a hidden tab (browsers pause or throttle it, which stalls lockstep for everyone).

## Release

A pushed tag `v<version>` runs [`release.yml`](../.github/workflows/release.yml) (plan: [release workflow](superpowers/plans/2026-11-06-release-workflow.md), evidence: [release verification](reference/release-verification.md)):

1. On a branch `release-<version>`, set `config/version` in `game/project.godot` to `<version>`, commit, push, and wait for CI to pass; then fast-forward `main` to it and push. `main` otherwise only carries `-dev` versions, so tests that depend on the version first meet a release version here (0.11.0: N5 went red on `main`). The tag must equal `v` plus that value: the relay only lets clients with equal versions share a room.
2. Push the tag on that commit. The full CI workflow runs on that commit, then Linux, Windows, macOS and Web are exported and packaged.
3. Approve the `production` Environment. The job deploys the relay (`wargrid-relay`), checks `/health`, deploys the web build (`wargrid-web`), checks `/health`, then publishes the three desktop zips as a GitHub Release. Its notes are only the generated changelog link: replace them with hand-written player notes in the style of the previous release (`gh release edit v<version> --notes-file <file>`).
4. Bump `config/version` on `main` to the next `-dev` version (`0.12.0-dev` after 0.11.0), so local and test builds stay out of production rooms.

A prerelease tag (`v0.7.0-rc.1`) skips both fly deploys and publishes a GitHub prerelease only. A relay deploy ends matches in progress, so release when nobody is playing. Builds are unsigned; the first-start steps for players are in the [README](../README.md#play). Each zip's `README.txt` says so and links the source for its tag. Re-running a failed release redeploys both fly apps, which ends live matches again.

M5 measurements of the Kotlin relay and the native decision: [M5 verification](reference/m5-verification.md). Findings and M9 list: [M5 findings](reference/m5-online.md).

## After a merge

Run `sh tools/run_benchmark.sh` on `main`: it records itself on a clean `main` (`PERF_LABEL` forces a record elsewhere, `PERF_RECORD=0` turns it off; [performance ledger](reference/performance.md)); if the load average is above 2.5, say so and run it later. A `CEILING ALARM` line on `main` goes into wrap-up's Pending user action, so kickoff lists it in "Open for you" (report only, never a reason to loosen). If the merge changed `game/scripts/presentation/` or `game/scripts/match/` after the newest rendered row in `perf-history.csv`, a rendered rerun is owed: ask for the window in the same turn and record it (`python3 tools/perf_record.py <log> --label "<merge>"`); until it runs, kickoff lists it in "Open for you". The status table blocks in `README.md` and the ledger are generated: never hand-edit them; fix `docs/reference/perf-history.csv` or `tools/perf_chart.py` and rerun `python3 tools/perf_chart.py`.

## Local references

- EA source: `~/projects/CnC_Generals_Zero_Hour`; research Zero Hour under `GeneralsMD/`.
- User-owned game backups: `~/CnC`; leave `.tar.gz` files in place. See installation reference for archive selection.
- Tooling example: `~/projects/hells-verdict`; reuse choices are documented in blueprint §3. Specified wrapper and CI patterns adapted; no gameplay code copied.

- OpenRA (GPL-3.0-or-later): `~/projects/OpenRA`; reading for M5 lockstep (`OpenRA.Game/Network`: `OrderManager.cs`, `SyncReport.cs`) and M8 bot structure (`OpenRA.Mods.Common/Traits/BotModules`). Reported to have smarter bots; unverified.
- TheSuperHackers patched Zero Hour source: `~/projects/GeneralsGameCode`; cross-check for EA source and known retail bugs.
- Art-direction archive (not a git repo, not vendored): `~/projects/wargrid-art-archive/`; interview images, GPT's QA images, validation, provenance and handoff notes from the 2026-11-09 art-direction pack. The kept parts are in `docs/art-direction/`; see blueprint §2.
- Native macOS Zero Hour fork (GPL, never vendored): `~/projects/GeneralsGameCode-macOS`, local branch `wargrid-parity` (`eb595cfc9`, never pushed); engine for the [parity harness](reference/zero-hour-parity-harness.md).

These sibling projects and backups are research inputs, not future build/test dependencies. Keep original EA source and game assets outside Wargrid. Exact retail executable version, mod status and runtime behavior remain unverified.
