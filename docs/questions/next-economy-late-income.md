# Next: late-game income: capture points, passive income caps, what happens when the boxes run out

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/`. **INI** = retail root `INIZH.big` through `python3 tools/zh_ini.py dump` (`build/zh_ini/inizh.jsonl`), cited as archive entry:line. **OpenRA** = ~/projects/OpenRA @ b4d95a5671. **Recoil** = ~/projects/RecoilEngine @ a0240a9b5c. **Zero-K** = ~/projects/Zero-K @ 54ef574db (a game on Recoil, used for its extractor data). Dawn of War has no local source: it appears here only as the owner's stated reference, nothing about it is claimed. Rates are per minute of game time; Wargrid runs 30 ticks per second (`docs/reference/faction-income-parity.md:12`).

Owner input (user, 2026-11-22, after playing Zero Hour on a Steam Deck; private inbox): Zero Hour's economy is its weakest part and could be Wargrid's biggest improvement. Once every supply source on the map is empty, whoever built the most Hackers, Black Markets or Supply Drop Zones wins. Dawn of War does it better: capture points each give a resource, and a structure built and upgraded on a captured point raises its income, which rewards active play. Wanted: something like that in Wargrid's own style; passive income units and buildings may keep a place, but their number should be limited.

Already decided, not asked again: secondary income is needed once the boxes run out (`docs/blueprint.md:711`; `docs/questions/answers-2026-11-09.md:5`); Supply Drop Zone and Internet Center go into ground batch A beside the Black Market, the Hacker with only its money ability (`answers-2026-11-09.md:8-9`, confirmed `docs/reference/design-answers-2026-11-08.md:1167`); oil derricks are the first tech building, capture and income, other capturable buildings unimportant (`design-answers-2026-11-08.md:898`; `docs/packages.md:82`, "map life"); bots must later use Supply Drop Zone, Hackers, Black Market and derricks (`design-answers-2026-11-08.md:1128`); capture building is a batch B system that needs fog first (`docs/blueprint.md:610`, `:692`). The blueprint still lists "whether other end-game money sources are needed as well" as open (`docs/blueprint.md:711`): this file is that question. Q8 to Q11 ask whether to revise parts of the batch A answer, and say so. Earlier private research: none found on capture points or income caps (searched `~/projects/wargrid-private/docs/`, session notes, deferred notes and `research/`); the only hit is the owner's inbox note itself.

Direction (user, 2026-11-22, later the same day): the design should combine Dawn of War 1 and 2's requisition from captured points with listening posts, elements from Warzone 2100 and Zero-K, and ideas of Wargrid's own, to make Zero Hour's income more fun. A direction for the design session, not an answer to any question below; Dawn of War still has no local source, so its rules need a primary source before they are used as numbers.

Answered in part (user, 2026-11-22; [hybrid economy frame](../reference/design-answers-2026-11-08.md#hybrid-economy-frame-user-2026-11-22)): Q1 piles, points and capped passives together (nearest option b, with piles staying primary); Q2 a for step 1, b for step 2; Q4 b, but only as step 2; Q5 not set, measured in bot matches first; Q6 b; Q7 piles stay finite (whether an empty pile refills a little, option b, was not asked); Q8 to Q11 get the rule that capped passive income in total stays clearly below one working depot, counts open. Still open: Q3, the counts in Q8 to Q11, Q12 to Q15.

## Findings (short, cited)

Zero Hour supply (finite):
- **source** A large pile holds 150 boxes and a small one 50, both deleted when empty; supply docks and warehouses hold 400 (INI `data\ini\object\civilianbuilding.ini:554-555`, `:606-607`, `:505`, `:406`). A box is worth 75 (`data\ini\gamedata.ini:248`). **inferred** 11,250, 3,750 and 30,000 credits.
- **source** A pile only counts down; when it reaches zero with `DeleteWhenEmpty` it is destroyed (ZH src `Source/GameLogic/Object/Update/DockUpdate/SupplyWarehouseDockUpdate.cpp:113-120`). Only a map script can set a pile's value (`:175-178`). No refill exists.
- **source** One Zero Hour supply center with two Chinooks next to a 400-box dock earns about 2,880 per minute (`docs/reference/faction-income-parity.md:24`, measured with the parity harness). **inferred** that dock is empty after about 10 minutes.
- **source** Wargrid today: a converted 1v1 runs dry near tick 30,000 and the FRC wins only at tick 73,560 (`docs/blueprint.md:711`). **inferred** about 17 and 41 minutes. Wargrid has no passive income code yet (`rg -i 'trickle|auto_deposit|passive_income|income_per' game/scripts game/data`: one unrelated comment).

Zero Hour passive income:
- **source** Hacker: 625, earns 5 every 2.0 s outside and every 1.8 s inside the Internet Center; 6, 8 and 10 at Veteran, Elite and Heroic; 1 XP per payout, ranks at 100, 300 and 500 XP (INI `data\ini\object\chinainfantry.ini:1292`, `:1295`, `:1332-1338`; ZH src `Source/GameLogic/Object/Update/AIUpdate/HackInternetAIUpdate.cpp:183-193`). **inferred** 150 per minute at the start, 300 at Heroic after about 16 minutes of hacking; pays back in about 4 minutes.
- **source** Internet Center: 2,500, at most 1 per player, 8 Hacker slots, cannot be captured (`data\ini\object\factionbuilding.ini:33952`, `:33966`, `:33995`, `:33980`). **inferred** full with 8 new Hackers: about 1,330 per minute for 7,500 spent.
- **source** Black Market: 2,500, pays 20 every 2 s, no capture bonus, can be captured, leaves a rebuild hole (`factionbuilding.ini:10092`, `:10143-10145`, `:10121`, `:10157`). **inferred** 600 per minute; pays back in about 4 minutes; a captured one pays its captor.
- **source** Supply Drop Zone: 2,500, every 120 s a cargo plane drops 6 crates of 250, +25 per crate with Supply Lines (`factionbuilding.ini:19263`, `:19305-19306`; `data\ini\objectcreationlist.ini:5140`, `:5147`; `data\ini\crate.ini:550-551`). **inferred** 750 per minute, 825 with Supply Lines.
- **source** No build limit on the Hacker, the Black Market or the Supply Drop Zone: of the income objects only the Internet Center sets `MaxSimultaneousOfType` (query over every object with `HackInternetAIUpdate`, `AutoDepositUpdate`, `InternetHackContain` or a Supply Drop Zone in the dump).
- **source** Zero Hour's own skirmish build lists plan 4 Supply Drop Zones for America, 1 Internet Center for China and 5 Black Markets for GLA (`data\ini\default\aidata.ini:483-509`, `:620-625`, `:711-737`, `:760-765`).

Zero Hour capture points:
- **source** The oil derrick is the only neutral tech building that pays money (the capturable Black Market also pays, see above): 200 every 12 s, +20 per payout with USA Supply Lines, 1,000 on capture, 2,000 health, no rebuild (`data\ini\object\civilianbuilding.ini:25108-25111`, `:25098`, `:25140`). The oil refinery gives -10 % vehicle cost instead (`:25407-25412`); hospital, artillery platform, reinforcement pad, repair pad and repair bay pay nothing (`civilianbuilding.ini:24487`, `data\ini\object\techbuildings.ini:2`, `:272`, `:494`, `:689`). **inferred** 1,000 per minute, about a third of one working depot.
- **source** The 1,000 bonus is paid once per derrick per match, to the first player who owns it; later captures pay nothing (ZH src `Source/GameLogic/Object/Update/AutoDepositUpdate.cpp:120-141`, `:150-156`; `Source/Common/RTS/Player.cpp:1072-1079`). A neutral derrick pays nobody (`AutoDepositUpdate.cpp:160`).
- **source** Capturing needs the 1,000 Capture Building upgrade, then a 3 s unpack and 20 s channel by a Ranger, Red Guard or Rebel, 15 s before the next (`data\ini\upgrade.ini:163-166`; `data\ini\object\americainfantry.ini:1035-1036`, `:1044-1045`; `data\ini\specialpower.ini:491-493`).
- **source** Map spots: Ashfall has 8 derricks, Tournament Desert 2 (`docs/reference/m6-verification.md:81`; `docs/reference/more-maps.md:13`). Dry Wells and Broken Crown: not found in the skip tables, which list only the top templates (`more-maps.md:37-39`).
- **source** ZH skirmish scripts have a condition "tech building within distance" (ZH src `Source/GameLogic/ScriptEngine/ScriptConditions.cpp:2257-2288`). Whether the shipped skirmish scripts use it for derricks: not found (the scripts are binary `.scb`, not read).

Other engines:
- **source** OpenRA Red Alert oil derrick: 100 every 375 ticks and 100 on capture, paid only while a combatant owns it; it returns to neutral when its owner loses (OpenRA `mods/ra/rules/civilian.yaml:518-563`; `OpenRA.Mods.Common/Traits/OwnerLostAction.cs:29`). At the normal 40 ms tick (`mods/ra/mod.yaml:297-299`) **inferred** 400 per minute. The engineer that captures it is used up, 200 ticks (`mods/ra/rules/infantry.yaml:279`, `:309-313`; `OpenRA.Mods.Common/Traits/Captures.cs:41`). No upgrade on the derrick. The Red Alert bot has no capture module configured (`rg CaptureManagerBotModule mods`: 0 hits).
- **source** OpenRA ore regrows: ore mines seed new ore, every 75 ticks by default (`mods/ra/rules/misc.yaml:240-257`; `OpenRA.Mods.Common/Traits/SeedsResource.cs:20-22`).
- **source** Recoil metal spots: an extractor built on a spot earns from the metal under its radius on every slow update while its upkeep is paid (Recoil `rts/Sim/Units/Unit.cpp:1104-1108`; `rts/Sim/Units/UnitTypes/ExtractorBuilding.cpp:117-148`; `rts/Sim/Units/UnitDef.cpp:305`, `:588`). Overlapping extractors split a spot; when one dies its neighbours take over its share (`ExtractorBuilding.cpp:53-71`, `:170-181`). Extraction never lowers the metal map; only game scripts can (`rts/Map/MetalMap.cpp:98-112`; `rts/Lua/LuaMetalMap.cpp:72-79`). **inferred** spots never run dry.
- **source** Zero-K's extractor costs 85 metal; energy fed into the grid adds 0.25 x √energy metal, an income boost with falling returns (Zero-K `units/staticmex.lua:44`; `LuaRules/Gadgets/unit_mex_overdrive.lua:265-267`). Beyond All Reason's upgraded extractors: not found (its game data is not in the Recoil checkout; `rg -l -i 'armmex|armmoho'`: 0 files).
- **source** Warzone 2100 (~/projects/warzone2100 @ b904885ff) ties all income to map positions: a derrick stands only on an oil resource feature (`src/structure.cpp:4657-4666`), yields forever (`src/power.cpp:250`) and pays only while linked to a power generator (`src/power.cpp:258-265`); one generator serves at most 4 derricks (`src/structuredef.h:35`, `:225`) and its power points multiply their output (`src/power.cpp:334-338`; 55 in the multiplayer stats, `data/mp/stats/structure.json:652`). **inferred** income grows only by holding more oil, with one base building per four derricks.

## Questions

Q1. When every supply pile is empty, what should the late game run on?
   a) Only passive income built earlier (Hackers, Black Markets, Supply Drop Zones), no limit — ZH default (SupplyWarehouseDockUpdate.cpp:113-120; factionbuilding.ini, no `MaxSimultaneousOfType` except :33966)   b) Mostly capture points on the map, with a few capped passive buildings beside them   c) Supply that never runs out (OpenRA ore regrows, misc.yaml:240-257; Recoil spots never run dry, inferred from MetalMap.cpp:98-112)   d) Capture points only, no supply piles at all
   Recommendation: b, because it keeps Zero Hour's collector opening and gives the late game something to fight over instead of a building count. Why it matters: decides whether Wargrid's economy differs from Zero Hour's at all.

Q2. Are oil derricks Wargrid's capture points?
   a) Yes, with Zero Hour's derrick rules: fixed pay, nothing built on it — ZH default (civilianbuilding.ini:25108-25111)   b) Yes, derricks become Wargrid's capture points with Wargrid's own rules (build on, upgrade)   c) No: derricks stay Zero Hour tech buildings and separate Wargrid points are added
   Recommendation: b, because derricks are already the first planned tech building (design-answers-2026-11-08.md:898) and Zero Hour players know them; one mechanic is easier to read than two. Why it matters: decides whether "map life" and this economy change are one package or two.

Q3. Where do capture points come from on a map?
   a) Only where the Zero Hour map places derricks (Ashfall 8, Tournament Desert 2, others not found) — ZH default (m6-verification.md:81; more-maps.md:13)   b) Each supply pile turns into a capture point when it empties   c) Zero Hour's derrick spots, plus points added in Wargrid's map data so every map has a set number per player
   Recommendation: c, because maps with no derricks would otherwise keep Zero Hour's dry-out; b puts the base pile's point next to the base, which plays like passive income again. Why it matters: decides converter and map-data work.

Q4. Can a captured point be built on or upgraded to raise its income?
   a) No, a derrick pays one fixed rate; only USA Supply Lines adds +20 per payout — ZH default (civilianbuilding.ini:25108-25111)   b) Yes, one building on the point with two paid upgrade levels that raise its income (the owner's Dawn of War reference)   c) Yes, but upgrades add defence (armour, a gun), not income   d) Not on the point: a base building serves up to four points and sets what they pay, so more points need more base buildings (Warzone 2100, `src/structuredef.h:35`, `src/power.cpp:334-338`)
   Recommendation: b, because paying to upgrade a point you must hold is the active choice the owner asked for; d puts the investment in the base, away from the raid. Why it matters: sets how much a raid on a point costs the owner.

Q5. How much should one point pay at its first level, compared with one working supply depot (about 2,880 per minute in Zero Hour)?
   a) About 1,000 per minute, about a third of a depot — ZH default derrick (civilianbuilding.ini:25108-25109; faction-income-parity.md:24)   b) About 500 per minute, rising to about 1,000 and 1,500 with the upgrades   c) About as much as a depot from the start
   Recommendation: b, because the first level stays below the collectors and points take over as the piles empty, with the Zero Hour derrick's rate as the middle level. Why it matters: too high and nobody gathers boxes; too low and nobody fights for points.

Q6. Who can capture a point, and how?
   a) Rangers, Red Guards or Rebels after the 1,000 Capture Building upgrade: 3 s plus 20 s, 15 s before the next — ZH default (upgrade.ini:163-166; americainfantry.ini:1035-1036; specialpower.ini:491-493)   b) Any infantry, no upgrade; it takes a set time and stops while an enemy unit stands nearby   c) A special unit that is used up by the capture (OpenRA engineer, infantry.yaml:309-313)
   Recommendation: b, because points must be cheap to take and retake all match; the batch B capture system still comes first or with it, and needs fog (blueprint.md:692). Why it matters: a 1,000 upgrade plus a 23 s channel makes points a late luxury, the opposite of active play.

Q7. Do supply piles stay finite?
   a) Yes, finite, removed when empty — ZH default (civilianbuilding.ini:554-555, 606-607; SupplyWarehouseDockUpdate.cpp:113-120)   b) Finite, but an empty pile slowly refills a little (OpenRA ore, SeedsResource.cs:20-22)   c) Never run out
   Recommendation: a, because finite piles force expansion, which is Zero Hour's feel, once points carry the late game. Why it matters: refilling piles would make the points of Q1 to Q6 unnecessary.

Q8. Which passive income sources get a build limit? (Revises the batch A answer, which ported them without limits.)
   a) Only the Internet Center, 1 per player — ZH default (factionbuilding.ini:33966)   b) Each kind on its own: Supply Drop Zone, Black Market, Internet Center and Hackers   c) One shared limit for all passive income buildings of a player
   Recommendation: b, because each faction then keeps its own income building and the limit reads per button. Why it matters: Zero Hour's own bots plan 4 Supply Drop Zones and 5 Black Markets (aidata.ini:483-509, 711-765), the stacking the owner names.

Q9. How many of each passive income building may one player own? (Revises the batch A answer, as Q8.)
   a) No limit — ZH default (no `MaxSimultaneousOfType` on the Supply Drop Zone or Black Market)   b) 1   c) 2   d) 1, plus 1 more for every 2 capture points held
   Recommendation: b, because it is simple to read and keeps passive income a supplement; d is worth a playtest only if b feels too flat. Why it matters: the limit decides how big the passive share of late income can get.

Q10. Where can a Hacker earn money? (Asks whether the 2026-11-09 answer, "internet hack in the Internet Center", rules out hacking outside it.)
   a) Anywhere; the Internet Center only makes it about 10 % faster — ZH default (chinainfantry.ini:1332-1333; HackInternetAIUpdate.cpp:183-193)   b) Only inside the Internet Center, so its 8 slots are the Hacker limit   c) Anywhere, but at most 8 Hackers per player
   Recommendation: b, because it reuses the Internet Center's limit of 1 and its 8 slots (factionbuilding.ini:33966, 33995) as the Hacker cap with no new rule. Why it matters: unlimited Hackers are China's version of the stacking the owner names.

Q11. With a limit in place, how much should the passive buildings pay? (Revises the batch A answer, as Q8.)
   a) Zero Hour's rates: Black Market 600, Supply Drop Zone 750, a Hacker 150 rising to 300 per minute — ZH default (factionbuilding.ini:10143-10144, 19305-19306; crate.ini:550; chinainfantry.ini:1332-1337)   b) Zero Hour's rates doubled, so the one allowed building is worth its 2,500   c) Zero Hour's rates, but the building pays only while its owner holds at least one capture point
   Recommendation: a, because the points carry the late game and Zero Hour's numbers keep the pay-back time players know (about 4 minutes). Why it matters: decides whether passive income still decides close matches.

Q12. What happens to a point when the building on it is destroyed?
   a) The derrick is gone for good; nothing can be rebuilt there — ZH default (inferred: the derrick's entry has no rebuild behaviour, civilianbuilding.ini:25098, 25140)   b) The point stays and turns neutral; anyone can capture it and build on it again, upgrades lost   c) The point stays with its owner, who can rebuild it, upgrades lost
   Recommendation: b, because a point that can vanish ends the late game the same way empty piles do. Why it matters: decides whether destroying a point is denial or a swing.

Q13. Should capturing a point pay a one-time bonus?
   a) Yes, 1,000 once per point per match, to the first owner only — ZH default (civilianbuilding.ini:25110; AutoDepositUpdate.cpp:120-141, 150-156)   b) Yes, on every capture   c) No bonus
   Recommendation: a, because it rewards the early grab without making points worth trading back and forth for cash. Why it matters: a bonus on every capture invites farming two points against each other.

Q14. How should bots treat capture points?
   a) Ignore them (Wargrid bots today; the OpenRA Red Alert bot also has no capture module, `rg CaptureManagerBotModule mods`: 0 hits)   b) Capture and upgrade nearby free points at every level   c) As b, and from Regular up also attack enemy points
   Recommendation: c, because bots should use the same mechanics as humans (design-answers-2026-11-08.md:1128), and raiding points is the active play this change is for. Why it matters: without it bots go broke again in the late game, as they do today (blueprint.md:711). Zero Hour default: not found (its skirmish scripts were not read; ScriptConditions.cpp:2257-2288 only shows the condition exists).

Q15. Does the building on a point look different per faction?
   a) One neutral derrick for everyone — ZH default (one `TechOilDerrick`, civilianbuilding.ini:24882)   b) One shape per faction, same numbers   c) Per faction shape and per faction numbers
   Recommendation: b, because faction differences are capability data, not rule branches (blueprint §14), and a faction shape shows the owner at a glance. Why it matters: one more shape per faction for the art pass.
