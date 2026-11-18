import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))

import perf_pairs

ROWS = ("open", "dense", "contact", "hordes300")
GUARDED = ("open", "dense", "hordes300")
BASE = {"open": (1.8, 2.2), "dense": (1.7, 2.1), "contact": (1.0, 1.4), "hordes300": (3.1, 3.5)}
PASSED = "COMBAT BENCHMARK PASSED 10"


def _log(rows: dict[str, tuple[float, float]], stress: tuple[str, ...] = GUARDED, end: str = PASSED) -> str:
    lines = [
        f'COMBAT {row} tick_ms={{"max":9.0,"n":1800,"p50":0.5,"p95":{p95},"p99":{p99}}} shots=1'
        for row, (p95, p99) in rows.items()
    ]
    lines += [
        f"COMBAT STRESS PASS {row} exceeds the 1.82/3.64 budget, regression ceiling p95/p99 [3.0, 5.0]"
        for row in stress
    ]
    return "\n".join([*lines, end])


def _scaled(
    factors: dict[str, float] | None = None, metrics: tuple[int, ...] = (0, 1)
) -> dict[str, tuple[float, float]]:
    factors = factors or {}
    return {
        row: tuple(v * factors.get(row, 1.0) if i in metrics else v for i, v in enumerate(vals))  # type: ignore[misc]
        for row, vals in BASE.items()
    }


def _run(refs: list[str], branches: list[str]) -> tuple[int, list[str]]:
    return perf_pairs.verdict(refs, branches)


def _same(n: int = 3) -> list[str]:
    return [_log(BASE)] * n


