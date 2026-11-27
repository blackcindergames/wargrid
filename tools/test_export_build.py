import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "export_build.sh"
FAKE_GODOT = '#!/bin/sh\necho "godot $*" >> "$STUB_LOG"; for last; do :; done; touch "$last"\n'


class ExportBuildTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        (self.root / "tools").mkdir()
        (self.root / "game").mkdir()
        shutil.copy(SCRIPT, self.root / "tools/export_build.sh")
        godot = self.root / "godot"
        godot.write_text(FAKE_GODOT)
        godot.chmod(0o755)
        self.log = self.root / "stub.log"
        self.env = {**os.environ, "GODOT_BIN": str(godot), "STUB_LOG": str(self.log)}
        self.env.pop("WARGRID_SYNTH_AUDIO", None)

    def run_script(self) -> subprocess.CompletedProcess[str]:
        out = self.root / "out/Wargrid"
        return subprocess.run(
            ["sh", str(self.root / "tools/export_build.sh"), "Linux", str(out)],
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_missing_licensed_audio_refuses(self) -> None:
        result = self.run_script()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("game/audio/licensed/ is missing", result.stderr)
        self.assertFalse(self.log.exists(), "no export may run without the pack")

    def test_licensed_audio_present_exports(self) -> None:
        (self.root / "game/audio/licensed/sfx").mkdir(parents=True)
        (self.root / "game/audio/licensed/sfx/impact.wav").write_bytes(b"RIFF")
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--export-release Linux", self.log.read_text())

    def test_opt_out_exports_without_the_pack(self) -> None:
        self.env["WARGRID_SYNTH_AUDIO"] = "1"
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
