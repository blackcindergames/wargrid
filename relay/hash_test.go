package main

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"
)

const (
	hashA = "aaaaaaaaaaaaaaaa"
	hashB = "bbbbbbbbbbbbbbbb"
)

func hashData(n, tick int, h hashMsg) []byte {
	if !h.ok {
		return []byte(tickFrame(n, tick))
	}
	return []byte(fmt.Sprintf(`{"type":"tick","seat":%d,"tick":%d,"commands":[],"hash":{"tick":%d,"value":%q}}`, n, tick, h.tick, h.value))
}

func sendHash(r *room, n, tick int, h hashMsg) {
	r.forward(&tickMsg{s: r.seats[n], seat: n, tick: tick, data: hashData(n, tick, h), hash: h})
}

// honest is the hash an honest client puts in the frame for tick: the state at tick-inputDelay.
func honest(tick int, value string) hashMsg { return hashMsg{tick - inputDelay, value, true} }

// play sends ticks from..to interleaved, seat order per tick; hash picks each frame's hash.
func play(r *room, seats, from, to int, hash func(n, tick int) hashMsg) {
	for tick := from; tick <= to; tick++ {
		for n := 1; n <= seats; n++ {
			sendHash(r, n, tick, hash(n, tick))
		}
	}
}

func noHash(int, int) hashMsg { return hashMsg{} }

// hashRoom is a testRoom with a code of its own, so log lines of rooms left over from other tests are told apart.
func hashRoom(t *testing.T, seats int) *room {
	r, _ := testRoom(t, seats)
	r.code = t.Name()
	return r
}

// unquoted keeps the log lines of room r and drops the quotes slog's text handler puts around some values.
func unquoted(logs *syncBuf, r *room) string {
	var mine []string
	for _, line := range strings.Split(strings.ReplaceAll(logs.String(), `"`, ""), "\n") {
		if strings.Contains(line, "code="+r.code+" ") || strings.HasSuffix(line, "code="+r.code) {
			mine = append(mine, line)
		}
	}
	return strings.Join(mine, "\n")
}

func matchEnd(t *testing.T, logs *syncBuf, r *room) string {
	t.Helper()
	var found []string
	for _, line := range strings.Split(unquoted(logs, r), "\n") {
		if strings.Contains(line, "msg=MATCH END") {
			found = append(found, line)
		}
	}
	if len(found) != 1 {
		t.Fatalf("%d MATCH END lines, want 1:\n%s", len(found), logs.String())
	}
	return found[0]
}

func leaveAll(r *room) {
	for n := 1; n <= 3; n++ {
		if s := r.seats[n]; s != nil {
			r.leave(s)
		}
	}
}

func TestHashMismatchLogsGroups(t *testing.T) {
	at34 := func(a, b string) func(n, tick int) hashMsg {
		return func(n, tick int) hashMsg {
			if tick == 34 {
				return honest(tick, map[int]string{1: a, 2: b}[n])
			}
			return hashMsg{}
		}
	}

	logs := captureLogs(t)
	r := hashRoom(t, 2)
	play(r, 2, 4, 34, at34(hashA, hashA))
	leaveAll(r)
	if strings.Contains(unquoted(logs, r), "DESYNC") || strings.Contains(matchEnd(t, logs, r), "desync") {
		t.Fatalf("equal hashes reported a desync:\n%s", logs.String())
	}

	logs = captureLogs(t)
	r = hashRoom(t, 2)
	play(r, 2, 4, 34, at34(hashA, hashB))
	play(r, 2, 35, 64, func(n, tick int) hashMsg {
		if tick == 64 {
			return honest(tick, map[int]string{1: hashA, 2: hashB}[n])
		}
		return hashMsg{}
	})
	leaveAll(r)
	if got := strings.Count(unquoted(logs, r), "msg=DESYNC"); got != 1 || !strings.Contains(unquoted(logs, r), "tick=30 groups=1|2") {
		t.Fatalf("want one DESYNC at tick 30 with groups 1|2, got %d:\n%s", got, logs.String())
	}
	if end := matchEnd(t, logs, r); !strings.Contains(end, "desync=30 desync_groups=1|2") {
		t.Fatalf("MATCH END without the desync fields: %s", end)
	}

	logs = captureLogs(t)
	r = hashRoom(t, 2)
	play(r, 2, 4, 34, func(n, tick int) hashMsg {
		if tick == 4 || tick == 34 {
			return honest(tick, map[int]string{1: hashA, 2: hashB}[n])
		}
		return hashMsg{}
	})
	leaveAll(r)
	if got := strings.Count(unquoted(logs, r), "msg=DESYNC"); got != 1 || !strings.Contains(unquoted(logs, r), "tick=0 groups=1|2") {
		t.Fatalf("want one DESYNC at hash tick 0, got %d:\n%s", got, logs.String())
	}
	if end := matchEnd(t, logs, r); !strings.Contains(end, "desync=0 desync_groups=1|2") {
		t.Fatalf("MATCH END without desync=0: %s", end)
	}
}

