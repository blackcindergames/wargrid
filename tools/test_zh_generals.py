import io
import json
import os
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
Object Lzr_RedHQ
  BuildCost = 2000
  CommandSet = Lzr_RedHQSet
End
Object Lzr_RedDozer
  BuildCost = 1000
  CommandSet = Lzr_RedDozerSet
End
Object Lzr_RedFactory
  BuildCost = 2000
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


def edit(text: str, *pairs: tuple[str, str]) -> str:
    for old, new in pairs:
        assert old in text, old
        text = text.replace(old, new)
    return text


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

    def test_all_includes_the_boss_template(self) -> None:
        names = [g["template"] for g in zg.build_report(blocks(), include_all=True)["generals"]]
        self.assertEqual(names, ["FactionRedBoss", "FactionRedLaserGeneral"])


class DiffTest(unittest.TestCase):
    def test_prefix_pairs_added_and_removed(self) -> None:
        g = general(zg.build_report(blocks()))
        self.assertEqual(g["prefix"], "Lzr")
        self.assertEqual(list(g["added"]), ["RedLaserTurret"])
        self.assertEqual(g["added"]["RedLaserTurret"]["reached"], "built by Lzr_RedDozer")
        self.assertEqual(g["removed"], ["RedArtillery"])

    def test_prefixed_references_compare_equal(self) -> None:
        g = general(zg.build_report(blocks()))
        self.assertIn("Lzr_RedFactory", g["unchanged"])
        self.assertIn("Lzr_RedHQ", g["unchanged"])

    def test_reskin_inherits_its_source_object(self) -> None:
        text = (
            edit(
                FIXTURE,
                (
                    "  3 = Command_UpgradeArmor\nEnd\nCommandSet Lzr_RedFactorySet",
                    "  3 = Command_UpgradeArmor\n  4 = Command_BuildRedScout\nEnd\nCommandSet Lzr_RedFactorySet",
                ),
                (
                    "  3 = Command_UpgradeArmor\nEnd\nCommandSet RedScienceSet",
                    "  3 = Command_UpgradeArmor\n  5 = Command_BuildLzrRedScout\nEnd\nCommandSet RedScienceSet",
                ),
            )
            + "Object RedScout\n  BuildCost = 40\nEnd\nObjectReskin Lzr_RedScout RedScout\n  MaxSimultaneousOfType = 2\nEnd\n"
            "CommandButton Command_BuildRedScout\n  Command = UNIT_BUILD\n  Object = RedScout\nEnd\n"
            "CommandButton Command_BuildLzrRedScout\n  Command = UNIT_BUILD\n  Object = Lzr_RedScout\nEnd\n"
        )
        self.assertIn("Lzr_RedScout", general(zg.build_report(blocks(text)))["unchanged"])

    def test_changed_cost_weapon_and_modules(self) -> None:
        delta = general(zg.build_report(blocks()))["changed"]["Lzr_RedTank"]
        self.assertEqual(delta["BuildCost"], ["900", "1100"])
        self.assertEqual(delta["modules_added"], ["LaserUpdate"])
        self.assertEqual(delta["weapon_fields"], {"Lzr_RedCannon": {"PrimaryDamage": ["60", "70"]}})
        self.assertEqual(delta["Weapons"], [["RedCannon"], ["Lzr_RedCannon"]])
        self.assertNotIn("MaxHealth", delta)

    def test_health_armor_and_vision_changes(self) -> None:
        text = edit(
            FIXTURE,
            (
                "  BuildCost = 900\n",
                "  BuildCost = 900\n  VisionRange = 150\n  ArmorSet\n    Armor = TankArmor\n  End\n",
            ),
            (
                "Object Lzr_RedTank\n  BuildCost = 1100\n",
                "Object Lzr_RedTank\n  BuildCost = 1100\n  VisionRange = 200\n  ArmorSet\n    Armor = Lzr_TankArmor\n  End\n",
            ),
            (
                "    MaxHealth = 480\n  End\n  Behavior = LaserUpdate",
                "    MaxHealth = 500\n  End\n  Behavior = LaserUpdate",
            ),
        )
        delta = general(zg.build_report(blocks(text)))["changed"]["Lzr_RedTank"]
        self.assertEqual(delta["MaxHealth"], ["480", "500"])
        self.assertEqual(delta["VisionRange"], ["150", "200"])
        self.assertEqual(delta["Armor"], [["TankArmor"], ["Lzr_TankArmor"]])

    def test_a_later_max_health_overrides_an_earlier_one(self) -> None:
        text = edit(
            FIXTURE,
            (
                "  Behavior = LaserUpdate",
                "  Body = ActiveBody ModuleTag_09\n    MaxHealth = 500\n  End\n  Behavior = LaserUpdate",
            ),
        )
        delta = general(zg.build_report(blocks(text)))["changed"]["Lzr_RedTank"]
        self.assertEqual(delta["MaxHealth"], ["480", "500"])

    def test_weapon_the_dump_does_not_define_has_no_field_deltas(self) -> None:
        text = edit(FIXTURE, ("Weapon Lzr_RedCannon\n  PrimaryDamage = 70\n  AttackRange = 150\nEnd\n", ""))
        delta = general(zg.build_report(blocks(text)))["changed"]["Lzr_RedTank"]
        self.assertNotIn("weapon_fields", delta)

    def test_every_prefixed_token_of_a_prerequisite_line_is_stripped(self) -> None:
        text = edit(
            FIXTURE,
            ("    Object = RedHQ\n", "    Object = RedHQ RedDozer\n"),
            ("    Object = Lzr_RedHQ\n", "    Object = Lzr_RedHQ Lzr_RedDozer\n"),
        )
        self.assertIn("Lzr_RedFactory", general(zg.build_report(blocks(text)))["unchanged"])

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


