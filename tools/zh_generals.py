"""Report how each Zero Hour general differs from its base faction, from the local INI dump.

Local research tool: reads `build/zh_ini/inizh.jsonl` (written by `python3 tools/zh_ini.py dump`) and writes
`build/zh_generals/generals.md` and `generals.json`; the output quotes retail data and is never committed.
Usage:
    python3 tools/zh_generals.py report [--dump PATH] [--out DIR] [--all]
    python3 tools/zh_generals.py port OBJECT | --roster usa|china|gla [--dump PATH] [--out DIR]
    python3 tools/zh_generals.py census [--base-only] [--dump PATH] [--out DIR]
`port` writes a per-object port sheet (modules, command card, upgrades, weapon sets, OCLs) and `census` counts
objects per mechanic, both to `build/zh_mechanics/` (docs/reference/zh-mechanics-prep.md, Preparation work).

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
MECHANICS_OUT = ROOT / "build/zh_mechanics"

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
        self.defs: dict[tuple[str, str], list[Block]] = defaultdict(list)
        for block in blocks:
            name = block.get("name")
            if name is None:
                continue
            kind = "Object" if block["kind"] == "ObjectReskin" else block["kind"]
            if name in self.by_kind[kind]:
                self.duplicates.append(f"{kind} {name}")
            self.by_kind[kind][name] = block
            self.defs[(kind, name)].append(block)

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


def _slots(index: Index, command_set: str, roster: Roster) -> list[tuple[str, Block]]:
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
        found.append((field["key"], button))
    return found


def buttons(index: Index, command_set: str, roster: Roster) -> list[dict[str, Any]]:
    return [button for _, button in _slots(index, command_set, roster)]


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


MODULE_HEADS = frozenset({"Behavior", "Body", "Draw", "ClientUpdate"})
UPGRADE_LIST_KEYS = frozenset({"TriggeredBy", "ConflictsWith", "RemovesUpgrades"})
BUTTON_KEYS = (
    ("command", "Command"),
    ("upgrade", "Upgrade"),
    ("object", "Object"),
    ("special_power", "SpecialPower"),
    ("weapon_slot", "WeaponSlot"),
    ("science", "Science"),
)
EMPTY_MODULE_LIMIT = (
    "A module whose block has no fields leaves no record in the dump (zh_ini.py parse_entry), "
    "so an empty module of this object cannot be listed."
)
CAMPAIGN_PREFIXES = frozenset({"GC", "CINE", "Cin", "MISSION", "AFG"})


def short_entry(entry: str) -> str:
    return entry.rsplit("\\", 1)[-1]


def cite(block: Block, line: int | None = None) -> str:
    return f"{short_entry(block['entry'])}:{block['line'] if line is None else line}"


def _modules(fields: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Every module that has fields, in file order, with each key's value and line."""
    found: dict[str, dict[str, Any]] = {}
    for field in fields:
        if not field["path"]:
            continue
        opener = field["path"][0]
        head, _, rest = opener.partition("=")
        if head.strip() not in MODULE_HEADS or not rest.strip():
            continue
        parts = rest.split()
        module = found.setdefault(
            opener, {"opener": opener, "class": parts[0], "tag": parts[1] if len(parts) > 1 else "", "fields": []}
        )
        module["fields"].append(
            {"key": field["key"], "value": field["value"], "line": field["line"], "sub": field["path"][1:]}
        )
    return list(found.values())


def _groups(fields: list[dict[str, Any]], opener: str) -> list[list[dict[str, Any]]]:
    """Fields of each `opener` block; the dump keeps no block borders, so a Conditions key or a repeated key starts one."""
    groups: list[list[dict[str, Any]]] = []
    for field in fields:
        if field["path"] != [opener]:
            continue
        if not groups or field["key"] == "Conditions" or any(_ident(f) == _ident(field) for f in groups[-1]):
            groups.append([])
        groups[-1].append(field)
    return groups


def _ident(field: dict[str, Any]) -> tuple[str, str]:
    """A WeaponSet repeats the key `Weapon` once per slot, so the slot is part of the identity."""
    slot = field["value"].split()[:1] if field["key"] == "Weapon" else []
    return field["key"], "".join(slot)


def _weapon_sets(fields: list[dict[str, Any]]) -> list[dict[str, Any]]:
    sets = []
    for group in _groups(fields, "WeaponSet"):
        slots = {}
        for f in group:
            parts = f["value"].split()
            if f["key"] == "Weapon" and len(parts) > 1:
                slots[parts[0]] = parts[1]
        sets.append({"conditions": _first(group, "Conditions"), "slots": slots, "line": group[0]["line"]})
    return sets


