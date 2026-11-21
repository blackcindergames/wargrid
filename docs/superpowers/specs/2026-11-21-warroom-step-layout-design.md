# War Room step layout: three panels

Status: approved by the owner (user, 2026-11-21). Decision record: design answers, "Decision app", bullet "Step layout three panels".

## Why

The step page shows too much text, and its areas run into each other (user, 2026-11-20). In the live P2.3b round the owner also found the optional note in an odd place (user, 2026-11-21). A small crop made the stage collapse to a strip, which moved the Pick row up. At Window 1280 x 800 with True 100 %, the stage overflowed its column: its left half was black, and the HUD, the option C tab and the controls row were cut off on the right. Success means three calm, clearly separated panels whose positions never move between steps or options, with long text folded away.

## Goals

- **Three panels on desktop, layout 2b.** The private mock-up is `warroom-layout-mock/index.html#4`; its screenshots are `shot4.png` and `shot4-phone.png`.
- **Fixed zones.** Within one viewport, the stage zone has the same size on every step and option. The picture is centred on black inside it (`object-fit: contain` or equivalent). Pick, the controls and the option list never move when the crop or option changes.
- **Less text on screen.** Long texts are folded under Details, and an authoring rule with loader warnings keeps the always-visible texts short.

## Non-goals

- No change to the round data contract, so existing YAML (`demo`, `demo-controls`, `p2-3b-dock`) loads unchanged.
- No new YAML fields.
- No auto-zoom: steps open at Fit.
- No game/ change, no deploy, no rewrite of the P2.3b round's texts.
- No fix for the owner's clipped HUD text in Firefox (not reproduced; minimum font size ruled out, page zoom unchecked).

## Anti-goals

- Anything that cuts the "Look at" text.
- Anything that lets the stage collapse or overflow its column.
- Any Claude's-pick marker that can be read as "the option you are viewing".
- Pick and its controls jumping between options.

## Approaches

1. **Restructure the existing templ page in place (chosen).** This needs a CSS grid with three areas and a fixed stage row. It moves markup between `steps.templ`, `parts.templ`, `viewchoice.go`, `viewmodel.go`, `app.css` and `warroom.js`.
2. **CSS-only reskin.** Rejected: putting Options on the right with Pick under the list needs a different DOM order.
3. **Move the step page into the Svelte island.** Rejected: it goes against the 2026-11-19 choice of templ, plain CSS and a small page script.

## Layout (desktop, >= the existing phone breakpoint)

**Left panel (~260 px), the same on every step kind:**
- named step tabs: today's chips, with the step key or short question as the name, plus Summary;
- eyebrow (round, step n of m) and the question;
- the always-visible "Look at" callout, in amber, shown in full and never clamped;
- Details fold-outs, all closed by default: "Why this question" (`why`), "Claude's reason" (`recWhy`), "This round" (round `intro`);
- the existing info blocks (checklist, uses, numbers, folds), also under Details, closed by default.

Today `Info` opens `why` on desktop, and step 1 opens the intro. Both change to closed, and the summary page keeps its intro open.

**Centre:**
- **The stage zone.** Its height is `100dvh` minus the fixed bars (header, status line, "More of" strip) and is computed by CSS, not JS. The stage fills the column width and never exceeds it. The live bug (Window 1280 x 800, True 100 %) must stay inside the column; content larger than the zone scrolls or scales inside the zone, never past it.
- **One muted status line under the stage.** It lists the current view values, such as `Window · Fit · Sand · Plain ground · Normal vision`, taken from the existing control state. Then come `Side by side (W)` and `Large (L)`, and `View ▾`, a disclosure holding today's whole `CtlBar`. Every control key keeps working with the menu closed.
- **One strip, "More of <option>".** It shows the selected option's `extra` pictures and follows the selection; a click opens Large. It is hidden when the option has none.
  - An extra with `local: true` whose file is missing is left out, and today's "Your mock (local, not committed)" placeholder goes.
  - If nothing is left, the strip is not drawn. Its space stays reserved, so the stage zone height does not depend on the option.
- **Side by side (W).** It keeps today's side view (the Today tile plus all option tiles, one shared Pick) inside the stage zone at the same fixed size. The right Options panel stays, with Pick in it. Tiles show only the picture and a header (letter, name, Claude's pick tag), because the panel carries the text. "More of" follows the selected tile. With more than four tiles the zone scrolls inside itself (my calls). Correction: the approval message said "two tiles"; the owner's pick was "keep today's side view … with Today pairable", and today's side view already shows the Today tile next to every option.

