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


SCAN_EXCLUDED = (
    "game/scripts/simulation/",
    "game/scripts/debug/",
    "game/scripts/lab/",
    "game/scripts/net/headless_client.gd",
)
PUMP_ACCESS = re.compile(r"\.pump\b(?:\s*\.\s*\w+)?|\bpump\s*\.\s*\w+|\bget\(\s*[\"']pump[\"']\s*\)")
PUMP_FILE = "game/scripts/match/sim_pump.gd"
PUMP_COUNTS: dict[str, int] = {
    # +1: _read_failure() reads pump.failure() for the freeze card (P2.3a1 Task 8).
    # +1 each: sim_mode() reads pump.mode() (SB5a Task 2).
    "game/scripts/match/offline_driver.gd": 11,
    "game/scripts/match/online_driver.gd": 10,
}


def scanned_files(root):
    return sorted(
        p for p in (root / "game/scripts").rglob("*.gd") if not p.relative_to(root).as_posix().startswith(SCAN_EXCLUDED)
    )


def pump_accesses(path, text):
    if path == PUMP_FILE:
        return []
    code = "\n".join(strip_comment(line) for line in text.splitlines())
    return [re.sub(r"\s+", "", m) for m in PUMP_ACCESS.findall(code)]


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
        self.assertEqual(live_reads("game/scripts/presentation/sim_pump.gd", "driver.sim.tick()"), [".sim"])
        self.assertEqual(live_reads("game/scripts/match/sim_pump.gd", "driver.sim.tick()"), [])

    def test_screen_reads_no_live_sim(self):
        for path in scanned_files(ROOT):
            found = live_reads(path.relative_to(ROOT).as_posix(), path.read_text())
            self.assertFalse(found, f"{path.name} reads the live simulation: {found}")

    def test_pump_access_flagged(self):
        hud = "game/scripts/match/hud.gd"
        self.assertEqual(pump_accesses(hud, "var t: int = driver.pump.current().tick"), [".pump.current"])
        self.assertEqual(pump_accesses(hud, "var p = driver.pump"), [".pump"])
        self.assertEqual(pump_accesses(hud, "if not pump . post(job): return"), ["pump.post"])
        self.assertEqual(pump_accesses(hud, 'var p = driver.get("pump")'), ['get("pump")'])

    def test_pump_access_ignores_lookalikes(self):
        hud = "game/scripts/match/hud.gd"
        self.assertEqual(pump_accesses(hud, "var n: SimPump.Note = null\nvar c = pump_count"), [])
        self.assertEqual(pump_accesses(hud, "var a = 1  # driver.pump.live()"), [])
        self.assertEqual(pump_accesses(PUMP_FILE, "pump.post(job)"), [])

    def test_pump_access_counts_pinned(self):
        for path in scanned_files(ROOT):
            rel = path.relative_to(ROOT).as_posix()
            found = pump_accesses(rel, path.read_text())
            self.assertEqual(len(found), PUMP_COUNTS.get(rel, 0), f"{rel} touches the pump {len(found)} times: {found}")

    def test_pump_counts_files_exist(self):
        for rel in PUMP_COUNTS:
            self.assertTrue((ROOT / rel).is_file(), f"{rel} is gone: remove it from PUMP_COUNTS")

    def test_scan_covers_scripts(self):
        rels = {p.relative_to(ROOT).as_posix() for p in scanned_files(ROOT)}
        for rel in ("match/match_screen.gd", "playtest/playtest_overlay.gd", "launcher.gd"):
            self.assertIn(f"game/scripts/{rel}", rels)
        for rel in ("simulation/simulation.gd", "net/headless_client.gd"):
            self.assertNotIn(f"game/scripts/{rel}", rels)


if __name__ == "__main__":
    unittest.main()
