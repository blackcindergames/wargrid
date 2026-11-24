#!/bin/sh
# usage: run_netplay.sh match|rematch|kill|left-mid|left-mid-pump|trio-play-on|trio-left-first|trio-result|stall|silent|spike|perturb|version|maps|map-mismatch|relay-down|relay-term|proxy-clean|proxy-burst|proxy-reset|proxy-blackhole
scenario=$1
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
out=${NETPLAY_OUT:-$(mktemp -d)}
mkdir -p "$out" || exit 1
client=${WARGRID_CLIENT:-"godot --headless --path $repo_root/game"}
relay_bin=$WARGRID_RELAY_BIN
free_port() { ${PYTHON:-python3} -c 'import socket;s=socket.socket();s.bind(("",0));print(s.getsockname()[1])'; }
port=$(free_port)
url=${WARGRID_RELAY_URL:-ws://127.0.0.1:$port/ws}
remote=${WARGRID_RELAY_URL:+1}
netfault_bin=${WARGRID_NETFAULT_BIN:-}
url1=""
url2=""
pids=""
started=$(${PYTHON:-python3} -c 'import time;print(time.time())')

cleanup() { for p in $pids; do kill -9 "$p" 2>/dev/null; done; }
trap cleanup EXIT HUP INT TERM
fail() {
  echo "NETPLAY FAILED $scenario: $*"; echo "logs: $out"
  if [ -n "$url1" ]; then
    echo "repro: ${WARGRID_RELAY_BIN:+WARGRID_RELAY_BIN=$WARGRID_RELAY_BIN }${WARGRID_NETFAULT_BIN:+WARGRID_NETFAULT_BIN=$WARGRID_NETFAULT_BIN }${WARGRID_CLIENT:+WARGRID_CLIENT=\"$WARGRID_CLIENT\" }NETPLAY_OUT=$out-repro sh tools/run_netplay.sh $scenario"
  fi
  if [ -e "$out/proxy-seat1.log" ]; then
    grep -h 'NETFAULT' "$out"/proxy-seat*.log
    cat "$out"/proxy-seat*.out
    ! grep -q ' exit cap' "$out"/proxy-seat*.log || echo "proxy life cap hit"
  fi
  exit 1
}
ms() { ${PYTHON:-python3} -c 'import time;print(int(time.time()*1000))'; }

start_relay() {
  [ -z "$remote" ] || return 0
  if [ -z "$relay_bin" ]; then
    relay_bin=$out/relay
    (cd "$repo_root/relay" && go build -o "$relay_bin" .) || fail "relay build failed"
  fi
  env PORT="$port" "$@" "$relay_bin" >"$out/relay.log" 2>&1 &
  relay_pid=$!
  pids="$pids $relay_pid"
  i=0
  until curl -sf "http://127.0.0.1:$port/health" >/dev/null; do
    i=$((i + 1)); [ $i -lt 100 ] || fail "relay did not start"
    sleep 0.2
  done
}

# start_proxy N FAULTS: one netfault for seat N in front of the relay; the URL it serves lands in $url1/$url2
start_proxy() {
  proxy_port=$(free_port)
  : >"$out/proxy-seat$1.log"
  "$netfault_bin" -listen "127.0.0.1:$proxy_port" -target "127.0.0.1:$port" -log "$out/proxy-seat$1.log" -faults "$2" >"$out/proxy-seat$1.out" 2>&1 &
  proxy_pid=$!
  pids="$pids $proxy_pid"
  i=0
  # The proxy takes one connection only, so a connect probe would use it up: wait for its listen line.
  until grep -q ' listen ' "$out/proxy-seat$1.log"; do
    kill -0 "$proxy_pid" 2>/dev/null || fail "proxy $1 exited at start"
    i=$((i + 1)); [ $i -lt 100 ] || fail "proxy $1 did not start"
    sleep 0.2
  done
  if [ "$1" = 1 ]; then url1=ws://127.0.0.1:$proxy_port/ws; else url2=ws://127.0.0.1:$proxy_port/ws; fi
}

start_proxies() { # FAULTS_SEAT1 FAULTS_SEAT2
  if [ -z "$netfault_bin" ]; then
    netfault_bin=$out/netfault
    (cd "$repo_root/tools/netfault" && go build -o "$netfault_bin" .) || fail "netfault build failed"
  fi
  start_proxy 1 "$1"
  start_proxy 2 "$2"
}

# Both seats must have connected through their proxy, or a fault scenario proves nothing.
proxies_accepted() {
  for n in 1 2; do grep -q ' accept ' "$out/proxy-seat$n.log" || fail "no traffic through seat $n's proxy (no accept line)"; done
}

# proxy_ms N EVENT: unix ms of the first EVENT line in seat N's proxy log
proxy_ms() { awk -v e="$2" '$4 == e {print $2; exit}' "$out/proxy-seat$1.log"; }

# between LABEL VALUE LOW HIGH
between() { [ "$2" -ge "$3" ] && [ "$2" -le "$4" ] || fail "$1: $2 is outside $3 to $4"; }

# same_prefix A B: the seats stop at different ticks when one leaves, so compare the rows both have
same_prefix() {
  n1=$(($(wc -l <"$1"))); n2=$(($(wc -l <"$2")))
  n=$n1; [ "$n2" -ge "$n1" ] || n=$n2
  [ "$n" -gt 0 ] || fail "no shared hash rows"
  head -n "$n" "$1" >"$out/prefix-1.tsv"; head -n "$n" "$2" >"$out/prefix-2.tsv"
  same_hashes "$out/prefix-1.tsv" "$out/prefix-2.tsv"
}

# start_client NAME ARGS...: logs to $out/NAME.log, pid in $pid
start_client() {
  name=$1; shift
  # shellcheck disable=SC2086
  $client -- --netclient --relay "$url" --uncapped --hash-log "$out/$name.tsv" --command-log "$out/$name.cmd" --report-dir "$out" "$@" >"$out/$name.log" 2>&1 &
  pid=$!
  pids="$pids $pid"
}

# shellcheck disable=SC2086 # $1 and $2 are flag lists, split on purpose
start_pair() { # EXTRA_SEAT1 ... -- EXTRA_SEAT2 ...
  rm -f "$out/code"
  [ -z "$url1" ] || url=$url1
  start_client s1 --match new --code-file "$out/code" --seat-script human $1
  pid1=$pid
  i=0
  until [ -s "$out/code" ]; do
    i=$((i + 1)); [ $i -lt 100 ] || fail "no match code"
    sleep 0.2
  done
  [ -z "$url2" ] || url=$url2
  start_client s2 --match "$(cat "$out/code")" --seat-script opponent $2
  pid2=$pid
}

# shellcheck disable=SC2086 # $1 to $3 are flag lists, split on purpose
start_trio() { # EXTRA_SEAT1 EXTRA_SEAT2 EXTRA_SEAT3 (each one quoted word)
  start_pair "--map broken_crown --seat-script idle $1" "--map broken_crown --seat-script idle $2"
  i=0
  until grep -q '^NETCLIENT WELCOME SEAT 2 ' "$out/s2.log"; do
    i=$((i + 1)); [ $i -lt 100 ] || fail "seat 2 did not join"
    sleep 0.2
  done
  start_client s3 --match "$(cat "$out/code")" --map broken_crown --seat-script idle $3
  pid3=$pid
}

# Every client still running at the defeat tick must have run the hook, and all three got three starts.
trio_checks() { # NAME... (clients that reach tick 300)
  for name in "$@"; do
    grep -q '^NETCLIENT DEFEAT 2 AT 300$' "$out/$name.log" || fail "$name: no DEFEAT 2 AT 300"
  done
  for name in s1 s2 s3; do
    grep -q '^NETCLIENT MAP broken_crown SEED [^ ]* STARTS [^,]*,[^,]*,[^,]*$' "$out/$name.log" || fail "$name: no three-start MAP line"
  done
  same_prefix "$out/s1.tsv" "$out/s2.tsv"; same_prefix "$out/s1.tsv" "$out/s3.tsv"; same_prefix "$out/s2.tsv" "$out/s3.tsv"
  ! grep -q ' DESYNC ' "$out/relay.log" || fail "relay logged a DESYNC"
  ! grep -q 'lead bound' "$out/relay.log" || fail "relay refused a frame as too far ahead"
}

wait_exit() { # PID SECONDS
  i=0; limit=$(($2 * 5))
  while kill -0 "$1" 2>/dev/null; do
    i=$((i + 1)); [ $i -lt $limit ] || fail "pid $1 still running after $2 s"
    sleep 0.2
  done
}

end_line() { grep '^NETCLIENT END' "$out/$1.log" | tail -n 1; }
log_ms() { grep "^NETCLIENT $2" "$out/$1.log" | tail -n 1 | awk '{print $NF}'; }
expect_end() { # NAME STATUS
  line=$(end_line "$1")
  case "$line" in "NETCLIENT END $2 TICK "*) ;; *) fail "$1: expected END $2, got '$line'" ;; esac
}
end_tick() { end_line "$1" | awk '{print $5}'; }
end_winner() { end_line "$1" | awk '{print $7}'; }
same_hashes() { ${PYTHON:-python3} "$repo_root/tools/compare_replays.py" --interval 30 --rows 0 "$@" >/dev/null || fail "hash logs differ: $*"; }

