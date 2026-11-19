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
| [p2-3a1-slab](p2-3a1-slab.webp) | Interim slab with a China Bulldozer selected: no order row (builders have no weapon), China's build menu in 2 columns, Rotary Gun Tower armed (`panel2`, 2 px `sel` inset); specimens: Medium Tanks with `Attack move (A)` armed in the same look (after the button or the key, until a ground click, a right-click or Esc; pointer: system crosshair; order row only, the build menu below it as in the main slab), and the Bulldozer's slab while the pointer is on a paused site, `Right-click: resume` as its top line |
| [p2-3a1-notice](p2-3a1-notice.webp) | Online notice `Waiting for player 2`, top centre; a Medium Tank selected, so the order row shows and no `Esc` chip |
| [p2-3a1-freeze](p2-3a1-freeze.webp) | Offline freeze as the result card: map and HUD dimmed (a Bulldozer selected: build menu, no order row), centred card with the warning mark and `Match stopped`, body, divider, footer with the report's version and map (`Version 0.14.0-dev+75898c8 · Dry Wells`, illustrative) and the code `GAME ERROR`, `Copy report` (secondary, focused) and `Back to menu` (primary); Esc opens the pause menu as on the Victory/Defeat card |
| [p2-3a1-freeze-copied](p2-3a1-freeze-copied.webp) | The same card after a click on `Copy report`: the button reads `Report copied` and holds the focus |
| [p2-3a1-forecast](p2-3a1-forecast.webp) | Strip in place with the USA Power Plant armed (`8 / 10 → 8 / 15`); specimens: China Rotary Gun Tower (`→ 3600`, `LOW POWER`), the same at 500 credits (`→ 700 short`), FRC with no POWER group (owner question 6) |
| [p2-3a1-sites](p2-3a1-sites.webp) | Own paused site (`PAUSED · NO BUILDER`, progress bar in `muted`), the slab with `Cancel construction`; specimens: enemy site with its percent in the owner colour, own factory with the rally footer (84) |
| [p2-3a1-chips](p2-3a1-chips.webp) | Owner question 5's worst case: China factory, nine-entry queue (slab top 313), checklist capped at 217 and scrolling, note form to its left |
| [p2-3a1-chips-f3](p2-3a1-chips-f3.webp) | Stack closed, F3 at top 88 |
| [p2-3a1-chips-f3-rule](p2-3a1-chips-f3-rule.webp) | F3 rule, worst case: the state above with F3 open; no room below the checklist and the note form already left of it, so F3 opens under the note form (x 699 to 944, top 173 to 233, above the slab top minus 8) |
| [p2-3a1-chips-checklist](p2-3a1-chips-checklist.webp) | Checklist open, F3 below it; Power Plant selected, so the slab has no button and is hidden |
| [p2-3a1-chips-form](p2-3a1-chips-form.webp) | Checklist and note form open, the form below the checklist, F3 below the form |
| [p2-3a1-chips-off](p2-3a1-chips-off.webp) | Playtest helper off: no chip, F3 at top 48 |
| [p2-3a1-refusal](p2-3a1-refusal.webp) | Amber line `Insufficient credits` at `H - 204`; factory selected at 500 credits |
| [p2-3a1-pile](p2-3a1-pile.webp) | Supply Pile, `CREDITS LEFT 10650`, 62 high, `line` edge; specimen `Empty` |
| [p2-3a1-rows-footer](p2-3a1-rows-footer.webp) | Kind rows (the rows picture): Rotary Gun Tank hovered (`panel2`, 1 px `muted` inset, pointing hand), Militia held at `0`, header `96 selected · 5 kinds · 12 idle collectors`, the rule `Click a kind: select only that kind · Shift-click: deselect it` as the panel's last line (158 high, top 562); specimen: `12 selected · 1 kind` with one row and no rule line |
| [p2-3a1-unload](p2-3a1-unload.webp) | A USA Scout Car with infantry inside: `Unload (F)` joins the order row, second line of the 2-column grid; specimens: an empty Scout Car with no own unit in any container, `Unload (F)` hidden, an FRC Tunnel Hub with units inside, a building, so `Unload (F)` alone and no build menu |
| [collector-status](collector-status.webp) | Collector labels per the spec table (no place numbers, `TO SUPPLY DEPOT`, `BUILDING`, `MOVING`, FRC's `SUPPLY CACHE`) and the header `9 selected · 2 kinds · 1 idle collector` with the kind-row rule as its last line; redrawn from the same page (`#shot=collector`); `source/collector-status.html` now points there |

`p2-3a1-rows.webp` folded into `p2-3a1-rows-footer.webp` (the design answers link that file); `p2-3a1-rows-tooltip.webp`, `p2-3a1-rows-none.webp` and `p2-3a1-chips-f3-clash.webp` are gone with their states (the clash rule is replaced; the gate A answers keep the history).

Drawn as the plan gives it:

- Build menu columns: the widest label of all three factions' builds, `5: Rotary Gun Tower $1200`, is 165.2 px at 13/600; with 8 px button padding on each side, 2 columns fit the 412 px inside the slab (432 minus padding 12 and 8), 3 do not. The order row uses the same columns.
- Slab buttons (`HudButton`, 13/600) draw proportional digits, as the plan gives them no `tnum`; the strip, panels and chips keep `tnum`.
- The build menu shows whenever no building is selected, as today (`hud.gd` `_menu_kinds`), so the slab holds China's builder menu in most pictures; the order row shows above it while own units are selected.
- The `Esc` chip shows only when Esc would open the menu: hidden with a selection, an inspection, a placement or the note form open; shown under the freeze card.
- The checklist, the note form and F3 keep today's Godot control look at 12 px with square corners (owner question 4), approximated from Godot's default fills; Public Sans because the one theme sets it. The focus cards are shipped ones (`Play again`, and `Every order heard` for the worst case), not P2.3a1's own card; the F3 figures are illustrative.
- A held kind row is drawn with the `quiet` fill and muted text and an empty bar (agent pick for "greyed"); the header counts the live selection while six rows hold.
- The freeze card takes `result_panel.gd`'s card: dim black at 0.6, `#2a2a2a` fill, 1 px `#808080` border, padding 24, title 30 px ExtraBold, body 15 px `#d4d4d4`, buttons 15 px at least 144x36 with padding 12/4 and 12 apart, the primary in the launcher's amber `PrimaryButton` look, the secondary in its `Button` field look, the focus ring 2 px `#e6e6e6` 4 px out; corners square.

Agent picks (not in the answers; owner may change them):

- The slab hides when it holds no button (a Power Plant selected) instead of drawing an empty strip.
- `Right-click: resume` is the slab's top line, muted 12/400, 4 above the buttons; the slab grows up by 18 while it shows.
- `Attack move (A)` takes the armed build button's look while attack-move mode is armed (plan Task 9's `HudButtonArmed`), with no hint line, as an armed placement has none.
- Freeze card words: title `Match stopped`, body `The game hit an error and cannot continue. Please copy the report and send it to us.`, footer `Version <build> · <map>` (the report's own version and map, so a playtester sees what they send; it reads the same after the copy) with the code `GAME ERROR` (13/700, 0.1 em tracking; P2.3a2's online variants put `DESYNC` and the like there); `Report copied` after the copy, kept until the card closes. No module name or `tick` in player text; the clipboard report keeps `tick:`. Layout from the owner's mock (title and mark left, buttons right) rather than the Victory card's centred lines; card 450 wide (content 400); divider 1 px `#808080` with 16 above and below; footer 13 px; 24 above the buttons. `Copy report` holds the focus when the card opens, so a reflexive Enter copies rather than leaving with the report (with the playtest helper off nothing else keeps it); `Back to menu` keeps the amber primary look and leaves on a click or Tab then Enter. The result card's precedent (`result_panel.gd` `_take_focus` focuses `Back to menu` as the only live button) does not apply here, since `Copy report` is live.
- Warning mark: an amber (`#f7c871`) triangle with a dark `!` drawn as an SVG shape, 32x28.

