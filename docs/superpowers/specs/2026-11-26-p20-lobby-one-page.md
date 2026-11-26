# P20 A lobby for every match: one page

Package row: [packages](../../packages.md#day-lane). Answers: [lobby prototype answers](../../reference/design-answers-2026-11-08.md#lobby-prototype-answers-user-2026-11-24) and [lobby round](../../reference/design-answers-2026-11-08.md#lobby-round-user-2026-11-26). Pictures: War Room round `lobby`, source `docs/images/lobby-round/lobby.html` (the answered options are its defaults, except `invite=toolbar`). Builds on P7 part 2 (merged first).

## What the player will notice

Play opens on one lobby page for both Skirmish and Host game: a Mode row, players grouped under Team 1 and Team 2, each row with its colour swatch and faction dropdown (Random last), the map dropdown and a preview with a marker per start. You click a free start to take it; the host closes a single start the same way. Hosting puts a code with a copy icon at the right of the Mode row ("Your friend types this code under Join."); the friend appears in the list, and the host presses Start match. A line under the teams counts the starts ("2 of 4 starts used") with + Add bot. The guest sees the host's settings as text and changes only their own faction.

## What would refute it

- The owner's ten-minute look finds the page slower to a match than today's Play (more clicks from launch to Start match for a bot match: today 1, must stay 1).
- A friend cannot tell from the page what to do: in the owner's online match the friend has to ask where they are, which team they are on or where they start.
- Start pick changes who starts where without both windows agreeing (a lockstep desync at the first tick). Existing code first: `StartSpots.assign` already takes `chosen` starts (`game/scripts/simulation/start_spots.gd`); a pinned trace with chosen starts settles it before any match.

## First playable slice

Skirmish and Host game on the new page with what exists today: Mode row, team-grouped rows with swatches, inline faction and map dropdowns with Random, the count line, the code in the Mode row, Start match after the friend joins, the guest's text view; headless layout tests at 1280x720, 1280x800 and 1920x1080. Then start pick on the preview (host and guest, closing a start) as the second slice, test-first for the chosen-starts rule. The owner plays one bot match and one match with a friend.

## Out

Mode cards (remembered for when Quick play and public games exist), Quick play, public games, Private or public, match settings, bot levels (all hidden, room kept), colour pick, ready-up and humans on both sides (P11), lobby chat, spectators, a launcher results page, a separate Invite button.

## Open for the build

- Which team a bot added with + Add bot joins; allied bots stay the Later item Team up with a bot, so the default is the side without humans.
- Whether the host may change the map, the teams or the starts after the friend joined without a new protocol message: the start flow answer says no relay or protocol change, so if the settings cannot reach the guest before Start match, they lock once the friend is in, and P11 unlocks them.
- Start pick online: the chosen starts must reach the guest with the match start (a new field in the start settings), and a guest taking their own start needs a guest-to-host message. If either counts as the protocol change the answers rule out, P20 ships the host placing every start and the guest's own pick waits for P11; ask the owner before the build.
