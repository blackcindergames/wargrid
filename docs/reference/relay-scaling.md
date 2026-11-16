# Relay scaling reference — 2026-11-04

Status: **PROPOSED**. Design input for [M9](../blueprint.md#m9--3v3-online), placed there by the user 2026-11-04. **User decisions 2026-11-04:** fly.io stays the host for now; the design is cloud-agnostic, using no routing, discovery or placement feature that exists on only one provider. Provider features stay in deploy config (e.g. `fly.toml` autostop) and code must work without them. Nothing else here is approved or implemented. Host docs read 2026-11-04; providers say limits change.

## Provenance

User-supplied proposal `game_backend_rendezvous_architecture_v2.md` ("Multiplayer WebSocket Routing — Rendezvous Hashing + Encoded Match Ownership"), kept outside the repository; zip SHA-256 `853adabdfecde446ac9bd84b5c145f319d3854524b717788bed54f653e15df90`, markdown SHA-256 `9fb092eaa134a1c570ef98923be63144b812aafc9210eae81b1d1b5752d8f958`. It targets server-authoritative matches with accounts; Wargrid's relay is a lockstep forwarder for private matches with friends.

## Assessment (Claude, 2026-11-04; not a user decision)

Keep:

- **Owner encoded in the match code, never re-hashed on join.** The proposal calls this "the essential design choice". Adding or removing machines never moves a live room.
- **Owner machine admits atomically** (seats, full, build). Already true: every join after the create goes through the room's own goroutine (`relay/room.go` `registry.join`, `room.join`); the creator is seated before the room runs and before anyone else knows the code (`registry.create`).
- **Drain before deploy; a new process never reuses a live owner ID.**
- **Trust boundary:** resolve only known owner IDs, never build an internal URL from client text, rate-limit joins and handshakes.

Change or drop:

- **Rendezvous hashing (HRW): drop.** The proposal concedes least-loaded is simpler with one coordinator. HRW ignores latency; lockstep input delay follows the slowest round trip, so place rooms by region (minimise worst player RTT).
- **Short codes stay.** The first code character names the owner's worker slot (32 slots per character), the rest is random, instead of the proposal's UUID-length ID. A separate `bootId` adds little: after a restart the room is gone and the relay answers `unknown match`.
- **Tickets, idempotent create, coordinator-to-worker API: defer.** No accounts exist; the code is the key for private play. Add a per-IP join rate limit. These return with accounts or public matchmaking.
- **Reconnect is mostly a lockstep problem, not routing:** the relay keeps the room's command log, a returning client replays it fast to catch up. Routing a reconnect is trivial once the owner is in the code.
- **Capacity is unmeasured.** M5: about 100 MiB idle, about 128 MiB peak for one match on 256 MB ([M5 verification](m5-verification.md)). Benchmark rooms per machine before any placement policy; until then more machines buy region latency and fault isolation, not CPU.

Keep from the proposal's test list (§10): join reaches the encoded owner after machines change (4), last-seat race (9), reconnect within grace (10), restart rejects old codes (11), drain keeps live rooms reachable (12), expiry/cleanup (15), forged owner IDs contact no arbitrary host (16).

## Routing options

| Option | How | Hosts | Cost |
|---|---|---|---|
| R1 platform replay | Any machine answers the upgrade request with `fly-replay: instance=<owner>` | fly.io only | **Rejected 2026-11-04 (provider-specific)** |
| R2 app redirect | Every worker has its own public hostname; a non-owner answers `hello` with `redirect {url}`, client reconnects | any, browser too | one extra handshake on a wrong-worker join |
| R3 coordinator | Proposal's HTTP coordinator places rooms and returns the owner URL | any | extra service, single point of failure for create/join |

**Recommended (Claude, not decided): R2** with these agnostic parts:

- **Worker = one deployable with its own public URL:** a fly app per worker, a Railway service per worker, or a DNS name per VM. Never rely on routing between replicas of one deployable.
- **Static worker list** (slot, URL, region) in relay config; every worker serves it at `GET /workers`. Adding a worker is a config change plus a deploy; no provider DNS discovery.
- **Placement by the client:** the creator pings every listed worker and creates the room on the lowest RTT. For 3v3 that favours the creator; minimising the worst player RTT needs a lobby step first, an M9 detail.
- **Drain in the relay, not the platform:** mark a worker `draining` in the list; it refuses new rooms and keeps live ones; remove it once empty. Platform kill timeouts (fly 300 s, Railway undocumented) then never decide whether a match survives.
- **Client tolerates cold start:** retry the handshake on 502 or timeout, so idle sleep on any host is safe.

## fly.io (docs read 2026-11-04)

Replay and `.internal` discovery are recorded as evidence only; the agnostic design does not use them.

- Replay: header field `instance` is "The ID of a specific Machine to route to", e.g. `fly-replay: instance=00bb33ff`; "Requests larger than 1MB cannot be replayed" (docs.fly.io/networking/dynamic-request-routing).
- WebSocket: "an application returning `fly-replay` headers should not negotiate a web socket upgrade itself … the application or instance receiving the requests should handle the upgrade" (same page). Implies replayed upgrades; not stated outright.
- Request headers `fly-prefer-instance-id` / `fly-force-instance-id` route to one Machine (same page); browsers cannot set WebSocket headers.
- Discovery: `all.vms.<appname>.internal` TXT is a "comma-separated list of Machine ID and region name for all deployed app Machines"; `vms.<appname>.internal` lists only started Machines (docs.fly.io/networking/private-networking). Use `all.vms` or a suspended owner disappears.
- Deploy: `kill_timeout` "up to a maximum of 300 seconds (5 minutes)", "best-effort" (docs.fly.io/reference/configuration). Matches last up to an hour, so draining means new machines plus retiring old ones when empty, not `fly deploy` alone.
- Regions: `fra` in use; many others.

## Railway (docs read 2026-11-04)

- WebSocket: "Websocket connections are exempt from these duration and inactivity limits, and can stay open indefinitely, even while idle." Cap "10,000 concurrent connections" per service (docs.railway.com/networking/public-networking/specs-and-limits).
- Replicas: traffic goes to the nearest region and is then distributed randomly; "Railway does not support sticky sessions"; no documented way to address one replica (docs.railway.com/reference/scaling). So R1 is impossible and replicas of one service cannot own rooms; R2 or R3 needs **one service per worker**, each with its own domain.
- Discovery: `<service>.railway.internal` "resolves to the internal IP addresses of the service"; env `RAILWAY_REPLICA_ID`, `RAILWAY_REPLICA_REGION` (docs.railway.com/networking/private-networking/how-it-works, /variables/reference).
- Deploy: old deployment gets SIGTERM, "By default, it is given 0 seconds"; `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` sets the SIGTERM-to-SIGKILL buffer, `RAILWAY_DEPLOYMENT_OVERLAP_SECONDS` the overlap (docs.railway.com/reference/deployments). **No maximum documented**; whether an hour-long drain is honoured is unverified.
- Sleep: a service is inactive 5 minutes after it stops sending packets, sleeps within 5–10 minutes; "The first request sent to a slept service may return a 502 Bad Gateway response" (docs.railway.com/reference/app-sleeping). The client would need a retry on wake. An open but silent WebSocket does not keep it awake.
- Regions: one in Europe, Amsterdam (`europe-west4-drams3a`) (docs.railway.com/reference/deployment-regions). fly `fra` is closer to Bavaria.
- Price: Hobby $5/month, includes $5 usage; RAM $10/GB/month, CPU $20/vCPU/month, egress $0.05/GB; Hobby up to 6 replicas per service (docs.railway.com/reference/pricing/plans). fly has no monthly minimum.

## fly.io vs Railway, measured (2026-11-04/05)

Source: [relay stack spike](relay-stack-spike.md), which deployed the same four relay images (Kotlin, Go, Rust, Elixir; 3v3 rooms) on both hosts and ran the same probes and a 180 s, 10-room load from the user's Mac (near Bavaria) through each host's TLS edge. fly: four temporary apps in `fra`, shared-cpu-1x 256 MB, suspend autostop. Railway: user's **trial** account, one project, one service per stack in `europe-west4` (Amsterdam). Everything was deleted afterwards; Railway usage for about 3.5 h of four services plus load was **$0.08** (`railway usage`). One machine per stack and one client location, so treat latency as indicative.

### Deploying

| | fly.io | Railway |
|---|---|---|
| Steps per service | `fly apps create`, then `fly deploy <dir> -c <abs>/fly.toml --dockerfile … --ha=false --remote-only` | `railway add --service s --variables …`, `railway service scale --service s eu-west=1 sfo=0`, `railway up <dir> --path-as-root --service s --ci`, `railway domain --service s --port 8080` |
| Config | `fly.toml` in the repository: VM size, `[http_service]`, autostop, health checks, env | Lives in Railway's project state, set through CLI or dashboard; config-as-code files not tried |
| First deploy (remote build + start) | 47–93 s, includes builder warm-up | Go 64 s, Elixir 97 s, Rust 152 s, Kotlin 183 s |
| Redeploy of an existing image | `fly deploy` again (rebuild) | `railway service redeploy --service s --yes` (no rebuild) |
| Public URL | `<app>.fly.dev`, automatic | `railway domain` generates `<service>-production-xxxx.up.railway.app`; one extra step |
| Upload | Build context = positional dir, `.dockerignore` honoured | Respects `.gitignore`; dirs without one needed a `.railwayignore`, or local `target/`, `_build/` and `build/` would upload |
| Removal | `fly apps destroy <app> --yes`, gone at once | `railway delete --project <id> --yes`: endpoints 404 at once, project soft-deleted with `deletedAt` 48 h later |

Gotchas hit (measured):

- **fly:** relative `-c` fails once a positional dir is given (absolute path needed); without `--ha=false` fly creates two machines and rooms split ([M5 verification](m5-verification.md)); app names cannot be renamed; Prometheus API needs `Authorization: FlyV1 <token>` (Bearer gives 401).
- **Railway:** a new service defaults to region `sfo` (California). `scale eu-west=1` *adds* Amsterdam next to it, and the trial refuses the deploy with "Your plan can only deploy to a single region. Please upgrade to Pro to deploy to multiple regions." Right after `railway add` the region map was not populated yet (`Unknown region sfo`), so three services silently deployed to California until `sfo=0` and a redeploy. Project creation is rate-limited ("1 project per 30 seconds"). `railway init` prints prompt text before its `--json` output, so scripts must not parse it blindly. Whether Hobby (not trial) allows multi-region is unverified.

### Operating

- **Metrics:** fly exposes Prometheus per machine (CPU by mode, `fly_instance_cpu_balance`, `_cpu_baseline`, `_cpu_throttle`, memory), 15 s steps. Railway: `railway metrics --cpu --memory --raw --json`, 30 s points, CPU in vCPU against a `CPU_LIMIT` of **2.0** on the trial; no balance or throttle concept.
- **Logs:** both stream app logs from the CLI (`fly logs`, `railway logs`). fly also logs machine lifecycle (suspend, resume, "Machine started in …"), which is what exposed a slow host.
- **Placement control:** fly `machine clone` moved a slow-resuming Rust machine to another host (resume 1.6–12 s became 0.67–0.80 s). Railway gives no host-level control in the CLI used.
- **Idle cost model:** fly suspends idle machines (resume 0.6–0.7 s, cold start 1.6–3.8 s depending on stack) and bills rootfs only while suspended (docs, [M5 findings](m5-online.md#hosting)). Railway sleep ("serverless") was **not tested**; services stayed up for the whole run. Docs: first request after sleep "may return a 502" (see Railway section above).

### Performance (measured, 10 rooms 3v3 unless stated)

| | fly `fra` shared-cpu-1x | Railway Amsterdam (trial) |
|---|---|---|
| CPU, Go / Rust / Elixir / Kotlin | 38–39 % / 29–31 % / 64 % / 98 % of one shared vCPU | 0.20–0.23 / 0.21–0.24 / 0.77 / 2.4–2.6 vCPU |
| Sustained load | Burst balance drains, then **throttled to the 6.25 % baseline** (Kotlin p99 → 30 s); balance does not accrue while suspended, so about one 3v3 room per machine is sustainable | No throttling seen in 3 min at up to 2.6 vCPU |
| Memory used, Go / Rust / Elixir / Kotlin | VM 53 / 52 / 159 / 98 MiB of 210 usable (guest base ~48) | 15 / 2–9 / 171 / 122–130 MB (service only) |
| Latency from the Mac, p50 / p99 (Go, Rust, Elixir) | 11–12 / 12–18 ms | 39–41 / 44–45 ms |
| Warm connect → welcome | 58–64 ms | 147–201 ms |

Railway's per-vCPU figures look lower than fly's percentages partly because the units differ (vCPU-seconds on an unthrottled, probably faster host vs share of a quota-limited shared vCPU); the CPU ratio between stacks is similar on both hosts except Kotlin.

### Assessment (Claude, not a user decision)

**Railway is a real alternative technically, but not a better default for Wargrid now.**

For Railway:
- WebSockets ran through its TLS edge for every stack without changes.
- Dockerfile deploys from the CLI were straightforward once the region trap was known.
- Metrics are easy to script.
- Capacity per service is much higher: no burst quota, so ten 3v3 rooms cost about 0.22 vCPU in Go or Rust instead of throttling.

Against Railway:
- **Latency:** the only EU region is Amsterdam, and players near Bavaria saw about +28 ms p50 per round trip. That eats into M5's 45–59 ms headroom under the 250 ms command budget, which the 4-tick input delay already leaves ([M5 findings](m5-online.md#latency-budget-command-p95--250-ms)). For lockstep this matters more than CPU.
- **Cost floor:** Railway Hobby is $5/month (docs). The fly organisation is on the legacy Hobby plan (user, 2026-11-05), whose allowances are honoured for pre-October-2024 orgs: "Up to 3 shared-cpu-1x 256mb VMs" and "100 GB North America & Europe" outbound, with "no monthly subscription fee" (docs.fly.io/about/discontinued-plans, read 2026-11-05). So up to three relay machines cost nothing on fly. For new fly orgs the list price is $2.53/month per started shared-cpu-1x 256 MB in `fra`; fly.io/pricing.md says "invoices under $5 are waived" for new users.
- **Infra as code:** config sits in Railway's state, not in a reviewed file like `fly.toml`.
- **Multi-region:** the plan's single-region limit conflicts with M9's region-aware placement unless Pro.
- **Sleep:** the sleep/502 path is untested with the Godot client.

Recommendation (proposal):
- Stay on fly `fra` for the friends relay.
- Treat fly's 6.25 % baseline as the capacity limit to design around in M9: batching, a compact log, one room per shared machine, or a non-shared CPU size.
- Keep Railway as the cloud-agnostic fallback the R2 design already allows (one service per worker, own domain).
- Re-evaluate Railway only if fly's per-machine capacity or pricing becomes the binding constraint.

## High availability options (proposed 2026-11-05)

User, 2026-11-05: one machine is acceptable for now; it is not highly available, so what could be done there is worth exploring. Here "available" means a crash or host loss does not end live matches; deploys are already covered by draining. Nothing below is decided or measured; the options are for M9 planning.

Fly's managed Redis (docs read 2026-11-05, fly.io/docs/about/pricing and /docs/upstash/redis): it is **Upstash Redis**, a third-party extension billed through the Fly invoice. Databases run "within Fly.io infrastructure, but not inside your organization's network" and are "replicated within the same region in a highly-available configuration"; the primary region is chosen at creation and cannot change; read replicas in other regions are optional; data transfer to it is billed like other cross-boundary traffic. Standard Redis protocol, so code that uses only that protocol stays cloud-agnostic; only provisioning (`flyctl redis create`) is fly-specific.

| Option | How | What it survives | Cost / risk |
|---|---|---|---|
| A. One machine (today) | Drain before deploy; fly restarts a crashed machine | Deploys | A crash or host loss ends live rooms; players rematch |
| B. Rebuild rooms from the clients | Relay keeps no durable room state. Every client already holds the full command history in its simulation; after a restart, reconnecting clients re-send it and the relay restores the room from the longest log | Crash, host loss, deploy, with no extra service | Idea, not checked against the fixed wire protocol (`protocol/vectors`, conformance suite); likely a protocol addition, so a conformance change; clients may sit at different ticks, so the relay needs a rule for which log wins |
| C. Mirror room state to Redis | Seats and the command log appended to Redis off the hot path; a replacement machine adopts the room, clients reconnect and replay | Same as B, plus the relay can restart without any client having every command | Extra dependency, a fixed primary region, transfer cost; never put Redis on the per-tick path (the command budget has little headroom, see the latency numbers above) |
| D. Several machines, owner in the match code (existing design) | See Routing options | Fault isolation, region latency; a live room still lives on one machine | Most machinery; adds availability only when combined with B or C |

Assessment (Claude, not a user decision):

- Every option beyond A depends on **client reconnect with command-log replay**, which M9 already plans. Build and test that first; it is useful on its own for dropped players.
- B should be tried before C: it needs no new service, and the clients already hold exactly the data Redis would store. If the protocol can carry it, Redis adds little for room state.
- Redis earns its place for **shared directory state** (match code to owner machine, seat claims, public matchmaking) once there is more than one machine, which is option D, not for the live room.
- For a friends-scale game, A plus fast reconnect is probably enough; B or C is for learning and robustness. Choose at M9 planning.

## Availability to start a game (user, 2026-11-16)

The goal changed on 2026-11-16: a server must always be there to start a game; a match surviving a crash comes second ([answers](design-answers-2026-11-08.md#relay-availability-questionnaire-user-2026-11-16)). That makes option D above the main line and options B and C optional. The mechanics below are proposed (Claude), built from those answers; nothing is placed or built.

- **Two workers, one stable DNS name each**, built into the game: the name's first label is the worker's slot, and the first character of the match code names that slot, so a joiner reaches the owner without a lookup. Moving a worker is a DNS change. A relay override (prerelease field, `relay` link parameter) replaces the whole list. A shared name with two address records cannot do this: DNS keeps no room's players together.
- **Create fails over in the client.** Pick a worker at random; on no answer, or the refusal `relay busy` or `relay restarting` (a draining worker), try the other. A worker answers `relay busy` above its own limit of players; an open lobby reserves all its seats against it, and the number comes from night 10. A deploy that changes the protocol leaves the two workers on different versions for a while, so `protocol mismatch` on create is a reason to try the other worker too. That does not keep old builds served through the whole deploy: once the first worker runs the new protocol and the second drains, an old build finds no worker for a new game, for up to the drain limit, until the player updates. Accepted as the cost of a protocol change (user, 2026-11-16); no worker speaks two versions. Order: first worker, then the new build, then the second worker. Random keeps both workers in daily use, so a broken one is noticed before it is needed.
- **Drain before deploy.** The registry's drain flag and `room.markDraining` exist (`relay/room.go`); missing are a trigger other than the stop signal, because the platform's kill timeout is shorter than a match, and the 60 minute limit. The trigger is a signal to the process (SIGUSR1); the worker reports on `/health` that it is draining and how many rooms remain, and the deploy script waits for draining with zero rooms. Zero rooms alone is not enough: an idle worker shows zero before the signal is handled, so the relay closes create admission under the registry lock before it reports draining. Unlike today's shutdown, which stops accepting connections at once (`relay/main.go` `shutdown`), a draining worker keeps listening, so joins to its rooms and `/health` still answer. Relay deploys get their own workflow, started by hand; today every release that is not a prerelease deploys the relay (`.github/workflows/release.yml`, step "Deploy relay"). A draining worker refuses only new games: lobbies that exist may still fill and start, which today's `markDraining` closes; a lobby lives at most 15 minutes (`WARGRID_LOBBY_MS`), so a match that starts on a draining worker still has at least 45. Play again is off: the result panel hides it with one line, so the client has to know by the end of the match that its worker drains, and a press that still arrives is refused; at the limit the remaining matches end with a reason and no earlier warning. The reason travels in the existing `error` message, so no message type is new: one new reason, proposed `relay restarting`, for a refused new game, a refused Play again and the end at the limit. Today `closeAll` closes without a reason and the player reads "Connection to relay lost". Deploy one worker at a time.
- **No wire change.** No `redirect` message and no `GET /workers`: the slot character and the worker names replace both, so of R2 above the worker, drain and retry bullets stay and the worker list endpoint and the redirect go.
- **The database is never in the path** of create, join or play.
- **Both workers always on.** No wake-up on the first connection, and the peer check below would keep a suspended worker awake anyway.
- **The workers check each other.** Every few minutes each opens a real game connection to the other, which covers name, certificate, proxy and relay, where `/health` covers only the process. After repeated failures it posts to a configured webhook that pushes to a phone. Blind when both are down at once, which is the accepted outage case: then the names are repointed by hand to a worker deployed elsewhere.

Already built or on a branch (checked on `main` `2979497`, 2026-11-16):

| Part | State |
|---|---|
| Atomic admission, hello and lobby deadlines, rematch in the room | built (P2.2 and before) |
| Drain on the stop signal, 3.5 s, closing lobbies that have not started | built (`relay/main.go` `shutdown`) |
| Relay address in the invite link | built (`game/scripts/join_link.gd` `link`) |
| Join and connection limits: `relay busy` for the global ones, `too many connections` and `too many joins` per address | branch `relay-guards`, not merged |
| Client retry after a failed connect | not built |
| Slot character, worker names, fail-over, long drain, player limit per worker | not built, not placed |

Reference engines (read 2026-11-16; evidence, not a decision): in ioquake3 (`52088b9e`), OpenRA (`b4d95a5671`) and Recoil (`a0240a9b5c`) a match is bound to one server process and nothing routes or hands a match over; when the server dies the clients time out or lose the connection and the match ends in all three (`code/client/cl_main.c:2903` `CL_CheckTimeout`; `OpenRA.Game/Network/Connection.cs:222-226`; `rts/Game/Game.cpp:1200`). ioquake3, whose server simulates, gives a reconnecting client its old slot (`code/server/sv_client.c:456-473`) and a fresh game state (`:720` `SV_SendClientGameState`). Of the two lockstep engines only Recoil lets a client back into a running match: while reconnecting or joining as a spectator is allowed, its server keeps the broadcast packets and sends them all to the returning client (`rts/Net/GameServer.cpp:564`, `:3119`), which is the idea behind P8's replay buffer; OpenRA refuses a join once the game started (`OpenRA.Game/Server/Server.cs:471-476`). ioquake3 gets availability from up to five master addresses asked at once (`code/qcommon/q_shared.h:78`, the loop at `code/client/cl_main.c:4246`), with no fail-over logic, and does not try another server when one is full (`code/server/sv_client.c:525`).

Where other projects keep their server address (read 2026-11-16; evidence for the built-in names): OpenTTD compiles in one DNS name (`src/network/core/config.cpp:23`, `de9df409a7`), OpenRCT2 a constant (`src/openrct2/network/Network.h:43`, `64c3fef27b`), 0 A.D. and Hypersomnia ship it as a config default (`binaries/data/config/default.cfg:561`, `136720dada`; `hypersomnia/default_config.json:16`, `fd812be10`). What Hypersomnia, fteqw and Zero Hour fetch at run time is a list of game servers, never the address of the service itself; the Zero Hour fork replaced the dead GameSpy host at build time (`cmake/gamespy.cmake:2`, `afc2a103f`).

fly facts for this design (fly's own pages, read 2026-11-16 through a summarising fetch, wording not checked byte for byte): `kill_timeout` "up to a maximum of 300 seconds" (docs.fly.io/reference/configuration); the Machines API has an endpoint that sends a signal to a running machine, `flyctl` has no command for it (docs.fly.io/api/machines/openapi.json, docs.fly.io/flyctl/machine); a suspended machine resumes in "a few hundred ms" and requests during an early start "might fail" (docs.fly.io/reference/suspend-resume, docs.fly.io/reference/fly-proxy-autostop-autostart); `shared-cpu-1x` 256 MB in `fra` $2.53 a month running, `performance-1x` 2 GB $38.08 (fly.io/pricing), so two always-on workers cost about $5 a month at list price. Not stated on those pages: what happens to a machine when its host fails without warning, spend limits or billing alerts, whether the legacy allowance counts machines across apps. The status history readable on that day (about three months) had one partial `fra` network incident and one platform-wide round of host reboots.

Player texts (proposed by the player-experience review, 2026-11-16; the starting wording for the package's design, not decided). Today these cases reach the player as raw relay reasons or as "Cannot connect to relay".

| Case | Proposed text |
|---|---|
| Both workers full | "All game servers are full. Try again in a few minutes." |
| Both unreachable | "Could not reach a game server. Check your connection and try again. If it keeps failing, the servers may be down." |
| The code's worker is down | "Can't reach the server for this game. It may be restarting. Ask the host for a new code." |
| Play again on a draining worker | "This server is restarting soon, so Play again is off. The host can create a new game and send a new code." Better: hide Play again with that line before anyone presses it. |
| Drain limit reached | "Match ended: the server restarted for an update. No winner. Start a new game from Play." |

When the two workers refuse for different reasons, show the more useful one: a version mismatch must reach the version message, not "servers full".

Open: the player limit's number (night 10); which service turns the webhook into a push (chosen in the package's design); whether the platform can alert on its own failing health checks (not checked); the runbook for repointing the names.

### Research for P8 (2026-11-16)

Read on `main` `2979497`; evidence for P8's design, not a decision.

- **A network drop needs almost no catch-up.** Lockstep stalls every client at the dropped seat, so peers hold at most about 2 × delay + 2 ticks more (`game/scripts/net/lockstep.gd` `MAX_QUEUED_TICKS` and its comment). A small relay buffer of recent ticks per seat is enough; the client erases its own sent frames once applied today and would have to keep the recent ones.
- **A reloaded or crashed client needs the whole match.** Clients keep every applied command without a limit (`_command_log`); the relay keeps no log. No state restore exists, and `snapshot()` leaves out bot memory ([simulation interface](sim-interface.md)). Replay from tick 0 at 30 ticks a second, a step mean of 1.07 ms with the profiler on ([performance ledger](performance.md)) and the 5.5 slowdown: about 106 s for a match 10 minutes old on the low-end target, 212 s at 20, 424 s at 40, against a 60 s grace. Rough: nothing was measured past 25 minutes.
- **Other engines:** 0 A.D. asks an existing client (session 0, assumed to be the host's) to serialise its state for a rejoining client and then sends the commands after that turn (`source/network/NetServer.cpp:1146-1180`, `:1456-1462`, `136720dada`); OpenTTD's server sends a savegame (`src/network/network_server.cpp:588-604`, `de9df409a7`); Warzone 2100 closes joining at match start (`src/multiint.cpp:5828`, `b904885ff`). None rebuilds a server's match from its clients.
- **Option B above is cheaper than its row says.** Every frame has one author and the relay forwards identical bytes, so no rule for "which log wins" is needed: clients report the last tick they hold per seat and each author resends its own frames after the lowest. It still needs a token that checks after a restart, start parameters all clients resend and the relay finds equal, and frames copied from a peer when an author never returns, which the relay refuses today.


## Web build delivery (researched 2026-11-12; parked)

Question (user, 2026-11-12): would moving `wargrid-web` and `wargrid-web-test` from fly.io to a CDN or static host, starting with bunny.net, bring tangible benefits, and which candidates work well from a CLI and in agent-driven workflows? **Parked by the user** for M9 hosting planning, next to the relay machine-type question in the [blueprint](../blueprint.md#m9--3v3-online). That question (`performance-1x`) concerns relay CPU; the web app serves static files, so its CPU size does not matter. Labels: **measured**, **docs** (primary source read 2026-11-12), **unverified**.

**Requirements.** One 39.5 MB (37.7 MiB) `index.wasm`. Godot's file names never change, so the host must send `Cache-Control: no-cache` or clear its cache on every deploy; today `no-cache` plus 304s from the origin keep a new `.wasm` from pairing with an old `.pck` ([development notes](../development.md#browser-build)). COOP/COEP headers if the threaded build ships ([worker thread design](../superpowers/specs/2026-11-12-worker-thread-design.md)). A custom domain behind a CNAME. Deploys from CI and agent shells without prompts.

**Measured** (`curl` with `Accept-Encoding: br` from the development Mac, two runs per URL): `index.wasm` is 6.9 MB brotli. Time to first byte 0.54-0.88 s when the suspended machine resumes, 0.04 s warm; whole file 0.17 s warm. A cold page load is about 7.6 MB, so fly's 100 GB outbound allowance ([development notes](../development.md#relay)) covers roughly 13,000 cold loads a month; repeat visits get 304s.

| Host | Free allowance | Per-file limit | Headers | Deploy model | CLI and agents | Fit |
|---|---|---|---|---|---|---|
| fly.io (today) | 100 GB/month outbound (legacy plan) | none (own image) | yes, `web/sws.toml` | new image per machine | `flyctl`, used in CI | works; resume delay only |
| bunny.net | none; $0.01/GB EU/NA, $0.03/GB Asia, $1/month minimum | not stated | Edge Rules (dashboard) | versioned, rollback; purge and atomicity not stated | CLI in public preview, `--output json` | possible; purge on deploy unresolved |
| Cloudflare Workers static assets | static asset requests "free and unlimited" | **25 MiB** | `_headers` file | code and assets "in a single operation" | `wrangler`, `CLOUDFLARE_API_TOKEN`, `--json` | **blocked** by the wasm size unless the wasm moves to R2 |
| Netlify | 300 credits; 20 per GB, 15 per production deploy | not found | `_headers` or `netlify.toml` | atomic | `NETLIFY_AUTH_TOKEN`; official MCP server | works; free tier about 15 GB minus deploys |
| Vercel Hobby | 100 GB/month, 1M requests | 100 MB upload per deploy | `vercel.json` | unique URL per deploy, instant rollback | `--token`, `--json` | works; non-commercial use only |
| Firebase Hosting | 10 GB/month transfer, 10 GB storage | 2 GB | `firebase.json` | releases; redeploy clears the CDN cache | service account; `FIREBASE_TOKEN` deprecated | works; free site disabled past 10 GB until next month |
| GitHub Pages | 100 GB/month (soft), 1 GB site | not on the limits page | none documented | Actions artifact | `actions/deploy-pages` | **no headers**: no COOP/COEP, no cache control |
| itch.io HTML5 | free | 200 MB, 1,000 files | none documented | `butler push` channels | `BUTLER_API_KEY`, no JSON output | iframe on itch.io, no custom domain |
| Tigris (fly.io storage) | 5 GB storage, egress free | not stated | per-object headers | object uploads | S3 tools, `fly storage` | **blocked**: no `index.html` for `/` |

Notes per host (docs):

- **bunny.net:** 119 PoPs ([CDN pricing](https://bunny.net/pricing/cdn/)); storage-to-CDN traffic free ([storage pricing](https://bunny.net/docs/storage/pricing.md)). Free certificates "via Let's Encrypt" behind a CNAME, so the apex CAA record allowing only Let's Encrypt keeps working ([SSL setup](https://bunny.net/docs/cdn/ssl-setup.md)). Compresses with gzip, Brotli or zstd on the fly, `application/wasm` included ([compression](https://bunny.net/docs/cdn/frequently-asked-questions/mime-compression.md)). Headers come from [Edge Rules](https://bunny.net/docs/cdn/edge-rules/index.md). "Bunny CDN does not monitor your origin for file changes" ([purge](https://bunny.net/docs/cdn/purge-cache.md)), and the deploy docs do not say whether a deploy purges. The CLI is in "public preview", "commands, flags, and behaviour may change" ([announcement](https://bunny.net/blog/introducing-the-bunny-net-cli/), [sites commands](https://bunny.net/docs/cli/commands/sites)); "Every prompt has a flag. Every command has `--output json`." ([storage CLI](https://bunny.net/blog/you-can-now-manage-bunny-storage-with-the-bunny-net-cli/)); `BUNNYNET_API_KEY` for CI ([configuration](https://bunny.net/docs/cli/configuration.md)); `bunny sites deploy ./dir` uploads a built directory, `bunny sites deployments publish --previous` rolls back. No official MCP server; the CLI does not need one.
- **Cloudflare:** the 25 MiB limit applies to Workers static assets and Pages alike, and Cloudflare recommends Workers for new projects ([Workers limits](https://developers.cloudflare.com/workers/platform/limits/), [static assets billing](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/), [headers](https://developers.cloudflare.com/workers/static-assets/headers/)). R2 allows 5 TiB objects with free egress ([R2 limits](https://developers.cloudflare.com/r2/platform/limits/)), but a split origin needs CORS that satisfies COEP.
- **Netlify:** "No changes go live on your site's public URL before all changes have been uploaded" ([deploys](https://docs.netlify.com/deploy/deploy-overview/)), which removes the file-pairing risk. The pricing page does not state the period of the credit limit ([pricing](https://www.netlify.com/pricing/), [headers](https://docs.netlify.com/routing/headers/)).
- **Vercel:** Hobby is "for personal, non-commercial use"; donations are allowed, and Hobby cannot buy extra usage ([fair use](https://vercel.com/docs/limits/fair-use-guidelines), [limits](https://vercel.com/docs/limits)). Brotli includes `wasm` ([compression](https://vercel.com/docs/how-vercel-cdn-works/compression)).
- **Firebase Hosting:** "If you redeploy your site's content, Firebase Hosting automatically clears all your cached content across the CDN" ([cache](https://firebase.google.com/docs/hosting/manage-cache)); on the free plan the site is disabled after 10 GB of transfer until the next month ([quotas](https://firebase.google.com/docs/hosting/usage-quotas-pricing)).
- **GitHub Pages:** the [limits page](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits) documents no custom headers, so it cannot serve the threaded build.
- **itch.io:** HTML5 games take payments as donations only and run in an iframe; the CDN gzips `wasm` ([HTML5](https://itch.io/docs/creators/html5), [butler](https://itch.io/docs/butler/pushing.html)). A distribution channel with its own audience rather than a host for our domain.
- **Tigris:** caches objects near users, billed through fly.io ([fly Tigris](https://docs.fly.io/tigris), [caching](https://www.tigrisdata.com/docs/objects/caching/), [pricing](https://www.tigrisdata.com/pricing/)); a public bucket "never serves index.html" ([public buckets](https://www.tigrisdata.com/docs/buckets/public-bucket/)). The fly.io proxy has no response cache in the docs read; more fly.io regions mean one machine per region plus egress ([pricing](https://docs.fly.io/about/pricing)).

**Assessment (Claude, not a user decision).** No tangible gain for players near `fra`: the only cost on fly.io is the resume delay, which `min_machines_running = 1` in `web/fly.toml` removes (check first that the free allowance covers a third always-on machine next to the relay and the test app). A CDN pays off only for players far from Europe. Then the shortlist is Netlify (atomic deploys; small free tier) and bunny.net (lowest price per GB; purge on deploy unresolved), trialled on `wargrid-web-test` first. Any move adds a second vendor, token and CI secret, since the relay stays on fly.io.

**Unverified.** Delivery times and compressed sizes on every alternative (no accounts used); which hosts serve our build-time `.br` copies as stored, and bunny.net's compression size limit; Netlify's per-file limit and brotli support; deploy atomicity on bunny.net, Vercel and Cloudflare; bunny.net Edge Rules through its API; the fly.io proxy reference page (not read).

## Unverified

- fly: public hostname per worker as one app per worker (cost, deploy commands); the actual bill; `performance-1x` under our relay load (planned for M9, user 2026-11-05). Docs, fetched 2026-11-05 (fly.io/docs/about/pricing, /machines/cpu-performance): `shared` baseline 5 ms per 80 ms (6.25 %), `performance` 100 %; `performance-1x` 2 GB $33/month and `performance-2x` 4 GB $66/month at the lowest-priced regions, `fra` costs more (its 1 GB shared example is $7.73 against $6.70 in `iad`); stopped or suspended machines pay only $0.15 per GB of rootfs per month. Unknown: `performance` price in `fra`, whether `shared-cpu-2x` doubles the baseline.
- Railway: Hobby vs trial limits (regions, CPU limit), maximum honoured draining time, sleep/wake time and the 502 path with the Godot client, cold start, config-as-code files, behaviour under sustained load beyond 3 minutes.
- Both: RTT from players' locations other than the user's Mac; more than one machine per stack.
