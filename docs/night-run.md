# Night run

`/prepare-night-run` turns an evening into a ready unattended run: the work picked, every open choice settled, a handoff with one start line. `/start-night-run <handoff>` checks the machine and coordinates the run until morning. Design: [night run commands](superpowers/specs/2026-11-12-night-run-commands-design.md). One-time setup: `/config` "Push when actions required" on, so questions reach the phone.

## Prepare

Runs while the user is reachable, at the PC or on the phone.

0. Before picking work, run the previous-run check below (the same as Start step 2). Open items of an earlier run are raised first, so a new run never buries them.

1. Read the session notes (`~/projects/wargrid-private/docs/session-notes.md`: Next action, Deferred experiments and research) and [packages](packages.md). Offer two or three ranked candidates that suit unattended work (no playtest, no visible window, no push); the user picks.
2. Pick one or two small independent backup tasks (research, reruns, tooling) for when the main task ends or parks.
3. Ask in questionnaire rounds until no open choice is left: up to four short questions per round, each with a recommendation, readable on a phone; send a `PushNotification` before each round.
4. Refine the plan so a coordinator on any model can run it: exact paths, verify commands, stop conditions. The coordinator may run on Opus (user, 2026-11-18: the pump night's coordinator ran on Opus despite `/model sonnet`; accepted).
5. Dispatch a fresh Opus (high) readiness review of the plan: vague steps, missing paths, commands behind an `ask` rule. Apply its fixes.
6. Check permissions against `~/projects/wargrid-overnight-work/night-settings.json`. Every `ask` rule in `.claude/settings.json` and `~/.claude/settings.json` is denied at night; read them, the plan must not need any. Never edit the settings file; when the run needs a new allow rule or folder, write a proposed copy beside the run's work and give the user a `! cp` line. List `additionalDirectories` entries and run-specific allows whose path no longer exists, and drop them in that proposed copy.
7. Write the handoff to `~/projects/wargrid-private/docs/<task>-prompt.txt`: the task and its plan, the backups in order, pre-approved actions (including which local commits are pre-authorized), the run's ledger path (resume record, rulings, morning summary beside it), run-specific rules, and the start line:

   ```text
   claude --remote-control --settings ~/projects/wargrid-overnight-work/night-settings.json --permission-mode auto
   /start-night-run ~/projects/wargrid-private/docs/<task>-prompt.txt
   ```

8. Commit the repository changes this preparation made (local commit, pre-authorized, user 2026-11-12); never push.
9. End with the start line to paste.

## Start

Runs at the PC, in the session started with the handoff's start line, inside the run's own worktree. Never dispatch a writer from `claude agents` (agent view): its sessions branch from a fresh `origin/main` and are told to commit and push without asking; only background (`/bg`) a session already in its worktree and watch it there (user, 2026-11-16).

1. The argument is the handoff path. Missing or unreadable: say so and stop.
2. Previous-run check (user, 2026-11-15): every `morning-summary.md` under `~/projects/wargrid-overnight-work/*/` needs an Investigations entry in the session notes (add missing ones as open, see [kickoff](kickoff.md)), and none may be open. If any is open, list each with its morning items and stop; start only after the user has gone over them or says to start anyway, in which case record that in the ledger. Also list unresolved gates of Pending user action that name a branch, push or deploy the run could touch.
3. `ps -o args= -p $PPID` must contain `--remote-control` and `night-settings.json`. If either is missing, name it, print the handoff's start line and stop. A hybrid start (attended settings first) only when the handoff says so.
4. `pgrep -fl 'godot|generalszh'`: list processes of other sessions, never kill them. Tick-based work continues; stop only if the handoff runs benchmarks.
5. Keep the host awake: `caffeinate -ims -w $PPID` with `run_in_background` (system awake, display may sleep; other tools' assertions are harmless). Report the `pmset -g assertions` lines that keep the display on.
6. Post the Task / What / Status table, then coordinate under the rules below and the handoff.

## Coordinator rules

- **Coordinator** (the main session) reads only `AGENTS.md`, the handoff and the resume record. It never reads suite logs, diffs or plan task bodies.
- **One fresh subagent per task** (model per the plan's routing). Its brief names paths, not content: the resume record and the plan task heading. It runs session start steps 1–4 of the [milestone prompt](milestone-prompt.md), does the task test-first, runs lint and warnings, updates the resume record and verification rows, and returns at most ten lines: `GREEN` with counts, exit, marker and changed paths, or `BLOCKED` with the question, the options and its recommendation. It never commits.
- **After `GREEN`** the coordinator checks `git status --short` against the reported paths, makes the local commit if the handoff pre-authorizes it, and dispatches the next task.
- **Diagnose before asking.** Before asking a question that a default or a rule can decide, dispatch an Opus (high) agent to diagnose and recommend (G3.5: five phone questions in 30 minutes). Ask only for what stays a real choice, with the diagnosis and options.
- **Questions may go unanswered overnight** (user, 2026-11-12). `AskUserQuestion` blocks until answered, so a night run never calls it. Instead send a `PushNotification` with the question, the options and the choice taken, write it to the ledger, and keep working: a reversible choice takes the recommended option as `Ruling: <what> — <why> — <cost if wrong>`; an irreversible one parks the task and the run takes the next backup. A reply sent to the session overrides the ruling; continue a blocked subagent with `SendMessage` so its context is kept.
- **Stop conditions are never ruled on.** The [milestone prompt](milestone-prompt.md#stop-conditions) stop conditions (budget exceeded, assertion weakened, contract change, pinned outcome change) park the task for the user; the run takes the next backup.
- **Unblock once.** On any block (parked task, busy port, failed step), dispatch one fresh Opus (high) agent to diagnose and find a legitimate way around it before parking; once per block (user, 2026-11-19). On a stop condition it may only search the handoff and recorded decisions for an existing approval, never rule or loosen anything (user, 2026-11-20).
- **Backups.** When the main task ends, parks or reaches its stop gate, take the handoff's backups in order.
- **No leftovers.** A subagent stops every loop or watcher it started before it returns; after each task the coordinator checks `pgrep -fl 'godot|generalszh'` and closes what the run started with `TaskStop` on its own background task (no `kill` at night: the night settings deny it, user 2026-11-19), never another session's processes.
- **Long commands.** Every suite, benchmark, netplay, lint and parity call passes `timeout: 600000`; the benchmark gate takes about 7 min on a branch that touches `game/` (it adds a pair step), so run it alone. Anything longer runs in the background; wait only for the completion notification or a `Monitor` with an until-loop, never `sleep N; cat`.
- **Opus work stays on Opus.** Plan or outline expansion, diagnosis and gate reviews go to an Opus (high) subagent even when the coordinator runs on Sonnet.
- **Reviews and task size** (user, 2026-11-17, after night 7). Per-task reviews stay Opus (high), on attended days too; Codex and Grok review only at the gate, Codex only where the plan's gate line names it (user, 2026-11-19). The handoff splits a task known to be big into short subagents (docs, gate run and benchmark apart; a plan draft, then a separate pass that applies its review fixes): cost grows with requests times context. Briefs pass paths, never history. Research backups cover only the next one or two packages, on Opus. The gate on a relay, protocol, CI or test diff: Opus whole-branch, Grok normal (not fast) if available, else a second Opus pass, silent-failure-hunter and pr-test-analyzer; ponytail-review on Sonnet; the player-experience reviewer wherever its rule in `AGENTS.md` (Implementation) applies. Each gate reviewer gets the [gate review](milestone-prompt.md#gate-review) brief.
- **Compaction.** If the coordinator compacts, it writes the resume record and ends; the user starts it again. The record is the handoff; the conversation is not.

## Morning

The run ends with a final message and a morning summary file beside its ledger: results, every ruling with its cost, what waits for the user, and the run's processed-token total from `python3 tools/session_usage.py` on the coordinator and subagent session files, so workflow changes can be compared night to night (user, 2026-11-16). `/kickoff` asks the open choices as a questionnaire.
