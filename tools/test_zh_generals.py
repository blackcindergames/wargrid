import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import zh_generals as zg
import zh_ini

# Invented INI text in Zero Hour's shapes (names made up, values made up); parsed by the real zh_ini parser.
FIXTURE = """PlayerTemplate FactionRed
  Side = Red
  BaseSide = Red
  PlayableSide = Yes
  StartingBuilding = RedHQ
  StartingUnit0 = RedDozer
  PurchaseScienceCommandSetRank1 = RedScienceSet
End
PlayerTemplate FactionRedLaserGeneral
  Side = RedLaser
  BaseSide = Red
  PlayableSide = Yes
  StartingBuilding = Lzr_RedHQ
  StartingUnit0 = Lzr_RedDozer
  ProductionCostChange = RedTank -10%
  PurchaseScienceCommandSetRank1 = Lzr_RedScienceSet
End
PlayerTemplate FactionRedBoss
  Side = Boss
  BaseSide = Red
  PlayableSide = Yes
  StartingBuilding = Boss_RedHQ
End
PlayerTemplate FactionObserver
  Side = Observer
  IsObserver = Yes
  PlayableSide = Yes
  StartingBuilding = RedHQ
End
Object RedHQ
  BuildCost = 2000
  CommandSet = RedHQSet
End
Object RedDozer
  BuildCost = 1000
  CommandSet = RedDozerSet
End
Object RedFactory
  BuildCost = 2000
  CommandSet = RedFactorySet
  Prerequisites
    Object = RedHQ
  End
End
Object RedTank
  BuildCost = 900
  WeaponSet
    Weapon = PRIMARY RedCannon
  End
  Body = ActiveBody ModuleTag_01
    MaxHealth = 480
  End
End
Object RedArtillery
  BuildCost = 1500
End
ObjectReskin Lzr_RedHQ RedHQ
  CommandSet = Lzr_RedHQSet
End
ObjectReskin Lzr_RedDozer RedDozer
  CommandSet = Lzr_RedDozerSet
End
ObjectReskin Lzr_RedFactory RedFactory
  CommandSet = Lzr_RedFactorySet
  Prerequisites
    Object = Lzr_RedHQ
  End
End
Object Lzr_RedTank
  BuildCost = 1100
  WeaponSet
    Weapon = PRIMARY Lzr_RedCannon
  End
  Body = ActiveBody ModuleTag_01
    MaxHealth = 480
  End
  Behavior = LaserUpdate ModuleTag_02
    Speed = 3
  End
End
Object RedLaserTurret
  BuildCost = 1000
End
Weapon RedCannon
  PrimaryDamage = 60
  AttackRange = 150
End
Weapon Lzr_RedCannon
  PrimaryDamage = 70
  AttackRange = 150
End
CommandSet RedHQSet
  1 = Command_BuildRedDozer
  2 = Command_PowerStrike
End
CommandSet Lzr_RedHQSet
  1 = Command_BuildLzrRedDozer
End
CommandSet RedDozerSet
  1 = Command_ConstructRedFactory
End
CommandSet Lzr_RedDozerSet
  1 = Command_ConstructLzrRedFactory
  2 = Command_ConstructRedLaserTurret
End
CommandSet RedFactorySet
  1 = Command_BuildRedTank
  2 = Command_BuildRedArtillery
  3 = Command_UpgradeArmor
End
CommandSet Lzr_RedFactorySet
  1 = Command_BuildLzrRedTank
  3 = Command_UpgradeArmor
End
CommandSet RedScienceSet
  1 = Command_PurchaseStrike
End
CommandSet Lzr_RedScienceSet
  1 = Command_PurchaseLaserStrike
End
CommandButton Command_BuildRedDozer
  Command = UNIT_BUILD
  Object = RedDozer
End
CommandButton Command_BuildLzrRedDozer
  Command = UNIT_BUILD
  Object = Lzr_RedDozer
End
CommandButton Command_PowerStrike
  Command = SPECIAL_POWER
  SpecialPower = SuperweaponStrike
End
CommandButton Command_ConstructRedFactory
  Command = DOZER_CONSTRUCT
  Object = RedFactory
End
CommandButton Command_ConstructLzrRedFactory
  Command = DOZER_CONSTRUCT
  Object = Lzr_RedFactory
End
CommandButton Command_ConstructRedLaserTurret
  Command = DOZER_CONSTRUCT
  Object = RedLaserTurret
End
CommandButton Command_BuildRedTank
  Command = UNIT_BUILD
  Object = RedTank
End
CommandButton Command_BuildRedArtillery
  Command = UNIT_BUILD
  Object = RedArtillery
End
CommandButton Command_BuildLzrRedTank
  Command = UNIT_BUILD
  Object = Lzr_RedTank
End
CommandButton Command_UpgradeArmor
  Command = PLAYER_UPGRADE
  Upgrade = Upgrade_RedArmor
End
CommandButton Command_PurchaseStrike
  Command = PURCHASE_SCIENCE
  Science = SCIENCE_Strike
End
CommandButton Command_PurchaseLaserStrike
  Command = PURCHASE_SCIENCE
  Science = SCIENCE_LaserStrike
End
SpecialPower SuperweaponStrike
  ReloadTime = 240000
  RequiredScience = SCIENCE_Strike
End
Science SCIENCE_Strike
  SciencePurchasePointCost = 1
End
"""


