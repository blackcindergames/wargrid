# P16 Know what your factory is making: verification

Branch `p16-know-what-your-factory-is-making`. Package row: [packages](../packages.md#day-lane). Answers: [queue follow-up round](design-answers-2026-11-08.md#queue-follow-up-round-user-2026-11-23); pictures: [queue round](../images/queue-round/README.md).

## One page (approved by the owner, 2026-11-23)

- **The player notices:** a selected factory's panel says what it makes and when: `NOW PRODUCING` with the unit's glyph, name, bar and seconds left (`5s`), `NEXT` with runs merged as `×N`, a read-only `+N more` list, `QUEUE n / 9`, one 198 px panel height in every state. Slow or stuck production explains itself on the NOW row: seconds in `warn` with `Low power` on hover, or `Exit blocked` instead of `0s`. An idle factory shows the dashed `Nothing in production` box with the rally line. Right-click on a build cell cancels the last of that kind, a left- or right-click on NOW cancels the unit in production (`×`, `Cancel · refunds 800` on hover), Shift queues and cancels five, and the cell card teaches the right-click.
- **Refuting observation:** after 30 s away the owner selects a factory with a mixed queue and cannot say within about 3 s what is made, roughly when, what is next and how many wait; or asks "why isn't it coming out", cancels by accident (a cancel, then the same kind queued within 2 s), or clicks NEXT expecting something. Existing data: the owner's 13 recorded sessions on the P2.3b queue tiles hold 609 produce and 5 cancel commands; 2 cancels were followed by a produce at the same factory within 60 ticks (the recorder has no kind on a cancel, so an upper bound). No data shows whether the panel reads in 3 s, so the match is the first evidence.
- **First playable slice:** the panel replacing the queue tiles; seconds left, `Low power`, `Exit blocked`; cancel on NOW and by kind, Shift ×5 both ways; the HUD skips cancels it already sent; the cell card line and `2 per order` for Militia; unit glyphs on the panel and the unit cells; an accidental-cancel count in the playtest session file; headless layout tests at 1280x720, 1280x800 and 1920x1080 for idle, one entry, 9/9, held, HQ, Militia, low power and exit blocked.
- **Later in P16:** the production strip right of POWER, after its blocking War Room round (built beside the slice).
- **Out:** multi-factory selection, AFTER NEXT order editing, building glyphs (P2.6), any simulation change.

## Decided for you

- Shift ×5 sends min(5, room, affordable) `produce` commands in one tick message; no new command.
- Shift-right-click follows the single right-click (newest five of the kind), so it can include the unit in production; the cell card then reads `Right-click: cancel the one in production`.
- Seconds left = ceil(remaining work / `work_rate` / 30), from the published view.
- `Exit blocked` when the head entry's work is complete and it is still queued.
- One glyph per body role (`Shapes.role`) shared by the factions, drawn from the round's `glyphs3.js`; the Rotary Gun Tank gets a multi-barrel cluster; a kind without a glyph shows its name only.
- The accidental-cancel count is kept by `orders.gd`, which sees produces from keys and clicks; it and a NEXT-click count go into the playtest session file's match entry.
- [HUD v5 layout](hud-v5-layout.md) top strip: low power also slows production (50-80 %, `economy_definitions.gd` `work_rate`), not only defences.