class RosterWalkTest(unittest.TestCase):
    def test_last_starting_unit_slot_is_walked(self) -> None:
        text = edit(
            FIXTURE, ("  StartingUnit0 = RedDozer\n", "  StartingUnit0 = RedDozer\n  StartingUnit9 = RedScout\n")
        )
        text += "Object RedScout\n  BuildCost = 5\nEnd\n"
        self.assertIn("RedScout", zg.build_report(blocks(text))["factions"]["Red"]["objects"])

    def test_command_set_alt_and_upgrade_swapped_sets_are_followed(self) -> None:
        text = edit(
            FIXTURE,
            (
                "Object RedArtillery\n  BuildCost = 1500\n",
                "Object RedArtillery\n  BuildCost = 1500\n  Behavior = CommandSetUpgrade ModuleTag_09\n    CommandSet = SwapSet\n    CommandSetAlt = AltSet\n  End\n",
            ),
        ) + (
            "CommandSet AltSet\n  1 = Command_BuildAlt\nEnd\nCommandSet SwapSet\n  1 = Command_BuildSwapped\nEnd\n"
            "CommandButton Command_BuildAlt\n  Command = UNIT_BUILD\n  Object = RedAltUnit\nEnd\n"
            "CommandButton Command_BuildSwapped\n  Command = UNIT_BUILD\n  Object = RedSwappedUnit\nEnd\n"
            "Object RedAltUnit\n  BuildCost = 1\nEnd\nObject RedSwappedUnit\n  BuildCost = 2\nEnd\n"
        )
        objects = zg.build_report(blocks(text))["factions"]["Red"]["objects"]
        self.assertIn("RedAltUnit", objects)
        self.assertIn("RedSwappedUnit", objects)

    def test_special_power_construct_counts_as_a_build_command(self) -> None:
        text = edit(
            FIXTURE,
            (
                "  Command = UNIT_BUILD\n  Object = RedArtillery",
                "  Command = SPECIAL_POWER_CONSTRUCT\n  Object = RedArtillery",
            ),
        )
        self.assertIn("RedArtillery", zg.build_report(blocks(text))["factions"]["Red"]["objects"])

    def test_build_variations_are_walked_and_paired(self) -> None:
        text = edit(
            FIXTURE,
            ("Object RedArtillery\n", "Object RedArtillery\n  BuildVariations = RedArtilleryOne\n"),
        ) + (
            "Object RedArtilleryOne\n  BuildCost = 10\nEnd\nObject Lzr_RedArtillery\n  BuildCost = 1500\n  BuildVariations = Lzr_RedArtilleryOne\nEnd\n"
            "Object Lzr_RedArtilleryOne\n  BuildCost = 12\nEnd\n"
            "CommandSet Lzr_ArtillerySet\n  1 = Command_BuildLzrRedArtillery\nEnd\n"
            "CommandButton Command_BuildLzrRedArtillery\n  Command = UNIT_BUILD\n  Object = Lzr_RedArtillery\nEnd\n"
        )
        text = edit(
            text,
            (
                "  3 = Command_UpgradeArmor\nEnd\nCommandSet RedScienceSet",
                "  3 = Command_UpgradeArmor\n  4 = Command_BuildLzrRedArtillery\nEnd\nCommandSet RedScienceSet",
            ),
        )
        g = general(zg.build_report(blocks(text)))
        self.assertEqual(g["changed"]["Lzr_RedArtilleryOne"]["BuildCost"], ["10", "12"])
        self.assertEqual(g["removed"], [])

    def test_player_level_command_sets_are_walked_for_the_objects_they_build(self) -> None:
        for command in ("SPECIAL_POWER_CONSTRUCT", "SPECIAL_POWER_CONSTRUCT_FROM_SHORTCUT"):
            with self.subTest(command=command):
                text = edit(
                    FIXTURE,
                    (
                        "  PurchaseScienceCommandSetRank1 = RedScienceSet\n",
                        "  SpecialPowerShortcutCommandSet = RedShortcutSet\n",
                    ),
                ) + (
                    f"CommandSet RedShortcutSet\n  1 = Command_BuildPad\nEnd\nCommandButton Command_BuildPad\n  Command = {command}\n  Object = RedPad\nEnd\n"
                    "Object RedPad\n  BuildCost = 1\n  CommandSet = RedPadSet\nEnd\nCommandSet RedPadSet\n  1 = Command_BuildPadChild\nEnd\n"
                    "CommandButton Command_BuildPadChild\n  Command = UNIT_BUILD\n  Object = RedPadChild\nEnd\nObject RedPadChild\n  BuildCost = 2\nEnd\n"
                )
                objects = zg.build_report(blocks(text))["factions"]["Red"]["objects"]
                self.assertIn("RedPad", objects)
                self.assertIn("RedPadChild", objects)

    def test_empty_command_set_slot_is_skipped(self) -> None:
        text = edit(FIXTURE, ("  1 = Command_BuildRedTank\n", "  1 =\n  6 = Command_BuildRedTank\n"))
        faction = zg.build_report(blocks(text))["factions"]["Red"]
        self.assertIn("RedTank", faction["objects"])
        self.assertEqual(faction["missing"], [])

    def test_the_last_top_level_command_set_wins(self) -> None:
        text = edit(
            FIXTURE, ("  CommandSet = RedFactorySet\n", "  CommandSet = RedGhostSet\n  CommandSet = RedFactorySet\n")
        ) + (
            "CommandSet RedGhostSet\n  1 = Command_BuildRedGhost\nEnd\n"
            "CommandButton Command_BuildRedGhost\n  Command = UNIT_BUILD\n  Object = RedGhost\nEnd\nObject RedGhost\n  BuildCost = 1\nEnd\n"
        )
        objects = zg.build_report(blocks(text))["factions"]["Red"]["objects"]
        self.assertIn("RedTank", objects)
        self.assertNotIn("RedGhost", objects)

    def test_stray_equals_sign_in_a_command_set_name_is_skipped(self) -> None:
        text = edit(FIXTURE, ("  CommandSet = RedFactorySet", "  CommandSet = = RedFactorySet"))
        faction = zg.build_report(blocks(text))["factions"]["Red"]
        self.assertEqual(faction["missing"], [])
        self.assertIn("RedTank", faction["objects"])

    def test_missing_object_reported(self) -> None:
        text = edit(FIXTURE, ("  Object = Lzr_RedTank", "  Object = Lzr_Ghost"))
        self.assertIn("Object Lzr_Ghost", general(zg.build_report(blocks(text)))["missing"])

    def test_intrinsic_sciences_join_the_roster_sciences(self) -> None:
        text = edit(
            FIXTURE, ("  ProductionCostChange = RedTank -10%\n", "  IntrinsicSciences = SCIENCE_RED SCIENCE_RED2\n")
        )
        g = general(zg.build_report(blocks(text)))
        self.assertEqual(g["sciences"]["added"], ["SCIENCE_LaserStrike", "SCIENCE_RED", "SCIENCE_RED2"])

    def test_unplayable_template_is_left_out_by_default(self) -> None:
        text = edit(
            FIXTURE,
            (
                "PlayerTemplate FactionRedBoss\n  Side = Boss\n  BaseSide = Red\n  PlayableSide = Yes",
                "PlayerTemplate FactionRedSpare\n  Side = Spare\n  BaseSide = Red\n  PlayableSide = No",
            ),
        )
        self.assertEqual([g["template"] for g in zg.build_report(blocks(text))["generals"]], ["FactionRedLaserGeneral"])
        self.assertIn(
            "FactionRedSpare", [g["template"] for g in zg.build_report(blocks(text), include_all=True)["generals"]]
        )


