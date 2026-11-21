# P2.3b Build from the dock: design and plan (2026-11-21)

Approved by the user 2026-11-21; pre-authorized: one local commit per green task and one push of the branch at the gate, never `main`. T15 keeps this file current. Base `main` `18a46ca6`. For one attended session on branch `p2-3b-build-from-the-dock` from `main`, own worktree. Lighter process (`docs/superpowers/specs/2026-11-20-fun-first-reorder-design.md`).

Inputs (private, `~/projects/wargrid-overnight-work/fun-first-prep/`): `p23b-hud-decisions.md` (`HD#n`), `zh-controls-defaults.md` (`ZH#n`; `*.ini:N` = `build/zh_ini/inizh.jsonl` entry:line), `f23-f33-repro.patch`, `owner-answers.md`, `p23b-final-review.md`. `DA` = `docs/reference/design-answers-2026-11-08.md`, `LR` = `docs/reference/hud-v5-layout.md`, `PK` = `docs/packages.md`. Owner decisions (`owner-answers.md`, DA "P2.3b War Room round (user, 2026-11-21)", `DA:1470-1479`) are final.

## Why and scope

Today a player builds from a column of `1: Name $cost` buttons and selects by mouse only; P2.3b brings the HUD v5 command card and the controls a friend match needs. Scope `PK:27`: card, blocked cells, cell card, queue tiles, chips, Controls list; riders groups, `H`, `Space`, allied line, LOW POWER, counter lines, F23, F33, F38, camera keys, edge scroll, focus card, start selection. Out: everything `PK:27` defers, P2.3a2's refusal wording table, a site cell on the card.

No sim change except the drivers carrying the preview on every job (F33); no re-pin: the preview is an unlogged query after the step (`sim_pump.gd:156-159`), its `construction.gd:87-92` bump local and unhashed.

## Decisions already taken

No title row, cells 100 x 60 (`LR:142`); no Stop for builders and collectors (`DA:1344`); arrow keys pan (`match_screen.gd:328`); strip owns the purchase preview (`DA:1414,1420`); Esc chip only when Esc opens the menu (`DA:1303`); X only on blocked cells (`DA:1274`); reasons and costs in `warn` (`DA:1352`); hover `panel2` + 1 px inset + hand (`DA:1279,1332,1430`); message homes `DA:1417`; key chips keep the as-built layout labels (`hud_model.gd:74-78`, 3-14).

## Design

**Grid table.** Buildings carry a role in `slot` (`definitions/{usa,china,frc}.gd`); unit ids are `<faction>_<role>`. One `HudModel.CELL_KEYS` maps role to key.

| Card | Q | W | E | R | A | S | F | V |
|---|---|---|---|---|---|---|---|---|
| Units | | | | | Attack Move | Stop | Unload (transport) | |
| One builder | Build › | | | | | | | |
| Two or more builders | Build › blocked, `Select one builder` (3-7) | | | | | | | |
| Nothing selected | no card; `Q` → `Select a <builder>` (3-6) | | | | | | | |
| Build sub-grid | power_plant (FRC empty, 3-13) | supply_center | barracks | factory | defence | | | Back |
| Placement | sub-grid, armed `sel` | | | | | | | Cancel |
| HQ / supply center | builder / collector (FRC Cache: builder) | | | | | | | |
| Barracks | rifle_inf. | rocket_inf. | | | | | | |
| Factory | light_vehicle | tank | (P15) | | | | | |
| Defence | | | | | | | Unload if `contains` (`frc.gd:15`) | |
| Power, enemy, pile | no card | | | | | | | |
| Site | no card; `Cancel construction` button stays | | | | | | | |

`<builder>` = `Registry.kind(start_unit).display_name` via `HudModel` (`hud_model.gd:32`): `Select a Bulldozer` (USA, China), `Select a Laborer` (FRC). Mixed selection: shared commands only, Attack Move when any unit can attack (`LR:207`, `hud_model.gd:118`). Cells show `quantity` (Militia `×2`). Back's chip reads `V`, its tooltip names Esc.

