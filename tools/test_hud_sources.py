import re
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


ORDERS = ROOT / "game/scripts/match/orders.gd"
HUD_MODEL = ROOT / "game/scripts/match/hud_model.gd"
ORDER_KEY = re.compile(r"\bKEY_[ASEU]\b|\bKEY_F\b")


def hard_coded_keys(text: str) -> list[str]:
    return ORDER_KEY.findall(text)


def guarded_label_call(text: str) -> bool:
    lines = [line for line in text.splitlines() if "keyboard_get_label_from_physical" in line]
    return bool(lines) and all("if " in line and "keyboard_get_layout_count()" in line for line in lines)


class OrderKeys(unittest.TestCase):
    def test_orders_keys_from_the_table(self) -> None:
        found = hard_coded_keys(ORDERS.read_text())
        self.assertFalse(found, f"KL2 orders.gd names order keys instead of HudModel.ORDER_KEYS: {found}")
        model = HUD_MODEL.read_text()
        self.assertRegex(
            model, r'ORDER_KEYS\s*:?=\s*\{[^}]*"unload":\s*KEY_F\b', "KL2 ORDER_KEYS binds unload to KEY_F"
        )
        self.assertTrue(guarded_label_call(model), "KL2 the layout label call sits behind keyboard_get_layout_count()")

    def test_scan_catches_a_planted_key(self) -> None:
        self.assertEqual(hard_coded_keys("if code == KEY_U: pass"), ["KEY_U"])
        self.assertEqual(hard_coded_keys("if code == KEY_F3 or code == KEY_F: pass"), ["KEY_F"])
        self.assertFalse(guarded_label_call("return DisplayServer.keyboard_get_label_from_physical(key)"))


SIMULATION = ROOT / "game/scripts/simulation"
PHASE_ASSIGN = re.compile(r"\.phase\s*=(?!=)")
LITERAL = re.compile(r'"([^"]*)"')
PHASE_FIELD = re.compile(r'"phase"\s*:\s*"(\w+)"')
LABEL_TABLE = re.compile(r"PHASE_LABELS\s*:?=\s*\{([^}]*)\}")
SPEC_PHASES = {
    "flying_source",
    "lead_source",
    "waiting_source",
    "loading",
    "flying_depot",
    "lead_depot",
    "waiting_depot",
    "unloading",
    "seeking",
    "idle",
}


def published_phases(texts) -> set[str]:
    found: set[str] = set()
    for text in texts:
        for line in text.splitlines():
            if PHASE_ASSIGN.search(line):
                found.update(LITERAL.findall(line))
            found.update(PHASE_FIELD.findall(line))
    return found


def label_table(text: str) -> set[str]:
    match = LABEL_TABLE.search(text)
    return set(re.findall(r'"(\w+)":', match.group(1))) if match else set()


class CollectorPhases(unittest.TestCase):
    def test_every_phase_has_a_row(self) -> None:
        phases = published_phases(path.read_text() for path in sorted(SIMULATION.rglob("*.gd")))
        self.assertEqual(phases, SPEC_PHASES, "CL2 the simulation publishes exactly the spec's ten phases")
        self.assertEqual(label_table(HUD_MODEL.read_text()), phases, "CL2 hud_model.gd's label table names every phase")

    def test_scan_catches_an_unknown_phase(self) -> None:
        planted = published_phases(['collection.phase = "loading" if full else "parked"'])
        self.assertEqual(planted, {"loading", "parked"})
        self.assertNotEqual(planted | SPEC_PHASES, SPEC_PHASES)
        self.assertFalse(published_phases(['elif collection.phase == "loading":']))
        self.assertEqual(published_phases(['var c := {"enabled": false, "phase":"docked"}']), {"docked"})


if __name__ == "__main__":
    unittest.main()