class DetailTest(unittest.TestCase):
    def test_power_and_science_details_come_from_their_blocks(self) -> None:
        text = (
            edit(
                FIXTURE,
                (
                    "CommandSet Lzr_RedHQSet\n  1 = Command_BuildLzrRedDozer\n",
                    "CommandSet Lzr_RedHQSet\n  1 = Command_BuildLzrRedDozer\n  2 = Command_PowerStrike\n",
                ),
            )
            + "Science SCIENCE_LaserStrike\n  SciencePurchasePointCost = 3\nEnd\n"
        )
        g = general(zg.build_report(blocks(text)))
        self.assertEqual(g["power_details"]["SuperweaponStrike"]["ReloadTime"], "240000")
        self.assertEqual(g["power_details"]["SuperweaponStrike"]["RequiredScience"], "SCIENCE_Strike")
        self.assertEqual(g["science_details"]["SCIENCE_LaserStrike"]["SciencePurchasePointCost"], "3")

    def test_prefixed_power_science_and_upgrade_pair_with_their_base_names(self) -> None:
        text = (
            edit(
                FIXTURE,
                ("  1 = Command_BuildLzrRedDozer\nEnd", "  1 = Command_BuildLzrRedDozer\n  2 = Command_LzrPower\nEnd"),
                (
                    "  3 = Command_UpgradeArmor\nEnd\nCommandSet RedScienceSet",
                    "  3 = Command_LzrArmor\nEnd\nCommandSet RedScienceSet",
                ),
                ("  1 = Command_PurchaseLaserStrike\n", "  1 = Command_PurchaseLzrStrike\n"),
            )
            + "CommandButton Command_LzrPower\n  Command = SPECIAL_POWER\n  SpecialPower = Lzr_SuperweaponStrike\nEnd\n"
            "CommandButton Command_LzrArmor\n  Command = PLAYER_UPGRADE\n  Upgrade = Lzr_Upgrade_RedArmor\nEnd\n"
            "CommandButton Command_PurchaseLzrStrike\n  Command = PURCHASE_SCIENCE\n  Science = Lzr_SCIENCE_Strike\nEnd\n"
        )
        g = general(zg.build_report(blocks(text)))
        for label, kept in (
            ("powers", "Lzr_SuperweaponStrike"),
            ("sciences", "Lzr_SCIENCE_Strike"),
            ("upgrades", "Lzr_Upgrade_RedArmor"),
        ):
            self.assertEqual(g[label], {"added": [], "removed": [], "kept": [kept]}, label)


