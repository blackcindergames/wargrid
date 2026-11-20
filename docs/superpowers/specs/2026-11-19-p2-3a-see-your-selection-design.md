# P2.3a See your selection: design

Status: approved by the user 2026-11-19 ([design answers](../../reference/design-answers-2026-11-08.md#spec-review-follow-ups-user-2026-11-19)); the offline freeze signal settled the same day after a research round; the owner's answers at P2.3a1's stop gate A applied the same day ([gate A](../../reference/design-answers-2026-11-08.md#p23a1-gate-a-user-2026-11-19); unreviewed until the plan reviews pass; review round 1 applied the same day), each changed spot marked (gate A, user 2026-11-19); gate A's round 2 and the director round after it (queue cap, forecast card, `warn`, build buttons and the order row by selection, low power named) were applied in the night run's docs pass, marked the same way. It covers the whole [P2.3a row](../../packages.md#day-lane), split into three packages (user, 2026-11-19). Decisions marked (user, DATE) come from the owner's questionnaires: [groundwork questionnaire](../../reference/design-answers-2026-11-08.md#p23a-groundwork-questionnaire-user-2026-11-17), [A/B lab picks](../../reference/design-answers-2026-11-08.md#p23a-ab-lab-picks-user-2026-11-18), [design round](../../reference/design-answers-2026-11-08.md#p23a-design-round-user-2026-11-19), its [advisor review](../../reference/design-answers-2026-11-08.md#advisor-review-of-the-p23a-answers-user-2026-11-19) and the [spec review follow-ups](../../reference/design-answers-2026-11-08.md#spec-review-follow-ups-user-2026-11-19). The agent's calls are listed at the end. The code facts come from a read-only survey at `main` `62e6b3c` (2026-11-19), built on the groundwork notes (`p2-3a-groundwork.md`, private) and their refresh, and from a builder check and three reviews of the first draft (player-experience, a fresh Opus correctness reviewer and Codex gpt-6.2-astra high, 2026-11-19; reports private). Visual values live in the [layout reference](../../reference/hud-v5-layout.md), the [HUD v5 pictures](../../images/hud-v5/notes.md) and [map art round 6](../../reference/map-art-shapes.md#p23a-see-your-selection-map-edge-canvas-and-marks); this spec links them rather than repeating them, except where it changes them.

## Why

Today's match HUD is a debug readout. One label prints `Credits: %d | Power: supply/demand | Tick`, unit ids, modes and raw simulation errors (`game/scripts/match/hud.gd:59,130-168`). A refused order shows the simulation's English with a `Rejected: ` prefix. The order voice plays before the answer, so a refused order says "yes sir" and then beeps (F29). The beep itself is barely audible (F30). The match runs in `keep` aspect with black bars on wide screens, nothing is anchored to the screen edges, and map marks are green and red boxes. HUD v5 (2026-11-16) and map art round 6 (2026-11-17) drew the replacement, and the A/B lab (2026-11-18) settled the open looks. P2.3a builds it.

The full row is about 16 tasks, more than one 15 to 20 minute playtest can judge, so it ships as three packages (user, 2026-11-19). Each has its own card, release and rendered row, so the cost of `expand` and the cost of the new marks show up separately.

## Packages

| Package | Name | Holds | Gate rows |
|---|---|---|---|
| P2.3a1 | See your selection | one theme, stretch with caps, edge anchoring, top strip, Menu and Playtest chips, online notices, interim slab, the whole selection panel, the refusal line with today's words, the click resolver, `view_player`, palette A on the bodies | HUD with a 120-unit selection at 1280x720 and 2560x1080 |
| P2.3a2 | Know why an order failed (user, 2026-11-19) | wording table (match and launcher), F29, F30, the N-cap rider, the Esc menu | rendered rerun with a refusal shown during the sample |
| P2.3a3 | Read the battlefield (user, 2026-11-19) | white marks, hover ticks, drag box and preview, rally and target line, map edge and canvas, health-bar rule and size | damaged-army row at 1280x720 and 2560x1080 |

The three run back to back, then P7 (superseded: P2.3b, P7 and P15 now run between P2.3a1 and P2.3a2, [fun-first reorder](2026-11-20-fun-first-reorder-design.md), user, 2026-11-20); night 8 Play on after a leave takes the first free night gap after P2.3a1 (user, 2026-11-19). P2.5 needs only P2.3a1 (credits left and build percent in the panel). This session writes the plan for P2.3a1 only; P2.3a2 and P2.3a3 get their plans when the owner starts them (user, 2026-11-19).

## Goals

### P2.3a1 See your selection

- **One theme** (user, 2026-11-15): `game/ui/launcher_theme.tres` grows into the one theme for launcher and match (user, 2026-11-17). Set A tokens (user, 2026-11-18), plus the warning colour `warn` `#f47b6c` for low power, the shortfall, the refusal line and the freeze card's mark; amber keeps alerts and primary buttons; no saturated red text (gate A, user 2026-11-19). Public Sans 400/600/700, tabular numbers through a `FontVariation` with `tnum` (user, 2026-11-17). Type scale 12, 13, 14, 16, 24, 30 with a 12 px floor; the launcher's sizes snap to it, 15 up and 17 down to 16, 23 to 24 (user, 2026-11-19). Spacing 4, 8, 12, 16, 24, 36 where a file is touched, square corners in the match, at most 2 px in the launcher, no drop shadows (user, 2026-11-15).
- **Stretch with caps:** `expand` instead of `keep`, the match capped at 2.4:1 and at 16:10, the same online and offline; Godot's black bars beyond the caps (user, 2026-11-17 and 2026-11-19). The launcher stays uncapped (user, 2026-11-14, confirmed 2026-11-19).
- **Anchored HUD:** every HUD element anchored to the screen edges per the layout reference.
- **Top strip:** an 8 px swatch in your slot colour (user, 2026-11-19), `CREDITS 4800` (plain digits, no thousands separator anywhere (gate A, user 2026-11-19)), `POWER used / available`, the value and `LOW POWER · DEFENCES OFF` in `warn` when used exceeds available (`POWER 12 / 10`), naming low power's one effect: powered defences hold fire (`combat.gd` `_is_dark`) (gate A, user 2026-11-19). The strip always shows the real numbers and never grows. While a building is armed, the `AFTER PURCHASE` card sits under the strip with the values after the purchase: `CREDITS 3600` and `POWER 11 / 10 LOW POWER · DEFENCES OFF` for a building that uses power, `POWER 8 / 15` for a power plant, `CREDITS −700` (U+2212, the shortfall) when you cannot afford it; values with a problem and the low-power words in `warn`, the others in `text`; no arrow, which Public Sans lacks (gate A, user 2026-11-19; replaces the in-strip forecast of the design round). No tick counter and no "You are blue (P1)" (user, 2026-11-17).
- **Chips:** Menu with its `Esc` chip top right; `PLAYTEST n / m` under it, from which the checklist and the note form drop down; the F3 overlay under the chip too (user, 2026-11-16 and 2026-11-17), or left of the checklist when it does not fit above the slab (gate A, user 2026-11-19).
- **Online notices** at top centre (user, 2026-11-17), in today's words until P2.3a2's table words them.
- **Offline freeze card:** a failed offline pump shows a variant of the Victory/Defeat result card with `Copy report` and `Back to menu`, not a line at top centre (gate A, user 2026-11-19); the online endings join the card in P2.3a2. Details in [Offline freeze notice](#offline-freeze-notice-p23a1).
- **Interim slab:** today's button column (build menu, Produce, Cancel construction, queue) becomes one bottom-right slab in the command card's future rectangle until P2.3b; no key-hint block: the keys sit on the buttons, with interim `Attack move (A)`, `Stop (S)` and `Unload (F)` buttons, Unload moving from `U` to `F`, and the keys printed in the player's keyboard layout (gate A, user 2026-11-19); the order row only while the selection holds an own unit with a weapon, the build buttons only while nothing or exactly one own builder alone is selected, an unaffordable price in `warn`, updated live, a capped queue and the system crosshair while attack-move is armed (gate A, user 2026-11-19); the resume hint stays contextual at its top (user, 2026-11-17, kept at gate A); the armed build button shows the cyan armed look (user, 2026-11-19).
- **Selection panel** on the bottom edge, only when something is selected, as tall as its content, no command buttons (user, 2026-11-16). States in [Selection panel](#selection-panel).
- **Refusal line with today's words:** the `warn` line (gate A, user 2026-11-19) at its final place with its timer and rules, showing the simulation's text until P2.3a2 words it (user, 2026-11-19).
- **Clicks:** one resolver for click and hover: tier (unit, building, pile, ground), then own before others, then front-most (user, 2026-11-16 and 2026-11-19). Hover and click always name the same object, any owner, piles included; in P2.3a1 a hover shows what it shows today (the health bar under today's rule, the resume outline), now for any owner, and the corner ticks come in P2.3a3. The HUD blocks the map. Shift-click toggles a unit on the map (user, 2026-11-19). A pile is inspected by a click, never by a drag (user, 2026-11-17). No mixed unit and building selection (user, 2026-11-17).
- **`view_player`** beside `local_player` (user, 2026-11-16; in P2.3a, user 2026-11-17).
- **Palette A on the bodies** so the panel edge matches the unit (user, 2026-11-19).
- **Rebuild on change:** the strip and panel rebuild only when their inputs change (user, 2026-11-19).

### P2.3a2 Know why an order failed

- **Wording table:** the refusal line speaks player words from one table for match and launcher (user, 2026-11-16 and 2026-11-17). Details in [Refusals](#refusals).
- **F29:** the order voice and the order hint play only for accepted orders (user, 2026-11-16).
- **F30:** the refusal beep's level, picked by ear (user, 2026-11-19).
- **Sound rules** (user, 2026-11-20, from the P2.3a1 night's P2.3a2 research, private): local hints stay silent; one beep per frame across issue-time and due-time refusals; a 300 ms beep cooldown, judged by ear in P2.3a1's stop gate B batch; no beep while the result card shows; "Not enough credits" repeats with no cooldown, as in Zero Hour.
- **Line rules** (user, 2026-11-20, same research): a repeated refusal restarts the 3 s timer; the neutral-line rules and placement reopening after a due-time refusal as the research words them; the P2.3a2 plan writes them out.
- **Words** (user, 2026-11-20, same research): the plan takes the research's proposed lines for the launcher's connection and map-mismatch words, "your friend" in the launcher and rematch line versus "your opponent" in match, the shortened opponent-left line, the kept game-error line and "Order not possible" for an invalid producer; `Select a container` (F key only; China has no transports) reads "Nothing to unload", silent like the other local hints, and the simulation's empty-host refusal, if there is one, uses the same words; the player-experience reviewer checks the whole table there. No builder "can't build" voice. The raw refusal record keeps the simulation text without the `Rejected: ` prefix.
- **Scope:** words only (user, 2026-11-20). Order behaviour that differs from Zero Hour is an Order controls rider in `packages.md`; "Cannot move there" keeps its beep until it lands.
- **Relay words in the launcher** through the same table, including the flood case (user, 2026-11-17 and 2026-11-19).
- **Esc menu** in the launcher Settings structure: two columns, opaque panel, the launcher's switches (user, 2026-11-14 and 2026-11-19).

### P2.3a3 Read the battlefield

- **White marks** by shape over one under-stroke rule, at a constant screen width (user, 2026-11-15 and 2026-11-19). Details in [Map marks](#map-marks-p23a3).
- **Map edge B on the canvas `#08090A`** (user, 2026-11-17).
- **Health bars** on "damaged or hovered" (user, 2026-11-18), drawn in screen space on whole pixels; the step rule is picked from a capture pair (user, 2026-11-19).

## Non-goals

- The command card, position keys, the factory queue row, the cell card, the 55 % placement ghost (P2.3b; user, 2026-11-17 and 2026-11-19) and the range ring (P2.3b; user, 2026-11-15).
- Glyphs (after P2.6), the minimap (P3), the alert feed, group row, idle-builder button and pinned factory.
- A right-click remove-one gesture on kind rows (user, 2026-11-19, revisited with control groups).
- An owner name on panels: P7 adds it with more than one opponent (user, 2026-11-19).
- Tiers or binary for the drag box: decided after a playtest with the preview visible (user, 2026-11-19); the rule is drafted under [Later](#later-drafts-and-riders).
- A health-bar "Always" setting: a later settings item (user, 2026-11-19).
- Sound under `view_player`: alerts stay on the seat in P2.3a (agent call).
- The `.` key-cap readability check (`map-art-shapes.md:59`): handed to P2.3b, which draws the first key chips beyond `Esc` (agent call).
- Palette A green `#4ad49b` against the `ally` token `#69ceaa` (ΔE 15.0, 7.8 under simulated deuteranopia, bar 20; `map-art-shapes.md:60`): no Core element in P2.3a shows `ally` beside an owner colour, so it is decided at P3's minimap, where the `ally` token first appears (user, 2026-11-19).
- Neon removal and the faction shapes: P2.4.

## Anti-goals

- Any simulation change or trace re-pin ("words only, no simulation change", row). The pair gate is the tripwire.
- Overflow code for selection panels: a layout test proves the largest roster fits (user, 2026-11-15).
- A HUD that reads the simulation or the pump directly (`tools/test_sim_boundary.py`).
- Blocking the playtest form or leaving a match (F22).
- New fields in `view_state()` for the panel; aggregate in presentation from the existing view rows (the plumbing rows are already over budget, `docs/reference/performance.md:30-31`).
- Loosening a budget, ceiling or test expectation to make a row pass.

## Constraints

- Typed GDScript; lint and warnings clean; headless tests through the [simulation interface](../../reference/sim-interface.md) plus static `definitions/` data.
- Headless layout tests at 1280x720, 1280x800, 1920x1080 and 3440x1440 (the row's three sizes plus the owner's non-16:9 pick, user 2026-11-17), using the stretched `[window, logical]` pairs: `[1280x720, 1280x720]`, `[1280x800, 1280x800]`, `[1920x1080, 1280x720]`, `[3440x1440, 1720x720]`.
- Rendered benchmarks need a quiet host. Another Claude session or the Codex app made an A/A pair gate go red at 1.03 on 2026-11-19; the owner is told so when a window is asked for.
- The pair gate runs with the approved `MAX_RATIO` (p95 1.020, p99 1.025; `tools/perf_pairs.py:17`, [performance](../../reference/performance.md) "Pair gate (benchmark pair gate, 2026-11-19)"). P2.3a changes no timed combat code, so its pair step mostly guards against accidents; the rendered rerun and its row are the presentation evidence.
- Sound code (`sound_*`, `game/audio/`, `tools/audio/`) is touched only after reading the sound spike design, evidence note and plan (AGENTS.md); F30 and F29 are in P2.3a2.

## Approaches

Three ways to build the HUD were weighed; the owner picked the first ([design answers](../../reference/design-answers-2026-11-08.md#spec-review-follow-ups-user-2026-11-19); user, 2026-11-19). The call's name and arguments below are an implementation proposal.

1. **A new HUD node with a narrow input, tests moved first (picked).** `hud.gd` today is a `RefCounted` that reads 24 match-screen members and also drives sound, the inspected mark and the build menu (`hud.gd:40,45,69,101`). It becomes a Control node with one update call, signals out, and no side effects. Text-pinned tests move to node ids first, so the suite stays green. Pay-off: the benchmark hosts the real HUD for the gate rows without a match screen, and the boundary check holds.
2. **Panels beside the old label, label removed last.** Smaller first steps, but two HUDs live side by side for most of the run, and the benchmark still cannot host it without the screen.
3. **Promote the lab panel as is.** Fast to look at, but lab code has no live selection or view input and is fixed at 1280x800 (the refresh calls it reference only).

## Design

### Shared groundwork (P2.3a1)

**HUD node.** A `Hud` Control under the `HUD` CanvasLayer replaces `hud.gd`'s text label. Its root is full-rect with `MOUSE_FILTER_IGNORE`; only occupied panels, chips and buttons stop the mouse.

- **Input:** `update_hud(view: Dictionary, selection: Dictionary, view_player: int, seat: int)`. Not `show()`: a Control already has `CanvasItem.show()`, and GDScript refuses an override with a different signature. `view` is the published `driver.current().view` (`match_screen.gd:299`). `selection` holds `ids`, `building_id`, `inspected_id`, `placement_kind`, the resume candidate (`world_view.resume_candidate()`, hover-dependent, not in the view), the driver's notice line and the refusal line. `seat` (the `local_player`) feeds the build menu's faction and `_production_kind`; `view_player` feeds every display read. Forecast and panel arithmetic read `definitions/` directly, as presentation already does (`hud.gd:4-5`).
- **Output:** signals for menu choices, queue cancels, Produce, Cancel construction, the interim Attack move, Stop and Unload buttons (gate A, user 2026-11-19) and kind-row clicks (`row_clicked(kind, shift)`); the screen wires them to orders.
- **No side effects:** the sound update, `set_inspected` and `orders.menu` move into `match_screen._show` (`match_screen.gd:314-327`). The result panel's update (`show_result` with the driver's rematch line, play-again, rematch-pending, friend-wants-rematch, match stats and opponent-left, `hud.gd:65-75`) moves to the match screen, and `_result_text` (called at `match_screen.gd:158`) moves with it into the result panel; `reset()` (`match_screen.gd:393`) becomes a method of the `Hud` node. `_unit_record` and `_inspected`, which orders reuse today (`orders.gd:71,263`), move to a static helper, so orders stop reading the HUD.
- **Rebuild on change:** the node rebuilds its child nodes only on a structural change (the selection ids, the set of kinds, the panel state, the placement kind, the notice, the refusal); values (health, counts, credits, power, percent) patch bar widths and label texts in place, and only when they differ. A headless test expects zero rebuilds across a fight with an unchanged selection and one rebuild per selection change (agent call, builder check).
- **Test helper:** `hud_text()` in the test base returns every visible HUD label's text joined, so behaviour tests that only check words keep working.

**Theme.** The grown `launcher_theme.tres` holds the tokens as theme colours and styleboxes, the type scale as type variations, the `tnum` `FontVariation` and the spacing. It is set once as the project theme (`gui/theme/custom`), replacing the six per-node assignments (`match_screen.gd:66-67`, `pause_menu.gd:34`, `perf_overlay.gd:22`, `playtest_overlay.gd:43`, `playtest/focus_card_view.gd:23`, `match/result_panel.gd:26`), and `ui_style.gd` goes. Its `FONT_SIZE` consumers move with it: the two map-label calls (`world_view.gd:336,669`) and the pile-spacing test (`test_skirmish_scene.gd:328`) read a map-label size constant beside the theme; map labels keep `ThemeDB.fallback_font` until P2.5 removes them. The launcher scene's local 20 px join-code override (`launcher.tscn:316`) snaps to the scale (16 or 24, whichever fits the field at 1280x720), and T1 (`test_launcher.gd:868`, which pins 15, 17 and 23) asserts the effective control sizes instead. Drawing code that needs token colours reads them from one place (builder's choice: the theme or a small constants script beside it, not both).

**Stretch and caps.** `project.godot` sets `window/stretch/aspect="expand"`. One pure function `layout_for(window: Vector2i) -> {size, aspect}` decides:

| Window aspect | Content scale size | Aspect | Result |
|---|---|---|---|
| above 2.4:1 | 1728x720 | `keep` | side bars |
| below 16:10 | 1280x800 | `keep` | top and bottom bars |
| otherwise | 1280x720 | `expand` | no bars; 2560x1080 gives 1706x720 (Godot floors the viewport size, `window.cpp:1377`), 3440x1440 gives 1720x720 |

- **Host:** no app shell node outlives a scene change (the launcher frees itself at match start, `launcher.gd:538`), and an autoload would also run inside the test runner. So a static `apply(root)` installs the layout and connects `size_changed` when a capped scene enters the tree (the match screen, the benchmark) and restores plain `expand` at 1280x720 when it leaves; it writes only when the value changes (rewriting re-runs Godot's viewport update, `window.cpp:1328-1418`). The labs keep their own 1280x800 override and restore on exit (LB16, `test_selection_lab.gd:430-441`).
- **Launcher:** uncapped `expand` in any window (user, 2026-11-14, confirmed 2026-11-19 after two advisors): the caps bound the online vision edge and the draw cost, which a menu does not have, and black bars would stand out on the launcher's grey. Guard: the cap handler never runs while the launcher is open, and entering the launcher resets the size to 1280x720 as well as the aspect, so a match's 1728x720 or 1280x800 cannot leak back. The launcher's own keep switch before an online match (`launcher.gd:535`) goes, since the match applies its caps on entry; its enter toggle (`:57-61`) becomes that reset.
- **No rounding:** a `keep` size must not be rounded to the window aspect inside the cap; integer rounding fails Godot's `is_equal_approx` and gives 1 px bars.
- **Bars:** Godot's fixed black; the compatibility renderer clears them before the blit (`drivers/gles3/rasterizer_gles3.cpp:427-435`), so against the canvas `#08090A` they are a different shade only nominally (contrast 1.05:1), which the owner accepted (user, 2026-11-19). The view's edge is read from the map edge and the anchored HUD, not from the bars.

**Palette A on the bodies.** Palette A's owner colours and its darker side faces `SIDE` `#1c2e39` and `SIDE_DARK` `#0e1b23` (`game/scripts/lab/lab_look.gd:21-26,53-57`; `map-art-shapes.md:100` lists the sides with palette A) move into `palette.gd`, the look the owner judged in the lab, so panel edges, bars and bodies share one owner colour per slot. One owner-colour function serves all three, so P2.4's opt-in friend/foe mode can switch it later. Neon stays until P2.4. The world-batch colour goldens and SH15 are re-pinned once, in their own commit.

**`view_player`.** `match_screen` gets `var view_player: int`, set wherever the seat is set (offline at start, online in `setup()` after the seat arrives, `match_screen.gd:60`, and again on rematch), never copied once at declaration, where `local_player` still holds its default 1 (`match_screen.gd:37`). The HUD and the world view's display reads (`world_view.gd:375,389,556`; `match_screen.gd:99,134`; the strip's player row) take it; picks, orders, the seat and sound keep `local_player` (survey table). `_local_state` splits into a view read (strip) and a seat read (faction for the build menu).

### Layout (P2.3a1)

Rectangles and looks for the top strip, Menu, Playtest, the selection panel and kind rows come from the [layout reference](../../reference/hud-v5-layout.md) and [`layout.json`](../../images/hud-v5/layout.json) (Core set). Additions this design makes:

- **Swatch:** 8x8 in your slot colour, first in the strip, 8 px before `CREDITS`.
- **Forecast card** (gate A, user 2026-11-19): at (8, 48) under the strip while a building is armed, gone on place or cancel; a `bg` slab with a 1 px `line`, padding 8, square, width hugs (about 490 x 56 at 1280x720 at its longest); the match ending clears the placement (a won or drawn match, or an ended online match), so it never shows over a result card or an ended online notice; line 1 a muted `AFTER PURCHASE`, line 2 the after-values with muted 12/600 labels and 16/700 `tnum` values, counting live as credits change.
- **Chip stack, top right:** Menu at right 8, top 8; Playtest at right 8, top 48; the checklist drops down from right 8, top 88; the note (marker) form opens below the checklist when both are open, never overlapping it (PO8 requires both visible and disjoint, `test_playtest_overlay.gd:319`); F3 sits below whatever is open, at top 88 when nothing is; when it does not fit between the open helper surfaces and the slab top minus 8, it opens left of the checklist (or under the note form when the form already sits there), the note form's rule; with the checklist closed F3 stays under the Playtest chip (top 88, or below the note form when only the form is open) (gate A, user 2026-11-19), and when only the form is open and F3 does not fit below it, F3 opens left of the form at top 88 (agent call, plan Task 7); with the playtest helper off, the chip is hidden and F3 sits at top 48. The `Esc` chip on Menu shows only when Esc would open the menu: it hides while `orders.escape_pending()` is true (a placement, a selection or an inspection, `orders.gd:53`), because Esc then backs out of that first (`match_screen.gd:194-199`); hidden often, never wrong (user, 2026-11-19). This is the layout reference's rule (hidden in the build and place states, user 2026-11-16) applied to today's Esc order; the reference's Menu bullet gets the same words in the docs step.
- **Online notice:** centred, top 48, 28 high, a `bg` slab with a 1 px `line`, muted 13/600, no square (agent call). At 1280 a top-8 notice would hit a long forecast strip. Online only in P2.3a1: the offline freeze shows a card instead (gate A, user 2026-11-19).
- **Interim slab:** x `W - 432`, 432 wide, bottom on the screen edge, growing up; `bg` fill drawn on the `Economy` VBox's `draw` signal so its child paths (`Economy/BuildMenu`, `Produce`, `CancelBuild`, `Queue`) and their 18 test references stay; 4 px own edge, `line` top border, padding 8 and 12 left; buttons 32 high on `btn`; no key-hint block and no kind-row hint in the slab (the kind-row rule is the selection panel's footer) (gate A, user 2026-11-19); `Right-click: resume` as one muted 12/400 line at the slab's top, only while a paused site is hovered with a builder selected (kept at gate A); interim order buttons in a two-column row 8 px above the build menu: `Attack move (A)` and `Stop (S)` only while the selection holds at least one own unit with a weapon (builders or collectors alone get none, as Zero Hour's dozer command sets carry neither), `Unload (F)` only while an own container is loaded: a Tunnel Hub exactly, through the local player's record (`HudModel.player(view, seat).get("tunnel", [])`; `players` is sorted by id and the key appears at the first enter), a Scout Car or Armed Pickup while some own unit row has `ViewRows`' `CONTAINED` flag (the view has no container id, so a dead button remains only in the rare mixed case; no view field added); calling today's input paths, no new command; P2.3b's grid replaces them (gate A, user 2026-11-19). While attack-move is armed the pointer is the system crosshair beside the button's armed look, no hint line, until the pointer-set package draws Wargrid's own (gate A, user 2026-11-19). The build buttons show only while nothing or exactly one own builder alone is selected, exactly when placement accepts a build click (`orders.gd:284-287`), so no shown build button can only fail; an army selection, a builder with an armed unit or a collector, and two builders show none (the order row where an armed unit is selected) (gate A, user 2026-11-19; the multi-builder case is an agent ruling, the pick of one builder is the Order controls rider). Every build button prints today's words, the name left and the price as its own right-aligned label; a price the player cannot afford prints in `warn`, updated live as credits change (gate A, user 2026-11-19). The queue is capped: a header `QUEUE` with `N waiting` at its right, no `1.` numbers, the entry in production with its percent and a 2 px own-colour line on a dark track, then 3 next; up to 5 entries all show; from 6 a full-width `Show N more queued` row with a drawn chevron opens the rest and reads `Show fewer` while open; the list collapses on a selection change or at 5 or fewer; a click anywhere on a row cancels it, the × is its sign (gate A, user 2026-11-19). Their keys print the bound physical key in the player's keyboard layout (AZERTY shows `Q` for physical `A`), QWERTY where the platform cannot answer (the web export and headless runs), through one helper P2.3b's key chips reuse; the key comes from the live binding, never a hand-written label, and a disabled button keeps it (gate A, user 2026-11-19). The build buttons keep today's words with `$1200` (the price as its own right-aligned label) and the 1-9 and E keys until P2.3b; the mouse rules go to the Esc menu's Controls list (P2.3b, see Esc menu), no F1 overlay (gate A, user 2026-11-19). The build menu takes as many columns as fit the longest labels of every faction in 432 px (user, 2026-11-19) (China's four-column labels need about 520 px at 12/600 before padding, measured by the Codex review; today `match_screen.gd:18` sets 4). The armed build button shows the cyan armed look (`panel2` with a 2 px `sel` inset, user 2026-11-19). `place_economy` goes. At 1280 wide the slab (x from 848) clears the selection panel and a refusal line up to about 416 px wide.
- **Refusal line:** centred at y `H - 204`, 28 high, a `bg` slab with a 1 px `line`, an 8x8 `warn` square, `warn` 13/600 (layout reference "Refusal line"; `warn`, gate A, user 2026-11-19).

### Selection panel

Bottom left, x 0, 408 wide, as tall as its content; `bg`, 1 px `line` on top and right, a 4 px owner edge inside the left side, padding 12 and 16. Health reads `cur / max` rounded up (user, 2026-11-17), in plain digits (`5000 / 5000`) (gate A, user 2026-11-19). Heights: the identity block is 62 and a key-value line adds 24 (layout reference); a footer hint line adds 22 (agent arithmetic: 14 line plus 8 gap).

| State | Content | Edge | Height |
|---|---|---|---|
| nothing selected | panel hidden | | 0 |
| one unit | name, health bar and `cur / max` (user, 2026-11-17) | own slot | 62 |
| one collector | as one unit, plus a muted caps status label on the name row (below) | own | 62 |
| many | header `N selected · K kinds`, with ` · n idle collector(s)` when selected collectors are idle (user, 2026-11-19); kind rows 186x26 in two columns, roster order (user, 2026-11-17); one kind still shows one row (user, 2026-11-19); with two or more kinds the footer `Click a kind: select only that kind · Shift-click: deselect it`, hidden at one kind (gate A, user 2026-11-19) | own | 76 at one kind; 98, 128 or 158 for 2, 3-4 or 5-6 kinds (76, 106, 136 plus the 22 px footer) |
| own building | name and health | own | 62 |
| powered building (kind `powered`, the defences) whose owner is short of power | as its building row, plus `OFFLINE · LOW POWER` in `warn` caps on the name row, for any owner, because the view already carries every player's `power_supply` and `power_demand` (`simulation.gd:792,912-923`; no new view field) (gate A, user 2026-11-19) | owner's slot | 62 |
| power plant | name, health and `POWER +n` (producers only, user 2026-11-19) | own | 86 |
| factory (interim) | name, health and the muted footer `Right-click ground: rally point`; no queue row until P2.3b (user, 2026-11-17) | own | 84 |
| own site | name, `UNDER CONSTRUCTION` label, progress bar in the owner colour with the percent, health | own | 86 |
| own paused site (`builder_id == null`) | `PAUSED · NO BUILDER` instead of `UNDER CONSTRUCTION`, muted, no amber (user, 2026-11-17); the progress bar in `muted` instead of the owner colour (gate A, user 2026-11-19) | own | 86 |
| enemy or allied unit or building | name and health | owner's slot | 62 |
| enemy or allied site | name, `UNDER CONSTRUCTION`, progress and percent, health; never the paused label (user, 2026-11-19) | owner's slot | 86 |
| supply pile | `Supply Pile` and `CREDITS LEFT 10650` (plain digits (gate A, user 2026-11-19)), `Empty` at zero (user, 2026-11-17) | `line` | 62 |

- **Collector status labels** (user, 2026-11-19, except the `seeking`, busy-dock and contained rows, which are agent calls; [first mock-up](../../images/hud-v5/collector-status.webp), [source](../../images/hud-v5/source/collector-status.html), to be redrawn to the forms below):

  | Published state | Label |
  |---|---|
  | collecting, `flying_source` or `lead_source` | `TO PILE` |
  | collecting, `waiting_source` | `WAITING AT PILE` |
  | collecting, `loading` | `LOADING` |
  | collecting, `flying_depot` or `lead_depot` | `TO <DROP-OFF>` |
  | collecting, `waiting_depot` | `WAITING AT <DROP-OFF>` |
  | collecting, `unloading` | `UNLOADING` |
  | collecting, `seeking` (one tick between legs) | the previous label held; no label if the collector was selected during that tick |
  | collecting, `idle` while the owner has no finished building that receives supply (an unfinished site does not count) | `NO <DROP-OFF>`, muted like `IDLE`, counted as idle in the header; wins over the busy-dock row: without a finished drop-off no load can be delivered (user, 2026-11-20) |
  | collecting, `idle` with a pile holding boxes in the view (retrying a busy dock, `supply_collection.gd:101-104`) | `WAITING AT PILE`; also for a loaded truck retrying a full drop-off ring, since the view publishes no cargo (known limit, user 2026-11-20; the fix, trucks waiting near the drop-off, goes to "see your economy": [design answers](../../reference/design-answers-2026-11-08.md#p23a1-before-gate-b-user-2026-11-20)) |
  | collecting, `idle` with no pile holding boxes | `IDLE` |
  | not collecting, moving or path pending | `MOVING` |
  | not collecting, named builder of an unfinished site | `BUILDING` |
  | not collecting, inside a transport | no label |
  | not collecting, none of the above | `IDLE` |

  `<DROP-OFF>` is the display name of the viewer faction's building that receives supply, from the definitions (`TO SUPPLY CACHE` for FRC; user, 2026-11-19). The waiting labels carry no place number: the simulation orders the line by arrival tick, which the view does not publish, so `View.line_position`'s id count can be wrong (user, 2026-11-19). The simulation sets the phase to `idle` for any other task (`Simulation._detach_task`, `simulation.gd:983-987`), so the table also reads the collecting flag, the movement status, containment and the buildings' `builder_id`, all in the published view. The header's idle count uses the same `IDLE` and `NO <DROP-OFF>` rows. `IDLE` stays muted; neither amber's nor `warn`'s list grows. A table test lists every phase string the simulation can publish.
- **Kind rows:** click narrows the selection to that kind; shift-click removes it (user, 2026-11-17). Hover steps the fill to `panel2` with a 1 px `muted` inset (5.15:1 against `btn`; `panel2` alone measured 1.09:1) and shows the pointing-hand cursor (user, 2026-11-19; inset (gate A, user 2026-11-19)); cyan stays for selected. The rule is the panel's last muted 12/400 line while two or more kinds show (+22 px; [picture](../../images/hud-v5/p2-3a1-rows-footer.webp)), not in the slab and not a tooltip (gate A, user 2026-11-19). While the pointer is over the panel the row layout holds: a kind whose last unit dies keeps its row, greyed with count 0, until the pointer leaves (user, 2026-11-19). A row's bar shows `sum(hp) / sum(max_hp)` of its units in the health colours (agent call).
- **Credits left** is `boxes × box_value` of the viewer's collector kind, read from the definitions (75 in every faction today), not a literal.

**Pictures before the builders (agent call).** ART_DIRECTION §12 asks for every state drawn. P2.3a1's first task draws its states into the HUD v5 source page at 2x, beside the source: the interim slab with its hint lines (dropped at the gate for keys on the buttons) and an armed button, the top-centre notice and the freeze notice, the forecast forms (full pair, power plant, the shortfall; redrawn at the gate as the `AFTER PURCHASE` card), the swatch, the paused site, an enemy site with its percent, the chip stack (closed, checklist open, checklist and note form open, F3 open with each, helper off), the refusal line, the pile at 62 px with `CREDITS LEFT`, and the collector labels in the forms above with the idle header. The player-experience reviewer checks them against this spec and the owner looks once before the HUD tasks start (a stop gate in the plan; user, 2026-11-19). P2.3a2 and P2.3a3 draw their own states with their plans (the neutral overtaken line, the Esc menu, the marks).

### Click resolver (P2.3a1)

One read-only function in the world view, `resolve_pick(plane_point, modifiers) -> {tier, id}`, used by hover and by the click. It retires `pick_object`'s own-only first step and `_enemy_at` (`world_view.gd:638-653`, `orders.gd:398-402`).

- **Order:** tier first (unit, then building, then pile, then ground), then own before others within a tier, then front-most (user, 2026-11-16 and 2026-11-19).
- **Hit geometry per tier:** units by their selection and hit bounds; buildings and piles by their ground footprint, as today ([art integration](../../reference/art-godot-integration.md) §2 keeps building footprint picking; `world_view.gd:631,645-652`).
- **Front-most:** the rendered order, layer then depth then id, so an aircraft (air layer) is in front of a ground unit beneath it; today's pick gives every unit the ground layer (`world_batch.gd:157`).
- **Result:** an own unit or building selects; another owner's unit, building or site and any pile inspect (`inspected_id`); ground deselects. The inspected lookup learns piles, so `orders.prune` keeps a selected pile (`orders.gd:71`).
- **Shift:** shift-click on a selected own unit removes it, on an unselected one adds it; shift-drag adds (user, 2026-11-19).
- **HUD blocks:** panels, the strip, chips and the slab use `MOUSE_FILTER_STOP` over the `IGNORE` root. Entering a HUD control clears the world hover. A drag started on the map keeps its box and preview in step while the pointer crosses a panel, and its release still arrives (Godot delivers a release to the control that took the press). A drag box skips units whose anchor lies under a panel rectangle, and the drag preview (P2.3a3) uses the same filter (user, 2026-11-19). These are tested with events sent through the viewport, not through the `pointer()` test helper, which calls `_unhandled_input` directly and bypasses the GUI (`test_base_scene.gd:54`).
- **No mixed selection:** a building pick clears the unit selection and any other pick clears the building (`orders.gd:172-178`); a shift-click on an own building with units selected also replaces them (agent call).
- **Later:** Order controls wraps the same function into `{command, pointer, reason}` for right-click (the resolver shape from the OpenRA review, private).

### Refusals

**P2.3a1: one entry point and the line.** Every refusal goes through one call, `refuse(raw_error, command)`, from all four writers: issue-time answers (`match_screen.gd:160-167`), local placement refusals (`:340-344`), due-time results (`hud.gd:48-52`, sound at `sound_director.gd:133-136`) and the five local hints in orders (`orders.gd:292,342,352,368,384`). It keeps the raw text in `hud.refusal` (the moved tests read it; OV8's `hud.note == "Rejected: ..."` pin moves there too). The line shows the simulation's text, without the `Rejected: ` prefix (the `warn` square says it), until P2.3a2's table words it (user, 2026-11-19). Its rules hold from P2.3a1 on:

- about 3 s of wall time; a new refusal replaces it and restarts the timer (user, 2026-11-17); the next accepted order's answer clears it (user, 2026-11-19);
- placement refusals show only after the click, never while hovering (user, 2026-11-17);
- many refusals in one frame show the last reason once with exactly one beep (user, 2026-11-19).

**P2.3a2: wording table.** A static table maps each raw command-answer text to one of three columns (draft rows in [Appendix A](#appendix-a-draft-wording-table)):

- **Player-causable:** a short line in player words, sentence case, no full stop, with the beep, except "Not enough credits", which plays the announcer voice and no beep (user, 2026-11-19). A missing prerequisite reads `Needs <Kind>` without an article, the name from the definitions, the same words as P2.3b's cell card (user, 2026-11-19); a local preview refusal passes the placement kind so the name is known.
- **Overtaken in flight** (user, 2026-11-18): an order that was valid at the click and impossible on arrival. A dead unit or target is silent. An emptied pile ("Supply pile is empty"), a finished site ("Already finished") or a production entry no longer queued ("No longer in the queue", which covers finished and already cancelled) gets a neutral line: the same slab and place, muted text, no `warn` square (the refusal line's square, gate A), no sound (user, 2026-11-19).
- **Cannot be caused by a player** (malformed commands, guarded paths, setup): "Order not possible", raw text to the playtest record (user, 2026-11-17).

**Overtaken, decided in presentation.** The final view alone cannot tell an order on an already-empty permanent pile from one on a pile that emptied in flight (an empty pile stays in the view, `supply_collection.gd:197-199`). So at submit the screen keeps, per command, the facts it needs from the view shown at the click: the pile had boxes, the production entry was queued, the site was unfinished, the target and units existed. A pure function of `(error, command, click facts, newest view)` then classifies: overtaken when the click facts held and the newest view no longer does; otherwise the player-causable row (an already-empty pile reads "Supply pile is empty" with the beep) or "Order not possible". No simulation change.

**Joining answers and due-time results.** Sequences are per player, and the screen can drain several notes before taking one flattened answer list (a catch-up fixture shows two players' commands sharing a sequence in one tick, `test_online_scene.gd:1689`). A due-time failure is therefore matched to an issue-time success by `(command.tick, player, sequence)`, scoped to the current match; unstamped local refusals are handled apart. `move` produces no due-time row (`simulation.gd:425`), so an accepted move acknowledges on its issue answer alone. For other commands the voice waits until the results of the command's tick are known: when an accepted answer arrives in an earlier drain than its tick's due results (an offline flush, `offline_driver.gd:74`), the voice and hint hold until that tick's results arrive, at most one tick later.

**Completeness test.** The table test derives the inventory independently: it scans the command-path simulation sources (command validation, construction, combat, containers, supply) for refusal literals and asserts each maps to a row, so a new simulation text fails instead of leaking raw words. Setup and tooling errors outside the command path (`simulation.gd:88-90,150-156,862-865,966`) are out of scope. Two reachable cases the inventory called guarded get fixed at the input: `E` on an unfinished site goes through the same availability check as the Produce button (`orders.gd:122,380`), and so does a completed building that cannot train the unit, so neither sends an order.

**Playtest record.** A capped `refusals` list (tick, sequence, raw text; the last 50) in the match record, added to the record's readme in the same branch (agent call, implements "raw text to the playtest log").

**Launcher and notices.** The launcher footer's relay reasons and protocol errors and the match's driver notices go through the same table (user, 2026-11-17): the 1v1 notices name "your opponent", not "player N", because no player number is visible any more; relay loss and mid-match relay reasons share one line; the desync line is plain. A Join closed after hello and before any welcome reads "No answer for that code. Check the code, or try again in a minute." (user, 2026-11-19); no relay change. Protocol mismatch is worded per platform (reload the page on web, update the game on desktop). The table test covers the notice strings too.

**F29.** `_submit` keeps `driver.submit` and drops the hint and the voice; `_take_answers` plays them for each accepted answer, from the stamped command, unless a matching due-time failure exists (above). The move ring starts on acceptance (agent call). The voice reads speaker rows the sound director cached at its last update (`sound_director.gd:84`), which runs before `_take_answers` refreshes them; a dead first speaker must fall to a surviving one. Offline the answer comes in the same frame (one frame later with no physics step, about 33 ms at most); online at least about 133 ms after the click (input delay 4, `game/scripts/net/lockstep.gd:39`). Zero Hour plays the voice at the click, after its own client checks (`CommandXlat.cpp:909-915` @ 0a05454); the owner keeps the decision and the P2.3a2 card asks "Online, orders answered: at once / slight delay / too slow" (user, 2026-11-19). F29 removes F33's audible half (voice then beep); F33's stale preview stays P2.3b's, so the card does not read F33 as fixed.

**F30.** `error.wav` measures −34.3 LUFS (looped, ffmpeg `ebur128`), heard at about −40 after the Effects bus trim: about 10 dB under the music and 16 dB under the voices. The likely cause is the click's offset given to it in the sound spike (`docs/reference/sound-spike.md:57-58`). The fix is the cue's `gain_db` (`sound_cues.gd:17`), picked by the owner on a labelled Firefox listening page with music and voices under it, +6, +10 and +14 dB, +10 as the start (user, 2026-11-19); the sample file is not regenerated. One check inside a fight mix follows in the playtest (agent call).

**N-cap rider (#86).** The test with 200 large moves in one frame (`test_online_scene.gd:1698-1709`) also asserts exactly one reject beep, no voice for a refused order, the line's state and timer, and that the accepted orders were sent. Headless tests count emitted sound requests, because `.playing` stays false without audio.

**Esc menu.** Resume, Back to main menu and Quit on top; below, Audio on the left and Graphics and Playtest on the right, as the launcher's Settings body (`launcher.tscn:396-441`, `launcher.gd:253-361`), from one builder shared with the launcher; an opaque panel; the launcher's `CheckButton` switches and Low/High pair; no Display section (user, 2026-11-19); Neon stays until P2.4. The menu keeps its live signals (`pause_menu.gd:10-14`) by connecting them to the switches. Layout tests at 1280x720 and 1280x800, and a focus test (Esc closes it, as Resume). P2.3b adds the Controls list.

### Offline freeze notice (P2.3a1)

`OfflineDriver.notice()` returns `""` today (`offline_driver.gd:106-107`), and a refused `post()` keeps its queue for a retry (`:50`), so a failed pump freezes the match silently. Decided after research over the code, the engines and SB5 (user, 2026-11-19; [design answers](../../reference/design-answers-2026-11-08.md#spec-review-follow-ups-user-2026-11-19)):

- **Pump:** `_failed: bool` (`sim_pump.gd:50`) becomes a failure reason, first reason wins, set where `_failed` is set today (`:72` post, `:95` query): the job kind and the last published tick. A main-thread call `failure() -> String` returns it, `""` while healthy; `stop()` alone sets no reason, and a reason found after `stop()` (the leave path's `record()` query) is returned. "Raw reason" honestly means that line: the real cause is Godot's own script error on stderr just before it, which GDScript cannot catch (`run_job` has no `return null`, `:131-160`).
- **Driver:** on a refused post, `step()` reads `pump.failure()` once, logs `SIM PUMP FAILED <reason>` with `printerr` (not `push_error`, which fails the suite, `tools/run_tests.sh:46`), and keeps its queue as today; from then on, in the same frame, the match shows the freeze card (below). The playtest match record's `end` reads "sim pump failed: <reason>" (user, 2026-11-19).
- **Card** (gate A, user 2026-11-19): the one-line notice looked like a leftover debug message, so the freeze becomes a variant of the Victory/Defeat result card (`game/scripts/match/result_panel.gd`): dimmed map, centred card with square corners, its buttons too (the match rule), a warning mark and the title `Match stopped`, one body sentence, a divider, a footer row with the report's own version and map (`Version <build> · <map name>`, the launcher's map name such as `Dry Wells`; the copied report keeps the playtest record's map id) and a short code on the right, and two right-aligned buttons, `Copy report` (secondary, focused, so a reflexive Enter copies instead of leaving with the report; the error text, game version, map and tick to the clipboard) and `Back to menu` (primary). Leaving still files the playtest record. Input follows the Victory/Defeat card: the first Esc opens the pause menu, also with a selection or a placement armed, orders and placement keys do nothing behind the card, Enter never restarts the frozen match, and later refreshes keep the card, its focus and `Report copied` (agent call). It replaces the top-centre freeze line; offline only in P2.3a1, the online endings (desync, game error, opponent left, relay lost) move to the card in P2.3a2 with the wording table. The exact words follow the redrawn [freeze picture](../../images/hud-v5/p2-3a1-freeze.webp) (agent wording, checked by the player-experience reviewer). On web, `Copy report` writes through the browser clipboard from the button press, the same call the launcher's Copy link uses; the plan records what was checked.
- **Pin:** the offline count in `tools/test_sim_boundary.py:102` goes from 9 to 10 in the same commit, with its reason (user, 2026-11-19); `failure()` joins the pump API in the sim boundary design and the guide.
- **Leave path:** once failed, `record()` (`sim_pump.gd:98-104`) skips its query and returns the last tick, an empty digest, the view's match and the kept command log; `flush()` (`offline_driver.gd:81-82`) returns on a null note. Today both read fields off a null note, and Esc-leave with the playtest helper on reaches `record()`.
- **Tests:** the pump's null-job test covers `failure()` before, after a failed post, after a failed query and after `stop()`, and `record()` on a failed pump; a scene case with a shared failing-pump fixture checks the card on that frame, exactly one log line over several ticks, the kept queue, and both ways out (`Back to menu`, and Esc then the pause menu) reaching the launcher with a record; a card case checks its place at the four sizes and that `Copy report` hands the report to a stubbed clipboard call (gate A, user 2026-11-19); the existing refused-post test (a `stop()` from outside) asserts no card and no error line. Mutation proofs: removing the `failure()` read or the `record()` fallback turns a test red.
- **SB5a inherits:** every terminal cause (null result, owner-thread check, fault flag, stall, dead thread) writes the same main-side reason, never read across threads; queue-full and stopped keep `failure()` empty; the offline driver also checks after `drain()`; the online driver reads `failure()` for critique change 28 instead of treating every refused post as terminal (`online_driver.gd:121-122`).
- **Limit:** release builds may raise no script error, so in friends' builds the card may first show once SB5a's detectors exist; P2.3a1 delivers the tested channel (user, 2026-11-19).

### Map marks (P2.3a3)

Every mark is white `#ffffff` over the under-stroke `rgba(14,18,22,0.78)`, 2 device px wider than its white line, buildings too (user, 2026-11-15 and 2026-11-19). Line widths and dash lengths stay constant in screen pixels at every zoom, times the window scale: inside the `Camera2D` subtree they are drawn at `width / zoom` (positive, so antialiasing stays); shapes, lengths and positions scale with the world (user, 2026-11-19). Sizes are the round 6 values, now decided (user, 2026-11-19), except where this list changes them.

- **Selection:** unit diamond 2:1 at the game's half widths, line 1.25 over 3.25; building footprint 1.5 over 3.5, drawn above the body. Own, enemy and allied selections all use it; the red inspect boxes go (user, 2026-11-19).
- **Hover:** four corner ticks, 0.32 of each edge, line 1.5, on unit diamonds and on building and pile footprints of any owner (user, 2026-11-19).
- **Drag box:** white 1.5 px line, no fill, with the live corner-tick preview on the own units the release would pick, today's all-units rule, skipping units under a panel (user, 2026-11-18 and 2026-11-19).
- **Attack target:** a reticle, a small ring with four inward ticks, one state (user, 2026-11-19); sizes are an agent proposal (ring radius 6, ticks 3 long, line 1.5, lifted 8 above the ground point) checked in the first capture.
- **Move confirmation:** a ring closing from radius 18 to 4 (half as high) over 0.4 s of wall time, from the order's acceptance; a place mark, drawn under the bodies (user, 2026-11-19).
- **Placement cells:** outline 1.25; a refused footprint crosses out every cell with the X between edge midpoints, line 1.5 (user, 2026-11-19); the debt (one blocked cell crosses out all) is logged for P2.3b.
- **Rally:** a line from the door 1.25, a pole 24 at line 1.5, a filled 10x9 flag, a foot ring 4x2 at line 1; the door is the middle of the footprint's front edge until P2.6 draws doors.
- **Battery and defence target line:** dashed 1.25 with 6/4 dashes, from `MUZZLE_LIFT` 20 plus 8 above the defence to 8 above the target; Godot's `draw_dashed_line` has equal dash and gap, so the segments are computed.
- **Resume cue:** a dashed white footprint (6/4) on your paused site while a builder is selected and the site is hovered (user, 2026-11-19).
- **Unchanged:** the grid while placing, the crate squares (P2.5) and the debug destination crosses.
- **Map edge B:** `EDGE_HEIGHT` 24 world px at zoom 1, hanging from the two camera-facing edges, lit face `#425463`, shaded face `#2E3B45`, no lit top line, drawn once in `TerrainView`; fog on the faces waits for fog.
- **Canvas** `#08090A` past the edge: the clear colour set on match enter and reset on exit (the launcher keeps its own).
- **Health bars:** "damaged or hovered" replaces `WorldView.shows_health`'s "selected, damaged or hovered" (user, 2026-11-18). The bar is drawn in screen space on its own child node, snapped to whole device pixels after the window stretch, at the lab geometry: fill 24x3, a 1 px black track, a 1 px frame in the owner's slot colour (`lab_marks.gd:43-48`); it redraws on a camera or window change. The pixel step is `max(1, floor(zoom × window scale))` or `max(1, round(zoom × window scale))`; P2.3a3 starts with an offscreen pair at 1920x1080, zoom 1, on a damaged army, and the owner picks (user, 2026-11-19). The green-yellow-red fill is the one named exception to "no red on the map" (agent, 2026-11-19).

The P2.3a3 offscreen captures at zoom 0.5, 1 and 2 get a reviewer check against the round 6 mock-ups before the owner's look (AGENTS.md exception, user 2026-11-14).

### Benchmarks and gate

**P2.3a1.**

- A new benchmark flag `-- --hud` runs only the HUD layouts. `hud_select` uses the `open` workload with one player added (so the strip has data) and 120 own units selected; the same 120 ids go to the real `Hud` node and to the world view's `set_view` (which gets `no_selection` today, `movement_benchmark.gd:170-171`), both updated inside the timed `_physics_process`.
- It runs at 1280x720 and at 2560x1080 (`sh tools/run_game.sh --resolution 2560x1080 res://scenes/movement_benchmark.tscn -- --hud`); scenario names carry the size. The benchmark applies the caps through `apply(root)`, prints `window=` from `DisplayServer.window_get_size()` and fails when the window differs from the request. A clamped or missing wide run leaves the gate pending for the owner, who picks another host, an offscreen run labelled as such, or accepting it without the row; no fallback is swapped in silently (user, 2026-11-19).
- The run asserts its mechanics in the timed window: the panel shows 120 selected and the world draws 120 selection marks.
- The HUD layouts' draw-call ceiling is set from one scratch-window measurement before the first recorded run, then never raised, and enforced like today's ceilings; time is reported against the rendered 3.04 ms budget at both sizes and not enforced, as the ledger treats rendered rows (agent call, builder check).
- `perf_record.py` accepts the HUD run's marker, with distinct completion evidence for the four standard layouts and for each HUD window size; the rows go into `perf-history.csv` and the ledger's history only, not the README chart (user, 2026-11-19).
- Gate: the suite, `sh tools/run_checks.sh`, `PERF_LABEL="P2.3a1" sh tools/run_benchmark.sh` (headless, with the pair gate) on a quiet host, the rendered rerun with the four standard layouts plus both HUD rows recorded by hand (`python3 tools/perf_record.py <log> --label "P2.3a1"`, then `python3 tools/perf_chart.py`), the reviews, and the owner's playtest. A row over budget is reported as exceeded, never loosened.

**P2.3a2.** The suite, checks, headless benchmark with the pair gate, and a rendered rerun in which the HUD rows show a refusal during the timed sample (the benchmark feeds a fixed raw text through `refuse()` on a schedule and asserts the line is visible).

**P2.3a3.** Adds `hud_damaged` (the same workload, all 300 units at spread health fractions, the same 120 selected) at both sizes, asserting in the window that every unit is below full health and that the bar node submitted a bar for each; the suite, checks, headless benchmark, rendered rerun and rows as above.

## Tests that change

- **Text pins moved first (P2.3a1, first code task):** about 119 lines in 10 test files read `HUD/Status`, `hud.note`, `Economy/` or `Rejected` (`test_skirmish_scene.gd` 52, `test_online_scene.gd` 24, `test_base_scene.gd` 23, `test_playtest_overlay.gd` 10, `test_scene.gd` 4, `test_order_voice.gd` 2, four files with 1). Behaviour checks move to node ids, `hud_text()` or `hud.refusal`; pure text pins are rewritten by design: `HUD_TEXTS` (HUD1), E1, K4, S1, N1, HU1, IC1's golden rows in `tests/input_script_rows.gd`, Bs1, the resume-status test and FS1 (12 px). H1's key hints go in P2.3a1: H1 reads the keys on the interim buttons, and TU1, IC1 step 15 and the economy-input test press `F` for unload (gate A, user 2026-11-19). K5 and TU1 move with the slab. The no-overlap lists (PO8, the perf overlay and pause menu layout tests) change from `HUD/Status`, `HUD/Economy` to the new ids. `test_scene.gd:67`'s click-through check becomes "panels stop clicks, the rest passes". `test_benchmark.gd:84` reads the benchmark's own label and is unaffected unless the HUD rows replace it.
- **Stretch:** a unit test covers `layout_for` (2560x1080 → 1706x720, 3440x1440 → 1720x720, one size beyond 2.4:1 such as 3840x1080, one below 16:10 such as 1024x768); a root-window test starts directly in a capped scene, crosses both caps, checks the logical rectangle and the HUD anchors, and checks the restore on exit; the existing match layout tests move to the stretched size pairs. L7 (`test_launcher.gd:124-129`) pins `keep` at the fixture start and after the launcher leaves the tree; both become the project default `expand` at 1280x720. L13 (`:345`) keeps asserting the launcher's `expand`; N25 (`test_online_scene.gd:845-854`) changes from "added under keep" to "the match applies its caps"; a new test resizes the launcher to 1024x768 and 3840x1080 (no caps), starts a match (caps applied), and returns to the menu (`expand` at 1280x720 again).
- **New (P2.3a1):**
  - the panel per state at the four sizes (inside the view, clear of the strip, the slab and the refusal line, labels not cut, bottom on `H`);
  - the largest roster built from data (one unit of each kind of the faction with the most kinds, three-digit counts, the longest names, the idle header and the kind-row footer, 158 high with six kinds) fits; the footer shows from two kinds and hides at one (gate A, user 2026-11-19);
  - the slab with the real China build menu and a full nine-entry queue, and the checklist, the note form and F3 open together, at 1280x720; the armed button look for each menu kind; the interim order buttons (visibility by selection and by a loaded container, the payload each press submits, the layout-label helper with its QWERTY fallback, the crosshair while armed) and Unload on `F`; the build buttons by selection and the unaffordable price in `warn`; the capped queue collapsed and open (gate A, user 2026-11-19);
  - the rebuild count; the rows holding while the pointer is over the panel;
  - the resolver table (own and enemy unit, own unit behind an enemy, aircraft over a ground unit of the same owner, unit over a building, building, pile, ground, contained unit; hover equals click), kind-row click narrows and shift-click removes, shift toggle on the map, shift-drag adds, a drag box skipping units under a panel, a pile kept selected across a refresh, HUD mouse routing through the viewport;
  - power reads used / available; the forecast card's forms; `LOW POWER · DEFENCES OFF` and `OFFLINE · LOW POWER`; the swatch;
  - the collector label table (every phase, plus moving, path pending, building, contained and the busy-dock retry) and the idle header;
  - `view_player` set after the online seat (a seat-2 join with different credits and starts, and after a rematch) and a `view_player` that differs from the seat changing only display reads;
  - the online notice; the offline freeze card (place, words, `Copy report` to a stubbed clipboard, `Back to menu` leaves, Esc opens the pause menu, whose Back to main menu leaves) (gate A, user 2026-11-19);
  - the refusal line's rules (timer, replace, clear on acceptance, one per frame) with today's text;
  - the theme's effective sizes in the launcher at 1280x720.
- **Palette re-pin:** `test_world_batch.gd` colour goldens and SH15, in one commit.
- **F29 (P2.3a2):** OV7 to OV11 and the restart and busy-player cases (`test_order_voice.gd:140-180`) change: no voice at submit, the voice on acceptance; tests count emitted requests. Same-tick cases, offline and online unless marked:
  1. accepted and refused in one step (a move plus a builder ordered to attack), in both orders: one voice, exactly one beep, the line shows the refusal, a hint at the move point only;
  2. two accepted orders in one frame: one voice, the last hint;
  3. accepted at issue, refused when due in the same tick (two `produce` with credits for one; two overlapping builds; `cancel_build` then `resume_build`; `cancel_production` twice on one entry): no voice for the refused one, the right line and sound;
  4. both seats' commands sharing a sequence in one tick, and two notes in one drain: each player's answer matched to its own due row;
  5. offline, a rejected then an accepted command reusing a sequence;
  6. an order, then its unit removed (online, inside the input delay): all units gone, silent; the first speaker dead and a second alive, the survivor speaks;
  7. an order, then its target removed: attack target dies, silent; transport dies, silent; pile emptied in flight, neutral line; pile already empty at the click, "Supply pile is empty" with the beep; pile deleted, neutral line; production entry finished or already cancelled, neutral line; site completed, neutral line; site destroyed, silent;
  8. the N-cap test's additions (#86);
  9. an injected answer with an empty command: no voice, worded by text;
  10. offline with the menu open between click and step: no voice until the match resumes;
  11. restart or rematch with answers pending: no stale voice or line;
  12. a local placement refusal: no voice, beep, line, placement stays armed.
- **P2.3a3:** `test_view.gd` V20 (selection geometry holds), V17 and V18 (bar drawn by its own node; a selected healthy unit shows no bar), H1 and H2 (ring lifetime on wall time), V6 (dashed line), the build preview and grid tests; new screen-bar cases at scales 0.5, 0.75, 1, 1.5, 2 and 3 for whole-pixel frame, track and fill, asserting a visible 28x7 outer frame at the smallest scale; line widths and dash lengths constant on screen at zoom 0.5, 1 and 2.

## Docs

- **Guide chapters** (each updates its `Checked against` footer): 01 Big picture (the match screen's HUD object), 04 The tick (F29 timing, in P2.3a2), 05 Presentation (HUD, input with Unload on `F` and the interim order buttons, the layout labels, the freeze card (gate A, user 2026-11-19), stretch and window, playtest helper place, unit voices, art as built), 11 Multiplayer (notices, launcher relay words, in P2.3a2), 12 Performance and platforms (HUD rows, wider view), 13 Testing and tooling (id-based HUD layout tests, size pairs, resolver and routing tests, benchmark `--hud`).
- **Packages and status:** the P2.3a row becomes P2.3a1, P2.3a2 and P2.3a3 in `docs/packages.md` and the STATUS package table, with `python3 tools/roadmap.py`; the stale "before the camera package, so edge scrolling is built against the dock" clause goes (edge scrolling moved to the Later item Pan with the mouse, `packages.md:66`); the note dialog's "place not decided" is settled; F29 and F30 close in P2.3a2; F25 gets a note that `expand` draws more map with no culling (CPU unchanged, GPU fill measured in the wide row).
- **References:** `hud-v5-layout.md` (pile row, the wording-table note, the places this spec adds, the collector label, the forecast form; its "redrawn with the P2.3a design" becomes "redrawn in P2.3a1's first task"), `map-art-shapes.md` (carried sizes decided, the reticle, the bar size), `design-answers` (already written), `ART_DIRECTION.md` (the health-bar red exception; the health rule is decided), `blueprint.md:672` (health rule decided), `docs/playing-online.md` status lines (P2.3a2), `docs/development.md` (Esc menu, the rejection message, and Start here entries for P2.2, P12, Sim boundary, the A/B lab and P2.3a, which are missing today).
- **Verification files:** one per package, `docs/reference/p2.3a1-verification.md` and so on, with the resume record block and an evidence table.

## Risks and checks

- **Bulk test breakage.** About 119 text-pinned lines plus a golden file; the pin move is the first code task, with the full suite green before any visual change.
- **Stretch re-entry.** Setting `content_scale_*` inside `size_changed` may re-emit it; `apply` writes only on change and the root-window test resizes across both caps. Not run yet.
- **Wide window on the measuring host.** Whether the Mac mini's display opens a 2560x1080 window at that size is unknown; the benchmark fails on a mismatch, the gate stays pending, and the owner is asked before the run.
- **Theme spill.** A project theme applies to every unthemed control; launcher, result panel, playtest and focus-card layout tests run at 1280x720 in the same task.
- **Draw cost of `expand`.** CPU batch cost is unchanged (no culling today, F25), so the wide row measures GPU fill: 2560x1080 draws about a third more pixels than today's `keep` at that window. Reported, never loosened.
- **HUD draw calls.** Text in several sizes and font variations may break batching; the ceiling comes from a scratch measurement before the first recorded run.
- **Mixed look between packages.** Between P2.3a1 and P2.3a3 the new HUD sits beside green and red map marks; the P2.3a1 card asks nothing about marks.
- **Sound docs.** F29 and F30 touch `sound_*`; P2.3a2's plan starts with reading the sound spike docs.
- **Online acknowledgement lag** (about 133 ms or more): watched by the P2.3a2 card question; if it reads "slight delay" or "too slow", a small static click mark at the click is the first fix, not a revert of F29.
- **Overtaken matching on English strings.** Brittle by nature; the independent inventory test catches drift.

## Owner window batch (implementation rounds, not agent work)

- The Steam Deck session: numbers at 13/700 against 14/700, the uppercase 12 px labels (8.7 px cap height at scale 1 against Valve's 9 px guideline) raised to 13 px only if they read poorly (user, 2026-11-18 and 2026-11-19), and the match-bench pair with the HUD off against on (low-end report §8.7, private; user 2026-11-19).
- The P2.3a1 state pictures (one look before the HUD tasks), the F30 listening page (P2.3a2) and the health-bar step capture pair (P2.3a3).
- Carried from 2026-11-14 and batched with the P2.3a window round: the Mac Firefox Web Render Bench row, the README screenshot and fight clip, one uncovered gated Ashfall run.

## Later: drafts and riders

- **Drag tiers (draft, user 2026-11-19):** if the playtest says builders or collectors end up in fights by accident, a drag box with any combat unit in it drops builders and collectors (OpenRA keeps only the top selection priority band, `OpenRA.Mods.Common/Widgets/SelectionUtils.cs:61-75` @ b4d95a5671; Zero-K filters constructors by default, `LuaUI/Widgets/gui_selection_hierarchy.lua:97-115` @ 54ef574db). The "take everything" override needs a free modifier: Shift adds or toggles, Ctrl and Alt are taken (`orders.gd:199-201,230-231`); a double-tap drag or a new key is the candidate, decided with the playtest answer.
- **Fog:** hover and inspect go through visibility under `view_player` once fog exists.
- **Online view width:** the 2.4:1 cap still gives ultrawide players about a third more view than 16:9; revisit before strangers play online (player-experience advisor, 2026-11-19).
- **Mirror matches:** an inspected enemy differs from your own unit only by the panel edge in a mirror match; a muted `ENEMY` label is the fix if playtests show "why won't it move?" (player-experience reviewer, 2026-11-19).
- **Economy:** collectors against an ideal count on the depot, a nearly-empty pile alert (user, 2026-11-17); a map mark on your own stalled sites (P3).
- **Settings:** a health-bar "Always" option (user, 2026-11-19).

## Left to the builder

- Node names and the split of the `Hud` node into child scripts.
- Whether tokens live as theme colours only or also in a constants script (one place, not both).
- The build menu's column count within the fit rule, and the join-code size within the scale.
- Exact wording of rows marked draft in Appendix A, within the rules above; the player-experience reviewer checks the final table.
- The dashed segment generator and the reticle geometry, within the stated sizes.
- The idle and fight stretches the rebuild-count test uses.

## Agent's calls (check while reading)

1. A kind row's bar is `sum(hp) / sum(max_hp)` in the health colours.
2. Credits left uses the viewer's collector `box_value` from the definitions.
3. The slab keeps the `Economy` VBox and draws its fill on `draw`, so 18 test paths stay; the build menu's columns fit the longest labels.
4. Chip stack positions (Playtest top 48, checklist at top 88 with the note form below it, F3 below both, or beside the checklist when it does not fit, the owner's rule at gate A), the notice at top 48 on a `bg` slab, the swatch 8 px before `CREDITS`.
5. Shift-click on an own building with units selected replaces them (no mixed selection).
6. Sound stays on the seat under `view_player` in P2.3a.
7. The move ring starts on acceptance; the F30 level gets one check in a fight mix.
8. The raw refusal log is a capped list of the last 50 in the match record.
9. The reticle's sizes (radius 6, ticks 3, line 1.5, lifted 8).
10. The `.` key-cap check is handed to P2.3b.
11. The HUD rebuilds only on structural changes; values patch in place.
12. The caps are applied by a static `apply(root)` from each capped scene (match, benchmark), not an autoload or app shell.
13. Palette A includes its darker side faces.
14. HUD rows: draw-call ceiling from one scratch measurement, enforced; time reported against 3.04 ms.
15. The collector label table's rows for `seeking` (previous label held), the busy-dock retry (`WAITING AT PILE`) and a contained collector (no label).
16. Overtaken classification keeps click-time facts per command; a production entry no longer queued reads "No longer in the queue".
17. Gate A follow-ups (2026-11-19): Esc on the freeze card opens the pause menu, as on the Victory/Defeat card; the freeze card's words and focus follow its redrawn picture (`Copy report` focused), and keys reach no order behind it; `Unload (F)` shows only while a container is loaded, a Tunnel Hub exactly and a vehicle while some own unit is contained (the plan's owner question 9, answered (b) on the gate page, user 2026-11-19); the order row sits 8 px above the build menu; buttons carry no `tnum`; with only the note form open and no room below it, F3 opens left of the form (plan agent call 25); the freeze card's buttons are square too; its footer prints the map's launcher name.

## Appendix A: draft wording table

Agent proposals unless marked; sentence case, no full stop; sources at `main` `62e6b3c`. Scope: answers to commands; setup and tooling errors are out of scope.

**Player-causable** (beep unless noted):

| Simulation text | Where | Line |
|---|---|---|
| `Insufficient credits` | `simulation.gd:302`, `construction.gd:79` | Not enough credits (announcer, no beep; user 2026-11-19) |
| `Production queue full` | `simulation.gd:301` | Queue full |
| `Missing completed prerequisite` | `simulation.gd:300`, `construction.gd:76` | Needs <Kind> (user, 2026-11-19) |
| `Footprint outside map or overlaps obstacle` | `construction.gd:32` | Cannot build here |
| `Footprint covers ground unit or destination` | `construction.gd:33` | Units in the way |
| `Too close to the map edge` | `construction.gd:37` | Too close to the map edge |
| `Too close to a supply source` | `construction.gd:38` | Too close to a supply pile |
| `No reachable builder approach` | `construction.gd:96,128` | Builder cannot reach it |
| `Unit is inside a transport` | `simulation.gd:262,278`, `construction.gd:73` | Unit is inside a transport |
| `Attack requires armed units` | `simulation.gd:271` | No armed units selected |
| `Invalid attack target` (target still in view) | `simulation.gd:272`, `combat.gd:450` | Cannot attack that |
| `Target out of range` (defence) | `combat.gd:452` | Out of range |
| `Target outside map` | `simulation.gd:330` | Outside the map |
| `Target must be walkable and within map` | `simulation.gd:333` | Cannot move there |
| `Cannot enter this container` (host in view) | `containers.gd:9,33-36` | Cannot go in there |
| `Container is full` | `containers.gd:37` | No room inside |
| `Cannot unload this container` (host in view) | `containers.gd:41` | Cannot unload that |
| `Foundation is being rebuilt` | `simulation.gd:282` | Already being rebuilt |
| `Source is empty` (pile already empty at the click) | `simulation.gd:308` | Supply pile is empty |
| `Too many orders at once; wait a moment` (online driver) | `online_driver.gd:14,216` | Too many orders, wait a moment |
| local hints: "Choose one builder", "Choose homogeneous collector selection", "Select a container", "Select a production building" | `orders.gd:292,342,352,368,384` | Select one builder; Select only collectors; Select a transport; Select a building that trains units |

**Overtaken** (dead unit or target silent, user 2026-11-18): `Missing entity or wrong owner` and `No units left` (all units gone), `Invalid attack target`, `Invalid owned defence`, `Cannot enter this container`, `Cannot unload this container`, `Missing producer`, `Invalid builder`, `Invalid builder or building kind` (their object gone: silent); `Missing owned foundation` (site gone: silent; completed: "Already finished"); `Missing supply source`, `Source is empty` after the pile had boxes at the click ("Supply pile is empty", neutral); `Missing production entry` ("No longer in the queue"); `Match ended` (silent, the result panel speaks).

**Cannot be caused by a player** ("Order not possible"): `Missing field: <key>`, `<key> must be an integer`, `Invalid tick, player or sequence`, `Sequence must increase`, `Unsupported command type`, `Invalid <key>`, `Expected integer origin`, `Expected nonempty entity array`, `Invalid or duplicate entity ID`, the three target-coordinate format errors, `Gather requires collectors`, `Unit cannot be commanded`, `Player has no economy`, `Economic command unavailable`, `Choose a faction first`, `Match has not started`, `Unknown faction`, `Faction already chosen`; `Producer cannot build that unit` and `Invalid owned completed producer` stay here as a fallback after the input fix above; overtaken texts whose object is still in the view fall back to the player-causable row or here.

**Launcher footer and match notices** (full sentences, as today's `Your friend did not join in time`):

| Raw | Source | Line |
|---|---|---|
| `relay busy` | `relay/limits.go:94,127,136` | The server is busy. Try again in a moment. |
| `too many connections` | `limits.go:99` | Too many connections from your network. Try again later. |
| `too many joins` | `limits.go:131` | Too many tries. Wait a few seconds. |
| `unknown match` | `relay/room.go:211,524,533,536` | No match with that code. |
| `build mismatch` | `room.go:214` | Your friend has a different game version. |
| `match full` | `room.go:217` | That match is already full. |
| `protocol mismatch` | `room.go:509` | Your game version does not match the server. Reload the page. (web) / Update the game. (desktop) |
| `invalid message`, `missing settings`, `Protocol error: …` | `room.go:512,516`; `launcher.gd:483,504` | Could not join. Please report it. |
| closed after hello, before welcome, on Join | `launcher.gd:472` | No answer for that code. Check the code, or try again in a minute. (user, 2026-11-19) |
| `Waiting for player %d` | `online_driver.gd:335` | Waiting for your opponent… (1v1; P7 words teams) |
| `Player %d disconnected` | `online_driver.gd:336` | Your opponent disconnected. |
| `Connection to relay lost`; mid-match `Relay: too far ahead`, `invalid message`, `room expired` | `online_driver.gd:337` | Connection to the match lost. |
| `Desync — report saved to / downloaded as %s` | `online_driver.gd:338` | The games went out of step. Report saved to %s. |
