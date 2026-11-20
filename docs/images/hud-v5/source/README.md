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
| `hud.js`, `hud.css` | The shared HUD drawing (the map art page loads them too) |
| `glyphs.js`, `glyphs3.js` | Unit, building and command glyphs |
| `worlds/` | Backdrops `w-<state>.png` at 2560 x 1600 (`full` uses `w-factory.png`); a missing one shows plain sand. Re-made by `../../map-art/source/shoot_worlds.sh` |
| `server.py` | Static server for the repository root; `POST /pick` writes `picks.json`, `POST /layout` writes `../layout.json` |
| `shoot_final.sh` | `sh shoot_final.sh [picks]`: the 26 pictures, 2560 x 1600 lossless WebP, into `docs/images/hud-v5/`; needs the server, Firefox and `cwebp` |
| `p2-3a1-states.html` | The P2.3a1 states at a 1280x720 layout: `#shot=<state>&size=720&scale=2` draws one state (`slab`, `notice`, `freeze`, `freeze-copied`, `sites`, `chips`, `chips-f3`, `chips-f3-rule`, `chips-checklist`, `chips-form`, `chips-off`, `refusal`, `pile`, `rows-footer`, `unload`, `collector`, and from gate A round 2 and the director round `queue`, `queue-open`, `forecast-card`, `slab-army`, `slab-poor`, `slab-builder`, `low-power`, `offline`; `forecast`, the first round's strip forecast, stays for the gate page but is no longer shot); the colour tokens include `warn` (`#f47b6c`); without a hash, all of them at 1x. War Room's stage controls add `&size=1280x800` or `1720x720`, `&world=<backdrop>`, `&ground=dark` or `none` (transparent), `&hud=0` and `&you=<hex>` (`warroom/README.md`) |
| `p2-3a1-gate.html` | Owner page for the P2.3a1 gate A second look: Unload rule, attack-move hint, card question, then every state with a note box and the verdict; picks go to `picks.json` under `p2-3a1-gate:` keys. `#step=1`-`5` opens a step (`5` the summary), `#step=4&state=<state>` a gallery state. Its pictures are `p2-3a1-states.html` states in iframes, including the gate-only `unload-loaded`, `unload-empty-hidden`, `unload-empty-greyed`, `unload-empty-always`, `armed-hint` and `armed-none` (not shot) |
| `p2-3a1-gate.html#round=2` | Gate A round 2: queue cap (A-D), purchase preview placement (A-B), warning colour (A-B, each also as deuteranopia and protanopia), the changed states with the verdict; picks under `p2-3a1-gate2:` keys, `#round=2&step=1`-`5` (`5` the summary); gate-only states `queue-a`, `queue-a-open`, `queue-a-hover`, `queue-b`, `queue-c`, `queue-d`, `forecast-a`, `forecast-b`, `forecast-c`, `forecast-c-armed`, `forecast-c-unit`, `forecast-c-list` (not shot); `p2-3a1-states.html` takes `&cvd=deut` or `&cvd=prot` |
| `shoot_p2_3a1.sh` | `sh shoot_p2_3a1.sh [state ...]`: the P2.3a1 pictures, 2560 x 1440 lossless WebP, into `docs/images/hud-v5/` (`collector` writes `collector-status.webp`); needs the server, Firefox and `cwebp` |
| `export_layout.sh` | `sh export_layout.sh [picks]`: `../layout.json` for the Godot layout tests; fails when the file was not rewritten or a screen's covering rects do not sum to its coverage figure |
