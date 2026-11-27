// Command relay forwards lockstep tick frames between the seats of a Wargrid match.
package main

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/lxzan/gws"
)

const (
	closeGrace = 200 * time.Millisecond
	stopGrace  = time.Second // close handshakes after a forced stop
	// Far above legitimate traffic; a peer reading slower than the room sends is cut off before memory runs out.
	maxQueuedBytes = 1 << 20
	jobOverhead    = 256 // charged per job so empty pings count too
)

// deadline is the socket's read deadline, shared by the reader goroutine (touch) and the room goroutine.
type deadline struct {
	mu    sync.Mutex
	set   func(time.Time) // nil for unit-test conns
	renew time.Duration   // 0: fixed, frames do not extend it
}

func (d *deadline) hold(until time.Time) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.renew = 0
	d.apply(until)
}

func (d *deadline) every(window time.Duration) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.renew = window
	d.apply(time.Now().Add(window))
}

func (d *deadline) touch() {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.renew > 0 {
		d.apply(time.Now().Add(d.renew))
	}
}

func (d *deadline) apply(t time.Time) {
	if d.set != nil {
		d.set(t)
	}
}

type conn struct {
	sender
	dl       deadline
	rejected atomic.Bool
	queued   atomic.Int64 // bytes waiting in gws's unbounded write queue
	room     *room        // set by the reader goroutine after a successful hello
	seat     *seat
	ip       string // limiter key, "" for none
	tracked  bool   // OnClose owes the limiter a decrement
}

func (c *conn) reject(reason string) {
	if c.rejected.Swap(true) {
		return
	}
	c.sendLast([]byte(`{"type":"error","reason":"` + reason + `"}`))
	// Godot drops frames still queued when it sees the close, so the error must land first.
	time.AfterFunc(closeGrace, c.close)
}

type relay struct {
	reg      *registry
	lim      *limiter
	ipHeader string
}

func (h *relay) key(r *http.Request) string {
	k := clientKey(r, h.ipHeader)
	if k == "" && h.ipHeader != "" {
		h.lim.unusableHeader()
	}
	return k
}

func envInt(name string, def int) int {
	v, ok := os.LookupEnv(name)
	if !ok {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		slog.Error("invalid config", "var", name, "value", v)
		os.Exit(2)
	}
	return n
}

func getConn(s *gws.Conn) *conn { v, _ := s.Session().Load("c"); return v.(*conn) }

// writeLater runs w in the connection's ordered write queue. The deadline makes a write to a peer that stopped
// reading fail and close the socket; otherwise it holds gws's write lock forever and OnClose (and `left`) never runs.
func (h *relay) writeLater(s *gws.Conn, n int, w func() error) {
	q := &getConn(s).queued
	cost := int64(n + jobOverhead)
	if v := q.Add(cost); v > maxQueuedBytes {
		if v-cost <= maxQueuedBytes {
			slog.Warn("write queue full, closing")
		}
		// Close the socket directly: a queued close would wait behind the backlog.
		_ = s.NetConn().Close()
		return
	}
	s.Async(func() {
		defer q.Add(-cost)
		_ = s.SetWriteDeadline(time.Now().Add(h.reg.cfg.silence))
		_ = w()
	})
}

func (h *relay) OnOpen(s *gws.Conn) {
	v, _ := s.Session().Load("ip")
	ip, _ := v.(string) // no Authorize hook (test servers): "", no per-IP rules
	c := &conn{ip: ip, sender: sender{
		write: func(f []byte) { h.writeLater(s, len(f), func() error { return s.WriteMessage(gws.OpcodeText, f) }) },
		shut:  func() { h.writeLater(s, 0, func() error { return s.WriteClose(1000, nil) }) },
	}, dl: deadline{set: func(t time.Time) { _ = s.SetReadDeadline(t) }}}
	c.dl.hold(time.Now().Add(h.reg.cfg.hello))
	s.Session().Store("c", c)
	slog.Info("connection opened")
	var reason string
	reason, c.tracked = h.lim.open(ip)
	if reason != "" {
		c.reject(reason)
	}
}

func (h *relay) OnClose(s *gws.Conn, err error) {
	slog.Info("connection closed", "err", err)
	c := getConn(s)
	h.lim.close(c.ip, c.tracked)
	if c.seat != nil {
		c.room.post(leaveMsg{c.seat})
	}
}

func (h *relay) OnPing(s *gws.Conn, p []byte) {
	p = bytes.Clone(p)
	h.writeLater(s, len(p), func() error { return s.WritePong(p) })
}
func (h *relay) OnPong(*gws.Conn, []byte) {}

