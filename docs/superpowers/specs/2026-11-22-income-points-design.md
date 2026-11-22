# Fight over income points: design proposal

Status: approved (user, 2026-11-22), nothing built. For the Later item "Fight over income points" in [packages](../../packages.md); the owner places it after reading. Frame and answers: [hybrid economy frame](../../reference/design-answers-2026-11-08.md#hybrid-economy-frame-user-2026-11-22), [late-income wizard round](../../reference/design-answers-2026-11-08.md#late-income-wizard-round-user-2026-11-22), [income points proposal round](../../reference/design-answers-2026-11-08.md#income-points-proposal-round-user-2026-11-22); findings with citations: [late-game income](../../questions/next-economy-late-income.md).

## What the player notices

With the match setting "Income points" on (the default), every map has income points: two per seat, one near home and one out where the armies meet. Right-click a free point with infantry and they take it in about 20 seconds; from then on it pays its holder 1,000 a minute, shown as a rising "+200" over the derrick, and the first holder gets 1,000 once. Points cannot be destroyed, only taken, so when the supply piles run dry the late game is a fight over the map instead of a count of Hackers and Supply Drop Zones. A player who never touches a point still lives on piles and the capped passive set; an equal opponent who holds points is ahead.

**Refuting observation:** in bot matches, holding half the points either changes nothing measurable (points are decoration) or decides the match before the piles run dry (points replace gathering). Either result sends the numbers back, not the mechanic forward.

## Why

Zero Hour's late game is decided by whoever stacked the most passive income once the piles are empty (owner, 2026-11-22, [late-game income](../../questions/next-economy-late-income.md)). Wargrid today goes broke instead: a 1v1 on Wargrid's own Skirmish map runs dry near tick 30,000 and ends only at 73,560 ([blueprint M8, end-game income](../../blueprint.md#m8--bots-worth-playing)). Income points reward active play, raise the skill ceiling and leave the floor where it is.

## Goals, non-goals, anti-goals

- **Goals:** a territorial income layer between finite piles and capped passive income; points worth fighting for all match; bots that use them at every level; every map with the same number of points per seat.
- **Non-goals (this proposal):** step 2's post and its numbers, caches, networks, falling returns, per-faction point numbers. Each waits for the measurement below or is parked by the frame.
- **Anti-goals:** a player who ignores points becomes useless to a 3v3 team; holding points becomes required for any unit or technology; points become a second base (turtling on a point); capture becomes busywork (repeated clicks, babysitting); allies argue over points.

## Constraints

- Faction differences are capability data, not simulation branches ([blueprint §14](../../blueprint.md#14-decision-log)).
- Simulation follows the [determinism rules](../../reference/determinism-rules.md): integer ticks, 30 per second; new tests use only the [simulation interface](../../reference/sim-interface.md).
- Bots play by human rules and see only what their team could see ([fair bots research](../../reference/fair-bots-research.md)).
- Converted maps' points come out of `tools/zh_map/convert.py` and must survive re-conversion; converted maps keep EA's notice (`game/data/maps/NOTICE.md`). Skirmish is hand-written, so its points are written into `skirmish.json` directly.
- The match setting is synced match state, so the branch touches `protocol/` and gets the reviews AGENTS.md sets for it.

## Approaches

Picked by the owner (user, 2026-11-22): **A**.

- **A. A point is a neutral building (picked).** An invulnerable derrick object with an owner, a capture timer and a payout. Owner colour, drawing, the selection card and bot targeting already exist for buildings, so the new work is mostly the capture rule.
- **B. A point is a map zone.** A circle in map data with an ownership table in the simulation. Lighter simulation, but drawing, HUD, view rows and bot targeting all need new code for something that is neither unit nor building.
- **C. Inside batch B's capture system.** Zero Hour's Capture Building skill first (a 1,000 upgrade, 3 s unpack, 20 s channel by a Ranger, Red Guard or Rebel; `upgrade.ini:163-166`, `specialpower.ini:491-493`), points as one of its targets. Ties step 1 to everything batch B carries, the opposite of "cheap to take and retake".

## Step 1: Zero Hour's derrick, captured by infantry

### Rules

Decided by the owner (user, 2026-11-22, frame, wizard round and proposal round) unless marked as the agent's call.

- **Match setting:** "Income points", on by default, set in the lobby before Create match and synced with the match settings. Off removes every point from the map; everything else plays the same.
- **Pay:** 200 every 12 s (360 ticks), 1,000 per minute, flat per point, as Zero Hour's `TechOilDerrick` (`civilianbuilding.ini:25108-25111`). The payout timer starts at capture. A neutral point pays nobody (`AutoDepositUpdate.cpp:160`).
- **Capture bonus:** 1,000 once per point per match, to its first holder only (`AutoDepositUpdate.cpp:120-141`, `:150-156`).
- **Team pay:** the holder only.
- **Never destroyed:** the derrick is not a target; it is only captured. A departure from Zero Hour, where it has 2,000 health and is gone for good (`civilianbuilding.ini:25098`, `:25140`).
- **Look:** one neutral derrick shape for everyone, shown in its holder's colour.
- **Who captures (agent's call, narrowing "any infantry"):** units with a `captures: true` capability, set on combat infantry (riflemen and rocket troopers of every faction). Builders, collectors and Hackers do not capture. Without it the FRC Laborer, an `infantry` start unit (`factions.gd:26`, `frc.gd:7`), would take its home point at tick 0 while USA and China start with a vehicle builder (`usa.gd:5`, `china.gd:10`). Vehicles cannot capture.
- **Capture order (agent's call):** right-clicking a point with capturers selected moves them into the radius and sets a capture stance: they chase only within the radius plus weapon range and return to the point afterwards. Today's guard scan for human seats (vision × 2.2, `combat.gd:63`, `:77-78`) would otherwise walk them off the point (`combat.gd:126-128`, `:185-199`). Right-clicking a point with only vehicles moves them there and shows "Only infantry can capture".
- **Capture time and radius (agent's call):** 600 ticks (20 s) with at least one capturer within 3 cells of the point's centre. 20 s matches both Zero Hour's channel and Dawn of War's strategic point (fan wiki, below). Several capturers do not speed it up; one rate reads at a glance. The capture and neutralise times are a starting point, tuned by playtest; 30 s and 10 s is the second pair to try (user, 2026-11-22).
- **Pause (agent's call on who counts):** progress pauses while an armed enemy ground unit the capturing team sees stands within the radius. Collectors, builders, aircraft and passengers do not pause it. Armed vehicles therefore defend a point without being able to take one.
- **Decay (agent's call):** with no capturer in the radius, progress drains at the neutralise rate instead of resetting, so a step out for one second costs about three, not twenty.
- **Taking an enemy point (agent's call):** neutralise first, 200 ticks (about a third of the capture time, as Dawn of War's decapture per the fan wiki), during which the point still pays its holder; capture then continues on the same order, 800 ticks in all. Neutralising follows the same pause and decay rules. A raid that neutralises and leaves still costs the holder the point.
- **Allies (agent's call):** a seat's home point can be captured only by that seat or by enemies; allies neither capture nor neutralise a point an ally holds. Free contested points go to whichever ally takes them first.
- **Empty seats (agent's call):** a seat's home point exists only when the seat is filled; contested points always exist.
- **Victory:** a point does not count for victory; holding one never keeps a defeated seat alive.
- **A seat that stops playing (agent's call):** a defeated seat's points and a leaver's points both turn neutral at that tick, so leaving never gives the team more than fighting on. P10's base transfer moves buildings, not points. The first-holder bonus is not paid again.
- **Fog:** who holds a point is public, shown on the map under fog (and on the minimap once P3 has built it), as Dawn of War's strategic UI shows captured points ("Displays the captured Strategic Points, Objectives and Relics", manual p. 8). Capture progress is visible only where the team sees.

### What the player must see

Acceptance for step 1; the War Room round decides the look, not this list (agent's call, from the player-experience review).

- **Ownership:** neutral in the existing neutral owner colour (`palette.gd:10-12`), held points in the holder's colour; a pump silhouette with no damage states, so it does not read as a building to attack.
- **Radius:** a flat ring on an earth pad, as the piles lie on the ground.
- **Ring states:** filling in the capturer's colour; paused, with a mark on the unit causing the pause; neutralising, the holder's colour draining away; decaying.
- **Payout:** a rising "+200" over the derrick on each payout, "+1000" on the first capture, in the holder's colour and seen by everyone who sees the point (Zero Hour floats its derrick payout, `AutoDepositUpdate.cpp:185-210`).
- **Alerts:** "Point captured", "Point under attack" (when a neutralise starts) and "Point lost", each with a sound and a jump to it; through P3's attack alerts if they exist by then, otherwise step 1 brings these three.
- **Point card:** "Income point · 1,000 / min to its holder · capture with infantry", no health bar.
- **Refusal:** an attack order on a point says "Income points cannot be destroyed".
- **HUD income readout:** open (below).

### Step 1 needs batch A, not batch B

Batch B's capture (`docs/blueprint.md:692`, `:697`) is Zero Hour's Capture Building skill against any building, grouped with stealth, detection and hijacking because those need fog's visibility model. Step 1's capture rule reads unit positions, team sight (for the pause) and point ownership, which is public. It needs neither batch B nor fog on its own terms, and batch B's Capture Building stays its own system for enemy buildings.

It does need ground batch A (user, 2026-11-22): before batch A there is no passive income, so a player who ignores points would have nothing once the piles run dry while a holder earns 2,000 or more per minute, which breaks the floor. Batch A comes after fog ([packages](../../packages.md) Later), so step 1 lands after both, and the measurement uses batch A's real capped set.

### What step 1 needs

1. **Simulation:** the point building (neutral owner, invulnerable, `counts_for_victory: false`), `captures`, the capture order and stance, capture, neutralise, pause and decay, payout and first-holder bonus, hand-back to neutral; income tracked by source (piles, points, passive) for the measurement. Same-tick tests against every existing command and against removal (AGENTS.md).
2. **Match setting:** the lobby option, synced; bots read it.
3. **Maps:** two points per seat on Dry Wells, Broken Crown, Ashfall and Skirmish (below), and on any map P13 has added by then.
4. **Presentation:** what the player must see, above; the HUD readout after its War Room round.
5. **Bots:** every level captures and holds nearby free points, home point first; the easiest level holds at most its share (its home point and one contested point), so a newcomer who never contests is not buried (agent's call within the owner's rule); from Regular up bots also neutralise and take enemy points, contested ones first. Builds on P7's shared bot.
6. **Measurement tool:** the plan below, on the Bot report card's runner.

### First playable slice

Dry Wells only, points on: the simulation, the derrick, ring, payout text, alerts and card, and bots that take their home point. The capture and neutralise times are data, with a lab key that switches between 20 s / 7 s and 30 s / 10 s mid-match, as the [A/B labs](../../reference/art-lab-verification.md) do. Then the owner's ten-minute match (AGENTS.md, How a package runs). The other maps, the full bot rules and the measurement follow and aim at what that match showed.

## Where points sit

Rule (user, 2026-11-22): **two points per seat**, one **home** point nearer its own start than any other start, about 20 to 32 cells out, outside the base slots and reachable by the first infantry, and one **contested** point between opposing seats or in the centre. Zero Hour derrick spots are kept where they fit and moved or merged where they do not. The 20 to 32 band is the agent's correction of its own "20 to 25", so that Dry Wells' derricks fit. Dawn of War's map layouts are not sourced; the rule is Wargrid's own.

Measured spots (Zero Hour maps from `CnC_Modding_Support` at `3aad8e4`, read with `convert.read_map`; cells of 25 world units; distances in cells to the nearest start):

| Map | Seats | Zero Hour derricks | What they are now | Proposed points |
|---|---|---|---|---|
| Dry Wells (Tournament Desert) | 2 | 2: (14, 39) and (71, 75), about 31 cells from their own start, 52 and 60 from the other | one per side, on the flanks; nothing in the middle | 4: the two derricks become the home points; 2 new contested points in the centre band near the small piles (about rows 47 to 58) |
| Ashfall (Twilight Flame) | 8 | 8, in four pairs 3 to 5 cells apart on a ring 34 to 44 cells from the centre; seats 1, 3/4, 5 and 8 have a pair 39 to 50 cells away; seats 2, 6 and 7 none closer than 59 | four double hot spots, three seats without | 16: each pair becomes one contested point at its midpoint; 4 new contested points in the ring gaps nearest seats 2, 6, 7 and the 3/4 side; 8 new home points, present only for filled seats |
| Broken Crown (Fallen Empire) | 4 | none | none | 8: 4 home points; 4 contested on the lanes between corner bases |
| Skirmish (Wargrid's own, 48 × 32, starts 39 cells apart) | 2 | none | none | 4: 2 home points about 10 cells out (the band does not fit a map this small); 2 contested on the centre line |

In a team match, the contested points that fall between two allied seats are first-come among allies; the playtest card for team matches asks "did you argue over a point?".

**Converter:** `convert.py` emits `TechOilDerrick` objects as points and merges each Ashfall pair into one; Wargrid's additions and moves are a small per-map list next to the converter, applied on every conversion, so the map JSON stays generated. Each point records its seat when it is a home point. The derrick's footprint, the list's format and exact cells are the builder's.

## The capped passive set

Decided (user, 2026-11-22, wizard round): per player at most 2 Supply Drop Zones and 2 Black Markets; 1 Internet Center whose Hacker slots drop from Zero Hour's 8 to 4, Hackers earn only inside it. Each faction's full set pays the same total, **1,200 per minute provisional**, set by the measurement, below one working depot (2,760 to 2,880 per minute, [faction income parity](../../reference/faction-income-parity.md)). These revise ground batch A's uncapped answer and are built into batch A; step 1 comes after it.

Per building at 1,200 (agent's call, the arithmetic of the decided total):

| Faction | Full set | Per building | Zero Hour rate | Change |
|---|---|---|---|---|
| USA | 2 Supply Drop Zones | 600 per minute: 6 crates of 200 every 120 s | 750: 6 crates of 250 (`crate.ini:550-551`, `objectcreationlist.ini:5140`) | crate value 250 to 200 |
| FRC | 2 Black Markets | 600 per minute: 20 every 2 s | 600 (`factionbuilding.ini:10143-10145`) | none |
| China | 1 Internet Center, 4 Hackers | 300 per minute per Hacker: 10 every 2 s, flat | 150 rising to 300 with rank (`chinainfantry.ini:1332-1338`) | flat, no rank bonus to money; the Center pays nothing itself |

The China row drops Zero Hour's money-per-rank (Hackers reach Heroic after about 16 minutes of hacking), because a rank bonus would lift China's set above the equal total late in the match. A Hacker still gains rank as a unit.

The limit is capability data: a per-kind owned-count field on the building or unit, as Zero Hour's `MaxSimultaneousOfType` on the Internet Center (`factionbuilding.ini:33966`); the build button explains the limit. Open for batch A: whether a Black Market captured in batch B counts against its captor's cap.

**Raid profiles differ, the total does not** (user, 2026-11-22):

- **USA:** income arrives in lumps by plane every 2 minutes; killing a Drop Zone stops it, and once anti-air exists the plane can be shot down before it drops.
- **FRC:** a steady trickle split over two buildings; a Black Market can be captured (batch B's Capture Building) and then pays its captor (`factionbuilding.ini:10121`).
- **China:** all of it in one building; destroying the Internet Center stops all four Hackers at once.

## Measurement plan: how far holding half the points swings a game

Purpose (user, 2026-11-22, "Income target, measure first"): fix the point's pay (question Q5), the passive total and whether falling returns are needed, stated as a share of total income, before any number is final. Runs after the owner's first match on the slice.

- **Setup:** headless bot matches, mirror factions (all three), Dry Wells, Broken Crown and Ashfall (3v3 seats), both slots, seeds to at least the Bot report card's noise floor (about 20), the match tick cap stated in the tool. Same bot level both sides; batch A's capped passive set in play.
- **Conditions:**
  0. Points off (the match setting): the baseline.
  1. Points on, both sides capture normally: what points do when both play them.
  2. **Half against none:** one side is given half the map's points at tick 0, locked so they cannot be lost; the other never captures. Measures the raw value of holding, the ignoring newcomer against a point holder. In 3v3 the half is split evenly over the team's seats; points of empty seats do not exist.
  3. **Three quarters against a quarter,** both locked, neither captures: the leader-runs-away check for falling returns.
  4. **Easiest bot with points against the same bot without them** (the newcomer's first match).
- **Reported per condition:** each seat's income by source (piles, points, passive) as a share of its total, in windows 0 to 10 min, 10 to 20 min and after the piles run dry; win rate; match length; income lead at the tick the last pile empties. Conditions 1 and 4 also report flips per point per 10 minutes, time each point spends neutral, and time to first capture per faction.
- **Reading:** the table goes to the owner, who sets the target share and the easiest bot's win-rate bar (scope, not the agent's call). The proposal gives no target; the frame dropped the brief's +15 % and +30 % for lack of a baseline.
- **Then:** step 2 is designed with the owner's match and the table in hand.

## Risks

- **Snowball:** flat pay rewards the leader. Condition 3 decides whether falling returns (the Zero-K overdrive pattern, `unit_mex_overdrive.lua:265-267`) are needed.
- **Fortification:** step 1 has nothing to build on a point, so a point is held by units, not walls. Step 2's guns bring the risk back; its design weighs it.
- **Busywork:** capture is one order and a wait; the stance keeps capturers on the point; nothing to refresh. A held point needs no care until an alert says someone is on it.
- **3v3:** points pay their holder only, so one player can play raider and deny while the others build; a teammate who ignores points keeps piles and the passive set; home points cannot be taken by allies.
- **1v1:** on Dry Wells holding both contested points is 2,000 per minute against 2,760 to 2,880 from a working depot; one fight decides a lot there. The measurement shows it per map.
- **Two economies:** the match setting doubles what balance covers; the passive cap is tuned with points on, and points off is checked only for the floor.
- **Bot strength:** today China loses most bot rows ([STATUS](../../STATUS.md)); measure faction mirrors, not mixed, so point effects are not confused with that gap.

## Still open

- **HUD income display:** how a player sees points held and their pay (points count, a `+N/min` readout, both). The look is the question, so a War Room round before that part is built (AGENTS.md); the director's optional `+N/min` strip readout ([packages](../../packages.md), director proposals) is one input.
- **Step 2's post and its upgrade levels:** a post built by the holder on a held point, one shape per faction with the same numbers, that shields the point: it must be destroyed before the point can be neutralised; destroying it loses its upgrades and their pay, the holder may rebuild (user, 2026-11-22, Q12, Q15). The Dawn of War manual: a Listening Post is built "on a captured Strategic Point or Relic to defend the point against aggressors", and upgrading it adds "defenses (weapons and armor), increase Requisition Rate" (p. 10). Levels, pay and guns wait for the measurement.
- **Caches:** the first experiment after the baseline plays well: a neutral point builds up a capped bonus paid to whoever captures it, a variation of the first-holder 1,000 (user, 2026-11-22).
- **Networks:** parked until capture points have been playtested (user, 2026-11-22).

## Sources on Dawn of War

Primary: the *Warhammer 40,000: Dawn of War* and *Winter Assault* manual (THQ; PDF at segaretro.org, `WHDoW_Steam_manual.pdf`), p. 8 ("Use squads with the Capture ability … to capture Strategic Points") and p. 10 (Listening Post). The manual has no times or rates. Capture time, decapture share and per-point income come from fan wikis only (private `research/dawn-of-war-points-2026-11-22.md`); nothing numeric here rests on them except the agent's 20 s and one-third calls, which playtests tune (user, 2026-11-22).

## Placement

The owner places the item after reading. Dependencies (user, 2026-11-22): after ground batch A, which comes after fog; also P7's shared bot and the Bot report card's runner. The capped passive set rides with batch A. Agent's recommendation: step 1 as the first package after batch A's last package, before Wrecks and batch B.

## Left to the builder

Point footprint and art detail within the art direction; the per-map additions list format and exact cells within the rule; how the capture ring draws; the lobby option's place in the match settings; test names and suites; the measurement tool's file layout; whether infantry inside transports count (they do not capture or pause, by the rule above).
