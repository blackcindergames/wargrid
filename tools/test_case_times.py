import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from case_times import main

OLD = 'const CASE_SECONDS := {"gone": 9.9}\n'


class CaseTimesTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.directory = Path(temp.name)

    def log(self, name: str, lines: list[str]) -> Path:
        path = self.directory / name
        path.write_text("\n".join(lines) + "\n")
        return path

    def target(self, text: str) -> Path:
        path = self.directory / "run_tests.gd"
        path.write_text(text)
        return path

    def run_main(self, *args: object) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main([str(a) for a in args])
        return code, out.getvalue(), err.getvalue()

    def test_ct1_merges_logs_applies_threshold_and_sorts(self):
        a = self.log("a.log", ["CASE_STAT test_b 2.5 10", "CASE_STAT test_fast 0.9 3", "CASES 2 CHECKS 13 FAILURES 0"])
        b = self.log("b.log", ["CASE_STAT test_a 44.8 7", "CASE_STAT test_edge 1.0 1", "CASES 2 CHECKS 8 FAILURES 0"])
        code, out, _ = self.run_main(a, b)
        self.assertEqual(code, 0)
        self.assertEqual(out, 'const CASE_SECONDS := {"test_a": 44.8, "test_b": 2.5, "test_edge": 1.0}\n')

    def test_ct2_write_needs_exactly_one_table_line(self):
        log = self.log("l.log", ["CASE_STAT test_a 3.0 1", "CASES 1 CHECKS 1 FAILURES 0", "TESTS PASSED 1"])
        for text in ["var x = 1\n", OLD + OLD]:
            target = self.target(text)
            code, _, _ = self.run_main(log, "--write", target)
            self.assertEqual(code, 2)
            self.assertEqual(target.read_text(), text)

    def test_ct2_write_refuses_a_partial_log(self):
        partial = self.log("p.log", ["CASE_STAT test_a 3.0 1", "CASES 2 CHECKS 1 FAILURES 0", "TESTS PASSED 1"])
        nocases = self.log("n.log", ["CASE_STAT test_a 3.0 1", "TESTS PASSED 1"])
        target = self.target(OLD)
        for log in [partial, nocases]:
            code, _, _ = self.run_main(log, "--write", target)
            self.assertEqual(code, 2)
            self.assertEqual(target.read_text(), OLD)

    def test_ct2_write_replaces_the_line_and_drops_stale_keys(self):
        log = self.log("l.log", ["CASE_STAT test_a 3.0 1", "CASES 1 CHECKS 1 FAILURES 0", "TESTS PASSED 1"])
        target = self.target("before\n" + OLD + "after\n")
        code, _, _ = self.run_main(log, "--write", target)
        self.assertEqual(code, 0)
        self.assertEqual(target.read_text(), 'before\nconst CASE_SECONDS := {"test_a": 3.0}\nafter\n')

    def test_ct4_unkeyable_lambda_cases_count_but_stay_out_of_the_table(self):
        log = self.log(
            "l.log",
            [
                "CASE_STAT <anonymous lambda> 5.0 1",
                "CASE_STAT test_a 3.0 1",
                "CASES 2 CHECKS 2 FAILURES 0",
                "TESTS PASSED 2",
            ],
        )
        target = self.target(OLD)
        code, _, _ = self.run_main(log, "--write", target)
        self.assertEqual(code, 0)
        self.assertEqual(target.read_text(), 'const CASE_SECONDS := {"test_a": 3.0}\n')

    def test_ct5_write_refuses_a_filtered_run(self):
        log = self.log(
            "f.log", ["CASE_FILTER test_a", "CASE_STAT test_a 3.0 1", "CASES 1 CHECKS 1 FAILURES 0", "TESTS PASSED 1"]
        )
        target = self.target(OLD)
        code, _, err = self.run_main(log, "--write", target)
        self.assertEqual(code, 2)
        self.assertIn("filtered", err)
        self.assertEqual(target.read_text(), OLD)

    def test_ct6_write_refuses_a_log_without_a_pass_or_with_a_failure(self):
        stat = ["CASE_STAT test_a 3.0 1", "CASES 1 CHECKS 1 FAILURES 0"]
        bad = [self.log("nopass.log", stat), self.log("fail.log", [*stat, "FAIL: x", "TESTS PASSED 1"])]
        target = self.target(OLD)
        for log in bad:
            code, _, _ = self.run_main(log, "--write", target)
            self.assertEqual(code, 2)
            self.assertEqual(target.read_text(), OLD)

    def test_ct6_write_refuses_a_log_with_an_engine_error(self):
        stat = ["CASE_STAT test_a 3.0 1", "CASES 1 CHECKS 1 FAILURES 0", "TESTS PASSED 1"]
        target = self.target(OLD)
        for error in ["ERROR: leaked node", "SCRIPT ERROR: Parse Error"]:
            code, _, _ = self.run_main(self.log("e.log", [*stat, error]), "--write", target)
            self.assertEqual(code, 2, error)
            self.assertEqual(target.read_text(), OLD)

    def test_ct6_print_mode_names_the_problem_and_still_prints(self):
        log = self.log("f.log", ["CASE_STAT test_a 3.0 1", "CASES 1 CHECKS 1 FAILURES 0", "FAIL: x", "TESTS PASSED 1"])
        code, out, err = self.run_main(log)
        self.assertEqual((code, out), (0, 'const CASE_SECONDS := {"test_a": 3.0}\n'))
        self.assertIn("did not pass", err)

    def test_ct2_failed_write_leaves_no_temp_file(self):
        log = self.log("l.log", ["CASE_STAT test_a 3.0 1", "CASES 1 CHECKS 1 FAILURES 0", "TESTS PASSED 1"])
        target = self.target(OLD)
        with mock.patch("case_times.os.replace", side_effect=OSError("disk full")):
            code, _, err = self.run_main(log, "--write", target)
        self.assertEqual(code, 2)
        self.assertIn("disk full", err)
        self.assertEqual(target.read_text(), OLD)
        self.assertEqual(sorted(p.name for p in self.directory.iterdir()), ["l.log", "run_tests.gd"])

    def test_ct7_a_name_in_two_suites_keeps_the_slower_time_in_either_order(self):
        a = self.log("a.log", ["CASE_STAT test_a 3.0 1", "CASES 1 CHECKS 1 FAILURES 0"])
        b = self.log("b.log", ["CASE_STAT test_a 5.0 1", "CASES 1 CHECKS 1 FAILURES 0"])
        for order in [(a, b), (b, a)]:
            self.assertEqual(self.run_main(*order)[1], 'const CASE_SECONDS := {"test_a": 5.0}\n')

    def test_ct1_raw_shard_logs_sum_their_cases_lines(self):
        a = self.log("a.log", ["CASE_STAT test_a 3.0 1", "CASES 1 CHECKS 1 FAILURES 0", "TESTS PASSED 1"])
        b = self.log("b.log", ["CASE_STAT test_b 2.0 1", "CASES 1 CHECKS 1 FAILURES 0", "TESTS PASSED 1"])
        target = self.target(OLD)
        code, _, _ = self.run_main(a, b, "--write", target)
        self.assertEqual(code, 0)
        self.assertEqual(target.read_text(), 'const CASE_SECONDS := {"test_a": 3.0, "test_b": 2.0}\n')

    def test_ct3_malformed_line_is_named(self):
        log = self.log("m.log", ["CASE_STAT test_a 3.0 1", "CASE_STAT test_b slow 2", "CASES 2 CHECKS 3 FAILURES 0"])
        code, out, err = self.run_main(log)
        self.assertEqual(code, 2)
        self.assertEqual(out, "")
        self.assertIn("CASE_STAT test_b slow 2", err)


if __name__ == "__main__":
    unittest.main()
