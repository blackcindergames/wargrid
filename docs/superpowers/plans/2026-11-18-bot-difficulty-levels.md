# Six bot levels: incremental plan

> **For agentic workers:** this is a roadmap plan: it orders packages and fixes their contracts. Each package below gets its own execution plan (superpowers:writing-plans) when the owner starts it; run those with superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** six fair bot levels (Cadet, Recruit, Regular, Veteran, Elite, Nemesis; default Regular) grown from today's bot in small measured steps, Regular first.

**Architecture:** one bot (`game/scripts/simulation/skirmish.gd`) reads a per-seat skill profile, a plain data row per level, instead of its constants. A level is a set of competences the profile switches on or tunes; it never touches resources, rules or what the bot may see. Every change is judged on the Bot report card (headless bot-against-bot matrix) before it ships, and levels are checked against people by a one-tap rating after logged matches.

**Tech stack:** typed GDScript (Godot, headless), Python tooling in `tools/`, POSIX shell wrappers.

**Spec:** [design answers](../../reference/design-answers-2026-11-08.md), headings "Bot vision (user, 2026-11-17)", "Bot difficulty design (user, 2026-11-18)" and "Bot plan round (user, 2026-11-18)"; [blueprint](../../blueprint.md) M8, M8.1 and §14 (Bots, Difficulty, Fog of war). Inputs reused, not redone: the better-bots folder in the private notes (`better-bots/`, private): `3-evidence-plan.md` (report card contract), `4-near-tasks.md` (near tasks and kill checks), `5-m8-package-cut.md` (packages B1 to B10, L1 to L3), `probe/probe-report.md` (415 headless matches).

Status: proposal (agent, 2026-11-18). Package rows in §7 are proposed; only the placements tagged "(user, 2026-11-18)" are decided.

## Global Constraints

- Fairness for every level, Nemesis included (user, 2026-11-05 and 2026-11-18): same resources, costs, income and production rules as a human; fog and scouting respected once fog exists; no knowledge of hidden enemy state; no inhuman reaction or unit control; only ordinary game commands through `issue_command`; bot units follow the same automatic unit rules as human-owned units (Q7 b, Q8 b).
- Weaker levels lack competences a weaker player lacks (scouts less, expands late, focuses fire worse, reacts slower); never deliberately wrong choices, idle workers or slowness for its own sake (user, 2026-11-18).
- Ladder bar (user, 2026-11-18): a level ships only if, over the ladder matrix (three maps, all faction pairs, both slots, five or more random start values per row; 270 matches at five), it wins at least 60 % of decided matches against the level below, the low end of the 95 % interval of that share is above 50 %, and it is ahead in each slot on its own. Otherwise it is reworked, or the ladder ships fewer levels.
- A bot improvement ships before M8 only as one small bot package once two or more changes have passed their test (Q5 b); traces re-pin once per package.
- The level control appears once Regular and one more level pass the ladder; it lists only passed levels, default Regular (user, 2026-11-18).
- Simulation code follows the [determinism rules](../../reference/determinism-rules.md): a bot decision draws nothing from `next_random()`; any per-match variety comes from the match seed with integer arithmetic.
- New tests use only the [simulation interface](../../reference/sim-interface.md) (`tools/test_sim_boundary.py`).
- Each package updates `docs/guide/09-ai.md` and, where tooling changes, `docs/guide/13-testing-and-tooling.md`, with their `Checked against` footers, in the same branch.
- Player-facing text (level names, one-liners, rating options) gets the player-experience reviewer beside the correctness reviewer.
- Never claim professional strength for Nemesis without evidence; never weaken Elite or Nemesis because the owner's group cannot beat them.

## Review Focus

