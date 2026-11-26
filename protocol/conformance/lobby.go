package main

import (
	"fmt"
	"strings"
	"time"
)

const (
	lobbySettings = `{"map":"a"}`
	startRequest  = `{"type":"start_request"}`
)

func settingsMsg(raw string) string { return `{"type":"settings","settings":` + raw + `}` }

func pickMsg(raw string) string { return `{"type":"pick","pick":` + raw + `}` }

func pickFrom(seat int, raw string) string {
	return fmt.Sprintf(`{"type":"pick","seat":%d,"pick":%s}`, seat, raw)
}

func joined(seat int) string { return fmt.Sprintf(`{"type":"joined","seat":%d}`, seat) }

func welcome3(seat int, code, settings string) string {
	return fmt.Sprintf(`{"type":"welcome","seat":%d,"match":"%s","settings":%s}`, seat, code, settings)
}

func lobbyHost(url, settings string) (*client, string) {
	cl := must(dial(url))
	check(cl.say(helloSettings("", "abc", 3, settings)) == nil, "send")
	w := must(cl.hear(wait))
	code := codeOf(w)
	check(code != "" && w == welcome3(1, code, settings), "bad welcome %q", w)
	return cl, code
}

func lobbyGuest(url, code string, seat int, settings string, host *client) *client {
	cl := must(dial(url))
	check(cl.say(hello(code, "abc", 3)) == nil, "send")
	expect(cl, welcome3(seat, code, settings))
	expect(host, joined(seat))
	return cl
}

func lobbyRoom(url string) (host, guest *client, code string) {
	host, code = lobbyHost(url, lobbySettings)
	return host, lobbyGuest(url, code, 2, lobbySettings, host), code
}

func lobbyStart(host, guest *client, settings string) {
	check(host.say(startRequest) == nil, "send")
	seed := expectStart(host, 2, settings)
	check(expectStart(guest, 2, settings) == seed, "seats got different seeds")
}

func expectErrorClosed(cl *client, reason string) {
	expect(cl, fmt.Sprintf(`{"type":"error","reason":"%s"}`, reason))
	expectClosed(cl)
}

