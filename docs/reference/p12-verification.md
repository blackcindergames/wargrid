# P12 Notes that never block: verification

Plan: [P12 plan](../superpowers/plans/2026-11-17-p12-notes-that-never-block.md). Spec: [P12 design](../superpowers/specs/2026-11-17-p12-notes-that-never-block-design.md).

```text
Resume record (updated 2026-11-17)
Branch / base commit / working-tree state: p12-notes / 10d152c / this file only
Last green task / next incomplete task: none / Task 1 (probe built, stop gate A open)
Changed paths since last commit: docs/reference/p12-verification.md
Last command / cases / checks / failures / exit / marker: curl probe pages / - / - / - / 200, 200 / -
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: attended day run (user, 2026-11-17); stop gate A open
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: stop gate A with the user; Task 2 in parallel
```

## Web download probe (Task 1)

Godot's download routine, as exported in `build/web-bench/index.js` (Godot 4.7.2 web export):

```js
function _godot_js_os_download_buffer(p_ptr,p_size,p_name,p_mime){const buf=GodotRuntime.heapSlice(HEAP8,p_ptr,p_size);const name=GodotRuntime.parseString(p_name);const mime=GodotRuntime.parseString(p_mime);const blob=new Blob([buf],{type:mime});const url=window.URL.createObjectURL(blob);const a=document.createElement("a");a.href=url;a.download=name;a.style.display="none";document.body.appendChild(a);a.click();a.remove();window.URL.revokeObjectURL(url)}
```

The probe (`build/p12-probe/`, untracked) copies it from `new Blob` to `revokeObjectURL` with the three `GodotRuntime` lines replaced by a JSON string, a file name and a mime type. `index.html` downloads `probe-1.json` from its load handler and `probe-2.json` 2 s later from a `setTimeout`; `embed.html` holds `index.html` in an iframe.

## Evidence

| Date | Task | Check | Tree | Result |
| --- | --- | --- | --- | --- |
| 2026-11-17 | 1 | `python3 -m http.server 8061 --directory build/p12-probe`, `curl` on `index.html` and `embed.html` | `p12-notes`, `10d152c` | 200, 200 |
