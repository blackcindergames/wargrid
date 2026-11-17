# P12 Notes that never block: design

Status: approved by the user 2026-11-17. Decisions marked (user, 2026-11-17) come from this session's questionnaire ([design answers](../../reference/design-answers-2026-11-08.md#p12-notes-that-never-block-questionnaire-user-2026-11-17)); the agent's calls are listed at the end. Scope lives in the [P12 row](../../packages.md#day-lane) and [F22](../../STATUS.md#findings-list). The code facts below come from the P12 research note (private), checked against `main` at `9b21db3`, and from a builder check and a player-experience review of this spec's first draft (2026-11-17).

## Why

The playtest helper's form is modal. `holds_match()` (`game/scripts/playtest/playtest_overlay.gd:89`) is true while the form shows, and that one flag pauses offline play, blocks every order (`match/orders.gd:34`), blocks Enter on Play again and takes the result panel's focus (`match/match_screen.gd:90, 159, 183`). In the P2.2 playtest a leaver got stuck behind it (F22, user 2026-11-15); 0.13.0 shipped a minimal fix for the leave path only. The owner wants to write text and tick boxes at their own pace, with no buttons, and nothing may ever block leaving a match. A closed tab also loses every marker today, because markers live only in `PlaytestSession._pending` until `finish_match` (rider, user 2026-11-16).

P12 comes before P2.3a, so that P2.3a only has to place a finished form (user, 2026-11-16).

## Goals

- **One panel, any time** (user, 2026-11-17): the checklist panel on the ` key grows into the whole form. It holds the checklist, the card's questions (a 1-5 score plus text) and the marker list, each marker with a comment field. It opens and closes during a match and on the result screen, offline and online.
- **Marker list** (user, 2026-11-17): the panel lists this match's markers. After Play again, the previous match's markers stay listed as "Last match" until the new match gets its first marker.
- **Never holds the match** (user, 2026-11-17): an open panel neither pauses offline play nor blocks orders. Only the marker dialog (N) keeps its offline pause, as P1 decided.
- **No action buttons** (user, 2026-11-17): Next match, End session, Save session, Discard, Close, Try again and Show in folder are gone. The 1-5 score toggles stay, and so do the marker dialog's kind toggles, Save and Cancel.
- **Saves itself** (user, 2026-11-17): ticks, scores and markers save at once. A text field saves on Enter or when focus leaves it, never per keystroke. Today every keystroke writes (`session_form.gd:104, 132`), so this changes behaviour on purpose.
- **Saved hint** (user, 2026-11-17), passive text only:
  - the panel footer shows "Saved" and the time of the last write;
  - the launcher line under "Session open" shows the last filed path as selectable text on desktop, or "Notes downloaded: <name>" on web.
- **Match end** (user, 2026-11-17): the panel opens by itself without taking focus; the result panel keeps Enter for Play again.
- **Kept mid-match** (rider, user 2026-11-16; cadence user 2026-11-17): a marker is written to `current.json` when it is saved, inside an unfinished match. There is no timer and no state digest mid-match.
- **Filed only if filled in** (user, 2026-11-17): a sitting counts as filled once it holds any text, any score, a manual tick or a marker. Automatic trigger ticks alone fill nothing. A sitting with nothing filled in is deleted when it ends, with no file and no download.
- **Sitting ends** (user, 2026-11-17):
  - desktop: pause Quit, launcher Quit and closing the window write `session-<time>.json`;
  - web: the record downloads on every return to the launcher and at every start of the game, if the sitting is filled; downloading ends the sitting;
  - both: a new build id ends the open sitting, and so does picking another focus card; the next match starts a new one (card picker unlocked, user 2026-11-17).
- **Cut-short matches** (user, 2026-11-17): a match interrupted by a crash or a closed tab stays in its sitting, flagged unfinished, with no new UI.

## Non-goals

- Discard: there is no discard action; an unwanted file is deleted by hand (user, 2026-11-17).
- Where the panel finally sits in HUD v5 (P2.3a owns that; the `PLAYTEST 2 / 5` chip, `docs/reference/hud-v5-layout.md:80`). P12 keeps today's bottom-right column.
- A periodic mid-match write, a launcher note about cut-short matches, replaying a cut-short match, a new session format, retiring the helper.
- Release builds: the helper stays on by default only in `-dev` builds (`playtest/playtest_settings.gd`).

## Anti-goals

- Anything that pauses, blocks or delays play, leaving or quitting, online or offline. A focused text field counts: it must never silently eat the player's hotkeys after they went back to the battlefield.
- A failed write that blocks a quit. The data stays in `current.json`, and the sitting resumes at the next start.
- A simulation, trace, command or replay change. This is presentation and tooling only; no same-tick cases are needed.
- A frame hitch from saving during play: no whole-file write per keystroke.
- Breaking `tools/playtest_session.py` on existing files: new fields are additive, `format` stays 1.
- Losing an owner's answers in the move: a `current.json` from 0.13.x must survive the first start of the new build.

## Constraints

- Typed GDScript; lint, warnings and the full suite pass; new tests use only the [simulation interface](../../reference/sim-interface.md). The panel is a HUD-type change, so it gets a headless layout test.
- Player-experience reviewer beside the correctness reviewer on this spec, the plan's UI tasks and the final diff (AGENTS.md).
- `match/match_screen.gd` changes, so a rendered benchmark rerun is owed after merge (AGENTS.md).
- The P1 design ([packages and playtest helper](2026-11-11-packages-and-playtest-helper-design.md)) still holds where this design is silent: the helper only reads view, snapshot and command stream; the desktop file goes to `user://playtests/`; web saves via `JavaScriptBridge.download_buffer`.
- Guide chapters [05 presentation](../../guide/05-presentation.md) and [13 testing and tooling](../../guide/13-testing-and-tooling.md) describe the old form and are updated in the same branch, with their `Checked against` footers.

## Approaches

- **A. The checklist panel grows into the form (picked, user 2026-11-17).** The ` panel takes the question rows and marker comment rows that `session_form.gd` builds today, without its buttons. The match in progress lives in the session as an unfinished match. That replaces `_pending` and gives both the rider and the cut-short flag. One sitting-close routine serves every exit. This is the least new code, and it reuses the existing row builders.
- **B. A new notes panel from scratch, `session_form.gd` deleted.** A cleaner file, more new code, and the same test rewrites as A. P2.3a moves the panel anyway, so the clean slate buys nothing now.
- **Dropped: a separate form panel beside the checklist.** The user asked for one panel on one key.

## Design

### Panel

- **Layout:** one scrolling panel in today's bottom-right column. In order, it holds:
  - the card title, followed by the toggle key's label as the current layout shows it (`DisplayServer.keyboard_get_label_from_physical` on ` ; a German keyboard shows its own glyph);
  - the checklist and the questions;
  - the marker list ("This match", or "Last match" as above), each row with kind, tick and a comment field;
  - the "Saved hh:mm" footer.
