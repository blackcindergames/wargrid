"""Report how each Zero Hour general differs from its base faction, from the local INI dump.

Local research tool: reads `build/zh_ini/inizh.jsonl` (written by `python3 tools/zh_ini.py dump`) and writes
`build/zh_generals/generals.md` and `generals.json`; the output quotes retail data and is never committed.
Usage:
    python3 tools/zh_generals.py report [--dump PATH] [--out DIR] [--all]

Method (docs/reference/zh-generals-prep.md): each playable PlayerTemplate is a roster root (starting building and
units). The roster is every object reachable through command sets (`DOZER_CONSTRUCT`, `UNIT_BUILD`,
`SPECIAL_POWER_CONSTRUCT` and its shortcut form, including command sets swapped in by upgrades, plus
`BuildVariations`). A general's object pairs with the base faction's object of the same name once the general's
prefix (`AirF_`, `Lazr_`, ...) is stripped.
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, TextIO

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DUMP = ROOT / "build/zh_ini/inizh.jsonl"
DEFAULT_OUT = ROOT / "build/zh_generals"

BUILD_COMMANDS = frozenset(
    {"DOZER_CONSTRUCT", "UNIT_BUILD", "SPECIAL_POWER_CONSTRUCT", "SPECIAL_POWER_CONSTRUCT_FROM_SHORTCUT"}
)
UPGRADE_COMMANDS = frozenset({"PLAYER_UPGRADE", "OBJECT_UPGRADE"})
POWER_COMMANDS = frozenset(
    {
        "SPECIAL_POWER",
        "SPECIAL_POWER_FROM_SHORTCUT",
        "SPECIAL_POWER_CONSTRUCT",
        "SPECIAL_POWER_CONSTRUCT_FROM_SHORTCUT",
    }
)
SCIENCE_SETS = ("PurchaseScienceCommandSetRank1", "PurchaseScienceCommandSetRank3", "PurchaseScienceCommandSetRank8")
TEMPLATE_KEYS = (
    "Side",
    "BaseSide",
    "StartingBuilding",
    "StartingUnit0",
    "StartingUnit1",
    "IntrinsicSciences",
    "IntrinsicSciencePurchasePoints",
    "ProductionCostChange",
    "ProductionTimeChange",
    "ProductionVeterancyLevel",
    *SCIENCE_SETS,
    "SpecialPowerShortcutCommandSet",
)
# Top-level object fields compared between a general's object and its base counterpart.
OBJECT_KEYS = ("BuildCost", "BuildTime", "VisionRange", "ShroudClearingRange", "KindOf", "Buildable", "EditorSorting")
WEAPON_KEYS = (
    "PrimaryDamage",
    "PrimaryDamageRadius",
    "SecondaryDamage",
    "SecondaryDamageRadius",
    "AttackRange",
    "DamageType",
    "DelayBetweenShots",
    "ClipSize",
    "ClipReloadTime",
    "WeaponSpeed",
    "ProjectileObject",
    "RadiusDamageAffects",
)
# Block kinds the report reads by name; a name defined twice in any other kind (MappedImage, Terrain, Upgrade) changes nothing in it.
READ_KINDS = frozenset({"Object", "CommandSet", "CommandButton", "PlayerTemplate", "Weapon", "SpecialPower", "Science"})
PREFIX = re.compile(r"^([A-Za-z]+)_(?=[A-Z])")

Block = dict[str, Any]


class Index:
    """Last definition wins per (kind, name), as a later INI entry replaces an earlier one."""

    def __init__(self, blocks: list[Block]) -> None:
        self.by_kind: dict[str, dict[str, Block]] = defaultdict(dict)
        self.duplicates: list[str] = []
        for block in blocks:
            name = block.get("name")
            if name is None:
                continue
            kind = "Object" if block["kind"] == "ObjectReskin" else block["kind"]
            if name in self.by_kind[kind]:
                self.duplicates.append(f"{kind} {name}")
            self.by_kind[kind][name] = block

    def get(self, kind: str, name: str) -> Block | None:
        return self.by_kind.get(kind, {}).get(name)

    def fields(self, kind: str, name: str, seen: frozenset[str] = frozenset()) -> list[dict[str, Any]]:
        """Fields of a block; an ObjectReskin inherits its source object's fields, overridden by its own."""
        block = self.get(kind, name)
        if block is None:
            return []
        own: list[dict[str, Any]] = block["fields"]
        if block["kind"] != "ObjectReskin" or not block["args"] or name in seen:
            return own
        mine = {(tuple(f["path"]), f["key"]) for f in own}
        inherited = [
            f for f in self.fields(kind, block["args"][0], seen | {name}) if (tuple(f["path"]), f["key"]) not in mine
        ]
        return inherited + own


