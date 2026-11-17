package main

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type fault struct {
	kind    string // slice, hold, reset or blackhole
	at, dur time.Duration
	n       int
}

func parseFaults(spec string) ([]fault, error) {
	var out []fault
	for _, s := range strings.Split(spec, ",") {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		f, err := parseFault(s)
		if err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, nil
}

func parseFault(s string) (fault, error) {
	bad := fmt.Errorf("bad fault %q", s)
	if v, ok := strings.CutPrefix(s, "slice:"); ok {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 {
			return fault{}, bad
		}
		return fault{kind: "slice", n: n}, nil
	}
	kind, args, ok := strings.Cut(s, "@")
	if !ok {
		return fault{}, bad
	}
	atText, durText, hasDur := strings.Cut(args, ":")
	if hasDur != (kind == "hold" || kind == "blackhole") || (!hasDur && kind != "reset") {
		return fault{}, bad
	}
	f := fault{kind: kind}
	var err error
	if f.at, err = parseMillis(atText); err != nil {
		return fault{}, bad
	}
	if hasDur {
		if f.dur, err = parseMillis(durText); err != nil {
			return fault{}, bad
		}
	}
	return f, nil
}

func parseMillis(s string) (time.Duration, error) {
	v, err := strconv.Atoi(s)
	if err != nil || v < 0 {
		return 0, fmt.Errorf("bad milliseconds %q", s)
	}
	return time.Duration(v) * time.Millisecond, nil
}

func writeSliced(w io.Writer, data []byte, n int) error {
	if n <= 0 {
		n = len(data)
	}
	for len(data) > 0 {
		k := min(n, len(data))
		if _, err := w.Write(data[:k]); err != nil {
			return err
		}
		data = data[k:]
	}
	return nil
}

// lane is one direction. Its mutex orders every write to dst, so a flush after a hold never overtakes later bytes.
type lane struct {
	side      string // who src is: client or target
	src, dst  net.Conn
	mu        sync.Mutex
	released  *sync.Cond
	held      bytes.Buffer
	holding   bool
	hole      bool
	discarded int
	slice     int
}

func newLane(side string, src, dst net.Conn, slice int) *lane {
	l := &lane{side: side, src: src, dst: dst, slice: slice}
	l.released = sync.NewCond(&l.mu)
	return l
}

func (l *lane) forward(data []byte) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	switch {
	case l.hole:
		l.discarded += len(data)
	case l.holding:
		l.held.Write(data)
	default:
		return writeSliced(l.dst, data, l.slice)
	}
	return nil
}

// release writes out what a hold kept and returns how many bytes that was.
func (l *lane) release() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	n := l.held.Len()
	if l.hole {
		l.discarded += n
	} else {
		if err := writeSliced(l.dst, l.held.Bytes(), l.slice); err != nil {
			warn("release-error", err)
		}
	}
	l.held.Reset()
	l.holding = false
	l.released.Broadcast()
	return n
}

// waitHeld blocks while a hold is active and reports whether the lane is in the blackhole.
func (l *lane) waitHeld() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	for l.holding {
		l.released.Wait()
	}
	return l.hole
}

type proxy struct {
	start    time.Time
	logMu    sync.Mutex
	log      io.Writer
	up, down *lane
	reset    atomic.Bool
	capped   atomic.Bool
}

func (p *proxy) logf(event, detail string) {
	now := time.Now()
	line := fmt.Sprintf("NETFAULT %d %d %s", now.UnixMilli(), now.Sub(p.start).Milliseconds(), event)
	if detail != "" {
		line += " " + detail
	}
	p.logMu.Lock()
	defer p.logMu.Unlock()
	if _, err := io.WriteString(p.log, line+"\n"); err != nil {
		warn("log-error", err)
	}
}

// warn goes to stderr, which the netplay script keeps in proxy-seatN.out.
func warn(kind string, err error) {
	fmt.Fprintf(os.Stderr, "netfault: %s: %v\n", kind, err)
}

func (p *proxy) lanes() []*lane { return []*lane{p.up, p.down} }

func (p *proxy) closeBoth() {
	_ = p.up.src.Close()
	_ = p.up.dst.Close()
}

