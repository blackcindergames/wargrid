# HUD v5 layout reference

This note holds the sizes, colours, type and rules of the HUD v5 mock-ups, so that P2.3a and P2.3b can build the in-match HUD in Godot without measuring pictures. Where it disagrees with the [design answers](design-answers-2026-11-08.md#hud-m76), the design answers win; where the [pictures](../images/hud-v5/notes.md) disagree with this note, this note wins. Nothing here was run in Godot: every figure is measured on the mock-up page in a browser.

Only the picked options are described (all eight picks were A: `two`, `right`, `hug`, `panel`, `cell`, `common`, `pack`, `quiet`; user, 2026-11-16). The numbers come from [layout.json](../images/hud-v5/layout.json) and the page source [round1.html](../images/hud-v5/source/round1.html); the page, its export and picture scripts are all in [source/](../images/hud-v5/source/README.md). The note and the export cover the 13 drawn states; cards for buildings not drawn are a proposal under "Not covered". Labels: "(user, 2026-11-16)" marks a decision recorded in the design answers; "agent call" and "proposal" mark the rest; "measured on the page" marks a figure read from the page.

## Units and scaling

All figures are HUD px, origin top left. The HUD scales with the screen ("HUD size: scaled with the screen" in the design answers) by `k = min(width / 1280, height / 720)` (`meta.scale` in the export), so `k` screen px = 1 HUD px, and the layout is `width / k` by `height / k`: a window wider or taller than 16:9 gives the layout the extra width or height. P2.3a1 builds it as `expand` between 1.6:1 and 2.4:1 and a capped view outside that range (see "As built in P2.3a1"); `test_view_caps.gd` and the headless layout tests check the layout, the rendered rows at 2560x1080 are owed to stop gate B. The export has three sizes:

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

Anchored top left at (8, 8), 32 high, width hugs its text (Core about 255 at `4800` and `8 / 10`; plain digits, no thousands separator anywhere, gate A, user 2026-11-19). 1 px `line` border, padding 0 8, groups 24 apart, label to value 8. Content: `CREDITS` + value at 16 / 700, `POWER` + `used / available` ("power as used / available", design answers), and, when used exceeds available, the value (`12 / 10`) and the label `LOW POWER · DEFENCES OFF` in `warn` (gate A, user 2026-11-19: it names the effect a player must act on, powered defences hold fire; low power also slows production and construction to 50-80 % (`economy_definitions.gd` `work_rate`), which P16's NOW row shows). The strip always shows the real numbers. As built (P2.3b top strip round, user 2026-11-22, [design answers](design-answers-2026-11-08.md#p23b-top-strip-round-user-2026-11-22)): two slabs, credits and power, 8 apart at (8, 8), each hugging its content; FRC shows the credits slab alone; the LOW POWER words show while power is low at rest, and during a forecast only when the purchase flips power low ([As built in P2.3b](#as-built-in-p23b)). Full adds muted `+1,350 −1,600 / min` after the credits, a 1 x 16 `line` separator and the production strip (built in P16 as its own slab beside Menu instead, [Full set additions](#full-set-additions-later-packages)).

**Forecast while a building is armed or a buy button is hovered** (user, 2026-11-13; moved out of the strip at P2.3a1's gate A, user 2026-11-19; back into the strip at gate B, user 2026-11-20, replacing the `AFTER PURCHASE` card): the strip previews the purchase itself, as built in [As built in P2.3a1](#as-built-in-p23a1): a `sel` `PREVIEW` label, a 1 px `sel` border, the credits after the purchase with a muted 13 / 700 delta beside them and the power after it with the strip's own low-power words, no arrow (Public Sans has none). Placing a Rotary Gun Tower at 4800 credits and power 8 / 10: `CREDITS 3600 −1200`, `POWER 11 / 10 LOW POWER · DEFENCES OFF`; at 500 credits the strip keeps `500` and shows the cost in `warn`, `−1200` (U+2212). Placing a Power Plant: `POWER 8 / 15`. Gone on place, cancel or leaving the button. Replaced in P2.3b (top strip round, user 2026-11-22): no `PREVIEW` label, no delta; each slab whose number changes shows today's number, a drawn 12 x 8 arrow and the number after it, with a 1 px `sel` frame (`4800 → 3600`, `8 / 10 → 11 / 10 LOW POWER · DEFENCES OFF`); short of credits the number goes below zero in `warn` (`500 → −700`; the coin went in the P16 match, user, 2026-11-23), and power still forecasts; both slabs hold the width of their widest forecast while the pointer is on a card with an item cell or a building is armed.

### Menu chip, Team chip, playtest chip

- **Menu**: anchored top right, right edge 8 from the screen edge, top 8, 32 high, padding 0 8, fill `btn`, 1 px `line` border, 13 / 600, then an `Esc` key chip. 86.75 wide with the chip, 50.3 without. It shows `Esc` only while a press of Esc would open the menu: nothing pending for Esc to clear (a placement, an armed attack move, a selection), no open note form or focused text field, and the menu closed (states build, place, blocked; user, 2026-11-16; `match_screen.esc_opens_menu`). As built (P2.3a1 gate fix, user 2026-11-20): 88 wide both ways (Godot's laid-out width; the mock-up draws 86.75); the `Esc` chip fades to alpha 0 instead of hiding, so neither the chip nor its `Menu` label moves when a selection takes Esc (`test_hud.gd` MW1).
- **Team** (Full): same chip, 8 left of Menu.
- **Playtest** (the checklist chip, user, 2026-11-16): under Menu, right-aligned at right 8, top 48: label `PLAYTEST` and number `2 / 5`, 32 high, about 124 wide. Drawn in Core only; where it sits beside the Full set's alert feed and Team chip is not drawn.

### Selection panel

Anchored bottom left: x = 0 in Core, x = 176 in Full (8 right of the minimap); it moves once when the minimap lands (user, 2026-11-16). 408 wide, bottom on the screen bottom, height hugs. Borders 1 px top and right in `line`, 4 px owner edge on the left, padding 12 top and bottom, 16 left and right, blocks 8 apart. It holds no command buttons, with one exception: Sell stays a button here until its own package decides between panel and card cell (user, 2026-11-16). Not shown when nothing is selected.

Heights per state (measured, HUD px): Core one, builder, build, place, blocked, enemy, pile 62; plant, site 86; factory and full 84 until P2.3b, which makes every own producer's Core panel 152 with queue tiles (user, 2026-11-23), measured 153 with the rally footer (its 15 px line box, as the factory's 85 against 84; [verification](p2.3b-verification.md#t8-queue-tiles-t8b-f38-parked)); P2.3a1 moved the queue to the slab and the pile to one `CREDITS LEFT` line; [P2.3a1 plan](../superpowers/plans/2026-11-19-p2-3a1-see-your-selection.md) Task 10); many 76 at one kind, 98, 128 and 158 for 2, 3-4 and 5-6 kinds with the rule line (gate A, user 2026-11-19; Task 11; drawn many 136 without it), measured 99, 129 and 159 because the 12 px rule line's box is 15 (gate B's pixel check, as the factory's 85 against 84). Full: one, builder, build, place, blocked, site 88 (64 px glyph); plant 128 (with Sell); factory and full 172; enemy 62; pile 86; many 136.

Blocks:

- **Identity**: name 14 / 700; then 8 below a 160 x 6 health bar and `cur / max`, 8 apart. A label can sit at the right end of the name row (`QUEUE 4 / 9`, `UNDER CONSTRUCTION`). Full puts a 64 px glyph 8 left of the block.
- **Kind rows** (many): header row 18 high, then rows of 186 x 26 in two columns, 4 apart both ways. A row: padding 0 8 4, name 13 / 600 filling the row, count right-aligned in 28, a 3 px health bar along its bottom; Full adds a 22 px glyph. Click narrows the selection to that kind, shift-click removes that kind (user, 2026-11-17, [design answers](design-answers-2026-11-08.md#p23a-groundwork-questionnaire-user-2026-11-17)). Cap (user, 2026-11-20, not built until a seventh selectable kind exists): at most six cells, three lines, 158 high; from seven kinds, five kind rows in roster order and a sixth cell `+N kinds` with the summed count and a pooled health bar, which click keeps, shift-click removes and holds like a row; the header still counts every kind; no scrolling (the wheel zooms) and no third column. As built (P2.3a1 gate fix, user 2026-11-20): not built; `test_hud.gd` KC1 fails once any faction fields a seventh selectable unit kind.
- **Queue** (factory, user, 2026-11-16; P2.3a1 builds it as capped rows in the slab, see "As built in P2.3a1"): nine 36 x 36 slots, 4 apart, 8 under the identity. A filled slot is a `btn` button showing, in Core, the key of the cell that made the item (`Q Q W Q`), in Full a 24 px glyph; the first has a 4 px `you` progress bar on its bottom edge. Click cancels. As built in P2.3b (War Room round, user 2026-11-21, 3-3, 3-11; every own producer, user 2026-11-23): in each own producer's panel, which is 152 high in Core, one row of up to four 91 x 60 tiles instead of nine slots: the full name on up to two lines, the making cell's key chip, `NOW` and a 4 px `you` bar on the tile in production, no digits; adjacent waiting entries of one kind share a tile with `×N`; a click cancels the newest stored entry of its run; hover turns the chip into `×` with `Cancel · refunds <cost>`; tiles hold still while the pointer is in the row; over four, three tiles and a muted, borderless, tooltip-only `+N more`; empty reads `Nothing in production`. Progress shows on the NOW tile only; cells keep their `×N` (user, 2026-11-23). Right-click on a production cell cancels the newest entry of its kind.
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

**Looks**: ready is `btn`. Armed is `panel2` plus the 2 px `sel` inset. Blocked (cannot afford, missing prerequisite, queue full) is quiet but readable, no opacity: fill `quiet`, name and cost `muted`, an unaffordable cost in `warn` at full strength (gate A, user 2026-11-19; amber before), key chip unchanged (user, 2026-11-16; name 6.4:1 by page arithmetic; `warn` cost 6.1:1 on `quiet`, 4.9:1 on `btn`, WCAG 2.x, agent arithmetic 2026-11-19). As built (P2.3b, user 2026-11-21): the cost is `warn` only when credits are the sole blocker (its solid `$` coin went in the P16 match, user, 2026-11-23: beside the unit glyph `900 $` ran into the key chip; the cell card keeps `N credits short`); with a missing prerequisite (alone or beside credits) the cost is muted and the reason is `Needs X`; a full queue mutes the cost. A blocked cell shows the arrow pointer, a ready or armed one the hand, a well the arrow. Hovering a cell blocked by a prerequisite frames that prerequisite's cell in 1 px `sel`.

Cards per state (China figures from `china.gd`). Decided (user, 2026-11-16): Build on `Q`, Back on `V`, Attack Move on `A`, Stop on `S`, Guard on `D`, Unload on `F`. Which item sits on which slot in the build menu and in a factory is a proposal (agent, design answers):

| Selection | Cells |
|---|---|
| Units (one, many) | `A` Attack Move (when any unit can attack; its click orders only the armed units), `S` Stop; Full adds `D` Guard; `F` Unload with a transport (built, with the cell shown only while something is loaded) |
| Builder | `Q` Build ›, no Stop (a lone builder's `A` and `S` do nothing) |
| Two or more builders | `Q` Build › blocked, `Select one builder` |
| Nothing selected | no card; `Q` puts `Select a Bulldozer` (FRC: `Select a Laborer`) on the refusal line; a match starts with the start builder selected |
| Build menu (one key per role in every faction) | `Q` Power Plant 1,000 (FRC: empty); `W` Supply Depot 1,500; `E` Barracks 500; `R` Vehicle Factory 2,000; `A` Rotary Gun Tower 1,200; `V` Back, chip `V`, tooltip `Back · V or Esc` |
| Building armed | as the build menu, the armed cell cyan; `V` reads Cancel |
| Factory (one key per role) | `Q` light vehicle, `W` tank, with queued counts (`×4`); Rotary Gun Tank 800 and Medium Tank 800 for China |
| Headquarters, supply building | `Q` its builder or collector (FRC Supply Cache: the builder) |
| Barracks | `Q` rifle infantry, `W` rocket infantry |
| Defence | `F` Unload while it holds units |
| Power Plant, enemy, supply pile, nothing | no card |
| Construction site | no card; `Cancel construction` and the resume hint stay as slab rows outside the grid (a site cell is an owner question after P2.3b) |

Other factions and undrawn buildings: see "Not covered".

### Cell card

A hover card for item cells: 248 wide, padding 8, fill `bg`, 1 px `line` border, 13 px, lines of 20. Placed 8 above the card slab's top, left-aligned with the hovered cell, clamped 8 from the screen edges. Two lines are 56 high, three 76. First line: name (600) and muted `cost · build time`. Then one reason line, in `warn` (gate A, user 2026-11-19; amber before): `Needs Power Plant`; `Queue full`; `150 credits short`, with Full adding muted `about 7 s at current income`. As built (P2.3b, user 2026-11-21): no forecast on the card (3-4; the strip forecasts), and a unit cell's counter line in `text` as the last line (`Beats light vehicles`; line 2 when ready, line 3 under a reason), none for buildings, builders and collectors or in the one-unit and inspected-enemy panels. The card steps 8 px left of any visible playtest helper surface it would sit under, and a blocked command cell (two builders) opens one with its reason. Its timing and behaviour follow the decided tooltip rules ([second pass](design-answers-2026-11-08.md#visual-and-ux-proposal-second-pass-user-2026-11-15), [review](design-answers-2026-11-08.md#visual-and-ux-proposal-review-user-2026-11-15)); this note does not restate them. It is not counted as coverage.

### Refusal line

Bottom centre (user, 2026-11-16): centred on `W`, 28 high, bottom edge 8 above the dock line (top = `H - 204`; 516 at 720, 596 at 800), in every state and tier. Fill `bg`, 1 px `line` border, padding 0 8, an 8 x 8 `warn` square, 8 gap, `warn` text 13 / 600 (gate A, user 2026-11-19; amber before). Width hugs the text (140 for `Cannot build here`, a proposal; x 570 at 1280). Shows for about 3 s (user, 2026-11-13, "Refused orders") after the refused click, not while hovering (agent call). The page lifts it 8 above any slab it would overlap; with the card on the right that never happens at 1280. Not counted as coverage.

As built (gate B, user 2026-11-20; picked in the window A/B): until the dock exists the line is grounded, its bottom edge 8 above the screen bottom, centred between the selection panel's right edge (408) and the slab's left edge (`W - 432`), so at 628 and top 684 at 1280 x 720; the longest refusal (293 wide) clears both at every HUD size (`test_hud.gd` RN1). Once the dock exists the line lifts onto it as drawn above, and 8 above any slab or panel it would overlap.

### Messages

Each kind of message has one home, one colour and one lifetime (user, 2026-11-20, [design answers](design-answers-2026-11-08.md#p23a1-gate-b-window-feedback-user-2026-11-20)); a shared list would let refusal spam push out alerts.

| Kind | Trigger | Home | Life | Colour and sound |
| --- | --- | --- | --- | --- |
| Answer (refusal; P2.3a2's neutral line) | the player's click | bottom centre, see Refusal line | 3 s, the next replaces it | `warn` with the beep; the neutral line muted and silent |
| Notice (waiting, disconnected) | the match or network | top centre, top 48 | while the state lasts | `muted`, silent |
| Alert (base under attack, building lost, ready) | the world | the alert feed at (8, 48), with its feature | about 10 s (proposal) | amber, the announcer's voice with a caption (P3 rider) |
| Ending (desync, opponent left, game error) | the match ends | the result card (P2.3a2) | until left | the card's own |

The refusal line's spot before the dock exists was settled by an A/B in the window: B, grounded 8 above the screen bottom between the selection panel and the slab (user, 2026-11-20; see the refusal line's as-built note).

### Full set additions (later packages)

These come with their own features, after P2.3b ([packages](../packages.md)). Geometry as drawn:

- **Glyphs**: single-colour silhouettes; 64 in the identity, 22 in item cells and kind rows, 20 in command cells and Sell, 24 in queue slots, 18 in chips.
- **Minimap**: bottom left, 168 x 168, padding 8 around a 152 map, borders top and right. Drawn as a sketch; at low power it reads `RADAR OFFLINE`.
- **Ledge**: x 0, top `H - 208`, 32 high, about 310 wide: idle builder chip (glyph, count, key `.`) and control-group chips (key, count), chips 24 high with padding 0 8, 12 apart.
- **Production strip**: in the top strip after the separator, one chip per factory with a glyph and a 40 x 4 progress bar. As built in P16 ([production strip round](design-answers-2026-11-08.md#production-strip-round-user-2026-11-23), user 2026-11-23; `production_strip.gd`, `HudModel.strip_chips`): its own slab (`bg`, 1 px `line` border, 32 high, top 8), shown only while at least one own producer is producing (user, 2026-11-23: with nothing in production there is no slab, no chip and no `+N`, and the map under it takes clicks; a selected producer does not keep it), whose right edge sits 8 left of Menu, growing leftward, so the credits and power slabs holding their forecast widths never move it, for FRC too. Inside, 4 from the edge and 4 apart, one chip per finished own producer. Upright by default (user, 2026-11-23, after trying both): 42 x 26, in columns 2 | 9 px count | 2 | 18 px unit glyph (4 from the top) | 4 | 4 x 20 bar | 3; the count column stays reserved while the count hides, so a chip never changes width. Stacked (`F7`, the round's chip C): 48 x 26, the glyph 1 from the chip's top over a 40 x 4 bar. Bars sit on `well`, filled in the viewer's slot colour in whole pixels from the bottom (stacked: from the left edge), the track drawn without anti-aliasing so its edges match the fill's. The current run (the unit in production plus the same kind straight behind it, as NEXT's `×N`; user, 2026-11-23, superseding the queue length after a mixed queue's `7` read as seven tanks) sits in 12 px `muted` digits (the HUD's smallest size; the owner asked for about 11) in its own column left of the glyph, top-aligned with it (stacked: the chip's top right, right of the glyph), hidden while idle (user, 2026-11-23; the first upright layout put it over the glyph's corner, where the owner saw it collide); while other kinds follow, a filled right-pointing 4 x 6 `muted` triangle sits under it, centred in the count column, its bottom on the glyph's (stacked too). Order: Headquarters, Supply Depot, Barracks, Vehicle Factory, an airfield-type slot if one ever exists, then by age (object id). Headquarters and Supply Depot kinds show only while producing; an idle Barracks or factory keeps its chip with its last unit in production (the Q cell's unit if it made none) in the darker `#7b8d99` grey and a hollow bar (1 px outline in that grey). Under low power (`work_rate` below 1000) the bar is `warn`; an exit-blocked entry gives a full `warn` bar. Eight chips, then a muted `+N` at the left end, the front of the order folding first. Chip fill `btn`; the selected producer's chip `panel2` with a 1 px `sel` inset; hover `panel2` with a 1 px `muted` inset. A click on an own finished producer selects it without moving the camera and ends a placement, the build sub-grid or attack move; a second click on the same chip within 0.667 s (the control groups' double tap) also glides the camera there. Hover cards follow the tooltip rules (a neighbour opens at once; after leaving the strip the next waits 250 ms again): 8 under the strip, from the chip's left, clamped 8 from the screen edge and 8 left of a playtest helper they would cover; a chip's card reads the producer's name, `Medium Tank ×4 · 4s, then Scout Car ×3 · QUEUE 7 / 9` (` · +N more` before `QUEUE` when a third run follows; `Medium Tank · 4s · QUEUE 1 / 9` alone; or `Idle`) and `Click: select it · Double-click: go there`; `+N`'s lists `ALSO PRODUCING` and one line per folded producer (`Headquarters · Bulldozer 3s`, `Barracks · idle`). `F7` (ignored while a text field has the focus) flips between the upright default and the stacked chip for the session. An unchanged refresh does no layout work on the strip (F38; `test_production_strip.gd` PS14). The first time the strip shows on a machine, a one-line slab under it, right-aligned with it (stepping 8 left of the Playtest chip), reads `Your busy buildings: click one to select it, double-click to go there` in the hint style; it takes no clicks, and the first chip click or 10 s of visible time end it for good (`hints/strip_seen` in the settings file; user, 2026-11-23). A hidden strip, an online notice (which takes the top centre and would meet it at 1280), the open menu, an unfocused window, a result or the freeze card pause it instead; the chip cards also hide while a notice shows, and a chip click under the menu, a result or the freeze card does nothing. The Esc Controls list has a `Top-right production icons` row under Commands.
- **Alert feed**: (8, 48), 28 high (free again since the gate B window feedback moved the purchase preview into the strip, user 2026-11-20), amber square, `Base under attack`, key `Space`. Edge arrows 28 x 28: amber at the left edge at y = 0.4 `H`, ally at the top edge.
- **Team** chip beside Menu.
- **Pinned factory**: a click-only placeholder (user, 2026-11-16) 220 wide, 8 right of the selection panel (x 592), height hugs (154), padding 12 8: title with muted `×`, two item cells without key chips, five queue slots, and a muted `+N` when more than five are queued (described, not drawn: the drawn queue holds four). Settled in its own package.

## As built in P2.3a1

What the in-game HUD does where the pictures above are not enough (the [P2.3a1 plan](../superpowers/plans/2026-11-19-p2-3a1-see-your-selection.md), gate A answers user 2026-11-19; checks in the [verification](p2.3a1-verification.md)). The pictures stay the look; this list is the behaviour.

- **Stretch.** The match content size is 1280x720 with `expand` from 1.6:1 to 2.4:1 window aspect, 1728x720 with `keep` wider than 2.4:1 and 1280x800 with `keep` taller than 1.6:1, so a very wide or tall window gets bars instead of a stretched map. Every HUD element is anchored to the screen edges.
- **Top strip.** An 8 px swatch in the viewer's slot colour sits before `CREDITS`; the POWER group is hidden for a faction with no power kinds (FRC); low power turns the numbers `warn` and adds `LOW POWER · DEFENCES OFF`. As built (gate B window feedback, user 2026-11-20): the strip has a fixed width per faction, 704 with a power group and 352 without (FRC), credits left and power right, and while a building is placed or a build or unit button is hovered it previews that purchase itself instead of the `AFTER PURCHASE` card: a `sel` `PREVIEW` label at one x in every form, 24 after a credits slot sized for the widest five-digit form (gate C, user 2026-11-20), a 1 px `sel` border, the credits after the purchase with a muted 13 / 700 delta beside them (`3600 −1200`), and the power after it with the strip's own low-power words. Short of credits the strip keeps today's balance and shows the cost in `warn` (`500 −1200`; strip follow-ups, user 2026-11-20); a free building shows no delta, and once the match is over (with or without a result card) a hover previews nothing (gate C, user 2026-11-20). Hovering wins over an armed building and hands back to it on leaving; the strip never changes its rect between forms within a faction (`test_hud.gd` TS4, TS6). The Menu chip is top right, the Playtest chip stacks under it, online notices sit at the top centre.
- **Slab.** (Replaced by the command card in P2.3b: the build, order and unload buttons below are gone, the queue rows and the resume hint remain; see [As built in P2.3b](#as-built-in-p23b).) The old button column is one bottom-right slab, 432 wide. Build buttons show only with nothing or one own builder selected, and an unaffordable price reads in `warn`; the order buttons `Attack move (A)`, `Stop (S)` and `Unload (F)` show only with an own armed unit, and `Unload` only while a Tunnel Hub holds units or a loaded vehicle is selected. Keys print in the player's keyboard layout (QWERTY fallback). The armed button looks cyan. While attack move is armed the pointer is the system crosshair. The resume hint sits at the slab's top while exactly one own builder is selected and the pointer hovers a paused own site (`WorldView.resume_candidate`). The queue is capped: up to five rows show, more collapse to four under a `Show N more queued` button, a row cancels its entry. As built (P2.3a1 gate B fix, user 2026-11-20): the price, a queue row's `42 %` and its `×` sit on the name's centre line; the price ends 8 from the button's right edge; `42 %` and the `×` are `muted` 13 / 600, 16 apart, the `×` turning `text` on the hovered row; a hovered queue row takes `panel2` with a 1 px `muted` inset, the first row's 2 px track moving inside it (`test_hud.gd` SL7); a hovered build button takes the same inset unless it is armed (gate C, user 2026-11-20, SL9). Names start 12 from the left edge (the `HudButton` content margin); the mock-up draws 8. As built (gate B fix and window feedback, user 2026-11-20): the slab grows upward from the screen edge, so the queue block sits above the buttons as one list, top down `QUEUE`, the rows (newest on top, the entry in production lowest), then `Show N more queued` or `Show fewer` 12 above the top button row (4 between other rows); past five entries opening adds the newer rows on top. A queue change, a finished unit or the toggle never moves the menu buttons; from six entries on, they never move the toggle or the four oldest rows either (at the step between five and six entries the toggle appears under the rows and they move up one slot) (`test_hud.gd` SL8), and the chevron points up while collapsed. `Produce <unit> (E)` and the E key are gone: the menu's `1:` button and key 1 queue the same unit. `Unload (F)` takes its own row above `Attack move (A)` and `Stop (S)`, which keep the bottom row whether it shows or not. The [queue](../images/hud-v5/p2-3a1-queue.webp) and [queue-open](../images/hud-v5/p2-3a1-queue-open.webp) mock-ups draw the queue below the buttons; the game departs from them on purpose.
- **Selection panel.** Kind rows hold while the pointer is inside the panel so rows never reflow under it, but only while the selection shrinks (a death, a row click); a fresh selection released over the panel replaces them at once, and a window leave lets them go (gate C, user 2026-11-20); the hovered row insets its health track by 1 px; the footer rule `Click a kind: select only that kind · Shift-click: deselect it` shows with two or more kinds. A paused construction site reads `PAUSED · NO BUILDER` with a muted bar. A powered building with its owner short of power reads `OFFLINE · LOW POWER` in `warn`. A selected own collector names what it is doing (`TO SUPPLY DEPOT`, `LOADING`, `WAITING AT PILE`, `IDLE`, `NO SUPPLY DEPOT`, `MOVING`, `BUILDING`), the drop-off name taken from the collector owner's faction. Heights: many 98, 128 and 158 for 2, 3-4 and 5-6 kinds, pinned by `test_hud.gd` within 1 px; Task 11 measured 99, 129 and 159 (the rule line's 12 px box is 15 high, as above).
- **Refusal line.** Grounded between the selection panel and the slab, 8 above the screen bottom (gate B, user 2026-11-20), `warn`, three seconds, showing the simulation's own words until P2.3a2's table. A drain's last refusal wins; the next accepted order answered after the refusal clears it, otherwise the timer does.
- **Freeze card.** If the offline pump fails, a card in the result card's style reads `Match stopped` with `GAME ERROR`, the report (reason, build, map, tick), `Copy report` (focused; then `Report copied`) and `Back to menu`, and the footer `Version <build> · <map name>`. Orders and placement are off behind it, and Enter never restarts.
- **Playtest chip and note form.** `PLAYTEST n / m` counts ticked checklist items; the checklist and the note form drop from the chip, the form below the checklist when it fits above the slab and left of it otherwise; F3's overlay goes under the stack or left of the helper's panels.

## As built in P2.3b

What the game does after P2.3b (plan [P2.3b](../superpowers/plans/2026-11-21-p2-3b-build-from-the-dock.md), owner picks in the [War Room round](design-answers-2026-11-08.md#p23b-war-room-round-user-2026-11-21), record in the [verification](p2.3b-verification.md)). The pictures stay the look; where the tree differs from them it says so here.

- **Card and keys.** The slab's buttons are the Q W E R / A S D F / Z X C V lattice: 100 x 60 cells, wells without a pointer, rows above the top cell hidden (140 for two rows, 204 for three). One role means one key in every faction; every unmodified grid key is consumed and presses its shown cell or nothing. No title row. Esc, innermost first; a match starts with the start builder selected (no voice, camera untouched).
- **Blocked cells.** First reason in the simulation's order: `Needs <building>`, `Queue full` at 9, `<n> credits short`. A click does what the key does: nothing arms, the reason goes on the refusal line, a beep for a prerequisite or a full queue, a short disabled click and the funds voice (30 s cooldown) for credits, silence for two builders.
- **Cell card.** Opens after 250 ms of hover, switches at once between neighbours; name and `cost · time`, the reason in `warn`, then the counter line. The counter words come from a table checked against the damage numbers; rifle infantry have none.
- **Strip.** Two compact slabs with an arrow forecast, below-zero in `warn` (no coin since the P16 match, user, 2026-11-23); `LOW POWER · DEFENCES OFF` during a forecast only when the purchase flips power low.
- **Queue.** The tiles in every own producer's 152 px Core panel (153 with the rally footer), `+N more`, right-click cancel on a cell and the cells' `×N` counts, as in Elements above; progress only on the NOW tile (user, 2026-11-23) ([verification](p2.3b-verification.md#t8-queue-tiles-t8b-f38-parked)). `Cancel construction` and the resume hint stay as slab rows.
- **Outside the card.** Control groups (`Ctrl+N` or `Cmd+N` saves, `Shift+Ctrl+N` too, `N` recalls, double tap centres; the `Group 1 · 12 units` line bottom centre for 2 s), `H` and `Space`, the top-left alert line at (8, 48) for 4 s, edge scroll in a 3 px band of the visible picture (over HUD panels too, not in a stretch bar), and a Controls list beside the Esc menu's buttons. Key chips print the keyboard layout's own label (built); the defence range ring is deferred.

## Behaviour without a rectangle

- **Esc** backs out innermost first: an armed placement or attack move, then the build sub-grid, then the selection or inspection, then the game menu (user, 2026-11-16; P2.3b). A match starts with the start builder selected, so the first Esc deselects it and the Esc chip stays hidden until then.
- **Mixed selection** shows shared commands only: Attack Move shows when any selected unit can attack; a unit without a weapon just moves (user, 2026-11-16; superseded by the next sentence). The attack-move click then orders only the selection's armed units; the others keep their jobs (user, 2026-11-22).
- **No card** for a selection without commands, such as a Power Plant (user, 2026-11-16), nor for an enemy, a supply pile, a construction site or nothing (as drawn; the site keeps its `Cancel construction` row outside the grid).
- **Core against Full**: Core is words only and only what the game can feed today: top strip with credits and power, previewing a purchase itself (P2.3a1 gate B); selection panel; command card with Attack Move, Stop, Build, the build menu and production; queue; cell card with the credits shortfall, a missing prerequisite and `Queue full`, all HUD arithmetic (user, 2026-11-16), and since P2.3b the counter line instead of a forecast; refusal line; playtest chip. Full adds glyphs, minimap, ledge, production strip, income per minute, time until affordable, alert feed and edge arrows, Team, Guard, Sell and the pinned factory.

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
| pile | Supply Pile, `CREDITS LEFT 10650` (`Empty` at zero), grey edge; no card. Drawn with `BOXES LEFT 142` and `COLLECTORS 2 docked · 1 waiting`, both replaced (user, 2026-11-17, [questionnaire](design-answers-2026-11-08.md#p23a-groundwork-questionnaire-user-2026-11-17)); the pictures and the 86 px height were redrawn in P2.3a1's first task (62 px, one `CREDITS LEFT` line) | [core-pile](../images/hud-v5/core-pile.webp) | [full-pile](../images/hud-v5/full-pile.webp) |
| site | Vehicle Factory, `UNDER CONSTRUCTION`, progress `62 %`, `1,240 / 2,000`; no card | [core-site](../images/hud-v5/core-site.webp) | [full-site](../images/hud-v5/full-site.webp) |

P2.3b redrew the Core pictures from the picked looks (the queue tiles are drawn as picked, not as built) and added six, Core only: [hover on a cell](../images/hud-v5/core-hover-cell.webp), [hover on a tile](../images/hud-v5/core-hover-tile.webp), [a blocked press](../images/hud-v5/core-press.webp), [two builders](../images/hud-v5/core-builders.webp), [nothing selected, refused](../images/hud-v5/core-none-refuse.webp) and [the two-cause cell](../images/hud-v5/core-two-cause.webp). The prerequisite hint is drawn in `core-build` and `core-two-cause`, the counter under a reason in `core-factory` and `core-full`. What was drawn and what was left alone is in [notes](../images/hud-v5/notes.md#p23b-redraw-2026-11-23).

Credits, income, group sizes and queue contents are illustrative; names, costs, build times, health and power come from `game/scripts/simulation/definitions/china.gd`, and for the enemy Battle Tank from `usa.gd` (`max_hp` 480000, shown as 480).

## layout.json

[layout.json](../images/hud-v5/layout.json) is the page's own export with the picks applied:

- `meta`: the eight picks, the font, the unit (`HUD px, origin top left`), `scale` (the `k` rule above) and `source` (the page path).
- `tokens`: the colour table above; `type`: the type scale (size and weight per role).
- `screens`: 78 entries, 13 states x 2 sets (`tier`: `core`, `full`) x 3 sizes, each with `state`, `tier`, `size`, `k`, `coverage_pct` and `rects`.
- A rect has `id`, `kind` (`slab`, `cell`, `row`, `slot`, `button`, `popup`) and `x`, `y`, `w`, `h`. `covers: true` marks the opaque slabs the coverage figure sums. Card cells add `key` (bound by position), `chip` (only where the label differs: Back and Cancel show `Esc`), `text` (not for wells) and `state`: `ready`, `armed`, `empty` or `blocked` with `reason` `credits`, `prerequisite` or `queue`. P2.3b re-exported the 39 Core screens (the two-slab strip, the 152 px factory panel with tiles as picked, tile rects); the Full screens are unchanged, and the six new Core pictures below are not in the export. Queue slots carry `state` `filled` or `empty` and, when filled, `text` (the key letter in Core, the item name in Full). Kind rows carry `text` (the kind) and `count`.

Ids are stable and dotted: `top_strip`, `menu`, `team`, `playtest`, `alert`, `arrow.alert`, `arrow.ally`, `ledge`, `minimap`, `selection`, `selection.row.<n>`, `selection.queue.<n>`, `selection.sell`, `pinned`, `pinned.cell.<n>`, `pinned.queue.<n>`, `card`, `card.cell.<KEY>` (wells included), `refusal`, `cell_card`. Numbers count from 1.

How layout tests should use it (proposal, agent): give each HUD control the matching id, render a state headless at each size and compare. Assert strictly what does not depend on text shaping: which ids exist, order along an edge, containment (cells in the card, rows in the panel), no overlap between `covers` rects, the refusal line and the cell card, anchoring to the screen edges, and the cell lattice. Assert sizes and positions within a few px, because Godot will not shape Public Sans exactly as the browser did; text-hugging widths (top strip, chips, refusal line) need the widest tolerance.

## Not covered or not decided

- The grid table across factions (which item sits on which key for USA, China and FRC) is a proposal on the page for the P2.3b design; only China is drawn.
- Cards for buildings not drawn (proposal, agent; from `produces` and `builds` in `usa.gd`, `china.gd`, `frc.gd`): Headquarters `Q` its builder (Bulldozer; FRC Laborer); Supply Depot `Q` its collector (USA Supply Helicopter, China Supply Truck); FRC's Supply Cache produces the Laborer instead of a collector, so its `Q` is the builder; Barracks `Q` rifle and `W` rocket infantry in all three. FRC builds no Power Plant, so its build menu's `Q` stays empty in the page's table. The key order is not the `produces` order: China's factory lists the tank first.
- Player wording for refused orders needs a table from each simulation refusal text; `Cannot build here` is a proposal.
- Not drawn: Barracks, Headquarters, Supply Depot, a building being sold, two factories selected, buildings and units selected together, a transport with Unload, the playtest chip beside the Full set's top-right chips.
- The Full enemy panel has no glyph only because the page lacks a USA glyph.
- On a touchscreen the cell card's reasons cannot be reached; input to the Steam Deck controls spike.