func (h *relay) OnMessage(s *gws.Conn, msg *gws.Message) {
	defer msg.Close()
	c := getConn(s)
	if c.rejected.Load() {
		return
	}
	c.dl.touch()
	if msg.Opcode != gws.OpcodeText {
		c.rejected.Store(true)
		c.close()
		return
	}
	e := parseEnvelope(msg.Bytes())
	if e == nil || (c.seat == nil) != (e.typ == "hello") {
		c.reject("invalid message")
		return
	}
	switch e.typ {
	case "hello":
		if reason := h.lim.join(c.ip); reason != "" {
			slog.Info("join rejected", "reason", reason)
			c.reject(reason)
			return
		}
		res := h.reg.join(e, c)
		if res.seat == nil && res.reason == "unknown match" && !h.lim.unknown() {
			c.rejected.Store(true) // no reply (ioq3 sv_main.c:727-733)
			c.close()
			return
		}
		if res.seat == nil {
			slog.Info("join rejected", "reason", res.reason)
			c.reject(res.reason)
			return
		}
		c.seat = res.seat
		c.room = res.seat.r
	case "tick":
		c.room.post(tickMsg{s: c.seat, seat: e.seat, tick: e.tick, data: bytes.Clone(msg.Bytes()), hash: e.hash})
	case "over":
		c.room.post(overMsg{c.seat})
	case "again":
		c.room.post(againMsg{c.seat})
	case "settings":
		c.room.post(settingsMsg{c.seat, e.raw})
	case "pick":
		c.room.post(pickMsg{c.seat, e.raw})
	case "start_request":
		c.room.post(startRequestMsg{c.seat})
	case "ping":
		c.send([]byte(`{"type":"pong","t":`+e.t+`}`), 0)
	}
}

func main() {
	cfg := config{
		seats:     max(1, envInt("WARGRID_SEATS", 2)),
		testDelay: time.Duration(envInt("WARGRID_TEST_DELAY_MS", 0)) * time.Millisecond,
		batch:     time.Duration(envInt("WARGRID_BATCH_MS", 0)) * time.Millisecond,
		hello:     time.Duration(envInt("WARGRID_HELLO_MS", 5000)) * time.Millisecond,
		silence:   time.Duration(envInt("WARGRID_SILENCE_MS", 10000)) * time.Millisecond,
		lobby:     time.Duration(envInt("WARGRID_LOBBY_MS", 900000)) * time.Millisecond,
		lobbyCap:  time.Duration(envInt("WARGRID_LOBBY_CAP_MS", 3600000)) * time.Millisecond,
	}
	drain := time.Duration(envInt("WARGRID_DRAIN_MS", 3500)) * time.Millisecond
	ipHeader := os.Getenv("WARGRID_CLIENT_IP_HEADER")
	addr := ":" + os.Getenv("PORT")
	if addr == ":" {
		addr = ":8080"
	}
	reg := newRegistry(cfg)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		slog.Error("listen failed", "err", err)
		os.Exit(1)
	}
	slog.Info("relay started", "addr", addr, "seats", cfg.seats, "hello", cfg.hello, "silence", cfg.silence, "lobby", cfg.lobby, "batch", cfg.batch, "drain", drain, "per_ip", ipHeader != "")
	lim := newLimiter(tableSize, globalBurst, globalPeriod, time.Now)
	if err := serve(ln, newServer(&relay{reg: reg, lim: lim, ipHeader: ipHeader}), reg, drain); err != nil {
		slog.Error("serve failed", "err", err)
		os.Exit(1)
	}
}

func serve(ln net.Listener, srv *http.Server, reg *registry, drain time.Duration) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	errc := make(chan error, 1)
	go func() { errc <- srv.Serve(ln) }()
	select {
	case err := <-errc:
		return err
	case <-ctx.Done():
	}
	stop() // a second signal exits immediately
	shutdown(srv, reg, drain)
	return nil
}

func newServer(h *relay) *http.Server {
	up := gws.NewUpgrader(h, &gws.ServerOption{
		ReadMaxPayloadSize: 1 << 20, CheckUtf8Enabled: true, Recovery: gws.Recovery,
		Authorize: func(r *http.Request, s gws.SessionStorage) bool { s.Store("ip", h.key(r)); return true },
	})
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok")) })
	mux.HandleFunc("GET /ws", func(w http.ResponseWriter, r *http.Request) {
		if s, err := up.Upgrade(w, r); err == nil {
			go s.ReadLoop()
		}
	})
	return &http.Server{Handler: mux, ReadHeaderTimeout: 10 * time.Second, IdleTimeout: 60 * time.Second}
}

// shutdown stops accepting connections, lets started matches run until drain passes, then closes the rest.
// http.Server.Shutdown does not wait for WebSockets (hijacked), so rooms are tracked by the registry.
func shutdown(srv *http.Server, reg *registry, drain time.Duration) {
	slog.Info("draining", "rooms", reg.count(), "timeout", drain)
	ctx, cancel := context.WithTimeout(context.Background(), drain)
	defer cancel()
	reg.startDrain()
	if err := srv.Shutdown(ctx); err != nil && !errors.Is(err, context.DeadlineExceeded) {
		slog.Warn("http shutdown", "err", err)
	}
	_ = srv.Close() // HTTP requests still open at the deadline
	forced := 0
	if !reg.waitEmpty(ctx) {
		forced = reg.count()
		reg.stop()
		grace, cancelGrace := context.WithTimeout(context.Background(), stopGrace)
		defer cancelGrace()
		reg.waitEmpty(grace)
	}
	slog.Info("stopped", "forced", forced, "remaining", reg.count())
}