**Input resolver.** New `orders._card_key(event)` runs first (before `orders.gd:49`). The key branches of `_combat_input` (`orders.gd:113-119`) and `F` (`:153-155`) move into it: every unmodified grid key is consumed, pressed if its cell is shown on the current card (selection + sub-grid), ignored otherwise; one exception, `Q` with nothing selected refuses. Ctrl/Cmd/Alt never press a cell. The digit path (`:146`) and the `KEY_B` swallow (`:148`) go too. Sub-grid state lives in `orders.gd`; `_hud_selection()` (`match_screen.gd:440`) carries it. `prune` (`:98`) closes the sub-grid unless exactly one own builder is selected; after a placement ends (`:177,184`) the sub-grid shows again (3-28).

**Start selection (3-6).** Each match starts with the local seat's start unit (lowest id of `start_unit`) selected once the first view is shown: offline start, online start, rematch (`_restart_world`, `match_screen.gd:521-543`, after `orders.reset()`). Not replays or spectators (neither exists on `main`; rule: only a seat that takes orders). No selection voice, camera untouched; nothing selected if the start unit is gone. So `escape_pending()` (`orders.gd:84`) is true at start: the first Esc deselects, the Esc chip hides until then.

**Esc, innermost first** (`HD#14`): placement or attack move; sub-grid; selection or inspection; menu (`escape_pending()`, `match_screen._input`).

**Blocked cells.**
- `Needs Power Plant`, `Queue full` (9, `ZH#21`), `150 credits short`, first in the sim's order (`simulation.gd:300-302`). Sub-grid cells use the kind's `prerequisite`, unit cells the producer's (USA factory after its Supply Depot dies).
- Look: credits the sole blocker: `warn` cost plus a solid 15 px `warn` coin with `$` cut out, 4 px after the bare cost (3-2, `DA:1478`). Prerequisite missing, with or without credits: muted cost, no coin, `Needs X` (user, 2026-11-21). Queue full: muted cost.
- Click equals key press: nothing arms, the reason goes on the refusal line; no Godot `disabled`. Beep for prerequisite and queue. Credits (3-8): short disabled click and `150 credits short` on every press; the `insufficient_funds` voice through a new 900-tick entry in `Announcer.COOLDOWN_TICKS` (`announcer.gd:4`, today absent, so 0). Today's `Choose one builder` (`orders.gd:324,384`) becomes `Select one builder`.
- `refuse(raw_error, sound)` (`match_screen.gd:488-494`) feeds the raw string to `SoundDirector.rejected`, which voices only `"Insufficient credits"` (`sound_director.gd:53-55`): split into `refuse(text, sound_reason)`. Sim refusals (`match_screen.gd:422-428`) keep raw words until P2.3a2.

**Cell card.** Line 1 name and muted `cost · time`; line 2 the `warn` reason when blocked; then the counter line (line 2 when ready, line 3 when blocked, kept while blocked; `DA:1477` plus PX 7). No forecast (3-4); hovering a blocked cell highlights its missing prerequisite (3-10). Opens after 250 ms on `now_msec` (`hud.gd:29`), switches at once between neighbours. No counter line in the one-unit or inspected-enemy panels.

**Queue tiles (3-3, 3-11, `DA:1475`).** In the factory selection panel, Core panel fixed at 152 px. One row of up to four 91 x 60 tiles: full name on up to two lines, the making cell's key chip, `NOW` and a 4 px `you` bar on the tile in production, no digits. Adjacent waiting entries of one kind share a tile with `×N`. Each tile keeps its entries' ids; a click cancels the newest stored entry of its run, so older entries keep their order; if that entry completed meanwhile the sim refuses (`Missing production entry`, beep), never another entry. Hover turns the chip into `×` with `Cancel · refunds <cost>`. Regrouping waits until the pointer leaves the row (as `_holding`, `hud.gd:689-690`). Over four tiles: three tiles and `+N more` (hidden entries), muted, borderless, no click, tooltip listing them. Empty: muted `Nothing in production`. The producing cell gets the 4 px `you` bar; cells show queued counts. Right-click on a production cell cancels the newest entry of that kind (OpenRA; user, 2026-11-21); none queued, nothing sent. The slab queue goes (`hud.gd:296-308,502-590`, `HudModel.QUEUE_SHOWN/COLLAPSED`). Playtest watch: a cell counts all queued of its kind (`×4`), a tile only its waiting run (`×3`).

