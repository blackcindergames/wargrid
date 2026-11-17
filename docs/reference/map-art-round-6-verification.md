```text
Resume record (updated 2026-11-17, commit point B)
Branch / base commit / working-tree state: spike-art-6 / commit point B (Task 10) / clean after the commit
Last green task / next incomplete task: Task 9 (stop gate 3 answered, china_collector nudged) / Task 11 (page frame)
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: roundtrip.sh picked PASS 2040 max 1.00e-5 px ties 121 shade 218 triangles known-failing 1; today PASS 1872 known-failing 1; audit PASS 187 known 25; export.sh 37 shapes, corrections hold
Known red case or blocker: frc_builder|0|2|24|24 listed failing (P2.4); docs/images/hud-v5/source/export_layout.sh can report "not rewritten" by chance (whole-second -nt check), a rerun passes
Approved decisions, pre-authorizations used, deferred gates: stop gates 1 and 3 answered (user, 2026-11-17, Task 2 and Task 9 rows); Neon dropped, new steps owners_dark and cargo (user, 2026-11-17); local commits A and B (pre-approved); full suite and run_checks.sh deferred to Task 31
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: dispatch Task 11 with steps surfaces, edge, power, owners_dark, cargo (A/B), paused, wrecks (confirm), optional clash
```

## Zero Hour defaults

Revisions: Zero Hour source `~/projects/CnC_Generals_Zero_Hour` @ 0a05454 (paths under `GeneralsMD/Code/`, short form `GE/` = `GameEngine/Source`, `GED/` = `GameEngineDevice/Source`). INI entries cite `entry:line` from `build/zh_ini/inizh.jsonl`. "Wargrid today" = `game/scripts/` at 9b21db3 (unchanged at e71401c). Durations in INI are milliseconds, converted to 30 logic frames per second (`INI::parseDurationUnsignedInt`).

### (a) Low power: a building and a defence

**Zero Hour behaviour.** Only objects with `KINDOF_POWERED` are affected. When consumption exceeds supply, every such object gets `DISABLED_UNDERPOWERED`; the flag clears when supply recovers. Power-plants, barracks, factories and supply centres are not POWERED, so they keep producing. Wargrid's work-rate slowdown has no Zero Hour counterpart: not found.
- What stops: a disabled object skips every update module not in its "disabled types to process" mask (`GE/GameLogic/System/GameLogic.cpp:3702`, `:3742`), so the defence stops targeting and firing. Update modules that opt in: `BaseRegenerateUpdate.h:79`, `ParticleUplinkCannonUpdate.h:190`. `Object::isMobile` returns false when disabled (`GE/GameLogic/Object/Object.cpp:2907`). Control-bar buttons are greyed out unless flagged `IGNORES_UNDERPOWERED` (`GE/GameClient/GUI/ControlBar/ControlBarCommand.cpp:1072-1079`).
- What the player sees:
  - Animation pauses. `Drawable::getShouldAnimate` returns false when underpowered, but only if the draw module has `AnimationsRequirePower` set (default true: `GED/W3DDevice/GameClient/Drawable/Draw/W3DModelDraw.cpp:1024`, parsed `:1206`, applied `:2043`; `GE/GameClient/Drawable.cpp:653-659`). The main draw module of Patriot and Gattling keeps the default. Only their damaged-state modules `ModuleTag_02` and `ModuleTag_03` set it `No` (`factionbuilding.ini:28599, 28704` Patriot; `:31370, 31476` Gattling).
  - A looping "Disabled" lightning icon is drawn above the health bar (`GE/GameClient/Drawable.cpp:3648-3687`; the same icon serves EMP, hacked, subdued and paralysed). Its animation is `Animation Disabled`: 16 frames `SCPLightning000-015`, `AnimationDelay 66`, LOOP (`animation2d.ini:214-238`).
  - A one-shot "building disabled" sound plays on the first loss (`GE/GameLogic/Object/Object.cpp:2093-2103`, `m_buildingDisabled`).
  - No tint, no model swap and no light change for power: not found. The NIGHT/SNOW condition states are keyed to time of day and map weather, not to power.
