DP.step({
  "key": "forecast",
  "kind": "pictures",
  "question": "Purchase preview: card under the strip, which red, or on hover?",
  "why": "Take your card. It fixes three things at once: the strip keeps your real numbers, the label says the card is a preview, and the arrow goes (the game's font has no arrow glyph; it does have the minus sign). `−700` replaces `short`; that was your own earlier answer before `700 short` replaced it. Red is fine: Zero Hour's power bar turns red although red is a player colour there, and the old rule was only right about saturated red. A is your mock at the strip's size; B also swaps your sampled coral for a stronger one, #f0776a: yours passes contrast (7.1:1) but turns nearly grey for colour-blind players, close to the labels and the green player colour. I judged that by numbers, so compare the last swatch with the enemy red (second) and the health red (tenth), also in the simulated views, and pick A if B reads too close to the enemy red. One warning colour means low power, the shortfall, the refusal line, the cell card's reason line and the freeze card's warning mark all change together. Hover waits for P2.3b, which already plans it; pick C only if you want the warning before you click now.",
  "look": "Where to look: the top left. In place: China, Rotary Gun Tower armed at 500 credits; below it the owner colours and the other cases. Under A and B, the top of the same picture as deuteranopia and protanopia see it (Machado 2009, severity 1). The card counts live while armed (−700, −200, then 300 in white) and goes on place or cancel. C is drawn in B's colour, bottom right.",
  "rec": "B",
  "recWhy": "your card; this coral stays apart from the green owner colour and the grey labels for colour-blind players, where yours turns nearly grey.",
  "neutral": "None of these",
  "crop": {
    "x": 0,
    "y": 0,
    "w": 448,
    "h": 616
  },
  "ref": {
    "label": "Round 1 picture: arrow and `700 short` in the strip",
    "render": {
      "state": "forecast",
      "crop": {
        "x": 0,
        "y": 0,
        "w": 600,
        "h": 290
      }
    }
  },
  "notesLabel": "Challenger",
  "pairs": [
    ["A coral", "#dc948b", "HUD bg", "#121c24"],
    ["A coral", "#dc948b", "enemy red", "#d6120c", "vs"],
    ["A coral", "#dc948b", "green owner", "#4ad49b", "vs"],
    ["A coral", "#dc948b", "muted label", "#93a5b0", "vs"],
    ["B coral", "#f0776a", "HUD bg", "#121c24"],
    ["B coral", "#f0776a", "button", "#223241"],
    ["B coral", "#f0776a", "enemy red", "#d6120c", "vs"],
    ["B coral", "#f0776a", "green owner", "#4ad49b", "vs"],
    ["B coral", "#f0776a", "health red", "#d8453a", "vs"]
  ],
  "options": {
    "A": {
      "name": "Your card and your coral: under the strip, while a building is armed",
      "render": {
        "state": "forecast-a"
      },
      "sees": "The top strip always shows your real numbers (`CREDITS 500  POWER 8 / 10`) and never grows. Arm a building and a second slab appears right under it at (8, 48): square corners, `bg` fill, 1 px line, padding 8, Public Sans, about 320 x 56. Line 1: muted `AFTER PURCHASE`. Line 2: `CREDITS −700   POWER 11 / 10  LOW POWER`, labels muted 12/600, values 16/700 with tabular digits (the strip's size; your mock drew about 24). Values with a problem and `LOW POWER` are coral #dc948b; fine values are white (`CREDITS 3600`, power plant `POWER 8 / 15`). It counts live: −700, −200, then white 300. Gone when you place or cancel. No arrow, no word `short`. The strip's own low power, the refusal line and the freeze card's warning mark turn coral too.",
      "notes": "Coral: 7.11:1 on bg, 62.5 from the enemy red (42.5 deuteranopia). Weak spots: almost the green owner colour under deuteranopia (6.6) and almost the muted label grey under protanopia (18.2), so only the minus sign and the words carry the warning there. Rules changed: hud-v5-layout :36 and :47 (new token `warn`; \"no saturated red text\" replaces \"no red warning text\"), design answers :79, :109, :1272 and :1276, ART_DIRECTION :146, spec :28 and :131, plan Tasks 6, 8 and 12, focus card text; pictures forecast, refusal and freeze redrawn. No new input. Amber afterwards: alerts and the primary buttons (the freeze card's `Back to menu`, drawn whole bottom left) only; every warning text, the P2.3b cell card's reason line included, is the warning colour.",
      "changes": "Changed from your mock: values at the strip's 16 px, not about 24 (at 24 the card meets the longest online notice at 1280 wide); square corners, the HUD's `bg` fill and 1 px line.",
      "extra": [
        {
          "label": "Your mock (local, not committed)",
          "img": "docs/images/hud-v5/source/owner-mocks/forecast.png",
          "local": true
        },
        {
          "label": "The top of the same picture as deuteranopia sees it",
          "render": {
            "state": "forecast-a",
            "crop": {
              "x": 0,
              "y": 0,
              "w": 448,
              "h": 156
            },
            "params": {
              "cvd": "deut"
            }
          }
        },
        {
          "label": "The same as protanopia sees it",
          "render": {
            "state": "forecast-a",
            "crop": {
              "x": 0,
              "y": 0,
              "w": 448,
              "h": 156
            },
            "params": {
              "cvd": "prot"
            }
          }
        }
      ]
    },
    "B": {
      "name": "Same card, a stronger red: coral #f0776a",
      "render": {
        "state": "forecast-b"
      },
      "sees": "Exactly A, but the warning colour is a more saturated coral-red, #f0776a: clearly a red, still lighter and pinker than the enemy red #d6120c. Under simulated colour blindness it stays a warm olive (#b2a568 deuteranopia, #948b68 protanopia) that differs from the green owner colour and from the grey labels, where A's coral turns nearly grey (#a39e8a).",
      "notes": "6.20:1 on bg, 4.72:1 on buttons. From the enemy red 39.8 / 28.3 / 31.9. Worst case against any owner colour, ally, muted or text is 21.2, above the project's bar of 20; A's coral is at 6.6. It sits near the health bar's red (16 to 20), which means the same thing. Same rule changes, amber rule and cost as A. Judged by numbers only: compare A and B side by side with the two simulated views; the last swatch is the warning colour.",
      "extra": [
        {
          "label": "The top of the same picture as deuteranopia sees it",
          "render": {
            "state": "forecast-b",
            "crop": {
              "x": 0,
              "y": 0,
              "w": 448,
              "h": 156
            },
            "params": {
              "cvd": "deut"
            }
          }
        },
        {
          "label": "The same as protanopia sees it",
          "render": {
            "state": "forecast-b",
            "crop": {
              "x": 0,
              "y": 0,
              "w": 448,
              "h": 156
            },
            "params": {
              "cvd": "prot"
            }
          }
        }
      ]
    },
    "C": {
      "name": "Card on hover above the build buttons, not under the strip",
      "render": {
        "state": "forecast-c",
        "crop": {
          "x": 840,
          "y": 440,
          "w": 440,
          "h": 280
        }
      },
      "sees": "The same card (colour as A or B, say which) appears 8 px above the bottom-right slab, left-aligned with the build or Produce button under the pointer, after 250 ms, and stays while a building is armed. You see `−700` or `LOW POWER` before you click, and for units too, which have no armed state. Nothing under the strip. With the playtest checklist open, the checklist ends 8 px above the slab, exactly where the card goes: the card draws over the checklist while the pointer stays (third picture).",
      "notes": "Closes the real gap: Wargrid lets you arm what you cannot afford, Zero Hour greys the button. Cost: new input (mouse_entered on buttons the menu refresh reuses and frees, hover against armed, keys 1-9 while hovering) on a slab P2.3b throws away; brings P2.3b's tooltip rules (design answers :774, :876) forward; about one more task and one more picture. P2.3b's cell card already plans exactly this.",
      "extra": [
        {
          "label": "The same card on a unit: pointer on Produce at 500 credits",
          "render": {
            "state": "forecast-c-unit"
          }
        },
        {
          "label": "Checklist open: the card draws over it",
          "render": {
            "state": "forecast-c-list"
          }
        }
      ]
    }
  }
});
