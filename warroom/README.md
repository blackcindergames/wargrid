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
| `WARROOM_SECRET` | unset | Signs the write tokens (see Tokens). Unset: every link can record and read back, and the log says so once |
| `WARROOM_RUN_AS` | unset | A uid to drop to after handing the picks directory to it; only `fly/Dockerfile` sets it. Unset: no chown, no drop |

Never use ports 8767 to 8772 (other servers run there).

On SIGINT or SIGTERM the server stops accepting, lets requests in flight finish (a pick being written lands first) for up to 4 s, then closes the rest; a second signal exits at once. A serve error exits with status 1. With `WARROOM_RUN_AS` set (the Fly image sets 65534) the process must be root on Linux: it hands the picks directory to that uid, drops to it, and logs the uid it runs as. Logs are `log/slog` text lines on stderr; the request log has the path only, never the query (it carries tokens).

## Code layout

| Package | Job |
|---|---|
| `main.go` | Reads the environment, listens, shuts down on a signal; the `token` and `schema` commands; `go:generate` lines; `priv_linux.go` drops root when `WARROOM_RUN_AS` asks |
| `internal/store` | The picks file and its history: one lock, atomic writes, key and size caps |
| `internal/rounds` | Round and step YAML types, strict loading and validation, stage control definitions, tune params, the JSON Schema |
| `internal/stage` | Stage controls resolved per request, the render-page hash, crops and window sizes, the numbers panel (contrast, CIE76) |
| `internal/web` | Routes (stdlib `ServeMux`), tokens, request log and recovery, handlers, query parsing, view models, templ views, embedded `static/` |

Dependencies point one way: `web` uses `stage`, `rounds` and `store`; `stage` uses `rounds`; `rounds` uses `store` (the `Entry` type).

## Routes

State lives in the address, not in a hash, so every view is a link.

| Route | What |
|---|---|
| `GET /{$}` | Round list; `?demo=1` also shows rounds marked `demo: true` |
| `GET /r/{round}` | Redirects to the first unanswered step, or the summary when all are answered |
| `GET /r/{round}/{n}` | Step `n` (1-based) |
| `GET /r/{round}/summary` | The round's picks, unanswered steps as links, earlier rounds, Copy summary |
| `POST /r/{round}/{step}/pick?t=<round token>` | Form fields `pick`, `note`. The server builds the key from the round's prefix, so only real steps are accepted |
| `POST /r/{round}/{step}/note?t=<round token>` | Form fields `note`, optional `sub` (a gallery item id or a wording field id) |
| `GET /picks.json?t=<admin token>` | All picks, for reading back (`Cache-Control: no-store`) |
| `GET /history.jsonl?t=<admin token>` | Every recorded change, one JSON line each |
| `GET /health` | `200 ok` |
| `/static/{path...}`, `/docs/...`, `/game/...`, `/web/...` | Embedded assets; repository files (no listings, no links out of the root) |

## Tokens

`WARROOM_SECRET` makes every write need a token. A token is `base64url(HMAC-SHA256(secret, scope))` cut to 16 bytes (22 characters): scope `round:<id>` for a round's write token, `admin` for reading `/picks.json` and `/history.jsonl`. Tokens never expire; changing the secret revokes all of them. Comparison is `subtle.ConstantTimeCompare`.

```sh
WARROOM_SECRET=... go run . token p2-3a1-gate-2    # a round's write link is  /r/p2-3a1-gate-2?t=<token>
WARROOM_SECRET=... go run . token admin            # curl "$HOST/picks.json?t=<token>"
```

- A link without a valid token for its round is read only: step pages leave out the pick buttons, notes, the answer form and the phone bar's pick and note buttons, and say "Read only: this link cannot record." Keys that would pick find no button and do nothing. A POST without a valid token is 403.
- The token is a query parameter like the stage controls: `Query.Carry()` puts it on every link, form action, `hx-get` and `hx-post` the server renders, on the redirects and on `HX-Push-Url`, so htmx navigation and Retry keep it. A link to another round (earlier rounds in the chips) drops it. The client adds nothing: `warroom.js` only rewrites the `phone` and view parameters of the address it was given.
- A token longer than 64 bytes or with characters outside the control-value set is ignored.
- Unset secret: no token is checked, nothing is read only, and `/picks.json` is open (local use).

## History

Each write that changes an entry appends `{"t": RFC 3339 UTC, "key", "pick", "note", "value"?}` to `picks.jsonl` next to `picks.json` (`O_APPEND`, fsync, under the store lock, before the state file is replaced). `picks.json` stays the current state in the old format. A write that changes nothing adds no line. The summary shows "changed N times" on a row with more than one line; there is no other history view. The history stops at 5 MiB: a write past it is 507 and changes nothing. A write whose state file then fails leaves its history line behind.

