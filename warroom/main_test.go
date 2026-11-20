package main

import (
	"bytes"
	"context"
	"io"
	"net"
	"net/http"
	"strings"
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
	env := map[string]string{"WARROOM_PORT": "9000", "WARROOM_PICKS": "/data/picks.json", "WARROOM_SECRET": "s", "WARROOM_RUN_AS": "65534"}
	cfg = configFromEnv(func(k string) string { return env[k] })
	if cfg.Port != "9000" || cfg.Picks != "/data/picks.json" || cfg.Root != ".." || cfg.Secret != "s" || cfg.RunAs != "65534" {
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

func TestTokenCommandPrintsTheTokenTheServerAccepts(t *testing.T) {
	var out bytes.Buffer
	if err := printToken(&out, "s", []string{"demo"}); err != nil {
		t.Fatal(err)
	}
	if got, want := strings.TrimSpace(out.String()), web.Token("s", web.RoundScope("demo")); got != want {
		t.Errorf("round token %q, want %q", got, want)
	}
	out.Reset()
	if err := printToken(&out, "s", []string{"admin"}); err != nil || strings.TrimSpace(out.String()) != web.Token("s", web.AdminScope) {
		t.Errorf("admin token %q, %v", out.String(), err)
	}
	for _, bad := range []struct {
		secret string
		args   []string
	}{{"", []string{"demo"}}, {"s", nil}, {"s", []string{"a", "b"}}} {
		if printToken(io.Discard, bad.secret, bad.args) == nil {
			t.Errorf("printToken(%q, %v) succeeded", bad.secret, bad.args)
		}
	}
}

func TestRunAsMustBeAPositiveUID(t *testing.T) {
	t.Setenv("WARROOM_RUN_AS", "root")
	t.Setenv("WARROOM_SECRET", strings.Repeat("s", minSecret))
	t.Setenv("WARROOM_PORT", "0")
	if err := run(); err == nil || !strings.Contains(err.Error(), "positive uid") {
		t.Errorf("run() = %v", err)
	}
}

func TestContainerModeRefusesToStartWithoutASecret(t *testing.T) {
	t.Setenv("WARROOM_RUN_AS", "65534")
	t.Setenv("WARROOM_SECRET", "")
	// Unlistenable, so a regression fails at once instead of serving.
	t.Setenv("WARROOM_HOST", "256.0.0.1")
	t.Setenv("WARROOM_PORT", "0")
	if err := run(); err == nil || !strings.Contains(err.Error(), "WARROOM_SECRET") {
		t.Errorf("run() = %v", err)
	}
}

func TestContainerModeRefusesAShortSecret(t *testing.T) {
	t.Setenv("WARROOM_RUN_AS", "65534")
	t.Setenv("WARROOM_SECRET", strings.Repeat("s", minSecret-1))
	t.Setenv("WARROOM_HOST", "256.0.0.1")
	t.Setenv("WARROOM_PORT", "0")
	if err := run(); err == nil || !strings.Contains(err.Error(), "at least 32 bytes") {
		t.Errorf("run() = %v", err)
	}
}

func TestUnknownCommandIsAnError(t *testing.T) {
	if runCommand([]string{"nope"}) == nil {
		t.Error("an unknown command succeeded")
	}
}
