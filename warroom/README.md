# War Room

The owner's decision page: steps with options A to H on one stage, a click records the pick on the server and the page moves on. It replaced the Python prototype `tools/decision_page/`, deleted 2026-11-20; Git keeps it at `8e4bb7b` and `0be1d865`.

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
| `WARROOM_SECRET` | unset | Signs the tokens (see Tokens). Unset: every route is open, every link can record and read back, and the log says so once |
| `WARROOM_VIEWERS` | unset | Comma-separated names of the friends whose viewer tokens get in (`a-z`, `0-9`, `-`, at most 32 each; another name stops the server at start). On fly a secret, never in `fly.toml`: the repository is public. Removing a name revokes that friend's link and cookie |
| `WARROOM_RUN_AS` | unset | A uid to drop to after handing the picks directory to it; only `fly/Dockerfile` sets it. Set, the server refuses to start without `WARROOM_SECRET` or with one under 32 bytes, so a deploy is never open or guessable. Unset: no chown, no drop |

Never use ports 8767 to 8772 (other servers run there).

On SIGINT or SIGTERM the server stops accepting, lets requests in flight finish (a pick being written lands first) for up to 4 s, then closes the rest; a second signal exits at once. A serve error exits with status 1. With `WARROOM_RUN_AS` set (the Fly image sets 65534) the process must be root on Linux: it hands the picks directory to that uid, drops to it, and logs the uid it runs as. Logs are `log/slog` text lines on stderr; the request log has the path only, never the query (it carries tokens).

## Code layout

| Package | Job |
|---|---|
| `main.go` | Reads the environment, listens, shuts down on a signal; the `token`, `schema` and `open` commands; `go:generate` lines; `priv_linux.go` drops root when `WARROOM_RUN_AS` asks |
| `internal/store` | The picks file and its history: one lock, atomic writes, a key cap per round, history rotation |
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

`WARROOM_SECRET` makes every route but `GET /health` need a token, and every write a round's token. A token is `base64url(HMAC-SHA256(secret, scope))` cut to 16 bytes (22 characters): scope `round:<id>` for a round's write token, `admin` for reading `/picks.json` and `/history.jsonl`, `viewer:<name>` for a friend who may look around. Tokens never expire; changing the secret revokes all of them. Comparison is `subtle.ConstantTimeCompare`.

```sh
WARROOM_SECRET=... go run . token demo             # a round's write link is  /r/demo?t=<token>
WARROOM_SECRET=... go run . token admin            # curl "$HOST/picks.json?t=<token>"
WARROOM_SECRET=... go run . token viewer:<name>    # a friend's link is  /?t=<token>; <name> must be in WARROOM_VIEWERS
```

- The gate: a request gets in with any valid token (admin, any served round's, or a viewer's whose name is in `WARROOM_VIEWERS`) in the query `t` or in the cookie `wr`; otherwise 403, "War Room needs your invite link; open it again." A valid query token sets the cookie (`HttpOnly; Secure; SameSite=Lax; Path=/`, 90 days, the last valid token wins), so pictures, iframes, static files and htmx requests without `t` get in. The cookie only opens the gate: writes, answers and read-back still need the token in the query, as below (user, 2026-11-20). A viewer sees what a reader without the round's token sees. Without a token an unknown path is also 403, so nothing tells which paths exist.

`go run . open` prints each round (demos left out) that still has unanswered steps, as `<round>\t<N> of <M> answered` (an advisory round adds `\tadvisory: answer when you like`), from the local picks file, then a `load error:` line per load error and a `warning:` line per loader warning; kickoff runs it.

