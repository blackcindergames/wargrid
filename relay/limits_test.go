package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/lxzan/gws"
)

type fakeClock struct{ t time.Time }

func (c *fakeClock) now() time.Time          { return c.t }
func (c *fakeClock) advance(d time.Duration) { c.t = c.t.Add(d) }

func newFakeClock() *fakeClock { return &fakeClock{t: time.Unix(1_000_000, 0)} }

func prodLimiter(c *fakeClock) *limiter {
	return newLimiter(tableSize, globalBurst, globalPeriod, c.now)
}

func (l *limiter) conns(key string) int {
	l.mu.Lock()
	defer l.mu.Unlock()
	if e := l.entries[key]; e != nil {
		return e.conns
	}
	return 0
}

func TestBucketLeaksOnePerPeriod(t *testing.T) {
	c := newFakeClock()
	l := prodLimiter(c)
	var b bucket
	take := func(n int) (ok int) {
		for range n {
			if l.allow(&b, 10, time.Second) {
				ok++
			}
		}
		return ok
	}
	if got := take(11); got != 10 {
		t.Fatalf("burst: %d of 11 allowed, want 10", got)
	}
	c.advance(time.Second)
	if got := take(2); got != 1 {
		t.Fatalf("after 1 s: %d of 2 allowed, want 1", got)
	}
	c.advance(10 * time.Second)
	if got := take(12); got != 10 {
		t.Fatalf("after 10 s: %d of 12 allowed, want 10", got)
	}
}

func TestConnCountOpenClose(t *testing.T) {
	l := prodLimiter(newFakeClock())
	const key = "203.0.113.1"
	for i := range maxConnsPerIP {
		if reason, tracked := l.open(key); reason != "" || !tracked {
			t.Fatalf("open %d: %q tracked %v", i+1, reason, tracked)
		}
	}
	if reason, tracked := l.open(key); reason != "too many connections" || !tracked {
		t.Fatalf("open %d: %q tracked %v, want refusal that still counts", maxConnsPerIP+1, reason, tracked)
	}
	if got := l.conns(key); got != maxConnsPerIP+1 {
		t.Fatalf("count %d, want %d", got, maxConnsPerIP+1)
	}
	for range maxConnsPerIP + 1 {
		l.close(key, true)
	}
	if got := l.conns(key); got != 0 {
		t.Fatalf("count %d after all closes, want 0", got)
	}
	l.close(key, true)
	if got := l.conns(key); got != 0 {
		t.Fatalf("count %d after an extra close, want 0", got)
	}
	l.close(key, false)

	for range 100 {
		if reason, tracked := l.open(""); reason != "" || tracked {
			t.Fatalf("open(\"\"): %q tracked %v", reason, tracked)
		}
	}
	var none *limiter
	if reason, tracked := none.open(key); reason != "" || tracked {
		t.Fatalf("nil open: %q tracked %v", reason, tracked)
	}
	if none.join(key) != "" || !none.unknown() {
		t.Fatal("nil limiter refused")
	}
	none.close(key, true)
}

func TestTableFullFailsClosed(t *testing.T) {
	c := newFakeClock()
	l := newLimiter(4, 1000, time.Millisecond, c.now)
	for _, k := range []string{"a", "b", "c", "d"} {
		if reason, tracked := l.open(k); reason != "" || !tracked {
			t.Fatalf("open %s: %q tracked %v", k, reason, tracked)
		}
	}
	if reason, tracked := l.open("e"); reason != "relay busy" || tracked {
		t.Fatalf("open e on a full table: %q tracked %v", reason, tracked)
	}
	if reason := l.join("a"); reason != "" {
		t.Fatalf("join a: %q", reason)
	}
	l.close("a", true)
	if reason, _ := l.open("e"); reason != "relay busy" {
		t.Fatalf("open e while a's join bucket still holds a token: %q", reason)
	}
	c.advance(joinBurst * joinPeriod)
	if reason, tracked := l.open("e"); reason != "" || !tracked {
		t.Fatalf("open e after a went idle: %q tracked %v", reason, tracked)
	}
	if len(l.entries) > 4 {
		t.Fatalf("table grew to %d", len(l.entries))
	}
}

func TestClientKey(t *testing.T) {
	const header = "X-Wargrid-Test-Ip"
	req := func(v string) *http.Request {
		r := httptest.NewRequest(http.MethodGet, "/ws", nil)
		if v != "" {
			r.Header.Set(header, v)
		}
		return r
	}
	for _, c := range []struct{ header, value, want string }{
		{"", "203.0.113.7", ""},
		{header, "203.0.113.7", "203.0.113.7"},
		{header, "2001:db8:1:2:3:4:5:6", "2001:db8:1:2::"},
		{header, "2001:db8:1:2:ffff::1", "2001:db8:1:2::"},
		{header, "", ""},
		{header, "not-an-ip", ""},
	} {
		if got := clientKey(req(c.value), c.header); got != c.want {
			t.Errorf("header %q value %q: key %q, want %q", c.header, c.value, got, c.want)
		}
	}
}