func lobbyCases() []tcase {
	return []tcase{
		{"lobby_no_start_on_fill", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			quiet(host, 500*time.Millisecond)
			quiet(guest, 100*time.Millisecond)
		}},
		{"lobby_settings_reach_joined_seat_byte_exact", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			raw := `{ "map" : "ashfall", "n":1.50, "u":"ü€", "nested":{"a":[1, 2]} }`
			host.say(settingsMsg(raw))
			expect(guest, settingsMsg(raw))
			quiet(host, 200*time.Millisecond)
		}},
		{"lobby_welcome_carries_latest_settings", func(url string) {
			host, code := lobbyHost(url, lobbySettings)
			defer host.close()
			host.say(settingsMsg(`{"map":"b"}`))
			host.say(settingsMsg(`{ "map":"c" }`))
			host.say(`{"type":"ping","t":1}`)
			expect(host, `{"type":"pong","t":1}`)
			lobbyGuest(url, code, 2, `{ "map":"c" }`, host).close()
		}},
		{"lobby_settings_from_guest_refused", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			guest.say(settingsMsg(`{"map":"x"}`))
			expectErrorClosed(guest, "invalid message")
			expect(host, left(2, 3))
		}},
		{"lobby_settings_after_start_refused", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			lobbyStart(host, guest, lobbySettings)
			host.say(settingsMsg(`{"map":"x"}`))
			expectErrorClosed(host, "invalid message")
			expect(guest, left(1, 3))
		}},
		{"lobby_settings_not_object_refused", func(url string) {
			for _, bad := range []string{`"x"`, `[1]`, `null`} {
				host, guest, _ := lobbyRoom(url)
				host.say(settingsMsg(bad))
				expectErrorClosed(host, "invalid message")
				expect(guest, `{"type":"error","reason":"host left"}`)
				host.close()
				guest.close()
			}
		}},
		{"lobby_settings_over_cap_refused", func(url string) {
			pad := func(n int) string { return `{"k":"` + strings.Repeat("x", n-8) + `"}` }
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			host.say(settingsMsg(pad(4096)))
			expect(guest, settingsMsg(pad(4096)))
			host.say(settingsMsg(pad(4097)))
			expectErrorClosed(host, "invalid message")
		}},
		{"lobby_start_request_from_guest_refused", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			guest.say(startRequest)
			expectErrorClosed(guest, "invalid message")
			expect(host, left(2, 3))
		}},
		{"lobby_start_request_before_full_ignored", func(url string) {
			host, code := lobbyHost(url, lobbySettings)
			defer host.close()
			host.say(startRequest)
			quiet(host, 200*time.Millisecond)
			guest := lobbyGuest(url, code, 2, lobbySettings, host)
			defer guest.close()
			lobbyStart(host, guest, lobbySettings)
		}},
		{"lobby_start_request_twice_refused", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			lobbyStart(host, guest, lobbySettings)
			host.say(startRequest)
			expectErrorClosed(host, "invalid message")
			expect(guest, left(1, 3))
		}},
		{"lobby_start_carries_latest_settings", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			host.say(settingsMsg(`{"map":"b"}`))
			host.say(settingsMsg(`{ "map":"c" }`))
			expect(guest, settingsMsg(`{"map":"b"}`))
			expect(guest, settingsMsg(`{ "map":"c" }`))
			lobbyStart(host, guest, `{ "map":"c" }`)
		}},
		{"lobby_guest_leaves_and_seat_is_reused", func(url string) {
			host, guest, code := lobbyRoom(url)
			defer host.close()
			guest.close()
			expect(host, left(2, 3))
			lobbyGuest(url, code, 2, lobbySettings, host).close()
		}},
		{"lobby_host_leaves_closes_room", func(url string) {
			host, guest, code := lobbyRoom(url)
			defer guest.close()
			host.close()
			expectErrorClosed(guest, "host left")
			late := must(dial(url))
			defer late.close()
			late.say(hello(code, "abc", 3))
			expect(late, unknownMatch)
		}},
		{"lobby_settings_rate_limit", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			for range 10 {
				host.say(settingsMsg(`{"map":"x"}`))
			}
			host.say(settingsMsg(`{"map":"over"}`))
			expectErrorClosed(host, "too many settings")
			for range 10 {
				expect(guest, settingsMsg(`{"map":"x"}`))
			}
			expect(guest, `{"type":"error","reason":"host left"}`)
		}},
		{"lobby_pick_reaches_host_byte_exact_with_seat", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			raw := `{ "faction" : "usa", "u":"ü€" }`
			guest.say(pickMsg(raw))
			expect(host, pickFrom(2, raw))
			quiet(guest, 200*time.Millisecond)
			lobbyStart(host, guest, lobbySettings)
		}},
		{"lobby_pick_from_host_refused", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			host.say(pickMsg(`{"faction":"usa"}`))
			expectErrorClosed(host, "invalid message")
			expect(guest, `{"type":"error","reason":"host left"}`)
		}},
		{"lobby_pick_after_start_dropped", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			lobbyStart(host, guest, lobbySettings)
			guest.say(pickMsg(`{"faction":"usa"}`))
			guest.say(`{"type":"ping","t":1}`)
			expect(guest, `{"type":"pong","t":1}`)
			quiet(guest, 200*time.Millisecond) // the pong can overtake the pick; an error would follow it
			guest.say(`{"type":"ping","t":2}`)
			expect(guest, `{"type":"pong","t":2}`)
			quiet(host, 200*time.Millisecond)
		}},
		{"lobby_pick_not_object_refused", func(url string) {
			for _, bad := range []string{`"x"`, `[1]`, `null`} {
				host, guest, _ := lobbyRoom(url)
				guest.say(pickMsg(bad))
				expectErrorClosed(guest, "invalid message")
				expect(host, left(2, 3))
				host.close()
				guest.close()
			}
		}},
		{"lobby_pick_missing_refused", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			guest.say(`{"type":"pick"}`)
			expectErrorClosed(guest, "invalid message")
		}},
		{"lobby_pick_over_cap_refused", func(url string) {
			pad := func(n int) string { return `{"k":"` + strings.Repeat("x", n-8) + `"}` }
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			guest.say(pickMsg(pad(512)))
			expect(host, pickFrom(2, pad(512)))
			guest.say(pickMsg(pad(513)))
			expectErrorClosed(guest, "invalid message")
			expect(host, left(2, 3))
		}},
		{"lobby_pick_rate_limit", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			for range 11 {
				guest.say(pickMsg(`{"faction":"usa"}`))
			}
			for range 10 {
				expect(host, pickFrom(2, `{"faction":"usa"}`))
			}
			expectErrorClosed(guest, "too many settings")
			expect(host, left(2, 3))
		}},
		{"protocol2_room_rejects_pick", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			cls[1].say(pickMsg(`{"faction":"usa"}`))
			expectErrorClosed(cls[1], "invalid message")
			expect(cls[0], left(2, 3))
		}},
		{"lobby_protocol_must_match_room", func(url string) {
			host, guest, code := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			p2 := must(dial(url))
			defer p2.close()
			p2.say(hello(code, "abc", 2))
			expect(p2, `{"type":"error","reason":"protocol mismatch"}`)
			a := must(dial(url))
			defer a.close()
			a.say(hello("", "abc", 2))
			code2 := codeOf(must(a.hear(wait)))
			p3 := must(dial(url))
			defer p3.close()
			p3.say(hello(code2, "abc", 3))
			expect(p3, `{"type":"error","reason":"protocol mismatch"}`)
			other := must(dial(url))
			defer other.close()
			other.say(hello(code2, "newer", 3))
			expect(other, `{"type":"error","reason":"build mismatch"}`)
		}},
		{"protocol2_room_rejects_lobby_messages", func(url string) {
			for _, msg := range []string{startRequest, settingsMsg(`{"map":"x"}`)} {
				cl := must(dial(url))
				cl.say(hello("", "abc", 2))
				must(cl.hear(wait))
				cl.say(msg)
				expectErrorClosed(cl, "invalid message")
				cl.close()
			}
		}},
		{"protocol2_room_still_starts_on_fill", func(url string) {
			first := must(dial(url))
			defer first.close()
			first.say(hello("", "abc", 2))
			code := codeOf(must(first.hear(wait)))
			second := must(dial(url))
			defer second.close()
			second.say(hello(code, "abc", 2))
			expect(second, fmt.Sprintf(`{"type":"welcome","seat":2,"match":"%s"}`, code))
			expectStart(first, 2, "{}")
			expectStart(second, 2, "{}")
		}},
		{"lobby_rematch_after_start", func(url string) {
			host, guest, _ := lobbyRoom(url)
			defer host.close()
			defer guest.close()
			host.say(settingsMsg(`{"map":"z"}`))
			expect(guest, settingsMsg(`{"map":"z"}`))
			lobbyStart(host, guest, `{"map":"z"}`)
			cls := []*client{host, guest}
			cls[0].say(tick(1, 4, ""))
			cls[1].say(tick(2, 4, ""))
			expect(cls[1], tick(1, 4, ""))
			expect(cls[0], tick(2, 4, ""))
			cls[0].say(over)
			cls[1].say(over)
			rematchStart(cls, `{"map":"z"}`)
		}},
	}
}