- **Height:** at most 60 % of the viewport height. Above that it scrolls. The layout test checks the panel covers no HUD control at the test's window sizes.
- **Toggles:** the checklist boxes, the score toggles and the marker kind toggles take no keyboard focus (`FOCUS_NONE`), as the checklist boxes already do. Only the text fields take focus.
- **Keys while a panel field has focus:** keys go to the field. That covers ` , N, match hotkeys, orders and the checklist's automatic `key:` triggers (`overlay.gd:130`). `test_note_typing_is_not_a_hotkey` covers the marker field today; the panel's fields get the same guard.
- **Leaving a field:** each of these releases the focus, which saves the field:
  - Enter;
  - Esc, which the overlay handles and consumes, so the pause menu stays closed (`match_screen._input` opens it on `deselect` without checking typing, :178);
  - a left or right click that reaches the battlefield (`orders.handle`, `match_screen.gd:272`).

  Once Enter has released the field, a second Enter on the result screen means Play again.
- **Focus style:** a focused field shows a clear focus outline.
- **Match end:** the panel shows without grabbing focus. Play again begins a match, and the panel keeps the visibility it had.
- **`holds_match()`:** it becomes "the marker dialog is visible". Its four callers (offline pause, order block, Enter on Play again, result-panel focus) keep working unchanged for the marker dialog. `reviewing()` goes away; its callers (`test_online_scene.gd` N35 at :1167, `test_playtest_overlay.gd` PO11 at :406, :409) assert the new behaviour instead.

### Session model

- **Unfinished match:** the in-progress match is the last entry of `data.matches`, marked `"unfinished": true`. It is created at the first marker of a match, and it carries every key `tools/playtest_session.py` reads:
  - `mode`, `map`, `seed`, `factions`, `seat` and `build`;
  - `end_tick`, set to the latest marker's tick;
  - `result: "unfinished"` and `commands: []`.

  It has no `end_digest`, because the mid-match header is taken without a digest query.
- **Match end:** `finish_match(record)` replaces the unfinished entry when there is one, keeping its markers and comments; otherwise it appends. Either way the flag is dropped. A cut-short match keeps the flag forever.
- **Markers:** `add_marker` writes `current.json` at once, and `_pending` goes away.
- **Filled:** `data.filled` (additive) turns true on the first text, score, manual tick or marker. Trigger ticks go through a path that does not set it. When the flag is missing (a `current.json` from 0.13.x), the sitting counts as filled if it has any answer, any match with markers, or any ticked item.
- **Writes:** a tick, a score or a marker writes `current.json` at once; a text field writes when it is released (above). The whole file is written each time, JPGs included.

### Ending a sitting

One routine ends the open or stored sitting. It first releases any focused panel field, so the text is saved. Then:
- if the sitting is filled: on desktop it writes the session file; on web it stores `last-session-<time>.json` (one per sitting, never overwritten) and downloads it;
- if not: it deletes `current.json`.

A failed write keeps `current.json` and lets the exit proceed. A successful one updates the launcher's saved line.

- **Desktop exits:** pause Quit (`match_screen.gd:83`, today a bare `get_tree().quit()`), launcher Quit (`launcher.gd:75-77`) and `NOTIFICATION_WM_CLOSE_REQUEST` in both scenes. In a match the running match is filed first, as `keep_match()` does on a leave.
- **Web:** when the launcher opens, it ends a filled sitting, which covers both a return from a match and a fresh start after a closed tab. A sitting with nothing filled in stays open across launcher visits.
- **New build:** a sitting whose `build` differs from the current build id is ended before a new one opens. The check covers both the stored sitting and the in-memory `PlaytestSession.current`, which `resume_or_open` returns early today (`playtest_session.gd:13`).
- **New card:** picking another card in the launcher ends the open sitting at once; on web the pick is a click, so its download comes from a gesture. `FocusCards.shown()` returns the picked card when there is one this run, otherwise the stored sitting's card, otherwise the default. A resume after a crash therefore keeps its card, even though `FocusCards.chosen` resets at each start. The picker no longer disables while a sitting is open, and the "Session open: N matches" line stays.
- **Crash or closed tab on desktop:** the next start resumes `current.json` as today, with the cut-short match flagged.

### Tools

`tools/playtest_session.py` keeps `format` 1 and gets a case in `tools/test_playtest_session.py`. It:
- prints the unfinished flag on a match;
- handles a missing `end_digest`;
- skips flagged matches in `--replay-args`.

### Tests that change

The old flow lives in three places, and its tests are rewritten to the new behaviour, not deleted:
- `game/tests/test_playtest_overlay.gd`: `test_leave_flow`, `test_match_end_opens_review_once`, `test_back_to_menu_from_result_panel`, PO11 (`reviewing()`), `test_leave_after_closed_sitting`, `test_two_match_session_file`, `test_web_save_downloads`, `test_desktop_write_error_keeps_session`, `test_form_layout`, `test_scale_legend` and `test_sb2_review_form_and_pending_answer`;
- `game/tests/test_playtest.gd`: the session cases and the launcher sitting card;
- `game/tests/test_online_scene.gd`: N35.

New behaviour tests, at least:
- **Play is never held:**
  - an open panel neither pauses offline play nor blocks an order;
  - Play again works with the panel open;
  - after a field is focused, a battlefield click releases it and the next hotkey order fires;
  - Esc in a field releases and saves it, and the pause menu stays closed;
  - typing ` , N or a checklist trigger key in a field is text: no toggle, no tick.
