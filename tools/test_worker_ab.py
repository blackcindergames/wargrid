import contextlib
import io
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent))

import worker_ab

BASE = {"skirmish3v3": 10.0, "team": 12.0}


def _row(load: str, export: str, arm: str, i: int, p95: float, **kw: Any) -> dict[str, Any]:
    row: dict[str, Any] = {
        "load": load, "export": export, "arm": arm, "run": i, "build": "b1", "window_ticks": 1800, "start_tick": 600,
        "end_tick": 2400, "failed": "", "isolated": True, "frames": 5000,
        "cpu_ms": {"n": 5000, "p50": 3.0, "p95": p95, "p99": p95 + 1.0, "max": p95 + 3.0},
        "frame_ms": {"n": 5000, "p50": 7.0, "p95": 8.0, "p99": 9.0, "max": 11.0},
        "missed_share": 0.0, "main_per_tick": 15.0, "tick_rate": 30.0, "pace_worst_2s_tps": 29.8,
        "posts_attempted": 1800, "room_refusals": 0, "refusal_streak_max": 0, "depth_max": 1,
        "job_ms": {"n": 1800, "p50": 4.0, "p95": 6.0, "p99": 7.0, "max": 8.0},
        "handoff_ms": {"n": 1800, "p50": 0.8, "p95": 1.0, "p99": 1.1, "max": 1.2},
        "age_ms": {"n": 1800, "p50": 30.0, "p95": 32.0, "p99": 33.0, "max": 34.0},
    }  # fmt: skip
    row.update(kw)
    return row


def _page(rows: list[dict[str, Any]], *, digest: str = "aa", end: str = "WORKER BENCH DONE") -> str:
    lines = ["WORKER BENCH engine=x"]
    for r in rows:
        lines.append(f"RUN {r['run']} arm={r['arm']}")
        lines += [f"DIGEST tick={t} {digest}{t}" for t in range(r["start_tick"], r["end_tick"] + 1, 300)]
        lines.append("WORKER RUN " + json.dumps(r))
    return "\n".join([*lines, end]) + "\n"


def _write(root: Path, worker_gain: float = 5.0, worker: dict[str, Any] | None = None, runs: int = 3) -> None:
    for load, base in BASE.items():
        rows = []
        for i in range(1, runs + 1):
            jitter = 0.05 * i
            rows.append(_row(load, "threads", "inline", i, base + jitter))
            rows.append(_row(load, "threads", "worker", i, base - worker_gain + jitter, **(worker or {})))
        (root / f"web-{load}-threads.log").write_text(_page(rows))
        nothreads = [_row(load, "nothreads", "inline", i, base + 0.5 + 0.05 * i) for i in range(1, runs + 1)]
        (root / f"web-{load}-nothreads.log").write_text(_page(nothreads))


def _run(*args: str) -> str:
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        worker_ab.main(list(args))
    return out.getvalue()


class WorkerAbTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.addCleanup(self._tmp.cleanup)

    def test_a_clean_set_is_go(self) -> None:
        _write(self.root)
        text = _run("decide", str(self.root))
        self.assertIn("VERDICT GO", text)
        self.assertIn("DIGESTS EQUAL team (9 runs)", text)
        self.assertTrue(text.rstrip().endswith("AB DONE"))

    def test_unset_guards_say_so_and_set_guards_bite(self) -> None:
        _write(self.root, worker={"room_refusals": 90, "pace_worst_2s_tps": 20.0, "tick_rate": 25.0})
        self.assertIn("VERDICT GO", _run("decide", str(self.root)))
        self.assertIn("guard refusal_share: ok (unset,", _run("decide", str(self.root)))
        for flag, value in (
            ("--max-refusal-share", "0.01"),
            ("--min-worst-pace", "29"),
            ("--tick-rate-tolerance", "1"),
        ):
            self.assertIn("VERDICT DROP", _run("decide", flag, value, str(self.root)), flag)

    def test_a_missing_field_is_no_verdict_and_report_survives(self) -> None:
        _write(self.root)
        path = self.root / "web-team-threads.log"
        path.write_text(path.read_text().replace('"depth_max": 1, ', ""))
        text = _run("decide", str(self.root))
        self.assertIn("NO VERDICT", text)
        self.assertIn("field depth_max missing", text)
        self.assertNotIn("VERDICT GO", text)
        self.assertIn("AB DONE", _run("report", str(self.root)))

    def test_a_row_without_backlog_max_is_fine(self) -> None:
        _write(self.root)
        text = _run("report", str(self.root))
        self.assertNotIn("backlog", text)
        self.assertIn("depth_max", text)
        self.assertNotIn("NOTE", text.replace("not isolated", ""))

    def test_a_one_run_arm_reports_but_has_no_verdict(self) -> None:
        _write(self.root, runs=1)
        self.assertIn("1 runs, needs 3", _run("decide", str(self.root)))
        text = _run("report", str(self.root))
        self.assertIn("team | threads | worker | 1 |", text)
        self.assertIn("[0.00]", text)

    def test_unequal_digests_across_arms(self) -> None:
        _write(self.root)
        path = self.root / "web-team-threads.log"
        rows = [
            json.loads(line[len("WORKER RUN ") :])
            for line in path.read_text().splitlines()
            if line.startswith("WORKER RUN")
        ]
        pages = [_page([r], digest="bb" if r["arm"] == "worker" else "aa") for r in rows]
        path.write_text(pages[0] + "".join(page.replace("WORKER BENCH engine=x\n", "") for page in pages[1:]))
        text = _run("decide", str(self.root))
        self.assertIn("DIGESTS DIFFER team: DIGEST differs at tick 600", text)
        self.assertIn("NO VERDICT", text)
        self.assertNotIn("VERDICT GO", text)

    def test_a_missing_digest_tick(self) -> None:
        _write(self.root)
        path = self.root / "web-team-threads.log"
        path.write_text(path.read_text().replace("DIGEST tick=1200 aa1200\n", "", 1))
        text = _run("decide", str(self.root))
        self.assertIn("NO VERDICT", text)
        self.assertIn("are not 600..2400 every 300", text)

    def test_an_absurd_duration_gives_no_number(self) -> None:
        for bad in (1.8e16, -3.0):
            with self.subTest(bad=bad):
                _write(self.root, worker={"cpu_ms": {"n": 5000, "p50": 3.0, "p95": 7.0, "p99": 8.0, "max": bad}})
                text = _run("decide", str(self.root))
                self.assertIn("NO VERDICT", text)
                self.assertIn("absurd duration cpu_ms.max", text)
                self.assertNotIn("VERDICT GO", text)
                self.assertNotIn("VERDICT DROP", text)
                self.assertIn("absurd duration", _run("report", str(self.root)))

    def test_an_empty_timing_pipeline_is_no_verdict(self) -> None:
        empty = {"n": 0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
        for key in ("job_ms", "age_ms", "handoff_ms"):
            with self.subTest(key=key):
                _write(self.root, worker={key: empty})
                text = _run("decide", str(self.root))
                self.assertIn(f"no {key} samples", text)
                self.assertIn("NO VERDICT", text)
                self.assertNotIn("VERDICT GO", text)
                self.assertIn(f"no {key} samples", _run("report", str(self.root)))

    def test_a_worker_row_without_timing_fields(self) -> None:
        _write(self.root)
        path = self.root / "web-team-threads.log"
        path.write_text(re.sub(r', "age_ms": \{[^}]*\}', "", path.read_text()))
        self.assertIn("field age_ms.p95 missing", _run("decide", str(self.root)))

    def test_a_run_without_digest_lines_or_identity(self) -> None:
        _write(self.root)
        path = self.root / "web-team-threads.log"
        for each in self.root.glob("*.log"):
            lines = each.read_text().splitlines()
            each.write_text("\n".join(line for line in lines if not line.startswith("DIGEST ")) + "\n")
        text = _run("decide", str(self.root))
        self.assertIn("NO VERDICT", text)
        self.assertIn("DIGESTS DIFFER", text)
        path.write_text(path.read_text().replace('"load": "team", ', "", 1))
        text = _run("decide", str(self.root))
        self.assertIn("lacks ['load']", text)
        self.assertIn("NO VERDICT", text)

    def test_a_failed_or_timed_out_run(self) -> None:
        _write(self.root)
        path = self.root / "web-team-threads.log"
        path.write_text(path.read_text().replace("WORKER BENCH DONE", "WORKER BENCH TIMEOUT"))
        self.assertIn("WORKER BENCH TIMEOUT", _run("decide", str(self.root)))

    def test_bench_logs_in_a_folder_are_read(self) -> None:
        (self.root / "t12-bench-worker.log").write_text(_page([_row("team", "threads", "worker", 1, 9.0)]))
        (self.root / "t12-red1.log").write_text("not a bench log\n")
        text = _run("report", str(self.root))
        self.assertIn("team | threads | worker | 1 |", text)
        self.assertNotIn("t12-red1", text)


if __name__ == "__main__":
    unittest.main()
