# P7 part 1 verification: enemy bot rules

Plan: [P7 part 1](../superpowers/plans/2026-11-21-p7-enemy-bots.md). Raw probe rows are private (`~/projects/wargrid-private/docs/better-bots/probe/p7/`).

```text
Resume record (updated 2026-11-21 12:57)
Branch / base commit / working-tree state: p7-enemy-bots / 6bd58ff3 + plan 194048e0 / this file new
Last green task / next incomplete task: T1-1 (probe, no code) / T1-2
Changed paths since last commit: docs/reference/p7-verification.md
Last command / cases / checks / failures / exit / marker: baseline suite on 194048e0: CASES 1250 CHECKS 152754 FAILURES 0 / exit 0 / TESTS PASSED; T1-1 probe 1,350 matches, 0 errors
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: plan approved (user, 2026-11-21); (a) local commit per green task, (b) one branch push at the gate
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: T1-2
```

## Red ledger

| Task | `FAIL:` names left red | On the re-pin list |
|---|---|---|

## Evidence

### T1-1 kill check A

Ran on `p7-enemy-bots` at `194048e0` (bot code = `main` `6bd58ff3`, `skirmish.gd` unchanged). Variant `collectors1` built by `make_variant.py` into a scratch file in the private probe folder; no source in this worktree changed. Probe `p7_probe.gd`, headless, 1,350 matches (stock `ctrl=human` 522, stock `ctrl=ai` Broken Crown 225 beside the old `BL` rows, `collectors1` `ctrl=human` 603), all rows parsed, 0 errors. Raw rows, job files, `t11.py`, `pooled.py`: `~/projects/wargrid-private/docs/better-bots/probe/p7/`. Matrix: `BL` sets (Dry Wells 1,2; Ashfall 2,6; Ashfall 3,7; 9 faction pairs; bot vs bot 5 seeds, idle seat both slots 3 seeds); Broken Crown 2v2 teams [1,1,2,2], faction per team, starts 1,2,3,4 and 3,4,1,2 ("slot orders"), 5 seeds; Broken Crown 1v1 idle (idle start 1, bot on 2, 3, 4; 5 seeds); Broken Crown 1v2 idle (idle start 1, two bots on 2,3 / 2,4 / 3,4, same faction; 3 seeds). The 1v2 rows and `collectors1` Broken Crown rows have no stock 1v2 counterpart (not asked).

**Minute 6 (tick 10,800), fighting units per slot, median (mean), seat rows still in a running match:**

| Slot | stock `ai` (`BL`) | stock `human` | `collectors1` `human` |
|---|---|---|---|
| Dry Wells and both Ashfall sets, seat 1 | 24 (24.2) | 25 (24.4) | 27 (25.5) |
| same, seat 2 | 31 (32.0) | 34.5 (33.2) | 38 (34.0) |
| Broken Crown 2v2, team 1 (seats 1,2) | 15 (15.4) | 14 (16.2) | 16 (16.9) |
| Broken Crown 2v2, team 2 (seats 3,4) | 15 (14.4) | 16 (16.8) | 15 (15.7) |

Medians rise in both 1v1 slots (the stop condition does not fire), means by only 0.8 to 1.1 units against stock `human`. Broken Crown is mixed per seat (seat 3 of 1,2,3,4: 6 to 9; seat 4 of 3,4,1,2: 23 to 15). Per map and seat in `t11.py` output.

**Night 12 columns** (`docs/packages.md:61`; `collectors1` against stock `human`; against stock `ai` in brackets): column 1, seats that never damage an enemy building under stock and do under `collectors1`: 61 of 190 (63 of 190); column 2, matches that end under stock and still end: 141 of 179 (123 of 150; lost 38 / 27). Both fail, as expected for BR1 alone; hard only at T1-5 and T1-8. By map (stock ended to `collectors1` ended): Dry Wells 38 to 36, Ashfall 2,6 30 to 21, Ashfall 3,7 33 to 29, Broken Crown 2v2 39 to 25 and 39 to 30; 46 seats that damaged a building under stock do not under `collectors1`.

**Stock Broken Crown rows (`ctrl=human`; `ai` idle rows equal within 2 ticks, 2v2 differs):** 2v2 ended 78 of 90 (starts 1,2,3,4 39 of 45, 3,4,1,2 39 of 45; `ai` 61 of 90). Idle seat defeat tick, 1v1, min / median / max: bot on start 2 8,033 / 8,170 / 8,220; start 3 9,558 / 9,738 / 10,031; start 4 7,887 / 7,966 / 8,046. **Broken Crown stock idle defeat minimum: 7,887** (the 7-13 floor for that map). First idle building lost: min 5,964.

**Idle defeat floor under `collectors1`** (min tick; stock 1v1 min in brackets): Dry Wells 7,428 (7,414), Ashfall 2,6 10,701 (10,698), Ashfall 3,7 10,314 (10,314), Broken Crown 1v1 7,775 (7,887), Broken Crown 1v2 7,365 (7,887). BR1 alone already falls below the floor on Broken Crown; BR2 and BR3 must hold it back (T1-5).

Not run here: the 150 s rule, wave-level rows (the variant's waves are not logged; stock `BL` waves unchanged).

