# Wargrid HUD v5

Mock-ups of the in-match HUD with the command card, as picked on an A/B page (user, 2026-11-16); decisions with their reasons are in the [design answers](../../reference/design-answers-2026-11-08.md#hud-m76), sizes and rules for implementers in the [layout reference](../../reference/hud-v5-layout.md). Pictures of an HTML page, not screenshots of the game. They replace [v4](../hud-v4/notes.md) for the dock; v4's look and its pictures stay as history.

Drawn under the [mock-up rules](../../art-direction/ART_DIRECTION.md#12-interface-mock-ups): Public Sans from `game/fonts/`, 2560x1600 for a 1280x800 layout, the source beside the pictures, every state. Corners are square and every margin, padding and gap is on the theme's spacing scale (4, 8, 12, 16, 24, 36), as [decided](../../reference/design-answers-2026-11-08.md#visual-and-ux-proposal-second-pass-user-2026-11-15) for the match.

| State | Full | Core (packages P2.3a and P2.3b) |
|---|---|---|
| Nothing selected | [full-none](full-none.webp) | [core-none](core-none.webp) |
| One unit | [full-one](full-one.webp) | [core-one](core-one.webp) |
| 120 units of six kinds | [full-many](full-many.webp) | [core-many](core-many.webp) |
| Factory with a queue, credits short | [full-factory](full-factory.webp) | [core-factory](core-factory.webp) |
| Building without commands (Power Plant) | [full-plant](full-plant.webp) | [core-plant](core-plant.webp) |
| Factory with a full queue | [full-full](full-full.webp) | [core-full](core-full.webp) |
| Builder | [full-builder](full-builder.webp) | [core-builder](core-builder.webp) |
| Build menu open, a prerequisite missing | [full-build](full-build.webp) | [core-build](core-build.webp) |
| Placing a defence, with its range | [full-place](full-place.webp) | [core-place](core-place.webp) |
| Placement refused | [full-blocked](full-blocked.webp) | [core-blocked](core-blocked.webp) |
| Enemy unit | [full-enemy](full-enemy.webp) | [core-enemy](core-enemy.webp) |
| Supply pile | [full-pile](full-pile.webp) | [core-pile](core-pile.webp) |
| Construction site | [full-site](full-site.webp) | [core-site](core-site.webp) |

Core is words only and holds what the game can feed today; Full adds glyphs, the minimap, the group row, the production strip, the alert feed and the pinned factory, each with its later package (as in v4).

HUD coverage of the screen at 1280x800, summed from [layout.json](layout.json) (opaque slabs; the cell card and the refusal line are not counted):

| | Nothing | One unit | 120 units | Factory | Power Plant | Full queue | Builder | Build menu | Placing | Refused | Enemy | Pile | Site |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Full | 6.8 % | 15.5 % | 21.7 % | 21.5 % | 11.2 % | 21.6 % | 18.2 % | 18.1 % | 18.7 % | 18.4 % | 8.6 % | 9.5 % | 9.6 % |
| Core | 1.5 % | 9.8 % | 13.1 % | 15.1 % | 4.9 % | 15.2 % | 12.5 % | 12.4 % | 13.1 % | 12.7 % | 3.9 % | 4.9 % | 4.9 % |

Files beside the pictures:

- [layout.json](layout.json): every slab, cell, row and slot as a rectangle, for 13 states, both sets and three sizes (1280x800, 1280x720, 1920x1080), with the colour tokens and the type scale. Expected values for the HUD's layout tests; how to read it is in the layout reference.
- [source/](source/README.md): the page the pictures and `layout.json` are made from, self-contained (user, 2026-11-16): the page, its glyphs, the shared HUD drawing (`source/hud.js`, `source/hud.css`, which the map art page loads too), the backdrops, a small server and the two scripts that re-make the pictures (`shoot_final.sh`) and the export (`export_layout.sh`); how to run them is in its README. The page loads the fonts from `game/fonts/`. It is the A/B page, so it still holds the options that were not picked; without a recorded pick it shows the first option of each step, which is what was picked.

What is real and what is not:

- Unit and building names, costs, build times, health and power come from `game/scripts/simulation/definitions/china.gd`, the enemy Battle Tank's from `usa.gd`. Credits, income, group sizes and queue contents are illustrative; in the Full build menu picture the top strip and group row show mid-game figures over an early base.
- The world is drawn from the picked map art data ([map art](../map-art/notes.md): picked shapes, owner palette A, deeper side band), composed by hand for these scenes. It is not a game screenshot. The white marks (selection, hover ticks, attack X, move ring, placement cells, range ring, rally flag) are mock-up drawings of the decided marks.
- The unit selection mark is drawn over the unit, as the game draws it today.
- The minimap is a sketch, not map data. The glyphs are v4's mock-up drawings; the Build glyph is new and as rough.
- "Cannot build here" is a proposal; the game prints the simulation's own refusal text today.
- The refusal line shows for about 3 s after a refused order; the picture shows it during the placement.
- The pinned factory in the Full 120 units picture is a placeholder for its own package. Sell is drawn in the selection panel; panel or card cell is decided in its package.
- Health bars in the panels change colour in three steps; the game blends the colours.

Not drawn: Barracks, a building being sold, two factories selected, buildings and units selected together, a transport with Unload, the playtest note dialog.

Not tested: anything in Godot beyond the map art geometry round trip, a real Steam Deck, colour-vision deficiencies, real hover and clicks. The backdrops are drawn by the map art page (`../map-art/source/shoot_worlds.sh`, round 6 look); the recorded picks are a working file in the private notes repository.

## P2.3a1 states (2026-11-19)

The states the [P2.3a1 plan](../../superpowers/plans/2026-11-19-p2-3a1-see-your-selection.md) (Task 1) draws before its HUD tasks, for stop gate A. Values come from the [layout reference](../../reference/hud-v5-layout.md) and the [P2.3a design](../../superpowers/specs/2026-11-19-p2-3a-see-your-selection-design.md); names, costs, health and power from `game/scripts/simulation/definitions/`. A 1280x720 layout drawn at 2x, 2560x1440 (the plan's agent call 1); each picture is the whole screen over plain sand (`#a88e5c`, the source page's fallback ground), with the top strip, the chips, the interim slab and, where the state has one, the selection panel. Captioned panels in the middle of a screen are specimens of a second form, not part of that screen. Source: [source/p2-3a1-states.html](source/p2-3a1-states.html), pictures re-made by `source/shoot_p2_3a1.sh`.

| Picture | What it shows |
|---|---|
| [p2-3a1-slab](p2-3a1-slab.webp) | Interim slab: hint lines, China's build menu in 2 columns, Rotary Gun Tower armed (`panel2`, 2 px `sel` inset); specimen of the hints with `Right-click: resume` |
| [p2-3a1-notice](p2-3a1-notice.webp) | Online notice `Waiting for player 2`, top centre; one unit selected, so no `Esc` chip |
| [p2-3a1-freeze](p2-3a1-freeze.webp) | Offline freeze notice in the same place; a Bulldozer selected and the `Esc` chip still shown (plan Task 8: on the freeze the first Esc opens the menu even with a selection); specimen: the line in the refusal look (gate A question 4) |
| [p2-3a1-forecast](p2-3a1-forecast.webp) | Strip in place with the USA Power Plant armed (`8 / 10 → 8 / 15`); specimens: China Rotary Gun Tower (`→ 3,600`, `LOW POWER`), the same at 500 credits (`→ 700 short`), FRC with no POWER group (owner question 6) |
| [p2-3a1-sites](p2-3a1-sites.webp) | Own paused site (`PAUSED · NO BUILDER`, muted), the slab with `Cancel construction`; specimens: enemy site with its percent, own factory with the rally footer (84) |
| [p2-3a1-chips](p2-3a1-chips.webp) | Worst case (owner question 5): China factory, nine-entry queue, checklist capped above the slab and scrolling, note form to its left |
| [p2-3a1-chips-f3](p2-3a1-chips-f3.webp) | Stack closed, F3 at top 88 |
| [p2-3a1-chips-f3-clash](p2-3a1-chips-f3-clash.webp) | The plan's rule meeting the slab: China Bulldozer selected (slab top 554), the longest shipped card's checklist capped at 458, F3 below it at 554, over the hints (gate A question 1) |
| [p2-3a1-chips-f3-rule](p2-3a1-chips-f3-rule.webp) | The same with the proposed rule: no room below, so F3 opens left of the checklist (x 699 to 944, top 88) |
| [p2-3a1-chips-checklist](p2-3a1-chips-checklist.webp) | Checklist open, F3 below it (Power Plant selected) |
| [p2-3a1-chips-form](p2-3a1-chips-form.webp) | Checklist and note form open, the form below the checklist, F3 below the form |
| [p2-3a1-chips-off](p2-3a1-chips-off.webp) | Playtest helper off: no chip, F3 at top 48 |
| [p2-3a1-refusal](p2-3a1-refusal.webp) | Amber line `Insufficient credits` at `H - 204`; factory selected at 500 credits |
| [p2-3a1-pile](p2-3a1-pile.webp) | Supply Pile, `CREDITS LEFT 10,650`, 62 high, `line` edge; specimen `Empty` |
| [p2-3a1-rows](p2-3a1-rows.webp) | Kind rows: Rotary Gun Tank hovered (`panel2`, pointing hand), Militia held at `0`; the plural idle header `96 selected · 5 kinds · 12 idle collectors` (the longest form, fits the 376 px content width); specimen: the hover with a 1 px `muted` inset (gate A question 3) |
| [collector-status](collector-status.webp) | Collector labels per the spec table (no place numbers, `TO SUPPLY DEPOT`, `BUILDING`, `MOVING`, FRC's `SUPPLY CACHE`) and the header `9 selected · 2 kinds · 1 idle collector`; redrawn from the same page (`#shot=collector`); `source/collector-status.html` now points there |

Drawn as the plan gives it:

- Build menu columns: the widest label of all three factions' builds, `5: Rotary Gun Tower $1,200`, is 168.8 px at 13/600; with 8 px button padding on each side, 2 columns fit the 412 px inside the slab (432 minus padding 12 and 8), 3 do not. The costs are drawn in comma thousands like the strip (gate A question 2); today's `menu_label` prints `$1000`.
- The build menu shows whenever no building is selected, as today (`hud.gd` `_menu_kinds`), so the slab holds China's builder menu in most pictures.
- The `Esc` chip shows only when Esc would open the menu: hidden with a selection, an inspection, a placement or the note form open.
- The checklist, the note form and F3 keep today's Godot control look at 12 px with square corners (owner question 4), approximated from Godot's default fills; Public Sans because the one theme sets it. The focus cards are shipped ones (`Play again`, and `Every order heard` for the worst case), not P2.3a1's own card; the F3 figures are illustrative.
- Worst case: the slab's top is at 266, so the checklist is capped at 170 (266 − 8 − 88, measured after the fonts load) and scrolls; with no room below it, the note form's right edge sits 8 left of the checklist.
- A held kind row is drawn with the `quiet` fill and muted text and an empty bar (agent pick for "greyed"); the header counts the live selection (`96 selected · 5 kinds · 12 idle collectors`) while six rows hold.
- Hint lines are one muted 12/400 label, 4 px above the buttons (the slab's one separation); the longest, today's key hints, is 373 px and fits without wrapping.

Questions for gate A (from the player-experience review, 2026-11-19; answers go into the design answers before the task that builds the part):

1. **F3 when the space below the stack is too short.** The plan's rule (F3 below whatever is open, owner question 5 capping only the checklist and moving only the note form) puts F3 on the slab in common states: with a builder selected (slab top 554) and the shortest shipped card (`Play again`, checklist bottom 491) F3 runs 499 to 559; with the longest card the capped checklist ends at 546 and F3 starts at 554 ([chips-f3-clash](p2-3a1-chips-f3-clash.webp)); with a China factory's nine-entry queue (slab top 266) it would cover the hints and the first cancel buttons. The plan's SL2 (F3 never meets the slab) cannot pass under that rule. Options: (a) extend owner question 5 to F3: when F3 does not fit between the stack and the slab top minus 8, it opens left of the checklist (or of the note form when only the form is open), below the note form when the form already sits there ([chips-f3-rule](p2-3a1-chips-f3-rule.webp); in the worst case the form is 77 high, so F3 would run 173 to 233, above 258, arithmetic, not drawn); (b) F3 at top left (8, 48) under the strip, free in Core, taken by the Full alert feed later. Recommendation: (a), one rule for every helper surface; `_fit` already computes the floor. Needs Task 7's placement contract and SL2 to name it.
2. **Build button costs.** The plan's Copy line asks for comma thousands with no exception; today's `menu_label` prints `$1200` beside the strip's `4,800`. Options: (a) Task 9 formats the cost with the strip's comma helper (`$1,200`, as drawn), which re-pins M1 (`test_base_scene.gd:474`); (b) record an interim exception, the slab text stays today's until P2.3b's command card. Recommendation: (a), one helper and one test line. The queue's `(42%)` stays; P2.3b replaces the queue buttons.
3. **Kind-row hover strength.** `panel2` over `btn` measures 1.09:1 (WCAG relative luminance), so the hovered row barely differs; `line` would give 1.21:1, a 1 px `muted` inset 5.15:1. Options: (a) keep the spec's `panel2` step; (b) `panel2` plus a 1 px `muted` inset, the armed look's inset mechanism without cyan (specimen in [rows](p2-3a1-rows.webp)). Recommendation: (b), because shift-click removes a whole kind on rows 4 px apart. Either way the P2.3a1 playtest card can ask whether the row a click would hit was clear.
4. **Freeze notice look.** The freeze line uses the online notice's muted look (an agent call made for `Waiting for player 2`), so a stopped match reads like a routine wait while the build buttons still look ready. Options: (a) keep it; (b) the refusal line's amber square and amber text in the same slab, place and size (specimen in [freeze](p2-3a1-freeze.webp); amber is "needs you now" in the layout reference). Recommendation: (b). The slab buttons stay as they are in P2.3a1.
5. **Rows hint only with rows.** The slab shows `Rows: click narrows, Shift-click removes` in every state, also where no kind rows exist (pile, sites, freeze, Power Plant). Options: (a) always, as the spec words it; (b) only while the panel shows kind rows (SL4 then asserts it present with rows and absent without). Recommendation: (b), a hint naming an absent control costs reading time; one condition.
6. **Own paused site.** `PAUSED · NO BUILDER` uses the same muted caps as `UNDER CONSTRUCTION` and the progress bar stays in the owner colour, so a stalled site reads like an active one; amber is ruled out (spec, user 2026-11-17). Options: (a) keep as drawn; (b) the paused site's progress bar in `muted` instead of the owner colour. Recommendation: (b), a non-amber cue a test can assert.

Not settled (found while drawing):

- **Enemy site bars.** On an enemy (red) site the owner-coloured progress bar sits right above a health bar of the same size; below about a third of health both are red, told apart only by `38 %` against `cur / max`. No change in P2.3a1; the P2.3a3 health-bar rule should look at the site panel too.
