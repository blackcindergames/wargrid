# Decision page

> Successor: [War Room](../../warroom/README.md), the Go port, runs in parallel with this prototype (user, 2026-11-19).

One reusable owner page for decision rounds: steps with options A to D on one stage, a click records the pick on the server, and the page moves on. Decided in the design answers, "Decision app" (user, 2026-11-19). This is the prototype: the core flow and the stage controls (window size, fit, ground, backdrops, zoom, HUD layer, colour vision and more, below); a short spec follows once the owner has looked.

## Run it

```sh
python3 tools/decision_page/server.py
```

Then open `http://127.0.0.1:8770/tools/decision_page/` in Firefox (`/` redirects there). The server serves the repository root, so rounds can embed `docs/images/...` and `game/...` files.

| Variable | Default | What |
|---|---|---|
| `DECISION_PICKS` | `tools/decision_page/picks.json` (ignored by Git) | Where picks are stored |
| `DECISION_ROOT` | the repository root | The folder that is served |
| `DECISION_HOST`, `DECISION_PORT` | `127.0.0.1`, `8770` | Where the server listens |

Endpoints: `POST /pick` takes `{key, pick, note}` and answers 204, 400 for a body over 8 KiB, a key of a round the site does not ship, a pick that is not 1 to 16 letters (or `null`) or a wrong type, 507 for a new key past 500 keys, 500 when the write fails or the picks file is not a JSON object of entries (the file is left as it is); a client that stalls for 15 s, or has not sent its whole request after 15 s, is dropped. `GET /picks.json` and `GET /picks.js` (`DP.saved({...})`, a script so a headless screenshot waits for it) read the picks back, or answer 500 on such a file; `GET /health` answers 200. Writes are atomic (temporary file, then rename); the page sends one key's posts one after another, so an older one cannot land last.

Tests: `python3 tools/decision_page/test_server.py` (also run by `sh tools/run_python_tests.sh`).

## Page rules

Click to record; "Recorded: <step> <pick>." (the last 204; plain navigation clears it) only on a 204, otherwise an amber "Not recorded" line keeps the pick on the page with a Retry button and the step's chip turns amber and dashed. A pick moves to the next step. No Save button, no download, no autoplay, one tab. About five steps per round. Every step shows Claude's pick and notes per option.

## Keys

| Key | What |
|---|---|
| `A` `B` `C` `D` or `1` to `4` | Show that option on the stage (side by side: highlight it) |
| `Enter` | Pick the shown option, record it and go on |
| `W` | One at a time / side by side |
| `←` `→` (`[` `]`, `Backspace` back) | Previous / next step without picking (wraps through the summary) |
| `N` `P` | Next / previous item inside a step (gallery picture, or the state on a step with a state control) |
| `L`, or a click on a picture | Large view; `Esc` or a click closes it |
| `Space` | Play / stop the shown option's sound |
| `?` | Key list, with the stage controls this step has |
| `S` `F` `G` `⇧G` `Z` `H` `T` | Window size, fit / true 100 %, ground, game-world backdrop, zoom, HUD layer, tier |
| `O` `⇧O` `R` `⇧R` `⇧C` `M` `K` | Owner colour, colour set, unit heading (back), colour vision, small-change marker, numbers panel |
| `V` `X` `⇧F` | Taken by a step's own controls (view, camera, faction pair in the demo) |

Resolved clashes from the older pages: arrows move between steps (not flip), letters and digits only pick options, `N` `P` only step inside a step, `[` `]` are step aliases so heading moved to `R`, `C` is option C so colour vision is `⇧C` and the numbers panel `K`, no `Tab`, `Space` only plays.

Keys do nothing while a note or a list has the focus or with Cmd, Ctrl or Alt. Below 900 px wide or on a touch screen a two-row button bar at the bottom covers every key; its View button opens a sheet with the stage controls, Whole screen and the key list, and scrolls the stage above the sheet so a change shows; a swipe on the picture flips the option (gallery: the item). There a tap on the picture shows the step's crop at 200 % of game pixels (a whole frame at 100 %) to pan, opened on the step's mark or the crop's middle, and Whole screen shows the whole frame as the desktop's Large does. The step's "Where to look" line and its reference picture (folded) come right under the question, then the stage; "Why this question" is folded.

Side by side, "Why this question" is folded, the reference picture is the first tile at the options' scale and the step's other panels (checklist, numbers) follow the tiles. The summary lists the round's unanswered steps as links, and says the tab can be closed only when every step is answered.

Hash: `#round=<id>&step=<n|summary>&show=<A-D>&view=side&item=<id>`, plus every stage control away from its first value (`size`, `fit`, `ground`, `world`, `zoom`, `hud`, `state`, `tier`, `owner`, `set`, `heading`, `cvd`, `marker`, `x-<id>`). The page keeps it current, so a reload returns to the same view. Read only: `sheet=1` opens the phone's View sheet, `keys=1` the key list, `shot=1` the shown option alone at its frame size on black (`crop=step` keeps the step's crop), for `shoot.sh`. Without `step` it opens the first unanswered step. Without `round` it lists the rounds of `rounds/index.js`; entries with `demo: true` only with `demo=1`.