- Which objects are POWERED (selection): `AmericaPatriotBattery` `factionbuilding.ini:28472` (`EnergyProduction -3` at `:28827`), `ChinaGattlingCannon` `:30670` (`-3` at `:31603`), `ChinaSpeakerTower` `:13770`, `ChinaNuclearMissileLauncher` `:12297`, `AmericaParticleCannonUplink` `:4910`. 39 Object blocks in total list KindOf POWERED. The Power Plant has `EnergyProduction 5` (`:4819`).
- Trigger: `Player::onPowerBrownOutChange` runs on every production or consumption change (`GE/Common/RTS/Energy.cpp:235-248`, `GE/Common/RTS/Player.cpp:3250-3258`). It disables or enables every POWERED object at once. Power sabotage also forces the low state (`Energy.cpp:100-106`).

**Wargrid today.**
- A completed building whose kind has `powered: true` (the missile battery, the rotary gun tower) stops firing while the owner's power balance is negative: `game/scripts/simulation/combat.gd:403-404, 428-437`.
- Separately, every player's production and construction rate falls to 500-800 per mille when supply is below demand: `game/scripts/simulation/economy_definitions.gd:11-15`, applied in `simulation.gd:620, 922`. Zero Hour does not slow production at all (not found), so this is a Wargrid rule.
- Presentation: the announcer line "low_power" on the transition (`game/scripts/presentation/sound_director.gd:185-198`), and the status line "Power: supply/demand" (`game/scripts/match/hud.gd:59`). No per-building marker for a dark defence: not found in `game/scripts/presentation/`.

**Gap for Task 15.** Zero Hour marks the dark defence itself (frozen animation plus a lightning icon over the health bar). Wargrid marks nothing at the defence.

**Uncertainty.** I did not open the W3D art or the sound files, so I cannot say what the frozen pose looks like. The `AnimationsRequirePower` readings are for the damaged modules of the Patriot and Gattling blocks only; I did not read the main module's `ConditionState` list. The icon's size and position come from health-bar geometry (not measured here).

### (b) Vehicle wrecks (hulks)

