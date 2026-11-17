package main

import (
	"bytes"
	"testing"
)

func newBatchSender() (*sender, *frames) {
	f := &frames{}
	return &sender{write: f.write, shut: func() {}}, f
}

func TestBatchCutAtFrameCap(t *testing.T) {
	t.Run("max frames come out one by one", func(t *testing.T) {
		s, f := newBatchSender()
		frame := bytes.Repeat([]byte("x"), maxMessageBytes)
		for range 5 {
			s.addBatch(frame)
		}
		s.flushNow()
		if len(f.got) != 5 {
			t.Fatalf("got %d messages, want 5", len(f.got))
		}
		for i, m := range f.got {
			if len(m) > maxMessageBytes {
				t.Fatalf("message %d has %d bytes, over %d", i, len(m), maxMessageBytes)
			}
		}
		if got, want := bytes.Join(f.got, []byte("\n")), bytes.Join([][]byte{frame, frame, frame, frame, frame}, []byte("\n")); !bytes.Equal(got, want) {
			t.Fatal("frames reordered or altered")
		}
	})

	t.Run("exactly the cap is one message", func(t *testing.T) {
		s, f := newBatchSender()
		s.addBatch(bytes.Repeat([]byte("a"), 32767))
		s.addBatch(bytes.Repeat([]byte("b"), 32768))
		s.flushNow()
		if len(f.got) != 1 {
			t.Fatalf("got %d messages, want one", len(f.got))
		}
		if len(f.got[0]) != maxMessageBytes {
			t.Fatalf("got a message of %d bytes, want %d", len(f.got[0]), maxMessageBytes)
		}
	})

	t.Run("one byte more is two messages", func(t *testing.T) {
		s, f := newBatchSender()
		s.addBatch(bytes.Repeat([]byte("a"), 32767))
		s.addBatch(bytes.Repeat([]byte("b"), 32769))
		s.flushNow()
		if len(f.got) != 2 || len(f.got[0]) != 32767 || len(f.got[1]) != 32769 {
			t.Fatalf("got %d messages, want 32767 then 32769 bytes", len(f.got))
		}
	})

	t.Run("small frames stay joined", func(t *testing.T) {
		s, f := newBatchSender()
		frame := bytes.Repeat([]byte("s"), 100)
		for range 3 {
			s.addBatch(frame)
		}
		s.flushNow()
		want := bytes.Join([][]byte{frame, frame, frame}, []byte("\n"))
		if len(f.got) != 1 || !bytes.Equal(f.got[0], want) {
			t.Fatalf("got %d messages, want one newline-joined message", len(f.got))
		}
	})

	t.Run("sealed sender takes no more frames", func(t *testing.T) {
		s, f := newBatchSender()
		first := bytes.Repeat([]byte("s"), 100)
		s.addBatch(first)
		s.sendLast([]byte("err"))
		s.addBatch(bytes.Repeat([]byte("x"), maxMessageBytes))
		s.flushNow()
		if len(f.got) != 2 || !bytes.Equal(f.got[0], first) || string(f.got[1]) != "err" {
			t.Fatalf("got %d messages, want the batched frame then err", len(f.got))
		}
	})
}