**Cancel construction.** `CancelBuild` (`hud.gd:263-264,295,407`, `match_screen.gd:88` → `orders.gd:411-413`) and `ResumeHint` (`hud.gd:285,405`) stay as today's slab rows outside the grid (ZH keeps it, `commandbutton.ini:2215`); a site cell is an owner question after P2.3b.

**LOW POWER** (`hud_model.gd:42`): a purchase that flips power shows `LOW POWER · DEFENCES OFF` in the strip; already low, numbers turn `warn` (`HD#5`; ZH none, `ZH#24`).

**Counter line.** Words per role in a `HudModel` table; one rule, and a test derives every claim from the definitions.
- Rate `clip > 0 ? clip × damage / ((clip − 1) × delay + reload) : damage / delay` × `ARMOR[armor][type] / 100` (`combat.gd:601-611`, `shared.gd:3,15`; plain `damage/delay` overstates `rifle` 2.5x). A `ramp` weapon uses its last `percent` (Rotary Gun Tank: 300 % after 6 shots, `shared.gd:20`). FRC `weapon_tiers` at base tier.
- Per cost: `t(A→X) = hp_X × cost_A / (rate_A→X × cost_X)`, cost divided by `quantity` (Militia 150).
- `Beats X`: against every representative of X, `t(A→X)` ≤ half of `t(X→A)`. `Good against X`: A wins against every representative, not by half. `Weak against X`: every representative needs at most half A's time. The line shows the strongest `Beats`/`Good` and the strongest `Weak`; no claim, no line; none for builders and collectors.
- Classes by armour, representatives from all rosters (a unit is not its own): infantry (`human`): Rifleman, Militia, Insurgent; light vehicles (`light_vehicle`): Scout Car, Rotary Gun Tank, Armed Pickup; tanks (`tank`): Battle Tank, Medium Tank, Light Tank.
- Intended and true (user, 2026-11-21): a claim prints only if the numbers above hold AND it appears in the role's intended counter table (T9 writes the table from the Zero Hour roles, one row per role, in `HudModel`); the test proves every printed claim true and lists each intended claim the numbers refute. Each refuted claim and each true-but-unintended claim (e.g. rifle infantry `Beats tanks`, tanks `Weak against infantry`: no crushing, cannon 10 % to `human`) goes into one new STATUS finding as a balance gap for playtests; no balance change in P2.3b.
- Scratch run (unverified until the test runs): rifle infantry `Beats tanks` (cannon 10 % to `human`, no crushing); rocket infantry `Beats tanks · Weak against infantry`; tanks `Beats light vehicles · Weak against infantry`; Scout Car, Pickup `Weak against tanks`; Rotary Gun Tank `Good against light vehicles · Weak against tanks` (at base damage it loses to all three).

**Groups.** Ctrl+N saves, Cmd+N too on macOS; units only (Wargrid's own, 3-31); Ctrl+N with nothing selected clears group N, with only a building selected (`orders.gd:258`) leaves it unchanged. `N` selects live members and clears `selected_building_id`; double tap within 0.667 s (`ZH#5`) centres on the live members' centroid (3-15), injectable clock. One group per unit (`ZH#1`). Dead and contained (`orders.gd:294`) ids drop on recall; `reset()` and rematch clear. Nine `Array[int]` in new `game/scripts/match/control_groups.gd` (RefCounted) owned by `orders.gd`. Digits do nothing in placement, no build alias (3-19); `Shift+N` adds (3-16); no `Alt+N` (3-17); fallback `Shift+Ctrl+N` (3-18); save line `Group 1 · 12 units`, 2 s, bottom centre (3-27).

**Camera** (built in T10). One `match_screen.centre_camera(world)`, clamped like `pan_camera`, for groups, `H`, `Space`. `pan_camera`'s guard (`match_screen.gd:353-354`) narrows from `orders.busy()` to `is_selecting()`: the camera moves during placement (deliberate). After a camera move, orders re-run `_update_preview(_view.get_local_mouse_position())` (today motion only, `orders.gd:164-165`).

**H.** The faction's `start_building` (`factions.gd:9`), lowest id; else the costliest own building; else nothing (`ZH#8`; tie-break Wargrid's own).

