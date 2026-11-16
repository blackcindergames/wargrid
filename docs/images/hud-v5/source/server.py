"""Serves the repository root for the HUD v5 mock-up and records picks and the layout export."""

import http.server
import json
import pathlib
from typing import Any

SOURCE = pathlib.Path(__file__).resolve().parent
ROOT = SOURCE.parents[3]
PICKS = SOURCE / "picks.json"
LAYOUT = SOURCE.parent / "layout.json"


def record_pick(raw: bytes) -> None:
    body = json.loads(raw)
    data = json.loads(PICKS.read_text()) if PICKS.exists() else {}
    data[body["key"]] = {"pick": body.get("pick"), "note": body.get("note", "")}
    PICKS.write_text(json.dumps(data, indent=1))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_POST(self) -> None:
        raw = self.rfile.read(int(self.headers["Content-Length"]))
        if self.path == "/layout":
            LAYOUT.write_bytes(raw)
        else:
            record_pick(raw)
        self.send_response(204)
        self.end_headers()

    def log_message(self, format: str, *args: Any) -> None:
        pass


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", 8767), Handler).serve_forever()
