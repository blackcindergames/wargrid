package main

import (
	"fmt"
	"sync/atomic"
	"testing"
	"time"
)

func seatedLobby(t *testing.T, g *registry, match string, write func([]byte), set func(time.Time)) (*conn, *atomic.Bool) {
	t.Helper()
	c, shut := loopConn(write)
	c.dl.set = set
	e := &envelope{protocol: lobbyProtocol, build: "b", match: match}
	if match == "" {
		e.raw = []byte(`{"map":"a"}`)
	}
	res := g.join(e, c)
	if res.seat == nil {
		t.Fatalf("join %q: %s", match, res.reason)
	}
	bindSeat(c, res.seat)
	return c, shut
}

func lobbyPair(t *testing.T, cfg config) (a, b *conn, fa, fb *frames) {
	t.Helper()
	g := newRegistry(cfg)
	fa, fb = &frames{}, &frames{}
	a, _ = seatedLobby(t, g, "", fa.write, nil)
	b, _ = seatedLobby(t, g, a.room.code, fb.write, nil)
	return a, b, fa, fb
}

func send(c *conn, raw string) { c.room.post(settingsMsg{c.seat, []byte(raw)}) }

func rejectedWith(t *testing.T, what string, f *frames, reason string) {
	t.Helper()
	eventually(t, what+": no error "+reason, func() bool { return f.has(`{"type":"error","reason":"` + reason + `"}`) })
}

func TestProtocol2WelcomeBytesUnchanged(t *testing.T) {
	g := newRegistry(testConfig())
	f := &frames{}
	a, _ := seated(t, g, "", f.write)
	if got, want := f.first(), fmt.Sprintf(`{"type":"welcome","seat":1,"match":%q}`, a.room.code); got != want {
		t.Fatalf("welcome %s want %s", got, want)
	}
}

func (f *frames) first() string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return string(f.got[0])
}

func TestWelcomeCarriesLatestSettingsAndHostHearsJoined(t *testing.T) {
	cfg := testConfig()
	cfg.seats = 3
	g := newRegistry(cfg)
	fa, fb, fc := &frames{}, &frames{}, &frames{}
	a, _ := seatedLobby(t, g, "", fa.write, nil)
	code := a.room.code
	if want := fmt.Sprintf(`{"type":"welcome","seat":1,"match":%q,"settings":{"map":"a"}}`, code); fa.first() != want {
		t.Fatalf("host welcome %s want %s", fa.first(), want)
	}
	seatedLobby(t, g, code, fb.write, nil)
	if want := fmt.Sprintf(`{"type":"welcome","seat":2,"match":%q,"settings":{"map":"a"}}`, code); fb.first() != want {
		t.Fatalf("guest welcome %s want %s", fb.first(), want)
	}
	eventually(t, "no joined", func() bool { return fa.has(`{"type":"joined","seat":2}`) })
	send(a, `{ "map" : "b" }`)
	eventually(t, "settings not forwarded", func() bool { return fb.has(`"type":"settings"`) })
	seatedLobby(t, g, code, fc.write, nil)
	if want := fmt.Sprintf(`{"type":"welcome","seat":3,"match":%q,"settings":{ "map" : "b" }}`, code); fc.first() != want {
		t.Fatalf("late guest welcome %s want %s", fc.first(), want)
	}
	eventually(t, "second joined", func() bool { return fa.has(`{"type":"joined","seat":3}`) && fb.has(`{"type":"joined","seat":3}`) })
	if fb.has(`{"type":"joined","seat":2}`) || fc.has(`"type":"joined"`) {
		t.Fatal("joined went to its own seat")
	}
}

func TestSettingsRefusedInProtocol2Room(t *testing.T) {
	g := newRegistry(testConfig())
	f := &frames{}
	a, _ := seated(t, g, "", f.write)
	send(a, `{"map":"x"}`)
	rejectedWith(t, "protocol 2 room", f, "invalid message")
}

func TestRefusedSettingsNotStoredOrForwarded(t *testing.T) {
	cfg := testConfig()
	cfg.seats = 3
	g := newRegistry(cfg)
	fb := &frames{}
	a, _ := seatedLobby(t, g, "", nop, nil)
	b, _ := seatedLobby(t, g, a.room.code, fb.write, nil)
	send(b, `{"map":"guest"}`)
	eventually(t, "guest not rejected", func() bool { return fb.has(`"error"`) })
	fc := &frames{}
	seatedLobby(t, g, a.room.code, fc.write, nil)
	if want := fmt.Sprintf(`{"type":"welcome","seat":3,"match":%q,"settings":{"map":"a"}}`, a.room.code); fc.first() != want {
		t.Fatalf("welcome %s", fc.first())
	}
}