func TestHashGroupsNameOddSeat(t *testing.T) {
	logs := captureLogs(t)
	r := hashRoom(t, 3)
	play(r, 3, 4, 34, func(n, tick int) hashMsg {
		if tick == 34 {
			return honest(tick, map[int]string{1: hashA, 2: hashB, 3: hashA}[n])
		}
		return hashMsg{}
	})
	if !strings.Contains(unquoted(logs, r), "groups=1,3|2") {
		t.Fatalf("want groups 1,3|2:\n%s", logs.String())
	}
}

func TestHashCompletesAfterOver(t *testing.T) {
	logs := captureLogs(t)
	r := hashRoom(t, 2)
	play(r, 2, 4, 33, noHash)
	sendHash(r, 1, 34, honest(34, hashA))
	r.onOver(r.seats[1])
	sendHash(r, 2, 34, honest(34, hashB))
	if got := strings.Count(unquoted(logs, r), "msg=DESYNC"); got != 1 {
		t.Fatalf("want one DESYNC from the pending entry completed after over, got %d:\n%s", got, logs.String())
	}
}

func TestHashOffOffsetIgnored(t *testing.T) {
	logs := captureLogs(t)
	r, f := testRoom(t, 2)
	r.code = t.Name()
	off := hashMsg{30, hashA, true}
	sendHash(r, 1, 4, off)
	if !f[1].has(string(hashData(1, 4, off))) {
		t.Fatal("frame with an off-offset hash was not forwarded byte-exact")
	}
	if len(r.hashes) != 0 {
		t.Fatalf("off-offset hash recorded: %v", r.hashes)
	}
	sendHash(r, 2, 4, hashMsg{})
	play(r, 2, 5, 33, noHash)
	sendHash(r, 1, 34, hashMsg{})
	sendHash(r, 2, 34, honest(34, hashB))
	if strings.Contains(unquoted(logs, r), "DESYNC") {
		t.Fatalf("stale off-offset value completed a comparison:\n%s", logs.String())
	}
}

// fullLead sends seat 1 five ticks ahead of seat 2 (the most the bound allows) until seat 2 reaches last.
func fullLead(t *testing.T, r *room, last int, hash1, hash2 func(tick int) hashMsg, openMax int) (peak int) {
	t.Helper()
	check := func() {
		peak = max(peak, len(r.hashes))
		if len(r.hashes) > openMax {
			t.Fatalf("%d open hash entries, want at most %d", len(r.hashes), openMax)
		}
	}
	for tick := 4; tick <= 8; tick++ {
		sendHash(r, 1, tick, hash1(tick))
		check()
	}
	for tick := 4; tick <= last; tick++ {
		sendHash(r, 2, tick, hash2(tick))
		check()
		sendHash(r, 1, tick+5, hash1(tick+5))
		check()
	}
	return peak
}

func every30(value string) func(tick int) hashMsg {
	return func(tick int) hashMsg {
		if (tick-inputDelay)%30 == 0 {
			return honest(tick, value)
		}
		return hashMsg{}
	}
}

func TestHashEntriesBounded(t *testing.T) {
	logs := captureLogs(t)
	r := hashRoom(t, 2)
	// seat 1's last frame is 304, which carries hash tick 300 that seat 2 has not sent
	if peak := fullLead(t, r, 299, every30(hashA), every30(hashA), 1); peak != 1 {
		t.Fatalf("peak %d open entries, want exactly 1 (the lead is below the hash interval)", peak)
	}
	if len(r.hashes) != 1 {
		t.Fatalf("%d entries pending before the leave, want 1", len(r.hashes))
	}
	r.leave(r.seats[2])
	if len(r.hashes) != 0 {
		t.Fatalf("%d entries left after the leave", len(r.hashes))
	}
	if strings.Contains(unquoted(logs, r), "DESYNC") {
		t.Fatalf("DESYNC without a mismatch:\n%s", logs.String())
	}
}

func TestHashFloodBounded(t *testing.T) {
	logs := captureLogs(t)
	r := hashRoom(t, 2)
	flood := func(tick int) hashMsg { return honest(tick, hashA) }
	seat2 := func(tick int) hashMsg {
		if tick == 154 {
			return honest(tick, hashB)
		}
		return every30(hashA)(tick)
	}
	t.Logf("largest open set %d", fullLead(t, r, 299, flood, seat2, maxDelay+1))
	out := unquoted(logs, r)
	if got := strings.Count(out, "msg=DESYNC"); got != 1 || !strings.Contains(out, "tick=150 groups=1|2") {
		t.Fatalf("want one DESYNC at tick 150, got %d:\n%s", got, logs.String())
	}
}