## Rounds: the data contract

A round is a folder `rounds/<round-id>/` with `round.js` and one file per step, `<step-key>.js`. List it in `rounds/index.js` (`DP.index([{id, title}])`). Files are plain JavaScript that call `DP.round({...})` or `DP.step({...})`; nothing is computed at load time.

`round.js`:

| Field | What |
|---|---|
| `id` | The folder name (`[a-z0-9-]+`) |
| `prefix` | Optional key namespace, default `id`. Write it as `prefix: '<name>',` on its own line: the server reads that line to allow the round's keys |
| `title` | Shown in the header and the summary |
| `steps` | Step keys in order; a missing file shows `[step missing: <key>]` |
| `earlier` | Optional round ids whose picks the summary lists and `uses` can name |
| `render` | Live-render recipe `{page, w, h, hash, pass}` over the app's default (`p2-3a1-states.html`, 1280 x 720, `shot={state}&size=720&scale=1`); `hash` has `{state}` in it |

Step file, common fields:

| Field | What |
|---|---|
| `key`, `kind` | The step key (the file name) and its kind, below |
| `question`, `why`, `look` | The question; why it is asked (with the Zero Hour default where there is one); where to look. Backticks mark a word in bold |
| `rec`, `recWhy` | Claude's pick (an option letter) and one line why |
| `options` | `{A: {...}, B: {...}}`, up to `D`. One option only makes a confirm step: Yes, as drawn, or Change with a note |
| `uses` | Optional steps whose recorded picks this one is shown with: `'<key>'` or `'<round-id>/<key>'` |
| `neutral` | Optional neutral answer label (`'Neither'`, `'No difference'`), recorded as `neither` |
| `blind` | Letters stay neutral; each option's `reveal` (`"today's look"`) shows after the step is picked |
| `view` | `'side'` opens side by side instead of one at a time |
| `crop` | Default crop `{x, y, w, h}` for the step's live renders |
| `phoneCrop` | Optional crop for the stage and reference picture below 900 px wide, so the part to judge is on the first phone screen; extras keep `crop` |
| `ref` | A reference picture beside the question: `{label, render}` or `{label, img}` |
| `notesLabel` | Header over each option's `notes` (default `Notes`) |
| `controls` | Stage controls, below; a round's `controls` apply to all its picture and gallery steps |
| `render` | Step default live-render recipe, over the round's |
| `mark` | Small-change marker `{x, y, w, h, label, below?}` (or a list) in the 1280x720 frame; `below: true` puts the label under the ring; an option or gallery item may carry its own |
| `pairs` | Colour pairs for the numbers panel: `[[name, '#hex', name, '#hex', kind?]]`; kind `'vs'` (two colours that only need to differ) prints no contrast, the default is a colour on its background |
| `interactive` | Live renders take the mouse (hover cards); a click no longer enlarges, `L` does |
| `checklist` | "What to judge" lines |
| `folds` | Fold-outs `[{label, text, pics: [{label, img | render}]}]`; options take `folds` too |

An option has `name`, `notes`, optional `sees` ("What you see"), `changes`, `extra` (more pictures: `[{label, render | img}]`) and one body: a picture `img: '<repo path>'` (`local: true` for a file that is never committed, such as an owner mock: where it is missing the page says so in grey instead of a red error), a live render `render: {state, crop?, params?, page?, hash?, w?, h?}` (`params` adds `&key=value` to the hash, for example `{cvd: 'deut'}`), a clip `video: '<repo path>'` (muted, looping, with controls; nothing plays until play or `Space`), `text` for a text step, `audio: '<repo path>'` plus `level` for an audio step.

Kinds:

| Kind | Fields | Recorded as |
|---|---|---|
| `pictures` | `options` with `img` or `render` | `<prefix>:<key>` = option letter, `yes`, `change` or `neither` |
| `text` | `options` with `text`; optional `card: {title, lines, foot}` where a `null` line is the option's text | as `pictures` |
| `audio` | `options` with `audio`, `level` | as `pictures`; nothing plays until Play or `Space` |
| `lab` | `url` of a web build, `w`, `h`, `labHint`, `options` as answers | as `pictures`; the build loads only on "Start the lab here" |
| `gallery` | `items: [{id, label, caption, render | img}]`, optional `verdict: {key, pass, changes}` | item notes `<prefix>:<key>:<item id>` (pick `null`); verdict `<prefix>:<verdict key>` = `pass` or `changes` |
| `verdict` | `labels: {pass, changes}` | `<prefix>:<key>` = `pass` or `changes`, with the overall note |
| `wording` | `fields: [{id, label, text}]` | `<prefix>:<key>:<field id>`, the text as `note`, posted as you type |

Every note is saved with its key: a step note goes with the pick (or alone, pick `null`), and leaving a step posts a changed note. The summary reads `/picks.json` back and lists the round's keys, then the earlier rounds'.