- A level change that moves no trace but changes behaviour: the default profile must reproduce today's bot field for field, or every "no re-pin" claim is false. Owned by S4 (test BP1).
- A seat's level leaking into the hashed simulation state (players row, snapshot): online, only the host runs bots, so a level in hashed state is harmless today but becomes a desync source the day another client takes a seat over. Owned by S4 (test BP2) and S7 (test LV4).
- A match taken over mid-game (P8 handover) continuing with a different level or opening than it started with. Owned by S5 (OP6) and S7 (LV5).
- One noisy matrix row read as a result: every comparison reports both slots and the interval, and a missing result line fails the run. Owned by S1 (RC11, LD1 to LD3).
- A weaker level that feels broken rather than weaker (workers standing, buildings left unbuilt): each cut is checked on the report card's idle-production and income columns, not only on wins. Owned by S7 (LV3).

---

## 1. Today's bot, in one paragraph

`Skirmish.decide` runs every `DECISION_TICKS` (30 ticks = 1 s at 30 Hz) per seat, staggered by seat (`skirmish.gd:81-82`). It reads `bot_state()` (the whole state: every entity and building, every player's credits; `skirmish.gd:87-109`) and in one pass builds the next missing building of the faction's fixed `build_order` at a map slot (`_build`), keeps every finished production building's queue filled, collectors up to `bot_collectors_per_supply_center` per depot (`_produce`), sends idle units at intruders within `DEFENCE_RADIUS` 10 of its buildings (`_defend`), and from `ATTACK_TICK` 5400 (3 min) gathers idle units at its start and launches a wave at 6 units or after 60 s (`WAVE_MIN`, `WAVE_TIMEOUT`), aimed by the Zero Hour priority-minus-distance score (`_pick`, `_priority`). Memory (waves, gather start) lives in a meta dictionary on the simulation, outside the hash (`_bot`). Bot seats are created with controller `"ai"`, which makes their idle units scan further than a player's (vision × `GUARD_OUTER_AI` 1.333 or weapon reach, whichever is larger, where a player's idle guard scans only weapon reach; `combat.gd:73-78`, `:170-179`), and gives them no leash, no attack-move retarget and no retaliation (`:113`, `:620`, `:649`): the one place where today's bot does not play by the player's rules (Q7 b removes it, S3). There is no fog, so the bot's full view is also the player's full view: until fog exists, "same information" holds by symmetry.

## 2. Skill dimensions against the code

| Dimension | Settable today (constant or data) | Small parameter needed | New work |
|---|---|---|---|
| Strategy | `build_order` per faction (`definitions/*.gd`); `ATTACK_TICK`; `WAVE_MIN`, `WAVE_TIMEOUT`; target score `_priority`, `DISTANCE_STEP` | openings table per faction and a first-attack window from the match seed (S5, Q9 b); launch rule (S4) | plans and timing attacks chosen from scouted state (B2, B4), adaptation and opponent modelling (long term) |
| Economy | `bot_collectors_per_supply_center` (USA 2, China 3, FRC 5, faction data) | collector delta per level, only if the economy curve shows it is a lever (S6, S7) | second depot and expansion, end-game income buildings (ground batch A, Q15 a), oil derricks (B3) |
| Tactics | `DEFENCE_RADIUS`; wave retarget rule `_engaged`; target score | defence of allied bases (S3, Q11 b) | squads with jobs, focus fire, combat estimate, retreat with hysteresis (B5); defences and rebuild (B6) |
| Use of scouted information | nothing: reads everything; fair only because there is no fog | none before fog | observation filter on `bot_state()` with fog, last-seen memory, hidden-state invariance test (B1); scouting (B2) |
| Doing several things at once | build, produce, defend and attack all run every decision; one wave pipeline | none | several fronts and an attention model that limits how many things it handles per interval (B7) |
| Execution | `DECISION_TICKS` 30 (also the reaction delay: 0 to 1 s, on a fixed beat) | per-level decision period with a deterministic phase so there is no fixed beat (candidate for S5 or the second bot package) | human-pace budget: orders per minute, reaction delay and bursts within the owner's measured band (B7) |

Read: before fog, levels can differ in strategy, economy, tactics and execution. Use of scouted information and real multitasking need fog and B7, so Veteran's scouting, Elite's adaptation and Nemesis are long term.

## 3. The skill profile (the one seam)

- `game/scripts/simulation/definitions/bot_levels.gd` (new): `const DEFAULT_LEVEL := "regular"`, `const LEVELS: Dictionary` (level id to profile Dictionary), `static func profile(level: String) -> Dictionary`. Level ids: `cadet`, `recruit`, `regular`, `veteran`, `elite`, `nemesis`; only levels that passed the ladder are in `LEVELS`.
- A profile key enters with the package that reads it; S4's first profile holds `attack_tick`, `wave_min`, `wave_timeout`, `defence_radius` (the `regular` profile references today's constants, which stay in `skirmish.gd` because tests and benchmarks read them) plus the launch-rule key the attack test needs. An explicit `attack_tick` argument (`scripted_human.gd` passes 9000, `test_team_match.gd` 0) wins over the profile. `decision_ticks` enters only with the package that makes `decides()` and `next_decision()` per-seat (S5's fallback or S7), since `run_team_match.gd` and `test_skirmish.gd` call them statically. No key for a competence not yet built.
- A profile may hold only decision knobs. It never holds credits, costs, income, build times, vision or unit stats; the simulation never reads it (test BP2).
- `Skirmish.set_level(sim: RefCounted, player: int, level: String) -> Dictionary` stores the level in the seat's bot memory (`_bot(sim, player).level`), before tick 0; it returns `{ok, error}` like `issue_command`, and an unknown level is refused (`ok` false) and leaves `regular` (no `push_error`: `tools/run_tests.sh` fails a run on any `ERROR:` line).
- The level travels in match settings: offline from the launcher through `offline_driver.gd` `create`; online in the host's opaque `settings` (protocol 2 already carries them in `hello` and echoes them in `start`), so a P8 handover reads the same level. No relay change.
- The report card runs any level on any seat, which replaces the "debug policy" of the evidence plan: a ladder row is two profiles, not two copies of `skirmish.gd`.

## 4. Criteria per level

Common to every level (fairness):

| Check | How | From |
|---|---|---|
| F1 Ordinary commands only | the bot's only writes are `issue_command`; the report card counts rejected commands apart | S1 (today true by construction) |
| F2 Same resources and rules | a seat's level is outside hashed state and changes nothing before the bot's first decision (BP2) | S4 |
| F3 Same unit rules | no production path creates a bot seat with controller `"ai"` (S3 test UR1) | S3 |
| F4 Human pace | report card "tells": orders per minute, busiest 5 s, reaction delay (ticks from an enemy unit coming within a fixed 10 cells of the seat's buildings, not the level's defence radius, to the first order naming it), share of orders on the seat's decision phase | report-only from S1; a band per level from the owner's own logged orders per minute (S2) at B7 |
| F5 Same information | with fog: hidden-state invariance test at zero violations; zero orders naming an enemy its team has not seen | B1 |

Per level:

| Level | Bot against bot | Behaviour check (report card) | Human check | Earliest |
|---|---|---|---|---|
| Regular | Regular v1 not below today's bot outside the noise floor in either slot | every seat damages an enemy building on all three maps (Bot attack test column 1); rows that end today still end within the floor | about ten logged matches by the group; bar (user, 2026-11-18): six or more rated "Close match" and neither side winning more than seven | S5 |
| Recruit | Regular passes the ladder bar against Recruit | idle production while affordable and income end no worse than Regular's (it is weaker, not broken) | rated, recorded; no gate | S7 |
| Veteran | passes the bar against Regular | stronger opening and first attack timing; with fog: scouts before its first attack | top-level check while it is the top: about ten logged matches, recorded | S7 if the economy curve gives a lever, else long term |
| Elite | passes the bar against Veteran | changes production after it scouts a new enemy unit kind (B4 row) | top-level check; never weakened for the group | long term |
| Cadet | Recruit passes the bar against Cadet | first attack on a building later than Recruit's, never before the threshold its plan sets from Recruit's measured value | rated by a beginner when one exists | long term (after Elite, by design) |
| Nemesis | passes the bar against Elite, re-checked on every Nemesis change | all fairness checks at their strictest band | recorded; no professional claim without evidence | continuous |

Step-size warning (research proposal, report-only): an adjacent pair where the upper level wins more than 90 % of decided matches is flagged, so the step does not feel like a different game.

## 5. Short-term work (today's bot to a solid Regular and a second level)

Order in today's lanes: S2 before or at the start of P7, S3 with P7, S1 after P2.3b (P7 comes before P2.3b in the day lane), S4 and S5 before P9, S6 and S7 after P9. Because S1 lands after P7, S3's kill check uses the probe's unit-rule result (76 matches, bot rules 23, human rules 20, 95 % interval 0.39 to 0.67) and is re-checked in S1's first report; the earlier option of the evidence plan (scorer slice as night 8's backup task) would let P7 use the tracked tool instead.

### S1: Bot report card (night, between P2.3b and P8; placed, user, 2026-11-18)

Contract: `3-evidence-plan.md` "Refined task: Bot report card" (private), unchanged except the additions below. Files, measures (RC1 to RC11), the random start value setter (accepted only before the first `step()`, 1 to 0xFFFFFFFF, `RNG_SEED` stays the default) and the kill checks stand as written there.

Added by this plan:

- [ ] "Tells" columns per seat (Q10 c): busiest 5-second order count; reaction delay as defined in F4; share of orders on the seat's decision phase (`tick % 30 == seat % 30` today). Test RC12: on a scripted intruder at a fixed tick the reaction delay is the tick of the first order naming it minus that tick; an order to another target does not count.
- [ ] Variety columns (Q10 c, "variety between matches"): over a row's start values, the number of distinct build orders seen and the spread of the first-attack tick. Today's bot gives one order; S5 must raise it.
- [ ] A `level` field per seat in each row, filled once S4 adds the profile.
- [ ] Ladder verdict in `tools/bot_report_card.py`: `ladder_verdict(rows: list[dict], upper: str, lower: str) -> dict` with keys `share`, `low`, `high` (Wilson 95 %), `per_slot` (share per slot), `capped`, `passes` (share ≥ 0.60 and low > 0.50 and each slot's share > 0.50), `step_warning` (share > 0.90). Tests in `tools/test_bot_report_card.py`: LD1 hand-made rows with 28 of 40 decided won (low end 0.546) pass and 26 of 40 (low end 0.495) fail; LD2 the same share with one slot at 0.45 fails; LD3 capped rows are counted apart and never as wins.
- [ ] First report also carries the baseline tells, so the human-pace band has a "before" row.

Verify: `sh tools/run_checks.sh` and the full suite (`timeout: 600000`), exit 0 with the completion marker; RC1 green (scorer leaves the digest unchanged); no pinned trace moves; `PERF_LABEL="Bot report card" sh tools/run_benchmark.sh` row unchanged within the ledger's noise.

### S2: Rate the bot (small; proposed as the backup task of night 8 Play on after a leave, else the first task of P7)

What a player notices: after every logged match with a bot opponent, two rows about the enemy bots: "The enemy bots were: Too easy · Close match · Too hard" and "Did they play like a person? Yes · Partly · No", with a field "What gave it away? (optional)". Both optional, never blocking leaving (finding F22: free text and ticks any time, nothing that blocks).

- [ ] Files: `game/scripts/playtest/session_form.gd` (`add_match_rating(parent: VBoxContainer, session: PlaytestSession, match_index: int) -> void`, built like `add_question`: toggle buttons in a `ButtonGroup`, a field that saves on leave, no submit button), `game/scripts/playtest/playtest_session.gd` (`set_rating(match_index: int, key: String, value: String) -> void`, keys `difficulty` in `too_easy|close|too_hard`, `human` in `yes|partly|no`, `human_text` free), `tools/playtest_session.py` (`RATING` line per match with the enemy bot seats' levels once S7 exists, and `CPM`: the human's accepted orders per minute from the match's `commands`), a focus card entry "Today's bot" in `game/data/playtest/focus.json` for the Q1 sittings.
- [ ] The rows sit right under the match title, above the markers, so `playtest_overlay.gd` `end_match()`'s scroll target keeps them in view.
- [ ] Tests: a headless form test that the two rows exist under each finished match with a bot opponent (team matches with a friend included) and none under a match without one; after `end_match()` the rating row is inside the scroll view; a stored rating survives resume after a crash (`resume_or_open`); the Python summary prints `RATING 1 difficulty=close human=partly` and `CPM 1 <n>` from a hand-made session; an old session without ratings still parses.
- [ ] Player-experience reviewer on the wording and placement.
- [ ] Then the Q1 sittings (user, 2026-11-18): the owner and one friend each play two short logged matches against today's bot, on a build without S3's riders (Q1 says before any bot work). Their ratings are the first human data point, recorded as such.

### S3: P7 riders (P7 owns them; decided Q7 b, Q11 b, Q12 c)

Contracts: `4-near-tasks.md` tasks 2 and 3 (private). In short:

- [ ] Bot seats on the human unit rules everywhere (`Skirmish.create` default, `debug/team_match.gd`, `offline_driver.gd`, P7's seats); the session replay and `benchmarks/run_recorded_match.gd` keep `"ai"` for records made before the change (the record gains the controller, or old records replay with the old rules: P7's design picks). Test UR1: no production create path passes `"ai"`; a bot seat's idle unit does not acquire an enemy outside its weapon reach. Kill check: the probe's unit-rule result now; S1's unit-rule column re-checks it (inside the noise floor in both slots, or the owner sees the number).
- [ ] Ally defends your base: `_defend` counts intruders near allied buildings, for units at home only (not units in a wave). Tests: an idle unit goes for an intruder within 10 cells of an allied building; a wave unit does not; the bot still never attacks an ally.
- [ ] Ally tells you: a map mark (a shape distinct from the rally marker, not only the ally's hue) and one line "Ally army heading to …" when the allied bot's army sets out (its accepted attack on an enemy building), once per wave, not per retarget; a call when its base is hit, through the announcer's cooldown and priority (`announcer.gd`) on its own key ranked below the player's own base alarm, always paired with the text line so it works muted. Drawn from commands and combat events every client has. Headless HUD tests as in task 2, plus: an enemy bot's accepted attack command produces no mark, line or call (every client receives every seat's commands, so a team-filter bug would leak the enemy's plan). Player-experience reviewer.
- [ ] One re-pin of the offline bot traces, batched with P7's own pins.

### S4: Bot attack test plus the skill profile (night, between P13 and P14; moved, user, 2026-11-18)

Evidence only, no production behaviour change. Its rule is unchanged: a launch rule goes to a day package only if it wins both columns (user, 2026-11-16).

**Interfaces — Produces:** `BotLevels.profile(level: String) -> Dictionary`, `BotLevels.DEFAULT_LEVEL`, `Skirmish.set_level(sim: RefCounted, player: int, level: String) -> Dictionary`; profile keys `attack_tick`, `wave_min`, `wave_timeout`, `defence_radius`, `launch` (`"stock"` default; candidate rules as debug-only profiles in `game/scripts/debug/`).

- [ ] Write BP1: with no level set and with `regular` set, the pinned skirmish, team match and FRC match digests are unchanged.
- [ ] Write BP2: two simulations, one seat set to each profile in `LEVELS` (and a debug profile), run 600 ticks of the same scripted commands with no bot; digests equal every 200 ticks. Plus a source check in `tools/test_sim_boundary.py`: no `game/scripts/simulation/*.gd` file except `skirmish.gd` names `BotLevels`.
- [ ] Write BP3: an unknown level returns `ok` false and the seat plays `regular`; the run prints no `ERROR:` line.
- [ ] `skirmish.gd` reads `attack_tick`, `wave_min`, `wave_timeout` and `defence_radius` from the seat's profile; the constants stay as the `regular` profile's values.
- [ ] Run the attack test matrix (stock, gate, commit on Dry Wells, Broken Crown, Ashfall, both slots, five or more start values) on the report card; write the two columns per rule.

Verify: BP1 to BP3 green, full suite and `sh tools/run_checks.sh` green, no pinned trace moves. Docs step: `docs/reference/sim-interface.md` (`BotLevels`, `Skirmish.set_level`), `docs/guide/09-ai.md`.

### S5: Regular v1, first bot package (day, before P9; Q5 b)

What a player notices: the bot no longer opens the same way every match, and its army reaches your base on every map. Ships only when two or more changes have passed (Q5 b): the openings, plus the launch rule if S4 found one; if S4 found none, the second candidate is a decision period with a deterministic phase (no fixed beat), checked on the tells columns.

Contract for the openings: `4-near-tasks.md` task 1 (private), with Q9 b deciding it: every level varies. `Skirmish.opening(faction: String, match_seed: int, player: int) -> Array` (pure, integer arithmetic, no draw; match seed 0 gives today's order); `openings` list per faction in `definitions/factions.gd`, first entry today's `build_order`; a first-attack window around `attack_tick`; the match seed reaches the bot through `offline_driver.gd` `create` (today the unused `_match_seed`) and `SimPump.Job`, and online through `online_driver.gd` from the relay's `start` seed for P7's host-run bots; the headless netplay client keeps seed 0 so the netplay pins do not depend on the relay's draw. Tests OP1 to OP6 as written there (OP6: a bot taken over mid-match continues the same opening).

- [ ] Kill check per change first: each candidate against today's bot on the ladder matrix; it must not fall below the noise floor in either slot, and the "rows that end today still end" column within its floor.
- [ ] Regular v1 against today's bot: not below the floor in either slot (the Regular row of §4).
- [ ] One re-pin of all bot traces; one ledger row.
- [ ] Human check at Regular: about ten logged matches with S2's ratings (§4 Regular row).

### S6: Economy curve (night, between P9 and P10, the slot the attack test left; proposed)

Contract: `3-evidence-plan.md` "Economy curve" (private): income per faction against collector count and depot distance on one-seat rows, then how long a seat lasts once its pile is empty. Here it also answers one level question: is collector count a competence lever (Veteran up, Recruit down) beyond the noise floor? No behaviour change, no re-pin.

### S7: Pick your bot's level (day, after S5 and S6; proposed)

What a player notices: a Level control on the Play page next to the bot's faction, listing Regular and each level that passed, default Regular, with the chosen level's one line from the design shown as text under it (not a tooltip), e.g. "For average RTS players", updating on selection. Nemesis, when it exists, shows a line that promises no skill tier ("The strongest fair bot we can build") until L3 evidence (user, 2026-11-18).

- [ ] Placement: the empty cells beside the bot faction picker (`launcher.tscn` `Spacer2`, `Spacer3`), a hint label like `MapInfo` under Map; the new nodes join `BOT_ONLY` and the `_set_busy` lock list (`launcher.gd`); `_summary()` reads "… vs Regular China bot".

- [ ] Recruit: cut candidates, one ladder row each, kept only if the cut lowers the share below the floor: longer decision period (reacts slower), smaller defence radius (notices raids later), no wave retarget, one collector fewer per depot if S6 shows it matters. The cut set that makes Regular pass the bar against Recruit becomes the `recruit` profile.
- [ ] Veteran, only if S6 shows an economy lever: one collector more per depot plus the earlier timing of a strong opening; passes the bar against Regular, or waits for fog.
- [ ] LV1: the launcher lists exactly the ids in `BotLevels.LEVELS`, in ladder order, default `regular`, and shows no Level control at all while `LEVELS` holds one id; LV2: the pick is remembered with the other launcher picks; LV3: Recruit's idle-production-while-affordable and income-end columns are no worse than Regular's beyond the floor; LV4: the level is in the match settings and the report, never in the snapshot; LV5: a P8 handover keeps the seat's level.
- [ ] Player-experience reviewer on the control and the one-liners; headless launcher layout test, including the longest line ("For highly competitive players") at 1280x720 without truncation.
- [ ] Re-pin only if the default path moved (it must not: default is `regular`).

## 6. Long-term work (M8 and M8.1, in need order)

1. **Fog of war** (Later item 5, before ground batch A): filters `bot_state()` (user, 2026-11-16), runs the observation mask spike. Until it lands, "respect fog" means nothing and F5 cannot run.
2. **B1 Bots play by your rules:** observation entry point with last-seen memory; hidden-state invariance test written first; the decision trace line format. Every level is re-run on the ladder after B1, since the bot then knows less.
3. **Veteran (if not short-term) and Elite:** B2 scouting, B4 counters from what was seen, B5 squads, combat estimate and retreat (with the Bot attack test's result and the new movement as default), B6 defences and rebuild (needs the Headquarters rule change for USA and China first), B3 economy (second depot, end-game income from ground batch A per Q15 a, derricks).
4. **B7 Bots at a human pace:** the attention model: orders per minute, reaction delay and bursts per level inside a band set from the owner's logged orders per minute (S2) and the research ranges; higher levels get a larger budget (user, 2026-11-05) and better decisions, not just more orders.
5. **B8 and B9 team play:** allied waves on the same target at the same time; the ally sets out with you toward the enemy you attack (Q13 d); the map ping request with "coming" or "not ready" (Q14 b) as a new command with same-tick cases.
6. **Cadet:** after Elite, by the design's order: little aggression and forgiving play as missing competences (late first attack, no raids, slow rebuilding), not idle workers.
7. **Nemesis:** a continuous lane: the strongest profile, re-checked against Elite on every change; the hidden server seat for a much stronger bot (user idea, 2026-11-16) is evaluated here, under the same fairness rules.
8. **L2 styles** (aggressive, economic, defensive, random): profiles layered on a level, each style of one level inside a strength band.
9. **L3 levels on real players:** about ten logged matches at Regular and at the top level; win rates per level only once enough matches exist; testers of other skill levels when they exist.
10. **Adaptation and opponent modelling** beyond reacting to what was scouted: Elite and Nemesis, last.
11. Content each package owes the bots (powers, batch A and B units, aircraft): the table in `5-m8-package-cut.md` (private) stands.

Changes to the earlier cut (`5-m8-package-cut.md`): L1 "about five levels" becomes six, shipped one at a time as each passes (S7 is the first L1 step); "strong bot first" is gone (Regular first); B10 "A fair bot that can beat you" becomes Elite's gate; the opening repertoire is no longer a level lever (Q9 b: every level varies).

## 7. Proposed package rows (not applied; the owner approves edits to tracked documents)

`docs/packages.md`, night lane:

> **Bot report card:** between P2.3b and P8, in the gap Adaptive input delay does not take (user, 2026-11-18): evidence only, no production behaviour change; a headless scorer for bot against bot over maps, slots, factions, unit rules, levels and random start values, with first attack, first enemy building damaged, credits floated, idle production, value traded, orders per minute, tells and match end per seat, and the ladder verdict; first report: baseline, noise floor and the unit-rule column; no trace re-pin.

> **Bot attack test:** between P13 and P14 (user, 2026-11-18; was between P9 and P10), written against the Bot report card; adds the bot's skill profile with today's values as Regular: (rest unchanged).

> **Economy curve:** between P9 and P10 (proposed): evidence only; income per faction against collector count and depot distance, and how long a bot lasts once its pile is empty; decides whether collector count is a level lever; no trace re-pin.

`docs/packages.md`, day lane (ids by placement order, left open):

> | P… | Bots that start each match differently | The bot opens differently from match to match and its army reaches your base on every map: two or three openings per faction from the match seed, a first-attack window, and the launch rule the Bot attack test passed (proposed; before P9; ships once two changes pass, Q5 b) | none |

> | P… | Pick your bot's level | A Level control next to the bot's faction: Regular and each level that passed the ladder (first Recruit), each with one line on who it is for (proposed; after Bots that start each match differently and the Economy curve) | none |

`docs/STATUS.md`, rows in the existing form:

> | night N | Bot report card | Placed 2026-11-18 (user): between P2.3b and P8; no plan yet; evidence only; no trace re-pin | [packages](packages.md#night-lane) | [bot plan](superpowers/plans/2026-11-18-bot-difficulty-levels.md) |
> | night N | Bot attack test | Placed 2026-11-16 (user), moved 2026-11-18 (user): between P13 and P14; no plan yet; evidence only, a rule ships only if it wins both columns | (unchanged) | (unchanged) |
> | night N | Economy curve | Proposed 2026-11-18 (agent), not placed by the user; evidence only | [packages](packages.md#night-lane) | [blueprint M8](blueprint.md#m8--bots-worth-playing) |
> | P… | Bots that start each match differently | Proposed 2026-11-18 (agent), not placed by the user, no plan yet | [packages](packages.md#day-lane) | [bot plan](superpowers/plans/2026-11-18-bot-difficulty-levels.md) |
> | P… | Pick your bot's level | Proposed 2026-11-18 (agent), not placed by the user, no plan yet | [packages](packages.md#day-lane) | [bot plan](superpowers/plans/2026-11-18-bot-difficulty-levels.md) |

Night numbers follow the lane order, so the new nights renumber the later ones (as nights 7 and 8 did). Also touched when applied: the online teams design's package table (attack test slot), the findings-list row on Ashfall attacks, P7's row (riders S2 and S3), and the README roadmap through `python3 tools/roadmap.py` for the two day rows. Blueprint §14 Fog of war got a note with this plan: levels before fog are profiles of today's bot, re-measured once fog lands (user, 2026-11-18); M9's lobby "bot difficulty 1–5" was corrected to the six levels with this plan. `docs/reference/sim-interface.md` gets `BotLevels`, `Skirmish.set_level` (S4) and the changed `issue_opponents` signature (S5) in those packages' docs steps.

## 8. Dependencies and risks

- Fog is Later item 5, after P4 to P6 and the movement packages. Everything in §5 is fair by symmetry (no fog for anyone); every level is re-measured after B1, and a level that drops below the bar then is reworked, not kept.
- The movement and avoidance packages (P5, P6) change fights: report card numbers measured before them are re-measured after them (handoff constraint 3 of the evidence plan). S5 sits before P9 and S7 after it, both before P4 to P6 in today's order, so their ladder rows are re-run when those land.
- Pre-M8 levels are profiles of today's bot; M8 rewrites much of `skirmish.gd`. The profile keys and the ladder rows survive; the cut values may not. This is the price of Regular first and a level control early (both owner decisions).
- Separability may fail: the research found no shipped RTS that built honest levels by removal alone. S7 is the first real test; if Recruit cannot pass the bar with legitimate cuts, the launcher keeps one level and the owner sees the rows.
- Sample size and cost: at a 0.60 share the interval's low end clears 0.50 only from about 91 decided matches, and the probe capped about 40 % of matches. The ladder matrix (3 maps, 9 ordered faction pairs, 5 start values, both slots) is 270 matches, about 160 decided per level pair; at about 40 s a match on the large maps and four in parallel that is about 45 minutes (probe timing on a 4-core container, not measured on the Mac mini). Rows are sized from the bar: add start values until a pair has 100 or more decided matches.

## 9. Not checked

- No code was run for this plan; the cost estimate and the ladder sample size come from the probe, not from the tracked tool.
- Whether `decides()` can take a per-level period without disturbing the night 4 seat stagger in `run_team_match.gd` (S5's second candidate and S7's first cut both need it).
- P8's handover design does not exist yet; LV5 and OP6 assume the host's `settings` reach the new host.
- Research items still unread (Pietikäinen's critique of AlphaStar's limits, GDC talk videos); not needed for this plan.