- **Notes are kept:**
  - a marker reaches `current.json` before match end;
  - a cut-short match is flagged and resumes;
  - typed text without Enter survives a window close;
  - a 0.13.x `current.json` without `filled` survives the first start of the new build.
- **Sittings end correctly:**
  - a sitting with nothing filled in leaves no file on each exit, and trigger ticks alone do not fill it;
  - pause Quit, launcher Quit and window close each write a filled sitting;
  - opening the web launcher downloads a filled sitting once;
  - a build change ends the sitting, and so does a card pick;
  - a failed desktop write keeps `current.json` and still quits.
- **Panel layout:** the panel stays inside its height cap and covers no HUD control at the layout test's window sizes.

## Risks and checks

1. **Download without a click (web).** On scene load the launcher's download runs without a click, and a browser may block it or prompt for it. One idea, unverified: Chrome lets the first such download through and prompts for later ones, and a page embedded in another site may block all of them. This check can kill the web half of the design, so it runs first. A scratch web export, in a visible window that is asked for first, tests three cases in Firefox and Chrome on the Mac:
   - one download from `_ready`;
   - a second download in the same tab;
   - the export embedded in an iframe.

   If downloads are blocked, the fallback comes back to the user before the web path is built. The per-sitting `last-session-<time>.json` keeps the data either way.
