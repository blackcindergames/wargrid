# HUD v5 mock-up: source

The HTML/CSS the pictures in `docs/images/hud-v5/` and `layout.json` are made from (art direction §12: implementers take sizes, weights, paddings and colours from this source, not from pixels).

Run from this folder: `python3 server.py` serves the repository root on 127.0.0.1:8767; open `http://127.0.0.1:8767/docs/images/hud-v5/source/round1.html` in Firefox. Fonts come from `game/fonts/`, backdrops from `worlds/`. A Pick posts to the server, which writes `picks.json` here (ignored by Git); the page says "Recorded." only when the server answered. Without `picks.json` every step's pick is A.

Keys: `A` / `B` flip, `Enter` picks, `1`-`9`, `0`, `,`, `.`, `-` choose one of the 13 states (`N` next), `T` tier (Full / Core), `S` size (1920 x 1080 / 1280 x 800 / 1280 x 720), `F` fit / 100 %.

Hashes (steps count from 0):

- `#step=2&show=B&state=many&size=1280&tier=core&picks=cell:A,side:B`
- `#final`: picks, coverage, contrast, owner colours, name fit, grid across factions, notes, gallery.
- `#shot=<state>&size=<1920|1280|720>&tier=<full|core>&scale=2&picks=...`: the stage only.
- `#audit`: every state x tier x size for the defaults and each single B: layout, colour, contrast and theme rules.
- `#layout&picks=...`: posts the layout document to `/layout`.

| File | What |
|---|---|
| `round1.html` | The page |
| `glyphs.js`, `glyphs3.js` | Unit, building and command glyphs |
| `worlds/` | Backdrops `w-<state>.png` at 2560 x 1600 (`full` uses `w-factory.png`); a missing one shows plain sand |
| `server.py` | Static server for the repository root; `POST /pick` writes `picks.json`, `POST /layout` writes `../layout.json` |
| `shoot_final.sh` | `sh shoot_final.sh [picks]`: the 26 pictures, 2560 x 1600 lossless WebP, into `docs/images/hud-v5/`; needs the server, Firefox and `cwebp` |
| `export_layout.sh` | `sh export_layout.sh [picks]`: `../layout.json` for the Godot layout tests; fails when the file was not rewritten or a screen's covering rects do not sum to its coverage figure |
