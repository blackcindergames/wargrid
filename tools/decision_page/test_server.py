import http.client
import http.server
import json
import os
import pathlib
import shutil
import socket
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import server


class ServerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        rounds = self.root / "tools/decision_page/rounds"
        (rounds / "demo").mkdir(parents=True)
        (rounds / "demo/round.js").write_text("DP.round({\n  id: 'demo',\n  steps: [],\n});\n")
        (rounds / "gate-2").mkdir()
        (rounds / "gate-2/round.js").write_text("DP.round({\n  id: 'gate-2',\n  prefix: 'gate2',\n});\n")
        self.picks = self.root / "data/picks.json"
        env = {"DECISION_ROOT": str(self.root), "DECISION_PICKS": str(self.picks)}
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()
        self.addCleanup(self.httpd.server_close)
        self.addCleanup(self.httpd.shutdown)

    def request(self, method: str, path: str, body: bytes | None = None) -> tuple[int, bytes]:
        conn = http.client.HTTPConnection("127.0.0.1", self.httpd.server_address[1], timeout=5)
        self.addCleanup(conn.close)
        conn.request(method, path, body=body)
        resp = conn.getresponse()
        return resp.status, resp.read()

    def post(self, data: object) -> int:
        return self.request("POST", "/pick", json.dumps(data).encode())[0]

    def test_health_is_200(self) -> None:
        self.assertEqual(self.request("GET", "/health"), (200, b"ok"))

    def test_good_key_is_204_and_written(self) -> None:
        self.assertEqual(self.post({"key": "demo:pictures", "pick": "B", "note": "fine"}), 204)
        self.assertEqual(self.post({"key": "gate2:look:slab", "pick": None, "note": "x"}), 204)
        saved = json.loads(self.picks.read_text())
        self.assertEqual(saved["demo:pictures"], {"pick": "B", "note": "fine"})
        self.assertEqual(saved["gate2:look:slab"], {"pick": None, "note": "x"})
        self.assertEqual(json.loads(self.request("GET", "/picks.json")[1]), saved)

    def test_bad_keys_are_400_and_not_written(self) -> None:
        bad = [
            {"key": "other:x", "pick": "A"},
            {"key": "gate-2:x", "pick": "A"},
            {"key": "demo:", "pick": "A"},
            {"key": "demo:../x", "pick": "A"},
            {"key": 5, "pick": "A"},
            {"pick": "A"},
            {"key": "demo:x", "pick": 3},
            {"key": "demo:" + "x" * server.MAX_KEY, "pick": "A"},
            ["demo:x"],
        ]
        for body in bad:
            with self.subTest(body=body):
                self.assertEqual(self.post(body), 400)
        self.assertEqual(self.request("POST", "/pick", b"not json")[0], 400)
        self.assertEqual(self.request("POST", "/other", b'{"key": "demo:x"}')[0], 400)
        self.assertFalse(self.picks.exists())

    def test_bad_values_are_400(self) -> None:
        bad = [
            {"key": "demo:x\n", "pick": "A"},
            {"key": "demo:x", "pick": "A", "note": 5},
            {"key": "demo:x", "pick": "<script>"},
            {"key": "demo:x", "pick": "A" * 17},
            {"key": "demo:x", "pick": ""},
        ]
        for body in bad:
            with self.subTest(body=body):
                self.assertEqual(self.post(body), 400)
        self.assertFalse(self.picks.exists())

    def test_answer_words_are_204(self) -> None:
        for pick in ("neither", "yes", "change", "pass", "changes"):
            with self.subTest(pick=pick):
                self.assertEqual(self.post({"key": "demo:" + pick, "pick": pick}), 204)

    def post_with_length(self, length: str | None) -> int:
        conn = http.client.HTTPConnection("127.0.0.1", self.httpd.server_address[1], timeout=5)
        self.addCleanup(conn.close)
        conn.putrequest("POST", "/pick")
        if length is not None:
            conn.putheader("Content-Length", length)
        conn.endheaders()
        return conn.getresponse().status

    def test_missing_or_bad_length_is_400(self) -> None:
        for length in (None, "abc", "-1"):
            with self.subTest(length=length):
                self.assertEqual(self.post_with_length(length), 400)

    def test_new_keys_past_the_cap_are_507(self) -> None:
        with mock.patch.object(server, "MAX_KEYS", 2):
            self.assertEqual(self.post({"key": "demo:a", "pick": "A"}), 204)
            self.assertEqual(self.post({"key": "demo:b", "pick": "A"}), 204)
            self.assertEqual(self.post({"key": "demo:c", "pick": "A"}), 507)
            self.assertEqual(self.post({"key": "demo:a", "pick": "B"}), 204)
        self.assertEqual(sorted(json.loads(self.picks.read_text())), ["demo:a", "demo:b"])

    def test_lone_surrogate_note_is_stored_and_read_back(self) -> None:
        raw = b'{"key": "demo:x", "pick": "A", "note": "\\ud800"}'
        self.assertEqual(self.request("POST", "/pick", raw)[0], 204)
        status, body = self.request("GET", "/picks.json")
        self.assertEqual((status, json.loads(body)["demo:x"]["note"]), (200, "\ud800"))

    def test_failed_write_is_500_and_keeps_the_file(self) -> None:
        self.assertEqual(self.post({"key": "demo:a", "pick": "A"}), 204)
        with mock.patch.object(server, "write_atomic", side_effect=OSError("disk full")):
            self.assertEqual(self.post({"key": "demo:b", "pick": "B"}), 500)
        self.assertEqual(json.loads(self.picks.read_text()), {"demo:a": {"pick": "A", "note": ""}})

    def test_picks_js_wraps_the_picks(self) -> None:
        self.assertEqual(self.post({"key": "demo:a", "pick": "A"}), 204)
        status, body = self.request("GET", "/picks.js")
        self.assertEqual(status, 200)
        self.assertTrue(body.startswith(b"DP.saved("))
        self.assertEqual(json.loads(body[len(b"DP.saved(") : -3]), {"demo:a": {"pick": "A", "note": ""}})

    def test_concurrent_writers_all_land(self) -> None:
        # Straight to record(): 20 sockets at once overflow the listen backlog before LOCK is reached.
        threads = [
            threading.Thread(target=server.record, args=(f"demo:k{i}", {"pick": "A", "note": ""})) for i in range(20)
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.assertEqual(len(json.loads(self.picks.read_text())), 20)

    def test_stalled_body_is_dropped(self) -> None:
        self.assertIsInstance(server.Handler.timeout, (int, float))
        with (
            mock.patch.object(server.Handler, "timeout", 0.3),
            socket.create_connection(("127.0.0.1", self.httpd.server_address[1]), timeout=5) as sock,
        ):
            sock.sendall(b"POST /pick HTTP/1.1\r\nHost: x\r\nContent-Length: 100\r\n\r\n{")
            self.assertEqual(sock.recv(1024), b"")

    def test_trickled_request_is_cut_at_the_deadline(self) -> None:
        with (
            mock.patch.object(server, "REQUEST_SECONDS", 0.5),
            socket.create_connection(("127.0.0.1", self.httpd.server_address[1]), timeout=0.1) as sock,
        ):
            sock.sendall(b"POST /pick HTTP/1.1\r\nHost: x\r\nContent-Length: 100\r\n\r\n")
            start = time.monotonic()
            closed = False
            while not closed and time.monotonic() - start < 5:
                try:
                    sock.sendall(b" ")
                    closed = sock.recv(1024) == b""
                except TimeoutError:
                    pass
                except OSError:
                    closed = True
            self.assertTrue(closed)
            self.assertLess(time.monotonic() - start, 3)
        self.assertFalse(self.picks.exists())

    def test_unreadable_picks_file_is_500_and_kept(self) -> None:
        self.picks.parent.mkdir(parents=True)
        pick = json.dumps({"key": "demo:a", "pick": "A"}).encode()
        for text in ("{not json", '["demo:a"]', '{"demo:a": null}'):
            self.picks.write_text(text)
            for method, path, body in (
                ("GET", "/picks.json", None),
                ("GET", "/picks.js", None),
                ("POST", "/pick", pick),
            ):
                with self.subTest(text=text, path=path):
                    self.assertEqual(self.request(method, path, body)[0], 500)
            self.assertEqual(self.picks.read_text(), text)

    def test_shipped_rounds_keep_their_prefixes(self) -> None:
        rounds = server.HERE / "rounds"
        self.assertLessEqual({"p2-3a1-gate", "p2-3a1-gate2"}, server.round_prefixes(rounds))
        for file in rounds.glob("*/round.js"):
            text = file.read_text(encoding="utf-8")
            if "prefix" in text:
                with self.subTest(round=file.parent.name):
                    self.assertRegex(text, server.PREFIX_RE)

    def test_oversize_body_is_400(self) -> None:
        note = "x" * server.MAX_BODY
        self.assertEqual(self.post({"key": "demo:x", "pick": "A", "note": note}), 400)
        self.assertFalse(self.picks.exists())

    def test_write_is_atomic(self) -> None:
        self.assertEqual(self.post({"key": "demo:a", "pick": "A"}), 204)
        with mock.patch.object(server.json, "dump", side_effect=OSError("disk full")), self.assertRaises(OSError):
            server.record("demo:b", {"pick": "B", "note": ""})
        self.assertEqual(json.loads(self.picks.read_text()), {"demo:a": {"pick": "A", "note": ""}})
        self.assertEqual([p.name for p in self.picks.parent.iterdir()], ["picks.json"])

    def test_root_redirects_to_app(self) -> None:
        conn = http.client.HTTPConnection("127.0.0.1", self.httpd.server_address[1], timeout=5)
        self.addCleanup(conn.close)
        conn.request("GET", "/")
        resp = conn.getresponse()
        self.assertEqual((resp.status, resp.getheader("Location")), (302, server.APP_PATH))


if __name__ == "__main__":
    unittest.main()
