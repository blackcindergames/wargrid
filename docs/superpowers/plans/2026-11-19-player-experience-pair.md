# Player-experience pair: Implementation Plan

**Status:** executed 2026-11-19 (Tasks 1 to 4; owner approved the run and widened the routing the same day, Task 3 Step 2). Checks passed (`CHECKS PASSED 5`); the three trial outputs are private (`px-pair-trial-2026-11-19/`). Docs only: three instruction files and one sentence. Writing or approving this plan does not start implementation.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The player-experience reviewer becomes a thin gate that reads a shared bar and rates three player seats; a new game director proposes direction on request; both read one bar note.

**Architecture:** One tracked note, `docs/reference/player-experience-bar.md`, holds the seats, the ranked factors, the taste rules and the gaps. The two agent files link to it and carry only method and output shape. `AGENTS.md` gains one sentence.

**Tech Stack:** Markdown; Claude Code agent files (frontmatter plus body); `rg`, `wc`, `git`; `sh tools/run_checks.sh`.

**Spec:** [player-experience pair design](../specs/2026-11-19-player-experience-pair-design.md) (approved by the owner 2026-11-19).

## Global Constraints

- **No commit, push or `git add`.** Commits need the owner's approval; subagents never commit.
- **Don't touch:** game code, the correctness reviewers, `docs/images/` (another round has uncommitted pictures there), any file not named in a task.
- **Public repository** (AGENTS.md, last section): home-relative paths, no scratch paths, no personal detail. The research report is named only as `Great RTS game factors.md` (private); the bar note cites public URLs directly.
- **Research input:** `Great RTS game factors.md` (private; private notes repository, `docs/research/reports/`) and its notes in `docs/research/research_notes/Great RTS game factors/` beside it. Refer to it by path; it may still be in progress.
- **Evidence rule:** a quote enters a tracked file only after its URL was re-opened and the wording matched. Unconfirmed: drop the quote, or mark the factor "hypothesis". Never invent a playtest, a source or an approval.
- **Tags:** "(user, DATE)" only for real decisions; this plan's real ones are the spec's (user, 2026-11-19).
- **Link rather than duplicate:** the agent files link to the bar note, art direction, layout reference and packages; they do not copy their rules or values.
- **`<scratch>`** below means the session's scratch directory outside the repository; never write its real path into a tracked file.
- **Checks:** `sh tools/run_checks.sh` with `timeout: 600000`, output to a file, judged by exit code. It does not check links (verified 2026-11-19: its gates are lint, warnings, Python, shell, public); the link check below does.

Link check, used by every task (prints nothing when every relative link resolves):

```sh
sh -c 'for f in "$@"; do rg -o "\]\(([^)#]+)" -r "\$1" "$f" | rg -v "^https?:" | while read -r p; do [ -e "$(dirname "$f")/$p" ] || echo "BROKEN $f -> $p"; done; done' sh FILES
```

## Review Focus

1. **The agent skips the bar note.** Both bodies tell it to read the note first and cite factors by name; the trials (Task 4) show whether they do.
2. **Taste leaks into the verdict.** Taste stays in its labelled section; no taste item carries S0-S3 or moves the verdict.
3. **The director reopens decided or scheduled work unlabelled.** Every proposal touching a "(user, DATE)" decision or a row in `docs/packages.md` says "challenge" and names the decision.
4. **Unverified quotes in a tracked file.** Every quoted string in the bar note is on the re-check's confirmed list (Task 1 Step 3).
5. **A private path leaks.** No `wargrid-private`, `research_notes` or scratch path in tracked text; `sh tools/check_public.sh` passes.

---

### Task 1: Bar note

**Files:** Create `docs/reference/player-experience-bar.md` (at most about 120 lines).

**Interfaces:** Produces the headings the agents cite, exactly: `## Seats`, `## Factors`, `## Taste`, `## Not established`, `## Project pointers`, in that order.

- [ ] **Step 1: Precondition.** Open the report. If it is unfinished (no ranked factor list, or a "draft"/"in progress" marker), stop and ask the owner.
- [ ] **Step 2: Draft the factor list in `<scratch>/bar-draft.md`** (Opus high). Keep all 14 factors of the report in its ranking (the low-ranked ones, faction identity and sound, rank low on thin evidence and matter most to the Zero Hour fan; say so in one line). Each factor is three lines:
  ```markdown
  1. **Name**: what it is, one line.
     Check: how to check it in a build, one line.
     Source: [title](https://...) "short quote" | hypothesis. Seats: newcomer, veteran, fan.
  ```
