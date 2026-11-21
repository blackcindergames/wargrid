# War Room step layout: three panels — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn War Room's step page into three fixed, clearly separated panels with far less text on screen, per the approved spec.

**Architecture:** This is an in-place restructure of the existing templ page.
- The desktop grid follows the established `display: contents` pattern: `.step .left` / `.right` already dissolve on the phone and in side view, so the step's parts become grid items of one three-column layout.
- The stage zone gets a fixed height from CSS alone.
- Selection-following parts (option rows, "More of", "About") reuse the existing `data-opt` + `hidden` toggling in `warroom.js`.
- The loader gains three length warnings next to `checkBlindLetters`.

**Tech Stack:** Go 1.x, templ (generated `*_templ.go` are committed; run `go tool templ generate` as `tools/quality.sh` does), htmx, plain CSS, `warroom.js`, and playwright-go browser tests in Firefox (`-tags browser`).

**Spec:** `docs/superpowers/specs/2026-11-21-warroom-step-layout-design.md` (read it first). Decision record: `docs/reference/design-answers-2026-11-08.md`, "Decision app", bullet "Step layout three panels". Visual reference (private): `~/projects/wargrid-private/docs/warroom-layout-mock/shot4.png` (1440 x 900) and `shot4-phone.png` (390 x 844). The mock's own top "Layout:" bar is mock chrome; leave it out.

## Global Constraints

- Only `warroom/`, `docs/guide/13-testing-and-tooling.md` and this plan/spec change. No `game/` change.
- The round data contract is unchanged: no new YAML fields, and `demo`, `demo-controls` and `p2-3b-dock` load with zero errors.
- Typed Go, and templ output regenerated and committed. Comments explain the WHY only, in one line.
- Keys:
  - 0 shows Today. T stays `tier`.
  - 1–8 and a–d pick A–H as today.
  - Enter picks the shown option, and does nothing while Today is shown.
  - W toggles side view and L opens Large. Every stage-control key works with View ▾ closed.
- Pick names only the letter (`Pick B`), and its width never changes between options. The `ptab` "Claude's pick" tab inside the Pick button is removed.
- "Claude's pick" shows only as a tag on Claude's own option row (and on its side-view tile header). Never on the row being viewed unless that row is Claude's.
- Details fold-outs ("Why this question", "Claude's reason", "This round", "About <letter>", and the existing info blocks) start closed on every step. The summary keeps its intro open.
- "Look at" (`look`) is always visible and never clamped or cut.
- Loader warnings go to the log and `go run . open` only, never to the page. Lengths are counted after removing backticks. Limits: question 70, option `notes` 90, `look` 120 characters.
- Fixed zones:
  - **Desktop:** the stage zone height is `100dvh` minus the fixed bars (status line, "More of" strip, page padding), by CSS only. The picture is centred on black, and its width never exceeds the centre column.
  - **Phone:** the stage is a 4:3 box at full width.
  - The "More of" strip keeps its height even when an option has no extras.
- Serve locally with `WARROOM_PORT=8782 go run .` from `warroom/`. Never touch `~/projects/wargrid-wt-p23b-warroom`.
- Test output goes to a file under `$LOGS` (the session scratchpad directory). Judge it by exit code, and on failure read only the failing lines. Pass `timeout: 600000` on suite calls.
- Commits: one per task, only after the owner approves each one (AGENTS.md); the executor stages and shows the diff summary, then waits. Subagents never commit.

## Review Focus

1. **Many options (`demo` `many`, six options):** the Options list plus Pick must still fit in the right panel at 1440 x 900, with the list scrolling inside the panel, not pushing Pick off-screen. Test in Task 4.
2. **Confirm step (one option, `demo` `confirm`):** the single row plus Yes/Change sit where Pick sits. No Today row unless `ref` is set. Test in Task 2.
3. **Read-only link:** the right panel shows the rows but no Pick, neutral or note. `TestReadOnlyLinkHasNoPickControls` must keep passing; extend it to assert that `.opts` rows exist. Task 2.
4. **Blind step:** no Claude's-pick tag and no row text that reveals the candidate before the pick. `TestBlindStepHasNoBadgeBeforeThePick` keeps passing against the new rows. Task 2.
5. **htmx swaps (a stage control or the side toggle):** after a swap, the selected row, "More of" and "About" still match the shown letter, and Today is no longer shown. Test in Task 3.

