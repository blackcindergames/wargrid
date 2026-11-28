# Milestone prompt

Reusable execution rules for implementing one milestone. A task's handoff (`<task>-prompt.txt`, private, location in `AGENTS.md`) names the milestone, its design, plan and verification file, its model choice and anything milestone-specific, then says "follow `docs/milestone-prompt.md`". Rules here do not override `AGENTS.md`; they fill in how a milestone run proceeds. Why these rules exist: [workflow retrospective](reference/2026-11-03-milestone-workflow-retrospective.md).

## Resume record

The milestone verification file (`docs/reference/mN-verification.md`) starts with this block. Overwrite it at every checkpoint; dated evidence rows below it stay append-only.

```text
Resume record (updated <date/time>)
Branch / base commit / working-tree state:
Last green task / next incomplete task:
Changed paths since last commit:
Last command / cases / checks / failures / exit / marker:
Known red case or blocker:
Approved decisions, pre-authorizations used, deferred gates:
Usage so far (python3 tools/session_usage.py <session files>):
Next exact action:
```

## Session start (coordinator steps 1–2; every task subagent steps 1–4)

1. Read `AGENTS.md`, then the resume record. Do not re-read finished tasks.
2. Run `git status --short` and `git log --oneline -3`; compare with the record. A mismatch is a blocker to report, not to repair silently.
3. Run the baseline once: `sh tools/run_tests.sh > <log> 2>&1`, then read only the summary lines. Skip it when the resume record shows a full-suite pass on this exact HEAD and `git status --short` is empty; say "baseline skipped, passed on <hash>" in the return (user, 2026-11-16). Lint, warnings and `sh tools/run_python_checks.sh` (ruff, mypy and the Python tests) may run at the same time; benchmarks always run alone.
4. Read only the active task: `rg -n '^#' <plan>` for headings, then that task's range, the interfaces it consumes, and decisions recorded since. The full design and plan are read once, at kickoff, in non-overlapping ranges.

## Unattended run

Fresh context per task keeps the token saving of the old restart rule (retrospective item 1) without a manual `/clear` (user, 2026-11-06). Start and coordinator rules: [night run](night-run.md#start) and [coordinator rules](night-run.md#coordinator-rules). Milestone-specific:

- **Stop gate.** Dispatch the gate reviewers ([How a package runs](../AGENTS.md#how-a-package-runs) step 3), record their findings, notify the user and end the session (a night run takes its backups instead). Playtest, visible windows, push, PR, merge and outline expansion wait for the user. A gate that ends at an owner look prepares a [War Room](../warroom/README.md) round for it, not a loose page.
- Push only as plain `git push`: the ask rule matches the command prefix, so `git -C … push` would bypass it.

## Pre-authorized actions

Granted by the user on 2026-11-03 for milestone runs:

- a local commit after each green checkpoint (short message, never push);
- dispatching the gate review subagent at each stop gate;
- closing any window or background process the run started.

Still require explicit approval: anything on `main`, PR, merge, visible game windows, design changes, relaxing any budget or assertion.

## Engineering lessons

- **Outcome tests.** Never recommend relaxing an assertion; one that fails on real behaviour is a defect until a measurement says otherwise. A tuned system (rates, timings, costs) gets an outcome test against the measured reference (e.g. credits per minute), not only an invariant (e.g. one collector per dock).
- **New entity states.** Each new state (contained, held, masked) is tested against all existing queries and commands (pick, target, validate, retaliate, salvage, bot), and the whole class is fixed at once (about eight findings came from the contained state).
- **Long sweeps.** Before a parity or benchmark sweep expected to take over 15 minutes, measure one row end to end and check for caps (frame cap, rate limits) first; the parity harness ran 157 minutes before a 27x speed-up was found. Benchmark runs before the gate follow the ledger's [while iterating](reference/performance.md#rule-per-milestone) rule: touched layouts only, one run, sequential A/B pairs.
- **Briefs state units.** A coordinator brief states units explicitly and checks them in the repo (e.g. 1 cell = 25 world units, [Zero Hour verification](reference/zero-hour-verification.md)) before it is sent.

## Stop conditions

Stop and ask when:

- a contract or phase order in the approved design would have to change;
- a budget is exceeded (a row the user already accepted as exceeded is recorded with its numbers, not re-asked; `run_benchmark.sh` then exits 1, so name the failing line);
- the pair gate fails or is inconclusive (`PAIR GATE FAILED` / `PAIR GATE INCONCLUSIVE`, `run_benchmark.sh` exits 1); a `CEILING ALARM` line alone is not a stop;
- a pinned outcome changes (winner, a match no longer ending inside its window) or the pair threshold or a stress ceiling would need a change: record old and new values and ask for sign-off;
- an assertion would have to be weakened;
- calibration cannot meet a gate within its permitted parameters;
- the resume record disagrees with the tree.

Never skip failures, widen tolerances or silence diagnostics.