**Space and the allied line.** One predicate `SoundDirector._base_hit(id, current, allied)` for voice, allied line and Space: a building, not a hole, like `_own_base` (`sound_director.gd:138-140`), not `counts_for_victory`; pass the team table into `_consume`. `_shot` records `last_attack = {tick, position}`; Space jumps there (no cycling, nothing before the first event, works in the cooldown, `ZH#9-10`); own and allied base hits only (3-20); own if younger than the voice cooldown, else newest (3-21), any age (3-22); `reset()` (`:94`) clears it. `allied_base_under_attack` (new wav, 3-23): priority 6, cooldown 900 (ZH `eva.ini:2097-2100`), listed in `Announcer.PRIORITY` (`announcer.gd:25` indexes it). Text line (3-24) top-left at (8, 48), 4 s, own and allied; HUD-owned on `now_msec`, never `driver.notice()` (`frozen()` reads it, `match_screen.gd:223-224`).

**Edge scroll.** 3 px band, window and browser, focus only, no toggle (3-25), on the visible picture rect (`match_screen.gd:246`); HUD panels count at every edge, dock included (3-26); arrow speed, step capped; stops on `NOTIFICATION_WM_MOUSE_EXIT` and focus out (web unverified).

**Controls list** in `presentation/pause_menu.gd`: mouse rules, grid keys, groups, `H`, `Space`, arrows, Esc; fits `_check_small` at 1280x720 (`test_hud.gd:234`) or scrolls.

**F23.** In `prune`, clear placement when `_placement_kind` is set and `_builder() == -1`, fields first so the nested `_show` → `prune` is a no-op (`orders.gd:335-340`); refusal `Builder lost` (3-30). Online same-step case not reproduced (covered by reading).

**F33.** Both drivers attach the standing request to every job, cleared only by `request_preview({})` and resets: `offline_driver.gd:54,58,66`, `online_driver.gd:119,126,132`; `orders.gd` keeps it standing while placement is open (`:356-358`).

**F38**: avoidable layout work per refresh (`hud.gd:458` `reset_size`, `:515,523` per queue row, `:397-398` copied shape); card and tiles do layout only when their set or size changes. HUD p95 at 2560x1080 3.06-3.22 ms against the report-only 3.04 ms.

## Run rules

