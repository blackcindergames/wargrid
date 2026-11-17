# P12 Notes that never block: Implementation Plan

**Status:** approved by the user 2026-11-17 after a fresh Opus readiness review; attended day run in a fresh session (user, 2026-11-17); not started. Writing or approving this plan does not start implementation.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md): one fresh subagent per task, each starting from the resume record in `docs/reference/p12-verification.md`.

**Goal:** The playtest helper's form becomes the ` panel: checklist, questions and markers, open at any time, never pausing or blocking play, with no action buttons. It saves itself, markers survive a crash or a closed tab, and the record is filed on every exit (desktop) or downloaded when the launcher opens (web), only if something was filled in.

**Architecture:**
- `PlaytestSession` keeps the running match as an unfinished last entry of `data.matches`, which replaces `_pending`. It also gets a `filled` flag and one static `close_sitting()` that every exit calls.
- `playtest_overlay.gd` builds a single scrolling panel from the row builders that move out of `session_form.gd`, and `holds_match()` shrinks to the marker dialog.
- `match_screen.gd` and `launcher.gd` call `close_sitting()` from both Quit buttons and the window-close notification. The launcher also calls it on open (web) and on a card pick.

**Tech Stack:** Godot 4.7.2 typed GDScript, suite runner `game/tests/run_tests.gd`, Python 3 tool `tools/playtest_session.py`. No simulation, relay or protocol change.