## Pick rules

A body over 8 KiB is 400; the pick must be an option letter the step has, `neither` (step has a neutral answer), `yes` or `change` (confirm step), `pass` or `changes` (verdict), or `tuned` (tune step, with a `value` field); `change` without a note shows the step again asking for one; a `tuned` pick must carry `value`, a JSON object of at most 1 KiB with exactly the step's param ids (numbers in range and on the step grid from `min`, colours `#rrggbb`, choices from the list; anything else is 400) and the server stores it cleaned (grid-snapped, colours lower case); a note is at most 4000 characters; a new key past 500 keys is 507; a failed write, or a picks file that is not a JSON object of objects (left as it is), is 500. Writes are atomic (temporary file, fsync, rename) under one lock. Requests that stall for 15 s are dropped. A pick from a plain form post redirects (303) to the next step; from htmx it answers with the next step's page and `HX-Push-Url`.

Query parameters (carried by the navigation links, so values stay page-wide): `show` (option), `view=side`, `item`, every stage control away from its first value (`size fit ground world zoom hud state tier owner set heading cvd marker x-<id>`), `numbers=0` (hide the numbers panel). A control value over 64 bytes or with characters other than letters, digits and ` ._,:+-` is dropped, as is any `x-` control past 16, since every link repeats them. Read only: `sheet=1` opens the phone's View sheet, `keys=1` the key list, `shot=1` the shown option alone at its frame size on black (`crop=step` keeps the step's crop), `lab=1` starts a lab step's build, `phone=1` asks for the phone crops (a phone-sized first load adds it itself).

`picks.json` keeps the prototype's format, `{"<prefix>:<key>[:<sub>]": {"pick": str|null, "note": str}}`, so the old gate picks read back. A tune step's entry has one more optional field, `"value": {param id: number|string}`; entries without it stay valid.

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
| `tune` | `target`, `params`, optional `neutral` | `<prefix>:<key>` = `tuned` with `value`, or `neither` |
| `wording` | `fields [{id, label, text}]` | `<prefix>:<key>:<field id>`, the text as `note`, posted as you type |

Rounds here: `demo` and `demo-controls` (marked `demo: true`: one step per kind, one step per render target with its controls; `demo` ends with a `tune` step) and the two P2.3a1 gate rounds.

## Stage controls

`controls` on a round or step: `name: true` (every value) or a list (these values, the first is the start); a step's entry overrides the round's per control. `state` needs a list. Values: `size` (`1280x720`, `1280x800`, `1920x1080`, `3440x1440`), `fit` (`fit`, `100`), `ground` (`sand`, `dark`), `world` (`plain`, `none` and the named `docs/images/hud-v5/source/worlds/` scenes), `zoom` (`0.5`, `1`, `2`), `hud` (`on`, `off`, or a list of states laid over the picture), `tier` (`full`, `core`), `owner` (`drawn`, `1` to `8`), `set` (`default`, `neon`), `heading` (`0` to `7`), `cvd` (`normal`, `deut`, `prot`), `marker` (`on`, `off`). `extra: [{id, label, key?, values: [{v, label}], param?}]` adds the step's own controls, sent to the render page as `param` (default `id`).

`fit`, `set`, `cvd` and `marker` are done by the app; the others reach the render page through `render.pass` (`{size: size, world: world, ground: ground, hud: hud, owner: you}` for `p2-3a1-states.html`). A control that neither does is a load error. The numbers panel prints WCAG contrast and CIE76 distance (normal, deuteranopia, protanopia; Machado 2009) for the step's `pairs`.

`sh warroom/tools/shoot.sh '<path?query>' <out.png|out.webp> [WIDTHxHEIGHT]` screenshots a page with headless Firefox (`WR_URL` points at the server). Headless Firefox here plays only VP8 clips.

## Tune steps

A `tune` step lets you move parameters of a live render and records the values as a preset. Go and templ render the page; a Svelte island, the custom element `<wr-tune>`, draws the knobs with Tweakpane.

```yaml
kind: tune
question: Which outline weight and unit size read best?
neutral: None of these          # optional: records `neither`
target: {page: static/demo/scene.html, hash: shot=1}   # a render recipe, like an option's `render`
params:
- {id: outline, label: Outline, min: 0, max: 4, step: 0.5, value: 1}
- {id: unit, label: Unit size, min: 0.5, max: 2, step: 0.1, value: 1}
- {id: you, label: Owner colour, color: '#376eac'}
- {id: ground, label: Ground, values: [sand, dark], value: sand}
```

