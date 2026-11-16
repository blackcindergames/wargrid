package main

import (
	"net"
	"net/http/httptest"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/lxzan/gws"
)

// slowReader keeps reading, but slower than its peer sends, so no single write ever hits the deadline.
// At ~120 KB/s a close queued behind a 1 MiB backlog would land after the 3 s wait, so only a direct close passes.
type slowReader struct{ welcome chan string }

func (c *slowReader) OnOpen(*gws.Conn)         {}
func (c *slowReader) OnClose(*gws.Conn, error) {}
func (c *slowReader) OnPing(*gws.Conn, []byte) {}
func (c *slowReader) OnPong(*gws.Conn, []byte) {}
func (c *slowReader) OnMessage(_ *gws.Conn, m *gws.Message) {
	select {
	case c.welcome <- m.Data.String():
	default:
	}
	_ = m.Close()
	time.Sleep(500 * time.Millisecond)
}

func TestSlowReaderBacklogIsCapped(t *testing.T) {
	h := &relay{reg: &registry{rooms: map[string]*room{}, cfg: testConfig()}}
	srv := httptest.NewServer(newServer(h).Handler)
	defer srv.Close()
	sr := &slowReader{welcome: make(chan string, 1)}
	a, _, err := gws.NewClient(sr, &gws.ClientOption{Addr: "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws", NewDialer: smallWindow})
	if err != nil {
		t.Fatal(err)
	}
	go a.ReadLoop()
	say(t, a, `{"type":"hello","protocol":2,"build":"x","match":"","settings":{}}`)
	w := <-sr.welcome
	b, bc := dial(t, srv.URL)
	say(t, b, `{"type":"hello","protocol":2,"build":"x","match":"`+w[strings.Index(w, `"match":"`)+9:len(w)-2]+`"}`)
	hear(t, bc)
	hear(t, bc)
	logs := captureLogs(t)
	pad := strings.Repeat("x", 60000)
	seen := map[string]bool{}
	sent := 0
	for i := 4; i < 2004 && !seen["left"]; i++ {
		say(t, b, `{"type":"tick","seat":2,"tick":`+strconv.Itoa(i)+`,"commands":["`+pad+`"]}`)
		sent++
		untilPong(t, b, bc, seen)
		if a.WriteString(`{"type":"tick","seat":1,"tick":`+strconv.Itoa(i)+`,"commands":[]}`) != nil {
			break
		}
	}
	runtime.GC()
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	if m.HeapAlloc > 32<<20 {
		t.Fatalf("heap %d MB after %d frames of 60 KB to a slow reader; the write queue is not capped", m.HeapAlloc>>20, sent)
	}
	deadline := time.After(3 * time.Second)
	for !seen["left"] {
		select {
		case <-deadline:
			t.Fatal("no left within 3 s; the slow reader was not cut off")
		case <-time.After(50 * time.Millisecond):
			drain(bc, seen)
		}
	}
	if seen["error"] {
		t.Fatal("seat 2 got an error frame; the lead bound fired")
	}
	if !strings.Contains(logs.String(), "write queue full") {
		t.Fatal("seat 1 was not closed by the write-queue cap")
	}
}

// smallWindow pins the receive buffer so kernel autotuning cannot absorb the relay's backlog.
func smallWindow() (gws.Dialer, error) {
	return &net.Dialer{Control: func(_, _ string, c syscall.RawConn) error {
		return c.Control(func(fd uintptr) { _ = syscall.SetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_RCVBUF, 32<<10) })
	}}, nil
}