class DuplicateTest(unittest.TestCase):
    def test_duplicate_in_a_read_kind_is_a_problem(self) -> None:
        text = FIXTURE + "Object RedTank\n  BuildCost = 1\nEnd\n"
        self.assertEqual(len(zg.build_report(blocks(text))["problems"]), 1)

    def test_duplicate_in_an_unread_kind_is_not(self) -> None:
        text = FIXTURE + "Upgrade Upgrade_X\n  BuildCost = 1\nEnd\nUpgrade Upgrade_X\n  BuildCost = 2\nEnd\n"
        self.assertEqual(zg.build_report(blocks(text))["problems"], [])


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

    def test_exit_code_is_1_without_generals_or_with_problems(self) -> None:
        base_only = edit(
            FIXTURE,
            (
                "  PlayableSide = Yes\n  StartingBuilding = Lzr_RedHQ",
                "  PlayableSide = No\n  StartingBuilding = Lzr_RedHQ",
            ),
        )
        for text in (base_only, FIXTURE + "Object RedTank\n  BuildCost = 1\nEnd\n"):
            with tempfile.TemporaryDirectory() as d:
                dump = Path(d) / "dump.jsonl"
                dump.write_text("".join(json.dumps(b) + "\n" for b in blocks(text)), encoding="utf-8")
                self.assertEqual(zg.main(["report", "--dump", str(dump), "--out", d], io.StringIO()), 1)

    def test_missing_dump_fails(self) -> None:
        with tempfile.TemporaryDirectory() as d, mock.patch("sys.stderr", io.StringIO()):
            self.assertEqual(zg.main(["report", "--dump", str(Path(d) / "none.jsonl"), "--out", d]), 1)