---

### Task 1: Loader length warnings

**Model:** Sonnet, high.

**Files:**
- Modify: `warroom/internal/rounds/rounds.go`. Add `checkLengths(r *Round)` beside `checkBlindLetters` (around :452) and call it from `validateRound`.
- Test: `warroom/internal/rounds/rounds_test.go`, next to the blind-letter tests (around :280), using the existing `oneRound` helper.

**Interfaces:**
- Produces: `func (c *Catalog) checkLengths(r *Round)`. It appends to `c.Warnings` and nothing else.

- [ ] **Step 1: Write the failing tests**
  - `TestLongTextsWarnTheAuthor`: one step whose question is 71 chars, option B `notes` 91 chars, and `look` 121 chars. Want exactly these three warnings (sorted, like the existing ones), with no errors:
    - `r/a: question is 71 characters; keep it to one line (70)`
    - `r/a option B: notes is 91 characters; keep it to one line (90)`
    - `r/a: look is 121 characters; keep it to one line (120)`
  - `TestTextsAtTheLimitDoNotWarn`: 70 / 90 / 120 chars, where the 70-char question also contains two backticks that don't count. Want no warnings.
  - `TestShippedRoundsLoadWithoutErrors`: if no such test exists, assert that `LoadCatalog("../../rounds").Errors` is empty. Warnings are allowed, and `p2-3b-dock` is expected to warn.
- [ ] **Step 2:** `cd warroom && go test ./internal/rounds/ > $LOGS/t1.log 2>&1; echo exit=$?`. Expected: FAIL, because no warnings are produced.
- [ ] **Step 3:** Implement `checkLengths`. Count `utf8.RuneCountInString` after `strings.ReplaceAll(s, "`", "")`. Skip `KindMissing` steps. Iterate the options in `OptionLetters()` order.
- [ ] **Step 4:** Rerun: PASS. Then `go run . open` lists the `p2-3b-dock` warnings and the server log prints `rounds warning=`.
- [ ] **Step 5:** Stage the changes and ask the owner before committing. Message: `Warn War Room authors about over-long step texts`.

### Task 2: Three-panel markup for choice steps (desktop)

**Model:** Opus, high (UI quality first).

**Files:**
- Modify `warroom/internal/web/viewchoice.go`:
  - add `Key` to `OptView` (from `flipKey`);
  - `ChoiceView.Ref` is set whenever `s.Ref != nil`, not only in side view;
  - add `func (c CtlBarView) Status() string`, which joins the buttons' `Value` with ` · `;
  - drop `ActView.Cp`;
  - keep `Flip` only if `viewphone.go` still needs it.
- Modify `warroom/internal/web/viewmodel.go`:
  - `head()` sets `IntroOpen` to false on steps;
  - `info()` never sets `Ref` for choice steps (Today moves to the Options list);
  - `figures()` drops a picture whose `Kind == "missing" && Local`.
- Modify `warroom/internal/web/steps.templ`:
  - new `Options(v ChoiceView)`: the right panel, with the Today row, the A–H rows, then `Act`, `NoteBox` and `StepNav`;
  - new `StatusLine(v ChoiceView)`: the status text, Side by side (W), Large (L), and `<details class="viewmenu"><summary>View</summary>@CtlBar(v.Ctl,false)</details>`;
  - new `MoreOf(v ChoiceView)`: one `data-opt` block per option holding `Figures(o.Extras)`, always rendered (empty block = reserved height);
  - `FlipStage` loses `FlipBar` and `CtlBar` and gains a Today stage block `<div class="ostage" data-opt="today" hidden>` with the ref picture;
  - `Details` (the right-hand option text) is deleted, and its content moves to an "About <letter>" fold in the left panel, one `data-opt` block per option: `sees`, `notes` heading, `changes`, the option's folds;
  - `ChoiceMain` lays out left (head, look, Details folds), centre (stage, status, More of) and right (Options).