def _armor_sets(fields: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "conditions": _first(g, "Conditions"),
            "armor": _first(g, "Armor"),
            "damage_fx": _first(g, "DamageFX"),
            "line": g[0]["line"],
        }
        for g in _groups(fields, "ArmorSet")
    ]


def _first(group: list[dict[str, Any]], key: str) -> str | None:
    return next((f["value"] for f in group if f["key"] == key), None)


def _upgrade_reactions(modules: list[dict[str, Any]]) -> list[tuple[str, str, str, int]]:
    found = []
    for module in modules:
        for f in module["fields"]:
            if f["key"] in UPGRADE_LIST_KEYS:
                found += [(t, f["key"], f"{module['class']} {module['tag']}", f["line"]) for t in f["value"].split()]
            elif f["key"] == "UpgradeToRemove" and f["value"].split():
                found.append((f["value"].split()[0], f["key"], f"{module['class']} {module['tag']}", f["line"]))
    return found


def _upgrade_entry(index: Index, name: str, roles: list[dict[str, Any]]) -> dict[str, Any]:
    fields = index.fields("Upgrade", name)
    definitions = [cite(b) for b in index.defs.get(("Upgrade", name), [])]
    return {
        "name": name,
        "roles": roles,
        "defined": bool(definitions),
        "type": top(fields, "Type"),
        "cost": top(fields, "BuildCost"),
        "time": top(fields, "BuildTime"),
        "definitions": definitions,
        "duplicate": len(definitions) > 1,
    }


def _command_set_sheets(index: Index, obj: str, fields: list[dict[str, Any]]) -> list[dict[str, Any]]:
    sheets = []
    for name in command_sets_of(index, obj):
        field = next(
            f
            for f in fields
            if f["value"].replace("=", " ").split()[:1] == [name] and f["key"].startswith("CommandSet")
        )
        roster = Roster()
        slots = []
        for slot, button in _slots(index, name, roster):
            bfields = button["fields"]
            slots.append(
                {"slot": slot, "button": button["name"], "cite": cite(button)}
                | {label: top(bfields, key) for label, key in BUTTON_KEYS}
            )
        sheets.append(
            {
                "name": name,
                "via": field["path"][0] if field["path"] else "CommandSet",
                "slots": slots,
                "missing": sorted(roster.missing),
            }
        )
    return sheets


def _referenced(index: Index, kind: str, modules: list[dict[str, Any]]) -> dict[str, list[str]]:
    """Blocks of `kind` that module fields name, with the modules that name them."""
    found: dict[str, list[str]] = {}
    for module in modules:
        for f in module["fields"]:
            token = (f["value"].split() or [""])[0]
            if index.get(kind, token) is not None:
                found.setdefault(token, []).append(f"{module['class']} {module['tag']}")
    return found


def _ocl_sheet(index: Index, name: str, sources: list[str]) -> dict[str, Any]:
    block = index.by_kind["ObjectCreationList"][name]
    creates = []
    for field in block["fields"]:
        if field["key"] not in ("ObjectNames", "Transport", "Payload"):
            continue
        for token in field["value"].split()[:1] if field["key"] == "Payload" else field["value"].split():
            made = index.get("Object", token)
            if made is not None:
                creates.append(
                    {
                        "object": token,
                        "entry": short_entry(made["entry"]),
                        "line": made["line"],
                        "modules": _modules(index.fields("Object", token)),
                    }
                )
    return {"name": name, "cite": cite(block), "from": sorted(set(sources)), "creates": creates}