# Invented port-sheet fixture: one tank with upgrade modules, weapon sets, a command set swapped in by an upgrade
# (CommandSetUpgrade), an empty module (leaves no record) and an upgrade defined twice.
PORT_FIXTURE = """Upgrade Upgrade_BlueShield
  Type = OBJECT
  BuildCost = 500
  BuildTime = 5.0
End
Upgrade Upgrade_BlueShield
  Type = OBJECT
  BuildCost = 600
  BuildTime = 5.0
End
Upgrade Upgrade_BlueRam
  Type = PLAYER
  BuildCost = 300
  BuildTime = 10.0
End
Object BlueTank
  BuildCost = 900
  CommandSet = BlueTankSet
  WeaponSet
    Conditions = None
    Weapon = PRIMARY BlueCannon
  End
  WeaponSet
    Conditions = PLAYER_UPGRADE
    Weapon = PRIMARY BlueCannonPlus
    Weapon = SECONDARY BlueGun
  End
  ArmorSet
    Conditions = None
    Armor = BlueArmor
  End
  Body = ActiveBody ModuleTag_01
    MaxHealth = 480
  End
  Behavior = ObjectCreationUpgrade ModuleTag_05
    UpgradeObject = OCL_BlueDrone
    TriggeredBy = Upgrade_BlueShield
    ConflictsWith = Upgrade_BlueRam
  End
  Behavior = CommandSetUpgrade ModuleTag_06
    CommandSet = BlueTankRamSet
    TriggeredBy = Upgrade_BlueRam
  End
  Behavior = EmptyUpdate ModuleTag_07
  End
End
Object BlueDrone
  Behavior = SlavedUpdate ModuleTag_01
    GuardMaxRange = 50
  End
  Behavior = UpgradeDie ModuleTag_02
    UpgradeToRemove = Upgrade_BlueShield
  End
End
Object BlueFieldMaker
  Behavior = FireWeaponUpdate ModuleTag_01
    Weapon = BlueFieldWeapon
  End
  Behavior = LifetimeUpdate ModuleTag_02
    MinLifetime = 5000
  End
End
Object BlueJammer
  Behavior = FireWeaponUpdate ModuleTag_01
    Weapon = BlueJamWeapon
  End
End
Object BlueHorde
  Behavior = HordeUpdate ModuleTag_01
    Radius = 10
  End
End
Object Lzr_BlueHorde
  Behavior = HordeUpdate ModuleTag_01
    Radius = 10
  End
End
Object GC_BlueHorde
  Behavior = HordeUpdate ModuleTag_01
    Radius = 10
  End
End
Object Boss_BlueHorde
  Behavior = HordeUpdate ModuleTag_01
    Radius = 10
  End
End
ObjectCreationList OCL_BlueDrone
  CreateObject
    ObjectNames = BlueDrone
    Count = 1
  End
End
Weapon BlueCannon
  PrimaryDamage = 60
  AttackRange = 150
  DamageType = ARMOR_PIERCING
End
Weapon BlueCannonPlus
  PrimaryDamage = 80
  AttackRange = 160
End
Weapon BlueGun
  PrimaryDamage = 5
End
Weapon BlueFieldWeapon
  DamageType = POISON
End
Weapon BlueJamWeapon
  DamageType = SUBDUAL_MISSILE
End
CommandSet BlueTankSet
  1 = Command_BlueShield
  2 = Command_BlueFire
  4 = Command_Missing
End
CommandSet BlueTankRamSet
  1 = Command_BlueFire
End
CommandButton Command_BlueShield
  Command = OBJECT_UPGRADE
  Upgrade = Upgrade_BlueShield
End
CommandButton Command_BlueFire
  Command = FIRE_WEAPON
  WeaponSlot = SECONDARY
End
"""


def port_blocks(text: str = PORT_FIXTURE) -> list[zg.Block]:
    return [dict(b) for b in zh_ini.parse_entry("data\\ini\\object\\blue.ini", text)] + blocks()


def sheet(name: str = "BlueTank", text: str = PORT_FIXTURE) -> dict:
    return zg.port_sheet(zg.Index(port_blocks(text)), name)


def module(sheet_: dict, cls: str) -> dict:
    (found,) = [m for m in sheet_["modules"] if m["class"] == cls]
    return found


