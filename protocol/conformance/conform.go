package main

import (
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const wait = 3 * time.Second

// The relay's timeouts (WARGRID_SILENCE_MS, WARGRID_HELLO_MS, WARGRID_LOBBY_MS); set by -silence, -hello, -lobby.
var (
	silence    = 10 * time.Second
	helloLimit = 5 * time.Second
	lobbyLimit = 15 * time.Minute
)

type failure struct{ msg string }

func check(cond bool, format string, args ...any) {
	if !cond {
		panic(failure{fmt.Sprintf(format, args...)})
	}
}

func must[T any](v T, err error) T {
	check(err == nil, "unexpected error: %v", err)
	return v
}

func expect(cl *client, want string) {
	got, err := cl.hear(wait)
	check(err == nil, "want %q, got error %v", want, err)
	check(got == want, "want %q\n       got  %q", want, got)
}

// expectClosed: the server must close the socket without sending anything else first.
func expectClosed(cl *client) {
	got, err := cl.hear(wait)
	check(err == errClosed, "want close, got %q err %v", got, err)
}

func startPrefix(seats int) string {
	ids := make([]string, seats)
	for i := range ids {
		ids[i] = fmt.Sprint(i + 1)
	}
	return fmt.Sprintf(`{"type":"start","seats":[%s],"delay":4,"seed":`, strings.Join(ids, ","))
}

// expectStart checks the start bytes: fixed prefix, seed in range, the creator's settings text; returns the seed.
func expectStart(cl *client, seats int, settings string) int {
	got, err := cl.hear(wait)
	check(err == nil, "want start, got error %v", err)
	pre, suf := startPrefix(seats), `,"settings":`+settings+`}`
	check(strings.HasPrefix(got, pre) && strings.HasSuffix(got, suf), "bad start %q", got)
	seed, err := strconv.Atoi(got[len(pre) : len(got)-len(suf)])
	check(err == nil && seed >= 0 && seed <= 2147483647, "bad seed in %q", got)
	return seed
}

// room joins `seats` clients and checks welcome/start bytes; returns clients indexed by seat-1.
func room(url string, seats int, build string) ([]*client, string) {
	cls, code, _ := roomWith(url, seats, build, "{}")
	return cls, code
}

func roomWith(url string, seats int, build, settings string) ([]*client, string, int) {
	first := must(dial(url))
	check(first.say(helloSettings("", build, 2, settings)) == nil, "send")
	w := must(first.hear(wait))
	code := codeOf(w)
	check(code != "" && w == fmt.Sprintf(`{"type":"welcome","seat":1,"match":"%s"}`, code), "bad welcome %q", w)
	cls := []*client{first}
	for s := 2; s <= seats; s++ {
		cl := must(dial(url))
		check(cl.say(hello(code, build, 2)) == nil, "send")
		expect(cl, fmt.Sprintf(`{"type":"welcome","seat":%d,"match":"%s"}`, s, code))
		cls = append(cls, cl)
	}
	seed := expectStart(cls[0], seats, settings)
	for _, cl := range cls[1:] {
		check(expectStart(cl, seats, settings) == seed, "seats got different seeds")
	}
	return cls, code, seed
}

func closeAll(cls []*client) {
	for _, c := range cls {
		c.close()
	}
}

const (
	errInvalid  = `{"type":"error","reason":"invalid message"}`
	roomExpired = `{"type":"error","reason":"room expired"}`
	over        = `{"type":"over"}`
	again       = `{"type":"again"}`
)

func againFrom(seat int) string { return fmt.Sprintf(`{"type":"again","seat":%d}`, seat) }

// rejectAfterOver: seat 1 ticks 4 and sends over, optionally again, then text; expects error, close, and left(1, 4).
func rejectAfterOver(url, text string, withAgain bool) {
	cls, _ := room(url, 2, "abc")
	defer closeAll(cls)
	cls[0].say(tick(1, 4, ""))
	expect(cls[1], tick(1, 4, ""))
	cls[0].say(over)
	if withAgain {
		cls[0].say(again)
		expect(cls[1], againFrom(1))
	}
	cls[0].say(text)
	expect(cls[0], errInvalid)
	expectClosed(cls[0])
	expect(cls[1], left(1, 4))
}

// parkedRoom: both seats tick 4, hear each other and send over.
func parkedRoom(url string) []*client {
	cls, _ := room(url, 2, "abc")
	cls[0].say(tick(1, 4, ""))
	cls[1].say(tick(2, 4, ""))
	expect(cls[1], tick(1, 4, ""))
	expect(cls[0], tick(2, 4, ""))
	cls[0].say(over)
	cls[1].say(over)
	return cls
}

// rematchStart: both seats send again, hear the other's, and get one start with a shared seed.
func rematchStart(cls []*client, settings string) int {
	cls[0].say(again)
	expect(cls[1], againFrom(1))
	cls[1].say(again)
	expect(cls[0], againFrom(2))
	seed := expectStart(cls[0], 2, settings)
	check(expectStart(cls[1], 2, settings) == seed, "seats got different rematch seeds")
	return seed
}

// quiet: nothing arrives within d.
func quiet(cl *client, d time.Duration) {
	got, err := cl.hear(d)
	check(err != nil && err != errClosed, "want nothing for %v, got %q err %v", d, got, err)
}

func left(seat, after int) string {
	return fmt.Sprintf(`{"type":"left","seat":%d,"after_tick":%d}`, seat, after)
}

// rejectAfterJoin: seat 1 sends text after start, expects error, close, and seat 2 sees left after `after`.
func rejectAfterJoin(url string, text string, after int, before ...string) {
	cls, _ := room(url, 2, "abc")
	defer closeAll(cls)
	for _, b := range before {
		check(cls[0].say(b) == nil, "send")
		expect(cls[1], b)
	}
	check(cls[0].say(text) == nil, "send")
	expect(cls[0], errInvalid)
	expectClosed(cls[0])
	expect(cls[1], left(1, after))
}

type tcase struct {
	name string
	run  func(url string)
}

func defaultCases() []tcase {
	return []tcase{
		{"health", func(url string) {
			h := strings.Replace(strings.Replace(url, "ws://", "http://", 1), "wss://", "https://", 1)
			resp := must(http.Get(strings.TrimSuffix(h, "/ws") + "/health"))
			body := must(io.ReadAll(resp.Body))
			check(resp.StatusCode == 200 && string(body) == "ok", "health %d %q", resp.StatusCode, body)
		}},
		{"create_join_start", func(url string) { cls, _ := room(url, 2, "abc"); closeAll(cls) }},
		{"forwards_byte_for_byte", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			frame := `{"type":"tick","seat":1,"tick":4,"commands":[{"target":[14.1,0.30000000000000004]}],"hash":{"tick":30,"value":"3a0ad3856b168044"}}`
			cls[0].say(frame)
			cls[0].say(tick(1, 5, ""))
			expect(cls[1], frame)
			expect(cls[1], tick(1, 5, ""))
			cls[1].say(tick(2, 4, `{"x":"ü€"}`))
			expect(cls[0], tick(2, 4, `{"x":"ü€"}`))
		}},
		{"spaced_json_forwarded_verbatim", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			frame := "{ \"commands\" : [ ] , \"tick\" : 4.0, \"seat\":1, \"type\":\"tick\" }"
			cls[0].say(frame)
			expect(cls[1], frame)
		}},
		{"wrong_seat", func(url string) { rejectAfterJoin(url, tick(2, 4, ""), 3) }},
		{"non_contiguous_tick", func(url string) { rejectAfterJoin(url, tick(1, 6, ""), 4, tick(1, 4, "")) }},
		{"first_tick_before_delay", func(url string) { rejectAfterJoin(url, tick(1, 3, ""), 3) }},
		{"fractional_tick", func(url string) { rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":4.5,"commands":[]}`, 3) }},
		{"string_tick", func(url string) { rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":"4","commands":[]}`, 3) }},
		{"commands_not_array", func(url string) { rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":4,"commands":{}}`, 3) }},
		{"bad_hash_value", func(url string) {
			rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":4,"commands":[],"hash":{"tick":30,"value":"3A0AD3856B168044"}}`, 3)
		}},
		{"hash_not_object", func(url string) { rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":4,"commands":[],"hash":5}`, 3) }},
		{"not_object", func(url string) { rejectAfterJoin(url, `[1,2]`, 3) }},
		{"not_json", func(url string) { rejectAfterJoin(url, `{"type":`, 3) }},
		{"unknown_type", func(url string) { rejectAfterJoin(url, `{"type":"cheat"}`, 3) }},
		{"server_type_from_client", func(url string) { rejectAfterJoin(url, left(1, 3), 3) }},
		{"hello_after_join", func(url string) { rejectAfterJoin(url, hello("", "abc", 2), 3) }},
		{"huge_int_tick", func(url string) { rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":4294967300,"commands":[]}`, 3) }},
		{"ping_before_hello", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(`{"type":"ping","t":1}`)
			expect(cl, errInvalid)
			expectClosed(cl)
		}},
		{"tick_before_start", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello("", "abc", 2))
			must(cl.hear(wait))
			cl.say(tick(1, 4, ""))
			expect(cl, errInvalid)
			expectClosed(cl)
		}},
		{"protocol_and_build_mismatch", func(url string) {
			p := must(dial(url))
			defer p.close()
			p.say(`{"type":"hello","protocol":1,"build":"abc","match":""}`)
			expect(p, `{"type":"error","reason":"protocol mismatch"}`)
			expectClosed(p)
			p3 := must(dial(url))
			defer p3.close()
			p3.say(hello("", "abc", 3))
			expect(p3, `{"type":"error","reason":"protocol mismatch"}`)
			expectClosed(p3)
			a := must(dial(url))
			defer a.close()
			a.say(hello("", "abc", 2))
			code := codeOf(must(a.hear(wait)))
			b := must(dial(url))
			defer b.close()
			b.say(hello(code, "other", 2))
			expect(b, `{"type":"error","reason":"build mismatch"}`)
			expectClosed(b)
			c := must(dial(url))
			defer c.close()
			c.say(hello(code, "abc", 2))
			expect(c, fmt.Sprintf(`{"type":"welcome","seat":2,"match":"%s"}`, code))
		}},
		{"unknown_match", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello("ZZZZZZ", "abc", 2))
			expect(cl, `{"type":"error","reason":"unknown match"}`)
			expectClosed(cl)
		}},
		{"match_full", func(url string) {
			cls, code := room(url, 2, "abc")
			defer closeAll(cls)
			third := must(dial(url))
			defer third.close()
			third.say(hello(code, "abc", 2))
			expect(third, `{"type":"error","reason":"match full"}`)
			expectClosed(third)
			cls[0].say(tick(1, 4, ""))
			expect(cls[1], tick(1, 4, ""))
		}},
		{"frame_cap_boundary", func(url string) {
			overhead := len(tick(1, 4, `""`))
			exact := tick(1, 4, `"`+strings.Repeat("x", 65536-overhead)+`"`)
			check(len(exact) == 65536, "len %d", len(exact))
			over := tick(1, 5, `"`+strings.Repeat("x", 65537-overhead)+`"`)
			rejectAfterJoin(url, over, 4, exact)
		}},
		{"multibyte_counts_bytes", func(url string) {
			overhead := len(tick(1, 4, `""`))
			// 65535-overhead ASCII + one 2-byte char = 65537 bytes but fewer runes
			over := tick(1, 4, `"`+strings.Repeat("x", 65535-overhead)+"ü"+`"`)
			check(len(over) == 65537, "len %d", len(over))
			rejectAfterJoin(url, over, 3)
		}},
		{"close_announces_left_with_last_tick", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			cls[1].say(tick(2, 4, ""))
			cls[1].say(tick(2, 5, ""))
			expect(cls[0], tick(2, 4, ""))
			expect(cls[0], tick(2, 5, ""))
			cls[1].close()
			expect(cls[0], left(2, 5))
			cls[0].say(`{"type":"ping","t":1}`)
			expect(cls[0], `{"type":"pong","t":1}`)
			cls[0].say(tick(1, 4, ""))
			cls[0].say(`{"type":"ping","t":2}`)
			expect(cls[0], `{"type":"pong","t":2}`)
		}},
		{"binary_frame_ends_connection", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			cls[0].sayBinary([]byte(tick(1, 4, "")))
			expectClosed(cls[0])
			expect(cls[1], left(1, 3))
		}},
		{"ping_pong", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello("", "abc", 2))
			must(cl.hear(wait))
			cl.say(`{"type":"ping","t":123}`)
			expect(cl, `{"type":"pong","t":123}`)
			cl.say(`{"type":"ping","t":1730000000123}`)
			expect(cl, `{"type":"pong","t":1730000000123}`)
			cl.say(`{"type":"ping","t":"x"}`)
			expect(cl, errInvalid)
		}},
		{"room_code_freed_after_empty", func(url string) {
			cls, code := room(url, 2, "abc")
			closeAll(cls)
			time.Sleep(300 * time.Millisecond)
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello(code, "abc", 2))
			expect(cl, `{"type":"error","reason":"unknown match"}`)
		}},
		{"started_room_stays_full_after_leave", func(url string) {
			cls, code := room(url, 2, "abc")
			defer closeAll(cls)
			cls[1].close()
			expect(cls[0], left(2, 3))
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello(code, "abc", 2))
			expect(cl, `{"type":"error","reason":"match full"}`)
		}},
		{"settings_echoed_byte_exact", func(url string) {
			text := `{ "map" : "ashfall", "n":1.50, "u":"ü€", "nested":{"a":[1, 2]} }`
			cls, _, _ := roomWith(url, 2, "abc", text)
			closeAll(cls)
		}},
		{"joiner_settings_ignored", func(url string) {
			first := must(dial(url))
			defer first.close()
			first.say(helloSettings("", "abc", 2, `{"map":"host"}`))
			code := codeOf(must(first.hear(wait)))
			second := must(dial(url))
			defer second.close()
			second.say(fmt.Sprintf(`{"type":"hello","protocol":2,"build":"abc","match":"%s","settings":{"map":"other"}}`, code))
			must(second.hear(wait))
			expectStart(first, 2, `{"map":"host"}`)
			expectStart(second, 2, `{"map":"host"}`)
		}},
		{"create_without_settings_refused", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(`{"type":"hello","protocol":2,"build":"abc","match":""}`)
			expect(cl, `{"type":"error","reason":"missing settings"}`)
			expectClosed(cl)
		}},
		{"protocol_beats_bad_settings", func(url string) {
			for _, bad := range []string{`"x"`, `{"k":"` + strings.Repeat("x", 4090) + `"}`} {
				cl := must(dial(url))
				cl.say(helloSettings("", "abc", 3, bad))
				expect(cl, `{"type":"error","reason":"protocol mismatch"}`)
				expectClosed(cl)
				cl.close()
			}
		}},
		{"settings_null_refused", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(helloSettings("", "abc", 2, `null`))
			expect(cl, errInvalid)
			expectClosed(cl)
		}},
		{"settings_not_object_refused", func(url string) {
			for _, bad := range []string{`"x"`, `[1]`} {
				cl := must(dial(url))
				cl.say(helloSettings("", "abc", 2, bad))
				expect(cl, errInvalid)
				expectClosed(cl)
				cl.close()
			}
		}},
		{"settings_over_cap_refused", func(url string) {
			pad := func(n int) string { return `{"k":"` + strings.Repeat("x", n-8) + `"}` }
			ok := must(dial(url))
			defer ok.close()
			ok.say(helloSettings("", "abc", 2, pad(4096)))
			check(codeOf(must(ok.hear(wait))) != "", "4096 bytes refused")
			over := must(dial(url))
			defer over.close()
			over.say(helloSettings("", "abc", 2, pad(4097)))
			expect(over, errInvalid)
			expectClosed(over)
		}},
		{"rematch_before_hello", func(url string) {
			for _, text := range []string{over, again} {
				cl := must(dial(url))
				cl.say(text)
				expect(cl, errInvalid)
				expectClosed(cl)
				cl.close()
			}
		}},
		{"over_in_lobby", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello("", "abc", 2))
			must(cl.hear(wait))
			cl.say(over)
			expect(cl, errInvalid)
			expectClosed(cl)
		}},
		{"over_before_first_tick", func(url string) { rejectAfterJoin(url, over, 3) }},
		{"over_twice", func(url string) { rejectAfterOver(url, over, false) }},
		{"tick_after_over", func(url string) { rejectAfterOver(url, tick(1, 5, ""), false) }},
		{"again_before_over", func(url string) { rejectAfterJoin(url, again, 4, tick(1, 4, "")) }},
		{"again_twice", func(url string) { rejectAfterOver(url, again, true) }},
		{"tick_after_again", func(url string) { rejectAfterOver(url, tick(1, 5, ""), true) }},
		{"binary_after_over", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			cls[0].say(tick(1, 4, ""))
			cls[1].say(tick(2, 4, ""))
			expect(cls[1], tick(1, 4, ""))
			expect(cls[0], tick(2, 4, ""))
			cls[0].say(over)
			cls[0].sayBinary([]byte(again))
			expectClosed(cls[0])
			expect(cls[1], left(1, 4))
		}},
		{"rematch_round_trip", func(url string) {
			settings := `{"map":"x"}`
			cls, code, s1 := roomWith(url, 2, "abc", settings)
			defer closeAll(cls)
			cls[0].say(tick(1, 4, ""))
			cls[1].say(tick(2, 4, ""))
			expect(cls[1], tick(1, 4, ""))
			expect(cls[0], tick(2, 4, ""))
			cls[0].say(over)
			cls[1].say(tick(2, 5, ""))
			expect(cls[0], tick(2, 5, ""))
			cls[1].say(over)
			cls[0].say(`{"type":"ping","t":1}`)
			expect(cls[0], `{"type":"pong","t":1}`)
			cls[0].say(again)
			expect(cls[1], againFrom(1))
			quiet(cls[0], 200*time.Millisecond)
			cls[1].say(again)
			expect(cls[0], againFrom(2))
			s2 := expectStart(cls[0], 2, settings)
			check(expectStart(cls[1], 2, settings) == s2, "seats got different rematch seeds")
			check(s2 != s1, "rematch kept seed %d", s1)
			cls[0].say(tick(1, 4, ""))
			cls[1].say(tick(2, 4, ""))
			expect(cls[1], tick(1, 4, ""))
			expect(cls[0], tick(2, 4, ""))
			third := must(dial(url))
			defer third.close()
			third.say(hello(code, "abc", 2))
			expect(third, `{"type":"error","reason":"match full"}`)
		}},
		{"rematch_needs_every_seat", func(url string) {
			cls := parkedRoom(url)
			defer closeAll(cls)
			cls[1].close()
			expect(cls[0], left(2, 4))
			cls[0].say(again)
			cls[0].say(`{"type":"ping","t":1}`)
			expect(cls[0], `{"type":"pong","t":1}`)
			quiet(cls[0], 300*time.Millisecond)
		}},
		{"seed_in_range_and_varies", func(url string) {
			seeds := map[int]bool{}
			for range 3 {
				cls, _, seed := roomWith(url, 2, "abc", "{}")
				closeAll(cls)
				seeds[seed] = true
			}
			check(len(seeds) > 1, "three rooms, one seed")
		}},
	}
}

