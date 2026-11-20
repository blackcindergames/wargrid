// Command warroom serves the decision rounds and records the owner's picks.
package main

import (
	"log"
	"net"
	"net/http"
	"os"
	"time"
)

//go:generate go tool templ generate
//go:generate sh tools/fetch.sh
//go:generate .bin/tailwindcss --input static/input.css --output static/app.css --minify

const requestTimeout = 15 * time.Second

// Paths are relative to the working directory, which is warroom/: the repository root is its parent.
func configFromEnv(getenv func(string) string) Config {
	pick := func(name, fallback string) string {
		if v := getenv(name); v != "" {
			return v
		}
		return fallback
	}
	return Config{
		Root:   pick("WARROOM_ROOT", ".."),
		Picks:  pick("WARROOM_PICKS", "picks.json"),
		Rounds: pick("WARROOM_ROUNDS", "rounds"),
		Host:   pick("WARROOM_HOST", "127.0.0.1"),
		Port:   pick("WARROOM_PORT", "8780"),
	}
}

func main() {
	cfg := configFromEnv(os.Getenv)
	addr := net.JoinHostPort(cfg.Host, cfg.Port)
	srv := &http.Server{
		Addr:        addr,
		Handler:     NewServer(&cfg).Routes(),
		ReadTimeout: requestTimeout,
		// Generous: the same server streams the repository's large clips and pictures.
		WriteTimeout:   time.Minute,
		MaxHeaderBytes: 16 << 10,
		IdleTimeout:    time.Minute,
	}
	log.Printf("war room on http://%s/", addr)
	log.Fatal(srv.ListenAndServe())
}