A param is a number (`min`, `max`, `step`, `value`; the value must lie on the grid `min + k * step`), a colour (`color: '#rrggbb'`) or a choice (`values`, `value`). Ids are `[a-z0-9-]+`, unique, at most 12. Loading checks all of it, with the line. Keep ids clear of the hash names the render page already reads: `size` there is the window size, so the demo's unit size is `unit`.

How it hangs together:

- The page prints `<wr-tune data-params='[...]' data-target="<iframe id>" data-field="tune-value">` and a hidden `<input id="tune-value" name="value" form="answer">` holding the start values: the recorded ones when they still fit the params, else the step's own. The target frame's address carries the same start values as hash parameters, so the first draw is right before any script runs.
- `islands/Tune.svelte` is compiled to a custom element (`shadow: 'none'`, so `app.css` reaches it). On every change it writes the values as JSON into the hidden field and posts `{type: 'wr:params', params: {id: value}}` to the target frame with `postMessage(msg, location.origin)`; it posts again when the frame finishes loading.
- The target listens for `wr:params` (`static/demo/scene.html` does), checks `event.origin === location.origin`, `event.source === parent` and the type, and redraws without a reload. Any render page can opt in the same way.
- The pick button submits the answer form as before; htmx posts the hidden field with it, the server validates it (see Routes) and stores it with the pick. Enter picks, also from a focused slider; other keys inside the panel stay with Tweakpane (`warroom.js` skips them). `warroom.js` starts nothing: htmx swaps add and remove the element, and the custom element lifecycle starts and stops the pane.
- The summary shows the value compactly: `outline 1.5 · unit 1.2 · you #376eac · ground dark`.

## Islands build

`islands/` holds the Svelte sources, `package.json` with exact versions and `package-lock.json`. `npm run build` (Vite library mode, one ES module) writes `internal/web/static/islands.js`, which is committed and embedded like `app.css`, so `go build`, `go test` and the Docker build need no Node. `go generate ./...` runs `npm ci` and the build; `tools/check_generated.sh` rebuilds in a temporary copy and fails when `internal/web/static/islands.js` differs.

## Styles

`internal/web/static/app.css` is one hand-written file with native nesting and no build. Its first line fixes the cascade layers, and a later layer beats an earlier one whatever the selector weight:

| Layer | What |
|---|---|
| `reset` | Margins, borders and form fonts zeroed, `[hidden]` always hides |
| `tokens` | Public Sans from `/game/fonts/` and the custom properties below |
| `base` | Body, links, `textarea`, `kbd` (the HUD key chip), `.sr-only` |
| `components` | Buttons, tags, chips, the step grid, head, notes, tiles, gallery, verdict, tables, key list, the `wr-tune` theme |
| `stage` | The black stage, pictures and frames, marks, the large view, colour-vision filters, true 100 %, `?shot=1` |
| `phone` | Below 900 px or on a touch screen: one column, the fixed two-row bar and its View sheet |

Colour tokens take the HUD v5 set A values (`docs/reference/hud-v5-layout.md`, `game/scripts/lab/lab_look.gd`), so the page frames art in the game's own quiet chrome: `--well` page, `--slab` panels, `--quiet` idle buttons, `--btn` hover, `--panel2` highlighted card line, `--line` borders, `--muted` labels, `--sel` cyan for the shown or current item (also the eyebrow, folds and links), `--amber` (the HUD `amber`, `lab_look.gd`) for the pick button and Retry, Claude's pick, look cues, marks, unsent or failed picks, low numbers and the loading bar. `--text` is `#dfe7ec`, softer than the HUD's, and `--soft` sits between it and `--muted`; `--stage` is black. Type: `--font` (Public Sans), `--label` 12 px (the HUD floor, uppercase labels), `--row` 13 px.

Own classes, no utility classes: `.btn` with `.sm` `.lg` `.xs` sizes and the states `.on` (cyan) and `.pick` (amber); `.tag` with `.cp` `.got` `.rv`; `.chip`, `.scroll` (a table that may scroll sideways). `warroom.js` toggles `.on` on the option buttons and `.sel` on tiles; keys find elements by `data-key`, `data-show`, `data-act` and `data-pick`, never by a style class.

## Build and checks

| What | Version |
|---|---|
| Go | 1.27.4 |
| invopop/jsonschema | v0.14.0 (2026-04-23) |
| templ | v0.3.1100 (CLI as a `go.mod` tool: `go tool templ`) |
| YAML | goccy/go-yaml v1.19.2 |
| htmx | 4.0.1, vendored as `static/htmx.min.js` |
| Svelte | 5.57.3 (islands) |
| Vite | 8.3.6 |
| @sveltejs/vite-plugin-svelte | 7.3.1 |
| Tweakpane | 4.0.5 |
| Node, npm | only for `islands/`; built with Node 24, npm 12 |