def port_sheet(index: Index, obj: str) -> dict[str, Any]:
    """Everything a port needs to know about one object: modules, command card, upgrades, weapon sets, OCLs."""
    block = index.get("Object", obj)
    if block is None:
        raise KeyError(obj)
    fields = index.fields("Object", obj)
    modules = _modules(fields)
    sets = _command_set_sheets(index, obj, fields)
    reactions: dict[str, list[dict[str, Any]]] = {}
    for name, role, module, line in _upgrade_reactions(modules):
        reactions.setdefault(name, []).append({"role": role, "module": module, "line": line})
    for command_set in sets:
        for slot in command_set["slots"]:
            if slot["upgrade"]:
                via = f"{command_set['name']} slot {slot['slot']}"
                reactions.setdefault(slot["upgrade"], []).append({"role": "button", "module": via, "line": None})
    weapon_names = {w for ws in _weapon_sets(fields) for w in ws["slots"].values()} | set(
        _referenced(index, "Weapon", modules)
    )
    weapons = {
        name: weapon_summary(index, name) | {"cite": cite(index.by_kind["Weapon"][name])}
        for name in sorted(weapon_names)
        if index.get("Weapon", name) is not None
    }
    ocls = [
        _ocl_sheet(index, name, via) for name, via in sorted(_referenced(index, "ObjectCreationList", modules).items())
    ]
    upgrades = [_upgrade_entry(index, name, roles) for name, roles in sorted(reactions.items())]
    sheet = {
        "object": obj,
        "entry": short_entry(block["entry"]),
        "line": block["line"],
        "end_line": block["end_line"],
        "reskin_of": block["args"][0] if block["kind"] == "ObjectReskin" and block["args"] else None,
        "summary": object_summary(index, obj, ""),
        "modules": modules,
        "command_sets": sets,
        "upgrades": upgrades,
        "weapon_sets": _weapon_sets(fields),
        "armor_sets": _armor_sets(fields),
        "weapons": weapons,
        "ocls": ocls,
    }
    sheet["limits"] = _limits(index, sheet, weapon_names)
    return sheet


def _limits(index: Index, sheet: dict[str, Any], weapon_names: set[str]) -> list[str]:
    limits = [EMPTY_MODULE_LIMIT]
    if sheet["reskin_of"]:
        limits.append(f"ObjectReskin of {sheet['reskin_of']}: inherited fields keep that object's line numbers.")
    named = [("Upgrade", u["name"]) for u in sheet["upgrades"]] + [("Weapon", w) for w in sorted(weapon_names)]
    named += [("ObjectCreationList", o["name"]) for o in sheet["ocls"]]
    named += [("Object", c["object"]) for o in sheet["ocls"] for c in o["creates"]]
    named += [("CommandButton", s["button"]) for c in sheet["command_sets"] for s in c["slots"]]
    for kind, name in dict.fromkeys(named):
        found = index.defs.get((kind, name), [])
        if len(found) > 1:
            times = {2: "twice"}.get(len(found), f"{len(found)} times")
            limits.append(f"{kind} {name} is defined {times} ({', '.join(cite(b) for b in found)}); the last one wins.")
    for c in sheet["command_sets"]:
        limits += [f"CommandSet {c['name']}: {m} is not defined." for m in c["missing"]]
    return limits


def roster_sheets(index: Index, side: str) -> list[dict[str, Any]]:
    group = [
        t for t in playable_templates(index, False) if (top(t["fields"], "BaseSide") or "").lower() == side.lower()
    ]
    base = base_template(group) if group else None
    if base is None:
        raise KeyError(side)
    return [port_sheet(index, obj) for obj in sorted(walk_roster(index, base).objects)]


def port_markdown(sheets: list[dict[str, Any]]) -> str:
    lines = [
        "# Zero Hour port sheets",
        "",
        "Generated by `tools/zh_generals.py port`; local only, never committed.",
        "",
    ]
    for sheet in sheets:
        lines += _sheet_markdown(sheet)
    return "\n".join(lines) + "\n"


