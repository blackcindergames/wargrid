# War Room follow-ups after the tune spike

Owner answers (user, 2026-11-20): perform all suggested changes; the learning goal is Go and htmx, so chi and Tailwind/daisyUI go (stdlib `ServeMux`, one hand-written `app.css`); keep the Svelte island for now (owner checks its size); browser tests in Go with playwright-go; a link without a write token is read-only; War Room serves future packages (P2.3b, P3, P2.4, P2.5, P2.6), not historic rounds; the Python prototype `tools/decision_page/` is deleted at the end (git keeps it at `8e4bb7b`/`0be1d865`); a deploy (later, with approval) replaces the prototype on `wargrid-lab-test`; CI job later.

Sessions (user, 2026-11-20: split into several sessions with a handoff between them; the handoff file is `warroom-prompt.txt`, private, rewritten at each stop):

| Session | Tasks | Ends when | Handoff names |
|---|---|---|---|
| 1 (2026-11-19/20) | port, tune spike, 0, A, B | B committed | branch tip, open findings, next session's first command |
| 2 | C, D | D committed: features the next packages need, each guarded by a browser test | test list with the change that turns each red |
| 3 | G, E | quality gate green locally and in a pushed-branch CI run only if the owner approves the push; prototype deleted; reviews and fix round done | review findings left open, CI status |
| 4 | F, owner look | docs point at War Room; owner's questionnaire on the set-aside features answered; branch ready to merge | merge steps (squash, tag tip, AGENTS.md) |
| 5 | Godot lab step: 15-minute checks, brainstorm, spec | spec approved | spec path, check results |
| 6+ | lab step implementation | per its plan | per its plan |

Each session starts by reading `warroom-prompt.txt`, this plan and `warroom/README.md`, and runs `sh warroom/tools/check_generated.sh` plus `go test ./...` in `warroom/` before new work. A session stops at its row even if time is left.

