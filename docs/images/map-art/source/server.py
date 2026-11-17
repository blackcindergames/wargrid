"""Serves the repository root for the map art page; records picks, the shapes export and page reports."""

import http.server
import json
import pathlib
import re
import urllib.parse
from typing import Any

SOURCE = pathlib.Path(__file__).resolve().parent
ROOT = SOURCE.parents[3]
PICKS = SOURCE / "picks.json"
EXPORT = SOURCE.parent / "shapes-picked.json"
REPORTS = ROOT / "build" / "map-art"
NAME_RE = re.compile(r"^[a-z0-9-]+$")


def write_atomic(path: pathlib.Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_bytes(data)
    tmp.replace(path)


def record_pick(raw: bytes) -> None:
    body = json.loads(raw)
    data = json.loads(PICKS.read_text()) if PICKS.exists() else {}
    data[str(body["key"])] = {"pick": body.get("pick"), "note": body.get("note", "")}
    write_atomic(PICKS, json.dumps(data, indent=1).encode())


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def reply(self, code: int) -> None:
        self.send_response(code)
        self.end_headers()

    def do_POST(self) -> None:
        url = urllib.parse.urlsplit(self.path)
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        try:
            if url.path == "/pick":
                record_pick(raw)
            elif url.path == "/export":
                json.loads(raw)
                write_atomic(EXPORT, raw)
            elif url.path == "/report":
                name = urllib.parse.parse_qs(url.query).get("name", [""])[0]
                if not NAME_RE.match(name):
                    return self.reply(400)
                write_atomic(REPORTS / (name + ".txt"), raw)
            else:
                return self.reply(400)
        except (ValueError, KeyError, TypeError):
            return self.reply(400)
        self.reply(204)

    def log_message(self, format: str, *args: Any) -> None:
        pass


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", 8769), Handler).serve_forever()
