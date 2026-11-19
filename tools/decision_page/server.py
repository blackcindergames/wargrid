"""Decision page server: serves a site root, records picks through a guarded POST /pick and reads them back."""

import contextlib
import http.server
import json
import os
import pathlib
import re
import socket
import tempfile
import threading
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
MAX_BODY = 8192
MAX_KEY = 160
# Public URL: caps what an anonymous client can grow the volume to.
MAX_KEYS = 500
REQUEST_SECONDS = 15
KEY_RE = re.compile(r"([a-z0-9-]+):[A-Za-z0-9._:-]+")
PICK_RE = re.compile(r"[A-Za-z]{1,16}")
PREFIX_RE = re.compile(r"^\s*prefix:\s*['\"]([a-z0-9-]+)['\"]", re.MULTILINE)
APP_PATH = "/tools/decision_page/"
LOCK = threading.Lock()


def site_root() -> pathlib.Path:
    return pathlib.Path(os.environ.get("DECISION_ROOT") or HERE.parents[1])


def picks_path() -> pathlib.Path:
    return pathlib.Path(os.environ.get("DECISION_PICKS") or HERE / "picks.json")


def round_prefixes(rounds: pathlib.Path) -> set[str]:
    prefixes = set()
    for file in rounds.glob("*/round.js"):
        found = PREFIX_RE.search(file.read_text(encoding="utf-8"))
        prefixes.add(found.group(1) if found else file.parent.name)
    return prefixes


def read_picks(path: pathlib.Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    # A hand-seeded file of another shape would be overwritten unseen on the next pick.
    if not isinstance(data, dict) or not all(isinstance(v, dict) for v in data.values()):
        raise ValueError(f"{path}: not an object of entries")
    return data


def write_atomic(path: pathlib.Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".picks-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as out:
            json.dump(data, out, indent=1)
            out.flush()
            os.fsync(out.fileno())
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def parse_pick(raw: bytes, prefixes: set[str]) -> tuple[str, dict[str, str | None]] | None:
    try:
        body = json.loads(raw)
    except ValueError:
        return None
    if not isinstance(body, dict):
        return None
    key, pick, note = body.get("key"), body.get("pick"), body.get("note", "")
    if not isinstance(key, str) or len(key) > MAX_KEY:
        return None
    found = KEY_RE.fullmatch(key)
    # Public URL: only keys of a round the site ships may be written.
    if not found or found.group(1) not in prefixes:
        return None
    if not (pick is None or (isinstance(pick, str) and PICK_RE.fullmatch(pick))) or not isinstance(note, str):
        return None
    return key, {"pick": pick, "note": note}


def record(key: str, entry: dict[str, str | None]) -> bool:
    path = picks_path()
    with LOCK:
        data = read_picks(path)
        if key not in data and len(data) >= MAX_KEYS:
            return False
        data[key] = entry
        write_atomic(path, data)
        return True


class Handler(http.server.SimpleHTTPRequestHandler):
    # A client that stalls mid-body would otherwise hold its thread forever.
    timeout = 15

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, directory=str(site_root()), **kwargs)

    def setup(self) -> None:
        super().setup()
        # The per-read timeout restarts on every byte, so a trickling client needs a deadline for the whole request.
        self.deadline = threading.Timer(REQUEST_SECONDS, self.cut)
        self.deadline.daemon = True
        self.deadline.start()

    def cut(self) -> None:
        with contextlib.suppress(OSError):
            self.connection.shutdown(socket.SHUT_RDWR)

    def finish(self) -> None:
        self.deadline.cancel()
        super().finish()

    def send_plain(self, code: int, body: bytes, kind: str = "text/plain") -> None:
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def picks_json(self) -> bytes:
        with LOCK:
            return json.dumps(read_picks(picks_path())).encode()

    def send_picks(self, script: bool) -> None:
        try:
            body = self.picks_json()
        except (OSError, ValueError):
            self.send_error(500)
            return
        if script:
            # A script, not a fetch: it holds the load event, so headless screenshots see restored picks.
            self.send_plain(200, b"DP.saved(" + body + b");\n", "text/javascript")
        else:
            self.send_plain(200, body, "application/json")

    def do_GET(self) -> None:
        self.deadline.cancel()
        if self.path == "/health":
            self.send_plain(200, b"ok")
        elif self.path in ("/picks.json", "/picks.js"):
            self.send_picks(self.path == "/picks.js")
        elif self.path in ("/", "/index.html"):
            self.send_response(302)
            self.send_header("Location", APP_PATH)
            self.end_headers()
        else:
            super().do_GET()

    def do_POST(self) -> None:
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = -1
        if self.path != "/pick" or not 0 < length <= MAX_BODY:
            self.send_error(400)
            return
        raw = self.rfile.read(length)
        self.deadline.cancel()
        if len(raw) < length:
            return
        parsed = parse_pick(raw, round_prefixes(site_root() / APP_PATH.strip("/") / "rounds"))
        if not parsed:
            self.send_error(400)
            return
        try:
            stored = record(*parsed)
        except (OSError, ValueError):
            self.send_error(500)
            return
        if not stored:
            self.send_error(507)
            return
        self.send_response(204)
        self.end_headers()

    def log_message(self, format: str, *args: Any) -> None:
        pass


def main() -> None:
    host = os.environ.get("DECISION_HOST", "127.0.0.1")
    port = int(os.environ.get("DECISION_PORT", "8770"))
    print(f"decision page on http://{host}:{port}{APP_PATH}", flush=True)
    http.server.ThreadingHTTPServer((host, port), Handler).serve_forever()


if __name__ == "__main__":
    main()
