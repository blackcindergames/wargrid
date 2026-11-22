# P7 T1-8c: bot debug lines in F3

Short design (approved 2026-11-22 by the owner, one line per bot). Plan entry: T1-8c in [P7 part 1](../plans/2026-11-21-p7-enemy-bots.md).

**Why.** A window check showed infantry-only waves and nothing on screen said why. F3 should show what the bot is thinking: money, what it builds, what waits at home, when and why the next wave leaves, and where the last one went (user, 2026-11-21).

**Goals.** One line per bot in the F3 overlay, offline matches against bots only:

```text
Bot 2 usa | W1 in 89s | ready 7,875/6,372 | home 3i/8v | $475 | B:Rifleman F:- | ->Headquarters#2
```

Per bot: credits; each producer's current unit (`-` when idle); next wave number and seconds until it is due (`late N/60s` once past due: seconds since due over the wait cap); home infantry / vehicles (own army units in no wave); ready cost against the wave target `_form` compares (guards included); the team's last objective.

**Non-goals.** Online matches (the online driver never asks); a new panel or toggle key; lines for human seats; world-space drawing.

**Anti-goals.** Any change to the simulation's state, digest or bot memory from reading it; a cost while F3 is closed.

**Approaches.**
- Chosen: the pump thread builds the text. `Skirmish.debug_lines(sim, players)` reads bot memory read-only; `Job.want_bot_lines` asks for it, `Note.bot_lines` carries it; the offline driver asks only while F3 is open and hands the text to the overlay's existing `extra` line.
- Rejected: building the lines on the screen from the view. The view has no bot memory (wave timer, objective, waves), so it could not show the target or the due time.
- Rejected: copying bot memory into the view. Every frame would pay for it, F3 open or not, and the view is the sim interface's contract.

**Decided for you (reversible).** Producers in short form (the owner's compact preview left them out; the plan's field list has them). The target includes guards (the number the wave actually waits for). Lines refresh every 30 ticks. After the reviews the line has labels, the timer first and army producers only (evidence: `p7-verification.md` T1-8c). Tests: a sim test that `debug_lines` leaves the digest and bot memory unchanged and shows each field; a headless layout test that F3 with a bot line stays inside the screen.

**Left to the builder.** Short names for producers; how `debug_lines` reuses `_form`'s target scan without its side effects.