- Per task: failing test first, record the red line; code; `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `python3 -m unittest tools/test_sim_boundary.py`. Iterate `WARGRID_TEST_ONLY=/test_x.gd sh tools/run_tests.sh > "$PWD/build/t.log" 2>&1; echo "exit=$?"` (timeout 600000; the `/` stops `test_scene` matching `test_base_scene`, `run_tests.gd:94`).
- Expected-red ledger: each task names its expected reds first and ends green except those; any other red is a regression: stop. Record them in new `docs/reference/p2.3b-verification.md` (T1 creates it, with a resume record).
- Opus high builds and reviews UI tasks (T0, T4, T5, T7, T8, T9, T13), plus the player-experience reviewer (`.claude/agents/player-experience-reviewer.md`); Sonnet high otherwise; one reviewer per task. Commits need the owner's go.
- Default verify T4-T13: `/test_hud.gd`, `/test_base_scene.gd`, `/test_skirmish_scene.gd` plus the task's suite.

## Tasks

- **T0 Redraw from the picks.** `docs/images/hud-v5/core-{factory,full,build,place,blocked}` at 2x from the picked `p23b-*` states in `source/p2-3a1-states.html` (`p23b-qt-run*`, `-qt-hover`, `-qt-empty`, `-none`, `-counter-card`, `-cost-dollar-solid`) via `source/shoot_final.sh`; touch up `core-{builder,one,many,none}`. New: hovered cell and tile, blocked press, two builders (3-7), nothing selected with `Select a Bulldozer` on the refusal line, the two-cause cell, prerequisite hint, counter under a reason. `source/export_layout.sh` if geometry moved. Check: player-experience reviewer against `LR` and the picks. No owner stop.
- **T1 F23.** Apply `f23-f33-repro.patch` (private) to `game/tests/test_base_scene.gd`. Expected red: `WARGRID_TEST_ONLY=test_base_scene` → `FAILURES 4`, only the three new cases (`still 'usa_power_plant'`, `HUD 'Invalid builder_id'`, `'Invalid builder or building kind'`, F33 `held 1`). `prune` fix, `Builder lost`. After: F23 cases green, F33 red.
- **T2a F33 offline.** `offline_driver.gd`, `orders.gd`. Red: `test_f33_red_ghost_refused_after_a_two_step_frame` (`held 1, tick 4, answer ... "tick": 3`). Verify `/test_base_scene.gd`, `test_sim_pump`; `PUMP_COUNTS` unchanged (`tools/test_sim_boundary.py:100-104`).
- **T3 Camera keys.** Red: `not InputMap.has_action("camera_left")` and three more. Remove `game/project.godot:30-45`, update `test_scene.gd:72`. Verify `/test_scene.gd`.
- **T4 Grid, resolver, sub-grid, Q/V.** Red: `test_no_chip_on_two_actions` (all factions, `builds`, `produces`), `test_slot_same_role_all_factions`, resolver (sub-grid `A` places defence, sub-grid `S` nothing, lone builder `A`/`S` inert with no `stop` sent, Ctrl/Cmd+A/S nothing), prune closing, `test_q_nothing_selected_refuses` (`Select a Bulldozer` USA, `Select a Laborer` FRC, refusal beep, nothing armed). Add `BaseScene.build_key(main, kind)`/`produce_key`; re-key the 33 `KEY_n` sites: `test_base_scene.gd` 10 (`:132,141,160,180,289,307,370,514,520,563`), `test_skirmish_scene.gd` 11, `test_online_scene.gd` 8 (`:1514-1676`), `test_hud.gd` 3 (`:399,403,2450`), `test_perf_overlay.gd:102-103`; plus `orders._menu_choose` at `test_skirmish_scene.gd:770,771,802,2314` and HN2's `menu_chosen` (`test_hud.gd:71-98`); `test_playtest_overlay.gd:192,1132`, `test_art_lab.gd:171` unchanged. Modifier helper from `_mod_key` (`test_playtest_overlay.gd:1106`). Expected red until re-keyed: those sites.
- **T5 Card and start selection.** `hud.gd:_build_slab` (`:278`): cells, chips, wells, Unload; `CancelBuild`, `ResumeHint` outside the grid. Red: builder + tank shows `A`, `S`, no `Q`; transport + infantry `F`; Tunnel Hub `F`; Militia quantity; `test_match_starts_with_builder_selected` (offline, rematch, online: `selected_ids == [start unit id]` after the first view; start unit removed first: nothing selected; no voice; camera unchanged). Rewrite `test_slab_*`, `test_build_buttons_*`; keep `test_rebuild_count`; HN2 (`test_hud.gd:106-109`), TH5 (`:275`), Bs3 (`test_base_scene.gd:208-221`), `:401`, `test_skirmish_scene.gd:758` stay green. Port `BuildMenu` readers: `test_skirmish_scene.gd:259,277,759,780,960,1295,1944,2424,2441`, `_menu_texts`, `test_build_menu_from_capabilities`, `_wraps_eleven`, `_quantity_label`, `game/scripts/lab/hud_capture.gd:177-197` (run once headless). Expected red: those, HN2 build-button checks, tests assuming an empty start or a first Esc opening the menu (list them at task start, default suites plus `/test_online_scene.gd`).
- **T6 Esc order.** One case per layer via `OverlayTests._key` (`test_hud.gd:687`), including start: first Esc deselects, second opens the menu.
- **T7 Blocked cells.** Red per reason and precedence, producer prerequisite, two-cause look, coin only when credits are the sole blocker (position, visibility), click = key, 250 ms open and switch, prerequisite hint, two builders, card line order; sounds (`test_order_voice.gd`, `test_announcer.gd`): two credit-blocked presses 10 ticks apart give two clicks, two lines, one voice; a press 901 ticks after the voice, voice again.
- **T8 Queue tiles.** Red: `test_queue_tiles_merge_adjacent_waiting`, `test_queue_tile_click_cancels_newest_of_run`, `test_queue_tiles_keep_entry_ids` (a unit completes between hover and click: stored entry or a sim refusal, never another), `test_queue_tiles_hold_under_pointer`, `test_queue_more_counts_hidden` (no click, tooltip), `test_producing_cell_bar`, `test_queue_full_at_9`, `test_right_click_cell_cancels_newest_of_kind`, `test_factory_panel_fixed_152` (0, 1, 5, 9 queued). Expected red, rewritten: `test_slab_queue_cap`, `test_slab_queue_toggle_holds_still`, SL7/SL8, `test_queue_label` (`test_base_scene.gd:411`), `test_skirmish_scene.gd:759`.
- **T8b F38** (after T5, T8). Step 1, a benchmark-only commit: `game/scripts/debug/movement_benchmark.gd:465` gives `hud_select` an `Economy` VBox (as `test_hud.gd` `_economy()`) instead of `setup(null)` (`hud.gd:259-261` skips the card), so the 120 units show their card; BH tests (`p2.3a1-verification.md:63-65`) red first (header plus a card-cell check). Step 2: red `test_unchanged_refresh_keeps_layout` (two refreshes, same state, factory at 9: same tile nodes, order, anchors, no strip resize); `test_rebuild_count` green; no copy in `_count_rebuild` is a review item. `DRAW_CALL_CEILINGS.hud_select` (30, `:17`) exceeded with the card: report it; the owner changes ceilings.
- **T9 LOW POWER, counter lines.** Rewrite `test_forecast_forms` (flip, already low, no forecast). Red `test_counter_lines_match_damage`: every role's words equal the rule's; a deliberately false fixture (Rifleman `Weak against tanks`) through the same check must fail (asserted); Rotary Gun Tank names the ramp; no line in one-unit or enemy panels. `test_definitions_lint` green.
- **T10 Groups, `centre_camera`.** New `game/tests/test_control_groups.gd` in `run_tests.gd` `SUITES`: save, select, double tap centroid, Shift add, exclusive, dead and contained, building-only (unchanged), nothing (clears), Ctrl/Cmd+N not building, placement, save line, reset, rematch; narrowed pan guard, preview re-run.
- **T11 H, Space, allied line.** `test_announcer.gd`: allied hit new line, own the old, cooldown, own defence counts, FRC hole not. H several/none; Space no event, in cooldown, dead target, both hit, focused button never pressed (`HD#36`); `test_skirmish_scene.gd:685` green. Audio: wav, `tools/audio/synth.py:32,262-263`, `test_credits.gd` rows, loudness row (`sound-spike.md:137`), agent-map sound entry.
- **T12 Edge scroll.** Injected pointer and focus: band pans, also over a HUD panel at every edge; no focus, pointer exit, drag box: no pan; placement pans, ghost under the pointer; `H` in placement re-runs the preview; step capped; picture rect at 3440x1440.
- **T13 Controls list.** Fits 1280x720. Verify `test_pause_menu`, `test_graphics_settings`, `/test_playtest_overlay.gd`.
- **T14 Focus card.** `game/data/playtest/focus.json`: from Play, mouse only; time from start to the first building; idle-builder trigger from the first deselect (time to next build, seconds with no card while affordable, observer question); the title-less Back question (fallback `Back · Build`); edge scroll at the Back chip's corner (3-26); watch item cell `×4` against tile `×3`.
- **T2b F33 online, last code task.** `online_driver.gd:119,126,132` only, plus a red online two-job catch-up case (`CATCH_UP_STEPS = 2`, `:10`), both jobs with the preview. Expected flip: `test_ph_preview_on_last_job_of_catch_up` (`test_online_scene.gd:2135`) `previews == 1` → `2`. Verify `/test_online_scene.gd`, `/test_base_scene.gd`, `test_sim_pump`. If night 8 `play-on-after-a-leave` (plan `~/projects/wargrid-wt-playon/docs/superpowers/plans/2026-11-21-play-on-after-a-leave.md`) has merged to `main` by then: `git merge main` into the branch first (full suite on the merged tree), then T2b builds on night 8's catch-up loop and its `test_ph_*` rule. If not: T2b lands as written and night 8 reconciles (its "`test_ph_*` cases green, unchanged" becomes "green; P2.3b's F33 expects two previews").
- **T15 Docs.** Copy this plan into `docs/superpowers/plans/`. Guide `01-big-picture.md:129-130`, `04-the-tick.md:53`, `05`, `07` (preview), `11`, `12-performance-and-platforms.md:37,53` (`hud_select` with the card, F38 row, browser edge scroll), `13` (incl. `hud_capture`), each `Checked against`. `LR` 96, 110 (panel 152), 116 (tiles), 142, 149, 150, 153, 159, 198, 206-209 (site keeps Cancel construction), 240, grid table; DA answers and `DA:1355`'s interim, ended by 3-6; blueprint Controls; STATUS F23/F33/F38; F38 ledger row. `PK:27` sentences: "queue of nine slots, click cancels" → tiles; "a small card with the credits shortfall and the credits and power forecast before a purchase" → cell card, no forecast (3-4), LOW POWER on a flip (3-5); counter line "placed at design" → cell card only (3-12); "key chips that print the keyboard layout's own label ... deferred ... (QWERTY labels stay)" → layout labels as built (3-14), range ring deferred; "Ctrl+1-9 saves" → adds Cmd on macOS; "Design and plan not written" → state. Then `python3 tools/roadmap.py`; `sh tools/check_public.sh`.