// pingUntil sends a JSON ping every 100 ms and returns the first frame that is not a pong, or errClosed.
func pingUntil(cl *client, limit time.Duration) (string, error) {
	tk := time.NewTicker(100 * time.Millisecond)
	defer tk.Stop()
	end := time.After(limit)
	for i := 0; ; i++ {
		select {
		case <-tk.C:
			_ = cl.say(fmt.Sprintf(`{"type":"ping","t":%d}`, i))
		case s, ok := <-cl.in:
			if !ok {
				return "", errClosed
			}
			if !strings.HasPrefix(s, `{"type":"pong"`) {
				return s, nil
			}
		case <-end:
			return "", fmt.Errorf("nothing but pongs for %v", limit)
		}
	}
}

func silenceCases() []tcase {
	return []tcase{
		{"silence_announces_left", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			cls[0].say(tick(1, 4, ""))
			// seat 2 keeps pinging past the server's silence timeout; seat 1 stays silent after its tick
			for i := 0; time.Duration(i)*100*time.Millisecond < silence+500*time.Millisecond; i++ {
				cls[1].say(fmt.Sprintf(`{"type":"ping","t":%d}`, i))
				time.Sleep(100 * time.Millisecond)
			}
			var got []string
			for {
				s, err := cls[1].hear(200 * time.Millisecond)
				if err != nil {
					break
				}
				got = append(got, s)
			}
			found := false
			for _, s := range got {
				found = found || s == left(1, 4)
			}
			check(found, "no left in %v", got)
			expectClosed(cls[0])
		}},
		{"hello_deadline", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			start := time.Now()
			got, err := cl.hear(helloLimit + wait)
			el := time.Since(start)
			check(err == errClosed, "want close, got %q err %v", got, err)
			check(el >= helloLimit/2 && el <= helloLimit+wait, "closed after %v", el)
		}},
		{"hello_deadline_ignores_protocol_pings", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			for end := time.Now().Add(helloLimit + time.Second); time.Now().Before(end); {
				got, err := cl.hear(100 * time.Millisecond)
				if err == errClosed {
					return
				}
				check(err != nil, "unexpected frame %q", got)
				_ = cl.ping()
			}
			check(false, "still open %v after connect despite no hello", helloLimit+time.Second)
		}},
		{"lobby_survives_silence", func(url string) {
			first := must(dial(url))
			defer first.close()
			first.say(hello("", "abc", 2))
			code := codeOf(must(first.hear(wait)))
			time.Sleep(max(3*silence, helloLimit+silence))
			second := must(dial(url))
			defer second.close()
			second.say(hello(code, "abc", 2))
			expect(second, fmt.Sprintf(`{"type":"welcome","seat":2,"match":"%s"}`, code))
			seed := expectStart(first, 2, "{}")
			check(expectStart(second, 2, "{}") == seed, "seats got different seeds")
		}},
		{"lobby_expires_despite_pings", func(url string) {
			first := must(dial(url))
			defer first.close()
			first.say(hello("", "abc", 2))
			code := codeOf(must(first.hear(wait)))
			start := time.Now()
			got, err := pingUntil(first, lobbyLimit+time.Second)
			el := time.Since(start)
			check(err == nil && got == `{"type":"error","reason":"lobby expired"}`, "want lobby expired, got %q err %v", got, err)
			check(el >= lobbyLimit-200*time.Millisecond && el <= lobbyLimit+time.Second, "expired after %v", el)
			expectClosed(first)
			late := must(dial(url))
			defer late.close()
			late.say(hello(code, "abc", 2))
			expect(late, `{"type":"error","reason":"unknown match"}`)
		}},
		{"start_window_outlasts_silence", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			got, err := cls[1].hear(3 * silence)
			check(err != nil && err != errClosed, "want no frame, got %q err %v", got, err)
			cls[0].say(tick(1, 4, ""))
			expect(cls[1], tick(1, 4, ""))
		}},
		{"over_keeps_silence_until_every_seat", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			cls[0].say(tick(1, 4, ""))
			cls[1].say(tick(2, 4, ""))
			expect(cls[1], tick(1, 4, ""))
			cls[0].say(over)
			got, err := pingUntil(cls[1], silence+wait)
			check(err == nil && got == left(1, 4), "want %q, got %q err %v", left(1, 4), got, err)
		}},
		{"parked_room_expires", func(url string) {
			cls := parkedRoom(url)
			defer closeAll(cls)
			start := time.Now()
			got, err := pingUntil(cls[1], 3*silence)
			check(err != nil && err != errClosed, "want only pongs for %v, got %q err %v", 3*silence, got, err)
			cls[0].say(`{"type":"ping","t":1}`)
			expect(cls[0], `{"type":"pong","t":1}`)
			got, err = pingUntil(cls[1], lobbyLimit+time.Second-time.Since(start))
			check(err == nil && got == roomExpired, "seat 2 want room expired, got %q err %v", got, err)
			expect(cls[0], roomExpired)
			check(time.Since(start) <= lobbyLimit+time.Second, "expired after %v", time.Since(start))
			expectClosed(cls[0])
			for got, err = cls[1].hear(wait); err == nil && strings.HasPrefix(got, `{"type":"pong"`); got, err = cls[1].hear(wait) {
			}
			check(err == errClosed, "seat 2 want close, got %q err %v", got, err)
		}},
		{"rematch_start_window", func(url string) {
			cls := parkedRoom(url)
			defer closeAll(cls)
			rematchStart(cls, "{}")
			quiet(cls[1], 3*silence)
			cls[0].say(tick(1, 4, ""))
			expect(cls[1], tick(1, 4, ""))
		}},
		{"start_window_ends", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			start := time.Now()
			tk := time.NewTicker(100 * time.Millisecond)
			defer tk.Stop()
			end := time.After(lobbyLimit + wait)
			for t := 4; ; {
				select {
				case <-tk.C:
					cls[1].say(tick(2, t, ""))
					t++
				case s, ok := <-cls[1].in:
					el := time.Since(start)
					check(ok && s == left(1, 3), "want %q, got %q (open %v)", left(1, 3), s, ok)
					check(el >= lobbyLimit-200*time.Millisecond, "left after %v", el)
					return
				case <-end:
					check(false, "no left within %v", lobbyLimit+wait)
				}
			}
		}},
	}
}