- [ ] **Step 3: Quote re-check** (one Sonnet medium subagent, given `<scratch>/bar-draft.md`). It opens each URL and returns a table: quote, URL, confirmed yes/no, actual wording. Drop each unconfirmed quote or turn its factor into "hypothesis".
- [ ] **Step 4: Write the note.** `## Seats`: RTS newcomer (a friend with a link, first match, in a browser), RTS veteran (expects hotkeys, control groups, a fast camera), returning Zero Hour fan; one line that no seat is assumed to remember Zero Hour's keys. `## Factors`: the checked list. `## Taste`: plain statements about looks, measured against the art direction (link `../art-direction/ART_DIRECTION.md`), labelled taste, never blocking. `## Not established`: no primary source was found for mode-popularity figures, target match lengths, Zero Hour developers' design intent, team play against bots. `## Project pointers`: art direction §11 and §12, `docs/reference/hud-v5-layout.md`, blueprint Controls, the findings list in `docs/STATUS.md`, `docs/packages.md`, `docs/reference/design-answers-2026-11-08.md`. One line naming the source report as `Great RTS game factors.md` (private).
- [ ] **Step 5: Check.**
  - `wc -l docs/reference/player-experience-bar.md`: at most about 120.
  - `rg -n '^## ' docs/reference/player-experience-bar.md`: the five headings, in order.
  - `rg -n 'Source:' docs/reference/player-experience-bar.md | rg -v 'https://|hypothesis'`: prints nothing.
  - `rg -n 'wargrid-private|research_notes' docs/reference/player-experience-bar.md`: prints nothing; `rg -n 'Great RTS game factors' docs/reference/player-experience-bar.md`: one line, saying "private".
  - `rg -o '"[^"]+"' docs/reference/player-experience-bar.md`: every hit is on Step 3's confirmed list.
  - Link check on the file; `sh tools/check_public.sh`.

### Task 2: Reviewer rewrite

**Files:** Modify (rewrite) `.claude/agents/player-experience-reviewer.md`, 252 lines to about 60.

**Interfaces:** Consumes Task 1's headings. Keeps the name, verdict words and S/C labels, so plans that name the reviewer still work.

