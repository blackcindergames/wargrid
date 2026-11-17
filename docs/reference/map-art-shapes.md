# Map art shapes and colours for P2.3a to P2.6

An implementer of P2.3a, P2.4, P2.5 or P2.6 finds here every picked shape, size, colour and affected test of the map art, without the private notes and without measuring a picture. Shapes and palette values live in one export, [`shapes-picked.json`](../images/map-art/shapes-picked.json); this note says how to read it, what each package takes from it, which tests each pick touches, and what is still open. Decisions are in the [design answers](design-answers-2026-11-08.md#map-art-faction-shapes-m75-user-2026-11-13) (rounds 1 to 6); the pictures and their source are in [map art](../images/map-art/notes.md) and [source/](../images/map-art/source/README.md).

Labels: "(user, DATE)" marks a decision in the design answers; "agent proposal" or "carried, not decided" marks the rest. Test and code references are path:line at `8cb338c`; Zero Hour references are in the round 6 verification file's [Zero Hour defaults](map-art-round-6-verification.md#zero-hour-defaults).

## What is proven and what is not

- **Geometry is proven in the game's own bake.** `roundtrip.gd` bakes every shape of the export headless with the game's `ShapeBake`, and the page compares each baked triangle with its own drawing: `PASS 2208 max 1.02e-5 px ties 172 shade 314 triangles known-failing 1` (Task 24 row of the verification file). A pose is `id|damage variant|detail|hull bucket|turret bucket`, hull buckets 0 to 56 in steps of 8, turret bucket hull + 11. A tie is a reorder or a side shade the game decides by float noise; ties that change the picture fail, except the listed one.
- **The one listed failure is today's game shape:** `frc_builder|0|2|24|24`, the Laborer at detail 2, whose prim order changes the picture in the game too. P2.4's eight-heading paint-order audit fixes it (user, 2026-11-17).
- **Not run:** colours in a Godot window, anything drawn by an overlay (map edge, power bolt, marks), motion, feel, the rendered benchmark, a Steam Deck. Colours and overlays are page data; their contrast and colour-vision numbers come from the page's own maths (WCAG ratio; CIELAB distance under normal vision, deuteranopia and protanopia, the smallest of the three).

## How to read `shapes-picked.json`

The export has the shape format of the game's own export, [`source/shapes-current.json`](../images/map-art/source/shapes-current.json) (the game at `10b9423`; `shapes.gd`, `palette.gd`, `shape_bake.gd`, `world_batch.gd` and `world_view.gd` are unchanged since). The projection is in that file's `meta.projection`: a cell is a 64 x 32 px diamond, `x_px = 32*(cx - cy)`, `y_px = 16*(cx + cy)`, one height unit lifts 3.5 px at zoom 1, 64 heading buckets with 0 along +x. Detail is 0, 1, 2 at zoom 0.5, 1, 2 (High quality; Low draws detail 0). Slots 0 to 7 are `roof`, `roof_dark`, `side`, `side_dark`, `machine`, `smoke`, `owner_flat`, `skin` (`meta.slot_names`).

- **`shapes`**: the 37 game shape ids, picked. Each has `id`, `name`, `faction`, `class`, `role`, `layer`, `has_turret`, a `footprint` for buildings, and `parts`: `{name, angle: heading|turret|fixed, pivot [x, y] in cells, prims}`; a prim is `{type: box|cylinder, offset [x, y, z], size [x, y, z], slot}`, x and y in cells, z in height units. `parts_by_detail` (`"1"`, `"2"`) and `damage_variants` (`"1"`, `"2"`: round 4's 70 % and 35 % looks) replace `parts` where present; a detail without its own list uses `parts`, and a damage variant is used at every detail (`meta.note`). Roles are today's; splitting them per faction is the packages' work.
- **`extras`**: 27 shapes that are not one game id each: `default_building`, `default_vehicle`, `supply_source_default`, the ten piles `pile_<big|small>_<100|60|25|5|0>`, six construction frames `site_frame_<2|3>_<10|50|90>`, `salvage_crate`, six `<unit>_wreck` and `usa_factory_paused`.
- **`palette`**: only the values that differ from `shapes-current.json`: `side`, `side_dark`, `owner_base` (eight, slot order), `owner_names`, `cliff`, `fog`, `cargo`, `wreck`, and `round6`, the round 6 palette names as picked (`palette` for both grounds, `paletteDark` for the dark ground only).
- **`meta`**: `picks` (every step of rounds 1 to 6 as picked: round 6 `surfaces A, edge B, power A, owners A, cargo B, paused A, wrecks A`), `corrections` (checked by `export.sh`), and `provisional.missing_zoom2`, the 23 ids with no zoom 2 version (they bake from `parts` at detail 2; never invented in the export).

Heights below are the highest prim top of `parts` in height units (x 3.5 px at zoom 1); "today" is `shapes-current.json`. Re-make or re-check: `sh docs/images/map-art/source/export.sh` and `sh docs/images/map-art/source/roundtrip.sh` ([source README](../images/map-art/source/README.md)).

## P2.3a See your selection: map edge, canvas and marks

Pictures: [gate reference](../images/map-art/gate-reference-z1.webp), [marks](../images/map-art/marks-z1.webp), [edge today](../images/map-art/edge-today-z05.webp) and [picked](../images/map-art/edge-picked-z05.webp), and the HUD v5 backdrops `docs/images/hud-v5/source/worlds/w-<state>.png`, re-made from this source.

**Map edge B and canvas** (user, 2026-11-17; the edge itself decided 2026-11-15 in the [second pass](design-answers-2026-11-08.md#visual-and-ux-proposal-second-pass-user-2026-11-15)). Values from `palette.round6`:

| Name | Value | What |
|---|---|---|
| `EDGE_HEIGHT` | 24 | Side face height in px at zoom 1 (12 at 0.5, 48 at 2), hanging straight down from the two camera-facing map edges |
| `EDGE_SIDE` | `#425463` | South-west (lit) face; the south-east face is the same colour darkened 0.3 (Godot `darkened`), `#2E3B45` |
| `CANVAS` | `#08090A` | Everything past the map edge |

- No lit line on the top edge (decided 2026-11-15). Faces past the fog edge take the fog (black at 0.35, the fog's 0.65 brightness); the canvas is not fogged. The shade factor, the hanging geometry and the fog rule are in the overlay only (`cand6-edge.js`), not in the export.
- Numbers (WCAG ratio, no bar decided for any of them): lit face on canvas 2.54, shaded 1.73, fogged 1.64 and 1.30; ground on canvas: sand 6.35, dark ground 4.34, fogged dark ground 2.33 (noted, user, 2026-11-17).
- Zero Hour draws no map edge; its maps carry a terrain border band (edge step, GeneralsGameCode `afc2a103f` `GeneralsMD/Code/Tools/WorldBuilder/src/MapPreview.cpp:192-196`; what it draws past the terrain was not checked).
- The game sets no clear colour today (no `clear_color` in `game/project.godot` or `game/scripts/`), and no test pins one.
- The black bars of the 2.4:1 and 16:10 cap are "a different shade from the canvas" ([groundwork](design-answers-2026-11-08.md#p23a-groundwork-questionnaire-user-2026-11-17)); that shade against `#08090A` is picked by the P2.3a design (user, 2026-11-17).

**White marks.** White with a dark under-stroke `rgba(14,18,22,0.78)` 2 px wider, told apart by shape (decided 2026-11-15, [second pass](design-answers-2026-11-08.md#visual-and-ux-proposal-second-pass-user-2026-11-15)). Sizes in stage px at zoom 1, as drawn in `source/marks.js`, with where each comes from:

| Mark | Size | Source of the size |
|---|---|---|
| Unit selection | Diamond 2:1, half width 10 infantry, 19 armour-piercing vehicles, 16 others; line 1.25 | Half width: game code (`_half_width + 4`, `world_view.gd:147-153, 350-354`). Line: carried from the HUD v5 backdrops (`world.js`, private), not decided |
| Building selection | Footprint diamond, white 1.5 over a 4.5 under-stroke | Carried, not decided |
| Hover | Four corner ticks, 0.32 of each diamond edge, line 1.5 | Ticks decided (2026-11-15); 0.32 and 1.5 carried, not decided |
| Attack target | X, arm 6, line 2, 8 px above the ground point | X decided; sizes carried, not decided |
| Move confirmation | Ring 9 x 4.5, line 1.5, one still of the 0.4 s close | 0.4 s decided; start and end radius not decided |
| Placement valid / blocked | Cell outline 1.25; blocked adds an X between edge midpoints (0.22 to 0.78 of the cell), 1.5; ghost at 55 % | Shapes decided; widths carried, not decided |
| Range ring | 9 cells for the Rotary Gun Tower (`game/scripts/simulation/definitions/shared.gd:21`), iso ellipse rx 407, ry 204; line 1.25 | Range: game data. Line carried, not decided |
| Rally | Line from the door 1.25; pole 24, line 1.5; flag 10 x 9; foot ring 4 x 2, line 1 | Pole and flag decided; sizes carried, not decided |
| Dashed target line | Line 1.25, dash 6/4, from 20 + 8 px above the defence to 8 px above the target | Width and dash: **agent proposal, not decided**. End points: `MUZZLE_LIFT` 20 from game code (`world_view.gd:60, 592`, which ends at the target's ground point); the extra 8 px at both ends is the page's |
| Order | Place marks (move, range) under the pieces, unit marks above | Decided (2026-11-15) |

- **Health bars:** the green-yellow-red fill with a thin owner frame is decided (HUD round, user, 2026-11-09); the pictures keep the game's colours (`health_color`, `world_view.gd:84`; bar 24 x 3, `:61`) by a coordinator call; the bar rule goes to the P2.3a health-bar A/B ([groundwork](design-answers-2026-11-08.md#p23a-groundwork-questionnaire-user-2026-11-17)).
- **The "." key cap.** A filled square was tried in the gate picture and reverted: "." is the decided idle-builder key ([controls](design-answers-2026-11-08.md#controls-friends-playtest-user-2026-11-08)). Whether a bare "." reads on a key cap is for P2.3a to check.
- **Owner colours in the HUD** follow palette A: the HUD v5 tokens `you` `#628ffa` and `enemy` `#d6120c` in `docs/images/hud-v5/layout.json` (lifted until 3:1 on `bg`; neither needed it). The P2.3a token A/B also checks owner colours against the cyan `sel` of the set that wins (user, 2026-11-17). Open (agent finding, 2026-11-17): palette A green `#4ad49b` sits 15.0 from the HUD `ally` token `#69ceaa` (teammate ping arrow and minimap dots, [layout](hud-v5-layout.md)), 7.8 under deuteranopia, below the owner-pair bar of 20; not decided whether the token A/B checks owners against `ally` as well, or the minimap draws owner colours (Full set, P3).
- **Owner without colour** (open, agent finding, 2026-11-17): the selection panel shows a selected enemy's owner by colour only; in 3v3, with the friend/foe mode on or for a colour-blind player, nothing says which enemy owns a unit. Not decided whether the panel names the owner (player name or seat) beside the owner-colour edge.

Game today and the tests these touch:
- Selection green `#8cff87` (`world_view.gd:62`, drawn `:451`, move ring `:552`); attack and target marks red `#ff3b30` (`:516-537`); battery line red (`:585`).
- `game/tests/test_view.gd`: V20 selection diamond geometry `:483` (colour not pinned), V6 battery line `:194` and `:678`, move ring lifetime `:114` and `:130` (1.3 s today, 0.4 s decided), build preview `:87`, grid while placing `:524`; health bar `:455`, `:468`, `:475` only if the A/B changes the rule.

## P2.4 Three armies: unit shapes and the palette

Pictures: [units](../images/map-art/units-picked-z2.webp), [tanks](../images/map-art/tanks-picked-z2.webp), [owners today](../images/map-art/owners-today-z1.webp) and [picked](../images/map-art/owners-picked-z1.webp).

**Shapes.** The 17 unit ids in `shapes` (`class` vehicle, infantry, air), picked in rounds 2 and 4 with the round 4 questionnaire corrections (`meta.corrections`). Heights to re-pin:

| Id | Height | Today | Hull length (cells) |
|---|---|---|---|
| `usa_tank`, `china_tank`, `frc_tank`, `china_light_vehicle` | 3.0 | 3.0 | 0.9, 0.76, 0.7, 0.76 |
| `usa_light_vehicle` (Scout Car) | 2.7 | 4.5 | 0.64 |
| `frc_light_vehicle` (Armed Pickup) | 3.95 | 4.5 | 0.65 |
| `usa_builder`, `china_builder` (bulldozers) | 4.95, 4.2 | 4.5 | 0.73, 0.745 |
| Rifle and rocket infantry, Laborer | 4.5 | 4.5 | |

The zoom 2 versions of the unit ids in `meta.provisional.missing_zoom2` are drawn in P2.4 (user, 2026-11-14).

**Palette A** (user, 2026-11-17): `palette.owner_base` and `owner_names`, in slot order. Teal moves to slot 5 and orange to slot 7, which takes orange out of the first six slots; the 3v3 gain comes from that order (owners step) (a match's players are seats 1 to N, `map_data.gd:26-35, 58`, coloured by `OWNER_BASE[owner - 1]`, `palette.gd:29`).

| Slot | Name | Game today (`palette.gd:3-6`) | Round 5 pick (never in the game) | Palette A |
|---|---|---|---|---|
| 1 | blue | `#376eac` | `#44adf4` | `#628ffa` |
| 2 | red | `#b04a3a` | `#d54f3b` | `#d6120c` |
| 3 | green | `#3f8f4f` | `#4fc389` | `#4ad49b` |
| 4 | gold | `#c9a227` | `#ecdc3c` | `#f8e425` |
| 5 | teal (orange today) | `#d27a2c` | `#e08522` | `#0e92a7` |
| 6 | purple | `#7a4fa0` | `#9249ac` | `#7242fe` |
| 7 | orange (teal today) | `#2f9c9c` | `#008d8d` | `#ec8600` |
| 8 | pink | `#c8628f` | `#ffa5d4` | `#f79cef` |

- Same colours on every ground; the dark ground stays `#7B7566` (its lift to `#837d6d` failed six owner distances, so the owner colours were redrawn instead).
- With them, unchanged since round 5: `side` `#1c2e39`, `side_dark` `#0e1b23`, the cliff factors (`palette.cliff`). Fog 0.65 belongs to the fog package. The labels "gold" and "purple" match Zero Hour's `ColorGold` and `ColorPurple` (`data\ini\multiplayer.ini:44-48, 80-84`).
- **The bar the palette meets** (replaces "owner top 3:1 against the ground"): side band against the ground at least 3:1, every owner pair at least 20 apart, and a colour-vision distance between each owner top and each ground (user, 2026-11-17); the numbers the coordinator set for the round: owner against the HUD slab at least 3:1 (the HUD v5 lift rule), owner against the cargo colour and the HUD amber `#F7C871` at least 20, and per ground the smallest owner-to-ground distance not below the round 5 set's (coordinator calls). The old bar was dropped because it cannot be met: research for the round (research agent's report, `owners-dark-research.md`, private) found that no ground tone and no eight-hue set reaches 3:1 for every top except a near-black ground (about `#1f1d1a`, darker than any playable ground), and that what separates an owner from the ground is hue, under colour-vision simulation. Its reading of the guidelines: WCAG 2.2 SC 1.4.11 asks 3:1 against adjacent colours for parts of graphics needed to understand the content and does not mention games, and the side band at 3:1 against the ground is the outline that carries that contrast (agent reading); Xbox Accessibility Guideline 102 asks 3:1 for large visual elements but accepts that a game world will not always meet it and names outlines. Shipped RTS games with an opt-in friend/foe or team colour mode, per the same report: Age of Empires II DE, StarCraft II (from a secondary copy of its patch notes) and Beyond All Reason.
- Numbers (audit over the baked picks, `PASS 830 known 1`): weakest pair of the first six slots 31.4 (blue/purple; round 5 set 22.2), of all eight 23.6; per ground the smallest owner distance on sand 21.51, fogged sand 15.19, dark ground 25.36, fogged dark ground 17.72 (round 5 set 14.31, 10.18, 15.27, 11.03); lowest on the HUD slab 3.23 (purple); HUD amber 25.2. Not audited: pink sits 7.1 from the HUD cyan `#60e5ed` under deuteranopia (accepted, user, 2026-11-17, checked in P2.4 with the colour-blind presets); purple and red tops are about 2.6 against their own side band; tritanopia is not in the bar (open, agent finding, 2026-11-17), and its weakest pair is blue/teal 12.1, both in the first six slots; green sits 15.0 from the HUD `ally` token `#69ceaa` (7.8 under deuteranopia; open, see [P2.3a](#p23a-see-your-selection-map-edge-canvas-and-marks)).

**Riders** (user, 2026-11-17):
- **Neon removed.** The opt-in Neon set goes with its menu toggle; F12 closes as "Neon removed". Code: `palette.gd:11-14, 28-30`, `graphics_settings.gd:38-43`, `pause_menu.gd:11, 54-56, 134-141`, `launcher.gd:301`, `match/match_screen.gd:89, 96`, `world_batch.gd:42`, `world_view.gd:122`, `lab/ab_variants.gd:15`.
- **Friend/foe colour mode and colour-blind presets,** opt-in and off by default (in 3v3 it hides which enemy is which), presentation only; the HUD edge colour follows it.

Tests the palette and riders touch (`game/tests/`):
- Neon: `test_graphics_settings.gd:156-193` (W8), `:207` (S1), `:244-245` (D1); `test_view.gd:968-978` (W8); `test_shapes.gd:249-257` (AB8, which also holds the only `NEUTRAL` distance check); `test_launcher.gd:537-547` (G1, G2); `test_playtest.gd:206` (PT6); `test_online_scene.gd:622` (Settings node list).
- Palette: `test_shapes.gd:202-207` (SH15 pins today's sides `3D515F`, `263842`), `:51-58` (SH6, distinct roofs, holds), `:259-266` (W1 grounds, unchanged); `test_world_batch.gd:203, 245` (golden colours and shapes, re-pinned once for colours and once for shapes, decided 2026-11-14).
- Shapes: `test_shapes.gd:61-73` (SH7 role map), `:99-131` (SH9, SH9b turrets), `:159-171` (SH12 heights: tanks 3.0, light vehicle and bulldozer 4.5), `:181-186` (SH13 hulls), `:188-200` (SH14), `:209` (SH16 infantry), `:224-229` (SH17 bulldozer blade), `:231-238` (SH18 head fan), `:268-274` (W4); `test_shape_audit.gd:71` (SA3 identity), `:174-181` (SA4 paint order, two headings today; eight in P2.4), `:190` (SA5 owner share; the China rifle at detail 2 measures 21.2 % on the page against the 30 % floor, the audit's one known line), `:207` (SA6, SA7).

Art lab items: owner colours under fog for colour-blind players (blue and teal are the closest fogged pair; no palette fixes it without losing elsewhere); after P2.4, the contact mark under infantry; the occluded-unit cue F17 (no package named).

## P2.5 Supplies you can read: cargo, piles, crates and sites

Pictures: [cargo today](../images/map-art/cargo-today-z1.webp) and [picked](../images/map-art/cargo-picked-z1.webp), [surfaces picked](../images/map-art/surfaces-picked-z1.webp), [placeholders picked](../images/map-art/placeholders-picked-z1.webp).

**Cargo white** (user, 2026-11-17; [value](design-answers-2026-11-08.md#map-art-faction-shapes-m75-user-2026-11-13)): `palette.cargo`, the neutral owner's colour (owner 0, `NEUTRAL` `#f7c871` today, `palette.gd:20`), replacing round 3's pale steel `#DDE4E6`, which failed against pink. Pallet sides are cargo x 0.75. Numbers: sand 3.14, dark ground 4.59; nearest palette A owner green 28.9, in fog 20.3. It is the same white as the map marks, which are outlines with a dark under-stroke, so shape tells them apart.

**Earth pile pad** (user, 2026-11-17): `PILE_PAD` `#5c4e33` on sand, `#444037` on the dark ground (`paletteDark`), the ground darkened 45 %, in slot 5 of the pile and crate colours. The pad prim fills the whole footprint (big 4 x 5, small 1 x 1, 0.5 high), so the game's fixed footprint fill `Color("9f8045")` under every supply source (`game/scripts/presentation/world_view.gd:473`) is hidden; hiding that fill is a rider (user, 2026-11-17). Pad on sand 2.58, on the dark ground 2.25 (no bar decided).

**Shapes** in `extras`: `pile_big_*` and `pile_small_*` (rows of pallets that empty from one end, round 3), `site_frame_3_*` (posts 13.6 high) and `site_frame_2_*` (posts 6 high), `salvage_crate`; in `shapes`, the tandem-rotor `usa_collector` (height 4.2, today 3.6).

Tests these touch (`game/tests/`):
- `test_shapes.gd:202-207` (SH15): every owner's slot 5 must be a dark neutral (`v < 0.3`); the sand pad `#5c4e33` has `v` 0.36, so a pad in owner 0's slot 5 fails it (the dark-ground pad, 0.27, passes); one owner 0 slot cannot hold a per-ground pad colour either, so P2.5 needs the pad colour from the ground set.
- `test_view.gd:363` and `:388` tell sources from buildings by the `9f8045` fill; `:365` (V11 pile label), `:390` (small pile view), `:259` (V10 crate marks).
- `test_world_batch.gd:77, 118` (rise with work), `:148` (supply stack shrinks), `:157` (small pile inside footprint), `:203, 245` (golden); `test_shape_audit.gd:171` (supply source cases).

Open: the salvage crate's drum is slot 5 too, so it takes the pad colour in the pictures (earth brown instead of the dark `#2a2c2e` accepted on 2026-11-13); not asked.

## P2.6 Three kinds of base: buildings, doors, paused sites, no power

Pictures: [buildings](../images/map-art/buildings-picked-z1.webp), [damage](../images/map-art/damage-picked-z05.webp), [surfaces](../images/map-art/surfaces-picked-z1.webp), [paused today](../images/map-art/paused-today-z1.webp) and [picked](../images/map-art/paused-picked-z1.webp), [power today](../images/map-art/power-today-z1.webp) and [picked](../images/map-art/power-picked-z1.webp).

**Shapes.** The 20 building ids in `shapes`; footprints unchanged. Heights to re-pin (today in brackets):

| Role | USA | China | FRC |
|---|---|---|---|
| Barracks | 5 (6) | 4 (6) | 4 (6) |
| Vehicle Factory | 13.2 (14) | 14.5 (14) | 12.6 (14) |
| Headquarters | 29.4 (18) | 23 (18) | 33 (18) |
| Supply Depot | 12.3 (8) | 11 (8) | 13 (8) |
| Power Plant | 18 (13) | 12 (13) | none |

Damage variants 1 and 2 for the 14 picked bodies are in `damage_variants`; the building ids in `meta.provisional.missing_zoom2` get their zoom 2 versions in P2.6 (user, 2026-11-14); the China and FRC barracks' zoom 2 versions are stale (see [Not covered](#not-covered-or-not-decided)).

**Roof shade** (open for the user at P2.6, agent note): the 2026-11-09 answer gives building roofs a calmer, darker owner colour ([look Q5](../questions/next-m75-art-look.md)); the game and every round 1 to 6 picture draw them in the same full owner colour as unit tops (`palette.gd:29-33`), and palette A was picked on that look.

**Doors A, framed openings** (user, 2026-11-17): each door keeps its dark slab (slot 3, `side_dark`); `DOOR` `#8098a5` pieces in slot 7 frame it in the door's plane. USA, FRC and the China barracks get two side posts and a top bar; the China factory and Headquarters a top bar only (their pillars already flank the opening, `source/cand6-surfaces.js:65`); the USA factory's steel lintel becomes its top bar. Sizes, post width in cells and top bar height in units: USA barracks 0.07 and 0.6, China barracks 0.07 and 0.25, FRC barracks 0.05 and 0.5, China HQ 0 and 0.4, USA factory 0.1 and 0.8, China factory 0 and 0.8, FRC factory 0.1 and 0.5. Frame against wall 4.64, against the opening 5.80. In the game slot 7 is `SKIN`, shared with infantry heads (`palette.gd:15`; pinned by `test_shapes.gd:209` SH16 and `:268-274` W4), so doors need a building-only colour; `#8098a5` is already `MACHINE` (`palette.gd:10`, slot 4) (agent note). Slot 4 cannot carry it: machine side faces take the neutral sides (`shape_bake.gd:63-65`), and a 0.04-deep frame is mostly side face.

**Paused construction** (P2.6 rider, user, 2026-11-17): a site nobody is building shows its four corner posts alone, round 3's rule as written ("posts alone mean just started or paused"). Drawn for the USA factory only: `usa_factory_paused` in `extras`, four slot 4 boxes 0.09 x 0.09 x 14.2 at (±1.42, ±1.42), the building's height plus 1; the footprint takes the site tint (`world_view.gd:478`). The price: a site paused at 90 % looks like one just started, and an opponent no longer sees how far it got, which Zero Hour shows ([paused](map-art-round-6-verification.md#c-construction-paused-part-way)). Today the game appends " paused" to the site's percent text (`world_view.gd:330-333`, tested `test_view.gd:143-165`, H2); the text leaves the map in P2.5, the panel reads `PAUSED · NO BUILDER` ([groundwork](design-answers-2026-11-08.md#p23a-groundwork-questionnaire-user-2026-11-17)). For its owner, too, a paused site and an active one at 0 to 10 % are the same four posts; the P3 rider "a map mark on your own stalled construction sites" ([packages](../packages.md)) and that panel line are what tell them apart (agent finding, 2026-11-17). Open (agent finding, 2026-11-17): what a paused site shows to allies and opponents, and as a remembered site under fog.

**No power, option A** (P2.6 rider after the art lab confirms it; F21 stays open, user, 2026-11-17): a steady white lightning bolt over a 3 px dark under-stroke `rgba(14,27,35,0.9)` stands 3 + 2 x zoom px above each dark powered defence, 11 + 8 x zoom px tall (15, 19, 27 at zoom 0.5, 1, 2); nothing else changes, and the production slowdown shows only in the HUD power readout. Powered kinds: `usa_defence`, `china_defence` (`game/scripts/simulation/definitions/usa.gd:17`, `china.gd:17`). This is Zero Hour's rule in Wargrid's mark style ([low power](map-art-round-6-verification.md#a-low-power-a-building-and-a-defence)). Overlay only, not in the export. No presentation test covers power today; `test_defences.gd:56` (DF4) is the simulation side and does not change. Open (agent finding, 2026-11-17): who sees the bolt (owner, allies, opponents with vision, remembered under fog); to an opponent it says the defence is offline.

Tests the buildings touch: `test_shapes.gd:61-73` (SH7), `:83-97` (SH8 damage stages on the shared `war_factory`), `:141-151` (SH11 slots), `:167-168` (SH12 factory 14.0, barracks 6.0); `test_shape_audit.gd:52` (footprints), `:71` (SA3); `test_world_batch.gd:100` (damage stage edges), `:203, 245` (golden).

Art lab items: pale roof edges; a completion settle and a roof inset; F21's bolt confirmed in the game.

## Not placed in a package yet: wrecks

Wrecks are their own small item after P2.4 (user, 2026-11-17). Pictures: [today](../images/map-art/wrecks-today-z1.webp) and [picked](../images/map-art/wrecks-picked-z1.webp).

- **Shapes:** six `<unit>_wreck` ids in `extras`, one per tank and light vehicle hull, at full live height (accepted, user, 2026-11-17): USA tank turret slid back, China tank with drooping barrels, China light vehicle with one side sagged and its track thrown, FRC tank with its turret on the ground beside the hull (its own `fallen` part, drawn first, visible at every heading, user, 2026-11-17), the two light vehicles with the gun knocked low. Loose pieces sit in a `debris` part drawn first. 42 to 60 triangles per wreck against 36 to 60 live (drawing agent's count).
- **Colours:** no owner colour. `palette.wreck` (`WRECK_TOP` `#5d6269`, `WRECK_SIDE` `#34383d`, `WRECK_SIDE_DARK` `#222529`) paint top, lit side and dark side faces in place of the machine and side slots; slot 5 keeps its colour. Top on sand 1.96, fogged 1.62, dark ground 1.34, fogged 1.22; lit side on sand 3.76, dark ground 2.57; dark side 4.90 and 3.36. Nearest palette A owner top: teal `#0e92a7` at 20.5 (computed with the page's `minDistance`); the audit's 12.3 was against round 5's teal `#008d8d` (recorded for the wrecks item; no bar).
- **Turret angle:** the pictures turn each wreck's turret 9 to 18 buckets off its hull. In the game, the turret angle at death or a fixed offset (agent proposal). A turned turret alone does not mean "dead"; the read comes from no owner colour, charcoal and the barrel off the axis.
- **Lifetime** stays as decided ([design answers](design-answers-2026-11-08.md#map-art-faction-shapes-m75-user-2026-11-13)). Rule: the salvage crate draws above or beside a wreck (user, 2026-11-17); a crate drops at the wreck's cell (`game/scripts/simulation/salvage.gd:10-15`) and lives 900 to 1050 ticks (`definitions/shared.gd:38`), longer than either wreck. Open (agent finding, 2026-11-17): whether "beside" may offset the crate from its cell, which would break "a click hits what is drawn" (F17); the agent reading is draw order only, the crate at its own cell. Also open: whether a click on a wreck passes through to what is under it, whether a wreck may hide a live unit (with the F17 cue), and who sees a wreck (an opponent with vision only, or remembered under fog).
- **Today** wrecks exist only in the art lab (`game/scripts/lab/ab_variants.gd:24-27`, a shrinking dark diamond); tested by `test_art_lab.gd:151-155` (AB6). Art lab item: wrecks drawn under units.

## Not covered or not decided

- **Zoom 2 versions** of the 23 ids in `meta.provisional.missing_zoom2` (units in P2.4, buildings in P2.6); the export never invents them.
- **Stale zoom 2 barracks:** `china_barracks` and `frc_barracks` `parts_by_detail["2"]` are the bodies before round 4's fixes (China 5.5 high instead of 4; FRC two rooms 5 high instead of three rooms 4 high), so they break the zoom 2 rule; P2.6 redraws both from `parts` (agent finding, not asked).
- **Own stalled-site mark:** the P3 rider; until then the owner tells a paused site from a just-started one only by the selection panel (agent finding, 2026-11-17).
- **F21 stays open** until the art lab confirms the bolt in the game.
- **Art lab list** (design non-goals and round 6): the occluded-unit cue (F17), pale roof edges, the contact mark under infantry, the completion settle and roof inset, dark ground on Ashfall, health bar size and rule, owner colours under fog for colour-blind players, F21's bolt, wrecks drawn under units.
- **Not decided:** the health-bar rule (P2.3a A/B); the bar shade against the canvas (P2.3a design); mark line widths and sizes marked "carried" above; the dashed line's width and dash; the move ring's start and end radius; the crate drum's colour on the pad; a calmer, darker building roof (the 2026-11-09 answer) against today's full owner colour (P2.6).
- **Open, agent findings (2026-11-17), not asked:** who sees the power bolt, wrecks and paused sites as owner, ally or opponent, and what is remembered under fog (Zero Hour's default to look up; each package's design; agent proposal: none appears where the viewer has no vision now); palette A green against the HUD `ally` token `#69ceaa` (15.0, 7.8 under deuteranopia, below the bar of 20; P2.3a token A/B or the P3 minimap); naming the owner in the P2.3a selection panel for 3v3, so friend/foe mode and colour-blind players keep which enemy is which; tritanopia is not in the palette bar (blue/teal 12.1; P2.4 colour-blind presets); whether the crate may be offset "beside" a wreck, wreck clicks and wrecks hiding live units (wrecks item, with F17).
- **Not drawn:** paused sites for China and FRC (the same four posts at that building's height); wrecks and paused sites in a HUD backdrop; the HUD layer over the edge except in the gate picture; the power bolt in a backdrop.
- **Not run:** see [What is proven](#what-is-proven-and-what-is-not).
