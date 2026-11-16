import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DECL = re.compile(r"^\s*(?:static\s+)?(?:var|const|func)\s+(_[a-z0-9_]+)", re.M)
ACCESS = re.compile(r"(?<!self)\.(_[a-z0-9_]+)\b")

ALLOWLIST: frozenset[str] = frozenset(
    [
        "economy_fixture.gd",
        "test_announcer.gd",
        "test_art_lab.gd",
        "test_combat.gd",
        "test_combat_navigation.gd",
        "test_construction.gd",
        "test_containers.gd",
        "test_defences.gd",
        "test_factions.gd",
        "test_groups.gd",
        "test_horde.gd",
        "test_lockstep.gd",
        "test_movement.gd",
        "test_navigation_incremental.gd",
        "test_production.gd",
        "test_ramp.gd",
        "test_rebuild_holes.gd",
        "test_repath.gd",
        "test_salvage.gd",
        "test_scene.gd",
        "test_skirmish.gd",
        "test_skirmish_scene.gd",
        "test_skirmish_waves.gd",
        "test_supply.gd",
        "test_supply_parity.gd",
        "test_teams.gd",
        "test_tunnels.gd",
        "test_view.gd",
        "test_wire.gd",
        "test_world_batch.gd",
    ]
)


LIVE_READ = re.compile(r"\.sim\b|\blive\s*\(\s*\)|\bget\(\s*[\"']sim[\"']\s*\)|\.simulation\s*\(\s*\)")
LIVE_ALLOWLIST: frozenset[str] = frozenset(
    [
        "game/scripts/match/sim_pump.gd",
        "game/scripts/match/online_driver.gd",  # until SB4 moves lockstep into jobs
    ]
)


def private_names(root):
    names = set()
    for path in (root / "game/scripts/simulation").rglob("*.gd"):
        names.update(DECL.findall(path.read_text()))
    return names


def hits(text, names):
    code = "\n".join(line.split("#", 1)[0] for line in text.splitlines())
    return [m for m in ACCESS.findall(code) if m in names]


def test_files(root):
    return sorted((root / "game/tests").rglob("*.gd"))


def strip_comment(line):
    quote = ""
    escaped = False
    for i, char in enumerate(line):
        if escaped:
            escaped = False
        elif quote and char == "\\":
            escaped = True
        elif quote:
            quote = "" if char == quote else quote
        elif char in "\"'":
            quote = char
        elif char == "#":
            return line[:i]
    return line


def live_reads(path, text):
    if path in LIVE_ALLOWLIST:
        return []
    code = "\n".join(strip_comment(line) for line in text.splitlines())
    return LIVE_READ.findall(code)


def screen_files(root):
    return sorted(p for folder in ("match", "presentation") for p in (root / "game/scripts" / folder).rglob("*.gd"))


SCREEN = "game/scripts/match/match_screen.gd"


class SimBoundary(unittest.TestCase):
    def test_flags_private_read(self):
        found = hits("var hp = sim._entities[1].hp", {"_entities"})
        self.assertEqual(found, ["_entities"])

    def test_ignores_own_helper(self):
        self.assertEqual(hits("Replay.new()._world(runner)", {"_entities"}), [])

    def test_ignores_comment(self):
        self.assertEqual(hits("var a = 1  # sim._entities", {"_entities"}), [])

    def test_private_names_found(self):
        names = private_names(ROOT)
        self.assertLessEqual({"_entities", "_buildings"}, names)

    def test_new_files_clean(self):
        names = private_names(ROOT)
        for path in test_files(ROOT):
            if path.name in ALLOWLIST:
                continue
            found = hits(path.read_text(), names)
            self.assertFalse(found, f"{path.name} reads sim internals: {sorted(set(found))}")

    def test_allowlist_still_needed(self):
        names = private_names(ROOT)
        by_name = {p.name: p for p in test_files(ROOT)}
        for name in sorted(ALLOWLIST):
            self.assertIn(name, by_name, f"{name} is gone: remove it from ALLOWLIST")
            self.assertTrue(
                hits(by_name[name].read_text(), names),
                f"{name} no longer reads sim internals: remove it from ALLOWLIST",
            )

    def test_live_read_flagged(self):
        self.assertEqual(live_reads(SCREEN, "var t: int = driver.sim.tick()"), [".sim"])
        self.assertEqual(live_reads("game/scripts/match/hud.gd", "var s = pump.live().snapshot()"), ["live()"])

    def test_live_read_allowlist(self):
        self.assertEqual(live_reads("game/scripts/match/sim_pump.gd", "var t: int = driver.sim.tick()"), [])
        self.assertEqual(live_reads(SCREEN, "var a = 1  # driver.sim.tick()"), [])
        self.assertEqual(live_reads(SCREEN, "if driver.pauses_sim(): return"), [])

    def test_live_read_spellings(self):
        self.assertEqual(live_reads(SCREEN, "var s = pump.live ( ).tick()"), ["live ( )"])
        self.assertEqual(live_reads(SCREEN, 'var s = driver.get("sim")'), ['get("sim")'])
        self.assertEqual(live_reads(SCREEN, "var s = driver.get( 'sim' )"), ["get( 'sim' )"])
        self.assertEqual(live_reads(SCREEN, "var s = pump.recorder().simulation()"), [".simulation()"])

    def test_live_read_hash_in_string(self):
        self.assertEqual(live_reads(SCREEN, 'var t = "#%d" % driver.sim.tick()'), [".sim"])
        self.assertEqual(live_reads(SCREEN, "var t = '\\'#' + driver.sim.name  # driver.sim"), [".sim"])

    def test_live_allowlist_is_exact_path(self):
        self.assertEqual(live_reads("game/scripts/presentation/online_driver.gd", "driver.sim.tick()"), [".sim"])
        self.assertEqual(live_reads("game/scripts/match/online_driver.gd", "driver.sim.tick()"), [])

    def test_screen_reads_no_live_sim(self):
        for path in screen_files(ROOT):
            found = live_reads(path.relative_to(ROOT).as_posix(), path.read_text())
            self.assertFalse(found, f"{path.name} reads the live simulation: {found}")


if __name__ == "__main__":
    unittest.main()
