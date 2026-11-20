module wargrid/warroom

go 1.27.4

ignore ./islands/node_modules

require (
	github.com/a-h/templ v0.3.1100
	github.com/goccy/go-yaml v1.19.2
	github.com/invopop/jsonschema v0.14.0
	github.com/mxschmitt/playwright-go v0.6201.1
)

require (
	github.com/a-h/parse v0.0.0-20250122154542-74294addb73e // indirect
	github.com/andybalholm/brotli v1.2.7 // indirect
	github.com/bahlo/generic-list-go v0.2.0 // indirect
	github.com/buger/jsonparser v1.1.2 // indirect
	github.com/cenkalti/backoff/v4 v4.3.0 // indirect
	github.com/cli/browser v1.3.0 // indirect
	github.com/deckarep/golang-set/v2 v2.8.0 // indirect
	github.com/fatih/color v1.19.0 // indirect
	github.com/fsnotify/fsnotify v1.10.1 // indirect
	github.com/go-stack/stack v1.8.1 // indirect
	github.com/mattn/go-colorable v0.1.15 // indirect
	github.com/mattn/go-isatty v0.0.24 // indirect
	github.com/natefinch/atomic v1.0.1 // indirect
	github.com/pb33f/ordered-map/v2 v2.3.1 // indirect
	go.yaml.in/yaml/v4 v4.0.0-rc.2 // indirect
	golang.org/x/mod v0.42.0 // indirect
	golang.org/x/net v0.61.0 // indirect
	golang.org/x/sync v0.24.0 // indirect
	golang.org/x/sys v0.49.0 // indirect
	golang.org/x/telemetry v0.0.0-20261010193011-f71dc92da45e // indirect
	golang.org/x/tools v0.52.0 // indirect
	golang.org/x/vuln v1.9.0 // indirect
)

tool (
	github.com/a-h/templ/cmd/templ
	golang.org/x/vuln/cmd/govulncheck
)