2. **Write cost during play.** A marker save writes the whole file with every JPG (each up to about 128 KiB as base64, `marker_capture.gd:7`). There are a few markers per match, so this is expected to stay small. The plan measures one write with five markers on the Mac and names the number.
3. **Window close.** Two things are checked against the Godot documentation and a test, not assumed: whether the close notification reaches the scene with `auto_accept_quit` left on, and whether the write finishes before the quit.
4. **Focus on click.** Whether Godot 4.7.2 drops a field's focus by itself on a click outside it is not assumed; the battlefield click releases it explicitly.

## Left to the builder

- File layout: how much of `session_form.gd` survives as row builders inside the panel, and whether the sitting-close routine is a static on `PlaytestSession`.
- How the mid-match header is obtained without a digest (a header-only record call or a flag).
- Scroll behaviour inside the height cap, and the focus outline's look within the HUD theme.
- Wording of the new labels and empty states, reviewed by the player-experience reviewer.

## Agent's calls (check while reading)

- The unfinished entry is created at the first marker, not at match start, so a crash before any marker leaves nothing behind.
- "Filled" is one additive `filled` flag rather than a separate list of manual ticks; a missing flag is worked out from the contents.
- A cut-short match carries no command log and is not replayable.
- A quit or leave mid-match files the match as finished, with the record and digest at that moment, as `keep_match()` does today. Only a crash or a closed tab leaves the flag.
- On web, a sitting with nothing filled in stays open across launcher visits.
- A card pick ends the sitting at once in the launcher.
- Enter and Esc in a field release it, and so does a battlefield click. The toggles take no keyboard focus, so scores are mouse-only, like the checklist.
- The toggle key's label sits in the panel title; no separate hint.
- Each web sitting gets its own `last-session-<time>.json`.
- The web download check runs before any web-path code.
