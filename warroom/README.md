# War Room

The owner's decision page: steps with options A to D on one stage, a click records the pick on the server and the page moves on. Go port of the Python prototype in `tools/decision_page/`, which keeps running in parallel (user, 2026-11-19). The page rules, keys and stage controls are the prototype's; what changed is below.

## Run it

```sh
cd warroom
go run .
```

Then open `http://127.0.0.1:8780/` in Firefox. Paths are relative to the working directory, which must be `warroom/`. The app serves only `/docs/`, `/game/` and `/web/` from the repository root, so rounds can embed `docs/images/...` and `game/...` files. Rounds are read from disk on every request: edit a YAML file and reload. A load error is a red banner on the page and a log line.

| Variable | Default | What |
|---|---|---|
| `WARROOM_PICKS` | `picks.json` (ignored by Git) | Where picks are stored |
| `WARROOM_ROOT` | `..` | The repository root that `/docs/`, `/game/`, `/web/` are served from |
| `WARROOM_ROUNDS` | `rounds` | The rounds folder |
| `WARROOM_HOST`, `WARROOM_PORT` | `127.0.0.1`, `8780` | Where the server listens |

Never use ports 8767 to 8772 (other servers run there).

## Routes

State lives in the address, not in a hash, so every view is a link.

| Route | What |
|---|---|
| `GET /` | Round list; `?demo=1` also shows rounds marked `demo: true` |
| `GET /r/{round}` | Redirects to the first unanswered step, or the summary when all are answered |
| `GET /r/{round}/{n}` | Step `n` (1-based) |
| `GET /r/{round}/summary` | The round's picks, unanswered steps as links, earlier rounds, Copy summary |
| `POST /r/{round}/{step}/pick` | Form fields `pick`, `note`. The server builds the key from the round's prefix, so only real steps are accepted |
| `POST /r/{round}/{step}/note` | Form fields `note`, optional `sub` (a gallery item id or a wording field id) |
| `GET /picks.json` | All picks, for reading back (`Cache-Control: no-store`) |
| `GET /health` | `200 ok` |
| `/static/*`, `/docs/*`, `/game/*`, `/web/*` | Embedded assets; repository files (no listings, no links out of the root) |

Pick rules: a body over 8 KiB is 400; the pick must be an option letter the step has, `neither` (step has a neutral answer), `yes` or `change` (confirm step), or `pass` or `changes` (verdict); `change` without a note shows the step again asking for one; a note is at most 4000 characters; a new key past 500 keys is 507; a failed write, or a picks file that is not a JSON object of objects (left as it is), is 500. Writes are atomic (temporary file, fsync, rename) under one lock. Requests that stall for 15 s are dropped. A pick from a plain form post redirects (303) to the next step; from htmx it answers with the next step's page and `HX-Push-Url`.

Query parameters (carried by the navigation links, so values stay page-wide): `show` (option), `view=side`, `item`, every stage control away from its first value (`size fit ground world zoom hud state tier owner set heading cvd marker x-<id>`), `numbers=0` (hide the numbers panel). A control value over 64 bytes or with characters other than letters, digits and ` ._,:+-` is dropped, as is any `x-` control past 16, since every link repeats them. Read only: `sheet=1` opens the phone's View sheet, `keys=1` the key list, `shot=1` the shown option alone at its frame size on black (`crop=step` keeps the step's crop), `lab=1` starts a lab step's build, `phone=1` asks for the phone crops (a phone-sized first load adds it itself).

`picks.json` keeps the prototype's format, `{"<prefix>:<key>[:<sub>]": {"pick": str|null, "note": str}}`, so the old gate picks read back.

## Keys

| Key | What |
|---|---|
| `A` `B` `C` `D` or `1` to `4` | Show that option on the stage (side by side: highlight it) |
| `Enter` | Pick the shown option, record it and go on |
| `W` | One at a time / side by side |
| `←` `→` (`[` `]`, `Backspace` back) | Previous / next step without picking |
| `N` `P` | Next / previous item inside a step (gallery picture, or the state on a step with a state control) |
| `L`, or a click on a picture | Large view; `Esc` or a click closes it |
| `Space` | Play / stop the shown option's sound or clip |
| `?` | Key list, with the stage controls this step has |
| `S` `F` `G` `⇧G` `Z` `H` `T` | Window size, fit / true 100 %, ground, backdrop, zoom, HUD layer, tier |
| `O` `⇧O` `R` `⇧R` `⇧C` `M` `K` | Owner colour, colour set, unit heading (`⇧R` turns back), colour vision, small-change marker, numbers panel |

