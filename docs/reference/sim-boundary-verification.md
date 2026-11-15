# Sim boundary SB1-SB2 verification

Plan: [sim boundary SB1-SB2](../superpowers/plans/2026-11-15-sim-boundary-sb1-sb2.md). Resume record below is overwritten at each checkpoint; evidence rows are append-only.

```text
Resume record (updated 2026-11-15 21:00)
Branch / base commit / working-tree state: sim-boundary-sb1-sb2 / f838f793a0cfccfbbba7ce70d3a59fcaddeb3f2a (P2.2 merged, ee2f353 is an ancestor) / Task 2 uncommitted
Last green task / next incomplete task: Task 1 (base evidence) green; Task 2 green, uncommitted / Task 3
Changed paths since last commit: game/scripts/match/offline_driver.gd, game/tests/test_base_scene.gd, game/tests/test_skirmish_scene.gd, docs/reference/sim-boundary-verification.md (build/sb/ is untracked output)
Last command / cases / checks / failures / exit / marker: base suite, 955 cases, 146367 checks, 0 failures, exit 0, TESTS PASSED 146367; netplay match exit 0, NETPLAY PASSED match; team match exit 0, TEAM MATCH won tick=38786 winner=2 units_peak=268
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: local commits per task pre-authorized (night run); no rendered benchmark rerun, world_view.gd is not touched; gate 1 and gate 2 reviews pending
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: Task 3 (commit Task 2 first). Plan path:line are 32748c8; use this file's Line map.
```

## Evidence

| Date | Command | Result | Tree |
|---|---|---|---|
| 2026-11-15 | `sh tools/run_tests.sh` with the four `WARGRID_*_REPLAY_TRACE` variables into `build/sb/base/` | exit 0, CASES 955 CHECKS 146367 FAILURES 0, `TESTS PASSED 146367` | base f838f79, clean |
| 2026-11-15 | `NETPLAY_OUT=build/sb/base/netplay sh tools/run_netplay.sh match` | exit 0, `NETPLAY PASSED match 10.6 s`; `s1.tsv` kept | base f838f79, clean |
| 2026-11-15 | `sh tools/run_team_match.sh` | exit 0, `TEAM MATCH won tick=38786 winner=2 units_peak=268` (pin at `tools/run_team_match.sh:13`), `TEAM PATHS PASS` | base f838f79, clean |
| 2026-11-15 | `WARGRID_TEST_ONLY=sb1_` (red first: `RB3 ... got 3`, exit 1; then green) | exit 0, CASES 1 CHECKS 2 FAILURES 0 | Task 2, uncommitted |
| 2026-11-15 | `WARGRID_TEST_ONLY=scene` (red first: 11 failures, "Sequence must increase") | exit 0, CASES 114 CHECKS 3536 FAILURES 0, `TESTS PASSED 3536` | Task 2, uncommitted |
| 2026-11-15 | `=order_voice` / `=playtest` / `=announcer` | exit 0 each: 14/97, 44/930, 21/68 cases/checks | Task 2, uncommitted |
| 2026-11-15 | `run_lint.sh`, `run_warnings.sh`, `test_sim_boundary.py` | exit 0, 0, 0 | Task 2, uncommitted |
| 2026-11-15 | Task 2 review merge rerun: `sb1_`, `scene`, `order_voice`, `playtest`, `announcer`, `run_lint.sh`, `run_warnings.sh` (Sonnet and Codex reviews: no critical or important findings) | exit 0 each; 2/3536/97/930/68 checks, 0 failures | Task 2, uncommitted |

`sync_sequence(main)` added after direct sends in: `test_production_ui` (Bs3, after the builds), `test_base_scene.gd` CancelBuild case (after the foundation send), M3 case (after the factory build), `test_rally_input_and_marker` (R1), `test_hud_strings_use_display_names` (N1), `test_frc_laborer_right_click_pile` (K13). Expected values unchanged.

Base traces: `build/sb/base/{replay,economy,combat,team}.tsv`, `build/sb/base/netplay/s1.tsv` (untracked). No rendered benchmark rerun: drawing code (`world_view.gd`) is not touched.

## Line map

Plan lines are `main` 32748c8 (before P2.2); right column is the base f838f79. A function name is the stable anchor. Files not listed (`orders.gd`, `offline_driver.gd` lines before :60, `simulation.gd`, `presentation_clock.gd`, `sound_director.gd`, all docs except `11-multiplayer.md`) are unchanged since 32748c8 and keep the plan's numbers.