def blocks(text: str = FIXTURE) -> list[zg.Block]:
    return [dict(b) for b in zh_ini.parse_entry("data\\ini\\test.ini", text)]


def general(report: dict) -> dict:
    (only,) = report["generals"]
    return only


class RosterTest(unittest.TestCase):
    def test_base_roster_walks_command_sets(self) -> None:
        faction = zg.build_report(blocks())["factions"]["Red"]
        self.assertEqual(faction["template"], "FactionRed")
        self.assertEqual(faction["objects"], ["RedArtillery", "RedDozer", "RedFactory", "RedHQ", "RedTank"])
        self.assertEqual(faction["upgrades"], ["Upgrade_RedArmor"])
        self.assertEqual(faction["powers"], ["SuperweaponStrike"])
        self.assertEqual(faction["sciences"], ["SCIENCE_Strike"])

    def test_boss_and_observer_left_out_by_default(self) -> None:
        names = [g["template"] for g in zg.build_report(blocks())["generals"]]
        self.assertEqual(names, ["FactionRedLaserGeneral"])

    def test_all_includes_unplayable_templates(self) -> None:
        names = [g["template"] for g in zg.build_report(blocks(), include_all=True)["generals"]]
        self.assertEqual(names, ["FactionRedBoss", "FactionRedLaserGeneral"])


