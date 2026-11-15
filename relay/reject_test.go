package main

import (
	"bytes"
	"sync"
	"testing"
)

func TestNoPongAfterReject(t *testing.T) {
	for round := range 20000 {
		f := &frames{}
		c := &conn{}
		c.sender = sender{write: f.write, shut: func() {}}
		var wg sync.WaitGroup
		wg.Add(2)
		go func() { defer wg.Done(); c.send([]byte(`{"type":"pong","t":1}`), 0) }()
		go func() { defer wg.Done(); c.reject("lobby expired") }()
		wg.Wait()
		f.mu.Lock()
		last := f.got[len(f.got)-1]
		f.mu.Unlock()
		if !bytes.Contains(last, []byte("lobby expired")) {
			t.Fatalf("round %d: %q after the error", round, last)
		}
	}
}