- A link without a valid token for its round is read only: step pages leave out the pick buttons, notes, the answer form and the phone bar's pick and note buttons and the Controls sheet's neutral answer, and say "View only: you can look around, nothing you do is recorded". Keys that would pick find no button and do nothing. A POST without a valid token is 403 ("Read only: this link cannot record.").
- Reads of answers need a token too: without one, pages show the rounds, questions and pictures but no picks, notes, recorded wording texts or tune values (chips, Picked tags, the `uses` lines and the tune knobs start from the step's own defaults), the summary lists the questions only (no pick or note cells, no change counts, no "Not answered yet" links) and `/r/{round}` opens at step 1. A round's token also reads the earlier rounds' answers its summary and `uses` lines show; that is intended, since only the owner holds round tokens. Writer identity is not recorded: only the owner writes for now (user, 2026-11-20).
- The token is a query parameter like the stage controls: `Query.Carry()` puts it on every link, form action, `hx-get` and `hx-post` the server renders, on the redirects and on `HX-Push-Url`, so htmx navigation and Retry keep it. A link to another round (earlier rounds in the chips) drops it. The client adds nothing: `warroom.js` only rewrites the `phone` and view parameters of the address it was given.
- A token longer than 64 bytes or with characters outside the control-value set is ignored.
- With or without a secret, a POST from another site is 403 (`http.CrossOriginProtection`, by `Sec-Fetch-Site` or `Origin`), so a page the owner visits cannot record into a local War Room.
- Unset secret: no token is checked, no cookie is set, nothing is read only, and `/picks.json` is open (local use only: with `WARROOM_RUN_AS` set the server does not start).

## History

Each write that changes an entry appends `{"t": RFC 3339 UTC, "key", "pick", "note", "value"?}` to `picks.jsonl` next to `picks.json` (`O_APPEND`, fsync, under the store lock, before the state file is replaced). `picks.json` stays the current state in the old format. A write that changes nothing adds no line. The summary shows "changed N times" on a row with more than one line; there is no other history view. When the next line would take `picks.jsonl` past 64 MiB, the file is renamed aside as `picks-<UTC time, to the nanosecond>.jsonl` and a new one started, so the history never refuses a write; "changed N times" and `/history.jsonl` read the current file only. A write whose state file then fails leaves its history line behind.

## Pick rules

A form body over 64 KiB is 400 (`form body over 64 KiB`; a 4000-character note of 4-byte characters fits); the pick must be an option letter the step has, `neither` (step has a neutral answer), `yes` or `change` (confirm step), `pass` or `changes` (verdict), or `tuned` (tune step, with a `value` field); `change` without a note shows the step again asking for one; a `tuned` pick must carry `value`, a JSON object of at most 1 KiB with exactly the step's param ids (numbers in range and on the step grid from `min`, colours `#rrggbb`, choices from the list; anything else is 400) and the server stores it cleaned (grid-snapped, colours lower case); a note is at most 4000 characters (400 `note over 4000 characters or not UTF-8`); a new key past 500 keys of its round's prefix is 507 (`picks file is full: 500 keys per round`), and other rounds keep recording; a failed write, or a picks file that is not a JSON object of objects (left as it is), is 500. Writes are atomic (temporary file, fsync, rename, fsync of the directory) under one lock. A request has 15 s in total to arrive, headers and body (`ReadTimeout`); a slower one is cut off. A pick from a plain form post redirects (303) to the next step; from htmx it answers with the next step's page and `HX-Push-Url`.

Query parameters (carried by the navigation links, so values stay page-wide): `show` (option), `view=side`, `item`, every stage control away from its first value (`size fit ground world zoom hud state tier owner set heading cvd marker x-<id>`), `numbers=0` (hide the numbers panel). A control value over 64 bytes or with characters other than letters, digits and ` ._,:+-` is dropped, as is any `x-` control past 16, since every link repeats them. Read only: `sheet=1` opens the phone's Controls sheet, `keys=1` the key list, `shot=1` the shown option alone at its frame size on black (`crop=step` keeps the step's crop), `lab=1` starts a lab step's build, `phone=1` asks for the phone crops (a phone-sized first load adds it itself).

`picks.json` keeps the prototype's format, `{"<prefix>:<key>[:<sub>]": {"pick": str|null, "note": str}}`, so the old gate picks read back. A tune step's entry has one more optional field, `"value": {param id: number|string}`. A pick of an option letter also stores `"name"`, the option's name at pick time, so a later edit of the step's options cannot silently change what an old "B" meant; any other answer clears it, a note keeps it. Entries without these fields stay valid.

## Keys