**Zero Hour behaviour.**
- A vehicle's `SlowDeathBehavior` or `CreateObjectDie` spawns a separate Object flagged `KindOf NO_COLLIDE HULK`. Hulks live in `hulk.ini`. Per-vehicle hulk objects differ, and some vehicles leave only debris. Examples: Battlemaster `SlowDeathBehavior` makes debris only (`chinavehicle.ini:164-166` `OCL_ChinaTankBattleMasterDebris`); I did not look for a hulk from it.
- Tank (Crusader), `americavehicle.ini:1371`: two alternative `SlowDeathBehavior` modules (each `ProbabilityModifier 50`). One has `DestructionDelay 500` (+/-100) and spawns the hulk at MIDPOINT, with a turret debris OCL at FINAL (`:1517-1524`). The other has `DestructionDelay 2000` (+/-300) with fire FX and spawns the hulk at FINAL (`:1529-1535`). Both use `OCL_GenericTankDeathEffect`, which creates `DeadCrusaderHulk` and 12 flying hull debris pieces `GXMammoth_D01-D12` (`objectcreationlist.ini:1193-1303`, hulk at `:1195-1199`, `SEND_IT_FLYING`, intensity 0.1).
- `DeadCrusaderHulk` (`hulk.ini:1351-1381`): model `AVLeopard_D1`; physics with `KillWhenRestingOnGround Yes` (`:1367-1369`); `LifetimeUpdate` min 1500, max 1600 ms (`:1372-1373`); then a `SlowDeathBehavior` with `SinkDelay 1500`, `SinkRate 2`, `DestructionDelay 8000` (`:1377-1379`). `LifetimeUpdate` calls `kill()`, not destroy, after the lifetime (`GE/GameLogic/Object/Update/LifetimeUpdate.cpp:93-97`). That `kill()` starts the slow death, and the sink and destruction frames count from that moment (`GE/GameLogic/Object/Behavior/SlowDeathBehavior.cpp:262-263, 326`). Net: the generic tank hulk (`DeadTankHulk`, `hulk.ini:820-851`, same numbers, model `GXMammoth_CH`) sits about 1.5 s, sinks from about 3 s (at rate 2, `SlowDeathBehavior.cpp:455-460`) and is gone about 9.5 s after it spawns. Plus 0.5-2.3 s of burning before it spawns.
- Light vehicle (Humvee), `americavehicle.ini:3`: `SlowDeathBehavior` `DestructionDelay 1`, `OCL INITIAL OCL_InitialHumveeDebris` (creates `AmericaVehicleHumveeDeadHull`, `objectcreationlist.ini:5343-5350`), `OCL FINAL OCL_FinalHumveeDebris` (4 hull pieces `AVHUMMER_D2/D3` plus 4 `AVScrap` pieces, `:5352-5418`; `americavehicle.ini:212-217`). `AmericaVehicleHumveeDeadHull` (`hulk.ini:58-111`): model `AVHUMMER_D1`, `LifetimeUpdate 0/0` (so it is killed after one frame, `LifetimeUpdate.cpp:85-88`), then `SinkDelay 14000`, `SinkRate 2`, `DestructionDelay 20000` (`:96-98`), `TransitionDamageFX` smoke (`:102`). It also has `GeometryIsSmall Yes`.
- Look: the dark charred hull is the `_D1` model (damaged-state geometry, not a fresh model). Smoke only on the Humvee hull. The wreck sinks into the ground before it is removed and its shadow decal fades (`SlowDeathBehavior.cpp:225-232`). A global script override can force hulks to sink at once and vanish after 1 s (`SlowDeathBehavior.cpp:252-258`, `LifetimeUpdate.cpp:55`; `GameLogic::m_scriptHulkMaxLifetimeOverride`). There is no map or game option for it.

**Wargrid's 20 s tanks / 8 s light vehicles: contradicted, and inverted.** In Zero Hour the tank hulk is the short one (about 9.5 s after spawn) and the Humvee hull is the long one (20 s, sinking from 14 s). The 20 s figure exists in the data, but for the light vehicle, and 8 s is close to the tank's 8 s destruction delay. If Wargrid wants Zero Hour feel: tank about 8-10 s, light vehicle about 20 s. If it keeps its own numbers it is a deliberate departure and should be labelled so. One vehicle per class was read (Crusader, Humvee); other vehicles have their own hulk objects and lifetimes.

**Wargrid today.** The wreck is a lab-only construct, not simulation: `game/scripts/lab/ab_variants.gd:24-26` (`WRECK_TICKS_A = 600`, `WRECK_TICKS_A_LIGHT = 240`, `WRECK_SINK_TICKS = 45`; at 30 ticks per second that is 20 s and 8 s, last 1.5 s as a sink); the picking is at `:101-102`, the drawing at `:136-141` (dark diamond `Color("2b2d2f")`, shrinking). The simulation removes a dead unit at once (`game/scripts/simulation/combat.gd:420-425`, `remove_object`). No hulk object exists in the game proper.

**Uncertainty.** Frames-per-second 30 assumed from `LOGICFRAMES_PER_SECOND` (not opened). Total hulk time for the tank is my sum, not a value in the data. `SinkRate 2` is a per-frame step in world units after unit conversion; not measured. Which of the two tank slow-death modules fires is random (50/50).

### (c) Construction paused part-way