The generated files are committed (`internal/web/*_templ.go`, `internal/web/static/islands.js`, `rounds/round.schema.json`, `rounds/step.schema.json`), so `go build` and `go test` need no templ or Node. `internal/web/static/app.css` is hand-written (see Styles) and needs no build step. After changing a `.templ` file or `islands/`:

```sh
go generate ./...     # templ generate, the schemas, npm ci and the islands build
```

The JSON Schemas come from the Go types (`go run . schema round|step`, run by `go generate`). Every round and step YAML starts with `# yaml-language-server: $schema=../round.schema.json` (`../step.schema.json` for steps), so an editor with the YAML language server completes fields and flags unknown ones; the strict decoder stays the authority. Two schemas, not one: `round.yaml` and a step file are different types. A new custom YAML type needs a case in `customTypes` (`internal/rounds/schema.go`).

Dev loop: `sh tools/dev.sh` runs `go tool templ generate --watch --open-browser=false --proxy=http://127.0.0.1:8780 --cmd="go run ."`: templ regenerates on a `.templ` or `.go` save, restarts the server and reloads the browser through its proxy at `http://127.0.0.1:7331/`. Rounds are read per request, so a YAML edit needs only a reload. `WARROOM_PORT` changes the port the proxy forwards to. The island is not watched, and `app.css` is embedded, so a CSS edit needs a restart (save a `.go` file).

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
fly secrets set WARROOM_SECRET=... -a wargrid-lab-test   # once; without it every link can record and read back
sh warroom/fly/sync.sh                                  # fly/site/: Go sources, rounds, referenced repository files
fly volumes create decision_picks --region fra --size 1 -a wargrid-lab-test   # once; exists if the prototype was deployed
fly deploy warroom/fly
```

`sync.sh` copies the Go sources, the rounds not marked `demo: true` (so the public site has no demo rounds or keys) and every `docs/...` and `game/...` path their YAML and the Go sources name, plus the local files those HTML pages load, the backdrops, `layout.json` and the game font. It copies only files Git tracks: a file that exists only on disk, such as an owner mock, is reported as `skipped, not tracked by Git` and stays off the public site. The Dockerfile builds a static binary (`CGO_ENABLED=0 go build -trimpath`) and copies it into `gcr.io/distroless/static-debian12` (root variant, pinned by digest; no shell). Fly's volume and `[mounts]` docs say nothing about who owns a mount, and community reports say mounts arrive root-owned, so the binary chowns the picks directory to 65534 and drops root itself (`priv_linux.go`); the machine stops when idle and starts on the next request; the Dockerfile sets `WARROOM_RUN_AS=65534`, so a local run as root never chowns anything; `WARROOM_PICKS` is `/data/picks.json`, the prototype's file and format. It replaces the prototype's image on `wargrid-lab-test`: both cannot be live there.

Test the image without Fly with Apple's `container` CLI (`container system start` first). Use a named volume: a host directory cannot be chowned through the shared mount.

```sh
container build -t warroom-test warroom/fly
container volume create warroom-test-vol
container run -d --name warroom-test -p 8783:8780 -e WARROOM_PICKS=/data/picks.json -e WARROOM_SECRET=test -v warroom-test-vol:/data warroom-test
curl -s http://127.0.0.1:8783/health
container logs warroom-test                  # "running as uid 65534"
container stop warroom-test && container rm warroom-test && container volume rm warroom-test-vol && container image rm warroom-test
```

With the secret set, reading `/picks.json` or `/history.jsonl` needs the admin token and a pick needs the round's token (see Tokens); without it anyone with the URL can read the notes and overwrite a pick. Reading picks back is `curl "$HOST/picks.json?t=$(WARROOM_SECRET=... go run . token admin)"`, which needs the secret on the machine that asks.

## Learning notes

Things that cost time with the pinned versions.

- `ServeMux` patterns (Go 1.22+): `GET /r/{round}/{n}`, read with `r.PathValue("n")`. The literal `GET /r/{round}/summary` is more specific than the wildcard `{n}`, so both register and the literal wins; two patterns neither of which matches a subset of the other panic at startup. `GET /` would match every path, so the round list is `GET /{$}`. `{path...}` takes the rest of the path. A pattern with a method answers 405 for other methods, and `GET` also serves `HEAD`. ServeMux cleans the path itself: `/docs/../x` and `/docs` (the subtree `/docs/{path...}` exists) answer a 307 to the cleaned or slashed path, which is then served or 404.
- `invopop/jsonschema` names fields from `json` tags unless `FieldNameTag: "yaml"`; it makes every field required unless `RequiredFromJSONSchemaTags` is set; pointers are dereferenced before `Mapper` runs, so a `*string` cannot be mapped (the `Card.lines` null is patched after reflection); `ExpandedStruct` puts the root type's fields at the top instead of behind a `$ref`.
- templ's `--proxy` forwards to the URL after `--cmd` has run the app, and opens a browser unless `--open-browser=false` (`go tool templ generate --help`).

- htmx 4 attributes are not inherited unless they say so: `hx-boost:inherited`, `hx-target:inherited` (`internal/web/layout.templ`).
- htmx 4 swaps 4xx and 5xx responses by default. The `<body>` sets `hx-status:4xx:inherited="swap:none"` and `hx-status:5xx:inherited="swap:none"`, so a refused pick leaves the page alone and `warroom.js` shows "Not recorded" with Retry.
- htmx 4 sends `HX-Request-Type: partial` or `full`: `full` when the target is `<body>` (or the request has `hx-select`). A history restore targets `<body>`, so it sends `full` and the server must answer with the whole document, not the fragment (`internal/web/render.go`, `Vary: HX-Request-Type`).
- htmx 4 event names are `htmx:after:request`, `htmx:response:error`, `htmx:error`, `htmx:after:swap` and `htmx:config:request` (used in `warroom.js`), not the htmx 2 `htmx:afterRequest` family.
- htmx 4's `innerMorph` keeps an iframe and only sets its new `src`; when the address differs only after `#`, that is a hash change and the render page does not redraw. Frames carry an id hashed from their address (`frameID` in `internal/web/pics.go`), so a changed frame is replaced and an unchanged one survives.
- templ: `@Comp() { text }` on one line is a call with children (the literal text `text`), not a call followed by an expression.
- History (Tailwind and daisyUI, removed 2026-11-20): daisyUI's `@layer daisyui` outranked Tailwind's `components` layer, so every override of a daisyUI class had to sit outside all layers. With one hand-written file the layer order is declared once at its top and later layers win.
- Svelte 5 custom elements (`customElement: true` in the plugin options, `<svelte:options customElement={{tag, shadow: 'none', props}} />`): with `shadow: 'none'` the component renders into the element itself and `$host()` is that element, which is what Tweakpane gets as its container (no template needed). Props come from attributes only when declared: `props: {params: {attribute: 'data-params', type: 'Array'}}`; the type does the `JSON.parse`, otherwise you get the string, and an undeclared prop looks for an attribute named like the prop in lower case.
- A Svelte custom element builds its component one microtask after `connectedCallback` and destroys it one microtask after `disconnectedCallback` (so a DOM move does not rebuild). An `$effect` that creates the pane and returns `pane.dispose` is therefore enough to start and stop it on htmx swaps.
- Runes: `$props()` values are reactive, so reading `params` inside the `$effect` rebuilds the pane when `data-params` changes; the values object handed to Tweakpane is a plain object, not `$state`, because Tweakpane writes into it.
- Tweakpane 4.0.5 ships `.d.ts` files that import `@tweakpane/core`, which is not installed, so the editor has no types; the API (`new Pane({container})`, `addBinding`, `pane.on('change')`, `dispose`) was read from `dist/tweakpane.js`. Number steps count from the initial value, not from `min` (`StepConstraint(step, initialValue)`), which is why a loaded `value` must lie on the grid from `min` and the server snaps from `min`.
- Tweakpane's slider is a focusable `div` with its own arrow-key handler that does not stop the event, so `warroom.js` would flip the step; it now ignores keys from inside `wr-tune` except Enter. Its text inputs are covered by the existing input rule. It injects its own `<style>` and is themed with `--tp-*` custom properties on `wr-tune` (`internal/web/static/app.css`), set from the page's tokens; its list is a native `<select>` that stays light grey unless `--tp-button-*` is set.
- Vite library mode: `build.emptyOutDir` must be `false` because `outDir` is `static/`, which holds the rest of the site. The output keeps whitespace and comments (about 220 KB, 47 KB gzipped). The Svelte plugin's "no Svelte config found" line is harmless; the compiler option sits in `vite.config.js`.
- Headless Firefox through WebDriver cannot be made narrower than 500 px wide; for a 390 px layout load the page in a same-origin `<iframe>` of that width. In a WebDriver test, `clear` on a Tweakpane text input fires `change` and the pane reverts it; select the text and type instead.
