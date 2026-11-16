package main

import (
	"bytes"
	"errors"
	"io"
	"net"
	"testing"
	"time"
)

type pipeListener struct{ conn net.Conn }

func (l pipeListener) Accept() (net.Conn, error) { return l.conn, nil }
func (l pipeListener) Close() error              { return nil }
func (l pipeListener) Addr() net.Addr            { return &net.TCPAddr{} }

// A net.Pipe read never spans two writes, so the client's read sizes show how run cut the target's data.
func TestRunSlicesWhatTheClientReads(t *testing.T) {
	srv, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = srv.Close() }()
	faults, err := parseFaults("slice:7")
	if err != nil {
		t.Fatal(err)
	}
	client, proxySide := net.Pipe()
	done := make(chan error, 1)
	go func() { done <- run(pipeListener{proxySide}, srv.Addr().String(), faults, &syncBuf{}, 10*time.Second) }()

	_ = srv.(*net.TCPListener).SetDeadline(time.Now().Add(3 * time.Second))
	target, err := srv.Accept()
	if err != nil {
		t.Fatal(err)
	}
	want := pattern(7000, 1)
	go func() {
		_, _ = target.Write(want)
		_ = target.Close()
	}()

	_ = client.SetReadDeadline(time.Now().Add(3 * time.Second))
	var got []byte
	buf := make([]byte, 64<<10)
	for {
		n, err := client.Read(buf)
		if n > 7 {
			t.Fatalf("client read %d bytes, want at most 7", n)
		}
		got = append(got, buf[:n]...)
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			t.Fatalf("read after %d bytes: %v", len(got), err)
		}
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("stream differs: got %d bytes, want %d", len(got), len(want))
	}
	_ = client.Close()
	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("run: %v", err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("proxy still running")
	}
}
