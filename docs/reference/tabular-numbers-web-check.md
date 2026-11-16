# Tabular numbers web check

Result (2026-11-16, main `bf93cc3`, Godot 4.7.2 official templates): **tabular numbers work in the web build, in Firefox and Safari, exactly as in the native build.** Every measured width matches native to the pixel. The item "whether tabular numbers render in the web build" from the [design answers](design-answers-2026-11-08.md#package-review-second-pass-user-2026-11-13-night) is closed; P12 and the P2.3a design are no longer waiting on it.

What the HUD code must do: Public Sans digits are proportional by default. Tabular numbers need a `FontVariation` whose `opentype_features` turns on `tnum`; the shipped fonts' imports (`opentype_features={}`) do not. No fallback (digit cells, a monospace digit font) is needed.

## Facts

- **The fonts carry `tnum`.** All four files in `game/fonts/` (Regular, SemiBold, Bold, ExtraBold) list `tnum` and `pnum` in their GSUB feature list. Read with a small table-directory parser (fontTools is not installed); the script and its output are in the private notes.
- **The web build shapes with HarfBuzz.** The `Web` preset sets no custom template, so the official `nothreads` template ships. At run time `TextServerManager.get_primary_interface().get_name()` printed `ICU / HarfBuzz / Graphite (Built-in)` on macOS, in Firefox 160 and in Safari 27.2: the advanced text server, which applies OpenType features.
- **Default digits are proportional.** Without `tnum`, `1111111` is 35 px and `8888888` is 54 px at 12 px Regular.

## Method

A scratch scene in the throwaway worktree (branch `spike-throwaway`, not merged): Labels for `1111111`, `8888888`, `0123456789`, `$10,480` and `12:07` at 12, 16 and 24 px in Regular, SemiBold and Bold, each once with the plain font and once through a `FontVariation` with `opentype_features = {name_to_tag("tnum"): 1}`; each row also prints `Font.get_string_size()`. The web build posted the widths, the user agent and a viewport screenshot to `tools/serve_web_bench.py`.

```sh
godot --headless --path game res://scenes/tnum_check.tscn                 # native widths
godot --path game res://scenes/tnum_check.tscn -- --shot=<png>          # native screenshot
sh tools/export_build.sh Web <dir>/index.html                           # main scene pointed at the scratch scene
python3 -I tools/serve_web_bench.py <dir> <results> 8060
open -a Firefox http://127.0.0.1:8060/index.html                        # then Safari
```

`diff` of the 90 width lines: native vs Firefox identical, native vs Safari identical. The screenshots show the same: with `tnum` the ones are spaced to the eights' width. Screenshots, logs and the scene script are in the private notes (`tabular-numbers-web-check/`), not in this repository.

## Widths (px, `get_string_size`, identical on native, Firefox and Safari)

Proportional (plain font) / tabular (`tnum`):

| Text | 12 Regular | 12 Bold | 16 Regular | 16 Bold | 24 Regular | 24 Bold |
|---|---|---|---|---|---|---|
| `1111111` | 35 / 59 | 36 / 59 | 46 / 79 | 48 / 79 | 69 / 118 | 72 / 118 |
| `8888888` | 54 / 59 | 57 / 59 | 72 / 79 | 75 / 79 | 108 / 118 | 113 / 118 |
| `0123456789` | 72 / 85 | 76 / 85 | 96 / 113 | 101 / 113 | 143 / 168 | 151 / 168 |
| `$10,480` | 46 / 55 | 48 / 55 | 61 / 73 | 64 / 73 | 92 / 108 | 96 / 108 |
| `12:07` | 30 / 37 | 32 / 37 | 39 / 49 | 42 / 50 | 59 / 73 | 63 / 74 |

SemiBold lies between Regular and Bold and is tabular the same way. With `tnum` a digit is the same width in all three weights, so a number does not move when its weight changes.

## Not checked

- Chrome and the Steam Deck browser; the result rests on the template's text server, not the browser, so the risk is low.
- The 2x picture rule of the [art direction §12](../art-direction/ART_DIRECTION.md#12-interface-mock-ups) applies to mock-ups; these are evidence screenshots at the browser's device pixel ratio.
- No HUD code; the `FontVariation` belongs to the P2.3a design.