- Modify `warroom/internal/web/parts.templ`:
  - `Info`: "Why this question" is never `open`, and the `.ref` fold is removed;
  - add "Claude's reason" (`Head.ClaudePick.Why`) as a closed fold;
  - `Intro` on steps renders closed, labelled "This round".
- Modify `warroom/internal/web/layout.templ`: the chip nav renders where the left panel can hold it (see Step 3).
- Modify `warroom/internal/web/static/warroom.js`:
  - rows carry `data-show`;
  - key `0` and a Today row click show `data-opt="today"`, set Pick `disabled`, and make Enter a no-op;
  - "More of" and "About" blocks follow the shown letter through the existing show function;
  - remove the `ptab` handling.
- Modify `warroom/internal/web/static/app.css`: the three-panel grid (left ~260 px, right ~340 px, centre `minmax(0,1fr)`), row styles (`--sel` for the selected row, a dashed muted Today row), and the `.tag.cp` on rows.
- Test: `warroom/internal/web/views_test.go` (Go view tests), `warroom/internal/web/browser_test.go`.

**Interfaces:**
- Consumes: Task 1, nothing at runtime.
- Produces:
  - DOM hooks that Tasks 3–5 test against:
    - `.lpanel`, `.cpanel` and `.rpanel` as the three panel containers;
    - `.opts .orow[data-show=<L|today>]` for the option rows;
    - `.zone` around `.stage`;
    - `.status`, `.viewmenu`, `.moreof`;
    - `button.pick[data-shown]` and `.about[data-opt]`.
  - `CtlBarView.Status() string`.

- [ ] **Step 1: Write the failing tests**
  - In `views_test.go`:
    - `TestMissingLocalExtraIsLeftOut`: an option with `extra: [{img: nope.webp, local: true}]` and a missing file. Its `OptView.Extras` is empty. A committed but missing (non-local) extra still shows as `missing`.
    - `TestStepIntroStartsClosed`: `head(1, …).IntroOpen == false`.
    - `TestRefFeedsTodayNotInfo`: with `ref` set, `ChoiceView.Ref != nil` and `Info.Ref == nil`, in both flip and side view.
  - In `browser_test.go`, on the demo round (or a `writeTree` round with `ref`, extras on two options, and `rec: B`):
    - `TestKeyZeroShowsTodayAndDisablesPick`: press `0`. The today block is visible, `button.pick` is disabled, pressing Enter records nothing (`s.entries` is empty), and pressing `b` re-enables Pick showing `Pick B`.
    - `TestRowClickSelectsAndMoreOfAndAboutFollow`: click row B. Row B has class `sel`; the `.moreof [data-opt=B]` and `.about[data-opt=B]` blocks are visible, and A's are hidden.
    - `TestClaudesPickTagOnlyOnItsRow`: there is exactly one `.orow .tag.cp`, inside row B. `button.pick .tag` count is 0.
    - `TestViewMenuClosedAndKeysStillWork`: `.viewmenu` is not `open`, and `f` toggles `#view.true100`.
    - `TestDetailsFoldsStartClosed`: every `details` inside `.lpanel` has no `open` attribute.
    - `TestTodayAndExtrasSitInTheSamePlaceOnEveryStep` (spec test 6): on `p2-3b-dock` steps 1 and 2 (both have `ref` and extras), the first `.orow` is `[data-show=today]`, extras render only inside `.moreof`, and `.moreof`'s rect is equal on both steps.
    - `TestConfirmStepPicksFromTheRightPanel` (Review Focus 2): on the demo confirm step, Yes and Change are inside `.rpanel` and there is no Today row.
