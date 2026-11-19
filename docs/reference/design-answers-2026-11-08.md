# Design answers, 2026-11-08 (user wizard)

The user answered these one by one on 2026-11-08 after research agents looked up the Zero Hour behaviour for each (sources: ZH source @ 0a05454 and the retail `INIZH.big`, cited per line; the research files stayed outside the repo in `~/projects/wargrid-overnight-work/questions/`). They are user decisions and inputs for the named milestones' planning, not designs: each milestone still gets its own design and plan. "Zero Hour default" means the user picked Zero Hour's behaviour.


## Overnight run

- Night pings: none; questions collected for the morning summary.
- Coordinator: Sonnet; plans and reviews on Opus subagents.
- Morning summary: final message plus ~/projects/wargrid-overnight-work/morning-summary.md, every commit listed.
- Spare time after both work items: more research on the next open design points, adding questions; no decisions.
- Converted maps design: open points approved as proposed (map dropdown, Credits button and panel, joiner refusal wording, --map for headless_client).
- Unattended rules: exceeded budgets on the new maps recorded and continue; bots that never attack or collect: smallest fix inside existing bot code, else finding.

## Fog of war (M7.9)

All Zero Hour defaults.

- ~~Map starts black (shroud) until explored (PartitionManager.cpp:1243).~~ Superseded (user, 2026-11-09): follow retail Zero Hour multiplayer, where the map is revealed at the start (`data\ini\multiplayer.ini:38 UseShroud = No` in root `INIZH.big`; `GameLogic.cpp:1752-1753` calls `revealMapForPlayer` when shroud is off in multiplayer). Enemy units and bases still hidden by fog until seen: from the research note `questions/next-m79-fog.md` (`PartitionManager.cpp:2972-2981`), not re-checked.
- Explored areas nobody looks at turn grey (fogged) and hide enemy units (PartitionManager.cpp:1382-1391, 1672-1675).
- Enemy buildings already seen stay shown in their last seen state while fogged; mines stay hidden (PartitionManager.cpp:1672-1677).
- A building under construction reveals nothing (Object.cpp:4842).
- Teammates share vision (ZH: PartitionManager.cpp:3965 "Look/Unlook are the ones sending Ally info").

Follow-up answers (user, 2026-11-09; questions and sources in the overnight `questions/next-m79-fog.md`, not re-checked unless noted):
- An area turns grey 5 s after the last viewer leaves (`data\ini\gamedata.ini:442 UnlookPersistDuration = 5000`).
- Vision is a plain circle; hills and cliffs do not block it (PartitionManager.cpp:3969-3990).
- Direct-fire units need a clear line over terrain and obstacles to auto-target; artillery does not (`data\ini\default\aidata.ini:31 AttackUsesLineOfSight = Yes`, AIUpdate.cpp:4612-4616, PartitionManager.cpp:4496-4566). This changes M6's "elevation affects passability only"; it lands in ground batch A with artillery.
- Explicit attack orders work on remembered buildings in the fog and on ground; only automatic targeting needs vision (WeaponSet.cpp:531-542, AIUpdate.cpp:4634-4641).
- A supply pile in the fog shows its last-seen amount (frozen picture as for fogged immobile objects, PartitionManager.cpp:1665-1684; inferred for piles).
- Firing does not reveal a fogged shooter (no such rule found; only superweapons reveal to all, Object.cpp:5005-5014).

