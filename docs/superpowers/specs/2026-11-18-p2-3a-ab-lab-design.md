# P2.3a A/B lab design

Status: approved (user, 2026-11-18).

## Intent

P2.3a builds the HUD's selection half from the HUD v5 Core set ([layout reference](../../reference/hud-v5-layout.md)). Four looks are still open. The owner picks them before the P2.3a plan, in one attended window session in the in-game lab, with no offscreen probe first ([design answers](../../reference/design-answers-2026-11-08.md#p23a-groundwork-questionnaire-user-2026-11-17)). This package builds that lab so the session can run tonight, batched with the SB4 owner check.

Goals:
- the four picks shown side by side;
- the picks recorded in a file the agent reads;
- nothing in the game changes.

Non-goals:
- building the P2.3a HUD;
- changing `palette.gd` or the match HUD;
- web or Steam Deck runs (desktop window only).

Anti-goal: a lab variant that differs from the v5 values it claims to show. Each variant cites its source value.

## Approaches

- **A. Extend the art lab (picked, user 2026-11-18).** Four new questions in `game/scripts/lab/ab_variants.gd`, same keys (`[` `]` question, Tab variant). One lab, one launch command.
- B. A separate HUD lab scene. Cleaner split, but a second lab with its own keys.
- C. A/B inside the match HUD. Ruled out: that is P2.3a's own work, and the picks come before its plan.

## The four questions (user, 2026-11-18)

1. **Token set A against B, shown side by side** (both panels at once; most slots differ by under 5 dE, so a Tab flip would be noise; user, 2026-11-18).
   - Set A is `hud-v5-layout.md` tokens.
   - Set B is the visual-UX set from the design answers.
   - B's missing slots (`panel2`, `quiet`, `well`) are derived from B's slab with A's lightness steps, marked as an agent derivation.
   - The owner colours `you` #628ffa, `enemy` #d6120c and `ally` #69ceaa are the same in both sets, so only the neutrals differ.
   - A slot-map table says which B colour fills each A role (B slab to `bg`, divider to `line`, secondary text to a named role); B's own canvas slot `#111c24` is obsolete beside the canvas `#08090A`.
   - The derived slots `panel2`, `quiet` and `well` are not seen in the Core states; they are marked unseen and re-checked in P2.3b.
   - The page offers "no difference" as an answer.
   - A computed table, not a window check, covers owner colours against the winning `sel` (user, 2026-11-17 check).
2. **Health-bar rule:**
   - selected or hovered (Zero Hour);
   - selected, damaged or hovered (today);
   - damaged or hovered.
   - Bars carry the decided owner frame: a 1 px frame outside a black 0.7 track, so the track separates frame from fill (agent proposal, from the player-experience review; without it the enemy frame vanishes on a low red fill, 1.22:1).
   - A second view runs the existing live `lab_fight.gd` under the same rule setter, so bars appearing on the first hit can be judged; judged at zoom 0.5 and 1 (user, 2026-11-18).
3. **Value size:**
   - the Numbers role at 13/700 against 14/700;
   - row names stay at 13/600, the panel title at 14 and the credits at 16;
   - tabular numbers on in both, through a `FontVariation` with `tnum`;
   - the lab window is fixed at 1280x800 (the Steam Deck size and the 16:10 cap), and a 1x offscreen capture of the one-unit and group states sits at 100 % on the click page, with the widest numbers (`1,240 / 2,000`, row counts for 120 units), because a 2x Retina screen flatters both sizes (user, 2026-11-18).
