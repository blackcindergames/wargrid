"""Fly entry for the gate click page: server.py's handler on 0.0.0.0:8080 with a health check and a guarded /pick."""

import http.server
import json
import sys

sys.path.insert(0, "/app/docs/images/hud-v5/source")
import server  # noqa: E402

MAX_BODY = 8192


class Handler(server.Handler):
    def do_GET(self) -> None:
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return
        if self.path == "/":
            self.send_response(302)
            self.send_header("Location", "/docs/images/hud-v5/source/p2-3a1-gate.html#round=2")
            self.end_headers()
            return
        super().do_GET()

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        if self.path != "/pick" or length > MAX_BODY:
            self.send_error(400)
            return
        raw = self.rfile.read(length)
        try:
            key = json.loads(raw)["key"]
        except (ValueError, KeyError, TypeError):
            self.send_error(400)
            return
        # Public URL: only gate keys may be written.
        if not str(key).startswith("p2-3a1-gate"):
            self.send_error(400)
            return
        server.record_pick(raw)
        self.send_response(204)
        self.end_headers()


http.server.ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
