package main

import (
	"bytes"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"
)

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

// pattern is a run of big-endian counters, so a reordered, repeated or lost byte shows up in a compare.
func pattern(n int, seed uint32) []byte {
	b := make([]byte, n)
	for c, i := seed, 0; i < n; c, i = c+1, i+4 {
		var w [4]byte
		binary.BigEndian.PutUint32(w[:], c)
		copy(b[i:], w[:])
	}
	return b
}

// sink collects everything one connection receives, with the arrival time of the first byte and the read error.
type sink struct {
	mu    sync.Mutex
	buf   []byte
	first time.Time
	err   error
}

func (s *sink) drain(c net.Conn) {
	go func() {
		chunk := make([]byte, 64<<10)
		for {
			n, err := c.Read(chunk)
			s.mu.Lock()
			if n > 0 {
				if s.first.IsZero() {
					s.first = time.Now()
				}
				s.buf = append(s.buf, chunk[:n]...)
			}
			s.err = err
			s.mu.Unlock()
			if err != nil {
				return
			}
		}
	}()
}

func (s *sink) state() ([]byte, time.Time, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return bytes.Clone(s.buf), s.first, s.err
}

func (s *sink) waitLen(t *testing.T, n int, limit time.Duration) []byte {
	t.Helper()
	end := time.Now().Add(limit)
	for {
		data, _, err := s.state()
		if len(data) >= n {
			return data
		}
		if err != nil || time.Now().After(end) {
			t.Fatalf("received %d of %d bytes (read error %v)", len(data), n, err)
		}
		time.Sleep(2 * time.Millisecond)
	}
}

func (s *sink) waitErr(t *testing.T, limit time.Duration) error {
	t.Helper()
	end := time.Now().Add(limit)
	for {
		if _, _, err := s.state(); err != nil {
			return err
		}
		if time.Now().After(end) {
			t.Fatal("connection still open")
		}
		time.Sleep(2 * time.Millisecond)
	}
}

type rig struct {
	t    *testing.T
	addr string
	srv  *net.TCPListener
	log  *syncBuf
	done chan error
}

// startRig runs the proxy in front of an in-test target server on loopback.
func startRig(t *testing.T, spec string, life time.Duration) *rig {
	t.Helper()
	faults, err := parseFaults(spec)
	if err != nil {
		t.Fatal(err)
	}
	srv, err := net.ListenTCP("tcp", &net.TCPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	pl, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	r := &rig{t: t, addr: pl.Addr().String(), srv: srv, log: &syncBuf{}, done: make(chan error, 1)}
	go func() { r.done <- run(pl, srv.Addr().String(), faults, r.log, life) }()
	t.Cleanup(func() { _ = srv.Close(); _ = pl.Close() })
	return r
}

// connect dials the proxy and returns the client end and the target end of the pipe.
func (r *rig) connect() (net.Conn, net.Conn) {
	r.t.Helper()
	c, err := net.Dial("tcp", r.addr)
	if err != nil {
		r.t.Fatal(err)
	}
	_ = r.srv.SetDeadline(time.Now().Add(3 * time.Second))
	s, err := r.srv.Accept()
	if err != nil {
		r.t.Fatal(err)
	}
	r.t.Cleanup(func() { _ = c.Close(); _ = s.Close() })
	return c, s
}

func (r *rig) waitLog(want string, limit time.Duration) {
	r.t.Helper()
	end := time.Now().Add(limit)
	for !strings.Contains(r.log.String(), want) {
		if time.Now().After(end) {
			r.t.Fatalf("log has no %q:\n%s", want, r.log.String())
		}
		time.Sleep(2 * time.Millisecond)
	}
}

func (r *rig) waitExit() {
	r.t.Helper()
	select {
	case err := <-r.done:
		if err != nil {
			r.t.Fatalf("run: %v", err)
		}
	case <-time.After(2 * time.Second):
		r.t.Fatalf("proxy still running:\n%s", r.log.String())
	}
	if !strings.Contains(r.log.String(), " exit") {
		r.t.Fatalf("no exit line:\n%s", r.log.String())
	}
}

func send(t *testing.T, c net.Conn, b []byte) {
	t.Helper()
	if _, err := c.Write(b); err != nil {
		t.Fatal(err)
	}
}

func TestListenLinePrecedesAccept(t *testing.T) {
	r := startRig(t, "", 5*time.Second)
	r.waitLog("listen "+r.addr, time.Second)
	if strings.Contains(r.log.String(), " accept ") {
		t.Fatalf("accept logged before any client connected:\n%s", r.log.String())
	}
	c, s := r.connect()
	r.waitLog(" accept ", time.Second)
	_ = c.Close()
	_ = s.Close()
	r.waitExit()
}

func TestParseFaults(t *testing.T) {
	got, err := parseFaults("slice:7, hold@3000:4000,reset@10,blackhole@5:6")
	if err != nil {
		t.Fatal(err)
	}
	want := []fault{
		{kind: "slice", n: 7},
		{kind: "hold", at: 3 * time.Second, dur: 4 * time.Second},
		{kind: "reset", at: 10 * time.Millisecond},
		{kind: "blackhole", at: 5 * time.Millisecond, dur: 6 * time.Millisecond},
	}
	if len(got) != len(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("fault %d: got %+v, want %+v", i, got[i], want[i])
		}
	}
	for _, bad := range []string{"hold@5", "reset@5:6", "slice:0", "slice", "blackhole@x:1", "delay@5:6", "hold@-1:5"} {
		if _, err := parseFaults(bad); err == nil {
			t.Fatalf("%q accepted", bad)
		}
	}
	if got, err := parseFaults(""); err != nil || len(got) != 0 {
		t.Fatalf("empty list: %v %v", got, err)
	}
}