class PortSheetTest(unittest.TestCase):
    def test_modules_list_keys_values_and_lines(self) -> None:
        found = module(sheet(), "ObjectCreationUpgrade")
        self.assertEqual(found["tag"], "ModuleTag_05")
        keys = {f["key"]: (f["value"], f["line"]) for f in found["fields"]}
        self.assertEqual(keys["TriggeredBy"], ("Upgrade_BlueShield", 37))
        self.assertEqual(keys["ConflictsWith"][0], "Upgrade_BlueRam")
        self.assertEqual(sheet()["entry"], "blue.ini")

    def test_command_sets_resolve_to_slots_including_upgrade_swaps(self) -> None:
        sets = {s["name"]: s for s in sheet()["command_sets"]}
        self.assertEqual(sets["BlueTankSet"]["via"], "CommandSet")
        self.assertEqual(sets["BlueTankRamSet"]["via"], "Behavior = CommandSetUpgrade ModuleTag_06")
        slot1, slot2 = sets["BlueTankSet"]["slots"]
        self.assertEqual(
            (slot1["slot"], slot1["command"], slot1["upgrade"]), ("1", "OBJECT_UPGRADE", "Upgrade_BlueShield")
        )
        self.assertEqual((slot2["slot"], slot2["command"], slot2["weapon_slot"]), ("2", "FIRE_WEAPON", "SECONDARY"))
        self.assertEqual(sets["BlueTankSet"]["missing"], ["CommandButton Command_Missing"])

    def test_upgrades_carry_roles_and_the_upgrade_block(self) -> None:
        upgrades = {u["name"]: u for u in sheet()["upgrades"]}
        ram = upgrades["Upgrade_BlueRam"]
        self.assertEqual(sorted(r["role"] for r in ram["roles"]), ["ConflictsWith", "TriggeredBy"])
        self.assertEqual((ram["type"], ram["cost"], ram["time"]), ("PLAYER", "300", "10.0"))
        self.assertEqual(sorted(r["role"] for r in upgrades["Upgrade_BlueShield"]["roles"]), ["TriggeredBy", "button"])

    def test_upgrade_reacted_to_by_a_die_module_is_listed(self) -> None:
        roles = [r["role"] for u in sheet("BlueDrone")["upgrades"] for r in u["roles"]]
        self.assertEqual(roles, ["UpgradeToRemove"])

    def test_duplicate_upgrade_lists_both_definitions(self) -> None:
        shield = {u["name"]: u for u in sheet()["upgrades"]}["Upgrade_BlueShield"]
        self.assertTrue(shield["duplicate"])
        self.assertEqual(shield["definitions"], ["blue.ini:1", "blue.ini:6"])
        self.assertTrue(any("Upgrade_BlueShield" in x and "twice" in x for x in sheet()["limits"]))

    def test_empty_module_leaves_no_record_and_the_limit_is_reported(self) -> None:
        self.assertEqual([m["class"] for m in sheet()["modules"]].count("EmptyUpdate"), 0)
        self.assertTrue(any("no fields" in x for x in sheet()["limits"]))

    def test_weapon_and_armor_sets_with_conditions(self) -> None:
        found = sheet()
        self.assertEqual(
            [(w["conditions"], w["slots"]) for w in found["weapon_sets"]],
            [
                ("None", {"PRIMARY": "BlueCannon"}),
                ("PLAYER_UPGRADE", {"PRIMARY": "BlueCannonPlus", "SECONDARY": "BlueGun"}),
            ],
        )
        self.assertEqual([(a["conditions"], a["armor"]) for a in found["armor_sets"]], [("None", "BlueArmor")])

    def test_weapons_show_key_fields(self) -> None:
        weapons = sheet()["weapons"]
        self.assertEqual(sorted(weapons), ["BlueCannon", "BlueCannonPlus", "BlueGun"])
        self.assertEqual(weapons["BlueCannon"]["PrimaryDamage"], "60")
        self.assertEqual(weapons["BlueCannon"]["DamageType"], "ARMOR_PIERCING")
        self.assertEqual(weapons["BlueCannon"]["cite"], "blue.ini:94")

    def test_ocl_resolves_one_level_to_created_objects_and_their_modules(self) -> None:
        (ocl,) = sheet()["ocls"]
        self.assertEqual(ocl["name"], "OCL_BlueDrone")
        (created,) = ocl["creates"]
        self.assertEqual(created["object"], "BlueDrone")
        self.assertEqual(sorted(m["class"] for m in created["modules"]), ["SlavedUpdate", "UpgradeDie"])

    def test_unknown_object_raises(self) -> None:
        with self.assertRaises(KeyError):
            sheet("NoSuchObject")

    def test_markdown_cites_entry_and_line(self) -> None:
        text = zg.port_markdown([sheet()])
        self.assertIn("## BlueTank (blue.ini:", text)
        self.assertIn("TriggeredBy = Upgrade_BlueShield (blue.ini:37)", text)
        self.assertIn("Limits", text)

    def test_roster_sheets_cover_the_base_roster(self) -> None:
        sheets = zg.roster_sheets(zg.Index(port_blocks()), "red")
        self.assertIn("RedTank", [s["object"] for s in sheets])
        self.assertNotIn("Lzr_RedTank", [s["object"] for s in sheets])
        with self.assertRaises(KeyError):
            zg.roster_sheets(zg.Index(port_blocks()), "purple")


