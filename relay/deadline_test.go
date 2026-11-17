package main

import (
	"bytes"
	"sync"
	"testing"
	"time"
)

type recorder struct {
	mu    sync.Mutex
	times []time.Time
}

func (r *recorder) set(t time.Time) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.times = append(r.times, t)
}

func (r *recorder) all() []time.Time {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]time.Time(nil), r.times...)
}

func (r *recorder) last() time.Time {
	t := r.all()
	return t[len(t)-1]
}

type frames struct {
	mu  sync.Mutex
	got [][]byte
}

func (f *frames) write(b []byte) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.got = append(f.got, bytes.Clone(b))
}

func (f *frames) has(part string) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, b := range f.got {
		if bytes.Contains(b, []byte(part)) {
			return true
		}
	}
	return false
}

func renewOf(c *conn) time.Duration {
	c.dl.mu.Lock()
	defer c.dl.mu.Unlock()
	return c.dl.renew
}

func near(a, b time.Time) bool { return a.Sub(b).Abs() < time.Second }

func TestDeadlineHoldIgnoresTouch(t *testing.T) {
	rec := &recorder{}
	d := &deadline{set: rec.set}
	until := time.Now().Add(time.Hour)
	d.hold(until)
	d.touch()
	if got := rec.all(); len(got) != 1 || !got[0].Equal(until) {
		t.Fatalf("got %v want [%v]", got, until)
	}
}

func TestDeadlineEveryRenews(t *testing.T) {
	rec := &recorder{}
	d := &deadline{set: rec.set}
	d.every(10 * time.Second)
	time.Sleep(5 * time.Millisecond)
	d.touch()
	got := rec.all()
	want := time.Now().Add(10 * time.Second)
	if len(got) != 2 || !got[1].After(got[0]) || !near(got[0], want) || !near(got[1], want) {
		t.Fatalf("got %v want two renewals near %v", got, want)
	}
}

func TestSeatDeadlinesFollowPhase(t *testing.T) {
	cfg := testConfig()
	cfg.lobby = time.Hour
	g := newRegistry(cfg)
	recA, recB := &recorder{}, &recorder{}
	a, _ := seatedWith(t, g, "", nop, recA.set)
	if want := a.room.expiresAt.Add(expiryGrace); !recA.last().Equal(want) {
		t.Fatalf("lobby deadline %v want %v", recA.last(), want)
	}
	b, _ := seatedWith(t, g, a.room.code, nop, recB.set)
	window := time.Now().Add(time.Hour)
	for i, rec := range []*recorder{recA, recB} {
		if !near(rec.last(), window) {
			t.Fatalf("seat %d start window %v want about %v", i+1, rec.last(), window)
		}
	}
	if renewOf(a) != 0 || renewOf(b) != 0 {
		t.Fatal("start window renews on frames")
	}
	a.room.post(tickMsg{a.seat, 1, inputDelay, []byte(`{"type":"tick"}`), hashMsg{}})
	eventually(t, "first tick did not start the silence rule", func() bool { return renewOf(a) == cfg.silence })
	if renewOf(b) != 0 {
		t.Fatal("the other seat left its start window")
	}
}

func TestLobbyExpirySendsReason(t *testing.T) {
	cfg := testConfig()
	cfg.lobby = 50 * time.Millisecond
	g := newRegistry(cfg)
	f := &frames{}
	a, shut := seated(t, g, "", f.write)
	code := a.room.code
	eventually(t, "no lobby expired", func() bool { return f.has(`{"type":"error","reason":"lobby expired"}`) })
	eventually(t, "socket not closed", shut.Load)
	eventually(t, "room not removed", func() bool { return g.count() == 0 })
	c, _ := loopConn(nop)
	if res := g.join(&envelope{protocol: protocol, build: "b", match: code}, c); res.reason != "unknown match" {
		t.Fatalf("join after expiry: seat %v reason %q", res.seat, res.reason)
	}
}

func TestExpiryRacesJoin(t *testing.T) {
	cfg := testConfig()
	cfg.lobby = 2 * time.Millisecond
	g := newRegistry(cfg)
	for round := range 200 {
		f := &frames{}
		a, _ := seated(t, g, "", f.write)
		time.Sleep(time.Duration(round*15) * time.Microsecond) // spreads the joins over 0-3 ms
		b, _ := loopConn(nop)
		res := g.join(&envelope{protocol: protocol, build: "b", match: a.room.code}, b)
		if res.seat != nil {
			bindSeat(b, res.seat)
			eventually(t, "joined but no start", func() bool { return f.has(`"type":"start"`) })
			time.Sleep(5 * time.Millisecond)
			if f.has("lobby expired") {
				t.Fatalf("round %d: both start and lobby expired", round)
			}
			a.close()
			b.close()
			continue
		}
		if res.reason != "unknown match" {
			t.Fatalf("round %d: reason %q", round, res.reason)
		}
		eventually(t, "refused but no lobby expired", func() bool { return f.has("lobby expired") })
		if f.has(`"type":"start"`) {
			t.Fatalf("round %d: refused join but start sent", round)
		}
	}
}

func TestLeaveBeforeExpiry(t *testing.T) {
	cfg := testConfig()
	cfg.lobby = 30 * time.Millisecond
	g := newRegistry(cfg)
	f := &frames{}
	a, _ := seated(t, g, "", f.write)
	r := a.room
	a.close()
	select {
	case <-r.done:
	case <-time.After(2 * time.Second):
		t.Fatal("room did not end after its last seat left")
	}
	time.Sleep(60 * time.Millisecond)
	if f.has(`"error"`) || g.count() != 0 {
		t.Fatalf("error frame %v, rooms %d", f.has(`"error"`), g.count())
	}
}