func TestStartListsOnlyPresentSeats(t *testing.T) {
	r, fs := testRoom(t, 3)
	r.started, r.protocol, r.settings = false, lobbyProtocol, []byte(`{}`)
	delete(r.seats, 2)
	r.start()
	if !fs[0].has(`"seats":[1,3],`) || !fs[2].has(`"seats":[1,3],`) {
		t.Fatalf("start %q", lastFrame(fs[0]))
	}
}

func TestHostLeavingClosesRoom(t *testing.T) {
	a, b, _, fb := lobbyPair(t, testConfig())
	r, code, reg := a.room, a.room.code, a.room.reg
	a.close()
	rejectedWith(t, "host left", fb, "host left")
	if reg.count() != 0 {
		t.Fatal("room still registered")
	}
	c, _ := loopConn(nop)
	if res := reg.join(&envelope{protocol: lobbyProtocol, build: "b", match: code}, c); res.reason != "unknown match" {
		t.Fatalf("join after host left: %+v", res)
	}
	req := joinReq{&envelope{protocol: lobbyProtocol, build: "b", match: code}, c, make(chan joinResult, 1)}
	r.joins <- req
	if res := <-req.reply; res.seat != nil || res.reason != "unknown match" {
		t.Fatalf("join queued at the room after host left: %+v", res)
	}
	b.close()
	ended(t, r)
}

func TestHostLeavingAfterStartKeepsPlainLeft(t *testing.T) {
	a, _, fa, fb := lobbyPair(t, testConfig())
	a.room.post(startRequestMsg{a.seat})
	eventually(t, "no start", func() bool { return fa.has(`"type":"start"`) })
	a.close()
	eventually(t, "no left", func() bool { return fb.has(`{"type":"left","seat":1,"after_tick":3}`) })
	if fb.has("host left") {
		t.Fatal("started match got host left")
	}
}

func TestJoinWithOtherProtocolRefused(t *testing.T) {
	g := newRegistry(testConfig())
	a, _ := seatedLobby(t, g, "", nop, nil)
	b, _ := loopConn(nop)
	if res := g.join(&envelope{protocol: protocol, build: "b", match: a.room.code}, b); res.reason != "protocol mismatch" {
		t.Fatalf("protocol 2 into a protocol 3 room: %+v", res)
	}
	a2, _ := seated(t, g, "", nop)
	if res := g.join(&envelope{protocol: lobbyProtocol, build: "b", match: a2.room.code}, b); res.reason != "protocol mismatch" {
		t.Fatalf("protocol 3 into a protocol 2 room: %+v", res)
	}
	if res := g.join(&envelope{protocol: protocol, build: "other", match: a.room.code}, b); res.reason != "build mismatch" {
		t.Fatalf("other protocol and other build: %+v", res)
	}
}

func TestSettingsRefillAcceptsTwoMoreAfterOneSecond(t *testing.T) {
	a, _, fa, fb := lobbyPair(t, testConfig())
	for range settingsBurst {
		send(a, `{"map":"x"}`)
	}
	time.Sleep(1500 * time.Millisecond)
	send(a, `{"map":"y"}`)
	send(a, `{"map":"z"}`)
	eventually(t, "refilled settings not forwarded", func() bool { return fb.count(`"type":"settings"`) == settingsBurst+2 })
	if fa.has(`"error"`) {
		t.Fatal("host rejected after the refill")
	}
}

func TestBucketRefillsTwoPerSecond(t *testing.T) {
	var b bucket
	now := time.Unix(1_000_000, 0)
	for i := range settingsBurst {
		if !b.allow(now, settingsBurst, settingsPeriod) {
			t.Fatalf("take %d refused", i)
		}
	}
	if b.allow(now, settingsBurst, settingsPeriod) {
		t.Fatal("burst exceeded")
	}
	now = now.Add(time.Second)
	got := 0
	for range 5 {
		if b.allow(now, settingsBurst, settingsPeriod) {
			got++
		}
	}
	if got != 2 {
		t.Fatalf("one second refilled %d, want 2", got)
	}
}

func TestSettingsMoveExpiryAndHoldEverySeat(t *testing.T) {
	cfg := testConfig()
	cfg.lobby = time.Hour
	cfg.lobbyCap = 3 * time.Hour
	g := newRegistry(cfg)
	recA, recB := &recorder{}, &recorder{}
	a, _ := seatedLobby(t, g, "", nop, recA.set)
	seatedLobby(t, g, a.room.code, nop, recB.set)
	a.room.expiresAt = time.Now().Add(time.Minute) // a stale expiry that settings must move
	before, beforeB := len(recA.all()), len(recB.all())
	send(a, `{"map":"x"}`)
	eventually(t, "no re-hold", func() bool { return len(recA.all()) > before && len(recB.all()) > beforeB })
	want := time.Now().Add(time.Hour + expiryGrace)
	for i, rec := range []*recorder{recA, recB} {
		if got := rec.last(); !near(got, want) {
			t.Fatalf("seat %d deadline %v want about %v", i+1, got, want)
		}
	}
}