**Zero Hour behaviour.**
- A new site is created with construction percent 0, 1 hit point, and model conditions `AWAITING_CONSTRUCTION` set, `PARTIALLY_CONSTRUCTED` and `ACTIVELY_BEING_CONSTRUCTED` cleared (`GE/GameLogic/Object/Update/AIUpdate/DozerAIUpdate.cpp:1726-1737`). AWAITING shows no model at all: `ConditionState = AWAITING_CONSTRUCTION  Model NONE` (`factionbuilding.ini:4272`, `:4773`, `:21497`; PowerPlant and Barracks).
- When a builder first reaches the site, AWAITING is cleared and both PARTIALLY and ACTIVELY are set (`DozerAIUpdate.cpp:356-361`). Each tick at the dock, the percent rises by `100 / framesToBuild` and health by `maxHealth / framesToBuild` (`:536-550`). The player pays up front (BuildAssistant), as Wargrid does.
- Look while building, American Power Plant (`AmericaPowerPlant`, `factionbuilding.ini:3858-4907`):
  - Main body, module 01 and 05: model `ABPWRPLANT`, flag `ADJUST_HEIGHT_BY_CONSTRUCTION_PERCENT` (`:4223-4224`). The building rises out of the ground by percent: `translate Z by -height + height*pct/100` (`GED/.../W3DModelDraw.cpp:2024-2035`). Same for damaged, night and snow variants.
  - Scaffold, module 03, state `PARTIALLY_CONSTRUCTED`: model `ABPwrPlant_A6`, animation `AnimationMode MANUAL`, `START_FRAME_LAST`, with blue spark particles `BuildUpBlueSpark` at bones `SparksS01/S02/S06` and `SparksSmall` at `S03` (`:4448-4456`). Barracks equivalent `ABBarracks_A6` with six `BuildUpBlueSpark` (`:21668-21678`).
  - Active work, module 04, state `ACTIVELY_BEING_CONSTRUCTED`: model `ABPwrPlant_A5`, `AnimationMode LOOP` (`:4574-4577`); Barracks `ABBarracks_A5` LOOP (`:21801-21804`). Module 02 (`ABPwrPlant_A4`, MANUAL, smoke plus sparks) is keyed to both flags (`:4334-4340`).
  - A percentage label is drawn over the site ("CONTROLBAR:UnderConstructionDesc") only while `OBJECT_STATUS_UNDER_CONSTRUCTION` is set (`GE/GameClient/Drawable.cpp:3700-3745`).
  - Construction cost `BuildCost 800`, `BuildTime 10.0` s (`:4817-4818`); Barracks `600`, `10.0` (`:21888-21889`).
- Paused (the builder leaves): the site stays at its percent, keeps its health and keeps `UNDER_CONSTRUCTION`; no decay is implemented (not found). `ACTIVELY_BEING_CONSTRUCTED` is cleared in only one place I found: `DozerAIUpdate::onDelete` (`:2238-2262`), when the builder is removed. When the builder is merely given another order, the clear is commented out with the note "we don't have idle crane animations and it is December" (`:2166-2173`). So:
  - Builder dies: the loop scaffold `_A5` goes, `_A6` (MANUAL, last frame, blue sparks) and the rising body remain. This is the closest thing to a distinct "paused" look.
  - Builder just walks away: the site looks exactly like an active site, with the `_A5` loop still running (a gap against the intent of the engine comments; Zero Hour has no separate paused look).
  - Resuming sets PARTIALLY/ACTIVELY again at the same percent (`:356-361`).
- Scaffold versus just started: same models; at 0 percent the body is fully underground (translate -height) and the `_A6`/`_A5` scaffold stands alone, and as the percent grows the body rises through it. The scaffold does not itself change with percent.

**Wargrid today.** `building.completed == false` marks a site; `work` accrues only while the builder stands at the approach point with status "arrived" (`game/scripts/simulation/construction.gd:144-150`); `builder_id` is cleared at `construction.gd:156` and `simulation.gd:991`, which is the "paused" state. Presentation draws the label "N%" and appends " paused" when `builder_id == null` (`game/scripts/presentation/world_view.gd:330-333`, label drawn at `:456`), tints the footprint (`:478`), and gives a hover hit only to paused unowned-by-builder sites of the local player (`:347`). The picture is a tinted footprint: no rising body, no scaffold, no sparks and no distinct paused look beyond the text. Nothing is read from the "paused" state for animation.