## Same-tick interaction cases

No new sim command. One test each, in the task adding the input:
- Produce or cancel while the factory dies: refusal, no crash. Two presses at 8 queued in one frame: both sent, the second refused (`Production queue full`, beep, `simulation.gd:301`). Credits spent elsewhere that tick: sim refusal, voice once within the cooldown. A unit cell pressed the step its prerequisite dies: `Missing completed prerequisite`, beep; next view blocks the cell.
- Cancel in the completing tick: no double refund. Two cancels of one tile, or a tile click and a right-click on the same entry in one frame: one refund, then `Missing production entry` and a beep (`simulation.gd:294-297`).
- Builder dies in the click step (F23); sub-grid `A` while the builder dies: F23 path. Placement click in a two-step frame and an online catch-up (F33). Start builder dies in the first step: nothing selected, no card.
- `F` the step the transport dies or empties: sim refusal (`simulation.gd:267`), beep; `F` twice in a frame: the second refused or empty. `S` in the frame an attack-move click was sent: both in order, the stop wins.
- Grid key with attack move armed: `S` stops and disarms, `F` unloads and disarms (`orders.gd:77,391`), `A` keeps it armed. Ctrl/Cmd + grid key: nothing.
- Recall with a member dead or contained: live, uncontained ids; save with a member dying; recall disarms attack move, is ignored in placement, closes the sub-grid.
- `H`/`Space` in placement or sub-grid: camera moves, state stays, ghost follows. `Space` after the target died: stored position. Own and allied hit in one tick: priority 7 voice, `Space` to own.