class CensusTest(unittest.TestCase):
    def census(self, base_only: bool = False) -> dict:
        return zg.census(zg.Index(port_blocks()), base_only)

    def test_counts_objects_per_mechanic_not_per_module(self) -> None:
        mechanics = self.census()["mechanics"]
        self.assertEqual(mechanics["Ground field (timed FireWeaponUpdate)"], ["BlueFieldMaker"])
        self.assertEqual(mechanics["Missile deflection (FireWeaponUpdate firing SUBDUAL_MISSILE)"], ["BlueJammer"])
        self.assertEqual(mechanics["Drone (SlavedUpdate)"], ["BlueDrone"])
        self.assertEqual(mechanics["Drone host (ObjectCreationUpgrade creating a SlavedUpdate object)"], ["BlueTank"])

    def test_base_only_drops_general_boss_and_campaign_copies(self) -> None:
        horde = "Horde (HordeUpdate)"
        self.assertEqual(
            self.census()["mechanics"][horde], ["BlueHorde", "Boss_BlueHorde", "GC_BlueHorde", "Lzr_BlueHorde"]
        )
        self.assertEqual(self.census(True)["mechanics"][horde], ["BlueHorde"])
        self.assertEqual(self.census(True)["filter"], "base-only")

    def test_lists_duplicate_upgrade_names_with_both_citations(self) -> None:
        self.assertEqual(self.census()["duplicate_upgrades"], {"Upgrade_BlueShield": ["blue.ini:1", "blue.ini:6"]})

    def test_reports_the_empty_module_limit(self) -> None:
        self.assertTrue(any("no fields" in x for x in self.census()["limits"]))


class PortMainTest(unittest.TestCase):
    def run_main(self, argv: list[str], text: str = PORT_FIXTURE) -> tuple[int, str, Path]:
        d = tempfile.mkdtemp()
        dump = Path(d) / "dump.jsonl"
        dump.write_text("".join(json.dumps(b) + "\n" for b in port_blocks(text)), encoding="utf-8")
        out = io.StringIO()
        code = zg.main([*argv, "--dump", str(dump), "--out", d], out)
        return code, out.getvalue(), Path(d)

    def test_port_object_writes_markdown_and_json(self) -> None:
        code, out, d = self.run_main(["port", "BlueTank"])
        self.assertEqual(code, 0)
        self.assertIn("ZH_PORT objects=1", out)
        self.assertEqual(json.loads((d / "port-BlueTank.json").read_text())[0]["object"], "BlueTank")
        self.assertIn("## BlueTank", (d / "port-BlueTank.md").read_text())

    def test_port_roster_writes_every_roster_object(self) -> None:
        code, out, d = self.run_main(["port", "--roster", "red"])
        self.assertEqual(code, 0)
        self.assertIn("ZH_PORT objects=", out)
        names = [s["object"] for s in json.loads((d / "port-roster-red.json").read_text())]
        self.assertIn("RedFactory", names)

    def test_port_fails_on_unknown_object_and_on_no_target(self) -> None:
        with mock.patch("sys.stderr", io.StringIO()):
            self.assertEqual(self.run_main(["port", "NoSuchObject"])[0], 1)
            self.assertEqual(self.run_main(["port"])[0], 1)
            self.assertEqual(self.run_main(["port", "--roster", "purple"])[0], 1)

    def test_census_writes_files_and_honours_base_only(self) -> None:
        code, out, d = self.run_main(["census", "--base-only"])
        self.assertEqual(code, 0)
        self.assertIn("ZH_CENSUS filter=base-only", out)
        data = json.loads((d / "census-base-only.json").read_text())
        self.assertEqual(data["mechanics"]["Horde (HordeUpdate)"], ["BlueHorde"])
        self.assertIn("| Horde (HordeUpdate) | 1 |", (d / "census-base-only.md").read_text())


