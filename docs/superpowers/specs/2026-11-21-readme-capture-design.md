# README capture: scripted screenshot and fight clip

**Why.** The README picture (2026-11-07) shows the placeholder shapes and a bot-against-bot mode that no longer exists; it has been owed since 0.11.0. A scripted, reproducible capture replaces it with a real match in the HUD v5 look (user, 2026-11-21).

**Goals.** One still and one short fight clip (about 10 s, 960 px wide, animated WebP inline in `README.md`), from a real match: Dry Wells, USA (player 1) against China, the player's army in the fight selected, fixed camera on the fight (user, 2026-11-21).

**Non-goals.** No bot-against-bot mode in the game; no changes to simulation, HUD or match code (capture only); no camera pan.

**Approaches.**
- Chosen: run both bots headless with `Skirmish.issue_opponents(sim, [1, 2])` to the first big clash, adopt the sim into the skirmish screen in a SubViewport (the `hud_capture.gd` pattern), capture.
- Rejected: hand-placed armies from `economy_fixture` (not a real match); Movie Maker (no scripted staging); a bot-against-bot mode in match code (out of scope).

**Design.**
- `game/scripts/lab/readme_capture.gd`, a `SceneTree` script run through `tools/run_game.sh` with `--fixed-fps 30`, argument an absolute output folder.
- Clash tick found at run time (deterministic sim): the first tick with at least 8 units of each owner within 8 cells of one point; fail past a tick cap.
- 1280×720 match view (built drawn at 2x, clip cropped to the fight; see guide 13); camera on the clash centre; player 1's units near it selected; save `skirmish.png` (converted to lossless `docs/images/skirmish.webp`, replacing `skirmish.png`).
- Then 300 frames as PNGs; ffmpeg to `docs/images/skirmish-fight.webp` (960 px, `libwebp`, lossy, `-loop 0`); 15 fps if 30 fps exceeds about 4 MB.
- After adoption the driver runs only seat 2's bot (`OfflineDriver.BOTS`); the script runs seat 1's itself before each tick (changed after the PX review: seat 1 on its last orders looked passive).
- Fails on a blank frame, no clash within the cap, or an empty selection.
- Docs: README image, alt text, caption; guide 13 capture section and `Checked against` footer.
- Reviews: player-experience reviewer on still and clip; correctness review of the script.

**Left to the builder.** Exact clash radius and counts, if the first clash proves too small or too early; the ffmpeg quality value.