## AI rules

None; a task that needs bot code stops and asks.

## HUD headless layout tests

At `BaseScene.HUD_SIZES` (`test_base_scene.gd:12`: 1280x720, 1280x800, 1920x1080 → 1280x720, 3440x1440 → 1720x720): one, many, mixed, transport; builder, two builders, nothing selected with `Select a Bulldozer`, sub-grid, placement; factory 0/1/5/9 queued with `×N` and `+N more`, panel 152; each blocked reason, two-cause cell, cost coin; cell card ready and blocked; refusal line; LOW POWER flip; the 3-24 line beside a driver notice; group save line; Esc menu with Controls. Assert lattice, containment, no overlap, anchoring (`LR`).

## Parallel branches

- **Night 8** (plan only, `3cedb122`): `online_driver.gd` `step` (N8 `:116`, T2b `:119-132`: textual conflict likely), `test_online_scene.gd` `cases()`, `test_sim_pump.gd`, guide `01`, `11`, `13`, `STATUS.md`; the `test_ph_*` rule (T2b). Both keep `PUMP_COUNTS`.
- **P7 part 1 `p7-enemy-bots`** (plan only, `194048e0`): `run_tests.gd:6` `SUITES` is one line, P7 adds `test_bot_rules.gd` and T10 `test_control_groups.gd`: a certain, trivial conflict, keep both. Separate hunks elsewhere (`offline_driver.gd`, `match_screen.gd`, `test_skirmish_scene.gd`, guide, STATUS, DA); README roadmap: rerun `python3 tools/roadmap.py` after each merge, never hand-merge.
- No pin changes; full suite on every merged tree.