// NF1: nothing changes the bytes without a fault.
func TestCleanForwardsBothWays(t *testing.T) {
	r := startRig(t, "", 30*time.Second)
	c, s := r.connect()
	cs, ss := &sink{}, &sink{}
	cs.drain(c)
	ss.drain(s)
	up, down := pattern(1<<20, 1), pattern(1<<20, 7)
	go func() { _, _ = c.Write(up) }()
	go func() { _, _ = s.Write(down) }()
	if !bytes.Equal(ss.waitLen(t, len(up), 10*time.Second), up) {
		t.Fatal("upstream bytes differ")
	}
	if !bytes.Equal(cs.waitLen(t, len(down), 10*time.Second), down) {
		t.Fatal("downstream bytes differ")
	}
	_ = c.Close()
	if err := ss.waitErr(t, 2*time.Second); !errors.Is(err, io.EOF) {
		t.Fatalf("target side saw %v, want EOF", err)
	}
	_ = s.Close()
	r.waitExit()
}

// NF2: a hold delays both directions, keeps their order and counts what it kept.
func TestHoldDelaysBothDirectionsInOrder(t *testing.T) {
	r := startRig(t, "hold@50:300", 30*time.Second)
	t0 := time.Now()
	c, s := r.connect()
	cs, ss := &sink{}, &sink{}
	cs.drain(c)
	ss.drain(s)
	r.waitLog("hold-start", time.Second)
	up, down := pattern(1000, 1), pattern(2000, 2)
	send(t, c, up)
	send(t, s, down)
	if !bytes.Equal(ss.waitLen(t, len(up), 2*time.Second), up) {
		t.Fatal("upstream bytes differ")
	}
	if !bytes.Equal(cs.waitLen(t, len(down), 2*time.Second), down) {
		t.Fatal("downstream bytes differ")
	}
	for _, k := range []*sink{ss, cs} {
		if _, first, _ := k.state(); first.Sub(t0) < 350*time.Millisecond {
			t.Fatalf("bytes arrived %v after the dial, before the hold ended", first.Sub(t0))
		}
	}
	r.waitLog("hold-end 1000 2000", time.Second)
	more := pattern(500, 9)
	send(t, c, more)
	if !bytes.Equal(ss.waitLen(t, len(up)+len(more), 2*time.Second), append(bytes.Clone(up), more...)) {
		t.Fatal("bytes sent after the hold are out of order")
	}
}

