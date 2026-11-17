package main

import (
	"context"
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"log/slog"
	"maps"
	"math"
	"runtime/debug"
	"slices"
	"strings"
	"sync"
	"time"
)

const (
	codeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	protocol     = 2
	inputDelay   = 4
	maxDelay     = inputDelay  // the highest delay a seat may use; the lead bound allows it, adaptive input delay raises it
	expiryGrace  = time.Second // the socket backstop sits after the room timer, so the error frame lands before the close
)

type config struct {
	seats     int
	testDelay time.Duration
	batch     time.Duration
	hello     time.Duration
	silence   time.Duration
	lobby     time.Duration // lobby expiry and start window
}

type seat struct {
	n        int
	c        *conn
	r        *room
	lastTick int
	frames   int
	bytes    int
	maxFrame int
	peak     int // most bytes in one tumbling second
	winBytes int
	winStart time.Time
	dead     bool // rejected: ignore further input, still counts until the socket closes
	over     bool
	again    bool
}

type joinReq struct {
	hello *envelope
	c     *conn
	reply chan joinResult
}

type joinResult struct {
	seat   *seat
	reason string
}

type tickMsg struct {
	s    *seat
	seat int
	tick int
	data []byte // one copy, shared read-only by every recipient
	hash hashMsg
}

type leaveMsg struct{ s *seat }

type overMsg struct{ s *seat }

type againMsg struct{ s *seat }

// room owns all its state in run(); connections talk to it only through channels.
type room struct {
	code     string
	cfg      config
	reg      *registry
	build    string
	joins    chan joinReq // unbuffered: a send succeeds only while run() is alive
	events   chan any
	done     chan struct{}
	seats    map[int]*seat
	started  bool
	settings []byte
	stats    map[int]string
	// hashes holds comparisons still waiting for a seat: hash tick -> seat -> value.
	hashes       map[int]map[int]string
	peaks        map[int][2]int // seat -> max frame, peak bytes per second
	desyncTick   int
	desyncGroups string // empty until the first mismatch; hash tick 0 is real
	// expiresAt is set in create; expiry and expired belong to run().
	expiresAt time.Time
	expiry    *time.Timer
	expired   bool
	parked    bool // every seat sent over; the park limit runs on expiry
	draining  bool
}

func (r *room) run() {
	defer close(r.done)
	defer r.recoverCrash()
	drain, quit := r.reg.draining, r.reg.quit
	var flush <-chan time.Time
	if r.cfg.batch > 0 {
		t := time.NewTicker(r.cfg.batch)
		defer t.Stop()
		flush = t.C
	}
	r.expiry = time.NewTimer(time.Until(r.expiresAt))
	defer r.expiry.Stop()
	for {
		select {
		case <-flush:
			for _, s := range r.seats {
				s.c.flushNow()
			}
		case <-drain:
			drain = nil
			r.markDraining()
		case <-quit:
			quit = nil
			r.closeAll()
		case <-r.expiry.C:
			r.expire()
		case j := <-r.joins:
			j.reply <- r.join(j)
		case ev := <-r.events:
			// select picks ready cases at random, so a queued again could otherwise beat a closed drain.
			select {
			case <-drain:
				drain = nil
				r.markDraining()
			default:
			}
			switch ev := ev.(type) {
			case tickMsg:
				r.forward(&ev)
			case overMsg:
				r.onOver(ev.s)
			case againMsg:
				r.onAgain(ev.s)
			case leaveMsg:
				if r.leave(ev.s) {
					return
				}
			}
		}
	}
}

func (r *room) markDraining() {
	r.draining = true
	if !r.started || r.parked { // no new connections arrive while draining, so the lobby can never fill
		r.closeAll()
	}
}

// post never blocks on a room whose goroutine has ended.
func (r *room) post(ev any) {
	select {
	case r.events <- ev:
	case <-r.done:
	}
}

// closeAll ends every seat's socket; each close comes back as a leave.
func (r *room) closeAll() {
	for _, s := range r.seats {
		s.c.close()
	}
}

