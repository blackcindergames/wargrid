# Playing online (M5 spike)

Two players, one match, through the relay. Both need the same build; a different build is refused with a version error.

## Install

1. Download the build for your system from the link the host sends you and unpack it.
2. **macOS:** the app is ad-hoc signed, not notarized. Right-click the app and choose Open. If macOS blocks it anyway (newer macOS versions may not offer Open on the first try), open System Settings → Privacy & Security and choose Open Anyway. Not verified on a current macOS yet.
3. **Windows:** SmartScreen warns about an unknown publisher. Choose More info → Run anyway.
4. **Linux:** `chmod +x` the binary and run it.

## Play

1. The launcher opens. The relay URL is prefilled; leave it unless the host says otherwise.
2. One player presses **Create match** and reads the 6-character code (`Match code: XXXXXX — waiting for player 2`) to the other.
3. The other player types the code and presses **Join**. The match starts at once. The creator is player 1 (blue), the joiner player 2 (red).
4. **Play offline** starts the normal single-player skirmish.

Controls are the same as offline. Restart is hidden online.

## Status lines

| Line | Meaning |
|---|---|
| `Waiting for player N` | Their input for the next tick has not arrived. The game resumes by itself. |
| `Player N disconnected` | The other player left or lost connection. The match stops. |
| `Connection to relay lost` | No data from the relay for 5 s, the socket closed, or the game could not send a frame. The match stops. When joining, a wrong code can also show this while the relay is flooded with bad codes; check the code and try again. |
| `Relay: <reason>` | The relay ended a running match with an error (for example `too far ahead`, listed below the table). Refusals at join time appear in the launcher's status line instead, in the relay's own words; a malformed frame at join time shows there as `Protocol error: <reason>`. |
| `Rejected: Too many orders at once; wait a moment` | A note, not an end: so many orders piled up in one tick that they would not fit one network packet, so every order past that point was dropped. Give them again a moment later. |
| `Desync — report saved to <path>` | The two games disagreed. The match stops and the report is written. |
| `Match stopped: game error. Please report it.` | The game hit an internal error or a malformed frame arrived. The match stops. The technical reason goes into the playtest helper's match record (`end`) and the game's log as `NETPLAY PROTOCOL END <reason>`: `logs/godot.log` in the user data directory on desktop, the browser console on the web. With the helper on, send the session file. |

The reasons the relay added with Relay guards (on `main`, not deployed yet; the game shows them in the relay's words, as `Relay: <reason>` during a match and without the prefix in the launcher's status line at join; the plain wording here is for the host to pass on). The first two per-address reasons only appear once the relay is set to count addresses, which the hosted relay is not yet:

- `too far ahead`: your game sent ahead of the others. That should not happen in normal play; please report it.
- `too many connections`: too many games from your network at once.
- `too many joins`: too many tries in a short time; wait a few seconds (one try comes back every second).
- `relay busy`: the relay is busy; try again shortly.

## Reports and latency

- Desync report: `desync-seat<N>.json` in the `desync` folder of the game's user data directory (the status line prints the full path). Send both players' files to the host.
- At the end of a match the game prints and saves command latency (p50/p95) and relay round-trip p95 to `netplay-latency.txt` in the same user data directory.
