package main

import (
	"bytes"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/lxzan/gws"
)

// stalled reads its first frame (the welcome) and then stops reading, so its TCP receive window fills up.
type stalled struct {
	welcome chan string
	block   chan struct{}
}

func (c *stalled) OnOpen(*gws.Conn)         {}
func (c *stalled) OnClose(*gws.Conn, error) {}
func (c *stalled) OnPing(*gws.Conn, []byte) {}
func (c *stalled) OnPong(*gws.Conn, []byte) {}
func (c *stalled) OnMessage(_ *gws.Conn, m *gws.Message) {
	select {
	case c.welcome <- m.Data.String():
	default:
	}
	<-c.block
}

// drain reads c without blocking and notes which frame types arrived.
func drain(c *cl, seen map[string]bool) {
	for {
		select {
		case s := <-c.ch:
			for _, k := range []string{"left", "error"} {
				if strings.Contains(s, `"type":"`+k+`"`) {
					seen[k] = true
				}
			}
		default:
			return
		}
	}
}

// untilPong pings over s and reads c until the pong, noting left and error frames on the way. The relay's reader
// posts a tick to the room before it answers the next ping, so a tick sent after the pong is behind it in room order.
func untilPong(t *testing.T, s *gws.Conn, c *cl, seen map[string]bool) {
	say(t, s, `{"type":"ping","t":1}`)
	deadline := time.After(2 * time.Second)
	for {
		select {
		case m := <-c.ch:
			if strings.Contains(m, `"type":"pong"`) {
				return
			}
			for _, k := range []string{"left", "error"} {
				if strings.Contains(m, `"type":"`+k+`"`) {
					seen[k] = true
				}
			}
		case <-deadline:
			t.Fatal("no pong within 2 s")
		}
	}
}

type syncBuf struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuf) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.Write(p)
}

func (s *syncBuf) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.String()
}

// captureLogs routes slog to a buffer for one test; relay goroutines log concurrently, hence the lock.
func captureLogs(t *testing.T) *syncBuf {
	buf := &syncBuf{}
	prev := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(buf, nil)))
	t.Cleanup(func() { slog.SetDefault(prev) })
	return buf
}

func TestStalledPeerStillProducesLeft(t *testing.T) {
	cfg := testConfig()
	cfg.silence = 500 * time.Millisecond
	h := &relay{reg: &registry{rooms: map[string]*room{}, cfg: cfg}}
	up := gws.NewUpgrader(h, &gws.ServerOption{ReadMaxPayloadSize: 1 << 20, CheckUtf8Enabled: true})
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s, err := up.Upgrade(w, r); err == nil {
			go s.ReadLoop()
		}
	}))
	defer srv.Close()
	st := &stalled{welcome: make(chan string, 1), block: make(chan struct{})}
	defer close(st.block)
	a, _, err := gws.NewClient(st, &gws.ClientOption{Addr: "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws"})
	if err != nil {
		t.Fatal(err)
	}
	go a.ReadLoop()
	say(t, a, `{"type":"hello","protocol":2,"build":"x","match":"","settings":{}}`)
	w := <-st.welcome
	b, bc := dial(t, srv.URL)
	say(t, b, `{"type":"hello","protocol":2,"build":"x","match":"`+w[strings.Index(w, `"match":"`)+9:len(w)-2]+`"}`)
	hear(t, bc)
	hear(t, bc)
	// Puts seat 1 on the silence rule; otherwise it sits in the start window.
	say(t, a, `{"type":"tick","seat":1,"tick":4,"commands":[]}`)
	logs := captureLogs(t)
	pad := strings.Repeat("x", 60000)
	seen := map[string]bool{}
	for i := 4; i < 400 && !seen["left"]; i++ {
		say(t, b, `{"type":"tick","seat":2,"tick":`+strconv.Itoa(i)+`,"commands":["`+pad+`"]}`)
		untilPong(t, b, bc, seen)
		// Seat 1 keeps sending so the lead bound never fires; only its reads are stalled.
		if a.WriteString(`{"type":"tick","seat":1,"tick":`+strconv.Itoa(i+1)+`,"commands":[]}`) != nil {
			break
		}
	}
	deadline := time.After(4 * time.Second)
	for !seen["left"] {
		select {
		case <-deadline:
			t.Fatal("no left within 4 s although seat 1 stopped reading")
		case <-time.After(200 * time.Millisecond):
			say(t, b, `{"type":"ping","t":1}`)
			drain(bc, seen)
		}
	}
	if seen["error"] || strings.Contains(logs.String(), "lead bound") {
		t.Fatal("the lead bound fired, so the stall is not what produced left")
	}
}
