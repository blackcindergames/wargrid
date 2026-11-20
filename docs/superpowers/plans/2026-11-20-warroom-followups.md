# War Room follow-ups after the tune spike

Owner answers (user, 2026-11-20): perform all suggested changes; the learning goal is Go and htmx, so chi and Tailwind/daisyUI go (stdlib `ServeMux`, one hand-written `app.css`); keep the Svelte island for now (owner checks its size); browser tests in Go with playwright-go; a link without a write token is read-only; War Room serves future packages (P2.3b, P3, P2.4, P2.5, P2.6), not historic rounds; the Python prototype `tools/decision_page/` is deleted at the end (git keeps it at `8e4bb7b`/`0be1d865`); a deploy (later, with approval) replaces the prototype on `wargrid-lab-test`; CI job later.

Run order: strictly after `2026-11-20-warroom-tune-spike.md` is done, Task 0 then A to E, one task at a time (all touch the same files). Each task ends green: in `warroom/` `go test -race ./...`, `go vet ./...`, `golangci-lint run`, `sh tools/check_generated.sh`, `node --check static/warroom.js`. Ports 8767-8772 off limits. Never commit, push or run fly (the coordinator commits on approval).

## Task 0: packages, shutdown, container (first, before A)

Owner (user, 2026-11-20): the flat `package main` is hard to read; graceful shutdown like the relay; final image scratch or distroless, no su-exec.

1. Packages (idiomatic layout, `main.go` stays at the module root so `go run .` works and only wires things):
   - `internal/store`: picks file (and later history).
   - `internal/rounds`: YAML types, loading, validation, controls specs.
   - `internal/stage`: render-hash building, crops, sizes, marks, numbers (contrast/CIE76).
   - `internal/web`: server, routes, handlers, query parsing, view models, templ views (`internal/web/views` if templ components want their own package), static embed (`internal/web/static`).
   Exported API only where another package needs it; tests move with their code (package-internal tests stay `package x`). Keep render output byte-identical: capture `curl` output of the pages listed below before the move and diff after (`/r/demo/1`, `/r/demo/1?view=side`, `/r/demo-controls/1?ground=dark&world=one`, `/r/p2-3a1-gate-1/1`, `/r/p2-3a1-gate-2/1`, `/r/demo/7`, `/r/p2-3a1-gate-1/summary`, the tune step, `/`). Update `go:generate` lines, `check_generated.sh`, `fly/sync.sh` (it copies Go sources), README.
2. Shutdown and signals, with `relay/main.go` (around lines 240-300) as the template: `signal.NotifyContext` for SIGINT/SIGTERM, `srv.Shutdown` with a drain timeout, a second signal exits at once, the store's pending write finishes (mutex) before exit, exit code non-zero on a serve error. A test that sends a request, triggers shutdown and checks the in-flight request completes.
3. Container: final stage `gcr.io/distroless/static-debian12` pinned by digest (as `relay/Dockerfile`), no alpine, no shell, no su-exec. Volume ownership: first fetch Fly's docs on volumes (fly.io/docs) and check whether a mount can be owned by a chosen uid; if yes use it with the `:nonroot` image; if not, the binary starts as root, `chown`s the picks directory, then drops to 65534 with `syscall.Setgid`/`Setuid` (Linux only, build-tagged; a no-op elsewhere) before serving, and the image is the root `static-debian12` variant. Quote the doc line you based the choice on in the report. Rebuild and run with Apple `container` (port 8783+): `/health`, a page, a pick into a mounted temp dir, `/picks.json`; check the process runs as 65534 (`/proc/1/status` via the binary is not possible without a shell: log the effective uid at startup instead).

## Task A: stdlib router, write tokens, pick history, schema, dev loop (Go)