**Uncertainty.** I read the Power Plant and Barracks only; the module-to-flag reading (which module uses which state) comes from the INI path text. I did not render or open the `_A4/_A5/_A6` models, so what the scaffold looks like (crane, poles) is unknown. I did not test in a running Zero Hour game whether a walked-away builder leaves the loop playing; this comes from the commented-out clear only.

Coordinator cross-check (2026-11-17): `DeadTankHulk` `hulk.ini:841-848` (MinLifetime 1500, SinkDelay 1500, DestructionDelay 8000) and `AmericaVehicleHumveeDeadHull` `hulk.ini:91-98` (Lifetime 0, SinkDelay 14000, DestructionDelay 20000) read again from `build/zh_ini/inizh.jsonl`. Wargrid's decided 20 s tanks / 8 s light vehicles carries the same two numbers the other way round; round 6 draws wrecks only and does not change the times; the point goes to the Task 22 questionnaire.

## Evidence rows (append-only)

### 2026-11-17 Task 1: Base and verification file (tree: spike-art-6 52f0a06 plus this file)

- `git status --short` empty at start; `git log --oneline -3`: 52f0a06 (Task 0), 9b21db3, 895d615. Exit 0.
- Presentation files unchanged since 10b9423 (`git log --oneline 10b9423..HEAD -- shapes.gd palette.gd shape_bake.gd world_batch.gd world_view.gd isometric.gd graphics_settings.gd`): empty, exit 0.
- Environment: Firefox 160.0; cwebp 1.6.0; dwebp 1.6.0; ImageMagick 7.1.2-36 Q16-HDRI aarch64; Godot 4.7.2.stable.official.ed1daf0bf; Zero Hour `~/projects/CnC_Generals_Zero_Hour` 0a05454; fork `~/projects/GeneralsGameCode` afc2a103f.
- `ls docs/images/hud-v5/source/picks.json`: no such file (expected).
- Baseline `WARGRID_TEST_ONLY=test_shapes sh tools/run_tests.sh`: 22 cases, 1374 checks, 0 failures, TESTS PASSED 1374, exit 0 (log `build/map-art/logs/1-shapes.log`).
- Counts for later proofs: `docs/images/map-art/*.webp` 25; `docs/images/hud-v5/*.webp` 26; `docs/images/hud-v5/layout.json` sha256 `19eb6e1fb5d6c0686761f24728b7dc79ec20d8cb028e327be1351bb0f61ef977`.

### 2026-11-17 Task 2: Move and trim the source, shoot script, first shoot (tree: spike-art-6 52f0a06 plus `docs/images/map-art/source/` untracked)