oracle() {
  # shellcheck disable=SC2086
  $client -- --netclient --replay-log "$out/s1.cmd" --hash-log "$out/oracle.tsv" >"$out/oracle.log" 2>&1 || fail "oracle failed"
  expect_end oracle match_over
}

[ -z "$remote" ] || [ "$scenario" = match ] || fail "WARGRID_RELAY_URL supports only match"
match_wait=${WARGRID_MATCH_WAIT:-180}

case $scenario in
  match|proxy-clean|proxy-burst)
    start_relay
    case $scenario in
      proxy-clean) start_proxies "" "" ;;
      # Seat 1's hold spans seat 2's hold start; with seat 2 alone held, seat 1 may wait on it and send nothing down.
      # Seat 2 is starved while seat 1 is held, so its hold stays 3 s to keep 1 s under the client's 5 s silence rule.
      proxy-burst) start_proxies "slice:7,hold@2000:3500" "slice:7,hold@3000:3000" ;;
    esac
    start_pair "" ""
    wait_exit "$pid1" "$match_wait"; wait_exit "$pid2" "$match_wait"
    expect_end s1 match_over; expect_end s2 match_over
    [ "$(end_tick s1)" = "$(end_tick s2)" ] || fail "terminal ticks differ"
    [ "$(end_tick s1)" = 9746 ] || fail "terminal tick $(end_tick s1), pinned 9746"
    [ "$(end_winner s1)" = 1 ] && [ "$(end_winner s2)" = 1 ] || fail "winners $(end_winner s1) / $(end_winner s2), pinned 1"
    oracle; same_hashes "$out/s1.tsv" "$out/s2.tsv" "$out/oracle.tsv"
    [ -n "$remote" ] || ! grep -q ' DESYNC ' "$out/relay.log" || fail "relay logged a DESYNC in a clean match"
    [ "$scenario" = match ] || proxies_accepted
    if [ "$scenario" = proxy-burst ]; then
      grep -q ' slice 7$' "$out/proxy-seat2.log" || fail "no slice line in seat 2's proxy log"
      end1=$(proxy_ms 1 hold-end); start2=$(proxy_ms 2 hold-start)
      [ -n "$end1" ] && [ -n "$start2" ] && [ "$start2" -lt "$end1" ] || fail "seat 2's hold did not begin inside seat 1's (seat 2 joined too late)"
      grep -q ' hold-end [1-9][0-9]* [1-9][0-9]*$' "$out/proxy-seat2.log" || fail "no hold-end with held bytes both ways in seat 2's proxy log"
      ! grep -q 'lead bound' "$out/relay.log" || fail "relay refused a frame as too far ahead after a hold"
      burst_note=", seat 2's hold began $((end1 - start2)) ms before seat 1's ended, seat 2 hold-end $(awk '$4 == "hold-end" {print $5, $6; exit}' "$out/proxy-seat2.log")"
    fi
    echo "$scenario terminal tick $(end_tick s1)$burst_note" ;;
  rematch)
    start_relay; start_pair "--rematch" "--rematch"
    wait_exit "$pid1" $((2 * match_wait)); wait_exit "$pid2" $((2 * match_wait))
    expect_end s1 match_over; expect_end s2 match_over
    [ "$(end_tick s1)" = "$(end_tick s2)" ] || fail "terminal ticks differ"
    [ "$(end_tick s1)" = 9746 ] || fail "second match terminal tick $(end_tick s1), pinned 9746"
    [ "$(end_winner s1)" = 1 ] && [ "$(end_winner s2)" = 1 ] || fail "second match winners $(end_winner s1) / $(end_winner s2), pinned 1"
    for name in s1 s2; do
      [ "$(grep -c '^NETCLIENT MAP' "$out/$name.log")" = 2 ] || fail "$name: expected two MAP lines"
      [ "$(grep -c '^NETCLIENT OVER TICK 9746$' "$out/$name.log")" = 1 ] || fail "$name: expected one OVER TICK 9746"
    done
    grep -q '^NETCLIENT AGAIN SEAT 2$' "$out/s1.log" || fail "s1: no AGAIN line from seat 2"
    grep -q '^NETCLIENT AGAIN SEAT 1$' "$out/s2.log" || fail "s2: no AGAIN line from seat 1"
    seed1=$(grep '^NETCLIENT MAP' "$out/s1.log" | head -n 1 | awk '{print $5}'); seed2=$(grep '^NETCLIENT MAP' "$out/s1.log" | tail -n 1 | awk '{print $5}')
    if [ -z "$seed1" ] || [ "$seed1" = "$seed2" ]; then fail "both matches share the seed: $seed1"; fi
    second=$(grep '^NETCLIENT MAP' "$out/s1.log" | tail -n 1)
    [ "$(grep '^NETCLIENT MAP' "$out/s2.log" | tail -n 1)" = "$second" ] || fail "second MAP lines differ across seats"
    [ "$(grep -c 'INFO rematch' "$out/relay.log")" = 1 ] || fail "expected one rematch line in relay.log"
    i=0
    until grep -q 'MATCH END' "$out/relay.log"; do
      i=$((i + 1)); [ $i -lt 25 ] || fail "no MATCH END within 5 s"
      sleep 0.2
    done
    [ "$(grep -c 'MATCH END' "$out/relay.log")" = 1 ] || fail "expected one MATCH END"
    ! grep -q ' DESYNC ' "$out/relay.log" || fail "relay logged a DESYNC in a clean match"
    ! grep -q 'lead bound' "$out/relay.log" || fail "relay refused a frame as too far ahead"
    oracle; same_hashes "$out/s1.tsv" "$out/s2.tsv" "$out/oracle.tsv"
    echo "rematch terminal tick $(end_tick s1)" ;;
  kill)
    start_relay; start_pair "" "--exit-at-tick 600"
    wait_exit "$pid1" 60
    expect_end s1 ended_left
    [ "$(end_tick s1)" -ge 600 ] || fail "seat 1 ended before tick 600" ;;
  left-mid|left-mid-pump)
    start_relay
    if [ "$scenario" = left-mid-pump ]; then start_pair "--pump" "--stop-at-tick 600"; else start_pair "" "--stop-at-tick 600"; fi
    wait_exit "$pid1" 60; wait_exit "$pid2" 60
    expect_end s1 ended_left; expect_end s2 stopped
    grep -q '^NETCLIENT VICTORY left$' "$out/s1.log" || fail "s1: no VICTORY left"
    [ "$scenario" = left-mid ] || grep -q '^NETPLAY LATENCY' "$out/s1.log" || fail "s1: no NETPLAY LATENCY line, so the pump did not run"
    ! grep -q ' DESYNC ' "$out/relay.log" || fail "relay logged a DESYNC in a clean match"
    ! grep -q 'lead bound' "$out/relay.log" || fail "relay refused a frame as too far ahead"
    [ "$(end_tick s1)" -ge 600 ] || fail "seat 1 ended before tick 600" ;;
  trio-play-on)
    start_relay WARGRID_SEATS=3
    start_trio "--pump --defeat 2@300" "--faction usa --stop-at-tick 320 --defeat 2@300" "--stop-at-tick 900 --defeat 2@300"
    wait_exit "$pid1" 120; wait_exit "$pid2" 120; wait_exit "$pid3" 120
    expect_end s1 ended_left; expect_end s2 stopped; expect_end s3 stopped
    case "$(end_line s1)" in *"layer 3 disconnected") ;; *) fail "s1 reason: $(end_line s1)" ;; esac
    [ "$(end_tick s1)" -ge 900 ] || fail "seat 1 ended at $(end_tick s1), before seat 3's stop at 900"
    grep -q '^NETPLAY LATENCY' "$out/s1.log" || fail "s1: no NETPLAY LATENCY line, so the pump did not run"
    trio_checks s1 s2 s3 ;;
  trio-left-first)
    start_relay WARGRID_SEATS=3
    start_trio "" "--stop-at-tick 600" "--stop-at-tick 300"
    wait_exit "$pid1" 120; wait_exit "$pid2" 120; wait_exit "$pid3" 120
    expect_end s1 ended_left; expect_end s2 ended_left; expect_end s3 stopped
    for name in s1 s2; do
      case "$(end_line $name)" in *"layer 3 disconnected") ;; *) fail "$name reason: $(end_line $name)" ;; esac
      between "$name end tick" "$(end_tick $name)" 300 310
    done
    ! grep -q ' DESYNC ' "$out/relay.log" || fail "relay logged a DESYNC"
    ! grep -q 'lead bound' "$out/relay.log" || fail "relay refused a frame as too far ahead"
    same_prefix "$out/s1.tsv" "$out/s2.tsv"; same_prefix "$out/s1.tsv" "$out/s3.tsv"; same_prefix "$out/s2.tsv" "$out/s3.tsv" ;;
  trio-result)
    start_relay WARGRID_SEATS=3
    start_trio "--pump --defeat 2@300,3@1200" "--stop-at-tick 320 --defeat 2@300,3@1200" "--defeat 2@300,3@1200"
    wait_exit "$pid1" 120; wait_exit "$pid2" 120; wait_exit "$pid3" 120
    expect_end s1 match_over; expect_end s2 stopped; expect_end s3 match_over
    for name in s1 s3; do
      [ "$(end_tick $name)" = 1201 ] || fail "$name ended at $(end_tick $name), expected 1201"
      grep -q '^NETCLIENT DEFEAT 3 AT 1200$' "$out/$name.log" || fail "$name: no DEFEAT 3 AT 1200"
    done
    same_hashes "$out/s1.tsv" "$out/s3.tsv"
    grep -q '^NETPLAY LATENCY' "$out/s1.log" || fail "s1: no NETPLAY LATENCY line, so the pump did not run"
    trio_checks s1 s2 s3 ;;
  stall)
    start_relay; start_pair "" "--stall-at-tick 300 --stall-seconds 3"
    wait_exit "$pid1" 180; wait_exit "$pid2" 180
    expect_end s1 match_over; expect_end s2 match_over
    grep -q '^NETCLIENT STALL' "$out/s2.log" || fail "stall hook never ran"
    same_hashes "$out/s1.tsv" "$out/s2.tsv" ;;
  silent)
    start_relay; start_pair "" "--stall-at-tick 300 --stall-seconds 15"
    wait_exit "$pid1" 40
    expect_end s1 ended_left
    gap=$(($(log_ms s1 TIME) - $(log_ms s2 STALL)))
    [ "$gap" -le 12000 ] || fail "left took $gap ms after the stall started"
    echo "left announced $gap ms after stall start" ;;
  spike)
    start_relay WARGRID_TEST_DELAY_MS=200
    start_pair "--stop-at-tick 900" "--stop-at-tick 900"
    wait_exit "$pid1" 120; wait_exit "$pid2" 120
    expect_end s1 stopped; expect_end s2 stopped
    same_hashes "$out/s1.tsv" "$out/s2.tsv" ;;
  perturb)
    start_relay; start_pair "" "--perturb-at-tick 40"
    wait_exit "$pid1" 60; wait_exit "$pid2" 60
    expect_end s1 ended_desync; expect_end s2 ended_desync
    ${PYTHON:-python3} - "$out" <<'PY' || fail "desync report tick is not 60"
