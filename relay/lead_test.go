package main

import (
	"fmt"
	"strings"
	"testing"
)

const tooFar = `{"type":"error","reason":"too far ahead"}`

func tickData(n, tick int) []byte {
	return []byte(fmt.Sprintf(`{"type":"tick","seat":%d,"tick":%d}`, n, tick))
}

func lastFrame(f *frames) string {
	f.mu.Lock()
	defer f.mu.Unlock()
	if len(f.got) == 0 {
		return ""
	}
	return string(f.got[len(f.got)-1])
}

// testRoom builds a started room that is never run(), so a test drives forward and leave on one goroutine.
func testRoom(t *testing.T, seats int) (*room, []*frames) {
	t.Helper()
	cfg := testConfig()
	cfg.seats = seats
	r := &room{
		code: "TEST", cfg: cfg, reg: newRegistry(cfg), seats: map[int]*seat{}, stats: map[int]string{}, started: true,
		hashes: map[int]map[int]string{}, peaks: map[int][2]int{},
	}
	fs := make([]*frames, seats)
	for i := range fs {
		fs[i] = &frames{}
		c := &conn{sender: sender{write: fs[i].write, shut: func() {}}}
		s := &seat{n: i + 1, c: c, r: r}
		c.seat, c.room = s, r
		r.seats[s.n] = s
	}
	return r, fs
}

func feed(r *room, n, from, to int) {
	s := r.seats[n]
	for i := from; i <= to; i++ {
		r.forward(&tickMsg{s, n, i, tickData(n, i), hashMsg{}})
	}
}

func wantTicks(t *testing.T, what string, f *frames, want int) {
	t.Helper()
	if got := f.count(`"type":"tick"`); got != want {
		t.Fatalf("%s: %d tick frames forwarded, want %d", what, got, want)
	}
}

func wantRejected(t *testing.T, what string, r *room, n int, f *frames) {
	t.Helper()
	if lastFrame(f) != tooFar || !r.seats[n].dead {
		t.Fatalf("%s: seat %d not rejected with too far ahead (last frame %q, dead %v)", what, n, lastFrame(f), r.seats[n].dead)
	}
}

func TestLeadBoundFollowsOtherSeats(t *testing.T) {
	r, f := testRoom(t, 2)
	feed(r, 1, 4, 8)
	wantTicks(t, "start window", f[1], 5)
	feed(r, 1, 9, 9)
	wantRejected(t, "tick 9 with seat 2 silent", r, 1, f[0])
	feed(r, 1, 10, 12)
	wantTicks(t, "after the rejection", f[1], 5)

	r, f = testRoom(t, 2)
	feed(r, 1, 4, 5)
	feed(r, 2, 4, 10)
	wantTicks(t, "seat 2 up to seat 1's tick 5 + 5", f[0], 7)
	feed(r, 2, 11, 11)
	wantRejected(t, "seat 2 tick 11", r, 2, f[1])

	r, f = testRoom(t, 2)
	feed(r, 1, 4, 5)
	feed(r, 2, 4, 10)
	feed(r, 1, 6, 15)
	wantTicks(t, "seat 1 up to seat 2's tick 10 + 5", f[1], 2+10)
	feed(r, 1, 16, 16)
	wantRejected(t, "seat 1 tick 16", r, 1, f[0])

	r, f = testRoom(t, 2)
	feed(r, 2, 4, 5)
	r.leave(r.seats[2])
	feed(r, 1, 4, 40)
	wantTicks(t, "seat 2 already gone", f[1], 0)
	if r.seats[1].frames != 37 || strings.Contains(lastFrame(f[0]), "error") || !f[0].has(`{"type":"left","seat":2,"after_tick":5}`) {
		t.Fatalf("seat 1 after seat 2 left: frames %d, last %q", r.seats[1].frames, lastFrame(f[0]))
	}

	r, f = testRoom(t, 2)
	feed(r, 1, 4, 8)
	feed(r, 1, 9, 9)
	wantRejected(t, "tick 9 before the leave is processed", r, 1, f[0])
	r.leave(r.seats[2])
	wantTicks(t, "nothing past 8", f[1], 5)
}

func TestLeadBoundFollowsLowestOfSeveralSeats(t *testing.T) {
	r, f := testRoom(t, 3)
	feed(r, 1, 4, 5)
	feed(r, 3, 4, 5)
	feed(r, 2, 4, 10)
	feed(r, 1, 6, 10)
	if r.seats[1].dead || r.seats[1].lastTick != 10 {
		t.Fatalf("seat 1 should reach tick 10 (seat 3 at 5 + 5); lastTick %d dead %v", r.seats[1].lastTick, r.seats[1].dead)
	}
	feed(r, 1, 11, 11)
	wantRejected(t, "seat 1 tick 11 with seat 3 stuck at 5 and seat 2 at 10", r, 1, f[0])
}