- `report=fonts` (Firefox headless, server on 8769): `400 ok / 600 ok / 700 ok / 800 ok / PASS 4`, exit 0. `report=pics`: 25 names, `PASS 25`, exit 0.
- First shoot, 1x, `AS=shot`, 25 files each, exit 0, sizes 1280x720; 2x run 25 files 2560x1440, exit 0 (logs `build/map-art/logs/2-shoot-*.log`).
- Count of differing pixels against the committed picture (`magick compare -metric AE`), Inter (`&font=inter`): 21 pictures 0; `damage-today-z05` 2170, `damage-picked-z05` 2170, `placeholders-today-z1` 2381 (text only). `base-usa-china-z05`: 0 against the private page shot with the HUD layer hidden, whole frame (against the committed `-hud` picture 85200, the HUD v4 layer). `base-usa-z1`, `base-china-z1`, `base-frc-z1` carry no HUD layer: 0.
- The three text pictures with `&font=arial` (the fallback face): 0 each. The private pages shoot them 0 against the committed files in the same way: the committed text was drawn before Inter had loaded.
- Public Sans (1x) against Inter (1x): only those three differ (2062, 2062, 2434 px, text); the rest 0.
- 2x beside 1x (`units-picked-z2`, `world-picked-z05`): same layout, edges sharper.
- `sh tools/check_public.sh`: `PUBLIC CHECK PASSED`; `sh tools/run_shell_checks.sh`: exit 0; ruff format, ruff check, mypy on `server.py`: exit 0. `git status --short game tools`: empty. Server stopped.
- Stop gate 1: with Inter `damage-today-z05` 2170, `damage-picked-z05` 2170, `placeholders-today-z1` 2381; with `&font=arial` 0 each. Accepted (user, 2026-11-17): the first-shoot proof baseline for these three is `&font=arial`, because the committed captions were drawn in the fallback face; kept pictures stay Public Sans.
- Decisions:
  - `legacy` is part of the selection (`{steps, fix4b, fix6, legacy}`): the `shot` selections of the rounds 1 to 4 pictures set it, and the old ground shade, shadow and owner table and no China tank mix follow. Task 24's `final` selections must set it false.
  - A step left out of a selection does not apply; `'0'` means today. Why: `damage: '0'` turns bodies back to today's shapes, while the other round 4 pictures leave damage unset.
  - `&font=arial` beside `&font=inter` (proofs only, both kept and documented), per the stop gate 1 acceptance above.
  - `world-picked-z05`, `world-picked-dark-z05` and `world-cliff-decor-z1` use fog `'0'` (the old page never applied fog outside its own step); `world-today-z05` has every round 5 step `'0'`.
  - `dmg` (damage levels spread over the bases) is on only in `world-today-z05`, `world-picked-z05` and `world-picked-dark-z05`.
  - `shoot.sh` runs `report=fonts` first and exits 1 when it fails; the page throws when a Public Sans weight does not load (`&font=arial` is the explicit exception). Negative test on a scratch copy with a missing face: `shoot.sh` exit 1, no file written.
  - `meta.export_command` in `shapes-current.*` is the plan's contract string with literal `<repo>` and `<file>`.

### 2026-11-17 Task 4: One shared HUD file and its no-difference proof (tree: spike-art-6 52f0a06 plus `docs/images/hud-v5/source/{hud.js,hud.css}` untracked, `round1.html` modified, `docs/images/map-art/source/` untracked)

- Step 1: `docs/images/hud-v5/source/picks.json` absent; `git status --short docs/images/hud-v5` empty.
- Step 2 baseline on the unedited source: `shoot_final.sh` exit 0, `export_layout.sh` exit 0 ("78 screens, coverage sums match"), `git status --short docs/images/hud-v5` empty (no drift). 8 size shots (`#shot=<none|many|factory|build>&size=<720|1920>&tier=full&scale=2`, 2560x1440 and 3840x2160) in `build/map-art/hud-before/`.
- `export_layout.sh` failed with "layout.json was not rewritten" on 3 of 5 runs in this task (before and after the move), each time on the `-nt` whole-second check (Firefox writes it within about 1 s of the stamp); rerun once or twice passed, every time with an identical file. Script not edited.
- Step 3: `hud.js` (334 lines, `window.HUDV5`, one global; exports SIZES, STATES, FONT, BG, FLAT, OWNERS, HEALTH, CELL, CELL_PAD, DATA, BASE, KINDS, luminance, contrast, mix, lifted, isCore, pinnedShown, glyph, glyphFor, unitGlyph, layout, dock, hud, hudScale, updateCard, placeRefusal, placeCards, shown), `hud.css` (96 lines: four `@font-face`, `.hud .cur`, every `.hud` rule), `round1.html` 960 to 535 lines (`<link>` and `<script src="hud.js">`, one `const {...} = HUDV5;` line; page-only names stay: size and state labels, keys, name-fit widths, stage, backdrops, coverage, audit, picks). `node --check` on `hud.js` and the page script: ok.
- Step 4 proof: `shoot_final.sh` exit 0 (26 files rewritten, all newer than `hud.js`); `export_layout.sh` exit 0 on a rerun; `git status --short docs/images/hud-v5` shows only `round1.html`, `hud.css`, `hud.js`; `cmp docs/images/hud-v5/layout.json <(git show HEAD:...)` exit 0 (sha256 `19eb6e1f...f977`, as Task 1); 8 size shots in `build/map-art/hud-after/`: AE 0 for all 8 against `hud-before/`. The default (interactive) HUD page renders with no error banner.
- Step 5, map page: `report.sh 'report=fonts' fonts` exit 0, `PASS 4`. Hash `&hud=<state>` (optional `&tier=`) adds the layer from `layout.json` meta values plus `HUDV5.hud` and `placeCards`; layout.json is fetched together with the font load (a fetch after the draw lost the race with the headless screenshot, the page showed no layer). `[hidden]{display:none!important}` added to `page.css` (the HUD page has it in its own style; without it the hidden cursor showed). `page.css` no longer has `@font-face`. Screenshots read by eye: `build/map-art/hud-check/base-usa-z1-hud-none.png` (dock, strip, Team/Menu, minimap, Public Sans) and `base-usa-z1-hud-factory.png` (selection panel, card, hover card).
- Task 2 proof rerun: `SCALE=1 AS=shot EXTRA='&font=arial' OUT=build/map-art/t4-arial sh docs/images/map-art/source/shoot.sh` exit 0, 25 files; `magick compare -metric AE` against `docs/images/map-art/<name>.webp` (`base-usa-china-z05` against `build/map-art/ref-nohud/`): 25 of 25 are 0, 0 differ. Control: `base-usa-z1` against `base-china-z1` AE 72899.8.
- `sh tools/check_public.sh`: `PUBLIC CHECK PASSED`; `sh tools/run_shell_checks.sh`: exit 0; `rg -n 'wargrid-private|wargrid-wt-|/Users/'` over the touched files: no hit. `git status --short game tools`: empty. Both servers (8767, 8769) stopped.

