package main

import (
	"bytes"
	"fmt"
	"sync/atomic"
	"testing"
	"time"
)

const roomExpired = `{"type":"error","reason":"room expired"}`

func (f *frames) count(part string) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	n := 0
	for _, b := range f.got {
		if bytes.Contains(b, []byte(part)) {
			n++
		}
	}
	return n
}

func pair(t *testing.T, g *registry, wa, wb func([]byte)) (a, b *conn, aShut, bShut *atomic.Bool) {
	t.Helper()
	a, aShut = seated(t, g, "", wa)
	b, bShut = seated(t, g, a.room.code, wb)
	return a, b, aShut, bShut
}

func firstTick(c *conn) tickMsg {
	return tickMsg{c.seat, c.seat.n, inputDelay, []byte(fmt.Sprintf(`{"type":"tick","seat":%d,"tick":%d}`, c.seat.n, inputDelay))}
}

func park(a, b *conn) {
	a.room.post(firstTick(a))
	a.room.post(firstTick(b))
	a.room.post(overMsg{a.seat})
	a.room.post(overMsg{b.seat})
}

func ended(t *testing.T, r *room) {
	t.Helper()
	select {
	case <-r.done:
	case <-time.After(2 * time.Second):
		t.Fatal("room did not end")
	}
}

func TestRematchResetsTicksAndKeepsCounters(t *testing.T) {
	g := newRegistry(testConfig())
	fa, fb := &frames{}, &frames{}
	a, b, _, _ := pair(t, g, fa.write, fb.write)
	r := a.room
	park(a, b)
	r.post(againMsg{a.seat})
	r.post(againMsg{b.seat})
	eventually(t, "no second start", func() bool { return fa.count(`"type":"start"`) == 2 && fb.count(`"type":"start"`) == 2 })
	if !fb.has(`{"type":"again","seat":1}`) || !fa.has(`{"type":"again","seat":2}`) {
		t.Fatal("again not echoed to the other seat")
	}
	if fa.has(`{"type":"again","seat":1}`) || fb.has(`{"type":"again","seat":2}`) {
		t.Fatal("again echoed to its sender")
	}
	second := firstTick(a)
	r.post(second)
	eventually(t, "tick 4 after the restart not forwarded", func() bool { return fb.count(string(second.data)) == 2 })
	a.close()
	b.close()
	ended(t, r)
	if want := fmt.Sprintf("2f/%dB", 2*len(second.data)); r.stats[1] != want {
		t.Fatalf("seat 1 stats %q want %q", r.stats[1], want)
	}
}

func TestParkedRoomExpires(t *testing.T) {
	cfg := testConfig()
	cfg.lobby = 50 * time.Millisecond
	g := newRegistry(cfg)
	fa, fb := &frames{}, &frames{}
	a, b, _, _ := pair(t, g, fa.write, fb.write)
	time.Sleep(80 * time.Millisecond)
	if fa.has(`"error"`) || fb.has(`"error"`) {
		t.Fatal("running match got an error frame from the expiry timer")
	}
	park(a, b)
	eventually(t, "parked room did not expire", func() bool { return fa.has(roomExpired) && fb.has(roomExpired) })
	ended(t, a.room)
}

func TestQueuedAgainAfterExpiry(t *testing.T) {
	cfg := testConfig()
	cfg.lobby = 30 * time.Millisecond
	g := newRegistry(cfg)
	fa, fb := &frames{}, &frames{}
	held, release := make(chan struct{}), make(chan struct{})
	// Holds the room goroutine inside expire() so both again messages queue behind the timer.
	hold := func(f []byte) {
		fa.write(f)
		if bytes.Contains(f, []byte("room expired")) {
			close(held)
			<-release
		}
	}
	a, b, _, _ := pair(t, g, hold, fb.write)
	park(a, b)
	select {
	case <-held:
	case <-time.After(2 * time.Second):
		t.Fatal("park limit never fired")
	}
	a.room.post(againMsg{a.seat})
	a.room.post(againMsg{b.seat})
	close(release)
	ended(t, a.room)
	if fa.count(`"type":"start"`) != 1 || fb.count(`"type":"start"`) != 1 {
		t.Fatal("start after room expired")
	}
	if !fb.has(roomExpired) || fb.has(`"type":"again"`) {
		t.Fatalf("seat 2 frames: expired %v, again echo %v", fb.has(roomExpired), fb.has(`"type":"again"`))
	}
}