## Gate

1. `/ponytail-review` on the branch diff; apply cuts; re-verify.
2. `sh tools/run_checks.sh` and full `sh tools/run_tests.sh` (timeout 600000) with the completion marker, the layout tests at 1280x720, 1280x800, 1920x1080 inside it; branch CI green.
3. `PERF_LABEL="P2.3b" sh tools/run_benchmark.sh` alone, host load noted; ledger row; budgets unchanged.
4. Rendered batch (windows: ask first, one batch with the owner's visible checks): `sh tools/run_game.sh res://scenes/movement_benchmark.tscn` (four layouts), then the HUD row with the card and 120 selected (after T8b step 1) at 1280x720 (`-- --hud`) and 2560x1080 (`--resolution 2560x1080 ... -- --hud --expect-window=2560x1080`, `performance.md:144`); `python3 tools/perf_record.py <log> --label "P2.3b"`, `python3 tools/perf_chart.py`.
5. F38 before/after in that batch: before = branch base plus the T8b step 1 commit (scratch worktree, cherry-pick), after = tip. F38 closes only if the tip's 2560x1080 HUD p95 ≤ 3.04 ms, else reported exceeded, F38 open. The row notes that tile layout work is covered by `test_unchanged_refresh_keeps_layout`.
6. Gate reviews: Grok 4.7 high plus an Opus high whole-branch pass (Opus alone if Grok is missing or fails; recipe in private `grok-handoff.md`), and the player-experience reviewer on the diff and T0's pictures.
7. One owner check: visible batch (card states, start selection, Esc layers, tiles, edge scroll, `H`, `Space`, allied line), the web pass (3-29), the playtest (T14 with an RTS-naive friend, timed Ashfall test). T10 is done only once Ctrl/Cmd+1 passes on the web or `Shift+Ctrl+N` is in.
8. On owner approval: tag `p2-3b-build-from-the-dock-tip`, `git merge --squash`, push the tag with `main`.

## Final review applied

From `p23b-final-review.md` (private) and the final player-experience pass, each checked against `main` `18a46ca6`. Applied: P1-1 (with the owner's `Select a Bulldozer` and PX 1), P1-2 (Cancel construction kept outside the grid), P1-3 (T8b step 1, gate 4-5), P2-1 to P2-10 (P2-4 as decided, 900 ticks; P2-10 with T2b last as the coordinator set), P3-1 to P3-12 (P3-9 as recommended), PX 1, 3, 4, 5, 6, 7, 8, 10 (PX 7 reconciled with `DA:1477`: counter line 2 when ready, 3 under a reason). Rejected: none; every finding held.
