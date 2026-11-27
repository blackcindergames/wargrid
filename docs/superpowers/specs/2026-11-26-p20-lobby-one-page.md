# P20 A lobby for every match: one page

Package row: [packages](../../packages.md#day-lane). Answers: [lobby prototype answers](../../reference/design-answers-2026-11-08.md#lobby-prototype-answers-user-2026-11-24) and [lobby round](../../reference/design-answers-2026-11-08.md#lobby-round-user-2026-11-26). Pictures: War Room round `lobby`, source `docs/images/lobby-round/lobby.html` (the answered options are its defaults, except `invite=toolbar`). Builds on P7 part 2 (merged first).

## What the player will notice

Play opens on one lobby page for both Skirmish and Host game: a Mode row, players grouped under Team 1 and Team 2, each row with its colour swatch and faction dropdown (Random last), the map dropdown and a preview with a marker per start. You click a free start to take it; the host closes a single start the same way. Hosting puts the code under a small INVITE CODE label at the right of the Mode row, with Copy ("Copied" for 2 s) and a tooltip saying what to do with it; the friend appears in the list, and the host presses Start match. A line under the teams counts the starts ("2 of 4 starts used") with + Add bot. The guest sees the host's settings as text and changes only their own faction.

## What would refute it

- The owner's ten-minute look finds the page slower to a match than today's Play (more clicks from launch to Start match for a bot match: today 1, must stay 1).
- A friend cannot tell from the page what to do: in the owner's online match the friend has to ask where they are, which team they are on or where they start.
- Start pick changes who starts where without both windows agreeing (a lockstep desync at the first tick). Existing code first: `StartSpots.assign` already takes `chosen` starts (`game/scripts/simulation/start_spots.gd`); a pinned trace with chosen starts settles it before any match.

## First playable slice

Skirmish, Host game and Join game on the new page in the prototype's navy look: Mode row (Join game is the third mode; the Join page goes), team-grouped rows with swatches and an aligned action column with a grey X to remove a bot, inline faction and map dropdowns with Random, the count line naming why + Add enemy bot is greyed, the code shown at once on Host game in the invite box ("Invite code", code, fixed-width "Copy code"/"Copied" segment), a live room (the friend sees each host change with one line naming it, the host sees the friend join and leave, Start match after the friend joins), the guest's text view with their own faction; headless layout tests at 1280x720, 1280x800 and 1920x1080. Then start pick on the preview (host and guest, closing a start) as the second slice, test-first for the chosen-starts rule. The owner plays one bot match and one match with a friend.

## Out

Mode cards (remembered for when Quick play and public games exist), Quick play, public games, Private or public, match settings, bot levels (all hidden, room kept), colour pick, ready-up and humans on both sides (P11), lobby chat, spectators, a launcher results page, a separate Invite button.

## Answered for the build

[Lobby build answers](../../reference/design-answers-2026-11-08.md#lobby-build-answers-user-2026-11-26), [lobby look after the first bot match](../../reference/design-answers-2026-11-08.md#lobby-look-after-the-first-bot-match-user-2026-11-26), [lobby look round](../../reference/design-answers-2026-11-08.md#lobby-look-round-user-2026-11-26) and [live room in P20](../../reference/design-answers-2026-11-08.md#live-room-in-p20-user-2026-11-26) (user, 2026-11-26): + Add bot adds an enemy bot (offline 1 against several bots; no team move); protocol 3 live room on the relay (host-only `settings`, `joined`, `start_request`, `welcome` with settings), served beside protocol 2; hold C and the lock at Get invite code retire.

## Answered for the second slice

[Lobby after the friend match](../../reference/design-answers-2026-11-08.md#lobby-after-the-friend-match-user-2026-11-26) (user, 2026-11-26): each player places their own start on the preview; the friend's choice rides on the protocol 3 `pick` message, the host folds it into the settings. A Skirmish click while hosting asks "Stop hosting?" (user, 2026-11-27).
