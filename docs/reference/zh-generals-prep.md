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
- **Retail INI:** the owner's local dump `build/zh_ini/inizh.jsonl` (`python3 tools/zh_ini.py dump`), queried only through that dump. A citation `file.ini:line` is the dump's `entry` (basename; object files live under `data\ini\object\`) and `line`. Where two entries share a basename (`aidata.ini`, `specialpower.ini` and `upgrade.ini` exist in `data\ini\` and `data\ini\default\`) the citation keeps the folder. Details under [Retail INI evidence](#retail-ini-evidence).

## Summary

1. **A general in Zero Hour is a player template plus a full prefixed copy of its faction.** Examples are `FactionChinaTankGeneral` with `Tank_ChinaWarFactory` and `Tank_ChinaTankBattleMaster`. The simulation has no "general" concept. Between 31 and 81 percent of each copy is unchanged: for 11 to 22 of the 26 to 36 objects in a general's roster, nothing the report compares differs from the base object. Wargrid should write only the difference.
2. **What the generals actually change falls into a few kinds:**
   - costs and build times;
   - a few roster swaps (0 to 1 units added and 0 to 4 removed per general);
   - weapon swaps;
   - about a dozen behaviour module kinds (start veteran, stealth, suicide on death, weapon tiers by upgrade, point-defence laser, free upgrade on creation);
   - their own science purchase trees and general's powers.

   Every one of these is a generic engine module. None is code written for one general.
3. **Wargrid's roster is too small for generals today.** Every one of the nine generals changes the Zero Hour counterpart of at least one of today's kinds, and four of them remove a factory unit:
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
6. **New tool:** `python3 tools/zh_generals.py report` turns the local INI dump into a per-general diff. It was run against the owner's local dump (nine generals found, results in [the per-general table](#what-each-general-changes)); `RealDumpTest` runs against the same dump.

## How Zero Hour builds a general

### Player template

A general is a `PlayerTemplate` block (fields `S/Common/RTS/PlayerTemplate.cpp:75-124`).

**Fields that matter for gameplay:**

- `Side`: the general's own identity, for example `ChinaTankGeneral`.
- `BaseSide`: `USA`, `China` or `GLA`.
- `StartingBuilding` and `StartingUnit0..9` (`:81-91`).
- `ProductionCostChange`, `ProductionTimeChange` and `ProductionVeterancyLevel` (`:92-94`). These are per-object modifiers on the template: `Player.cpp:1966-1990` looks them up and `ThingTemplate.cpp:1538-1553` applies them to cost and build time. No player template in the dump uses them (`playertemplate.ini:17-487`): the generals change prices through their own object copies instead.
- `IntrinsicSciences` (`:95`).
- `PurchaseScienceCommandSetRank1/3/8` (`:96-98`): the three pages of the general's science store.
- `SpecialPowerShortcutCommandSet` (`:99`): the general's-power bar.

**What reads `Side` and what reads `BaseSide`.** The simulation reads `Side` everywhere it matters:

- skirmish scripts and teams: `Player.cpp:835,864,902`;
- the AI build list and the AI's science choices: `AISkirmishPlayer.cpp:1079-1086`, `AIPlayer.cpp:2945`;
- the "my command centre" check: `Player.cpp:1251`;
- the "player is faction" script condition: `ScriptConditions.cpp:2205`.

`BaseSide` is read only by presentation and statistics: the score screen (`ScoreScreen.cpp:2183`), rank images (`PopupPlayerInfo.cpp:1066`) and Academy hints (`S/Common/RTS/AcademyStats.cpp:118-120`). No prerequisite or buildability check looks at either side. A general's units can build only what their command sets offer (next section).

**The lobby** lists one entry per unique `Side` plus Random and Observer (`S/GameNetwork/GUIUtil.cpp:238-294`), skipping templates with no `StartingBuilding` (`:257`) and challenge generals that do not start enabled (`:266-269`). Random picks among the same set (`S/GameLogic/System/GameLogic.cpp:719-790`; the same two filters at `:730` and `:739-743`). The challenge boss is `StartsEnabled = no` (`challengemode.ini:277-278`), which is what keeps it out of both; it is also kept out of ladders (`S/GameNetwork/GameSpy/LadderDefs.cpp:183`) and of the win/loss statistics (`S/GameClient/GUI/GUICallbacks/Menus/WOLWelcomeMenu.cpp:348`) by name.

### Objects are full prefixed copies

Each general has its own object for nearly every unit and building of its faction: `AirF_`, `Lazr_`, `SupW_`, `Tank_`, `Infa_`, `Nuke_`, `Chem_`, `Demo_` and `Slth_`. The Air Force Combat Chinook alone uses `AFG_`.

- The score screen names the prefixed superweapons directly (`ScoreScreen.cpp:1135-1173`).
- EA's own test map `AllBuildingsAllSidesUnitTest_Save` places 7 to 11 prefixed objects per general, mostly buildings (Air Force 8, Stealth 7, Superweapon 11; CnC_Modding_Support, see [GPL map evidence](#gpl-map-evidence)). It is a sample, not the roster: the Air Force has no Particle Cannon there and no general has a Patriot.

The engine offers four copy mechanisms. The INI uses them unevenly:

- **`ObjectReskin <new> <old>`** (`S/Common/INI/INIObject.cpp:54-59`): copies the old object in full, then re-reads only `Draw`, the geometry fields, the fence width and offset, and the simultaneous-count limit (`ThingTemplate.cpp:259-276`). Reskins count as the same object for prerequisites (`ThingTemplate::isEquivalentTo`, `S/Common/Thing/ThingTemplate.cpp:1478-1515`).
- **`AddModule`, `RemoveModule <tag>` and `ReplaceModule <tag>`** (`ThingTemplate.cpp:739-811`): edit one module by tag.
- **A `DefaultThingTemplate`** that every object copies first (`S/Common/Thing/ThingFactory.cpp:138-146`), with `InheritableModule` and `OverrideableByLikeKind` defaults (`ThingTemplate.cpp:240-242,815-848`).
- **`BuildVariations`** (`ThingTemplate.cpp:157`): a random pick among other objects at creation. The Technical is one: its object is a stub and the chassis variants carry the modules, so the tool walks every variant (see [Limits](#limits)).

Even so, the shipped general files mostly repeat whole `Object` blocks, unchanged fields included. That is why 31 to 81 percent of each general's roster compares as "unchanged".

### Build lists are command sets

What a dozer, worker or factory can make is not a field on the unit. It is the set of buttons in the object's `CommandSet` (`ThingTemplate.cpp:156`; buttons 1 to 18, `S/GameClient/GUI/ControlBar/ControlBar.cpp:707-724`):

- A `DOZER_CONSTRUCT` or `UNIT_BUILD` button names its `Object`.
- `Player::canBuild` then checks permission, `Buildable` and the prerequisites (`Player.cpp:2912-2950`). A prerequisite is an OR list of objects or a science (`ProductionPrerequisite.cpp:155-190`).
- A `CommandSetUpgrade` module swaps an object's set after an upgrade (`S/GameLogic/Object/Upgrade/CommandSetUpgrade.cpp:45-101`). The Demolition general uses this on 18 objects (15 units and buildings, 3 Technical chassis variants) to add the suicide button.

A general therefore differs from its faction because each prefixed builder, factory and command centre points at a prefixed command set. It does not differ because of a rule anywhere in the code.

### Rank, sciences and general's points

- **Ranks** are data blocks (`S/GameLogic/System/RankInfo.cpp:120-131`): `SkillPointsNeeded`, `SciencesGranted` and `SciencePurchasePointsGranted`.
- **Skill points** come from kills: the victim's `SkillPointValue`, which falls back to `ExperienceValue` (`Player.cpp:2494-2506`, `ThingTemplate.cpp:1392-1399`). Special abilities and scripts can also award them.
- **Each new rank** grants its sciences and purchase points (`Player.cpp:2686-2760`).
- **A science can be bought** when its `PrerequisiteSciences` are owned and its cost is above 0 and within the points left (`Player.cpp:2636-2666`).
- **Owning a science** wakes every special-power module that requires it (`Player.cpp:2535-2584`).
- **All nine generals keep their faction's intrinsic science** (`SCIENCE_AMERICA`, `SCIENCE_CHINA` or `SCIENCE_GLA`; `playertemplate.ini:52,86,120,155,189,223,257,291,326,361,396,431`). What differs is which science buttons their three store pages hold.

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

**A wart to avoid.** Zero Hour gave each general's copy of a power its own value in the power-type enum (`SUPW_`, `SUPR_`, `LAZR_`, `AIRF_`, `NUKE_`, `INFA_`, `SLTH_`, `EARLY_`; `I/Common/SpecialPowerType.h:102-128`). The reason: the shortcut bar found a power by type and mixed up powers from captured command centres. Wargrid should key powers by id from the start.

### AI

The skirmish AI keeps a `SideInfo` (gatherer counts, base defence, `SkillSet1..5` science lists) and a `SkirmishBuildList` per `Side`, matched by string with no fallback to the base side (`S/GameLogic/AI/AI.cpp:145-298`, `AISkirmishPlayer.cpp:1079`). Each general has its own bot build list and science order.

### Hard-coded exceptions

The C++ hard-codes a few upgrade names:

- `Upgrade_Nationalism` and `Upgrade_Fanaticism` (horde bonus, `AIUpdate.cpp:4689-4700`);
- `Upgrade_ChinaEMPMines` (`GenerateMinefieldBehavior.cpp:469`);
- `Upgrade_AmericaChemicalSuits`, `Upgrade_GLAWorkerShoes` and `Upgrade_AmericaSupplyLines`.

It also hard-codes the per-general power types and superweapon names above. Nothing else is special-cased for one general: the Demolition general's suicide, the Toxin general's anthrax and the Stealth general's camouflage are generic modules (`FireWeaponWhenDeadBehavior`, `WeaponSetUpgrade`, `StealthUpdate`, `StealthUpgrade`).

## What each general changes

Counts come from `tools/zh_generals.py` run against the owner's local dump (2026-11-22; see [Retail INI evidence](#retail-ini-evidence)). Rerun it and replace this table if the dump changes.

- "Changed" means the general's copy differs from the base object in at least one compared field: cost, build time, vision range, shroud-clearing range, health, armor, weapons, locomotor, prerequisites, `KindOf`, `Buildable`, `EditorSorting` or module classes. Module classes are compared by name, so a changed module of a class the base already has does not count (see [limits](#limits)).
- The roster is what the general's command sets can reach, including one Biohazard Tech button the USA base sets reach that no USA general does (`commandset.ini:778`, the base Barracks set; button `commandbutton.ini:2880`).

| General (base) | Prefix | Added | Removed | Changed | Unchanged | Powers (own / lost) | Sciences (own / lost) |
|---|---|---|---|---|---|---|---|
| Air Force (USA) | `AirF` | 1 | 3 | 13 | 14 | 2 / 1 | 7 / 6 |
| Laser (USA) | `Lazr` | 0 | 3 | 5 | 22 | 1 / 0 | 0 / 1 |
| Superweapon (USA) | `SupW` | 0 | 3 | 11 | 16 | 2 / 2 | 4 / 3 |
| Tank (China) | `Tank` | 1 | 3 | 12 | 14 | 3 / 3 | 8 / 9 |
| Infantry (China) | `Infa` | 1 | 4 | 13 | 12 | 3 / 2 | 6 / 6 |
| Nuke (China) | `Nuke` | 0 | 0 | 12 | 17 | 3 / 3 | 4 / 5 |
| Toxin (GLA) | `Chem` | 0 | 2 | 16 | 20 | 0 / 2 | 0 / 2 |
| Demolition (GLA) | `Demo` | 0 | 2 | 25 | 11 | 2 / 0 | 0 / 2 |
| Stealth (GLA) | `Slth` | 1 | 3 | 18 | 17 | 1 / 2 | 3 / 6 |

"Own" powers and sciences include `Early_` copies: the same power offered at a lower rank, for example `Early_SCIENCE_EmergencyRepair1`. Six generals use them. The Laser general's one own power is `Lazr_LaserCannon`, an unwired leftover (see its entry).

**Per general.** These are the main points from the report. Costs are retail dollars; build times are seconds. Module claims come from the report's `modules_added`; each value has its `file.ini:line` in the *Lines* item (the general's line first, the base object's in brackets).

- **Air Force.**
  - Roster: adds the Combat Chinook (`AFG_AmericaVehicleChinook`, built at the Supply Center); drops the Crusader and the Paladin.
  - Cheaper aircraft with more health, and point-defence lasers on the Aurora, Raptor, Stealth Fighter and Chinook (`PointDefenseLaserUpdate`). For example: Raptor $1400 → $1100 with 160 → 240 health; Airfield $1000 → $800 with 1500 → 2500 health.
  - The Stealth Fighter needs no science.
  - Stealth Comanche upgrade (`StealthUpgrade`).
  - Carpet Bomb power on the Strategy Center (`OCLSpecialPower`); Spectre Gunship 1 to 3 in place of the solo Spectre.
  - Dearer ground vehicles (Humvee $700 → $800).
  - The Chinook takes 25 s instead of 10 s and needs the War Factory.
  - *Lines:* Raptor cost `airforcegeneral.ini:17831` (`americaair.ini:593`), health `:17863` (`:625`); Airfield cost `:13109` (`factionbuilding.ini:8241`), health `:13135` (`:8267`); Humvee cost `:5203` (`americavehicle.ini:101`); Chinook build time `:17563` (`americaair.ini:2204`), prerequisite `:17565` (`:2206`); Combat Chinook object `:17232`.
- **Laser.**
  - Laser Crusader (`Lazr_CrusaderTankGun`), laser Patriot (`Lazr_PatriotMissile*`).
  - A Laser Cannon power (`Lazr_LaserCannon`) that no player can use: its building button is in no command set (`commandbutton.ini:7371-7378`), the Laser dozer builds the Particle Uplink instead (`commandset.ini:4170`), and only a shortcut-bar slot and the unreachable building's own set name the power (`commandset.ini:4160`, `:4410`; power `data\ini\specialpower.ini:942`). EA's test map places `Lazr_AmericaLaserCannon` and `Lazr_AmericaLaserCannonUplink`.
  - Paladin and Tomahawk removed.
  - Power Plant $800 → $700; Avenger $2000 → $1500.
  - The Fire Base carries a laser-guided howitzer ability (`lasergeneral.ini:16346`), but its button (`commandbutton.ini:7625`) is in no command set, not even the Fire Base's own (`commandset.ini:4254-4263`): a leftover.
  - *Lines:* Power Plant `lasergeneral.ini:9374` (`factionbuilding.ini:4817`); Avenger `:6790` (`americavehicle.ini:2446`).
- **Superweapon.**
  - EMP Patriot (`SupW_PatriotMissile*`, $1000 → $900, `EMP_HARDENED`); Aurora Alpha fuel bomb; Particle Cannon $5000 → $2500.
  - Crusader and Paladin removed.
  - Dearer units and Power Plant (Humvee $700 → $850, Power Plant $800 → $900).
  - Leaflet Drop moved to an earlier rank.
  - *Lines:* Patriot `superweapongeneral.ini:15685` (`factionbuilding.ini:28825`); Particle Cannon `:9644` (`factionbuilding.ini:5645`); Humvee `:4926` (`americavehicle.ini:101`); Power Plant `:17302` (`factionbuilding.ini:4817`).
- **Tank.**
  - Emperor Overlord (`Tank_ChinaTankEmperor`, built at the War Factory) replaces the Overlord; Inferno Cannon and Nuke Cannon are removed.
  - Cheaper tanks: Battlemaster, Dragon and Gattling $800 → $700. Tanks start veteran (`VeterancyGainCreate`): the Dragon, Gattling and ECM tanks gain the module; the Battlemaster starts veteran too, but the base Battlemaster already carries a `VeterancyGainCreate` (for the elite-training science), so the report cannot see it ([limits](#limits)). `SCIENCE_BattlemasterTraining` makes Battlemasters elite.
  - Dearer infantry and aircraft (Red Guard $300 → $375, MiG $1200 → $1600).
  - Tank Drop power; Autoloader upgrade.
  - Loses the Napalm Strike power and the three Cash Hack science purchases.
  - *Lines:* Battlemaster cost `tankgeneral.ini:2719` (`chinavehicle.ini:55`), start veteran `:2767`, elite science `:2783-2784` (base `chinavehicle.ini:138-139`); Dragon cost `:3572` (`chinavehicle.ini:859`), veteran `:3621`; Gattling cost `:4062` (`chinavehicle.ini:1819`), veteran `:4145`; ECM veteran `:4692`; Red Guard `:1402` (`chinainfantry.ini:271`); MiG `:756` (`chinaair.ini:740`); Emperor object `:2868`.
- **Infantry.**
  - Mini-Gunner replaces the Red Guard.
  - No Battlemaster, no Gattling Tank, no Overlord.
  - Infantry start veteran (`VeterancyGainCreate`; the Mini-Gunner at `infantrygeneral.ini:15044`, the Tank Hunter at `:1224`, Black Lotus `:927`, Hacker `:1572`).
  - Free upgrades on four buildings (`GrantUpgradeCreate` on the command centre, Barracks, Bunker and War Factory).
  - The Troop Crawler gains a Propaganda Tower (`PropagandaTowerBehavior`) and loses its assault-transport behaviour; the Listening Outpost also gains a Propaganda Tower.
  - Infantry Paradrop power.
- **Nuke.**
  - Same roster.
  - Nuclear weapons on the Battlemaster, Overlord and MiG (`Nuke_BattleMasterTankGun`, `Nuke_OverlordTankGun`, `Nuke_MiGMissileWeapon`), and `Nuke_FusionBattleMasterLocomotor`, faster than even the speed upgrade (Speed 45; the base locomotor has 25 and the upgraded one 35). A Helix nuke bomb upgrade is in the roster (`Nuke_Upgrade_HelixNukeBomb`).
  - Isotope Stability and Tactical Nuke MiG upgrades.
  - Dearer Power Plant ($1000 → $1200) and infantry.
  - *Lines:* locomotor speeds `locomotor.ini:4560` (fusion), `:697` (base), `:721` (upgraded); Power Plant `nukegeneral.ini:9994` (`factionbuilding.ini:17885`); Red Guard $300 → $350 `:1674` (`chinainfantry.ini:271`).
- **Toxin.**
  - Toxin weapons with an Anthrax Beta and Gamma tier swap on the Rebel, the Tunnel Defender, the Tunnel Network and the Scud Launcher (`WeaponSetUpgrade`, `Chem_Upgrade_GLAAnthraxGamma`; the Scud's at `chemicalgeneral.ini:16945`, its Gamma weapons at `:16798`, `:16808` and `:16818`). The report misses the Scud's, because the base Scud already has the module class (`glavehicle.ini:4382`; [limits](#limits)). The Scorpion's rocket upgrade keeps the base trigger (`Upgrade_GLAScorpionRocket`, `chemicalgeneral.ini:14444`); only its upgraded rocket copy adds a poison field (`Chem_ScorpionMissileWeaponPlusTwo`, `weapon.ini:7173`).
  - Rebels wear their own armor (`ChemReb_HumanArmor`).
  - Hijacker and Saboteur removed; GPS Scrambler and Booby Trap lost.
  - Most units dearer (Rebel $150 → $200, Rocket Buggy $900 → $1100).
  - *Lines:* Rebel `chemicalgeneral.ini:20052` (`glainfantry.ini:186`); Rocket Buggy `:14602` (`glavehicle.ini:371`).
- **Demolition.**
  - A suicide upgrade (`Demo_Upgrade_SuicideBomb`) adds a detonate button to nearly every unit and to the Barracks and Tunnel Network (`CommandSetUpgrade` on 18 objects: 15, plus the three Technical chassis variants) and a suicide death explosion to all of them but the Barracks, which gets a `SlowDeathBehavior` instead (`FireWeaponWhenDeadBehavior`). The report counts 15 of those as new: the Worker's is new (`demogeneral.ini:15864-15874`), while the Stinger Site (`:5826-5837`), the Combat Bike (`:17628-17661`) and the Toxin Truck (`:18444-18454`) already had the class.
  - The Armed Pickup is a stub (`Demo_GLAVehicleTechnical`, `demogeneral.ini:19065-19095`, cost `:19079`) that picks one of three chassis objects (`BuildVariations`, `:19091`); the suicide weapon, death modules and command-set swap are on those (`Demo_GLAVehicleTechnicalChassisOne`: `:19352`, `:19516-19526`, `:19530-19531`).
  - High-explosive weapon copies (`RED*`, `DEMO_*`).
  - Jarmen Kell's timed and remote charges.
  - Demo Trap $400 → $200 and buildable from the Supply Stash on.
  - Hijacker and Saboteur removed.
  - *Lines:* Demo Trap cost `demogeneral.ini:4601` (`factionbuilding.ini:14486`), prerequisite `:4599` (`:14484`); Technical $500 → $600 `:19079` (`glavehicle.ini:4421`).
- **Stealth.**
  - Every base building can be camouflaged (`StealthUpdate` and `StealthUpgrade` on 12 objects).
  - Rebel, Stinger Site and Tunnel Network appear stealthed from the start (`GrantUpgradeCreate` added, `StealthUpgrade` removed; inference from the modules, not checked in game).
  - The Hijacker needs no science ($400 → $600).
  - Scorpion, Marauder and Scud Launcher removed.
  - A Terrorist Combat Cycle (`GLAVehicleCombatBikeTerrorist`) is reachable from the Arms Dealer set (`commandset.ini:2641`); whether the game shows it is unchecked.
  - *Lines:* Hijacker `stealthgeneral.ini:14884` (`glainfantry.ini:3342`), prerequisite `:14881`.

### Module classes the generals add

These are the module classes the report finds on a general's copy that its base object lacks (`modules_added`), summed over all nine generals. This is the list of systems a general needs that a base faction's units do not use. Classes the base object already has are invisible to it ([limits](#limits)):

| Module class (Zero Hour) | Objects (generals) | Wargrid system |
|---|---|---|
| `StealthUpdate` (`StealthUpgrade` on 13) | 14 (Stealth 12, Air Force 1, Infantry 1) | stealth, batch B |
| `CommandSetUpgrade` | 18 (Demolition, 3 of them Technical chassis variants) | upgrades that add a button |
| `FireWeaponWhenDeadBehavior` | 16 (Demolition 15, Toxin 1) | death weapon |
| `GrantUpgradeCreate` | 10 (Infantry 4, Stealth 4, Toxin 1, Demolition 1) | free upgrade at creation |
| `VeterancyGainCreate` | 6 (Tank 3, Infantry 3; the Tank's Battlemaster is not counted, see below) | veterancy |
| `WeaponSetUpgrade` | 5 (Toxin 3, Tank 1, Demolition 1) | weapon tier swap by upgrade |
| `PointDefenseLaserUpdate` | 4 (Air Force) | missile interception, after aircraft |
| `MaxHealthUpgrade` | 3 (the Avenger of the Air Force, Laser and Superweapon) | health upgrade |
| `SpecialAbility` + `SpecialAbilityUpdate` | 2 each (Laser Fire Base, an unwired leftover; Demolition Jarmen Kell) | unit abilities |
| `PropagandaTowerBehavior` | 2 (Infantry Troop Crawler and Listening Outpost) | aura heal |
| `AssaultTransportAIUpdate` | 2 (Tank and Nuke Listening Outpost) | transport behaviour |
| `AIUpdateInterface` | 2 (Air Force Chinook, Demolition Stinger Site) | unit AI |
| `OCLSpecialPower` | 1 (Air Force Strategy Center) | general's powers |
| `ObjectCreationUpgrade`, `ProductionUpdate` | 1 each (Superweapon Patriot; no button in its command set, `commandset.ini:3442-3445`, so a leftover) | upgrade-spawned object, a building that produces |
| `SlowDeathBehavior` | 1 (Demolition Barracks) | death behaviour |
| `StealthDetectorUpdate` | 1 (Air Force Raptor) | detection |

Counts are per object, and the three Technical chassis variants count as three. Empty modules leave no trace in the dump, so a module with no fields can be missing (see [tool limits](#limits)). Of the 125 changed objects, 36 differ in `BuildCost` or `BuildTime` alone.

## What generals mean for today's roster

Wargrid's 34 playable kinds (37 in the registry with three FRC rebuild holes) stand in for these Zero Hour objects (stats in [M7 factions](m7-factions.md)):

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
| Tank | none | Medium Tank and Rotary Gun Tank $800 → $700; both start veteran; Medium Tank gets a second gun by upgrade and an elite-training science; Militia and Anti-Tank Trooper $300 → $375 |
| Infantry | Militia, Medium Tank, Rotary Gun Tank | Anti-Tank Trooper starts veteran with own armor; free upgrades on Headquarters, Barracks and Vehicle Factory |
| Nuke | none | Medium Tank nuclear gun and faster locomotor; infantry $300 → $350; Power Plant $1000 → $1200 |
| Toxin | none | Insurgent $150 → $200, toxin gun and own armor; Rocket Fighter, Light Tank and Tunnel Hub toxin tiers |
| Demolition | none | Laborer, Insurgent, Rocket Fighter, Armed Pickup, Light Tank and Tunnel Hub get suicide; Armed Pickup $500 → $600 |
| Stealth | Light Tank | Insurgent $150 → $200 and stealthed; every building can be camouflaged |

Two conclusions:

- **Cost-only generals are possible today.** Laser, Tank and Nuke (and partly Toxin) could be represented on the current roster with cost and weapon changes only, if veterancy and weapon tiers were left out. But Laser and Nuke play differently through their weapons. A laser that is only renamed would be a hollow variant.
- **The others need a bigger roster.** Air Force, Superweapon, Infantry and Stealth remove a factory unit. With two units per factory they would ship a factory with one unit (Air Force, Superweapon, Stealth) or none (Infantry). The generals package should come after batch A's ground roster at least, which matches its place after P9.

## Wargrid readiness audit

Read-only audit of the tree at `111e17e` (2026-11-21); its line numbers rechecked against `54786862` (2026-11-22).

**Already ready:**

- The simulation never branches on faction; it reads capability data by kind id. The faction id is read when a seat is set up (`game/scripts/simulation/simulation.gd:160-163`) and on every bot lookup of build order, units, start unit and collector count (`game/scripts/simulation/skirmish.gd:27,30,142-143`). `tools/test_faction_guard.py` enforces this.
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
| `game/scripts/presentation/shapes.gd:15,37-55` | Draw roles come from kind-id suffixes and a tank table. A variant unit id draws with the suffix role (a variant tank id gets `light_vehicle`, `:42-45`); only an unknown role such as `defence_<prefix>` falls through to the small box (`:140`). |
| `game/scripts/presentation/sound_cues.gd:21-31` | A new damage type needs a shot sound (`test_sound.gd:107` enforces this). |
| `skirmish.gd:49-51`, map slots, `tools/zh_map/convert.py:32-39` | The bot places buildings by six fixed slot names. A variant building must reuse one. |
| `game/tests/test_hud.gd:1838` | Asserts exactly `["china","frc","usa"]`. |
| `debug/combat_workload.gd:327-345`, `lab/hud_capture.gd:175` | Build ids as `<faction>_<suffix>` and parse the prefix. |
| `tools/test_faction_guard.py:11` | Knows only the three base prefixes. A new prefix would slip past the guard. |

**Verdict.** At runtime, a general fits best as its own `FACTIONS` entry (its own start kinds, build order and units list). That keeps the "capability data, not branches" rule (blueprint §14). A runtime overlay that changes `usa_tank` for one player only would put the faction into every lookup.

Unchanged kinds can be shared by id; only changed kinds need rows. The cost is the ripple above. It shrinks if build lists stop living on the builder and factory rows.

## Proposed preparation steps

These are ordered by gain for effort. None is approved. Steps 1 to 3 are small enough for one technical package if the owner wants them before the generals package; the rest belong to the generals package or to systems already planned.

1. **Definitions lint against shadowing** (proposed). These tests fail when:
   - an id is defined in two faction files;
   - a unit has more than one producer;
   - a damage type is missing from any `ARMOR` row.

   Extend `game/tests/test_definitions_lint.gd` (DL1 unknown keys, DL2 dangling references, DL3 the real registry is clean). All three are silent today. This is cheap now and pays off with the first new kind of any package, not just generals.
2. **Row inheritance at load** (proposed): a kind row may say `"extends": "usa_tank"` and list only what differs. It is expanded once at load into a `static var`, then frozen with the other caches (`definitions.gd:21,120`).

   This is how a general should be written: Tank's Medium Tank is `extends china_tank`, cost 700, veteran. Zero Hour repeats whole blocks instead. The Zero Hour data shows 5 to 25 changed objects per general (36 of the 125 differ in cost or build time alone), so this decides whether a general is 5 to 25 short rows or 26 to 36 full ones.
3. **Draw role as data** (proposed): an explicit `role` key, instead of `shapes.gd` guessing from the id suffix and the tank table. Then a variant kind id (`usa_laser_tank`) draws right without a code change. Batch A's new units need the same thing.
4. **Faction-level build lists** (proposed, larger): move "what this builder can build" and "what this factory trains" from the kind rows into the faction entry (`FACTIONS[...].builds` and `.produces`, keyed by building kind). Then a general that removes one unit changes one list in its faction entry; its factory, builder and headquarters can stay shared ids.

   This matches Zero Hour, where command sets, not objects, hold the build lists. The cost is touching `construction.gd:71`, `simulation.gd:310`, `_producer_of`, the bot and the HUD model. Worth doing before batch A widens the rosters, or at the start of the generals package. The owner decides.
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
| Veterancy | 2 directly (Tank, Infantry), every general via the science purchases | Ground batch A: veterancy as Zero Hour (user, 2026-11-08; [blueprint](../blueprint.md) line 603); player rank is out ([blueprint](../blueprint.md) line 608) |
| Aircraft | 4 (Air Force most) | No milestone yet; aircraft are listed under Later ([blueprint](../blueprint.md) line 769) |
| Death weapon, suicide button | 2 (Demolition, Toxin Demo Trap) | The Terrorist's suicide attack ships in batch A ([blueprint](../blueprint.md) line 612); P15 carries it as a stretch ([packages](../packages.md)) |
| Superweapons | 4 (cheap Particle Cannon, the nuclear copy, Toxin's and Demolition's Scud Storm copies; the Laser Cannon is an unwired leftover) | Deferred by the owner |

## Tools

### `tools/zh_generals.py`

```sh
python3 tools/zh_ini.py dump          # once: retail INIZH.big -> build/zh_ini/inizh.jsonl
python3 tools/zh_generals.py report   # -> build/zh_generals/generals.md and generals.json (--dump PATH for another dump)
python3 -m unittest tools.test_zh_generals   # ZH_INI_DUMP=PATH points RealDumpTest at a dump outside build/
```

**What it does:**

1. Each playable player template is a roster root: its starting building and units. The challenge boss (`Side = Boss`) is left out unless `--all` is given.
2. The tool follows each object's last top-level `CommandSet` (a later line replaces an earlier one, as in the engine) and the sets swapped in by upgrade modules (a `CommandSet` or `CommandSetAlt` field inside a module counts; the engine parses `CommandSetAlt` only there, `CommandSetUpgrade.cpp:46`). It also walks every object an object lists in `BuildVariations`. A stray `=` before a set name, as in the Demo Trap's retail line (`factionbuilding.ini:14509`), is skipped. The roster also takes `StartingBuilding` and `StartingUnit0` to `StartingUnit9`. It takes `DOZER_CONSTRUCT`, `UNIT_BUILD`, `SPECIAL_POWER_CONSTRUCT` and `SPECIAL_POWER_CONSTRUCT_FROM_SHORTCUT` buttons as roster (the shortcut form names the same object in retail, so it adds none today), upgrade buttons as upgrades, and power buttons as powers.
3. It adds the three science store pages, the power shortcut set (buttons there are walked like any other, so an object only a shortcut builds joins the roster) and the template's `IntrinsicSciences`.
4. The base faction is the template whose starting building has no prefix. A general's object pairs with the base object of the same name once the general's prefix is stripped.
5. For each pair it compares cost, build time, vision range, shroud-clearing range, health, armor, weapon names (prefix kept, so a general's own weapon counts as a change), locomotor, prerequisites (the prefix stripped from every name of an OR list), `KindOf` (as a set), `Buildable`, `EditorSorting` and module classes. Weapon field deltas are listed when both weapons are defined and the general's weapon is the base weapon's name with the general's prefix.
6. `ObjectReskin` inherits its source's fields.
7. The exit code is 1 when no general is found, when a base side has no single unprefixed template, or when a name is defined twice in a block kind the report reads (`Object`, `CommandSet`, `CommandButton`, `PlayerTemplate`, `Weapon`, `SpecialPower`, `Science`). The dump repeats names in kinds the report never looks up (`MappedImage`, `Terrain`, `FXList`, `Upgrade`, an OCL); they are ignored, including `SupW_Upgrade_AmericaPointDefenseDrone` (`data\ini\upgrade.ini:724` and `:796`, not the `default\` copy), because the report takes upgrade names from buttons and never reads an `Upgrade` block.

**Tests:** `tools/test_zh_generals.py` runs on invented INI text through the real `zh_ini` parser and needs no retail data. It covers:

- roster walking (all ten starting-unit slots, `CommandSetAlt`, the last of two `CommandSet` lines, command sets swapped in by upgrade, an empty slot, `BuildVariations`, buttons in the player-level sets, `SPECIAL_POWER_CONSTRUCT` and its shortcut form, a stray `=`), prefix pairing, reskin inheritance;
- cost, health (a later `MaxHealth` wins), armor, vision, weapon (none when the general's weapon is undefined) and module deltas, `KindOf` order, prerequisite OR lists;
- science, power and upgrade sets, `IntrinsicSciences`, power and science details, prefixed names paired with their base names in the three set deltas;
- the boss, observer and unplayable-template filters, an unresolved button and an unresolved object;
- two unprefixed templates and a duplicate in a read kind as problems, a duplicate in an unread kind as none;
- output files, a missing dump, and exit code 1 without generals or with problems.

`RealDumpTest` runs only when the dump exists (`build/zh_ini/inizh.jsonl`, or the path in `ZH_INI_DUMP`). It asserts three base factions, nine generals with a prefix and more than ten paired objects each, no problems and no unresolved references.

**Checks run** (working tree over `54786862`, 2026-11-22):

- `ZH_INI_DUMP=<local dump> python3 -m unittest tools.test_zh_generals`: 34 tests, OK, `RealDumpTest` included.
- `sh tools/run_python_checks.sh`: exit 0 (ruff format and lint clean, mypy clean on 54 source files, Python tests passed; `RealDumpTest` skipped there, no dump in the worktree). `sh tools/check_public.sh`: passed.
- The GDScript gates and the game suite were not run: no GDScript changes.

#### Limits

- A module whose block has no fields leaves no trace in the `zh_ini` dump, so module lists can miss empty modules. `zh_ini.py` does not record openers that have no fields.
- "Reachable" is command-set reachability. A button the game hides (a science gate, a `Buildable = No` object, a leftover button such as the Stealth general's Terrorist Combat Cycle) still counts. The USA base sets reach a Biohazard Tech that no USA general reaches.
- Module classes are compared by name. A module the base object already has, changed in the general's copy, does not show: the Tank general's Battlemaster starts veteran (`tankgeneral.ini:2767`), but the base Battlemaster already has a `VeterancyGainCreate` for the elite-training science (`chinavehicle.ini:138-139`), so the report's "Tank 3" veteran objects leave it out.
- Weapon field deltas need `weapon.ini` in the dump. Armor and locomotor are compared by name only; their contents and the contents of object creation lists are not followed.
- Player-template `ProductionCostChange` is reported as a setting, not applied to object costs. The engine allows several `Production*` lines per template (`PlayerTemplate.cpp:92-94`); the tool reads the last. Retail has none. `StartingUnit2` to `9` are walked into the roster but not compared as settings: no retail template sets them, and a change would show as an added or removed object.
- Weapon field deltas pair a weapon only with the base weapon of the same name once the general's prefix is stripped. Copies under another name are listed in `Weapons` but not compared field by field: the Demolition general's `RED*` and `DEMO_*` copies, `DemoTunnelDefenderRocketWeapon`, and the Toxin general's `GC_Chem_*` rebel guns.
- The module comparison is per object. The Toxin general's Scud Launcher also gets the Gamma weapon swap (`chemicalgeneral.ini:16945`), but the base Scud already carries a `WeaponSetUpgrade` (`glavehicle.ini:4382`), so the report does not list it. The same blindness hides the suicide death weapons of the Demolition general's Stinger Site, Combat Bike and Toxin Truck.
- `BuildVariations` are walked, so each chassis of the Technical counts as an object: the base roster has three, the Toxin and Stealth generals reuse those three (unchanged), the Demolition general has its own three.
- Retail leftovers count as reachable when any command set names them. Three are not usable in game: the Laser Cannon power (button in no set; the shortcut slot names the power, `commandset.ini:4160`), the Laser Fire Base ability (button `commandbutton.ini:7625` in no set), and the Superweapon Patriot's drone production (set `commandset.ini:3442-3445` has only Stop and Sell).

### GPL map evidence

EA's GPL map sources hold the general prefixes without any retail data. Objects placed in the maps were read with `tools/zh_map/convert.py` (`load`, or `read_map` for the uncompressed maps); the one-off scan script was not committed.

- The Generals Challenge maps (`GC_AirGeneral`, `GC_LaserGeneral`, `GC_TankGeneral`, ...) place each general's prefixed base.
- `AllBuildingsAllSidesUnitTest_Save` places 7 to 11 prefixed objects for each general (Air Force 8, Stealth 7, Superweapon 11, the others 9 to 11; the Stealth count leaves out one `GC_Slth_GLADemoTrap`) and 12 for the boss, plus 57 unprefixed objects: 29 base buildings, 26 vehicles, `SalvageCrate` and `GLABurningBarrier`. It is a sample: the Air Force has no Particle Cannon there and no general has a Patriot.
- `_Art Review New Units` places the prefixed units: for example `Lazr_AmericaTankCrusader`, `Tank_ChinaTankEmperor`, `Infa_ChinaInfantryMiniGunner`, `Nuke_ChinaTankOverlord`.
- The test map also places `SupW_AmericaNuclearMissileLauncher` and `SupW_AmericaCruiseMissileLauncher`, which no general can build in the checked INI: likely cut content.

Placement is naming evidence only. Art-review maps are not rosters: the Superweapon general's art review places no Crusader, and the INI confirms it has none, but other gaps there are just unplaced units. These maps cannot give costs or stats.

### Retail INI evidence

Every INI value in this note comes from the owner's local dump `build/zh_ini/inizh.jsonl` (written by `tools/zh_ini.py` from the retail archive; nothing records whether that run skipped the archive hash check in `check_reference.py`), queried through `tools/zh_generals.py` and the dump's JSONL records. Citations are `file.ini:line` from the records' `entry` and `line`. The dump holds `rank.ini`, `weapon.ini` and the AI data, so the earlier open points about them are answered:

- **Ranks** (skill points needed at `rank.ini:7,14,21,28,35`, purchase points granted at `:9,16,23,30,37`): skill points needed 0, 800, 1500, 2500 and 5000; purchase points granted 1, 1, 1, 1 and 3.
- **AI.** `SideInfo` and `SkirmishBuildList` blocks sit inside the `AIData` block of `default\aidata.ini` (for example `SideInfo ChinaTankGeneral` at `:236-258`, with its two science orders at `:242-258`, and the build list from `:1386`). The note's per-general bot claim (a build list and a science order per general) rests on those.

No community copy of the INI was used for any number here.

## Open points

- Compare the table with any later dump: rerun `zh_generals.py`, and let `RealDumpTest` guard the nine-generals shape.
- Whether the Stealth general's Terrorist Combat Cycle (`commandset.ini:2641`), the Superweapon general's Point Defense Drone (`superweapongeneral.ini:42`) and the defined but unreachable Laser Paladin (`lasergeneral.ini:6153`; its button `commandbutton.ini:7580` sits in no Laser command set) can be built in game: in-game check. The Laser Cannon, the Laser Fire Base ability and the Superweapon Patriot's drones are not on this list: their buttons are in no command set ([limits](#limits)).
- Whether Wargrid adopts steps 1 to 4 before batch A, at the generals package, or not at all: owner decision. Proposed default: steps 1 to 3 as a small technical package when the next roster package starts, since batch A's new kinds hit the same silent failures. Step 4 goes at the start of batch A or the generals package.
- Names: Wargrid names its own variants, following the roster rule of Wargrid names for every kind ([blueprint](../blueprint.md) line 23). No general names or portraits from Zero Hour.