### 2026-11-17 Task 8: Zero Hour defaults (tree: spike-art-6 e71401c, read-only)

- `python3 tools/zh_ini.py dump` -> `ZH_INI entries=135 blocks=12419 fields=324399`, exit 0 (writes only `build/zh_ini/inizh.jsonl`, ignored).
- `rg` and small `python3` filters over `build/zh_ini/inizh.jsonl` (objects `AmericaPowerPlant`, `AmericaBarracks`, `AmericaPatriotBattery`, `ChinaGattlingCannon`, `AmericaTankCrusader`, `AmericaVehicleHumvee`, `DeadTankHulk`, `DeadCrusaderHulk`, `AmericaVehicleHumveeDeadHull`; OCLs `OCL_GenericTankDeathEffect`, `OCL_InitialHumveeDebris`, `OCL_FinalHumveeDebris`; animation `Disabled`; every Object with KindOf POWERED), read-only, exit 0.
- `rg -n` and `sed -n` over `~/projects/CnC_Generals_Zero_Hour` @ 0a05454 (`Drawable.cpp`, `Player.cpp`, `Energy.cpp`, `Object.cpp`, `GameLogic.cpp`, `LifetimeUpdate.cpp`, `SlowDeathBehavior.cpp`, `DozerAIUpdate.cpp`, `BuildAssistant.cpp`, `W3DModelDraw.cpp`), read-only, exit 0.
- `rg -n` and `sed -n` over `game/scripts/` at e71401c (the same game code as 9b21db3), exit 0.
- `git status --short game tools` after the work: empty. Nothing written in the repository except this report file.
- Not checked: `sh tools/check_public.sh` (the section uses `~/projects/...` paths and no machine names; the coordinator runs the check when it pastes the text). Fork `~/projects/GeneralsGameCode` (afc2a103f) was not consulted; the original source at 0a05454 sufficed.

### 2026-11-17 Task 7: Today export, picked export and the Godot round trip, fix round 2 (tree: spike-art-6 e71401c plus `docs/images/map-art/source/{export_shapes.gd,roundtrip.gd,export.sh,roundtrip.sh}` and `docs/images/map-art/shapes-picked.json` untracked, `round6.html`, `picked.js`, `draw.js`, `README.md` modified)