def _sheet_markdown(sheet: dict[str, Any]) -> list[str]:
    entry = sheet["entry"]
    lines = [f"## {sheet['object']} ({entry}:{sheet['line']}-{sheet['end_line']})", ""]
    summary = {k: v for k, v in sheet["summary"].items() if v not in (None, [], "")}
    lines += [
        ", ".join(
            f"{k}: {v if not isinstance(v, list) else ' '.join(v)}" for k, v in summary.items() if k != "Modules"
        ),
        "",
    ]
    lines.append("### Modules")
    for m in sheet["modules"]:
        lines.append(f"- **{m['opener']}**")
        lines += [f"  - {_sub(f)}{f['key']} = {f['value']} ({entry}:{f['line']})" for f in m["fields"]]
    lines += ["", "### Command sets"]
    for c in sheet["command_sets"]:
        lines.append(f"- **{c['name']}** via {c['via']}")
        for s in c["slots"]:
            extra = ", ".join(f"{label} {s[label]}" for label, _ in BUTTON_KEYS if s[label])
            lines.append(f"  - slot {s['slot']}: {s['button']} ({s['cite']}): {extra}")
    lines += ["", "### Upgrades"]
    for u in sheet["upgrades"]:
        roles = ", ".join(
            f"{r['role']} in {r['module']}" + (f" ({entry}:{r['line']})" if r["line"] else "") for r in u["roles"]
        )
        block = (
            f"{u['type']}, cost {u['cost']}, time {u['time']}, " + " and ".join(u["definitions"])
            if u["defined"]
            else "not defined"
        )
        lines.append(f"- {u['name']}: {block}" + (" (DUPLICATE)" if u["duplicate"] else "") + f"; {roles}")
    lines += ["", "### Weapon and armor sets"]
    lines += [f"- WeaponSet {w['conditions']} ({entry}:{w['line']}): {w['slots']}" for w in sheet["weapon_sets"]]
    lines += [
        f"- ArmorSet {a['conditions']} ({entry}:{a['line']}): {a['armor']} {a['damage_fx'] or ''}".rstrip()
        for a in sheet["armor_sets"]
    ]
    lines += ["", "### Weapons"]
    for name, w in sheet["weapons"].items():
        lines.append(
            f"- {name} ({w['cite']}): " + ", ".join(f"{k} {v}" for k, v in w.items() if k != "cite" and v is not None)
        )
    lines += ["", "### Object creation lists"]
    for o in sheet["ocls"]:
        lines.append(f"- {o['name']} ({o['cite']}) from {', '.join(o['from'])}")
        for made in o["creates"]:
            lines.append(f"  - creates {made['object']} ({made['entry']}:{made['line']})")
            for m in made["modules"]:
                keys = ", ".join(f"{_sub(f)}{f['key']} = {f['value']} ({f['line']})" for f in m["fields"])
                lines.append(f"    - {m['class']} {m['tag']}: {keys}")
    lines += ["", "### Limits", *[f"- {x}" for x in sheet["limits"]], ""]
    return lines


def _sub(field: dict[str, Any]) -> str:
    return f"[{' / '.join(field['sub'])}] " if field["sub"] else ""


def _classes_of(index: Index, obj: str) -> tuple[list[dict[str, Any]], set[str]]:
    fields = index.fields("Object", obj)
    return fields, set(module_classes(fields))


def _object_weapons(index: Index, fields: list[dict[str, Any]]) -> list[str]:
    return [w for ws in _weapon_sets(fields) for w in ws["slots"].values() if index.get("Weapon", w)]


def _module_weapons(index: Index, fields: list[dict[str, Any]], cls: str) -> list[str]:
    names = [
        f["value"].split()[0]
        for f in fields
        if f["key"] == "Weapon"
        and f["path"][:1] == [f"Behavior = {cls} " + f["path"][0].split()[-1]]
        and f["value"].split()
    ]
    return [n for n in names if index.get("Weapon", n)]


def _damage_types(index: Index, weapons: list[str]) -> set[str]:
    return {top(index.fields("Weapon", w), "DamageType") or "" for w in weapons}


def _hosts_slaved(index: Index, fields: list[dict[str, Any]], _classes: set[str]) -> bool:
    for ocl in _referenced(index, "ObjectCreationList", _modules(fields)):
        for made in _ocl_sheet(index, ocl, [])["creates"]:
            if any(m["class"] == "SlavedUpdate" for m in made["modules"]):
                return True
    return False


def _ground_fields(index: Index, fields: list[dict[str, Any]], classes: set[str]) -> bool:
    return "FireWeaponUpdate" in classes and bool(classes & {"LifetimeUpdate", "DeletionUpdate"})


def _jams_missiles(index: Index, fields: list[dict[str, Any]], classes: set[str]) -> bool:
    return "SUBDUAL_MISSILE" in _damage_types(index, _module_weapons(index, fields, "FireWeaponUpdate"))


def _gattling_ramp(index: Index, fields: list[dict[str, Any]], classes: set[str]) -> bool:
    return any(top(index.fields("Weapon", w), "ContinuousFireOne") for w in _object_weapons(index, fields))


def _kills_pilots(index: Index, fields: list[dict[str, Any]], classes: set[str]) -> bool:
    return "KILL_PILOT" in _damage_types(index, _object_weapons(index, fields))


def _levels_up(index: Index, fields: list[dict[str, Any]], classes: set[str]) -> bool:
    return top(fields, "ExperienceRequired") is not None


def _uses_power(index: Index, fields: list[dict[str, Any]], classes: set[str]) -> bool:
    return top(fields, "EnergyProduction") is not None


