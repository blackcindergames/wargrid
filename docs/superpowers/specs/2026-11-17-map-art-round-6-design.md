# Map art round 6: consolidation and a short pick round

Status: design **approved** (user, 2026-11-17); plan not written, nothing built. Branch `spike-art-6`. Decisions: [round 6 scope questionnaire](../../reference/design-answers-2026-11-08.md#map-art-faction-shapes-m75-user-2026-11-13) (user, 2026-11-17).

## Intent

The map art picked in rounds 1 to 5 (2026-11-13 and 2026-11-14) is the input of three packages that have no design yet: P2.4 Three armies, P2.5 Supplies you can read, P2.6 Three kinds of base ([packages](../../packages.md)). Since then the HUD was redrawn as v5 and a set of look rules was decided. The map art did not follow:

- Its page and picked data are working files in the private notes repository (`art-spike/`); the repository holds pictures only. HUD v5 keeps its page, an export for tests and a layout reference beside its pictures; only its backdrops, drawn from the map art by a private generator, cannot be re-made from the repository.
- Its pictures are 1x, two are known wrong, the base scenes carry the HUD v4 layer and today's colours.
- Decisions made after round 5 are not drawn: the map edge on the dark canvas, 2:1 unit shadows, the white map marks.
- The art bible (v1.3, 2026-11-09) still states superseded proposals.
- Some looks the packages need were never drawn or picked.

Round 6 brings the map art to the HUD v5 standard, closes the open looks that block the three packages, and leaves each package a place to read its facts from. It changes no game code.

It runs before the P2.3a design (user, 2026-11-17): the map edge on the dark canvas and the white map marks are P2.3a riders, and its design reads them from round 6's reference doc.

## Goals

1. An implementer of P2.4, P2.5 or P2.6 finds every picked shape, size, colour and affected test in the repository, without the private notes and without measuring pixels.
2. Every map art picture can be re-made from the repository with one command.
3. The pictures show the look as decided today, at 2x.
4. The open looks named below are picked by the user on a labelled A/B page.
5. The art bible states decided rules.

## Non-goals

- No change under `game/`, no simulation, trace or test change, no benchmark row.
- The capture script (its own item, before P2.4).
- Anything routed to the in-game art lab: the occluded-unit cue (F17), pale roof edges, the contact mark under infantry, the completion settle and roof inset, dark ground on Ashfall, health bar size and rule.
- Power Plant drums and edge aliasing (P2.6 rider), driving cues (P2.4 rider), a bolder infantry faction cue at zoom 0.5 (accepted as not readable there).
- Zoom 2 versions on the picked hulls (P2.4).
- Ground and decoration polish (with the map ports).
- The designs and plans of P2.4 to P2.6.

## Anti-goals

- Reopening a pick of rounds 1 to 5. The darker side band, the lifted owner colours and the picked bodies stand.
- A picture or number in the repository that cannot be traced to the source beside it.
- Private working material in the public repository: build specs, recorded picks, scratch pages, browser profiles, handoffs, anything `tools/check_public.sh` rejects.
- New picks stated as verified. Round 6's looks are page data; only the geometry that passes the round trip is called proven in Godot, and everything else is labelled as not run there.

## Constraints

- [Art direction §12](../../art-direction/ART_DIRECTION.md#12-interface-mock-ups) applies to the pictures that carry the HUD layer: Public Sans from `game/fonts/`, 2x, source beside the pictures, every state.
- The five [screenshot marks](../../art-direction/ART_DIRECTION.md#11-acceptance-gates).
- Defaults for game behaviour are looked up in Zero Hour before they are offered (low power, wrecks, paused construction), cited with path, line and revision.
- Pages open in Firefox. Screenshots are rendered to files; no visible game window is needed. Godot runs headless only, for the shape export and its round trip; a scratch Godot script quits on every path.
- `shapes.gd`, `palette.gd`, `shape_bake.gd`, `world_batch.gd` and `world_view.gd` are unchanged since `10b9423`, the commit the "today" export was taken at (checked 2026-11-17 on `9b21db3`); the plan re-checks this before reusing the export.
- No commit without the user's approval; subagents never commit.

## Approaches

**A. Finish in the private folder, then copy the result.** Round 6 is `round6.html` beside rounds 1 to 5 in `art-spike/`; a trimmed copy goes to the repository at the end. Fewest moving parts during the picks. But the repository copy is then never used before it is declared self-contained, and the pictures are shot from a tree nobody else has.

**B. Move first, then pick in the repository (picked, agent call; the user handed over the how).** Step one trims the page into `docs/images/map-art/source/` and re-shoots the existing pictures from there. The pick round is then built in that folder and is its first real user, so a missing file shows at once. Build spec, drawing briefs and recorded picks stay private, as for HUD v5.

**C. Rebuild the page on the HUD v5 page.** One page for HUD and map. Rejected: the map page's drawing code is checked against the game's bake to 0.00001 px on 552 of 555 poses; a rebuild throws that away for no gain.

## Design

### Part 1: source in the repository

`docs/images/map-art/source/`, modelled on [`docs/images/hud-v5/source/`](../../images/hud-v5/source/README.md):

- One page with round 6's steps on top of the picked look of rounds 1 to 5, its drawing code, scene data and the picked candidate data as one set of files, not one file per round and drawing agent. No single private page holds all of it: the round 1 to 3 pictures come from `final.html`, round 4's from `round4.html`, and `round5.html` has rounds 1 to 4 built in without a "today" switch. The three are merged so that every existing today and picked pair can still be shot.
- The "today" shape export and the headless script that makes it, with the commit it was taken at and a command that runs from this repository.
- **One shared HUD file** (user, 2026-11-17): the HUD drawing moves out of the HUD v5 page (`docs/images/hud-v5/source/round1.html`, where it is inline) into its own file that both pages load. The map page's HUD v4 copy goes. Proof: the 26 HUD pictures and `layout.json` re-made from the edited source show no difference to the committed ones, before anything else about them changes.
- The glyph-size views of rounds 1 to 3 are dropped (user, 2026-11-17): round 6 judges no new unit or building body, and the glyph decision after P2.6 uses the game's own shapes.
- A small server and one shoot script that writes every picture, 2560x1440 lossless WebP, into `docs/images/map-art/`.
- A README: how to run, keys, hashes, a file table.
- Recorded picks are written beside the page and ignored by Git; without them the page shows the picked options.

Left out: scratch pages, per-agent passes, generators, browser profiles, earlier round pages, shots.

### Part 2: shape export

`docs/images/map-art/shapes-picked.json`: every picked shape in the format of the game's own export (parts, sizes, heights, colour slots), per role and faction, with the palette values that change (side band, owner colours, cliff factors, cargo colour, and round 6's picks). Written by the page through the server, as HUD v5 writes `layout.json`, and failing when the file was not rewritten. The corrections decided after the drawings are baked in: FRC tank 0.7 cells, Armed Pickup about 0.65, tanks exactly 3 units tall.

A header names what is provisional: zoom 2 versions that do not exist yet. Agent calls: the Armed Pickup is pinned at exactly 0.65 cells; how its parts follow the shorter hull is the drawing agent's, inside the page's audit; the export carries the zoom 1 parts and the zoom 2 versions that exist, the missing ones are listed, not invented.

**Round trip in the game's code** (user, 2026-11-17): a headless scratch script, kept in the source folder, feeds every shape of the export through the game's own bake and compares the triangles with the page's, at the eight headings and three zoom steps. No game code changes. A pass proves the picked geometry in Godot; pixels, motion and feel stay unproven and the notes say so. A shape that fails is fixed in the candidate data or listed as failing, never dropped from the comparison.

### Part 3: pictures

Lossless WebP throughout, as HUD v5 (user, 2026-11-17). Shot twice (agent call). First straight after the move, unchanged looks at 1x and 2x, only to compare with the committed pictures; these are not kept. Then the final set after the picks. "Picked" in the final set means the look as decided including round 6. The map edge shows only where a scene reaches the map's border, the marks only in the marks picture and the gate reference.

All existing pictures re-shot at 2x from the repository source, with:

- the tank row corrected for FRC;
- the base scenes in the picked colours, without a HUD layer;
- the 2:1 unit shadow in the "picked" pictures.

New pictures:

- **Marks:** every decided white mark (selection, hover ticks, attack X, closing move ring, placement cells valid and blocked, range ring, rally pole and flag with its line, dashed target line) on sand and on the dark ground.
- **Gate reference:** one composed scene under the HUD v5 layer with the picked map edge, showing all five screenshot marks.
- **Old shapes check:** defences, the Laborer, the supply truck and rubble beside their faction's picked bodies under the darker sides.
- One today and picked pair per round 6 step.

**HUD v5 backdrops** (user, 2026-11-17): after the picks the map source writes the backdrops the HUD v5 page reads from its `worlds/` folder, and the 26 HUD pictures are re-shot once with round 6's look. `layout.json` must come out unchanged. The HUD v5 notes then drop their "not re-makeable" line.

### Part 4: the pick round

A labelled A/B page, opening on sand at zoom 0.5 with the lifted owner colours, HUD v5 layer switchable, dark ground one key away. Four A/B steps, each with computed numbers where a rule exists (contrast, colour-vision distance):

1. **Dark surfaces:** the supply pile pad, doors on building side faces, building sides at zoom 1 on the dark ground. The side band itself is fixed.
2. **Neon set (F12):** a teal clear of the HUD cyan and a blue and purple pair that pass the colour-vision bar of 20; the HUD cyan is fixed. Neon stays an opt-in set (user, 2026-11-17, asked again against dropping it).
3. **Map edge and canvas:** edge height and the canvas colour; slate side faces on the camera-facing edges and no lit top line are fixed.
4. **Low power and a dark defence (F21):** how a building and a defence show that they have no power. The page picks a favourite; the art lab confirms it in the game, and F21 stays open until then (user, 2026-11-17).

Two draw-and-confirm steps, one drawing each, answered yes or change (user, 2026-11-17), because their rule is already decided:

5. **Paused construction:** round 3 decided that posts alone mean just started or paused; drawn for a site paused part-way.
6. **Vehicle wrecks** on the picked hulls, in the art lab's wreck look; they stay 20 s for tanks and 8 s for light vehicles, as decided.

Only if the old shapes check shows a clear clash: one more A/B step for that shape.

Before the user's look: the [player-experience reviewer](../../../.claude/agents/player-experience-reviewer.md) on screenshots of every step. After the picks: a short questionnaire for what the picks leave open, including which package each pick lands in where none is named today (wrecks are a backlog item, F21 "a later art package").

### Part 5: documents

- **`docs/reference/map-art-shapes.md`:** how to read the export; then one section per package (P2.4, P2.5, P2.6) with its shapes, sizes and heights to re-pin, palette values, the tests each pick touches, its riders and its art lab items; a section for P2.3a (map edge, canvas, mark sizes) and one for picks not placed in a package yet (agent call); a last section "not covered or not decided". Facts move here from the design answers' research paragraphs, which keep the decisions and link to it.
- **Art bible v2:** sections 4 to 9 become the look as decided, short, each rule linking to its decision, illustrated with the map art pictures; rules in words, every size, colour value and test only by link to the reference doc and the export (user, 2026-11-17); it opens with round 6's gate reference picture in place of the GPT north star (user, 2026-11-17); superseded proposals go; the interview table, §11 and §12 stay; §12 gains one line that map art pictures follow the same source and resolution rule. Agent calls for the rest: the header says v2, who wrote which part, and that decided rules carry their tag while anything else is a proposal; §3 stays, checked against the code; §10 shrinks to its links; §13 (provenance and rights) stays word for word; §2 and the eight GPT sheets move to one closing section "Where it started (2026-11-09)", labelled as the starting proposals.
- **`docs/images/map-art/notes.md`:** the new table, what is real and what is not, the source folder.
- **Design answers:** a "Round 6" block with the picks and the agent assessment, in the form of rounds 1 to 5.
- **`docs/packages.md` and `docs/STATUS.md`:** links to the reference and the export in the P2.3a and P2.4 to P2.6 rows, round 6's picks as riders where they land, F12 and F21 updated with what was picked (F21 stays open). No package state changes, so the README roadmap is not regenerated.
- **`docs/images/hud-v5/notes.md` and its source README:** the shared HUD file and the re-makeable backdrops.
- **`docs/development.md`:** one line under Start here.
- The codebase guide is not touched: nothing about how the game works changes.

## How the work runs

By day in one session (user, 2026-11-17), not as a night run: the user is asked when the page is ready for the picks. A coordinator with one fresh subagent per task; model and effort per task (user, 2026-11-17):

| Task | Model, effort | Why |
|---|---|---|
| Plan | Opus, high | Plans are written by Opus |
| Trim and move the source, shoot script, re-shoot | Sonnet, medium | Mechanical, checked by re-made pictures |
| Shared HUD file and the no-difference proof | Sonnet, high | Edits a reference source; proof is pass or fail |
| Shape export, its check against the page and the Godot round trip | Sonnet, high | Small code, exact numbers |
| Drawing candidates for steps 1 to 6 | Opus, high, one agent per step | Look work is routed by quality |
| Colour arithmetic for steps 1 and 2 | Sonnet, medium | Computed, pass or fail |
| Zero Hour defaults for steps 4 to 6 | Sonnet, medium | Lookup with citations |
| Reference doc and art bible v2 | Opus, high | States code facts and decisions |
| Link, path and public checks | Haiku, low | Decision-free, pass or fail |
| Review of the page and pictures | player-experience reviewer | Project rule for art |
| Review of the documents against the code | fresh Opus, high | Docs with code claims |

## Verification

- Every picture re-made by the shoot script from a clean checkout of the branch; the first shoot compared with the committed 1x pictures.
- After the shared HUD file: the 26 HUD v5 pictures and `layout.json` re-made with no difference; after the backdrops: `layout.json` still unchanged.
- The export checked against the page's own drawing data, its "today" counterpart against the game's export, and the picked shapes through the headless round trip.
- The page's audit (paint order at eight headings, footprint, owner-colour share, contrast and colour-vision tables) over every round 6 candidate, with no failure in a picked option.
- `sh tools/check_public.sh`, `sh tools/run_shell_checks.sh`, `sh tools/run_python_checks.sh`; links and paths in every touched document.
- Not verified by this round, stated in the notes: anything in Godot, motion, the rendered benchmark, a real Steam Deck.

## Left to the builder

- Which files of `art-spike/` make up the trimmed set, and how the candidate files are merged.
- The export's exact field names, following the game's export.
- The options offered in each step and the recommendation, after the drawing agents report.
- The scene composition of the new pictures.
- File names of new pictures, following the existing pattern.