func TestParkLimitBeatsLateAgain(t *testing.T) {
	cfg := testConfig()
	cfg.lobby = 30 * time.Millisecond
	g := newRegistry(cfg)
	fa, fb := &frames{}, &frames{}
	a, b, _, _ := pair(t, g, fa.write, fb.write)
	park(a, b)
	a.room.post(againMsg{a.seat})
	time.Sleep(60 * time.Millisecond)
	a.room.post(againMsg{b.seat})
	ended(t, a.room)
	if fa.count(`"type":"start"`) != 1 || fb.count(`"type":"start"`) != 1 {
		t.Fatal("late again restarted an expired room")
	}
	if !fa.has(roomExpired) || !fb.has(roomExpired) {
		t.Fatal("no room expired")
	}
}

func TestLeaveAfterParkStillExpires(t *testing.T) {
	cfg := testConfig()
	cfg.lobby = 50 * time.Millisecond
	g := newRegistry(cfg)
	fa := &frames{}
	a, b, _, _ := pair(t, g, fa.write, nop)
	park(a, b)
	b.close()
	eventually(t, "no left", func() bool { return fa.has(`{"type":"left","seat":2,"after_tick":4}`) })
	eventually(t, "no room expired after the leave", func() bool { return fa.has(roomExpired) })
	ended(t, a.room)
}

func TestDrainAndParking(t *testing.T) {
	t.Run("parked_then_drain", func(t *testing.T) {
		g := newRegistry(testConfig())
		fb := &frames{}
		a, b, aShut, bShut := pair(t, g, nop, fb.write)
		park(a, b)
		a.room.post(againMsg{a.seat}) // its echo proves the overs before it were handled
		eventually(t, "no again echo", func() bool { return fb.has(`{"type":"again","seat":1}`) })
		g.startDrain()
		eventually(t, "parked room not closed on drain", func() bool { return aShut.Load() && bShut.Load() })
	})
	t.Run("park_while_draining", func(t *testing.T) {
		g := newRegistry(testConfig())
		a, b, aShut, bShut := pair(t, g, nop, nop)
		g.startDrain()
		time.Sleep(50 * time.Millisecond)
		if aShut.Load() || bShut.Load() {
			t.Fatal("running match closed by drain")
		}
		park(a, b)
		eventually(t, "room parked while draining not closed", func() bool { return aShut.Load() && bShut.Load() })
	})
	t.Run("again_while_draining", func(t *testing.T) {
		g := newRegistry(testConfig())
		fa, fb := &frames{}, &frames{}
		a, b, _, _ := pair(t, g, fa.write, fb.write)
		g.startDrain()
		r := a.room
		r.post(firstTick(a))
		r.post(firstTick(b))
		r.post(overMsg{a.seat})
		r.post(againMsg{a.seat})
		r.post(overMsg{b.seat})
		r.post(againMsg{b.seat})
		ended(t, r)
		if fa.has(`"type":"again"`) || fb.has(`"type":"again"`) || fa.count(`"type":"start"`) != 1 {
			t.Fatal("again handled while draining")
		}
	})
	// Drain starts on the room goroutine while seat 2's again is queued; each round the old
	// select-only check restarted the match half the time, so 64 rounds fail it with p = 1-2^-64.
	t.Run("again_queued_when_drain_starts", func(t *testing.T) {
		for range 64 {
			g := newRegistry(testConfig())
			fa := &frames{}
			drainOnEcho := func(f []byte) {
				if bytes.Contains(f, []byte(`{"type":"again","seat":1}`)) {
					g.startDrain()
				}
			}
			a, b, _, _ := pair(t, g, fa.write, drainOnEcho)
			r := a.room
			park(a, b)
			r.post(againMsg{a.seat})
			r.post(againMsg{b.seat})
			ended(t, r)
			if fa.count(`"type":"start"`) != 1 {
				t.Fatal("queued again restarted the match after drain started")
			}
		}
	})
}

func TestPanicOnAgainEchoEndsOnlyThatRoom(t *testing.T) {
	g := newRegistry(testConfig())
	boom := func(f []byte) {
		if bytes.Contains(f, []byte(`"again"`)) {
			panic("boom")
		}
	}
	a, b, aShut, bShut := pair(t, g, nop, boom)
	other, _ := seated(t, g, "", nop)
	park(a, b)
	a.room.post(againMsg{a.seat})
	ended(t, a.room)
	eventually(t, "seats of the crashed room were not closed", func() bool { return aShut.Load() && bShut.Load() })
	if g.count() != 1 || g.rooms[other.room.code] == nil {
		t.Fatalf("want only the other room left, have %d", g.count())
	}
}