// settingsUntilError sends settings every `every` and returns the first frame the relay sends and when.
func settingsUntilError(cl *client, every, limit time.Duration) (string, time.Duration) {
	start := time.Now()
	tk := time.NewTicker(every)
	defer tk.Stop()
	for {
		select {
		case <-tk.C:
			_ = cl.say(settingsMsg(`{"map":"x"}`))
		case s, ok := <-cl.in:
			check(ok, "closed without an error frame")
			return s, time.Since(start)
		case <-time.After(limit):
			check(false, "nothing within %v", limit)
		}
	}
}

func lobbySilenceCases() []tcase {
	return []tcase{
		{"lobby_settings_extend_idle_expiry", func(url string) {
			host, _ := lobbyHost(url, lobbySettings)
			defer host.close()
			time.Sleep(lobbyLimit * 2 / 3)
			host.say(settingsMsg(`{"map":"x"}`))
			start := time.Now()
			got, err := pingUntil(host, lobbyLimit+time.Second)
			el := time.Since(start)
			check(err == nil && got == `{"type":"error","reason":"lobby expired"}`, "want lobby expired, got %q err %v", got, err)
			check(el >= lobbyLimit-300*time.Millisecond, "expired %v after the last settings, want about %v", el, lobbyLimit)
		}},
		{"lobby_settings_stop_at_hard_cap", func(url string) {
			host, _ := lobbyHost(url, lobbySettings)
			defer host.close()
			got, el := settingsUntilError(host, 500*time.Millisecond, lobbyCap+wait)
			check(got == `{"type":"error","reason":"lobby expired"}`, "want lobby expired, got %q", got)
			check(el >= lobbyCap-300*time.Millisecond && el <= lobbyCap+time.Second, "expired after %v, want about %v", el, lobbyCap)
		}},
	}
}