- [ ] **Step 2: Update existing browser tests whose DOM moved.** For each, the reviewer must be told which behaviour stays pinned:
  - `TestDigitFiveShowsOptionE`: `.flipbar [data-show=E]` becomes `.opts [data-show=E]`.
  - `TestClaudesPickIsALightBadge`: the selector moves to the row tag, and the colours stay pinned.
  - `TestPickButtonWearsClaudesTabWhileItsOptionIsShown`: **delete**. The behaviour was removed by the spec, and `TestClaudesPickTagOnlyOnItsRow` replaces it.
  - `TestMeasureTableIsUnderItsOptionInFlipAndSideViews`: it stays under the stage in flip view; update the selectors only.
  - `TestReadOnlyLinkHasNoPickControls`: also assert `.opts .orow` count > 0 (Review Focus 3).
  - `TestBlindStepHasNoBadgeBeforeThePick`: point it at the rows (Review Focus 4).
  - The side-view and Pick-row geometry tests (`TestSideViewSharedPickRowIsCentredUnderTheGrid`, `TestPickRowsSit16PxFromThePictureAndTheLargeRow`, `TestNeutralAnswerIsExplainedUnderItsRow`) are rewritten in Task 4 against the right panel. In this task, mark each `t.Skip("rewritten in Task 4")` so the suite stays green; Task 4 removes every skip.
- [ ] **Step 3: Implement.** Order: Go view changes → templ → `go tool templ generate` → js → css. Chip nav: render it at the top of the left panel on step pages. Either move `ChipLink` rendering into the step templates (passing `[]Chip` in the view) or place `.top` in the left grid column with CSS. Pick whichever leaves `Shell` simplest. Summary, missing and round-list pages still show the chips.
- [ ] **Step 4: Run.**
  - `cd warroom && go test ./... > $LOGS/t2.log 2>&1; echo exit=$?`
  - `go test -tags browser ./internal/web/ > $LOGS/t2b.log 2>&1; echo exit=$?`

  Expected: both exit=0. Then serve on 8782 and eyeball `/r/p2-3b-dock/1` at 1440 x 900 in headless screenshot form (`playwright` screenshot to the scratchpad), not a visible window.
- [ ] **Step 5:** Run `sh tools/quality.sh` from `warroom/` (exit 0). Stage the changes and ask before committing. Message: `Lay War Room steps out as three panels`.

### Task 3: Selection survives htmx swaps

**Model:** Opus, high.

**Files:**
- Modify: `warroom/internal/web/static/warroom.js` (re-apply the shown letter after a swap, and clear the Today state).
- Test: `warroom/internal/web/browser_test.go`.

**Interfaces:**
- Consumes: the Task 2 DOM hooks.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test** `TestControlSwapKeepsRowMoreOfAndAboutOnTheShownLetter` (Review Focus 5):
  - press `b`, press `0`, then press a stage-control key that swaps (`s` on a step with the size control);
  - then: row B `sel`, More of B visible, About B visible, the today block hidden, Pick enabled with text `Pick B`.
- [ ] **Step 2:** Run it alone (`cd warroom && go test -tags browser ./internal/web/ -run TestControlSwap > $LOGS/t3.log 2>&1; echo exit=$?`). FAIL is expected if the swap loses state; if it already passes, keep the test as a guard and say so.
- [ ] **Step 3:** Fix in `warroom.js` with the existing after-swap hook.
- [ ] **Step 4:** Full browser suite: exit 0.
- [ ] **Step 5:** Stage the changes and ask before committing. Message: `Keep War Room's selection across stage-control swaps`.

### Task 4: Fixed zones (desktop geometry)

**Model:** Opus, high.

**Files:**
- Modify: `warroom/internal/web/static/app.css` (zone height, contain-fit picture, True 100 % scrolling inside the zone, side-view tiles inside the zone, right-panel list scroll).
- Modify: `warroom/internal/web/steps.templ` `Tile` (header + picture only; drop the per-tile text and extras fold).
- Test: `warroom/internal/web/browser_test.go`.
- A small helper in `browser_helper_test.go`: `func (s *site) rect(t *testing.T, sel string) playwright.Rect` (BoundingBox, failing on nil), plus `s.Page.SetViewportSize`.

