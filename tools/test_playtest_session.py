import base64
import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import playtest_session as ps

JPG = base64.b64encode(bytes([0xFF, 0xD8, 0xFF, 0xD9])).decode()


def marker(tick, kind, text, jpg):
    return {
        "tick": tick,
        "kind": kind,
        "text": text,
        "comment": "",
        "camera": [4.5, 14.5],
        "selected": [1, 2],
        "jpg": jpg,
    }


def session():
    return {
        "format": 1,
        "build": "0.11.0-dev+abc1234",
        "focus": "p1-frc-economy",
        "started": "2026-11-12T12:00:00",
        "checklist": {"a": True, "b": False},
        "answers": {"q1": {"score": 4, "text": 'fine "quoted"'}},
        "matches": [
            {
                "mode": "offline",
                "map": "skirmish",
                "seed": 7,
                "factions": ["frc", "china"],
                "build": "0.11.0-dev+abc1234",
                "seat": 1,
                "end_tick": 60,
                "end_digest": "aa",
                "result": "win",
                "markers": [marker(30, "good", "nice", JPG), marker(60, "bad", "no pic", "")],
                "commands": ["line one", "line two"],
            },
            {
                "mode": "online",
                "map": "dry_wells",
                "seed": 3,
                "factions": ["usa", "china"],
                "build": "0.11.0-dev+def5678",
                "seat": 0,
                "end_tick": 90,
                "end_digest": "bb",
                "result": "",
                "markers": [],
                "commands": ["line three"],
            },
        ],
    }


class PlaytestSessionTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.path = Path(self._tmp.name) / "sess.json"
        self.path.write_text(json.dumps(session()))

    def test_summary_lines(self):
        s = ps.load_session(self.path)
        jpgs = [self.path.parent / "sess-m1-1.jpg", None]
        expected = [
            "SESSION build=0.11.0-dev+abc1234 focus=p1-frc-economy started=2026-11-12T12:00:00 matches=2",
            "CHECK a yes",
            "CHECK b no",
            'ANSWER q1 4 fine "quoted"',
            "MATCH 1 offline skirmish seed=7 seat=1 end_tick=60 build=0.11.0-dev+abc1234 result=win",
            f'MARKER 1.1 tick=30 good text="nice" comment="" camera=4.5,14.5 selected=1,2 jpg={jpgs[0]}',
            'MARKER 1.2 tick=60 bad text="no pic" comment="" camera=4.5,14.5 selected=1,2 jpg=-',
            "MATCH 2 online dry_wells seed=3 seat=0 end_tick=90 build=0.11.0-dev+def5678 result=",
        ]
        self.assertEqual(ps.summary_lines(s, jpgs), expected)

    def test_write_jpgs(self):
        jpgs = ps.write_jpgs(ps.load_session(self.path), self.path)
        self.assertEqual(jpgs, [self.path.parent / "sess-m1-1.jpg", None])
        self.assertEqual(self.path.parent.joinpath("sess-m1-1.jpg").read_bytes()[:2], b"\xff\xd8")

    def test_replay_rows(self):
        rows = [r.split("\t") for r in ps.replay_rows(ps.load_session(self.path), self.path)]
        cmd1 = self.path.parent / "sess-m1.cmd"
        self.assertEqual(
            rows[0],
            [
                "1",
                str(cmd1),
                "offline",
                "skirmish",
                "7",
                "frc,china",
                "60",
                "aa",
                "30,60",
                "-",
                "0.11.0-dev+abc1234",
                "-",
            ],
        )
        self.assertEqual(rows[1][5], "-", "online rows pass no --factions")
        self.assertEqual(rows[1][8], "-")
        self.assertEqual(rows[1][10], "0.11.0-dev+def5678")
        self.assertEqual(cmd1.read_text(), "line one\nline two\n")

    def test_replay_rows_carry_bots(self):
        data = session()
        data["matches"][1]["bots"] = [{"player": 3, "faction": "china"}, {"player": 4, "faction": "frc"}]
        data["matches"][1]["teams"] = [1, 1, 2, 2]
        path = self._write(data)
        rows = [r.split("\t") for r in ps.replay_rows(ps.load_session(path), path)]
        self.assertEqual(rows[1][11], "3:china,4:frc")
        self.assertEqual(rows[0][11], "-", "a record without bots passes none")

    def test_replay_rows_offline_bots_ride_on_factions(self):
        data = session()
        data["matches"][0]["factions"] = ["usa", "china", "frc", "usa"]
        data["matches"][0]["bots"] = [{"player": 2, "faction": "china"}, {"player": 3, "faction": "frc"}]
        path = self._write(data)
        rows = [r.split("\t") for r in ps.replay_rows(ps.load_session(path), path)]
        self.assertEqual(rows[0][5], "usa,china,frc,usa", "an offline row passes every seat as --factions")
        self.assertEqual(rows[0][11], "-", "and no --bots, which the client refuses beside --factions")

    def test_replay_rows_bots_from_a_resumed_sitting(self):
        data = session()
        data["matches"][1]["bots"] = [{"player": 3.0, "faction": "china"}, {"player": 4.0, "faction": "frc"}]
        path = self._write(data)
        rows = [r.split("\t") for r in ps.replay_rows(ps.load_session(path), path)]
        self.assertEqual(rows[1][11], "3:china,4:frc")

    def test_replay_rows_carry_controller(self):
        data = session()
        data["matches"][0]["controller"] = "human"
        path = self._write(data)
        rows = [r.split("\t") for r in ps.replay_rows(ps.load_session(path), path)]
        self.assertEqual(rows[0][9], "human")
        self.assertEqual(rows[1][9], "-", "a record without a controller passes none, so the oracle replays it as ai")
        data["matches"][0]["controller"] = None
        path = self._write(data)
        rows = [r.split("\t") for r in ps.replay_rows(ps.load_session(path), path)]
        self.assertEqual(rows[0][9], "-", "a null controller passes none")

    def test_float_numbers_from_a_resumed_sitting(self):
        floaty = session()
        floaty["format"] = 1.0
        for m in floaty["matches"]:
            for key in ("seed", "seat", "end_tick"):
                m[key] = float(m[key])
            for mk in m["markers"]:
                mk["tick"] = float(mk["tick"])
                mk["selected"] = [float(e) for e in mk["selected"]]
        for answer in floaty["answers"].values():
            answer["score"] = float(answer["score"])
        self.path.write_text(json.dumps(floaty))
        s = ps.load_session(self.path)
        self.assertEqual(
            ps.summary_lines(s, [None, None]), ps.summary_lines(ps.load_session(self._write(session())), [None, None])
        )
        rows = [r.split("\t") for r in ps.replay_rows(s, self.path)]
        self.assertEqual(rows[0][4:9], ["7", "frc,china", "60", "aa", "30,60"])

    def _with_unfinished(self):
        data = session()
        cut = data["matches"][1]
        del cut["end_digest"]
        cut.update({"unfinished": True, "result": "unfinished", "commands": []})
        return data

    def test_unfinished_match(self):
        path = self._write(self._with_unfinished())
        s = ps.load_session(path)
        self.assertIn("result=unfinished", ps.summary_lines(s, [None, None])[-1])
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            rows = ps.replay_rows(s, path)
        self.assertEqual([r.split("\t")[0] for r in rows], ["1"])
        self.assertIn("match 2 was cut short", err.getvalue())
        self.assertFalse(path.with_name("plain-m2.cmd").exists())

    def _write(self, data):
        other = self.path.with_name("plain.json")
        other.write_text(json.dumps(data))
        return other

    def test_rejects_other_format(self):
        bad = session()
        bad["format"] = 2
        self.path.write_text(json.dumps(bad))
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            code = ps.main([str(self.path)])
        self.assertEqual(code, 2)
        self.assertIn("unsupported session format", err.getvalue())

    def _replay(self, client_exit, extra="", rows=None, final="aa", count=1, python=sys.executable, controller=None):
        one = session()
        one["matches"] = one["matches"][:1] * count
        if controller is not None:
            one["matches"][0]["controller"] = controller
        if rows is not None:
            one["matches"][0]["tick_hashes"] = rows
        self.path.write_text(json.dumps(one))
        fake = Path(self._tmp.name) / "fake_client.sh"
        fake.write_text(f"#!/bin/sh\necho 'ORACLE FINAL 60 {final}'\n{extra}exit {client_exit}\n")
        fake.chmod(0o755)
        script = Path(__file__).resolve().parent / "replay_session.sh"
        env = {**os.environ, "WARGRID_CLIENT": str(fake), "PYTHON": python}
        return subprocess.run(["sh", str(script), str(self.path)], env=env, capture_output=True, text=True, check=False)

    def test_replay_wrapper_needs_client_success(self):
        passed = self._replay(0)
        self.assertEqual((passed.returncode, "REPLAY MATCHED 1" in passed.stdout), (0, True), passed.stdout)
        crashed = self._replay(1)
        self.assertNotEqual(crashed.returncode, 0, crashed.stdout)
        self.assertNotIn("REPLAY MATCHED", crashed.stdout)
        errored = self._replay(0, "echo 'SCRIPT ERROR: boom'\n")
        self.assertEqual((errored.returncode, "REPLAY MATCHED" in errored.stdout), (1, False), errored.stdout)

    def test_replay_wrapper_passes_controller(self):
        args = Path(self._tmp.name) / "args"
        record = f'echo " $*" > "{args}"\n'
        self._replay(0, record, controller="human")
        self.assertIn(" --controller human ", args.read_text() + " ")
        self._replay(0, record)
        self.assertNotIn("--controller", args.read_text())

    def _hash_files(self, recorded, ring):
        rec, rng = Path(self._tmp.name) / "rec.hashes", Path(self._tmp.name) / "ring.tsv"
        rec.write_text("".join(f"{r}\n" for r in recorded))
        rng.write_text("".join(f"{r}\n" for r in ring))
        return rec, rng

    def _compare(self, recorded, ring):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ps.main(["--compare-hashes", *map(str, self._hash_files(recorded, ring))])
        return code, out.getvalue()

    @staticmethod
    def _ring(changed_from=None, ticks=90):
        return [f"{t}\t{'bad' if changed_from and t >= changed_from else 'h%d' % t}" for t in range(1, ticks + 1)]

    RECORDED = ("30\th30", "60\th60", "90\th90")

    def test_compare_hashes_equal_rows_print_nothing(self):
        self.assertEqual(self._compare(self.RECORDED, self._ring()), (0, ""))
        self.assertEqual(self._compare([], self._ring()), (0, ""), "a match under 30 ticks has no rows")

    def test_compare_hashes_names_first_differing_row(self):
        self.assertEqual(
            self._compare(self.RECORDED, self._ring(changed_from=90)),
            (1, "first differing row at tick 90, last equal row at tick 60\n"),
        )

    def test_compare_hashes_edge_rows(self):
        malformed = self._compare(("30\th30", "oops"), self._ring())
        self.assertEqual(malformed, (2, "malformed hash row 2 in rec.hashes\n"))
        bad_ring = self._compare(self.RECORDED, ["1\th1", "2"])
        self.assertEqual(bad_ring, (2, "malformed hash row 2 in ring.tsv\n"))
        first = self._compare(self.RECORDED, self._ring(changed_from=30))
        self.assertEqual(first, (1, "first differing row at tick 30, no earlier recorded row\n"))
        later = self._compare(("60\th60", "90\th90"), self._ring(changed_from=60))
        self.assertEqual(later, (1, "first differing row at tick 60, no earlier recorded row\n"))
        gap = self._compare(("30\th30", "90\th90"), self._ring(changed_from=90))
        self.assertEqual(gap, (1, "first differing row at tick 90, last equal row at tick 30\n"))
        undecodable = Path(self._tmp.name) / "bin.hashes"
        undecodable.write_bytes(b"\xff\xfe\n")
        self.assertEqual(ps.compare_hashes(undecodable, self._hash_files((), ())[1])[0], 2)
        early = self._compare(self.RECORDED, self._ring(ticks=75))
        self.assertEqual(early, (1, "replay ended before tick 90\n"))
        self.assertEqual(self._compare(self.RECORDED, []), (1, "replay ended before tick 30\n"))

    def test_compare_hashes_blank_recorded_line_is_malformed(self):
        self.assertEqual(
            self._compare(("30\th30", "", "60\th60"), self._ring()), (2, "malformed hash row 2 in rec.hashes\n")
        )

    def test_compare_hashes_blank_ring_lines_are_no_rows(self):
        rec, ring = self._hash_files((), ())
        self.assertEqual(ps.main(["--compare-hashes", str(rec), str(ring)]), 0)
        ring.write_text("\n")
        self.assertEqual(ps.main(["--compare-hashes", str(rec), str(ring)]), 0, "a ring with no rows is one newline")

    def test_compare_hashes_missing_file_is_a_tool_failure(self):
        rec, ring = self._hash_files(self.RECORDED, self._ring())
        gone = Path(self._tmp.name) / "gone.hashes"
        for args in [(gone, ring), (rec, gone)]:
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = ps.main(["--compare-hashes", *map(str, args)])
            self.assertEqual(code, 2, out.getvalue())
            self.assertIn("gone.hashes", out.getvalue())

    def test_compare_hashes_crash_is_a_tool_failure(self):
        out = io.StringIO()
        with (
            mock.patch.object(ps, "_parse_hash_rows", side_effect=RuntimeError("boom")),
            contextlib.redirect_stdout(out),
        ):
            code = ps.main(["--compare-hashes", "a", "b"])
        self.assertEqual(code, 2)
        self.assertIn("boom", out.getvalue())

    def test_replay_rows_write_and_delete_hashes_file(self):
        data = session()
        data["matches"][0]["tick_hashes"] = ["30\th30", "60\th60"]
        data["matches"][1]["tick_hashes"] = []
        path = self._write(data)
        ps.replay_rows(ps.load_session(path), path)
        self.assertEqual(path.with_name("plain-m1.hashes").read_text(), "30\th30\n60\th60\n")
        self.assertEqual(path.with_name("plain-m2.hashes").read_text(), "", "empty rows still write the file")
        path = self._write(session())
        rows = [r.split("\t") for r in ps.replay_rows(ps.load_session(path), path)]
        self.assertEqual(
            rows[0][:9],
            ["1", str(path.parent / "plain-m1.cmd"), "offline", "skirmish", "7", "frc,china", "60", "aa", "30,60"],
        )
        self.assertFalse(path.with_name("plain-m1.hashes").exists(), "a stale file from an earlier run is deleted")
        self.assertFalse(path.with_name("plain-m2.hashes").exists())

    RING_WRITER = (
        'while [ $# -gt 0 ]; do [ "$1" = --ring-log ] && ring=$2; shift; done\n'
        'for t in $(seq 1 60); do printf "%s\\th%s\\n" "$t" "$t"; done > "$ring"\n'
    )

    def test_replay_wrapper_compares_hash_rows(self):
        rows = ["30\th30", "60\th60"]
        same = self._replay(0, self.RING_WRITER, rows=rows)
        self.assertEqual((same.returncode, same.stdout), (0, "REPLAY MATCHED 1\n"), same.stdout)
        changed = self._replay(0, self.RING_WRITER, rows=["30\th30", "60\tzz"])
        self.assertEqual(changed.returncode, 1, changed.stdout)
        self.assertIn("REPLAY DIFFERS 1 first differing row at tick 60, last equal row at tick 30", changed.stdout)
        self.assertNotIn("REPLAY MATCHED", changed.stdout)
        unhashed = self._replay(0, self.RING_WRITER, rows=rows, final="cc")
        self.assertEqual(unhashed.returncode, 1, unhashed.stdout)
        self.assertIn("REPLAY DIFFERS 1 recorded=aa replayed=cc", unhashed.stdout)
        self.assertIn(
            "no recorded row differs (last row tick 60); the difference is after tick 60 or in unhashed state",
            unhashed.stdout,
        )
        short = self._replay(0, self.RING_WRITER, rows=["30\th30"], final="cc")
        self.assertEqual(short.returncode, 1, short.stdout)
        self.assertIn("no recorded row differs (last row tick 30); the difference is after tick 30", short.stdout)
        empty = self._replay(0, self.RING_WRITER, rows=[], final="cc")
        self.assertEqual(empty.returncode, 1, empty.stdout)
        self.assertIn("no hash rows recorded", empty.stdout)
        self.assertNotIn("no recorded row differs", empty.stdout)
        norows = self._replay(0, final="cc")
        self.assertEqual(norows.returncode, 1, norows.stdout)
        self.assertNotIn("recorded row", norows.stdout)
        broken = self._replay(0, self.RING_WRITER, rows=["30\th30", "oops"])
        self.assertEqual(broken.returncode, 1, broken.stdout)
        self.assertIn("REPLAY FAILED 1: malformed hash row 2 in sess-m1.hashes", broken.stdout)

    def test_replay_wrapper_python_dying_before_main_is_a_failure(self):
        dead = Path(self._tmp.name) / "dead_python.sh"
        dead.write_text(
            f'#!/bin/sh\n[ "$2" != --compare-hashes ] || {{ echo SyntaxError >&2; exit 1; }}\nexec {sys.executable} "$@"\n'
        )
        dead.chmod(0o755)
        died = self._replay(0, self.RING_WRITER, rows=["30\th30"], python=str(dead))
        self.assertEqual(died.returncode, 1, died.stdout)
        self.assertIn("REPLAY FAILED 1: hash compare gave no result", died.stdout)
        self.assertNotIn("REPLAY DIFFERS", died.stdout)

    def test_replay_wrapper_empties_the_ring_per_match(self):
        once = Path(self._tmp.name) / "wrote"
        parse, write = self.RING_WRITER.splitlines()
        first_only = f'{parse}\n[ -f "{once}" ] || {{ touch "{once}"; {write}; }}\n'
        two = self._replay(0, first_only, rows=["30\th30", "60\th60"], count=2)
        self.assertEqual(two.returncode, 1, two.stdout)
        self.assertIn("REPLAY MATCHED 1", two.stdout)
        self.assertIn("REPLAY DIFFERS 2 replay ended before tick 30", two.stdout)


if __name__ == "__main__":
    unittest.main()
