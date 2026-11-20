# Fun-first reorder (design, user, 2026-11-20)

Short design; approved by the user 2026-11-20 in a brainstorming session.

## Why

Wargrid is not fun to play yet with so many basics missing, and progress feels slow (user, 2026-11-20). The history agrees: from 2026-11-01 to 2026-11-10 M0 to M7 built the whole game; from 2026-11-11 to 2026-11-20 599 commits added 536 lines of simulation code (about 7,400 across game scripts, 13,500 in tests) against about 29,000 lines of Markdown docs, the night lane ran infrastructure only (performance, sim boundary, relay), and P2.3a1's plan is 159 KB on its branch. Two causes, about equal: the process cost per package and an order that puts later scale (3v3 online, browser threads, Steam Deck) ahead of play today.

## Goal

A 2v2 with a friend against bots, with a real HUD and one or two new units.

- **Non-goals:** P2.3a2, P2.3a3, P3, P5, P6, fog and the art packages in this run; they follow in their existing order.
- **Anti-goal:** a technical package pushing a player package back.

## Approaches

- **A, reorder only:** the order below with today's full process; about 3 to 4 weeks at P2.3a1's pace.
- **B, reorder and a lighter process (picked by the user):** the same order with the process exception below; the estimate of about half the calendar time is a guess, not a measurement.
- **C, P7 first:** a 2v2 on today's build menu, units next, P2.3b after; fastest to a friend match but without the real HUD, so dropped.

## Decisions (user, 2026-11-20)

1. **Day lane order:** P2.3a1 (finish) → P2.3b → P7 → P15 First new units → P2.3a2 → P2.3a3 → P3, then the rest unchanged. Pulling P3 ahead of P15 was offered and declined.
2. **P15 First new units:** one or two units that need little new simulation code, picked at P15's design. Candidates, checked against the code by the review: FRC Marauder is data only (salvage weapon tiers exist); USA Ambulance needs the tunnel's passenger heal generalised to a host's own passengers (no area heal, no hazard cleanup, so unarmed); China Troop Crawler is data only as an empty transport, arriving full needs a passenger spawn. None is stealth or artillery, so fog and the targetability predicate stay required for the rest of ground batch A only. It brings the kind-row cap (the first seventh selectable kind), a counter line and grid slot per new kind on P2.3b's card, and a shape per unit in today's look (P2.4 redraws it). Bots get armed picks only; an unarmed transport in their lists needs its own load rule and a spec-worded test. Any new unit in the bots' lists re-pins the bot traces. The picked units leave ground batch A.
3. **The roster rule is dropped:** "the roster stays at four units per faction until three recorded 1v1 matches are reviewed" (2026-11-11) no longer holds; balance is judged in playtests.
4. **Night lane stays.** Night 8 Play on after a leave runs before P7. SB5a, SB5b and SB6 are night lane only: never ahead of a day package and never needing a morning gate session; their Deck rows run over SSH without the owner, since the Deck is available for headless and windowed runs at any time.
5. **Day packages change what a player sees or plays;** technical work enters the day lane only when a measured problem blocks a player package.

## Lighter process for P2.3b, P7 and P15

- One short design-and-plan file per package instead of a spec plus a plan; aim for about a tenth of P2.3a1's 159 KB plan.
- No A/B lab rounds unless the look itself is the question.
- One owner check at the end (the visible-window checks in one batch, then the playtest) instead of stop gates A, B and C.
- Reviews: the per-task reviewer is the one reviewer per diff; the gate review (Grok and Opus, plus the player-experience reviewer for UI) runs once, at merge. The short design-and-plan file of P2.3b and P15 still gets a player-experience pass before the owner approves it (agent call, from the UI quality rule).
- Benchmark rows and CI unchanged.
- One release after P15; test-app deploys in between for friend sessions, each with approval.

## Director round (user, 2026-11-20)

The game director reviewed the order (kept) and the packages' contents; the owner picked:

6. **P7's bot work goes to the enemy bots,** after the owner's read of today's bot: "it plays ok, it just builds too few units too slowly and can be overwhelmed after a few minutes easily. It also doesn't deal well with base defenses in its way". The enemy bots build more units sooner, share one wave clock and one target, send waves that grow over the match and deal with base defences in their way. Offline team matches with an allied bot and the bot plan's S3 ally riders move to a Later item, Team up with a bot. No bot-rating evening first: the owner's read replaces it.
7. **Control groups, H, Space to the last attack and an "Allied base under attack" line ride on P2.3b;** the layout key labels and the defence range ring are deferred to pay for them. The minimap stays in P3.
8. **P15 is a heavy tank per faction:** China Overlord without add-ons, FRC Marauder, USA Paladin without its laser; the FRC Terrorist as a stretch. This replaces decision 2's candidate list; transports and artillery stay in ground batch A.

## Hand-offs the order changes

- P2.3b adds the Controls list to today's pause menu; P2.3a2's Esc menu rebuild carries it over.
- The LOW POWER wording rider moves from P2.3a2 to P2.3b, which builds the cost card first.
- P7 takes its rows of P2.3a2's wording table (version mismatch, team waiting text); F29 stays open and goes on P7's card as known.

## Left to each package

P2.3b, P7 and P15 keep their scope in [packages](../../packages.md#day-lane); each package's short design-and-plan file settles its details, P15 also its units.
