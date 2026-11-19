DP.step({
  "key": "card-numbers",
  "kind": "text",
  "question": "The playtest card's numbers question",
  "why": "The new card (\"See your selection\") holds at most five questions, answered 1 to 5 plus free text. Today's fourth question asks two things at once: all numbers, and the five-digit credits gate A asked about.",
  "look": "The card's five questions, the one that changes highlighted.",
  "rec": "A",
  "card": {
    "title": "See your selection",
    "lines": [
      "I could always tell what I had selected",
      "Clicking picked the unit, building or pile I meant",
      "The HUD never swallowed a click I meant for the battlefield",
      null,
      "On a wide or 16:10 screen, the game filled it well"
    ],
    "foot": "1 strongly disagree … 5 strongly agree"
  },
  "options": {
    "A": {
      "name": "Five-digit credits only",
      "text": "Five-digit credits like 10650 read at a glance",
      "notes": "One question, one answer, on what gate A asked (plain digits, no separator). Health and power go to the free-text comment."
    },
    "B": {
      "name": "Keep both in one",
      "text": "Credits, power and health read at a glance, five-digit credits too",
      "notes": "Today's wording (plan Task 17). Covers health and power too, but a low score does not say which number read badly."
    }
  }
});