import json, sys
for seat in (1, 2):
    report = json.load(open(f"{sys.argv[1]}/desync-seat{seat}.json"))
    assert report["tick"] == 60
    assert report["map"] == "skirmish" and isinstance(report["seed"], int) and report["starts"] == []
    assert len(report["hash_ring"]) > 0
PY
    diff_out=$(${PYTHON:-python3} "$repo_root/tools/desync_diff.py" "$out/desync-seat1.json" "$out/desync-seat2.json")
    [ $? -eq 1 ] || fail "desync_diff should exit 1"
    case "$diff_out" in *players*) ;; *) fail "desync_diff did not name players: $diff_out" ;; esac
    case "$diff_out" in *"ring diverges at tick 41"*) ;; *) fail "desync_diff did not name ring tick 41: $diff_out" ;; esac
    echo "$diff_out"
    grep -q ' DESYNC .*tick=60 ' "$out/relay.log" || fail "relay logged no DESYNC at tick 60"
    bisect_out=$(${PYTHON:-python3} "$repo_root/tools/desync_bisect.py" "$out/desync-seat1.json" "$out/desync-seat2.json" --out "$out/bisect")
    [ $? -eq 1 ] || fail "desync_bisect should exit 1: $bisect_out"
    for line in "RINGS DIVERGE AT TICK 41" "SEAT 1 MATCHES LOCAL REPLAY" "SEAT 2 DIVERGES FROM LOCAL REPLAY AT TICK 41"; do
      case "$bisect_out" in *"$line"*) ;; *) fail "desync_bisect missing '$line': $bisect_out" ;; esac
    done
    case "$bisect_out" in *"SEAT 2 FIRST FIELD"*players*) ;; *) fail "desync_bisect did not name players: $bisect_out" ;; esac
    echo "$bisect_out" ;;
  version)
    start_relay; start_pair "" "--build other"
    wait_exit "$pid2" 30
    expect_end s2 ended_relay
    case "$(end_line s2)" in *"build mismatch") ;; *) fail "seat 2 reason: $(end_line s2)" ;; esac
    kill -0 "$pid1" 2>/dev/null || fail "seat 1 should still be waiting"
    ! grep -q '^NETCLIENT END' "$out/s1.log" || fail "seat 1 ended"
    kill -9 "$pid1" ;;
  maps)
    start_relay; rm -f "$out/code"
    start_client s1 --match new --code-file "$out/code" --seat-script opponent --map ashfall --stop-at-tick 900
    pid1=$pid
    i=0
    until [ -s "$out/code" ]; do
      i=$((i + 1)); [ $i -lt 100 ] || fail "no match code"
      sleep 0.2
    done
    start_client s2 --match "$(cat "$out/code")" --seat-script opponent --stop-at-tick 900
    pid2=$pid
    wait_exit "$pid1" 120; wait_exit "$pid2" 120
    expect_end s1 stopped; expect_end s2 stopped
    line1=$(grep '^NETCLIENT MAP' "$out/s1.log"); line2=$(grep '^NETCLIENT MAP' "$out/s2.log")
    [ -n "$line1" ] && [ "$line1" = "$line2" ] || fail "map lines differ: '$line1' / '$line2'"
    spots=${line1##* }; first=${spots%,*}; second=${spots#*,}
    [ $(((first - second + 8) % 8)) -eq 4 ] || fail "starts $spots are not diagonal"
    same_hashes "$out/s1.tsv" "$out/s2.tsv"
    echo "$line1" ;;
  map-mismatch)
    start_relay; rm -f "$out/code"
    start_client s1 --match new --code-file "$out/code" --seat-script opponent --map ashfall
    pid1=$pid
    i=0
    until [ -s "$out/code" ]; do
      i=$((i + 1)); [ $i -lt 100 ] || fail "no match code"
      sleep 0.2
    done
    start_client s2 --match "$(cat "$out/code")" --seat-script opponent --perturb-map-hash
    pid2=$pid
    wait_exit "$pid1" 60; wait_exit "$pid2" 60
    expect_end s2 ended_settings
    case "$(end_line s2)" in *"REASON Your copy of Ashfall differs from the host's") ;; *) fail "joiner reason: $(end_line s2)" ;; esac
    expect_end s1 ended_left
    case "$(end_line s1)" in "NETCLIENT END ended_left TICK 4 "*) ;; *) fail "host line: $(end_line s1)" ;; esac ;;
  relay-down|relay-term)
    drain_ms=500
    start_relay WARGRID_DRAIN_MS=$drain_ms; start_pair "" ""
    i=0
    until grep -q '^NETCLIENT MAP' "$out/s1.log" 2>/dev/null && grep -q '^NETCLIENT MAP' "$out/s2.log" 2>/dev/null; do
      i=$((i + 1)); [ $i -lt 100 ] || fail "match did not start"
      sleep 0.2
    done
    sleep 1
    if [ "$scenario" = relay-down ]; then kill -9 "$relay_pid"; stop_limit=2000; else kill -TERM "$relay_pid"; stop_limit=$((drain_ms + 2000)); fi
    down=$(ms)
    wait_exit "$pid1" 20; wait_exit "$pid2" 20
    for name in s1 s2; do
      echo "$name: $(end_line $name) $(($(log_ms $name TIME) - down)) ms after relay stop"
      expect_end $name ended_relay
      [ "$(end_tick $name)" -gt 0 ] || fail "$name never started the match"
      [ $(($(log_ms $name TIME) - down)) -le $stop_limit ] || fail "$name took too long"
    done
    if [ "$scenario" = relay-term ] && [ -z "$remote" ]; then
      wait "$relay_pid" || fail "relay exited $? on SIGTERM"
      grep -q 'MATCH END' "$out/relay.log" || fail "relay logged no MATCH END on SIGTERM"
    fi ;;
  proxy-reset)
    start_relay; start_proxies "" "reset@4000"; start_pair "" ""
    wait_exit "$pid1" 30; wait_exit "$pid2" 30
    expect_end s2 ended_relay; expect_end s1 ended_left
    proxies_accepted
    cut=$(proxy_ms 2 reset); [ -n "$cut" ] || fail "the reset never landed (no reset line in seat 2's proxy log)"
    gap2=$(($(log_ms s2 TIME) - cut)); gap1=$(($(log_ms s1 TIME) - cut))
    between "seat 2 ended after the reset" "$gap2" 0 2000; between "seat 1 left after the reset" "$gap1" 0 2000
    same_prefix "$out/s1.tsv" "$out/s2.tsv"
    echo "reset: seat 2 ended $gap2 ms, seat 1 left $gap1 ms after it" ;;
  proxy-blackhole)
    start_relay; start_proxies "" "blackhole@3000:7000"; start_pair "" ""
    wait_exit "$pid1" 40; wait_exit "$pid2" 40
    expect_end s2 ended_relay
    case "$(end_line s2)" in *"connection to relay lost") ;; *) fail "seat 2 reason: $(end_line s2)" ;; esac
    expect_end s1 ended_left
    proxies_accepted
    cut=$(proxy_ms 2 blackhole-start); [ -n "$cut" ] || fail "the blackhole never landed (no blackhole-start line in seat 2's proxy log)"
    gap2=$(($(log_ms s2 TIME) - cut)); gap1=$(($(log_ms s1 TIME) - cut))
    between "seat 2 ended after the blackhole began" "$gap2" 5500 7500; between "seat 1 left after the blackhole began" "$gap1" 9000 12000
    same_prefix "$out/s1.tsv" "$out/s2.tsv"
    echo "blackhole: seat 2 ended $gap2 ms, seat 1 left $gap1 ms after it began" ;;
  *) fail "unknown scenario" ;;
esac
echo "NETPLAY PASSED $scenario $(${PYTHON:-python3} -c "import time;print(round(time.time()-$started,1))") s"
[ -n "$NETPLAY_OUT" ] || rm -rf "$out"