Inputs from the OpenRA review (user, 2026-11-16, OpenRA review (private)), for the fog package's design:
- **Edge-update scheme for the fog map** (user, 2026-11-16), later: update only the cells a viewer's circle gains or loses, not the whole map each tick.
- **Ghosts of fogged buildings inside the fog package** (user, 2026-11-16), later: not a separate step.
- **Open question: the trail of a moving unit** (user, 2026-11-16): what stays shown where a unit just left; the 5 s linger above is already decided.
- **Dev commands as orders** (user, 2026-11-16), with fog: reveal-map and similar go through the command stream, not around it.
- **Bot reaction delay** (user, 2026-11-16): a bot level lever once fog exists; see the [Hypersomnia review](#hypersomnia-review-user-2026-11-16) section below.

## HUD (M7.6)

Zero Hour defaults.

- Production queue holds 9 entries per building (ProductionUpdate.cpp:109).
- Minimap flashes where an off-screen unit is attacked (Radar.cpp:1171-1185), in addition to the existing announcer line.

Follow-up answers (user, 2026-11-09; [next-m76-hud.md](../questions/next-m76-hud.md)):
- Every building can be sold (`data\ini\commandset.ini:770`), for 50 % of its cost (`gamedata.ini:390`).
- Selling takes 3 s while the building un-builds and can still be destroyed (BuildAssistant.cpp:177, 1499-1603); a "being sold" state blocks production and repair.
- Health bars show for selected or damaged objects (Wargrid today, not Zero Hour's selected or hovered).
- Veterancy chevrons show above every unit with a level, enemies included (Drawable.cpp:2807, 3797-3815; enemies inferred); bots may treat enemy veterancy as public information.
- No selection limit (`data\ini\ingameui.ini:7`).
- A Guard order: attack inside 1.8 x vision, chase to 2.2 x vision for up to 10 s, then return (`data\ini\default\aidata.ini:18-20`).
- Map pings for teammates without text (against Zero Hour's 3 text beacons per player, `multiplayer.ini:37`); one per player, a new ping replaces the old (OpenRA), lasting 30 s; plain ping only, no icon kinds (2026-11-09 HUD round).

HUD round on a click page (user, 2026-11-09 late evening; [re-check](../questions/hud-modern-recheck.md), [mock-up review](../questions/next-m76-hud.md); recommendations unless noted):
- Minimap attack flash at most once every 10 s per area (about 250 units), so an attack elsewhere still flashes (Zero Hour as written; retail's bug makes it map-wide).
- No health-bar setting: fixed "selected or damaged" (against the recommendation of an "Always" option); the unit under the mouse also shows its bar (Zero Hour, OpenRA). Under review: an art lab A/B of three rules, Zero Hour's selected or hovered, this one, and damaged or hovered ([second pass](#visual-and-ux-proposal-second-pass-user-2026-11-15), user, 2026-11-15).
- Health bars keep the green-yellow-red fill; a thin frame shows own / ally / enemy colour (compromise with look Q13).
- Teammates' attacks also show on your minimap, in a different colour (AoE IV).
- Idle builder button with a count only; no idle-army button (against the recommendation; the comma hotkey for idle army stays).
- Control-group row with unit counts, click selects (SC2, BAR).
- Production overview strip: each factory's current item and progress, click jumps there (AoE IV); no queueing from the strip.
- Keep formation: Zero Hour's opt-in Ctrl+F.
- Layout: the compact direction, one bottom dock with the minimap inside, optional panels as toggles (HUD v3 compact).
- The army panel and a pinned factory panel side by side; the factory never takes army orders.
- Production hotkeys by button position, the same grid in every building (AoE IV / BAR style). Open for M7.6 planning: with the pinned factory beside the army panel, the grid must not use Attack Move `A`, Guard `G` or Stop `S`.
- Large selections show cards per kind with count and total health; click filters, shift-click adds.
- Alert feed kept (click jumps to the event); team strip as a toggle in the compact dock; "Show performance" in the Esc menu or settings, next to F3.

HUD v4 mock-ups, round 1 on a labelled A/B page (user, 2026-11-13; picks as recommended unless noted). The clickable pages, the build spec and the survey are working files in the private notes repository (`hud-v4/`); the final pictures of all three rounds are in [HUD v4](../images/hud-v4/notes.md) ([120 units](../images/hud-v4/full-many.webp), [Core factory](../images/hud-v4/core-factory.webp)). Critique of [v2](../images/hud-v2/wargrid-hud-v2.png) and [v3](../images/hud-v3/wargrid-hud-v3-notes.md) that led here (agent assessment): one accent colour doing six jobs, an outline on every box, shrunk world sprites as unit pictures, and a v3 coverage figure that left out the decided strips.
- **Direction:** the HUD need not look like Zero Hour; parity is mostly about gameplay. It should be modern, take the best of well-regarded modern RTS games, keep Wargrid's own look, add something others lack, be beautiful and clear with good contrasts, and follow UI practice.
- **Look:** the flat look of the [fancy launcher set](#new-launcher-user-2026-11-13): matte slabs, cyan for a selected or armed control only, owner colour for whose a panel is, no gradients or glow. World selection stays white ([blueprint M7.5](../blueprint.md), look answers); cyan is for HUD controls.
- **Dock: slabs that hug their content.** Minimap, selection panel and context panel each are their own slab in a fixed place on the bottom edge; an unused place shows the world. This refines "one bottom dock" above. Measured on the round 1 mock-up at 1280x800 (superseded by the round 3 figures below): 5.6 % of the screen with nothing selected, 20.7 % with a 120-unit selection and a pinned factory; a full-width bar is 23 to 24 % in every state.
- **Status on the top edge** (against the recommendation of a ledge on the dock): credits, power and the production strip sit top left; the group row and the idle-builder button stay on a ledge above the dock.
- **HUD size: scaled with the screen,** as the game does today (a 1280x720 layout stretched to the window, world and HUD together; `game/project.godot`), so a bigger screen of the same shape shows no more map; with P2.1's stretch aspect `expand` a wider or taller one shows more at the same scale. No pixel-size mode. The mock-up's own text floor of 12 px (agent choice) becomes 18 px at 1080p.
- **Glyph plus word.** Resolves the blueprint's "command buttons with icons" against the launcher's "no icons": HUD buttons, cells and rows carry a single-colour silhouette in front of the name. A glyph is added to a worded cell and changes no size.
- **Flat buttons** (no recommendation was given)**;** the cyan outline is the only thing that marks an armed or selected control.
- **Amber means "needs you now" only:** under attack, low power, cannot afford. Money is plain text. No red warnings, because red is an owner colour. This narrows amber for the HUD only: in the launcher it stays the one start button.
- **Two sets on one layout.** Core is the early package: words only and only the panels the game can feed today (selection panel, build and production grid with position keys Q W E R T, queue of nine, credits, power, Attack Move, Stop), with no simulation change. The position keys are an input change: E produces today, and W is a camera key in the sandbox scenes only; settled in the questionnaire below. Full adds glyphs, minimap, group row, idle builder, production strip, alert feed, Guard, Sell and the pinned factory, each with its feature. Core uses the flat dark look from the start, not today's grey. Placement: [packages](../packages.md).
- **Rows per kind, not cards** (user, 2026-11-13, confirmed after round 2): a large selection lists rows of name, count and health in two columns, so names are never cut and the panel has one width with or without glyphs. Replaces "cards per kind" above; click filters and shift-click adds as before.
- **Drawing calls, confirmed in the questionnaire below:** Core queue slots show the key of the cell that made the item; Sell appears only on a selected building, never on the pinned panel; no rally button, right-click on the ground stays, with a "Right-click ground: rally point" line in the factory panel. Still an agent call: minimap dots differ by shape as well as hue.
- **Checked against published criteria** (survey with quotes in the private notes; fetched 2026-11-13): Steam Deck asks for text of at least 9 px at 1280x800 and recommends 12 px; the Xbox Accessibility Guidelines ask for 18 px on PC at 1080p; the flat dark tokens pass the WCAG contrast pairs computed on the page (4.5:1 text, 3:1 non-text), today's grey fails two. Not tested in the game.
- **Round 2, all six additions taken** (picks as recommended):
  - *Reason at a blocked cell:* a small card above the dock names the cause with its number ("150 credits short") when a build or production cell cannot be used (Stormgate, Beyond All Reason). Needs a read-only "can I, and why not" query per cell on the simulation interface.
  - *Forecast before a purchase:* the same card shows credits and power after the purchase and warns when a building would cause low power (own idea; not found in the surveyed games). HUD arithmetic on the definitions.
  - *Time until affordable:* "about 7 s at current income" on a cell blocked by credits (own idea; not found). Income arrives in truckloads, so the figure jumps and says "about".
  - *Queued count on the production cell* (Beyond All Reason). The option as drawn also named shift-click to queue five; five queue commands in one tick are a same-tick case for the plan.
  - *Income and spending per minute beside the credits* (Beyond All Reason). Its "wasting" warning is not taken: Wargrid has no storage cap.
  - *Edge arrows* at the screen edge to an off-screen attack (amber) or teammate ping (ally colour), click jumps there (Forged Alliance Forever). Comes with the alert events.
  - Left out of round 2: a box selection that skips workers (Zero-K) and a range ring while placing (Beyond All Reason).
  - *In the Core package (P2.3):* the queued count, the credits shortfall on the card (cost minus credits; other reasons need the simulation query and come later) and the forecast, all HUD arithmetic. Income, time until affordable and the edge arrows come with later packages.
  - The card is small and was missed once on the page; the questionnaire below adds the forecast to the top strip.
- **Round 3, look** (picks as recommended):
  - *Judged on the game's own colours:* sand ground and the owner colours of `game/scripts/presentation/palette.gd`, not v3's muted backdrop. The dark slabs separate more clearly on the light ground.
  - *One type scale:* three text sizes with fixed roles and tabular numbers; the top strip is 32 px high with the credits at 16 px. Both liked as drawn.
  - *Typeface Inter* (SIL Open Font License) over Barlow Semi Condensed. The game needs a font file; this is the one to add with the theme. **Superseded 2026-11-14 (user):** Public Sans is the UI font ("Font" in [New launcher](#new-launcher-user-2026-11-13)); P2.3a re-checks these pictures in it.
  - *Glyphs, third pass:* bright top faces as the dominant mass, one ground line, at most six shapes each. Mock-up drawings, not game art.
  - *Dock height: tight.* The polished dock was 16 px taller, and that was feared to take too much of the screen (user, 2026-11-13). A second flip kept the type scale and took the height back: dock 168 px in the 1280x720 layout, rows 26 px, buttons 32 px, and the queue label moved into the title row so a production panel is only as wide as its nine slots (376 px against 484). Build cells grew from 88 to 100 px so a four-digit cost clears the key chip, which costs about one point of coverage while placing (agent call, confirmed in the questionnaire below against 96 px cells with a smaller glyph).
  - Coverage with all picks, measured on the mock-up at 1280x800: Full 6.6 % with nothing selected, 20.0 % with 120 units and a pinned factory, 21.8 % while placing; Core 1.0 %, 8.1 % and 16.9 %.
  - Agent call: the mock-ups show power as used / available ("11 / 10" is low power); today's status line prints supply / demand.
  - The mock-ups use the art sheets' lighter owner blue for the panel edge and progress bars; the questionnaire below decides for the game's own colours.
- **Questionnaire after round 3** (user, 2026-11-13; all as recommended; the new decisions are not in the pictures, the confirmations in the last line but one are):
  - *Keys:* W, A, S, D are no camera keys; W and E are grid keys (A and S are already Attack Move and Stop). In a match the camera already pans with the arrow keys only (`game/scripts/skirmish_main.gd`); W, A, S, D pan only in the sandbox scenes (`game/scripts/main.gd`) and are dropped there too, so the keys mean the same everywhere. Edge scrolling and right-drag come with P3. The question as asked said W pans the camera today; that was wrong for matches (agent error), which makes the answer cost nothing there.
  - *Refused orders:* the reason shows on one amber line just above the dock for about 3 s, in Core and Full. It replaces the status line's error text.
  - *Key hints:* the status line's key hints go; every button shows its own key, the mouse rules move to a short Controls list in the Esc menu, and Unload gets a button with its U key when a transport is selected.
  - *A selected enemy unit* shows in the selection panel like an own unit, name and health, with its owner's colour on the panel edge and no command buttons.
  - *Owner colour on the HUD* (panel edge, progress bars): the colour the game draws that owner's units in, the Neon set included when it is on, lightened only where it misses 3:1 against the dock. Agent arithmetic, not measured in the game: owner 1's blue is about 3.3:1, owner 2's red about 3.2:1, the purple about 2.8:1.
  - *Forecast in the top strip too:* while a building is armed for placement, the credits and power figures themselves show the values after the purchase, with the low-power warning; the card stays for hovering.
  - Confirmed as drawn: Sell only on a selected building; no rally button, with the rally line in the factory panel; key letters in Core queue slots (against a list of names, and against bringing glyphs into Core); build cells 100 px wide.
  - Next for the HUD: a headless check whether the game's shape parts can be drawn into a UI control, because it decides what glyphs cost; evidence only. The P2.3 design follows it. Run on 2026-11-13, headless and then in one window: baked shape parts draw in a `Control` in the right order and colours, and two-tone silhouettes read at 28 px ([map art](#map-art-faction-shapes-m75-user-2026-11-13), questionnaire after round 3).
- **Edge scrolling against the dock** (user, 2026-11-13, P2.3 planning): P3's edge scrolling works in a band at every screen edge, also where a dock slab touches it, as in Zero Hour (a 3 px band at all four edges with no HUD exception, `GeneralsGameCode` @ `afc2a103f` `LookAtXlat.cpp:80,358`).

- **HUD v5 mock-ups** (user, 2026-11-16; [pictures and source](../images/hud-v5/notes.md), [layout reference](hud-v5-layout.md)). A full redraw before the P2.3a design. Reason: the StarCraft II style command card ([player-experience review](#player-experience-review-user-2026-11-16)) does not fit v4's dock (three rows of v4's 72 px cells with their title row and padding need about 260 px, agent arithmetic; the dock is 168), and v4 predates Public Sans, the picked map art, the white map marks and the [mock-up rules](../art-direction/ART_DIRECTION.md#12-interface-mock-ups). v4's look, top strip, rows per kind, amber and cyan rules stand, and its pictures stay as history. v5 is drawn under the mock-up rules: Public Sans from `game/fonts/`, pictures at 2x, the page source beside the pictures, 13 states. A last pass put it on the [theme rules](#visual-and-ux-proposal-second-pass-user-2026-11-15) (square corners, spacing only 4, 8, 12, 16, 24, 36), which v4's 2 px corners and gaps of 6, 10 and 18 predate. Eight picks on a labelled A/B page, all as recommended; where one replaces a line above it says so. The page, its backdrops and the scripts that re-make the pictures and the layout export sit beside the pictures, self-contained (user, 2026-11-16); the page's build spec, the recorded picks and the backdrop generator are working files in the private notes repository (`hud-v5/`).
  - *Commands leave the selection panel.* One command card holds a 4 x 3 lattice of cells whose key is their position (`Q W E R` / `A S D F` / `Z X C V`). This replaces v4's command row in the selection panel, its one-row context panel and the position keys `Q W E R T` of "Two sets on one layout".
  - *Cell shape: two lines, 100 x 60* (cost and key chip on the first line, the name on up to two lines below, a glyph in front of the cost later). The card is 432 wide and 204 high with three rows, 36 above the old dock line. Against one-line cells of 148 x 40 in a lower, wider card, which would have taken glyphs out of card cells and left no room for the pinned factory at 1280.
  - *The card sits in the bottom right corner,* the same place whatever is selected and whether or not the minimap exists. Against beside the selection panel, where it would move with the panel's neighbours.
  - *Panels are as tall as their content.* The selection panel hugs its lines; the card's slab runs from the top-most row in use down to the screen edge, so cells never move and only the slab's top edge does. This extends "slabs that hug their content" to height. Cost, seen and accepted: in the Full set the bottom slabs have different heights. Against fixed-size panels (one unit: about 17 % of the screen against about 10 %, reviewer's measurement on the page before the spacing pass below).
  - *The production queue sits in the factory's selection panel,* with `QUEUE 4 / 9` in the title row; the card never grows for it. Against under the cells in the card, which the player-experience reviewer preferred (cause next to effect, 44 px more card for factories).
  - *The build menu has a Back cell* on `V` with the key chip `Esc`; while a building is armed it reads `Cancel`. Against the key alone. Both `Esc` and `V` trigger it (questionnaire below).
  - *A mixed selection shows shared commands only.* Against one active kind with Tab (StarCraft II): no hidden state, and Tab is the browser's focus key. Clicking a kind row narrows the selection to it and brings its card, as before.
  - *Core starts at the left edge;* the selection panel moves once, by 176 px, when the minimap lands. Against holding the minimap's corner empty until then.
  - *A cell the player cannot use yet stays readable:* no opacity; a quieter fill (`#16212a`), name and cost muted, a cost the player cannot afford amber at full strength. v4's 45 % fade put the name at 3.7:1 and the amber cost at 2.9:1 (page arithmetic); the quiet cell is 6.4:1 and 10.5:1. Replaces the fade drawn in v4.
  - **Questionnaire after the picks** (user, 2026-11-16; as recommended):
    - *Build on `Q`,* the first cell, so `Q` then `Q` builds a Power Plant.
    - *Guard on `D` and Unload on `F`,* so the row reads Attack Move, Stop, Guard, Unload. Replaces Unload's `U` key in "Key hints" above; Guard's `G` was never a grid key.
    - *No title row in the card* (the player-experience reviewer advised the same): the cells say which card it is and the selection panel names the selection. The playtest watches whether new players find Back; a "Back · Build" label is the fallback.
    - *Esc backs out innermost first:* an armed placement, then the build menu, then the game menu. The Menu chip hides its `Esc` chip while a menu or a placement is open.
    - *The refusal line sits at the bottom centre,* centred just above the 168 dock line, where it is nearest to the pointer and meets neither the cell card nor the group row. Refines "just above the dock" in "Refused orders" above. Against above the card (the reviewer's pick) and above the selection panel.
    - *Confirmed as drawn:* a grey, not amber, edge on a supply pile's panel (amber stays "needs you now"); no card for a selection without commands, such as a Power Plant; `Queue full` on the cell card with the cells in the blocked look; Attack Move shows when any selected unit can attack, and a unit without a weapon just moves, as today; the playtest checklist as a chip top right under Menu; empty card positions as quiet wells, so the twelve positions teach the keys; the pinned factory as a 220 px click-only placeholder without keys, to be settled in its own package; without keys it no longer competes with the card, which closes the open point in the HUD round above that the grid must not use `A`, `G` or `S`.
    - *Reasons on the cell card in Core:* the credits shortfall, a missing prerequisite (from the building's one `prerequisite`) and a full queue are HUD arithmetic and come with P2.3b. This narrows "other reasons need the simulation query and come later" in round 2 above to the reasons that are left.
    - *`V` also goes back* (after the reviews): the Back cell keeps its `Esc` chip, and its position key `V` works too, so every cell is reachable by position.
    - *Sell: decided in its own package.* It is drawn as a button in the selection panel, as v4 confirmed, on every own building; whether it stays there or becomes a card cell is open until then. Until then it is the one exception to "commands leave the selection panel".
  - **Findings on the page** (agent measurements, not in the game):
    - Every unit and building name of the three factions fits a two-line cell; the widest name is 102.1 px at 12 px semi-bold.
    - None of the eight lifted owner colours needs lightening against the dock slab `#121c24`; the lowest, purple, is 3.10:1. This replaces the arithmetic in "Owner colour on the HUD" above, which used today's colours.
    - The game prints a refused order as "Rejected: " plus the simulation's own text (`game/scripts/match/match_screen.gd:157` at `2fbdd4e` and `:310`), wording written for developers ("Obstacle overlaps building or source"). The pictures' "Cannot build here" is a proposal; the P2.3a design needs a table from each simulation refusal to player wording.
    - On a touchscreen there is no hover, so the reasons on the cell card ("Needs Power Plant", the credits shortfall) cannot be reached: input to the Steam Deck controls spike.
  - Coverage with the picks, measured on the page at 1280x800 (the cell card and the refusal line are not counted): Core 1.5 % with nothing selected, 9.8 % with one unit, 13.1 % with 120 units, 15.1 % with a factory, 13.1 % while placing; Full 6.8 %, 15.5 %, 21.7 %, 21.5 % and 18.7 %. Against v4 (Core 1.0, 7.7, 8.1, 14.1, 16.9; Full 6.6, 12.6, 20.0, 19.0, 21.8): the card costs ground while an army is selected and gives some back while building.
  - Proposed, not decided (agent): the grid table across factions on the page (build menu `Q` Power Plant, `W` supply building, `E` Barracks, `R` factory, `A` defence; Barracks `Q` rifle, `W` rocket infantry; factory `Q` light vehicle, `W` tank), for the P2.3b design.
  - Checked: a script on the page over 702 screens (13 states, both sets, 1280x800, 1280x720 and 1920x1080, the picks and each single alternative) for cut text, overflow, overlaps, a key on two controls, the colour rules, square corners and the spacing scale, with no failure beyond the alternative fade's contrast; the player-experience reviewer on the pictures and the alternatives; two independent reviews of this record against the code and the export (Opus, and Codex with gpt-6-astra), whose findings are worked in (the enemy tank's health, Sell on every building, the labels, the self-contained source). Not drawn: Barracks, a building being sold, two factories selected, buildings and units selected together, a transport, the playtest note dialog. Not tested: anything in Godot, a real Steam Deck, colour-vision deficiencies, real hover and clicks.
- **Tabular numbers render in the web build** (agent check, 2026-11-16): Public Sans has `tnum`, the web build shapes with HarfBuzz, and Firefox and Safari give the same digit widths as native once a `FontVariation` turns `tnum` on; the open item from the [second pass](#package-review-second-pass-user-2026-11-13-night) is closed. Evidence: [tabular numbers web check](tabular-numbers-web-check.md).

## Unit avoidance: scope

- Re-pin every trace and pinned test once, at the end; no switch to turn avoidance off.
- Extra simulation cost on the 300-unit benchmark: about 0.5 ms per tick at most (half of today's headroom under the 1.82 ms budget).
- Experiments: the benchmark layouts (dense walls with gaps, docks) first, then Dry Wells.
- First version covers moving units only; arrival spreading keeps today's reserved destination cells.
- Revised (user, 2026-11-13): the order "movement and pathing is its own milestone before the unit avoidance milestone; avoidance is then designed on the finished movement model" becomes a core avoidance package right after core movement and advanced avoidance later, both on the new movement base, behind a toggle key ([second pass](#package-review-second-pass-user-2026-11-13-night)).

## Avoidance spike (night of 2026-11-08)

- Two approaches prototyped side by side (e.g. cell-based queue/nudge and the closest to Zero Hour's way).
- A few screenshots per approach (chokepoint, dock), linked from the morning summary.
- Cost also measured in the browser build (web bench export, tools/serve_web_bench.py).

## Bots (M8.1)

- Three selectable play styles besides "random": aggressive, economic, defensive.

## Veterancy (ground batch A)

All Zero Hour defaults, checked in the retail `gamedata.ini` and `default\object.ini`.

- Four levels: Regular, Veteran, Elite, Heroic (GameCommon.h:206-218).
- XP only from kills, per unit type (ExperienceValue / ExperienceRequired in the object INI; Object.cpp:2940-2965).
- Bonuses: damage 110/120/130 %, rate of fire 120/140/160 %, max health 120/130/150 % (gamedata.ini:333-338, 352-354); current health keeps its ratio.
- Elite and Heroic self-heal 10 HP per 1000 ms, starting 5000 ms after the last hit (default\object.ini:101-106).

## Ground batch A systems (user, 2026-11-09)

Questions and sources: [next-batch-a.md](../questions/next-batch-a.md).

- Researched upgrades stay when the building that researched them is destroyed (Zero Hour default).
- Add-ons die with their vehicle (Zero Hour default).
- Prerequisites are checked only at queueing: queued units finish after the prerequisite is lost, new orders are refused until it is rebuilt (Zero Hour default).
- A shell flies to where its target stood when it was fired; a fast unit can dodge (Zero Hour default).
- Tank shells hit structures and walls on the way (Zero Hour default).
- Tank shells scatter against infantry by Zero Hour's per-weapon radius (Crusader 10 units), using the simulation's seeded random (Zero Hour default).
- A unit ordered to attack inside its minimum range backs away until the target is past it, then fires (Zero Hour default).
- Poison and radiation fields hurt everything on the ground, own and allied units included, not aircraft (Zero Hour default).
- A small poison field lives a fixed 10 s; a new field cleans its spot first, so fields never stack (Zero Hour default; replaces the blueprint's "duration after the last hit").
- Hazard damage follows Zero Hour's armour table: tanks 25 % poison and 50 % radiation, trucks 50 % poison, buildings 1 % poison and 0 % radiation, Hazmat troops immune (Zero Hour default).
- The FRC Palace's garrison cannot be cleared by flame or toxin clear-building weapons (Zero Hour default).
- USA buildings self-heal 0.3 % of max health per second after 3 s without damage, not while under construction or being sold; other factions' buildings do not (Zero Hour default; capability data, not a faction branch).
- FRC rebuild holes (raised by the user): most FRC buildings leave a hole when destroyed (Zero Hour GLA: 500 HP, heals 0.5 % per second, `HoleMaxHealth` / `HoleHealthRegen%PerSecond` in retail `data\ini\object\factionbuilding.ini:143-144`, 11 `RebuildHoleExposeDie` buildings); after 20 s (`WorkerRespawnDelay`) a worker spawns and rebuilds the building unless the hole is destroyed; a killed worker or rebuild restarts the wait (`RebuildHoleBehavior.cpp:200-335`). Lands in batch A gate A4 (FRC), Zero Hour behaviour. The rebuild is free: money is withdrawn only when `isRebuild` is false (WorkerAIUpdate.cpp:408-416; checked 2026-11-09).

## Minimap (M7.6)

- Free with the Command Center for all three factions for now (Zero Hour differs per faction: USA free, China $500 upgrade, GLA $500 radar van; revisit when those items exist).
- Goes blank at low power until power returns, with an "offline" voice line (ZH Player.cpp:3260-3272).
- Goes blank when the last radar provider is lost or captured; a second provider keeps it (ZH RadarUpgrade.cpp:72-120, Player.cpp:3160-3200).

## Bots (M8)

- Start from Zero Hour's behaviour (enemy choice AISkirmishPlayer.cpp:485-563, target scores AI.cpp:683-720, wave timing), then develop Wargrid's own, better rules: bot intelligence should be unique and really good at this game; moving far from Zero Hour parity is fine for bots. Sources the user collected: docs/reference/fair-bots-research.md.
- A losing bot never gives up; it rebuilds lost base buildings (ZH RebuildDelayTimeSeconds = 30).

## Unit avoidance: behaviour

Zero Hour defaults unless noted. Paths are under `GeneralsMD/Code/GameEngine/` (AIPathfind/AIUpdate/AIStates/AIGroup in `Source/GameLogic/AI/` or `Source/GameLogic/Object/Update/`).

- A standing friend on the route steps aside; busy units (shooting, building, using an ability) do not (AIPathfind.cpp:6306-6316, 10112-10187, 10166-10178).
- Head-on deadlock: the unit with lower right of way sidesteps a cell or two, then both continue (AIUpdate.cpp:1521-1535, AIPathfind.cpp:10195-10360).
- Right of way: dozers/builders over everyone, vehicles over infantry, then the unit in front, then a fixed tie-break (AIUpdate.cpp:1215-1253).
- Infantry pass through all infantry; only vehicles block them (AIPathfind.h:51, AIUpdate.cpp:1332-1338). Refines the 2026-11-07 "units go around each other": vehicles stay solid.
- Last resort: two vehicles still blocking each other pass through after about 5 s (ZH: crossing/opposite units after 1 s, AIUpdate.cpp:1355-1362; user chose 5 s so units mostly go around).
- Supply trucks on a supply run drive through all units, others yield to them, as Zero Hour (AIStates.cpp:6170, AIUpdate.cpp:1445). Supersedes "trucks included" of 2026-11-07.
- Tanks, trucks and dozers crush ordinary enemy infantry they drive over (not heroes, never allies), so those soldiers never block vehicles (SquishCollide.cpp:97-131; crusher levels in retail INI).
- Re-route: at once if the blocker stands still, otherwise after 2 s blocked (AIUpdate.cpp:1511-1519, AIStates.cpp:1821).
- Standing units are walls to enemies; enemies are never asked to step aside (AIPathfind.cpp:6265-6270, 10156).
- A unit that is shooting holds its spot; the friend goes around (AIPathfind.cpp:10166-10171).
- Factory exit: friends at the door step aside, but the new unit stays solid (ZH instead lets it drive through for up to 10 s, AIUpdate.cpp:1698-1708).
- Long group moves travel as a column on one shared route, infantry 3 wide and vehicles 2 wide, each unit at its own speed (AIGroup.cpp:528-638).
- A unit that stepped aside stays there; it does not walk back (inferred from AIStateMachine.h:185-186).
- A fast unit behind a slower friend slows and follows, then tries a way past after about 2 s (AIUpdate.cpp:1258-1292, AIStates.cpp:1821).
- "Keep formation" command (ZH Ctrl+F): later, with the M7.6 HUD, not in the avoidance milestone.
- Aircraft do not take part in avoidance; ground units only.

Follow-up after the avoidance spike (user, 2026-11-09 evening; open questions from the spike note on `spike-avoidance`, `docs/reference/unit-avoidance-spike.md`):
- A unit within one cell of its destination ignores blockers and squeezes in; overlaps there are spread out afterwards (Zero Hour default, AIUpdate.cpp:1303-1311).
- Each unit keeps its own reserved destination cell (today's rule) together with the squeeze-in rule; if packed moves still cannot finish within the cost cap, OpenRA-style "stop near enough when close and blocked" is the allowed fallback (user asked for its trade-offs first: cheaper, no fight for the last cells, but irregular end positions and a tail that can stop short).
- The +0.5 ms cost cap applies to every 300-unit row, the all-infantry horde row included.
  - That means all six rows (docks included; "five" was a slip, user, 2026-11-10): HEADLESS movement open and dense, docks, COMBAT open and dense (150 v 150), and COMBAT hordes300.
  - A miss on COMBAT open or dense counts as a movement-row miss for the near-enough fallback below (user, 2026-11-09).
- The next spike round builds on approach A (Zero Hour-style yielding) and borrows B's "claim the next cell" only where A's retry cost shows up (a hypothesis to test).
- The about-5-s last resort counts "no progress towards the goal", not consecutive blocked ticks, so circling units are caught.
- A move order is never given up because the unit is stuck; it fails only when no path exists (Zero Hour default, AIStates.cpp:1880-1895).
- Speed matching (a fast unit follows a slower friend) is part of the first version, not a follow-up; it is expected to cut A's per-tick retries as well (inferred, not measured).
- Narrow passages are tested twice: a synthetic benchmark layout with a 2-3 cell gap, and the narrowest real passage found on the three converted maps (the spike's Dry Wells "choke" was a 20-cell lane).
- The next round adds a mixed-owner scenario (tanks driving through an enemy infantry blob) so crushing and its cost are measured.
- Per-unit avoidance state goes into the snapshot and state hash already in the next spike round, so its measured cost is honest.
- Existing tests that fail because behaviour changed (G3, P3, S8, BM6 in round 1) are listed with what changed and a proposed rewrite; the user decides per test before the avoidance milestone. The spike does not change them.
- Screenshots colour units by moving group, so crossings and who yielded are visible.
- The overnight run of spike round 2 may open short-lived game windows for screenshots (no sound, closed by the run); this pre-approval covers that run only.
- Round 2 continues on branch `spike-avoidance` (worktree `../wargrid-wt-avoid`), rebased onto current `main` first.
- If round 2 still misses the cap: record the exceeded rows and what costs most, never loosen. If the miss is on the movement rows, also measure the near-enough fallback as a separate variant next to the main one and report both; if only the horde row misses, report only (near-enough does not reduce bookkeeping cost). The user decides the next step (revised from "report only" after the user asked why not; 2026-11-09).
- Round 2 is measured natively and in the browser (Firefox web bench, as round 1).
- Steam Deck measurement by the user after round 2, only if round 2 passes the cap on the Mac.

After round 2 (no variant met the cap; user, 2026-11-10):
- Round 3 is a cost experiment on R1, no rule changes: trim the cheap path, merge the per-class grid fills, skip the grid for all-infantry, re-measure against r0 in the same interleave. Hard stop after one round: if it does not close the gap, the next step is a design brainstorm for a different structure (for example grids only near vehicles), not another experiment.
- Round 3 verdict (user, 2026-11-10, round 2 open question 2): a row passes only if its median-of-3 delta p95 against r0 is at most +0.500 ms; the spread is reported, there is no noise allowance.
- Round 3 also changes the movement benchmark legs so packed moves can finish (round 2 open question 8; user, 2026-11-10). Risk raised before the answer: spreading destinations makes `run_benchmark.sh` pass while the in-game "select 300, click one spot" jam remains. So the new legs apply identically to r0 and the variant, the old packed one-anchor move stays in the jam harness as a reported jam row, r0 is measured on old and new legs so the budget shift is visible, and only on the spike branch (main's benchmark is unchanged).
- Round 3 measures the browser (Firefox Web Bench, a dedicated profile, never the user's own Firefox) only if the native cap passes; otherwise it is skipped and said so (user, 2026-11-10, round 2 open question 13).

After round 3 (brainstorm; user, 2026-11-10; round 3 missed the cap on one row and packed moves still jam):
- The user asked what Zero Hour, OpenRA and Recoil do when there is no room. Two independent source readings (main session and a subagent; notes outside the repo in `~/projects/wargrid-overnight-work/avoidance/brainstorm/`) agree: all three have a fallback and none relies on hard blocking alone; Zero Hour lays goals out so units rarely have to pass a standing one (`AIGroup.cpp:480-514`, `:990-1012`, `:1696-1700`), while Wargrid hands goal cells out by unit id (`destination_allocation.gd`).
- Next is a spike, not a milestone (user): first Zero Hour's goal layout, then a no-room fallback (goal swap with a standing friend), then a small slice of column moves to get a feeling for them. Draft plan: [avoidance round 4](../superpowers/plans/2026-11-10-avoidance-round4-spike.md); not approved yet, and open to change from the subagent's findings (user).
- (Not built: round 4 was narrowed to `s1` and `s3`, user 2026-11-10.) Added from the subagent's reading, as a measured variant only: crossing movers pass through each other after 1 s, Zero Hour's rule (`AIUpdate.cpp:1355-1362`). It contradicts the "about 5 s" answer above for that case; **not decided**, the user rules after the results.
- Column moves make a group long and thin, so the front arrives well before the tail (Zero Hour has the same trait); the user judges that by seeing it.
- Friend's playtest (competitive RTS experience, reported by the user 2026-11-10, in substance): the pathfinding grid looks as coarse as the building grid, and units "move strangely, probably because there is no 360° movement". Checked: routes use four directions on the same cell grid that buildings block (`grid_navigation.gd:19-24` at `2f3bb01`), one cell is 25 Zero Hour world units; Zero Hour paths on 10-unit cells and smooths the path (`AIPathfind.h:439`, `AIPathfind.cpp:474`). Movement in any direction is an **open design question**, to be asked before the avoidance milestone because the blocking rules depend on it; round 4 only shows an eight-direction probe.
- **Decided (user, 2026-11-10):** units path on a finer grid than buildings and drive at any angle, as Zero Hour does, "unless there is very good reason not to". Wargrid may use its own method, closer to what modern RTS games do, as long as it feels similar. Design not done yet: grid size, path smoothing method, cost on the browser target. The movement brainstorm must also investigate a navmesh and flow fields (user, 2026-11-10), not only a finer grid with smoothing.

## Movement and pathing (user, 2026-11-10)

Questions and research: [movement and pathing brief](../questions/movement-pathing-brief.md). The decisions that started it (finer grid, any angle, own method allowed, navmesh and flow fields investigated) are under "After round 3" above.

- Priority (user, 2026-11-10): for movement and pathing, units not getting stuck and good performance matter more than exact Zero Hour parity. The method choice and any later trade-off are judged on these two first.
- Base method: measured first (finer grid with smoothing, hand-written navmesh, flow fields; pathing timing spike note `docs/reference/pathing-timing-spike.md` on branch `spike-pathing`, commit `70026c5`), then **chosen provisionally (user, 2026-11-10, questionnaire after the art lab; the user was unsure on some items: the movement milestone shows in-game A vs B examples, like the avoidance round 4 feel session and the art lab, before any item is locked)**:
  1. **Rectangle navmesh (B)** as the base method, with the same straightening; the finer grid (A) stays as the reference that B's paths are checked against. The milestone's first task is a moving-units prototype that checks stuck behaviour; if B fails it, fall back to A.
  2. Big group orders: **individual routes first**; shared trunks or flow fields later, only if measured jams or cost need them.
  3. Path budget: **keep 8 route requests per tick** (`simulation.gd:18` at `fdf3e49`) and measure; a Zero Hour style searched-cell cap (`AIPathfind.cpp:1103`) only if measurement shows spikes.
     Superseded: path searches are budgeted by route cells, `PATH_CELLS_PER_TICK = 384` in `56cfcb2` (2026-11-14).
  4. **Three size classes: infantry, vehicle, large**, one mesh per class.
  5. Building placement: **local update** (re-widen and rebuild only the tiles around the building) in the milestone, measured.
  6. Straightening: **body-safe line test** (the unit's full width along the line), because a centre-line test can clip a corner by about half a cell (spike part 7).
  7. **Own navmesh code is acceptable** (rectangle building and incremental updates; the search stays Godot's `AStar2D`).
  8. Determinism: **cross-platform path test early** (fixed scenarios compared across macOS, Linux and Windows CI, like the trace comparison); if paths differ, switch to integer costs in an own search.
  Feel goal (user, 2026-11-10): movement does not have to play exactly like Zero Hour, but like a polished modern RTS. So responsiveness wins over Zero Hour's wave start where they conflict, for example a large order should get every unit moving within a tick or two (today 8 routes per tick means about 1.3 s until the last of 300 units starts).
  Movement lab, the milestone's first task (in the art lab style: `[` `]` question, `Tab` variant, click page), in this order of gameplay impact: (1) route budget per tick (8 vs 32 vs all at once, watching the response to the click and the cost); (2) body-safe vs centre-line straightening (corner hugging, scraping, getting stuck); (3) individual routes vs shared trunk for big orders (broad stream vs column); (4) navmesh vs finer grid path shape. No A/B for the local building update (same paths when correct: proved by a test) or cross-platform determinism (a test).
- Grid size: 2x2 pathing cells per building cell (12.5 Zero Hour units; Zero Hour uses 10, `AIPathfind.h:439`). Ashfall becomes 388x374 cells, so the map cap of 256 per side (`grid_navigation.gd:15` at `2f3bb01`) must rise.
- Turning needs no new decision: units already turn at a per-kind rate, wheeled vehicles only while rolling (`locomotion.gd`), as Zero Hour (retail `locomotor.ini`: `TurnRate`, `MinTurnSpeed`).
- Unit size: **revised (user, 2026-11-10)** to a few size classes, Recoil-style (2 or 3, for example infantry, vehicle, large vehicle; each kind assigned one; one pathing layer per class), after the priority above; soldiers still fit where tanks do not. Superseded: "per unit kind, as Zero Hour" (its width gives 1 to 5 pathing cells across, `AIPathfind.cpp` `getRadiusAndCenter`), chosen earlier the same day. Other games: OpenRA uses whole cells for vehicles and five shared slots for infantry (`mods/ra/rules/world.yaml:15`, `MapGrid.cs:118-124`); Recoil one pathing layer per size class (`QTPFS/PathManager.cpp:397-400`).
- Order: movement and pathing is its own milestone before the unit avoidance milestone; avoidance is then designed on the finished movement model (two trace re-pins accepted).
  - Revised (user, 2026-11-13): movement and avoidance ship as core slices soon and advanced slices later, both on the new movement base ([second pass](#package-review-second-pass-user-2026-11-13-night)).
- The timing spike for the three methods runs right after avoidance round 4, before the art lab: scratch scripts, no simulation change, every row labelled as a GDScript cost to be re-read after the native simulation core spike (a native core could make navmesh or flow fields cheap).
- Feel: units keep Zero Hour's weight (per-kind turn rates, rolling turns for wheels, acceleration and braking); not made snappier.
- Permafrost Engine (`~/projects/permafrost-engine` @ `083a99c`, GPLv3 or later; evaluated read-only 2026-11-10, report `~/projects/wargrid-overnight-work/engines/permafrost-engine.md`): read as a reference only, not used as code, engine or core (C and Python 2.7, x86_64 Linux and Windows only, no WebAssembly, no lockstep, float and threaded movement). **Into the movement or avoidance milestone design (user, 2026-11-10):** moving units never lock grid cells; only stopped units mark cells blocked, with a reference count (`src/navigation/nav_data.h:132-137`); moving units steer around each other with velocity-based avoidance, ClearPath/HRVO (`src/game/clearpath.c:36-41`); waiting units wake when a counter bumps as a cell frees up (`nav_data.h:138-142`). Determinism of the steering maths (square roots, vector maths, no trigonometry) is a design point.
- **Deferred (user, 2026-11-10):** if the native simulation core spike decides on Rust or C++, evaluate Permafrost's chunk flow fields (A* over chunk portals, per-chunk fields cached by chunk, target and layer, a line-of-sight field for straight driving; `src/navigation/a_star.h:128`, `field.c:2186`, `fieldcache.c:61-65`, `field.h:206-214`) against the chosen method; in GDScript one chunk field is estimated at about 55 ms in the browser (inferred).
- Left open on purpose: shared group routes or flow fields for big orders (waits for the round 4 column feel session and the timing spike). Proposed, not decided (technical, measured in the spike): budget path work in searched cells per tick as Zero Hour does (5,000 per frame, `AIPathfind.cpp:1103`) instead of 8 routes per tick; raise the map cap to 512 cells per side.

## Friend's playtest (reported by the user, 2026-11-08)

Reported points, verbatim in substance: units in a building's footprint should move away when it is placed (as the friend remembers Zero Hour); queue buildings with Shift, and which Zero Hour keys to support; a USA bot on Dry Wells built only one Chinook and put its supply depot far from the boxes; defences such as the missile tower can be built anywhere (the friend thinks Zero Hour restricts this, maybe per faction); no way out after "Create match"; do dozers and workers auto-repair structures; the match code should be copy/pastable; can the camera move without arrow keys.

- Launcher, tonight in the converted-maps task (user, 2026-11-08): a Cancel button while waiting for player 2 closes the connection and returns to the launcher; a Copy button next to the shown match code puts it on the clipboard (browser clipboard unverified until tested).
- Bot economy, tonight in the converted-maps task (user, 2026-11-08): collectors per supply center, counting the depot's free one, same at every difficulty: USA 2, China 3, FRC 5 (down from 7), as human players do (Zero Hour's skirmish AI uses 2 + 1 for America and China, aidata.ini ResourceGatherers, AIPlayer.cpp:190-215); per-collector inflow already differs by data (USA helicopter 8 boxes but slow unload, China truck 4 boxes at speed 1.6, FRC laborer 1 box at speed 1.0). Revisit in M8: stronger levels should make increasingly optimal economic decisions. Pins moved by this change may be re-pinned overnight, with old and new values recorded, in their own commit. The depot target ignores small piles and aims at the nearest full dock. The bot's supply-center slot is chosen by the map converter as the open spot nearest the supplies, up to 12 cells from the start (today 16-27 cells from supplies on all three maps). The proper fix comes with M8: the bot chooses its depot site near supplies itself (Zero Hour buildBySupplies/findSupplyCenter); recorded in the blueprint's M8 entry so it is not forgotten.
- Building placement (user, 2026-11-08; Zero Hour behaviour checked in BuildAssistant.cpp:908-1067, which has no distance or ownership check): your own units standing on a placed building's footprint move to the nearest free cell (Zero Hour: friendly units "politely move out of the way", BuildAssistant.cpp:942-943, but it also moves teammates' units and picks a random spot); teammates' units are not moved; an enemy unit on the footprint refuses placement and is highlighted (BuildAssistant.cpp:758-767). No build radius and no defence- or faction-specific placement rule, as Zero Hour: a builder that reaches and sees a spot in the enemy base can build a tower there. Once fog exists (M7.9), placement needs currently visible ground (BuildAssistant.cpp:922-940). A refused placement shows the red ghost, a text reason and the blocking object highlighted (InGameUI.cpp:1478-1500, 4020-4060). Milestone: the move-away belongs with unit avoidance (it reuses step-aside); the visibility rule with M7.9; the blocker highlight with M7.6.

## Controls (friend's playtest; user, 2026-11-08)

Zero Hour's key map is in the retail `EnglishZH.big` `data\english\commandmap.ini` (the `INIZH.big` copy is an empty header). Findings: Shift never queues in Zero Hour (it adds to the selection); waypoints are queued by holding Alt and right-clicking; dozers cannot queue buildings (a new order replaces the old one and the half-built site stays, DozerAIUpdate.cpp:1982-1996).

- Mouse stays StarCraft style (left selects, right orders), with no option to switch to Zero Hour's default left-click orders. A short right-click orders, a right-drag pans the camera, as Zero Hour's "Alternate Mouse Setup" (LookAtXlat.cpp:221-233 starts the scroll regardless of the mouse mode).
- Edge scrolling, also in a window and the browser (Zero Hour: 3 px band, fullscreen only, LookAtXlat.cpp:69, 301).
- Space jumps to the last alert (CommandXlat.cpp:2867-2884); H centres on the Command Center (CommandXlat.cpp:2861).
- Builders queue several buildings with Shift+place; plain placement still replaces (a Wargrid addition: Zero Hour has no building queue).
- Units queue move points with Shift + right-click (Zero Hour: hold Alt).
- Number keys become control groups as in Zero Hour (Ctrl+0-9 make, 0-9 select, Shift adds, Alt centres). With the HUD, building and production are mainly done with the mouse, plus Zero Hour's per-button letter hotkeys, shown on the buttons (the letters come from the localized `generals.csf` `&` markers, not decoded yet).
- No Q (select all) or E (select same type) hotkeys; double-click keeps selecting a type.
- Ctrl + right-click forces an attack, as Zero Hour (retail commandmap BEGIN_FORCEATTACK = Ctrl).
- Period (.) jumps to and selects the next idle builder, as Age of Empires II DE ("Pressing the '.' Key will move you to and select an idle Villager", ageofempires.com Match Goals & Hotkeys, read 2026-11-08; StarCraft II uses F1, Blizzard game guide); comma (,) does the same for idle army units (community guides; not on the official page).
- Camera spots on F1-F8 (Zero Hour SAVE_VIEW/VIEW_VIEW): later. No middle-click zoom reset; the wheel keeps Wargrid's fixed zoom levels.

## Repair (friend's playtest; user, 2026-11-08)

Wargrid has no repair today (`rg -i repair game/scripts`: nothing). All Zero Hour behaviour, retail values identical for the USA dozer, China dozer and GLA worker:

- Idle builders repair damaged own buildings by themselves: after 5 s idle, the nearest damaged own building within 150 Zero Hour units, about 6 Wargrid cells (DozerAIUpdate.cpp:1111-1128; BoredTime 5000, BoredRange 150). Not enemy buildings, full-health ones or ones under construction (ActionManager.cpp:383-433).
- A builder can also be ordered to repair: right-click a damaged own building.
- Rate 2 % of max health per second per builder, free, several builders add up (RepairHealthPercentPerSecond 2 %; DozerAIUpdate.cpp:719, 725-727).
- Bot builders use the same scan range as humans (Zero Hour doubles it for bots, aidata.ini AIDozerBoredRadiusModifier 2.0; not copied, fair bots).
- Pins moved by the depot-slot change (Ashfall team match digest, core series, peak units) may also be re-pinned overnight, recorded with old and new values, in their own commit (user, 2026-11-08).

## Simulation core and state digest (user, 2026-11-09 late evening)

Questions from [sim core options](sim-core-options.md) (Q1-Q15) and [state digest research](state-digest-research.md) (Q1-Q8). Own engine is out of scope unless done for fun; C++ in Godot is acceptable; Rust in Godot is the leaning; the browser stays the primary target, a reduced browser mode is only a measured fallback (user).

- Write down the simulation's public interface (commands in, snapshot and events out) as a short note now.
- New tests check the game only through that interface; the 19 existing test files that read internals are not migrated now.
- Replace Godot's `Dictionary.hash()` in the online desync digest with our own hash over every field (one re-pin).
- The hash walks every field automatically with sorted keys (not Zero Hour's hand-written per-class list).
- Hash function: 64-bit FNV-1a with a fold, 16 hex characters on the wire (relay unchanged).
- If the full hash is too slow on a hash tick, spread one hash over the next 30 ticks (desync detected about 1 s later), not Zero Hour's every-100-ticks.
- 0.0 and -0.0 hash the same (as Godot today), so a Python checker can verify the JSON desync dump.
- The new hash ships together with the golden test scenarios: one re-pin.
- A new game version keeps old and new clients apart (the relay already refuses a build mismatch); no protocol bump.
- The CI replay traces switch to the same digest (today a Godot-only SHA-256 over `var_to_bytes`, `test_replay.gd:56` at `2b9fdb6`).
- The simulation performance spike starts with a one-day check that a tiny Rust extension (godot-rust) runs in Firefox on the Steam Deck.
- If native code wins: Rust, with C++ only if Rust fails in the browser.
- Pass line: Rust must show at least 5x after the data hand-off cost. **Superseded 2026-11-10** by the ratio rule in "Native simulation core spike" below (the user called the 5 arbitrary on 2026-11-09).
- If native wins, production also sends the cross-origin isolation headers (needed for any extension in the browser; refines the earlier "test app only").
- Whole simulation port or hot loops first: decided after the spike (the data hand-off cost decides).
- During any port the GDScript simulation stays the reference until the golden scenarios match (the rollback).
- Fixed-point (integer) simulation maths, like OpenRA's 1024 units per cell (`OpenRA.Game/WDist.cs:22`): not now; floats with written determinism rules and a CI check, and switch to integers as part of a Rust port if one happens (one re-pin). User asked for the upsides first (determinism by construction, cross-language for free, simpler hashing).
- Browser fallback trigger (if the browser proves too slow): either skirmish simulation p95 over 10 ms in Firefox on the Steam Deck after the spike's fixes, or frame p95 over 16.7 ms at Low.
- In that fallback the browser defaults to Low graphics; High stays available with a warning (graphics are per player).
- In that fallback the host can pick a lower unit cap per match (a simulation switch, identical for all players).
- No reduced update rate for far-away or idle units until measured (it changes fights).
- Per-match switches travel with the host's match settings in the start message; only the code fingerprint (R1.1) gates rooms.
- Golden scenarios get a horde-style case only when a horde mode is planned.

## Native simulation core spike (user, 2026-11-10 evening)

Interview before the overnight run of the handoff (`native-sim-spike-prompt.txt`, private); evidence in [its verification file](native-sim-spike-verification.md).

- Verdict by the ratio rule (language gain K, hand-off H, effective gain E, template tax T against the need Q), not by "5x"; the old quantity is still reported as E.
- Headroom factor 1.5: the projected gain must reach Q x 1.5 (today 1.45 x 1.5 = 2.18).
- The Rust core is engine-independent as a requirement: it builds and passes its tests with no Godot installed.
- Slices: the horde step and the movement of moving units, ported in parallel (movement is rewritten by the next milestone, which does not matter for ratios).
- Added probe: what it costs to hand 400 unit records from Rust to Godot as today's Dictionary-shaped snapshot against packed number arrays.
- Template tax measured on the simulation benchmark and on the rendered web benchmark.
- Emscripten 3.1.74 is the main version (documented by godot-rust); 4.0.20, the engine's own, gets a comparison row.
- Linux x86-64 binaries are built in a container on the Mac; nothing is installed on the Deck beyond one folder.
- The user sets up the Deck (Desktop Mode, mains power, no sleep) before starting; without it the run continues on the Mac and the outcome is at most CONDITIONAL GO.
- If the Deck does not work during the night: "run the stuff on the mac and follow your best judgement" (late evening, after the Deck preflight passed: Desktop Mode, mains, no screen-off, no lock, "when inactive: do nothing").
- Overnight a stop condition takes its written default and the run continues; only push, deploy and loosening a budget or pin are never defaulted.
- Local commits on `spike-native-sim` are pre-authorized; no push, PR or merge.
- Models: Sonnet coordinator; Opus 5.5 and Sonnet 5.5 subagents by difficulty (the plan names one per task).
- If the run is not finished in the morning it keeps going; the user checks in.
- One phone notification, when the report is done or nothing can continue.
- Browser windows on the Mac and on the Deck are allowed during this run (user: "fine to spawn windows, play sounds, run benchmarks, launch browsers").
- Coordinator calls (not the user's, change if wanted): Vivaldi is the Chromium browser on the Mac; no C++ fallback is built at night (a morning decision if Rust fails in a browser); parallel code tasks get their own task worktree and branch, and their commits reach `spike-native-sim` by `git cherry-pick`, because `git merge` asks for approval and a night session denies what asks.


## Turret aiming (user, 2026-11-10; [impact note](turret-aiming.md))

- A tank's turret must point at its target before it fires: it turns at its rate and fires once aligned (Zero Hour default, TurretAI.cpp:1169-1199). Replaces "firing ignores heading" (blueprint M6).
- It lands in ground batch A, together with travelling shells and minimum range, so one re-pin covers all of them. Until then turrets are drawing only (the art lab uses that stand-in).
- Soldiers (no turret) turn their whole body to within about 2 degrees of the target before firing, at their turn rate (Zero Hour default, AIStates.cpp:5051-5072; at most about 0.36 s).
- Each turreted kind keeps its own Zero Hour turret rate (Crusader 180, BattleMaster 120, Scorpion 100, Technical 240 deg/s; table in the impact note). China/FRC kind mappings are inferred from display names: re-check with `tools/zh_ini.py` at batch A planning.
- After losing its target a turret holds for `RecenterTime` (2 s; Humvee and Scorpion 5 s), then turns back to face forward (Zero Hour default, TurretAI.cpp:200, :1439).
- Turreted units fire while driving at whatever is in range once their turret is aligned; units without a turret still stop to fire (Zero Hour: the turret's idle state picks targets on its own timer, TurretAI.cpp:879-900, :1306-1327; `getNextMoodTarget` has no movement check, AIUpdate.cpp:4495; source reading, not every guard traced). Check each unit's `AutoAcquireEnemiesWhenIdle` with `tools/zh_ini.py` at batch A planning.

## Performance next (user, 2026-11-11)

Asked one at a time after the native sim spike; analysis and experiments in [performance next](performance-next.md).

- **Goal row:** a 210-unit 3v3 must run smoothly in Firefox on the Steam Deck. 400 units fighting at once (hordes300) stays a reported stress row, not the goal. Budgets, F and gates in the [ledger](performance.md) are unchanged by this answer.
- **Motive:** no performance problem is felt in play. All playtesters have gaming PCs; no low-end tester exists yet. The work is driven by the ledger, a possible horde mode later, and fixing architectural base issues now so later work is easier.
- **Horde mode size:** 1,000 enemies "for now". Not thought through; a spike comes first so the user can see whether the mode makes sense. The horde spike is approved (benchmark, then a playable throwaway scene).
- **Threads:** a threaded browser build may send the cross-origin isolation headers in production if the experiment shows a clear win (replaces "test app only" for that case). The user still wants threads together with Godot's "Separate" render thread measured (asked 2026-11-09 as perf question Q11, never run).
- **Tick rate:** split rates. Movement and firing stay at 30 per second; unit decisions may run less often, staggered across units. Asked first how modern RTS games do it (StarCraft II 22.4, OpenRA 25, Recoil and Zero Hour 30, Permafrost movement 20 and combat 10; sources in the note).
- **Order:** experiments first (speed-built web template, simulation on a thread, packed-array horde spike), then decide the data layout, before the movement and pathing milestone starts.
- **Budgets:** may be re-derived from a new structure (simulation on its own thread or frame) as an explicit proposal with measurements and a ledger row for the user's approval; nothing is loosened silently.
- **Measuring host:** the Mac mini; the Steam Deck gets a break. Windows and non-headless runs on the Mac mini were approved for 2026-11-11 while the user was away.
- **Working style (user):** other engines' sources (OpenRA, Recoil, Permafrost) are one input, not the only one: "we have looked at the other engines before and not fixed our own engine so far".

## After performance next (user, 2026-11-11 evening)

- Interpolation rework (presentation only, folds in T4b, changes WB18's golden batch by design, needs a rendered A/B): before the movement milestone.
- Packed-array storage for per-unit simulation state: inside the movement milestone, not as its own refactor task; after the golden scenarios plan.
- Test app: final tree, single-threaded (deployed 2026-11-11 as fly release v11 of wargrid-web-test); the threaded build with isolation headers stays in `~/projects/wargrid-perf-work/threaded-deploy/`.
- Next run to start: the golden scenarios plan ([plan](../superpowers/plans/2026-11-09-state-digest-golden-scenarios.md)).
- Worker thread for the simulation: the user wants to pursue it ("unless you tell me it is not worth it"); design in [worker thread design](../superpowers/specs/2026-11-12-worker-thread-design.md), stage 1 (single-threaded `SimPump` boundary) first, the thread itself after a browser measurement.
- Order of the next work (user agreed, 2026-11-11): 1 golden scenarios, 2 interpolation rework, 3 worker thread stage 1 (`SimPump` boundary), 4 the worker thread itself only if a browser measurement shows a main-thread win. Each is started by the user explicitly.

## Worker-thread experiment preparation (user, 2026-11-14)

- First deliverable: a scratch experiment with measurements, not a production `SimPump` implementation. Architecture reference: [worker thread design](../superpowers/specs/2026-11-12-worker-thread-design.md).
- Base: One controller after integration, not its unmerged branch.
- Overnight scope: headless checks. Rendered browser measurements remain an attended follow-up; headless results alone do not establish the design's browser performance go/no-go.
- These choices define preparation scope; implementation still requires an explicit start.
- Second round (user, 2026-11-14): Flatter worst ticks first; the spike goes at the end of the night lane. A Safari and Chromium check of a threaded export comes first, attended. Thin scope: a scratch worker driver in the real match scene, a headless digest check, threaded exports built overnight, plus one fault probe (a script error in the worker fails loudly, no hang); the full reader audit and other fault probes only after a go. Lever A1 (step and hand-off in separate frames, no threads) is a third arm in the browser A/B. Go rule: a gain above twice the A/A spread on skirmish3v3 and the team match against the better of current `main` and A1, no worse frame tails; hordes300 reported as stress, outside the rule.
- Third round (user, 2026-11-15): the spike moves to next in the night lane. A third outcome besides go and drop: **park**, when skirmish3v3 and the team match miss the go rule but hordes300 or the late-game 3v3 canary show a gain above twice the A/A spread; they stand in for the simulation cost later packages add (P5 routes, P6 avoidance, fog, the batches), with no projected numbers. A parked experiment is re-run on the newer tree at the P6 and fog of war gates. The results also give the hand-over cost per unit (copy time over unit count at the workloads' unit counts), so a park predicts how the tax grows toward the 210-unit target. A read-only reader inventory made before the go is kept as input for the plan (user, 2026-11-15), although the second round put the full reader audit after a go; the thin scope stays.

## Main branch audit (user, 2026-11-11 night)

Answers to an outside audit of `main` at `ec78012` (audit and fix list kept outside the repo in `~/projects/wargrid-overnight-work/audit-2026-11-11/`). Fixes applied the same night on branch `verify/2026-11-11`: WB18 made platform-stable, CI check in kickoff and wrap-up, web desync download, lockstep queue bound, `chases` in the snapshot, release actions pinned by SHA.

- **Golden order (changes "After performance next" item 1):** pin as few new golden digests as possible until the movement milestone has landed; the golden scenarios plan moves after movement. The snapshot restore round-trip test comes with the movement milestone's unit schema, not before.
- **Presentation tests:** no byte-exact goldens over drawn geometry; use counts, summed coordinates with a tolerance and colour digests (as WB18 now does).
- **Reference-trace parity:** a gate only for units that change locomotion feel; otherwise a tool used when a unit feels wrong.
- **Design questions:** research only for the next one or two milestone packages.
- **Bot memory:** stays outside the snapshot while each netplay client runs only its own seat's bot; revisit when M9 bot takeover runs bots on every client.
- **Relay Origin check:** skipped for now (friends only); revisit in M9.
- **Fuzz and invariant test:** before the movement milestone. **One targetability predicate:** before ground batch A. **Controller chain flattening:** with the controls task, together with the `SimPump` seam.
- **Performance:** now a `BUDGET EXCEEDED` summary line and a report-only worst-tick line; the forward budget per unbuilt system after measuring the browser against native on the team match (desktop-only 3v3 is decided from that measurement); a report-only late-game canary before the movement design.
- **Roadmap:** a thin playable slice (controls task, minimal real HUD, order acknowledgement sound, regular 1v1 playtests) directly after the movement milestone; fog (M7.9) before ground batch A; the roster stays at four units per faction until three recorded 1v1 matches are reviewed.
- **Unit autonomy (human vs AI behaviour):** decided at the M8 design, leaning toward a per-unit stance; count "units just stood there" and "ran off" remarks in playtests first.
- **Documentation:** `docs/ARCHITECTURE.md`; a `docs/STATUS.md` that replaces the status bullets in the development notes' Start here; symbols instead of line numbers in living documents; a short table at the head of the performance ledger. Logs are not moved.
- **README:** current screenshot and a short fight clip (needs a window: ask first), remove "placeholder shapes for now", CI badge once `main` is green, three lines on what Wargrid does differently. Align `AGENTS.md` with the README's "inspired by" wording; open item: a qualified opinion on deriving the roster's numbers from retail data before wider distribution.
- **Next (user):** overhaul milestone planning into smaller packages that each give players a meaningful increment and can be shipped and playtested on their own, plus tooling that focuses playtests on the current aspects and makes feedback easy, clear and directed. Starts right after the audit batch, with brainstorming.

## Planning overhaul: packages and playtest tooling (user, 2026-11-11 night)

- **Feedback moments:** both mid-match and afterwards: a quick in-match marker plus a short after-match form that shows the markers again.
- **Players:** mostly the user alone; a friend joins only for online parts.
- **Playtest length per package:** 15 to 20 minutes, one or two matches.
- **Cadence:** a new package every 2 to 3 days.
- **Package rule:** mostly every package changes something the player can feel in a match; a pure engine package is allowed now and then, without a playtest.
- **Big changes (movement, avoidance):** ship behind a toggle, old and new side by side in the build, flipped with a key like the art lab, before the new one becomes the default.
- **Where packages go:** every package to the test app (`wargrid-web-test`); a public release bundles a week's packages.
- **Playtest findings:** a problem in what the package was about is fixed before the next package; other findings go on a list that orders later packages.
- **In-match marker:** one key (for example F2) opens a quick note, Good / Bad / Confusing plus an optional line of text, pausing offline; it saves tick, camera spot, selection and a screenshot.
- **Focus:** the launcher shows a card per build (what is new, what to try); in a match a toggleable checklist ticks items off as they are done.
- **After-match form:** in the game, shown after the match: three to five rating questions about the package's focus, and the session's markers listed again to comment on; works in the browser and on desktop.
- **Hand-off:** one file per session, saved on desktop and downloaded in the browser (the desync report's download path); the user drops it in a folder the agent reads.
- **First package:** the playtest helper (marker key, focus card, checklist, after-match form, session file).
- **Open playtest backlog** (M7 FRC checks, art-lab defaults never seen in a match, M6 fixes checked headless only): three 15-minute focus cards, one per area, played with the helper.
- **Focus cards:** the agent drafts each from the package plan; the user approves it with the plan and may edit it before playing.
- **Re-plan depth:** the next five packages in detail (about two weeks), the rest of blueprint §7 re-cut roughly, re-planned as playtests come in.
- **Order (replaces "playable slice directly after the movement milestone" above):** interleave: playtest helper, camera controls, movement part 1 behind a toggle, order controls (control groups, Shift-queue, acknowledgement sound), movement part 2, and so on.
- **Engine-only audit items** (fuzz test, `BUDGET EXCEEDED` line, browser against native measurement): riders, one small item per package next to its player change.
- **Naming:** P1, P2, ... with a player-facing name (for example "P3 Camera that follows you"), tracked in `docs/STATUS.md`; M-numbers stay for history.
- **Helper scope:** on by default in the test app and dev builds; off in public releases unless switched on in the settings, so friends can send session files too.
- **Session file contents:** the match's command log (so the agent replays the match headless and jumps to each marker's tick), the notes, answers, build id, map and seed, and each marker's screenshot as a small JPG (about 640 px wide) inside the one file.
- **Plan home:** `docs/packages.md` (next five packages in detail, the rest rough); blueprint §7 links to it and keeps design scope; `docs/STATUS.md` shows state.
- **Session inbox:** `~/projects/wargrid-playtests/`, outside the public repository; the agent reads new files at kickoff.
- **Earlier order kept:** the interpolation rework becomes its own package ("Smooth motion", P4) before movement (P5); the `SimPump` seam goes with controller flattening in the HUD packages; writing the movement design is P3's rider.
- **Session:** one sitting; one file holds every match of the sitting; a short marker review after each match, the focus questions once when the session ends.
- **First plan covers:** `docs/packages.md`, `docs/STATUS.md` and the blueprint §7 link; P1 with its rider; all three backlog focus cards. Only card 1 blocks P2; findings from cards 2 and 3 go on the list unless they block play. Design: [packages and playtest helper](../superpowers/specs/2026-11-11-packages-and-playtest-helper-design.md).

## Dock-hold experiment (user, 2026-11-12)

Evidence: [dock-hold experiment](dock-hold-experiment.md).

- **Dock model:** adopt neither split nor queue yet; measure option C next (one pile lock per credit for every collector, rest of the stand unlocked), with a per-phase breakdown for the unexplained FRC 7-worker loss and the saturation and payback metrics.
- **Gated multi-collector targets:** change them (steady window, re-measured values) together with the change that adopts a dock model, not before.
- **Code location:** harness tooling and the note on `main`; the split and queue variants stay on the local branch `dock-hold` as evidence.

## Dock option C follow-up (user, 2026-11-12 night)

Answers to the open points of the [dock-hold note](dock-hold-experiment.md#option-c-and-saturation-2026-11-12):

- **Dock model:** none chosen yet; the frc7 shortfall is investigated first, because it decides whether any dock rebuild pays (c1 18 of 22 rows, split 17, hold 16, c2 15).
- **USA 2-Chinook overshoot:** up to +5 % above Zero Hour is acceptable (c1's usa2 far +4.3 % steady is inside).
- **frc7 shortfall** (Wargrid loses 14.4 % against the pile bound, Zero Hour about 7 %): one small evidence-only investigation: phase breakdown at n = 1 and n = 7 on both sides, the gap between a pile release and the next grant, and the far-depot cycle length.
- **Economy metrics:** saturated income per dock site with spend to 90 %, and marginal income with payback, become standing report rows (cap, n90, spend90 per curve, payback only up to n90, a flag when a pile empties); the basket metric waits until a basket is chosen.
- **Branch `dock-hold`:** stays local; nothing is cherry-picked or pushed until a dock decision.
- **c1 and c2 in CI:** run only when named (`WARGRID_DOCK_MODELS`); the default suite runs hold, split and queue.

## frc7 gap follow-up (user, 2026-11-12 night)

Answers after the [frc7 gap measurement](dock-hold-experiment.md#frc7-gap-measurement-2026-11-12) (one extra cell walked per trip with several workers; no dock lock rule touches it):

- **Dock model:** c1 is chosen for a clean rebuild (one pile throughput rule, 184 ticks per 300 credits; usa2 far +4.3 % is inside the +5 % allowance). Order: the dock rebuild comes before the movement fix, so FRC income leaves hold's cap (frc7 close 1590 against Zero Hour's 2850) without waiting for it.
- **Release first:** release 0.11.0 before any of this, so the live site gets the new graphics (top priority).
- **Then:** the c1 rebuild plan (Opus-written), then its run; frc7 close and far rows stay reported, not judged, because the movement fix will lift them about 8 %. The evidence-only spike on the rule behind the extra cell (trace one leaving worker's cells against the standing workers' cells, then the route, arrival-cell and exit-cell code) runs after it or in a second worktree.
- **Start-dependent n = 7 rates** (split sweep 2385 against opening 2625; Zero Hour 30 apart): a caveat in the note for now; revisited after the movement fix.
- **Zero Hour far opening:** three new games approved and run (`open_worker_u3125_x7`, 3 of 3).

## Netplay reference review (user, 2026-11-13)

Evidence: [netplay reference review](netplay-reference-review.md). Placements: Relay guards and Adaptive input delay in the rough rest of [packages](../packages.md), the deploy wait as a rider on Is Wargrid healthy, the rest in [blueprint §7 M9](../blueprint.md#m9--3v3-online), the M7.9 fog section (map hacking) and Later; snapshot rejoin answers [dropped players](../questions/next-m9-drops.md) Q11.

- **Anti-cheat without a server simulation:** the Relay guards package covers what a relay can see (lead bound, hash comparison, later the byte budget). Map hacking cannot be stopped in lockstep, because every client holds the full state; accepted for friends' matches, revisit at fog (M7.9) if matches become public. A server-authoritative simulation stays rejected.
- **Metrics:** both. Relay `/metrics` into fly's hosted Grafana stays the Is Wargrid healthy package (live health); `MATCH END` log fields carry the per-match detail (frame bytes, desync groups). The 2026-11-08 removal of Prometheus does not block that package.
- **Hidden browser tab:** observe it at the next browser playtest (hide the tab 3, 8 and 15 s in Firefox, Chrome and Safari; note the time to stall and to `left`) before designing anything for it.
- **Rejected or deferred (agreed with the review's §10):** a second transport for native clients (UDP or ENet, QUIC, WebTransport, WebRTC) is rejected, revisited only if the M9 burst-loss scenario shows stalls that redundancy would remove; a server-authoritative simulation is rejected, lockstep stays; relay-side tick stamping (OpenRA) and a relay clock that never waits (Recoil) are rejected for now, adaptive delay goes in-band (Warzone 2100); binary encoding instead of JSON is deferred, the fallback if fewer frames per second (M9 relay CPU item) is not enough.
- **Also deferred or skipped:** an external store such as Redis for room state (deferred; clients already hold the same data, so it is not the first availability option); per-subsystem sync hash rings in the running game (deferred until a desync does not reproduce on command-log replay); an Origin check on the WebSocket upgrade (skipped; nothing to steal, native clients send no Origin, the M9 lobby tickets are the gate).

## Simulation reference review (user, 2026-11-13)

Evidence: [simulation reference review](simulation-reference-review.md). Packages: Sim quick wins and Flatter worst ticks in the rough rest of [packages](../packages.md).

- **Movement design inputs** (for the movement milestone design, P3's rider; built in P5): path delivery is deferred and deterministic: a request at tick T gets its route at T+1 at the earliest, served in (request tick, unit id) order under a budget of searched nodes (a started search finishes; no new one starts once the budget is spent); search inputs stay frozen until delivery, and undelivered routes are simulation state in the snapshot. The search over the rectangle navmesh ([Movement and pathing](#movement-and-pathing-user-2026-11-10)) becomes Wargrid's own typed GDScript with an explicit tie-break (f, then g, then node index), replacing item 7's `AStar2D` search, whose tie-breaks are Godot's and unread, if it is fast enough: the P5 plan measures it first (review X3: the pathing spike's 200 pairs against `AStar2D` on the same mesh). Group orders share one search per (goal, size class, tick), dropped at the end of the tick, so who shares depends only on (goal, size class, tick, request order). Mesh updates when buildings land are capped per tick.
- **Avoidance design inputs** (for the avoidance milestone): moving units are soft (they push and are pushed, with pressure damping so crowds settle), parked units block their cell for search and movers, waiting units wake when a cell frees; each unit sums the pushes on itself so the result does not depend on iteration order. The neighbour query comes from one packed per-tick index (review X5: packed rebuild against incremental against today's grid). Hard cell occupancy for movers (OpenRA) matches the avoidance spike rules that jammed packed moves.
- **Split rates scope** (refines the [split rates decision](#performance-next-user-2026-11-11)): slower cadence applies to target rescans, retaliation joins and return-home scans; keeping the current target (lookup, hostility, range, engage or chase) stays per tick, because it decides how fast a unit reacts. The per-unit cost is expected to fall from packed storage, not from cadence.
- **Browser digests (review X7):** the golden scenarios run in the Firefox web bench and their digest lines are compared with native, as part of the golden scenarios work after the movement milestone; a CI job later only if cheap.
- **Rejected (agreed with the review's §8, among them):** fixed-point maths now (the 2026-11-09 decision stands: only with a native port); an ECS or component framework (packed columns per system instead); parallel work inside a tick (the compute-then-apply-in-order shape stays for kernels); a lower global simulation rate; GPU movement; path caches kept across ticks; hard cell occupancy for movers; a bot thread with a state copy; a whole port to Rust or C++ now (the native spike's conditional verdict is unchanged); a `streflop`-style libm (nothing to fix: only `sqrt` is allowed); diff-based range queries everywhere.

## Package review (user, 2026-11-13)

Questionnaire over the packages after two days of additions; result in [packages](../packages.md).

- **c1 dock rebuild:** tracked as package P1.1 "Laborers that pay" before P2, without renumbering P2 to P5; its card is a replay of card 1 (`p1-frc-economy`); F2 (Laborer back pack) rides on it.
- **P2 scope:** widened with menu quick wins (including the F5 paste fix) and F1 (scale legend), because the order sound alone is thin for a session.
- **P5:** P3's rider, the movement design, ends with movement cut into packages of 2 to 3 days each; P5 is the first of them.
- **Canary:** the late-game 3v3 canary and the recorded playtest match row move from P5 to P2's rider, so they feed the movement design (the audit answer wanted the canary before that design).
- **Engine packages:** a night lane: headless, unattended, no focus card, at most one between two day packages. Order: Sim quick wins, Flatter worst ticks, Relay guards, Adaptive input delay.
- **Adaptive input delay:** if a measured gain adopts it, one online session with a friend before it becomes the default; P1's card 2 is played in that session.
- **Card 3:** played soon in a free sitting on 0.11.0 with the helper switched on.
- **Roadmap page:** `docs/packages.md` becomes the one-screen "what comes when" page (now, day lane, night lane, later); scope stays in the blueprint and the reviews.
- **Blueprint:** a small pass later in its own session: take order and status out of §7 (they live in packages and STATUS) and check every done or not-done claim against its evidence; no full renumbering.
- **README roadmap** (branch `spike-visualization`): kept next to packages; its check is re-keyed from blueprint §7 headings to package names and its rows refreshed, merged in its own session after this one.

## Package review, second pass (user, 2026-11-13 night)

Questionnaire over the packages after the HUD v4 and map art additions; result in [packages](../packages.md) and [STATUS](../STATUS.md#packages).

- **P2.3 HUD core splits into two day packages** (user, 2026-11-13): P2.3a "See your selection" (flat dark theme and Inter (Public Sans since 2026-11-14), top strip, selection panel, refusal line, owner colour, stretch aspect `expand` and edge anchoring: everything P2.5 needs) and P2.3b "Build from the dock" (build and production grid with position keys, queue, forecast and shortfall card, Unload, key on every button, Controls list in the Esc menu). P2.5 needs P2.3a only; P3's edge scrolling is built against P2.3a's dock.
- **Controller flattening (FIX-6) becomes its own night package, "One controller", before P2.3a** (user, 2026-11-13): night 2 after Tighter gates; the later night packages move down one. The `SimPump` seam stays in Later 3, which changes "the `SimPump` seam goes with controller flattening" from the [planning overhaul](#planning-overhaul-packages-and-playtest-tooling-user-2026-11-11-night).
- **The movement design moves from P3's rider to P2.1's** (user, 2026-11-13), written during the launcher days so P5 can be planned when its turn comes; P3 has no rider. Day lane order unchanged.
- **Gates of P2.3a and P2.3b:** a rendered benchmark row with the HUD in the scene and a 120-unit selection (user, 2026-11-13).
- **P2.1 keeps the Fullscreen setting; stretch aspect `expand`, HUD anchoring and the non-16:9 layout test move to P2.3a** (user, 2026-11-13), because anchoring today's status line would be thrown away. `expand` shows more map on a wide screen, which is a vision edge online and a draw cost the 1280x720 benchmark misses, so P2.3a also gets a rendered row at a wide window size.
- **Hello deadline and unstarted-lobby expiry move from Relay guards into P2.2 Quick rematch** (user, 2026-11-13): P2.2 lets a lobby wait minutes, so the cap on that wait ships with it. Relay guards keeps the lead bound, the relay hash comparison, the per-IP limits, the `MATCH END` byte fields and the `WebSocketPeer` rider.
- **The web hotkey check moves to order controls as its first step** (user, 2026-11-13): which decided keys a browser takes before the game ([F10](../STATUS.md#findings-list)); P3 checks Space itself. The only check left before the P2.3 designs is whether tabular numbers render in the web build; the glyph silhouettes were checked in a window inside the [map art spike](#map-art-faction-shapes-m75-user-2026-11-13).
- **HUD glyphs come after P2.6** (user, 2026-11-13): in the windowed check Vehicle Factory and Headquarters were the same rhombus until the faction bodies exist.
- **Order controls gains** the comma key for the next idle army unit, the control-group row and the idle-builder button (user, 2026-11-13), so each HUD Full item lands with its control.
- **Later 3 is renamed** (user, 2026-11-13): it holds the minimap rectangle, the base-under-attack alert and the `SimPump` seam, no longer a "minimal real HUD" and no longer FIX-6.
- **Findings list destinations** (user, 2026-11-13): budget rows exceeded go to Sim quick wins and Flatter worst ticks; F10 to order controls' hotkey check; air collector full load, F8, F9 and the repeat friend match are parked.
- The names "See your selection", "Build from the dock", "One controller" and "Minimap and attack alerts" are proposed (agent, 2026-11-13) per the [wording rule](../roadmap-wording.md).

Movement and avoidance, same questionnaire (user, 2026-11-13):
- **Core slices soon, advanced slices later, both on the new movement base.** Avoidance is not built on today's grid, because the new base changes the cell model: moving units lock no cells. This revises the order "movement and pathing is its own milestone before the unit avoidance milestone" ([movement and pathing](#movement-and-pathing-user-2026-11-10)).
- **Core movement** (day package P5, replacing "Smarter paths (toggle)"): the provisional base method in minimal form (rectangle navmesh B, the finer grid A as reference and as fallback if B fails the stuck check), individual routes, body-safe straightening, moving units never lock cells (only stopped units, reference-counted, the Permafrost rule above), behind a toggle key. First step: the seeded fuzz and invariant test, moved from P4's rider. The movement lab is reduced to what core needs: navmesh against finer-grid path shape, body-safe against centre-line straightening. The cross-platform path determinism test comes early (item 8 of the 2026-11-10 list).
- **Core avoidance** (day package P6, after core movement): moving units yield and steer around each other, starting from the avoidance spike's Zero Hour style yielding (approach A, branch `spike-avoidance`, `docs/reference/unit-avoidance-spike.md` there), behind a toggle key; cost cap as in [unit avoidance: scope](#unit-avoidance-scope) (about 0.5 ms per tick on the 300-unit benchmark).
- **Advanced slices, later packages:** three size classes, local navmesh updates on building placement, the route budget per tick (8 against 32 against all, or a searched-cell cap), shared trunks or flow fields for big orders, formations and keep formation; arrival spreading, crusher rules, the open questions of avoidance round 2, soft movers. Each toggle becomes the default with one trace re-pin, so the "two trace re-pins accepted" count stands (one for movement, one for avoidance).
- **Day lane order:** P2.3b, core movement, P2.4, core avoidance, P2.5, P2.6, then P3 camera and P4 smooth motion. P4 stays its own package after P3.
- **The movement design** (P2.1's rider) designs the core movement and core avoidance packages and cuts the advanced ones into packages.
- **Golden scenarios** stay after movement: after the advanced movement packages make its toggle the default.
- The names "Units that find their way", "Units that make room", "Smoother big moves" and "Crowds that sort themselves" are proposed (agent, 2026-11-13).

Answers to the contradictions found while placing these (user, 2026-11-13):
- **P6 starts from soft movers** (user, 2026-11-13): moving units push and are pushed, with pressure damping, and parked units block their cell, as in the [simulation review answers](#simulation-reference-review-user-2026-11-13). Approach A (yielding) stays a reference only. Pressure tuning, crusher rules and the round 2 questions stay in advanced avoidance. Replaces "starting from approach A" above.
- **The path budget goes into P5** (user, 2026-11-13): deferred path delivery under a searched-node budget, as the simulation review answers placed it, because a big order must get every unit moving within a tick or two. The 2026-11-10 lab's "8 against 32 against all" comparison moves into P5's lab as the budget size check (response to the click against cost). Shared group searches and trunks or flow fields stay advanced. Replaces the route budget in the advanced list above.
- **P6 keeps the 0.5 ms per tick cap** (user, 2026-11-13): its design measures the soft-mover cost first; going over the cap is a stop for the user to decide, never loosened. No avoidance spike variant met the cap (rounds 1 to 4).
- **One controller is planned as small resumable tasks with a resume record and may span one or two nights** (user, 2026-11-13). The audit's manual offline and online match in a window becomes a short attended check before P2.3a starts, not part of P2.3a's playtest.

## Play with a friend (user, 2026-11-13)

Questionnaire after a research pass on simple ways to play 1:1 with a friend (research note private). Placements: the P2.2 row and a line under "Not ordered yet" in [packages](../packages.md).

- **Channel-neutral:** Discord was only an example of where a link gets sent (chat, SMS or a phone call do as well). Nothing is optimised for or integrated with a chat or storefront service: no Discord Activity or bot, no Steam features.
- **Target flow now: link only.** Host: Create, Copy link, send it by any channel; friend: click, pick a faction, Join (built in P2). A second, simpler round of questions the same day replaced the first round's "easy codes now" and "code before room" answers.
- **Hidden tab while sending the link (P2.2):** a lobby still waiting for its second player tolerates minutes of silence instead of the 10 s read deadline; the 10 s rule stays for started matches; the client's 5 s silence rule (`RelayTransport.silent`) gets the same lobby tolerance. Checked before deciding: the lobby phase ends before the relay's `start` message, from which replays, seeds and traces begin, so the wait does not touch replays or determinism; it fits the Relay guards package (hello deadline before `hello`, unstarted-lobby expiry of about 15 min as the upper bound, [netplay reference review](netplay-reference-review.md) S3/S4); the open M9 question of pausing or continuing while a seat is away in a running match ([dropped players](../questions/next-m9-drops.md) Q1) is unaffected. Whether browsers keep a hidden tab's WebSocket open for minutes: unverified, observed at P2's playtest with the hidden-tab check.
- **Rematch (P2.2):** a "Play again" button after a match: the room stays open, both press it, a new match starts with the same opponent and no new link.
- **Word codes:** only if reading a 6-character code to a friend on a call proves painful.
- **Permanent friend link, quick match:** the friend link is re-explored with the M9 lobby, together with other modern, easy ways to match up with friends; quick match comes after M9.

## New launcher (user, 2026-11-13)

Every screen is drawn in two sets with one layout, kept in [launcher mockups](../images/launcher-mockups/): `minimal-*` is P2.1, `fancy-*` is for later packages. Placement: P2.1 in [packages](../packages.md).

- **First round:** light tabs on top (Vs. Bot, With Friend, Settings; mockups deleted) in the dark game look, own package right after P2; superseded the same day by the sidebar decision below.
- **Second round: sidebar** with separate Vs. Bot and Play with Friend pages, drawn by ChatGPT in a primitive grey and a rich dark version (mockups deleted). The sidebar stays; its pages and the rich skin were superseded the same day by the picks below, made on labelled A/B pages.
- **Structure: one Play page.** Sidebar: Play, Join, Settings, Credits, version at the bottom. [Play](../images/launcher-mockups/minimal-play-bot.webp) holds your faction, an opponent slot switched between Bot and [Friend](../images/launcher-mockups/minimal-play-friend.webp), and the map; [Join](../images/launcher-mockups/minimal-join.webp) takes a match code. The Vs. Bot and Play with Friend pages are dropped: a 3v3 with friends and bots fits neither, so that split would have changed again at M9.
- **Two sets, one layout:** the minimal set keeps today's grey; the [fancy set](../images/launcher-mockups/fancy-play-bot.webp) uses the flat look of the [art direction](../art-direction/ART_DIRECTION.md): matte fills, square slabs, owner blue and red on the chosen faction, cyan for selected only, amber for the one start button, no icons, no backdrop. The ChatGPT skin (gradients, painted backdrop, painted map) is dropped.
- **Factions and map: dropdowns** in both sets. The fancy set adds the faction emblem and a map preview panel (thumbnail, start positions, supply sources).
- **Waiting for the friend: its own view** ([minimal](../images/launcher-mockups/minimal-waiting.webp), [fancy](../images/launcher-mockups/fancy-waiting.webp)): invite link with Copy, both player slots, the map, Cancel match. Part of P2.1.
- **Fast bot start:** the launcher opens on Play with Bot selected and the last settings preselected; no quick-match button. Part of P2.1.
- **Bot level and play style:** hidden in the minimal set until they exist (supersedes "shown, only Normal enabled" from the same day); the fancy set shows levels 1 to 5 and the play style.
- **No Back button** (every page is one sidebar click away) and **no mode-card start screen** (a dark start screen with two mode cards, mockup deleted); the launcher opens on a page directly.
- **Starting resources, game speed, Expert:** left out until the features exist; each control comes with its feature.
- **Emblems:** Wargrid's own, not the Zero Hour faction emblems the ChatGPT mockups resembled (EA trademarks). Single-colour, so each works in any owner colour (colour is ownership, art direction §6); abstract badge shapes, no machines: [USA](../images/launcher-mockups/emblem-usa.svg) a split arrowhead, [China](../images/launcher-mockups/emblem-china.svg) two chamfered plates with the lower one wider, [FRC](../images/launcher-mockups/emblem-frc.svg) a broken ring of three unequal pieces. Stars, wings, national symbols and letters are out. No search against existing logos was done (agent note: the arrowhead is the one to check before the fancy set ships).
- **Open points settled** (user, 2026-11-14, questionnaire): while waiting for the friend the sidebar is locked and only Cancel match leaves; an invite link (`?code=`) opens on Join with the code filled in, and the friend picks a faction and clicks Join; the host row keeps its READY badge as decoration, so the slot is there when the M9 lobby adds a real ready step (no ready step exists today, the match starts when the friend joins); the sidebar lock gets a P2.1 playtest card question (is it annoying?); the Fullscreen switch is desktop only, and the launcher fills a non-16:9 window without black bars, the match keeping them until P2.3a; the selected side of the Bot/Friend toggle takes the selected sidebar item's green fill, the other side stays dark; a remembered setting that no longer exists falls back to its default per field, silently; match codes stay 6 characters (the mockups' 4 are a sketch); the launcher remembers your faction, the bot's faction and the map in a `[launcher]` section of `user://settings.cfg`, and still opens with Bot selected. **Launcher colours (user, 2026-11-14):** selected things (sidebar item, Bot|Friend side, Quality Low|High) are neutral grey `#666a6c`; the one action per page (Start match, Create match, Join match, Copy link) is amber `#f7c871` with dark text `#1a1408`; switches are off as the field dark `#2b2b2b` with a grey `#808080` knob and on as `#d4d4d4` with a dark knob. Green leaves the launcher. Picked on A/B pages (seven palettes, four switch styles) against the first build's two greens (`#2f6b55` selected, `#2fb58a` action), which the user found too close; amber matches the fancy set's start button, so the later fancy look adds cyan for selected without changing what a colour means (the HUD keeps amber for "needs you now", the launcher for its one start button, as decided for HUD v4). **Font (user, 2026-11-14):** Public Sans 2.001 (uswds/public-sans, SIL OFL 1.1) is the game's UI font, for the launcher now and the HUD in P2.3a; it supersedes Inter from the HUD v4 decisions. Picked on an A/B page that drew the launcher mockups and the HUD v4 page in Helvetica Neue (the mockups' font), Inter, IBM Plex Sans and Public Sans at the same CSS sizes; Geist was rejected earlier the same day. Public Sans has the mockups' x-height (0.517 of the em, Helvetica Neue 0.517, Inter 0.546) and is 1 % wider, so mockup sizes carry over 1:1. It sets slightly larger than Inter in the HUD v4 page, so P2.3a checks the HUD v4 pictures again in Public Sans before fixing dock sizes (user: keep the overall look as intended). For M9 (user, 2026-11-14): joining should gather the players in a room where the host may still change the map and starts the match, instead of today's relay rule that starts a room once it is full; recorded in the blueprint's lobby look.
- **Fancy set notes (agent assessment, for its planning):** the map picture is a thumbnail rendered from the real map data in Wargrid's look, not painted art; the thumbnails in the fancy mockups are sketches.

## Map art: faction shapes (M7.5; user, 2026-11-13)

A design spike on branch `spike-art`: no game code changed. Candidates were shown on labelled A/B pages that draw the game's own shapes: a headless script exported every shape of `game/scripts/presentation/shapes.gd` with the palette and projection, and the page redraws them with the same bake rules, so a candidate is the same data edited. Judged at the three zoom steps, smallest first, on the game's ground and owner colours, each role beside the other factions' version, in a small base under the [HUD v4](../images/hud-v4/notes.md) mock-up layer, and as a single-colour silhouette at HUD glyph size. The pages, the build spec, the exported shapes and the candidate data are working files in the private notes repository (`art-spike/`). Pictures: [map art](../images/map-art/notes.md).

Starting point (inventory of the code at `10b9423`): 37 definitions, of which 24 share 9 shapes across factions, colour being the only difference: Headquarters, Supply Depot, Vehicle Factory and Barracks in all three factions (FRC calls its own Supply Cache and Vehicle Yard), Power Plant in USA and China (FRC has none), rifle and rocket infantry in all three, the bulldozer in USA and China, the light vehicle in USA and FRC. Factory and Headquarters share one slab; the factory adds a door, the Headquarters one roof box.

**Round 1, the five shared buildings** (user, 2026-11-13; all six picks as recommended, no comments; the recorded view at each pick was the base view at zoom 0.5 with the Neon set on the dark ground):
- **Own body per faction ("bold") for Barracks, Vehicle Factory, Headquarters, Supply Depot and Power Plant,** against "restrained" (today's body with faction parts on and beside it) and against today's shared shape. The role cue is the same in every faction (barracks low with repeated rooms, power plant two drums, depot an open pad under lifting gear, factory one hall with a wide dark door, headquarters the tallest with a tower or mast); the faction changes the construction: USA symmetric with centred modules, China a thick plinth and mass that steps inwards, FRC unequal boxes pushed together off-centre. These three constructions were proposals in the [art direction](../art-direction/ART_DIRECTION.md); for buildings they are now picked.
- **No wedge primitive.** China's buildings were also drawn with true sloped faces; stepped boxes were picked, so "boxes and cylinders" stands. Agent note: the slopes clearly helped only the factory; vehicle hulls are the stronger case and may be asked again.

Agent assessment from the round, not user decisions:
- At zoom 0.5 the restrained factories and barracks of the three factions could not be told apart; their faction parts were 2 to 4 px.
- Cost is shape data plus splitting five roles by faction in `Shapes.role()` and its pinned test. The picked bodies no longer use the shared four-part slab, so each needs its own rule for the decided damage look (missing corner, darker roof); the drawing agents described one per shape, none was drawn.
- All candidates pass a JavaScript port of the shape audit's paint-order and footprint rules (`game/tests/test_shape_audit.gd`) at heading 0, undamaged. Not run in Godot.
- At zoom 0.5 the game draws a cylinder with four sides (`game/scripts/presentation/shape_bake.gd`), so the power plant's drums are square posts at the smallest zoom.
- Baked from the shape parts as one flat colour, most buildings are the same lozenge at 22 and 28 px; two tones help somewhat. A headless probe drew baked shape parts into a `Control` through the same call the world uses without errors; pixels are unproven without a window (windowed run: questionnaire after round 3 below). Both feed the HUD's choice between baked and hand-drawn glyphs.

**Round 2, the four shared unit shapes** (user, 2026-11-13; no comments; the recorded views were the base view on the dark ground with the default set, three of four at zoom 1; asked afterwards, the dark ground was only being looked at, so rounds keep opening on sand):
- **Rifle and rocket infantry get faction versions, the "restrained" ones:** today's body and height, the faction in headgear, pack or weapon. Picked against the agent recommendation to keep one shared soldier.
- **Bulldozer: own body for USA and China ("bold").** USA narrow with a tall rear cab, China low with a wide blade. FRC builds with the Laborer, which keeps its shape.
- **Scout Car and Armed Pickup become two vehicles ("bold"):** a low closed car, and a pickup with an off-centre cab, an open bed and a gun on a post. The picked car is lower than a tank; today's shared shape is taller than one.

Agent assessment from round 2:
- At zoom 0.5 a soldier is about 8 px tall at the decided true size. Three drawing agents and the coordinator each found that the faction cannot be read on infantry there in either option; it shows from zoom 1 and in the HUD glyphs. So the requirement to tell faction apart at the smallest zoom is met for buildings and vehicles and not for infantry.
- The picked bulldozers and the Scout Car change heights that `game/tests/test_shapes.gd` pins, and four more roles split by faction.
- The shape audit limits infantry: one thin weapon per soldier, the launcher touching the torso and under 0.4 cells long, and an owner-colour share of the drawn area (`game/tests/test_shape_audit.gd`).
- Candidates were checked for paint order at eight headings; the game's audit samples two of its 64 heading steps for paint order. Today's shared rifle infantry has one wrong sample at a heading the game does not test.
- The four tanks were not redrawn; their hulls differ by 0.05 to 0.15 cells, 1 to 3 px at zoom 0.5, and the two China tanks share one hull.

**Round 3, the placeholders** (user, 2026-11-13; all five picks as recommended, no comments; judged on sand with the default set). Covers findings F6 and F7 of the [status list](../STATUS.md#findings-list) as far as the look goes:
- **Supply piles show their fill as rows of pallets that empty from one end,** so the share of cargo against bare pad is the fill level; picked against one stack that loses height. Both pile sizes, no text. This gives the 2026-11-09 answer "the stack shrinks; the number is in the selection panel" ([look questions](../questions/next-m75-art-look.md) Q12) its form: the cargo still shrinks with the box count, as rows, not as one stack (confirmed when asked, user, 2026-11-13). Today the pile draws the same four crates from 40 to 400 boxes. Agent note: one pallet per 20 boxes would give the big source 20 steps from one shape.
- **Cargo colour pale steel `#DDE4E6`** in place of amber `#F7C871`, which is also the HUD's "needs you now" colour. Computed against sand: amber 2.01, pale steel 2.44 (pure white would reach 3.14, so no cargo colour passes 3:1 there); amber sits at a colour distance (CIE76) of 21 from the gold owner, pale steel at about 42 from the nearest owner colour of either set. Cargo is the neutral owner's colour in `game/scripts/presentation/palette.gd`, so the change reaches everything neutral-owned.
- **Salvage crate: a small crate beside a drum on an oblong ground mat,** in place of the 4 px square. Agent assessment: the mat makes it findable beside a crowd at zoom 0.5; on a dark plate the same crate looked like a small supply pile.
- **Construction: the building rises inside four thin corner posts at its final height,** so progress reads as how full the frame is and posts alone mean just started or paused. Picked against today's rise without the text, where half built reads as a finished, lower building (the game scales the shape's height, `game/scripts/presentation/world_batch.gd`). The building still rises as answered on 2026-11-09 (Q14), now inside the posts.
- **Supply Helicopter: a tandem-rotor transport,** a long owner-coloured hull with a rotor cross at each end and a cargo pod, picked against a single rotor with a slung load. Both rotors stay fixed parts: a fixed part keeps its own orientation while its pivot turns with the hull (`game/scripts/presentation/shape_bake.gd`), so each rotor follows its end of the body.

Agent assessment from round 3:
- The pile and construction text carries numbers the player uses (boxes left, collectors docked and waiting, build percent). With the text gone they belong in the selection panel, as answered on 2026-11-09 (Q11, Q12); that is HUD work, so the two should land together or the gap be accepted.
- Cost: shape data, a few lines of drawing code for the pile's fill steps, the crate and the site posts (the posts are not part of the building's shape), one palette value. Removing the labels removes the game's only text on the map.
- Open after the picks: the crate's top took the cargo colour and would sit pale on its mat; the pictures show an agent choice made afterwards (grey crate, dark drum, cream mat), accepted in the questionnaire below. The helicopter's cargo pod is in the skin colour, the only pale neutral a unit shape has, because colour slots resolve per owner. The paused construction case was not drawn.
- Today's helicopter rotor is a fixed part 0.1 cells off the anchor with no pivot, while the hull, also 0.1 off, turns about the anchor, so hull and rotor drift apart as it turns; possibly part of F7's "moves oddly". Read from the shape data, not checked in the game. Motion stays with the aircraft work.

**Questionnaire after round 3** (user, 2026-11-13; all as recommended except the last but one):
- The numbers the map text carried go into the HUD core package: its selection panel shows boxes left and collectors docked and waiting for a selected pile, and build percent for a selected construction site. P2.5 then removes the text with no gap.
- P2.4 "Three armies" goes before the HUD core package if it is ready first.
- The game's shape audit checks paint order at eight headings from P2.4 on, and today's rifle infantry gets its one-sample fault fixed there.
- Every ground batch package brings its new units' shapes in the picked faction look; no later art pass over them.
- The salvage crate's colours stay as drawn: grey crate, dark drum, cream mat. Known weak spot (agent): the crate's top is the grey of rubble; mat and size tell them apart.
- The windowed check of shape parts in a UI control is run at once (the recommendation was the next session). Result (agent run), one window, Godot 4.7.2 with the compatibility renderer, today's shapes at 22, 28 and 64 px on one dark slab colour: the shapes draw in a `Control` through the same call the world uses, in the right order, hard-edged and without seams; the control must clip its contents; sizes are layout pixels, because the game stretches its 1280x720 layout. As one flat colour, infantry and, barely, the helicopter read at 22 px, the tank loses its barrel at 22 px, and Vehicle Factory and Headquarters are the same rhombus at every size. In two tones (top faces light, other faces muted) all five tested shapes are recognisable at 28 px; at 22 px the two buildings differ by a roof block of 2 to 3 px. Agent assessment: baked two-tone glyphs are workable for units and need the picked faction bodies to tell buildings apart; a glyph control is about 40 lines on public calls, no game change. Not proven: other renderers and GPUs, the web build, the game's stretched and HiDPI scales (the run turned the stretch off), clipping inside scrolled containers, the cost of many glyphs.
- Second half of the spike, in this order: damage looks for the 14 new building bodies (P2.6's first step), tanks with the wedge asked again for hulls, detail per zoom step, the weak spots of rounds 1 to 3; then ground, owner colours, cliffs and decoration.

**Round 4, prettier shapes** (user, 2026-11-14; all six picks as recommended, no comments; judged on sand with the default set, Row view):
- **Damaged buildings lose their corners on the camera side:** at 70 % one corner facing the camera goes and the remaining roof turns dark, at 35 % a second, different corner goes and one thin smoke column rises, clear of doors and the Headquarters tower. Drawn for all 14 picked bodies; picked against corners taken off the rear and the skyline, and against today's shared-slab rule. This is P2.6's first step.
- **Tanks tell their faction by hull outline, boxes only:** USA long and slim, China broad (both China tanks share the hull and differ by turret: one long barrel against a short twin-barrel block), FRC short with a set-back, lopsided turret. Picked against the same tanks with sloped hull plates, so "boxes and cylinders" stands for hulls too.
- **Zoom 0.5 draws the same parts as zoom 1;** **zoom 2 adds up to four finishing parts per shape** (window bands, vents, track bands, hatches) that leave the outline unchanged. This narrows the 2026-11-09 answer "one detail level per zoom step" to an added level at zoom 2; at zoom 0.5 cylinders still lose sides as today.
- **Weak spots fixed:** China's power plant drums now clearly top its barracks, which is the lowest building again; FRC's barracks reads as three unequal rooms in a row; the USA soldier's pale head shows under the helmet; the Scout Car's and Armed Pickup's guns are at least 2 px at zoom 1.

**Questionnaire after round 4** (user, 2026-11-14; all as recommended):
- FRC's tank goes back to today's hull length (0.7 cells) and the Armed Pickup is shortened to about 0.65, so the tank stays the bigger vehicle; the round 4 drawing had the tank at 0.56 and the pickup at 0.86.
- The zoom-dependent drawing code (`_build_parts` reading the detail level, which today it ignores) rides with P2.4, with its units' zoom 2 versions; P2.6 brings the buildings' zoom 2 versions.
- Round 5 (ground, owner colours, cliffs, decoration) follows in the same session.

Agent assessment from round 4:
- Cutting a corner out of one box means splitting it, so a damaged body can have more primitives than the healthy one; the healthy shape is unchanged.
- At zoom 0.5 every building and tank part is already at least 2 px wide; only weapons on small units are thinner, and dropping them removes the unit's role cue. So a reduced zoom 0.5 level gains nothing; the thicker weapons go into the shape at every zoom instead.
- At zoom 0.5 a sloped hull plate is a slightly darker face, too little for a new primitive.
- The faction tanks change hull sizes that `game/tests/test_shapes.gd` pins; the USA soldier fix widens the torso slightly to keep the owner-colour share above the audit's 30 %. Neither is checked in Godot.
- The zoom 0.5 and zoom 2 tank versions on the page were built on today's hulls; P2.4 redraws them on the picked hulls.

**Round 5, the world** (user, 2026-11-14; all six picks as recommended, no comments; judged in the base view at zoom 0.5, mostly on sand):
- **Darker unit and building sides** (`SIDE` `#1c2e39`, `SIDE_DARK` `#0e1b23` in `game/scripts/presentation/palette.gd`), so the dark side band reaches 3:1 on both grounds (`SIDE` 4.46 on sand and 3.05 on the dark ground, against 2.63 and 1.80 today); picked against today's sides with a tighter, darker contact shadow.
- **Lifted default owner colours:** `44adf4 d54f3b 4fc389 ecdc3c e08522 9249ac 008d8d ffa5d4` in place of today's set. Every owner pair stays at least 22 apart (CIELAB distance) in normal vision and under simulated deuteranopia and protanopia (today's blue and purple: 5.2), and gold moves away from sand. No owner top reaches 3:1 against sand, which would need an almost black or almost white colour; the side band carries the outline. Picked against richer, darker owners.
- **Neon stays opt-in;** the default set stays the default.
- **Firmer cliffs:** top lightened 0.22 and sides darkened 0.55 (today 0.15 and 0.4), height unchanged, so the side reaches 3.23 against sand (today 2.3); picked against today's cliffs with a thin lit rim on the top edge.
- **Decoration lies flat on the ground:** roads as lighter strips, rock plates and tree discs with flat shadows, water as a muted blue-grey surface; nothing has height, so nothing can hide a unit. Picked against low raised rocks and tree clusters. None of it exists in the code.
- **Fog at 0.65 brightness** rather than half, so frozen buildings and the side band keep more contrast and the fog edge stays visible.

**Questionnaire after round 5** (user, 2026-11-14; all as recommended):
- Fog brightness 0.65 replaces half brightness (Zero Hour's default, answered 2026-11-10 with "re-check once the ground is sand") as the fog package's starting value; the fog package confirms it in the game, since the page only multiplied brightness.
- The palette changes (side band, owner colours, cliffs) ride with P2.4.
- Flat decoration lands with the next map ports, whose converter learns roads, rocks, trees and water.
- The Neon set fails the colour-vision check (blue against purple 1.5 under deuteranopia) and its teal `#00d8e8` sits close to the HUD's cyan: recorded on the findings list.

Agent assessment from round 5:
- With the darker sides, building sides look nearly black at zoom 1 on the dark ground and doors on side faces lose contrast.
- A unit standing right in front of a cliff face loses its side band against the dark face (contrast 1.1 to 1.5) with either cliff option; its owner-coloured top carries it there.
- Under either fog value some frozen owner pairs fall under the colour-vision distance of 20.
- Raised decoration would have to be drawn in the terrain layer and sorted with the cliff cells to stay under units; the picked flat decoration needs neither. Raised cliff cells are blocked today, so no unit stands on top of a cliff.
- The game's per-cell ground shade is at most 4 % either way.

Contrast, computed (WCAG relative luminance): no owner colour of the default set reaches 3:1 against the sand ground `#A88E5C` (blue 1.68, red 1.72, green 1.27, gold 1.30, orange 1.02, purple 1.94, teal 1.05, pink 1.19), and the Neon set does not either (best: yellow 2.40). A shape separates from the sand through its dark side faces (`#263842` 3.87, `#3D515F` 2.63). On the dark biome `#7B7566` the side faces drop to 2.65 and 1.80, and only Neon yellow passes (3.50). **Owner colour against ground goes to an A/B in a later round (done: round 5, 2026-11-14) of this spike** (user, 2026-11-13), part of its second half.

**P2.4 prep questionnaire** (user, 2026-11-14; all eight as recommended, after the research below; P2.4's design and plan are written when the package starts):
- Straight swap: the picked unit shapes replace today's; no look toggle.
- The palette changes (side band, owner colours, cliffs) go in their own commit inside P2.4, so the golden output re-pins once for colours and once for shapes; whatever fixes the Neon finding F12 (not yet picked) rides in that commit.
- P2.4 starts with the eight-heading paint-order audit, run on today's shapes, with zero wrong samples allowed at every heading.
- P2.4 draws the missing zoom 2 versions: the three rocket infantry, both bulldozers, the Armed Pickup and the four tanks on their picked hulls (the page's zoom 2 tanks sit on today's hulls).
- Tanks are nudged to exactly 3 units tall, keeping the Zero Hour height-to-length rule (picked: USA 3.1, 3.2 at zoom 2; FRC 2.9). Light vehicles and bulldozers keep their drawn heights and are re-pinned (Scout Car 2.7, Armed Pickup 3.95, USA bulldozer 4.95, China bulldozer 4.2; today 4.5).
- The identity audit's rule becomes "zoom 0.5 and zoom 1 draw the same parts; zoom 2 keeps every part and primitive and adds at most four", so zoom 2 versions are drawn as supersets.
- The firmer cliff factors (top lightened 0.22, sides darkened 0.55) apply to the dark biome too, which has hand-set cliff colours today.
- Branch `spike-art` was rebased onto `main` first (clean).

Research for the questionnaire (agent, 2026-11-14; page-side counts from the spike's own triangle counter, which matches the game's exported counts at heading 0; nothing run in Godot):
- **Triangles per tick (estimate),** mean over the 64 headings, today against picked: team match army (210 units and 6 builders) 5487 to 7250 at zoom 0.5 (+32 %), 6974 to 8964 at zoom 1 (+29 %), 8370 to 11837 at zoom 2 (+41 %). The rendered benchmark's open, dense and Ashfall layouts are 300 Scout Cars, the unit that grows most: 7050 to 10575 (+50 %; +75 % at zoom 2). Horde layout +22 %. Zoom 2 counts use the zoom 1 parts where no zoom 2 version exists yet, and the page's zoom 2 tanks sit on today's hulls, so they are provisional. At a rough two-point slope from the art lab's headless Low and High rows (about 0.075 ms per 1000 triangles per tick; shadows and a higher detail level are mixed in; [performance ledger](performance.md#art-lab-exit-rerun-2026-11-10-tree-96f89e8)) that is about +0.26 ms rendered tick-frame p95 on those layouts at zoom 0.5, from 64-70 % to about 73-79 % of the budget against the single-run P2 gate rows (worst: open; runs on one tree spread by about 0.5 ms), and about +0.18 ms on the horde layout, which has no P2 gate row and last measured about 6 ms (art lab, 2026-11-10). Agent judgement, not measured: the cost is the CPU append in `WorldBatch.build`, and counts this small barely load the GPU. The gate overstates a real match, whose mix grows by about a third.
- **Tests the picks touch:** in `game/tests/test_shapes.gd` the role map SH7, turret parts SH9 and SH9b (USA tank turret is the third part, FRC pivot moves), heights SH12, hulls SH13 (USA 0.9 x 0.4, China 0.76 x 0.68, FRC 0.7 x 0.46), tank parts SH14 (USA and FRC tracks and deck), side colours SH15, infantry SH16 (the USA helmet is a fourth cylinder, the USA torso 0.17 wide and its head 1.15 tall, against 0.16 and 1.3), the bulldozer and head-fan checks SH17 and SH18 (they name shared roles; under the USA helmet SH18 finds no head top), cliff factors W1; in `test_shape_audit.gd` the shared role lists and SA7's infantry and laborer pair, identity SA3, paint order SA4 (two headings), owner-colour share SA5 (China rifle at zoom 2 about 23 % on the page's raster against SA5's 30 % floor, USA rocket at zoom 0.5 and USA tank at zoom 2 at the floor), the weapon rule SA6 (China's rocket launcher sits 0.13 cells off the torso and is 0.4 long, limits 0.08 and under 0.4); in `test_world_batch.gd` the golden output. At eight headings today's three rifle infantry have one wrong sample at heading 6, the picked FRC rifle two. The list as of round 6, with line numbers and the other packages' tests: [map art shapes](map-art-shapes.md).
- **Code:** `Shapes.role()` already gives each tank its own role; rifle and rocket infantry, bulldozer and light vehicle split by faction. `_build_parts` reads the detail level only for the fallback shape; its cache is already keyed by detail. `WorldBatch.INFANTRY_ROLES` gives infantry their wide click box, so faction infantry roles must join it (a view test covers only the USA rifle). Palette: `OWNER_BASE`, `SIDE`, `SIDE_DARK` and the cliff factors in `ground_set`; the art lab's sand steps reuse `ground_set`.

Where the game differs from decided answers (inventory, 2026-11-13; none changed by this spike): selection is drawn green (`game/scripts/presentation/world_view.gd`), decided white; supply sources show two lines of text and construction a percentage, decided no text on the map; vehicle wrecks exist only in the art lab, and a death shows a dark ground patch that fades in two seconds, not a body that fades; a zoom step changes only the number of cylinder sides, decided one detail level per zoom step; big supply sources look the same from 40 to 400 boxes; salvage crates are a 4 px square.

Not tested: anything in the game, motion, effects, fog, a fight, the rendered benchmark, colour-vision deficiencies beyond a computed table on the page.

**Round 6 scope questionnaire** (user, 2026-11-17; 18 answers in five rounds, all as recommended; after an agent check of the map art against the decisions made since round 5; design: [map art round 6](../superpowers/specs/2026-11-17-map-art-round-6-design.md)). Nothing here starts a package or changes game code:
- **Round 6 is a consolidation with one short pick round,** against consolidation only, a wide prettiness round, and no round 6. Reason (agent): rounds 1 to 5 are page data never run in Godot, so more page picks are kept few.
- **Pick topics:** the supply pile pad with the Neon fix (F12); the map edge and canvas; the missing states (paused construction, vehicle wrecks, the low-power and dark-defence look of F21). Ground and decoration polish was not picked and stays with the map ports.
- **Files:** a trimmed, self-contained copy of the page and the picked data beside the pictures, as HUD v5 has; one export file of the picked shapes as expected values for the shape tests; one reference doc with a section per package (P2.4, P2.5, P2.6); the art bible rewritten as v2 with the decided rules.
- **Pictures:** all re-shot at 2x; the tank row gets the FRC correction, the zoom 2 versions on picked hulls stay P2.4's; the base scenes get the picked colours and no HUD layer; defences, the Laborer, the supply truck and rubble are checked beside the picked look, and only one that clearly clashes gets a pick step.
- **Later decisions drawn in:** one picture of the white map marks on sand and on the dark ground; the 2:1 unit shadow in the re-shot pictures; one reference picture that shows all five screenshot marks.
- **The capture script stays its own item, before P2.4,** outside round 6.
- **One palette step** for the pile pad, doors on side faces and building sides on the dark ground; the round 5 side band stands.
- **Art lab items stay in the art lab** (the occluded-unit cue F17, pale roof edges, the contact mark, the completion settle, dark ground on Ashfall, bar size); round 6 only lists them under their package.
- **Left with their packages:** the Power Plant drums (P2.6 rider) and the driving cues (P2.4 rider); that infantry do not show their faction at zoom 0.5 is accepted.
- **Judged as before:** a labelled A/B page of about five steps, opening on sand at zoom 0.5 with the lifted owner colours, the HUD v5 layer switchable.
- **The work runs on subagents** with model and effort chosen per task by the coordinator (user, 2026-11-17).
- After the design's builder check (user, 2026-11-17; four answers, as recommended): **one shared HUD file,** moved out of the HUD v5 page so the map page loads the same drawing, proven by re-making the 26 HUD pictures and `layout.json` without a difference; **the HUD v5 backdrops are re-made from the map art source after the picks,** and its pictures re-shot once; **round 6 runs before the P2.3a design,** which reads the map edge and the mark sizes from it; **for F21 the page picks a favourite and the art lab confirms it,** so F21 stays open after round 6.
- On the points the agent was least sure of (user, 2026-11-17; eight answers, seven as recommended): **the shape export is proven in the game's own bake by a headless round trip,** no game code changed, so the picked geometry is the first map art run in Godot; **paused construction and vehicle wrecks are drawn once and confirmed,** not put to an A/B, which leaves four A/B steps; **Neon is fixed, not dropped,** asked again because it is carried through every art package; **the round runs by day in one session,** against the recommended night run for the consolidation; **the art bible states rules in words and links to every number;** **it opens with round 6's gate reference picture,** the GPT north star moves to "Where it started"; **pictures are lossless WebP,** for an estimated 20 to 30 MB of repository growth (agent estimate from today's file sizes); **the glyph-size views are dropped from the page.**

**Round 6, consolidation and the open looks** (user, 2026-11-17; seven steps on the labelled page in `docs/images/map-art/source/`, opening on sand at zoom 0.5; five picks as recommended, paused confirmed, wrecks redrawn on request). Values, sizes and the tests each pick touches: [map art shapes](map-art-shapes.md); pictures: [map art](../images/map-art/notes.md). Nothing here starts a package or changes game code:
- **Dark surfaces A, framed openings and an earth pad:** each door keeps its dark slab inside a light steel frame (`#8098a5`; the China factory and Headquarters a top bar only), and the supply pile pad is the ground darkened 45 %. Picked against steel shutters and a slate pad. Building sides stay as round 5 picked them.
- **Map edge B:** a 24 px slate edge at zoom 1 on a near-black canvas `#08090A`, picked against a 12 px edge on the HUD's `well` colour.
- **No power A (F21):** a steady white bolt over each dark powered defence only, Zero Hour's rule in Wargrid's mark style; picked against small bolts on every slowed building as well. The art lab confirms it in the game, so F21 stays open.
- **Owner palette A:** `628ffa d6120c 4ad49b f8e425 0e92a7 7242fe ec8600 f79cef` (blue, red, green, gold, teal, purple, orange, pink; teal moves to slot 5 and orange to slot 7), replacing round 5's lifted set; picked against the same set with magenta as the eighth. One colour per player on every ground.
- **Cargo white `#ffffff`,** replacing round 3's pale steel, picked against ivory `#ffffe1`.
- **Paused construction, confirmed:** the four corner posts alone, round 3's rule as written, drawn for a USA factory beside an active site.
- **Vehicle wrecks, redrawn on request** after "change" with a reference picture (outside the repository): full hull volume, charcoal greys with face contrast instead of black, loose debris, a different break per wreck, no effects; accepted for now, then the FRC turret-off wreck had to show its fallen turret at every heading, accepted after the fix.

Decisions during the run (user, 2026-11-17):
- **Neon dropped,** reversing the scope answer "Neon is fixed, not dropped": the default palette passes colour vision on every owner pair, Neon fails three. Removing its menu toggle and code is a P2.4 rider; F12 closes as "Neon removed".
- The first-shoot proof baseline for three pictures whose committed captions were the fallback face is Arial (`&font=arial`, 0 px); the kept pictures stay Public Sans.
- The one failing round trip pose of today's game shapes (`frc_builder|0|2|24|24`, the Laborer at detail 2) is listed as failing and fixed by P2.4's eight-heading audit; the picked supply truck's pose was nudged in the candidate data.
- From the first page audit: owner colour in fog on sand is accepted; the side band against the HUD slab leaves the audit (a round 5 grid artefact no decision used); owner tops on the dark ground and cargo on sand (2.44) became pick steps.
- **The owner bar "top 3:1 against the ground" is replaced** after a research agent and the player-experience reviewer both advised it: side band against the ground at least 3:1, owner pairs at least 20 apart under the three simulations, and a colour-vision distance between owner tops and each ground; the coordinator set that floor at round 5's values for the round. The research found the old bar unreachable (only a near-black ground meets it) and not required by the guidelines it read for a game world (XAG 102 asks 3:1 for large elements but accepts that a game world will not always meet it); numbers in the [reference](map-art-shapes.md). With it: an opt-in friend/foe colour mode with colour-blind presets as a P2.4 rider; owner colours under fog for colour-blind players as an art lab item. Ground colours were allowed to change; a dark ground lifted to `#837d6d` failed six owner distances, so the dark ground stays `#7B7566`.
- The owner colours may be overhauled for the best combination, which turned the dark-ground step into the full palette step above.
- The HUD v5 proof after the re-shoot: every `layout.json` rectangle identical, the tokens differ only in `you` and `enemy` (palette A, lifted), and the top strip only inside the production bars. Palette A goes into the HUD v5 source.
- The shade of the 2.4:1 window bars against the canvas `#08090A` is picked by the P2.3a design; its token A/B also checks the owner colours against the cyan of the set that wins.

**Questionnaire after round 6** (user, 2026-11-17; three rounds):
- **P2.3a:** map edge B and canvas `#08090A` (fogged dark ground against the canvas 2.33, noted).
- **P2.4:** palette A, the Neon removal and the friend/foe mode; the China tank's two barrels further apart (the user, checking the final pictures: too close together; a small A/B when P2.4 is planned); tracks on tanks and wheels on wheeled vehicles in the same A/B (track band and wheel blocks at zoom 1, road and round wheels at zoom 2); pink sits 7.1 from the HUD cyan under simulated deuteranopia, accepted and checked in P2.4 with the colour-blind presets; the label "gold" stays (Zero Hour's `ColorGold`).
- **P2.5:** cargo white, the earth pile pad, and hiding the fixed footprint fill `#9f8045` the game paints under every supply source (`game/scripts/presentation/world_view.gd:473`), which showed as a gold rim on the dark ground.
- **P2.6:** building doors A; the paused construction look; the no-power look once the art lab confirms it.
- **Wrecks are their own small item after P2.4.** Their lifetime stays 20 s for tanks and 8 s for light vehicles, the inverse of Zero Hour's hulks ([verification](map-art-round-6-verification.md#b-vehicle-wrecks-hulks)), with the rule that a salvage crate draws above or beside a wreck: a crate drops at the wreck's cell and outlives it.

Agent assessment from round 6:
- The picked geometry is the first map art run in Godot: a headless round trip bakes the export with the game's `ShapeBake` and matches the page's triangles on 2208 poses, with the one listed failure. Colours, the edge, the bolt and the marks are page data; pixels, motion, the rendered benchmark and a Steam Deck were not run.
- Paused as posts alone costs a read: a site paused at 90 % looks just started, and an opponent no longer sees its progress, which Zero Hour shows ([verification](map-art-round-6-verification.md#c-construction-paused-part-way)).
- At zoom 0.5 a wreck reads as destroyed through the missing owner colour, the charcoal and the barrel off the axis; the debris is 1 to 2 px. The wreck top is 20.5 from palette A's teal (12.3 from round 5's teal, the set the audit line used).
- Cargo white is the map marks' white; shape tells them apart. The pile pad gives the salvage crate's drum its colour too, which nobody was asked about.
- Most mark line widths and sizes in the pictures are carried from the HUD v5 backdrops, not decided; the dashed target line's width and dash are an agent proposal, and the pictures draw health bars in the game's colours without the decided owner frame; the green-yellow-red fill and the owner frame are decided (HUD round, user, 2026-11-09), only which units show a bar goes to the P2.3a A/B (coordinator calls; the [reference](map-art-shapes.md) labels each size).
- A filled square on the "." key cap tripped the HUD page's 12 px text rule and was reverted; whether a bare "." reads is a P2.3a check.

## Movement design (P2.1 rider; user, 2026-11-14)

Questionnaire for the core movement (P5) and core avoidance (P6) design.

- **Core mesh width:** P5 uses one mesh at vehicle width (2 fine cells, one building cell), so tanks never clip corners; infantry lose gaps narrower than a tank until the size classes arrive in advanced movement.
- **Parked units and the search: two layers** (user, 2026-11-14, after a source reading of OpenRA, Warzone 2100, Recoil, 0 A.D., Permafrost and Zero Hour): the navmesh holds buildings only and never changes for units. Parked units are reference-counted per cell in the fine grid, and parked enemies and busy friends there are walls. When a mover's next straight stretch is blocked, a short search on that fine grid in a small window finds a detour (OpenRA's local search, 0 A.D.'s short-range pathfinder). This is how the 2026-11-13 "parked units block their cell for search" is met on a navmesh. Every navmesh or hierarchical engine read keeps its long-range layer blind to units (OpenRA `HierarchicalPathFinder.cs:82-89` @ `b4d95a5671`; 0 A.D. `template_unit.xml:50-51` @ `136720dada`; Recoil `GroundBlockingObjectMap.cpp:60-64` @ `a0240a9b5c`); only the grid engines Zero Hour and Permafrost put parked units into the main structure. Rejected: carving the mesh, and a per-rectangle cost for parked friends.
- **Step aside goes to P6** (user, 2026-11-14): in P5 movers only detour around parked units; asking or pushing a parked friend aside comes with P6's soft movers.
- **Toggle key: offline only** (user, 2026-11-14): the movement toggle key works in matches against the bot; online matches keep the old movement until the new one becomes the default. The switch is a local command in the offline command log (never sent to the relay), so a replay repeats every switch (agent, after the builder check).
- **Front-first goal layout in P5** (user, 2026-11-14): group goals are laid out so front units take the far slots, as Zero Hour (`AIGroup.cpp:480-514` @ `0a05454`) and as `s1` in the round 4 feel session; inside the toggle.
- **P5 performance gate: today's budgets** (user, 2026-11-14): with the toggle on, every benchmark row stays inside its current budget, plus one new row for a 300-unit order; a miss is recorded and stops for the user. P6 keeps its own +0.5 ms cap on top.
- **Mesh rebuild in P5: full rebuild** (user, 2026-11-14): a building placed or destroyed, or a supply pile removed, rebuilds the whole mesh (about 17 ms on the development Mac, about 90 ms projected for the browser: re-widen 7.7 ms plus build 9.1 ms, pathing timing spike part 4). One hiccup per change with the toggle on; P5's focus card says so. The local update (touched tiles plus reconnect, about 3 ms or less, upper bound) with a local-against-full equality test over random placements is the first advanced movement package and lands before the toggle becomes the default.
- **Infantry pass through infantry in P6** (user, 2026-11-14): the Zero Hour rule stays (`AIPathfind.h:51`); vehicles push and are pushed; soft spreading among infantry is an advanced item, measured against the cap first (hordes300 is all infantry).
- **Pushing only own and allied units** (user, 2026-11-14): enemies are solid to each other, a mover slides around an enemy and never shoves it (Recoil's default, `GroundMoveType.cpp:2923-2927` @ `a0240a9b5c`).
- **One toggle key, three states** (user, 2026-11-14): old movement, new movement, new movement plus avoidance, shown on the F3 overlay; offline only.
- **Last resort: about 5 s, friends only** (user, 2026-11-14, after a source reading of the same six engines: only Zero Hour and Warzone 2100 ghost on purpose, 0 A.D., Recoil and Permafrost give up or settle, OpenRA waits forever): after about 5 s with no progress towards the goal, own and allied units pass through each other until clear; enemies never ghost. A new route at 2 s blocked (Zero Hour, `AIStates.cpp:1821-1827` @ `0a05454`). Settles round 4 open question 1 (5 s against 1 s) and the "about 5 s" answer of 2026-11-09 for soft movers.
- **Near the goal: squeeze-in only** (user, 2026-11-14): the decided squeeze-in within one cell stays; no Permafrost-style settle; "near enough" remains only the decided fallback for a cap miss.
- **Advanced packages cut** (user, 2026-11-14), each 2 to 3 days, staying in Later 2 and 4 and ordered after P6's playtest: movement (Later 2) 1 local mesh update with the local-against-full equality test, 2 three size classes, 3 shared searches and trunks or flow fields for big orders (only if P5 measures jams or cost; dropped otherwise), 4 formations and keep formation (after order controls), 5 the movement toggle becomes the default, online included, one trace re-pin, then the golden scenarios with browser digests; avoidance (Later 4) 1 pressure tuning and arrival spreading, 2 crusher rules with the mixed-owner scenario, 3 soft spreading among infantry measured against the cap plus the round 2 open questions, 4 the avoidance toggle becomes the default, one trace re-pin. Names are proposals (agent) under the wording rule.
- **P5 unsticks parked-friend blocks with the 5 s pass-through** (user, 2026-11-14, after the builder check found that a parked friend in a one-vehicle corridor would block a P5 mover forever): the decided last resort (about 5 s without progress, own and allied only) lands in P5 for parked friends; P6 extends it to moving friends and adds step aside before it.
- **P5 gate for rows already over budget: no worse than old** (user, 2026-11-14): rows inside their budget stay inside it; rows already exceeded (combat open, dense, hordes300; F13) must not get worse than the old movement on the same tree (median of 3), the gap reported; budgets never loosened.
- **P5 size: the plan decides** (user, 2026-11-14): if the P5 plan sizes it over 3 days, it splits into P5a (mesh, search, lab, plain moves) and P5b (supply, docks, combat and construction on the new grid).
- **Vehicles and infantry push each other in P6** (agent's call, confirmed by the user 2026-11-14).
- **Design approved** (user, 2026-11-14): [core movement and core avoidance design](../superpowers/specs/2026-11-14-movement-core-design.md).

## Visual and UX proposal review (user, 2026-11-15)

Questionnaire on an agent investigation of the look and UX (`wargrid-visual-ux-improvement.md`, private). Most of it restated decisions above; only the new points were asked. The investigation stays private; these answers are its only repository record.

- **HUD colours: A/B in the P2.3a design** (user, 2026-11-15): the HUD v4 mock-up tokens (`FLAT` in the round 3b page: bg `#121c24`, panel `#1b2731`, button `#223241`, line `#2e3f4b`, text `#eef3f5`, muted `#93a5b0`, selected `#60e5ed`) against the investigation's near-identical set (bg `#111c24`, slab `#172731`, control `#223640`, text `#f1f5f7` / `#b7c4cc`, muted `#96a5ae`, divider `#40535d`, selected `#67deeb`), compared in Godot with Public Sans before dock colours are fixed.
- **Dividers are decoration** (user, 2026-11-15): group lines need no contrast minimum (the mock-up line is 1.4:1, the proposed divider 1.9:1 on its slab); groups are told apart by spacing. Text keeps 4.5:1, focus and selected outlines 3:1.
- **Power reads used / available** (user, 2026-11-15): "Power 8/10", forecast "8/10 → 11/10 · Low power"; today's HUD prints supply / demand, so the order flips in P2.3a with a test.
- **No selection overflow code** (user, 2026-11-15): each faction has about 6 unit kinds and the two-column rows hold about 8; P2.3a's headless layout test asserts that the largest roster's selection fits, so a larger roster fails it instead of clipping.
- **HUD cyan stays, Neon teal moves** (user, 2026-11-15): Neon's `#00d8e8` is 1.1 to 1.2:1 against either HUD cyan; fixed in P2.4's palette commit with the rest of F12.
- **Cell card opens after 250 ms** (user, 2026-11-15): P2.3b's cost, shortfall and forecast card opens after 250 ms hover, switches at once between cells and closes on click; the playtest card asks whether it feels slow.
- **Combat effect tuning later** (user, 2026-11-15): shorter muzzle and hit effects, rifle against shell differences and recoil wait for an optional combat polish package after measured headroom; none in P2.4 to P2.6.
- **No recognition study** (user, 2026-11-15): art packages use their playtest card questions and the user's own blind look at a screenshot sheet; the proposed multi-participant protocol is dropped.
- **Interaction experiments parked** (user, 2026-11-15): consequence preview, grouped alerts, selection lens, production workload and order intent are recorded as later ideas in [UX experiments](../questions/later-ux-experiments.md); a command wheel and formation-shaped drag are rejected for the current roadmap.

## Visual and UX proposal, second pass (user, 2026-11-15)

Questionnaire on a second agent investigation of the look and UX (`wargrid-visual-ux-improvement-r2.md`, private), 27 questions in seven rounds. The investigation stays private; these answers are its only repository record. Nothing here starts a package; where each answer lands is in the [package notes](../packages.md#package-notes).

Health bars and selection:

- **Proposed: healthy units show no health bar, selected or not** (user, 2026-11-15): only damaged units show one; still no setting. Decided in an art lab A/B first (follow-up round below), so the "selected or damaged" rule in [HUD](#hud-m76) stands until then. Zero Hour goes the other way (selected or hovered, never a damaged unselected unit; `GeneralsMD/Code/GameEngine/Source/GameClient/Drawable.cpp:3783-3784`, `~/projects/GeneralsGameCode` @ `afc2a103f`). Beyond All Reason hides bars at 99 % health and above (`~/projects/Beyond-All-Reason`, `luaui/Widgets/gui_healthbars_gl4.lua:235`, revision `a31aa1c194`). The selection panel keeps showing health.
- **The unit under the mouse still shows its bar** (user, 2026-11-15), healthy or not.
- **Bar size at the farthest zoom: art lab toggle first** (user, 2026-11-15): 24x3 against 16x2 px on a damaged army.
- **Box selection that skips workers: decided later** (user, 2026-11-15): asked again once the drag shows what it will select; recorded in [UX experiments](../questions/later-ux-experiments.md).

Marks on the map (white with a dark under-stroke, told apart by shape; the selection mark was already white):

- **Attack target: a white X** (user, 2026-11-15), in place of the red box (`#ff3b30` is 1.13:1 on sand, and red is an owner colour).
- **Placement cells: valid a white outline, blocked an outline with an X** (user, 2026-11-15), in place of the green and red fills.
- **Move confirmation: a ring closing onto the point in 0.4 s** (user, 2026-11-15), in place of the ring growing for 1.3 s.
- **Range ring while placing or hovering a defence: yes, if the range can be read without a simulation change** (user, 2026-11-15); the data check comes first. This reopens the item left out of HUD round 2.

The world:

- **The map gets an edge** (user, 2026-11-15): slate side faces along the camera-facing map edges and the dark canvas colour beyond, so the map reads as a slab; no lit line on its top edge.
- **Contact mark under infantry: looked at again after P2.4** (user, 2026-11-15): an art lab comparison at the farthest zoom once the darker sides are in the game; the round 5 pick stands until then.
- **Pale roof edges on buildings: art lab toggle with P2.6** (user, 2026-11-15): buildings only, never units.
- **Dark ground on Ashfall: art lab toggle** (user, 2026-11-15): a look to judge, not a change.

Into and out of a match:

- **Intro band at every match start** (user, 2026-11-15): about 1.5 s under the top strip with the map name and each player's colour swatch, emblem and name; keys and clicks pass through to the game and dismiss it; skipped on a rematch. Drawing only, no delayed start.
- **Result panel** (user, 2026-11-15): outcome, match length, units built, units lost, buildings lost, Play again and Change setup (back to the Play page with the picks kept). The counts are tallied by the drawing side, no simulation change.
- **M9 lobby: a Play-page candidate on the A/B pages** (user, 2026-11-15), beside the lobby mock-up's layout: player rows in two teams on the launcher's Play page.
- **Own web loading page** (user, 2026-11-15): canvas colour, logo and a plain progress bar in place of the engine's default loader.

Playing at your own speed (bot matches only):

- **Think pause** (user, 2026-11-15): a key stops the simulation while camera, selection and orders stay live; orders run on resume. Approved after a cost check from the code: the pause gate (`game/scripts/match/match_screen.gd:180` at `8ee007a`) and order submission (`game/scripts/match/offline_driver.gd:40-50` at `8ee007a`) exist, no simulation change; the effort is an audit of the same-tick test cases, because every order given during a pause lands on one tick. Not prototyped.
- **Pause key: P** (user, 2026-11-15); Space stays the jump to the last alert.
- **Slower speeds: 0.5x, 0.75x and 1x** (user, 2026-11-15), in one package with the think pause (name proposed by the agent: Play at your own speed).
- **One tip on the result panel** (user, 2026-11-15): one line from what the player did not use in that match; never during play; tried as an experiment first.

Interface size, pointers, groups:

- **Larger interface option: 100 %, 115 %, 130 %** (user, 2026-11-15): a multiplier on the window scaling, never smaller. The HUD still scales with the window and there is still no pixel-size mode.
- **Pointers: attack-move first, the rest later** (user, 2026-11-15): P2.3b shows its own pointer while attack-move is armed; the full set (move, attack, gather, rally, blocked) is its own later package and needs a read-only "what would this click do" function first.
- **A factory can feed a control group** (user, 2026-11-15): a "Feeds group" control on the selected factory's panel; its units join the group when they leave the factory. Drawing-side state only; with order controls.

What comes first:

- **Capture script first** (user, 2026-11-15): one command renders each launcher page and a fixed match scene to image files, no visible window, no sound, so every later look change has a before and an after.
- **Steam Deck controls spike after P2.3b** (user, 2026-11-15), moved up from after P3: findings and a proposal, no implementation.

Follow-up round on the second pass (user, 2026-11-15; a fresh review of the investigation and of the answers above, 16 questions in four rounds, recommendations unless noted):

- **Health bars: art lab A/B before P2.3a builds the rule** (user, 2026-11-15, against the recommendation to keep the new rule as answered): three rules on the same damaged 120-unit army: selected or hovered (Zero Hour), selected, damaged or hovered (today), damaged or hovered (the answer above).
- **P2.3a's gate adds a damaged-army row** (user, 2026-11-15) beside the 120-unit selection, so the gate does not get cheaper when healthy units lose their bars while a fight costs the same.
- **Riders go into the package rows** (user, 2026-11-15), as the first review's did, not only into a package note.
- **Range ring while placing a defence, in P2.3b; the ring on hovering a defence follows later** (user, 2026-11-15): weapon ranges are static definitions data (`game/scripts/simulation/definitions/shared.gd`) that the match code already preloads (`game/scripts/match/orders.gd:5` at `8ee007a`), so the "no simulation change" condition above holds.
- **Launcher keyboard and target fixes in P2.2** (user, 2026-11-15): Enter submits the join code, each page's primary button has default focus so Enter starts a bot match, a keyboard focus outline that differs from hover, click targets of at least 32 px, the Tag at 12 px instead of 10 px, Quit in the sidebar on desktop.
- **While connecting: elapsed time and Cancel, in P2.2** (user, 2026-11-15): Cancel returns to the page with the picks kept and leaves no half-open relay session; the desktop invite field is labelled as a match code unless a web address is configured.
- **One theme for launcher and match with one type scale, in P2.3a** (user, 2026-11-15): one theme file, 12 px floor everywhere (the HUD's 11 px caption becomes 12 px), one value size picked in the P2.3a A/B.
- **Key chips print the keyboard layout's own label, in P2.3b** (user, 2026-11-15): keys stay bound by physical position; QWERTY letters where the platform cannot answer; the web behaviour joins the web hotkey check.
- **Unit shadows drawn 2:1, with P2.4** (user, 2026-11-15): like every other ground shape; size, darkness and High-only unchanged.
- **Completion settle and a producing roof inset: art lab toggle with P2.6** (user, 2026-11-15): buildings only, judged by looking like the roof edges.
- **No red applies to the match only** (user, 2026-11-15): the launcher's red-brown error chip stays.
- **Larger interface: a factor is offered only where the HUD fits** (user, 2026-11-15): at 130 % a 1280x720 window leaves about 985x554 layout pixels; layout tests decide per window size.
- **0.75x stays, looked at first** (user, 2026-11-15): it steps on 3 of 4 frames, so the package checks the cadence on High and on Low (no interpolation) before promising it.
- **Capture script: probe a hidden path first, then ask** (user, 2026-11-15): headless uses a dummy renderer and an off-screen `--position` was clamped back on screen ([perf chart spike](perf-chart-spike.md)); if no path stays hidden, stop and ask before any visible window. The same tool serves How Wargrid got its look.

Remaining points of the second pass (user, 2026-11-15; 20 questions in five rounds, recommendations throughout):

- **Five screenshot marks as the review checklist** for every art and HUD package (user, 2026-11-15), as a gate in the [art bible](../art-direction/ART_DIRECTION.md#11-acceptance-gates); the investigation's "three planes" idea is not adopted as a rule.
- **Amber means "act here"** (user, 2026-11-15): never decoration, at most one amber button per screen, in the launcher and in the match.
- **Two live alert causes: left to the alerts package** (user, 2026-11-15); "newest plus a count, never stacked" is input to it, not a decision.
- **No spoken line without visible text, and a refused order sounds different from an accepted one** (user, 2026-11-15): rules for the alerts package.
- **Four motion durations** (user, 2026-11-15): 90, 150, 250 and 400 ms as shared constants, progress always linear, nothing loops unless work is ongoing; added with the first animation, not before.
- **Reduce motion setting with the intro band** (user, 2026-11-15): all durations to zero, progress bars stay.
- **Turret angles blended in P4, eased zoom steps in P3** (user, 2026-11-15): 150 ms toward the cursor with the detail swap at the midpoint; eased steps, not free zoom.
- **One look from menu to match: a new package, not ordered, after P2.3b** (user, 2026-11-15; name proposed by the agent): the fancy launcher values through the shared theme, a darker base under the one primary button, the map preview and the intro band.
- **One map drawing, launcher first** (user, 2026-11-15): a reusable control draws the map's ground as the launcher's map preview, later the minimap's base layer; fog, pings, the view rectangle and click-to-jump stay the minimap's work.
- **The intro band is skipped on rematch and on the offline Restart** (user, 2026-11-15).
- **Orders given during a think pause show their confirmation on wall time** (user, 2026-11-15); combat effects stay frozen.
- **Click selection priority in P2.3a** (user, 2026-11-15): units, then buildings, then supply piles, then ground, written down and tested.
- **P2.3b's design holds a grid table across factions** (user, 2026-11-15): the same slot means the same kind of thing for all three where the rosters allow.
- **Theme rules with P2.3a** (user, 2026-11-15): spacing 4, 8, 12, 16, 24, 36, snapped where a file is touched; square corners in the match, at most 2 px in the launcher; no drop shadows on panels.
- **P3 camera limits: about a quarter screen of dark canvas past the map edge** (user, 2026-11-15).
- **Own outline at far zoom, known threat areas, a match timeline and a Spread order are parked** (user, 2026-11-15) in [UX experiments](../questions/later-ux-experiments.md) with their prerequisites.
- **Repeat production is a design question for the M9 balance revisit** (user, 2026-11-15), not an interface proposal: it is a new simulation command and changes Zero Hour's economy rhythm.
- **M9 lobby: the host may change the map with friends in the room, and every ready mark resets** (user, 2026-11-15), as Zero Hour (`GeneralsMD/Code/GameEngine/Source/GameClient/GUI/GUICallbacks/Menus/WOLMapSelectMenu.cpp:453`, `~/projects/GeneralsGameCode` @ `afc2a103f`).
- **3v3 friend or foe is a requirement of the M9 lobby and minimap designs** (user, 2026-11-15): how marks, the minimap and the intro band show teams is drawn there before six owner colours meet on one screen.
- **The joiner seeing the host's map and faction before the start is an M9 lobby question** (user, 2026-11-15): the relay may not carry it before the start.
- **Key rebinding: a later package of its own; the full pointer set starts with its read-only "what would this click do" function and a check of a 64 px cursor in browsers and on the Deck trackpad** (user, 2026-11-15).

Last points of the second pass (user, 2026-11-15; 11 questions in three rounds, recommendations throughout):

- **Hover shows four white corner ticks of the selection diamond, in P2.3a** (user, 2026-11-15); the same ticks preview what a drag box will select, which the parked box filter waits for.
- **Rally point as a short pole with a square flag, with a line from its factory while the factory is selected, and a dashed white line for battery and defence targets, in P2.3a** (user, 2026-11-15): the last red leaves the map.
- **An idle builder or collector gets two short white bars on the ground after 8 s, with order controls** (user, 2026-11-15), beside the idle builder button. For the factory that feeds a group, entities carry no producing-factory id (the entity record, `game/scripts/simulation/simulation.gd:101` at `8ee007a`, has none; `game/scripts/simulation/definitions/definitions.gd:90` at `8ee007a` holds the building kind only), so the drawing side infers it from a queue item finishing as a new unit appears beside that factory.
- **Marks on a unit draw above the pieces, marks on a place under them** (user, 2026-11-15); place marks move under only when one looks wrong on top, measured; P2.3b's range ring is the first candidate.
- **Tooltip rules from P2.3b's cell card on** (user, 2026-11-15): open after 250 ms, switch at once between neighbours, close on click or when the pointer leaves, never cover their control, never hold what the player needs to act; content is name, one line, numbers.
- **"Something finished" events are input to the alerts package** (user, 2026-11-15): building complete, unit ready and friend joined get a short sound and the piece's own settle, no chip; chips stay for things to act on now.
- **Weapon families: input to the optional combat polish package** (user, 2026-11-15): told apart by geometry and timing, not hue (owner colours take the hues): a ballistic streak already at the target (cannon thicker, the rotary gun as three streaks), a rocket that travels with a fading trail, a flame fan that persists while firing, a beam if lasers ever exist; warm white cores and orange explosive results only.
- **No spectator or replay interface work until observers exist** (user, 2026-11-15).
- **Enter on the result panel is Play again, in P2.2** (user, 2026-11-15).

## General's powers light (user, 2026-11-15)

Zero Hour's promotion screens per faction (`data\ini\commandset.ini:1251-1327`, sciences in `data\ini\science.ini`) sorted by what each pick needs. Recommendations throughout.

- **A light package after ground batch A** (user, 2026-11-15; name proposed by the agent): player rank from kills, points and the promotion picks; by then every rank-1 pick exists.
- **Its picks** (user, 2026-11-15): Emergency Repair for all three factions; China's Artillery Barrage, Cash Hack and Frenzy; the FRC's Rebel Ambush (4 rebels, `data\ini\objectcreationlist.ini:4594`) and Cash Bounty; the rank-1 unlocks (Paladin, Nuke Cannon, Scud Launcher, Marauder, gated by rank again, ending the departure in the blueprint's batch A) and the veteran-start trainings.
- **Later, with what they need:** powers delivered by aircraft (Paradrop, A-10 strike, Daisy Cutter, MOAB, Leaflet Drop, Spectre, Carpet Bomb, EMP Pulse, Anthrax Bomb), the aircraft picks (Stealth Fighter, Spy Drone), and the batch B ones (Pathfinder, GPS Scrambler, Cluster Mines, Hijacker, Sneak Attack).
- **USA gets only Emergency Repair at rank 3 in the light package** (user, 2026-11-15): accepted for offline and bot play; noted for the multiplayer balance revisit with M9.
- **Bots buy and use the light powers in the same package** (user, 2026-11-15): a fixed pick order and simple rules (area powers at the largest enemy group), each with a spec-worded test.

## Pre-research follow-ups: converter drops, Defcon6, web timing (user, 2026-11-15)

Questionnaire on the Flatter worst ticks night's pre-research (22 questions, merged into 15 decisions, recommendations throughout; reports private, `~/projects/wargrid-overnight-work/flatter-worst-ticks/backups/pre-research/`).

- **Converter reports what it drops** (user, 2026-11-15): a fourth stdout table "skipped objects: template, count", sorted by count; roads collapse into one `road pieces N` line and non-start waypoints into `waypoints N`; bridge-flagged objects (flag 0x30) are marked `bridge`. A dropped bridge is a warning line, not a failure. Map JSON stays byte-identical; one test. The skip list per converted map goes into `docs/reference/more-maps.md`, one line per map.
- **Oil derricks first, then the decorations** (user, 2026-11-15, with the inbox item of the same day): the first tech building to add (capture, income); the other capturable buildings are not important. The importer also brings in decorations such as trees, with an art pass for them and a re-import of the maps. Listed in [packages](../packages.md), no design yet.
- **Civilian buildings and walls as pathing obstacles: listed, after P5 and P6** (user, 2026-11-15), since they touch pathing.
- **Defcon6 accepted as it is** (user, 2026-11-15): "buildable cells within 12" (625 is the size of the 25 x 25 window) stays a report-only hint, no gate; seats 5 and 6 at 620 and 617 are fine because every building slot is placed. Source cells are not subtracted. Defcon6's docks, about 7 cells from the starts, stay as in Zero Hour. Measuring supply distance to the source centre instead of its corner: later, as its own small change. Defcon6 is converted after the M9 start-spot rule.
- **Web WebSocket timing: one Mac check** (user, 2026-11-15): two Firefox windows side by side, local relay, timestamp prints (about 15 min, a visible window), with delay thresholds of send p95 5 ms (or clusters near 40 or 200 ms) and receive p95 50 ms; the web clock is ms resolution; the Deck over LAN only if the Mac shows something; Chromium is not measured. It joins the window batch after the worker thread A/B and the old-tag screenshots. One citation line (`emws_peer.cpp:126`) joins the Relay guards plan's Task 4 when that plan is rebased on P2.2.
  Run 2026-11-15 evening (Firefox, two windows, scratch tree `5847e15` with timestamp prints): the launcher accepts only `wss://` relay links (`join_link.gd` `relay`), so both windows used the live relay instead of the local one and the per-leg split (send to relay, relay to receive) was not measured. End to end, one window's send to the other's receive through the live relay: 12,523 pairs, p50 18 ms, p95 35 ms, p99 46 ms, one outlier of 314 ms; no clusters near 40 or 200 ms. **Closed: no send delay found** (user, 2026-11-15); the per-leg split stays unmeasured.

## Worker thread A/B and the sim boundary (user, 2026-11-15)

After the worker thread spike: the attended Mac Firefox A/B gave PARK (team gain 1.56 ms against threaded inline, late 2.68 ms, skirmish3v3 none); the Steam Deck Firefox rows (2 runs per arm, report-only) show team missed frames 49 % inline against 0 % in worker mode, with the worker job at 26.8 ms p95 of a 33.3 ms tick; Safari 27.2 booted the real threaded match scene (6 runs, digests equal); a native Deck profile of the team window puts the step's p95 in bot decision ticks and combat planning, with snapshot plus digest every 30th tick at 7.7 ms native. Evidence outside the repository (`~/projects/wargrid-overnight-work/worker-threads/`); an independent review and two design agents advised (reports in the same folder).

- **Not parked: the sim boundary comes next in the night lane** (user, 2026-11-15): the inline `SimPump` seam as night packages right after P2.2, before the P2.3a plan, instead of Later 3, so later packages build on the published view. The worker thread is wanted in production (user, 2026-11-15); it follows behind an off-by-default flag once the Deck decides.
- **Published result: a slot pool plus an event queue** (user, 2026-11-15): state in reused, tick-stamped slots (four with a previous and a current slot for interpolation; P4 decides between four slots and copying the interpolated fields), events and command results in a queue the main thread drains, since per-tick events cannot be latest-wins.
- **First seam task: reads on request** (user, 2026-11-15, corrected the same day): the per-input `snapshot()` reads in `orders.gd` and the one per offline command; the earlier "snapshot and digest only when read" rested on the spike's own cadence, not `main`'s. The rest of the boundary design and its answers: [Sim boundary design](../superpowers/specs/2026-11-15-sim-boundary-design.md).
- **The go rule decides on the Steam Deck** (user, 2026-11-15): Deck Firefox with at least 3 runs per arm as the decision row; `backlog_max` at most 2 (the queue cap); `tick_rate` at least 29.7; the tick-rate floor gets a tolerance and a test (today 29.9999 against 30.0001 fails).
- **Hosting headers are not a risk** (user, 2026-11-15): both web apps are our own; still open before the thread goes on: a mixed online match in worker mode and a fault probe in a release web build.
- **Parked with the worker thread: a background job with a fixed join tick** (user, 2026-11-16, backlog review; idea from the 2026-11-14 OpenTTD research, private): every machine starts a long computation (path burst, bot planning) at tick T on a worker on a copy of its input and joins it at a fixed T+k (OpenTTD link graph, `src/linkgraph/linkgraphschedule.cpp:33-81` @ `de9df409a7`); costs a threaded export, the job in the snapshot, and a slow device stalls everyone at the join. Revive only if the worker thread comes back.

## Cheaper step (user, 2026-11-15)

After the Deck profile of the team window (native, 3 runs: step p50 6.7 ms, p95 12.5 ms with bots; movement about 37 % and combat planning about 36 % of the step) and a research pass (Grok, `~/projects/wargrid-overnight-work/step-cost/research.md`, estimates not measurements):

- **A night package "Cheaper step" after the Sim boundary, before P5** (user, 2026-11-15; name proposed by the agent): four experiments, each measured on the Steam Deck (three runs, digests equal) and kept only on a measured gain: combat planning skips units whose cell, orders and targets did not change (estimate 0.5 to 1.2 ms native); an incremental target grid (lever F, 0.3 to 0.45 ms); active id lists for movers, collectors, salvagers and units due to fire (0.5 to 0.9 ms); bot decisions without the per-unit copy (1 to 3 ms off decision ticks).
- **Fork-join (lever I) becomes a native-only option** (user, 2026-11-15): GDScript group tasks are expected to gain nothing (Godot issue #117640, the `WorkerThreadPool` small-task warning); a GDScript group task over movement stays only as a kill-test after packed movement columns exist.

## Quick rematch slice 1 questionnaires (user, 2026-11-15)

Confirmed calls in the [design](../superpowers/specs/2026-11-15-p2.2-quick-rematch-design.md); the [plan](../superpowers/plans/2026-11-15-p2.2-quick-rematch-slice-1.md) carries the details.

- The relay reuses the room for a rematch: two client messages, `over` and `again`, and a relay `again` with `seat`; the wire change was approved as such, protocol number stays 2 (user, 2026-11-15).
- One `WARGRID_LOBBY_MS` (15 min) covers the lobby expiry, the start window before a seat's first tick and the park limit (user, 2026-11-15).
- Hello deadline 5 s; the 10 s silence rule stays for running matches (user, 2026-11-15).
- Esc cancels only while connecting; the Waiting page keeps its Cancel button (user, 2026-11-15).
- Slice 1 has no stats on the result panel and no protocol pings; the panel shows the outcome, Play again and Change setup (user, 2026-11-15).
- Shipped wording that the user may change at the playtest (agent): "The room closed", "Connecting… N s", "closes in M:SS".

## Result panel A/B (user, 2026-11-15)

After the P2.2 playtest; four variants from an art and UX review (private, `~/projects/wargrid-overnight-work/p2.2-rematch/result-panel-variants.md`) compared on a browser A/B page.

- **P2.2 ships variant A** (user, 2026-11-15): the card fixed, opaque `#2a2a2a` with a 1 px `#808080` border, 24 px padding, 30 px ExtraBold outcome, 144x36 buttons 12 px apart and centred, black 60 % dim; a waiting Play again turns grey (`#666a6c`) instead of a dead amber.
- **The status row is always reserved**, offline too, so the card keeps one height in every state (user, 2026-11-15).
- **Labels stay "Play again" and "Back to menu"** (user, 2026-11-15); "Back to menu" replaced "Change setup", which was confusing; "Rematch" and "Leave" were compared and not taken.
- **Target look for slice 2 and P2.3a: variant B, the match slab** (square, HUD v4 tokens, a 4 px edge in the winner's colour, stats as 2x2 rows, black 40 % dim), **with the buttons centred** instead of bottom right (user, 2026-11-15); built with the stats in slice 2 on P2.3a's shared theme variations, not as overrides in the panel.

## Relay guards questionnaire (user, 2026-11-15)

The plan was rebased onto `main` `ee2f353` after P2.2 (private, `~/projects/wargrid-overnight-work/flatter-worst-ticks/backups/relay-guards-plan/plan-rebased.md`, 19 collisions handled); 29 questions, all answered as recommended except Q10.

- **Lead bound:** maximum delay 4 as its own constant (Q1); refused with the new reason `too far ahead` (Q2); the existing conformance case `start_window_ends` gets seat 2 sending ticks 4 to 8 then pings (Q28).
- **Hash comparison:** only the hash honest clients send per tick is recorded, cleared at every leave and rematch (Q3); `DESYNC` logged at the first mismatch per room, plus fields in `MATCH END` (Q4); the hash field is added to the three Go tests that build tick messages positionally (Q29).
- **`MATCH END`:** room-wide maxima `seatN_max_frame` and `seatN_peak_bps` next to today's counts (Q5), peak per fixed one-second window (Q6).
- **Limits:** per-IP rules off without a configured header (Q7); `Fly-Client-IP` on fly (Q8); IPv6 keyed by /64 (Q9); **16 sockets per address** (Q10, against the recommended 8, for shared addresses); joins burst 10 then 1 per second per address (Q11); global join bucket a fixed production value, burst 20 and refill 20 per second, with the conformance suite pacing its hellos or using a test-only override so suite growth never moves the production limit (Q12, revised after an independent review the same day); an empty unknown-match bucket closes without a reply (Q13); a 4096-entry table that reclaims idle entries, else `relay busy` (Q14); refused after the upgrade with a reason (Q15); a request without the header skips per-IP rules (Q26); the header reaches `fly.toml` with the approved deploy that checks a forged header is overwritten (Q27, Q22).
- **Players and client:** reasons shown as `Relay: <reason>` and explained in the player docs (Q16); an order that would push a frame past 64 KiB is refused with a HUD note and the reject sound (Q17); the headless client keeps the plain 5 s silence rule (Q30).
- **Batch size guard** (user, 2026-11-15, after the review): with `WARGRID_BATCH_MS` on, the relay joins the other seats' frames into one message (`sender.go`), and five full 64 KiB frames in a 3v3 exceed the client's 128 KiB receive buffer (`relay_transport.gd` `BUFFER_BYTES`); Relay guards adds a guard (cap the batch below the client buffer, or flush early) with a test.
- **Review notes:** Q10's 16 also covers M9 seat resume and a LAN party; Q26 and Q22 follow it (the forged-header check needs 17 sockets).
- **Proxy and CI:** faults hold, slice, reset and blackhole only (Q19); `go vet`, `go test -race` and golangci-lint for the proxy (Q20); the extra netplay scenarios join CI if the job stays under 20 minutes, else `spike` on Linux only (Q21); no `NETCLIENT WAITS` line, one proxy process per seat (Q23, Q25); a fresh proposed night-settings copy for the run (Q24).
- **Readiness round (user, 2026-11-16):** plan rebased onto `main` `52017fd` (private, `~/projects/wargrid-overnight-work/relay-guards/plan/`) and reviewed again; three new questions, all answered as recommended: the batch size guard flushes early before a joined message would pass 65,536 bytes, the relay's frame cap (Q31); the conformance suite paces its dials 50 ms apart so it stays under the fixed global burst, no test-only relay setting (Q32); a refused flood of orders keeps the shared prefix, "Rejected: Too many orders at once; wait a moment" (Q33). Discussion round the same day: a seat the relay throws out in a 1v1 gives the other player the opponent-left Victory, and P7's result panel says why; the batch size guard stays in Relay guards although the client still cannot split joined frames; the package moves to between P12 and P2.3a while its plan is fresh; the acknowledgement voice before a refusal becomes F29, a rider on P2.3a.

## Player-experience review (user, 2026-11-16)

First full review by the [player-experience reviewer](../../.claude/agents/player-experience-reviewer.md) (docs, UI code, mock-ups, a render of `main` 36aa180):

- **Command card:** StarCraft II style (fixed command cells, buildings behind one build key in a sub-grid), because the 3-row grid put the 5th build cell on A, Attack Move ([blueprint Controls](../blueprint.md#controls-small-task-after-converted-maps-user-2026-11-08-not-designed), P2.3b in [packages](../packages.md)).
- **Order:** P2.2 slice 2 stays before P2.3a, although the shipped HUD is still a debug readout (raw ids, `Tick`, `#id`); P2.3a follows it.
- **Pan while placing:** rider in P3.
- **Opponent left mid-match:** [F27](../STATUS.md#findings-list), fixed in P2.2 slice 2.
- **Missing prerequisite by name:** rider on P2.3b's card (pulls that slice of the Order controls rider earlier).
- **P3 before the art packages?** Decided by a timed Ashfall playtest ("watch your army fight, then queue a unit at base"); if it hurts, P3 and control groups move right after P2.3b.

## Online teams refinement (user, 2026-11-16)

Questionnaire that split M9 into packages; record and gates in the [online teams design](../superpowers/specs/2026-11-16-online-teams-design.md), placement in [packages](../packages.md). The bot restructuring notes from 2026-11-15 (private) were treated as proposals; only the answers below are decisions.

- **Goal:** friends play together online soon; polish and hardening follow in later packages.
- **First release:** friends against bots, at least you and one friend: 2v2, two friends against two bots, with today's bot; online team play does not wait for the M8 bot, fog, the ground batches, movement or art. Offline team matches (you and an allied bot against two bots) ship in the same package.
- **Setup:** the host picks the map and each bot's faction before Create match, the match starts when everyone has joined (no ready step until the ready room); only maps with at least as many starts as seats (Dry Wells hidden for 2v2); teammates start on neighbouring spots ([lobby questions](../questions/next-m9-lobby.md) Q1 b); a plain version-mismatch message, its wording and look picked on a short A/B.
- **Bots online:** the host's game runs the bots and sends their orders inside its own frames (OpenRA's model, `OpenRA.Game/Player.cs:216-224` @ `b4d95a5671`); when the host leaves, the lowest remaining seat takes them over (with drop recovery). Idea for a later, much stronger bot (user, 2026-11-16, not decided): a hidden server seat that runs the AI, evaluated at M8 planning.
- **Leaving and drops:** a teammate who quits or drops for good ends the match with a clear result panel in the first release; later their units, buildings and money go to a teammate, also when a dropped player's 60 s grace runs out ([dropped players](../questions/next-m9-drops.md) Q2 a, Q4 c, Q5 a). A defeated teammate keeps watching and may leave without ending the match. A dropped player: the game freezes with "Waiting for <player>" and a countdown, as Zero Hour and lockstep games do (Q1 a), and resumes when they return; short drops and relay restarts recover in one package before 3v3 (relay restarts superseded the same day, see "Relay availability questionnaire" below); peer quality notice with it. A brief hiccup in the first release behaves as 1v1 today.
- **Order:** 2v2 co-op after P2.3a (the agent recommended right after P2.2); a night that lets a match continue after a leave comes first; then drop recovery and Three friends after P2.3b, before core movement; teammate takeover right after 3v3; the ready room after P6 (agent placement, approved with the arrangement), humans on both sides with it. Before 3v3: Relay guards, Adaptive input delay (its experiment run; adoption still only on a measured gain), fewer relay frames with machine sizing, relay restart recovery (superseded the same day, see "Relay availability questionnaire" below). Not needed for 3v3: match history, accounts, chat, public match list.
- **Gates:** the first release passes with native Mac and Firefox in a real friend session (Safari and Chrome report-only); the 3v3 gate needs Mac rows, Steam Deck report-only.
- **Lobby backend:** option B stays the direction; the ready-room package compares it with the relay-only option A.
- **Bots:** the bot attack test compares stock, gate and commit (0 A.D. Petra's commit-and-escalate) and ships a rule only if it wins both columns: every seat damages an enemy building where stock fails, and rows that end today still end; the leave night comes before it. No separate bot read function now: the fog package filters `bot_state()`. The other spikes from the 2026-11-15 notes are recorded under M8 as proposals.
- **Loose ends (same day):** if the timed Ashfall playtest moves P3 and control groups right after P2.3b, they go before P8; the timed hidden-tab check (F11) runs in P7's friend session; P7's result panel names who left, teammate or opponent; whether a browser or Deck player may host three bots is measured and decided at P9; when bot levels exist, an allied bot uses the same level and style as the enemy bots (one setting for all bots).
- **After the reviews (same day):** in P7 the host leaving, defeated or not, ends the match with the reason shown; after a teammate quits, Play again is hidden and Back to menu stays; the Play page's 1v1 and 2v2 choice, and whether 1v1 against a friend stays, is an A/B in P7's design; Cheaper step moves before P9, so two nights (Lighter relay frames, Cheaper step) sit between P8 and P9, an exception to the one-night rule; P8 shows three waiting texts (others, the dropped player, a relay restart; two since the relay restart text went, see "Relay availability questionnaire" below), appears only after a short stall and has a Leave match button that says what leaving does; in P9 the waiting view lists missing friends, the host can turn an empty friend slot into a bot, and a joined friend can leave; renamed: P8 Reconnect after a drop, P9 You and two friends vs three bots, P11 Friends against friends.

## Quick rematch slice 2 questionnaire (user, 2026-11-16)

Spec: [P2.2 slice 2 design](../superpowers/specs/2026-11-16-p2.2-slice-2-design.md); plan: [slice 2 plan](../superpowers/plans/2026-11-16-p2.2-slice-2.md); evidence: [verification, slice 2](p2.2-verification.md#slice-2).

- **Counters in the simulation, outside the snapshot and the hash** (user, 2026-11-16): the numbers on the result panel come from per-player counters the simulation keeps (`match_stats()`), never hashed, so no trace re-pins. This replaces the 2026-11-15 answer that the drawing side tallies them with no simulation change.
- **One row per player** (user, 2026-11-16), with units built, units lost and buildings lost; the local row is marked "(you)".
- **Units built** (user, 2026-11-16): a unit produced from a building's production queue; start units, rebuild-hole workers and free units from a finished building do not count.
- **Buildings lost** (user, 2026-11-16): finished buildings only; an unfinished site and a rebuild hole do not count.
- **Match length** (user, 2026-11-16): game time (ticks divided by the tick rate), shown as m:ss.
- **Opponent left mid-match** (user, 2026-11-16): the player who stays sees Victory, the stats up to the leave and the status "Your opponent left", with Back to menu and no Play again.
- **Online leave text** (user, 2026-11-16): "Leave the match? Your opponent wins and the room closes."
- **Quit** (user, 2026-11-16): a sidebar button on desktop builds, without a confirmation.
- **Focus outline by A/B** (user, 2026-11-16, stop gate A): variant A with the reviewer's gap tweak: a 2 px #e6e6e6 border, 4 px expansion (a 2 px gap of page colour), corner radius 9. Hover stays a background tint.
- **Hidden capture probe failed** (user, 2026-11-16): the offscreen capture window was visible for about 0.7 s (macOS ignores `--position`); the user accepted one flash for the A/B captures. The capture run caused about three flashes in all (the probe, a minimised start whose PNGs came out blank, and the final run).
- **Release** (user, 2026-11-16): to production after the test-app playtest.
- **Playtest card** (user, 2026-11-16): one focus card, "Result panel"; the launcher riders are an unscored checklist.

Agent's calls, not asked:

- While "Waiting for your friend…" Back to menu does not take focus, so a second Enter cannot leave the room.
- A quantity-2 order counts 2 units built; a rebuild-hole worker is never built but counts as lost when it dies; units buried with the last tunnel hub or their container count as lost.
- The status line keeps "Player N disconnected" beside the opponent-left panel.
- `left-mid` uses seat 2's clean close at tick 600 as the leave (the headless client has no `leave` message) and joins CI's exported netplay loop.
- Match length uses `Engine.physics_ticks_per_second`; the row label is "P<n> <faction name>".
- Keyboard pickers send focus to Start or Join after each selection; the playtest checks that this is acceptable.
- The match-slab look of the 2026-11-15 result-panel A/B (square card, winner-colour edge, dimmed world) waits for P2.3a's shared theme variations.

## OpenRCT2 review (user, 2026-11-16)

Source: OpenRCT2 review (private). Items that went into package rows and findings are noted there; these wait.

- **One validation result with an error code, shared by preview and execute** (user, 2026-11-16), later, beside the deferred "can I, and why not" simulation query (Round 2): today `sound_director.gd` matches the string "Insufficient credits", and `construction.gd` and `simulation.gd` produce it.
- **Deterministic per-seat command cap per tick** (user, 2026-11-16), later, M9 hardening: `lockstep.gd` applies every command; low value for friends-only, and it needs a protocol decision on what to reject.
- **Debug commands gated by a flag in the hashed start settings** (user, 2026-11-16), later, on demand: only when a playtest card needs big armies (the 210-unit row, P6).

## Zero-K review (user, 2026-11-16)

Source: Zero-K review (private). Items that went into package rows, the online teams spec and the session notes (private) are noted there; these wait.

- **Keyed modifier table for derived stats** (user, 2026-11-16), later, design input to ground batch A1 (veterancy and hazard fields): build it when the second multiplier source arrives, not before. The review's bot handicap idea is dropped: bots play fair and levels cut competence only.
- **Retreat stance that keeps the order queue** (user, 2026-11-16), later, M8 bots input beside the blueprint's retreat with hysteresis: a stance flag plus the saved order, so a retreating unit resumes its queue.
- **Per-match definition overlay** (user, 2026-11-16), later, M9 multiplayer balance revisit: it needs handshake and digest changes, so not before P7 to P9.

## OpenRA review (user, 2026-11-16)

Source: OpenRA review (private). Items that went into package rows, findings and the fog section above are noted there; these wait.

- **Hotkey contexts for the key-rebinding package** (user, 2026-11-16), later: A and S have two meanings (attack-move and stop against the P2.3b grid), a real overlap; the package defines contexts. See the key-rebinding item in the [second pass](#visual-and-ux-proposal-second-pass-user-2026-11-15).
- **Prerequisite list with `provides`** (user, 2026-11-16), later, design input to ground batch A1 (building prerequisites): `construction.gd:75` at `bb311c5` holds one prerequisite per building. Travelling shots (artillery flight time and minimum range) are already in A1.
- **Balance sheet generated from the registry** (user, 2026-11-16), later: before the M9 balance revisit.

## Relay availability questionnaire (user, 2026-11-16)

Eight rounds on the several-machine sketch in [relay scaling](relay-scaling.md#availability-to-start-a-game-user-2026-11-16); answered as recommended, with research asked for on the worker names and on monitoring. Nothing here is placed or built. It replaces the relay restart part of "Online teams refinement" above.

- **Goal:** availability means first that a server is always there to start a game. Matches are short and players can start again, so a match surviving a relay crash is secondary: worth building if it is feasible.
- **Relay restart recovery:** not in P8. P8 builds seat resume with a message shaped so recovery can be added later without another protocol version; recovery is its own later package if still wanted.
- **P9 still follows P8:** seat resume alone is reason enough before 3v3, where one dropped connection otherwise ends the match for six seats.
- **Reload or crash of a client:** counts as leaving for now; P8 covers network drops, where the game is still in memory. Coming back after a reload is a later package.
- **Cost:** paying a small amount is fine when the pricing is fair and the cost can be controlled; a free tier is not a requirement.
- **Second worker:** a second fly app in `fra`, with its own hostname. It covers a crash, a deploy and a full machine, not a fly or `fra` outage.
- **Always on:** both workers run all the time instead of suspending when idle; revisit if night 10 leads to a larger machine.
- **Outage of the platform or region:** accepted; the worker names are repointed by hand to a worker deployed elsewhere, from a short runbook.
- **Monitoring:** the workers check each other with a real game connection every few minutes and send a push through a configured webhook after repeated failures; no outside probe.
- **Drain trigger:** a signal to the relay process; the worker reports its remaining rooms on `/health`.
- **Relay deploys:** an own workflow started by hand, one worker after the other; game releases no longer deploy the relay.
- **Deploys:** the worker being deployed drains: it refuses new games, lets running matches finish for at most 60 minutes, then restarts.
- **Placement:** a new game goes to a worker picked at random; the client tries the other one when the first does not answer or is full.
- **Database:** the database, with Neon Postgres as the candidate asked about, holds durable data only (match history and statistics, playtest and desync uploads, later friends lists), never the live match. Creating, joining and playing never wait on the database; a lost row is acceptable. The choice of store stays the M9 hosting comparison.
- **Lobby (P11 input):** two lobby instances on the same pattern as the relay workers, so the store must allow two writers.
- **Placement in the plan:** recorded as a proposed package, unplaced until a backlog review.
- **Worker names:** built into the game as DNS names on the project's domain, one per worker, the first label matching the code's first character; the build knows the scheme and which slots to try. Moving a worker is a DNS change, adding one a new build. No list is fetched.
- **Override:** the prerelease relay field and the `relay` link parameter replace the whole list: exactly that relay, no fail-over.
- **Full worker:** each worker has its own limit and refuses a new game above it with `relay busy`, the reason the client treats as "try the other". The limit counts players, not rooms; the number comes from night 10's measurement (3v3 rooms times 6).
- **Lobbies on a draining worker:** they may still fill and start; the worker refuses only new games.
- **Play again on a draining worker:** off. The result panel hides the button and says in one line that the server restarts soon and the host can create a new game; a press that still arrives is refused.
- **Lobby seats:** an open lobby reserves all its seats against the player limit, so a game that was accepted can always fill.
- **Protocol change:** accepted that players on the old build cannot start a new game between the first worker's upgrade and the end of the second worker's drain, until they update. Order: first worker, then the new build, then the second worker; no worker speaks two versions.
- **Leave prompt:** in P8 the browser build asks before a reload or a close while an online match runs.
- **Player texts:** the five wordings proposed by the player-experience review are the starting wording for the package's design, not decided.
- **Push service and fly wording:** the service behind the webhook is chosen in the package's design; the fly facts stay labelled as not checked word for word until then.
- **Drain limit reached:** the remaining matches end without an earlier warning, with the reason on the result panel; no new relay message type (the existing `error` message carries the reason).

## Hypersomnia review (user, 2026-11-16)

Source: Hypersomnia review (private). Items that went into package rows, findings, the blueprint and the determinism rules are noted there; these wait.

- **Bot reaction delay as a level lever** (user, 2026-11-16), later, M8.1 bot levels input: the delay between seeing a threat and reacting cuts competence, as the other level levers do; it only means something once fog exists, because today's bot reads the whole state.
- **Keyed randomness dropped** (user, 2026-11-16): the draw stays one global stream. Revisit only if a "Cheaper step" experiment fails its digests because of draw order.

## P12 Notes that never block questionnaire (user, 2026-11-17)

Inputs: the P12 research note (private), [F22](../STATUS.md#findings-list). Zero Hour has no playtest form, so each answer is a Wargrid tooling call.

- **No buttons** (user, 2026-11-17): only the action buttons go (Next match, End session, Save session, Discard, Close, Try again, Show in folder). The 1-5 score toggles stay, and so do the marker dialog's Save and Cancel.
- **Reached during a match** (user, 2026-11-17): the form merges into the checklist panel, one panel on the ` key, holding the checklist, the questions and this match's markers.
- **Never pauses** (user, 2026-11-17): an open form neither pauses offline play nor blocks orders; only the marker dialog keeps its offline pause.
- **Filled in** (user, 2026-11-17): text, a score, a manual tick or a marker. Automatic trigger ticks alone file nothing.
- **Sitting end** (user, 2026-11-17): a sitting ends when its file is written on quit (desktop) or downloaded (web); a new build id also starts a new sitting. Resume after a crash through `current.json` stays.
- **Web download** (user, 2026-11-17): on every return to the launcher when something new was filled in; a closed tab's notes stay in `user://` and download at the next start. Needs a browser check.
- **Desktop exits** (user, 2026-11-17): pause Quit, launcher Quit and closing the window all write the file.
- **Mid-match record** (user, 2026-11-17): written on each marker and at match end, with no timer and no state digest mid-match; the record carries an additive unfinished field, so the format stays 1.
- **Interrupted match** (user, 2026-11-17): a match cut short by a crash or a closed tab stays in its sitting, flagged unfinished, with no new UI.
- **Discard dropped** (user, 2026-11-17): no discard action is left; an unwanted file is deleted by hand.
- **Build path** (user, 2026-11-17): the checklist panel grows into the form, and the match in progress lives in the session as an unfinished match.
- **Field saves** (user, 2026-11-17): text fields save on Enter or when focus leaves the field, not on every keystroke.
- **Match end** (user, 2026-11-17): the panel opens by itself without taking focus, so the result panel keeps Enter.
- **Card picker** (user, 2026-11-17): the launcher's focus-card picker no longer locks while a sitting is open. Picking another card files the open sitting if anything was filled in, then starts a new one, the same way a new build does.
- **Saved hint** (user, 2026-11-17): passive text only. The panel footer shows "Saved" with the time of the last write. The launcher line under "Session open" shows the last filed path as selectable text on desktop, or "Notes downloaded: <name>" on web.
- **Earlier markers** (user, 2026-11-17): after Play again, the previous match's markers stay listed as "Last match", with comment fields, until the new match gets its first marker.

## P3 timed playtest (user, 2026-11-17)

The timed Ashfall playtest from the [player-experience review](#player-experience-review-user-2026-11-16), played by the user on desktop `main` `a7ba7ac`: from a fight in the enemy base, the trip back to the own base takes 3-4 s with the arrow keys, so 6-8 s away from the fight per round trip.

- **It hurts:** P3 moves right after P2.3b, before P8 and the art packages.
- **Scope:** minimap, H to the Command Center, control groups and Space to the last alert; edge scrolling and right-drag pan go to the Later item Pan with the mouse. The minimap beats edge scrolling and drag pan for long trips (user's view).
- **First minimap:** click or drag moves the camera, flash on attack, blank at low power; right-click orders on the minimap are not in it.
- **Merge:** P3 takes all of the Later item Minimap and attack alerts.
- **Name:** "See the whole map".

## P2.3a groundwork questionnaire (user, 2026-11-17)

Answers to a read-only gap map of today's HUD against HUD v5 (working notes `p2-3a-groundwork.md`, private), with research and player-experience reviews where the user asked. The nine map-mark, edge and canvas questions wait for map art round 6 (answered from round 6 on 2026-11-17: [map art shapes](map-art-shapes.md#p23a-see-your-selection-map-edge-canvas-and-marks)). Inputs for the P2.3a design, not a design.

- **Interim:** today's button column becomes one bottom-right slab until P2.3b; no queue row in P2.3a.
- **Window shapes:** the view is capped at 2.4:1 (2560x1080 and 3440x1440 fill the screen) and 16:10 (Steam Deck, MacBooks in fullscreen), the same online and offline; black bars beyond, a different shade from the canvas. Today's aspect is `keep`, so nobody loses width. Research found no RTS with a documented fairness cap (Zero Hour fork PR #1711 calls extra view an advantage). Rendered gate row at 2560x1080; headless layout tests at 1280x720, 1280x800 and 3440x1440.
- **A/B before the plan, one batched window session in the in-game lab (no offscreen probe first, user 2026-11-17):** the two colour token sets, the health-bar rule, value size 13 against 14 px, and the drag box: white outline with faint fill, green outline without fill, owner colour with low fill.
- **Plumbing:** tabular numbers through a `FontVariation` with `tnum`; `game/ui/launcher_theme.tres` grows into the one theme; the `view_player` rider happens in P2.3a.
- **Places:** online notices top centre; the F3 overlay, the playtest checklist and the note form drop down under the Playtest chip.
- **Panels:** enemy and allied buildings and units show name and health with their owner colour on the edge; enemy sites show no build percent (replaced 2026-11-19: they show it, [advisor review](#advisor-review-of-the-p23a-answers-user-2026-11-19)); one unit shows name and health only; health rounds up; kind rows in roster order; your stalled site reads a muted `PAUSED · NO BUILDER` in place of `UNDER CONSTRUCTION`.
- **Supply pile panel:** only `CREDITS LEFT` (boxes times 75; `Empty` at zero); docked and waiting counts dropped; "in line" stays on the collector's panel. Zero Hour's hover shows the dollar value left (GeneralsGameCode `InGameUI.cpp:2719-2727` @ afc2a103f). Piles are click-only.
- **Selection:** kind rows: click narrows to the kind, shift-click removes it (replaces "shift-click adds"; StarCraft II and Age of Empires IV remove with shift on the panel); no mixed unit and building selection in P2.3a, revisited with P3's control groups.
- **Refusals:** one line, a new refusal replaces it and restarts the 3 s; refusals a player cannot cause read "Order not possible" (raw text to the playtest log); one wording table for match and launcher; F30's quiet beep fixed with F29; placement refusals only after the click.
- **Dropped:** "You are blue (P1)" (an own-colour swatch replaces it, 2026-11-19, [advisor review](#advisor-review-of-the-p23a-answers-user-2026-11-19)) and the tick counter (F3 keeps it). Credits written `4,800`; the resume hint stays in the interim key-hint line.
- **Later riders:** for see your economy, collectors against an ideal count on the depot and a nearly-empty pile alert; for P3, a map mark on your own stalled sites.

## Bot vision (user, 2026-11-17)

What the bots are for. The open questions it raises are in [next-bots-fair-human.md](../questions/next-bots-fair-human.md). Levels, order of work and the top-level bar were settled on 2026-11-18 ([bot difficulty design](#bot-difficulty-design-user-2026-11-18)).

- **Purpose:** excellent bots for when friends are not available. Fair but challenging, not overwhelming.
- **Human feel:** bots feel like human players, with the same information, resources and game mechanics. No cheating. Whether "same mechanics" also rules out bot-only automatic unit behaviour was settled on 2026-11-18: it does (Q7 b, Q8 b).
- **Levels:** the highest level challenges a really competent human player; lower levels scale down the way some humans simply play worse. This differs from "the hardest should beat the user and friends regularly" (2026-11-05); the 2026-11-18 design replaced that bar. The user and friends expect to start on a medium level and work up; since 2026-11-18 that is Regular.
- **Order of work:** quick, effective wins soon; advanced work later. How soon was Q5: one small bot package once two or more changes pass their test, before M8 (user, 2026-11-18, [bot plan round](#bot-plan-round-user-2026-11-18)).
- **Later content (said separately the same day):** Supply Drop Zone, Hackers, the Black Market and oil derricks come later, and the bots must later make proper use of them, of general's powers and of the missing ground and air units.

## Bot difficulty design (user, 2026-11-18)

A difficulty design from the user, settled in one questionnaire. It replaces "about five levels", "strong bot first, ladder after" and the top-level bar of 2026-11-05, and answers [next-bots-fair-human.md](../questions/next-bots-fair-human.md) Q1, Q3, Q4, Q7 and Q8 (Q2 and Q6 are overtaken). The fairness rules of 2026-11-05 stand.

- **Six levels, default Regular**, each with one line saying who it is for:

  | Level | For | What it does |
  |---|---|---|
  | Cadet | complete beginners | basic economy, little aggression, forgives the player's mistakes |
  | Recruit | casual players | working economy and combat, simple plans |
  | Regular | average RTS players | competent production, expansion and attacks |
  | Veteran | experienced players | stronger openings, scouting, timing attacks, unit control |
  | Elite | highly competitive players | efficient economy, coordinated tactics, adapts to what it scouts |
  | Nemesis | experts | the strongest fair bot we can build; professional strength is a direction, claimed only with evidence |

- **One bot, skill profiles:** one shared bot with a skill profile per level, not six bots. Levels differ in strategy, economy, tactics, use of scouted information, doing several things at once, and execution (reaction time and orders per minute within human limits). Higher levels decide better; they do not just order faster.
- **Weaker levels:** a lower level is weaker only by missing competences a weaker player lacks (scouts less, expands late, focuses fire worse, reacts slower), never by deliberately wrong choices, idle workers or slowness for its own sake.
- **Same rules for every level, Nemesis included:** same resources, costs, income and production rules as a human; fog of war and scouting respected once fog exists; no knowledge of hidden enemy positions or plans; no inhuman reaction or unit control; only ordinary game commands. Bot units follow the same automatic unit rules as human-owned units everywhere; where units should behave differently, it is a stance a human can also set, or an ordinary order (Q7 b, Q8 b).
- **Order of work:** one shared bot, built to Regular first as the baseline; then Recruit, Veteran and Elite; then Cadet; Nemesis improves continuously. Replaces "strong bot first, levels cut once from it".
- **Bot against bot:** benchmarks across maps, factions, styles and both seats check that each level beats the one below and catch regressions. A level ships only if it beats the one below by more than chance alone produces (the noise floor); otherwise it is reworked, or the ladder ships fewer levels until it does.
- **Human checks:** a one-tap rating after every logged match (too easy, close, too hard); about ten logged matches at Regular and at the top level first (Q4 b); win rates per level only once enough matches exist. The user's group is the first human data point and is recorded as such, not as a level's audience; testers of other skill levels follow when they exist.
- **What is not claimed:** bot-against-bot results alone do not show human-level skill. Elite and Nemesis are never weakened because the user and friends cannot beat them.
- **First human data (Q1 a):** the user and one friend each play two short logged matches against today's bot with the playtest helper, with the one tap after each.
- **Regular's bar (Q3 b):** about even against an average player of the user's group in their first matches, most matches close.
- **Later, not in the first plan:** opponent modelling and adaptation beyond reacting to what was scouted (Elite and Nemesis, long term).

## Bot plan round (user, 2026-11-18)

Answers to the open questions of [next-bots-fair-human.md](../questions/next-bots-fair-human.md) (Q5, Q9 to Q15) and to four plan details, asked in three selector rounds while the incremental plan for the six levels was written ([plan](../superpowers/plans/2026-11-18-bot-difficulty-levels.md)). Every answer took the recommendation.

- **Ship before M8 (Q5 b):** a bot improvement that passes its report card test ships before M8, as one small bot package once two or more have passed, so the recorded match traces move once per package. Replaces "all bot changes wait for M8, except a launch rule that passes the Bot attack test" (user, 2026-11-16).
- **Openings (Q9 b):** at every level the bot picks one of two or three openings per faction each match, from the match seed, and its first attack time varies.
- **"Feels human" (Q10 c):** both automatic checks on the bot's recorded orders (variety between matches, pace, delay before it acts, no fixed beat) and one question after each logged match (did it feel like playing a person: yes, partly, no; what gave it away).
- **Ally defends your base (Q11 b):** from P7 on, an allied bot's army at home comes when your base is attacked. An exception to "P7 ships today's bot" (user, 2026-11-16).
- **What the ally tells you (Q12 c):** in P7, a map mark and one line of text when the allied bot's army sets out, and a call when its base is under attack.
- **Ally comes along (Q13 d):** with the later bot team-play package, the allied bot sets out with you, toward the enemy you attack.
- **Asking the ally (Q14 b):** with the later bot team-play package, the map ping you would give a friend: the bot sends its next army there for a limited time and answers "coming" or "not ready".
- **End-game income (Q15 a):** the 2026-11-09 answer stands: Supply Drop Zone, Internet Center and the Hacker's money ability land in ground batch A; the blueprint's "placement not decided" is corrected.
- **Ladder bar:** a level clearly beats the one below when, over the ladder matrix (three maps, all faction pairs, both slots, five or more random start values per row), it wins at least 60 % of the decided matches, the low end of the 95 % interval of that share is above 50 %, and it is ahead in each slot on its own.
- **Level control:** appears in the launcher as soon as Regular and one more level pass the ladder; it lists only levels that passed, default Regular.
- **Bot report card:** placed as a night package in the free gap between P2.3b and P8 (the one Adaptive input delay does not take).
- **Bot attack test:** moved from between P9 and P10 to the free gap between P13 and P14, so a winning launch rule can ship before P9's 3v3 gate on Ashfall; its rule is unchanged (a rule ships only if it wins both columns).
- **Nemesis in the launcher:** until logged human matches give evidence (L3), the launcher shows a line that promises no skill tier, such as "The strongest fair bot we can build", instead of "For experts".
- **Regular's human bar (Q3 b):** met when, of about ten logged matches, six or more are rated "Close match" and neither side wins more than seven.
- **Levels before fog:** levels may ship before fog as profiles of today's bot (fair by symmetry: no side has fog yet); every level is re-measured on the ladder once fog and the bot's observation filter land. Fog still comes before the M8 bot.
- **Rate the bot:** the one-tap rating after bot matches is a backup task of night 8 Play on after a leave, so it exists before P7 changes the bot.
- **P7's unit-rule evidence:** the 2026-11-17 probe's result (no measurable strength difference) is enough for P7; the Bot report card re-checks it in its first report.
- **Research inputs kept:** Uriarte and Ontañón's fight test as B5's first evidence; a middle-skill player in the L3 human checks on purpose; the unread items (Pietikäinen's critique of AlphaStar's limits, GDC talk videos) are read when B7 is planned.
- **Left for M8 planning (unchanged):** the Zero Hour bot data re-read and the fate of origin's `spike-bots` and `spike-native-sim`.

## Sim boundary critique review (user, 2026-11-18)

A private design critique of the sim boundary and worker thread (2026-11-17, against `425aa44`), checked at `d108b90` after the SB4 merge: SB4 fixed its B1 core and B2; most other findings still hold, mostly in SB5 and SB6, which are not built.

- **Pump hardening before SB5a:** a new small night package, all testable inline: offline keeps its queue and preview request on a refused post (folds in F32's `post` part), a null `run_job` result publishes nothing and fails the pump, one "end the match" call that stops the pump on every exit path (leave, quit, window close) before it records, `record()` returns the command log so `recorder()` goes and `playtest_header()` stops building the log, a wider static check, nested cache freeze with the warm-up derived from the freeze list. SB5a shrinks back to the queue.
- **SB5 split:** SB5a is the thread, native and headless behind an environment switch; SB5b is the threaded Web preset, COOP/COEP headers, the preset-and-headers pairing check and the pause-menu toggle, on the test app only until a GO. Replaces answer 12's "both land in SB5".
- **PARK or DROP at SB6:** production stays on the no-threads build; the flag code stays and the suite runs under the flag in CI.
- **Owner-thread check:** the pump checks in every build that `run_job` runs on its owner thread (`push_error`, fail the pump). This is not the debug hash check answer 8 declined.
- **Desktop after a GO:** the worker is on by default on desktop builds too, the same as web (against the recommendation to keep desktop inline unless measured; the Mac verdict was PARK and worker mode shows each tick a frame later).
- **Answer 11 closed:** published views are never refilled; the pump publishes a fresh `Slot` per job and never writes one after publishing (about 0.8 µs each), and the "main may hold CURRENT and PREVIOUS only" rule goes, so P4 may keep a ring of poses. Reuse would save about 1 % of the unit rows and brings torn reads on a kept column.
- **Overtaken orders:** an order that was valid at the click and became impossible in flight is not reported as the player's mistake: silent for a target or unit that died, a neutral line for an emptied pile or a finished production entry; mistakes keep the beep. Applied in `match_screen._take_answers`, as a column in P2.3a's wording table.
- **SB6 timing:** the Deck decision goes early as a measurement; a GO is re-measured at the P6 and fog gates and at P9, and the switch stays until then.
- **Go rule rewritten before the SB5a plan, in one place (the spec's SB6 row):** refused posts and the longest run of refusals replace the backlog guard (which cannot exceed the queue cap); pace is judged on the worst two-second window as well as the average; report-only rows for tick arrival spread and answer latency; a no-harm row on a fast machine.
- **SB6 bench:** scripted input, the quality the automatic pick chooses and Low, offline rows without the 30-tick digest, the online cadence as its own row, a no-threads inline arm and an inline arm with the physics-step cap; one attended look at offline placement with the worker on.
- **Peer after a local fault online:** the other player gets "Your opponent left" and no result is recorded; the reconnect package (P8) counts it as leaving at once.
- **Adaptive input delay floor:** night 9 keeps the delay above the two to three ticks a worker client can have undrained.
- **Pump hardening also takes:** the SB4 leftovers (`Lockstep.finish_tick` refuses to send after the lockstep ended or for a tick that is not the last sent plus one; a reference test of a scene driver against a plain `advance(sim)` peer with hashes through the match end; `FakeTransport` applies the relay's frame-order rule; the preview request on one job per step call, not every catch-up job; STATUS F35, the sequence stamp only on request), the inline-testable SB5 riders from the SB4 review (`take` checks `tick == _next_tick`, a test for a receive that ends the lockstep while a job is undrained, the static-check gaps widened to any member access on a pump outside the two drivers with per-file counts), and one profiled team-load row through `SimPump.post` and `drain` beside the direct row.
- **SB5a keeps** the pairing guard and the catch-up cap riders. The two 25-units-per-cell tooling constants are a small tooling fix when `tools/zh_map/` or `tools/check_reference.py` is touched next.
- **Placed elsewhere:** STATUS F23 widened, F33 and F34 added (riders on P2.3b and P4); a scene-client netplay scenario as a night 8 rider; reading cross-script statics into locals as a Cheaper step rider (night 13).
- **Attended Deck session without threads, before the SB5a plan:** the inline arm at the automatically picked quality, at Low, and with `Engine.max_physics_steps_per_frame` at 1 or 2.
- **SB5b gate:** before production switches to the threaded build, open the threaded test app from a link in each chat app friends use, and one listen check.
- **SB5a inherits list** recorded in the spec now, one line per item with its source.
- **Fresh Slot per job** (answer 11) lands in Pump hardening; **room before `take`** (a refused post ends an online match, so with SB5a's queue cap the driver checks for room first and clears the pending-build flag when a pump stops or fails) is on SB5a's inherits list.

## P2.3a A/B lab picks (user, 2026-11-18)

Four questions from the [A/B lab spec](../superpowers/specs/2026-11-18-p2-3a-ab-lab-design.md), judged from pictures and clips rendered at 1280x800 in the round 6 look, plus a browser build of the lab, on an office screen and a phone.

1. **Colour tokens: set A** (the HUD v5 tokens, unchanged; [Colour tokens](hud-v5-layout.md#colour-tokens)).
2. **Health-bar rule: A, "damaged or hovered".** A unit shows its bar when damaged or under the mouse; selected healthy units show none. This replaces today's "selected, damaged or hovered" (`WorldView.shows_health`) in P2.3a. Zero Hour's rule is "selected or hovered".
3. **Number size: B, Numbers 13/700** (v5, unchanged; [Type scale](hud-v5-layout.md#type-scale)). Preferred on an office screen, but the owner was unsure. It gets one look on the Steam Deck's 1x screen in the P2.3a playtest and switches to 14/700 if numbers read poorly there.
4. **Drag box: A, white 1.5 px line, no fill**, over the white-mark under-stroke rgba(14,18,22,0.78) drawn 2 px wider, with the live corner-tick preview on own units the release would pick. Today's green box goes.

Finding, not a decision (agent, 2026-11-18): in the lab, a framed health bar (1 px owner frame, black track, 24x3 fill) only keeps frame, track and fill apart at zoom 0.5 when drawn in screen space, snapped to whole pixels, at its zoom 1 size. The P2.3a design must decide the bar's size per zoom.

The owner colours against `sel` `#60e5ed` are computed in [Owner colours against `sel`](hud-v5-layout.md#owner-colours-against-sel).
- **Confirmed in motion** (user, 2026-11-18): in the browser build of the lab, started on the picks, the owner checked health bars A in the live fight, hover and drag box A with its corner-tick preview, and kept all four picks.

## P2.3a design round (user, 2026-11-19)

Questionnaire rounds while the P2.3a design was written, each with the Zero Hour default and a recommendation; inputs from a read-only survey at `main` `62e6b3c`.

- **Split into three packages:** P2.3a1 See your selection (theme, stretch cap and anchoring, top strip, chips, interim slab, the whole selection panel, click priority, `view_player`, the HUD gate rows), P2.3a2 (refusal line and wording table, F29, F30, the Esc menu) and P2.3a3 (white marks, hover ticks, drag box, rally and target line, map edge and canvas, health bars, the damaged-army row). P2.5 can start after P2.3a1. Reason: the full row is about 16 tasks, more than one 15 to 20 minute playtest covers, and separate rendered rows tell `expand` from the new marks.
- **Documents:** one design spec for the whole row; the implementation plan for P2.3a1 only; P2.3a2 and P2.3a3 get their plans when they start.
- **Palette A on the bodies in P2.3a1:** palette A's owner colours move into `palette.gd`, so the panel edge and the bars match the units they describe; Neon removal and the shapes stay in P2.4. Costs one re-pin of the world-batch colour goldens and SH15.
- **HUD rebuilds on change:** the strip and panel rebuild only when their inputs change (selection, health sums, credits, power), with a headless test that counts rebuilds; the Deck pair measurement (HUD off against on, low-end report §8.7, private) waits for the next Deck session.
- **Window bars black:** the bars beyond the 2.4:1 and 16:10 caps stay Godot's fixed black `#000000` (the renderer paints them; no own bars), against the canvas `#08090A`; the 2026-11-17 "a different shade from the canvas" is met only nominally (contrast 1.05:1), which the owner accepted.
- **Hover any owner:** own, allied and enemy units, buildings and piles hover through the same pick as the click, so hover and click always name the same object (Zero Hour: any owner's object under the mouse shows its bar).
- **Front-most wins** (replaced below by own units first): where units overlap, a left click picks the front-most drawn one whatever its owner (Zero Hour's ray pick); replaces today's own-first rule.
- **The HUD blocks the map:** a click on a panel, the top strip or a chip never selects or orders on the map, and a drag box skips units whose anchor lies under a panel (Zero Hour does the same).
- **Power line on producers only:** only power plants show a `POWER +n` line; buildings that use power show name and health (as drawn in HUD v5; Zero Hour shows none).
- **Enemy sites by name** (replaced below: sites show their percent): a selected enemy or allied construction site shows its plain name and health, no label and no percent (Zero Hour's under-construction view is for own sites only).
- **Collector status label** (idle count moved to the header below): one selected collector shows a muted caps label on its name row for every phase (`TO PILE`, `WAITING AT PILE · 2ND`, `LOADING`, `TO DEPOT`, `WAITING AT DEPOT · 1ST`, `UNLOADING`, `IDLE`), not only the place in line; the panel stays 62 px; a collector kind row in a multi-selection adds its idle count (`Supply Truck · 1 idle`). Replaces "(2nd in line)" on the collector panel. Zero Hour shows no text (the truck's cargo shows full or empty); cargo on the map comes with P2.5. Mock-up drawn 2026-11-19 in the HUD v5 stylesheet.
- **Open until the advisors report** (closed below: kind row): whether one kind with many units shows a kind row or the one-unit layout with a count.
- **Power plant forecast** (replaced below by the full pair): while a power plant is armed, the strip reads `POWER 8 / 10 → 8 / 15` (the available side grows), the same form as a building that uses power (`8 → 11 / 10`).
- **Short credits forecast** (replaced below by `700 short`): an armed building you cannot afford reads `CREDITS 500 → −700` with the after-value in amber (cannot afford is on amber's list).
- **Kind row hover:** a hovered kind row steps its fill up one shade (`panel2`), no outline; cyan stays for selected.
- **Offline freeze notice:** a failed offline pump shows "Match stopped: game error. Please report it." at the top-centre notice spot (the online wording); the raw reason goes to the log.
- **Type scale 12, 13, 14, 16, 24, 30:** the launcher snaps to it (15 up and 17 down to 16, 23 to 24, 30 stays), slightly larger for the Deck's small screen; launcher layout tests at 1280x720 must still fit.
- **HUD benchmark rows in the CSV only:** the new rendered HUD rows go into `perf-history.csv` and the ledger's history; the README chart and status table stay as they are.
- **No right-click remove-one on selection rows (non-goal):** shift-click removes the kind; per-unit removal (Zero-K's right-click, proposed by the 2026-11-16 Zero-K review) is revisited with control groups.
- **Owner name in the panel waits for P7:** P7 brings more than one opponent and adds a muted owner label then; 1v1 needs none.
- **An accepted order clears the refusal line:** when the next order's answer is accepted the stale reason goes; otherwise the 3 s timer ends it (Zero Hour's messages only time out).
- **Not enough credits on the line:** "Not enough credits" shows on the amber line with the voice, no beep (Zero Hour: the voice plus a silent text message).
- **One line and one beep per frame:** many refusals in one frame (for example the order cap) show the last reason once with one beep.
- **Neutral overtaken line:** an overtaken order's line uses the refusal slab and place with muted text, no amber square and no sound.
- **Missing prerequisite names the building** (wording replaced below: `Needs Power Plant`): "Needs a Power Plant", from the definitions, the same words P2.3b's cell card uses.
- **F30 level by ear:** the refusal beep (measured about 10 dB under the music and 16 dB under the voices, −40 LUFS after the bus) gets its new level on a labelled listening page in Firefox, +6, +10 and +14 dB against music and voices, +10 as the starting point.
- **Wrong code during a flood, launcher wording:** a Join closed after hello and before welcome reads "No answer for that code. Check the code, or try again in a minute."; no relay change.
- **F29's online lag as a card question:** the decision stands (offline the voice comes in the same frame, online at least about 133 ms after the click; Zero Hour plays it at the click); the P2.3a2 card asks whether online orders felt slow to answer.
- **Esc menu in two columns:** Resume, Back to main menu and Quit on top; below, Audio on the left and Graphics and Playtest on the right, as the launcher's Settings body, from one builder shared with the launcher; fits 1280x720.
- **No Fullscreen in the Esc menu:** the Display section stays in the launcher (Zero Hour changes no display settings during a game).
- **Inspected objects get the white mark:** a selected enemy or ally shows the same white diamond or footprint as your own selection; the panel edge says whose; the red boxes go.
- **One attack X** (replaced below by a reticle): one white X on the target whether the unit fires or approaches.
- **Health bar size per zoom, floor rule** (reopened below: decided in P2.3a3 by capture): the bar is drawn in screen space on whole device pixels with pixel step `max(1, floor(zoom × window scale))`; at 720p and 800p this is the lab look (28x7 at zoom 0.5 and 1, 56x14 at zoom 2), at 1080p it gives steps 1, 1, 3 (Zero Hour: fixed 3 px height, width follows the zoom).
- **Move ring 18 to 4 px on wall time:** the confirmation ring closes from radius 18 to 4 (half as high) linearly over 0.4 s of real time, so it stays smooth and plays during a pause.
- **Drag preview on today's all-units rule:** the corner-tick preview ships on today's rule (every own unit in the box, never buildings, as Zero Hour); tiers or binary is decided after a playtest with the preview visible; card question: did builders or collectors end up in a fight by accident.
- **Open until the advisors report** (closed below: constant screen width): mark line widths when zoomed out (fixed screen width or scaling with the zoom).
- **Carried mark sizes decided as drawn:** selection line 1.25, hover ticks 0.32 of an edge at 1.5, attack X arm 6 line 2 lifted 8, rally pole 24 with a 10x9 flag, line from the door 1.25 and foot ring 4x2, dashed target line 1.25 with 6/4 dashes (map art round 6 values); the P2.3a3 offscreen captures get a reviewer check against the mock-ups and the owner looks once in the playtest.
- **One under-stroke rule:** every mark's under-stroke is 2 px wider than its white line, buildings too (1.5 over 3.5, not the drawn 4.5).
- **Refused placement, X on every cell; ghost in P2.3b:** the simulation answers once per footprint, so a refused footprint outlines every cell with the X; the 55 % ghost comes with P2.3b's placement work.
- **Resume outline as white ticks** (replaced below by a dashed footprint): a building you can resume shows white corner ticks on its footprint instead of the green outline; crate squares wait for P2.5; debug destination crosses stay.

### Advisor review of the P2.3a answers (user, 2026-11-19)

Two advisors (the player-experience reviewer and a researcher over the engines in `~/projects` and primary web sources, each on Opus, reports private) checked every P2.3a answer above and in the earlier P2.3a sections. Changes the owner took:

- **Own units first on overlap** (replaces "Front-most wins" above): the full click rule is tier first (unit, building, pile, ground), then own before others, then front-most; hover uses the same rule. Reason: Zero Hour's front-most ray pick runs with left-click orders (GeneralsGameCode `GlobalData.cpp:1057` @ afc2a103f), so under Wargrid's left-select a front-most enemy would replace the selection in melees; OpenRA keeps own before enemy within a tier (`OpenRA.Game/SelectableExts.cs:36-46` @ b4d95a5671).
- **Enemy and allied sites show their build percent** (replaces "Enemy sites by name" above and the 2026-11-17 answer "enemy sites show no build percent"): a selected site of any owner shows `UNDER CONSTRUCTION` and the percent; `PAUSED · NO BUILDER` only on your own. Reason: Zero Hour draws the percent above every visible site of any owner (`Drawable.cpp:2751,3651-3679` @ 0a05454), and once P2.5 takes the map text away the panel is the only place left.
- **Resume cue as a dashed white footprint** (replaces "Resume outline as white ticks" above): the 6/4 dashed style around the footprint, because hover already draws white corner ticks.
- **Shift-click toggles on the map:** shift-click on a selected unit removes it, on an unselected one adds it; shift-drag still adds; so shift reads as toggle on the map and on the panel.
- **One kind shows a kind row** (closes the open item): `12 selected · 1 kind` and one row; the identity block always means one object, rows always mean groups (Zero-K and 0 A.D. use the single layout only for exactly one unit). Correction: Zero Hour shows the first unit's portrait for every multi-selection; its same-kind check is dead code (`ControlBarMultiSelect.cpp:274-293` @ 0a05454, read only).
- **Mark lines keep a constant screen width** (closes the open item): lines and under-strokes keep their zoom-1 widths (1.25 over 3.25, buildings 1.5 over 3.5) at every zoom, times the window scale; shapes, lengths and positions still scale with the world; dashes keep 6/4 screen px (OpenRA and Recoil draw marks at fixed pixel widths; WCAG 2.2 Understanding 1.4.11 warns that thin lines antialias faint).
- **Power forecast as a full pair** (replaces the two forms above): `POWER 8 / 10 → 11 / 10 LOW POWER` for a building that uses power and `POWER 8 / 10 → 8 / 15` for a power plant.
- **Idle collectors in the header** (replaces the row suffix above): `9 selected · 2 kinds · 1 idle`, shown only when a selected collector is idle; `Supply Helicopter · 1 idle` measured 157 px against about 146 px of row room.
- **Attack target as a reticle** (replaces the white X of 2026-11-15 and "One attack X" above): a small white ring with four inward ticks over the under-stroke, one state, so X keeps one meaning (blocked); its sizes are an agent proposal checked in the P2.3a3 captures.
- **Health bar step decided in P2.3a3 by capture** (reopens the floor rule above): P2.3a3 starts with an offscreen pair at 1920x1080, zoom 1, on a damaged army, floor against the lab's round rule; the owner picks from the pictures. The two differ only at 1080p, zoom 1.
- **Short credits read `700 short`** (replaces `500 → −700` above): `CREDITS 500 → 700 short` with `700 short` in amber, the cell card's phrase.
- **`Needs Power Plant` without an article** (replaces "Needs a Power Plant" above), on the refusal line and on P2.3b's cell card.
- **Own-colour swatch in the top strip:** an 8 px square in your slot colour at the strip's left until the intro band ships (the intro band has no slot yet, so a new player otherwise learns their colour only by selecting something). Amends the 2026-11-17 "Dropped: You are blue (P1)".
- **Kind rows show the hand cursor:** the `panel2` hover fill stays and the pointing-hand cursor shows over rows, because the fill step is only 1.09:1.
- **Uppercase 12 px labels checked on the Deck:** looked at in the same Deck session as the 13/14 px numbers (8.7 px cap height at scale 1 against Valve's 9 px guideline, whose em-or-glyph meaning is not stated); raised to 13 px only if they read poorly.
- **Freeze notice gives the way out:** "Match stopped: game error. Please report it. Esc: leave the match."
- **Later settings item:** a health-bar "Always" option (OpenRA, Age of Empires IV and StarCraft II offer one); not in P2.3a.
- **Drag tier rule drafted in the spec:** written now so the playtest answer can be applied at once; P2.3a ships today's all-units rule.
- **Record corrections (agent, 2026-11-19, from the advisor review):** 17 to 16 px is a step down for the launcher's primary button, not up; the HUD v4 note that the 12 px floor meets XAG used font size, but XAG 101 measures body height (Public Sans 12 px is 16.5 px body at 1080p, 13 px is 17.8 px; the 115 % interface option gives 18.9 px); the green-yellow-red health fill is the one named exception to "no red on the map"; the move ring starts on the order's acceptance (F29); the F29 card question is worded neutrally ("Online, orders answered: at once / slight delay / too slow"); a refused footprint crossing out every cell is placement debt for P2.3b; blocked costs stay normal text and only the hovered shortfall turns amber (P2.3b cell card).
- **Idle means doing nothing at all:** a collector reads `IDLE` and counts in `· n idle` only when it is not gathering, not moving, not building and not inside a transport; a collector on another task shows that task (`MOVING`, or `BUILDING` for a Laborer), told from the published view without a simulation change. Reason: any other task sets the simulation's collector phase to `idle` (`Simulation._detach_task`), so a building Laborer or a truck on a move order would otherwise read idle (builder check, 2026-11-19).

### Spec review follow-ups (user, 2026-11-19)

Questions from the builder check and the three spec reviews (player-experience, a fresh Opus correctness reviewer, Codex gpt-6.2-astra high; reports private).

- **The refusal line comes in P2.3a1, its words in P2.3a2:** P2.3a1 builds the amber line at its final place with the timer, replace and clear rules, showing today's simulation text, so the P2.3a1 release never beeps without a reason; P2.3a2 adds the wording table, F29, F30 and the launcher words.
- **No place number in the collector's waiting label** (replaces `· 2ND` and `· 1ST` above): `WAITING AT PILE` and `WAITING AT <drop-off>`, because the simulation orders the line by arrival tick, which the view does not publish (today's map label counts lower ids and can be wrong too).
- **Drop-off by its own name:** the collector label names the drop-off building from the definitions (`TO SUPPLY CACHE`, `WAITING AT SUPPLY DEPOT`), not "depot" for every faction.
- **Armed button look while placing:** the armed interim slab button shows the cyan armed look (`panel2` with a 2 px `sel` inset), the look P2.3b's card cell will use, because today's "Place: <name>" text goes with the label (Zero Hour keeps the armed button highlighted).
- **`· 1 idle collector` in the header** (amends the header form above; plural `collectors`), so the count does not read as idle units in general.
- **Piles hover with corner ticks** on their footprint, so hover always shows what a click picks.
- **Kind rows hold under the pointer:** while the pointer is over the panel, the row layout holds (a dead kind's row stays, greyed, count 0) and reflows when the pointer leaves, so a click never lands on a shifted row.
- **The launcher stays uncapped** (confirms the 2026-11-14 decision after two advisors, player-experience and research, both recommended it): the launcher fills any window with `expand`; the 2.4:1 and 16:10 caps apply only in the match and the benchmark. Reason: the caps bound the online vision edge and the draw cost, which a menu does not have, and Godot's black bars would stand out on the launcher's grey while staying near-invisible against the match canvas. Guard: the cap handler never runs while the launcher is open, and returning to the menu resets the size to 1280x720 as well as the aspect.
- **HUD built as a new node with a narrow input** (approach picked by the owner from three, 2026-11-19): a Control node with one update call, signals out and no side effects, text-pinned tests moved to node ids first; against panels beside the old label and promoting the lab panel as is.
- **Palette A green against `ally` moves to P3's minimap** (moves the open item placed on P2.3a on 2026-11-17): the `ally` token appears only in the Full set (ping arrow, minimap dots), so no P2.3a screen shows the pair; decided where it first appears, with the numbers carried (ΔE 15.0, 7.8 under simulated deuteranopia, bar 20).
- **Kind-row hint line:** one muted line among the interim slab's key hints ("Rows: click narrows, Shift-click removes"), going with them in P2.3b.
- **Day-lane order P2.3a1, P2.3a2, P2.3a3, then P7:** back to back, so the mixed old and new look lasts days, not weeks; P7 moves back about two packages; night 8 Play on after a leave takes the first free night gap after P2.3a1 (it does not need the HUD).
- **Esc chip shown only when Esc opens the menu:** it hides while Esc would first back out of a placement, a selection or an inspection; hidden often, never wrong.
- **One owner look at the P2.3a1 state pictures** before the HUD tasks start, after the player-experience reviewer's check.
- **A missing or clamped 2560x1080 run leaves the P2.3a1 gate pending** for the owner (another host, an offscreen run labelled as such, or accept without it); no silent fallback.
- **Package names:** P2.3a2 "Know why an order failed" and P2.3a3 "Read the battlefield"; P2.3a1 keeps "See your selection".
- **Interim build menu in fewer columns:** the slab keeps the command card's future 432 px width, so the build menu takes as many columns as fit the longest labels (likely two) and grows taller until P2.3b.
- **Development notes' Start here** gets its missing entries (P2.2, P12, Sim boundary, the A/B lab, P2.3a) in P2.3a1's docs step.
- **Offline freeze signal:** whether the driver may take one more pump access than the boundary check pins goes to a research round (the engines in `~/projects` and the sim boundary critique, private) before the plan.
- **Spec approved** (user, 2026-11-19): [P2.3a design](../superpowers/specs/2026-11-19-p2-3a-see-your-selection-design.md), with the freeze signal's mechanism left to that research round.
- **Offline freeze signal through a pump `failure()` call, offline pin 9 to 10** (after research over the code and the sim boundary critique, the engines in `~/projects` and SB5, judged by Fable 5.2; reports private): the pump keeps the first failure reason (job kind and last published tick; the real cause is Godot's own script error line on stderr, which GDScript cannot catch) and returns it from one main-thread call, `""` while healthy or stopped; the offline driver logs it once with `printerr` and shows the freeze notice in the same frame; the pinned count in `tools/test_sim_boundary.py` changes in the same commit with its reason. SB5a reuses the same call for its own detectors, because there a refused post can mean a full queue. The leave path's null read on a failed pump (`record()`, `flush()`) is fixed in the same task.
- **The match record names the failure:** the playtest match record's `end` field reads "sim pump failed: <reason>", so a friend's report keeps it when stderr is lost.
- **The freeze notice stays in P2.3a1** although release builds may raise no script error, so in friends' builds it may first fire once SB5a's detectors (stall, dead thread, owner-thread check) exist; P2.3a1 delivers the tested channel.
