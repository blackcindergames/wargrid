package main

import (
	"fmt"
	"net/http/httptest"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/lxzan/gws"
)

func tickFrame(seat, tick int) string {
	return fmt.Sprintf(`{"type":"tick","seat":%d,"tick":%d,"commands":[]}`, seat, tick)
}

func settledGoroutines() int {
	last := runtime.NumGoroutine()
	for deadline := time.Now().Add(5 * time.Second); time.Now().Before(deadline); {
		time.Sleep(100 * time.Millisecond)
		n := runtime.NumGoroutine()
		if n == last {
			return n
		}
		last = n
	}
	return last
}

const createHello = `{"type":"hello","protocol":2,"build":"x","match":"","settings":{}}`

type churnKind int

const (
	churnPlain churnKind = iota
	churnRematch
	churnRejected
	churnAbandoned
	churnKinds
)

func openLobby(t *testing.T, base string) (*gws.Conn, *cl, string) {
	t.Helper()
	a, ac := dial(t, base)
	say(t, a, createHello)
	w := hear(t, ac)
	return a, ac, w[strings.Index(w, `"match":"`)+9 : len(w)-2]
}

func joinMatch(t *testing.T, base, code string) (*gws.Conn, *cl) {
	t.Helper()
	b, bc := dial(t, base)
	say(t, b, `{"type":"hello","protocol":2,"build":"x","match":"`+code+`"}`)
	return b, bc
}

func churnRoom(t *testing.T, base string, kind churnKind) {
	t.Helper()
	a, ac, code := openLobby(t, base)
	if kind == churnAbandoned {
		_ = a.WriteClose(1000, nil)
		return
	}
	b, bc := joinMatch(t, base, code)
	hear(t, bc)
	hear(t, bc)
	hear(t, ac)
	if kind == churnRejected {
		churnReject(t, base, code, a, ac, b)
		return
	}
	for tick := 4; tick <= 6; tick++ {
		say(t, a, tickFrame(1, tick))
		say(t, b, tickFrame(2, tick))
	}
	if kind == churnRematch {
		for _, s := range []*gws.Conn{a, b} {
			say(t, s, `{"type":"over"}`)
			say(t, s, `{"type":"again"}`)
		}
		hearUntil(t, ac, `"type":"start"`)
		hearUntil(t, bc, `"type":"start"`)
	}
	_ = a.WriteClose(1000, nil)
	_ = b.WriteClose(1000, nil)
}

// churnReject leaves two rejected sockets, a seat past the lead bound and a third client of a started
// match, for the relay to close itself after closeGrace.
func churnReject(t *testing.T, base, code string, a *gws.Conn, ac *cl, b *gws.Conn) {
	t.Helper()
	_, cc := joinMatch(t, base, code)
	hearUntil(t, cc, `"reason":"match full"`)
	for tick := 4; tick <= 9; tick++ {
		say(t, a, tickFrame(1, tick))
	}
	hearUntil(t, ac, `"reason":"too far ahead"`)
	_ = b.WriteClose(1000, nil)
}

func churnRooms(t *testing.T, cfg config) {
	t.Helper()
	reg := newRegistry(cfg)
	srv := httptest.NewServer(newServer(&relay{reg: reg}).Handler)
	defer srv.Close()
	churnRoom(t, srv.URL, churnPlain)
	baseline := settledGoroutines()
	const rooms = 60
	for i := range rooms {
		churnRoom(t, srv.URL, churnKind(i)%churnKinds)
	}
	// Slack of 2 for goroutines that come and go with the scheduler: gws Async writers, AfterFunc callbacks.
	final := runtime.NumGoroutine()
	for deadline := time.Now().Add(5 * time.Second); (final > baseline+2 || reg.count() != 0) && time.Now().Before(deadline); final = runtime.NumGoroutine() {
		time.Sleep(20 * time.Millisecond)
	}
	if final > baseline+2 || reg.count() != 0 {
		t.Fatalf("baseline %d goroutines, after %d rooms %d; %d rooms left in the registry", baseline, rooms, final, reg.count())
	}
	t.Logf("goroutines: baseline %d, after %d rooms %d", baseline, rooms, final)
}

// Every fourth room rematches, so a goroutine left once per rematch adds 15 against the slack of 2,
// well above the few that other tests' sockets still holding on can take away in a full-suite run.
func TestRoomsDoNotLeakGoroutines(t *testing.T) {
	cfg := testConfig()
	cfg.hello, cfg.silence = time.Minute, 2*time.Second
	t.Run("plain", func(t *testing.T) { churnRooms(t, cfg) })
	t.Run("test delay", func(t *testing.T) {
		delayed := cfg
		delayed.testDelay = 3 * time.Millisecond
		churnRooms(t, delayed)
	})
	t.Run("batch", func(t *testing.T) {
		batched := cfg
		batched.batch = 5 * time.Millisecond
		churnRooms(t, batched)
	})
}