Run order: strictly after `2026-11-20-warroom-tune-spike.md` is done: Task 0, A, B, C, D, G, E, F, one task at a time (all touch the same files). Each task ends green: in `warroom/` `go test -race ./...`, `go vet ./...`, `golangci-lint run`, `sh tools/check_generated.sh`, `node --check static/warroom.js`. Ports 8767-8772 off limits. Never commit, push or run fly (the coordinator commits on approval).

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
2. Write tokens: `WARROOM_SECRET` (env; when unset, writes are open and the log says so once, for local use). Token = base64url HMAC-SHA256 over the round id, truncated to 16 bytes; link `?t=<token>` on `/r/{round}...`; pages carry it in every link and form (like control params). Pick/note POSTs without a valid token for that round: 403 and the page shows "Read only: this link cannot record." Pages without a token render read-only (no pick/note controls, a quiet notice). `GET /picks.json` needs `?t=` of an admin token (HMAC over `"admin"`). `go run . token <round>|admin` prints a token. Constant-time compare. Tokens never expire; changing `WARROOM_SECRET` revokes all (user, 2026-11-20). Logging with `log/slog` (text handler), config from env only. Tests.
3. Pick history: append-only `picks.jsonl` (one JSON line per write: `{t, key, pick, note, value?}`, RFC 3339 UTC) next to `picks.json`; `picks.json` stays the current-state file (same format, written as today). Append with `O_APPEND` + fsync under the existing mutex, before the state write. Summary shows "changed N times" per row when N > 1 (no history UI beyond that). `GET /history.jsonl` with the admin token. Key cap unchanged; history file size cap 5 MiB (507 past it). Tests.
4. JSON Schema for round YAML generated from the Go types (`github.com/invopop/jsonschema`, a version at least two weeks old) by `go run . schema > rounds/round.schema.json` in `go generate`; each round/step YAML gets the yaml-language-server modeline `# yaml-language-server: $schema=../round.schema.json`; `check_generated.sh` covers it. Strict decode stays the authority.
5. Dev loop: `tools/dev.sh` runs `go tool templ generate --watch --proxy=http://127.0.0.1:8780 --cmd="go run ."` (verify flags against templ v0.3.1100's `--help`); rounds already reload per request. README.

## Task B: plain CSS (UI; Opus builder)

Read first: `docs/art-direction/ART_DIRECTION.md` (§12 interface mock-ups: the game's font, the instrument-panel look), `game/scripts/presentation/palette.gd`, the prototype's `tools/decision_page/app.css`. Replace Tailwind + daisyUI with one hand-written `static/app.css`: cascade layers (`reset, tokens, base, components, stage, phone`), custom properties as design tokens taken from the game's palette and type, native nesting, `:has()`/container queries where they simplify. Quiet neutral dark chrome so nothing competes with the art being judged. Style the Svelte island (`shadow: 'none'`) with the same tokens. Remove `tools/fetch.sh`, `static/input.css`, the Tailwind/daisyUI pins, the go:generate tailwind line and its part of `check_generated.sh`; drop daisyUI/Tailwind classes from the templ files in favour of a small set of own classes. Screenshot parity against the current War Room screenshots (desktop 1600x1000, phone 390x844): same layout, phone stage top within 5 px; then the player-experience reviewer.

## Task C: gaps the next packages need

1. Options A to H: `A` to `D` stay letters, `1` to `8` pick any option, so E to H are digits `5` to `8` only; `G`, `H`, `F` keep their control meaning (user, 2026-11-20). Legend, phone bar and README key table updated. Side-by-side grid wraps beyond 4.
2. Round intro: `intro` field on the round (judging conditions, what neutral answers ship as), shown above step 1 and in the summary.
3. Measurement tables: a render page may post `{type: 'wr:measure', rows: [[label, value, ok?]]}` to its parent (same origin, checked); War Room shows them under the stage per option. Wire one demo (`static/demo/scene.html` reports unit count and outline px).
4. A page-script error banner (`window` `error` and `unhandledrejection`).
5. A visible Large button on desktop.
6. README: `V`, `X`, `⇧F` work only as a step's own `extra` controls.

8. Caps that would stop all recording (architecture check, 2026-11-20): when `picks.jsonl` reaches its cap, rename it aside (`picks-<UTC timestamp>.jsonl`) and start a new file instead of refusing writes, and raise the cap to 64 MiB; `maxKeys` counts per round prefix (500 per round) instead of over all rounds. Tests.
9. Picks record the picked option's name: optional `name` on the store entry, set by the pick handler for option letters, so a later edit of a step's options cannot silently change what an old "B" meant. Old entries stay valid.
10. In container mode (`WARROOM_RUN_AS` set) refuse to start without `WARROOM_SECRET`, so a deploy can never go out fully open.
7. Minify the island bundle (`build.minify` in `islands/vite.config.js`; it ships unminified at about 219 KB).

## Task D: browser tests (playwright-go)

`github.com/playwright-community/playwright-go` (a version at least two weeks old), tests behind build tag `browser` (`go test -tags browser ./...`), Firefox only, the server started in-process with `httptest` on a temp picks file. Install step documented (`go run github.com/playwright-community/playwright-go/cmd/playwright install firefox`). Cases: a flip keeps every iframe document; a stage control reloads the frame with the new hash; pick round trip writes `picks.json` and moves on; a failed pick shows Retry and Retry records the failed letter; a note survives leaving the step after a failure; the phone View sheet opens; tune slider redraws without reload and records `value`; read-only link has no pick controls. Each test is proven by breaking the code it guards once (report which change made it red).

## Task G: quality gate and CI (after D, before E)

Owner (user, 2026-11-20): strict, low-friction quality checks for War Room, also in GitHub Actions; proportional to the code (one Svelte component, one page script), not the full JS tool list: Knip, Vitest and import-x are added when the JS grows; Playwright stays in Go (Task D). Supersedes "CI job later".
- Go: keep `golangci-lint` (strict config), `go vet`, `go test -race`, `tools/check_generated.sh`; add `govulncheck` (`golang.org/x/vuln/cmd/govulncheck` as a Go tool dependency, a version at least two weeks old).
- Island: TypeScript with `strict: true` plus `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`; `Tune.svelte` uses `lang="ts"`; `svelte-check` with zero errors and warnings.
- Page script: `internal/web/static/warroom.js` stays plain JS without a build, type-checked in place by `tsc --checkJs` (JSDoc types where inference fails; `// @ts-check` header).
- ESLint flat config: `typescript-eslint` strict-type-checked (type-aware) for the island and `warroom.js`, `eslint-plugin-svelte` recommended including its a11y rules; no stylistic rules (Prettier owns formatting, `eslint-config-prettier`); `--max-warnings 0`; a lint suppression needs a reason (`eslint-comments` or the core `reportUnusedDisableDirectives`).
- Prettier with `prettier-plugin-svelte` for `islands/` and `warroom.js`.
- Tweakpane lifecycle: the pane is disposed and listeners removed on element disconnect (already the `$effect` cleanup; a check in Task D's browser tests: connect/disconnect twice leaves no orphan pane).
- npm scripts in `islands/package.json`: `format`, `format:check`, `lint`, `lint:fix`, `check` (tsc + svelte-check), `build`, `quality` (format:check, lint, check, build). One repo entry `warroom/tools/quality.sh` runs the Go and npm gates in order and is what agents run before reporting done.
- GitHub Actions `.github/workflows/warroom.yml`, triggered on pull requests and pushes touching `warroom/**` or the workflow: job `quality` (setup-go from `warroom/go.mod`, setup-node with the pinned Node version in `islands/.nvmrc` or `package.json` `engines`, `npm ci`, `sh tools/quality.sh` without browser tests), job `browser` (needs `quality`; playwright-go Firefox install, `go test -tags browser ./...`). Actions pinned by commit SHA as the repo's other workflows do (check `ci.yml`). Do not change the other workflows.
- `warroom/AGENTS.md` (short, agent-facing): inspect conventions first; run the relevant check after each change and `sh tools/quality.sh` before reporting done; fix causes, never suppress or loosen a rule to pass; add or update tests for changed behaviour; no unrelated refactors or new dependencies without a reason. Link it from the root `AGENTS.md` in one line.
- Fix existing violations without behaviour change; list any justified exception in `warroom/AGENTS.md`.

## Task E: remove the prototype, docs, reviews

Delete `tools/decision_page/` and its references (`tools/pyproject.toml` mypy path, `tools/run_python_checks.sh` if it lists it, `docs/images/hud-v5/source/README.md` pointer, `shoot.sh` mentions); `sh tools/run_python_checks.sh`, `sh tools/run_shell_checks.sh`, `sh tools/check_public.sh` exit 0. README brought current (routes, tokens, history, schema, dev loop, CSS layers, key map, learning notes on ServeMux patterns). Then one Opus correctness/security reviewer on the whole batch, the player-experience reviewer on the UI parts, one fix round, a lean pass.

## Task F: workflow docs point at War Room (after E)

Owner (user, 2026-11-20): art labs and decision rounds go through War Room from now on; the workflow docs say so. Grep first (`rg -n -i 'a/b|picks.json|server.py|decision page|click-to-record|round[0-9]+\.html|lab' AGENTS.md docs/kickoff.md docs/wrapup.md docs/night-run.md docs/milestone-prompt.md docs/packages.md docs/development.md docs/art-direction docs/reference/art-godot-integration.md docs/guide`), then short edits, linking `warroom/README.md` rather than repeating it:
- `AGENTS.md`: the art-work and UI bullets name War Room as the place for owner decision rounds (rounds as YAML in `warroom/rounds/`, picks read back from `picks.json`/`/picks.json` with the admin token); the old per-round A/B pages are history. "A/B" is only the name: a step offers as many options as the question needs (up to A to H), not always two (user, 2026-11-20); say so where the docs say A/B.
- `docs/kickoff.md`: "Open for you" lists unanswered War Room rounds (from `picks.json` via the summary logic or a `go run . open` style command if one is cheap; otherwise a manual check line).
- `docs/wrapup.md`: picks recorded today are read back from War Room and their decisions written into the design answers; finished rounds noted in the session notes.
- `docs/night-run.md` and `docs/milestone-prompt.md`: a night or milestone run that ends at an owner look prepares a War Room round instead of a loose page.
- `docs/packages.md`: one rider on the art packages (P2.3b, P3, P2.4, P2.5, P2.6): owner looks run as War Room rounds; P2.4/P2.6 motion looks through the lab step once it exists. Do not rename packages (`python3 tools/roadmap.py` must stay consistent).
- `docs/development.md`: War Room in the commands and Start here list; the codebase guide's tooling chapter gets a short War Room section with its `Checked against` footer.
- Session notes are private (`~/projects/wargrid-private/docs/session-notes.md`): the coordinator adds the War Room line there, not in this repo.
These files are also edited on `main` by other runs; keep each edit to a few lines so the merge stays small. Checks: links and paths resolve, `python3 tools/roadmap.py` leaves the README consistent, `sh tools/check_public.sh` exit 0. A fresh Opus review of the docs' code claims before the commit.

## Not in this batch

Godot lab step (next, before P2.4), CI job, fly deploy, audio features.

Godot lab step, owner answers (user, 2026-11-20), for its own brainstorm and spec after this batch: the game's web build in one persistent iframe (survives htmx step changes), driven over `postMessage`; options compared by flip only (A to H swap the variant live in one instance); the game forwards keys it does not use to War Room; on a phone, short muted clips recorded from the game by default plus a "Start the game anyway" button. The lab uses a single-threaded web preset (all presets have `variant/thread_support=false` today, `game/export_presets.cfg`); the threaded preset of SB5b is not needed for a lab scene (user, 2026-11-20). Settled without a spike (2026-11-20): the lab iframe lives in a fixed layout slot outside the htmx swap region `#page`, so it survives step changes in every browser (htmx 4's `hx-preserve` moves elements with `Element.moveBefore` where the browser has it and falls back to `insertBefore`, which reloads an iframe). Variants map onto the in-game lab's look sets (`game/scripts/lab/lab_look.gd`: palette token sets `SET_A`/`SET_B`, owner colours, bar rules, value sizes) via `{type: 'wr:params', variant, params}`; shape sets join as a look set when P2.4's design defines them. Decided (user, 2026-11-20, revised after the hosting research): War Room reverse-proxies `/lab/` to the game's deployed web build (`WARROOM_GAME_URL`, default the test app `wargrid-web-test.fly.dev`; `/game/` is taken by repo files), so the build keeps its own deploy but the browser sees one origin: today's same-origin `postMessage` checks stay, War Room reads the lab's keys directly, no storage partitioning. Cost: about 20 MB per cold load through War Room's machine. The game shows its `build_commit.txt` in a `wr:ready` message. Before the spec, the 15-minute checks: `addEventListener("message")` through `JavaScriptBridge`, and the proxy streaming wasm with `application/wasm` and brotli. Every `wr:*` message carries the step id, since the persistent lab iframe outlives step changes.
