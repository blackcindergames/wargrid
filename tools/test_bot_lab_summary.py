import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import bot_lab_summary as lab


def wave(index: int, veh: int, total: int = 1000, up: bool = True, far: float = 10.0) -> dict:
    spread = {"n": 5, "farthest": far, "slowest": far / 2, "slow_units": [["usa_tank", 1.0]]}
    return {"wave": index, "value": total, "veh_value": veh, "factory_up": up, "launch": spread, "contact": spread}


def seat(faction: str, waves: list[dict], lost: int = 0, back: int = 0, credits: int = 300) -> dict:
    return {
        "faction": faction,
        "waves": waves,
        "factory_lost": [1] * lost,
        "factory_back": [1] * back,
        "credits_mean_after_wave0": credits,
    }


def match(map_: str, starts: str, seats: list[dict], idle_tick: int | None = None, **extra: object) -> dict:
    row = {"map": map_, "starts": starts, "teams": [1, 2], "ended": True, "idle": [], "tower": None, "seats": seats}
    if idle_tick is not None:
        row["idle"] = [{"seat": 1, "faction": "usa", "team": 1, "defeat_tick": idle_tick}]
    return row | extra


class SummaryTests(unittest.TestCase):
    def test_idle_floor_passes_at_the_floor_and_fails_below_it(self) -> None:
        at = [match("dry_wells", "1,2", [], idle_tick=7414)]
        below = [match("dry_wells", "1,2", [], idle_tick=7413)]
        self.assertTrue(lab.summarise(at, [])[1])
        text, ok = lab.summarise(below, [])
        self.assertFalse(ok)
        self.assertIn("Dry Wells: 7413 / 7413 floor 7414 open 0 of 1 FAIL", text)

    def test_an_idle_seat_that_was_never_defeated_fails_the_floor(self) -> None:
        text, ok = lab.summarise([match("ashfall", "2,6", [], idle_tick=-1)], [])
        self.assertFalse(ok)
        self.assertIn("Ashfall 2,6: - / - floor 10698 open 1 of 1 FAIL", text)

    def test_broken_crown_groups_by_seat_count(self) -> None:
        one_v_two = match("broken_crown", "1,2,3", [], idle_tick=7413, teams=[1, 2, 2])
        self.assertEqual(lab.group_of(one_v_two), "Broken Crown 1v2")
        self.assertEqual(lab.group_of(match("broken_crown", "1,2", [])), "Broken Crown 1v1")

    def test_vehicle_waves_split_by_factory_standing(self) -> None:
        waves = [wave(0, 0), wave(1, 0, up=True), wave(2, 0, up=False), wave(3, 500)]
        text, _ = lab.summarise([match("dry_wells", "1,2", [seat("usa", waves)])], [])
        self.assertIn("  usa: 1 / 1 of 3", text)
        self.assertIn("  usa: 0 / 0 / 0 / 50", text.replace("-", "0"))

    def test_factories_and_credits_and_tower(self) -> None:
        row = match("dry_wells", "1,2", [seat("china", [wave(0, 0)], lost=2, back=1, credits=200)])
        row["idle"] = [{"seat": 2, "faction": "china", "team": 2, "defeat_tick": 9000}]
        row["tower"] = {"seat": 2, "died_tick": 7000, "shots": 10}
        text, _ = lab.summarise([row], [])
        self.assertIn("  china: 2 / 1 / 1 of 1 seats", text)
        self.assertIn("  china: [7000]", text)
        self.assertIn("  china: 200", text)

    def test_spread_median_and_p90(self) -> None:
        waves = [wave(1, 0, far=float(v)) for v in range(1, 11)]
        text, _ = lab.summarise([match("dry_wells", "1,2", [seat("usa", waves)])], [])
        self.assertIn("usa: launch 5.5 / 9.0 | 2.8 / 4.5   contact 5.5 / 9.0 | 2.8 / 4.5", text)

    def test_not_ended_bot_matches_are_listed_and_failed_jobs_fail(self) -> None:
        stuck = match("dry_wells", "1,2", [], ended=False, job="bvb-stuck")
        text, ok = lab.summarise([stuck], ["tower-broken"])
        self.assertFalse(ok)
        self.assertIn("0 ended, 1 not ended by the cap", text)
        self.assertIn("not ended: bvb-stuck", text)
        self.assertIn("failed: tower-broken", text)

    def test_load_rows_reads_rows_and_flags_failed_jobs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            (folder / "good.exit").write_text("exit=0 seconds=3 good\n")
            (folder / "good.jsonl").write_text("BOTLAB " + json.dumps({"map": "dry_wells"}) + "\n")
            (folder / "bad.exit").write_text("exit=1 seconds=0 bad\n")
            (folder / "bad.jsonl").write_text("")
            (folder / "silent.exit").write_text("exit=0 seconds=0 silent\n")
            (folder / "silent.jsonl").write_text("")
            rows, failed = lab.load_rows(folder)
        self.assertEqual([r["job"] for r in rows], ["good"])
        self.assertEqual(failed, ["bad", "silent"])

    def test_load_rows_fails_a_job_with_a_missing_or_broken_row_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            (folder / "crashed.exit").write_text("exit=1 seconds=0 crashed\n")
            (folder / "lost.exit").write_text("exit=0 seconds=0 lost\n")
            (folder / "torn.exit").write_text("exit=0 seconds=0 torn\n")
            (folder / "torn.jsonl").write_text('BOTLAB {"map": \n')
            rows, failed = lab.load_rows(folder)
        self.assertEqual(rows, [])
        self.assertEqual(failed, ["crashed", "lost", "torn"])

    def test_no_rows_fails(self) -> None:
        text, ok = lab.summarise([], [])
        self.assertFalse(ok)
        self.assertIn("BOT LAB 0 matches", text)


if __name__ == "__main__":
    unittest.main()
