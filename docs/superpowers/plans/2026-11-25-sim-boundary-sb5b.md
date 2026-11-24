# SB5b Worker mode, the Web half: Implementation Plan

**Status** — Proposed for the night lane. Start only from an explicit handoff after SB5a merges.

**Goal** — A player can open the threaded test app from chat, choose inline or worker simulation for the next match, and hear combat normally. Production keeps its single-threaded Web export through the SB6 decision.

**Spec** — [Package cut and answer 12](../specs/2026-11-15-sim-boundary-design.md#package-cut), [SB5b gate](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18), [SB5a handoff](2026-11-22-sim-boundary-sb5a.md#evidence-to-move-from-sb5a-to-sb5b). Research inputs (private): `sb5-threads-2026-11-25.md` and `sb6-protocol-sketch-2026-11-25.md`.

## Labels

- **[owner]** records a dated scope or gate decision. **[proposed]** covers implementation choices, including names to settle on the merged tree.
- **[probe]** needs an observation from the actual export, browser or player. An empty evidence row stays open.

## Target revision

Inspected `608267eb`. P18 builds `SettingsPage` in `PauseMenu._settings_body()`. All three Web presets have `variant/thread_support=false`. Both deploy targets export `Web`, the Dockerfile copies `sws.toml`, and the tag workflow independently exports `Web` and deploys the default image. The pump on this revision runs inline.

Build on the merged SB5a revision. Task 1 records its SHA and checks all eight items under [Evidence to move from SB5a to SB5b](2026-11-22-sim-boundary-sb5a.md#evidence-to-move-from-sb5a-to-sb5b), including the worker suite, fault processes, mixed loopback, pins, bench rows, Deck rider disposition and reviews.

## One page

- **First playable slice.** Start a test skirmish inline. Open Esc → Settings → Game, enable “Simulation worker”, resume, then start another match. F3 changes to worker only in the new match. Turning it off reverses the choice on the next start, offline or online.
- **What would refute it.** A normal chat link stops at Godot’s feature error, loses the invite code, or requires a manual browser workaround. A fresh match still runs inline after opt-in, or combat audio breaks up after the first gesture.
- **Existing evidence.** The spike recorded “websocket connects and matches two clients under COEP” and a Firefox combat p50 cost of +4.7% open / +8.3% dense. Those measurements motivate separate binaries. The deployed chat routes and audio still need a player. [Spike results](../../reference/perf-spike-verification.md)
- **Out.** SB5a’s worker implementation, gameplay or protocol changes, production deployment/defaults and the SB6 go rule, thresholds and decision runs. SB5b supplies the Web probes SB6 will use.

## Global Constraints

- **[owner, 2026-11-18]** Threaded gameplay ships on the test app only until GO. The Web template fixes `OS.has_feature("threads")` at export. Without isolation or `SharedArrayBuffer` (SAB), the stock shell stops before GDScript. Worker-off selects inline execution *after* boot. [Godot feature switch](https://github.com/godotengine/godot/blob/4.7.2-stable/core/os/os.cpp#L586-L598) · [Stock shell](https://github.com/godotengine/godot/blob/4.7.2-stable/misc/dist/html/full-size.html#L154-L190)
- **[owner, 2026-11-15]** The preference is local, saved with other settings, usable offline and online, and takes effect at the next match or restart. Keep settings, browser clocks, storage and JavaScript on the main thread, outside tick inputs, snapshots, command logs and hashes. [Simulation interface](../../reference/sim-interface.md#pump-screen-side) · [Determinism rules](../../reference/determinism-rules.md#rules-for-new-simulation-code)
- Keep the existing prerelease/release guards before any staging cleanup. Preserve bundled notices, compression, revalidation, WebSocket join and existing security headers. Check a real static response for isolation. [Browser build](../../development.md#browser-build)

## Model routing and reviews

Sonnet builds Tasks 2, 4 and 5. Opus builds the Settings slice in Task 3. The coordinator owns base and gate evidence. Use Opus (high) per task touching the pump, netplay, HUD or input. After the owner’s match, get one fresh Opus whole-branch review, the [player-experience review](../../../.claude/agents/player-experience-reviewer.md) and Gemini 4 Neon (high) via `agy` for the netplay diff (record a missing tool or quota). Each new test names its failing production mutation. [Package rules](../../../AGENTS.md#how-a-package-runs)

## Decided for you

1. **[proposed] Two targets.** Test selects `Web Threads` + `web/sws.toml` with both isolation headers. Move the current header policy verbatim to `web/sws-production.toml` and make it the Dockerfile default. Local production and tag releases select `Web` + that default. Rollback on test selects the production pair on the *test app*. No extra Fly app or tag artifact.
2. **[proposed] Smallest fallback.** Record the stock diagnostic and the outcome of “Open in browser” on the same invite URL. Defer a fallback page and service worker. A playable HTML fallback would have to select between “two separate builds” before engine startup. [Emscripten pthreads](https://emscripten.org/docs/porting/pthreads.html#compiling-with-pthreads-enabled)
3. **[proposed] One preference.** Use a test-gameplay preset feature plus thread capability for visibility. Default off. Save a boolean in `[simulation]` in `user://settings.cfg`; retain the choice for the current session if storage is unavailable. The launcher starts with the worker off on a fresh profile. Keep the ordinary on/off control in Esc Settings.
4. **[proposed] Pools and audio.** Start with `threads/emscripten_pool_size=8` and `threads/godot_pool_size=4`. Leave headroom for audio and the sim thread. Keep current Web audio settings. Poll readiness across main frames because an unpooled pthread “will only run after you return to the event loop.” [Godot pool settings](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/doc_classes/EditorExportPlatformWeb.xml#L81-L88) · [Emscripten startup](https://emscripten.org/docs/porting/pthreads.html#special-considerations)

## Review Focus

1. Follow each artifact from preset through Docker’s actual `COPY` to the served policy, including the independent tag workflow. A test that compares two expected filenames can pass with a broken image.
2. Follow one click through save, new pump construction and effective F3 mode. A release build with the worker off still pays the threaded-template cost. Keep requested and effective modes distinct when SB5a latches a failure.
3. Keep the boot shell, starter handshake, isolated bench collector and player’s chat launch independently observable. A healthy server or a successful local benchmark cannot fill the attended rows.

## Same-tick and ordering cases

Toggle while a note is pending, then resume. The original pump drains in order and retains its mode. On rematch, stop the old pump before reading the preference for the new one. A failed worker’s latch still wins. An online peer keeps its own mode and command stream.

## Files

- Packaging — `game/export_presets.cfg`, `game/project.godot` (bench scene feature), `web/{Dockerfile,sws.toml,sws-production.toml}`, `tools/{deploy_web.sh,test_deploy_web.py}`, `.github/workflows/ci.yml`, `game/tests/test_map.gd`. Read `.github/workflows/release.yml` as a production caller.
- Settings and pump — `game/scripts/presentation/pause_menu.gd`, a small settings reader beside `game/scripts/match_settings.gd`, merged `game/scripts/match/{sim_pump,offline_driver,online_driver}.gd` and their existing screen/start callers. Tests in `game/tests/{test_pause_menu,test_sim_pump,test_online_scene}.gd`.
- Bench and evidence — merged `game/scripts/debug/match_bench*.gd`, `tools/{worker_ab.py,test_worker_ab.py,serve_web_bench.py}`, [verification](../../reference/sim-boundary-verification.md), [development notes](../../development.md#browser-build), guide chapters [05](../../guide/05-presentation.md), [12](../../guide/12-performance-and-platforms.md) and [13](../../guide/13-testing-and-tooling.md). Update interface/guide 11 if the online record contract changes.

### Task 1: Verify the SB5a handoff and settle the seams (Opus)

- [ ] **Entry check first.** Run `git rev-parse HEAD`, `sh tools/run_worker_digests.sh` (expect `WORKER DIGESTS MATCHED 4`), and match the eight SB5a evidence items to the merged revision. Missing executables or evidence mean park before editing.
- [ ] **[proposed] API assumptions.** SB5a selects the request from `WARGRID_SIM_THREAD=1` or a preset flag at pump construction, checks capability/latch, then exposes `driver.sim_mode()` and `pump.queue_stats()`. Inspect `rg -n 'worker_wanted|WARGRID_SIM_THREAD|sim_mode|queue_stats|func (adopt|start|create)' game/scripts`. Record actual signatures, precedence, Web startup call sites and the release-safe fault hooks. Use the landed equivalents in later tasks.
- [ ] Locate the SB5a Web-proxied-call audit, static warmers, bench record/parser and both replay readers. Verify `rg -n 'WORKER RUN|MATCH BENCH|room_refusals|age_ms|match_log\(|command_log\(' game/scripts tools`. Resolve schema names with the producer and consumer together. Park a missing worker contract with SB5a.

### Task 2: Pair each deploy with the right binary and headers (Sonnet)

- [ ] **Red first.** Extend the stubbed deploy tests to observe the actual export argv (preserve preset names with spaces), app, Docker build arg or default, and release workflow’s export and image. Resolve preset name → matching options section and Docker arg → copied TOML → `source = "**"` header table. Pin test to threaded/isolated and both production routes to single-threaded/neither header.
- [ ] Run `python3 -I tools/test_deploy_web.py`. The current test route must fail. Negative fixtures change one side at a time: threaded with neither header, inline with both, each missing header, wrong value (including `credentialless`), wrong glob and wrong Docker default. Assert the guard rejects each even when the Fly app name is correct.
- [ ] Copy the gameplay `Web` preset to `Web Threads`, add the test feature and `variant/thread_support=true`. Under the existing catch-all in `web/sws.toml` add `Cross-Origin-Opener-Policy = "same-origin"` and `Cross-Origin-Embedder-Policy = "require-corp"`. Add `ARG SWS_CONFIG=sws-production.toml` before the final-stage `COPY ${SWS_CONFIG} /sws.toml`.
- [ ] Route `test` to the threaded pair and `test-nothreads` to the rollback pair with the same prerelease guard and test app. The no-argument route and tag workflow use the production pair. Exercise refusal-before-cleanup and rollback in the stub. Build both Docker variants in the existing placeholder CI job. Keep CI’s no-threads template install and single tag artifact.
- [ ] Verify `python3 -I tools/test_deploy_web.py`, `sh tools/run_python_checks.sh`, `sh tools/run_shell_checks.sh`, `WARGRID_TEST_ONLY=test_exports_ship sh tools/run_tests.sh`. Update MP5/MP9’s exact inventory as presets land. Temporarily swap the test config to the production file, observe the real pairing test fail, then restore and rerun green.

### Task 3: Make Settings control the next match (Opus)

- [ ] **Red first.** Extend `test_pages_layout` and the Settings interaction tests before adding the row. Inject availability in the headless fixture. Test both visible and absent states using P18’s `BaseScene.HUD_SIZES` at 1280×720, 1280×800 and 1920×1080 (1280×720 logical there). Retain the ultrawide case, 16 px inset, no clipped/overlapping leaves, Back focus, three sliders, five original switches and exactly one extra when available.
- [ ] Run `WARGRID_TEST_ONLY=test_pause_menu sh tools/run_tests.sh`. Pin visible label “Simulation worker” and hint “Takes effect after a restart”, off by default, save on/off, reopen and reload from an isolated settings path. Cover a missing/invalid key, failed persistence and a production-like preset with saved true.
- [ ] Use `_settings_body()`’s Game section and P18’s switch/readback path. Capture the requested mode on main at each offline/online pump creation. On the test Web preset, the stored bool supplies SB5a’s request; a capable preset enables the *choice*. Native/headless keep SB5a’s flag and test overrides. Apply SB5a’s capability and failure guards once. Never write an environment variable or swap a running pump from the menu.
- [ ] Assert current mode before/after a click and next-pump mode in both directions, including online rematch, an outstanding note and `inline-fallback`. Verify `WARGRID_TEST_ONLY=test_sb5b_ sh tools/run_tests.sh` and the pause-menu suite again. A mutation reading the saved value on every tick or ignoring it on rematch must go red.

### Task 4: Web startup and the online replay copy (Sonnet)

- [ ] **Red first.** Hold worker readiness over two frame callbacks: the main loop must advance, startup must withhold job zero and driver reads until ready, and leaving before ready must prevent a late start. Cover timeout using SB5a’s deadline and failure path. Verify `WARGRID_TEST_ONLY=test_sb5b_start sh tools/run_tests.sh`.
- [ ] Adapt only the Web startup boundary if Task 1 finds a synchronous handshake. Advance it from the existing main-frame driver, including while connecting. Keep one owner, warm statics on main, count frames and elapsed ms, and prove normal, cancelled and timed-out starts. Release-export the static warm-up Callables in Task 5.
- [ ] **Red first, memory rider [owner, 2026-11-22].** Recheck all recorder readers on the merged P7/SB5a tree. Assert a mixed online replay retains commands once via `Lockstep.command_log()`, including host bot orders, after a multi-note drain and leave. Pin commands, end tick and digest. Also assert the online pump retains no growing duplicate and offline recording still replays identically. [SB5a owner answer 10](2026-11-22-sim-boundary-sb5a.md#owner-answers-user-2026-11-22)
- [ ] Remove only online long-lived command retention. Keep validation, sequence, per-note issued orders and digest sampling. Verify `WARGRID_TEST_ONLY=test_sb5b_ sh tools/run_tests.sh`, `sh tools/run_netplay.sh match`, `sh tools/run_netplay.sh rematch`, `sh tools/run_worker_digests.sh` and `sh tools/run_pump_faults.sh`.

### Task 5: Deliver the SB6 Web records (Sonnet)

- [ ] **Red first.** In `tools/test_worker_ab.py`, parse a posted log from each export. Removing isolation, build ID, effective mode, handshake or Wasm sample must invalidate the affected worker record. Make a requested worker that fell back distinguishable. Run `python3 -m unittest discover -s tools -p test_worker_ab.py`.
- [ ] Export local-only `Web Match Bench` (threads) and `Web Match Bench NT` (inline) with the bench scene feature, notices and `build_commit.txt`. Restore the bench’s same-origin `POST /result` to the existing local collector (204). Keep the gameplay test app on the launcher and fault injection confined to the bench preset.
- [ ] Emit `WORKER RUN <json>`, `DIGEST tick=<t> <hash>`, `UA <ua>` and `WORKER BENCH DONE|FAILED|TIMEOUT` in the posted body. Preserve SB5a timing, `age_ms`, queue cap/depth, refusals/streak and main wait count/total/max. Include export, build, requested arm, effective `sim_mode`, `online_cadence`, observed `isolated`, `start_handshake_frames` and `start_handshake_ms`.
- [ ] Record `wasm_mem_mb` (start/end/peak) from the active module’s current linear-memory buffer on main across `hordes300` and rematch. Sample anew after growth. Record `hidden_fps`/`hidden_tps` from elapsed time and counter deltas across visibility changes, including complete suspension. Missing observations stay explicitly unmeasured.
- [ ] In the threaded **release** bench, run one fresh page per injected owner-thread violation, stall, dead worker and script-error control. Emit `FAULT PROBE <cause> <ms> <pass|fail>` against the landed detector contracts. Record what the release build actually catches, including the debug logger’s blind spot. Preserve console evidence on timeout. SB6 owns the decision rows.
- [ ] Verify locally, with matching 4.7.2 release templates installed. Run exports sequentially (`export_build.sh` owns a shared commit stamp). Start the collector from the last line, then open each bench only in an approved browser session.

```sh
sh tools/export_build.sh 'Web Threads' build/sb5b/game/index.html
sh tools/export_build.sh 'Web Match Bench' build/sb5b/bench/threads/index.html
sh tools/export_build.sh 'Web Match Bench NT' build/sb5b/bench/nothreads/index.html
python3 -I tools/serve_web_bench.py build/sb5b/bench build/sb5b/results 8060
```

- [ ] Use `/threads/?driver=worker&load=hordes300` and `/nothreads/?driver=inline&load=hordes300` on the collector. Check 204, check digests across arms, and run `python3 -I tools/worker_ab.py report build/sb5b/results` plus the parser tests again. These are instrumentation smokes.

### Task 6: Gate the candidate and ask for the test deploy (coordinator, Opus)

- [ ] **First check for a false pass.** Remove one chat row or the listen observation from the evidence sheet. The attended gate must read pending. Reinstate only actual observations.
- [ ] On the candidate run `sh tools/run_checks.sh`, `sh tools/run_tests.sh`, `WARGRID_SIM_THREAD=1 sh tools/run_tests.sh`, and `PERF_LABEL="Sim boundary SB5b" sh tools/run_benchmark.sh`. Capture quiet logs, revision, exit and final markers/counts. For authorized CI compare Linux/Windows traces with `sh tools/compare_local_traces.sh "$RUN_ID"`. Batch the rendered rerun with the approved look: `sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, then `python3 tools/perf_record.py "$RENDER_LOG" --label "Sim boundary SB5b"` and `python3 tools/perf_chart.py`.
- [ ] **Approval point.** After the local pairing mutation, layout, both-mode suite and release-export checks pass, identify the exact prerelease SHA and ask the owner in the attended handoff to run **`sh tools/deploy_web.sh test`** for that candidate. The command matches the repository’s `ask` rule. Without approval the night stages local exports, records which browser/CI checks still need attendance, marks deploy/chat/listen pending, and takes its handoff backups. No direct Fly call or tag release.
- [ ] After approved deployment, GET the final HTTPS document and each emitted JS, worker/worklet, Wasm, PCK and other static asset. Inspect status, both policies, content encoding and revalidation. For example, `curl -fsS --compressed -D - -o /dev/null "$TEST_URL/index.wasm"`; reuse its Last-Modified in `curl -sS -D - -o /dev/null -H "If-Modified-Since: $LAST_MODIFIED" "$TEST_URL/index.wasm"` and require 304 with both headers. Check a missing static path for 404 with both headers. SWS 2.44.3 also handles successful static preflight and automatic directory redirects in the header path. Health, 405 and configured redirects bypass it. [Request handler](https://github.com/static-web-server/static-web-server/blob/v2.44.3/src/handler.rs#L235-L388)
- [ ] **Chat gate [owner, 2026-11-18].** Fill one row for each actual chat app/route used. Tap a fresh test invite from the conversation in normal settings. Record the natural handoff, isolation/SAB, threaded launcher and retained Join code, including with a severed `window.opener`. On failure record the exact stock error, then retry in the external browser as a separate observation. Include phone, desktop and Deck Firefox routes where used.

| App / OS / browser version | In-app or automatic external handoff | Isolated / SAB | Launcher / Join code | Manual recovery if needed | Result |
|---|---|---|---|---|---|
| Fill per actual route | | | | | Pending |

- [ ] **One listen check [owner, 2026-11-18].** On the deployed candidate, interact to enable audio, start a match with F3 showing worker, and listen to music plus overlapping orders/combat. Record device/browser, sounds heard and any silence, delay or crackle. Also try save/reopen in private browsing and record the session/reload boundary. A console line cannot establish audibility.
- [ ] File the chat/listen rows and SHA in the verification note, package state in `docs/STATUS.md`, and update affected guide footers. Close after the owner’s match, reviews and gate evidence. SB6 receives the build ID, probe logs and any failures.

## Stop conditions

Park for missing SB5a evidence, wrong production pair, digest drift, new main-thread startup stall, lost replay commands or a package budget overrun. Apply the [night stop rules](../../night-run.md#coordinator-rules) after two unsuccessful fix rounds. Keep blocked approvals and unrun probes visible.

A failed or missing real chat launch or listen check holds the production gate. An external-browser retry is diagnostic. If the owner wants the test app rolled back, ask separately for `sh tools/deploy_web.sh test-nothreads` at the named prerelease SHA. An SB5b pass supplies compatibility evidence only. Production switching requires SB6 GO.

## Review disposition

Plan checked against P18, the deploy script and tag workflow at `608267eb`. R1 corrects the earlier preflight/redirect note. R2 supplies the chat worksheet, R3 the two-target layout, R4 supports a single sim owner, and R5 identifies the moved Settings page and existing layout pins. Independent readiness and player-experience reviews are pending.

## For the owner

- **Test deployment approval** at Task 6. Prior default is a prerelease on the test app with an explicit deploy approval. Recommend approving the named test SHA once the local checks pass.
- **Attended evidence** at that deployment. The prior gate is each chat app actually used plus one listen. Recommend the normal invite path on each route and the existing ten-minute match for the audio check. Zero Hour has no Web deployment counterpart.
