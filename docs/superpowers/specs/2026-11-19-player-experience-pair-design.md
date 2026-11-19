# Player-experience pair: reviewer and director (design)

Approved (user, 2026-11-19). Short design; a small change to agent instructions, no game code.

## Intent

Two agents that push Wargrid toward a game players love, judged from three player seats against a sourced bar, instead of only "no defect found". The reviewer of 2026-11-16 was too cautious, weak on looks, and judged from neither a beginner's nor a seasoned player's view (user, 2026-11-19).

## Goals, non-goals, anti-goals

- **Goals:** a higher bar in every player-facing review; taste calls about looks; a director that proposes direction for the whole game on request; one place to tune the bar.
- **Non-goals:** a director pass on every package; mock-ups from the director; any change to the correctness reviewers; a reminder hook.
- **Anti-goals:** a longer or more generic persona; taste blocking a merge; proposals that reopen decided or scheduled work unlabelled; invented playtests, sources or approvals.

## Approaches

| Approach | Trade-off | |
|---|---|---|
| Two self-contained agent files | No extra read per run; the bar is duplicated and drifts | |
| Shared bar note plus two thin agents | One Read per run; one place to tune | **Picked (user, 2026-11-19)** |
| One file, two modes | Fewest files; a gate reviewer can run in the wrong mode | Dropped |

## Decided (user, 2026-11-19)

- **Pair:** the reviewer stays the gate; a second agent, the director, proposes direction.
- **Seats:** RTS newcomer (a friend with a link, first match, in a browser); RTS veteran (expects hotkeys, control groups, a fast camera); returning Zero Hour fan. Zero Hour key memory is not assumed for any seat.
- **Taste:** both agents say plainly how something looks, in a labelled section measured against the [art direction](../../art-direction/ART_DIRECTION.md); never blocking.
- **Director:** runs on request only; looks at the whole game (pacing, sound, bots, maps, feedback, UI, looks); returns three to five ranked proposals as text; does not edit files.
- **Routing (widened the same day):** the reviewer runs unasked wherever its `AGENTS.md` rule applies, in planned work, ultracode runs and ad-hoc edits, before work is reported done or shown; trivial diffs are exempt; no reminder hook unless a review is seen skipped. Delegation stays the session's decision: the agent documentation offers no mandatory form, only a description that encourages it. The director is called through a `/director` command.
- **Bar content:** distilled from a targeted research run (report `research/reports/Great RTS game factors.md`, private); unsourced factors are marked as hypotheses.

## Files

| File | Change |
|---|---|
| `docs/reference/player-experience-bar.md` | New. The three seats; the factor list (one line each, how to check it in a build, public source link or "hypothesis"); taste rules; pointers to art direction §11 and §12, [HUD v5 layout](../../reference/hud-v5-layout.md), blueprint Controls and the findings list. |
| `.claude/agents/player-experience-reviewer.md` | Rewritten, 252 lines to about 60. Name, verdict words and severity scale unchanged, so plans that name it still work. Reads the bar first. A method per input (picture, spec or plan, diff). Three seat ratings and the taste section. |
| `.claude/agents/game-director.md` | New, about 50 lines. Each proposal: benefit per seat, a sketch in words, cost, the playtest or A/B that would prove it, the bar factor it serves. |
| `AGENTS.md` | Reviewer rule sharpened (see Routing); one sentence: the director runs on request only and never starts a package. |
| `docs/night-run.md` | Gate set: the reviewer runs wherever the `AGENTS.md` rule applies. |
| `.claude/commands/director.md` | New. Dispatches the director and relays its answer in full. |

Both agents: Opus, effort high; "does not edit files"; read [packages](../../packages.md) and the design answers before proposing; a "(user, DATE)" decision may be challenged only when labelled as a challenge.

## Verification

- The old reviewer (file at `0bc9388`) and the new one run on the same past target; the owner compares the two outputs.
- One director trial on a real question.
- `sh tools/run_checks.sh` passes; a link check on the changed files (the checks do not cover links).

## Left to the builder

Exact wording of the three files; which past target the comparison uses; the ranking and cut of factors in the bar note.