// recoverCrash ends only this room when its goroutine panics.
func (r *room) recoverCrash() {
	p := recover()
	if p == nil {
		return
	}
	slog.Error("room crashed", "code", r.code, "panic", p, "stack", string(debug.Stack()))
	r.reg.remove(r.code, r)
	r.closeAll()
}

func (r *room) expire() {
	if r.parked {
		r.expired = true
		slog.Info("room expired", "code", r.code)
		for _, s := range r.seats {
			s.dead = true
			s.c.reject("room expired")
		}
		return
	}
	if r.started {
		return
	}
	r.expired = true
	r.reg.remove(r.code, r)
	slog.Info("lobby expired", "code", r.code)
	for _, s := range r.seats {
		s.c.reject("lobby expired")
	}
}

func (r *room) join(j joinReq) joinResult {
	h := j.hello
	if r.expired {
		return joinResult{reason: "unknown match"}
	}
	if r.build != h.build {
		return joinResult{reason: "build mismatch"}
	}
	if r.started || len(r.seats) >= r.cfg.seats {
		return joinResult{reason: "match full"}
	}
	return joinResult{seat: r.admit(j.c)}
}

func (r *room) admit(c *conn) *seat {
	n := 1
	for r.seats[n] != nil {
		n++
	}
	s := &seat{n: n, c: c, r: r}
	r.seats[n] = s
	slog.Info("seat joined", "code", r.code, "seat", n)
	c.send([]byte(fmt.Sprintf(`{"type":"welcome","seat":%d,"match":%q}`, n, r.code)), 0)
	if len(r.seats) == r.cfg.seats {
		r.start()
	} else {
		c.dl.hold(r.expiresAt.Add(expiryGrace))
	}
	return s
}

func (r *room) start() {
	r.started = true
	list := make([]string, r.cfg.seats)
	for i := range list {
		list[i] = fmt.Sprint(i + 1)
	}
	slog.Info("match start", "code", r.code, "seats", r.cfg.seats)
	start := []byte(fmt.Sprintf(`{"type":"start","seats":[%s],"delay":%d,"seed":%d,"settings":%s}`, strings.Join(list, ","), inputDelay, randomSeed(), r.settings))
	window := time.Now().Add(r.cfg.lobby)
	for _, s := range r.seats {
		s.c.dl.hold(window)
		s.c.send(start, 0)
	}
}

func (r *room) forward(t *tickMsg) {
	s := t.s
	if s.dead {
		return
	}
	if !r.started || s.over || t.seat != s.n || t.tick != max(s.lastTick, inputDelay-1)+1 {
		r.refuse(s)
		return
	}
	if t.tick > r.leadLimit(s) {
		s.dead = true
		slog.Info("lead bound", "code", r.code, "seat", s.n, "tick", t.tick)
		s.c.reject("too far ahead")
		return
	}
	if s.lastTick == 0 {
		s.c.dl.every(r.cfg.silence)
	}
	s.lastTick, s.frames, s.bytes = t.tick, s.frames+1, s.bytes+len(t.data)
	now := time.Now()
	if now.Sub(s.winStart) >= time.Second {
		s.winStart, s.winBytes = now, 0
	}
	s.winBytes += len(t.data)
	s.peak, s.maxFrame = max(s.peak, s.winBytes), max(s.maxFrame, len(t.data))
	r.recordHash(s, t.tick, t.hash)
	for _, o := range r.seats {
		if o != s {
			if r.cfg.batch > 0 {
				o.c.addBatch(t.data)
			} else {
				o.c.send(t.data, r.cfg.testDelay)
			}
		}
	}
}

// leadLimit is the last tick an honest seat can send (derivation: codebase guide ch. 11).
func (r *room) leadLimit(s *seat) int {
	lowest := math.MaxInt
	for _, o := range r.seats {
		if o != s {
			lowest = min(lowest, max(o.lastTick, inputDelay-1))
		}
	}
	if lowest == math.MaxInt { // no other seat: nothing to stay behind
		return lowest
	}
	return lowest + maxDelay + 1
}