func delayCases() []tcase {
	return []tcase{{"test_delay_keeps_order_and_holds_left", func(url string) {
		cls, _ := room(url, 2, "abc")
		defer closeAll(cls)
		start := time.Now()
		cls[0].say(tick(1, 4, ""))
		cls[0].say(tick(1, 5, ""))
		expect(cls[1], tick(1, 4, ""))
		check(time.Since(start) >= 240*time.Millisecond, "tick arrived after %v", time.Since(start))
		cls[0].say(tick(1, 6, ""))
		time.Sleep(20 * time.Millisecond)
		cls[0].close()
		expect(cls[1], tick(1, 5, ""))
		expect(cls[1], tick(1, 6, ""))
		expect(cls[1], left(1, 6))
	}}, {"pong_not_delayed", func(url string) {
		cls, _ := room(url, 2, "abc")
		defer closeAll(cls)
		start := time.Now()
		cls[0].say(`{"type":"ping","t":7}`)
		expect(cls[0], `{"type":"pong","t":7}`)
		check(time.Since(start) < 200*time.Millisecond, "pong took %v", time.Since(start))
	}}}
}

func runConform(url, profile string) int {
	cases := map[string][]tcase{"default": defaultCases(), "silence": silenceCases(), "delay": delayCases()}[profile]
	if len(cases) == 0 {
		fmt.Println("unknown profile", profile)
		return 2
	}
	failed := 0
	for _, c := range cases {
		err := func() (err error) {
			defer func() {
				if r := recover(); r != nil {
					if f, ok := r.(failure); ok {
						err = fmt.Errorf("%s", f.msg)
					} else {
						err = fmt.Errorf("panic: %v", r)
					}
				}
			}()
			c.run(url)
			return nil
		}()
		if err != nil {
			failed++
			fmt.Printf("FAIL %s: %v\n", c.name, err)
		} else {
			fmt.Printf("ok   %s\n", c.name)
		}
	}
	fmt.Printf("CONFORM %s: %d cases, %d failed\n", profile, len(cases), failed)
	if failed > 0 {
		return 1
	}
	return 0
}
