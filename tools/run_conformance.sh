#!/bin/sh
# usage: run_conformance.sh — runs the relay protocol conformance suite (protocol/conformance) against the relay,
# one fresh relay per profile. Relay binary: $WARGRID_RELAY_BIN, else built from relay/. Prints CONFORMANCE PASSED <cases> or exits 1.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
out=$(mktemp -d)
relay_bin=${WARGRID_RELAY_BIN:-$out/relay}
relay_pid=""
cleanup() { [ -z "$relay_pid" ] || kill "$relay_pid" 2>/dev/null; }
trap cleanup EXIT HUP INT TERM

[ -n "$WARGRID_RELAY_BIN" ] || (cd "$repo_root/relay" && go build -o "$relay_bin" .) || { echo "CONFORMANCE FAILED: relay build"; exit 1; }
(cd "$repo_root/protocol/conformance" && go build -o "$out/conformance" .) || { echo "CONFORMANCE FAILED: suite build"; exit 1; }

total=0
for p in default: delay:WARGRID_TEST_DELAY_MS=250 silence:WARGRID_SILENCE_MS=300,WARGRID_HELLO_MS=300,WARGRID_LOBBY_MS=1500,WARGRID_LOBBY_CAP_MS=3000 limits:WARGRID_CLIENT_IP_HEADER=X-Wargrid-Test-Ip global:WARGRID_CLIENT_IP_HEADER=X-Wargrid-Test-Ip; do
  profile=${p%%:*}; envset=$(echo "${p#*:}" | tr , ' ')
  port=$(${PYTHON:-python3} -c 'import socket;s=socket.socket();s.bind(("",0));print(s.getsockname()[1])')
  # shellcheck disable=SC2086
  env PORT=$port $envset "$relay_bin" >"$out/relay-$profile.log" 2>&1 &
  relay_pid=$!
  i=0
  until curl -sf "http://127.0.0.1:$port/health" >/dev/null; do
    i=$((i + 1)); [ $i -lt 100 ] || { echo "CONFORMANCE FAILED: relay did not start ($profile), logs: $out"; exit 1; }
    sleep 0.2
  done
  "$out/conformance" -url "ws://127.0.0.1:$port/ws" -profile "$profile" -silence 300ms -hello 300ms -lobby 1500ms -lobbycap 3s >"$out/$profile.txt" 2>&1
  grep '^FAIL' "$out/$profile.txt"
  case $profile in
    limits | global) ;;
    *) ! grep 'WARN limit rule=' "$out/relay-$profile.log" || { echo "CONFORMANCE FAILED: $profile tripped a relay limit, logs: $out"; exit 1; } ;;
  esac
  summary=$(grep '^CONFORM ' "$out/$profile.txt") || { echo "CONFORMANCE FAILED: no summary ($profile), logs: $out"; exit 1; }
  echo "$summary"
  case $summary in
    *" 0 failed") ;;
    *) echo "CONFORMANCE FAILED: $profile, logs: $out"; exit 1 ;;
  esac
  cases=$(echo "$summary" | sed 's/.*: \([0-9]*\) cases.*/\1/')
  [ "$cases" -gt 0 ] || { echo "CONFORMANCE FAILED: zero cases ($profile)"; exit 1; }
  total=$((total + cases))
  kill "$relay_pid"; wait "$relay_pid" 2>/dev/null; relay_pid=""
done
echo "CONFORMANCE PASSED $total"
rm -rf "$out"
