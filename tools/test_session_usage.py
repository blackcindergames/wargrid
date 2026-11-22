import io
import json
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import session_usage as usage


def claude_lines():
    def request(rid, read, created, output, model="claude-sonnet-5-5"):
        return {
            "type": "assistant",
            "requestId": rid,
            "message": {
                "model": model,
                "usage": {
                    "input_tokens": 10,
                    "cache_read_input_tokens": read,
                    "cache_creation_input_tokens": created,
                    "output_tokens": output,
                },
            },
        }

    return [
        {"type": "user", "message": {"content": "hello"}},
        request("r1", 1000, 90, 5),
        request("r1", 1000, 90, 5),
        request("r2", 3000, 0, 7, model="claude-opus-5-5"),
    ]


def codex_lines(thread, parent=None, totals=(500, 400, 9), last_input=300):
    source = {"subagent": {"thread_spawn": {"parent_thread_id": parent}}} if parent else "vscode"
    lines = [
        {"type": "session_meta", "payload": {"id": thread, "cwd": "/x/wargrid", "source": source}},
        {"type": "turn_context", "payload": {"model": "gpt-6.1-sol"}},
    ]
    for step in (1, 2):
        lines.append(
            {
                "type": "event_msg",
                "payload": {
                    "type": "token_count",
                    "info": {
                        "total_token_usage": {
                            "input_tokens": totals[0] * step // 2,
                            "cached_input_tokens": totals[1] * step // 2,
                            "output_tokens": totals[2],
                        },
                        "last_token_usage": {"input_tokens": last_input},
                    },
                },
            }
        )
    return lines


def write(directory, name, lines):
    path = Path(directory) / name
    path.write_text("\n".join(json.dumps(line) for line in lines) + "\n")
    return path


class SessionUsageTests(unittest.TestCase):
    def test_claude_counts_each_request_once(self):
        with tempfile.TemporaryDirectory() as directory:
            result = usage.claude(write(directory, "s.jsonl", claude_lines()))
        self.assertEqual(result["requests"], 2)
        self.assertEqual(result["processed"], (10 + 1000 + 90) + (10 + 3000))
        self.assertEqual(result["output"], 12)
        self.assertEqual((result["first_context"], result["max_context"]), (1100, 3010))
        self.assertEqual(result["models"], {"claude-sonnet-5-5": 1, "claude-opus-5-5": 1})

    def test_codex_uses_last_cumulative_total(self):
        with tempfile.TemporaryDirectory() as directory:
            result = usage.codex(write(directory, "rollout-a.jsonl", codex_lines("a")))
        self.assertEqual(
            (result["processed"], result["cached"], result["output"], result["requests"]), (500, 400, 9, 2)
        )
        self.assertEqual((result["thread"], result["parent"], result["max_context"]), ("a", None, 300))

    def test_codex_children_roll_up_to_root(self):
        with tempfile.TemporaryDirectory() as directory:
            files = [
                write(directory, "rollout-root.jsonl", codex_lines("root")),
                write(directory, "rollout-child.jsonl", codex_lines("child", parent="root", totals=(100, 50, 1))),
                write(directory, "rollout-grand.jsonl", codex_lines("grand", parent="child", totals=(20, 10, 1))),
            ]
            groups = usage.group_codex([usage.codex(path) for path in files])
        self.assertEqual(list(groups), ["root"])
        self.assertEqual((groups["root"]["processed"], groups["root"]["threads"]), (620, 3))

    def test_detects_format_and_prints_total(self):
        with tempfile.TemporaryDirectory() as directory:
            claude_file = write(directory, "s.jsonl", claude_lines())
            codex_file = write(directory, "rollout-a.jsonl", codex_lines("a"))
            out = io.StringIO()
            self.assertEqual(usage.main([str(claude_file), str(codex_file)], out), 0)
        text = out.getvalue()
        self.assertIn("claude s.jsonl", text)
        self.assertIn("codex a", text)
        self.assertIn("TOTAL processed=4610", text)

    def test_lanes_split_tokens_by_day_and_lines_by_area(self):
        with tempfile.TemporaryDirectory() as directory:
            lines = claude_lines()
            lines[1]["timestamp"] = "2026-11-21T10:00:00Z"
            lines[3]["timestamp"] = "2026-11-22T10:00:00Z"
            by_day = usage.claude_by_day(write(directory, "s.jsonl", lines))
        self.assertEqual(sorted(by_day.values()), [1100, 3010])
        self.assertEqual(
            [usage.area(path) for path in ("game/scripts/a.gd", "game/tests/t.gd", "relay/a_test.go", "docs/x.md")],
            ["game", "tests", "tests", "docs"],
        )
        self.assertEqual([usage.area(path) for path in ("tools/roadmap.py", "README.md")], ["tools", "docs"])

    def test_landed_skips_binary_and_generated_files_and_follows_renames(self):
        log = "@2026-11-22\n3\t1\tgame/a.gd\n-\t-\tdocs/x.webp\n5\t0\t{docs => game}/b.gd\n9\t0\twarroom/x_templ.go\n2\t0\tdocs/old.md => tools/new.py\n"
        self.assertEqual(dict(usage.landed(log)[date(2026, 11, 22)]), {"game": 8, "tools": 2})

    def test_request_seen_in_two_files_counts_once(self):
        with tempfile.TemporaryDirectory() as directory:
            lines = claude_lines()
            for line in lines[1:]:
                line["timestamp"] = "2026-11-22T10:00:00Z"
            seen: set = set()
            first = usage.claude_by_day(write(directory, "a.jsonl", lines), seen)
            second = usage.claude_by_day(write(directory, "b.jsonl", lines), seen)
        self.assertEqual((sum(first.values()), sum(second.values())), (1100 + 3010, 0))

    def test_unknown_file_is_an_error(self):
        with tempfile.TemporaryDirectory() as directory:
            path = write(directory, "other.jsonl", [{"type": "nothing"}])
            out = io.StringIO()
            self.assertEqual(usage.main([str(path)], out), 1)


if __name__ == "__main__":
    unittest.main()