def _by_class(*names: str) -> Any:
    return lambda index, fields, classes: bool(classes & set(names))


# One row per catalogue mechanic (docs/reference/zh-mechanics-prep.md); a row is a module class or a small predicate.
MECHANICS = (
    ("Drone host (ObjectCreationUpgrade creating a SlavedUpdate object)", _hosts_slaved),
    ("Drone (SlavedUpdate)", _by_class("SlavedUpdate")),
    ("Host upgrade removed on death (UpgradeDie)", _by_class("UpgradeDie")),
    ("Overlord add-on host (OverlordContain)", _by_class("OverlordContain")),
    ("Command-set swap by upgrade (CommandSetUpgrade)", _by_class("CommandSetUpgrade")),
    ("Propaganda aura (PropagandaTowerBehavior)", _by_class("PropagandaTowerBehavior")),
    ("Point-defence laser (PointDefenseLaserUpdate)", _by_class("PointDefenseLaserUpdate")),
    ("Missile deflection (FireWeaponUpdate firing SUBDUAL_MISSILE)", _jams_missiles),
    ("Flares (CountermeasuresBehavior)", _by_class("CountermeasuresBehavior")),
    ("Salvage crate (SalvageCrateCollide)", _by_class("SalvageCrateCollide")),
    ("Crate on death (CreateCrateDie)", _by_class("CreateCrateDie")),
    ("Ground field (timed FireWeaponUpdate)", _ground_fields),
    ("Poison victim (PoisonedBehavior)", _by_class("PoisonedBehavior")),
    ("Burning (FlammableUpdate)", _by_class("FlammableUpdate")),
    ("Fire spread (FireSpreadUpdate)", _by_class("FireSpreadUpdate")),
    ("Weapon-set upgrade (WeaponSetUpgrade)", _by_class("WeaponSetUpgrade")),
    ("Armor upgrade (ArmorUpgrade)", _by_class("ArmorUpgrade")),
    ("Health upgrade (MaxHealthUpgrade)", _by_class("MaxHealthUpgrade")),
    ("Speed upgrade (LocomotorSetUpgrade)", _by_class("LocomotorSetUpgrade")),
    ("Weapon-bonus upgrade (WeaponBonusUpgrade)", _by_class("WeaponBonusUpgrade")),
    ("Death weapon (FireWeaponWhenDeadBehavior)", _by_class("FireWeaponWhenDeadBehavior")),
    ("Battle Bus second life (BattleBusSlowDeathBehavior)", _by_class("BattleBusSlowDeathBehavior")),
    ("Rider change (RiderChangeContain)", _by_class("RiderChangeContain")),
    ("Self-heal (AutoHealBehavior)", _by_class("AutoHealBehavior")),
    ("Horde (HordeUpdate)", _by_class("HordeUpdate")),
    ("Stealth (StealthUpdate)", _by_class("StealthUpdate")),
    ("Detection (StealthDetectorUpdate)", _by_class("StealthDetectorUpdate")),
    ("Transport (TransportContain)", _by_class("TransportContain")),
    ("Garrison (GarrisonContain)", _by_class("GarrisonContain")),
    ("Deploy to fire (DeployStyleAIUpdate)", _by_class("DeployStyleAIUpdate")),
    ("Gattling ramp (a weapon with ContinuousFireOne)", _gattling_ramp),
    ("Kill pilot (a weapon with DamageType KILL_PILOT)", _kills_pilots),
    ("Hijack (ConvertToHijackedVehicleCrateCollide)", _by_class("ConvertToHijackedVehicleCrateCollide")),
    ("Veterancy (ExperienceRequired key)", _levels_up),
    ("Power (EnergyProduction key)", _uses_power),
)


def census(index: Index, base_only: bool = False) -> dict[str, Any]:
    """Objects per mechanic. --base-only drops general-prefixed, Boss_ and campaign copies."""
    dropped = {prefix_of(top(t["fields"], "StartingBuilding") or "") for t in playable_templates(index, True)}
    dropped = (dropped | CAMPAIGN_PREFIXES) - {""}
    mechanics: dict[str, list[str]] = {label: [] for label, _ in MECHANICS}
    counted = 0
    for obj in sorted(index.by_kind["Object"]):
        if base_only and prefix_of(obj) in dropped:
            continue
        counted += 1
        fields, classes = _classes_of(index, obj)
        for label, test in MECHANICS:
            if test(index, fields, classes):
                mechanics[label].append(obj)
        if _ground_fields(index, fields, classes):
            for damage in sorted(_damage_types(index, _module_weapons(index, fields, "FireWeaponUpdate")) - {""}):
                mechanics.setdefault(f"Ground field, damage type {damage}", []).append(obj)
    duplicates = {
        name: [cite(b) for b in found]
        for (kind, name), found in sorted(index.defs.items())
        if kind == "Upgrade" and len(found) > 1
    }
    return {
        "filter": "base-only" if base_only else "all",
        "dropped_prefixes": sorted(dropped) if base_only else [],
        "objects": counted,
        "mechanics": mechanics,
        "duplicate_upgrades": duplicates,
        "limits": [
            EMPTY_MODULE_LIMIT,
            "A module class counts an object once however many modules of it the object has.",
        ],
    }


