// Command warroom serves the decision rounds and records the owner's picks.
package main

import (
	"context"
	"errors"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
	"wargrid/warroom/internal/web"
)

//go:generate go tool templ generate
//go:generate sh tools/fetch.sh
//go:generate .bin/tailwindcss --input internal/web/static/input.css --output internal/web/static/app.css --minify
//go:generate sh -c "cd islands && npm ci && npm run build"

const (
	requestTimeout = 15 * time.Second
	// Inside Fly's kill_timeout, so the last picks are written before the machine is killed.
	drainTimeout = 4 * time.Second
)

type config struct {
	web.Config
	Host, Port string
}

// Paths are relative to the working directory, which is warroom/: the repository root is its parent.
func configFromEnv(getenv func(string) string) config {
	pick := func(name, fallback string) string {
		if v := getenv(name); v != "" {
			return v
		}
		return fallback
	}
	return config{
		Config: web.Config{
			Root:   pick("WARROOM_ROOT", ".."),
			Picks:  pick("WARROOM_PICKS", "picks.json"),
			Rounds: pick("WARROOM_ROUNDS", "rounds"),
		},
		Host: pick("WARROOM_HOST", "127.0.0.1"),
		Port: pick("WARROOM_PORT", "8780"),
	}
}

func main() {
	if err := run(); err != nil {
		log.Printf("war room: %v", err)
		os.Exit(1)
	}
}

func run() error {
	cfg := configFromEnv(os.Getenv)
	if err := dropPrivileges(cfg.Picks); err != nil {
		return err
	}
	log.Printf("running as uid %d gid %d", os.Geteuid(), os.Getegid())
	ln, err := net.Listen("tcp", net.JoinHostPort(cfg.Host, cfg.Port))
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() { <-ctx.Done(); stop() }() // a second signal exits at once
	log.Printf("war room on http://%s/", ln.Addr())
	return serve(ctx, ln, newServer(web.NewServer(&cfg.Config).Routes()), drainTimeout)
}

func newServer(h http.Handler) *http.Server {
	return &http.Server{
		Handler:     h,
		ReadTimeout: requestTimeout,
		// Generous: the same server streams the repository's large clips and pictures.
		WriteTimeout:   time.Minute,
		MaxHeaderBytes: 16 << 10,
		IdleTimeout:    time.Minute,
	}
}

// serve returns the serve error, or nil after a clean shutdown; Shutdown waits for in-flight handlers, so a pick being written lands first.
func serve(ctx context.Context, ln net.Listener, srv *http.Server, drain time.Duration) error {
	errc := make(chan error, 1)
	go func() { errc <- srv.Serve(ln) }()
	select {
	case err := <-errc:
		return err
	case <-ctx.Done():
	}
	log.Printf("draining, timeout %s", drain)
	dctx, cancel := context.WithTimeout(context.Background(), drain)
	defer cancel()
	err := srv.Shutdown(dctx)
	if errors.Is(err, context.DeadlineExceeded) {
		log.Print("drain timeout, closing open requests")
		_ = srv.Close()
		return nil
	}
	return err
}
