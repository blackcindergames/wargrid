// Command netfault is a one-connection TCP proxy that applies a timeline of faults (see proxy.go) for the
// netplay scenarios.
package main

import (
	"flag"
	"fmt"
	"net"
	"os"
	"time"
)

// A failed scenario must never hang CI on a proxy that nobody closes.
const maxLife = 120 * time.Second

func main() {
	listen := flag.String("listen", "", "address to accept the one connection on")
	target := flag.String("target", "", "address to forward to")
	logPath := flag.String("log", "", "file the NETFAULT lines are written to")
	spec := flag.String("faults", "", "comma-separated hold@<at>:<for>, slice:<n>, reset@<at>, blackhole@<at>:<for> (milliseconds)")
	flag.Parse()
	if err := serve(*listen, *target, *logPath, *spec); err != nil {
		fmt.Fprintln(os.Stderr, "netfault:", err)
		os.Exit(1)
	}
}

func serve(listen, target, logPath, spec string) error {
	if listen == "" || target == "" || logPath == "" {
		return fmt.Errorf("-listen, -target and -log are required")
	}
	faults, err := parseFaults(spec)
	if err != nil {
		return err
	}
	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return err
	}
	defer logFile.Close()
	ln, err := net.Listen("tcp", listen)
	if err != nil {
		return err
	}
	return run(ln, target, faults, logFile, maxLife)
}