def load_dump(path: Path) -> list[Block]:
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def top(fields: list[dict[str, Any]], key: str) -> str | None:
    """Last top-level value of a key (a later line overrides an earlier one)."""
    found = None
    for field in fields:
        if not field["path"] and field["key"] == key:
            found = field["value"]
    return found


def values(fields: list[dict[str, Any]], key: str) -> list[str]:
    return [f["value"] for f in fields if f["key"] == key]


def module_classes(fields: list[dict[str, Any]]) -> list[str]:
    """Module class names (`Behavior = StealthUpdate ModuleTag_1` gives `StealthUpdate`) from field paths.

    A module whose block has no fields leaves no trace in the dump, so the list can miss empty modules.
    """
    found: set[str] = set()
    for field in fields:
        for opener in field["path"][:1]:
            head, _, rest = opener.partition("=")
            if rest.strip() and head.strip() in {"Behavior", "Body", "Draw", "ClientUpdate"}:
                found.add(rest.split()[0])
    return sorted(found)


def prefix_of(name: str) -> str:
    match = PREFIX.match(name)
    return match.group(1) if match else ""


def strip_prefix(name: str, prefix: str) -> str:
    return name[len(prefix) + 1 :] if prefix and name.startswith(prefix + "_") else name


class Roster:
    def __init__(self) -> None:
        self.objects: dict[str, str] = {}  # object -> how it was reached ("start", "built by X")
        self.upgrades: set[str] = set()
        self.powers: set[str] = set()
        self.sciences: set[str] = set()
        self.missing: set[str] = set()  # names referenced but not defined


def command_sets_of(index: Index, obj: str) -> list[str]:
    fields = index.fields("Object", obj)
    # The engine parses CommandSetAlt only inside a CommandSetUpgrade module (CommandSetUpgrade.cpp:46).
    in_modules = [f["value"] for f in fields if f["path"] and f["key"] in ("CommandSet", "CommandSetAlt")]
    chosen = [top(fields, "CommandSet"), *in_modules]
    names = [v.replace("=", " ").split() for v in chosen if v]
    return [n[0] for n in names if n]


def buttons(index: Index, command_set: str, roster: Roster) -> list[dict[str, Any]]:
    block = index.get("CommandSet", command_set)
    if block is None:
        roster.missing.add(f"CommandSet {command_set}")
        return []
    found = []
    for field in block["fields"]:
        if field["path"] or not field["key"].isdigit():
            continue
        if not field["value"].split():
            continue
        button = index.get("CommandButton", field["value"].split()[0])
        if button is None:
            roster.missing.add(f"CommandButton {field['value']}")
            continue
        found.append(button)
    return found


def walk_roster(index: Index, template: Block) -> Roster:
    roster = Roster()
    fields = template["fields"]
    queue: list[tuple[str, str]] = []
    for key in ("StartingBuilding", *(f"StartingUnit{i}" for i in range(10))):
        value = top(fields, key)
        if value:
            queue.append((value, "start"))
    for key in (*SCIENCE_SETS, "SpecialPowerShortcutCommandSet"):
        player_set = top(fields, key)
        if player_set:
            for button in buttons(index, player_set, roster):
                _take_button(button, "player", roster, queue)
    seen_sets: set[str] = set()
    while queue:
        obj, reached = queue.pop(0)
        if obj in roster.objects:
            continue
        if index.get("Object", obj) is None:
            roster.missing.add(f"Object {obj}")
            continue
        roster.objects[obj] = reached
        queue.extend(
            (name, f"variant of {obj}") for name in (top(index.fields("Object", obj), "BuildVariations") or "").split()
        )
        for command_set in command_sets_of(index, obj):
            if command_set in seen_sets:
                continue
            seen_sets.add(command_set)
            for button in buttons(index, command_set, roster):
                _take_button(button, obj, roster, queue)
    for science in (top(fields, "IntrinsicSciences") or "").split():
        roster.sciences.add(science)
    return roster