func TestUnknownAndGlobalBuckets(t *testing.T) {
	c := newFakeClock()
	l := prodLimiter(c)
	for i := range unknownBurst {
		if !l.unknown() {
			t.Fatalf("unknown %d refused", i+1)
		}
	}
	if l.unknown() {
		t.Fatal("unknown past the burst allowed")
	}

	keys := make([]string, 0, globalBurst)
	for i := range globalBurst - 1 {
		keys = append(keys, "198.51.100."+string(rune('a'+i)))
	}
	keys = append(keys, "")
	for _, k := range keys {
		if reason := l.join(k); reason != "" {
			t.Fatalf("join %q within the global burst: %q", k, reason)
		}
	}
	for _, k := range []string{"198.51.100.z", ""} {
		if reason := l.join(k); reason != "relay busy" {
			t.Fatalf("join %q past the global burst: %q, want relay busy", k, reason)
		}
	}
	c.advance(globalPeriod)
	if reason := l.join(""); reason != "" {
		t.Fatalf("join one period later: %q", reason)
	}
	if reason := l.join(""); reason != "relay busy" {
		t.Fatalf("second join one period later: %q", reason)
	}
}

func TestJoinRateIsPerAddress(t *testing.T) {
	l := prodLimiter(newFakeClock())
	for i := range joinBurst {
		if reason := l.join("203.0.113.3"); reason != "" {
			t.Fatalf("join %d: %q", i+1, reason)
		}
	}
	if reason := l.join("203.0.113.3"); reason != "too many joins" {
		t.Fatalf("join past the burst: %q", reason)
	}
	if reason := l.join("203.0.113.4"); reason != "" {
		t.Fatalf("other address: %q", reason)
	}
}

const (
	testIPHeader = "X-Wargrid-Test-Ip"
	testIP       = "203.0.113.9"
)

func dialAsTestIP(t *testing.T, base string) (*gws.Conn, *cl) {
	t.Helper()
	c := &cl{make(chan string, 50)}
	s, _, err := gws.NewClient(c, &gws.ClientOption{
		Addr:          "ws" + strings.TrimPrefix(base, "http") + "/ws",
		RequestHeader: http.Header{testIPHeader: {testIP}},
	})
	if err != nil {
		t.Fatal(err)
	}
	go s.ReadLoop()
	return s, c
}

func hearUntil(t *testing.T, c *cl, part string) {
	t.Helper()
	for s := hear(t, c); !strings.Contains(s, part); s = hear(t, c) {
		t.Logf("skipping %s", s)
	}
}

func TestLimitsAcrossP2Phases(t *testing.T) {
	createHello := `{"type":"hello","protocol":2,"build":"x","match":"","settings":{}}`
	newRelay := func(cfg config, l *limiter) (*relay, string) {
		h := &relay{reg: newRegistry(cfg), lim: l, ipHeader: testIPHeader}
		srv := httptest.NewServer(newServer(h).Handler)
		t.Cleanup(srv.Close)
		return h, srv.URL
	}

	t.Run("over_again_rematch_draw_no_token", func(t *testing.T) {
		_, url := newRelay(testConfig(), newLimiter(tableSize, 2, time.Hour, time.Now))
		a, ac := dialAsTestIP(t, url)
		say(t, a, createHello)
		w := hear(t, ac)
		b, bc := dialAsTestIP(t, url)
		say(t, b, `{"type":"hello","protocol":2,"build":"x","match":"`+w[strings.Index(w, `"match":"`)+9:len(w)-2]+`"}`)
		hearUntil(t, bc, `"type":"start"`)
		hearUntil(t, ac, `"type":"start"`)
		say(t, a, `{"type":"tick","seat":1,"tick":4,"commands":[]}`)
		say(t, b, `{"type":"tick","seat":2,"tick":4,"commands":[]}`)
		hearUntil(t, bc, `"seat":1,"tick":4`)
		hearUntil(t, ac, `"seat":2,"tick":4`)
		say(t, a, `{"type":"over"}`)
		say(t, b, `{"type":"over"}`)
		say(t, a, `{"type":"again"}`)
		say(t, b, `{"type":"again"}`)
		hearUntil(t, ac, `"type":"start"`)
		hearUntil(t, bc, `"type":"start"`)

		c, cc := dialAsTestIP(t, url)
		say(t, c, createHello)
		if got := hear(t, cc); got != `{"type":"error","reason":"relay busy"}` {
			t.Fatalf("third hello heard %q, want relay busy", got)
		}
	})

	t.Run("lobby_expiry_decrements_the_count", func(t *testing.T) {
		cfg := testConfig()
		cfg.lobby = 50 * time.Millisecond
		l := newLimiter(tableSize, 100, time.Second, time.Now)
		_, url := newRelay(cfg, l)
		a, ac := dialAsTestIP(t, url)
		say(t, a, createHello)
		hear(t, ac)
		eventually(t, "socket not counted for its address", func() bool { return l.conns(testIP) == 1 })
		hearUntil(t, ac, "lobby expired")
		eventually(t, "count not back to 0 after the lobby expired", func() bool { return l.conns(testIP) == 0 })
	})
}