def census_markdown(data: dict[str, Any]) -> str:
    lines = [
        "# Zero Hour objects per mechanic",
        "",
        f"Generated by `tools/zh_generals.py census`; filter: {data['filter']}"
        + (f" (drops prefixes {', '.join(data['dropped_prefixes'])})" if data["dropped_prefixes"] else "")
        + f"; {data['objects']} objects counted. Local only.",
        "",
        "| Mechanic | Objects |",
        "|---|---:|",
        *[f"| {label} | {len(names)} |" for label, names in data["mechanics"].items()],
        "",
        "## Duplicate upgrade names",
        "",
        *[f"- {name}: {', '.join(cites)}" for name, cites in data["duplicate_upgrades"].items()],
        "",
        "## Limits",
        "",
        *[f"- {x}" for x in data["limits"]],
        "",
        "## Objects",
        "",
        *[f"- {label}: {', '.join(names)}" for label, names in data["mechanics"].items() if names],
    ]
    return "\n".join(lines) + "\n"


def _write(target: Path, name: str, data: Any, text: str) -> None:
    target.mkdir(parents=True, exist_ok=True)
    (target / f"{name}.json").write_text(json.dumps(data, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    (target / f"{name}.md").write_text(text, encoding="utf-8")


def _run_port(index: Index, args: argparse.Namespace, out: TextIO) -> int:
    try:
        if args.roster:
            sheets, name = roster_sheets(index, args.roster), f"port-roster-{args.roster.lower()}"
        elif args.target:
            sheets, name = [port_sheet(index, args.target)], f"port-{args.target}"
        else:
            print("zh_generals: port needs an object name or --roster usa|china|gla", file=sys.stderr)
            return 1
    except KeyError as error:
        print(f"zh_generals: not found in the dump: {error}", file=sys.stderr)
        return 1
    target = Path(args.out or MECHANICS_OUT)
    _write(target, name, sheets, port_markdown(sheets))
    print(f"ZH_PORT objects={len(sheets)} out={target / name}", file=out)
    return 0


def _run_census(index: Index, args: argparse.Namespace, out: TextIO) -> int:
    data = census(index, args.base_only)
    target = Path(args.out or MECHANICS_OUT)
    _write(target, f"census-{data['filter']}", data, census_markdown(data))
    print(
        f"ZH_CENSUS filter={data['filter']} objects={data['objects']} mechanics={len(data['mechanics'])} "
        f"duplicate_upgrades={len(data['duplicate_upgrades'])} out={target}",
        file=out,
    )
    return 0


def main(argv: list[str], out: TextIO = sys.stdout) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["report", "port", "census"])
    parser.add_argument("target", nargs="?", help="port: the object name")
    parser.add_argument("--roster", help="port: every object of a base faction (usa, china or gla)")
    parser.add_argument(
        "--base-only", action="store_true", help="census: drop general-prefixed, Boss_ and campaign copies"
    )
    parser.add_argument("--dump", default=str(DEFAULT_DUMP))
    parser.add_argument(
        "--out", default=None, help="default: build/zh_generals (report), build/zh_mechanics (port, census)"
    )
    parser.add_argument(
        "--all", action="store_true", help="report: also include unplayable templates and the challenge boss"
    )
    args = parser.parse_args(argv)
    try:
        blocks = load_dump(Path(args.dump))
    except OSError as error:
        print(f"zh_generals: {error} (run python3 tools/zh_ini.py dump first)", file=sys.stderr)
        return 1
    if args.command == "port":
        return _run_port(Index(blocks), args, out)
    if args.command == "census":
        return _run_census(Index(blocks), args, out)
    report = build_report(blocks, args.all)
    target = Path(args.out or DEFAULT_OUT)
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