func TestWriteSlicedCutsEveryWrite(t *testing.T) {
	var got [][]byte
	w := writerFunc(func(p []byte) (int, error) { got = append(got, bytes.Clone(p)); return len(p), nil })
	data := pattern(30, 5)
	if err := writeSliced(w, data, 7); err != nil {
		t.Fatal(err)
	}
	if len(got) != 5 {
		t.Fatalf("%d writes for 30 bytes in slices of 7, want 5", len(got))
	}
	for _, p := range got {
		if len(p) > 7 {
			t.Fatalf("write of %d bytes", len(p))
		}
	}
	if !bytes.Equal(bytes.Join(got, nil), data) {
		t.Fatal("sliced bytes differ")
	}
	got = nil
	if err := writeSliced(w, data, 0); err != nil || len(got) != 1 {
		t.Fatalf("no slicing: %d writes, %v", len(got), err)
	}
}

type writerFunc func([]byte) (int, error)

func (f writerFunc) Write(p []byte) (int, error) { return f(p) }

// NF3: the proxy writes in 7-byte pieces (TestWriteSlicedCutsEveryWrite); the kernel may merge pieces before the
// target reads, so the socket-level check is the identical stream and the log line.
func TestSliceKeepsStreamIdentical(t *testing.T) {
	r := startRig(t, "slice:7", 30*time.Second)
	c, s := r.connect()
	cs, ss := &sink{}, &sink{}
	cs.drain(c)
	ss.drain(s)
	up, down := pattern(5000, 1), pattern(7000, 3)
	go func() { _, _ = c.Write(up) }()
	go func() { _, _ = s.Write(down) }()
	if !bytes.Equal(ss.waitLen(t, len(up), 5*time.Second), up) {
		t.Fatal("upstream bytes differ")
	}
	if !bytes.Equal(cs.waitLen(t, len(down), 5*time.Second), down) {
		t.Fatal("downstream bytes differ")
	}
	r.waitLog("slice 7", time.Second)
}

// NF4
func TestResetSendsRST(t *testing.T) {
	r := startRig(t, "reset@200", 30*time.Second)
	t0 := time.Now()
	c, _ := r.connect()
	_ = c.SetReadDeadline(time.Now().Add(3 * time.Second))
	_, err := c.Read(make([]byte, 16))
	if time.Since(t0) < 200*time.Millisecond {
		t.Fatalf("reset after %v", time.Since(t0))
	}
	if runtime.GOOS == "windows" {
		// Go reports the abort with a Windows-specific error, so only EOF (a clean close) is wrong there.
		if err == nil || errors.Is(err, io.EOF) {
			t.Fatalf("read after reset returned %v", err)
		}
	} else if !errors.Is(err, syscall.ECONNRESET) {
		t.Fatalf("read after reset returned %v, want ECONNRESET", err)
	}
	r.waitLog(" reset", time.Second)
	r.waitExit()
}

// NF5: nothing is delivered during the hole, and the stream does not resume when it ends.
func TestBlackholeNeverResumes(t *testing.T) {
	r := startRig(t, "blackhole@150:300", 30*time.Second)
	t0 := time.Now()
	c, s := r.connect()
	cs, ss := &sink{}, &sink{}
	cs.drain(c)
	ss.drain(s)
	r.waitLog("blackhole-start", time.Second)
	send(t, c, pattern(64, 1))
	send(t, s, pattern(64, 2))
	r.waitLog("blackhole-end 64 64", 2*time.Second)
	send(t, c, pattern(4096, 3))
	send(t, s, pattern(4096, 4))
	time.Sleep(300 * time.Millisecond)
	if d, _, _ := ss.state(); len(d) != 0 {
		t.Fatalf("target received %d bytes", len(d))
	}
	if d, _, _ := cs.state(); len(d) != 0 {
		t.Fatalf("client received %d bytes", len(d))
	}
	time.Sleep(time.Until(t0.Add(900 * time.Millisecond)))
	_ = c.Close()
	time.Sleep(time.Second)
	if _, _, err := ss.state(); err != nil {
		t.Fatalf("the client's close reached the target: %v", err)
	}
	_ = s.Close()
	r.waitExit()
}

func TestLifeCapEndsAnIdleConnection(t *testing.T) {
	r := startRig(t, "", 300*time.Millisecond)
	c, _ := r.connect()
	cs := &sink{}
	cs.drain(c)
	r.waitExit()
	if err := cs.waitErr(t, time.Second); err == nil {
		t.Fatal("client still open")
	}
	if !strings.Contains(r.log.String(), "exit cap") {
		t.Fatalf("exit line does not name the cap:\n%s", r.log.String())
	}
}