- [ ] **Step 1: Save the old file** for Task 4: `git show 0bc9388:.claude/agents/player-experience-reviewer.md > <scratch>/px-old.md` (identical to HEAD, verified 2026-11-19).
- [ ] **Step 2: Write the file** (Opus high). Frontmatter exactly:
  ```yaml
  ---
  name: player-experience-reviewer
  description: Wargrid player-experience reviewer. Judges specs, plans, mock-ups, screenshots and diffs touching UI, HUD, controls, art or player-facing text from three player seats (newcomer, RTS veteran, Zero Hour fan). Use proactively before such work is reported done, beside the correctness reviewer, and whenever the user asks for the player-experience reviewer, a player-experience review or a PX review. Does not edit files.
  tools: Read, Grep, Glob, Bash
  model: opus
  effort: high
  ---
  ```
  Body, in this order: read the bar note first; method per input (picture or mock-up: view at actual size first, cutting 1:1 crops into a copy outside the repository when the picture is larger than the tool shows it, then compare with the mock-up or the previous state, then the art direction's screenshot marks; spec or plan: walk each seat through the described journey; diff: trace intent, input, feedback, recovery); a rating per seat against "would this player love it", not "is there a defect"; findings as `[S# · C# · class]` with the old S0-S3, C1-C3 and class meanings compressed to one line each, the observed / inferred / hypothesis split and "not reproduced"; a labelled taste section, never blocking; before a premise challenge, check `docs/packages.md` and the design answers, and challenge a "(user, DATE)" decision only labelled as a challenge (spec, "Both agents"); the verdict words Ready / Ready with follow-ups / Changes required / Insufficient evidence.
  Cut: the Zero Hour versus grid key debate (an SC2-style command card was decided 2026-11-16), re-verifying engine and netcode each run, the generic source anchors, the reusable invocation block.
- [ ] **Step 3: Check.**
  - `wc -l .claude/agents/player-experience-reviewer.md`: about 60, at most 70.
  - `head -7 .claude/agents/player-experience-reviewer.md`: equals the block above, character for character.
  - `rg -n "Reusable invocation|grid mappings|Source anchors|Verify engine version|High-level multiplayer|Zero Hour bindings" .claude/agents/player-experience-reviewer.md`: prints nothing (exit 1).
  - `for p in player-experience-bar.md 'Ready with follow-ups' 'Changes required' 'Insufficient evidence' S0 S3 C1 C3 'not reproduced' hypothesis newcomer veteran 'Zero Hour fan' taste; do rg -qi -- "$p" .claude/agents/player-experience-reviewer.md || echo "MISSING $p"; done`: prints nothing.
  - Link check on the file; `sh tools/check_public.sh`.

### Task 3: Director and AGENTS.md

**Files:** Create `.claude/agents/game-director.md` (about 50 lines) and `.claude/commands/director.md` (about 10 lines). Modify `AGENTS.md:43` and the gate set in `docs/night-run.md` (Coordinator rules).

**Interfaces:** Consumes Task 1's headings.

- [ ] **Step 1: Write the director** (Opus high). Frontmatter exactly:
  ```yaml
  ---
  name: game-director
  description: Wargrid game director. Proposes direction for the whole game (pacing, feel, sound, bots, maps, onboarding, looks) as three to five ranked proposals. Use only when the user asks for the game director, the director's opinion, or what would make something great. Never starts a package. Does not edit files.
  tools: Read, Grep, Glob, Bash
  model: opus
  effort: high
  ---
  ```
  Body: read the bar note first; read `docs/packages.md` and the design answers so nothing decided or scheduled returns as a new idea; a "(user, DATE)" decision may be challenged only when labelled as a challenge; output three to five ranked proposals, each with benefit per seat, a sketch in words, cost, the playtest or A/B that would prove it, the bar factor it serves; a labelled taste note allowed; never invents a playtest, a source or an approval.
- [ ] **Step 2: Routing** (widened by the owner 2026-11-19, see the spec). `AGENTS.md` line 43: the reviewer also covers plans and mock-ups and runs unasked before work is reported done or shown, in planned work, ultracode runs and ad-hoc edits; typo, rename and comment-only diffs are exempt; a workflow stage that cannot call an agent by name gives a general agent the file to read and follow; the game director (link `.claude/agents/game-director.md`) runs on request only, usually through `/director`, and never starts a package (user, 2026-11-19). `docs/night-run.md` gate set: the reviewer runs wherever that rule applies, not only "when UI is touched". `.claude/commands/director.md`: dispatch the director with the request word for word, relay its answer in full, start none of its proposals.
- [ ] **Step 3: Check.**
  - `wc -l .claude/agents/game-director.md`: about 50, at most 60; `head -7` equals the block above.
  - `for p in player-experience-bar.md packages.md design-answers-2026-11-08.md challenge 'three to five' playtest 'Does not edit'; do rg -qi -- "$p" .claude/agents/game-director.md || echo "MISSING $p"; done`: prints nothing.
  - `git diff --numstat AGENTS.md docs/night-run.md`: `1 1` for each; `rg -c 'user, 2026-11-16' AGENTS.md` unchanged from `main` (the 2026-11-16 tag stays on the reviewer rule).
  - Link check on both files; `sh tools/check_public.sh`.
- [ ] **Step 4: Lean pass.** One `/ponytail-review` on the diff (the three files plus `AGENTS.md`), before the trials so they test what ships. Apply cuts; rerun the Task 1 to 3 checks.

### Task 4: Verification

**Files:** none tracked. Outputs go to `<scratch>`.

**Target** (picked 2026-11-19): the HUD v5 Core mock-ups, which the old reviewer reviewed on 2026-11-16 ([design answers](../../reference/design-answers-2026-11-08.md#hud-m76)), against HUD v4 Core as the previous state. Taken from commit `75898c8`, so in-flight picture work cannot change them:

```sh
mkdir -p <scratch>/target
for s in none factory build blocked; do git show 75898c8:docs/images/hud-v5/core-$s.webp > <scratch>/target/v5-core-$s.webp; done
for s in factory place; do git show 75898c8:docs/images/hud-v4/core-$s.webp > <scratch>/target/v4-core-$s.webp; done
```

- [ ] **Step 1: Old versus new reviewer**, in parallel, both general-purpose agents, Opus, effort high (agent types load at session start, so the new file may not be callable by name). Each gets: "Read `<file>` and follow it as your instructions." with `<file>` = `<scratch>/px-old.md` or `.claude/agents/player-experience-reviewer.md`, then the same task: "Review the HUD v5 Core mock-ups for packages P2.3a and P2.3b: nothing selected, factory with a queue and credits short, build menu with a prerequisite missing, placement refused (`<scratch>/target/v5-core-*.webp`). Previous state: HUD v4 Core factory and placing (`<scratch>/target/v4-core-*.webp`). Context: `docs/images/hud-v5/notes.md`, `docs/reference/hud-v5-layout.md`. Return the review as text; do not edit files." Save the outputs as `<scratch>/review-old.md` and `<scratch>/review-new.md`.
- [ ] **Step 2: Director trial**, general-purpose agent, Opus, effort high: "Read `.claude/agents/game-director.md` and follow it as your instructions. Question: What would make the first five minutes of a newcomer's first match great? Do not edit files." Save as `<scratch>/director.md`.
- [ ] **Step 3: Checks.** `sh tools/run_checks.sh > <scratch>/checks.log 2>&1; echo "exit=$?"` (timeout 600000): exit 0 and `CHECKS PASSED 5`. On failure: `rg -n -A15 'FAIL|---' <scratch>/checks.log`. Link check on all four changed files.
- [ ] **Step 4: Owner comparison.** Hand the owner the three output paths. Check with them, per Review Focus: does the new review cite the bar, rate each seat, keep taste out of the verdict, and drop the key debate; does the director label any challenge. The plan's execution stops here until the owner answers.
- [ ] **Step 5: After the owner accepts,** hand over the calling phrases: "ask the player-experience reviewer to review ...", "get the game director's opinion on ...", and note that both are callable by name from the next session on.

## Model routing

| Work | Model | Effort |
|---|---|---|
| Tasks 1-3 writing (bar note, reviewer, director, AGENTS.md sentence) | Opus | high |
| Task 1 Step 3 quote re-check | Sonnet | medium |
| Task 4 trial agents (old reviewer, new reviewer, director) | Opus | high |
| Checks and link check | main session | n/a |
| Task 3 Step 4 lean pass | `/ponytail-review` | n/a |

No separate reviewer per task: the old-versus-new comparison is the review.
