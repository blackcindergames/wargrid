# Zero Hour generals: preparation

Groundwork for the later package that adds Zero Hour's nine generals, the general variants of the three factions ([packages](../packages.md): after P9; [blueprint](../blueprint.md) scope lines 27 and 42). This note does not start that package and makes no design decision. It collects four things:

- how Zero Hour builds a general;
- what each general changes compared with its base faction;
- what that means for Wargrid's data and systems;
- a tool that re-derives the per-general differences from the retail INI.

Everything below labelled "proposed" waits for the owner.

Sources:

- **EA source:** `~/projects/CnC_Generals_Zero_Hour` at `0a05454d8574207440a5fb15241b98ad0b435590`, `GeneralsMD/Code/` only. Paths are cited relative to `GeneralsMD/Code/GameEngine/`, with `S/` = `Source/` and `I/` = `Include/`.
- **EA's GPL map sources:** `~/projects/CnC_Modding_Support` at `3aad8e412961ab543192ae70f8503dc8e178e095`, folder `Zero Hour/Maps/`.
- **Retail INI:** read only for the per-general table. Its provenance and confidence are covered under [Retail INI evidence](#retail-ini-evidence).

## Summary

1. **A general in Zero Hour is a player template plus a full prefixed copy of its faction.** Examples are `FactionChinaTankGeneral` with `Tank_ChinaWarFactory` and `Tank_ChinaTankBattleMaster`. The simulation has no "general" concept. Most of each copy is unchanged: for 11 to 21 of the 26 to 33 objects in a general's roster, nothing the report compares differs from the base object. Wargrid should write only the difference.
2. **What the generals actually change falls into a few kinds:**
   - costs and build times;
   - a few roster swaps (0 to 1 units added and 0 to 4 removed per general);
   - weapon swaps;
   - about a dozen behaviour module kinds (start veteran, stealth, suicide on death, weapon tiers by upgrade, point-defence laser, free upgrade on creation);
   - their own science purchase trees and general's powers.

   Every one of these is a generic engine module. None is code written for one general.
3. **Wargrid's roster is too small for generals today.** All nine generals change some of today's kinds (12 USA, 12 China, 10 FRC, plus FRC rubble), and four of them remove a factory unit:
   - USA Air Force and Superweapon lose the Battle Tank (Crusader), so their factory is left with one unit;
   - China Infantry loses Militia (Red Guard), Medium Tank (Battlemaster) and Rotary Gun Tank (Gattling Tank), so its factory produces nothing;
   - FRC Stealth loses the Light Tank (Scorpion).

   Generals only make sense once batch A's ground roster and the systems in point 5 exist ([what generals mean for today's roster](#what-generals-mean-for-todays-roster)).
4. **Wargrid's simulation is already faction-free, but its data model makes variants expensive.** Build lists live on the builder and factory kinds (`builds`, `produces`) and costs are keyed by kind id alone. So one changed unit forces new ids for its factory, its builder and the headquarters that trains the builder. The cheapest preparation is a data-shape change, not new systems ([readiness audit](#wargrid-readiness-audit), [proposed preparation steps](#proposed-preparation-steps)).
5. **The systems the generals need, ranked by how many generals use them:**
   - player rank with purchasable sciences (9 of 9);
   - general's powers with per-player timers (9);
   - upgrade-driven module effects: weapon tiers, an added button, free upgrades at creation, extra health (8);
   - stealth (3);
   - veterancy (2 directly, all nine through science purchases);
   - aircraft (Air Force most).

   Most are already on the roadmap for other reasons (batch B, powers light, aircraft), so generals mostly reuse them.
6. **New tool:** `python3 tools/zh_generals.py report` turns the local INI dump into a per-general diff. It was checked against a community copy of the retail INI (nine generals found, results in [the per-general table](#what-each-general-changes)). The owner's archive still has to confirm it: `RealDumpTest` runs once `build/zh_ini/inizh.jsonl` exists.

## How Zero Hour builds a general

### Player template

A general is a `PlayerTemplate` block (fields `S/Common/RTS/PlayerTemplate.cpp:75-124`).

**Fields that matter for gameplay:**

- `Side`: the general's own identity, for example `ChinaTankGeneral`.
- `BaseSide`: `USA`, `China` or `GLA`.
- `StartingBuilding` and `StartingUnit0..9` (`:81-91`).
- `ProductionCostChange`, `ProductionTimeChange` and `ProductionVeterancyLevel` (`:92-94`). These are per-object modifiers on the template, applied in `Player.cpp:1966-1990`. None of the nine generals uses them in the checked INI: they change prices through their own object copies instead.
- `IntrinsicSciences` (`:95`).
- `PurchaseScienceCommandSetRank1/3/8` (`:96-98`): the three pages of the general's science store.
- `SpecialPowerShortcutCommandSet` (`:99`): the general's-power bar.

**What reads `Side` and what reads `BaseSide`.** The simulation reads `Side` everywhere it matters:

- skirmish scripts and teams: `Player.cpp:835,864,902`;
- the AI build list and the AI's science choices: `AISkirmishPlayer.cpp:1079-1086`, `AIPlayer.cpp:2945`;
- the "my command centre" check: `Player.cpp:1251`;
- the "player is faction" script condition: `ScriptConditions.cpp:2205`.

`BaseSide` is read only by presentation and statistics: the score screen (`ScoreScreen.cpp:2183`), rank images (`PopupPlayerInfo.cpp:1066`) and Academy hints (`S/Common/RTS/AcademyStats.cpp:118-120`). No prerequisite or buildability check looks at either side. A general's units can build only what their command sets offer (next section).

**The lobby** lists one entry per unique `Side` plus Random and Observer (`S/GameNetwork/GUIUtil.cpp:238-294`). Random picks among the same set (`S/GameLogic/System/GameLogic.cpp:719-790`). The challenge boss (`Side = Boss`) is kept out of ladders and statistics by name (`LadderDefs.cpp:183`).

### Objects are full prefixed copies

Each general has its own object for nearly every unit and building of its faction: `AirF_`, `Lazr_`, `SupW_`, `Tank_`, `Infa_`, `Nuke_`, `Chem_`, `Demo_` and `Slth_`. The Air Force Combat Chinook alone uses `AFG_`.

- The score screen names the prefixed superweapons directly (`ScoreScreen.cpp:1135-1173`).
- EA's own test map `AllBuildingsAllSidesUnitTest_Save` places the prefixed copy of every base building for every general (CnC_Modding_Support, see [GPL map evidence](#gpl-map-evidence)).

The engine offers four copy mechanisms. The INI uses them unevenly:

- **`ObjectReskin <new> <old>`** (`S/Common/INI/INIObject.cpp:54-59`): copies the old object in full, then re-reads only draw, geometry and shadow. Reskins count as the same object for prerequisites (`ThingTemplate::isEquivalentTo`, `S/Common/Thing/ThingTemplate.cpp:1478-1515`).
- **`AddModule`, `RemoveModule <tag>` and `ReplaceModule <tag>`** (`ThingTemplate.cpp:739-811`): edit one module by tag.
- **A `DefaultThingTemplate`** that every object copies first (`S/Common/Thing/ThingFactory.cpp:138-146`), with `InheritableModule` and `OverrideableByLikeKind` defaults (`ThingTemplate.cpp:240-242,815-848`).
- **`BuildVariations`** (`ThingTemplate.cpp:157`): a random pick among looks at creation.

Even so, the shipped general files mostly repeat whole `Object` blocks, unchanged fields included. That is why most of each general's roster compares as "unchanged".

### Build lists are command sets

What a dozer, worker or factory can make is not a field on the unit. It is the set of buttons in the object's `CommandSet` (`ThingTemplate.cpp:156`; buttons 1 to 18, `S/GameClient/GUI/ControlBar/ControlBar.cpp:707-724`):

- A `DOZER_CONSTRUCT` or `UNIT_BUILD` button names its `Object`.
- `Player::canBuild` then checks permission, `Buildable` and the prerequisites (`Player.cpp:2912-2950`). A prerequisite is an OR list of objects or a science (`ProductionPrerequisite.cpp:155-190`).
- A `CommandSetUpgrade` module swaps an object's set after an upgrade (`S/GameLogic/Object/Upgrade/CommandSetUpgrade.cpp:45-101`). The Demolition general uses this on 15 objects to add the suicide button.

A general therefore differs from its faction because each prefixed builder, factory and command centre points at a prefixed command set. It does not differ because of a rule anywhere in the code.

### Rank, sciences and general's points

- **Ranks** are data blocks (`S/GameLogic/System/RankInfo.cpp:120-131`): `SkillPointsNeeded`, `SciencesGranted` and `SciencePurchasePointsGranted`.
- **Skill points** come from kills: the victim's `SkillPointValue`, which falls back to `ExperienceValue` (`Player.cpp:2494-2506`, `ThingTemplate.cpp:1392-1399`). Special abilities and scripts can also award them.
- **Each new rank** grants its sciences and purchase points (`Player.cpp:2686-2760`).
- **A science can be bought** when its `PrerequisiteSciences` are owned and its cost is above 0 and within the points left (`Player.cpp:2636-2666`).
- **Owning a science** wakes every special-power module that requires it (`Player.cpp:2535-2584`).
- **All nine generals keep their faction's intrinsic science** (`SCIENCE_AMERICA`, `SCIENCE_CHINA` or `SCIENCE_GLA`). What differs is which science buttons their three store pages hold.

### General's powers

**The power template** (`S/Common/RTS/SpecialPower.cpp:197-209`) has these fields:

- `ReloadTime`;
- `RequiredScience`;
- `PublicTimer`, which shows the timer to all players;
- `SharedSyncedTimer`, which keeps one countdown per player for that power, stored on the player (`Player.cpp:3293-3360`), so building a second command centre does not double it;
- the view-reveal and cursor fields.

**The power is carried out by a module on an object**, usually the command centre:

| Module | What it does |
|---|---|
| `OCLSpecialPower` | Spawns an object creation list: airstrikes, paradrops, the Carpet Bomb, the Tank Drop |
| `CashBountyPower` | Pays a percentage of each kill's value |
| `CashHackSpecialPower` | Steals money |
| `DefectorSpecialPower` | Converts an enemy unit |
| `SpyVisionSpecialPower` | Shares the enemy's vision for a while |
| `FireWeaponPower` | Fires a weapon at the target |
| `CleanupAreaPower` | Orders a unit to clean up an area |
| `BaikonurLaunchPower` | Launches the campaign rocket |
| `SpecialAbility` | A unit's own ability |

All are in `S/GameLogic/Object/SpecialPower/`. Update modules such as `SpecialAbilityUpdate` and `ParticleUplinkCannonUpdate` carry out the longer powers.

**A wart to avoid.** Zero Hour gave each general's copy of a power its own value in the power-type enum (`SUPW_`, `LAZR_`, `AIRF_`, `NUKE_`, `INFA_`, `SLTH_`, `EARLY_`; `I/Common/SpecialPowerType.h:102-128`). The reason: the shortcut bar found a power by type and mixed up powers from captured command centres. Wargrid should key powers by id from the start.

### AI

The skirmish AI keeps a `SideInfo` (gatherer counts, base defence, `SkillSet1..5` science lists) and a `SkirmishBuildList` per `Side`, matched by string with no fallback to the base side (`S/GameLogic/AI/AI.cpp:145-298`, `AISkirmishPlayer.cpp:1079`). Each general has its own bot build list and science order.

### Hard-coded exceptions

The C++ hard-codes a few upgrade names:

- `Upgrade_Nationalism` and `Upgrade_Fanaticism` (horde bonus, `AIUpdate.cpp:4689-4700`);
- `Upgrade_ChinaEMPMines` (`GenerateMinefieldBehavior.cpp:469`);
- `Upgrade_AmericaChemicalSuits`, `Upgrade_GLAWorkerShoes` and `Upgrade_AmericaSupplyLines`.

It also hard-codes the per-general power types and superweapon names above. Nothing else is special-cased for one general: the Demolition general's suicide, the Toxin general's anthrax and the Stealth general's camouflage are generic modules (`FireWeaponWhenDeadBehavior`, `WeaponSetUpgrade`, `StealthUpdate`, `StealthUpgrade`).

## What each general changes

Counts come from `tools/zh_generals.py` run against the retail INI copy described under [Retail INI evidence](#retail-ini-evidence). They are **provisional** until rerun against the owner's archive.

- "Changed" means the general's copy differs from the base object in at least one compared field: cost, build time, health, weapons, armor, locomotor, prerequisites or module classes.
- The roster is what the general's command sets can reach, including one Biohazard Tech button the USA base sets reach that no USA general does.

| General (base) | Prefix | Added | Removed | Changed | Unchanged | Powers (own / lost) | Sciences (own / lost) |
|---|---|---|---|---|---|---|---|
| Air Force (USA) | `AirF` | 1 | 3 | 13 | 14 | 2 / 1 | 7 / 6 |
| Laser (USA) | `Lazr` | 0 | 3 | 6 | 21 | 1 / 0 | 0 / 1 |
| Superweapon (USA) | `SupW` | 0 | 3 | 12 | 15 | 2 / 2 | 4 / 3 |
| Tank (China) | `Tank` | 1 | 3 | 12 | 14 | 3 / 3 | 8 / 9 |
| Infantry (China) | `Infa` | 1 | 4 | 13 | 12 | 3 / 2 | 6 / 6 |
| Nuke (China) | `Nuke` | 0 | 0 | 12 | 17 | 3 / 3 | 4 / 5 |
| Toxin (GLA) | `Chem` | 0 | 2 | 16 | 17 | 0 / 2 | 0 / 2 |
| Demolition (GLA) | `Demo` | 0 | 2 | 22 | 11 | 2 / 0 | 0 / 2 |
| Stealth (GLA) | `Slth` | 1 | 3 | 18 | 14 | 1 / 2 | 3 / 6 |

"Own" powers and sciences include `Early_` copies: the same power offered at a lower rank, for example `Early_SCIENCE_EmergencyRepair1`. Six generals use them.

**Per general.** These are the main points from the report. Costs are retail dollars; build times are seconds.

- **Air Force.**
  - Roster: adds the Combat Chinook (`AFG_AmericaVehicleChinook`, built at the Supply Center); drops the Crusader and the Paladin.
  - Cheaper aircraft with more health, and point-defence lasers on the Aurora, Raptor, Stealth Fighter and Chinook (`PointDefenseLaserUpdate`). For example: Raptor $1400 → $1100 with 160 → 240 health; Airfield $1000 → $800 with 1500 → 2500 health.
  - The Stealth Fighter needs no science.
  - Stealth Comanche upgrade (`StealthUpgrade`).
  - Carpet Bomb power on the Strategy Center (`OCLSpecialPower`); Spectre Gunship 1 to 3 in place of the solo Spectre.
  - Dearer ground vehicles (Humvee $700 → $800).
  - The Chinook takes 25 s instead of 10 s and needs the War Factory.
- **Laser.**
  - Laser Crusader (`Lazr_CrusaderTankGun`), laser Patriot (`Lazr_PatriotMissile*`), and a Laser Cannon power (`Lazr_LaserCannon`; EA's test map places `Lazr_AmericaLaserCannon` and `Lazr_AmericaLaserCannonUplink`).
  - Paladin and Tomahawk removed.
  - Power Plant $800 → $700; Avenger $2000 → $1500.
  - The Fire Base gains a special ability.
- **Superweapon.**
  - EMP Patriot (`SupW_PatriotMissile*`, $1000 → $900, `EMP_HARDENED`); Aurora Alpha fuel bomb; Particle Cannon $5000 → $2500.
  - Crusader and Paladin removed.
  - Dearer units and Power Plant (Humvee $700 → $850, Power Plant $800 → $900).
  - Leaflet Drop moved to an earlier rank.
- **Tank.**
  - Emperor Overlord (`Tank_ChinaTankEmperor`, built at the War Factory) replaces the Overlord; Inferno Cannon and Nuke Cannon are removed.
  - Cheaper tanks: Battlemaster, Dragon and Gattling $800 → $700. Tanks start veteran (`VeterancyGainCreate`), and `SCIENCE_BattlemasterTraining` makes Battlemasters elite.
  - Dearer infantry and aircraft (Red Guard $300 → $375, MiG $1200 → $1600).
  - Tank Drop power; Autoloader upgrade.
  - Loses Cash Hack and Napalm Strike.
- **Infantry.**
  - Mini-Gunner replaces the Red Guard.
  - No Battlemaster, no Gattling Tank, no Overlord.
  - Infantry start veteran (`VeterancyGainCreate`).
  - Free upgrades on its buildings (`GrantUpgradeCreate` on the command centre, Barracks and War Factory).
  - Assault Troop Crawler with a Propaganda Tower (`PropagandaTowerBehavior`), and a Listening Outpost with a Propaganda Tower.
  - Infantry Paradrop power.
- **Nuke.**
  - Same roster.
  - Nuclear weapons on the Battlemaster, Overlord and MiG (`Nuke_BattleMasterTankGun`, `Nuke_OverlordTankGun`, `Nuke_MiGMissileWeapon`), and `Nuke_FusionBattleMasterLocomotor` with the speed upgrade built in. A Helix nuke bomb upgrade is in the roster (`Nuke_Upgrade_HelixNukeBomb`).
  - Isotope Stability and Tactical Nuke MiG upgrades.
  - Dearer Power Plant ($1000 → $1200) and infantry.
- **Toxin.**
  - Toxin weapons with an Anthrax Beta and Gamma tier swap on infantry, the Tunnel Network, the Scorpion and the Scud (`WeaponSetUpgrade`, `Chem_Upgrade_GLAAnthraxGamma`).
  - Rebels wear their own armor (`ChemReb_HumanArmor`).
  - Hijacker and Saboteur removed; GPS Scrambler and Booby Trap lost.
  - Most units dearer (Rebel $150 → $200, Rocket Buggy $900 → $1100).
- **Demolition.**
  - A suicide upgrade (`Demo_Upgrade_SuicideBomb`) adds a detonate button and a death explosion to nearly every unit and to the Barracks and Tunnel Network (`CommandSetUpgrade` on 15 objects, `FireWeaponWhenDeadBehavior` on 12).
  - High-explosive weapon copies (`RED*`, `DEMO_*`).
  - Jarmen Kell's timed and remote charges.
  - Demo Trap $400 → $200 and buildable from the Supply Stash on.
  - Hijacker and Saboteur removed.
- **Stealth.**
  - Every base building can be camouflaged (`StealthUpdate` and `StealthUpgrade` on 12 objects).
  - Rebel, Stinger Site and Tunnel Network appear stealthed from the start (`GrantUpgradeCreate` added, `StealthUpgrade` removed; inference from the modules, not checked in game).
  - The Hijacker needs no science ($400 → $600).
  - Scorpion, Marauder and Scud Launcher removed.
  - A Terrorist Combat Cycle (`GLAVehicleCombatBikeTerrorist`) is reachable from the Arms Dealer set; whether the game shows it is unchecked.

### Module classes the generals add

These are the behaviour module classes on a general's copy that its base object lacks, summed over all nine generals. This is the list of systems a general needs that a base faction's units do not use:

| Module class (Zero Hour) | Objects (generals) | Wargrid system |
|---|---|---|
| `StealthUpdate` (`StealthUpgrade` on 13) | 14 (Stealth 12, Air Force 1, Infantry 1) | stealth, batch B |
| `CommandSetUpgrade` | 15 (Demolition) | upgrades that add a button |
| `FireWeaponWhenDeadBehavior` | 13 (Demolition 12, Toxin 1) | death weapon |
| `GrantUpgradeCreate` | 10 (Infantry 4, Stealth 4, Toxin 1, Demolition 1) | free upgrade at creation |
| `VeterancyGainCreate` | 6 (Tank 3, Infantry 3) | veterancy |
| `WeaponSetUpgrade` | 5 (Toxin 3, Tank 1, Demolition 1) | weapon tier swap by upgrade |
| `PointDefenseLaserUpdate` | 4 (Air Force) | missile interception, after aircraft |
| `SpecialAbility` + `SpecialAbilityUpdate` | 2 (Laser, Demolition) | unit abilities |
| `MaxHealthUpgrade` | 3 (USA generals' Avenger) | health upgrade |
| `PropagandaTowerBehavior` | 2 (Infantry) | aura heal |
| `AssaultTransportAIUpdate` | 2 (Tank, Nuke Listening Outpost) | transport behaviour |
| `OCLSpecialPower`, `ObjectCreationUpgrade` | 1 each (Air Force, Superweapon) | general's powers |

Counts are per object from the report's `modules_added`. Empty modules leave no trace in the dump, so a module with no fields can be missing (see [tool limits](#limits)).

## What generals mean for today's roster

Wargrid's 34 kinds stand in for these Zero Hour objects (stats in [M7 factions](m7-factions.md)):

| Faction | Zero Hour objects |
|---|---|
| USA | Dozer, Chinook, Ranger, Missile Defender, Crusader, Humvee, Command Center, Power Plant, Supply Center, Barracks, War Factory, Patriot |
| China | Dozer, Supply Truck, Red Guard, Tank Hunter, Battlemaster, Gattling Tank, Command Center, Power Plant, Supply Center, Barracks, War Factory, Gattling Cannon |
| FRC (GLA) | Worker, Rebel, RPG Trooper, Technical, Scorpion, Command Center, Supply Stash, Barracks, Arms Dealer, Tunnel Network |

Applied to these kinds alone, the generals change this:

| General | Today's kinds removed | Today's kinds changed |
|---|---|---|
| Air Force | Battle Tank | Scout Car $700 → $800; Supply Helicopter 25 s, needs the factory, point-defence laser |
| Laser | none | Battle Tank and Missile Battery get laser weapons; Power Plant $800 → $700 |
| Superweapon | Battle Tank | Scout Car $700 → $850; Power Plant $800 → $900; Missile Battery EMP, $1000 → $900 |
| Tank | none | Medium Tank and Rotary Gun Tank $800 → $700; Rotary Gun Tank starts veteran; Medium Tank gets a second gun by upgrade and an elite-training science; Militia and Anti-Tank Trooper $300 → $375 |
| Infantry | Militia, Medium Tank, Rotary Gun Tank | Anti-Tank Trooper starts veteran with own armor; free upgrades on Headquarters, Barracks and Vehicle Factory |
| Nuke | none | Medium Tank nuclear gun and faster locomotor; infantry $300 → $350; Power Plant $1000 → $1200 |
| Toxin | none | Insurgent $150 → $200, toxin gun and own armor; Rocket Fighter, Light Tank and Tunnel Hub toxin tiers |
| Demolition | none | Laborer, Insurgent, Rocket Fighter, Light Tank and Tunnel Hub get suicide; Armed Pickup $500 → $600 |
| Stealth | Light Tank | Insurgent $150 → $200 and stealthed; every building can be camouflaged |

Two conclusions:

- **Cost-only generals are possible today.** Laser, Tank and Nuke (and partly Toxin) could be represented on the current roster with cost and weapon changes only, if veterancy and weapon tiers were left out. But Laser and Nuke play differently through their weapons. A laser that is only renamed would be a hollow variant.
- **The others need a bigger roster.** Air Force, Superweapon, Infantry and Stealth remove a factory unit. With two units per factory they would ship a factory with one unit (Air Force, Superweapon, Stealth) or none (Infantry). The generals package should come after batch A's ground roster at least, which matches its place after P9.

## Wargrid readiness audit

Read-only audit of the tree at `111e17e` (2026-11-21).

**Already ready:**

- The simulation never branches on faction; it reads capability data by kind id. The faction id is read only when a seat is set up (`game/scripts/simulation/simulation.gd:160-163`). `tools/test_faction_guard.py` enforces this.
- The wire format and replays carry the faction as a free string. The relay passes it through (`game/scripts/net/wire.gd`, `relay/room.go:246`). There is no enum and no bit width to widen.
- The lobby dropdown lists every `FACTIONS` key (`game/scripts/launcher.gd:361-368`).
- The HUD build menu is derived from the faction entry (`game/scripts/match/hud_model.gd:30-57`).

**Would break or mislead with a fourth faction id:**

| Location | Problem |
|---|---|
| `game/scripts/simulation/definitions/definitions.gd:27-30,105-111` | Lookup tries Usa, then China, then Frc. The same id in two files is silently shadowed and listed twice in `units()` and `buildings()`. |
| `definitions.gd:65-84` | Unit and building caches are keyed by kind id only. A per-variant cost needs its own id. |
| `definitions.gd:100-103` `_producer_of` | A unit has one producer: the first building that lists it. A base factory and a variant factory sharing a unit report only one. |
| `builds` and `produces` on kinds (`usa.gd` and the others) | One changed unit ripples into new ids: the unit, then its factory (new `produces`), then the builder (new `builds`), then the headquarters (new `produces`), then every `prerequisite` that names them. |
| `game/scripts/simulation/combat_definitions.gd:31-32`, `shared.gd:3-12` | A damage type missing from an `ARMOR` row does 0 damage with no error. A new laser damage type would fail silently. |
| `game/scripts/presentation/shapes.gd:15,37-55` | Draw roles come from kind-id suffixes and a tank table. An unknown prefix draws as a small box. |
| `game/scripts/presentation/sound_cues.gd:21-31` | A new damage type needs a shot sound (`test_sound.gd:107` enforces this). |
| `skirmish.gd:49-51`, map slots, `tools/zh_map/convert.py:33-37` | The bot places buildings by six fixed slot names. A variant building must reuse one. |
| `game/tests/test_hud.gd:1838` | Asserts exactly `["china","frc","usa"]`. |
| `debug/combat_workload.gd:327-345`, `lab/hud_capture.gd:175` | Build ids as `<faction>_<suffix>` and parse the prefix. |
| `tools/test_faction_guard.py:12` | Knows only the three base prefixes. A new prefix would slip past the guard. |

**Verdict.** At runtime, a general fits best as its own `FACTIONS` entry (its own start kinds, build order and units list). That keeps the "capability data, not branches" rule (blueprint §14). A runtime overlay that changes `usa_tank` for one player only would put the faction into every lookup.

Unchanged kinds can be shared by id; only changed kinds need rows. The cost is the ripple above. It shrinks if build lists stop living on the builder and factory rows.

## Proposed preparation steps

These are ordered by gain for effort. None is approved. Steps 1 to 3 are small enough for one technical package if the owner wants them before the generals package; the rest belong to the generals package or to systems already planned.

1. **Definitions lint against shadowing** (proposed). These tests fail when:
   - an id is defined in two faction files;
   - a unit has more than one producer;
   - a damage type is missing from any `ARMOR` row.

   All three are silent today. This is cheap now and pays off with the first new kind of any package, not just generals.
2. **Row inheritance at load** (proposed): a kind row may say `"extends": "usa_tank"` and list only what differs. It is expanded once at load into a `static var`, then frozen with the other caches (`definitions.gd:21,120`).

   This is how a general should be written: Tank's Medium Tank is `extends china_tank`, cost 700, veteran. Zero Hour repeats whole blocks instead. The Zero Hour data shows 11 to 22 changed objects per general, most of them cost-only, so this decides whether a general is about 20 short rows or about 30 full ones.
3. **Draw role as data** (proposed): an explicit `role` key, instead of `shapes.gd` guessing from the id suffix and the tank table. Then a variant kind id (`usa_laser_tank`) draws right without a code change. Batch A's new units need the same thing.
4. **Faction-level build lists** (proposed, larger): move "what this builder can build" and "what this factory trains" from the kind rows into the faction entry (`FACTIONS[...].builds` and `.produces`, keyed by building kind). Then a general that removes one unit changes one list in its faction entry; its factory, builder and headquarters can stay shared ids.

   This matches Zero Hour, where command sets, not objects, hold the build lists. The cost is touching `construction.gd:71`, `simulation.gd:299`, `_producer_of`, the bot and the HUD model. Worth doing before batch A widens the rosters, or at the start of the generals package. The owner decides.
5. **A power model keyed by id** (proposed, for the powers light package): a per-player timer keyed by power id, with a shared timer across sources, the source object picked at use, and a required science. Do not copy Zero Hour's per-general enum duplication ([General's powers](#generals-powers)).
6. **A rank and science model** (proposed, with powers): three store pages per faction entry, prerequisites as a science list, a cost in purchase points, and kill points from unit cost or an explicit value (as `SkillPointValue` falls back to `ExperienceValue`). All nine generals are defined by their store pages, so this is the core data of a general.
7. **Per-general bot data** (proposed): the bot already reads build order and units from the faction entry (`skirmish.gd:26-31`). A general's entry carries its own lists, as Zero Hour's `SkirmishBuildList` does per `Side`. No new code until the bot buys sciences.
8. **Lobby grouping** (proposed, UI, needs the player-experience reviewer): twelve flat entries sorted alphabetically read badly. Zero Hour groups generals under their faction with a portrait. This is a War Room look round when the package starts.

**Systems the generals need, and where they come from:**

| System | Generals that need it | Already planned in |
|---|---|---|
| Rank, sciences, general's powers | 9 | General's powers light ([packages](../packages.md)) |
| Upgrades: weapon tier, command-set button, free at creation, extra health | 8 | Batch A upgrades ([blueprint](../blueprint.md) line 610) |
| Stealth | 3 (Stealth, Air Force, Infantry) | Batch B |
| Veterancy | 2 directly (Tank, Infantry), every general via the science purchases | Not designed (blueprint: no player rank, no veterancy in batch A) |
| Aircraft | 4 (Air Force most) | Aircraft milestone |
| Death weapon, suicide button | 2 (Demolition, Toxin Demo Trap) | Not planned |
| Superweapons | 3 (Laser Cannon, cheap Particle Cannon, nuclear and Scud Storm copies) | Deferred by the owner |

## Tools

### `tools/zh_generals.py`

```sh
python3 tools/zh_ini.py dump          # once: retail INIZH.big -> build/zh_ini/inizh.jsonl
python3 tools/zh_generals.py report   # -> build/zh_generals/generals.md and generals.json
python3 -m unittest tools.test_zh_generals
```

**What it does:**

1. Each playable player template is a roster root: its starting building and units. The challenge boss (`Side = Boss`) is left out unless `--all` is given.
2. The tool follows each object's `CommandSet` and `CommandSetAlt`, including sets swapped in by upgrade modules. It takes `DOZER_CONSTRUCT`, `UNIT_BUILD` and `SPECIAL_POWER_CONSTRUCT` buttons as roster, upgrade buttons as upgrades, and power buttons as powers.
3. It adds the three science store pages and the power shortcut set.
4. The base faction is the template whose starting building has no prefix. A general's object pairs with the base object of the same name once the general's prefix is stripped.
5. For each pair it compares cost, build time, vision, health, armor, weapon names (prefix kept, so a general's own weapon counts as a change), locomotor, prerequisites (prefix stripped), `KindOf` (as a set) and module classes. Weapon field deltas are listed when both weapons are defined.
6. `ObjectReskin` inherits its source's fields.
7. The exit code is 1 when no general is found or when a name is defined twice.

**Tests:** `tools/test_zh_generals.py` runs on invented INI text through the real `zh_ini` parser and needs no retail data. It covers:

- roster walking, prefix pairing, reskin inheritance;
- cost, weapon and module deltas, `KindOf` order;
- science, power and upgrade sets;
- the boss filter and an unresolved button;
- two unprefixed templates as a problem;
- output files and a missing dump.

`RealDumpTest` runs only when `build/zh_ini/inizh.jsonl` exists. It asserts three base factions and nine generals, each with a prefix and more than ten paired objects.

**Checks run** (working tree over `111e17e`, 2026-11-21):

- `python3 -m unittest tools.test_zh_generals`: 13 tests, OK, 1 skipped (`RealDumpTest`: no local dump in this session).
- `sh tools/run_python_checks.sh`: exit 0; ruff format and lint clean, mypy clean on 54 source files, Python tests passed.
- `sh tools/run_shell_checks.sh` and the GDScript gates were not run: no shell or GDScript changes.

#### Limits

- A module whose block has no fields leaves no trace in the `zh_ini` dump, so module lists can miss empty modules. `zh_ini.py` does not record openers that have no fields.
- "Reachable" is command-set reachability. A button the game hides (a science gate, a `Buildable = No` object, a leftover button such as the Stealth general's Terrorist Combat Cycle) still counts. The USA base sets reach a Biohazard Tech that no USA general reaches.
- Weapon field deltas need `weapon.ini` in the dump. Armor, locomotor and the contents of object creation lists are not followed.
- Player-template `ProductionCostChange` is reported as a setting, not applied to object costs.

### GPL map evidence

EA's GPL map sources hold the general prefixes without any retail data. Objects placed in the maps were read with `tools/zh_map/convert.py` (`load`, or `read_map` for the uncompressed maps); the one-off scan script was not committed.

- The Generals Challenge maps (`GC_AirGeneral`, `GC_LaserGeneral`, `GC_TankGeneral`, ...) place each general's prefixed base.
- `AllBuildingsAllSidesUnitTest_Save` places the prefixed copy of every base building for all nine generals and the boss.
- `_Art Review New Units` places the prefixed units: for example `Lazr_AmericaTankCrusader`, `Tank_ChinaTankEmperor`, `Infa_ChinaInfantryMiniGunner`, `Nuke_ChinaTankOverlord`.
- The test map also places `SupW_AmericaNuclearMissileLauncher` and `SupW_AmericaCruiseMissileLauncher`, which no general can build in the checked INI: likely cut content.

Placement is naming evidence only. Art-review maps are not rosters: the Superweapon general's art review places no Crusader, and the INI confirms it has none, but other gaps there are just unplaced units. These maps cannot give costs or stats.

### Retail INI evidence

The per-general table and the roster section come from a community repository's copy of the retail Zero Hour 1.04 INI: `TheSuperHackers/GeneralsGamePatch`, folder `Patch104pZH/GameFilesOriginalZH/Data/INI/`, read 2026-11-21. No commit hash was recorded. The copy was incomplete: the player templates, command sets, command buttons, sciences, special powers, upgrades and the faction and general object files were read, but `weapon.ini`, `rank.ini` and the AI data were not. Several file-name guesses returned nothing.

The copy was used for this one check in a scratch folder and is not in the repository. Numbers from it are **provisional**. Rerun the tool on the owner's archive (`installation.md` hashes) and cite `entry:line` from `build/zh_ini/inizh.jsonl` before any value goes into a plan.

## Open points

- Rerun `zh_generals.py` on the owner's `INIZH.big` dump; then `RealDumpTest` runs. Compare its counts with the table above.
- Rank thresholds, skill-point values and the AI `SideInfo` and `SkirmishBuildList` per general were not read (`rank.ini` and `aidata.ini` were not in the copy).
- Whether the Stealth general's Terrorist Combat Cycle, the Superweapon general's Point Defense Drone and the defined but unreachable Laser Paladin can be built in game: in-game or full-INI check.
- Whether Wargrid adopts steps 1 to 4 before batch A, at the generals package, or not at all: owner decision. Proposed default: steps 1 to 3 as a small technical package when the next roster package starts, since batch A's new kinds hit the same silent failures. Step 4 goes at the start of batch A or the generals package.
- Names: Wargrid names its own variants, following the roster rule of Wargrid names for every kind ([blueprint](../blueprint.md) line 23). No general names or portraits from Zero Hour.
