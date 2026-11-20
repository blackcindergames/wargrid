# HUD v5 layout reference

This note holds the sizes, colours, type and rules of the HUD v5 mock-ups, so that P2.3a and P2.3b can build the in-match HUD in Godot without measuring pictures. Where it disagrees with the [design answers](design-answers-2026-11-08.md#hud-m76), the design answers win; where the [pictures](../images/hud-v5/notes.md) disagree with this note, this note wins. Nothing here was run in Godot: every figure is measured on the mock-up page in a browser.

Only the picked options are described (all eight picks were A: `two`, `right`, `hug`, `panel`, `cell`, `common`, `pack`, `quiet`; user, 2026-11-16). The numbers come from [layout.json](../images/hud-v5/layout.json) and the page source [round1.html](../images/hud-v5/source/round1.html); the page, its export and picture scripts are all in [source/](../images/hud-v5/source/README.md). The note and the export cover the 13 drawn states; cards for buildings not drawn are a proposal under "Not covered". Labels: "(user, 2026-11-16)" marks a decision recorded in the design answers; "agent call" and "proposal" mark the rest; "measured on the page" marks a figure read from the page.

## Units and scaling

All figures are HUD px, origin top left. The HUD scales with the screen ("HUD size: scaled with the screen" in the design answers) by `k = min(width / 1280, height / 720)` (`meta.scale` in the export), so `k` screen px = 1 HUD px, and the layout is `width / k` by `height / k`: a window wider or taller than 16:9 gives the layout the extra width or height. That this is what the stretch aspect `expand` planned for P2.3a does is an agent reading, not tested in Godot. The export has three sizes:

| Screen | k | Layout (HUD px) |
|---|---|---|
| 1280 x 720 | 1 | 1280 x 720 |
| 1280 x 800 | 1 | 1280 x 800 |
| 1920 x 1080 | 1.5 | 1280 x 720 |

The 1920 x 1080 rectangles are the 1280 x 720 ones (text-hugging widths differ by up to 0.01 from rounding); multiply by `k` for screen px. Between 720 and 800 the bottom-anchored parts move by 80; the one other change is the alert edge arrow, which sits at 40 % of the height (y 288 at 720, 320 at 800). Below, `W` and `H` are the layout's width and height, and the "dock line" is `H - 168`, the top of the 168 px minimap.

## Colour tokens

From `layout.json` `tokens` (measured on the page):

Set A won the P2.3a A/B (user, 2026-11-18; [picks](design-answers-2026-11-08.md#p23a-ab-lab-picks-user-2026-11-18)); the table below is unchanged except `warn`, added at P2.3a1's stop gate A ([gate A](design-answers-2026-11-08.md#p23a1-gate-a-user-2026-11-19), user 2026-11-19).

| Token | Value | Use |
|---|---|---|
| `bg` | `#121c24` | Every slab: top strip, ledge, selection panel, card, minimap frame, cell card, refusal line |
| `btn` | `#223241` | A usable control: ready cell, kind row, filled queue slot, chips, Menu, Team, Sell |
| `panel2` | `#26384a` | An armed or selected control's fill |
| `quiet` | `#16212a` | A cell the player cannot use yet |
| `well` | `#0c141a` | Key chip and queued-count fill, bar tracks |
| `line` | `#2e3f4b` | 1 px slab borders, separators, the supply pile's panel edge |
| `text` | `#eef3f5` | Text |
| `muted` | `#93a5b0` | Labels, hints, key chip letters, blocked cell text |
| `sel` | `#60e5ed` | Cyan: armed or selected control only |
| `amber` | `#f7c871` | Alerts and primary buttons only |
| `warn` | `#f47b6c` | Warnings: low power, the shortfall, an unaffordable cost, the refusal line, the cell card's reason line, the freeze card's warning mark (gate A, user 2026-11-19) |
| `you` | `#628ffa` | Own owner colour (palette A): panel edge, progress bars |
| `enemy` | `#d6120c` | Enemy owner colour on the panel edge |
| `ally` | `#69ceaa` | Teammate ping arrow and minimap dots (Full) |
| `panel`, `edge` | `#1b2731`, `#263842` | Carried over from v4; not used on these pictures |

Two fills are literals on the page, not tokens: empty card wells and empty queue slots are `#0f1820`; an empty queue slot also has a 1 px inset outline in `#223241`. Health bars on the page fill `#5cc85a` above 66 %, `#e0d060` above 33 %, `#d8453a` below. Those steps are a drawing simplification: the game blends the three colours (`game/scripts/presentation/world_view.gd` `health_color`), and the game's rule wins.

Colour rules (design answers, "HUD v4 mock-ups" and "HUD v5 mock-ups"):

- **Cyan** marks only an armed or selected control: fill `panel2` plus a 2 px inset `sel` outline. Buttons are flat otherwise.
- **Amber** marks alerts and primary buttons only (primary buttons are amber already, `game/ui/launcher_theme.tres:71-76`, `:357`).
- **Warn** (`#f47b6c`, gate A, user 2026-11-19) marks warnings: a cost the player cannot afford and the shortfall, low power (`LOW POWER · DEFENCES OFF`, `OFFLINE · LOW POWER`), the cell card's reason line, the refusal line and the freeze card's warning mark. It was picked over the owner mock's `#dc948b`, which turns nearly grey under protanopia (18.2 from the label grey, under the bar of 20; `#f47b6c` stays 29.1 away). Money is plain text. No saturated red text: saturated red is an owner colour.
- **Owner colour** on the panel edge and progress bars is the colour the game draws that owner's units in, lightened toward white in 5 % steps only until it reaches 3:1 against `bg`. None of the eight owner colours of palette A (round 6, user 2026-11-17) needs it; the lowest, purple `#7242fe`, is 3.23:1, red `#d6120c` 3.25:1 (computed from `source/hud.js` `OWNERS` and `BG`).
- Own panels, the card included, carry a 4 px left edge in `you`; an enemy's panel in `enemy`; a supply pile's in `line` (grey, user, 2026-11-16).

## Owner colours against `sel`

Computed for set A's `sel` `#60e5ed` (agent, 2026-11-18; P2.3a A/B lab, Task 9 Step 3 of the [plan](../superpowers/plans/2026-11-18-p2-3a-ab-lab.md)). Contrast is WCAG 2.x; ΔE is CIELAB ΔE76 under normal vision and under Machado 2009 deuteranopia and protanopia at severity 1. The formula is in the plan's Task 9 Step 3.

| Owner | Value | Contrast | ΔE normal | ΔE deut. | ΔE prot. |
|---|---|---|---|---|---|
| blue | `#628ffa` | 2.04 | 70.5 | 48.7 | 52.5 |
| red | `#d6120c` | 3.53 | 130.1 | 81.2 | 73.8 |
| green | `#4ad49b` | 1.25 | 37.1 | 33.0 | 35.0 |
| gold | `#f8e425` | 1.16 | 101.7 | 99.6 | 97.4 |
| teal | `#0e92a7` | 2.45 | 30.8 | 28.9 | 29.8 |
| purple | `#7242fe` | 3.55 | 127.3 | 77.6 | 82.9 |
| orange | `#ec8600` | 1.75 | 110.5 | 91.1 | 79.0 |
| pink | `#f79cef` | 1.27 | 81.3 | 7.1 | 28.9 |
| ally token | `#69ceaa` | 1.27 | 25.4 | 25.5 | 25.5 |

Pink's 7.1 under deuteranopia was already accepted (user, 2026-11-17).

## Type scale

Public Sans from `game/fonts/` (weights 400, 600, 700), tabular numbers everywhere. Line heights measured in the page CSS.

| Role | Size | Weight | Line height |
|---|---|---|---|
| Panel title (unit name, `120 selected · 6 kinds`) | 14 | 700 | 14 (header row 18) |
| Row, button and command names | 13 | 600 | 16 |
| Cell names, up to two lines | 12 | 600 | 14 |
| Numbers | 13 | 700 | 16 |
| Credits value | 16 | 700 | none set; centred in the 32 px strip |
| Labels, uppercase, letter-spacing 0.1 em | 12 | 700 | 14 |
| Hints (rally line, `/ min`) | 12 | 400 | 14 |
| Key chips | 12 | 700 | 18 |

The Numbers row stays 13 / 700 (user, 2026-11-18; the owner was unsure against 14 / 700): it gets one look on the Steam Deck's 1x screen in the P2.3a playtest and switches to 14 / 700 if numbers read poorly there ([picks](design-answers-2026-11-08.md#p23a-ab-lab-picks-user-2026-11-18)).

12 px is the floor. The widest unit or building name of the three factions is 102.1 px at 12 / 600; every name fits a two-line cell at the 84 px name width (the page's name-fit table and its audit, no miss). Many names take two lines, for example Vehicle Factory, Rocket Trooper, Missile Battery, Anti-Tank Trooper, Supply Helicopter, Rotary Gun Tower, Rotary Gun Tank and Rocket Fighter; the name-fit table on the page has the full list.

## Elements

Positions are for 1280 x 720 unless a formula is given. The mock-up follows the match theme rules (user, 2026-11-15): square corners, and every margin, padding and gap on the scale 4, 8, 12, 16, 24, 36; where a 1 px border is drawn, the padding is measured from the outer edge. "Hug" means the slab is as tall as its content (user, 2026-11-16).

### Top strip

Anchored top left at (8, 8), 32 high, width hugs its text (Core about 255 at `4,800` and `8 / 10`). 1 px `line` border, padding 0 8, groups 24 apart, label to value 8. Content: `CREDITS` + value at 16 / 700, `POWER` + `used / available` ("power as used / available", design answers), and, when used exceeds available, the value (`12 / 10`) and the label `LOW POWER · DEFENCES OFF` in `warn` (gate A, user 2026-11-19: it names low power's one effect, powered defences hold fire). The strip always shows the real numbers. Full adds muted `+1,350 −1,600 / min` after the credits, a 1 x 16 `line` separator and the production strip.

**Forecast while a building is armed** (user, 2026-11-13; moved out of the strip at P2.3a1's gate A, user 2026-11-19): the `AFTER PURCHASE` card under the strip at (8, 48), a `bg` slab with a 1 px `line`, padding 8, width hugs (about 490 x 56 at 1280 x 720 at its longest); line 1 a muted `AFTER PURCHASE`, line 2 the values after the purchase, muted 12 / 600 labels and 16 / 700 tabular values, fine values in `text`, values with a problem and the low-power words in `warn`, no arrow (Public Sans has none). Placing a Rotary Gun Tower at 4800 credits and power 8 / 10: `CREDITS 3600`, `POWER 11 / 10 LOW POWER · DEFENCES OFF`; at 500 credits: `CREDITS −700` (U+2212). Placing a Power Plant: `POWER 8 / 15`. Gone on place or cancel.

### Menu chip, Team chip, playtest chip

- **Menu**: anchored top right, right edge 8 from the screen edge, top 8, 32 high, padding 0 8, fill `btn`, 1 px `line` border, 13 / 600, then an `Esc` key chip. 86.75 wide with the chip, 50.3 without. It hides `Esc` while the build menu or a placement is open (states build, place, blocked; user, 2026-11-16).
- **Team** (Full): same chip, 8 left of Menu.
- **Playtest** (the checklist chip, user, 2026-11-16): under Menu, right-aligned at right 8, top 48: label `PLAYTEST` and number `2 / 5`, 32 high, about 124 wide. Drawn in Core only; where it sits beside the Full set's alert feed and Team chip is not drawn.

### Selection panel

Anchored bottom left: x = 0 in Core, x = 176 in Full (8 right of the minimap); it moves once when the minimap lands (user, 2026-11-16). 408 wide, bottom on the screen bottom, height hugs. Borders 1 px top and right in `line`, 4 px owner edge on the left, padding 12 top and bottom, 16 left and right, blocks 8 apart. It holds no command buttons, with one exception: Sell stays a button here until its own package decides between panel and card cell (user, 2026-11-16). Not shown when nothing is selected.

Heights per state (measured, HUD px): Core one, builder, build, place, blocked, enemy, pile 62; plant, site 86; factory and full 84 (P2.3a1 moved the queue to the slab and the pile to one `CREDITS LEFT` line; [P2.3a1 plan](../superpowers/plans/2026-11-19-p2-3a1-see-your-selection.md) Task 10); many 136. Full: one, builder, build, place, blocked, site 88 (64 px glyph); plant 128 (with Sell); factory and full 172; enemy 62; pile 86; many 136.

Blocks:

- **Identity**: name 14 / 700; then 8 below a 160 x 6 health bar and `cur / max`, 8 apart. A label can sit at the right end of the name row (`QUEUE 4 / 9`, `UNDER CONSTRUCTION`). Full puts a 64 px glyph 8 left of the block.
- **Kind rows** (many): header row 18 high, then rows of 186 x 26 in two columns, 4 apart both ways. A row: padding 0 8 4, name 13 / 600 filling the row, count right-aligned in 28, a 3 px health bar along its bottom; Full adds a 22 px glyph. Click narrows the selection to that kind, shift-click removes that kind (user, 2026-11-17, [design answers](design-answers-2026-11-08.md#p23a-groundwork-questionnaire-user-2026-11-17)).
- **Queue** (factory, user, 2026-11-16): nine 36 x 36 slots, 4 apart, 8 under the identity. A filled slot is a `btn` button showing, in Core, the key of the cell that made the item (`Q Q W Q`), in Full a 24 px glyph; the first has a 4 px `you` progress bar on its bottom edge. Click cancels.
- **Footer** (factory): muted `Right-click ground: rally point` on the left; Full adds `Sell` (122 x 32, glyph 20, muted `+1,000`) on the right. The Full Power Plant panel ends in the same `Sell` button (`+500`).
- **Key and value lines** (plant, pile): label column 112 wide, value 13 / 700.

### Command card

Anchored bottom right: x = `W - 432`, 432 wide, bottom on the screen bottom (user, 2026-11-16). No title row. Fill `bg`, 1 px `line` top border, 4 px `you` left edge, padding 8, with 12 on the left (4 edge + 8).

**Lattice**: 4 x 3 cells of 100 x 60, 4 apart. A cell's key is its position (user, 2026-11-16). The one cell whose chip shows another key is Back (Cancel while armed) on `V`: its chip reads `Esc`, and both `V` and `Esc` trigger it (user, 2026-11-16). In the export, `key` is the key bound by position and `chip` is the label shown when it differs.

| Row | Keys | Cell top | Cell x |
|---|---|---|---|
| 1 | `Q W E R` | `H - 196` | `W - 420 + 104 i`, i = 0..3 |
| 2 | `A S D F` | `H - 132` | same |
| 3 | `Z X C V` | `H - 68` | same |

At 1280 x 720 the cells start at x 860, 964, 1068, 1172 and y 524, 588, 652.

**Hug rule for rows**: the slab runs from the top-most row that holds a cell down to the screen edge, so its top is that row's top minus 8. Cells never move; only the slab's top edge does. Two rows: 140 high (top `H - 140`); three rows: 204 (top `H - 204`, 36 above the dock line). Inside the slab, every position without a cell is an empty well: `#0f1820`, no chip, no text (user, 2026-11-16).

**Item cell** (a building or unit to buy): padding 4 8, so names get 84. Line 1, 20 high: cost 13 / 700 on the left, key chip on the right; Full puts a 22 px glyph in front of the cost. Lines 2 and 3: name 12 / 600, line height 14, 4 below line 1, never cut. A queued count `×3` sits 4 from the bottom right: 14 high, padding 0 4, fill `well`, 13 / 700.

**Command cell** (Attack Move, Stop, Guard, Build, Back, Cancel): same box. Line 1 holds the key chip on the right (Full: a 20 px glyph on the left). The name, 13 / 600, sits in a 28 px line 4 under it. Build ends in a muted `›`.

**Key chip**: at least 18 x 18, padding 0 4, fill `well`, `muted` 12 / 700, centred.

**Looks**: ready is `btn`. Armed is `panel2` plus the 2 px `sel` inset. Blocked (cannot afford, missing prerequisite, queue full) is quiet but readable, no opacity: fill `quiet`, name and cost `muted`, an unaffordable cost in `warn` at full strength (gate A, user 2026-11-19; amber before), key chip unchanged (user, 2026-11-16; name 6.4:1 by page arithmetic; `warn` cost 6.1:1 on `quiet`, 4.9:1 on `btn`, WCAG 2.x, agent arithmetic 2026-11-19).

Cards per state (China figures from `china.gd`). Decided (user, 2026-11-16): Build on `Q`, Back on `V`, Attack Move on `A`, Stop on `S`, Guard on `D`, Unload on `F`. Which item sits on which slot in the build menu and in a factory is a proposal (agent, design answers):

| Selection | Cells |
|---|---|
| Units (one, many) | `A` Attack Move, `S` Stop; Full adds `D` Guard; `F` Unload with a transport (decided, not drawn) |
| Builder | `Q` Build ›, `S` Stop |
| Build menu (slots `Q` to `A` a proposal) | `Q` Power Plant 1,000; `W` Supply Depot 1,500; `E` Barracks 500; `R` Vehicle Factory 2,000; `A` Rotary Gun Tower 1,200; `V` Back with chip `Esc` |
| Building armed | as the build menu, the armed cell cyan; `V` reads Cancel |
| Factory (slots a proposal) | `Q` Medium Tank 800, `W` Rotary Gun Tank 800, with queued counts |
| Power Plant, enemy, supply pile, construction site, nothing | no card |

Other factions and undrawn buildings: see "Not covered".

### Cell card

A hover card for item cells: 248 wide, padding 8, fill `bg`, 1 px `line` border, 13 px, lines of 20. Placed 8 above the card slab's top, left-aligned with the hovered cell, clamped 8 from the screen edges. Two lines are 56 high, three 76. First line: name (600) and muted `cost · build time`. Then one reason line, in `warn` (gate A, user 2026-11-19; amber before): `Needs Power Plant`; `Queue full`; the forecast (a muted `CREDITS` or `POWER` label with the value before and after, low power in `warn`; P2.3b settles the form, since the strip no longer forecasts and Public Sans has no arrow); `150 credits short`, with Full adding muted `about 7 s at current income`. Its timing and behaviour follow the decided tooltip rules ([second pass](design-answers-2026-11-08.md#visual-and-ux-proposal-second-pass-user-2026-11-15), [review](design-answers-2026-11-08.md#visual-and-ux-proposal-review-user-2026-11-15)); this note does not restate them. It is not counted as coverage.

### Refusal line

Bottom centre (user, 2026-11-16): centred on `W`, 28 high, bottom edge 8 above the dock line (top = `H - 204`; 516 at 720, 596 at 800), in every state and tier. Fill `bg`, 1 px `line` border, padding 0 8, an 8 x 8 `warn` square, 8 gap, `warn` text 13 / 600 (gate A, user 2026-11-19; amber before). Width hugs the text (140 for `Cannot build here`, a proposal; x 570 at 1280). Shows for about 3 s (user, 2026-11-13, "Refused orders") after the refused click, not while hovering (agent call). The page lifts it 8 above any slab it would overlap; with the card on the right that never happens at 1280. Not counted as coverage.

### Full set additions (later packages)

These come with their own features, after P2.3b ([packages](../packages.md)). Geometry as drawn:

- **Glyphs**: single-colour silhouettes; 64 in the identity, 22 in item cells and kind rows, 20 in command cells and Sell, 24 in queue slots, 18 in chips.
- **Minimap**: bottom left, 168 x 168, padding 8 around a 152 map, borders top and right. Drawn as a sketch; at low power it reads `RADAR OFFLINE`.
- **Ledge**: x 0, top `H - 208`, 32 high, about 310 wide: idle builder chip (glyph, count, key `.`) and control-group chips (key, count), chips 24 high with padding 0 8, 12 apart.
- **Production strip**: in the top strip after the separator, one chip per factory with a glyph and a 40 x 4 progress bar.
- **Alert feed**: (8, 48), 28 high (the spot P2.3a1's `AFTER PURCHASE` card takes while a building is armed: a clash for the package that adds alerts), amber square, `Base under attack`, key `Space`. Edge arrows 28 x 28: amber at the left edge at y = 0.4 `H`, ally at the top edge.
- **Team** chip beside Menu.
- **Pinned factory**: a click-only placeholder (user, 2026-11-16) 220 wide, 8 right of the selection panel (x 592), height hugs (154), padding 12 8: title with muted `×`, two item cells without key chips, five queue slots, and a muted `+N` when more than five are queued (described, not drawn: the drawn queue holds four). Settled in its own package.

## Behaviour without a rectangle

- **Esc** backs out innermost first: an armed placement, then the build menu, then the game menu (user, 2026-11-16).
- **Mixed selection** shows shared commands only: Attack Move shows when any selected unit can attack; a unit without a weapon just moves (user, 2026-11-16).
- **No card** for a selection without commands, such as a Power Plant (user, 2026-11-16), nor for an enemy, a supply pile, a construction site or nothing (as drawn).
- **Core against Full**: Core is words only and only what the game can feed today: top strip with credits and power, the forecast on the card under it (P2.3a1 gate A); selection panel; command card with Attack Move, Stop, Build, the build menu and production; queue; cell card with the credits shortfall, a missing prerequisite, `Queue full` and the forecast, all HUD arithmetic (user, 2026-11-16); refusal line; playtest chip. Full adds glyphs, minimap, ledge, production strip, income per minute, time until affordable, alert feed and edge arrows, Team, Guard, Sell and the pinned factory.

## States

The 13 states drawn, both sets; pictures at 2560 x 1600 for a 1280 x 800 layout.

| State | What it shows | Core | Full |
|---|---|---|---|
| none | Top strip, Menu; no panel, no card | [core-none](../images/hud-v5/core-none.webp) | [full-none](../images/hud-v5/full-none.webp) |
| one | Medium Tank, `180 / 400`; unit card | [core-one](../images/hud-v5/core-one.webp) | [full-one](../images/hud-v5/full-one.webp) |
| many | `120 selected · 6 kinds`, six kind rows; unit card; low power | [core-many](../images/hud-v5/core-many.webp) | [full-many](../images/hud-v5/full-many.webp) |
| factory | Vehicle Factory, `QUEUE 4 / 9`; credits 650, both cells blocked by credits; cell card on `W`: `150 credits short` | [core-factory](../images/hud-v5/core-factory.webp) | [full-factory](../images/hud-v5/full-factory.webp) |
| plant | Power Plant, `1,500 / 1,500`, `POWER +10`; no card | [core-plant](../images/hud-v5/core-plant.webp) | [full-plant](../images/hud-v5/full-plant.webp) |
| full | `QUEUE 9 / 9` (`Q Q W Q W W Q Q W`), counts `×5`, `×4`, both cells blocked; cell card on `Q`: `Queue full` | [core-full](../images/hud-v5/core-full.webp) | [full-full](../images/hud-v5/full-full.webp) |
| builder | Bulldozer, `250 / 250`; `Q` Build, `S` Stop | [core-builder](../images/hud-v5/core-builder.webp) | [full-builder](../images/hud-v5/full-builder.webp) |
| build | Build menu, credits 2,400, power `0 / 0`; `W`, `R`, `A` blocked by prerequisite; cell card on `W`: `Needs Power Plant`; Menu without Esc | [core-build](../images/hud-v5/core-build.webp) | [full-build](../images/hud-v5/full-build.webp) |
| place | Rotary Gun Tower armed on `A`, `V` Cancel, forecast in the top strip | [core-place](../images/hud-v5/core-place.webp) | [full-place](../images/hud-v5/full-place.webp) |
| blocked | Vehicle Factory armed on `R`, forecast, refusal line | [core-blocked](../images/hud-v5/core-blocked.webp) | [full-blocked](../images/hud-v5/full-blocked.webp) |
| enemy | Battle Tank (a USA unit), `312 / 480`, enemy edge; no card | [core-enemy](../images/hud-v5/core-enemy.webp) | [full-enemy](../images/hud-v5/full-enemy.webp) |
| pile | Supply Pile, `CREDITS LEFT 10,650` (`Empty` at zero), grey edge; no card. Drawn with `BOXES LEFT 142` and `COLLECTORS 2 docked · 1 waiting`, both replaced (user, 2026-11-17, [questionnaire](design-answers-2026-11-08.md#p23a-groundwork-questionnaire-user-2026-11-17)); the pictures and the 86 px height are redrawn with the P2.3a design | [core-pile](../images/hud-v5/core-pile.webp) | [full-pile](../images/hud-v5/full-pile.webp) |
| site | Vehicle Factory, `UNDER CONSTRUCTION`, progress `62 %`, `1,240 / 2,000`; no card | [core-site](../images/hud-v5/core-site.webp) | [full-site](../images/hud-v5/full-site.webp) |

Credits, income, group sizes and queue contents are illustrative; names, costs, build times, health and power come from `game/scripts/simulation/definitions/china.gd`, and for the enemy Battle Tank from `usa.gd` (`max_hp` 480000, shown as 480).

## layout.json

[layout.json](../images/hud-v5/layout.json) is the page's own export with the picks applied:

- `meta`: the eight picks, the font, the unit (`HUD px, origin top left`), `scale` (the `k` rule above) and `source` (the page path).
- `tokens`: the colour table above; `type`: the type scale (size and weight per role).
- `screens`: 78 entries, 13 states x 2 sets (`tier`: `core`, `full`) x 3 sizes, each with `state`, `tier`, `size`, `k`, `coverage_pct` and `rects`.
- A rect has `id`, `kind` (`slab`, `cell`, `row`, `slot`, `button`, `popup`) and `x`, `y`, `w`, `h`. `covers: true` marks the opaque slabs the coverage figure sums. Card cells add `key` (bound by position), `chip` (only where the label differs: Back and Cancel show `Esc`), `text` (not for wells) and `state`: `ready`, `armed`, `empty` or `blocked` with `reason` `credits`, `prerequisite` or `queue`. Queue slots carry `state` `filled` or `empty` and, when filled, `text` (the key letter in Core, the item name in Full). Kind rows carry `text` (the kind) and `count`.

Ids are stable and dotted: `top_strip`, `menu`, `team`, `playtest`, `alert`, `arrow.alert`, `arrow.ally`, `ledge`, `minimap`, `selection`, `selection.row.<n>`, `selection.queue.<n>`, `selection.sell`, `pinned`, `pinned.cell.<n>`, `pinned.queue.<n>`, `card`, `card.cell.<KEY>` (wells included), `refusal`, `cell_card`. Numbers count from 1.

How layout tests should use it (proposal, agent): give each HUD control the matching id, render a state headless at each size and compare. Assert strictly what does not depend on text shaping: which ids exist, order along an edge, containment (cells in the card, rows in the panel), no overlap between `covers` rects, the refusal line and the cell card, anchoring to the screen edges, and the cell lattice. Assert sizes and positions within a few px, because Godot will not shape Public Sans exactly as the browser did; text-hugging widths (top strip, chips, refusal line) need the widest tolerance.

## Not covered or not decided

- The grid table across factions (which item sits on which key for USA, China and FRC) is a proposal on the page for the P2.3b design; only China is drawn.
- Cards for buildings not drawn (proposal, agent; from `produces` and `builds` in `usa.gd`, `china.gd`, `frc.gd`): Headquarters `Q` its builder (Bulldozer; FRC Laborer); Supply Depot `Q` its collector (USA Supply Helicopter, China Supply Truck); FRC's Supply Cache produces the Laborer instead of a collector, so its `Q` is the builder; Barracks `Q` rifle and `W` rocket infantry in all three. FRC builds no Power Plant, so its build menu's `Q` stays empty in the page's table. The key order is not the `produces` order: China's factory lists the tank first.
- Player wording for refused orders needs a table from each simulation refusal text; `Cannot build here` is a proposal.
- Not drawn: Barracks, Headquarters, Supply Depot, a building being sold, two factories selected, buildings and units selected together, a transport with Unload, the playtest note dialog, the playtest chip beside the Full set's top-right chips.
- The Full enemy panel has no glyph only because the page lacks a USA glyph.
- On a touchscreen the cell card's reasons cannot be reached; input to the Steam Deck controls spike.
