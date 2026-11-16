# Core movement and core avoidance: design (P5, P6)

Status: approved (user, 2026-11-14); the decisions it rests on are the user's, recorded in [design answers](../../reference/design-answers-2026-11-08.md#movement-design-p21-rider-user-2026-11-14) and the sections linked below. Writing or approving this design does not start P5. Rider of P2.1 ([packages](../../packages.md)).

## Why

Units today are points on a four-way grid of building cells; nothing collides ([guide ch. 6](../../guide/06-movement.md)). Playtesters see zigzag routes and units that move "strangely"; big moves pile up, and units overlap. The user's priority for movement (2026-11-10): **units never get stuck, and it stays fast**, both ahead of exact Zero Hour parity; the feel goal is a polished modern RTS that keeps Zero Hour's weight (turn rates, rolling wheel turns, acceleration and braking stay as in `locomotion.gd`).

Two day packages deliver the core, behind one offline toggle key, so the new movement can be felt and measured beside the old before it becomes the default:

- **P5 "Units that find their way"**: new route base. Routes at any angle on a rectangle navmesh, bodies that do not clip corners, parked units that movers go around, every unit of a big order moving within a tick or two.
- **P6 "Units that make room"**: moving units get past each other as soft movers instead of overlapping.

## Goals

- P5: a big order gets every unit moving within one or two ticks (today 8 routes per tick, about 1.3 s for the last of 300 units); straight, any-angle routes; no corner clipping at vehicle width; parked units are detoured; no unit is ever stuck for good; every benchmark row stays inside its current budget with the toggle on.
- P6: moving own and allied vehicles push and are pushed instead of overlapping, crowds settle (pressure damping), parked friends step aside; at most +0.5 ms per tick on each of the six 300-unit rows ([unit avoidance: scope](../../reference/design-answers-2026-11-08.md#unit-avoidance-scope)).

## Non-goals (advanced packages, Later 3 and 4)

Local mesh updates, three size classes, shared group searches or flow fields, formations and keep formation, arrival spreading and pressure tuning, crusher rules, soft spreading among infantry, the toggles becoming defaults, golden scenarios. Cut and order: [Advanced packages](#advanced-packages).

## Anti-goals

- A unit that never arrives because it is stuck (an order fails only when no path exists; Zero Hour, `AIStates.cpp:1880-1895`).
- A tick-time win bought by loosening a budget or the assumed browser slowdown.
- Results that depend on iteration order, Godot's undocumented heap tie-breaks or platform maths ([determinism rules](../../reference/determinism-rules.md)).
- Snappier units: Zero Hour's weight stays.
- Online behaviour change before the toggle becomes the default.

## Constraints

- Simulation stays typed GDScript, tick-driven, deterministic; only `sqrt` from libm; new tests use only the [simulation interface](../../reference/sim-interface.md) (`tools/test_sim_boundary.py`).
- Budgets and the browser target: [performance ledger](../../reference/performance.md). Measuring host: the Mac mini.
- The toggle is offline only (user, 2026-11-14): online matches keep the old movement until the default flips, so the online trace and the relay are untouched.
- Old movement stays bit-for-bit as today with the toggle on "old": all existing traces and pinned tests stay green without re-pins in P5 and P6.

## Approaches

The base method was chosen provisionally on 2026-11-10 from the pathing timing spike (`docs/reference/pathing-timing-spike.md` on branch `spike-pathing`, `70026c5`), on Ashfall at width 2:

| | A: finer grid + straightening | B: rectangle navmesh | C: flow fields |
|---|---|---|---|
| one long route p50 / p95 (Mac) | 1.78 / 6.66 ms | 0.16 / 0.40 ms | 25.7 ms per corridor field |
| memory per width | 11.7 MB | 0.9 MB | 0.7 MB per live field |
| path length vs A | reference | +2 % median, +29 % worst | not measured |

**Chosen: B**, with A kept as the reference that B's paths are checked against and as the fallback if B fails P5's stuck check. C does not fit a browser tick share per goal in GDScript; it may return in advanced movement for big orders only.

How parked units enter the search (user, 2026-11-14), after a source reading of OpenRA, Warzone 2100, Recoil, 0 A.D., Permafrost and Zero Hour (summary in the design answers):

1. **Two layers (chosen):** the mesh knows buildings only; parked units live in a reference-counted fine grid; a short local search on that grid detours a mover whose next straight stretch is blocked. Every navmesh or hierarchical engine read does this shape (long layer blind to units, short layer sees them).
2. Two layers plus a per-rectangle cost for parked friends (Zero Hour's 3 diagonal steps): rejected, the search inputs would change on every stop and start.
3. Carve parked units into the mesh: rejected, no navmesh engine read does it; the mesh would churn in every fight and at every dock.

## Design: shared parts

### The toggle

One key, three states, cycled: **old** → **new movement** → **new movement plus avoidance** → old. Offline matches only (the key does nothing online); the state shows on the F3 overlay. Switching re-routes every moving unit under the new state at the next tick (no in-flight state is converted). The switch is a local command in the offline command log, never sent to the relay (agent's call after the builder check), so an offline replay repeats every switch; it needs the same-tick cases of any command. The key itself is a builder's call (not one of A, G, S, E, F2, F3, Esc, digits, arrows). The state is a simulation setting read through the simulation interface, not a branch inside systems: a movement provider chosen per match.

### Fine grid and units of measure

Pathing cells are 2 × 2 per building cell (12.5 Zero Hour units; decided 2026-11-10). Ashfall becomes 388 × 374 fine cells, so the 256-per-side assert in `grid_navigation.gd` rises to 512 for the fine grid (the coarse grid keeps its own). The fine grid holds, per cell: static blocked (buildings, cliffs, supply sources) and a parked-unit reference count, split by owner and by infantry or vehicle, so a query can ask "blocked for this unit": parked enemies and parked friends block; parked infantry never block moving infantry (Zero Hour rule, `AIPathfind.h:51`, applied from P5 on).

**One source of truth per state (agent's call after the builder check):** in the new states every reachability and walkability question (`component_at`, `is_walkable`, the allocator's candidate cells, `_replace_union`'s blocked check, supply and dock slots, container exits, combat approach cells, construction) is answered from the vehicle-dilated fine grid through the movement provider, and every route request (also those that supply, containers and combat push onto `_path_queue` today) goes through the provider's queue. Goal slots stay one per building cell, snapped to the nearest open dilated fine cell. The old state keeps today's coarse queries untouched. This touches supply, containers, combat and construction, the main size risk of P5.

## P5: core movement

### Mesh

- One rectangle navmesh at **vehicle width** (2 fine cells; user, 2026-11-14): the static blocked grid dilated by the vehicle half-width, then covered by rectangles, split into tiles as in the spike's `rect_mesh.gd` (the spike code on `spike-pathing` is a reference, rewritten to the project's standards).
- Infantry use the same mesh in P5 and so lose gaps narrower than a vehicle until size classes arrive (accepted).
- **Full rebuild** whenever the static blocked cells change (building placed or destroyed, supply source removed, terrain replaced): about 17 ms on the Mac, about 90 ms projected for the browser (accepted for P5; user, 2026-11-14). P5's focus card warns the player of one hiccup per building. Every change re-queues routes as today (`_replace_union`).

### Search

- Our own typed GDScript A* over mesh rectangles with an explicit tie-break (f, then g, then node index) ([simulation reference review](../../reference/design-answers-2026-11-08.md#simulation-reference-review-user-2026-11-13)), **if fast enough**: P5's first measurement compares it against Godot's `AStar2D` on the same mesh with the spike's 200 pairs (review X3). If it is too slow, `AStar2D` stays and the cross-platform test below decides whether its tie-breaks are acceptable.
- Cost is the Euclidean distance between portal points (only `sqrt`); a heuristic that is admissible on rectangles.
- **Deferred delivery under a searched-node budget:** a request at tick T is served at T+1 at the earliest, in (request tick, unit id) order; a started search finishes; no new search starts once the tick's node budget is spent. Search inputs are frozen until delivery; undelivered requests are simulation state in the snapshot and the state hash.
- **One search per (start rectangle, goal rectangle, tick)**, dropped at the end of the tick, so who shares depends only on those and request order (agent's reading of the 2026-11-13 "one search per goal" after the builder check: each unit has its own goal slot, so sharing by slot would share nothing). A 300-unit blob spans tens of start rectangles, not 300; each unit then straightens from its own position through the shared rectangle chain to its own slot. With one size class in P5 the key has no class yet.
- Budget size is the movement lab's first question (below). P5's node budget replaces the route-cell cap from the night package Flatter worst ticks if that has landed.

### Straightening and following

- Portal path through the rectangle chain, then a **body-safe line test** (the unit's full width along the line, on the dilated fine grid) to drop waypoints; a centre-line test can clip a corner by about half a cell (spike part 7).
- Units follow the waypoints with today's `Locomotion.step` unchanged (any angle; the heading and braking rules already work per segment).

### Parked units and the local detour

- **Moving units never mark cells.** A unit marks its footprint in the fine grid when it parks (arrived, idle, holding, shooting, building, docked) and unmarks it when it starts moving, with a reference count per cell (the Permafrost rule, `nav_data.h:132-137` @ `083a99ca`).
- Before a mover enters its next straight stretch, and when it is blocked on it, the stretch is tested against the parked grid. If blocked, a **short local A*** on the fine grid in a small window around the mover finds a detour back onto its route (OpenRA's local search, 0 A.D.'s short-range pathfinder). The window size and the search budget are builder's calls, measured; the window grows on repeated failure, as 0 A.D. does (`CCmpUnitMotion.h:753-765` @ `136720dada`).
- If the local search fails, the unit waits and retries; it is woken early when a cell in its window loses its last parked unit (a per-region "freed" counter, Permafrost `nav_data.h:138-142`); after 2 s blocked it requests a new long route (Zero Hour, `AIStates.cpp:1821-1827` @ `0a05454`).
- **Last resort for parked friends** (user, 2026-11-14, after the builder check): a new long route returns the same route, because the mesh does not see units, so a parked friend in a one-vehicle corridor would block forever. After about 5 s with no progress towards the goal, the mover passes through parked own and allied units until clear; never through enemies. P6 extends the same rule to moving friends.
- Moving units still overlap each other in P5 (as today); P6 changes that.
- A unit within one cell of its goal ignores blockers and squeezes in (decided 2026-11-09, `AIUpdate.cpp:1303-1311`).

### Group goals

- **Front-first goal layout** (user, 2026-11-14): the units nearest the target take the far slots, as Zero Hour lays goals out (`AIGroup.cpp:480-514` @ `0a05454`) and as `s1` in the round 4 feel session; the ring allocator keeps its distinct goals and its examined-cell bound. Only with the toggle on.

### Movement lab (P5's look-and-feel step)

In the art lab style (`[` `]` question, `Tab` variant, click page), only what core needs: (1) node budget per tick: 8 routes' worth against 32 against unlimited, judging the response to the click against cost; (2) body-safe against centre-line straightening; (3) navmesh against finer-grid path shape. No A/B for determinism or the full rebuild (tests).

### P5 tests, first steps first

1. **Seeded fuzz and invariant test** (moved from P4): random maps, buildings and orders; invariants: no unit inside static blocked cells, every order ends arrived or blocked-with-no-path, no unit without progress for longer than the stuck limit, two runs of the same seed give equal snapshots at every checkpoint (corrected 2026-11-14: the simulation has `snapshot()` but no restore, so a save-restore round trip is not testable yet; a restore is an open item from the OpenTTD research).
2. **Cross-platform path determinism test** (2026-11-10 item 8): fixed scenarios whose route lists are compared across macOS, Linux and Windows CI, like the trace comparison; a difference means integer costs in our own search.
3. Behaviour tests per piece: mesh build matches the fine grid (every open dilated cell covered once), B's straightened path length against A within the spike's bounds, body-safe straightening never crosses a dilated blocked cell, local detour around a parked unit, wake on a freed cell, squeeze-in, front-first goals.
4. **Same-tick interaction cases** for the new state (toggle switch) and every changed command path: toggle against move, attack-move, stop, build, dock, unit removal, building placement in the same tick.
5. Old-state neutrality: with the toggle on old, every existing trace and pinned value is unchanged.

### P5 gate

Every benchmark row inside its current budget with the toggle on new movement, plus one new row for a 300-unit order on the new movement (user, 2026-11-14); rows already over budget (combat open, dense, hordes300; F13 on the team match) must not get worse than the old movement on the same tree, median of 3, gap reported (user, 2026-11-14). A miss is recorded and stops for the user; budgets are never loosened. A rendered benchmark row (units move differently on screen). The stuck check: the round 2-4 jam scenarios (`dw_group50`, packed and split 300-unit moves, the narrow-passage layout) finish with no unit stuck for good; if B fails it, fall back to A and report. Focus card: does movement look straight and responsive; one hiccup per building expected.

## P6: core avoidance

On top of P5, third toggle state.

- **Soft movers:** moving **vehicles** push and are pushed by moving **own and allied** vehicles (user, 2026-11-14). Each unit sums the pushes on itself from the tick-start positions, then all apply, so the result does not depend on iteration order. Pressure damping (a per-unit pressure value that rises while pushed and decays) lets crowds settle; 0 A.D.'s pressure and minimal-force cutoff (`CCmpUnitMotion_System.cpp:668-760`) is the closest reference. Constants are the builder's, measured in the jam scenarios.
- **Infantry pass through infantry** (Zero Hour rule kept, `AIPathfind.h:51`).
- **Enemies are solid to each other:** a mover slides around a moving enemy and never shoves it (Recoil's default, `GroundMoveType.cpp:2923-2927` @ `a0240a9b5c`); parked enemies are walls already in P5.
- **Step aside:** a parked, idle own or allied unit on a mover's next stretch is asked to step aside to a free neighbouring cell (Zero Hour `moveAllies`, `AIPathfind.cpp:10112-10187`; OpenRA nudge; Warzone shuffle); busy units (shooting, building, using an ability) do not; a unit that stepped aside stays there. Decided rules in [unit avoidance: behaviour](../../reference/design-answers-2026-11-08.md#unit-avoidance-behaviour) apply where they still fit the soft model: right of way for the step-aside choice, factory exit, supply trucks on a supply run drive through all units, speed matching behind a slower friend.
- **Last resort** (user, 2026-11-14): P5's rule extended to moving units: after about 5 s with no progress towards the goal (not consecutive blocked ticks, so circling is caught), own and allied units pass through each other until clear; enemies never. Step aside comes first. A new long route at 2 s blocked (from P5).
- Vehicles push infantry and infantry push vehicles (the 2026-11-09 rule "only vehicles block infantry" in the soft model; agent's call, confirmed by the user 2026-11-14).
- **Neighbour query:** one packed per-tick spatial index rebuilt each tick; review X5 (packed rebuild against incremental against today's grid) is P6's first measurement.
- Per-unit avoidance state (pressure, blocked clock, step-aside target) goes into the snapshot and state hash from the start.

### P6 tests and gate

- First step: measure the soft-mover cost on the six 300-unit rows before building the rest; a miss of the +0.5 ms cap (median-of-3 p95 delta against the P5 state, spread reported, no noise allowance) stops for the user. If the miss is on the movement rows, "near enough" (OpenRA-style stop when close and blocked) is the decided fallback to measure beside it.
- Spec-worded tests per rule above, same-tick cases for step aside against every command and removal, order-independence (shuffled entity order gives equal digests), the jam scenarios plus the mixed-owner scenario with no unit stuck for good, browser cost in the Firefox Web Bench if the native cap passes.
- Existing tests that fail only in the new states are listed with a proposed rewrite; the user decides per test before the default flips.
- Focus card: do units get past each other; does the crowd settle.

## Advanced packages

Cut by the user (2026-11-14), 2 to 3 days each, in Later 3 and 4 of [packages](../../packages.md) (Later 2 and 4 until the 2026-11-16 swap), ordered after P6's playtest. Names are proposals.

Movement (Later 3, "Smoother big moves"):
1. Buildings that update the map: local mesh update (touched tiles plus reconnect, about 3 ms or less) with a local-against-full equality test over random placements; lands before the default flips.
2. Infantry fits through gaps: three size classes (infantry, vehicle, large), one mesh each.
3. Big orders in one stream: shared searches and trunks or flow fields, only if P5 measures jams or cost; dropped otherwise.
4. Formations and keep formation, after order controls.
5. New movement for everyone: the movement toggle becomes the default, online included, one trace re-pin; then golden scenarios with browser digests.

Avoidance (Later 4, "Crowds that sort themselves"):
1. Arrivals that spread: pressure tuning and arrival spreading.
2. Tanks crush infantry: crusher rules and the mixed-owner scenario.
3. Infantry crowds spread: soft spreading among infantry, measured against the cap first; the round 2 open questions.
4. Avoidance for everyone: the avoidance toggle becomes the default, one trace re-pin.

## Left to the builder (plan)

Toggle key choice; local window size and budget; push, pressure and decay constants; node budget default before the lab; file split (a navmesh script, a fine occupancy grid, a movement provider); how the spike's `rect_mesh.gd` and `smooth.gd` are rewritten. The plan names guide chapters 4 (tick pipeline: path service, avoidance step), 6 (movement, rewritten), 10 (determinism: own search tie-break, snapshot state), 12 (performance rows) and 13 (fuzz and cross-platform tests) in its docs step.

## Risks

- P5's size: routing every reachability query and route request of supply, containers, combat and construction through the provider may push P5 past 3 days; the plan sizes it and splits it if so: P5a mesh, search, lab and plain moves; P5b supply, docks, combat and construction on the new grid (user, 2026-11-14).
- Old-state neutrality of the hash: undelivered requests and parked counts enter the snapshot and hash only in the new states, so old traces stay bit-identical.
- GDScript A* may be 10 to 30 times slower than `AStar2D` (estimate, unmeasured): mitigated by shared group searches and the node budget; measured first.
- The full rebuild hitch in the browser (about 90 ms) shows in P5 playtests; accepted, removed by advanced 1.
- The soft-mover cost cap: no avoidance spike variant met +0.5 ms on the old grid; the soft model is cheaper by design (no cell claims) but unmeasured.
- Vehicle-width mesh: infantry lose narrow gaps until advanced 2; a map whose only route is narrower than a vehicle would block infantry there (the converter's maps are drawn on building cells; check the three maps in P5).