class VerdictTest(unittest.TestCase):
    def assertFinal(self, result: tuple[int, list[str]], code: int, prefix: str) -> list[str]:
        self.assertEqual(result[0], code, result[1])
        final = [line for line in result[1] if line.startswith("PAIR GATE ")]
        self.assertEqual(len(final), 1, result[1])
        self.assertTrue(final[0].startswith(prefix), final[0])
        self.assertEqual(result[1][-1], final[0])
        return result[1]

    def test_identical_runs_pass_every_guarded_row(self) -> None:
        self.assertFinal(_run(_same(), _same()), 0, "PAIR GATE PASSED 3")

    def test_branch_three_percent_slower_on_hordes300_p95_fails_only_that_row(self) -> None:
        slow = _log(_scaled({"hordes300": 1.03}, metrics=(0,)))
        lines = self.assertFinal(_run(_same(), [slow] * 3), 1, "PAIR GATE FAILED hordes300:p95")
        self.assertEqual(lines[-1], "PAIR GATE FAILED hordes300:p95")
        self.assertTrue(any(line.startswith("PAIR open p95") and line.endswith("PASS") for line in lines))
        self.assertTrue(any(line.startswith("PAIR dense p95") and line.endswith("PASS") for line in lines))

    def test_ratios_pair_reference_i_with_branch_i_on_a_drifting_host(self) -> None:
        refs = [_log({"open": (v, 1.0)}, ("open",)) for v in (1.0, 2.0, 3.0)]
        branches = [_log({"open": (v, 1.0)}, ("open",)) for v in (1.05, 2.1, 2.0)]
        lines = self.assertFinal(_run(refs, branches), 1, "PAIR GATE FAILED open:p95")
        self.assertIn(
            "PAIR open p95 ref 1.000/2.000/3.000 branch 1.050/2.100/2.000"
            " ratios 1.0500/1.0500/0.6667 median 1.0500 limit 1.020 FAIL",
            lines,
        )

    def test_one_slow_pair_is_absorbed_by_the_median(self) -> None:
        branches = [_log(BASE), _log(_scaled({"open": 1.10, "dense": 1.10, "hordes300": 1.10})), _log(BASE)]
        self.assertFinal(_run(_same(), branches), 0, "PAIR GATE PASSED 3")

    def test_median_at_the_limit_passes_and_just_above_fails(self) -> None:
        for metric, index in (("p95", 0), ("p99", 1)):
            limit = perf_pairs.MAX_RATIO[metric]
            ref = {"open": (1.0, 1.0)}
            for ratio, code, prefix in (
                (limit, 0, "PAIR GATE PASSED 1"),
                (limit + 0.001, 1, f"PAIR GATE FAILED open:{metric}"),
            ):
                branch = {"open": tuple(ratio if i == index else 1.0 for i in range(2))}
                result = _run([_log(ref, ("open",))] * 3, [_log(branch, ("open",))] * 3)  # type: ignore[arg-type]
                self.assertFinal(result, code, prefix)

    def test_p99_has_its_own_limit(self) -> None:
        slow = _log(_scaled({"open": 1.03}, metrics=(1,)))
        lines = self.assertFinal(_run(_same(), [slow] * 3), 1, "PAIR GATE FAILED open:p99")
        self.assertTrue(any(line.startswith("PAIR open p95") and line.endswith("PASS") for line in lines))
        with mock.patch.dict(perf_pairs.MAX_RATIO, {"p99": 1.10}):
            self.assertFinal(_run(_same(), [slow] * 3), 0, "PAIR GATE PASSED 3")

    def test_unguarded_row_slower_never_fails(self) -> None:
        slow = _log(_scaled({"contact": 1.10}))
        self.assertFinal(_run(_same(), [slow] * 3), 0, "PAIR GATE PASSED 3")

    def test_row_new_on_branch_is_reported_not_gated(self) -> None:
        ref = _log({k: v for k, v in BASE.items() if k != "hordes300"}, ("open", "dense"))
        lines = self.assertFinal(_run([ref] * 3, _same()), 0, "PAIR GATE PASSED 2")
        self.assertTrue(any(line.startswith("PAIR NEW hordes300") for line in lines))

    def test_row_missing_in_one_reference_run_is_inconclusive(self) -> None:
        short = _log({k: v for k, v in BASE.items() if k != "hordes300"}, ("open", "dense"))
        self.assertFinal(_run([_log(BASE), short, _log(BASE)], _same()), 2, "PAIR GATE INCONCLUSIVE")

    def test_reference_with_script_error_is_inconclusive(self) -> None:
        bad = _log(BASE) + "\nSCRIPT ERROR: Parse Error"
        self.assertFinal(_run([bad] * 3, _same()), 2, "PAIR GATE INCONCLUSIVE ref run 1 unusable")

    def test_reference_without_any_tick_line_is_inconclusive_not_new(self) -> None:
        lines = self.assertFinal(_run([PASSED] * 3, _same()), 2, "PAIR GATE INCONCLUSIVE ref run 1 unusable")
        self.assertFalse(any("PAIR NEW" in line for line in lines))

    def test_three_identically_truncated_references_are_inconclusive(self) -> None:
        truncated = _log({"open": BASE["open"]}, ("open",), end="")
        lines = self.assertFinal(_run([truncated] * 3, _same()), 2, "PAIR GATE INCONCLUSIVE")
        self.assertFalse(any("PAIR NEW" in line or "PASSED" in line for line in lines))

    def test_reference_killed_after_the_guarded_rows_is_inconclusive(self) -> None:
        self.assertFinal(_run([_log(BASE, end="")] * 3, _same()), 2, "PAIR GATE INCONCLUSIVE ref run 1 unusable")

    def test_old_reference_with_an_unrelated_error_is_inconclusive(self) -> None:
        end = (
            "ERROR: Combat stress ceiling exceeded for hordes300\nERROR: Combat benchmark: no defence shots inside the timed window\n"
            "ERROR: Combat benchmark failed for hordes300"
        )
        old = _log(BASE, end=end) + "\nCOMBAT STRESS FAIL hordes300 exceeds the budget"
        self.assertFinal(_run([old] * 3, _same()), 2, "PAIR GATE INCONCLUSIVE ref run 1 unusable")

    def test_guarded_rows_differ_between_branch_runs_is_inconclusive(self) -> None:
        branches = [_log(BASE), _log(BASE, ("open", "dense")), _log(BASE)]
        self.assertFinal(_run(_same(), branches), 2, "PAIR GATE INCONCLUSIVE")

    def test_branch_without_tick_line_for_guarded_row_is_inconclusive(self) -> None:
        branches = [_log(BASE), _log({k: v for k, v in BASE.items() if k != "hordes300"}), _log(BASE)]
        self.assertFinal(_run(_same(), branches), 2, "PAIR GATE INCONCLUSIVE")

    def test_old_reference_with_ceiling_errors_still_compares(self) -> None:
        end = "ERROR: Combat stress ceiling exceeded for hordes300\nERROR: Combat benchmark failed for hordes300"
        old = _log(BASE, end=end) + "\nCOMBAT STRESS FAIL hordes300 exceeds the budget"
        self.assertFinal(_run([old] * 3, _same()), 0, "PAIR GATE PASSED 3")

    def test_zero_reference_value_is_inconclusive(self) -> None:
        zero = _log({**BASE, "open": (0.0, 2.2)})
        self.assertFinal(_run([zero] * 3, _same()), 2, "PAIR GATE INCONCLUSIVE")

    def test_fail_wins_over_inconclusive(self) -> None:
        short = _log({k: v for k, v in BASE.items() if k != "hordes300"}, ("open", "dense"))
        slow = _log(_scaled({"open": 1.05}))
        self.assertFinal(_run([_log(BASE), short, _log(BASE)], [slow] * 3), 1, "PAIR GATE FAILED open:p95")

    def test_cli_reads_files_and_returns_the_code(self) -> None:
        slow = _log(_scaled({"hordes300": 1.05}))
        with tempfile.TemporaryDirectory() as tmp:
            refs = [str(Path(tmp) / f"r{i}.log") for i in range(3)]
            branches = [str(Path(tmp) / f"b{i}.log") for i in range(3)]
            for path in refs:
                Path(path).write_text(_log(BASE))
            for path in branches:
                Path(path).write_text(slow)
            self.assertEqual(perf_pairs.main(["--ref", *refs, "--branch", *branches]), 1)


if __name__ == "__main__":
    unittest.main()
