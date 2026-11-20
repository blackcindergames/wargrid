#!/bin/sh
# The War Room gate: Go checks, then the island and page-script checks. Browser tests run apart (README, Browser tests).
set -eu

cd "$(dirname "$0")/.."

go vet -tags browser ./...
golangci-lint run --build-tags browser
go test -race ./...
go tool govulncheck ./...
sh tools/check_generated.sh

cd islands
npm ci
npm run quality
