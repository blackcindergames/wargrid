# P12 Notes that never block: verification

Plan: [P12 plan](../superpowers/plans/2026-11-17-p12-notes-that-never-block.md). Spec: [P12 design](../superpowers/specs/2026-11-17-p12-notes-that-never-block-design.md).

```text
Resume record (updated 2026-11-17)
Branch / base commit / working-tree state: p12-notes / 10d152c / Task 3 committed, clean
Last green task / next incomplete task: Task 3 (PO13, PO14 red by plan) / Task 4
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh / 1063 / 146353 / 6 (PO13, PO14) / 1 / -
Known red case or blocker: PO13 test_web_save_downloads, PO14 test_desktop_write_error_keeps_session, rewritten as exit tests in Task 4
Approved decisions, pre-authorizations used, deferred gates: attended day run (user, 2026-11-17); stop gate A passed (Firefox, Vivaldi); Chromium second-download prompt checked at gate 3; owner questions open: Saved footer after a failed write, tick vs mm:ss
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: Task 4 (Opus subagent)
```

## Web download probe (Task 1)

Godot's download routine, as exported in `build/web-bench/index.js` (Godot 4.7.2 web export):

```js
function _godot_js_os_download_buffer(p_ptr,p_size,p_name,p_mime){const buf=GodotRuntime.heapSlice(HEAP8,p_ptr,p_size);const name=GodotRuntime.parseString(p_name);const mime=GodotRuntime.parseString(p_mime);const blob=new Blob([buf],{type:mime});const url=window.URL.createObjectURL(blob);const a=document.createElement("a");a.href=url;a.download=name;a.style.display="none";document.body.appendChild(a);a.click();a.remove();window.URL.revokeObjectURL(url)}
```

The probe (`build/p12-probe/`, untracked) copies it from `new Blob` to `revokeObjectURL` with the three `GodotRuntime` lines replaced by a JSON string, a file name and a mime type. `index.html` downloads `probe-1.json` from its load handler and `probe-2.json` 2 s later from a `setTimeout`; `embed.html` holds `index.html` in an iframe.

## Evidence

