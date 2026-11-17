// Command conformance runs the black-box relay protocol suite against a running relay.
// Profiles need the server started with matching settings: default (none), silence (any silence,
// hello and lobby timeouts, passed as -silence, -hello and -lobby), delay (WARGRID_TEST_DELAY_MS=250),
// limits and global (WARGRID_CLIENT_IP_HEADER=X-Wargrid-Test-Ip, default timeouts).
package main

import (
	"flag"
	"os"
)

func main() {
	url := flag.String("url", "ws://127.0.0.1:8080/ws", "relay websocket url")
	profile := flag.String("profile", "default", "default|silence|delay|limits|global")
	flag.DurationVar(&silence, "silence", silence, "server silence timeout (silence profile)")
	flag.DurationVar(&helloLimit, "hello", helloLimit, "server hello deadline (silence profile)")
	flag.DurationVar(&lobbyLimit, "lobby", lobbyLimit, "server lobby expiry and start window (silence profile)")
	flag.Parse()
	os.Exit(runConform(*url, *profile))
}
