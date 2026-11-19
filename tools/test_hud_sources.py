import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HUD = ROOT / "game/scripts/match/hud.gd"
# CI runs the suite as an exported binary with compiled scripts, so source scans live here.
FORBIDDEN = ("_screen", "driver", "orders", "_sound", "set_inspected")


class HudSources(unittest.TestCase):
    def test_hud_reads_only_its_input(self) -> None:
        text = HUD.read_text()
        found = [name for name in FORBIDDEN if name in text]
        self.assertFalse(found, f"HN1 hud.gd reaches past its input: {found}")


if __name__ == "__main__":
    unittest.main()
