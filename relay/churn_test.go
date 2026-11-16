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

func churnRoom(t *testing.T, base string, rematch bool) {
	t.Helper()
	a, ac := dial(t, base)
	say(t, a, `{"type":"hello","protocol":2,"build":"x","match":"","settings":{}}`)
	w := hear(t, ac)
	b, bc := dial(t, base)
	say(t, b, `{"type":"hello","protocol":2,"build":"x","match":"`+w[strings.Index(w, `"match":"`)+9:len(w)-2]+`"}`)
	hear(t, bc)
	hear(t, bc)
	hear(t, ac)
	for tick := 4; tick <= 6; tick++ {
		say(t, a, tickFrame(1, tick))
		say(t, b, tickFrame(2, tick))
	}
	if rematch {
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

func TestRoomsDoNotLeakGoroutines(t *testing.T) {
	cfg := testConfig()
	cfg.silence = 2 * time.Second
	srv := httptest.NewServer(newServer(&relay{reg: newRegistry(cfg)}).Handler)
	defer srv.Close()
	churnRoom(t, srv.URL, false)
	baseline := settledGoroutines()
	for i := range 50 {
		churnRoom(t, srv.URL, i%10 == 9)
	}
	// Slack of 2 for the HTTP server's idle goroutines, which come and go with the scheduler.
	final := runtime.NumGoroutine()
	for deadline := time.Now().Add(5 * time.Second); final > baseline+2 && time.Now().Before(deadline); final = runtime.NumGoroutine() {
		time.Sleep(20 * time.Millisecond)
	}
	if final > baseline+2 {
		t.Fatalf("goroutines: baseline %d, after 50 rooms %d", baseline, final)
	}
	t.Logf("goroutines: baseline %d, after 50 rooms %d", baseline, final)
}
