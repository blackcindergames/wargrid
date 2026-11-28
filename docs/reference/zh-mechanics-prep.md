# Zero Hour unit mechanics: preparation

Groundwork for the packages that add Zero Hour's unit abilities, upgrades, add-ons and battlefield effects. Examples are drones, Overlord add-ons, salvage on every FRC vehicle, point-defence lasers, fire walls and toxin fields. Like the [generals preparation](zh-generals-prep.md), it makes no design decision. It maps what exists today, what Zero Hour does and which shared systems the mechanics need. It also proposes an order and lists the documents and tools to prepare first. Proposals are marked *proposed*; nothing here is approved.

Inputs:
- the owner's mechanics catalogue `zero-hour-unit-mechanics.md` (private);
- the [blueprint](../blueprint.md) sections Ground batch A and Ground batch B;
- the [batch classification](m7-factions.md#batch-classification-config-2026-11-07);
- the [batch A system answers](design-answers-2026-11-08.md#ground-batch-a-systems-user-2026-11-09);
- the local INI dump (`build/zh_ini/inizh.jsonl`, from `python3 tools/zh_ini.py dump`);
- the Zero Hour source in the fork `~/projects/GeneralsGameCode` at `afc2a103f` (the original is `~/projects/CnC_Generals_Zero_Hour` at `0a05454`). Paths are under `GeneralsMD/Code/GameEngine/` unless they start with `Core/`.

## Summary

- **Most of the scope is already placed.** Ground batch A holds upgrades, add-ons, drones, point defence, hazard fields, veterancy, travelling shots, second life and the three salvage tiers. It runs as A1 systems, then one gate per faction: A2 USA, A3 China, A4 FRC. Ground batch B holds stealth, capture, hijack and the Scout Drone. Aircraft and superweapons come later. A light general's powers package follows batch A ([promotion answers](design-answers-2026-11-08.md), user, 2026-11-15). This note does not re-decide any of that; its order is an order *inside* those batches.
- **Zero Hour uses one mechanism for all of it.** A unit is a list of generic modules configured by INI. Four things glue the modules together:
  - upgrade names (`TriggeredBy`, `ConflictsWith`);
  - status and weapon-set flags;
  - weapons and object-creation lists, referenced by name;
  - command sets (the buttons).
  
  The Overlord's three add-ons and the USA vehicle drones both use one `ObjectCreationUpgrade` per option, each listing the other options in `ConflictsWith`. They then differ in ways that matter for the design; see [The glue](#the-glue).
- **Wargrid already has the right shape.** Faction differences are optional row keys that shared systems read (`contains`, `horde`, `salvage`, `weapon_tiers`, `spawns_on_complete`); there is no per-faction branch. The missing pieces are five shared systems, not per-unit code:
  - **upgrades**, per player and per object, with conflicts and removal;
  - **timed status effects**;
  - **projectiles**;
  - **ground fields**;
  - **follower units**.
  
  On top of those come a data-driven **command card** and two new commands.
- **Most mechanics also need a picture.** Add-on parts, drones, tier marks, travelling projectiles, beams, ground fields, status icons and new card cells have no look yet. Each visual family gets one War Room round, run one package ahead of its build ([Presentation](#presentation)).
- **The biggest risk is performance.** Combat stress p95 is already over budget ([performance ledger](performance.md)), and projectiles and fields add per-tick objects on exactly those rows.
- **What to prepare first:**
  - a per-unit *port sheet* report from the INI dump, extending `tools/zh_generals.py`;
  - a design-input note per shared system, built from the Zero Hour source;
  - a question file for the open design points;
  - a War Room seed list.
  
  Lint keys, test helpers and benchmark layouts wait for the package that adds the first real key, command or system ([Preparation work](#preparation-work)).

## How Zero Hour builds a unit's mechanics

### Objects are module lists

An INI `Object` is a list of `Behavior = <Module> <tag>` blocks, plus `Body`, `WeaponSet`, `ArmorSet` and `CommandSet`.
- `ModuleFactory` (`Source/Common/Thing/ModuleFactory.cpp:322-559`) registers about 175 module classes.
- Each class's `buildFieldParse` table is exactly its INI keys.
- The dump has about 160 module classes in use on objects; the count depends on whether reskins are included.

Categories:
- **Body:** health and armor.
- **Update:** ticked logic.
- **Behavior.**
- **Die:** on-death effects, filtered by death type and status.
- **Upgrade:** fires on `TriggeredBy`.
- **Contain:** transports, garrisons, add-on slots.
- **Collide:** crates, hijack.
- **Create.**
- **SpecialPower.**

### The glue

| Glue | What it does | Example |
|---|---|---|
| Upgrade names | An `Upgrade` block (`Type = PLAYER` or `OBJECT`, cost, build time). Every upgrade module lists the names it fires on (`TriggeredBy`) and the ones that block it (`ConflictsWith`). A module does not fire while any of its conflicting upgrades is already on the object (`UpgradeModule.cpp:123-155`, `Object::affectedByUpgrade` in `Object.cpp:4602-4626`). | Overlord Gattling add-on fires on `Upgrade_ChinaOverlordGattlingCannon` and is blocked by the Propaganda and Bunker upgrades (`chinavehicle.ini:347-349`). |
| Flags | Upgrades set weapon-set, armor-set and status flags. `WeaponSet` / `ArmorSet` blocks with `Conditions =` pick the active data. | Dragon Tank's Black Napalm is a `WeaponSetUpgrade` (`chinavehicle.ini:928`). The Overlord's `PLAYER_UPGRADE` set adds only `GattlingBuildingGunAirDummy`, a dummy that lets the hull acquire air targets; the add-on passenger does the real firing (`chinavehicle.ini:258-260`, `:341`). Salvage sets `CRATEUPGRADE_ONE` / `TWO`. |
| Templates by name | Weapons, object creation lists (OCL), FX lists. | Paladin laser: `WeaponTemplate PaladinPointDefenseLaser` (`americavehicle.ini:1971`). |
| Command sets | Numbered slots of `CommandButton`s. A button has a `Command` type (about 30 generic types: `OBJECT_UPGRADE`, `PLAYER_UPGRADE`, `SPECIAL_POWER`, `FIRE_WEAPON`, `SWITCH_WEAPON`, `EVACUATE`, `TOGGLE_OVERCHARGE`, …) and names the upgrade, object or power it acts on. Classes: `Core/GameEngine/Include/GameClient/ControlBar.h`. | Crusader slots 1-3 are the three drone buttons (`commandset.ini:485-492`). |

**Add-ons and drones differ after the shared conflict pattern:**
- **Overlord add-ons are permanent.** A `CommandSetUpgrade` swaps the card per add-on (`chinavehicle.ini:369-381`). The add-on is a passenger in a one-slot `OverlordContain` (`:338-343`). A Battle Bunker add-on takes infantry: `OverlordContain` redirects garrisoning into the mounted bunker, which is nested containment (`Source/GameLogic/Object/Contain/OverlordContain.cpp`).
- **Drones can be bought again.** The Crusader has no `CommandSetUpgrade`; its three drone buttons stay fixed. A drone carries `UpgradeDie`, which removes the host's upgrade when the drone dies, so the host can buy a drone again (`americavehicle.ini:938-939`, `UpgradeDie.cpp:67-75`).

### Module census for the catalogue

Objects per mechanic from `python3 tools/zh_generals.py census`, run on the local INI dump with the tool of the `spike-missing-mechanics` working tree over `c82e5f64`. Each cell is two counts: all 2115 objects / `--base-only`. The filter `--base-only` drops general-prefixed copies (`AirF_`, `Lazr_`, `SupW_`, `Infa_`, `Nuke_`, `Tank_`, `Demo_`, `Slth_`, `Chem_`, `AFG_`), `Boss_` and campaign copies (`GC_`, `CINE_`, `Cin_`, `MISSION_`) and leaves 1408 objects. A count is objects, not module uses: `FireWeaponUpdate` serves ECM, Microwave and every field object, so the rows below name the object kind, not the module total. Reskins count with their source object's modules. The point of the table is generic versus bespoke. The census, the `port` sheets and their limits (an empty module leaves no record in the dump; `SupW_Upgrade_AmericaPointDefenseDrone` is defined twice, `upgrade.ini:724` and `:796`) are described in the [testing and tooling guide](../guide/13-testing-and-tooling.md).

| Mechanic in the catalogue | Zero Hour module(s) | Objects, all / base only | Kind |
|---|---|---:|---|
| Drones on vehicles | `ObjectCreationUpgrade` on the host (an OCL that creates a `SlavedUpdate` object), `SlavedUpdate` and `UpgradeDie` on the drone | hosts 36 / 7, drones 13 / 3, `UpgradeDie` 13 / 3 | generic |
| Overlord add-ons | `OverlordContain` + `ObjectCreationUpgrade` + `CommandSetUpgrade` | 10 / 2 (contain); 96 / 15 (any `CommandSetUpgrade`) | bespoke contain, generic glue |
| Propaganda aura | `PropagandaTowerBehavior` (radius, heal % per second, weapon bonus) | 14 / 3 | generic |
| Point-defence laser | `PointDefenseLaserUpdate` (weapon, primary and secondary target types, scan rate and range, lead factor) | 17 / 2 | generic |
| Missile deflection (ECM tank) | `FireWeaponUpdate` firing `ECMTankMissileJammer` (`chinavehicle.ini:2441`; `weapon.ini:5850`, `SUBDUAL_MISSILE`) | 4 / 1 | generic |
| Flares (aircraft) | `CountermeasuresBehavior` | 40 / 10 | generic |
| Salvage tiers | `SalvageCrateCollide` (weapon, level or money chance) + `CreateCrateDie` | crates 1 / 1; `CreateCrateDie` 184 / 43 | generic |
| Fire wall, fire fields | The weapon creates `FireWallSegment` / `FireFieldSmall` objects that carry `FireWeaponUpdate` and a timed `DeletionUpdate` (`system.ini:1636-1637`, `:1719-1720`) | 4 / 4 (damage type `FLAME`) | generic |
| Toxin and radiation fields | `Chem_PoisonField*` objects with `FireWeaponUpdate` + `LifetimeUpdate` (`system.ini:1911-1912`). A unit that is hit gets `PoisonedBehavior` | fields 14 / 8 (`POISON`), 5 / 4 (`RADIATION`); victims 168 / 49 | generic |
| Burning | `FlammableUpdate`, `FireSpreadUpdate` | 845 / 441; 10 / 10 | generic |
| Weapon upgrades (Black Napalm, Anthrax, TOW, Uranium) | `WeaponSetUpgrade` | 127 / 26 | generic |
| Armor, health, speed upgrades | `ArmorUpgrade`, `MaxHealthUpgrade`, `LocomotorSetUpgrade` | 154 / 32; 49 / 12; 18 / 4 | generic |
| Weapon bonus upgrades (Nationalism, etc.) | `WeaponBonusUpgrade` | 76 / 21 | generic |
| Death effects (nuclear tanks, Demolition) | `FireWeaponWhenDeadBehavior`, optionally `TriggeredBy` an upgrade | 127 / 49 | generic |
| Battle Bus second life | `BattleBusSlowDeathBehavior` | 6 / 2 | bespoke |
| Combat Cycle riders | `RiderChangeContain` | 11 / 3 | bespoke |
| Self-heal (Junk Repair, heroic) | `AutoHealBehavior` | 97 / 25 | generic |
| Horde | `HordeUpdate` | 13 / 3 | generic |
| Stealth / detection | `StealthUpdate`, `StealthDetectorUpdate` | 132 / 26; 103 / 23 | generic |
| Transports / garrison | `TransportContain`, `GarrisonContain` | 85 / 21; 200 / 184 | generic |
| Deploy to fire (Nuke Cannon) | `DeployStyleAIUpdate` | 10 / 2 | generic |
| Gattling ramp | Weapon fields `ContinuousFireOne/Two/Coast` + weapon bonus | objects with such a weapon 31 / 7 | weapon data |
| Kill pilot, hijack | `DamageType = KILL_PILOT` (`weapon.ini:6289`); `ConvertToHijackedVehicleCrateCollide` | 18 / 4; 6 / 1 | generic |
| Veterancy | `ExperienceTracker` (built in, not a module); the `ExperienceRequired` key | 312 / 67 | generic |
| Power dependency | `Energy` (built in); `DISABLED_UNDERPOWERED`; the `EnergyProduction` key | 268 / 62 | generic |

## What Wargrid has today

Checked at `706eccba`.

| System | State | Where |
|---|---|---|
| Unit and building rows | GDScript `const KINDS` per faction. Units have `class`, buildings do not. Capability keys are optional. | `game/scripts/simulation/definitions/{usa,china,frc}.gd`, `definitions.gd` |
| Weapons, armor | `WEAPONS` (damage, type, range, delay, clip, splash, `affects`, optional `ramp`, scatter) and `ARMOR` percent tables | `definitions/shared.gd` |
| Definitions lint | `KNOWN_KEYS` whitelist for row keys, plus reference and enum checks. Weapon keys are not linted. `contains.accepts` must be a unit class. | `game/tests/test_definitions_lint.gd` |
| Commands | 15 types (move … choose_faction), validated twice, applied in `_apply_orders` | `simulation.gd` (`_payload_fields`, `_validate`, `_apply_orders`), [sim interface](sim-interface.md) |
| Command card | Built in code: production lists, build sub-grid, attack-move, stop, unload. Hotkeys are keyed by role. | `game/scripts/match/hud_model.gd` (`card`, `ORDER_KEYS`, `GRID_KEYS`, `CELL_KEYS`) |
| Transports | Generic `contains` key, one level deep. Passengers fire. Tunnel Hub heals. Passengers are handled when the container dies. | `containers.gd` |
| Horde | Generic `horde` key, timer-staggered rechecks | `horde.gd` |
| Paired production, spawn on complete | China infantry produced in pairs; `spawns_on_complete` on buildings | `china.gd`, `production.gd`, `frc.gd` |
| Salvage | FRC crates, `salvage` and `weapon_tiers` keys. A money branch stands in for the level-up branch, because there is no veterancy yet. | `salvage.gd` |
| Splash, damage types | Exist | `combat.gd` (`_splash`, `_hit`) |
| Gattling ramp | Exists as the weapon key `ramp` | `combat.gd`, `shared.gd` |
| Power | Player-wide supply and demand; slows production and darkens `powered` defences | `simulation.gd`, `combat.gd` |
| Rebuild holes | Exist, with an on-death hook and hole regeneration | `rebuild_holes.gd` |
| Upgrades | **Absent** | – |
| Abilities / special powers | **Absent** (no command) | – |
| Projectiles | **Absent.** Shots are instant hits; presentation draws a travelling dash. | `combat.gd` (`fire`), `world_batch.gd` |
| Timed status effects | **Absent** (only weapon ramp and horde level) | – |
| Ground fields | **Absent** (only crates have an expiry tick) | – |
| Follower units | **Absent** | – |
| Veterancy | **Absent** in the simulation. Chevron drawing exists, dormant, and reads `veterancy` from the snapshot. | `world_view.gd` |
| Death weapons | **Absent.** On-death hooks exist for salvage crates, rebuild holes and passengers. | `salvage.gd`, `rebuild_holes.gd`, `containers.gd` |
| Repair / heal auras | Partial (Tunnel Hub only) | `containers.gd` |
| Stealth, detection, capture | **Absent** (batch B, after fog of war) | – |

Constraints a fresh session must keep ([determinism rules](determinism-rules.md), [the tick](../guide/04-the-tick.md)):
- State lives in dictionaries keyed by ids that are never reused, and in `snapshot()`.
- Iterate in sorted id order.
- Randomness only through `next_random()`; each extra draw shifts every later one.
- `sqrt` is the only allowed float function beyond arithmetic.
- New systems are static `step(sim, …)` functions placed by hand in `simulation.gd` `step()`.
- Tests go only through the [simulation interface](sim-interface.md).

## Shared systems the catalogue needs

Each catalogue line reduces to a few shared systems. The *proposed* shapes follow the existing capability-key style; the design session decides.

### S1 Upgrades (per player and per object)

Upgrades are capability data, per player and per object (user, 2026-11-09). Decided constraints from the [batch A answers](design-answers-2026-11-08.md#ground-batch-a-systems-user-2026-11-09):
- researched upgrades stay when the building that researched them is destroyed;
- add-ons die with their vehicle;
- prerequisites are checked only at queueing.

*Proposed* data:
- An `UPGRADES` table: `scope: player | object`, cost, ticks, prerequisite, `conflicts`.
- On rows, an `upgrades` list of `{on: <upgrade>, effect: <kind>, …}` entries.
- Effect kinds are a closed enum mirroring Zero Hour's generic modules: `weapon` (swap the weapon or add a secondary), `armor`, `max_hp`, `speed`, `weapon_bonus`, `spawn_follower`, `attach_addon`, `death_weapon`, `self_heal`, `passengers_fire`, `card` (swap the card).
- A player upgrade is researched at a building. An object upgrade is bought on the unit and queued like production.
- Conflicts give the one-of-three choice.
- An upgrade can be *removed* when its follower dies, so a drone can be bought again (Zero Hour's `UpgradeDie`).

Serves: TOW Humvee, drones, Overlord modules, Black Napalm, Anthrax, Uranium shells, Nuclear tanks, Junk Repair, Battlemaster propulsion, Rocket Buggy ammo, Bomb Truck payloads, Scorpion rocket, Demolitions.

### S2 Timed status effects

A per-entity list of `{kind, until_tick, source}`, expired by one `Effects.step`.
- *Proposed* kinds: `poisoned`, `burning`, `disabled` (EMP, ECM, microwave, hack, power), `weapon_bonus` (propaganda, designator), `revealed`.
- Readers (combat, movement, production) check a flag; no system reads another system's internals.
- Refresh versus stacking is a per-effect rule and is not decided. Zero Hour's poisoned unit refreshes its duration on each new dose and keeps its running damage interval (`PoisonedBehavior.cpp:164-173`). The owner's "no stacking" answer is about poison *fields* (S4), not about unit effects.

Serves: poison and radiation ticks, Microwave and ECM disable, Laser Lock, Avenger designator, propaganda bonus, power-dependent units (Laser General), hacker disable later.

### S3 Projectiles (travelling shots)

Already decided: all rockets and shells travel, and every combat trace is re-pinned once (blueprint, Ground batch A). That single re-pin also covers turret aiming (blueprint, turret aiming answers, user, 2026-11-10). Decided constraints:
- a shell flies to where its target stood when it was fired;
- tank shells hit structures and walls on the way;
- a unit inside its minimum range backs away first.

*Proposed:*
- A projectile list (`id, owner, weapon, pos, target or point, speed, kind_tags, until`) stepped after movement. Impact runs the existing `_hit` / `_splash`.
- **Point defence** is a scan over projectiles in range.
  - Zero Hour's Paladin laser hits small and ballistic missiles but not shells (`weapon.ini:388-389`: `AntiSmallMissile Yes`, `AntiProjectile No`), so the tags must separate missiles from shells.
  - It falls back to infantry when no missile is in range (`SecondaryTargetTypes INFANTRY`, `americavehicle.ini:1973`).
  - It searches every `ScanRate 500` ms, then tracks and fires every frame until the target dies or leaves range, and re-scans 0 to 3 frames later (`PointDefenseLaserUpdate.cpp:139-152`, `:182`, `:227`, `:259-267`).
- **ECM** jams missiles only (`MissileAIUpdate`). A jammed missile drops its target and flies to a randomly offset ground point (`ActiveBody.cpp:1316-1323`, `MissileAIUpdate.cpp:811-843`). While the ECM tank fires its vehicle-disable weapon, deflection pauses (`ExclusiveWeaponDelay`, `FireWeaponUpdate.cpp:91-128`).

Without S3 the Paladin laser and ECM have nothing to hit. That is why P15 ships the Paladin without its laser, with +10 % HP until the laser lands (packages P15; user, 2026-11-20 and 2026-11-21).

Serves: minimum range, artillery, point-defence laser (Paladin, Avenger), ECM deflection, Patriot assist.

### S4 Ground fields

*Proposed:* a field list (`id, owner, center, radius, weapon, period, until`) on a spatial bucket.
- A weapon or a death effect may create a field.
- Each field fires its weapon every `period` ticks, reusing splash and S2.
- This is Zero Hour's field object with `FireWeaponUpdate` and a lifetime, in one row.
- A fire wall is a line of small fields laid along the attack direction.

Decided (user, 2026-11-09):
- fields hurt everything on the ground, own units included;
- a small poison field lives a fixed 10 s;
- a new field cleans its spot first, so fields never stack;
- hazard damage follows Zero Hour's armour table (tanks 25 % poison, 50 % radiation).

Serves: Dragon Tank wall of fire, Inferno firestorm, Toxin Tractor contamination, Scorpion toxic shells, Nuke Cannon radiation, nuclear death, Anthrax upgrades. Cleanup by Ambulance and Hazmat comes later.

### S5 Follower units

A unit with `follows: <host id>` keeps station near its host, has its own weapon and health, and dies or is orphaned with the host.
- An S1 `spawn_follower` effect spawns it.
- Its death removes the host's upgrade.
- *Proposed:* reuse unit movement with a station target recomputed every N ticks, and no free will in this tier.

Serves: Battle and Hellfire drones. The Scout Drone and Sentry Drone come with batch B, the Spy Drone with aircraft. Angry Mob members may reuse it.

### Smaller additions

| Addition | Serves | Builds on |
|---|---|---|
| Add-on slot (`attach_addon`) | Overlord, Emperor | S1, plus a one-slot add-on mount that is *not* today's `contains`. `contains` is one level deep and accepts unit classes only, while the Battle Bunker needs infantry inside the add-on (nested containment, as `OverlordContain` does). |
| Auras (`aura: {radius, period, heal, bonus}`) | Propaganda module and tower, Ambulance heal and repair, Battle Drone repair | S2, timer-staggered like horde |
| Death effects (`on_death: {weapon, field, become}`) | Nuclear tanks, Demolitions, Battle Bus second life, Combat Cycle drop | S4, spawn, the existing on-death hooks |
| Veterancy | Everything (already placed in A1; chevrons decided, user, 2026-11-08) | S2 bonus multipliers, the dormant chevron drawing |
| Deploy mode | Nuke Cannon, Listening Outpost | Unit state flag and a card toggle |
| Rider change | Combat Cycle | `contains`, with the weapon taken from the passenger |

A1 also holds systems this note does not cover: repair, building prerequisites, turret aiming, line of sight for direct fire, and USA building self-heal (blueprint, Ground batch A). The first step of ground batch A is the overkill-guard spike, which may change the combat random stream (packages, item 5).

### Commands and buttons

Two new commands cover the whole catalogue except general's powers:
- `upgrade` (`{entity or building, upgrade}`), queued and cancelable like `produce`;
- `ability` (`{entities, ability, target entity | point | none}`), for toggles, fire wall, deploy and Laser Lock.

*Proposed:* the command card becomes data, the way Zero Hour's command sets are.
- A row lists `card: [cell, …]` entries (`produce`, `upgrade:<id>`, `ability:<id>`, `order:<id>`).
- `HudModel.card()` reads the list instead of growing a branch per unit.
- Upgrades that swap cells use the S1 `card` effect.
- Hotkeys stay keyed by role on the Q W E R grid.

### Online play: lockstep, wire and relay

Checked against `game/scripts/net/` and `relay/` at `706eccba`.

**The relay needs no change for new commands.**
- It reads only the tick envelope: integer `seat` and `tick`, `commands` an array, a frame of at most 64 KiB (`relay/envelope.go:12`, `:106-112`). It never reads what is inside a command.
- New command types need no relay code, no protocol vector and no conformance change.
- `Wire.PROTOCOL` (`wire.gd:3`) stays at 2, because the envelope shape does not change.

**Version compatibility is not guaranteed today.** The relay refuses clients whose `build` strings differ (`relay/room.go:214`). The client sends only `application/config/version` (`launcher.gd:464`, `headless_client.gd:81`), so two revisions with the same version string can join one match and disagree about which commands exist. The first package that adds a command must make the build string change with it, or add a join check that does.

**The Godot wire layer has one trap.**
- JSON numbers arrive as floats.
- `Wire._tick_extras` converts back to integers only the fields named in `_COMMAND_INTS` (`wire.gd:15`: tick, player, sequence, builder_id, building_id, production_id, source_id, target_id) and the int arrays `entity_ids` and `origin`.
- `_validate` rejects any id field that is not an integer (`simulation.gd:256`).
- A new integer field, such as a host id, an upgrade slot or an ability target entity, must be added in **both** places. Otherwise the command passes every offline test and is rejected in every online match.
- The rejection is deterministic, because a seat's own frame also goes through encode and decode (`lockstep.gd:178-183`). Both seats agree, nothing desyncs, and the button simply does nothing online.
- String fields (upgrade or ability ids) and float point targets (like `move.target`) pass through unchanged.
- `test_wire.gd` already checks payload round trips and integer types, but its command list omits `enter` and `unload` (`test_wire.gd:6`, `:30-47`).

**Lockstep does not care what a command is.**
- `Lockstep.submit` stamps tick, player and sequence, and refuses a command when the queued frame would exceed 64 KiB minus a 256-byte reserve (`lockstep.gd:8`, `:66-77`).
- `_apply_orders` sorts by tick, player and sequence (`simulation.gd:412`).
- Each seat records only its own rejections (`lockstep.gd:142`).
- An `upgrade` or `ability` command is a few dozen bytes.
- Headless clients and replays feed the command log back through `issue_command` (`headless_client.gd:323`).

**Desync detection has two separate paths:**
- **Every 30 ticks, lockstep compares a digest of `snapshot()`** (`simulation.gd:806`, `lockstep.gd:40`, `:166-171`); `tools/desync_diff.py` reads the same snapshot. All new state must be in the snapshot: bought upgrades, conflict state, status effects with their end ticks, projectiles, fields, follower links and veterancy XP. State left out drifts apart without any alarm.
- **The per-tick hash ring** (`_tick_hash`, `simulation.gd:691-726`) hashes only selected live fields: tick, RNG, entity id, owner, HP and position, building work, source boxes and credits. It does not read the snapshot. A new system shows up in the ring only once it changes one of those fields, for example when a projectile hits. Each system's design states whether its own state needs to enter `_tick_hash` for per-tick bisection. Projectiles and fields add ring cost only if they live in `_entities`.

**Checks per new command:**
- a `test_wire.gd` round trip, including the float-to-int conversion of every integer field;
- a `test_lockstep.gd` case where two seats issue it in the same tick and stay hash-equal;
- `sh tools/run_netplay.sh match` green.

A netplay scenario that issues `upgrade` and `ability` belongs with the first package that adds them. *Proposed:* in that package, replace the two hand-kept integer lists with one shared list.

## Presentation

Most mechanics add state the player has no picture for yet, so each one is a look question on top of the simulation work. The simulation stays authoritative; presentation draws state and visual events ([art direction](../art-direction/ART_DIRECTION.md)).

What already exists:
- **The shared shape renderer** (one short shape list per kind, one triangle array per tick) takes new kinds as data.
- **The match batch** (`world_batch.gd`) already draws the horde ring, muzzle flashes, hits, death fades and travelling dashes.
- **Long wrecks** (600 ticks for tanks) exist only in the art lab (`lab/ab_variants.gd:29`). Match deaths use a 60-tick fade (`visual_director.gd`).

### New visual vocabulary

| Visual need | Mechanics | Today | Look question for War Room |
|---|---|---|---|
| Add-on parts on a host shape | Overlord gattling, propaganda and bunker; Humvee TOW; Scorpion rocket | Needed: one fixed shape per kind | Part placement and size; does it read at max zoom-out |
| Small follower shapes | Battle and Hellfire drones | Needed | Drone shape, hover height, station offset, link to its host |
| Upgrade tier marks | FRC salvage tiers I and II, Uranium, Black Napalm, Anthrax | Needed: salvage weapon tiers have no mark | Mark per tier: extra parts, colour band, barrel change |
| Veterancy rank marks | Every unit | Chevrons decided (user, 2026-11-08) and drawn dormant in `world_view.gd` | Advisory only: placement and heroic glow |
| Travelling projectiles | All rockets and shells (S3) | In matches: a short dash, travel faked | Rocket versus shell versus artillery arc; trail length at scale |
| Interception beam and burst | Paladin and Avenger point defence | Needed | Beam colour and duration; a "shot down" burst that differs from a hit |
| Deflected missile path | ECM tank | Needed | How a jammed missile shows it was jammed |
| Ground fields with lifetime | Fire wall, firestorm, toxin, radiation, Anthrax Gamma | Needed | Fire, toxin and radiation colours on the sand and dark biomes; fade with remaining lifetime; overlap readability; cost at 30+ fields |
| Status on a unit | Poisoned, burning, disabled, propaganda bonus, laser lock, designated target | Needed | One icon row or a tint per status; which ones show on enemies |
| Aura radius | Propaganda, Ambulance heal, Battle Drone repair | In matches: horde ring | Reuse the horde ring style or a pulse |
| Second-life and changed shapes | Battle Bus hulk, Nuke Cannon deployed, Listening Outpost hidden, Combat Cycle rider | Lab: long wrecks; in matches: 60-tick fade | Deployed and hulk shapes; rider visible or not |
| Command card cells | Upgrade, ability, toggle and conflicting choices | In matches: production and order cells only | Icon style for upgrades versus abilities; "chosen, others blocked"; research progress on a cell |
| Ability targeting | Fire wall direction, Laser Lock, point targets | Needed: cursor modes are move, attack and build only | Cursor and preview for direction and area |
| Sound | New weapons, intercepts, fields, upgrade completion | Weapon set from the sound spike | New effect sounds and announcer lines (`tools/audio/` pipeline) |

### Look rounds

- **One round per visual family**, serving every mechanic that uses it. One field round covers fire, toxin and radiation.
- **Blocking or advisory** follows the War Room rule in AGENTS.md. Add-on parts, drones, tier marks, field look, status display and card cells are blocking.
- **Static questions** (shape, colour, icons) go to War Room pages.
- **Motion and cost questions** (field fade and overlap, projectile trails, drone orbit, intercept burst) go to the in-game A/B lab, with a rendered benchmark row per candidate. Fields and projectiles are the expensive draw paths.
- **Timing:** a family's round runs one package ahead of the build that needs it.

| Tier | Look rounds |
|---|---|
| T1 | Projectiles, fields, status display, upgrade and ability card cells |
| T2 | Tier marks |
| T3 | USA drones and beams; China add-on parts, fire and radiation; FRC toxin, salvage tiers, Battle Bus hulk, Combat Cycle riders |
| T4 | Stealth look (shimmer or outline, own or enemy), disguise, detection radius; these depend on fog of war |

## Catalogue mapped to systems and order

All tiers are *proposed*.
- T1 to T4 sit inside the placed batches.
- T3 keeps the blueprint's cut of one gate per faction, each with a user playtest (user, 2026-11-07).
- The order inside a faction gate puts the smallest new system first.

| Tier | Batch | Contents | New systems |
|---|---|---|---|
| T1 Foundations | A1 | Upgrades (S1), first playable slice one player upgrade per faction; status effects (S2); veterancy; travelling shots and minimum range (S3); ground fields (S4); data-driven card; `upgrade` and `ability` commands | S1 to S4 |
| T2 Upgrades on today's roster | A1 end | Weapon, armor and speed upgrades on existing units; FRC salvage level-up branch (replaces the money departure); Junk Repair self-heal | – |
| T3 USA | A2 | Point-defence laser on Paladin and Avenger, Laser Lock, Microwave disable and garrison clearing, Ambulance heal, repair and cleanup, Battle and Hellfire drones (S5), Humvee TOW and passengers firing | S5, auras |
| T3 China | A3 | Overlord add-ons (add-on mount, propaganda aura), Dragon fire wall, Inferno firestorm, Nuke Cannon deploy, neutron shells and radiation, ECM deflection and disable, Nationalism on horde, nuclear death, Troop Crawler | add-on mount, auras, death effects, deploy |
| T3 FRC | A4 | Three salvage tiers on every eligible vehicle, Toxin Tractor and toxic shells, Battle Bus second life, Combat Cycle riders, Angry Mob regrowth, Terrorist suicide, Rocket Buggy burst, Scud toxic switch | death effects, rider change |
| T4 Information warfare | B | Stealth and detection, Scout and Sentry drones, Pathfinder, Hijacker, Jarmen Kell pilot kill, capture, Bomb Truck disguise, Black Lotus, Hacker, Radar Van scan, mines, booby traps, Demo Trap, fake buildings | stealth, capture, disguise |
| T5 Later | after B | Aircraft (Helix and its modules, Comanche barrage, Aurora, Raptor ammo and rearming, King Raptor, Chinook supplies and combat drop, MiG firestorm, Stealth Fighter bunker busters); general's powers (the light package follows batch A, the rest later); the nine generals' variants ([generals preparation](zh-generals-prep.md)); superweapons; Laser General power-dependent tanks | aircraft, ranks, powers |

**Catalogue lines not mapped yet.** The design work must place these or record them as departures:
- vehicle crushing;
- civilian building garrison and its clearance (Ranger flashbangs, Dragon, Toxin Tractor, Microwave);
- repair facilities;
- terrain traversal (Burton, Combat Cycle cliffs);
- neutral technology and captured production;
- the structure mechanics:
  - Strategy Center battle plans (the Strategy Center building is in batch A);
  - Patriot target sharing;
  - Reactor overcharge;
  - Internet Center;
  - Tunnel Network relocation and repair;
  - GLA camouflage netting;
  - Black Market;
  - Stinger Site crew replacement;
  - Supply Drop Zone and the end-game income placement (blueprint, End-game income, not placed).

Already in Wargrid: China paired infantry production, horde, transports with passengers firing, gattling ramp, power, rebuild holes, salvage weapon tiers.

## Preparation work

Precedent: `tools/zh_generals.py` turned "nine generals" into a generated, diffable report from the dump, and `tools/check_reference.py` keeps Wargrid's numbers tied to the INI.

**Before any package:**
1. **Port sheets, as subcommands of `tools/zh_generals.py`.** It already has `command_sets_of` (including `CommandSetUpgrade`), `buttons`, `walk_roster`, `object_summary` and `_module_census`.
   - `port <Object>` lists every module that has fields, with keys and line citations, and the command set resolved to buttons (`Command` type, upgrade, object, weapon slot).
   - It lists the upgrades the object reacts to, with `TriggeredBy` / `ConflictsWith` and the `Upgrade` block's type, cost and time.
   - It lists weapon sets with `Conditions`, and resolves OCLs one level to the objects they create and *their* modules.
   - A `census` subcommand counts objects per mechanic.
   - Known dump limits must be reported, not hidden: a module opener with no fields leaves no record (`zh_ini.py:154-158`), and some upgrade names are defined twice (`upgrade.ini:724`, `:796`).
   - Output goes under `build/` (never committed).
   - *Built* (2026-11-28): `port`, `port --roster` and `census [--base-only]` exist in the tool; usage in the [development notes](../development.md) and the [testing guide](../guide/13-testing-and-tooling.md).
2. **One design-input note per shared system.** It holds the Zero Hour behaviour from the source with citations, Wargrid's hook points (file, function, tick slot, snapshot and hash fields), randomness draws, performance cost, and recorded departures. It is input for the A1 design, not the design itself.
3. **A question file** (`docs/questions/`) for design points the blueprint and design answers do not settle, each with the Zero Hour default and a recommendation.
4. **A War Room seed list:** one planned round per visual family, with the mechanics it serves, blocking or advisory, War Room page or lab, and the tier it must precede.
5. **Parity scenario specs** for the mechanics with feel-critical timing: point-defence intercept rate against a rocket volley, fire wall damage over time, poison duration, propaganda heal rate, drone station-keeping. Results go to a decision list ([parity harness](zero-hour-parity-harness.md)).

**With the package that needs it:**
- definitions lint for each new row key and the new weapon keys;
- a benchmark layout for many projectiles in flight and one for many overlapping fields, before S3 and S4 ship;
- the single integer-field list for commands.

Not proposed:
- a generic module engine mirroring Zero Hour's module classes. Wargrid's optional row keys are cheaper and already work.
- a test-matrix generator for new commands.
- a generated coverage ledger. The tables above are the map; package state stays in [STATUS](../STATUS.md).

## Risks

- **Performance.** Combat stress, horde plumbing and 3v3 rows already exceed budget ([performance ledger](performance.md)), and projectiles and fields are per-tick objects. Mitigations:
  - bucket fields on a grid;
  - stagger aura and point-defence searches by id;
  - gate every system on its benchmark row.
- **Determinism.** Point-defence re-scan delay, scatter, ECM redirect and salvage chances need simulation randomness in a fixed draw order. Every new draw shifts later ones, so trace re-pins come in planned batches.
- **Trace churn.** Travelling shots and turret aiming share one re-pin of every combat trace. The overkill-guard spike comes first in batch A and may shift the random stream again. Do both in T1, before any T3 package depends on stable traces.
- **Online compatibility.** The first new command needs a build check that refuses mixed revisions ([Online play](#online-play-lockstep-wire-and-relay)).
- **HUD space.** A Crusader card has three drone cells plus orders, and an Overlord swaps its card after an add-on. The card layout test must cover the largest card per faction.
- **Selection panel.** The kind-row cap (the seventh selectable kind, [layout reference](hud-v5-layout.md)) counts drones only if they are selectable. Fields never count.
- **Scope creep.** The catalogue is a roster several times the size of M7. Hold the blueprint's rule of packages of two or three units, each with its own playable slice and owner match.

## Open points for the owner

Scope and taste only.

1. Is the data-driven command card part of T1, or a HUD package of its own before it?
2. Within each faction gate, which signature comes first? Recommendations: the Paladin laser for USA, Overlord add-ons for China, salvage tiers for the FRC.
3. Look rounds: one per visual family across all factions (fewer rounds, earlier), or per faction with its gate (later, more context)?