1. Replace chi with `net/http.ServeMux` (Go 1.22+ patterns: `GET /r/{round}/{n}`, `POST /r/{round}/{step}/pick`, `r.PathValue`). Recoverer and request log as two small middleware funcs. Drop chi from `go.mod`.
2. Write tokens: `WARROOM_SECRET` (env; when unset, writes are open and the log says so once, for local use). Token = base64url HMAC-SHA256 over the round id, truncated to 16 bytes; link `?t=<token>` on `/r/{round}...`; pages carry it in every link and form (like control params). Pick/note POSTs without a valid token for that round: 403 and the page shows "Read only: this link cannot record." Pages without a token render read-only (no pick/note controls, a quiet notice). `GET /picks.json` needs `?t=` of an admin token (HMAC over `"admin"`). `go run . token <round>|admin` prints a token. Constant-time compare. Tests.
3. Pick history: append-only `picks.jsonl` (one JSON line per write: `{t, key, pick, note, value?}`, RFC 3339 UTC) next to `picks.json`; `picks.json` stays the current-state file (same format, written as today). Append with `O_APPEND` + fsync under the existing mutex, before the state write. Summary shows "changed N times" per row when N > 1 (no history UI beyond that). `GET /history.jsonl` with the admin token. Key cap unchanged; history file size cap 5 MiB (507 past it). Tests.
4. JSON Schema for round YAML generated from the Go types (`github.com/invopop/jsonschema`, a version at least two weeks old) by `go run . schema > rounds/round.schema.json` in `go generate`; each round/step YAML gets the yaml-language-server modeline `# yaml-language-server: $schema=../round.schema.json`; `check_generated.sh` covers it. Strict decode stays the authority.
5. Dev loop: `tools/dev.sh` runs `go tool templ generate --watch --proxy=http://127.0.0.1:8780 --cmd="go run ."` (verify flags against templ v0.3.1100's `--help`); rounds already reload per request. README.

## Task B: plain CSS (UI; Opus builder)

Read first: `docs/art-direction/ART_DIRECTION.md` (§12 interface mock-ups: the game's font, the instrument-panel look), `game/scripts/presentation/palette.gd`, the prototype's `tools/decision_page/app.css`. Replace Tailwind + daisyUI with one hand-written `static/app.css`: cascade layers (`reset, tokens, base, components, stage, phone`), custom properties as design tokens taken from the game's palette and type, native nesting, `:has()`/container queries where they simplify. Quiet neutral dark chrome so nothing competes with the art being judged. Style the Svelte island (`shadow: 'none'`) with the same tokens. Remove `tools/fetch.sh`, `static/input.css`, the Tailwind/daisyUI pins, the go:generate tailwind line and its part of `check_generated.sh`; drop daisyUI/Tailwind classes from the templ files in favour of a small set of own classes. Screenshot parity against the current War Room screenshots (desktop 1600x1000, phone 390x844): same layout, phone stage top within 5 px; then the player-experience reviewer.

## Task C: gaps the next packages need

1. Options A to H (keys `E` to `H` and `5` to `8`; resolve clashes with the key map: `G`, `H` are ground and HUD today, so move ground/HUD/world to free keys and update the legend, phone bar and README key table; propose the new map in the report). Side-by-side grid wraps beyond 4.
2. Round intro: `intro` field on the round (judging conditions, what neutral answers ship as), shown above step 1 and in the summary.
3. Measurement tables: a render page may post `{type: 'wr:measure', rows: [[label, value, ok?]]}` to its parent (same origin, checked); War Room shows them under the stage per option. Wire one demo (`static/demo/scene.html` reports unit count and outline px).
4. A page-script error banner (`window` `error` and `unhandledrejection`).
5. A visible Large button on desktop.
6. README: `V`, `X`, `⇧F` work only as a step's own `extra` controls.

## Task D: browser tests (playwright-go)

`github.com/playwright-community/playwright-go` (a version at least two weeks old), tests behind build tag `browser` (`go test -tags browser ./...`), Firefox only, the server started in-process with `httptest` on a temp picks file. Install step documented (`go run github.com/playwright-community/playwright-go/cmd/playwright install firefox`). Cases: a flip keeps every iframe document; a stage control reloads the frame with the new hash; pick round trip writes `picks.json` and moves on; a failed pick shows Retry and Retry records the failed letter; a note survives leaving the step after a failure; the phone View sheet opens; tune slider redraws without reload and records `value`; read-only link has no pick controls. Each test is proven by breaking the code it guards once (report which change made it red).

## Task E: remove the prototype, docs, reviews

Delete `tools/decision_page/` and its references (`tools/pyproject.toml` mypy path, `tools/run_python_checks.sh` if it lists it, `docs/images/hud-v5/source/README.md` pointer, `shoot.sh` mentions); `sh tools/run_python_checks.sh`, `sh tools/run_shell_checks.sh`, `sh tools/check_public.sh` exit 0. README brought current (routes, tokens, history, schema, dev loop, CSS layers, key map, learning notes on ServeMux patterns). Then one Opus correctness/security reviewer on the whole batch, the player-experience reviewer on the UI parts, one fix round, a lean pass.

## Not in this batch

Godot lab step (next, before P2.4), CI job, fly deploy, audio features.
