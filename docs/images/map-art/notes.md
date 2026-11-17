# Wargrid map art: faction shapes, placeholders, damage, tanks and the world

Mock-ups of the looks picked on A/B pages (user, 2026-11-13 to 2026-11-17); decisions with their reasons are in the [design answers](../../reference/design-answers-2026-11-08.md#map-art-faction-shapes-m75-user-2026-11-13). Pictures of HTML pages that redraw the game's exported shapes, not screenshots of the game. All 1280x720, sand ground unless named; the round 5 picked pictures use the picked owner colours, the others today's default set.

| What | Today | Picked |
|---|---|---|
| The five shared buildings, rows USA, China, FRC (zoom 1) | [buildings-today](buildings-today-z1.webp) | [buildings-picked](buildings-picked-z1.webp) |
| Rifle and rocket infantry, builder, light vehicle, Supply Helicopter (zoom 2) | [units-today](units-today-z2.webp) | [units-picked](units-picked-z2.webp) |
| Supply piles at five fill levels, construction at 10, 50 and 90 %, salvage crates (zoom 1) | [placeholders-today](placeholders-today-z1.webp) | [placeholders-picked](placeholders-picked-z1.webp) |

Rounds 4 and 5 (user, 2026-11-14):

| What | Today | Picked |
|---|---|---|
| Damage at 100, 70 and 35 % for every building body, all three factions (zoom 0.5) | [damage-today](damage-today-z05.webp) | [damage-picked](damage-picked-z05.webp) |
| Tanks, light vehicles and the Armed Pickup at eight headings (zoom 2) | [tanks-today](tanks-today-z2.webp) | [tanks-picked](tanks-picked-z2.webp) |
| Zoom 2 finish: Barracks, Factory, HQ, a tank, a light vehicle, riflemen (zoom 2) | [zoom2-today](zoom2-today-z2.webp) | [zoom2-picked](zoom2-picked-z2.webp) |
| Building fixes: China and FRC bodies (zoom 1) | [fix-buildings-today](fix-buildings-today-z1.webp) | [fix-buildings-picked](fix-buildings-picked-z1.webp) |
| Unit fixes: infantry, tanks, light vehicles and the Laborer at eight headings (zoom 2) | [fix-units-today](fix-units-today-z2.webp) | [fix-units-picked](fix-units-picked-z2.webp) |
| The whole scene, sand, no HUD (zoom 0.5): owner colours, side band, cliff, ground decoration | [world-today](world-today-z05.webp) | [world-picked](world-picked-z05.webp) |

Also from round 5:

- [The picked world on the dark ground](world-picked-dark-z05.webp) (zoom 0.5).
- [The lighter fog](world-fog-z1.webp), the picked one (zoom 1).
- [The picked cliff and decoration patch](world-cliff-decor-z1.webp) (zoom 1).

## Round 6 (user, 2026-11-17)

All pictures are 2560x1440 lossless WebP for a 1280x720 layout, drawn at 2x by the page. Each step shows today next to the full decided look: `<step>-today` is the step's stage with today's option, `<step>-picked` is the whole decided look (every pick, the marks, the power bolt). Values, sizes and tests per package: [map art shapes](../../reference/map-art-shapes.md); decisions: [design answers](../../reference/design-answers-2026-11-08.md#map-art-faction-shapes-m75-user-2026-11-13) (Round 6 block).

| What | Today | Picked |
|---|---|---|
| Dark surfaces: framed doors and the earth pile pad (zoom 1) | [surfaces-today](surfaces-today-z1.webp) | [surfaces-picked](surfaces-picked-z1.webp) |
| Map edge on the near-black canvas (zoom 0.5) | [edge-today](edge-today-z05.webp) | [edge-picked](edge-picked-z05.webp) |
| No power: the white bolt over a dark defence (zoom 1) | [power-today](power-today-z1.webp) | [power-picked](power-picked-z1.webp) |
| The eight owner colours (zoom 1) | [owners-today](owners-today-z1.webp) | [owners-picked](owners-picked-z1.webp) |
| Cargo white (zoom 1) | [cargo-today](cargo-today-z1.webp) | [cargo-picked](cargo-picked-z1.webp) |
| Paused construction: four posts alone (zoom 1) | [paused-today](paused-today-z1.webp) | [paused-picked](paused-picked-z1.webp) |
| Vehicle wrecks (zoom 1) | [wrecks-today](wrecks-today-z1.webp) | [wrecks-picked](wrecks-picked-z1.webp) |

Also: [the white map marks](marks-z1.webp), [the gate reference under the HUD](gate-reference-z1.webp) (the picture the art bible opens with), and [the old shapes check](old-shapes-check-z1.webp) (today's shapes drawn with the round 6 look).

Re-make: start `python3 docs/images/map-art/source/server.py` from the repository root, then `sh docs/images/map-art/source/shoot.sh [name ...]` (no name: every picture in `#report=pics`; Firefox headless, `cwebp`); details in the [source README](source/README.md). `base-*`, `buildings-*` and the other round 1 to 5 pictures keep the "today" and "picked" meaning of the tables above.

What is real in round 6:
- Real: the geometry of every picked shape. A headless Godot round trip bakes the picked export (`shapes-picked.json`) with the game's `ShapeBake` and matches the page's triangles, with one listed failing pose (today's Laborer at detail 2).
- Not real: the drawing itself. Colours, the map edge, the canvas, the bolt, the marks, shadows, fog and every picture are page data. Pixels, motion, feel, the rendered benchmark and a Steam Deck were not run; nothing was tested in the game window.
- The step pairs compare today with the decided look, not with a game screenshot.

Everything picked in rounds 1 to 3, together:

- [Two bases at the smallest zoom](base-usa-china-z05.webp), without the HUD.
- One base and army per faction at zoom 1: [USA](base-usa-z1.webp), [China](base-china-z1.webp), [FRC](base-frc-z1.webp).

What is real and what is not:
- "Today" is the output of `game/scripts/presentation/shapes.gd` at commit `10b9423`, exported headless and redrawn in the page with the bake's own rules. The redraw matched the game's baked triangles to 0.00001 px on 552 of 555 sampled poses; the other three are one tie in the paint order of two barrels of the same colour. Pixels were not compared with a game window.
- "Picked" is candidate data in the same format, not in the game. Every candidate passes a JavaScript port of the shape audit's paint-order and size rules; at the time none was run in Godot; round 6 later round-tripped the picked geometry (below).
- Sizes are the game's in its 1280x720 layout; a larger window scales everything up. The ground is the game's sand with its per-cell shade.
- Round 4 and 5 candidates are page data, not run in Godot, like the rest of "picked".
- The round 4 "today" pictures draw today's shapes with today's damage rule. In the zoom 2 finish picture the tank's zoom 2 version sits on today's hull, not the picked one.
- The tank picture is round 4's pick. It does not carry the later FRC correction (tank 0.7 cells, Armed Pickup 0.65); round 5's row view does not show the three tanks side by side, so the correction is visible only in the world pictures. The unit fixes are shown at zoom 2, because they hardly show at zoom 1.
- The world pictures are round 5's page with rounds 1 to 4 baked in. "Today" is every round 5 option at 0: today's owner colours, side band, cliff, no decoration, no fog. Picked colours are the "lift" owners and the "deeper" side band.
- The fog is a brightness multiply over half the stage, and part of the own army stands inside it, which the game would not show.
- Decoration (the road, scrub, rocks, water) is not in the game.
- The base scenes are composed by hand. Tanks, defence buildings, the Laborer, the supply truck and rubble are today's shapes.
- The HUD is the [HUD v4](../hud-v4/notes.md) mock-up layer; its glyphs here are silhouettes baked from the shapes, not the HUD's own drawings.
- In the "today" placeholder picture the pile and construction text uses the mock-up's typeface, not the game's font; the fill amounts are examples.
- The salvage crate's colours were an agent choice made after the cargo colour was picked (grey crate, dark drum, cream mat) and accepted afterwards (user, 2026-11-13).
- In the big-pile row neighbouring footprints touch at the corners; five do not fit side by side at zoom 1.

Not drawn: anything moving. Not tested: pixels in a game window, motion, the rendered benchmark, a Steam Deck (the picked geometry passed a Godot round trip in round 6, see below). The dark ground was looked at only with the round 5 world. The page and its scripts are in [source/](source/README.md); the recorded picks are a working file in the private notes repository.