**Interfaces:**
- Consumes: `.zone`, `.cpanel`, `button.pick`, `.rpanel`, `.opts`.

- [ ] **Step 1: Write the failing tests.** All run on the shipped rounds (`newSite(t, siteOpts{})`), so `p2-3b-dock` is served. Step 1 (`queue`) is a full frame; step 5 (`cost`) crops 460 x 260.
  - `TestStageZoneIsTheSameForACropAndAFullFrame`: at 1440 x 900, then at 1280 x 800, `rect(".zone")` on `/r/p2-3b-dock/1` equals the one on `/r/p2-3b-dock/5` (±1 px).
  - `TestPickNeverMovesBetweenOptionsAndSteps`: at 1440 x 900, `rect("button.pick")` is equal for A, B, C and D on step 5 and for A on step 1.
  - `TestStageFitsItsColumnAtTrue100`: viewport 1280 x 800, `/r/p2-3b-dock/1` with the size control at `1280x800` (via its URL value) and `f` pressed. Then:
    - `rect(".zone").x + width <= rect(".cpanel").x + width`;
    - `rect(".rpanel")` is fully inside the viewport;
    - every `.orow` is visible and not overlapped by the zone (zone right edge ≤ rpanel left edge).
  - `TestPickVisibleWithoutScrolling`: at 1440 x 900, on every step of `p2-3b-dock` and on the demo `many` step, `button.pick` lies inside the viewport.
  - `TestSideViewTilesStayInTheZone`: in side view on `/r/p2-3b-dock/1`, `.zone`'s rect equals its flip-view rect, and every `.tile` header is in the DOM. Scrolling inside the zone is allowed.
  - Rewrite the three geometry tests skipped in Task 2 against the right panel:
    - neutral hint directly under the neutral button;
    - Pick, neutral, note and nav in that order inside `.rpanel` with no spacer (gap ≤ 16 px between `.opts` bottom and Pick top).

    Remove every `t.Skip("rewritten in Task 4")`.
- [ ] **Step 2:** Run the new tests (`-run 'StageZone|PickNever|StageFits|PickVisible|SideViewTiles'`). Expected: FAIL on the zone and True 100 % cases.
- [ ] **Step 3: Implement in CSS.**
  - `.zone { height: calc(100dvh - var(--bars)); }`, with `--bars` covering the page padding, `.status` and `.moreof` heights (fixed heights on those two).
  - `.zone .stage` fills the zone, centred and black, with `overflow: auto` for True 100 %.
  - Replace the old `calc(100vh - 280px)` / `220px` rules at app.css:357–358 and :408–411 rather than adding new ones next to them.
- [ ] **Step 4:** Full browser suite exit 0, and `sh tools/quality.sh` exit 0.
- [ ] **Step 5:** Stage the changes and ask before committing. Message: `Give War Room's stage a fixed zone`.

### Task 5: Phone layout

**Model:** Opus, high.

**Files:**
- Modify: `warroom/internal/web/static/app.css` (the `@media (max-width: 900px), (pointer: coarse)` block at :421: order is question/look → stage → options; `.zone` becomes `aspect-ratio: 4/3; height: auto; width: 100%`).
- Modify: `warroom/internal/web/parts.templ` `PhoneBar` only if the Note button must open the note above the bar. It already has `data-act="note"`; check before changing.
- Modify: `browser_test.go` `/_phone` frame height from 800 to 844 in `browser_helper_test.go:105`.
- Test: `browser_test.go`.

**Interfaces:**
- Consumes: the Task 2 hooks and `s.phoneFrame`.

