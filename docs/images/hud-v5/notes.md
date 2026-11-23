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

P2.3b states, Core only (plan T0, 2026-11-23; see "P2.3b redraw" below):

| State | Core |
|---|---|
| Ready cell hovered, factory with nothing in production | [core-hover-cell](core-hover-cell.webp) |
| Queue tile hovered | [core-hover-tile](core-hover-tile.webp) |
| A credit-blocked cell pressed | [core-press](core-press.webp) |
| Two builders selected | [core-builders](core-builders.webp) |
| Nothing selected, `Q` pressed | [core-none-refuse](core-none-refuse.webp) |
| FRC build menu: a cell blocked by prerequisite and credits | [core-two-cause](core-two-cause.webp) |

Core is words only and holds what the game can feed today; Full adds glyphs, the minimap, the group row, the production strip, the alert feed and the pinned factory, each with its later package (as in v4).

HUD coverage of the screen at 1280x800, summed from [layout.json](layout.json) (opaque slabs; the cell card and the refusal line are not counted):

| | Nothing | One unit | 120 units | Factory | Power Plant | Full queue | Builder | Build menu | Placing | Refused | Enemy | Pile | Site |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Full | 6.8 % | 15.5 % | 21.7 % | 21.5 % | 11.2 % | 21.6 % | 18.2 % | 18.1 % | 18.7 % | 18.4 % | 8.6 % | 9.5 % | 9.6 % |
| Core | 1.5 % | 9.9 % | 14.4 % | 17.4 % | 4.9 % | 17.4 % | 12.6 % | 13.8 % | 13.8 % | 13.8 % | 4.0 % | 4.9 % | 4.9 % |

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
| [p2-3a1-slab](p2-3a1-slab.webp) | Interim slab with a China Bulldozer selected: no order row (builders have no weapon), China's build menu in 2 columns, Rotary Gun Tower armed (`panel2`, 2 px `sel` inset) with the `AFTER PURCHASE` card under the strip (`3600`, `11 / 10 LOW POWER · DEFENCES OFF`); specimens: Medium Tanks with `Attack move (A)` armed in the same look (after the button or the key, until a ground click, a right-click or Esc; pointer: system crosshair; the order row alone, no build menu, as an army selection has none), and the Bulldozer's slab while the pointer is on a paused site, `Right-click: resume` as its top line |
| [p2-3a1-notice](p2-3a1-notice.webp) | Online notice `Waiting for player 2`, top centre; a Medium Tank selected, so the order row alone (no builder, no build menu) and no `Esc` chip |
| [p2-3a1-freeze](p2-3a1-freeze.webp) | Offline freeze as the result card: map and HUD dimmed (a Bulldozer selected: build menu, no order row), centred card with the warning mark in `warn` and `Match stopped`, body, divider, footer with the report's version and map (`Version 0.14.0-dev+75898c8 · Dry Wells`, illustrative) and the code `GAME ERROR`, `Copy report` (secondary, focused) and `Back to menu` (primary); Esc opens the pause menu as on the Victory/Defeat card |
| [p2-3a1-freeze-copied](p2-3a1-freeze-copied.webp) | The same card after a click on `Copy report`: the button reads `Report copied` and holds the focus |
| [p2-3a1-forecast](p2-3a1-forecast.webp) | First round only, replaced by `forecast-card` (round 2: no arrow, no `short`) and no longer in the default set: strip in place with the USA Power Plant armed (`8 / 10 → 8 / 15`); specimens: China Rotary Gun Tower (`→ 3600`, `LOW POWER`), the same at 500 credits (`→ 700 short`), FRC with no POWER group (owner question 6) |
| [p2-3a1-sites](p2-3a1-sites.webp) | Own paused site (`PAUSED · NO BUILDER`, progress bar in `muted`), the slab with `Cancel construction`; specimens: enemy site with its percent in the owner colour, own factory with the rally footer (84) |
| [p2-3a1-chips](p2-3a1-chips.webp) | Owner question 5's worst case: China factory, nine-entry queue (slab top 313), checklist capped at 217 and scrolling, note form to its left |
| [p2-3a1-chips-f3](p2-3a1-chips-f3.webp) | Stack closed, F3 at top 88 |
| [p2-3a1-chips-f3-rule](p2-3a1-chips-f3-rule.webp) | F3 rule, worst case: the state above with F3 open; no room below the checklist and the note form already left of it, so F3 opens under the note form (x 699 to 944, top 173 to 233, above the slab top minus 8) |
| [p2-3a1-chips-checklist](p2-3a1-chips-checklist.webp) | Checklist open, F3 below it; Power Plant selected, so the slab has no button and is hidden |
| [p2-3a1-chips-form](p2-3a1-chips-form.webp) | Checklist and note form open, the form below the checklist, F3 below the form |
| [p2-3a1-chips-off](p2-3a1-chips-off.webp) | Playtest helper off: no chip, F3 at top 48 |
| [p2-3a1-refusal](p2-3a1-refusal.webp) | Line `Insufficient credits` in `warn` at `H - 204`; factory selected at 500 credits, so both `$800` prices print in `warn` |
| [p2-3a1-pile](p2-3a1-pile.webp) | Supply Pile, `CREDITS LEFT 10650`, 62 high, `line` edge; specimen `Empty` |
| [p2-3a1-rows-footer](p2-3a1-rows-footer.webp) | Kind rows (the rows picture): Rotary Gun Tank hovered (`panel2`, 1 px `muted` inset, pointing hand), Militia held at `0`, header `96 selected · 5 kinds · 12 idle collectors`, the rule `Click a kind: select only that kind · Shift-click: deselect it` as the panel's last line (158 high, top 562); specimen: `12 selected · 1 kind` with one row and no rule line |
| [p2-3a1-unload](p2-3a1-unload.webp) | A USA Scout Car with infantry inside: `Unload (F)` joins the order row, second line of the 2-column grid, no build menu (no builder selected); specimens: an empty Scout Car with no own unit in any container, `Unload (F)` hidden, an FRC Tunnel Hub with units inside, a building, so `Unload (F)` alone and no build menu |
| [collector-status](collector-status.webp) | Collector labels per the spec table (no place numbers, `TO SUPPLY DEPOT`, `BUILDING`, `MOVING`, FRC's `SUPPLY CACHE`) and the header `9 selected · 2 kinds · 1 idle collector` with the kind-row rule as its last line; redrawn from the same page (`#shot=collector`); `source/collector-status.html` now points there |
| [p2-3a1-queue](p2-3a1-queue.webp) | China factory, nine queued: header `QUEUE` with `8 waiting`, no numbers; the entry in production with `42 %` and a 2 px own-colour line on a `well` track, 3 next, then the full-width `Show 5 more queued` row with a drawn chevron (from 6 entries; up to 5 all show); pointer on a waiting row: the whole row lights up (`panel2`, 1 px `muted` inset), the × is its sign, tooltip `Cancel: refunds $800` beside the slab |
| [p2-3a1-queue-open](p2-3a1-queue-open.webp) | The same after a click on `Show 5 more queued`: all nine, then `Show fewer`; the list collapses again on a selection change or at 5 or fewer |
| [p2-3a1-forecast-card](p2-3a1-forecast-card.webp) | China Rotary Gun Tower armed at 4800: the strip keeps `4800` and `8 / 10`, the `AFTER PURCHASE` card under it reads `3600` and `11 / 10` with `LOW POWER · DEFENCES OFF` in `warn`; specimens: the same at 500 credits (`−700`, U+2212, in `warn`) beside its slab with the armed Rotary Gun Tower and its `$1200` in `warn`, USA Power Plant (`4000`, `8 / 15`, nothing to warn about), FRC Barracks (no POWER group) |
| [p2-3a1-slab-army](p2-3a1-slab-army.webp) | A Medium Tank selected: the order row alone, no build menu; a collector alone gets no button, so no slab |
| [p2-3a1-slab-poor](p2-3a1-slab-poor.webp) | China Bulldozer at 500 credits: each unaffordable price in `warn`, `$500` for the Barracks in `text`; the labels sit where they sit at any credits (every build button: name left, price right) |
| [p2-3a1-slab-builder](p2-3a1-slab-builder.webp) | China Bulldozer selected: the build menu alone, no order row; specimen: a Bulldozer and Medium Tanks together show the order row only |
| [p2-3a1-low-power](p2-3a1-low-power.webp) | Power `12 / 10`: the strip prints `12 / 10` and `LOW POWER · DEFENCES OFF` in `warn` |
| [p2-3a1-offline](p2-3a1-offline.webp) | Own Rotary Gun Tower selected while its owner is short: `OFFLINE · LOW POWER` in `warn` caps on its name row (the collector-status slot, no height change); no button, so no slab; an enemy defence only where the view already carries that player's power |

`p2-3a1-rows.webp` folded into `p2-3a1-rows-footer.webp` (the design answers link that file); `p2-3a1-rows-tooltip.webp`, `p2-3a1-rows-none.webp` and `p2-3a1-chips-f3-clash.webp` are gone with their states (the clash rule is replaced; the gate A answers keep the history).

Drawn as the plan gives it:

- Build menu columns: the widest label of all three factions' builds, `5: Rotary Gun Tower $1200`, is 165.2 px at 13/600; with 8 px button padding on each side, 2 columns fit the 412 px inside the slab (432 minus padding 12 and 8), 3 do not. The order row uses the same columns.
- Slab buttons (`HudButton`, 13/600) draw proportional digits, as the plan gives them no `tnum`; the strip, panels and chips keep `tnum`.
- The build menu shows only while nothing or exactly one own builder alone is selected (director round, user 2026-11-19; placement needs exactly one builder): a builder with a tank shows the order row only, two builders or a builder with a collector show no build menu. The order row shows while the selection holds an own unit with a weapon.
- Warnings (low power, `−700`, an unaffordable price, the refusal line, the freeze card's mark) take `warn` (`#f47b6c`, gate A round 2); amber keeps alerts and primary buttons.
- The `Esc` chip shows only when Esc would open the menu: hidden with a selection, an inspection, a placement or the note form open; shown under the freeze card.
- The checklist, the note form and F3 keep today's Godot control look at 12 px with square corners (owner question 4), approximated from Godot's default fills; Public Sans because the one theme sets it. The focus cards are shipped ones (`Play again`, and `Every order heard` for the worst case), not P2.3a1's own card; the F3 figures are illustrative.
- A held kind row is drawn with the `quiet` fill and muted text and an empty bar (agent pick for "greyed"); the header counts the live selection while six rows hold.
- The freeze card takes `result_panel.gd`'s card: dim black at 0.6, `#2a2a2a` fill, 1 px `#808080` border, padding 24, title 30 px ExtraBold, body 16 px `#d4d4d4`, buttons 15 px at least 144x36 with padding 12/4 and 12 apart, the primary in the launcher's amber `PrimaryButton` look, the secondary in its `Button` field look, the focus ring 2 px `#e6e6e6` 4 px out; corners square.

Agent picks (not in the answers; owner may change them):

- The slab hides when it holds no button (a Power Plant selected) instead of drawing an empty strip.
- `Right-click: resume` is the slab's top line, muted 12/400, 4 above the buttons; the slab grows up by 18 while it shows.
- `Attack move (A)` takes the armed build button's look while attack-move mode is armed (plan Task 9's `HudButtonArmed`), with no hint line, as an armed placement has none.
- Freeze card words: title `Match stopped`, body `The game hit an error and cannot continue. Please copy the report and send it to us.`, footer `Version <build> · <map>` (the report's own version and map, so a playtester sees what they send; it reads the same after the copy) with the code `GAME ERROR` (13/700, 0.1 em tracking; P2.3a2's online variants put `DESYNC` and the like there); `Report copied` after the copy, kept until the card closes. No module name or `tick` in player text; the clipboard report keeps `tick:`. Layout from the owner's mock (title and mark left, buttons right) rather than the Victory card's centred lines; card 450 wide (content 400); divider 1 px `#808080` with 16 above and below; footer 13 px; 24 above the buttons. `Copy report` holds the focus when the card opens, so a reflexive Enter copies rather than leaving with the report (with the playtest helper off nothing else keeps it); `Back to menu` keeps the amber primary look and leaves on a click or Tab then Enter. The result card's precedent (`result_panel.gd` `_take_focus` focuses `Back to menu` as the only live button) does not apply here, since `Copy report` is live.
- Warning mark: a `warn` (`#f47b6c`) triangle with a dark `!` drawn as an SVG shape, 32x28.
- Every priced build button draws its name left in `text` and `$price` as a right-aligned child label, whose colour alone flips between `text` and `warn` as credits change, so nothing moves (player-experience review, night of 2026-11-19). A centred name would meet the price: `5: Rotary Gun Tower` and `$1200` overlap by about 7 px in a 204 px button, by advance widths at 13/600.

Gate A answers (user, 2026-11-19): stop gate A's questions are answered in the [design answers](../../reference/design-answers-2026-11-08.md#p23a1-gate-a-user-2026-11-19); the pictures above follow them. The F3 clash, build button costs, kind-row hover, freeze look, rows hint and paused site questions were all closed there (the rows hint moved to the panel footer).

Not settled (found while drawing):

- **Unload on an empty container.** Settled as plan question 9 (b) (gate A, user 2026-11-19): a Tunnel Hub shows `Unload (F)` exactly, from the local player's tunnel list; a Scout Car or Armed Pickup only while some own unit row has `CONTAINED`, so a dead button remains only in the rare mixed case; no new view field ([unload picture](p2-3a1-unload.webp)).
- **Resume over an ended match.** One Esc from the freeze card (and from the Victory/Defeat card today) the pause menu's first item reads `Resume` (`game/scripts/presentation/pause_menu.gd:47`) and only returns to the card. No change in P2.3a1; the P2.3a2 Esc-menu redraw should label it `Back to card` or hide it once the match has ended or frozen.
- **Enemy site bars.** On an enemy (red) site the owner-coloured progress bar sits right above a health bar of the same size; below about a third of health both are red, told apart only by `38 %` against `cur / max`. No change in P2.3a1; the P2.3a3 health-bar rule should look at the site panel too.

## P2.3b redraw (2026-11-23)

The [P2.3b plan](../../superpowers/plans/2026-11-21-p2-3b-build-from-the-dock.md)'s T0 redrew the Core pictures from the owner's picks of the P2.3b War Room round (the `p23b-*` and `ts-card-*` states of [source/p2-3a1-states.html](source/p2-3a1-states.html); [design answers](../../reference/design-answers-2026-11-08.md#p23b-war-room-round-user-2026-11-21)) and, where the picks leave it open, from what the built HUD shows (`game/scripts/match/hud.gd`, `hud_model.gd` as of T7, T9, T13). The Full pictures are unchanged: the P2.3b look is drawn in the Core tier only (`source/hud.js`, `isCore`).

- Redrawn: `core-factory`, `core-full`, `core-build`, `core-place`, `core-blocked`; touched up: `core-builder` (no Stop, 3-14), `core-one`, `core-many` (the kind-row rule line), `core-none`; new: the six pictures in the table above.
- What Core now draws: the two-slab top strip with plain digits, the forecast arrow and the `sel` frame on a slab whose number changes, held at its widest forecast while the pointer is on the card or a building is armed, the `$` coin below zero (top strip round, user 2026-11-22); the Menu chip's `Esc` only when Esc opens the menu, faded rather than removed; wells with a 1 px `line` outline and the Back/Cancel chip `V` (3-14); a cost blocked by credits alone in `warn` with the solid 15 px `$` coin 4 after it, a missing prerequisite or a full queue muting it, two causes taking the prerequisite look (3-2); the hover inset on a ready cell, the 1 px `sel` frame on the hovered cell's missing prerequisite (3-10); the cell card with `cost · time`, the `warn` reason, then the counter line (`hud_model.gd` `COUNTER_LINES`, broken between claims when too wide), no forecast (3-4); the 4 px `you` bar on the producing cell (3-11); the factory panel fixed at 152 with up to four 91 x 60 queue tiles (`NOW`, merged runs `×N`, `+N more`) or a muted `Nothing in production` (3-3); two builders block `Build ›` with `Select one builder` (3-7); the refusal line grounded 8 above the screen bottom between panel and card, as built (gate B, user 2026-11-20).
- Not built yet: the queue tiles (T8 parked). The tile pictures (`core-factory`, `core-full`, `core-hover-tile`) draw the owner's picked design; the game still shows the queue rows above the cells.
- Drawn on the nearest existing backdrop: `core-builders` shows one selected Bulldozer in the world (backdrop `w-builder`), `core-two-cause` an FRC card over the China build-menu world (`w-build`). `Cannot build here` stays a proposal; the game prints the simulation's words.
- Not re-shot: `core-plant`, `core-enemy`, `core-pile`, `core-site` are outside T0's list and keep the old one-piece strip with thousands separators; re-running `shoot_final.sh` redraws them with the new strip (their only change).
