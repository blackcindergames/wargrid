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
- [source/](source/README.md): the page the pictures and `layout.json` are made from, self-contained (user, 2026-11-16): the page, its glyphs, the backdrops, a small server and the two scripts that re-make the pictures (`shoot_final.sh`) and the export (`export_layout.sh`); how to run them is in its README. The page loads the fonts from `game/fonts/`. It is the A/B page, so it still holds the options that were not picked; without a recorded pick it shows the first option of each step, which is what was picked.

What is real and what is not:

- Unit and building names, costs, build times, health and power come from `game/scripts/simulation/definitions/china.gd`, the enemy Battle Tank's from `usa.gd`. Credits, income, group sizes and queue contents are illustrative; in the Full build menu picture the top strip and group row show mid-game figures over an early base.
- The world is drawn from the picked map art data ([map art](../map-art/notes.md): picked shapes, lifted owner colours, deeper side band), composed by hand for these scenes. It is not a game screenshot. The white marks (selection, hover ticks, attack X, move ring, placement cells, range ring, rally flag) are mock-up drawings of the decided marks.
- The unit selection mark is drawn over the unit, as the game draws it today.
- The minimap is a sketch, not map data. The glyphs are v4's mock-up drawings; the Build glyph is new and as rough.
- "Cannot build here" is a proposal; the game prints the simulation's own refusal text today.
- The refusal line shows for about 3 s after a refused order; the picture shows it during the placement.
- The pinned factory in the Full 120 units picture is a placeholder for its own package. Sell is drawn in the selection panel; panel or card cell is decided in its package.
- Health bars in the panels change colour in three steps; the game blends the colours.

Not drawn: Barracks, a building being sold, two factories selected, buildings and units selected together, a transport with Unload, the playtest note dialog.

Not tested: anything in Godot, a real Steam Deck, colour-vision deficiencies, real hover and clicks. The backdrops were drawn by a generator that reads the map art spike's working data; that generator, the page's build spec and the recorded picks are working files in the private notes repository (`hud-v5/`), so the backdrops here are pictures, not re-makeable from this repository.
