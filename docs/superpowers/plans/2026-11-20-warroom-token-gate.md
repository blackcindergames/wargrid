# War Room token gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every War Room route except `GET /health` needs a valid token from the query or the `wr` cookie; friends get `viewer:<name>` tokens; the stale gate rounds go.

**Architecture:** One handler in `internal/web/token.go` wraps the whole mux (outside `CrossOriginProtection`). It admits the admin token, any served round's token, or a viewer token for a name in `Config.Viewers`; a valid query token sets the cookie. Write, answer-view and read-back checks stay as they are (query token only).

**Tech Stack:** Go stdlib `net/http`, existing HMAC tokens, playwright-go browser tests.

**Spec:** `docs/superpowers/specs/2026-11-20-warroom-token-gate-design.md`

## Global Constraints

- Branch `warroom-token-gate` from `main`. No commits, push or fly deploy without the owner's approval; subagents never commit.
- Cookie: name `wr`, `HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=7776000`. Value: the valid query token just presented.
- Refused request: status 403, body exactly `War Room needs your invite link; open it again.` via `plain()`.
- Viewer scope `viewer:<name>`, name matches `^[a-z0-9-]{1,32}$`.
- Empty `Secret`: the gate passes everything and sets no cookie.
- Names of friends never go into tracked files (public repo); tests use `friend`.
- Gate: `sh warroom/tools/quality.sh` green. While `warroom/fly/site/` exists, move it to the scratchpad for the run and back after (known `check_generated` bug, fixed on branch `warroom-check-generated`, not merged).
- Don't touch `~/projects/wargrid-wt-tooling` or `~/projects/wargrid-wt-checkgen`.
- `$SCRATCH` is the session scratchpad; test logs go there, judge by exit code, read only failing lines.

## Review Focus

- Unknown path without a token (`/nope`) answers the gate's 403, not 404, so paths don't leak. Test in Task 2.
- `/health` is exempt only as the exact path: `/health/x` without a token is 403. Test in Task 2.
- `WARROOM_VIEWERS=" friend , ,bob"` reads as `[friend bob]`; a name failing the pattern stops `run()` with an error instead of silently locking that friend out. Tests in Task 2.
- Cookie `wr=` (empty) or `wr=garbage` without a query token is 403. Test in Task 2.
- Valid cookie with an invalid `?t=`: passes, no `Set-Cookie`; valid cookie with a different valid `?t=`: passes, cookie replaced. Test in Task 2.

---

### Task 1: Move the gate rounds into test fixtures and delete them

**Files:**
- Create: `warroom/testdata/rounds/` (copy of `warroom/rounds/index.yaml`, `demo/`, `demo-controls/`, `p2-3a1-gate-1/`, `p2-3a1-gate-2/`; not the `*.schema.json` files)
- Delete: `warroom/rounds/p2-3a1-gate-1/`, `warroom/rounds/p2-3a1-gate-2/`, their two entries in `warroom/rounds/index.yaml`
- Modify: `warroom/main_test.go:182-197`, `warroom/internal/rounds/rounds_test.go:45-110`, `warroom/internal/web/views_test.go:20,54,241`, `warroom/README.md:61` (example round becomes `demo`)

**Interfaces:**
- Produces: `newShippedApp` in `views_test.go` loads `../../testdata/rounds` (name kept); Task 2 relies on it still serving `p2-3a1-gate-1`.

- [ ] **Step 1:** `cp -R` the five entries; if `index.yaml` or a step file has a `yaml-language-server` schema comment pointing at `../round.schema.json`, leave it (editors only).
- [ ] **Step 2:** Point every test that names `p2-3a1-gate-1` or `p2-3a1-gate-2` at the copy: `main_test.go` `TestOpenCommandListsRoundsWithUnansweredSteps` uses `testdata/rounds`; in `rounds_test.go` `TestShippedRoundsKeepTheirKeyPrefixes`, the `forecast`/`look`/`Earlier` test at :69 and `TestIndexFlagsDemoRounds` use `../../testdata/rounds`; `views_test.go` `newShippedApp` and the `LoadCatalog` calls at :54 and :241 use `../../testdata/rounds`. `TestShippedRoundsLoadClean` stays on `../../rounds`.
- [ ] **Step 3:** Run `cd warroom && go test ./... > $SCRATCH/t1a.log 2>&1; echo "exit=$?"`. Expected: exit 0 (fixtures equal the shipped set).
- [ ] **Step 4:** Delete the two gate folders and their `index.yaml` entries. Change `TestShippedRoundsLoadClean` to want 2 and 2.
- [ ] **Step 5:** Run `go test ./...` again. Expected: exit 0. Then `rg -n 'p2-3a1-gate-[12]' warroom --glob '!testdata/**'` lists only `rounds_test.go`/`main_test.go`/web tests that now read `testdata` (no hit in `warroom/rounds/` or README).