4. **Drag box** (user, 2026-11-18, after an RTS practice check and a player-experience check). Both options use a white 1.5 px line over the white-mark under-stroke `rgba(14,18,22,0.78)`, 2 px wider, and show the live preview: the hover corner ticks on the player's own units the release would pick (`pick_entities` rules: own units, ground centre inside, no buildings; a hovered enemy's ticks hidden during the drag; the Shift case shown).
   - white, no fill;
   - white with 4 % white fill (inside the 2 to 6 % other games use; Beyond All Reason and Warzone 2100).
   - Today's green (0.55, 1, 0.53) 1 px, no fill, drawn exactly as today (no under-stroke, no preview), as a baseline only, not a shipping option.
   - Dropped: the owner-colour box (1.02:1 on sand, invisible over the player's own blue army, red for seat 2; no checked game tints the box by owner), corner-only boxes (corners are the hover mark) and dashes (dashes mean the target line).
   - Shown held open over the mixed army, plus one drag across the map edge onto the canvas, on both grounds at zoom 0.5, 1 and 2.
   - Sources: Zero Hour `0a05454` `GeneralsMD/.../W3DInGameUI.cpp:450-460` (green `0x9933FF33`, 2 px, no fill); OpenRA `b4d95a5671` `mods/common/metrics.yaml:55-57` (white 1 px, live health bars inside); Recoil `a0240a9b5c` `CommandColors.cpp:84` (white, 1.49 px); Beyond All Reason `a31aa1c194` `gui_selectionbox.lua` (white, about 2.4 % fill, dark edge); 0 A.D. `136720dada` `session/sprites.xml:581-590` (white with a 1 px black outline). StarCraft II, Age of Empires IV and Company of Heroes 3: no primary source found.

## Aligned with map art round 6

The lab shows the world as P2.3a will ship it, from [map art round 6](../../reference/map-art-shapes.md#p23a-see-your-selection-map-edge-canvas-and-marks), not as the game draws it today. All of it is lab-only drawing; `palette.gd` and `world_view.gd` stay unchanged (P2.3a and P2.4 change them).

- **Owner colours:** palette A (`#628ffa` blue, `#d6120c` red, `#4ad49b` green). The game today still draws the old colours in `palette.gd`.
- **Marks:** the round 6 white marks with their dark under-stroke `rgba(14,18,22,0.78)`, 2 px wider, at the sizes in the marks table: unit diamond, hover corner ticks, building footprint. Not today's selection green `#8cff87`.
- **Map:** edge B (`EDGE_HEIGHT` 24, `EDGE_SIDE` `#425463`) on canvas `#08090A`, so the HUD tokens are judged against the real surround.
- **Ground:** both surfaces A grounds, sand and the dark ground `#7B7566`, switched with a key, because a mark or a bar that reads on sand can fail on the dark ground.
- **Health bars:** the decided green-yellow-red fill with a thin owner frame, 24 x 3.
- **No fog:** fog is not in the game yet, so no fogged look is judged.
- **Open point carried:** palette A green `#4ad49b` sits 15.0 from the HUD `ally` token `#69ceaa`. The lab shows both together; it does not decide the point.

## Scene

**Army.** A frozen 120-unit scene, no fight:
- 60 units per side;
- about 40 % damaged, a third of them at 90 to 99 % (the scratches most units carry after a fight), the rest at 15 to 90 %, with enemies below 33 %;
- an ally owner in palette A green, with a minimap-dot swatch beside it, so `#4ad49b` and the `ally` token `#69ceaa` are seen together;
- 10 of the player's units selected: 5 healthy and 5 damaged, since healthy selected units are where the rules differ;
- one enemy unit hovered.
(Fixture changes from the player-experience review, user, 2026-11-18.)

**HUD panel.** A lab-only v5 panel built from the active token set. It shows the Core selection states, switched with a key:
- one unit;
- a mixed group;
- the player's building;
- an enemy unit;
- a supply pile (where A's `line` and B's divider show on the 4 px edge);
- LOW POWER with the forecast (amber against text);
- plus the top bar with credits.

The panel sits where it overlaps the canvas and the map edge: slab on canvas is only 1.16:1 (A) and 1.30:1 (B), so the 1 px border carries it (user, 2026-11-18).

The panel uses the game's font with v5 sizes. It is lab-only Control code, and no game code refers to the lab.

**Picks.**
- A new small click page in Firefox lists the four questions, each with neutral letters, a "no difference" option, a note field and a field for window size and display.
- Labels such as "today" or "Zero Hour" appear only after the pick, and each question starts on a random variant, against status-quo bias (user, 2026-11-18).
- It is served locally the same way as the art-lab A/B page (`tools/serve_web_bench.py`).
- Results land in a JSON file outside the repository.

## Checks

- A headless layout test for the lab panel (each state fits; no text clipped at either value size).
- A lab test that every new question switches its variant.
- One batch of offscreen screenshots per question, compared by a reviewer with the v5 pictures before the owner's look.
- `sh tools/run_checks.sh` and the full suite.

## Left to the builder

- The exact fixture positions.
- The key for panel states.
- The page's layout, following the earlier A/B page.
- How the derived B slots are computed, stated in the code with its source.