def _take_button(button: Block, owner: str, roster: Roster, queue: list[tuple[str, str]]) -> None:
    command = (top(button["fields"], "Command") or "").strip()
    target = top(button["fields"], "Object")
    if command in BUILD_COMMANDS and target:
        queue.append((target, f"built by {owner}"))
    upgrade = top(button["fields"], "Upgrade")
    if command in UPGRADE_COMMANDS and upgrade:
        roster.upgrades.add(upgrade)
    power = top(button["fields"], "SpecialPower")
    if command in POWER_COMMANDS and power:
        roster.powers.add(power)
    if command == "PURCHASE_SCIENCE":
        roster.sciences.update((top(button["fields"], "Science") or "").split())


def object_summary(index: Index, obj: str, prefix: str) -> dict[str, Any]:
    fields = index.fields("Object", obj)
    summary: dict[str, Any] = {key: top(fields, key) for key in OBJECT_KEYS}
    summary["KindOf"] = " ".join(sorted((summary["KindOf"] or "").split())) or None
    summary["MaxHealth"] = ([f["value"] for f in fields if f["key"] == "MaxHealth"] or [None])[-1]
    # Weapon names keep their prefix: a general's own weapon definition is itself a change.
    summary["Weapons"] = sorted({_weapon_name(v) for v in values(fields, "Weapon")} - {"", "NONE", "None"})
    summary["Armor"] = sorted({v for f in fields if f["key"] == "Armor" for v in [f["value"]]})
    summary["Locomotor"] = sorted({v.split()[-1] for v in values(fields, "Locomotor") if v.split()})
    summary["Prerequisites"] = sorted(
        " ".join(strip_prefix(token, prefix) for token in f["value"].split())
        for f in fields
        if f["path"][:1] == ["Prerequisites"]
    )
    summary["Modules"] = module_classes(fields)
    return summary


def _weapon_name(value: str) -> str:
    parts = value.split()
    return parts[1] if len(parts) > 1 else (parts[0] if parts else "")


def weapon_summary(index: Index, name: str) -> dict[str, str | None]:
    fields = index.fields("Weapon", name)
    return {key: top(fields, key) for key in WEAPON_KEYS}


def diff(a: dict[str, Any], b: dict[str, Any]) -> dict[str, list[Any]]:
    return {key: [a.get(key), b.get(key)] for key in sorted(set(a) | set(b)) if a.get(key) != b.get(key)}


def base_template(group: list[Block]) -> Block | None:
    """The faction a general varies: its starting building carries no general prefix."""
    plain = [t for t in group if not prefix_of(top(t["fields"], "StartingBuilding") or "")]
    return plain[0] if len(plain) == 1 else None


def playable_templates(index: Index, include_all: bool) -> list[Block]:
    found = []
    for block in index.by_kind.get("PlayerTemplate", {}).values():
        fields = block["fields"]
        if (top(fields, "IsObserver") or "").lower() == "yes":
            continue
        # The challenge boss is PlayableSide = Yes; the engine keeps Side "Boss" out of ladders (LadderDefs.cpp:183).
        playable = (top(fields, "PlayableSide") or "").lower() == "yes" and top(fields, "Side") != "Boss"
        if not include_all and not playable:
            continue
        if top(fields, "StartingBuilding"):
            found.append(block)
    return sorted(found, key=lambda b: str(b["name"]))


