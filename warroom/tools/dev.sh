#!/bin/sh
# Dev loop: regenerates templ on save, restarts the server and reloads the browser through templ's proxy.
# Rounds are read per request, so YAML edits need only a reload. Open http://127.0.0.1:7331/ (the proxy).
set -eu
cd "$(dirname "$0")/.."
port=${WARROOM_PORT:-8780}
# The proxy forwards to the app and injects the reload script.
exec go tool templ generate --watch --open-browser=false --proxy="http://127.0.0.1:$port" --cmd="go run ."