class DiffTest(unittest.TestCase):
    def test_prefix_pairs_added_and_removed(self) -> None:
        g = general(zg.build_report(blocks()))
        self.assertEqual(g["prefix"], "Lzr")
        self.assertEqual(list(g["added"]), ["RedLaserTurret"])
        self.assertEqual(g["added"]["RedLaserTurret"]["reached"], "built by Lzr_RedDozer")
        self.assertEqual(g["removed"], ["RedArtillery"])

    def test_reskin_inherits_and_prefixed_references_compare_equal(self) -> None:
        g = general(zg.build_report(blocks()))
        # Lzr_RedFactory inherits BuildCost 2000 and its prerequisite Lzr_RedHQ strips to RedHQ: no change.
        self.assertIn("Lzr_RedFactory", g["unchanged"])
        self.assertIn("Lzr_RedHQ", g["unchanged"])

    def test_changed_cost_weapon_and_modules(self) -> None:
        delta = general(zg.build_report(blocks()))["changed"]["Lzr_RedTank"]
        self.assertEqual(delta["BuildCost"], ["900", "1100"])
        self.assertEqual(delta["modules_added"], ["LaserUpdate"])
        self.assertEqual(delta["weapon_fields"], {"Lzr_RedCannon": {"PrimaryDamage": ["60", "70"]}})
        self.assertEqual(delta["Weapons"], [["RedCannon"], ["Lzr_RedCannon"]])
        self.assertNotIn("MaxHealth", delta)

    def test_kindof_order_is_not_a_change(self) -> None:
        text = FIXTURE.replace("  BuildCost = 1500\nEnd", "  BuildCost = 1500\n  KindOf = A B\nEnd")
        text = text.replace(
            "Object RedLaserTurret",
            "Object Lzr_RedArtillery\n  BuildCost = 1500\n  KindOf = B A\nEnd\nObject RedLaserTurret",
        )
        text = text.replace(
            "  3 = Command_UpgradeArmor\nEnd\nCommandSet RedScienceSet",
            "  3 = Command_UpgradeArmor\n  4 = Command_BuildLzrRedArtillery\nEnd\nCommandSet RedScienceSet",
        )
        text += "CommandButton Command_BuildLzrRedArtillery\n  Command = UNIT_BUILD\n  Object = Lzr_RedArtillery\nEnd\n"
        g = general(zg.build_report(blocks(text)))
        self.assertIn("Lzr_RedArtillery", g["unchanged"])

    def test_powers_sciences_settings_and_census(self) -> None:
        g = general(zg.build_report(blocks()))
        self.assertEqual(g["powers"], {"added": [], "removed": ["SuperweaponStrike"], "kept": []})
        self.assertEqual(g["sciences"]["added"], ["SCIENCE_LaserStrike"])
        self.assertEqual(g["sciences"]["removed"], ["SCIENCE_Strike"])
        self.assertEqual(g["upgrades"]["kept"], ["Upgrade_RedArmor"])
        self.assertEqual(g["settings"]["ProductionCostChange"], [None, "RedTank -10%"])
        self.assertEqual(g["module_census"]["only_general"], ["LaserUpdate"])

    def test_missing_reference_reported(self) -> None:
        text = FIXTURE.replace("  2 = Command_ConstructRedLaserTurret\n", "  2 = Command_Nowhere\n")
        g = general(zg.build_report(blocks(text)))
        self.assertEqual(g["missing"], ["CommandButton Command_Nowhere"])

    def test_two_unprefixed_templates_is_a_problem(self) -> None:
        text = FIXTURE.replace("StartingBuilding = Lzr_RedHQ", "StartingBuilding = RedHQ")
        report = zg.build_report(blocks(text))
        self.assertEqual(report["generals"], [])
        self.assertEqual(len(report["problems"]), 1)


class MainTest(unittest.TestCase):
    def test_writes_report_files(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            dump = Path(d) / "dump.jsonl"
            dump.write_text("".join(json.dumps(b) + "\n" for b in blocks()), encoding="utf-8")
            out = io.StringIO()
            code = zg.main(["report", "--dump", str(dump), "--out", d], out)
            self.assertEqual(code, 0)
            self.assertIn("ZH_GENERALS factions=1 generals=1 problems=0", out.getvalue())
            text = (Path(d) / "generals.md").read_text(encoding="utf-8")
            self.assertIn("| FactionRedLaserGeneral | FactionRed | Lzr | 1 | 1 |", text)
            self.assertEqual(json.loads((Path(d) / "generals.json").read_text())["generals"][0]["prefix"], "Lzr")

    def test_missing_dump_fails(self) -> None:
        with tempfile.TemporaryDirectory() as d, mock.patch("sys.stderr", io.StringIO()):
            self.assertEqual(zg.main(["report", "--dump", str(Path(d) / "none.jsonl"), "--out", d]), 1)


@unittest.skipUnless(zg.DEFAULT_DUMP.exists(), "needs the local INI dump (python3 tools/zh_ini.py dump)")
class RealDumpTest(unittest.TestCase):
    def test_nine_generals_with_rosters(self) -> None:
        report = zg.build_report(zg.load_dump(zg.DEFAULT_DUMP))
        self.assertEqual(len(report["factions"]), 3, report["problems"])
        self.assertEqual(len(report["generals"]), 9, [g["template"] for g in report["generals"]])
        for g in report["generals"]:
            self.assertTrue(g["prefix"], g["template"])
            self.assertGreater(len(g["unchanged"]) + len(g["changed"]), 10, g["template"])


if __name__ == "__main__":
    unittest.main()