Gate A answers (user, 2026-11-19): stop gate A's questions are answered in the [design answers](../../reference/design-answers-2026-11-08.md#p23a1-gate-a-user-2026-11-19); the pictures above follow them. The F3 clash, build button costs, kind-row hover, freeze look, rows hint and paused site questions were all closed there (the rows hint moved to the panel footer).

Not settled (found while drawing):

- **Arrow glyph.** The strip's `→` (U+2192) is missing from every bundled Public Sans weight (checked with fontTools), so the pictures show a browser fallback and Godot will use the system fallback (`allow_system_fallback`); the strip task should decide.
- **Unload on an empty container.** Settled at gate A: hidden while empty ([design answers](../../reference/design-answers-2026-11-08.md#p23a1-gate-a-user-2026-11-19), user, 2026-11-19). The owner's answer shows `Unload (F)` while an own *loaded* container is selected; the spec and plan show it for any own completed container, because the view cannot tell empty from loaded, and `Containers.unload_error` (`game/scripts/simulation/containers.gd:39-41`) has no passenger check, so on an empty one the click is accepted, does nothing and prints no refusal ([unload picture](p2-3a1-unload.webp), empty Scout Car specimen). Options: (a) ship as planned, a dead click; (b) the view publishes a passenger count (read-only presentation field, still a sim-boundary check) and the button shows only when loaded; (c) greyed when empty, which needs the same data as (b). Recommendation: (b), closest to the answer.
- **Resume over an ended match.** One Esc from the freeze card (and from the Victory/Defeat card today) the pause menu's first item reads `Resume` (`game/scripts/presentation/pause_menu.gd:47`) and only returns to the card. No change in P2.3a1; the P2.3a2 Esc-menu redraw should label it `Back to card` or hide it once the match has ended or frozen.
- **Enemy site bars.** On an enemy (red) site the owner-coloured progress bar sits right above a health bar of the same size; below about a third of health both are red, told apart only by `38 %` against `cur / max`. No change in P2.3a1; the P2.3a3 health-bar rule should look at the site panel too.
