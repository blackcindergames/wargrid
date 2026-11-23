# P17 Pan with the mouse: verification

Branch `p17-pan-with-the-mouse`. Package row: [packages](../packages.md#day-lane). How it works: [guide chapter 5](../guide/05-presentation.md#app-shell-scenes-hud-and-input), "Mouse pan (P17)" and "Camera keys and the alert line".

## One page (approved by the owner, 2026-11-23)

- **The player notices:** holding the right button and pulling pans the camera, faster the further from the press (Zero Hour's anchor scroll, GeneralsGameCode `afc2a103f` `LookAtXlat.cpp:256-281`, `:476-483`); the middle button grabs the map 1:1; a short right-click still orders, and a right-drag never orders, cancels placement or leaves attack move. Edge scroll and the arrows stay.
- **Refuting observation:** in the owner's match an unintended move, placement cancel or attack-move exit while panning; a quick right-click order lost to a few px of hand movement; or the owner falling back to edge scroll and arrows. No existing data held pointer travel during right presses (the command recorder logs commands only), so the match was the first evidence.
- **First playable slice:** right-button actions on release within 8 px, right-drag anchor pan, middle-drag grab; then the riders (`H` again returns, arrival ring) and the trackpad check after the match.
- **Out:** invert toggle, simulation changes, pointer-travel telemetry, panning from the HUD.

## Owner checks (2026-11-23)

- Slice on the desktop (Mac mini, mouse): "everything i can test on this mac works great" (user, 2026-11-23).
- Windowed edge scroll was jerky unless the pointer sat on the window's last pixel. A probe log showed the outside rule (P2.3b) working but stopping past its 40-point margin, which a flick overshoots; the margin was dropped (any distance while focused, as Warzone 2100 `b904885ff` `src/display.cpp:1351-1354`). Recheck: "works perfect now" (user, 2026-11-23). Recorded also in the [P2.3b verification](p2.3b-verification.md#edge-scroll-just-outside-a-window-user-2026-11-23).
- MacBook trackpad, before the gesture handling: two-finger scroll did nothing, two-finger click-drag panned (a right-drag), pinch did nothing, three-finger drag did nothing (owner report, 2026-11-23). The owner chose scroll pans and pinch zooms (user, 2026-11-23). After: "works perfectly on the macbook now" (user, 2026-11-23), with `H` again, the arrival ring and the gestures.

## Tests

- `test_mouse_pan.gd` MP1-MP11: a held right press sends nothing and its release within 8 px orders; a 9 px drag sends nothing and keeps the selection; a drag keeps placement and attack move (with the move cursor and the crosshair back), a still click cancels them; anchor speed at 100 and 200 px, held behind the menu, stopped by the release; middle-drag 1:1; drag box holds right and middle; zoom mid-grab; a lost release; release and grab behind the menu; trackpad scroll and pinch.
- `test_camera_keys.gd` CK14 (`H` again, a third `H`, a 30 px pan recentres, double tap mid-glide) and CK15 (ring footprint, growth, fade, none on the return, amber on `Space`). CK10's snap check clears the remembered spot first.
- `test_edge_scroll.gd` ES14: well left, far left and a corner well out now pan (the margin rows changed with the owner's recheck, not to hide a failure).
- `test_hud.gd` QT8: a 12 px right-drag on a cell cancels nothing.
- About 40 older tests that sent only a right press now send a press and a release (`BaseScene.right_click`); expectations unchanged.
- Full suite on `0691fe9b`: 1517 cases, 0 failures; `sh tools/run_checks.sh` passes.

## Gate reviews (2026-11-23)

Opus whole-branch review, Gemini 4 Neon high through `agy`, and the player-experience pass. Fixed test-first: a map pan released over a queue cell cancelled a unit (the cell now needs the press too); a release far from the press with no motion between replayed the order; middle-drag fought edge scroll; the open menu or a result left a pan and its cursor running (now dropped each frame); `H`'s back spot could trap `H` near home and survived a restart; disarming attack move mid-pan replaced the move cursor; a left press ends a pan whose release was lost; the ring now starts when the glide lands (the picked picture); MP7 split so the drag-box rule is pinned (reverting `MousePan.take`'s guard turns both halves red). Owner decisions from the review round (user, 2026-11-23): edge scroll outside the window pans only on the window's own screen; any pan or other jump forgets `H`'s back spot; the arrival ring is a ground mark under buildings. Owner check after the fixes (Mac mini, windowed): ring under the HQ, `H` back and the pan forgetting it, edge scroll past all four edges: "works perfect" (user, 2026-11-23). Not taken: the pinch factor still carries between gestures (accepted). Open: the Esc menu's Controls list has no room for the new rows at 720 px; the owner wants the menu itself researched and redesigned as separate work (only the `H` line changed here).

## Decided for you

8 px distance-only threshold; anchor speed 4 x distance; the order fires at the press position; no pan from HUD presses; `H`'s 24 screen px "already home" range and the double tap mid-glide returning; the 2 x 2 cell start diamond for the `Space` ring; trackpad scroll at 33 px per gesture unit and a 1.25 pinch step.

## Not verified

The web build (whether browsers deliver a release outside the canvas; Firefox sends trackpad scroll as wheel events, which zoom there); Windows and Linux; Godot's macOS pan-gesture scaling in its source.