def compare(index: Index, base: Block, general: Block) -> dict[str, Any]:
    prefix = prefix_of(top(general["fields"], "StartingBuilding") or "")
    base_roster, roster = walk_roster(index, base), walk_roster(index, general)
    base_names = set(base_roster.objects)
    paired: dict[str, str] = {}
    added: list[str] = []
    for obj in sorted(roster.objects):
        counterpart = strip_prefix(obj, prefix)
        if counterpart in base_names:
            paired[obj] = counterpart
        else:
            added.append(obj)
    removed = sorted(base_names - set(paired.values()))
    changed: dict[str, Any] = {}
    for obj, counterpart in sorted(paired.items()):
        mine, theirs = object_summary(index, obj, prefix), object_summary(index, counterpart, "")
        delta: dict[str, Any] = dict(diff(theirs, mine))
        modules = delta.pop("Modules", None)
        if modules:
            delta["modules_added"] = sorted(set(mine["Modules"]) - set(theirs["Modules"]))
            delta["modules_removed"] = sorted(set(theirs["Modules"]) - set(mine["Modules"]))
        weapons = _weapon_deltas(index, obj, counterpart, prefix)
        if weapons:
            delta["weapon_fields"] = weapons
        if delta:
            changed[obj] = delta
    return {
        "template": general["name"],
        "base": base["name"],
        "prefix": prefix,
        "settings": diff(_settings(base), _settings(general)),
        "added": {obj: object_summary(index, obj, prefix) | {"reached": roster.objects[obj]} for obj in added},
        "removed": removed,
        "changed": changed,
        "unchanged": sorted(o for o in paired if o not in changed),
        "upgrades": _set_delta(base_roster.upgrades, roster.upgrades, prefix),
        "powers": _set_delta(base_roster.powers, roster.powers, prefix),
        "sciences": _set_delta(base_roster.sciences, roster.sciences, prefix),
        "power_details": {p: _power(index, p) for p in sorted(roster.powers)},
        "science_details": {s: _science(index, s) for s in sorted(roster.sciences)},
        "module_census": _module_census(index, base_roster, roster),
        "missing": sorted(roster.missing),
    }


def _settings(template: Block) -> dict[str, str | None]:
    return {key: top(template["fields"], key) for key in TEMPLATE_KEYS if key not in {"Side", "StartingBuilding"}}


def _weapon_deltas(index: Index, obj: str, counterpart: str, prefix: str) -> dict[str, Any]:
    mine = [_weapon_name(v) for v in values(index.fields("Object", obj), "Weapon")]
    theirs = [_weapon_name(v) for v in values(index.fields("Object", counterpart), "Weapon")]
    deltas: dict[str, Any] = {}
    for name in mine:
        base_name = strip_prefix(name, prefix)
        if (
            name == base_name
            or base_name not in theirs
            or None in (index.get("Weapon", base_name), index.get("Weapon", name))
        ):
            continue
        delta = diff(weapon_summary(index, base_name), weapon_summary(index, name))
        if delta:
            deltas[name] = delta
    return deltas


def _set_delta(base: set[str], mine: set[str], prefix: str) -> dict[str, list[str]]:
    plain = {strip_prefix(x, prefix) for x in mine}
    return {
        "added": sorted(x for x in mine if strip_prefix(x, prefix) not in base),
        "removed": sorted(base - plain),
        "kept": sorted(x for x in mine if strip_prefix(x, prefix) in base),
    }


def _power(index: Index, name: str) -> dict[str, str | None]:
    fields = index.fields("SpecialPower", name)
    return {k: top(fields, k) for k in ("Enum", "ReloadTime", "RequiredScience", "SharedSyncedTimer", "PublicTimer")}


def _science(index: Index, name: str) -> dict[str, str | None]:
    fields = index.fields("Science", name)
    return {k: top(fields, k) for k in ("PrerequisiteSciences", "SciencePurchasePointCost", "IsGrantable")}


def _module_census(index: Index, base: Roster, mine: Roster) -> dict[str, list[str]]:
    """Module classes the general's roster uses that the base roster never does: the systems a port must add."""
    used: dict[str, set[str]] = {"base": set(), "general": set()}
    for label, roster in (("base", base), ("general", mine)):
        for obj in roster.objects:
            used[label].update(module_classes(index.fields("Object", obj)))
    return {
        "only_general": sorted(used["general"] - used["base"]),
        "only_base": sorted(used["base"] - used["general"]),
    }