### Task 2: The gate, viewer tokens and the CLI

**Files:**
- Modify: `warroom/internal/web/token.go`, `warroom/internal/web/handlers.go:36-41` (`Config.Viewers`), `:71` (wrap), `warroom/main.go:41-59,85-95,150-160`
- Modify tests: `warroom/internal/web/handlers_test.go:30-83` (`testApp.cookie`), `warroom/internal/web/access_test.go:20-25` (`locked()`), `warroom/main_test.go`
- Docs: `warroom/README.md` (env table, Tokens, Fly section), `docs/guide/13-testing-and-tooling.md:181` and its `Checked against` footer (War Room section), the spec's Status line

**Interfaces:**
- Produces (package `web`):
  - `Config.Viewers []string`
  - `func ViewerScope(name string) string` → `"viewer:" + name`
  - `func ValidViewer(name string) bool` (the name pattern)
  - `func (s *Server) gate(next http.Handler) http.Handler`
  - consts `cookieName = "wr"`, `cookieMaxAge = 90 * 24 * 60 * 60`, `gateText = "War Room needs your invite link; open it again."`
- Produces (tests): `testApp.cookie string`, sent as `wr=<cookie>` by `testApp.do` when non-empty; `locked()` sets `Secret = testSecret`, `Viewers = []string{"friend"}`, `cookie = viewerToken`; `var viewerToken = Token(testSecret, ViewerScope("friend"))`.

- [ ] **Step 1: Failing tests** in `access_test.go`:
  - `TestGateRefusesEveryRouteWithoutAToken`: `a := newApp(t).locked(); a.cookie = ""`; for GET `/`, `/r/r`, `/r/r/1`, `/r/r/summary`, `/static/app.css`, `/picks.json`, `/history.jsonl`, `/nope`, `/health/x` and POST `/r/r/pic/pick`, `/r/r/pic/note`: status 403, body == `gateText`, no `Set-Cookie`. GET `/health` → 200 `ok`.
  - `TestGateAdmitsEachTokenKindAndSetsTheCookie`: tokens admin, `roundToken("r")`, `roundToken("d")`, `viewerToken`; GET `/r/r/1?t=<tok>` → 200 and one `Set-Cookie` with `Name=="wr"`, `Value==tok`, `HttpOnly`, `Secure`, `SameSite==http.SameSiteLaxMode`, `Path=="/"`, `MaxAge==7776000`.
  - `TestCookieAloneAdmits`: `a.cookie = tok` for each kind; GET `/r/r/1` and `/static/app.css` → 200, no `Set-Cookie`.
  - `TestGateRefusesViewersNotListed`: `viewer:bob` token as query and as cookie → 403 gate text.
  - `TestGateRefusesBadCookies`: cookie `""` sent as `wr=` and `garbage` → 403.
  - `TestCookieAndQueryTogether`: valid cookie + `?t=wrong` → 200, no `Set-Cookie`; valid viewer cookie + `?t=<roundToken("r")>` → 200, `Set-Cookie` value = round token.
  - `TestViewerIsReadOnly`: with `viewerToken` as query: `/r/r/1` has `id="readonly"` and none of `controlsOfRead`; POST `/r/r/pic/pick?t=<viewerToken>` → 403 `Read only`.
  - `TestOpenServerHasNoGate`: `newApp(t)` (no secret): GET `/r/r/1` 200, no `Set-Cookie`.
  - In `main_test.go`: `TestConfigFromEnv` gains `WARROOM_VIEWERS=" friend , ,bob"` → `Viewers: []string{"friend","bob"}` (unset → nil); `TestTokenCommandPrintsTheTokenTheServerAccepts` gains `viewer:friend` (accepted by a locked server listing `friend`); `TestTokenCommandRefusesBadViewerNames` for `viewer:`, `viewer:Bob`, `viewer:` + 33×`a` → error; `TestRunRefusesBadViewerNames` with `WARROOM_VIEWERS=Bob` → error naming the variable, in the style of `TestContainerModeRefusesAShortSecret`.
