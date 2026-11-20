# War Room: tune step spike

Smallest spike of the islands design (user, 2026-11-20): Go + templ + htmx render the page; a Svelte 5 island, compiled to a custom element `<wr-tune>`, gives live parameter tuning on a render target; the pick records the tuned values as a preset. Target for the spike: War Room's own demo page `warroom/static/demo/scene.html` (not `p2-3a1-states.html`, which the main tree's night run edits).

## Contract

- Step kind `tune` in YAML:
  ```yaml
  kind: tune
  question: Which outline weight and unit size read best?
  target: {page: static/demo/scene.html, state: ...}   # a render recipe like options' `render`
  params:
    - {id: outline, label: Outline, min: 0, max: 4, step: 0.5, value: 1}
    - {id: size, label: Unit size, min: 0.5, max: 2, step: 0.1, value: 1}
    - {id: you, label: Owner colour, color: '#376eac'}
    - {id: ground, label: Ground, values: [sand, dark], value: sand}
  ```
  Kinds of param: number (min/max/step/value), colour (`color: '#rrggbb'`), choice (`values` list + `value`). Ids `[a-z0-9-]+`, at most 12 params. Load-time validation as for other kinds (strict decode, value in range, step > 0, unique ids).
- Channel: the island posts `{type: 'wr:params', params: {...}}` to the target iframe with `postMessage(msg, location.origin)`; the target listens, checks `event.origin === location.origin` and `event.data.type`, and redraws without reload. `scene.html` gets this listener (keeps its hash reading for the first draw).
- Pick: the tune step's pick form gets a hidden field `value` (JSON object of param id → number|string) filled by the island on every change (the island raises an `input` event or sets the field; htmx posts the form as today). Pick letter for a tune step: `tuned`. Neutral answer allowed if `neutral` is set. Server validates `value` against the step's params (only known ids, numbers in range and on step within tolerance, colours `#rrggbb`, choices from the list) and stores it. Picks file entry grows an optional `value` object; old entries without it stay valid; the summary shows it compactly (`outline 1.5 · size 1.2 · you #376eac`). The step reopens with the recorded value as the panel's start.
- Island: `warroom/islands/` (Svelte 5.57.3, Vite 8.3.6, @sveltejs/vite-plugin-svelte 7.3.1 if its peer range accepts Vite 8, otherwise the newest Vite it accepts that is at least two weeks old; tweakpane 4.0.5), `package.json` with exact versions and `package-lock.json` committed, `node_modules/` ignored. Svelte compiles `<wr-tune>` as a custom element (`customElement: true`, `<svelte:options customElement={{tag: 'wr-tune', shadow: 'none'}} />` so Tailwind/daisyUI styles apply). Vite builds one ES module to `warroom/static/islands.js` (committed, embedded); `go generate` runs the build (`npm ci` then `npm run build`), and `tools/check_generated.sh` also checks `islands.js` is current. `go build`, `go test` and the Docker build need no Node.
- Props: templ prints `<wr-tune data-params='<json>' data-target="<iframe id>" data-field="<hidden input id>"></wr-tune>`; JSON via templ's attribute escaping. htmx swaps start it via the custom element lifecycle; no code in `warroom.js` for it. Keys: tune step has the usual Enter (pick), arrows, ?; sliders take arrow keys while focused (the key handler already ignores focused inputs; check Tweakpane's elements count as such).
- Phone: panel under the stage, full width; the stage stays first on screen.
- Demo round: `rounds/demo/tune.yaml` added to `demo` (and `demo-controls` if simpler), tuning 3 to 4 parameters of `scene.html` (outline width on the unit boxes, unit size, owner colour, ground).

## Done when

- `go test -race ./...`, `go vet ./...`, `golangci-lint run`, `sh tools/check_generated.sh`, `node --check static/warroom.js` exit 0 in `warroom/`; Go tests cover the YAML validation of `tune`, the server's `value` validation (out of range, unknown id, bad colour, wrong type, too big), the stored entry and the summary line.
- Headless Firefox (WebDriver) check: moving a slider changes the target's drawing without reloading the iframe (document tag survives); a pick records the value; reopening the step restores it; a flip of other steps still works.
- Screenshots desktop 1600x1000 and phone 390x844 of the tune step.
- README: the `tune` kind, the `wr:params` channel, the islands build, learning notes on Svelte 5 runes and custom elements as htmx islands (verified against the code).
- Reviews: player-experience reviewer and one Opus correctness reviewer; then a lean pass.

## Not in the spike

Pixi, Tone.js, the Godot bridge, tune on HUD render pages, A/B of presets, moving `warroom.js` into Svelte.
