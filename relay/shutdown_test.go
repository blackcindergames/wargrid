package main

import (
	"bytes"
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// loopMu guards the seat and room of loopConn conns: a lobby expiry may shut a conn while the test is still binding it.
var loopMu sync.Mutex

// loopConn behaves like a socket whose close comes back as OnClose: shut posts the seat's leave.
func loopConn(write func([]byte)) (*conn, *atomic.Bool) {
	c := &conn{}
	var shut atomic.Bool
	c.sender = sender{write: write, shut: func() {
		shut.Store(true)
		loopMu.Lock()
		room, seat := c.room, c.seat
		loopMu.Unlock()
		if room != nil {
			go room.post(leaveMsg{seat})
		}
	}}
	return c, &shut
}

func bindSeat(c *conn, s *seat) {
	loopMu.Lock()
	defer loopMu.Unlock()
	c.seat, c.room = s, s.r
}

func testConfig() config {
	return config{seats: 2, hello: 5 * time.Second, silence: time.Minute, lobby: time.Minute, lobbyCap: time.Hour}
}

func seated(t *testing.T, g *registry, match string, write func([]byte)) (*conn, *atomic.Bool) {
	t.Helper()
	return seatedWith(t, g, match, write, nil)
}

func seatedWith(t *testing.T, g *registry, match string, write func([]byte), set func(time.Time)) (*conn, *atomic.Bool) {
	t.Helper()
	c, shut := loopConn(write)
	c.dl.set = set
	e := &envelope{protocol: protocol, build: "b", match: match}
	if match == "" {
		e.raw = []byte("{}")
	}
	res := g.join(e, c)
	if res.seat == nil {
		t.Fatalf("join %q: %s", match, res.reason)
	}
	bindSeat(c, res.seat)
	return c, shut
}

func within(t *testing.T, d time.Duration) context.Context {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), d)
	t.Cleanup(cancel)
	return ctx
}

func eventually(t *testing.T, what string, ok func() bool) {
	t.Helper()
	for deadline := time.Now().Add(2 * time.Second); !ok(); time.Sleep(5 * time.Millisecond) {
		if time.Now().After(deadline) {
			t.Fatal(what)
		}
	}
}

func nop([]byte) {}

func TestDrainClosesLobbyKeepsMatch(t *testing.T) {
	g := newRegistry(testConfig())
	_, lobbyShut := seated(t, g, "", nop)
	a, aShut := seated(t, g, "", nop)
	seated(t, g, a.room.code, nop)
	g.startDrain()
	eventually(t, "lobby not closed", lobbyShut.Load)
	eventually(t, "lobby room not removed", func() bool { return g.count() == 1 })
	time.Sleep(50 * time.Millisecond)
	if aShut.Load() || g.count() != 1 {
		t.Fatal("started match was closed by drain")
	}
}

func TestStopClosesStartedMatch(t *testing.T) {
	g := newRegistry(testConfig())
	a, aShut := seated(t, g, "", nop)
	_, bShut := seated(t, g, a.room.code, nop)
	g.startDrain()
	if g.waitEmpty(within(t, 100*time.Millisecond)) {
		t.Fatal("match ended without stop")
	}
	g.stop()
	if !g.waitEmpty(within(t, 2*time.Second)) {
		t.Fatalf("%d rooms left after stop", g.count())
	}
	if !aShut.Load() || !bShut.Load() {
		t.Fatal("a seat was not closed")
	}
}

func TestRoomPanicEndsOnlyThatRoom(t *testing.T) {
	g := newRegistry(testConfig())
	boom := func(f []byte) {
		if bytes.Contains(f, []byte(`"tick"`)) {
			panic("boom")
		}
	}
	a, aShut := seated(t, g, "", nop)
	_, bShut := seated(t, g, a.room.code, boom)
	other, _ := seated(t, g, "", nop)
	a.room.post(tickMsg{a.seat, 1, inputDelay, []byte(`{"type":"tick"}`), hashMsg{}})
	select {
	case <-a.room.done:
	case <-time.After(2 * time.Second):
		t.Fatal("panicking room did not end")
	}
	if !aShut.Load() || !bShut.Load() {
		t.Fatal("seats of the crashed room were not closed")
	}
	for range 100 {
		a.room.post(leaveMsg{a.seat}) // must not block once the room is gone
	}
	if g.count() != 1 || g.rooms[other.room.code] == nil {
		t.Fatalf("want only the other room left, have %d", g.count())
	}
}
