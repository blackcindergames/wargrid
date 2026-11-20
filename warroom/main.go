// Command warroom serves the decision rounds and records the owner's picks.
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
	"wargrid/warroom/internal/rounds"
	"wargrid/warroom/internal/web"
)

//go:generate go tool templ generate
//go:generate sh -c "go run . schema round > rounds/round.schema.json && go run . schema step > rounds/step.schema.json"
//go:generate sh -c "cd islands && npm ci && npm run build"

const (
	requestTimeout = 15 * time.Second
	// Inside Fly's kill_timeout, so the last picks are written before the machine is killed.
	drainTimeout = 4 * time.Second
)

type config struct {
	web.Config
	Host, Port string
	// RunAs is the uid to drop to after handing the picks directory over; only the container sets it.
	RunAs string
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
			Secret: getenv("WARROOM_SECRET"),
		},
		Host:  pick("WARROOM_HOST", "127.0.0.1"),
		Port:  pick("WARROOM_PORT", "8780"),
		RunAs: getenv("WARROOM_RUN_AS"),
	}
}

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, nil)))
	err := runCommand(os.Args[1:])
	if err != nil {
		slog.Error("war room", "error", err)
		os.Exit(1)
	}
}

func runCommand(args []string) error {
	if len(args) == 0 {
		return run()
	}
	switch args[0] {
	case "token":
		return printToken(os.Stdout, os.Getenv("WARROOM_SECRET"), args[1:])
	case "schema":
		return printSchema(os.Stdout, args[1:])
	}
	return fmt.Errorf("unknown command %q (token <round>|admin, schema round|step)", args[0])
}

func printToken(w io.Writer, secret string, args []string) error {
	if len(args) != 1 || secret == "" {
		return errors.New("usage: WARROOM_SECRET=... go run . token <round>|admin")
	}
	scope := web.RoundScope(args[0])
	if args[0] == web.AdminScope {
		scope = web.AdminScope
	}
	_, err := fmt.Fprintln(w, web.Token(secret, scope))
	return err
}

func printSchema(w io.Writer, args []string) error {
	if len(args) != 1 {
		return errors.New("usage: go run . schema round|step")
	}
	out, err := rounds.Schema(args[0])
	if err != nil {
		return err
	}
	_, err = w.Write(out)
	return err
}

func run() error {
	cfg := configFromEnv(os.Getenv)
	if cfg.RunAs != "" {
		// A deploy must never go out with every link able to record and read back.
		if cfg.Secret == "" {
			return errors.New("WARROOM_RUN_AS is set (container mode) but WARROOM_SECRET is not")
		}
		uid, err := strconv.Atoi(cfg.RunAs)
		if err != nil || uid <= 0 {
			return fmt.Errorf("WARROOM_RUN_AS must be a positive uid, got %q", cfg.RunAs)
		}
		err = dropPrivileges(cfg.Picks, uid)
		if err != nil {
			return err
		}
	}
	slog.Info("running", "uid", os.Geteuid(), "gid", os.Getegid())
	if cfg.Secret == "" {
		slog.Warn("WARROOM_SECRET is not set: every link can record and read back")
	}
	ln, err := net.Listen("tcp", net.JoinHostPort(cfg.Host, cfg.Port))
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() { <-ctx.Done(); stop() }() // a second signal exits at once
	slog.Info("listening", "url", "http://"+ln.Addr().String()+"/")
	return serve(ctx, ln, newServer(web.NewServer(&cfg.Config).Handler()), drainTimeout)
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
	slog.Info("draining", "timeout", drain)
	dctx, cancel := context.WithTimeout(context.Background(), drain)
	defer cancel()
	err := srv.Shutdown(dctx)
	if errors.Is(err, context.DeadlineExceeded) {
		slog.Warn("drain timeout, closing open requests")
		_ = srv.Close()
		return nil
	}
	return err
}