**Right panel (~340 px), choice steps (`pictures`, `text`, `audio`, `lab`):**
- **Options list.**
  - First comes "Today" (from `ref`): a muted, dashed row on key 0, labelled `ref.label`. Choosing it shows the Today render on the full stage; it is viewing only, never a pick. T stays the built-in `tier` control, and digits 1 to 8 already pick A to H (user, 2026-11-21). While Today is shown, Pick is disabled and Enter does nothing, so no option can be recorded unseen. Showing Today is client-only, not URL state (my call).
  - Then a row for each of A to H: the keycap, the name, a "Claude's pick" tag on Claude's own row only, and `notes` as an always-visible line. The selected row is marked with `--sel`.
- **Directly under the list, with no spacer:**
  - `Pick X (Enter)`, letter only (cherry-picked `0158eb3c`; its width stays constant);
  - the neutral button with its hint;
  - the note field (`NoteBox`, moved here from the left);
  - Back/Skip (`StepNav`, moved here).
- Option text beyond `notes` (`sees`, `changes`, the option's own `folds`) goes in a left Details fold-out, "About <letter>", that follows the selected option and is closed by default (user, 2026-11-21). The right-hand `Details` section goes away.
- Today's flip bar above the stage goes away, because the Options list replaces it.
- The `ptab` "Claude's pick" tab inside the Pick button goes too, since the row tag carries the pick (builder: confirm it isn't needed elsewhere).
- Confirm steps (one option) show the single row plus Yes/Change in the same place.

**Other kinds** (`gallery`, `verdict`, `tune`, `wording`, missing, summary) use the same left panel. Their own main content goes in the centre, and the note and nav sit under it. They get no right panel unless that kind already has a list (builder's call, kept minimal).

## Phone (the existing phone breakpoint, tested at 390 x 844)

- Order: question and "Look at", then the stage, then the options, then a sticky bottom Pick bar.
- The stage is a fixed 4:3 box at full width, the same on every step and option.
- The bar is today's `PhoneBar`, kept; its Note button opens the note field above the bar.
- There must be no horizontal scroll.

## Authoring rule and loader warnings

The README Rounds section states the rule:
- the question takes one line (about 70 characters);
- `notes` takes one line of about 90 characters;
- `look` takes one line of about 120 characters;
- everything else goes in `why`, `recWhy`, `intro` or `folds`.

`rounds.go` appends a warning for each over-long text. Warnings go to the server log and `go run . open` (they reuse `Warnings`) and never to the page. Text is never cut. The exact limits are the builder's call within those numbers. Backticks don't count toward the length, which is measured after `unmark`. `p2-3b-dock` will warn, and that is expected.

## Tests (browser, playwright-go in Firefox; `go test -tags browser ./internal/web/`)

Run them against `p2-3b-dock` (served from `rounds/`) and the demo rounds:

1. **Same stage rect across crops.** The stage zone rect is equal on the `p2-3b-dock` cost step (crop 460 x 260) and on a full-frame step, at 1440 x 900 and at 1280 x 800.
2. **Pick stays put.** The Pick rect is unchanged across options A to D and between those two steps.
3. **Stage fits its column.** At viewport 1280 x 800 with Window 1280 x 800 and True 100 %, the stage's right edge is at or inside the centre column's, and no option row or control is cut off (the live bug).
4. **Pick visible.** At 1440 x 900, Pick is visible without scrolling.
5. **Phone.** At 390 x 844 there's no horizontal scroll; the question, "Look at" and the Pick bar are visible; and the stage box is 4:3, the same on two steps.
6. **Same placement everywhere.** In a round with a Today picture plus extras on two options, Today is always the first Options row and extras are always in the "More of" strip, on every step.
7. **Missing local extra.** A missing `local: true` extra is not drawn.

Plus Go unit tests for the length warnings, through the loader's existing warning tests. Existing browser tests are updated where the DOM moved. They are not deleted unless the behaviour they pinned is gone (state which, per test).

## Docs

- `warroom/README.md`: the Rounds section (authoring rule, warnings), Keys (0 for Today, View menu) and Stage controls.
- Guide chapter 13, War Room section, and its `Checked against` footer.

## Gates

- In `warroom/`: `sh tools/quality.sh` and `go test -tags browser ./internal/web/`.
- In the repo: `sh tools/run_checks.sh`, `sh tools/check_public.sh` and `python3 tools/roadmap.py --check`.
- One batch of offscreen screenshots (1440 x 900, 390 x 844) for the player-experience reviewer, then the owner's look in Firefox.

## Left to the builder

- Exact pixel widths, gaps and colours, within `app.css` tokens.
- The fixed bars' exact heights.
- How the status line reads its values.
- Character limits within the numbers above.
- Whether `Today` reuses the existing ref `Picture` markup.
