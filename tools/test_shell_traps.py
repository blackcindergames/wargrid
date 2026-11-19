import os
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

TOOLS = Path(__file__).parent
# A gate or shard whose grandchild is orphaned at once: only a process group still reaches it.
# The mv makes the pid file appear complete.
STUB = '#!/bin/sh\n(sleep 300 & echo $! > "$PIDS/$$.tmp" && mv "$PIDS/$$.tmp" "$PIDS/$$.pid")\nsleep 300\n'
GATES = ("ensure_venv", "run_lint", "run_warnings", "run_python_checks", "run_shell_checks", "check_public")


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def reap(pids: list[int]) -> None:
    for pid in pids:
        if alive(pid):
            os.kill(pid, signal.SIGKILL)


class TrapsKillGrandchildren(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        (self.root / "tools").mkdir()
        self.pids = self.root / "pids"
        self.pids.mkdir()

    def stub(self, name: str, body: str = STUB) -> Path:
        path = self.root / "tools" / name
        path.write_text(body)
        path.chmod(0o755)
        return path

    def run_and_term(self, script: str, expected: int, env: dict[str, str]):
        shutil.copy(TOOLS / script, self.root / "tools" / script)
        proc = subprocess.Popen(
            ["sh", f"tools/{script}"],
            cwd=self.root,
            env={**os.environ, "PIDS": str(self.pids), **env},
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.addCleanup(proc.kill)
        deadline = time.monotonic() + 10
        while len(list(self.pids.glob("*.pid"))) < expected and time.monotonic() < deadline:
            time.sleep(0.05)
        grandchildren = [int(p.read_text()) for p in self.pids.glob("*.pid")]
        self.assertEqual(len(grandchildren), expected, "stubs did not all start")
        self.addCleanup(reap, grandchildren)
        proc.send_signal(signal.SIGTERM)
        self.assertEqual(proc.wait(10), 1)
        deadline = time.monotonic() + 3
        while any(alive(p) for p in grandchildren) and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertEqual([p for p in grandchildren if alive(p)], [], "grandchildren outlived the trap")

    def test_run_checks(self):
        self.stub("ensure_venv.sh", "#!/bin/sh\n")
        for gate in GATES[1:]:
            self.stub(f"{gate}.sh")
        self.run_and_term("run_checks.sh", len(GATES) - 1, {})

    def test_run_bench_pairs(self):
        engine = self.stub("fake_godot")
        for rel in ("perf_pairs.py", "perf_record.py"):
            shutil.copy(TOOLS / rel, self.root / "tools" / rel)
        (self.root / "game").mkdir()
        (self.root / "game" / ".keep").write_text("")
        git_env = {
            **os.environ,
            "GIT_AUTHOR_NAME": "t",
            "GIT_AUTHOR_EMAIL": "t@t",
            "GIT_COMMITTER_NAME": "t",
            "GIT_COMMITTER_EMAIL": "t@t",
        }
        for args in (("init", "-q"), ("add", "game"), ("commit", "-qm", "init")):
            subprocess.run(["git", *args], cwd=self.root, env=git_env, capture_output=True, check=True)
        self.run_and_term("run_bench_pairs.sh", 1, {"PERF_REF": "HEAD", "GODOT_BIN": str(engine)})

    def test_run_tests(self):
        engine = self.stub("fake_tests")
        self.run_and_term(
            "run_tests.sh", 2, {"WARGRID_TEST_EXE": str(engine), "WARGRID_TEST_SHARDS": "2", "WARGRID_TEST_ONLY": ""}
        )


if __name__ == "__main__":
    unittest.main()