Rounds here: `demo-controls`, one step per kind of render target with its controls; `p2-3a1-gate-1` and `p2-3a1-gate-2` (the P2.3a1 gate A rounds of `docs/images/hud-v5/source/p2-3a1-gate.html`, with its key prefixes `p2-3a1-gate` and `p2-3a1-gate2`, so its recorded picks read back when `DECISION_PICKS=docs/images/hud-v5/source/picks.json` points at the old gate server's file), and `demo`, one step of each kind.

## Stage controls

A step turns a control on in `controls`: `true` (every value) or a list (these values, the first is the start). Values are page-wide, so a size or ground stays as you move between steps; a step that does not offer a value starts at its own first one. Code: `stage.js`.

| Control | Values | Done by |
|---|---|---|
| `size` | `1280x720`, `1280x800`, `1920x1080` (1280x720 at 1.5), `3440x1440` (1720x720 at 2) | the render page (`size=<w>x<h>`, `scale=<k>`); the frame grows and a crop keeps to the nearer edge |
| `fit` | fit, true 100 % (one picture pixel per screen pixel) | the app |
| `ground` | sand, dark; greyed while a backdrop is on, which covers it | the render page |
| `world` | plain, the twelve `docs/images/hud-v5/source/worlds/` scenes | the render page (`world=<name>`) |
| `zoom` | 0.5, 1, 2 | the render page |
| `hud` | `true`: on, off (render page, `hud=0`); a list of states: off or that HUD states page state laid over the picture, transparent | either |
| `state` | a list of states; options without their own `state` take it | the app (`{state}` in the hash) |
| `tier` | full, core | the render page |
| `owner`, `set` | as drawn, P1 to P8; default or Neon (`game/scripts/presentation/palette.gd`) | the render page (`you=<hex>`) |
| `heading` | 0 to 7 (45° steps) | the render page |
| `cvd` | normal, deuteranopia, protanopia (Machado 2009, SVG filter over the pictures) | the app |
| `marker` | on, off: rings the step's `mark`; the ring keeps its screen size on a small picture | the app |
| `extra` | `[{id, label, key?, values: [{v, label}], param?}]`: the step's own controls, sent as `param` (default `id`) | the render page |

`render.pass` names the hash parameter a render page takes for each control (`{size: 'size', world: 'world', ground: 'ground', hud: 'hud', owner: 'you'}` for `p2-3a1-states.html`); a control that neither the app nor the page does is an error banner, as is an extra control on an app key. Render pages in use: `p2-3a1-states.html` (takes `size`, `world`, `ground=dark|none`, `hud=0`, `you`; without them its output is unchanged), `round1.html` (`tier`, its own states), `round6.html` step shots (`ground`, `zoom`) and `rounds/demo-controls/scene.html` (a wiring demo, not game art). The numbers panel prints WCAG contrast (under 3:1 marked; only for a colour on its background) and CIE76 distance normal, deuteranopia and protanopia (under 20 marked) for the step's `pairs`.

`sh tools/decision_page/shoot.sh '<hash>' <out.png|out.webp> [WIDTHxHEIGHT]` screenshots a hash with headless Firefox (`DP_URL` points at the server). Headless Firefox here plays only VP8 clips; H.264 and VP9 show as corrupt there, not in a normal window.

## Fly

`fly/` deploys the page with a small volume, so picks survive restarts and redeploys:

```sh
sh tools/decision_page/fly/sync.sh   # site/: the page, its rounds and the repository files they name
fly volumes create decision_picks --region fra --size 1 -a wargrid-lab-test   # once
fly deploy tools/decision_page/fly
```

`sync.sh` copies the page and every round except the `demo*` ones (so the public `/pick` takes no demo keys), then every `docs/...` and `game/...` path the copied files name, the local files those HTML pages load, the backdrops, `layout.json` and the game font. It copies only files Git tracks: a file that exists only on disk, such as an owner mock, is reported as `skipped, not tracked by Git` and stays off the public site, from any tree; the page then shows it as a local file. The machine stops when idle and starts on the next request; `DECISION_PICKS` points at `/data/picks.json` on the volume. Deploying needs the owner's approval.

The first deploy of this image replaces the old gate deploy on the same app. The old one kept its picks on the machine's own disk, so the deploy drops them, and its URL (`/docs/images/hud-v5/source/p2-3a1-gate.html#round=2`) answers 404; `/` now opens the round list. Keep the old clicks (not yet tried; the `sftp put` path is the plan, not a tested command):

```sh
curl -fsS https://wargrid-lab-test.fly.dev/docs/images/hud-v5/source/picks.json -o old-picks.json   # before the deploy
fly deploy tools/decision_page/fly
python3 -c "import json; d = json.load(open('old-picks.json')); assert isinstance(d, dict) and all(isinstance(v, dict) for v in d.values())"   # before the put
fly ssh sftp shell -a wargrid-lab-test   # then: put old-picks.json /data/picks.json
```

The keys keep their old prefixes (`p2-3a1-gate:`, `p2-3a1-gate2:`), so the new rounds read them back unchanged. The endpoint has no login: anyone with the URL can read `/picks.json` (notes included) and overwrite a pick.
