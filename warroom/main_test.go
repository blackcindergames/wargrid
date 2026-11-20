package main

import (
	"context"
	"io"
	"net"
	"net/http"
	"testing"
	"time"
	"wargrid/warroom/internal/web"
)

func TestConfigFromEnv(t *testing.T) {
	cfg := configFromEnv(func(string) string { return "" })
	want := config{Config: web.Config{Root: "..", Picks: "picks.json", Rounds: "rounds"}, Host: "127.0.0.1", Port: "8780"}
	if cfg != want {
		t.Fatalf("defaults = %+v", cfg)
	}
	env := map[string]string{"WARROOM_PORT": "9000", "WARROOM_PICKS": "/data/picks.json"}
	cfg = configFromEnv(func(k string) string { return env[k] })
	if cfg.Port != "9000" || cfg.Picks != "/data/picks.json" || cfg.Root != ".." {
		t.Fatalf("overrides = %+v", cfg)
	}
}

func TestShutdownLetsAnInFlightRequestFinish(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	started, release := make(chan struct{}), make(chan struct{})
	h := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		close(started)
		<-release
		_, _ = io.WriteString(w, "done")
	})
	ctx, cancel := context.WithCancel(context.Background())
	served := make(chan error, 1)
	go func() { served <- serve(ctx, ln, newServer(h), 5*time.Second) }()

	type result struct {
		body string
		err  error
	}
	got := make(chan result, 1)
	go func() {
		resp, err := http.Get("http://" + ln.Addr().String() + "/")
		if err != nil {
			got <- result{err: err}
			return
		}
		defer func() { _ = resp.Body.Close() }()
		b, err := io.ReadAll(resp.Body)
		got <- result{string(b), err}
	}()

	<-started
	cancel()
	select {
	case err := <-served:
		t.Fatalf("serve returned %v while a request was in flight", err)
	case <-time.After(200 * time.Millisecond):
	}
	close(release)

	if r := <-got; r.err != nil || r.body != "done" {
		t.Fatalf("in-flight request = %q, %v", r.body, r.err)
	}
	if err := <-served; err != nil {
		t.Fatalf("serve after a clean shutdown = %v", err)
	}
	if _, err := http.Get("http://" + ln.Addr().String() + "/"); err == nil {
		t.Fatal("the listener still accepts after shutdown")
	}
}

func TestShutdownClosesRequestsThatOutlastTheDrain(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	started, release := make(chan struct{}), make(chan struct{})
	t.Cleanup(func() { close(release) })
	h := http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		close(started)
		<-release
	})
	ctx, cancel := context.WithCancel(context.Background())
	served := make(chan error, 1)
	go func() { served <- serve(ctx, ln, newServer(h), 100*time.Millisecond) }()
	go func() { _, _ = http.Get("http://" + ln.Addr().String() + "/") }() //nolint:bodyclose // the request is cut off on purpose

	<-started
	cancel()
	select {
	case err := <-served:
		if err != nil {
			t.Fatalf("serve = %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("serve did not return after the drain timeout")
	}
}

func TestServeReturnsAServeError(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	_ = ln.Close()
	if err := serve(context.Background(), ln, newServer(http.NotFoundHandler()), time.Second); err == nil {
		t.Fatal("a failed listener was reported as success")
	}
}