| Key | What |
|---|---|
| `A` `B` `C` `D` or `1` to `8` | Show that option on the stage (side by side: select its tile, as a click on the tile does; the shared Pick names it). `E` to `H` have only their digits `5` to `8`: `F`, `G` and `H` stay stage controls (user, 2026-11-20) |
| `0` | Show Today (the step's `ref` picture) on the stage, to look only: Pick is disabled and `Enter` does nothing until an option shows. One at a time only; side by side has the Today tile instead |
| `Enter` | Pick the shown option, record it and go on |
| `W` | One at a time / side by side (the status line's `Side by side (W)`) |
| `←` `→` (`[` `]`, `Backspace` back) | Previous / next step without picking |
| `N` `P` | Next / previous item inside a step (gallery picture, or the state on a step with a state control) |
| `L`, the Large button in the status line under the stage (desktop), or a click on a picture | Large view; `Esc` or a click closes it |
| `Space` | Play / stop the shown option's sound or clip |
| `?` | Key list, with the stage controls this step has |
| `S` `F` `G` `⇧G` `Z` `H` `T` | Window size, fit / true 100 %, ground, backdrop, zoom, HUD layer, tier. They work with the View menu closed |
| `O` `⇧O` `R` `⇧R` `⇧C` `M` `K` | Owner colour, colour set, unit heading (`⇧R` turns back), colour vision, small-change marker, numbers panel |

A step's own `extra` controls may name a key; the ones the app uses (`5` to `8` included) are refused at load. `V`, `X` and `⇧F` are not app keys: they work only on a step whose own `extra` controls name them (the demo scene's View, Camera and Factions). Keys do nothing while a note or list has the focus or with Cmd, Ctrl or Alt; `Enter` and `Space` on a focused button, link or fold (`summary`) do that element's own job, and a fold opened with the mouse gives the focus back, so the next `Enter` picks. Each key is a `data-key` on the element it clicks, so the buttons and the keys cannot drift apart. Below 900 px wide or on a touch screen a two-row bar covers every key; its Controls button opens a sheet with Side / One (side by side or one at a time) and the step's neutral answer on its first row, so they show without scrolling the sheet, then the stage controls, Whole screen and the key list; a tap on a picture zooms (side by side, the first tap on another tile selects it); a swipe on the picture flips the option (gallery: the item). A step with more than three options puts the option buttons in their own rows above the bar's first row, so each stays a thumb wide beside the fixed-width Pick. Side by side lays the tiles, Today's included, in two columns for up to four tiles and three for five or more.

A script error on the page (`window` `error` or `unhandledrejection`) shows as the red banner at the top ("Page script error: ... — reload the page; picks may not record"), so keys or picks that stop working say why; a click closes it. On a step that has option E, F, G or H, pressing that letter shows "Option F is key 6" for 2 s; F, G and H still do their control's job.

## Rounds: the data contract

Rounds are YAML, decoded strictly: an unknown field, an unknown step kind, no options, a `rec` that is not an option, a `uses` that is not a step, a gallery verdict key that clashes, or a control the render page does not take is a load error with the line.

```
rounds/index.yaml            - {id, title, demo?}   (order = list order)
rounds/<id>/round.yaml       the round
rounds/<id>/<step-key>.yaml  one file per step
```

`round.yaml`: `prefix` (key namespace, default the folder name; two rounds sharing a prefix are a load error and the later one in the index is not served, since write tokens are per round and keys per prefix; a round with a bad prefix is not served either), `title`, `intro` (what holds for the whole round, such as judging conditions and what a neutral answer ships as; the closed "This round" fold in the left panel on every step, open in the summary's centre column), `steps` (step keys in order; a missing file shows `[step missing: <key>]`), `earlier` (round ids whose picks the summary lists and `uses` can name), `advisory` (true for a package's closing round of defaults already built: the index and `go run . open` add "advisory: answer when you like"; it never blocks a merge), `render` (live-render recipe `{page, w, h, hash, pass}` over the app's default: `docs/images/hud-v5/source/p2-3a1-states.html`, 1280 x 720, `shot={state}&size=720&scale=1`), `controls`.

Step fields: `kind`, `question`, `why`, `look`, `rec` and `recWhy`, `options` (map `A` to `H`; one option makes a confirm step: Yes, as drawn, or Change with a note), `uses`, `neutral` (label of a neutral answer, recorded as `neither`), `blind` (letters stay neutral; each option's `reveal` and Claude's pick show after the pick; options keep their authored order, no shuffle), `view: side`, `crop {x,y,w,h}`, `phoneCrop`, `ref {label, render|img}`, `notesLabel` (still accepted so old rounds load; it has no visible effect since the three-panel layout), `controls`, `render`, `mark` (one or a list `{x,y,w,h,label,below?}`), `pairs` (`[name, '#hex', name, '#hex', 'vs'?]` for the numbers panel), `interactive`, `checklist`, `folds [{label, text, pics}]`.

A step opens on A, or on its recorded pick, never on `rec`: Claude's pick shows only as the tab on the Pick button while its option is shown, and as the pick and reason in the closed "Claude's reason" fold, so it does not choose what you see first.

Authoring rule: keep the always-visible texts to one line, and put the rest in a fold. The loader warns for each text over its limit: question 70, option `notes` 90, `look` 120 characters, counted after removing backticks. Longer detail goes in `why`, `recWhy`, `intro` or `folds` (and an option's `sees`, `changes` and `folds`, which the "About <letter>" fold shows). `look` always shows in full; an option row shows at most two lines of `notes`, and the "About <letter>" fold repeats a note the list cuts (measured in the page, whatever its length), so nothing is lost. Also vary the recommended letter across a round's steps, so `rec` is not always A or always the same letter. Blind steps are not shuffled, so the owner could learn where the candidate sits: the loader warns when a round has two or more blind steps with a `rec` and all of them put it at the same letter. These are the four warnings: the question, `notes` and `look` lengths, and the blind letter. Loader warnings go to the server log (`rounds warning=...`, on every load like the errors) and to `go run . open`, never to the page: on a blind step the blind-letter warning would name the candidate's letter before the pick.

Option fields: `name`, `notes`, `sees`, `changes`, `reveal`, `extra` (more pictures), `folds`, `mark`, and one body: `img` (`local: true` for a file never committed), `render {state, crop?, params?, page?, hash?, w?, h?}`, `video`, `text` or `audio` plus `level`.

| Kind | Fields | Recorded as |
|---|---|---|
| `pictures`, `text`, `audio`, `lab` | `options` (`text` kind: optional `card {title, lines, foot}` where a `null` line is the option's text; `lab`: `url`, `w`, `h`, `labHint`) | `<prefix>:<key>` = option letter, `yes`, `change` or `neither` |
| `gallery` | `items [{id, label, caption, render|img, mark}]`, optional `verdict {key, pass, changes}` | item notes `<prefix>:<key>:<item id>` (pick `null`); verdict `<prefix>:<verdict key>` = `pass` or `changes` |
| `verdict` | `labels {pass, changes}` | `<prefix>:<key>` = `pass` or `changes` |
| `tune` | `target`, `params`, optional `neutral` | `<prefix>:<key>` = `tuned` with `value`, or `neither` |
| `wording` | `fields [{id, label, text}]` | `<prefix>:<key>:<field id>`, the text as `note`, posted as you type |

Rounds here: `p2-3b-dock` (P2.3b's queue, empty card, counter line and cost mark; answers: design answers, "P2.3b War Room round"), `demo` and `demo-controls` (marked `demo: true`: one step per kind, one step per render target with its controls; `demo` has an `intro`, then a `tune` step and `many`, six options on the demo scene with measurement tables); the deleted P2.3a1 gate rounds live on as test fixtures in `testdata/rounds/` (answers: design answers, "P2.3a1 gate A").

## Stage controls

Under the stage, one muted line lists the current values of the step's controls (`1280 x 720 · Fit 63 % · Sand · Plain ground · Normal vision`, view values only): the Fit value carries the scale the stage shows it at, True 100 % the screen scale when it is not 1, and colour vision is always named (`Normal vision` without the control) and never cut when the rest is; then `Side by side (W)`, `Large (L)` and `View ▾`. `View ▾` opens the menu with every control button; the keys work with it closed. The stage zone above it has the same height on every step and option (see Styles).

`controls` on a round or step: `name: true` (every value) or a list (these values, the first is the start); a step's entry overrides the round's per control. `state` needs a list. Values: `size` (`1280x720`, `1280x800`, `1920x1080`, `3440x1440`), `fit` (`fit`, `100`), `ground` (`sand`, `dark`), `world` (`plain`, `none` and the named `docs/images/hud-v5/source/worlds/` scenes), `zoom` (`0.5`, `1`, `2`), `hud` (`on`, `off`, or a list of states laid over the picture), `tier` (`full`, `core`), `owner` (`drawn`, `1` to `8`), `set` (`default`, `neon`), `heading` (`0` to `7`), `cvd` (`normal`, `deut`, `prot`), `marker` (`on`, `off`). `extra: [{id, label, key?, values: [{v, label}], param?}]` adds the step's own controls, sent to the render page as `param` (default `id`).

`fit`, `set`, `cvd` and `marker` are done by the app; the others reach the render page through `render.pass` (`{size: size, world: world, ground: ground, hud: hud, owner: you}` for `p2-3a1-states.html`). A control that neither does is a load error. The numbers panel prints WCAG contrast and CIE76 distance (normal, deuteranopia, protanopia; Machado 2009) for the step's `pairs`.

Measurement tables: a render page may post `{type: 'wr:measure', rows: [[label, value, ok?], ...]}` to its parent (`parent.postMessage(msg, location.origin)`). `warroom.js` takes it only from its own origin and from a frame on the page, and on start and after every swap posts `{type: 'wr:ask-measure'}` to each frame, so a frame that reported before the script listened reports again (a frame still loading reports when it draws); keeps at most 20 rows per frame (by frame id, so a morph that keeps the frame keeps the table) and prints them as text in a table beside that option's extras in the "More of" strip (side by side: inside its tile), so it never scrolls the page; a table taller than the strip scrolls inside it; `ok: false` is a muted row with "✗" (amber stays for the pick), `ok: true` gets "✓", no `ok` neither. A blind step has no tables until its pick reveals the letters, since numbers could tell the options apart. `static/demo/scene.html` reports the units it drew and its outline width (under 1 px flagged). Tune steps show none.

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

`islands/` holds the Svelte sources, `package.json` with exact versions and `package-lock.json`. `npm run build` (Vite library mode, one minified ES module) writes `internal/web/static/islands.js` and copies `node_modules/htmx.org/dist/htmx.min.js` to `internal/web/static/htmx.min.js`; both are committed and embedded like `app.css`, so `go build`, `go test` and the Docker build need no Node. `go generate ./...` runs `npm ci` and the build; `tools/check_generated.sh` rebuilds in a temporary copy and fails when `internal/web/static/islands.js` or `htmx.min.js` differs. To update htmx, change the exact version in `islands/package.json`, run `npm install` and `go generate ./...`.

## Step layout

A choice step on the desktop has three panels, the same on every step and option. Left (260 px): the step tabs (chips) and Summary, the eyebrow and the question, "Look at" (`look`, always in full), then closed folds: "Why this question", "Claude's reason", "About <letter>" (the shown option's `sees`, `changes` and `folds`, and its `notes` only when the list cuts them; a fold that would hold nothing else stays hidden) and "This round" (`intro`), plus the step's info blocks. The eyebrow ("Step 1 of 6 · " then the round title) is one line; the ellipsis only ever cuts the title, and its tooltip has it in full. Centre: the stage zone, the status line (see Stage controls), and the "More of <letter>" strip with the measurement table. Right (340 px): the Options list, then Pick, the neutral answer, the note and Back / Skip under it. The note has no label above it: its placeholder says "Note for Claude (optional)" (a confirm step: "Note (say what to change, or anything else)"), the old label is its `aria-label`, and Change without a note shows "Say what to change here, then press Change again." as the amber placeholder.

Fixed zones keep things in place, by CSS only: the stage zone is `100dvh` minus the status line, the "More of" strip and the page padding, with the picture centred on black and never wider than the centre column; the strip keeps its height when an option has no extras; the Options list scrolls inside a fixed box, with a "▾ more" fade over its bottom while it goes on below, and the block under it keeps the height of Pick plus a second button, so Pick (and a confirm step's Yes) holds one position on every step, with or without the neutral answer or the note's hint. The read-only or error banner above the page is measured into `--banner` and taken off every fixed height, so the zones still end at the window's bottom. The list rows show the key, the name and `notes`, cut after two lines; row `0` is Today (a `ref` picture, to look at only) and picking is disabled while it shows. Side by side keeps the tiles and the one shared Pick but has no Today row (its tile carries Today). Every page kind (gallery, tune, wording, verdict, missing, summary) keeps the same three columns at the same positions, so no zone jumps between pages: left the question and folds, centre what you judge, right your answer and the step buttons (user, 2026-11-21). The right panel holds a tune step's Use these values, None of these and note; a verdict's Pass, Changes needed and note; a gallery's item counter, caption, item note and Previous / Next at the top and its verdict under them; a wording step's Done, next (Enter); the summary's Copy summary; and Back / Skip / Keys at the bottom on every page. The first answer button (Pass, Use these values, Done, next, a gallery's first verdict button) sits where Pick sits on a choice step; a page with nothing to answer keeps only the step buttons, still at the bottom. Every primary answer is yellow and takes Enter (Enter in a note types a new line); every secondary answer (None of these, Change, Changes needed) is outlined at the same size, 8 px under it. Every control's edge (buttons, step tabs, option rows, note fields) uses `--edge`, at least 3:1 against the panel it sits on (WCAG 1.4.11), and its label at least 4.5:1 (user, 2026-11-21). Blocks at a reading width in the centre (wording fields, the tune sliders, the summary as one column as wide as its widest part (table, chips or intro, at most 1200 px) with earlier rounds under it on the same left edge, the intro at 65 characters inside it, the missing-step message, a gallery's thumbnails) are centred in the column, their text left-aligned; a gallery's scale and Large row is styled like a choice step's status line; a verdict step's centre stays empty. A link with no token shows the rows and no Pick, neutral answer or note.

On a phone (below the breakpoint) the order is the question and "Look at", the stage as a 4:3 box at full width (side by side is not boxed; its tiles scroll with the page), the options, then the sticky bottom bar with Pick, 104 px wide on every step. The step strip scrolls the current step into view. There is no horizontal scroll.

## Styles

`internal/web/static/app.css` is one hand-written file with native nesting and no build. Its first line fixes the cascade layers, and a later layer beats an earlier one whatever the selector weight:

| Layer | What |
|---|---|
| `reset` | Margins, borders and form fonts zeroed, `[hidden]` always hides |
| `tokens` | Public Sans from `/game/fonts/` and the custom properties below |
| `base` | Body, links, `textarea`, `kbd` (the HUD key chip), `.sr-only` |
| `components` | Buttons, tags, chips, the step grid, head, notes, tiles, gallery, verdict, tables, key list, the `wr-tune` theme |
| `stage` | The black stage, pictures and frames, marks, the large view, colour-vision filters, true 100 %, `?shot=1` |
| `phone` | Below 900 px or on a touch screen: one column, the two-row bar and its Controls sheet. The bar sits in the page flow, `position: sticky` at the bottom of a `min-height: 100dvh` column, so the page always ends above it whatever its height (larger text, option rows, the open sheet) |

Colour tokens take the HUD v5 set A values (`docs/reference/hud-v5-layout.md`, `game/scripts/lab/lab_look.gd`), so the page frames art in the game's own quiet chrome: `--well` page, `--slab` panels, `--quiet` idle buttons, `--btn` hover, `--panel2` highlighted card line, `--line` borders, `--muted` labels (also the eyebrow), `--sel` cyan only as a signal: the shown or current item, a recorded verdict, the Picked tag, the open sheet; never decoration. `--amber` (the HUD `amber`, `lab_look.gd`) marks where to act and what needs attention: the pick button and Retry, look cues, marks, unsent or failed picks, low numbers, the note's hint and the loading bar, a 3 px line fixed across the window's top while a page change is in flight. Side by side, the tiles have no Pick buttons: a click on a tile (or its letter key) selects it, and its letter turns `--sel`; a click on the selected tile's picture opens the large view, a click on another tile's picture only selects it. The amber Pick sits in the right panel under the Options list, at one height on every step, and names only the shown or selected option's letter, "Pick B", so its width never changes (the one `Enter` presses; user, 2026-11-21); the neutral answer follows it. The neutral answer (`.neutral`, in the right panel and in the phone sheet) has a quiet fill and a `--muted` edge, since `--quiet` on `--well` alone is 1.1:1; its tooltip says "Records no winner. Say why in the note.", with no visible hint line (user, 2026-11-21). The tune slider shows keyboard focus with the buttons' `--text` ring, drawn inside the track (offset -2 px) so it never touches the value box or the next row; the pane's rows sit 8 px apart (`--tp-container-unit-spacing`). Claude's pick is a light badge, "Claude's pick" in sentence case, `--well` on `--text` (14.8:1) and never amber, and it appears in one place only (user, 2026-11-21): a 14 px tab on the top edge of the shared Pick button, left-aligned, while the shown or selected option is Claude's. It follows flips, digits and tile clicks (`.ptab`, `data-cp`; the phone bar's Pick wears it too), sits in the 16 px gap without reaching the picture, and leaves the button and row height alone. Option rows, side-view tiles, the option header, the line under the question and pictures carry none; a confirm step's only option carries none either. The closed "Claude's reason" fold names the pick and its reason in words. A blind step shows no tab before the pick, and a read-only page has no Pick, so no tab. `--text` is `#dfe7ec`, softer than the HUD's, and `--soft` sits between it and `--muted`; `--stage` is black. Type: `--font` (Public Sans), `--label` 12 px (the HUD floor, uppercase labels), `--row` 13 px.

Own classes, no utility classes: `.btn` with `.sm` `.lg` `.xs` sizes and the states `.on` (cyan) and `.pick` (amber); `.tag` with `.cp` (Claude's pick, the light badge; `.ptab` makes it the Pick's tab) `.got` (Picked, cyan) `.rv`; `.chip`, `.scroll` (a table that may scroll sideways). `warroom.js` toggles `.on` on the option buttons and `.sel` on tiles; keys find elements by `data-key`, `data-show`, `data-act` and `data-pick`, not by a style class; a click on a tile finds it by `.tile[data-opt]`, and a clip that starts playing in another tile selects that tile.

## Build and checks

| What | Version |
|---|---|
| Go | 1.27.4 |
| invopop/jsonschema | v0.14.0 (2026-04-23) |
| templ | v0.3.1100 (CLI as a `go.mod` tool: `go tool templ`) |
| YAML | goccy/go-yaml v1.19.2 |
| htmx | 4.0.1 (2026-11-01), npm `htmx.org` in `islands/`; the build copies `dist/htmx.min.js` to the committed `static/htmx.min.js` |
| Svelte | 5.57.3 (islands) |
| Vite | 8.3.6 |
| @sveltejs/vite-plugin-svelte | 7.3.1 |
| Tweakpane | 4.0.5 (types from `@tweakpane/core` 2.0.5) |
| mxschmitt/playwright-go | v0.6201.1 (2026-08-17), Playwright 1.62.1; browser tests only (`-tags browser`) |
| TypeScript | 6.0.3 (typescript-eslint 8.72.1 does not support 7 yet) |
| svelte-check, ESLint, Prettier | 4.7.8, 10.14.0 (with `eslint-plugin-svelte` 3.24.0), 3.9.10 (with `prettier-plugin-svelte` 4.1.1) |
| govulncheck | v1.9.0 (`go tool govulncheck`) |
| Node, npm | only for `islands/`; Node 24 (`islands/.nvmrc`, `engines`) |

The generated files are committed (`internal/web/*_templ.go`, `internal/web/static/islands.js`, `internal/web/static/htmx.min.js`, `rounds/round.schema.json`, `rounds/step.schema.json`), so `go build` and `go test` need no templ or Node. `internal/web/static/app.css` is hand-written (see Styles) and needs no build step. After changing a `.templ` file or `islands/`:

```sh
go generate ./...     # templ generate, the schemas, npm ci and the islands build
```

The JSON Schemas come from the Go types (`go run . schema round|step`, run by `go generate`). Every round and step YAML starts with `# yaml-language-server: $schema=../round.schema.json` (`../step.schema.json` for steps), so an editor with the YAML language server completes fields and flags unknown ones; the strict decoder stays the authority. Two schemas, not one: `round.yaml` and a step file are different types. A new custom YAML type needs a case in `customTypes` (`internal/rounds/schema.go`).

Dev loop: `sh tools/dev.sh` runs `go tool templ generate --watch --open-browser=false --proxy=http://127.0.0.1:8780 --cmd="go run ."`: templ regenerates on a `.templ` or `.go` save, restarts the server and reloads the browser through its proxy at `http://127.0.0.1:7331/`. Rounds are read per request, so a YAML edit needs only a reload. `WARROOM_PORT` changes the port the proxy forwards to. The island is not watched, and `app.css` is embedded, so a CSS edit needs a restart (save a `.go` file).

Checks, in `warroom/`:

```sh
sh tools/quality.sh               # the whole gate, in this order:
#   go vet -tags browser ./... ; golangci-lint run --build-tags browser   (config .golangci.yml, a copy of relay's)
#   go test -race ./... ; go tool govulncheck ./...
#   sh tools/check_generated.sh   (regenerates into a temp copy; fails when the committed output differs)
#   npm ci; npm run quality in islands/   (format:check, lint, check: tsc also parses warroom.js)
```

`.github/workflows/warroom.yml` runs `sh tools/quality.sh` as job `quality` and then the browser tests in Firefox as job `browser`, on pushes and pull requests that touch `warroom/**`. The browser tests (next section) run apart from `quality.sh`; `tools/run_checks.sh` does not call it.

The island is TypeScript (`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`). `internal/web/static/warroom.js` stays plain JavaScript with no build: it starts with `// @ts-check` and `tsc` checks it in place with JSDoc types (`islands/tsconfig.json` includes it; htmx event types come from the `htmx.org` package). ESLint (`islands/eslint.config.js`: typescript-eslint strict type-checked, `eslint-plugin-svelte` recommended, `eslint-config-prettier`, `--max-warnings 0`, unused disable directives are errors) and Prettier cover both. In `islands/`: `npm run format`, `format:check`, `lint`, `lint:fix`, `check`, `build`, `quality`. `lint` runs from `warroom/` because ESLint only lints files under its base path and `warroom.js` is outside `islands/`. Agent rules: [AGENTS.md](AGENTS.md).

## Browser tests

`internal/web/browser_test.go` drives the real page in headless Firefox through playwright-go: keys, option flips, picks and Retry, the phone sheet, tune sliders, measurement tables, the error banner, the read-only link. They sit behind the build tag `browser`, so `go test ./...` needs neither playwright nor a browser, and `go.mod` carries the module only for the tagged files. Each test starts the whole server in-process (`httptest`, a temp picks file) and opens a fresh page on it; the shipped rounds (`demo`, `demo-controls`) are the fixtures.

```sh
cd warroom
go run github.com/mxschmitt/playwright-go/cmd/playwright install firefox   # once; downloads the driver and the browser to ~/Library/Caches
go test -tags browser ./...
go vet -tags browser ./... && golangci-lint run --build-tags browser
```

Without the browser the tagged run fails at once with an install line; it never skips. The browser is Firefox; on macOS the helper points `MOZ_APP_DATA` at a temporary folder first, because macOS 27 denies a terminal-started Firefox its app data (see Learning notes). `WARROOM_BROWSER=chromium` (after `install chromium-headless-shell`) swaps the browser.

Covered: a flip keeps every iframe document; a stage control replaces the frame with the new hash; a pick round trip writes `picks.json` and moves on; a failed pick shows Retry and Retry records the failed letter, also with a secret and the round's token; a note survives leaving the step after a failure; Retry never sends a note older than a recorded one, and a recorded pick drops an older failed note; leaving with unsent picks asks first (`beforeunload`); side by side, a click on a tile selects it, the shared Pick's letter follows clicks and keys, and Enter picks the selected tile; the phone bar stays at the bottom mid-scroll and below the note at the end, with the sheet closed and open; the round list has no empty phone strip; the phone Controls sheet opens (a 390 px same-origin frame, since headless Firefox cannot go below 500 px), and Side and the neutral answer live in it, not in the bar, with the neutral answer (`--muted` edge) in view without scrolling on the step with the most controls; a loader warning never reaches the page (Go test); a non-blind step opens on A, not on Claude's pick, and on the recorded pick once there is one; Claude's pick is a light badge with at least 7:1 contrast and appears only as the Pick's tab, never on a row, tile, header or picture; the tab sits on its top edge, left-aligned and clear of the picture, only while Claude's option is shown or selected (one at a time and side by side), and a blind step has none before the pick; side by side, a click on another tile's picture only selects it and a second click opens the large view; Play on another tile's sound, or starting another tile's clip, selects that tile and keeps it playing; the selected tile's letter is `--sel` and the Pick names the option, a long name cut without wrapping; the Pick is 44 px tall; the neutral answer's tooltip says what it records and there is no visible hint line, on the desktop (also side by side and on a tune step) and in the phone sheet, and no neutral answer on a read-only page or a step without one; Pick, a step without the neutral answer's Pick and a confirm step's Yes (also with the note's hint) sit at one height; long notes are cut after two lines so every row starts inside the list at 1440 x 900 and 1280 x 800, and "About" repeats a note the list cuts, also one under the loader's 90-character limit (p2-3b-dock step 5, option B), and the "▾ more" fade shows while a list goes on below; the verdict sits in the centre at reading width while a gallery's stays left; the phone Pick has one width on every step and Claude's tab never overhangs it; the eyebrow is one line, starts with the step count and has the full text as its tooltip; the status line is one line with the scale in its Fit value and colour vision named and never cut; side by side, four tiles take two columns (pictures at least 340 px wide, one-line headers) and six take three; the measurement table sits inside the "More of" strip and the page does not scroll at 1440 x 900; the phone step strip shows the current step; the summary's intro is open in the centre column; "More of" captions wrap to two lines inside the strip; at true 100 % switching options keeps the stage's scroll (this one passed before its change and stays as a guard); Enter on a focused fold opens it and records nothing, and a mouse click leaves no fold focused; the read-only banner keeps the right panel's nav and the "More of" strip above the window's bottom; the loading bar is fixed across the window's top; the three-panel layout: the stage zone has the same rect for a crop and a full frame and Pick never moves between options and steps, at 1440 x 900 and 1280 x 800; the stage fits its column at Window 1280 x 800 with True 100 %; Pick is visible without scrolling; Today (key `0`) and the extras sit in the same place on every step, Pick is disabled and Enter does nothing while Today shows, and the side view has no Today row; the "About" fold never repeats a note the list shows whole, a fold with nothing else stays hidden (red when every note is marked cut), and it and the "More of" strip follow the shown option, also after a control swap; the detail folds start closed; the View menu closed still answers its keys; every step kind has the left panel and its controls need no scroll; the phone has no sideways scroll, a 4:3 stage box and a Pick bar that wears the tab; the tune knob is `--text` on a `--muted` track, and the track shows a focus ring from the keyboard; side by side, the shared amber Pick and the quiet neutral answer with its `--muted` edge sit in the right panel under the list; the tune pane's rows sit one even 8 px apart and the focus ring stays inside its row, clear of the value box; a tune slider redraws without reload and records `value`; the read-only link has no pick controls; a held Enter picks once; keys `5`, `f` and `e` on a step with options E and F; a `wr:measure` from a foreign origin or a non-frame is ignored; measurement rows render as text; the error banner for a thrown error and an unhandled rejection; a measurement that arrived before the script listened; a table that survives a control which keeps the frame; the table under its own option in flip and side views; the Large button; a tune element connected and disconnected twice leaves one pane, then none (red when `pane.dispose()` is removed from the `$effect` cleanup in `islands/Tune.svelte`); with a secret, the `wr` cookie a link's token sets carries a picture, a static file and an htmx request that have no `t`, page script cannot read it, and without it they get the gate's 403. Each was proven by breaking the code it guards once and seeing it fail.

## Fly

`fly/` deploys War Room to the fly app `warroom` at `warroom.pdstuber.dev`, with a volume, so picks survive restarts and redeploys. Every `fly` command needs the owner's approval.

```sh
fly secrets set WARROOM_SECRET=... -a warroom   # once; the image sets WARROOM_RUN_AS, so without it the server refuses to start
fly secrets set WARROOM_VIEWERS=name1,name2 -a warroom   # the friends let in; setting it restarts the machine
sh warroom/fly/sync.sh                                  # fly/site/: Go sources, rounds, referenced repository files
fly volumes create decision_picks --region fra --size 1 -a warroom   # once
fly deploy warroom/fly
```

`sync.sh` copies the Go sources, the rounds not marked `demo: true` (so the public site has no demo rounds or keys) and every `docs/...` and `game/...` path their YAML and the Go sources name, plus the local files those HTML pages load, the backdrops, `layout.json` and the game font. It copies only files Git tracks: a file that exists only on disk, such as an owner mock, is reported as `skipped, not tracked by Git` and stays off the public site. The Dockerfile builds a static binary (`CGO_ENABLED=0 go build -trimpath`) and copies it into `gcr.io/distroless/static-debian12` (root variant, pinned by digest; no shell). Fly's volume and `[mounts]` docs say nothing about who owns a mount, and community reports say mounts arrive root-owned, so the binary chowns the picks directory to 65534 and drops root itself (`priv_linux.go`); the machine stops when idle and starts on the next request; the Dockerfile sets `WARROOM_RUN_AS=65534`, so a local run as root never chowns anything; `WARROOM_PICKS` is `/data/picks.json`, the prototype's file and format. The custom domain is a fly certificate (`fly certs add warroom.pdstuber.dev -a warroom`) plus the DNS records `fly certs show` names.

Test the image without Fly with Apple's `container` CLI (`container system start` first). Use a named volume: a host directory cannot be chowned through the shared mount.

```sh
container build -t warroom-test warroom/fly
container volume create warroom-test-vol
container run -d --name warroom-test -p 8783:8780 -e WARROOM_SECRET="$(openssl rand -hex 16)" -v warroom-test-vol:/data warroom-test
curl -s http://127.0.0.1:8783/health
container logs warroom-test                  # "running as uid 65534"
container stop warroom-test && container rm warroom-test && container volume rm warroom-test-vol && container image rm warroom-test
```

With the secret set, every page needs a token or the cookie (see Tokens; `/health` stays open for fly's check), reading `/picks.json` or `/history.jsonl` needs the admin token and a pick needs the round's token (see Tokens), and a page shows answers only with the round's token. Reading picks back is `curl "$HOST/picks.json?t=$(WARROOM_SECRET=... go run . token admin)"`, which needs the secret on the machine that asks.

## Learning notes

Things that cost time with the pinned versions.

- `ServeMux` patterns (Go 1.22+, `go doc net/http.ServeMux`): `[METHOD ][HOST]/[PATH]`, with `{name}` for one segment, read with `r.PathValue("name")` (`GET /r/{round}/{n}`). Precedence: when two patterns match a request, the one matching a strict subset of the other's requests wins, so the literal `GET /r/{round}/summary` beats `GET /r/{round}/{n}` (`handlers.go` registers both). Two patterns that overlap with neither more specific "conflict", and registering the second panics at startup: `GET /r/{round}/x` beside `GET /r/x/{n}` would. `GET /` would match every path, so the round list is `GET /{$}`. `{path...}` takes the rest of the path. A pattern with a method answers 405 for other methods, and `GET` also serves `HEAD`. ServeMux cleans the path itself: `/docs/../x` and `/docs` (the subtree `/docs/{path...}` exists) answer a 307 to the cleaned or slashed path, which is then served or 404.
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
- Tweakpane's slider is a focusable `div` with its own arrow-key handler that does not stop the event, so `warroom.js` would flip the step; it now ignores keys from inside `wr-tune` except Enter. Its text inputs are covered by the existing input rule. It injects its own `<style>` and is themed with `--tp-*` custom properties on `wr-tune` (`internal/web/static/app.css`), set from the page's tokens; its list is a native `<select>` that stays light grey unless `--tp-button-*` is set. The slider knob takes the same button colour, which Tweakpane resolves once on `.tp-rotv`, so `app.css` sets Tweakpane's internal `--btn-bg*` on `.tp-sldv_k` alone (knob `--text`). The slider track is drawn in the input background (`--in-bg`, here `--well`, close to invisible on `--slab`), so `app.css` sets `--in-bg` to `--muted` on `.tp-sldv_t` alone; the text fields keep theirs. Check the names on an upgrade.
- Vite library mode: `build.emptyOutDir` must be `false` because `outDir` is `static/`, which holds the rest of the site. `build.minify` alone leaves whitespace in an ES library bundle (meant for another bundler), so `rolldownOptions.output.minify: true` forces full minification: 180 KB, 42 KB gzipped (was 219 KB, 47 KB); most of what is left is Tweakpane's injected stylesheet. The Svelte plugin's "no Svelte config found" line is harmless; the compiler option sits in `vite.config.js`.
- playwright-go: the canonical module path is now `github.com/mxschmitt/playwright-go` (its `go.mod` says so from v0.6100.0; `github.com/playwright-community/playwright-go` still resolves up to v0.6000.0 only). v0.6000.0 downloads its driver from the retired `playwright.azureedge.net` and fails with 404; from v0.6100.0 the driver comes from npm. On macOS 27, Playwright's Firefox 157 build (v0.6401.0) answers `Could not find profile folder.` and the 1.60 to 1.62 builds start but never answer the Juggler pipe (the `RenderCompositorSWGL` log line is a red herring): macOS 27 denies a terminal-started Firefox `~/Library/Application Support/Firefox`. Setting `MOZ_APP_DATA` to another folder before `playwright.Run` works (the driver passes its environment to Firefox; `Env` in the launch options would replace the whole environment). Firefox 158 fixes it (bugzilla 2069536; Playwright 1.65 ships Firefox 159), so the workaround goes once playwright-go has a 1.65 release.
- Headless Firefox through WebDriver cannot be made narrower than 500 px wide; for a 390 px layout load the page in a same-origin `<iframe>` of that width. In a WebDriver test, `clear` on a Tweakpane text input fires `change` and the pane reverts it; select the text and type instead.