func TestMatchEndByteFields(t *testing.T) {
	logs := captureLogs(t)
	r := hashRoom(t, 2)
	send := func(tick, size int) {
		r.forward(&tickMsg{s: r.seats[1], seat: 1, tick: tick, data: sizedTick(1, tick, size)})
	}
	send(4, 100)
	send(5, 2000)
	send(6, 65536)
	time.Sleep(1100 * time.Millisecond)
	send(7, 100)
	send(8, 100)
	send(9, 100)
	if !r.seats[1].dead {
		t.Fatal("tick 9 should have been rejected")
	}
	leaveAll(r)
	end := matchEnd(t, logs, r)
	for _, want := range []string{"seat1=5f/67836B", "seat1_max_frame=65536", "seat1_peak_bps=67636", "seat2=0f/0B", "seat2_max_frame=0", "seat2_peak_bps=0"} {
		if !strings.Contains(end, want) {
			t.Fatalf("MATCH END lacks %q: %s", want, end)
		}
	}
}

// sizedTick is a valid tick frame of exactly size bytes.
func sizedTick(n, tick, size int) []byte {
	base := fmt.Sprintf(`{"type":"tick","seat":%d,"tick":%d,"commands":[%q]}`, n, tick, "")
	return []byte(strings.Replace(base, `""`, `"`+strings.Repeat("x", size-len(base))+`"`, 1))
}

func TestHashesClearedAtRematch(t *testing.T) {
	logs := captureLogs(t)
	g := newRegistry(testConfig())
	fa, fb := &frames{}, &frames{}
	a, b, _, _ := pair(t, g, fa.write, fb.write)
	r := a.room
	post := func(c *conn, tick int, h hashMsg) {
		r.post(tickMsg{s: c.seat, seat: c.seat.n, tick: tick, data: hashData(c.seat.n, tick, h), hash: h})
	}
	postTo := func(from, to int) {
		for tick := from; tick <= to; tick++ {
			post(a, tick, hashMsg{})
			post(b, tick, hashMsg{})
		}
	}

	postTo(4, 33)
	post(a, 34, honest(34, hashA))
	r.post(overMsg{a.seat})
	r.post(overMsg{b.seat})
	r.post(againMsg{a.seat})
	r.post(againMsg{b.seat})
	eventually(t, "no second start", func() bool { return fa.count(`"type":"start"`) == 2 && fb.count(`"type":"start"`) == 2 })

	postTo(4, 33)
	post(b, 34, honest(34, hashB))
	post(a, 34, honest(34, hashB))
	eventually(t, "frames 34 of match 2 not forwarded", func() bool {
		return fa.count(`"seat":2,"tick":34`) == 1 && fb.count(`"seat":1,"tick":34`) == 2
	})
	if fa.has(`"type":"error"`) || fb.has(`"type":"error"`) {
		t.Fatal("an error frame arrived")
	}
	a.close()
	b.close()
	ended(t, r)
	if strings.Contains(unquoted(logs, r), "DESYNC") {
		t.Fatalf("match 1's pending value completed a comparison in match 2:\n%s", logs.String())
	}
}

func TestByteFieldsAcrossRematch(t *testing.T) {
	logs := captureLogs(t)
	g := newRegistry(testConfig())
	fa, fb := &frames{}, &frames{}
	a, b, _, _ := pair(t, g, fa.write, fb.write)
	r := a.room
	r.post(tickMsg{s: a.seat, seat: 1, tick: 4, data: sizedTick(1, 4, 100)})
	r.post(tickMsg{s: a.seat, seat: 1, tick: 5, data: sizedTick(1, 5, 2000)})
	r.post(tickMsg{s: b.seat, seat: 2, tick: 4, data: sizedTick(2, 4, 100)})
	r.post(overMsg{a.seat})
	r.post(overMsg{b.seat})
	r.post(againMsg{a.seat})
	r.post(againMsg{b.seat})
	eventually(t, "no second start", func() bool { return fa.count(`"type":"start"`) == 2 && fb.count(`"type":"start"`) == 2 })
	r.post(tickMsg{s: a.seat, seat: 1, tick: 4, data: sizedTick(1, 4, 500)})
	eventually(t, "match 2 frame not forwarded", func() bool { return fb.count(`"type":"tick"`) == 3 })
	a.close()
	b.close()
	ended(t, r)
	end := matchEnd(t, logs, r)
	m := regexp.MustCompile(`seat1_peak_bps=(\d+)`).FindStringSubmatch(end)
	if m == nil {
		t.Fatalf("MATCH END lacks seat1_peak_bps: %s", end)
	}
	if peak, _ := strconv.Atoi(m[1]); peak < 2100 {
		t.Fatalf("seat1_peak_bps %d lost the pre-rematch 2000 B frame: %s", peak, end)
	}
	for _, want := range []string{"seat1=3f/2600B", "seat1_max_frame=2000", "seat2_max_frame=100"} {
		if !strings.Contains(end, want) {
			t.Fatalf("MATCH END lacks %q: %s", want, end)
		}
	}
}