**Spec:** [P12 design](../specs/2026-11-17-p12-notes-that-never-block-design.md) (approved by the user 2026-11-17; every decision is final). Answers: [design answers](../../reference/design-answers-2026-11-08.md#p12-notes-that-never-block-questionnaire-user-2026-11-17). Package row: [packages](../../packages.md#day-lane) P12, [F22](../../STATUS.md#findings-list). P1 helper design: [packages and playtest helper](../specs/2026-11-11-packages-and-playtest-helper-design.md).

## Global Constraints

- **Branch:** `p12-notes` from `main` at the commit holding this plan, in `~/projects/wargrid`. The coordinator creates `docs/reference/p12-verification.md` (resume record plus an evidence table, the [p2.2 verification](../../reference/p2.2-verification.md) layout) and commits it as the first local commit on the branch; the spec, this plan and the design answers are already on `main`.
- **Don't touch:**
  - `game/scripts/simulation/`, `game/scripts/net/`, `relay/` and `protocol/`;
  - the command, replay and trace formats; `snapshot()`; pinned digests;
  - `SimPump` and both drivers' `record()`.

  `git diff <base> -- game/scripts/simulation game/scripts/net relay protocol` stays empty.
- **Session format:** `format` stays 1, and the new fields are additive: `filled` on the session, and `unfinished` plus `result: "unfinished"` and `commands: []` on a cut-short match. A 0.13.x `current.json` must keep its answers.
- **Helper scope:** it is on by default only in `-dev` builds (`playtest/playtest_settings.gd`). With the helper off (`PlaytestSettings.enabled()` false), no new code path writes, deletes or downloads anything: `test_helper_off_changes_nothing` stays green and gains the exit checks (Task 4).
- **Copy (spec):** "Last match"; "Saved" plus the time; "Notes downloaded: %s" (web). **Agent wording:** "This match"; "Saved %s" with `HH:MM` from `Time.get_time_string_from_system().left(5)`; "Notes saved to %s" (desktop); panel title `"%s  (%s)"`, the card title plus the key label. The player-experience reviewer may change agent wording only.
- **Code style:** typed GDScript, one-line WHY comments only. Edit with the Edit tool or asserted replacements only. Scratch Godot scripts `quit()` on every path and live under `build/`, never tracked.
- **Subagents** never commit, push, merge, deploy or open a window. Commit steps are the coordinator's (local commits pre-authorized by the milestone prompt). Task 1's browser check opens windows only at stop gate A with the user present.
- **Running checks:** every suite, lint, check and benchmark call gets `timeout: 600000`, sends its output to a file under `build/` and is judged by exit code; on failure read only the failing lines. While iterating: `WARGRID_TEST_ONLY=<substring> sh tools/run_tests.sh > build/<name>.log 2>&1; echo exit=$?`.
- **Per-task gate:** `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, the task's `WARGRID_TEST_ONLY` runs and `python3 tools/test_sim_boundary.py`. The full `sh tools/run_tests.sh` (about 78 s) runs at Tasks 2, 4 and 5; `sh tools/run_python_checks.sh` runs at Task 2.
- **Public repo:** home-relative paths, no hostnames, no personal details.

## Review Focus

1. **Text in a focused field when the window closes:** the text is in the written file, and the sitting counts as filled even if that text is its only content. Test NB9 (Task 4).
2. **A 0.13.x `current.json` (no `filled`, older build id) at the first start of the new build:** it is filed, not deleted, so the owner's answers survive. Test NB6 (Task 2).
3. **A field focused, then a click on the battlefield, then a hotkey:** the order fires. Before the fix the field would silently eat the hotkey. Test PO25 (Task 3).
4. **Esc in a field:** it releases the field and saves it, and the pause menu stays closed; a second Esc opens the pause menu. Test PO26 (Task 3).
5. **A failed desktop write at quit:** the quit still happens, `current.json` keeps everything, and the next start resumes it. Test NB10 (Task 4).

## Same-tick interactions

None. No new command and no simulation change; the spec rules them out ("presentation and tooling only"). The cases that matter happen in the same frame as input (a key while typing, a click while a field has focus, Enter on the result panel while typing). They are covered by PO23 to PO27.

### Task 1: Web download probe (then STOP GATE A)

Spec risk 1 can kill the web half of the design, so this task runs first. Tasks 2 and 3 do not depend on it and may run while gate A waits. Task 4's web steps wait for the gate.

**Files:**
- Create (untracked): `build/p12-probe/index.html` and `build/p12-probe/embed.html`.
- Modify: `docs/reference/p12-verification.md` (a probe section).

**What the probe does:**
- `index.html` calls a copy of Godot's own download routine in its load handler. That routine is `_godot_js_os_download_buffer` in `build/web-bench/index.js`: a Blob, an object URL, a hidden `<a download>`, then `click()`. Copy the routine byte for byte from `new Blob` to `revokeObjectURL`. Replace its three `GodotRuntime` lines with a JSON string, a file name and a mime type. Quote the copied function in the verification file. The page downloads `probe-1.json`, then `probe-2.json` from a `setTimeout` 2 s later, and shows on the page what it attempted.
- `embed.html` holds `index.html` in an `<iframe>`.
- Serve the folder with `python3 -m http.server 8061 --directory build/p12-probe`.

- [ ] **Step 1:** Write both pages and check them with `python3 -m http.server` plus a `curl -s -o /dev/null -w '%{http_code}' http://localhost:8061/index.html` call: expect 200. Record the result.
- [ ] **Step 2: STOP GATE A** (the coordinator, with the user, in one window batch). Open `index.html` and `embed.html` in Firefox and Chrome on the Mac (`open -a Firefox <url>`, `open -a "Google Chrome" <url>`). For each of the four cases, record what happened to download 1 and download 2: saved, blocked, or a prompt shown.

  **Rule:**
  - if download 1 is saved without a prompt in Firefox and Chrome in the top-level page, Task 4's web steps proceed as designed;
  - if only the iframe case fails, record that as a known limit for embedded hosting;
  - if the top-level case fails anywhere, stop and bring the fallback to the user before Task 4's web steps. The fallback is a download on the first click in the launcher. The user decides.

  Delete `build/p12-probe/` after the gate.

### Task 2: Session model, filled flag and the Python tool

**Files:**
- Modify: `game/scripts/playtest/playtest_session.gd`, `game/scripts/playtest/focus_cards.gd` (`shown` :79-81), `tools/playtest_session.py`, `tools/test_playtest_session.py`.
- Test: `game/tests/test_playtest.gd`: rewrite `test_session_schema` :327, `test_session_web_download` :347, `test_session_web_backup_fails` :367, `test_session_desktop_write` :379 and `test_session_resumes_after_restart` :394; add NB1-NB8.

**Interfaces:**
- Produces, on `PlaytestSession`:
  - **Matches:**
    - `func start_match() -> void` replaces `clear_pending()` and forgets the running entry (`_live = -1`).
    - `func add_marker(marker: Dictionary, header: Dictionary) -> void`: when `_live < 0`, it appends `header.merged({"unfinished": true, "result": "unfinished", "commands": [], "markers": [], "end_tick": 0})` and sets `_live`. It then appends the marker, sets `end_tick` to the marker's tick, sets `filled` and writes `current.json`. `header` holds `mode`, `map`, `seed`, `factions`, `seat` and `build`.
    - `func finish_match(record: Dictionary) -> int`: it replaces the `_live` entry when there is one, keeping its `markers` (comments included); otherwise it appends with `markers: []`. The result has no `unfinished` key. It sets `_live = -1` and `last_match = index`, writes `current.json` and returns the index.
    - `func marker_match() -> int`: `_live` if it is ≥ 0, else `last_match` (−1 when neither exists).
    - `var last_match: int = -1`: the newest entry finished in this run.
  - **Edits:**
    - `func set_comment(match_index: int, marker_index: int, text: String) -> void` and `func set_answer(question_id: String, score: int, text: String) -> void` are unchanged in effect. Each also sets `filled` when the text is non-empty or the score is above 0.
    - `func set_checked(item_id: String, on: bool, manual: bool) -> void`: only `manual` sets `filled`.
  - **Filled:**
    - `func filled() -> bool`: `data.filled` when the key exists.
    - Without the key it is derived from the contents: any answer with a score above 0 or non-empty text, any match with markers, or any ticked checklist item.
    - A new sitting starts with `"filled": false` (`resume_or_open`, `playtest_session.gd:17`), so only legacy files take the derived path.
  - **Saving and ending:**
    - `var saved_at: String = ""`: `HH:MM`, set by every successful `current.json` write.
    - `static var last_filed: String = ""`: the desktop path or the web file name of the last successful `close_sitting()` in this run. Both suites' `_begin` and `_end` reset it.
    - `static func close_sitting(web: bool, download: Callable) -> void` acts on `current`, else on the stored `current.json`, else does nothing:
      - filled: `write(web, download)`; on success it sets `last_filed`;
      - not filled: `discard()`.

      A failed write leaves `current.json` and `current` in place and never raises.
    - `write(web, download)`: the web copy goes to `"last-session-%s.json" % started` (colons replaced, as in `file_name`), never overwritten. The `LAST` constant goes away.
    - `static func settle(build: String, web: bool, download: Callable) -> void`: it calls `close_sitting(web, download)` when the open or stored sitting's `build` differs from `build`, or when `web` is true and the sitting is filled. It checks `current` first and then the stored file, so a sitting still open in this run counts.
- Produces, on `FocusCards.shown() -> String`: `chosen` if it is not empty, else `PlaytestSession.open_focus()` if that is not empty, else `""` (so `card()` falls back to the first card).
- `pending_markers()` and `_pending` are deleted; tests that used them read `data.matches[marker_match()].markers`.
- `tools/playtest_session.py`: `end_digest` is optional (`.get`), a match with `unfinished` prints `(unfinished)` after its result, and `--replay-args` skips unfinished matches with a stderr note. `format` stays 1.

- [ ] **Step 1: Failing tests** in `test_playtest.gd`. Each test redirects `PlaytestSession.dir` the way the existing session cases do.
  - **NB1 `test_marker_written_mid_match`:** after `add_marker(m, header)`, `current.json` parsed from disk has one match with `unfinished == true`, `result == "unfinished"`, `commands == []`, `end_tick == m.tick` and one marker. A second marker updates `end_tick`. Red if `add_marker` only buffers, or if `end_tick` stays 0.
  - **NB2 `test_finish_replaces_unfinished`:** with two markers, a comment on marker 0, then `finish_match(record)`: one entry on disk, no `unfinished` key, two markers, the comment kept, `end_digest == record.end_digest`. Without markers, `finish_match` appends with `markers == []`. Red if a second entry appears or the comment is lost.
  - **NB3 `test_restart_keeps_cut_short_entry`:** add a marker, `start_match()`, add a marker: two entries, the first still `unfinished`. Red if `start_match` drops or overwrites the first.
  - **NB4 `test_filled_rules`:** a fresh session is not filled; `set_checked(id, true, false)` is still not filled; `set_checked(id, true, true)` is filled. Separately: `set_answer(id, 0, "")` is not filled, `set_answer(id, 3, "")` is filled, `set_comment(.., "x")` is filled, and a marker is filled. Red if the trigger path fills.
  - **NB5 `test_close_sitting_unfilled_leaves_nothing`:** a session with only a trigger tick → `close_sitting(false, dl)` → no `session-*.json`, no `current.json`, `dl` never called, `current == null`.
  - **NB6 `test_legacy_current_is_filed`:** write a 0.13.x-shaped `current.json` (no `filled`, `build` "0.13.0-dev", one answer with score 4) → `settle("0.14.0-dev", false, dl)` → a `session-*.json` exists with the answer, and `current.json` is gone. The same file shape with no answers, no markers and no ticks → deleted, no file. Red if a missing `filled` reads as false.
  - **NB7 `test_settle_rules`:**
    - same build on desktop: the sitting stays open;
    - a different build: filed;
    - web with the same build and filled: downloaded once, `last-session-<started>.json` stored, `last_filed` is that name;
    - web and not filled: the sitting stays open.

    Run the check against an open `current` and again against a stored file only. Red if `settle` ignores `current`.
  - **NB8 `test_web_copies_never_overwritten`:** two web sittings with different `started` → two `last-session-*.json` files.
  - **Rewrites:** the five existing session cases are adjusted to the new API: `test_session_web_backup_fails` keeps the sitting open, and `test_session_resumes_after_restart` resumes an unfinished entry with its flag.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=test_playtest.gd` → red; record. Until Step 3 adds the API this is a parse error, not case failures, because `run_tests.gd:6` preloads every suite.
- [ ] **Step 3:** Implement per Interfaces. Update the callers of the old API just enough to compile; Task 3 rewrites the overlay.
  - In `playtest_overlay.gd`: `start_match` in `begin_match`; `add_marker(marker, {})` until Task 3 passes the header; `set_checked(.., false)` at :143 and `set_checked(.., true)` at :158.
  - In `game/tests/test_playtest_overlay.gd`: `add_marker(m, {})` at :566 and :613. Replace `pending_markers()` (:130, :162, :203, :659, :664) with `data.matches[marker_match()].markers`, or with `data.matches.is_empty()` where the case expects no markers (PO5, :203).
- [ ] **Step 4: Python.**
  - Add `test_unfinished_match` to `tools/test_playtest_session.py`: a session whose second match has `unfinished: true`, no `end_digest` and `commands: []`. The printout contains `(unfinished)`, `--replay-args` lists only the first match, and `load_session` does not raise.
  - Run it red, then make the change.
  - `sh tools/run_python_checks.sh > build/py.log 2>&1; echo exit=$?` → exit 0.
- [ ] **Step 5: Write cost (spec risk 2).**
  - Write a scratch script `build/p12_write_cost.gd`, run with `godot --headless --script` through the project's Godot wrapper as `tools/run_tests.sh` does, with `quit()` on every path.
  - It sets `PlaytestSession.dir = "user://p12-write-cost"` and removes that folder on exit, so the owner's real `current.json` is never touched.
  - It builds a session with five markers, each with a 131072-character base64 `jpg`, and times 20 `add_marker` writes with `Time.get_ticks_usec()`.
  - Record the median and the maximum in microseconds, with the tree, in the verification file. No assert. If the median is above 4000 µs (a quarter of a 60 Hz frame), stop and report: do not change the design.
- [ ] **Step 6:** `test_playtest.gd`, `test_playtest_overlay.gd` (expected red until Task 3; record which cases), lint, warnings, boundary. Then the full suite. Every failure must be one of the overlay cases Task 3 rewrites: list them. Commit `Keep playtest markers mid-match and file only filled sittings`.

### Task 3: The panel: one ` panel that never holds the match

**Files:**
- Modify:
  - `game/scripts/playtest/playtest_overlay.gd`: the whole flow, `_build_form` :163-175, `holds_match` :89, `_input` :119-132, `end_match` :59-63, `begin_match` :72-78 and `_build_checklist` :145-161;
  - `game/scripts/playtest/session_form.gd`: becomes the row builder;
  - `game/scripts/match/match_screen.gd`: `_add_playtest` :116-123 gains the header callable, `_unhandled_input` :272 gains the focus release, `playtest_match` :141 is unchanged, and `playtest_header()` is new.
- Test: `game/tests/test_playtest_overlay.gd`, `game/tests/test_online_scene.gd` (N14, N31, N35) and `game/tests/test_skirmish_scene.gd` (R2).
  - Rewrite: `test_leave_flow` :351, `test_match_end_opens_review_once` :383 (PO11, `reviewing()` at :406, :409), `test_back_to_menu_from_result_panel` :416 (PO11b), `test_leave_after_closed_sitting` :437, `test_two_match_session_file` :458, `test_form_layout` :601, `test_restart_drops_pending_markers` :652 (inverted, below), `test_scale_legend` :669 and `test_sb2_review_form_and_pending_answer` :710.
  - Add PO20-PO28.
  - **The marker dialog is now the only hold.** Replace `_form.show()/hide()` with `_dialog.show()/hide()` in:
    - `test_skirmish_scene.gd:594-597` (R2);
    - `test_online_scene.gd:242-245` (N14 `test_play_again_sends_once`);
    - `test_online_scene.gd:1098` (N31 `test_leave_panel_yields_focus`);
    - `test_online_scene.gd:1168` (N35).
  - Recheck PO8 `test_overlay_layout` (:274) against `HUD/Economy`.
  - Task 4 moves `test_web_save_downloads` :518 and `test_desktop_write_error_keeps_session` :540 to the exits.

**Interfaces:**
- Consumes the Task 2 API: `start_match`, `add_marker(marker, header)`, `finish_match`, `marker_match`, `set_checked(.., manual)`, `saved_at`.
- `session_form.gd` keeps `SCORES` and `SCALE_LEGEND`, and becomes:

  ```gdscript
  static func add_question(parent: VBoxContainer, session: PlaytestSession, question: Dictionary) -> void
  static func add_markers(parent: VBoxContainer, session: PlaytestSession, match_index: int) -> void
  static func add_action(parent: Control, button_name: String, label: String, target: Variant) -> Button  # unchanged
  ```

  `add_action` is still used by the marker dialog. The signals, `open_review`, `open_questions`, `show_saved` and the `PanelContainer` base go away; the file becomes `extends RefCounted`.
  - Score buttons and kind buttons get `focus_mode = FOCUS_NONE`.
  - Comment and answer `LineEdit`s no longer save on `text_changed`. They save on `text_submitted`, which also calls `release_focus()`, and on `focus_exited`.
  - Node names stay `Comment_<m>_<k>`, `<id>_<n>` and `Answer_<id>`.
- `playtest_overlay.gd`:
  - **`setup`:** `func setup(card: Dictionary, context: Callable, record: Callable, header: Callable) -> void`.
  - **The panel:**
    - it keeps the node name `Checklist` (the layout and trigger tests use it) and becomes a `PanelContainer` holding a `ScrollContainer` (horizontal scroll disabled) with a `VBoxContainer` named `Rows`, plus a `Label` named `Saved` below the scroll;
    - `CHECKLIST_WIDTH` stays 320;
    - the panel's height is at most `0.6 * get_viewport_rect().size.y`. After every rebuild and on the viewport's `size_changed`, set `scroll.custom_minimum_size.y = minf(rows.get_combined_minimum_size().y, 0.6 * viewport height - Saved height - panel margins)`; a `ScrollContainer` reports no minimum height of its own, so without this the panel collapses.
  - **Rows, in order:**
    - title `"%s  (%s)" % [card.title, key_label]`. The label is `KEY_QUOTELEFT` when `DisplayServer.get_name() == "headless"` (as `match_screen.gd:103` checks), else `DisplayServer.keyboard_get_label_from_physical(CHECKLIST_KEY)`. It shows as `char(label)` when the label is a printable code below 128, else as `OS.get_keycode_string(label)`;
    - the checklist `CheckBox`es (as today, `FOCUS_NONE`; a toggle calls `set_checked(id, on, true)`);
    - `SessionForm.add_question` per card question, then the `ScaleLegend` label;
    - a `MarkersTitle` label, "This match" or "Last match";
    - `SessionForm.add_markers(..., session.marker_match())`, or no rows when that is −1.
  - **Rebuilds:** the rows are rebuilt on `_open_session`, `begin_match`, `save_marker` and `end_match` only, never per frame. A rebuild first calls `get_viewport().gui_release_focus()` when the focus owner is inside `Checklist`, so a focused field saves before it is freed.
  - **The marker label:** "This match" while the running match has markers or the match just ended; "Last match" after `begin_match` until the new match's first marker.
  - **`Saved`:** it shows `"Saved %s" % session.saved_at`, hidden while `saved_at` is empty, and refreshes after each write.
  - **`holds_match() -> bool`:** returns `_dialog.visible`. `reviewing()` and `_form` are deleted.
  - **`end_match()`:** `cancel_marker()`, `_record_match()`, rebuild, `_checklist.show()` without any `grab_focus`.
  - **`begin_match()`:** `_reviewed = false`, `session.start_match()`, rebuild; visibility unchanged.
  - **`save_marker`:** passes `header.call()` to `add_marker`.
  - **`_input`:** the `_dialog.visible` branch stays first, as today (`playtest_overlay.gd:124-126`: Esc cancels the marker). After it, while a panel field has focus (the focus owner is a `LineEdit` inside `Checklist`):
    - Esc calls `get_viewport().gui_release_focus()` and marks the input handled;
    - every other key returns early: no toggle, no marker, no `_tick_triggers`.
    - Otherwise as today: ` toggles `_checklist`, N opens the marker, and other keys tick `key:` triggers through `set_checked(id, true, false)`.
  - **`_tick_triggers`:** calls `set_checked(id, true, false)`.
  - **A focused field** shows a focus style that differs from its `normal` style (`UiStyle.hud_theme()`; add a `LineEdit` `focus` stylebox there only if the theme has none).
- `match_screen.gd`:
  - **`func playtest_header() -> Dictionary`:** `{"mode", "factions"}` from `driver.match_log()`, plus `map`, `seed`, `seat` and `build` as in `_match_record`, with no `driver.record()` call (no digest mid-match).
  - **`_unhandled_input`:** before `orders.handle(event)`, a pressed left or right `InputEventMouseButton` (not the wheel) while `_typing()` calls `get_viewport().gui_release_focus()`. The event then continues to `orders.handle` as usual.

- [ ] **Step 1: Failing tests** in `test_playtest_overlay.gd`, using its `_begin`, `_scene`, `_camera`, `_mark` and `_end` helpers:
  - **PO20 `test_open_panel_never_holds`:** offline, panel open → `holds_match()` false, `menu_open()` false, the tick advances over 10 physics frames, and a move order through `orders` is sent. With the marker dialog open, `holds_match()` is true and the tick stops (P1 behaviour kept).
  - **PO21 `test_match_end_shows_panel_without_focus`:** the match ends → `Checklist` visible, the focus owner is not inside `Checklist`, and Enter on the result panel triggers Play again. After `begin_match`, `Checklist.visible` equals its value before.
  - **PO22 `test_marker_list_this_and_last`:** mark in match 1 → `MarkersTitle` reads "This match", with `Comment_0_0`. Match end → still "This match". `_restart()` → "Last match", `Comment_0_0` still editable and a comment saved to entry 0. Mark in match 2 → "This match", `Comment_1_0`.
  - **PO23 `test_typing_is_text_not_keys`:** focus `Answer_<id>` and push key events for `QUOTELEFT`, `N` and the `key:H` trigger of a fixture card (`{"id": "h", "text": "Press H", "trigger": "key:H"}`; no shipped card has a `key:` trigger) → `Checklist` still visible, no marker dialog, the trigger item not ticked, and a `LineEdit` still the focus owner.
  - **PO24 `test_field_saves_on_submit_and_exit`:** type text into `Answer_<id>` (set `text`, emit `text_changed`) → `current.json` unchanged. `text_submitted` → saved, the focus released, `Saved` visible. A second field: `focus_exited` → saved.
  - **PO25 `test_world_click_releases_field`:** focus `Comment_0_0` and with a unit selected, push a right `InputEventMouseButton` on open ground (a left click would deselect) through `main._unhandled_input` → no focus owner, the comment saved. The move order is sent; then the stop hotkey sends a stop command. Red if the release is removed.
  - **PO26 `test_escape_in_field`:** focus a field and push Esc → focus released, text saved, pause menu closed. A second Esc → pause menu open.
  - **PO27 `test_toggles_take_no_focus`:** every score button, kind button and `CheckBox` in the panel and dialog has `focus_mode == FOCUS_NONE`, and every `LineEdit` has `FOCUS_ALL`. A focused `LineEdit`'s `get_theme_stylebox("focus")` differs from `"normal"`.
  - **PO28 `test_header_has_no_digest`:** `main.playtest_header()` has no `end_digest` key and has `mode`, `map`, `seed`, `factions`, `seat` and `build`. A marker's entry on disk carries them.
  - **`test_form_layout` (rewrite):** at 1280x720 and 1920x1080 with the longest shipped card and five markers, the panel's height is at most 60 % of the viewport, the panel is inside the viewport, its rect intersects none of `HUD/Status`, `HUD/Economy` and `HUD/ResultPanel/Center/Card` (the result panel itself is full-rect), and the scroll reaches the last comment field.
  - **Inverted PO17 `test_restart_keeps_markers`:** after `_restart()`, the abandoned match's marker stays in `data.matches` with `unfinished == true`, also with the helper switched off before the restart.
  - **The other rewrites:**
    - `test_leave_flow`, `test_back_to_menu_from_result_panel` and `test_leave_after_closed_sitting` assert that a leave reaches the launcher at once and that the match is filed, with no form;
    - `test_two_match_session_file` keeps its end-tick, digest, command-log and answer asserts (:497-507) and sets the answers through the panel fields. It files the sitting with `PlaytestSession.close_sitting(false, overlay.download)` and copies `session-*.json` to `WARGRID_SESSION_OUT` as today, because the replay fixture depends on that copy (`p1-playtest-helper-verification.md:45`);
    - `test_sb2_review_form_and_pending_answer` covers the same pending-answer case through the panel. Offline it is inverted: with the panel open, the queued move is delivered (:728-731 asserted that nothing was delivered while the form held);
    - N35 asserts `Checklist` visible and `holds_match()` false at match end online.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=test_playtest_overlay` and `WARGRID_TEST_ONLY=test_online_scene` → the new cases fail; record.
- [ ] **Step 3:** Implement per Interfaces.
- [ ] **Step 4:** Both runs, `test_playtest.gd` and `test_skirmish_scene.gd` → exit 0; lint, warnings, boundary. Commit `Turn the playtest form into one panel that never holds the match`.

### Task 4: Exits, launcher and card picker

Its web steps (launcher `settle` on web) wait for stop gate A's outcome.

**Files:**
- Modify:
  - `game/scripts/playtest/playtest_overlay.gd`: `close_out()` and `_notification`;
  - `game/scripts/match/match_screen.gd`: `quit_requested` :83;
  - `game/scripts/launcher.gd`: `_ready` :63-77, `_add_playtest` :243-260 and a new `_notification`;
  - `game/scripts/playtest/focus_card_view.gd`: `_init` :11, `_pick` :44 and `_render` :48-63.
- Test: `game/tests/test_playtest_overlay.gd` (`test_web_save_downloads` :518 and `test_desktop_write_error_keeps_session` :540 rewritten as exit tests; NB9, NB10, NB11) and `game/tests/test_playtest.gd` (`test_launcher_shows_open_sitting_card` :258 rewritten; `test_launcher_focus_card` :154 adjusted; NB12, NB13). `test_helper_off_changes_nothing` (`test_playtest_overlay.gd:247`) is extended.

**Interfaces:**
- Consumes `close_sitting`, `settle`, `last_filed` and `shown()` from Task 2.
- `playtest_overlay.gd`:
  - **`func close_out() -> void`:** when the helper is not active, it does nothing. Otherwise it calls `get_viewport().gui_release_focus()` (so `focus_exited` saves the field), then `keep_match()`, then `PlaytestSession.close_sitting(web, download)`.
  - **`func _notification(what: int) -> void`:** on `NOTIFICATION_WM_CLOSE_REQUEST`, it calls `close_out()`.
- `match_screen.gd`: a new `var quit: Callable`, set in `_ready` to `get_tree().quit` when not already valid, as `launcher.gd:75` does, so that tests can stub it. `_pause.quit_requested` runs `_playtest.close_out()` and then `quit.call()`.
- `launcher.gd`:
  - **New field:** `var download: Callable = JavaScriptBridge.download_buffer`. It is a field so tests can replace it, as on the overlay.
  - **`_ready`:** with the helper enabled, `_ready` calls `PlaytestSession.settle(PlaytestSettings.build_id(), web, download)` before `_add_playtest`.
  - **Quit:** the Quit button and `NOTIFICATION_WM_CLOSE_REQUEST` (the launcher's `_notification`) call `PlaytestSession.close_sitting(web, download)` when the helper is enabled, then the existing `quit.call()` for the button.
- `focus_card_view.gd`:
  - **Constructor:** `_init(cards: Array[Dictionary], open_count: Callable = ..., end_sitting: Callable = func() -> void: pass, web: bool = false)`.
  - **`_pick(index)`:** when a sitting is open (`open_count.call() >= 0`) and `PlaytestSession.open_focus() != _cards[index].id`, it calls `end_sitting`; then it sets `FocusCards.chosen` and renders.
  - **`_render`:** the picker is never disabled. A new `LineEdit` named `LastFiled` (`editable = false`) sits under `OpenSession`. Its text is "Notes downloaded: %s" on web or "Notes saved to %s" on desktop; it is visible only when `PlaytestSession.last_filed` is not empty.
  - The launcher passes `func() -> void: PlaytestSession.close_sitting(web, download)` and `web`.

- [ ] **Step 1: Failing tests:**
  - **NB9 `test_window_close_files_typed_text`:** in a match with the helper on, focus `Answer_<id>` and set its text without submitting. Then `main.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)` (the match scene only, so the runner's other nodes see nothing) → `session-*.json` exists and holds the text and the match, `current.json` is gone. Same for the launcher's `_notification` with a stored filled sitting.
  - **NB10 `test_quit_with_write_error_still_quits`:** make the playtest dir unwritable, as `test_desktop_write_error_keeps_session` does today, and stub `main.quit`. Pause Quit → quit called once, `current.json` still holds the match. The next `resume_or_open` resumes it.
  - **NB11 `test_each_exit_files_filled_only`:** for pause Quit, launcher Quit and window close: a filled sitting writes exactly one file, and an unfilled one (only trigger ticks) writes none and removes `current.json`.
  - **NB12 `test_web_launcher_downloads_once`:** with web set on the launcher, a stored filled sitting, and opening the launcher scene → `download` called once with a name `session-*.json`, `last-session-*.json` stored, `LastFiled` reading "Notes downloaded: …". Opening it again → not called again.
  - **NB13 `test_card_pick_ends_sitting`:** with a stored filled sitting on card A, picking card B in the launcher → the picker enabled, a desktop `session-*.json` written, `FocusCards.shown() == B`, and `LastFiled` visible. Picking A again with no sitting open → no write. Before the pick, assert that no `session-*.json` exists, so the test cannot pass on `settle`.
  - **Launcher fixtures:** in `test_playtest.gd` they store sittings with `PlaytestSettings.build_id()`, so `settle` leaves them open.
  - **`test_launcher_shows_open_sitting_card` (rewrite):** the picker stays enabled while "Session open: N matches" shows.
  - **`test_helper_off_changes_nothing` (extend):** with the helper off and a stored filled sitting, pause Quit, window close and launcher open each leave `current.json` untouched and write no file.
- [ ] **Step 2:** The overlay and playtest runs → the new cases fail; record.
- [ ] **Step 3:** Check spec risk 3 before writing `_notification`.
  - Quote the Godot 4.7 class reference for `Node.NOTIFICATION_WM_CLOSE_REQUEST` and `SceneTree.auto_accept_quit` in the verification file, from the installed engine's built-in docs (`godot --doctool` into `build/doc`, then `rg -n 'WM_CLOSE_REQUEST' build/doc`) or from docs.godotengine.org.
  - If the reference says the notification does not reach scene nodes with `auto_accept_quit` on, stop and report.
  - Then implement per Interfaces.
- [ ] **Step 4:** The runs → exit 0; full suite, lint, warnings, boundary. Commit `File playtest notes on every exit and unlock the card picker`.

### Task 5: Focus card, docs and gate checks

**Files:**
- Modify:
  - `game/data/playtest/focus.json` (a new first card) and `game/tests/test_playtest.gd` (`SHIPPED`);
  - `docs/guide/05-presentation.md` (playtest helper passages near :156, :161, :216; footer) and `docs/guide/13-testing-and-tooling.md` (session file and tool near :83, :134-138; footer);
  - `docs/development.md`, only where it describes the form or the session file;
  - `docs/packages.md` (P12 row: implemented, plan and verification links), `docs/STATUS.md` (P12 row; F22 closed with this plan's evidence, playtest pending), `docs/reference/p12-verification.md`.
- **Card** (agent wording, the user may edit):

  ```json
  {"id": "p12-notes", "title": "Notes that never block", "new": ["The playtest notes live in one panel on the ` key: checklist, questions and markers, any time during or after a match.", "Nothing pauses or blocks play, and there are no buttons: notes save themselves.", "Your notes are filed when you quit, or download when you come back to the menu in the browser."], "try": [{"id": "panel", "text": "Open the panel mid-match, type a comment, then click the battlefield and give an order"}, {"id": "marker", "text": "Drop a marker with N and comment on it after the match"}, {"id": "quit", "text": "Close the window without pressing Enter and find the saved file"}], "questions": [{"id": "never_blocked", "text": "The notes never got in the way of playing or leaving"}, {"id": "found_file", "text": "I knew my notes were saved and where to find them"}, {"id": "saved_itself", "text": "I never had to think about saving"}]}
  ```

- [ ] **Step 1:**
  - Write the card.
  - In `test_launcher_focus_card` (`test_playtest.gd:188-190`), replace the picker index 4 (`select(4)`, `emit(4)`) with `SHIPPED.find("p1-frc-economy")`.
  - `WARGRID_TEST_ONLY=test_playtest` → exit 0.
  - Update the docs, keeping the guide's style (payoff first) and the footers' `Checked against` commit.
  - `python3 tools/roadmap.py` (a README diff only if a state changed), then `sh tools/check_public.sh` → exit 0.
- [ ] **Step 2:** `sh tools/run_checks.sh > build/checks.log 2>&1; echo exit=$?` → exit 0. Then the full suite. Also `git diff <base> -- game/scripts/simulation game/scripts/net relay protocol` → empty. Record each check with its tree.
- [ ] **Step 3: Benchmark.**
  - Run `uptime` once. If the 1-minute load is above 2.5, skip, mark it pending in the resume record and go on.
  - Otherwise: `PERF_LABEL="P12 Notes that never block" sh tools/run_benchmark.sh > build/bench.log 2>&1; echo exit=$?`. Never loosen a budget.
  - `rg -n 'playtest' game/scenes/movement_benchmark.tscn game/scripts/debug/movement_benchmark.gd`: if it is empty, the helper is not in the benchmark; record that.
  - A rendered rerun is owed after the merge, because `game/scripts/match/` changed. Record it in the resume record under deferred gates and in the session notes (private).
- [ ] **Step 4:** Resume record; commit `Document notes that never block`.

## Model routing

- **Implementers:**
  - Opus for Task 3 (focus and input in the same frame as the result panel) and Task 4 (exits, notification);
  - Sonnet for Tasks 1, 2 and 5.
  - The main session coordinates; if it still runs on the strongest model at execution, it says so once.
- **Per-task review:** one fresh-context reviewer per code task (Tasks 2-4): Codex, or Opus if Codex is unavailable, given the diff plus the task text, with findings checked against the source and fixed test-first before the commit.
  - Tasks 3 and 4 also get the [player-experience reviewer](../../../.claude/agents/player-experience-reviewer.md) on their UI diff.
  - Task 5's docs get Codex plus Sonnet.
- **Gate:** Grok 4.7 high plus an Opus whole-branch pass whose prompt asks about input that arrives while a field has focus, and exits that skip `close_out`. Opus alone if Grok is missing. Beside it, the player-experience reviewer on the whole UI diff. Then `/ponytail-review` on Sonnet on the branch diff.

## Stop conditions (the run parks, records why and stops)

- A simulation, net, relay or protocol diff, a pinned digest or trace change, or a session `format` other than 1.
- Gate A shows the top-level download blocked in Firefox or Chrome (Task 4's web steps wait for the user).
- Task 2's write cost median is above 4000 µs.
- The Godot reference says `NOTIFICATION_WM_CLOSE_REQUEST` does not reach scene nodes with `auto_accept_quit` on.
- An assertion would have to be weakened, or a budget is exceeded (report, never loosen).
- A step needs a push, a merge, a deploy, `run_game.sh` or a visible window outside gate A.

## Stop gates (not tasks)

- **A. Web download probe** (inside Task 1): the user opens the four probe pages with the coordinator.
1. **Implementation review** (after Task 5), as in Model routing. Fix critical and important findings test-first and record the rulings.
2. **`/ponytail-review`**: apply the cuts, then rerun the full suite and `sh tools/run_checks.sh`.
3. **Owner check, batched with other visible checks:** each step needs the user's approval.
   - Desktop `-dev` build: `sh tools/run_game.sh`, one offline match. Open the panel, type, click the battlefield, give an order, drop a marker, close the window, find the file.
   - The test app: `sh tools/deploy_web.sh test` with the user's approval. A marker, close the tab, reopen, check the download (this covers `user://` persistence on tab close, research note risk 5, unverified until then).
   - Answers go on the "Notes that never block" card; findings go into STATUS.
4. **Push, merge and release** wait for the user. After the merge, `sh tools/run_benchmark.sh` on `main` (load rule) and the owed rendered rerun.

## Agent's calls (spec gaps decided here)

- **A dev restart (`_restart`) keeps the abandoned match's markers** as a cut-short entry, flagged unfinished. PO17 used to drop them, but the spec writes markers to disk at once, and dropping notes the tester wrote contradicts "kept mid-match". The user may reverse this at review.
- **The mid-match header** comes from `driver.match_log()` plus the match screen's own fields, with no `driver.record()` call, so `SimPump` and the drivers stay untouched.
- **The build check runs in the launcher** (`settle` in `_ready`), not in `resume_or_open`. The launcher is the only entry into a match in real play, and web needs the same call there.
- **With the helper off, no exit touches a stored sitting.** It waits until the helper is switched on again.
- **The Saved time** is local `HH:MM`, and the launcher line uses a read-only `LineEdit` so the path can be selected and copied.
- **The panel's title shows the key label** through `DisplayServer.keyboard_get_label_from_physical` (headless: the key itself), as a glyph; no separate hint.
- **The marker list is rebuilt** only on open, begin, marker, end and restart, never per frame.
- **Gate A uses a pure HTML probe** with Godot's own download routine copied from the export (`build/web-bench/index.js`), not a scratch web export: the result is the same, and the cost is lower.
- **The write-cost limit** is a quarter of a 60 Hz frame (4000 µs, median), which the spec left open.
- **The card wording** is the agent's.

## Self-review notes

- **Spec coverage:**
  - one panel and its order, never holding, no action buttons, toggles kept: Task 3;
  - saves on Enter or focus exit, the Saved footer, match end without focus, the This/Last match list: Task 3;
  - mid-match marker write, unfinished flag, filled rule, legacy derive, sitting ends on build change: Task 2;
  - sitting ends on card pick, desktop exits, web launcher download, failed write still quits, the launcher line, the card picker unlocked: Task 4;
  - the tool: Task 2;
  - spec risks: 1 (Task 1, gate A), 2 (Task 2 Step 5), 3 (Task 4 Step 3), 4 (PO25); tab-close persistence (gate 3);
  - guide chapters and STATUS: Task 5.
- **Type consistency:** `set_checked(id, on, manual)` is used in Tasks 2 and 3; `add_marker(marker, header)` in Tasks 2 and 3; `close_sitting(web, download)` and `settle(build, web, download)` in Tasks 2 and 4; `marker_match()` in Tasks 2 and 3; the `close_out()` overlay hook in Task 4 only.