- Step 1, 2, export, negative checks and regression pictures as in the first row; comparer mutation (`projectShape` reverses part 0's prims) `FAIL 1429 of 1872` as in fix round 1.
- Today round trip: `PASS 1872 max 1.00e-5 px ties 35 shade 28 triangles known-failing 1` (`frc_builder|0|2|24|24`, listed failing, user 2026-11-17), exit 0. `export.sh`: `37 shapes, corrections hold`, exit 0. Picked round trip: `FAIL 1 of 2040` (`china_collector|0|2|8|8`, to be fixed in the candidate data), exit 1; 121 ties, known-failing 1. Out-of-range game order index: named FAIL, exit 1.
- Audit: `PASS 187 known 25`, exit 0 (KNOWN: owner tops on sand 8, in fog on sand 8, on the dark ground 7 and cargo on sand until Task 24, China rifle share 21.2 %).
- gdlint, check_public, shell checks green; no private path; `git status --short game tools` empty; server stopped.

### 2026-11-17 Task 9: stop gate 3 and the audit decisions (coordinator)

- Review of Task 7 (fresh Opus high) found the first comparer's reorder check vacuous; after the fix a page with one part's prims reversed fails 1429 of 1872 today poses. Two poses then failed: `frc_builder|0|2|24|24` (today's game shape, also in the today run) and `china_collector|0|2|8|8` (picked only): two prims of one part with equal paint sort keys, so the order, and the colour on top, is float noise in Godot.
- Neon owner set dropped (user, 2026-11-17): the default set passes colour vision on every owner pair (bar 20); Neon failed blue/purple 1.5, red/green 12.2, green/orange 19.5. Removing the Neon option from the game is a P2.4 rider; F12 closes as "Neon removed". The round 6 Neon step is cut.
- `frc_builder|0|2|24|24`: listed failing, stays in the comparison, P2.4's eight-heading paint-order audit fixes it (user, 2026-11-17).
- `china_collector|0|2|8|8`: nudged in the picked data (user, 2026-11-17); row below.
- Audit lines with no recorded decision, answered (user, 2026-11-17): owner tops in fog on sand (8) accepted; side band against the HUD slab dropped from the audit (round 5 measured every colour against all three backdrops; no world shape is drawn on the slab); owner tops on the dark ground (7) and cargo colour on sand (2.44) become new pick steps `owners_dark` and `cargo`, listed KNOWN as open until Task 24 bakes the pick.

### 2026-11-17 Task 9: china_collector nudge (tree: spike-art-6 e71401c plus the Task 7 working tree; `picked.js` cand4 `china_collector@d2` body side strips x 0 → ∓0.005)

- Tie: body prims 0, 1 and 2 at d2 all had x = 0, so their keys at buckets 8 and 40 were equal up to float noise; at bucket 8 Godot drew `[0,1,2]` and the page `[1,0,2]`. After the nudge the smallest key gap is 7.07e-3, and the order at all 8 headings equals the page's old order. Godot agrees at all 8.
- `sh docs/images/map-art/source/export.sh`: `37 shapes, corrections hold`, exit 0.
- `sh docs/images/map-art/source/roundtrip.sh`: `PASS 2040 max 1.00e-5 px ties 121 shade 218 triangles known-failing 1` (`frc_builder|0|2|24|24`), exit 0. The only china_collector TIE left is the knife-edge shade TIE at bucket 24, the same as today.
- `sh docs/images/map-art/source/report.sh audit audit`: `PASS 187 known 25`, exit 0 (`audit audit-7n`: exit 1, the page posts only to `audit`).
- Before and after pictures, `SCALE=2 AS=shot`: units-picked-z2, zoom2-picked-z2, world-picked-z05 and base-china-z1 each differ by AE 0 (none shows China at detail 2). Scratch truck picture over 64 buckets at zoom 2: 18575 edge pixels differ (801 by more than 32/255, max 108/255), no visible difference; zoom 1 and 0.5 differ by 0 px.
- `sh tools/check_public.sh`: PUBLIC CHECK PASSED, exit 0. `git status --short game tools` empty; server stopped.
