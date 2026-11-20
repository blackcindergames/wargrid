import argparse
import os
import re
import sys
from pathlib import Path

THRESHOLD = 1.0
TABLE = "const CASE_SECONDS :="
STAT = re.compile(r"CASE_STAT (\S.*) (\d+\.\d) (\d+)")
CASES = re.compile(r"CASES (\d+) CHECKS \d+ FAILURES \d+")


class Logs:
    def __init__(self, paths: list[Path]) -> None:
        self.stats: dict[str, float] = {}
        self.lines = 0
        self.total = 0
        self.case_lines = 0
        self.passed = 0
        self.failed = False
        self.filtered = False
        for path in paths:
            for line in path.read_text().splitlines():
                self._read(path, line)

    def _read(self, path: Path, line: str) -> None:
        if line.startswith("CASE_STAT"):
            match = STAT.fullmatch(line)
            if not match:
                raise ValueError(f"{path}: malformed line: {line}")
            self.lines += 1
            if not match.group(1).startswith("<"):  # wrapped cases are lambdas that share one name, so no key
                self.stats[match.group(1)] = max(self.stats.get(match.group(1), 0.0), float(match.group(2)))
        elif match := CASES.fullmatch(line):
            self.case_lines += 1
            self.total += int(match.group(1))
        elif line.startswith("TESTS PASSED "):
            self.passed += 1
        elif line.startswith("FAIL:"):
            self.failed = True
        elif line.startswith("CASE_FILTER"):
            self.filtered = True

    def complete(self) -> str | None:
        if self.filtered:
            return "filtered (WARGRID_TEST_ONLY) run"
        if self.failed or self.case_lines == 0 or self.passed != self.case_lines:
            return "run did not pass (FAIL line, or a CASES line without TESTS PASSED)"
        if self.total != self.lines:
            return f"{self.lines} CASE_STAT lines for CASES total {self.total}: partial run"
        return None


def table_line(stats: dict[str, float]) -> str:
    slow = sorted(((n, s) for n, s in stats.items() if s >= THRESHOLD), key=lambda item: (-item[1], item[0]))
    return TABLE + " {" + ", ".join(f'"{name}": {seconds:.1f}' for name, seconds in slow) + "}"


def write_table(target: Path, line: str) -> None:
    lines = target.read_text().split("\n")
    hits = [i for i, text in enumerate(lines) if text.startswith(TABLE)]
    if len(hits) != 1:
        raise ValueError(f"{target}: expected one '{TABLE}' line, found {len(hits)}")
    lines[hits[0]] = line
    temp = target.with_name(target.name + ".tmp")
    temp.write_text("\n".join(lines))
    os.replace(temp, target)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Regenerate CASE_SECONDS from WARGRID_CASE_STATS=1 logs.")
    parser.add_argument("logs", nargs="+", type=Path)
    parser.add_argument("--write", type=Path, metavar="TARGET")
    args = parser.parse_args(argv)
    try:
        logs = Logs(args.logs)
        line = table_line(logs.stats)
        if args.write:
            if problem := logs.complete():
                raise ValueError(f"refusing --write, {problem}")
            write_table(args.write, line)
        else:
            print(line)
    except (OSError, ValueError) as error:
        print(f"case_times: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