- [ ] **Step 2:** `go test ./... > $SCRATCH/t2a.log 2>&1; echo "exit=$?"`. Expected: fails to compile or the new tests fail.
- [ ] **Step 3: Implement.** `gate`: path `== "/health"` or empty secret → next. Query token first: if `s.admits(q)`, `http.SetCookie` then next. Else cookie: if `s.admits(c.Value)` → next. Else `plain(w, 403, gateText)`. `admits(tok string) bool` checks admin, then each `Config.Viewers`, then each key of `rounds.LoadCatalog(s.cfg.Rounds).Rounds` (not `s.catalog()`, which logs load errors on every call) via `tokenOK`; empty `tok` is false. `Routes()` returns `s.gate(http.NewCrossOriginProtection().Handler(mux))`. `configFromEnv` splits `WARROOM_VIEWERS` on `,`, trims, drops blanks. `run()` returns `fmt.Errorf("WARROOM_VIEWERS: %q is not a valid viewer name", n)` for the first invalid name, before the container checks. `printToken` accepts `viewer:<name>` with `ValidViewer`, usage string adds `|viewer:<name>`. Update the `token.go` doc comments for the new scope; `locked()` and `testApp.do` per Interfaces.
- [ ] **Step 4:** `go test -race ./... > $SCRATCH/t2b.log 2>&1; echo "exit=$?"`. Expected: exit 0, including every pre-existing locked test (they now read as the `friend` viewer).
- [ ] **Step 5: Docs.** README: env row `WARROOM_VIEWERS` (comma-separated viewer names; a fly secret, never in `fly.toml`, since the repo is public; removing a name revokes that friend); Tokens: the gate paragraph (every route but `/health` needs any valid token, cookie flags and lifetime, the gate text, viewer = token-less reader of before, `token viewer:<name>` example); the "Reads of answers" and "Unset secret" bullets stay true, re-read them; Fly: `fly secrets set WARROOM_VIEWERS=... -a warroom` line. Guide 13 :181: one sentence on the gate and viewer tokens; footer: War Room section checked against this branch's working tree over its base sha. Spec Status: "approved by the owner 2026-11-20".

### Task 3: Browser test, the cookie carries a page's requests

**Files:**
- Modify: `warroom/internal/web/browser_helper_test.go:90-125` (`newSite`), `warroom/internal/web/browser_test.go` (new test), `warroom/README.md` Browser tests "Covered" list (one clause)

**Interfaces:**
- Consumes: `viewerToken`, `ViewerScope`, `Config.Viewers`, `gateText` from Task 2.

- [ ] **Step 1:** `newSite` passes `Viewers: []string{"friend"}`; when `o.secret != ""`, after the page exists it opens `/?t=` + `viewerToken` so existing locked browser tests start as the viewer.
- [ ] **Step 2: Test** `TestCookieCarriesRequestsWithoutTheQuery`: `newSite(t, siteOpts{secret: testSecret})`; `ClearCookies` on the page's context; open `/r/demo/1?t=` + `viewerToken`; assert in the page: every `img` on the step is `complete` with `naturalWidth > 0`; `fetch('/r/demo/2', {headers: {'HX-Request': 'true'}})` → 200; `document.cookie` has no `wr` (HttpOnly). Then `ClearCookies`; the same fetch → 403 and its text == `gateText`.
- [ ] **Step 3:** Prove it guards: temporarily drop `http.SetCookie` from `gate`, run the test, see it fail at the image or fetch assertion, restore.
- [ ] **Step 4:** `go test -tags browser ./... > $SCRATCH/t3.log 2>&1; echo "exit=$?"` (timeout 600000). Expected: exit 0.

### Task 4: Gate and reviews

- [ ] **Step 1:** Move `warroom/fly/site` to `$SCRATCH/site-aside` if present; `sh warroom/tools/quality.sh > $SCRATCH/q.log 2>&1; echo "exit=$?"`; move it back. Expected: exit 0.
- [ ] **Step 2:** `sh tools/check_public.sh` from the repo root, exit 0 (no friend names, no hostnames beyond the README's existing domain).
- [ ] **Step 3:** One correctness reviewer (Opus high, fresh context, diff + file paths), then the `security-review` skill on the branch, then `/ponytail-review`. Apply fixes, rerun Steps 1 to 2.
- [ ] **Step 4:** Show the owner the summary and a proposed commit message; commit only on approval. Fly deploy (sync, `fly secrets set WARROOM_VIEWERS`, `fly deploy`) is a separate approval.
