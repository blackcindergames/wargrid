import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CREATE_PATHS = [
    "game/scripts/simulation/skirmish.gd",
    "game/scripts/match/offline_driver.gd",
    "game/scripts/debug/team_match.gd",
    "game/scripts/lab/readme_capture.gd",
]
AI_SEAT = re.compile(r'second_controller:\s*String\s*=\s*"ai"|Skirmish\.create\([^)\n]*"ai"|"controller":\s*"ai"')


class NoProductionCreatePassesAiTest(unittest.TestCase):
    def test_production_matches_run_bots_on_human_unit_rules(self):
        for path in CREATE_PATHS:
            hits = AI_SEAT.findall((ROOT / path).read_text())
            self.assertEqual(hits, [], f'{path} creates a bot seat with controller "ai"')


if __name__ == "__main__":
    unittest.main()
