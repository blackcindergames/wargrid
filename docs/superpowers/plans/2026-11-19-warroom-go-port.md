# War Room: Go port of the decision page

Port the decision page prototype (`tools/decision_page/`, Python server + vanilla JS SPA) to a Go app `warroom/` with chi, templ, htmx, Tailwind CSS and daisyUI, toward feature parity; the prototype stays alongside for now. Unattended night work; decisions below are the owner's answers of 2026-11-19 or marked provisional.

## Decisions

- Owner (user, 2026-11-19): htmx for navigation, picks, notes, summary and stage controls; a small vanilla JS file for instant option flips, keys, swipe and large view (a flip through the server would reload the live-render iframes). Rounds as YAML. Own Go module `warroom/` at the repository root beside `relay/`; the Python prototype stays in parallel for a time (revised the same night: parity of all 50 features may take more than one night). Full parity including the fly files (Dockerfile tested locally with Apple's `container` CLI, never deployed). Name: War Room.
- Provisional: the pick endpoint is per step, `POST /r/{round}/{step}/pick` (form fields `pick`, `note`); the server builds the key from the round's prefix, so the client never sends a key and only real steps are accepted. Notes: `POST /r/{round}/{step}/note` (field `note`, optional `sub` for a gallery item id or wording field id). `picks.json` keeps its exact format (`{"<prefix>:<key>[:<sub>]": {"pick": str|null, "note": str}}`), so the old gate picks read back. `GET /picks.json` stays for Claude; `/picks.js` goes (server rendering replaces it).
- Provisional: state lives in the URL path and query, not the hash: `/` round list (`?demo=1` shows demo rounds), `/r/{round}` opens the first unanswered step, `/r/{round}/{n}` (1-based) a step, `/r/{round}/summary`. Query: `show`, `view=side`, `item`, every stage control away from its first value (same names as the prototype's hash: `size fit ground world zoom hud state tier owner set heading cvd marker x-<id>`), `shot=1`, `crop=step`, `sheet=1`, `keys=1`. Navigation links carry the control params, so control values stay page-wide as before. JS updates `show`/`item`/`view` with `history.replaceState`.
- Port: default `127.0.0.1:8780`. Never use 8767 or anything up to 8772 (other servers run there).
- Static files: the app serves only `/docs/`, `/game/` and `/web/` from the repository root (`WARROOM_ROOT`), not the whole tree; its own assets are embedded (`go:embed`) under `/static/`.

## Pinned versions (each at least two weeks old on 2026-11-19)

| What | Version | How |
|---|---|---|
| Go | 1.27.4 (as `relay/`) | `go.mod` |
| chi | `github.com/go-chi/chi/v5` v5.5.0 | `go.mod` |
| templ | `github.com/a-h/templ` v0.3.1100 | library in `go.mod`, CLI as a Go tool dependency: `go get -tool github.com/a-h/templ/cmd/templ@v0.3.1100`, run with `go tool templ generate` |
| YAML | `github.com/goccy/go-yaml` v1.19.2 | strict decode (`yaml.Strict()`/`DisallowUnknownField`), errors carry line numbers |
| htmx | 4.0.1 | vendored `warroom/static/htmx.min.js` (from the npm package `htmx.org@4.0.1`, `dist/htmx.min.js`). htmx 4 differs from 2.x (fetch based, explicit attribute inheritance, renamed events): read its docs from the package or the repository tag `v4.0.1` before using an attribute or event; do not write htmx 2 idioms from memory |
| Tailwind CSS | v4.3.4 standalone CLI | `warroom/tools/fetch.sh` downloads `tailwindcss-macos-arm64` (and `-linux-x64`/`-linux-arm64` by `uname`) from the GitHub release into git-ignored `warroom/.bin/` |
| daisyUI | 5.7.50 | the same script downloads `daisyui.mjs` and `daisyui-theme.mjs` from the GitHub release into `warroom/.bin/`; the CSS input uses `@plugin "../.bin/daisyui.mjs"` (daisyUI's standalone-CLI setup) |

Generated files are committed so `go build`, `go test` and the Docker build need no templ or Tailwind: `*_templ.go` and `warroom/static/app.css` (minified). `go generate ./...` regenerates both (`//go:generate` lines in `warroom/main.go`); a check (`sh warroom/tools/check_generated.sh`) regenerates into a temp copy and fails on a diff.

## Layout

```
warroom/
  go.mod go.sum .golangci.yml (copy of relay/.golangci.yml) .gitignore (.bin/, warroom binary, picks.json)
  main.go            config from env, chi router, ListenAndServe with timeouts
  store.go           picks file: read, validate shape, atomic write, mutex, key cap
  rounds.go          YAML types, load + validate every round at startup and on each request in dev (see below)
  handlers.go        page and endpoint handlers
  numbers.go         WCAG contrast and CIE76 distances (normal, deuteranopia, protanopia; Machado 2009) for `pairs`
  stage.go           stage controls: specs, values, render-page hash building, crops, sizes (port of stage.js)
  views/*.templ      layout, round list, step kinds, summary, chips, phone bar, legend, shot mode
  static/            htmx.min.js, warroom.js (client), app.css (generated), input.css (Tailwind source)
  rounds/<id>/round.yaml, rounds/<id>/<step>.yaml, rounds/index.yaml
  fly/ Dockerfile fly.toml sync.sh
  tools/fetch.sh check_generated.sh shoot.sh
  *_test.go
```

Env: `WARROOM_ROOT` (default: the repository root, found as the parent of the `warroom` dir of the running source, or `.`/`..` checks; keep it simple: default `..` relative to the working directory `warroom/`, documented), `WARROOM_PICKS` (default `warroom/picks.json`, git-ignored), `WARROOM_ROUNDS` (default `warroom/rounds`), `WARROOM_HOST`, `WARROOM_PORT`. Rounds load from disk (not embedded) so a round edit shows on reload without a rebuild; load errors are a red banner on the page and a log line, as the prototype's error banner.

## Behaviour contract

`tools/decision_page/README.md` is the spec: "Page rules", "Keys", "Rounds: the data contract", "Stage controls", the endpoint rules and the fly notes. Port every rule there, translated by the decisions above (path/query instead of hash, YAML instead of JS, per-step endpoints). The code to read for details: `tools/decision_page/app.js`, `stage.js`, `app.css`, `server.py`, `test_server.py`, `shoot.sh`, `fly/`. The feature inventory with the owner-liked flags: `~/projects/wargrid-overnight-work/decision-page/decision-page-features.json` (private, read only). Known open findings to fix in passing if cheap: `proto-final-review.json` and `fix3-result.json` in the same folder.

Server guards to keep (from `server.py`): body cap 8 KiB (`http.MaxBytesReader`), pick is `null`/empty or 1 to 16 letters (`yes`, `change`, `neither`, `pass`, `changes` or an option letter the step has: stricter is fine), note is a string, note cap (pick a sane cap, 4000 chars), new-key cap 500 (507 past it), 500 when the picks file is not a JSON object of objects (file left as it is), atomic write (temp file in the same dir, fsync, rename), one mutex around read-modify-write, `ReadHeaderTimeout`/`ReadTimeout` 15 s (replaces the Python deadline timer), `Cache-Control: no-store` on picks. Demo rounds (`demo: true` in the index) accept picks locally; the fly site does not ship them (sync step). `GET /health` 200.

htmx flows (provisional, adjust to htmx 4's real API):
- Pick: a button posts to the step's pick endpoint with the note included; the response is the next step's page content (swap the main region, push the next URL), with the "Recorded: <step> <pick>." line computed by the server. On a network error or non-2xx: stay, show the amber "Not recorded: … Retry" line, chip amber and dashed, keep the pick on the page; Retry resends.
- Notes: textarea posts on input (debounced) and on blur, requests for one textarea in order (htmx sync queue), wording fields "as you type".
- Stage control: a control button fetches the same step URL with the new query and swaps only the stage region, pushing the URL.
- Summary: server-rendered from `picks.json` (no client read-back race: pick posts finish before the summary request is sent, since navigation waits for the swap).
- Keys: one `keydown` handler in `warroom.js` clicks the element carrying `data-key="<key>"` (server puts the key on each button), except for flip/side/large/play/swipe/item/legend which are client actions. Keys off while a textarea/select has focus or with Cmd/Ctrl/Alt.

## Tasks

Each task: TDD where there is logic (store, rounds validation, stage hash building, numbers, handlers); `go test ./...`, `go vet ./...` and `golangci-lint run` in `warroom/` pass at the end of the task. Output of test runs goes to a file; read the summary. Never commit; the coordinator commits.

### Task 1: module, store, rounds, endpoints

1. `warroom/` module with pinned deps, `.golangci.yml` copied from `relay/`, `.gitignore`.
2. `store.go` + tests: port every case of `tools/decision_page/test_server.py` that still applies (shape check, atomic write, cap 507, bad bodies 400, write failure 500, picks.json 500 on a bad file).
3. YAML conversion of the five rounds: a throwaway Node script in the session scratchpad loads each `rounds/*/*.js` with `DP` stubs and writes JSON; convert to YAML (any throwaway tool, e.g. `uv run --with pyyaml`), keeping literal prose (block scalars for long text), and keep the `prefix` comment ("Keeps the gate page's key namespace…") as a YAML comment. Commit only the YAML. `rounds/index.yaml` replaces `index.js`.
4. `rounds.go` + tests: types for round, step, option, item, field, controls, render, crop, mark, pairs, folds, card; strict decode; the checks of `checkStep`/`checkControls` (unknown kind, no options, rec not an option, uses not a step, gallery verdict key clash, control errors) as load errors; every shipped round loads clean.
5. chi router with the endpoints above (pages may be plain placeholders until Task 2), static `/docs/ /game/ /web/` file server (no directory listing, no `..`), `/static/` embedded, `/health`, `/picks.json`, `/` round list. Handler tests with `httptest`.

### Task 2: toolchain and server-rendered pages

1. `warroom/tools/fetch.sh` (pinned URLs; verify each download's SHA-256 against a value recorded in the script on first fetch), `input.css` with Tailwind + daisyUI (one dark theme close to the prototype's colours in `app.css`; keep the game font where the prototype used it), `go generate` lines, `check_generated.sh`.
2. templ views for every kind (`pictures`, `text`, `audio`, `lab`, `gallery`, `verdict`, `wording`, confirm steps, missing step), the round list, the summary (rows, unanswered links, "You can close this tab.", earlier rounds, Copy summary), the chips header, the record line, "Why this question", "Where to look", reference picture, uses, checklist, folds, Claude's pick line, blind reveal, neutral button, notes labels. Live renders as iframes with the render-hash built in Go (`stage.go`, port of `frameSrc`, `ctlParams`, `sizeOf`, `cropFor`, `renderBase`, marks, HUD layer); the numbers panel computed in Go.
3. htmx flows for pick, notes, stage controls, navigation, Retry. daisyUI components where they fit (btn, kbd, badge, collapse/details, table, textarea, alert); Tailwind utilities for layout; custom CSS only for the stage (iframe scaling `--s`, crops, marks, CVD filter).
4. Handler/render tests: each demo and gate step renders 200 and contains its question, its options and the right endpoint URLs; a pick round trip writes `picks.json` with the old key format (`p2-3a1-gate:unload` = `B`).

### Task 3: client, phone, screenshots

1. `static/warroom.js` (plain ES module, no build): flip A to D and `1`-`4`, side by side `W`, `Enter` pick, arrows/`[`/`]`/`Backspace` step nav, `N`/`P` items and states, `L` large view and the phone zoom/pan, `Space` audio/video, `?` legend, control keys, swipe, ResizeObserver scaling of live renders, View sheet `keepStage`, Copy summary. Keep the prototype's key map and its resolved clashes.
2. Phone layout below 900 px or coarse pointer: the two-row button bar, View sheet, tap-to-zoom, Whole screen, folded panels as in the README.
3. `shot=1` mode and `tools/shoot.sh` (same contract, URL instead of hash, `WR_URL` default `http://127.0.0.1:8780`).

### Task 4: fly, docs, removal (coordinator)

1. `fly/`: multi-stage Dockerfile (Go build, static binary, small runtime image), `fly.toml` (same app `wargrid-lab-test`, volume `decision_picks` at `/data`, `WARROOM_PICKS=/data/picks.json`, port 8780 inside), `sync.sh` ported (site copy of the non-demo rounds and the tracked `docs/`/`game/` files they name). Build and run it with `container build` / `container run`, curl `/health` and a page. No fly command.
2. `warroom/README.md` (the prototype README, updated), the codebase guide chapter that mentions tooling (`docs/guide/13-testing-and-tooling.md` if it covers the decision page; grep), references to `tools/decision_page` in tracked docs updated, `docs/images/hud-v5/source/README.md` pointer.
3. Keep `tools/decision_page/` running in parallel (user, 2026-11-19, revised); its README points at War Room. Removal is a later owner call.
4. Checks: `go test -race ./...`, `golangci-lint run`, `check_generated.sh`, `sh tools/run_python_checks.sh`, `sh tools/run_shell_checks.sh`, `sh tools/check_public.sh`.

### Reviews

One batch of offscreen screenshots (headless Firefox via `shoot.sh`: desktop 1600x1000 and phone 390x844, every demo step and the gate steps, side by side and one at a time) against the prototype's own screenshots of the same steps. Then the player-experience reviewer and one fresh Opus correctness/security reviewer on the diff; fix rounds; `/ponytail-review` last.

## Don't touch

`~/projects/wargrid` (main tree, night run), ports 8767 to 8772, fly (no deploy, no volume), EA assets, pushing.
