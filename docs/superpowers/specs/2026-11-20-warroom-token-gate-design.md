# War Room token gate: design

Status: approved by the owner 2026-11-20. Code facts from `main` `9df1387f`.

## Why

War Room runs on fly at its own public domain. Today anyone with the address can read every round, question and picture; only writes and the read-back routes need a token (`warroom/internal/web/token.go`, `handlers.go`). Only the owner and friends the owner picks later may see War Room (user, 2026-11-20).

## Goals

- Every route except `GET /health` needs a valid token, from the query `t` or from the cookie.
- A request with a valid query token sets the cookie, so later page loads, static files, iframes and htmx requests pass without the query.
- Per-friend view tokens, scope `viewer:<name>`, printed by `go run . token viewer:<name>`.
- A viewer sees what a token-less reader sees today: rounds, questions and pictures, no picks or notes, cannot record (user, 2026-11-20).
- Revoking one friend: remove the name from `WARROOM_VIEWERS` (a fly secret, so names never reach the public repo); that friend's link and cookie stop working on the restart (user, 2026-11-20).
- No valid token or cookie: 403, plain text "War Room needs your invite link; open it again." (user, 2026-11-20).
- Same branch: delete the stale rounds `p2-3a1-gate-1` and `p2-3a1-gate-2` (user, 2026-11-20; their answers live in [design answers](../../reference/design-answers-2026-11-08.md#p23a1-gate-a-user-2026-11-19)).

## Non-goals

- No change to what writes, answer views and `/picks.json` / `/history.jsonl` need: the round or admin token in the query, as today. The cookie only opens the gate.
- No login form, no writer identity, no expiry on tokens.
- Without `WARROOM_SECRET` (local use) nothing is gated, as today; container mode already refuses to start without a 32-byte secret.

## Approaches

- **A. One gate around all routes (picked, user 2026-11-20).** A handler outside `CrossOriginProtection` accepts the query `t` or the `wr` cookie when it equals the admin token, the token of any round in the catalog, or `viewer:<name>` for a name in `WARROOM_VIEWERS`. A few HMACs per request; revocation falls out of the allow-list.
- B. A separate signed session cookie per scope: a second token kind for nothing A lacks.
- C. A password login form: not asked for, and breaks sharing a link.

## Design

- `web.Config` gains `Viewers []string`, read from `WARROOM_VIEWERS` (comma-separated, blanks dropped).
- `Routes()` wraps the mux in the gate; `/health` passes untouched (fly's check). With an empty secret the gate passes everything.
- Cookie `wr`: value = the valid query token just presented, `HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=7776000` (90 days). Lax suffices because the cookie grants no write. One cookie; the last valid token wins.
- The gate checks the query first, then the cookie; an invalid query token with a valid cookie still passes (the cookie is checked on its own) and does not overwrite the cookie.
- `printToken` accepts `viewer:<name>`; a name outside `[a-z0-9-]`, empty, or longer than 32 characters is an error. It does not check the allow-list (the CLI has no fly secrets).
- The request log already drops the query; it never logs the cookie.
- Stale rounds: copy today's `warroom/rounds/` (both gate rounds, both demos, `index.yaml`) to `warroom/testdata/rounds/`, point the tests that load the gate rounds there, then delete the two gate folders and their `index.yaml` entries; README examples move to `demo`.

## Tests

- Go, per route class (round list, round redirect, step, summary, pick POST, note POST, `/static`, a site tree, `/picks.json`): no token → 403 gate text; valid query token of each kind → passes and sets the cookie; cookie only → passes; viewer not in the list (query or cookie) → 403; `/health` without anything → 200; no secret → everything open, no cookie set.
- Viewer token on a step page → read-only view; on a POST → 403 as today.
- Browser test (`-tags browser`): open a step with a round token, then an htmx request and a static file load without `t` succeed by the cookie (proves `Secure` is kept on `http://127.0.0.1` by the test browser).

## Left to the builder

Function names and where the gate lives (`token.go` fits); fixture paths in each test.

## Agent's calls

- 90-day cookie, `SameSite=Lax`, one cookie holding the last valid token.
- Admin token: opens the gate and reads back, as today; no write.
- Viewer name charset and length.
- Fixture copy under `warroom/testdata/rounds/`.