| Plan cite | Base location |
|---|---|
| `match_screen.gd` `playtest_context` :131 | :135 |
| `match_screen.gd` `_step_simulation` :141-146 (refusal text :146) | `_step_simulation` :147; the `"Rejected: "` text is at :152 |
| `match_screen.gd` `_escape_pending` :152 | :157 (`driver.sim.match_over()` :158) |
| `match_screen.gd` `_show` :248-259 | :265 (`driver.sim.view_state()` :257 in `_refresh` :256) |
| `match_screen.gd` `_show_hint` :263 | :278 (`driver.sim.tick()` :280) |
| `match_screen.gd` `_submit` :265-272 | :282 |
| `match_screen.gd` other `driver.sim` readers | :123, :127, :137, :144, :194, :202, :204, :207, :257, :298, :299 (the lines cited in the plan shift by 0-16; use `rg -n 'driver\.sim' game/scripts/match`) |
| `hud.gd` `_result_text` / :163 | `_result_text` :155-158; `team_of` read at :158 |
| `hud.gd` `_refresh_hud` :40-47 | :38 (the `Result` label and `Restart` button are gone; `ResultPanel` replaces them) |
| `hud.gd` `_economy_hud` :50-54 | :46 |
| `hud.gd` `_unit_record` | :125 |
| `offline_driver.gd` `submit` :40-50, comment :26 | unchanged (:40, :26); `step` :31 |
| `online_driver.gd` `step` :52-66 | :77 |
| `online_driver.gd` `_new_rejections` :71-77 | :109 |
| `online_driver.gd` `submit` | :117 |
| `online_driver.gd` `create` | :53-61 |
| `orders.gd` all cites (:31, :151, :232-238, :247, :259-261, :283, :291-301, :314-322, :332, :339, :359-364, `_refresh()` at :108, 157, 169, 224, 227, 267, 273, 279, 300, 310, 327, 343) | unchanged: `rg -n 'driver\.sim' game/scripts/match/orders.gd` and `rg -n '_refresh\(\)' game/scripts/match/orders.gd` list the same lines; `_matching_ids` :229, `_placement_input` :125, `_clear_placement` :275, `_update_preview` :281, `reset` :53 |

Findings that change later tasks:

- `_result_text` is still in `hud.gd` (:155) and still reads `_screen.driver.sim.team_of(local_player)`; `match_screen.gd:145` (session record) also calls `hud._result_text(state.match)`, which stays a caller with its own `state`.
- `ResultPanel` (`game/scripts/match/result_panel.gd`) reads no `driver.sim`. `hud.gd:70` hands it `driver.rematch_line()` and `driver.can_play_again()`, which are driver calls, not simulation reads. No new reader joins Task 3's list.
- Online driver seat field: `_seat` (`online_driver.gd:28`), set at :36; also `_phase`/`take_rematch` (:144) exist.
- `OnlineDriver.create` reset list (:53-61): `_map_path`, `_starts`, `_seed`, `_finished = false`, `_friend_again = false`, `_rejections_seen = 0`, `_credit = 0`, then a new `sim`.
- N3 layout check after P2.2 (`test_online_scene.gd:77-78`): the economy-below-status check stays at :77; the second line is now `not main.get_node("HUD/ResultPanel").visible` (:78), so `HUD/Restart` is gone.
- P2.2 rematch fixture: `test_rematch_builds_new_match` (`test_online_scene.gd:377`).

Test map by check label (plan line to base line):

| Label | Base location |
|---|---|
| K4 team line (plan `test_skirmish_scene.gd:135-136`) | `test_skirmish_scene.gd:141-142` (`_players[main.local_player].team = 7`, then `_result_text` check) in `test_match_hud_and_restart` :125 |
| K13 (plan :579) | `test_skirmish_scene.gd:769-787` (`Fixture.send` build for the laborer :769, gather check :776) |
| RF2 fixture (plan :601-605) | `test_one_snapshot_per_refresh`, `test_skirmish_scene.gd:791-795` |
| RF8 (plan `test_base_scene.gd:307-318`) | `test_rejection_survives_two_steps`, `test_base_scene.gd:307-319` (label at :318) |
| Bs2, Bs5, Bs6 | `test_base_scene.gd` :80-104, :206-217, :229-234 |
| OV8 | `test_order_voice.gd:152-158` |
| AN20 | `test_announcer.gd:295-297` |
| PO6, PO9 | `test_playtest_overlay.gd:212-239`, `:354-383` |
| H5 (online rejection) | `test_online_scene.gd:679` |
| IC1 / OD1 | `test_skirmish_scene.gd:936-1013` / `:1028` |
| IC2 | `test_online_scene.gd:1245-1300` |
| N3 | `test_online_scene.gd:77-78` (the `test_navigation.gd` and `test_horde.gd` hits are unrelated labels) |
| RF5 | `test_base_scene.gd` just above `test_rejection_survives_two_steps` |
| `sync_sequence` | not yet present (Task 2 adds it to `test_base_scene.gd`) |

Task 7 doc lines (no doc changed since 32748c8 except `11-multiplayer.md`, which P2.2 grew by 55 lines): `01-big-picture.md` :23, :37, :50, :100, :114, footer :135; `04-the-tick.md` :61, :66, footer :180; `05-presentation.md` :43, :157, :158, :159, footer :229; `07-economy.md` :108; `sim-interface.md` :45, :57 all hold the text the plan cites. `11-multiplayer.md`: the plan's "footer :221" is stale; the footer is at :248 and ":221" is now the `## Where in the code` heading. Re-locate the `online_driver.gd` line with `rg -n 'online_driver' docs/guide/11-multiplayer.md` in Task 7.