// recordHash compares a hash once every seat sent it. Honest clients hash tick T in the frame for T+delay
// (lockstep.finish_tick); other offsets are forwarded but not recorded.
func (r *room) recordHash(s *seat, tick int, h hashMsg) {
	if !h.ok || h.tick != tick-inputDelay {
		return
	}
	m := r.hashes[h.tick]
	if m == nil {
		m = map[int]string{}
		r.hashes[h.tick] = m
	}
	m[s.n] = h.value
	if len(m) == len(r.seats) {
		delete(r.hashes, h.tick)
		if g := hashGroups(m); strings.Contains(g, "|") && r.desyncGroups == "" {
			r.desyncTick, r.desyncGroups = h.tick, g
			slog.Warn("DESYNC", "code", r.code, "tick", h.tick, "groups", g)
		}
	}
	r.pruneHashes()
}

// pruneHashes drops comparisons that can no longer complete: once every seat sent the frame for h+delay, a
// missing value never comes. With the lead bound at most maxDelay+1 entries stay open, whatever clients send.
func (r *room) pruneHashes() {
	low := math.MaxInt
	for _, o := range r.seats {
		low = min(low, o.lastTick)
	}
	for h := range r.hashes {
		if h+inputDelay <= low {
			delete(r.hashes, h)
		}
	}
}

// hashGroups lists seats with equal values, groups ordered by their lowest seat: "1,3|2".
func hashGroups(m map[int]string) string {
	seats := slices.Sorted(maps.Keys(m))
	placed := map[int]bool{}
	var groups []string
	for _, n := range seats {
		if placed[n] {
			continue
		}
		var g []string
		for _, o := range seats {
			if m[o] == m[n] {
				placed[o] = true
				g = append(g, fmt.Sprint(o))
			}
		}
		groups = append(groups, strings.Join(g, ","))
	}
	return strings.Join(groups, "|")
}

func (r *room) refuse(s *seat) {
	s.dead = true
	s.c.reject("invalid message")
}

func (r *room) onOver(s *seat) {
	if s.dead || r.expired {
		return
	}
	if !r.started || s.over || s.lastTick == 0 {
		r.refuse(s)
		return
	}
	s.over = true
	if r.everySeat(func(o *seat) bool { return o.over }) {
		r.park()
	}
}

// everySeat reports whether all cfg.seats seats are still present and match ok.
func (r *room) everySeat(ok func(*seat) bool) bool {
	if len(r.seats) < r.cfg.seats {
		return false
	}
	for _, o := range r.seats {
		if !ok(o) {
			return false
		}
	}
	return true
}

func (r *room) park() {
	r.parked = true
	r.expiresAt = time.Now().Add(r.cfg.lobby)
	r.expiry.Reset(r.cfg.lobby)
	for _, s := range r.seats {
		s.c.dl.hold(r.expiresAt.Add(expiryGrace))
	}
	if r.draining {
		r.closeAll()
	}
}

func (r *room) onAgain(s *seat) {
	if s.dead || r.expired || r.draining {
		return
	}
	if !s.over || s.again {
		r.refuse(s)
		return
	}
	s.again = true
	echo := []byte(fmt.Sprintf(`{"type":"again","seat":%d}`, s.n))
	for _, o := range r.seats {
		if o != s {
			o.c.send(echo, 0)
		}
	}
	if r.parked && r.everySeat(func(o *seat) bool { return o.again }) {
		r.rematch()
	}
}

// rematch keeps frame and byte counts so MATCH END reports the whole room.
func (r *room) rematch() {
	for _, s := range r.seats {
		s.lastTick, s.over, s.again = 0, false, false
	}
	r.parked = false
	clear(r.hashes)
	slog.Info("rematch", "code", r.code)
	r.start()
}

