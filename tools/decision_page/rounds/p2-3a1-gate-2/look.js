DP.step({
  "key": "look",
  "kind": "gallery",
  "controls": { "marker": true },
  "question": "Gate A verdict: the states redrawn to your answers",
  "why": "Round 1 closed without a verdict. These four states changed after your last answers: no order row for a Bulldozer, Unload hidden on an empty Scout Car, and the system crosshair while attack-move is armed. A pass covers your answers, these pictures and the two picks above. After it I redraw to your picks, with no new choices: the strip in forecast and slab, the refusal line and the freeze card's warning mark (A or B), and the queue in chips and chips-f3-rule. Flip with N and P; a note under any state is optional.",
  "items": [
    {
      "id": "slab",
      "label": "slab",
      "caption": "Interim slab with a China Bulldozer selected: no order row (builders have no weapon), China's build menu in 2 columns, Rotary Gun Tower armed (panel2, 2 px sel inset); specimens: Medium Tanks with Attack move (A) armed in the same look (after the button or the key, until a ground click, a right-click or Esc; pointer: system crosshair; order row only, the build menu below it as in the main slab), and the Bulldozer's slab while the pointer is on a paused site, Right-click: resume as its top line",
      "render": {
        "state": "slab"
      },
      "mark": [
        { "x": 436, "y": 158, "w": 432, "h": 48, "label": "Attack move armed: system crosshair" },
        { "x": 848, "y": 600, "w": 432, "h": 120, "label": "Bulldozer: no order row" }
      ]
    },
    {
      "id": "freeze",
      "label": "freeze",
      "caption": "Offline freeze as the result card: map and HUD dimmed (a Bulldozer selected: build menu, no order row), centred card with the warning mark and Match stopped, body, divider, footer with the report's version and map (Version 0.14.0-dev+75898c8 · Dry Wells, illustrative) and the code GAME ERROR, Copy report (secondary, focused) and Back to menu (primary); Esc opens the pause menu as on the Victory/Defeat card",
      "render": {
        "state": "freeze"
      },
      "mark": { "x": 848, "y": 600, "w": 432, "h": 120, "label": "Bulldozer: no order row" }
    },
    {
      "id": "freeze-copied",
      "label": "freeze-copied",
      "caption": "The same card after a click on Copy report: the button reads Report copied and holds the focus",
      "render": {
        "state": "freeze-copied"
      },
      "mark": { "x": 848, "y": 600, "w": 432, "h": 120, "label": "Bulldozer: no order row" }
    },
    {
      "id": "unload",
      "label": "unload",
      "caption": "A USA Scout Car with infantry inside: Unload (F) joins the order row, second line of the 2-column grid; specimens: an empty Scout Car with no own unit in any container, Unload (F) hidden; an FRC Tunnel Hub with units inside, a building, so Unload (F) alone and no build menu",
      "render": {
        "state": "unload"
      },
      "mark": { "x": 436, "y": 308, "w": 432, "h": 48, "label": "Empty Scout Car: Unload hidden" }
    }
  ],
  "verdict": {
    "key": "verdict",
    "pass": "Pass gate A",
    "changes": "Changes needed"
  }
});
