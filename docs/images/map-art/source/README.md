# Map art: source

The page and scripts the pictures in `docs/images/map-art/` are made from. Every picture is a vector redraw of the game's exported shapes, so any of them can be re-made at 2560 x 1440 without upscaling.

Needs: Firefox (`/Applications/Firefox.app`), `python3`, `cwebp`; for proofs `magick` and `compare` (ImageMagick); Godot (`$GODOT_BIN` or `godot`) for the shape export and the round trip. A missing tool may be installed with Homebrew or `uv` (Pillow only as `uv run --with pillow python3 ...`).

Run from the repository root: `python3 docs/images/map-art/source/server.py` serves the repository root on 127.0.0.1:8769. Open `http://127.0.0.1:8769/docs/images/map-art/source/round6.html` in Firefox for the list of pictures.

Hashes (the page never shows anything else on a stage):

- `#pic=<name>&as=shot|final&scale=1|2`: the stage only, 1280 x 720 times `scale` pixels. `shot` is the selection the committed picture was shot with, `final` the selection for the re-shoot.
- `#export`: posts the picked shapes to `../shapes-picked.json` (`sh export.sh`). `#roundtrip[&set=today]`: compares `build/map-art/roundtrip-godot.json` with the page's own drawing (`sh roundtrip.sh`). `#audit`: paint order, footprint, owner share, contrast and colour-vision checks over every picked shape (`sh report.sh audit audit`).
- `#report=fonts`, `#report=pics`: post a text report to `build/map-art/<name>.txt` (`&name=<[a-z0-9-]+>` sets the file name). The last line starts with `PASS` or `FAIL`.
- `&font=inter` or `&font=arial` (proofs only): draw text in Inter from `build/map-art/proof-fonts/` or in Arial.

| File | What |
|---|---|
| `round6.html` | The page: shape resolution per step, ground, shadows, cliffs, fog, the scenes and the stages |
| `pics.js` | `PICS`: one entry per picture, `{shot, final, draw}` |
| `picked.js` | `PICKED`: the picked option data of rounds 1 to 5, in the structure the page reads |
| `draw.js`, `scenes.js`, `scenes5.js` | The shape projection and canvas drawing; the base scene cells; the round 5 terrain cells |
| `shapes-current.json`, `shapes-current.js` | The game's shapes exported at `10b9423`; the `.js` is what the page loads |
| `export_shapes.gd` | Headless Godot: the game's shapes as JSON (`-- --out=<file>`); `shapes-current.json` is its output at `10b9423` |
| `roundtrip.gd` | Headless Godot: bakes every shape of an export with `ShapeBake` (`-- --in=<json> --out=<json>`) |
| `export.sh`, `roundtrip.sh` | Run the page's `#export` and check the corrections; bake and compare the round trip (`sh roundtrip.sh [shapes json]`) |
| `page.css` | Page styles and the four Public Sans faces from `game/fonts/` |
| `server.py` | Static server; `POST /pick` writes `picks.json` (ignored by Git), `POST /export` writes `../shapes-picked.json`, `POST /report?name=` writes `build/map-art/<name>.txt` |
| `report.sh` | `sh report.sh '<hash>' <name>`: runs a report in headless Firefox, prints it, exits 0 only on `PASS` |
| `shoot.sh` | `[SCALE=1\|2] [AS=shot\|final] [OUT=dir] [EXTRA=...] sh shoot.sh [name ...]`: pictures as lossless WebP (default every picture, scale 2, `final`, into `docs/images/map-art/`) |

A selection is `{steps, fix4b, fix6}`: one option per step of rounds 1 to 6 (`'0'` is today, a step left out does not apply). `ALL_PICKED` and `ALL_TODAY` are the two extremes. The rounds 1 to 4 pictures keep their own ground and shadow drawing (`legacy` in the selection), so they still match the pictures as committed.
