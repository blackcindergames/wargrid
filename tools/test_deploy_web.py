import configparser
import os
import re
import shutil
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "tools/deploy_web.sh"
STUB = '#!/bin/sh\necho "{name} $*" >> "$STUB_LOG"\n'
FAKE_EXPORT = '#!/bin/sh\nmkdir -p "$(dirname "$2")" && echo "export synth=$WARGRID_SYNTH_AUDIO preset=[$1] out=$2" >> "$STUB_LOG"\n'
COOP = ("cross-origin-opener-policy", "same-origin")
COEP = ("cross-origin-embedder-policy", "require-corp")
DOCKER_ARG = "ARG SWS_CONFIG=sws.toml"
DOCKER_COPY = "COPY ${SWS_CONFIG} /sws.toml"


def preset_threads(presets_cfg: str, preset: str) -> bool | None:
    """thread_support of the options section that belongs to the preset with this name."""
    parser = configparser.RawConfigParser(delimiters=("=",), interpolation=None)
    parser.read_string(presets_cfg)
    sections = [s for s in parser.sections() if not s.endswith(".options") and parser[s].get("name") == f'"{preset}"']
    if len(sections) != 1 or f"{sections[0]}.options" not in parser:
        return None
    return parser[f"{sections[0]}.options"].get("variant/thread_support") == "true"


def served_headers(root: Path, build_arg: str | None) -> tuple[dict[str, str], list[str]]:
    """Headers the final Docker stage serves for `**` with this build arg, and what is wrong with the stage."""
    final_stage = (root / "web/Dockerfile").read_text().split("\nFROM ")[-1].splitlines()
    problems = [f"final stage lost `{line}`" for line in (DOCKER_ARG, DOCKER_COPY) if line not in final_stage]
    config = build_arg.removeprefix("SWS_CONFIG=") if build_arg else "sws.toml"
    toml_path = root / "web" / config
    if not toml_path.is_file():
        return {}, [*problems, f"no web/{config}"]
    tables = tomllib.loads(toml_path.read_text()).get("advanced", {}).get("headers", [])
    headers = {k.lower(): v for t in tables if t.get("source") == "**" for k, v in t.get("headers", {}).items()}
    return headers, problems


def pairing_problems(root: Path, preset: str | None, build_arg: str | None, want_threads: bool) -> list[str]:
    threads = preset_threads((root / "game/export_presets.cfg").read_text(), preset or "")
    headers, problems = served_headers(root, build_arg)
    if threads != want_threads:
        problems.append(f"preset {preset!r} has thread_support={threads}, want {want_threads}")
    if want_threads:
        problems += [f"missing {k}: {v}" for k, v in (COOP, COEP) if headers.get(k) != v]
    else:
        problems += [f"unexpected {k}" for k, _ in (COOP, COEP) if k in headers]
    return problems


def release_problems(workflow: str) -> list[str]:
    """The tag workflow must export the single-threaded preset and never choose the threaded config."""
    exports = re.findall(r"export_build\.sh\s+(\"[^\"]+\"|'[^']+'|\S+)\s+web/site/index\.html", workflow)
    problems = [] if [e.strip("\"'") for e in exports] == ["Web"] else [f"web exports {exports}, want exactly Web"]
    return problems + [f"release.yml mentions {m}" for m in ("sws-threads", "SWS_CONFIG") if m in workflow]


class DeployWebTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        (self.root / "tools").mkdir()
        shutil.copy(SCRIPT, self.root / "tools/deploy_web.sh")
        (self.root / "tools/export_build.sh").write_text(FAKE_EXPORT)
        (self.root / "game/data/maps").mkdir(parents=True)
        (self.root / "game/data/maps/NOTICE.md").write_text("")
        (self.root / "LICENSE").write_text("")
        (self.root / "game/audio").mkdir(parents=True)
        (self.root / "game/audio/CREDITS.md").write_text("")
        (self.root / "game/fonts").mkdir(parents=True)
        (self.root / "game/fonts/PublicSans-OFL.txt").write_text("")
        (self.root / "web/site").mkdir(parents=True)
        for name in ("game/export_presets.cfg", "web/Dockerfile", ".github/workflows/release.yml"):
            (self.root / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(REPO / name, self.root / name)
        for toml in (REPO / "web").glob("sws*.toml"):
            shutil.copy(toml, self.root / "web" / toml.name)
        (self.root / "web/site/old").write_text("")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        for name in ("fly", "curl", "godot"):
            (bin_dir / name).write_text(STUB.format(name=name))
            (bin_dir / name).chmod(0o755)
        self.log = self.root / "stub.log"
        self.env = {
            **os.environ,
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "GODOT_BIN": str(bin_dir / "godot"),
            "STUB_LOG": str(self.log),
        }

    def run_script(self, version: str | None, *args: str) -> subprocess.CompletedProcess[str]:
        line = f'config/version="{version}"\n' if version is not None else ""
        (self.root / "game/project.godot").write_text(f'[application]\n\nconfig/name="Wargrid"\n{line}')
        return subprocess.run(
            ["sh", str(self.root / "tools/deploy_web.sh"), *args],
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )

    def calls(self) -> list[str]:
        return self.log.read_text().splitlines() if self.log.exists() else []

    def route(self, version: str, *args: str) -> tuple[str | None, str | None]:
        """Run a deploy to the real-named app and return the exported preset and the docker build arg."""
        self.log.unlink(missing_ok=True)
        result = self.run_script(version, *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        fly = next(c for c in calls if c.startswith("fly "))
        self.assertIn(" -a wargrid-web-test " if args else " -a wargrid-web ", fly)
        preset = re.search(r"preset=\[(.*)\] out=", calls[0])
        arg = re.search(r"--build-arg (\S+)", fly)
        return (preset and preset[1]), (arg and arg[1])

    def edit(self, name: str, old: str, new: str) -> None:
        path = self.root / name
        text = path.read_text()
        self.assertIn(old, text)
        path.write_text(text.replace(old, new, 1))
        self.log.unlink(missing_ok=True)

    def set_threads(self, section: str, old: str, new: str) -> None:
        path = self.root / "game/export_presets.cfg"
        head, sep, tail = path.read_text().partition(f"[{section}.options]")
        self.assertIn(f"thread_support={old}", tail)
        path.write_text(head + sep + tail.replace(f"thread_support={old}", f"thread_support={new}", 1))

    def assert_refused(self, result: subprocess.CompletedProcess[str], needle: str) -> None:
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(needle, result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertTrue((self.root / "web/site/old").exists(), "refusal must not clear web/site")

    def test_test_target_deploys_the_test_app(self) -> None:
        result = self.run_script("0.7.0-dev", "test")
        self.assertEqual(result.returncode, 0, result.stderr)
        fly = [c for c in self.calls() if c.startswith("fly ")]
        self.assertEqual(len(fly), 1)
        self.assertIn(" -a wargrid-web-test ", fly[0])
        self.assertIn("https://wargrid-web-test.fly.dev/health", self.calls()[-1])

    def test_deploy_never_skips_the_licensed_audio(self) -> None:
        self.env["WARGRID_SYNTH_AUDIO"] = "1"
        result = self.run_script("0.7.0-dev", "test")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("export synth= preset=[Web Threads]", self.calls()[0])

    def test_production_deploys_the_production_app(self) -> None:
        result = self.run_script("0.7.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        fly = [c for c in self.calls() if c.startswith("fly ")]
        self.assertEqual(len(fly), 1)
        self.assertIn(" -a wargrid-web ", fly[0])
        self.assertIn("https://wargrid.blackcindergames.com/health", self.calls()[-1])

    def test_test_refuses_a_release_version(self) -> None:
        self.assert_refused(self.run_script("0.6.0", "test"), '"0.6.0"')

    def test_production_refuses_a_dev_version(self) -> None:
        self.assert_refused(self.run_script("0.7.0-dev"), '"0.7.0-dev"')

    def test_unknown_target_refuses(self) -> None:
        self.assert_refused(self.run_script("0.7.0-dev", "tset"), "usage: sh tools/deploy_web.sh [test|test-nothreads]")

    def test_rollback_refuses_a_release_version(self) -> None:
        self.assert_refused(self.run_script("0.6.0", "test-nothreads"), '"0.6.0"')

    def test_test_route_pairs_the_threaded_binary_with_isolation(self) -> None:
        preset, arg = self.route("0.7.0-dev", "test")
        self.assertEqual(preset, "Web Threads")
        self.assertEqual(pairing_problems(self.root, preset, arg, want_threads=True), [])

    def test_production_and_rollback_routes_pair_the_single_threaded_binary_with_no_isolation(self) -> None:
        for version, args in (("0.7.0", ()), ("0.7.0-dev", ("test-nothreads",))):
            with self.subTest(args=args):
                preset, arg = self.route(version, *args)
                self.assertEqual(pairing_problems(self.root, preset, arg, want_threads=False), [])

    def test_release_workflow_ships_the_default_pair(self) -> None:
        workflow = (self.root / ".github/workflows/release.yml").read_text()
        self.assertEqual(release_problems(workflow), [])
        self.assertEqual(pairing_problems(self.root, "Web", None, want_threads=False), [])

    def test_a_threaded_route_with_a_broken_pairing_is_rejected(self) -> None:
        threads = "web/sws-threads.toml"
        coop, coep = 'Cross-Origin-Opener-Policy = "same-origin"\n', 'Cross-Origin-Embedder-Policy = "require-corp"\n'
        fixtures = {
            "neither header": lambda: self.edit(threads, coop + coep, ""),
            "no COOP": lambda: self.edit(threads, coop, ""),
            "no COEP": lambda: self.edit(threads, coep, ""),
            "credentialless": lambda: self.edit(threads, "require-corp", "credentialless"),
            "wrong glob": lambda: self.edit(threads, 'source = "**"', 'source = "/index.html"'),
            "inline preset": lambda: self.set_threads("preset.11", "true", "false"),
            "default image served": lambda: self.edit("web/Dockerfile", DOCKER_COPY, "COPY sws.toml /sws.toml"),
        }
        for name, break_it in fixtures.items():
            with self.subTest(name):
                break_it()
                preset, arg = self.route("0.7.0-dev", "test")
                self.assertNotEqual(pairing_problems(self.root, preset, arg, want_threads=True), [])
                self.setUp()

    def test_a_single_threaded_route_with_a_broken_pairing_is_rejected(self) -> None:
        fixtures = {
            "both headers": lambda: shutil.copy(self.root / "web/sws-threads.toml", self.root / "web/sws.toml"),
            "threaded preset": lambda: self.set_threads("preset.9", "false", "true"),
            "wrong Docker default": lambda: self.edit("web/Dockerfile", DOCKER_ARG, "ARG SWS_CONFIG=sws-threads.toml"),
            "lost the final stage lines": lambda: self.edit("web/Dockerfile", DOCKER_ARG + "\n", ""),
        }
        for name, break_it in fixtures.items():
            with self.subTest(name):
                break_it()
                preset, arg = self.route("0.7.0-dev", "test-nothreads")
                self.assertNotEqual(pairing_problems(self.root, preset, arg, want_threads=False), [])
                self.assertNotEqual(pairing_problems(self.root, preset, None, want_threads=False), [])
                self.setUp()

    def test_a_release_workflow_that_ships_the_threaded_pair_is_rejected(self) -> None:
        workflow = (self.root / ".github/workflows/release.yml").read_text()
        for bad in (
            workflow.replace("export_build.sh Web web", 'export_build.sh "Web Threads" web'),
            workflow.replace('/web/Dockerfile"', '/web/Dockerfile" --build-arg SWS_CONFIG=sws-threads.toml', 1),
        ):
            self.assertNotEqual(bad, workflow)
            self.assertNotEqual(release_problems(bad), [])

    def test_missing_version_refuses_both_targets(self) -> None:
        self.assert_refused(self.run_script(None, "test"), 'config/version is ""')
        self.assert_refused(self.run_script(None), 'config/version is ""')


if __name__ == "__main__":
    unittest.main()