def build_report(blocks: list[Block], include_all: bool = False) -> dict[str, Any]:
    index = Index(blocks)
    groups: dict[str, list[Block]] = defaultdict(list)
    for template in playable_templates(index, include_all):
        groups[top(template["fields"], "BaseSide") or "?"].append(template)
    report: dict[str, Any] = {"factions": {}, "generals": [], "problems": []}
    for side, group in sorted(groups.items()):
        base = base_template(group)
        if base is None:
            report["problems"].append(f"BaseSide {side}: no single template without a general prefix")
            continue
        roster = walk_roster(index, base)
        report["factions"][side] = {
            "template": base["name"],
            "objects": sorted(roster.objects),
            "upgrades": sorted(roster.upgrades),
            "powers": sorted(roster.powers),
            "sciences": sorted(roster.sciences),
            "missing": sorted(roster.missing),
        }
        for general in group:
            if general is not base:
                report["generals"].append(compare(index, base, general) | {"base_side": side})
    duplicates = [d for d in index.duplicates if d.split()[0] in READ_KINDS]
    if duplicates:
        report["problems"].append(f"{len(duplicates)} names defined twice (last wins): {duplicates[:10]}")
    return report


def markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Zero Hour generals against their base factions",
        "",
        "Generated by `tools/zh_generals.py`; local only.",
        "",
    ]
    lines += ["| General | Base | Prefix | Objects added | removed | changed | unchanged | Powers +/- | Sciences +/- |"]
    lines += ["|---|---|---|---|---|---|---|---|---|"]
    for g in report["generals"]:
        lines.append(
            f"| {g['template']} | {g['base']} | {g['prefix']} | {len(g['added'])} | {len(g['removed'])} | "
            f"{len(g['changed'])} | {len(g['unchanged'])} | {len(g['powers']['added'])}/{len(g['powers']['removed'])} | "
            f"{len(g['sciences']['added'])}/{len(g['sciences']['removed'])} |"
        )
    for side, faction in report["factions"].items():
        lines += ["", f"## Base {side} ({faction['template']}): {len(faction['objects'])} objects", ""]
        lines.append(", ".join(faction["objects"]))
    for g in report["generals"]:
        lines += ["", f"## {g['template']} (base {g['base']}, prefix `{g['prefix']}`)", ""]
        if g["settings"]:
            lines.append(
                "Player template changes: " + "; ".join(f"{k}: {a} -> {b}" for k, (a, b) in g["settings"].items())
            )
        lines.append("Added: " + (", ".join(f"{o} ({s['reached']})" for o, s in g["added"].items()) or "none"))
        lines.append("Removed: " + (", ".join(g["removed"]) or "none"))
        for obj, delta in g["changed"].items():
            parts = []
            for key, value in delta.items():
                if key == "weapon_fields":
                    for weapon, wdelta in value.items():
                        parts.append(f"{weapon}: " + ", ".join(f"{k} {a}->{b}" for k, (a, b) in wdelta.items()))
                elif key.startswith("modules_"):
                    if value:
                        parts.append(f"{key} {value}")
                else:
                    parts.append(f"{key} {value[0]}->{value[1]}")
            lines.append(f"- {obj}: " + "; ".join(parts))
        for label in ("powers", "sciences", "upgrades"):
            lines.append(
                f"{label.capitalize()} added: {', '.join(g[label]['added']) or 'none'}; removed: {', '.join(g[label]['removed']) or 'none'}"
            )
        lines.append(
            "Module classes only this general uses: " + (", ".join(g["module_census"]["only_general"]) or "none")
        )
        if g["missing"]:
            lines.append("Unresolved references: " + ", ".join(g["missing"]))
    if report["problems"]:
        lines += ["", "## Problems", "", *[f"- {p}" for p in report["problems"]]]
    return "\n".join(lines) + "\n"


def main(argv: list[str], out: TextIO = sys.stdout) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["report"])
    parser.add_argument("--dump", default=str(DEFAULT_DUMP))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--all", action="store_true", help="also include unplayable templates and the challenge boss")
    args = parser.parse_args(argv)
    try:
        blocks = load_dump(Path(args.dump))
    except OSError as error:
        print(f"zh_generals: {error} (run python3 tools/zh_ini.py dump first)", file=sys.stderr)
        return 1
    report = build_report(blocks, args.all)
    target = Path(args.out)
    target.mkdir(parents=True, exist_ok=True)
    (target / "generals.json").write_text(json.dumps(report, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    (target / "generals.md").write_text(markdown(report), encoding="utf-8")
    print(
        f"ZH_GENERALS factions={len(report['factions'])} generals={len(report['generals'])} "
        f"problems={len(report['problems'])} out={target}",
        file=out,
    )
    return 0 if report["generals"] and not report["problems"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