func TestLeadBoundDeadAndSingleSeat(t *testing.T) {
	r, f := testRoom(t, 2)
	feed(r, 2, 4, 4)
	r.forward(&tickMsg{r.seats[2], 1, 5, tickData(1, 5), hashMsg{}})
	if !r.seats[2].dead {
		t.Fatal("seat 2 should be dead and still seated")
	}
	feed(r, 1, 4, 9)
	if r.seats[1].dead || r.seats[1].lastTick != 9 {
		t.Fatalf("seat 1 should reach tick 9 behind a dead seat at 4 (4 + 4 + 1); lastTick %d dead %v", r.seats[1].lastTick, r.seats[1].dead)
	}
	feed(r, 1, 10, 10)
	wantRejected(t, "tick 10 behind a dead seat at 4", r, 1, f[0])

	r, f = testRoom(t, 1)
	feed(r, 1, 4, 100)
	if r.seats[1].frames != 97 || r.seats[1].dead || lastFrame(f[0]) != "" {
		t.Fatalf("single seat: frames %d dead %v last %q", r.seats[1].frames, r.seats[1].dead, lastFrame(f[0]))
	}
}

func TestRejectedFrameCountsNothing(t *testing.T) {
	r, f := testRoom(t, 2)
	feed(r, 1, 4, 8)
	s := r.seats[1]
	n, size, last := s.frames, s.bytes, s.lastTick
	maxFrame, peak, hashes := s.maxFrame, s.peak, len(r.hashes)
	r.forward(&tickMsg{s, 1, 9, sizedTick(1, 9, 70000), honest(9, "a")})
	wantRejected(t, "tick 9", r, 1, f[0])
	if s.frames != n || s.bytes != size || s.lastTick != last {
		t.Fatalf("rejected frame changed counters: frames %d->%d bytes %d->%d lastTick %d->%d", n, s.frames, size, s.bytes, last, s.lastTick)
	}
	if s.maxFrame != maxFrame || s.peak != peak || len(r.hashes) != hashes {
		t.Fatalf("rejected frame was recorded: maxFrame %d->%d peak %d->%d hash entries %d->%d", maxFrame, s.maxFrame, peak, s.peak, hashes, len(r.hashes))
	}
}

func TestLeadBoundAcrossOverAndRematch(t *testing.T) {
	g := newRegistry(testConfig())
	fa, fb := &frames{}, &frames{}
	a, b, _, _ := pair(t, g, fa.write, fb.write)
	r := a.room
	r.post(firstTick(a))
	r.post(firstTick(b))
	for i := 5; i <= 6; i++ {
		r.post(tickMsg{a.seat, 1, i, tickData(1, i), hashMsg{}})
	}
	r.post(overMsg{a.seat})
	for i := 5; i <= 11; i++ {
		r.post(tickMsg{b.seat, 2, i, tickData(2, i), hashMsg{}})
	}
	eventually(t, "seat 2's ticks up to 6 + 4 + 1 not all forwarded", func() bool { return fa.count(`"type":"tick"`) == 8 })
	r.post(tickMsg{b.seat, 2, 12, tickData(2, 12), hashMsg{}})
	eventually(t, "tick 12 beyond seat 1's frozen tick 6 not rejected", func() bool { return fb.has(tooFar) })
	if fa.count(`"type":"tick"`) != 8 {
		t.Fatal("tick 12 was forwarded")
	}
	a.close()
	b.close()
	ended(t, r)

	fa, fb = &frames{}, &frames{}
	a, b, _, _ = pair(t, g, fa.write, fb.write)
	r = a.room
	park(a, b)
	r.post(againMsg{a.seat})
	r.post(againMsg{b.seat})
	eventually(t, "no second start", func() bool { return fa.count(`"type":"start"`) == 2 && fb.count(`"type":"start"`) == 2 })
	for i := 4; i <= 9; i++ {
		r.post(tickMsg{a.seat, 1, i, tickData(1, i), hashMsg{}})
	}
	eventually(t, "tick 9 of match 2 not rejected", func() bool { return fa.has(tooFar) })
	wantTicks(t, "match 1 tick 4 plus match 2 ticks 4..8", fb, 1+5)
	a.close()
	b.close()
	ended(t, r)
}