func TestSettingsExpiryStopsAtHardCap(t *testing.T) {
	cfg := testConfig()
	cfg.lobby = time.Hour
	cfg.lobbyCap = 2 * time.Hour
	g := newRegistry(cfg)
	rec := &recorder{}
	a, _ := seatedLobby(t, g, "", nop, rec.set)
	a.room.created = time.Now().Add(-90 * time.Minute)
	before := len(rec.all())
	send(a, `{"map":"x"}`)
	eventually(t, "no re-hold", func() bool { return len(rec.all()) > before })
	if want := time.Now().Add(30*time.Minute + expiryGrace); rec.last().Sub(want).Abs() > time.Minute {
		t.Fatalf("deadline %v want about %v (cap, not a full lobby window)", rec.last(), want)
	}
}

func TestParseLobbyMessages(t *testing.T) {
	cases := map[string]bool{
		`{"type":"settings","settings":{"map":"x"}}`:                                  true,
		`{"type":"settings","settings":{ "map" : "x" }}`:                              true,
		`{"type":"settings"}`:                                                         false,
		`{"type":"settings","settings":null}`:                                         false,
		`{"type":"settings","settings":[1]}`:                                          false,
		`{"type":"settings","settings":"x"}`:                                          false,
		`{"type":"settings","settings":{"k":"` + fmt.Sprintf("%4091s", "") + `"}}`:    false,
		`{"type":"start_request"}`:                                                    true,
		`{"type":"start_request"} x`:                                                  false,
		`{"type":"joined","seat":2}`:                                                  false,
		`{"type":"hello","protocol":3,"build":"a","match":"","settings":{"map":"x"}}`: true,
	}
	for in, want := range cases {
		if (parseEnvelope([]byte(in)) != nil) != want {
			t.Errorf("%.80s: want valid=%v", in, want)
		}
	}
	if e := parseEnvelope([]byte(`{"type":"settings","settings":{ "a" : 1 }}`)); e == nil || string(e.raw) != `{ "a" : 1 }` {
		t.Errorf("settings bytes %+v", e)
	}
}

func TestPickReachesOnlyTheHostAndKeepsExpiry(t *testing.T) {
	cfg := testConfig()
	cfg.seats = 3
	g := newRegistry(cfg)
	rec := &recorder{}
	fa, fb, fc := &frames{}, &frames{}, &frames{}
	a, _ := seatedLobby(t, g, "", fa.write, rec.set)
	b, _ := seatedLobby(t, g, a.room.code, fb.write, nil)
	seatedLobby(t, g, a.room.code, fc.write, nil)
	holds := len(rec.all())
	b.room.post(pickMsg{b.seat, []byte(`{ "faction" : "usa" }`)})
	eventually(t, "pick not forwarded", func() bool { return fa.has(`{"type":"pick","seat":2,"pick":{ "faction" : "usa" }}`) })
	a.room.post(settingsMsg{a.seat, []byte(`{"map":"x"}`)})
	b.room.post(pickMsg{b.seat, []byte(`{"faction":"china"}`)}) // queued behind the settings: both picks are in before holds are counted
	eventually(t, "settings or second pick not forwarded", func() bool { return fc.has(`"type":"settings"`) && fa.count(`"type":"pick"`) == 2 })
	if fb.has(`"type":"pick"`) || fc.has(`"type":"pick"`) {
		t.Fatal("pick reached a guest")
	}
	if len(rec.all()) != holds+1 {
		t.Fatalf("deadline holds %d, want %d: pick must not extend the lobby, settings must", len(rec.all()), holds+1)
	}
}

func TestPickInProtocol2RoomRefused(t *testing.T) {
	cfg := testConfig()
	cfg.seats = 3
	g := newRegistry(cfg)
	fa, fb := &frames{}, &frames{}
	a, _ := seated(t, g, "", fa.write)
	b, _ := seated(t, g, a.room.code, fb.write)
	b.room.post(pickMsg{b.seat, []byte(`{"faction":"usa"}`)})
	rejectedWith(t, "protocol 2 pick", fb, "invalid message")
	if fa.has(`"type":"pick"`) {
		t.Fatal("pick reached seat 1 of a protocol 2 room")
	}
}