- [ ] **Step 1: Write the failing tests** with `s.phoneFrame(t, "/r/p2-3b-dock/1", ".zone")`:
  - `TestPhoneHasNoSideScroll`: the frame document's `scrollWidth <= clientWidth`, on steps 1 and 5.
  - `TestPhoneShowsQuestionLookAndPickBar`: `.head h1` (or the question element), `.look` and the phone `.pick` are visible in the first 844 px, after scrolling to the top, with the Pick bar sticky at the bottom.
  - `TestPhoneStageIsAFixedFourByThreeBox`: on steps 1 and 5, `.zone` height = width × 3/4 (±1 px), and equal across both steps.
  - The existing `TestPhoneBarStaysAtTheBottomBelowTheNote`, `TestPhoneBarNeverCoversThePageEnd` and `TestPhoneSideAndNeutralLiveInTheControlsSheet` keep passing unchanged.
- [ ] **Step 2:** Run them: FAIL on the 4:3 test at least.
- [ ] **Step 3:** Implement the CSS.
- [ ] **Step 4:** Full browser suite exit 0 and `sh tools/quality.sh` exit 0.
- [ ] **Step 5:** Stage the changes and ask before committing. Message: `Fit War Room's three panels to the phone`.

### Task 6: Other step kinds share the left panel

**Model:** Sonnet, high.

**Files:**
- Modify: `warroom/internal/web/steps.templ` (`GalleryMain`, `VerdictMain`, `TuneMain`, `WordingMain`, `MissingMain`, `SummaryMain`), and `app.css`.
- Test: `browser_test.go`.

**Interfaces:**
- Consumes: `.lpanel`, `.cpanel` and the chip placement from Task 2.

- [ ] **Step 1: Write the failing test** `TestEveryStepKindHasTheLeftPanel`: for each `demo` step, plus the summary and a missing step (`writeTree` with a missing step key), `.lpanel` contains the chip nav and the question (summary: its title). `.lpanel details[open]` count is 0, except on the summary page, where the intro is open.
- [ ] **Step 2:** Run: FAIL.
- [ ] **Step 3:** Implement. Each kind's own content goes in `.cpanel`, with the note and nav under it. No right panel. Existing tune, gallery and verdict tests keep passing unchanged.
- [ ] **Step 4:** Full `go test ./...` and the browser suite exit 0, and `sh tools/quality.sh` exit 0.
- [ ] **Step 5:** Stage the changes and ask before committing. Message: `Put every War Room step kind on the left panel`.

### Task 7: Docs, checks, reviews, owner look

**Model:** Sonnet, high for the docs; the reviews are as named.

**Files:**
- Modify `warroom/README.md`:
  - "Rounds: the data contract": the authoring rule and the three warnings, with their limits;
  - "Keys": 0 Today, View menu;
  - "Stage controls": the status line and View ▾;
  - fix the sentence that says the intro is "shown open above step 1".
- Modify `docs/guide/13-testing-and-tooling.md`: the War Room section (layout, fixed zones, warnings) and its `Checked against` footer.

- [ ] **Step 1:** Write the docs. No custom domain; tracked docs name only the fly app `warroom`.
- [ ] **Step 2: Gates.** All must exit 0:
  - in `warroom/`: `sh tools/quality.sh` and `go test -tags browser ./internal/web/`;
  - in the repo: `sh tools/run_checks.sh`, `sh tools/check_public.sh` and `python3 tools/roadmap.py --check`.
- [ ] **Step 3: Offscreen screenshots.** One batch, headless, to the scratchpad: `/r/p2-3b-dock/1`, `/5`, side view of `/1`, demo `many`, and the summary, at 1440 x 900 and in the 390 px phone frame.
- [ ] **Step 4: Reviews.**
  - The player-experience reviewer gets the spec, the screenshots and `shot4.png`.
  - A fresh Opus high correctness reviewer gets the branch diff (`git diff main...`) and the file paths.
  - Apply the fixes, then run `/ponytail-review` on the diff, apply its cuts, and re-run Step 2.
- [ ] **Step 5: Owner look** in Firefox at `http://localhost:8782` (desktop plus responsive mode at 390 x 844). Ask before opening. Remind the owner of the open page-zoom check for the clipped HUD text.
- [ ] **Step 6:** Stage the changes and ask before committing. Message: `Document War Room's three-panel layout`. Merge, push and redeploy each need their own approval.