A step's own `extra` controls may name a key; the ones the app uses are refused at load. Keys do nothing while a note or list has the focus or with Cmd, Ctrl or Alt. Each key is a `data-key` on the element it clicks, so the buttons and the keys cannot drift apart. Below 900 px wide or on a touch screen a two-row bar covers every key; its View button opens a sheet with the stage controls, Whole screen and the key list; a swipe on the picture flips the option (gallery: the item).

## Rounds: the data contract

Rounds are YAML, decoded strictly: an unknown field, an unknown step kind, no options, a `rec` that is not an option, a `uses` that is not a step, a gallery verdict key that clashes, or a control the render page does not take is a load error with the line.

```
rounds/index.yaml            - {id, title, demo?}   (order = list order)
rounds/<id>/round.yaml       the round
rounds/<id>/<step-key>.yaml  one file per step
```

`round.yaml`: `prefix` (key namespace, default the folder name; the gate rounds keep `p2-3a1-gate` and `p2-3a1-gate2` so old picks read back), `title`, `steps` (step keys in order; a missing file shows `[step missing: <key>]`), `earlier` (round ids whose picks the summary lists and `uses` can name), `render` (live-render recipe `{page, w, h, hash, pass}` over the app's default: `docs/images/hud-v5/source/p2-3a1-states.html`, 1280 x 720, `shot={state}&size=720&scale=1`), `controls`.

Step fields: `kind`, `question`, `why`, `look`, `rec` and `recWhy`, `options` (map `A` to `D`; one option makes a confirm step: Yes, as drawn, or Change with a note), `uses`, `neutral` (label of a neutral answer, recorded as `neither`), `blind` (letters stay neutral; each option's `reveal` shows after the pick), `view: side`, `crop {x,y,w,h}`, `phoneCrop`, `ref {label, render|img}`, `notesLabel`, `controls`, `render`, `mark` (one or a list `{x,y,w,h,label,below?}`), `pairs` (`[name, '#hex', name, '#hex', 'vs'?]` for the numbers panel), `interactive`, `checklist`, `folds [{label, text, pics}]`.

Option fields: `name`, `notes`, `sees`, `changes`, `reveal`, `extra` (more pictures), `folds`, `mark`, and one body: `img` (`local: true` for a file never committed), `render {state, crop?, params?, page?, hash?, w?, h?}`, `video`, `text` or `audio` plus `level`.

| Kind | Fields | Recorded as |
|---|---|---|
| `pictures`, `text`, `audio`, `lab` | `options` (`text` kind: optional `card {title, lines, foot}` where a `null` line is the option's text; `lab`: `url`, `w`, `h`, `labHint`) | `<prefix>:<key>` = option letter, `yes`, `change` or `neither` |
| `gallery` | `items [{id, label, caption, render|img, mark}]`, optional `verdict {key, pass, changes}` | item notes `<prefix>:<key>:<item id>` (pick `null`); verdict `<prefix>:<verdict key>` = `pass` or `changes` |
| `verdict` | `labels {pass, changes}` | `<prefix>:<key>` = `pass` or `changes` |
| `wording` | `fields [{id, label, text}]` | `<prefix>:<key>:<field id>`, the text as `note`, posted as you type |

Rounds here: `demo` and `demo-controls` (marked `demo: true`: one step per kind, one step per render target with its controls) and the two P2.3a1 gate rounds.

## Stage controls

`controls` on a round or step: `name: true` (every value) or a list (these values, the first is the start); a step's entry overrides the round's per control. `state` needs a list. Values: `size` (`1280x720`, `1280x800`, `1920x1080`, `3440x1440`), `fit` (`fit`, `100`), `ground` (`sand`, `dark`), `world` (`plain`, `none` and the named `docs/images/hud-v5/source/worlds/` scenes), `zoom` (`0.5`, `1`, `2`), `hud` (`on`, `off`, or a list of states laid over the picture), `tier` (`full`, `core`), `owner` (`drawn`, `1` to `8`), `set` (`default`, `neon`), `heading` (`0` to `7`), `cvd` (`normal`, `deut`, `prot`), `marker` (`on`, `off`). `extra: [{id, label, key?, values: [{v, label}], param?}]` adds the step's own controls, sent to the render page as `param` (default `id`).

`fit`, `set`, `cvd` and `marker` are done by the app; the others reach the render page through `render.pass` (`{size: size, world: world, ground: ground, hud: hud, owner: you}` for `p2-3a1-states.html`). A control that neither does is a load error. The numbers panel prints WCAG contrast and CIE76 distance (normal, deuteranopia, protanopia; Machado 2009) for the step's `pairs`.

`sh warroom/tools/shoot.sh '<path?query>' <out.png|out.webp> [WIDTHxHEIGHT]` screenshots a page with headless Firefox (`WR_URL` points at the server). Headless Firefox here plays only VP8 clips.

## Build and checks

| What | Version |
|---|---|
| Go | 1.27.4 |
| chi | v5.5.0 |
| templ | v0.3.1100 (CLI as a `go.mod` tool: `go tool templ`) |
| YAML | goccy/go-yaml v1.19.2 |
| htmx | 4.0.1, vendored as `static/htmx.min.js` |
| Tailwind CSS | v4.3.4 standalone CLI |
| daisyUI | 5.7.50 |

The generated files are committed (`*_templ.go`, `static/app.css`), so `go build` and `go test` need no templ or Tailwind. After changing a `.templ` file or `static/input.css`:

```sh
sh tools/fetch.sh     # Tailwind CLI and daisyUI into .bin/ (git-ignored); checks each download's SHA-256
go generate ./...     # templ generate, fetch, Tailwind build
```

Checks, in `warroom/`:

```sh
go vet ./... && go test -race ./...
golangci-lint run                 # config .golangci.yml, a copy of relay's
sh tools/check_generated.sh       # regenerates into a temp copy; fails when the committed output differs
```

These are not in CI or `tools/run_checks.sh` yet.

## Fly

`fly/` deploys War Room to the prototype's app, with the same volume, so picks survive restarts and redeploys. Every `fly` command needs the owner's approval.

```sh
sh warroom/fly/sync.sh                                  # fly/site/: Go sources, rounds, referenced repository files
fly volumes create decision_picks --region fra --size 1 -a wargrid-lab-test   # once; exists if the prototype was deployed
fly deploy warroom/fly
```

`sync.sh` copies the Go sources, the rounds not marked `demo: true` (so the public site has no demo rounds or keys) and every `docs/...` and `game/...` path their YAML and the Go sources name, plus the local files those HTML pages load, the backdrops, `layout.json` and the game font. It copies only files Git tracks: a file that exists only on disk, such as an owner mock, is reported as `skipped, not tracked by Git` and stays off the public site. The Dockerfile builds a static binary (`CGO_ENABLED=0 go build -trimpath`) and runs it on Alpine as `nobody` after handing the volume to it; the machine stops when idle and starts on the next request; `WARROOM_PICKS` is `/data/picks.json`, the prototype's file and format. It replaces the prototype's image on `wargrid-lab-test`: both cannot be live there.

Test the image without Fly with Apple's `container` CLI (`container system start` first):

```sh
container build -t warroom-test warroom/fly
container run -d --name warroom-test -p 8783:8780 -e WARROOM_PICKS=/data/picks.json --tmpfs /data warroom-test
curl -s http://127.0.0.1:8783/health
container stop warroom-test && container rm warroom-test
```

The endpoint has no login: anyone with the URL can read `/picks.json` (notes included) and overwrite a pick.

## Learning notes

Things that cost time with the pinned versions.

- htmx 4 attributes are not inherited unless they say so: `hx-boost:inherited`, `hx-target:inherited` (`layout.templ`).
- htmx 4 swaps 4xx and 5xx responses by default. The `<body>` sets `hx-status:4xx:inherited="swap:none"` and `hx-status:5xx:inherited="swap:none"`, so a refused pick leaves the page alone and `warroom.js` shows "Not recorded" with Retry.
- htmx 4 sends `HX-Request-Type: partial` or `full`: `full` when the target is `<body>` (or the request has `hx-select`). A history restore targets `<body>`, so it sends `full` and the server must answer with the whole document, not the fragment (`render.go`, `Vary: HX-Request-Type`).
- htmx 4 event names are `htmx:after:request`, `htmx:response:error`, `htmx:error`, `htmx:after:swap` and `htmx:config:request` (used in `warroom.js`), not the htmx 2 `htmx:afterRequest` family.
- htmx 4's `innerMorph` keeps an iframe and only sets its new `src`; when the address differs only after `#`, that is a hash change and the render page does not redraw. Frames carry an id hashed from their address (`frameID` in `pics.go`), so a changed frame is replaced and an unchanged one survives.
- templ: `@Comp() { text }` on one line is a call with children (the literal text `text`), not a call followed by an expression.
- daisyUI's `@layer daisyui` outranks Tailwind's `components` layer, so an override of a daisyUI class must sit outside every layer (the end of `static/input.css`).
