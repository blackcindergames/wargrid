package main

import (
	"log/slog"
	"net"
	"net/http"
	"sync"
	"time"
)

// Rates follow ioq3's connection limits (sv_main.c:363-561); the global join bucket is fixed, so the conformance suite paces itself.
const (
	maxConnsPerIP = 16
	joinBurst     = 10
	joinPeriod    = time.Second
	globalBurst   = 20
	globalPeriod  = 50 * time.Millisecond
	unknownBurst  = 10
	unknownPeriod = time.Second
	tableSize     = 4096
)

// limiter guards connection slots and joins per client address: a bounded table that refuses when full,
// so a flood of addresses cannot grow memory; global buckets back up spoofed addresses.
type limiter struct {
	mu           sync.Mutex
	now          func() time.Time
	size         int
	entries      map[string]*ipEntry
	global       bucket
	globalBurst  int
	globalPeriod time.Duration
	unknownB     bucket
	refused      map[string]int
}

type ipEntry struct {
	conns int
	joins bucket
}

type bucket struct {
	used int
	last time.Time
}

func newLimiter(size, globalBurst int, globalPeriod time.Duration, now func() time.Time) *limiter {
	return &limiter{
		now: now, size: size, entries: map[string]*ipEntry{}, refused: map[string]int{},
		globalBurst: globalBurst, globalPeriod: globalPeriod,
	}
}

// clientKey is the address the per-IP rules count, or "" for none (variable unset, header missing or unparsable).
func clientKey(r *http.Request, header string) string {
	if header == "" {
		return ""
	}
	ip := net.ParseIP(r.Header.Get(header))
	switch {
	case ip == nil:
		return ""
	case ip.To4() != nil:
		return ip.To4().String()
	default:
		return ip.Mask(net.CIDRMask(64, 128)).String()
	}
}

// open counts a socket for key. A refusal still counts, since close decrements it.
func (l *limiter) open(key string) (reason string, tracked bool) {
	if l == nil || key == "" {
		return "", false
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	e := l.entry(key)
	if e == nil {
		l.refuse("table")
		return "relay busy", false
	}
	e.conns++
	if e.conns > maxConnsPerIP {
		l.refuse("conns")
		return "too many connections", true
	}
	return "", true
}

func (l *limiter) close(key string, tracked bool) {
	if l == nil || !tracked || key == "" {
		return
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if e := l.entries[key]; e != nil && e.conns > 0 {
		e.conns--
	}
}

// join draws from the address's bucket (unless key is "") and then the global one.
func (l *limiter) join(key string) string {
	if l == nil {
		return ""
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if key != "" {
		e := l.entry(key)
		if e == nil {
			l.refuse("table")
			return "relay busy"
		}
		if !l.allow(&e.joins, joinBurst, joinPeriod) {
			l.refuse("joins")
			return "too many joins"
		}
	}
	if !l.allow(&l.global, l.globalBurst, l.globalPeriod) {
		l.refuse("global")
		return "relay busy"
	}
	return ""
}

// unknown reports whether a reply for an unknown match code may be sent.
func (l *limiter) unknown() bool {
	if l == nil {
		return true
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.allow(&l.unknownB, unknownBurst, unknownPeriod) {
		return true
	}
	l.refuse("unknown")
	return false
}

// allow leaks elapsed/period units and keeps the remainder, then takes one unit if the burst has room.
func (l *limiter) allow(b *bucket, burst int, period time.Duration) bool {
	now := l.now()
	if b.last.IsZero() {
		b.last = now
	}
	if n := int(now.Sub(b.last) / period); n > 0 {
		b.used = max(0, b.used-n)
		b.last = b.last.Add(time.Duration(n) * period)
	}
	if b.used >= burst {
		return false
	}
	b.used++
	return true
}

// entry returns key's entry, reclaiming an idle one when the table is full; nil if none can be.
func (l *limiter) entry(key string) *ipEntry {
	if e := l.entries[key]; e != nil {
		return e
	}
	if len(l.entries) >= l.size && !l.reclaim() {
		return nil
	}
	e := &ipEntry{}
	l.entries[key] = e
	return e
}

func (l *limiter) reclaim() bool {
	for k, e := range l.entries {
		if l.idle(e) {
			delete(l.entries, k)
			return true
		}
	}
	return false
}

func (l *limiter) idle(e *ipEntry) bool {
	return e.conns == 0 && e.joins.used-int(l.now().Sub(e.joins.last)/joinPeriod) <= 0
}

// refuse logs the first refusal of a rule and every 100th after it; never the address.
func (l *limiter) refuse(rule string) {
	l.refused[rule]++
	if n := l.refused[rule]; n == 1 || n%100 == 0 {
		slog.Warn("limit", "rule", rule, "refused", n)
	}
}
