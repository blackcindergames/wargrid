DP.step({
  "key": "look",
  "kind": "gallery",
  "question": "Gate A look: every P2.3a1 state",
  "why": "The pictures after the gate A answers, one at a time. Flip with N and P (on a phone: the Item buttons) or the thumbnails; write a note under any state you want changed (saved only when you write one). Then pass the gate or ask for changes.",
  "items": [
    {
      "id": "slab",
      "label": "slab",
      "caption": "Interim slab with a China Bulldozer selected: no order row (builders have no weapon), China's build menu in 2 columns, Rotary Gun Tower armed (panel2, 2 px sel inset); specimens: Medium Tanks with Attack move (A) armed in the same look (after the button or the key, until a ground click, a right-click or Esc; pointer: system crosshair; order row only, the build menu below it as in the main slab), and the Bulldozer's slab while the pointer is on a paused site, Right-click: resume as its top line",
      "render": {
        "state": "slab"
      }
    },
    {
      "id": "notice",
      "label": "notice",
      "caption": "Online notice Waiting for player 2, top centre; a Medium Tank selected, so the order row shows and no Esc chip",
      "render": {
        "state": "notice"
      }
    },
    {
      "id": "freeze",
      "label": "freeze",
      "caption": "Offline freeze as the result card: map and HUD dimmed (a Bulldozer selected: build menu, no order row), centred card with the warning mark and Match stopped, body, divider, footer with the report's version and map (Version 0.14.0-dev+75898c8 · Dry Wells, illustrative) and the code GAME ERROR, Copy report (secondary, focused) and Back to menu (primary); Esc opens the pause menu as on the Victory/Defeat card",
      "render": {
        "state": "freeze"
      }
    },
    {
      "id": "freeze-copied",
      "label": "freeze-copied",
      "caption": "The same card after a click on Copy report: the button reads Report copied and holds the focus",
      "render": {
        "state": "freeze-copied"
      }
    },
    {
      "id": "forecast",
      "label": "forecast",
      "caption": "Strip in place with the USA Power Plant armed (8 / 10 → 8 / 15); specimens: China Rotary Gun Tower (→ 3600, LOW POWER), the same at 500 credits (→ 700 short), FRC with no POWER group (owner question 6)",
      "render": {
        "state": "forecast"
      }
    },
    {
      "id": "sites",
      "label": "sites",
      "caption": "Own paused site (PAUSED · NO BUILDER, progress bar in muted), the slab with Cancel construction; specimens: enemy site with its percent in the owner colour, own factory with the rally footer (84)",
      "render": {
        "state": "sites"
      }
    },
    {
      "id": "chips",
      "label": "chips",
      "caption": "Owner question 5's worst case: China factory, nine-entry queue (slab top 313), checklist capped at 217 and scrolling, note form to its left",
      "render": {
        "state": "chips"
      }
    },
    {
      "id": "chips-f3",
      "label": "chips-f3",
      "caption": "Stack closed, F3 at top 88",
      "render": {
        "state": "chips-f3"
      }
    },
    {
      "id": "chips-f3-rule",
      "label": "chips-f3-rule",
      "caption": "F3 rule, worst case: the state above with F3 open; no room below the checklist and the note form already left of it, so F3 opens under the note form (x 699 to 944, top 173 to 233, above the slab top minus 8)",
      "render": {
        "state": "chips-f3-rule"
      }
    },
    {
      "id": "chips-checklist",
      "label": "chips-checklist",
      "caption": "Checklist open, F3 below it; Power Plant selected, so the slab has no button and is hidden",
      "render": {
        "state": "chips-checklist"
      }
    },
    {
      "id": "chips-form",
      "label": "chips-form",
      "caption": "Checklist and note form open, the form below the checklist, F3 below the form",
      "render": {
        "state": "chips-form"
      }
    },
    {
      "id": "chips-off",
      "label": "chips-off",
      "caption": "Playtest helper off: no chip, F3 at top 48",
      "render": {
        "state": "chips-off"
      }
    },
    {
      "id": "refusal",
      "label": "refusal",
      "caption": "Amber line Insufficient credits at H - 204; factory selected at 500 credits",
      "render": {
        "state": "refusal"
      }
    },
    {
      "id": "pile",
      "label": "pile",
      "caption": "Supply Pile, CREDITS LEFT 10650, 62 high, line edge; specimen Empty",
      "render": {
        "state": "pile"
      }
    },
    {
      "id": "rows-footer",
      "label": "rows-footer",
      "caption": "Kind rows: Rotary Gun Tank hovered (panel2, 1 px muted inset, pointing hand), Militia held at 0, header 96 selected · 5 kinds · 12 idle collectors, the rule Click a kind: select only that kind · Shift-click: deselect it as the panel's last line (158 high, top 562); specimen: 12 selected · 1 kind with one row and no rule line",
      "render": {
        "state": "rows-footer"
      }
    },
    {
      "id": "unload",
      "label": "unload",
      "caption": "A USA Scout Car with infantry inside: Unload (F) joins the order row, second line of the 2-column grid; specimens: an empty Scout Car with no own unit in any container, Unload (F) hidden; an FRC Tunnel Hub with units inside, a building, so Unload (F) alone and no build menu",
      "render": {
        "state": "unload"
      }
    },
    {
      "id": "collector",
      "label": "collector",
      "caption": "Collector labels per the spec table (no place numbers, TO SUPPLY DEPOT, BUILDING, MOVING, FRC's SUPPLY CACHE) and the header 9 selected · 2 kinds · 1 idle collector with the kind-row rule as its last line",
      "render": {
        "state": "collector"
      }
    }
  ],
  "verdict": {
    "key": "verdict",
    "pass": "Pass gate A",
    "changes": "Changes needed"
  }
});
