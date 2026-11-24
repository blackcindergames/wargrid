# Online teams: refinement of M9 into packages (2026-11-16)

Planning record, not an implementation plan. It splits blueprint [§7 M9](../../blueprint.md#m9--3v3-online) into packages so friends play together online sooner. Decisions are the user's (questionnaire, 2026-11-16, [design answers](../../reference/design-answers-2026-11-08.md#online-teams-refinement-user-2026-11-16)); package ids, the night names, P7's name and the P11 slot are the agent's proposals, approved with the arrangement; P8, P9 and P11 were renamed by the user after the player-experience review. Placement in [packages](../../packages.md), state in [STATUS](../../STATUS.md#packages).

## What players can do today (code, `main` 778f449)

- Offline: you against one bot (`launcher.gd:357-363`, `offline_driver.gd:27`, seat 2 `ai` in `skirmish.gd:48-50`).
- Online: you against one friend; Create, send the link, the match starts when the friend joins; Play again keeps the room (P2.2 slice 1). No bots online: `online_driver.gd:67` builds two human seats.
- One leave ends the match for everyone (`lockstep.gd:104`, `:220-225`; one `_left_seat`, `:30`).
- The relay's seat count is global (`WARGRID_SEATS`, default 2, `relay/main.go:185`), a room starts when full (`relay/room.go:219-220`), no lobby messages (`envelope.go:84-112`); `settings` hold map and map hash only (`match_settings.gd:17-18`), factions arrive as commands after the start (`online_driver.gd:71`).
- The simulation already plays teams: a team survives while one of its seats owns a victory building (`simulation.gd:153-165`); 3v3 exists only as an all-bot benchmark scenario (`debug/team_match.gd`, `combat_workload.gd`). Eight owner colours (`palette.gd:3-6`). Starts: Ashfall 8, Broken Crown 4, Dry Wells 2.
- A refused join shows the raw relay reason, for example "build mismatch" (`launcher.gd:470-472`, `room.go:202`).
- Bot orders in another seat's frame: the relay passes them (`room.go:247` checks only the frame's seat; `envelope.go:97-103` never reads a command's `player`), but lockstep ends the match with "bad command stamp" when a command's `player` differs from the sending seat (`lockstep.gd:209-212`), and `submit` stamps every command with the own seat (`:66`). The simulation checks only that each player's `sequence` rises (`simulation.gd:210`).

## Player journey (decided, user 2026-11-16)

1. Play page: the host sets up the match before Create match: the map (only maps with at least as many starts as seats) and each bot's faction. The mode is picked in one row, `vs Bot · vs Friend · With a friend vs 2 bots`, so 1v1 against a friend stays beside co-op; no A/B (user, 2026-11-21, [fun-first prep](../../reference/design-answers-2026-11-08.md#fun-first-prep-user-2026-11-21)). The friend joins with the link and picks a faction; the match starts when everyone has joined. No ready step until P11.
2. Teammates start on neighbouring spots ([lobby questions](../../questions/next-m9-lobby.md) Q1 b).
3. Play: the host's game runs the bots and sends their orders in its own frames (OpenRA's model); from P8, the lowest remaining seat takes the bots over when the host leaves.
4. A defeated guest keeps watching and may leave without ending the match (from P7). In P7 the host leaving, defeated or not, ends the match with the reason shown; a defeated host's leave confirmation says so.
5. A dropped player (P8): after a short stall the game freezes for everyone with a 60 s countdown and a good, moderate or poor ping per player. Texts: the others see "Waiting for X (connection lost or game in background)", the dropped player "Reconnecting…". A Leave match button says what leaving does. Play resumes when the player reconnects. Relay restart recovery and its text "Server restarting, reconnecting…" left P8, and a reloaded tab or a crashed game counts as leaving (user, 2026-11-16, [relay availability](../../reference/design-answers-2026-11-08.md#relay-availability-questionnaire-user-2026-11-16)). A relay crash ends the match; its text is decided in P8's design. After 60 s the match ends until P10; from P10 the base goes to a teammate.
6. A teammate quits: until P10 the match ends with a result panel headed "Match ended", no winner, naming who left, teammate or opponent (`<name> left the match`); the reasons (quit, connection lost, did not return in 60 s) come with P8 (user, 2026-11-21, [fun-first prep](../../reference/design-answers-2026-11-08.md#fun-first-prep-user-2026-11-21)); Play again is hidden then, Back to menu stays. From P10 their units, buildings and money go to a teammate (Zero Hour's quit rule).
7. Result: Play again keeps the room, seats and settings when every human is still there (P2.2); Back to menu leaves. Once relay workers drain before a deploy, Play again is off on a draining worker ([relay availability](../../reference/design-answers-2026-11-08.md#relay-availability-questionnaire-user-2026-11-16); not placed).
8. Version mismatch: a plain message instead of the relay reason, wording and look from a static mock-up checked by the player-experience reviewer, no A/B (user, 2026-11-21, [fun-first prep](../../reference/design-answers-2026-11-08.md#fun-first-prep-user-2026-11-21)).
9. P9, a friend never joins: the waiting view lists who is missing and the expiry; the host can turn an empty friend slot into a bot and start; a joined friend can leave and free the seat.

## Package sequence

| Id | Name | Lane | Position | Gives players |
|---|---|---|---|---|
| night 7 | Play on after a leave | night | between P2.3a and P7 | a defeated seat that leaves no longer stops the others |
| P7 | Team up against bots | day | after P2.3a (after P2.3b since the [fun-first reorder](2026-11-20-fun-first-reorder-design.md), user, 2026-11-20) | you and a friend against two bots online; offline team matches with an allied bot |
| night 8 | Relay guards | night | between P7 and P2.3b (contents unchanged) | abuse limits; its fault proxy runs P8's scenarios |
| night 9 | Adaptive input delay | night | between P2.3b and P8 (contents unchanged) | one agreed delay, adopted only on a measured gain |
| P8 | Reconnect after a drop | day | after P2.3b | a dropped player no longer ends the match |
| night 10 | Lighter relay frames | night | between P8 and P9 (between P8 and P13 since the backlog review) | fewer relay messages per second; fly machine sized with 1, 2 and 4 rooms |
| night 11 | Cheaper step | night | between P8 and P9 (contents unchanged; between P14 and P9 since the backlog review) | cheaper ticks before the 3v3 gate measures them |
| P9 | You and two friends vs three bots | day | after P8 | 3 humans and 3 bots on Ashfall: the M9 exit gate |
| night 12 | Bot attack test | night | between P9 and P10 | evidence only: which launch rule gets armies to buildings |
| P10 | Keep your teammate's base | day | after P9 | a quitter's or dropped player's base goes to a teammate |
| P11 | Friends against friends | day | after P6 | a room: join, host may change map, everyone ready, host starts; humans on both sides |

Two nights sit between P8 and P9, one exception to the one-night rule (user, 2026-11-16); the backlog review the same day placed P13 More maps and P14 Desync reports there, so each night has its own gap and the exception is gone. Earliest benefit: P7, two packages from now. Cost: P2.3b moves back one package; P5, P2.4 and P6 four; P2.5 onward five.

## Dependencies

| Package | Needs | Kind |
|---|---|---|
| P7 | night 7 | quality: without it a defeated guest's Back to menu ends the survivor's match |
| P7 | P2.3a | inherited (user, 2026-11-16, placement); not technical |
| P7 | lockstep change | technical: a per-seat set of allowed players fixed at the start replaces the stamp check at `lockstep.gd:305-308`; `submit` takes an explicit player; one sequence counter (`_sequence`) numbers every order the seat submits, the bots' too (the simulation checks only that each player's sequence rises; built so, not a counter per bot), and bot orders stay out of the host's latency bookkeeping (`record`). Not a relay change: the room stays at two seats |
| P7 | M8 bot, fog, ground batches, P5, P6, art | none: today's bot is good enough for the first co-op release (user, 2026-11-16) |
| P8 | Relay guards | technical: its fault proxy is how the resume scenarios are run |
| P8 | protocol 3 | technical: a resume token in `welcome` and a relay replay buffer |
| P9 | P8 | quality: the order is kept (user, 2026-11-16), since without seat resume one dropped connection ends a 3v3 for six seats; the first reason, relay restart recovery before 3v3, went when recovery left P8 the same day |
| P9 | Lighter relay frames, machine sizing | technical: one shared vCPU holds about one 3v3 relay room ([relay scaling](../../reference/relay-scaling.md)) |
| P9 | Adaptive input delay, Cheaper step | quality: the experiments must have run; adoption still only on a measured gain |
| P9 | per-room seat count | technical: protocol 3 |
| P10 | night 7, P8 | technical: transfer happens after a leave or after the grace runs out |
| P11 | P10 | inherited order (agent placement, approved with the arrangement); backend option A or B compared in its design |

## Acceptance gates (proposed, refined in each package plan)

Every package: suite, lint and warnings; `sh tools/run_benchmark.sh` row; traces and netplay pins unchanged unless the package re-pins them on purpose. Relay changes: `go test -race ./...`, `golangci-lint run`, `sh tools/run_conformance.sh`, affected `tools/run_netplay.sh` scenarios; relay deploys need approval.

- **Night 7, Play on after a leave:** lockstep tracks a set of left seats. End rule, decided at the leave's `after_tick` from simulation state so every client agrees: the match plays on only when the left seat owns no victory building there (defeated) and its team or another seat still plays; otherwise it ends as today, so a 1v1 leave still shows P2.2's "opponent left" panel ([F27](../../STATUS.md#findings-list)). Netplay scenarios: a defeated seat leaves and the others play to a result; an undefeated seat leaves and the match ends as today; a 3-seat run with two leaves in either order (reproduce the overwrite first, [blueprint M9](../../blueprint.md#m9--3v3-online)). No trace re-pin; stop if any existing pin moves.
- **P7:** the stamp change above with tests (a bot command from a seat not allowed to issue it still ends the match); headless 2v2 netplay (two clients, two host-run bots) with equal digests and a pinned trace; offline 2v2 trace; same-tick cases for bot orders in the host's frame against the host's own orders and against a leave; a defeated guest leaving lets the survivor finish; the host leaving ends the match with its reason; Play again hidden after a quit; start spots side by side (SS7 not re-pinned: `StartSpots.assign` already places teammates side by side); maps under 4 starts hidden for 2v2; headless launcher layout tests for every slot row. Rendered 2v2 Ashfall row. Playtest: a real friend session, native Mac and Firefox, with the timed hidden-tab check; Safari and Chrome report-only.
- **P8:** proxy scenarios (a blackhole under 60 s resumes with equal digests; over 60 s ends); host-leave hands the bots to the lowest remaining seat; the two waiting texts, the stall delay and Leave match in headless layout tests. Playtest: cut the network mid-match and come back.
- **P9:** the M9 exit gate, a real 3v3 match with friends without desync; 3-client headless netplay with 3 host-run bots; the no-show path (missing list, bot swap, a joined friend leaving); relay machine measured with 1, 2 and 4 rooms; Mac rendered and headless 3v3 rows inside budget or reported as exceeded; Deck Firefox report-only ([F13](../../STATUS.md#findings-list)); whether a browser or Deck player may host three bots is measured and decided here.
- **Night 12, Bot attack test:** stock, gate and commit (0 A.D. Petra's style: commit, never call back, fall back to any remaining building, larger later waves) on Dry Wells, Broken Crown and Ashfall, both slots, several seeds. Two columns: every seat damages an enemy building on rows where stock fails, and rows that end today still end. A rule ships only if it passes both (user, 2026-11-16); if none does, report both columns and ship nothing. Evidence only.
- **P10:** a transfer command with same-tick cases (against the receiver's own defeat, against a building completing, against a second leave); quit and grace-over both transfer; no living teammate leaves the base idle.
- **P11:** layout candidates as a [War Room](../../../warroom/README.md) round built on the sidebar launcher's [mock-ups](../../images/launcher-mockups/) (no ready-room mock-up exists); any setting change clears ready; full, expired and mismatched rooms tested.

## Design inputs from the player-experience review (proposals, not decided)

- P7 (decided except the version message, user, 2026-11-21, [fun-first prep](../../reference/design-answers-2026-11-08.md#fun-first-prep-user-2026-11-21) 7-26 to 7-29): the setup lists every bot slot, allied ones too (yes); the invite link could carry map, host faction and bots so the friend sees them on Join (no relay change; no, it carries no settings); one line under the map field when a remembered 1v1 map is hidden for 2v2 (yes, muted); a 3 to 5 s start countdown with a sound (Zero Hour counts 5 s), which is not a ready step (no, it stays P11); the version message names the fix (reload or update) and a later host-side notice.
- P8: the stall delay before the waiting screen is picked at design between the planned peer notice's 2 s and Zero Hour's 5 s ([dropped players](../../questions/next-m9-drops.md) Q1). After the relay availability answers (2026-11-16): when a resume is refused with `unknown match` because the relay lost the match, end at once ("The server lost this match. Start a new game from Play.") instead of showing "Reconnecting…" for 60 s; the result panel's reasons in step 6 gain "game closed or reloaded". Decided (user, 2026-11-16): in P8 the browser build asks before a reload or a close while an online match runs.
- P9: show who has pressed Play again.
- P10: the receiver is told ("You now control X's base and money"); a player returning after 60 s gets a panel saying their base went to Y.
- Fog of war: what a defeated player sees once fog exists, decided before P11 (Zero Hour gives the whole map).

## Where every M9 requirement goes

| Requirement (blueprint M9 and overlaps) | Owner |
|---|---|
| 2 humans plus bots online, offline teams | P7 |
| Bots on online seats | P7 (host runs them), P8 (handover) |
| Continue after a permanent leave, left-seat set, 3-seat double leave | night 7 |
| Seat resume, waiting screen, peer quality notice | P8 |
| Relay restart recovery (availability option B), coming back after a reload or a crash | Later, unplaced (left P8, user 2026-11-16) |
| Per-room seat count, 3 humans, exit gate | P9 |
| Relay frames per second, machine sizing, per-seat byte budget | night 10 |
| Lead bound, relay hash comparison, per-IP limits, fault proxy | night 8 (unchanged) |
| One agreed input delay | night 9 (unchanged) |
| Drop policy: base to a teammate | P10 |
| Ready, host start, map change in a room, humans on both sides, lobby backend A or B, A/B layout | P11 |
| Bot difficulty and play style in the setup | M8.1 (one level and one style for all bots, allies included) |
| Team vision | Fog of war |
| Quick rematch, opponent-left panel (F27) | P2.2 (unchanged) |
| Desync reports that send themselves | unchanged, not a 3v3 prerequisite |
| Hardening: `parseEnvelope` fuzzing, netem run, nightly tier, browser through the proxy | M9 remainder, after P9 |
| Several relay machines, history, accounts, public list, chat, observers, permanent friend link | Later, unplaced |
| Bot launch rule | night 12, then a day package only if a rule passes both columns |

## Deferred and remaining decisions

- A bot taking over a dropped player's base: not chosen (no engine studied does it; private bot research note).
- A hidden server seat that runs the bots, for a much stronger bot later: the user's idea (2026-11-16), to evaluate at M8 planning; costs a simulation per room on the server.
- Lobby backend for P11: option B stays the direction (user, 2026-11-09); P11's design compares it with the relay-only option A.
- Relay availability (user, 2026-11-16; [answers](../../reference/design-answers-2026-11-08.md#relay-availability-questionnaire-user-2026-11-16)): relay restart recovery is not in P8, since matches are short and players can start again, and P8's resume message is shaped so recovery can be added later without another protocol version; proposed from the [research](../../reference/relay-scaling.md#research-for-p8-2026-11-16), not decided: the message carries the last tick held per seat; P11's design plans two lobby instances, so its store must allow two writers.
- Open in package designs: the 60 s grace against measured reconnect times (and as a per-seat, per-match total with at most two drops; user, 2026-11-16, Hypersomnia review (private)), the P11 A/B, the review proposals above; for P8's spec (user, 2026-11-16, Zero-K review (private)): an inactivity "claim win" button as an alternative to the 60 s auto-end.
