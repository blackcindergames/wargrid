# 11. Multiplayer

An online match sends only orders over the network. Each player's machine runs the whole simulation and gets the other seats' orders for every tick from a small relay server; a tick runs only when all seats' packets for it are in. Nothing about units, damage or economy is ever transmitted, so the average frame measured in the M5 spike was about 52 bytes, and a desync check is one 16-digit hash.

This chapter follows one click across the wire, then opens the three pieces: lockstep (the client rules), the wire protocol and the relay. It ends with what a slow or dead peer does to the match.

## Three pieces, one packet per tick

On each machine the online driver feeds `Lockstep`, the object that decides when a tick may run. Lockstep encodes through `wire.gd`, and `relay_transport.gd` moves the text over a WebSocket. The relay is a separate Go program that never sees the game.

```mermaid
flowchart TD
    OM["online_driver.gd<br/>driver: submit, advance,<br/>finish_tick"] --> LS["lockstep.gd<br/>stamp, queue, wait,<br/>compare hashes"]
    LS --> WI["wire.gd<br/>encode, decode,<br/>validate"]
    LS --> SIM["Simulation<br/>issue_command, step"]
    WI --> RT["relay_transport.gd<br/>WebSocket, ping,<br/>silence timer"]
    RT --> RL["Go relay<br/>rooms, forward<br/>byte for byte"]
    classDef sim fill:#2f5d8a,stroke:#7fb3e6,color:#ffffff
    classDef driver fill:#5b3f86,stroke:#b79ae6,color:#ffffff
    classDef net fill:#8a5a1f,stroke:#e6b06f,color:#ffffff
    class OM driver
    class LS,WI,RT,RL net
    class SIM sim
    linkStyle default stroke:#9aa4b2,stroke-width:2px
```

The one rule: **every seat sends exactly one packet per tick, empty or not.** The packet carries that seat's commands for one future tick, and optionally a state hash. Every other part follows from it.

- The simulation can tell "nobody ordered anything" from "the packet has not arrived yet", so lockstep needs no clock and no timeout to know when a tick is complete.
- The relay can check that each seat's ticks come one after another with no gap and forward them blindly.
- A peer that goes quiet is visible at once, as a missing packet.