func (p *proxy) pipe(l *lane) {
	buf := make([]byte, 32<<10)
	for {
		n, err := l.src.Read(buf)
		wrote := true
		if n > 0 {
			if werr := l.forward(buf[:n]); werr != nil {
				err, wrote = werr, false
			}
		}
		if err != nil {
			p.sideClosed(l, wrote)
			return
		}
	}
}

// sideClosed passes a close on as a half-close once everything before it is written; it never does so around a
// blackhole, where the other side must stay open and silent.
func (p *proxy) sideClosed(l *lane, wrote bool) {
	if l.waitHeld() || p.reset.Load() || p.capped.Load() {
		return
	}
	if wrote {
		p.logf("close", l.side)
	} else {
		p.logf("close", l.side+" write-error")
	}
	if tc, ok := l.dst.(*net.TCPConn); ok {
		_ = tc.CloseWrite()
	} else {
		_ = l.dst.Close()
	}
}

func (p *proxy) startHold(d time.Duration) {
	for _, l := range p.lanes() {
		l.mu.Lock()
		l.holding = true
		l.mu.Unlock()
	}
	p.logf("hold-start", "")
	time.AfterFunc(d, p.endHold)
}

func (p *proxy) endHold() {
	up, down := p.up.release(), p.down.release()
	p.logf("hold-end", fmt.Sprintf("%d %d", up, down))
}

func (p *proxy) startBlackhole(d time.Duration) {
	for _, l := range p.lanes() {
		l.mu.Lock()
		l.hole = true
		l.discarded = 0
		l.mu.Unlock()
	}
	p.logf("blackhole-start", "")
	time.AfterFunc(d, func() {
		var n [2]int
		for i, l := range p.lanes() {
			l.mu.Lock()
			n[i] = l.discarded
			l.mu.Unlock()
		}
		p.logf("blackhole-end", fmt.Sprintf("%d %d", n[0], n[1]))
	})
}

func (p *proxy) doReset() {
	p.reset.Store(true)
	p.logf("reset", "")
	for _, c := range []net.Conn{p.up.src, p.up.dst} {
		if tc, ok := c.(*net.TCPConn); ok {
			if err := tc.SetLinger(0); err != nil {
				warn("linger-error", err)
			}
		}
	}
	p.closeBoth()
}

func (p *proxy) schedule(faults []fault) []*time.Timer {
	var timers []*time.Timer
	for _, f := range faults {
		switch f.kind {
		case "hold":
			timers = append(timers, time.AfterFunc(f.at, func() { p.startHold(f.dur) }))
		case "blackhole":
			timers = append(timers, time.AfterFunc(f.at, func() { p.startBlackhole(f.dur) }))
		case "reset":
			timers = append(timers, time.AfterFunc(f.at, p.doReset))
		}
	}
	return timers
}

// run accepts one connection on ln, pipes it to target and applies faults until both sides are closed or life
// has passed since the accept.
func run(ln net.Listener, target string, faults []fault, log io.Writer, life time.Duration) error {
	p := &proxy{start: time.Now(), log: log}
	p.logf("listen", ln.Addr().String()) // the one connection is the client's, so scripts wait for this line instead of probing
	client, err := ln.Accept()
	_ = ln.Close()
	if err != nil {
		return err
	}
	p.start = time.Now()
	p.logf("accept", target)
	upstream, err := net.DialTimeout("tcp", target, 5*time.Second)
	if err != nil {
		_ = client.Close()
		p.logf("exit", "dial failed")
		return err
	}
	slice := 0
	for _, f := range faults {
		if f.kind == "slice" {
			slice = f.n
			p.logf("slice", strconv.Itoa(f.n))
		}
	}
	p.up = newLane("client", client, upstream, slice)
	p.down = newLane("target", upstream, client, slice)
	timers := p.schedule(faults)
	timers = append(timers, time.AfterFunc(life, func() {
		p.capped.Store(true)
		p.closeBoth()
	}))

	var wg sync.WaitGroup
	for _, l := range p.lanes() {
		wg.Add(1)
		go func() {
			defer wg.Done()
			p.pipe(l)
		}()
	}
	wg.Wait()
	for _, t := range timers {
		t.Stop()
	}
	p.closeBoth()
	if p.capped.Load() {
		p.logf("exit", "cap")
	} else {
		p.logf("exit", "")
	}
	return nil
}