REAL_DUMP = Path(os.environ.get("ZH_INI_DUMP", zg.DEFAULT_DUMP))


@unittest.skipUnless(REAL_DUMP.exists(), "needs the local INI dump (python3 tools/zh_ini.py dump)")
class RealDumpTest(unittest.TestCase):
    def test_nine_generals_with_rosters(self) -> None:
        report = zg.build_report(zg.load_dump(REAL_DUMP))
        self.assertEqual(report["problems"], [])
        self.assertEqual(len(report["factions"]), 3)
        self.assertEqual(len(report["generals"]), 9, [g["template"] for g in report["generals"]])
        for g in report["generals"]:
            self.assertTrue(g["prefix"], g["template"])
            self.assertGreater(len(g["unchanged"]) + len(g["changed"]), 10, g["template"])
            self.assertEqual(g["missing"], [], g["template"])
        for side, faction in report["factions"].items():
            self.assertEqual(faction["missing"], [], side)

    def real_index(self) -> zg.Index:
        return zg.Index(zg.load_dump(REAL_DUMP))

    def test_overlord_add_ons_conflict_with_each_other(self) -> None:
        found = zg.port_sheet(self.real_index(), "ChinaTankOverlord")
        by_tag = {m["tag"]: {f["key"]: f for f in m["fields"]} for m in found["modules"] if m["tag"] != "-"}
        gattling = by_tag["ModuleTag_07"]
        self.assertEqual(
            (gattling["TriggeredBy"]["value"], gattling["TriggeredBy"]["line"]),
            ("Upgrade_ChinaOverlordGattlingCannon", 348),
        )
        self.assertEqual(
            gattling["ConflictsWith"]["value"], "Upgrade_ChinaOverlordPropagandaTower Upgrade_ChinaOverlordBattleBunker"
        )
        self.assertEqual(by_tag["ModuleTag_13"]["CommandSet"]["line"], 379)
        sets = {s["name"]: s["via"] for s in found["command_sets"]}
        self.assertEqual(sets["ChinaTankOverlordBattleBunkerCommandSet"], "Behavior = CommandSetUpgrade ModuleTag_13")
        upgrade = {u["name"]: u for u in found["upgrades"]}["Upgrade_ChinaOverlordGattlingCannon"]
        self.assertEqual((upgrade["type"], upgrade["cost"], upgrade["time"]), ("OBJECT", "1200", "20.0"))
        ocl = {o["name"]: o for o in found["ocls"]}["OCL_OverlordGattlingCannon"]
        self.assertEqual([c["object"] for c in ocl["creates"]], ["ChinaTankOverlordGattlingCannon"])

    def test_crusader_drones_and_their_upgrade_die(self) -> None:
        found = zg.port_sheet(self.real_index(), "AmericaTankCrusader")
        drones = [m for m in found["modules"] if m["class"] == "ObjectCreationUpgrade"]
        self.assertEqual([m["fields"][0]["line"] for m in drones], [1487, 1492, 1497])
        battle = {o["name"]: o for o in found["ocls"]}["OCL_AmericanBattleDrone"]
        (drone,) = battle["creates"]
        die = [m for m in drone["modules"] if m["class"] == "UpgradeDie"]
        self.assertEqual([f["line"] for f in die[0]["fields"]], [938, 939])

    def test_duplicate_point_defense_upgrade_names_both_citations(self) -> None:
        data = zg.census(self.real_index())
        self.assertEqual(
            data["duplicate_upgrades"]["SupW_Upgrade_AmericaPointDefenseDrone"], ["upgrade.ini:724", "upgrade.ini:796"]
        )

    def test_census_base_only_is_a_subset_of_all(self) -> None:
        everything, base = zg.census(self.real_index()), zg.census(self.real_index(), True)
        for label, names in base["mechanics"].items():
            self.assertTrue(set(names) <= set(everything["mechanics"][label]), label)
        self.assertGreater(
            len(everything["mechanics"]["Horde (HordeUpdate)"]), len(base["mechanics"]["Horde (HordeUpdate)"])
        )
        self.assertFalse(
            any(zg.prefix_of(n) in {"Boss", "GC", "CINE"} for names in base["mechanics"].values() for n in names)
        )


if __name__ == "__main__":
    unittest.main()
