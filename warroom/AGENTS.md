# War Room agent rules

- Read the neighbouring code and [README](README.md) first; follow the conventions already there.
- After each change run the check for it (`go test ./...`, `npm run check` or `npm run lint` in `islands/`, `go test -tags browser ./...` for page behaviour). Before reporting done run `sh tools/quality.sh`; it is the same gate CI runs (`.github/workflows/warroom.yml`).
- Fix the cause. Never suppress a lint or type error, loosen a rule or edit a generated file to pass; a lint suppression needs a one-line reason and an entry under Exceptions.
- Changed behaviour gets a test (Go test, or a browser test behind `-tags browser`). Page-script behaviour is guarded by a browser test.
- No unrelated refactors and no new dependency without a reason; new versions are at least two weeks old.
- Generated files (`*_templ.go`, `internal/web/static/islands.js`, `internal/web/static/htmx.min.js`, `rounds/*.schema.json`) come from `go generate ./...`; `tools/check_generated.sh` fails on a difference. `tools/test_check_generated.sh` proves it ignores the `fly/site/` deploy copy.

## Exceptions

None.