The price is that a packet crosses the network every tick (30 per second) per seat, even when idle. The M5 spike measured about 52 bytes per frame, about 1.55 KB/s uplink per client ([M5 findings](../reference/m5-online.md#latency-budget-command-p95--250-ms)).

## One click, from machine A to both simulations

Two seats, input delay 4 (the relay announces it in the start message; [chapter 4](04-the-tick.md) shows where the online driver steps). Player 1 on machine A orders a tank to move while A's simulation stands at tick 100, with its packets up to tick 104 already sent.

1. The click arrives as an ordinary move payload and the online driver hands it to lockstep instead of the simulation. Lockstep stamps it with tick 105 (the next packet not yet sent), the local seat as player and the next sequence number, and queues it.  
   `online_driver.submit → Lockstep.submit`
2. Machine A finishes tick 100 and the driver calls `finish_tick(101)`. The packet for tick 105 is built from the queue (plus a hash on every 30th tick) and encoded as JSON text. A also stores it for itself, decoded back from that same text, then sends it.  
   `online_driver.step → Lockstep.finish_tick → Wire.encode, Wire.decode`
3. The relay's WebSocket handler parses the frame, checks it is well formed, and posts it to the room's goroutine. The room checks that the seat number matches the connection and that this is exactly the next tick from that seat. It then writes the same bytes to every other seat.  
   `relay.OnMessage → parseEnvelope → room.post → room.forward`
4. Machine B polls its socket, decodes the frame and stores the packet under seat 1, tick 105, after checking seat, order, each command's player and tick stamp, and the queue limit.  
   `online_driver.step → RelayTransport.poll → Lockstep.receive`
5. Once both machines have reached tick 105 and hold every seat's packet for it, lockstep runs the tick. For each seat in seat order, lockstep feeds the packet's commands to the simulation, which validates them as in [chapter 4](04-the-tick.md), then calls `step`, whose first phase applies the move. A and B run identical inputs in identical order.  
   `Lockstep.advance → Simulation.issue_command → Simulation.step`
6. On A only, lockstep records the click-to-execution time and any rejection for the status line.  
   `Lockstep.advance: _latency, _rejections`

```mermaid
flowchart TD
    C["A: click at tick 100<br/>submit stamps tick 105"] --> P["A: finish_tick(101)<br/>packet for tick 105"]
    P --> R["Relay: parse, check,<br/>forward same bytes"]
    P --> L["A: keeps its own copy,<br/>decoded from the same text"]
    R --> B["B: receive<br/>packet stored for tick 105"]
    B --> E["Tick 105 on A and B:<br/>issue_command, then step"]
    L --> E
    classDef sim fill:#2f5d8a,stroke:#7fb3e6,color:#ffffff
    classDef driver fill:#5b3f86,stroke:#b79ae6,color:#ffffff
    classDef net fill:#8a5a1f,stroke:#e6b06f,color:#ffffff
    class C driver
    class P,R,L,B net
    class E sim
    linkStyle default stroke:#9aa4b2,stroke-width:2px
```

**The order takes effect five ticks after the click, not four.** The stamp is the tick of the next packet to send, which is the delay plus one ahead of the current tick. At 30 ticks per second that is 5 × 33 ms ≈ 167 ms (arithmetic). The M5 command latency on the fixed build was p50 174 and 181 ms for the two seats, p95 191 and 205 ms, against a budget of 250 ms at p95 ([M5 findings](../reference/m5-online.md#latency-budget-command-p95--250-ms), measured).

**Why A runs its own command from the decoded copy.** Step 2 round-trips A's own packet through `Wire.encode` and `Wire.decode`. Godot parses every JSON number as a float, and the simulation's validation demands integers for tick, player, sequence and every id. `Wire.decode` converts integral floats in a fixed list of fields back to integers. A's own commands must pass through the same conversion as B's, or the two machines would apply slightly different dictionaries. The lockstep test `L3` pins this: the applied command equals the decoded sent form, and a target such as 0.1 + 0.2 keeps its full precision.

## Lockstep: when may a tick run?

`Lockstep` is a plain object with no scene or socket; the driver gives it frames and asks it questions. Its state is one table of packets per seat, keyed by tick.

**Starting.** The first packets cannot arrive before they are sent, so the constructor fills ticks 0 to delay-1 with empty packets for every seat. `start` then sends the first real packet, for tick `delay` (the relay refuses anything earlier). A command queued before `start` (every client queues `choose_faction`) is stamped with that same tick. The simulation runs its first four ticks without waiting.

**Advancing.** `Lockstep.advance(sim)` answers "may the tick run?" and runs it:

1. Return false if the match ended, or if a seat left and this tick is past its last packet (below).
2. If any seat's packet for this tick is missing, set the status to waiting and return false. The HUD says "Waiting for player N"; no tick runs and presentation keeps drawing the last state.
3. Compare any hashes riding on the packets (below).
4. Feed every seat's commands to `issue_command`, seats in ascending order, then drop those packets.
5. Call `step`, move on to the next tick, return true.

`finish_tick` runs after each successful advance: it builds and sends the packet for `tick + delay`. The driver calls the two in that order, and that pairing is why a seat stays at most `delay` ticks ahead of its slowest peer.

**Checks on every received packet.** A packet from an unknown seat or from the receiver's own seat, a tick that is not exactly the previous one plus one, a command whose player or tick differs from the packet's, or a seat with 300 packets already queued (`MAX_QUEUED_TICKS`) ends the match as a protocol error. TCP delivers in order, so "tick out of order" means a buggy or modified peer. The player field check means a seat cannot issue orders as another player; the simulation's own validation ([chapter 4](04-the-tick.md)) also refuses orders for units owned by someone else.

**Pacing.** Waiting for packets slows the game down, but the opposite problem exists: after a stall, packets arrive in a burst, and running them as fast as possible would speed the game up. `online_driver.step` rations catch-up with a small credit counter, as [chapter 4](04-the-tick.md#trade-offs-and-limits) describes; the HUD gets every advanced tick's command results, not only the last. The first online match ran at about 57 ticks per second before this existed ([M5 findings](../reference/m5-online.md#what-broke-and-why)).

**Ending.** Lockstep reports failure as a status, not an exception, and `advance` returns false from then on. The statuses are `ended_left` (a seat left), `ended_relay` (the relay sent an error or the connection was lost), `ended_desync` and `ended_protocol`. The scene turns them into the HUD line and, for a desync, writes the report. [Playing online](../playing-online.md#status-lines) lists the player-facing wording.

## The wire protocol

The protocol is JSON text, one message per WebSocket text frame, at most 64 KiB, with version `Wire.PROTOCOL` (2). Every message has a `type`. Who sends what:

| Message | From | Content |
|---|---|---|
| `hello` | client | protocol, build string, match code (empty creates a room), and from the creator the map settings |
| `welcome` | relay | the client's seat number and the match code |
| `start` | relay | seats, delay, a match seed, the creator's settings echoed unchanged; sent to every seat when the room is full |
| `tick` | client, relayed | seat, tick, commands, optionally a hash |
| `ping`, `pong` | client, relay | a timestamp the relay echoes byte for byte |
| `left` | relay | the seat that left and its last forwarded tick |
| `over` | client | this seat's match has ended; no content. Valid once, after the seat's first accepted tick |
| `again` | client, relay | the client asks to play again, no content; the relay echoes it to the other seats with `seat` set to the asker. Valid once, after the seat's own `over` |
| `error` | relay | a reason (`lobby expired` and `room expired` join the older ones); the relay closes the socket shortly after |

Bad ordering of `over` and `again` is `invalid message`: `over` in a lobby, before the seat's first accepted tick or twice, a `tick` after the seat's own `over`, `again` before the seat's own `over` or twice. The protocol number stays 2.

A tick message is one line (this is the committed vector `protocol/vectors/tick.json`):

```json
{"type":"tick","seat":1,"tick":10,"commands":[{"type":"move","tick":10,"player":1,"sequence":3,"entity_ids":[1,2],"target":[14.1,0.30000000000000004]}],"hash":{"tick":30,"value":"3a0ad3856b168044"}}
```

**Handshake.** The creator's hello carries map settings; the relay stores them without interpreting them and puts them in every seat's start. Each client compares the map and its hash with its own files and refuses to start on a mismatch (`MatchSettings.refusal`); the `map-mismatch` scenario shows the host then seeing the joiner leave at tick 4. The relay compares only the protocol number and the build string, which is the project's version setting: an old client cannot join a new relay's rooms, and the reverse. The match seed comes from the relay, not from a client, so neither player can pick favourable start spots; what the seed does (start spots, not the simulation's own generator) is explained in [chapter 10](10-determinism-and-replays.md#randomness).

**Decoding is strict.** `Wire.decode` rejects an unknown type, a missing required field, a non-integer where an integer belongs, a hash that is not 16 lowercase hex digits, and any frame over the cap. Go's `parseEnvelope` applies its own checks to what a client may send. Both implementations reject a bad frame instead of repairing it. The relay's checks are narrower: it never looks inside a command.

**Floats survive the wire.** `JSON.stringify` is called with sorted keys and full precision, so a coordinate like 0.30000000000000004 goes out and comes back as the same double. Without full precision two machines would compute positions from slightly different targets.

## The relay

The Go program in `relay/` is about 1,300 lines in five files, tests not counted (`main.go`, `room.go`, `envelope.go`, `sender.go`, `limits.go`; [development notes](../development.md#relay) for how to run it). It owns four things: matchmaking by code, forwarding, noticing who left, and refusing clients that ask too much.

**Rooms are goroutines.** A room is created by the first hello and gets its own goroutine. All its state (seats, started flag, settings) is touched only there. Connection handlers talk to it by channel: joins on an unbuffered channel, ticks and leaves on an events channel. A mutex guards only the registry of rooms, which is touched on create, lookup and removal, never per frame. If one room's goroutine panics, `recoverCrash` closes that room's sockets and removes it; other rooms keep running (a recommendation of the relay stack spike).

**Seats and start.** Seats take the lowest free number. The room starts when it holds `WARGRID_SEATS` seats (default 2); at that moment every seat receives start with the delay (a constant, 4) and a random 31-bit seed. After start, nobody can join, even if a seat leaves.

**Deadlines by phase.** The read deadline on a socket depends on what the room is doing, so a host can leave the tab while waiting but a dead match is still noticed fast. Each `conn` carries a small `deadline` (mutex-guarded, because the reader goroutine and the room goroutine both set it); `hold` fixes it, `every` renews it on each frame.

| Phase | Deadline | Default |
|---|---|---|
| Connected, no hello yet | `hold`: `WARGRID_HELLO_MS` | 5 s |
| Seat in an unstarted lobby | `hold` until the lobby expires (frames and pings do not extend it) | `WARGRID_LOBBY_MS`, 15 min |
| Started, no tick from this seat yet (start window) | `hold`: one `WARGRID_LOBBY_MS` from the start | 15 min |
| Running match, from the seat's first accepted tick | `every`: renewed by any frame | `WARGRID_SILENCE_MS`, 10 s |
| Parked (between matches) | `hold` until the park limit plus a 1 s grace | 15 min |

The lobby timer lives on the room, not the socket. When it fires with the room unstarted, the room removes itself from the registry, sends `lobby expired` to every seat and closes; a later join gets `unknown match`. The socket deadline sits one second behind the timer so the error frame lands before the close. The error is the socket's last frame: the sender is sealed with it, so no pong, tick or `left` follows (`sender.sendLast`, `relay/sender.go`). The start window exists for a hidden browser tab (F11): a host whose tab is hidden when the friend joins has the whole window to come back and send its first tick, while a running match keeps the 10 s rule. The attended hidden-tab check on a real browser is still pending.

**Park and rematch.** A seat sends `over` when its simulation decided the match. When every seat has sent it, the room is parked: it keeps its seats and runs the same timer again, now as the park limit, and a fire sends `room expired` and closes. A seat's `again` is echoed to the others at once; when every seat is parked and has sent `again`, the room clears each seat's tick counter, `over` and `again` flags (frame and byte counts stay, so `MATCH END` reports the whole room) and sends a second `start` with a fresh seed, logging `rematch`. An `again` that was queued when the timer won, or after a drain began, is dropped, never answered with `start`.

**Forwarding.** For every tick frame the room checks the match has started, the seat in the message equals the connection's seat, and the tick is exactly the previous one plus one (the first is 4). Anything else marks the seat dead: the relay replies with an error, closes the socket after a 200 ms grace (Godot drops queued frames when it sees the close, so the error would otherwise be lost), and the others hear `left`. A valid frame is copied once and the same bytes are queued to every other seat. The sender gets no echo. The relay keeps no command history: it counts frames and bytes per seat for its end-of-match log line, and holds the pending hash values described next.

**The lead bound.** A seat may not run far ahead of the slowest other seat. The limit is that seat's last forwarded tick plus the delay plus one (`room.leadLimit`, `relay/room.go:292-303`; before a peer has sent anything its tick counts as 3, so the first frames may reach tick 8). An honest client never gets near it: it sends the frame for tick T plus the delay only after running T, and running T needed every other seat's frame for T, which passed through this room first. A frame past the limit is refused before it is counted, with the error `too far ahead` and a log line `lead bound`; the seat is dropped like any other bad sender. The bound keeps the future ticks a single seat can push into the other seats' queues small. After a rematch the bound starts over with the second `start`.

**What the relay looks at in a hash.** The relay still reads no command. It does read the hash a frame may carry: an honest client attaches the hash of tick T to the frame for T plus the delay (`room.recordHash`, `relay/room.go:305-325`), and when every seat has sent the same tick's hash the relay compares them. A mismatch is logged once per room as `DESYNC code=… tick=… groups=1,3|2` (seats with equal values share a group) and repeated in the `MATCH END` line. The relay still never rules on a desync or pauses a match: the clients end the match themselves (see "Desync detection" below), and the relay line is for whoever reads the logs. Memory stays bounded whatever a client sends: a hash that cannot complete is dropped once every seat has sent the frame for that tick plus the delay, and with the lead bound at most `delay + 1` comparisons stay open (`pruneHashes`, `relay/room.go:327-339`). ([State digest research](../reference/state-digest-research.md) explains why the verdict stays with the clients.)

**Limits.** Per client address the relay allows 16 open sockets and a burst of 10 `hello` messages refilling one per second; globally a burst of 20 `hello` messages refilling one per 50 ms, and a separate bucket for `unknown match` replies (a burst of 10 refilling one per second), beyond which it closes without answering (`relay/limits.go:12-21`, `relay/main.go:185-195`). The refusals are the errors `too many connections`, `too many joins` and `relay busy`. The address table holds 4096 entries and refuses with `relay busy` when full, so a flood of addresses cannot grow memory. The address comes from a request header named by `WARGRID_CLIENT_IP_HEADER` (IPv4 as sent, IPv6 cut to its /64); without that variable the relay has no address to count, keeps no per-address rule and applies only the global buckets (`clientKey`, `relay/limits.go:57-70`); with the variable set but the header missing or unparsable, the socket skips the per-address rules and the relay logs `client ip header unusable, per-IP limits skipped` at most once a minute (`relay.key`). The relay logs a refusal as `limit rule=… refused=<count>` (the first and every hundredth) and never an address; each refused `hello` also logs `join rejected reason=…`. The hello deadline (5 s) frees a slot whose client connected and said nothing. Known limit, kept (user, 2026-11-17; revisit at M9 hosting): production runs without the variable, so one client sending more than about 20 `hello` messages a second on new sockets can drain the global bucket and make real joins fail with `relay busy`.

**Leaving.** When a seat's socket closes, for any reason, the room tells the others `left` with that seat's last forwarded tick, removes the seat, and when the last seat is gone removes the room and logs one `MATCH END` line. The line carries, per seat, the frames and bytes sent (`seat1=9014f/471081B`), the largest frame (`seat1_max_frame`) and the most bytes in one tumbling second (`seat1_peak_bps`; the name is the log key, the value is bytes; the window restarts on the first frame at least 1 s after the last restart, so a burst across a restart is split and the value can under-report the true worst second), counted for the whole room across rematches. Section "What a slow peer does" below covers how a silent peer's socket gets closed.

**Writes.** Each socket writes through a small `sender`: with no test delay configured it is a plain asynchronous write. Two knobs exist for tests. A test delay holds every forwarded tick back while keeping frame order, and `left` waits behind the ticks. A batch interval joins ticks into one newline-separated message, which the current Godot client cannot read; the sender cuts a batch before the joined message would pass 64 KiB (`addBatch`, `relay/sender.go:63-78`), so even this test mode never makes a message bigger than one full frame.

**Draining.** On a shutdown signal the relay stops accepting connections, closes lobbies that have not started, closes parked rooms too (a park that starts during the drain closes at once), lets started matches run for `WARGRID_DRAIN_MS`, then closes everything. A match longer than that does not survive a deploy ([development notes](../development.md#relay)).

## One protocol, three checkers

The protocol is the one thing both a GDScript client and a Go server must agree on, so it is pinned outside both implementations.

- **Vectors (`protocol/vectors`).** 19 JSON files, each holding a message as text plus its parsed form, or marked invalid. The Godot wire test and the Go test `TestVectors` read the same files, and the Godot one also checks that there are exactly 19. Each side must accept the valid ones and reject the invalid ones (a fractional tick, an unknown type, a start without a seed, ...). Go must accept only the valid client messages (hello, tick, ping, over, again) and reject the server messages and invalid vectors, since a client may send nothing else.
- **Conformance suite (`protocol/conformance`).** A separate Go program that plays two or more clients against a live relay and checks exact bytes: that ticks are forwarded unchanged, that a bad frame gets an error, a close and a `left` with the right tick, that a full match refuses a third client, that settings are echoed byte for byte, that seeds are in range and vary. It has five profiles, because some behaviour needs a differently configured relay: default (53 cases, including the `over` / `again` ordering rules, the rematch round trip and the lead bound's edges), delay (2), silence (10: hello deadline, lobby survives silence and expires despite pings, start window, park limit, silence in a match; the relay runs with 300 ms hello and silence and a 1.5 s lobby), limits (3: connection cap, join rate, `unknown match` replies; the relay runs with `WARGRID_CLIENT_IP_HEADER=X-Wargrid-Test-Ip` and the cases send addresses from the documentation ranges) and global (1: the global join bucket). `sh tools/run_conformance.sh` starts one relay per profile and ended `CONFORMANCE PASSED 69` on this branch. The relay's global join bucket is fixed and has no test setting, so the suite paces its own dials 50 ms apart (`helloGap`, `protocol/conformance/client.go:21-36`); the limit cases dial unpaced on purpose.
- **Relay unit tests (`relay/*_test.go`).** Run with the race detector. They cover parse rules, join rules (a protocol mismatch outranks bad settings), concurrent joins never overfilling a room, a panic ending only its room, drain keeping a started match, a stalled reader still producing `left`, the lead bound, the hash comparison and the `MATCH END` fields, the limiter, the batch cut, and that 180 rooms (plain, rematched, rejected and abandoned) leave no goroutine and no registry entry behind.
- **Netplay scenarios (`tools/run_netplay.sh`).** Two real Godot clients, headless, through a real relay. Seventeen scenarios: a full match (terminal tick pinned, hashes equal on both sides and against an offline replay of the command log), a rematch (both seats finish, send `over` and `again`, play a second match with a new seed and end on the same tick and hashes as the first; the relay logs one `rematch` and one `MATCH END`), a peer killed, a peer that closes cleanly at tick 600 (`left-mid`: the other seat must print `NETCLIENT VICTORY left`, which the headless client prints from `Lockstep.opponent_left()`, the same rule the game uses), a 3 s stall, a 15 s silence, a relay that delays every forward by 200 ms, a deliberate desync, a version mismatch, two map scenarios, a relay killed and a relay sent SIGTERM. Four more run each seat through `tools/netfault`, a small Go proxy that sits between one client and the relay and applies a timeline of faults (cut every write into pieces of at most 7 bytes, hold both directions for a while and then release at once, reset the connection, or drop all bytes from some moment without closing): `proxy-clean` (no fault; the match must end exactly as `match` does), `proxy-burst` (seat 1 held 3.5 s from 2 s, seat 2 held 3 s from 3 s, the two holds overlapping; the match must still end on tick 9013 with equal hashes, bytes must have been held in both directions, and the relay must not call a frame too far ahead), `proxy-reset` (seat 2's connection is reset at 4 s; both seats must end within 2 s, seat 2 as relay lost, seat 1 as left) and `proxy-blackhole` (seat 2's bytes vanish from 3 s for 7 s: seat 2 must end through its own 5 s silence rule 4.5 to 6.5 s after the hole began, measured about 6.0 s because the client waits 1 s for a close first; seat 1 must hear `left` 9 to 12 s after it, through the relay's 10 s silence rule). The headless client got that 5 s rule for this (`headless_client.gd:154`), mirroring the online driver. Each proxy writes a timestamped log, and a failed run prints a repro line.

Together these make the protocol an interface any relay can be checked against. That was the use made of it in the relay stack spike: five ports against the same suite, with Go chosen to replace the first (Kotlin) relay ([relay stack spike](../reference/relay-stack-spike.md)).

## Playing again

Between matches the client keeps its socket. In `online_driver.gd` a phase string tracks it: `playing`, then on a sim-decided end (win, loss, draw) `over`, after Play again `again`, and `done` once the room is gone. `_finish` sends `over`, sets `RelayTransport.patient` (the 5 s silence rule relaxes to the 15 min lobby length, because a parked room sends nothing) and keeps the transport. `play_again` sends exactly one `again` and moves to `again`; `can_play_again` is true only in `over`, so the panel's button is disabled while waiting and a second click cannot send a second `again`; `leave` moves to `done` at once (and sets `_left`, so `notice()` shows nothing for a deliberate leave although it ends the lockstep through `set_relay_lost`), so Play again is off. A finished match has no new ticks, so `match_screen` redraws the panel whenever `rematch_line` changes. The relay's `again` for the friend is remembered (`rematch_line`: "Your friend wants a rematch", also after this client's own Play again, so answering a friend never flashes "Waiting for your friend…"); if it arrives before this client's own end, `Lockstep` hands it to the driver's `session_handler` instead of ending the match as a protocol error.

On the relay's side the second `start` also restarts the lead bound and drops every hash comparison still open (`room.rematch`, `relay/room.go:426-436`). The relay's second `start` also reaches `Lockstep.receive`, which gives it to the driver; the driver builds a new `Lockstep` (`Lockstep.for_start`, shared with the launcher) at once, so a peer's tick 4 in the same poll batch lands in the new one. `match_screen` then sees `take_rematch` return the new seed and rebuilds the world from it, with start spots from `MatchSettings.starts`. A `left` in the same batch, a closed or silent socket, or an expiry cancels the rematch ("Your friend left", "The room closed"); a friend who leaves after the end is a leave, not a relay loss, so no relay notice shows behind the panel. An abnormal end (desync, left, relay lost, protocol) never sends `over`: it closes the transport and shows today's notice with Play again disabled, so an end the relay never parked cannot be restarted. The result panel (`result_panel.gd`) shows the outcome, a status line from `rematch_line`, the match length, a table with one row per player (units built, units lost, buildings lost; the local row marked "(you)" and bold), Play again (Enter) and Back to menu; offline it always allows Play again. When the friend pressed first and this player's Play again is still enabled, the button reads "Accept rematch" (`friend_wants_rematch`); the first presser keeps the greyed "Play again" and "Waiting for your friend…". The numbers come from `Simulation.match_stats()`, counters outside the snapshot and the hash ([chapter 10](10-determinism-and-replays.md)), so both seats and a replay show the same table; the length is `tick / 30` as m:ss. While Play again is gone for good (friend left, room closed, opponent left) Back to menu takes the keyboard focus, so Enter activates it; while the panel waits for the friend's answer it does not, so a second Enter cannot leave the room, and the panel never takes focus from the open pause menu.

**Opponent left.** `Lockstep.opponent_left()` is the one rule: status `ended_left`, the leave came after the start (`left_before_start` false) and the room had two seats. The online driver's `opponent_left()` passes it through, `rematch_line` puts "Your opponent left" first, and `Hud._match_hud` turns an empty match result into "Victory" when it is true, so a player whose opponent leaves mid-match sees Victory with the stats up to the leave, Back to menu focused (unless the pause menu, the playtest form or a text field holds the focus; it takes it when they release it) and no Play again. A leave on the tick the simulation itself ends the match stays a normal outcome (`advance` returns on `match_over` first). A leave after a normal end keeps "Your friend left"; with more than two seats the rule is false and the old notice stays. The status line behind the panel still reads "Player N disconnected". The online leave confirmation says "Leave the match? Your opponent wins and the room closes." and focuses Cancel, so a stray Enter does not forfeit.

In the launcher, `RelayTransport.patient` is set at the welcome, so a host who switches tabs while waiting is not dropped by the client's own 5 s rule. The Waiting view counts down the 15 minutes (`closes in 14:59`), the relay's `lobby expired` shows "Your friend did not join in time", and while connecting the page shows "Connecting… N s" with a Cancel button; Esc cancels too, except on the Waiting page, which keeps its own Cancel. Enter in the code field joins.

## Desync detection

Every 30th tick (`hash_interval`), `finish_tick` attaches the state hash to the outgoing packet, tagged with the tick it describes. The receiver compares it when it advances through that packet's tick, and on a mismatch ends as `ended_desync` before applying that tick's commands. A divergence is therefore caught at most 33 ticks (about 1.1 s, arithmetic) after it happens. The report (`Lockstep.desync_report`) also carries `hash_ring`, the simulation's last 64 per-tick hashes; they stay on the client and are never sent. What the hash covers, the report and how to find the first differing tick and field are in [chapter 10](10-determinism-and-replays.md#how-a-desync-is-caught-and-narrowed-down). The lockstep overhead (encode, decode, digest on hash ticks) is p99 0.067 ms against a 0.6 ms budget (measured, [ledger budget table](../reference/performance.md#budgets)).

## What a slow peer does to everyone

**Lockstep window.** A seat reaches tick T only when every seat's packet for T is in. That packet was sent when its owner reached T minus delay. So one-way network delay plus jitter has to stay under about `delay` ticks (133 ms) for the game to run at full speed. Beyond that the faster machine waits on every tick and the game runs stop and go. This is derived from the code and not measured at that limit. Measured on one good link between two Macs: relay round trip p95 of 34 and 42 ms, command p95 of 191 and 205 ms, which the note attributes mostly to the delay itself ([M5 findings](../reference/m5-online.md#latency-budget-command-p95--250-ms)). The Go relay added 1.6 to 8.7 ms at p99 locally with 10 to 100 rooms, and the hosted relay answered in 11 to 12 ms at p50 from the development Mac (measured, a single home connection, indicative only: [relay stack spike](../reference/relay-stack-spike.md#latency-measured)).

**A slow machine counts like a slow link.** If a machine needs more than 33 ms per tick, its packets come late for everybody. Chapter 12 has the tick budgets; the slowest machine paces the match.

**What happens when a peer is not just slow.** Each case below is read from the code and the scenarios.

| Peer state | Who notices | Result |
|---|---|---|
| Slow but alive (still pinging) | nobody; the others show "Waiting for player N" | others wait with no time limit: nothing in `advance` times out while the relay connection is healthy |
| Frozen for a few seconds (the `stall` scenario, 3 s) | nobody | packets arrive late and in a burst; catch-up credit rations the replay; both finish with equal hashes |
| Silent for over 10 s in a running match (no packets, no pings: the `silent` scenario, 15 s) | relay read deadline (`WARGRID_SILENCE_MS`, default 10 s, from the seat's first tick) | relay closes that socket, others get `left`; the scenario asserts that this happens within 12 s |
| Socket closed or process killed | relay at once | others get `left` with the last tick forwarded |
| Stops reading (full TCP buffer) | relay write deadline, same timeout | socket closed, `left`; `TestStalledPeerStillProducesLeft` (the stalled seat keeps sending, so neither the read deadline nor the lead bound fires; the test fails if the lead bound is what ended it) |
| Runs far ahead of its peer (a modified client) | relay lead bound | `error` `too far ahead`, socket closed, `left` for the others; the `lead bound` log line, conformance `lead_bound_*` and `racing_ticks_rejected` |
| Held up in transit, then released in a burst (the `proxy-burst` scenario, 3 to 3.5 s holds) | nobody | both sides wait, then catch up; the match ends on tick 9013 with equal hashes and the relay logs no `lead bound` |
| Connection reset by the network (`proxy-reset`) | the relay at once, the client by the closed socket | seat 2 `ended_relay`, seat 1 `ended_left`, both within 2 s of the reset |
| Bytes silently dropped, socket still open (`proxy-blackhole`) | the client's 5 s silence rule (relay lost); the relay's 10 s rule for the other seat | seat 2 `ended_relay` "connection to relay lost", seat 1 `ended_left` |
| Reads, but slower than the room sends | relay write-queue cap: more than 1 MiB waiting for that socket | socket closed at once, `left`; `TestSlowReaderBacklogIsCapped` |
| Relay unreachable | each client: a socket close, or the silence timer (5 s without any frame, pongs count) | `ended_relay`, "Connection to relay lost"; the `relay-down` scenario (relay killed) asserts both clients end within 2 s |
| Sends bad frames | relay, or the receiver if the relay passed the frame | relay-detected: `error` to the sender (`ended_relay`), `left` to the others (`ended_left`); receiver-detected: `ended_protocol` on that receiver |

Clients ping the relay once per second after their first send, so a healthy but idle connection keeps both timers fresh. The headless netplay client applies the same 5 s silence rule as the game (`headless_client.gd:154`), so the blackhole scenario can end a seat the way a player would be ended. The online driver never pauses the simulation (`pauses_sim` is false), so a peer is running, waiting or gone; there is no pause rule.

**`left` ends the match.** When a seat leaves, the others can still run ticks up to the leaver's last forwarded tick, because those packets are in hand. When the simulation needs the next tick, or a packet is missing, lockstep ends the match as `ended_left`. There is no pause, no bot takeover and no reconnect. "Dropped player becomes a bot" and reconnect with command-log replay are on the M9 list (proposed, not built: [M5 findings](../reference/m5-online.md#m9-list)). A leaver before the start means a refused map or version, and the HUD says so.

## Trade-offs and limits

**Why a relay and lockstep rather than a server that simulates.** The relay never sees a unit, so its cost grows with frames and rooms, not with army size: 5.2 % of a shared vCPU for one 3v3 room in the Go build (measured, [relay stack spike](../reference/relay-stack-spike.md#cpu-per-3v3-room-measured)). Authoritative-server simulation was the blueprint's fallback in case lockstep failed the M5 gate; lockstep passed ([blueprint §11](../blueprint.md#11-performance-multiplayer-and-future-architecture)). The cost moved to the game: every machine must stay bit-identical ([determinism rules](../reference/determinism-rules.md)), and every client holds the full state, so a modified client could read hidden information (the blueprint notes this for bots). The relay is for private matches with friends ([relay scaling](../reference/relay-scaling.md)); a public game would need more.

**Input delay is a constant.** The relay hard-codes 4, and the client takes whatever start says. With the stamp at delay + 1, command latency is bounded below at about 167 ms before any network time. The M5 note records that a farther link would exceed the 250 ms budget, and lists dynamic delay for M9 (not built). Raising it is a change to one relay constant (the conformance suite pins 4 as well) but makes every game feel slower.

**Hash checks are sparse and final.** One hash per 30 ticks keeps lockstep overhead tiny, but a desync can hide for about a second (at most 33 ticks), and the match then simply stops. There is no repair, rollback or resync. The report exists so a developer can find the first differing field.

**The packet-per-tick rule limits what the relay can do.** It forces every seat to send 30 frames a second even while idle, and it ties the relay's checks to the exact tick sequence. A batching mode (one message per interval) halves relay CPU in measurement but adds half an interval of latency (+18 ms p50 at 33 ms; [relay stack spike](../reference/relay-stack-spike.md#batching-measured-go-idiomatic-wargrid_batch_ms33)) and needs a client that can read it.

**Packet size is bounded by the frame cap.** All commands queued since the last packet go in one frame, and the client does not split a packet. A frame over 64 KiB is refused by the relay as an invalid message and by the receiving client as a protocol error. The client now keeps its own packet under that cap: `Lockstep.submit` refuses an order that would push the queued commands past the frame cap minus a 256-byte reserve for the envelope and hash (`FRAME_RESERVE_BYTES`, `game/scripts/net/lockstep.gd:8`, `:71`) and returns false, taking no sequence number. The online driver turns the refusal into an answer, and the screen shows the HUD note "Rejected: Too many orders at once; wait a moment" (`online_driver.gd:14`, `:174-178`, `match_screen.gd:155`); the order is dropped, not queued for later. A send the WebSocket itself refuses closes the transport (`RelayTransport._check_sent`, `relay_transport.gd:44-50`), because a lost frame would leave a tick gap the relay rejects; the match then ends as relay lost, "Connection to relay lost".

**WebSocket send delay was measured, and none was found.** On native loopback, a headless pair played a full `match` (18,260 frames): a client's send reached the relay in a median 41 µs (p95 62 µs, max 547 µs), and the relay's forward reached the other client in a median 2.2 ms (p95 8.5 ms), bounded by the receiving client's frame time, not the network. On the web export two Firefox windows through the live relay gave 12,523 send-to-receive pairs, p50 18 ms, p95 35 ms, p99 46 ms, one 314 ms outlier and no cluster near 40 or 200 ms; the split per leg is not measured ([netplay reference review](../reference/netplay-reference-review.md#gaps-and-unverified-points)).

**Fixed integer field list.** `Wire.decode` converts integers only in named command fields, plus the lists `entity_ids` and `origin`. A new command with a new integer field must be added to that list, or it stays a float on both machines and fails validation consistently (speculation on the exact symptom; the code requires integers for ids, tick, player and sequence).

**Capacity and availability are host questions.** Rooms live in one process's memory; a relay crash ends every live match, and the high-availability options (rebuild rooms from clients, mirror state) are proposed in [relay scaling](../reference/relay-scaling.md#high-availability-options-proposed-2026-11-05) and not built. 3v3 online and a lobby are milestone M9, not built; the blueprint says a lobby needs relay protocol 3 because the seat count is global today ([blueprint M9](../blueprint.md#m9--3v3-online)). The outbound queue per connection is capped at 1 MiB waiting (2026-11-12): the `gws` library's own queue has no limit, and the write deadline only bounds one write, so before the cap a peer that read slowly but steadily grew the relay's memory without bound (reproduced: 122 MB kept for 120 MB sent, on a 256 MB machine).

**Cross-platform identity is evidenced, not assumed.** macOS, Linux and Windows exports produced identical netplay traces in the M5 gate (364 rows matched); a mismatch would show first as a desync here. See [M5 findings](../reference/m5-online.md#answer).

## Where in the code

- `game/scripts/net/lockstep.gd` — `Lockstep`: `submit`, `receive`, `advance`, `finish_tick`, `waiting_for`, `can_step`, `desync_report`, `for_start`, `session_handler`, `opponent_left`; statuses; constants `MAX_QUEUED_TICKS`; private `_receive_tick`, `_verify_hashes`.
- `game/scripts/net/wire.gd` — `encode`, `decode` (also `over`, `again`), `tick_message`; `PROTOCOL`, `MAX_FRAME_BYTES`; required-field and integer-field tables.
- `game/scripts/net/relay_transport.gd` — `RelayTransport`: WebSocket peer, `poll`, `send_text`, once-a-second ping, 5 s silence (`silent`, 15 min while `patient`), `LOBBY_EXPIRY_SEC`, round-trip samples.
- `game/scripts/net/seat_sim.gd` — wrapper so bot and script code drive a networked seat through `Lockstep.submit`.
- `game/scripts/net/headless_client.gd` — the netplay test client: seat scripts, stall, kill and perturb hooks, command-log replay.
- `game/scripts/match/online_driver.gd` — online driver: `submit`, `step` (poll, catch-up credit, `finish_tick`; returns nothing: the answers to our orders, built from the command log and the local simulation's rejections in `Lockstep.advance`, come from `take_answers()`; each ticked step also posts a `step = false` pump job that publishes the view and note), `request_preview` / `preview_answer` (the placement ghost, answered after a step that ran), the phases and `play_again`, `take_rematch`, `rematch_line`, `opponent_left`, `rematch_pending`, `notice`, desync report writing, latency line. `match_screen.gd` `setup` creates it.
- `game/scripts/launcher.gd` — hello, welcome and start handling (`_connect`, `_handle`, `_start`); shows the Waiting view after a welcome and locks the sidebar and page controls while connecting or waiting (`_set_busy`; a failure or Cancel match unlocks it); countdown, Cancel, Enter and the did-not-join text; builds the `Lockstep` object (`Lockstep.for_start`) and starts the match scene with it.
- `game/scripts/match/result_panel.gd` — `ResultPanel`: outcome, status, length, stats table, Play again, Back to menu, the focus rule (`show_result`, `takes_enter`, `length_text`); `game/scripts/match/hud.gd` `_match_hud`, `_result_rows` (feed it); `match_screen.gd` `_play_again`, `_rematch`.
- `relay/main.go` — WebSocket handlers (`OnMessage`, `OnClose`), the `deadline` type, hello, silence and write deadlines, write-queue cap (`writeLater`), `reject`, shutdown and drain.
- `relay/room.go` — `registry` (create, join, remove), `room.run`, `admit`, `start`, `forward`, `expire`, `onOver`, `onAgain`, `park`, `rematch`, `leave`, `recoverCrash`; constants `protocol`, `inputDelay`, `expiryGrace`.
- `relay/envelope.go` — `parseEnvelope`, `parseHash`: what a client may send; size caps.
- `relay/sender.go` — per-socket write queue; test delay and batch modes (`addBatch` cuts at 64 KiB).
- `relay/limits.go` — `limiter`: per-address sockets and joins, global buckets, the bounded address table, `clientKey`.
- `tools/netfault/` — the fault proxy for the `proxy-*` netplay scenarios (`proxy.go`, `main.go`; stdlib only).
- `protocol/vectors/*.json` — the message vectors; `protocol/conformance/conform.go` — the case lists and profiles; `tools/run_conformance.sh`, `tools/run_netplay.sh`, `tools/desync_diff.py`, `tools/desync_bisect.py` — runners.
- `game/tests/test_lockstep.gd` (L15-L17 opponent-left rule, L18 stats mirror and replay, L19 pending-frame cap pinned to the reserve, L20 an undecodable own frame ends the match), `test_wire.gd`, `test_relay_transport.gd` (T7 a refused send closes the socket), `test_online_scene.gd` (N29 opponent left mid-match, N-cap the HUD shows a refused order) — the client-side tests.

## Further reading

- [M5 online findings](../reference/m5-online.md) — what broke, latency and lockstep overhead numbers, the M9 list. Its relay description predates the Go port.
- [Relay stack spike](../reference/relay-stack-spike.md) — why Go, relay CPU and latency measurements, the patterns adopted.
- [Relay scaling](../reference/relay-scaling.md) — routing and availability options (proposed).
- [Playing online](../playing-online.md) — the player's view and status lines.
- [Determinism rules](../reference/determinism-rules.md) and [state digest research](../reference/state-digest-research.md) — what the hash must cover.
- Previous: [10. Determinism and replays](10-determinism-and-replays.md). Next: [12. Performance and platforms](12-performance-and-platforms.md). The tick that lockstep gates is in [4. The tick](04-the-tick.md).

---
Checked against `275b399` for the relay guards passages (lead bound, hash comparison, limits, batch cut, client cap, proxy scenarios), the limits paragraph against `d94f880` plus the 2026-11-17 fix round (unusable-header warning); `f46993b` for the online driver's `step` and answers; `0b1e03e` plus the gate-1 fix round and the leave notice and Accept rematch changes (3b21ffc plus the working tree) (P2.2 slice 2: opponent-left rule, result panel statistics and focus, `left-mid`); the rest against `e166e8d` plus the gate-1 fix round; the `online_driver.gd` answers and preview passages against `314f487`; the last-frame rule against `785047b` plus the sealed sender. Files: `game/scripts/match/match_screen.gd`, `game/scripts/net/lockstep.gd`, `game/scripts/net/wire.gd`, `game/scripts/net/relay_transport.gd`, `game/scripts/net/seat_sim.gd`, `game/scripts/net/headless_client.gd`, `game/scripts/match/online_driver.gd`, `game/scripts/launcher.gd`, `game/scripts/match/result_panel.gd`, `game/scripts/match/hud.gd`, `relay/main.go`, `relay/room.go`, `relay/rematch_test.go`, `relay/deadline_test.go`, `relay/envelope.go`, `relay/sender.go`, `relay/envelope_test.go`, `relay/stall_test.go`, `relay/queue_test.go`, `protocol/conformance/conform.go`, `protocol/vectors/tick.json`, `tools/run_conformance.sh`, `tools/run_netplay.sh`, `relay/limits.go`, `tools/netfault/proxy.go`