// leave reports whether the room is now empty and has been removed.
func (r *room) leave(s *seat) bool {
	delete(r.seats, s.n)
	left := []byte(fmt.Sprintf(`{"type":"left","seat":%d,"after_tick":%d}`, s.n, max(s.lastTick, inputDelay-1)))
	for _, o := range r.seats {
		o.c.send(left, 0)
	}
	clear(r.hashes) // a pending comparison cannot complete with the old seat count
	r.stats[s.n] = fmt.Sprintf("%df/%dB", s.frames, s.bytes)
	r.peaks[s.n] = [2]int{s.maxFrame, s.peak}
	if len(r.seats) > 0 {
		return false
	}
	r.reg.remove(r.code, r)
	args := []any{"code", r.code}
	for _, n := range slices.Sorted(maps.Keys(r.stats)) {
		args = append(args, fmt.Sprintf("seat%d", n), r.stats[n],
			fmt.Sprintf("seat%d_max_frame", n), r.peaks[n][0], fmt.Sprintf("seat%d_peak_bps", n), r.peaks[n][1])
	}
	if r.desyncGroups != "" {
		args = append(args, "desync", r.desyncTick, "desync_groups", r.desyncGroups)
	}
	slog.Info("MATCH END", args...)
	return true
}

// registry is only touched on create, lookup and removal, never per frame.
type registry struct {
	mu       sync.Mutex
	rooms    map[string]*room
	cfg      config
	draining chan struct{} // closed on shutdown signal
	quit     chan struct{} // closed when the drain deadline passes
}

func newRegistry(cfg config) *registry {
	return &registry{rooms: map[string]*room{}, cfg: cfg, draining: make(chan struct{}), quit: make(chan struct{})}
}

func (g *registry) startDrain() { close(g.draining) }
func (g *registry) stop()       { close(g.quit) }

func (g *registry) count() int {
	g.mu.Lock()
	defer g.mu.Unlock()
	return len(g.rooms)
}

// waitEmpty reports whether every room ended before ctx was done.
func (g *registry) waitEmpty(ctx context.Context) bool {
	t := time.NewTicker(50 * time.Millisecond)
	defer t.Stop()
	for g.count() > 0 {
		select {
		case <-ctx.Done():
			return false
		case <-t.C:
		}
	}
	return true
}

func (g *registry) remove(code string, r *room) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.rooms[code] == r {
		delete(g.rooms, code)
	}
}

func (g *registry) join(h *envelope, c *conn) joinResult {
	if h.protocol != protocol {
		return joinResult{reason: "protocol mismatch"}
	}
	if h.badSettings {
		return joinResult{reason: "invalid message"}
	}
	if h.match == "" {
		if h.settings == nil {
			return joinResult{reason: "missing settings"}
		}
		return g.create(h, c)
	}
	g.mu.Lock()
	r := g.rooms[h.match]
	g.mu.Unlock()
	if r == nil {
		return joinResult{reason: "unknown match"}
	}
	req := joinReq{h, c, make(chan joinResult, 1)}
	select {
	case r.joins <- req:
		select {
		case res := <-req.reply:
			return res
		case <-r.done: // crashed mid-join
			return joinResult{reason: "unknown match"}
		}
	case <-r.done:
		return joinResult{reason: "unknown match"}
	}
}

func (g *registry) create(h *envelope, c *conn) joinResult {
	g.mu.Lock()
	code := randomCode()
	for g.rooms[code] != nil {
		code = randomCode()
	}
	r := &room{
		code: code, cfg: g.cfg, reg: g, build: h.build, settings: h.settings,
		joins: make(chan joinReq), events: make(chan any, 64), done: make(chan struct{}),
		seats: map[int]*seat{}, stats: map[int]string{}, expiresAt: time.Now().Add(g.cfg.lobby),
		hashes: map[int]map[int]string{}, peaks: map[int][2]int{},
	}
	g.rooms[code] = r
	g.mu.Unlock()
	slog.Info("room created", "code", code, "build", h.build)
	s := r.admit(c) // before run() starts: nobody else knows the code yet
	go r.run()
	return joinResult{seat: s}
}

func randomSeed() int {
	var b [4]byte
	rand.Read(b[:])
	return int(binary.BigEndian.Uint32(b[:]) & 0x7fffffff)
}

func randomCode() string {
	b := make([]byte, 6)
	rand.Read(b)
	for i := range b {
		b[i] = codeAlphabet[int(b[i])%len(codeAlphabet)] // 256 % 32 == 0: unbiased
	}
	return string(b)
}