| Date | Task | Check | Tree | Result |
| --- | --- | --- | --- | --- |
| 2026-11-17 | 1 | `python3 -m http.server 8061 --directory build/p12-probe`, `curl` on `index.html` and `embed.html` | `p12-notes`, `10d152c` | 200, 200 |
| 2026-11-17 | 1 | stop gate A, Firefox, `index.html` (top level) | probe | download 1 and download 2 saved silently, no prompt |
| 2026-11-17 | 1 | stop gate A, Firefox, `embed.html` (iframe) | probe | download 1 and download 2 saved silently, no prompt |
| 2026-11-17 | 1 | stop gate A, Vivaldi (Chromium; Chrome is not installed on the Mac), `index.html` | probe | with Vivaldi's "ask where to save" setting on: a save dialog for each download (a browser setting, also shown for clicked downloads). With "Always Save Files to Default Download Location" ticked: download 1 saved silently; download 2 held behind "would like to allow the download of multiple files" (Allow/Deny) |
| 2026-11-17 | 1 | stop gate A, Vivaldi, `embed.html` served from `127.0.0.1` (a fresh origin, so the localhost prompt does not carry over) | probe | download 1 saved silently; download 2 held behind the same multiple-files prompt; after Allow (clicked about 2 min later) the held download 2 saved |
| 2026-11-17 | 1 | gate A ruling | - | top-level download 1 saved without a prompt in Firefox and Chromium: Task 4's web steps proceed as designed. Known limit: Chromium prompts for a second automatic download in the same page; whether a click in between resets it is unverified and checked at gate 3 (test app). Safari and Chrome itself untested. `build/p12-probe/` deleted |
| 2026-11-17 | 2 | baseline `sh tools/run_tests.sh` | `p12-notes`, `9fced9f` | CASES 1039 CHECKS 146770 FAILURES 0, exit 0 |
| 2026-11-17 | 2 | red `WARGRID_TEST_ONLY=test_playtest.gd`, NB1-NB8 and rewrites against the old `playtest_session.gd` | `9fced9f` plus Task 2 tests | exit 1, 8 parse errors (`add_marker`/`set_checked` arity), as the plan predicts; reconstructed by reverting the implementation, not captured test-first |
| 2026-11-17 | 2 | red `test_unfinished_match` against the old tool | `9fced9f` plus Task 2 | FAIL test_unfinished_match (7 run, 1 failure); reconstructed the same way |
| 2026-11-17 | 2 | write cost (`build/p12_write_cost.gd`, scratch): five markers of 131072-character jpg (656 KB file), 20 `add_marker` writes | `9fced9f` plus Task 2 | median 1526 µs, max 1562 µs (limit 4000 µs median). Informational: growing to 24 markers (3.1 MB) gives median 5546 µs, max 8765 µs |
| 2026-11-17 | 2 | Codex review (gpt-6-astra high) of the Task 2 diff | `9fced9f` plus Task 2 | 2 important, 3 minor. Fixed: NB7 could not fail if `settle` ignored `current` (new check: an open sitting with no stored file is filed on a build change; red with the `current` branch removed, green restored); `_store` now returns `store_string`'s result (an untestable short write no longer counts as filed). Ruled, not fixed: a same-second `started` collision of two web copies (a sitting needs a manual entry, so two in one second do not happen); `filled()` without the key in memory (every in-memory session carries the flag; `_stored()` derives it for 0.13.x files); a record carrying `unfinished` (`_match_record` never sets it); the Python test does not pin the `.get("end_digest")` path for a finished match |
| 2026-11-17 | 2 | `run_lint.sh`, `run_warnings.sh`, `test_sim_boundary.py`, `run_python_checks.sh` | `9fced9f` plus Task 2 and review fixes | exit 0 each |
| 2026-11-17 | 2 | full `sh tools/run_tests.sh` | `9fced9f` plus Task 2 and review fixes | CASES 1047 CHECKS 146799 FAILURES 2, exit 1: both in PO17 `test_restart_drops_pending_markers` (Task 3 inverts it); simulation/net/relay/protocol diff empty |
| 2026-11-17 | 3 | red `WARGRID_TEST_ONLY` test_playtest_overlay and test_online_scene, Task 3 tests on the old code | `eb39843` plus Task 3 tests | exit 1 each: suites fail to compile (`Too many arguments for "setup()"`); captured before implementing |
| 2026-11-17 | 3 | red per case, PO23's `setup` made a dynamic call for this run only | `eb39843` plus Task 3 tests | overlay CASES 30 FAILURES 48 (PO9-PO12, PO15, PO18, RA7, PO20-PO22, PO24-PO27; PO23, PO28 script errors); online FAILURES 1 (N35); already green: inverted PO17, N14, N31, R2 |
| 2026-11-17 | 3 | mutations: click release removed from `match_screen._unhandled_input`; Esc release removed from overlay `_input` | `eb39843` plus Task 3 | PO25 red (2 of 4 checks), PO26 red (2 of 3); restored |
| 2026-11-17 | 3 | Codex review (gpt-6-astra high) and player-experience review of the Task 3 diff | `eb39843` plus Task 3 | fixed test-first: modifier shortcuts (Ctrl/Cmd+S, Ctrl+1, Cmd+E) leaked from a focused field into orders (PO29); arrow keys panned the camera while typing (PO30); a world click took focus from the marker dialog's text (PO31); one empty state "No markers yet (N adds one)", "Last match" only with markers (PO35). Added guards that passed before any fix: panel shrinks after a resize (PO32, SubViewport only), focused unsaved text survives rebuilds (PO33), Enter in a field then Enter plays again (PO34). Tab from the last field wraps to the first (probe, no fix). Ruled, not fixed: a `driver.record` call-count guard for PO28, a helper-off PO17 variant, score unpress. Owner questions: "Saved" footer after a failed write, tick vs mm:ss in marker rows |
| 2026-11-17 | 3 | red review tests before the fixes | `eb39843` plus Task 3 plus review tests | overlay CASES 38 FAILURES 13: PO13 x3, PO14 x3, PO29 x2, PO30, PO31, PO35 x3 |
| 2026-11-17 | 3 | `WARGRID_TEST_ONLY` online_scene, playtest.gd, skirmish_scene; lint, warnings, boundary | `eb39843` plus Task 3 and review fixes | exit 0 each (62/3088/0, 24/287/0, 58/328/0); lint, warnings, boundary exit 0; simulation/net/relay/protocol diff empty |
| 2026-11-17 | 3 | full `sh tools/run_tests.sh` (coordinator rerun) | `eb39843` plus Task 3 and review fixes | CASES 1063 CHECKS 146353 FAILURES 6, exit 1: only PO13 x3 and PO14 x3 (moved to the exits in Task 4); no SCRIPT ERROR |
