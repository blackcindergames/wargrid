# Player-experience bar

The shared bar that the [player-experience reviewer](../../.claude/agents/player-experience-reviewer.md) and the [game director](../../.claude/agents/game-director.md) read before they judge Wargrid. It names the three player seats, the factors that make players love an RTS (each with a check you can run in a playable build and a public source, or marked hypothesis), the rules for taste calls about looks, what the research could not establish, and where the project's own rules live. Tune the bar here, not in the agent files. Distilled from the research report `Great RTS game factors.md` (private).

## Seats

**Wargrid should feel familiar to someone who loves Generals, approachable to someone who has never played an RTS, and rewarding to someone who wants to master one.** It should get there through its own modern design, not by reproducing the past. The goal is not a compromise between nostalgia, accessibility and competitive depth, but a coherent, distinctive RTS that delivers the best of all three (user, 2026-11-19).

The three seats are the owner's working picture of the players (user, 2026-11-19), not player research; playtests correct them.

- **Newcomer**: an RTS newcomer, a friend who received a link and is playing their first match in a browser. Expects:
  - to understand the immediate goal and do something meaningful within the first minute, using only the mouse and without reading a manual;
  - sensible defaults and a frictionless start: no settings, shortcuts or unfamiliar concepts to learn before having fun;
  - an interface that makes available actions, costs, prerequisites and consequences discoverable, and clearly explains why something cannot be done;
  - to learn naturally through play, with optional guidance rather than mandatory tutorials or information overload;
  - to survive the opening and have a realistic chance of winning against the easiest bot, while understanding what went wrong when they lose;
  - to contribute meaningfully alongside experienced friends without being carried, overwhelmed or blamed;
  - to experience the excitement of commanding an army and making clever decisions before mastering the game's complexity.
- **Veteran**: an experienced RTS player, familiar with StarCraft II, Age of Empires or similar games. Expects:
  - familiar, efficient, customisable controls: comprehensive hotkeys, control groups, fast camera navigation, command queues and minimal unnecessary input;
  - responsive, predictable units that follow orders reliably, with explicit player commands taking precedence over automatic behaviour;
  - minimal busywork and unnecessary friction, without automating away meaningful decisions or opportunities for skill expression;
  - strategic depth through meaningful choices, counterplay, positioning, timing, scouting and adaptation rather than arbitrary complexity;
  - a high skill ceiling where better control, planning, creativity and decisions produce visible advantages;
  - to skip onboarding and play at their own pace without unnecessary animations, dialogs, tutorials or interface delays.
- **Fan**: a returning Zero Hour fan. Expects:
  - the game they remember without its faults: no stuck units, exploits or frustrating controls, and multiplayer that finishes the match without lag, disconnects or desyncs;
  - three factions with distinct identities, looks and sounds, asymmetric but fair: every strength comes with a real trade-off, and no option is better at everything;
  - punchy combat: weapons with impact, destruction worth watching within the art direction, memorable unit voices, distinctive weapon sounds;
  - freedom to improvise, harass, surprise opponents and discover creative strategies;
  - the familiar rhythm of accessible action, escalating tension and glorious chaos;
  - familiar strategic concepts and build orders, even if the exact controls and shortcuts are forgotten;
  - improvements and new ideas, provided they preserve or strengthen what made Generals special rather than merely replicate its mechanics.

No seat is assumed to remember Zero Hour's keys.

### Balancing the seats

The seats are complementary perspectives, not equal votes.

- **Fan protects identity**: the distinctive appeal of Generals, not its exact mechanics. Nostalgia does not justify keeping bad design.
- **Newcomer protects accessibility**: remove unnecessary barriers without giving up meaningful depth.
- **Veteran protects mastery**: reward agency, skill and strategic decisions, not repetitive execution.

When seats disagree:

- Prefer a solution that benefits several seats without compromising the game's identity.
- Tell meaningful complexity from unnecessary friction, and skill expression from busywork.
- Modernise or replace a legacy mechanic when its underlying purpose can be served better.
- Neither familiarity with Generals nor a modern convention makes a design better by itself.
- Weigh trade-offs by impact, severity and evidence, not by majority vote or fixed seat weights.
- When a conflict remains, say who benefits, who loses and which experience is affected, and recommend the direction that fits the principle above.

### Shared standards

Some expectations belong to every seat and are not balanced: reliable multiplayer and a consistent simulation; responsive controls and predictable units; clear, readable feedback and understandable rules; stability, reasonable performance and respect for the player's time. A failure here is a defect, not a preference, and one that stops players from finishing a match blocks a release.

## Factors

Ranked by strength of evidence and by fit to the target, three friends against three bots. A number marked hypothesis is a proposal to calibrate by playtest, not a sourced standard.

1. **Unit control feel and pathing**: every order is acknowledged at once by sound and marker, obeyed exactly, and groups never visibly jam.
   Check: order sound and marker start the moment the mouse button is released; 30 units pass a two-tile choke with none standing still (over 2 s, hypothesis).
   Source: [Zero-K lead developer, Cold Takes 10](https://zero-k.info/mediawiki/Cold_Takes/10_-_The_Smartest_Unit_in_Zero-K) "The fantasy of commanding an army can be shattered by a single unit wandering off in a weird direction". Seats: all (shared standard).
2. **Onboarding newcomers**: a first-time player selects, moves, attacks and builds through right-click and a build menu, and wins a first match against the easiest bot.
   Check: an RTS-naive tester with no coaching, mouse only, wins a first match against the easiest bot without changing any setting or toggle.
   Source: [Zero-K lead developer, Cold Takes 43](https://store.steampowered.com/news/app/334920/view/683005949807428679) "Most people stick with the defaults". Seats: newcomer.
3. **Bots as content**: bot difficulty tiers differ in behaviour, play by the player's rules, and cannot be beaten by one repeated trick.
   Check: testers play the easy, medium and hard bots blind, rank them in the intended order and name a different reason for each; no single strategy beats the hard bot every time.
   Source: [Blizzard, StarCraft II Co-op Missions](https://news.blizzard.com/en-us/starcraft2/19930660) "the AI will vary its strategy and use different tactics". Seats: newcomer, veteran, fan.
4. **Co-op and team play**: cooperating costs no more than any other action, and the weakest friend can contribute instead of being carried.
   Check: three humans of mixed skill against three bots; afterwards the weakest says they contributed, and nobody opened a sharing menu or argued over resources.
   Source: [Zero-K lead developer, Cold Takes 20](https://zero-k.info/mediawiki/Cold_Takes/20_-_Teamwork_By_Default) "cooperation within a team should be free of artificial limitations or hoops to jump through". Seats: newcomer.
5. **Pacing and match length**: the opening is short and busy, the first real decision and first fight come within minutes, and an early rush cannot end the match before the defender can scout.
   Check: note the time to the first non-economy decision and to the first fight; no stretch with nothing to do (over 10 s, hypothesis); decided matches do not drag on.
   Source: [Frost Giant studio, Stormgate 3v3 episode 1](https://playstormgate.com/news/inside-the-development-of-stormgate-3v3-episode-1) "We’re aiming for shorter game lengths to keep the experience exciting". Seats: newcomer, fan.
6. **Comebacks versus snowballing**: a losing team keeps a way back that the winner does not resent, and one collapsing teammate does not doom the team.
   Check: the team that loses the first big fight sometimes still wins; a friend knocked out early can rebuild or rejoin instead of watching.
   Source: [Frost Giant studio, Stormgate 3v3 episode 1](https://playstormgate.com/news/inside-the-development-of-stormgate-3v3-episode-1) "The inclusion of a comeback mechanic is also crucial". Seats: newcomer.
7. **Sync, stability and online trust**: all clients compute the same game, replays reproduce the match, and no input is lost to camera or menu state.
   Check: a long six-player match replays to the same final state; drag-panning the camera keeps the army selected; orders work with the pause menu open.
   Source: [Zero Hour community source project, issue 2750 title](https://github.com/TheSuperHackers/GeneralsGameCode/issues/2750) "Fix late game unit lockups and erroneous impassable terrain causes mismatch". Seats: all (shared standard).
8. **Finish before shipping**: show only what a stranger would call finished, in as few modes as possible; recent RTS games failed on unfinished scope and broken trust, not on mechanics.
   Check: a stranger shown each mode and screen of a shared build calls it finished, not a prototype.
   Source: [Stormgate CEO Tim Morten, as reported by PCGamesN, 2025-09-23](https://www.pcgamesn.com/stormgate/potential-recovery) "Recovering from a bad launch is extremely difficult". Seats: newcomer, veteran, fan.
9. **Skill ceiling and the automation line**: chores without decisions are automated, decisions stay with the player, and better control still wins.
   Check: every automated behaviour gives way to a direct order; a veteran beats a middling player clearly more often than not.
   Source: [Zero-K lead developer, Cold Takes 44](https://store.steampowered.com/news/app/334920/view/679630151248512264) "One thing automation cannot do is make choices on behalf of the player". Seats: veteran.
10. **Zero-friction joining**: a friend joins with a link and a name, no install and no account, and a refresh rejoins the same slot.
    Check: a friend on an unfamiliar laptop goes from link click to first unit order without installing anything (under about 60 s, hypothesis); a refresh mid-match rejoins the same slot.
    Source: [Jackbox CEO Mike Bilder, Nintendo Life (party games, not RTS)](https://www.nintendolife.com/features/time-to-laughter-is-like-zero-jackbox-games-ceo-on-quiplash-t-shirts-and-10-years-of-party-packs) "Time to laughter is like zero". Seats: newcomer.
11. **Faction identity and readable counters**: each faction wins through a different plan and is recognisable by look, sound and plan; players can predict which unit beats which.
    Check: after one match a newcomer states each faction's plan in one sentence; paused on an enemy army, testers pick a counter.
    Source: [Dustin Browder, StarCraft II design director, Game Informer](https://gameinformer.com/b/features/archive/2010/04/08/an-extensive-interview-with-starcraft-ii-design-director) "Zealots counter Stalkers unless the Stalkers kite, and if the Stalkers kite the Zealots will lose". Seats: fan, veteran.
12. **Sound and unit voices**: sound is a gameplay channel; each weapon class is identifiable by ear, voices carry faction identity, and response lines vary and stay sparse.
    Check: from audio-only combat clips testers name the firing unit class; in a 10-minute session the same response line does not keep repeating.
    Source: [Blizzard article, The Sounds of Koprulu](https://news.blizzard.com/en-gb/starcraft/20722027) "The distinct noise of Protoss photon cannons firing lets a player instantly understand what’s going on". Seats: fan.
13. **Maps**: 3v3 maps leave room for six players, keep camp-able high ground away from the centre, give fair starts, and come in enough numbers to avoid fatigue.
    Check: over many bot matches each start position wins about equally often; no high ground near the centre decides fights; testers do not tire of the maps after several evenings.
    Source: [Chris Fugate, senior systems designer at Frost Giant](https://playstormgate.com/news/inside-the-development-of-stormgate-3v3-episode-1) "we don’t start it near the middle of the map, as that’s too campy". Seats: veteran.
14. **Post-match and progression**: the end of a match feeds the next one through unlocks, a per-friend summary and a fast rematch. Little evidence shows this keeps players coming back; the source only shows a studio building it.
    Check: from the victory or defeat screen a rematch is a click or two away; testers ask for a rematch unprompted and can say what they unlocked.
    Source: [Blizzard article, StarCraft II 10th anniversary updates](https://news.blizzard.com/en-gb/article/23463124/starcraft-ii-10th-anniversary-game-updates) "replay the level 1–15 progression for each maxed-out commander up to three times". Seats: newcomer, veteran, fan.

Faction identity (11) and sound (12) rank low only because their published evidence is thin; they matter most to the returning Zero Hour fan.

## Taste

- Taste is a plain statement of how something looks: what reads well, what looks cheap, what clashes. Say it directly, without hedging.
- Measure looks against the [art direction](../art-direction/ART_DIRECTION.md), not personal preference; name the rule a look meets or misses.
- Label every taste item as taste, in its own section of the review. Taste never carries a severity and never moves the verdict.
- A look problem that harms reading the battlefield (units, owners, health, selection, threats or orders hard to tell apart) is a finding against a factor, not taste.

## Not established

No primary source was found for these. Reviewers must not fill the gaps with confident defaults.

- Mode popularity: no developer has published a share of players by mode.
- Target match lengths: no stated target exists for StarCraft II, Age of Empires IV, Company of Heroes, Tempest Rising or Beyond All Reason.
- Zero Hour developers' design intent: no reachable statement on faction asymmetry, general's powers, pacing, voice lines, superweapons or the command bar.
- Team play against bots: nothing on pings, leaver replacement, AI teammates, per-player difficulty or mixed-skill scaling, or on a weak teammate's collapse snowballing a team.
- Unit feel numbers: no values for turn rate, acceleration, attack wind-up or acceptable order latency.
- Sound design for Zero Hour, Company of Heroes or Age of Empires: no audio-director statement.
- Onboarding outcomes: no tutorial completion or churn data from any studio.
- Retention: no evidence for score screens, rematch flow or replays.
- Zero Hour player complaints about desync or superweapon stalemates: only tracker issues.
- Joining a browser RTS: no source.

The friends' own playtests are the primary source the published research cannot supply.

## Project pointers

- [Art direction §11, acceptance gates](../art-direction/ART_DIRECTION.md#11-acceptance-gates) and [§12, interface mock-ups](../art-direction/ART_DIRECTION.md#12-interface-mock-ups).
- [HUD v5 layout](hud-v5-layout.md).
- [Blueprint, Controls](../blueprint.md#controls-small-task-after-converted-maps-user-2026-11-08-not-designed).
- [Findings list](../STATUS.md#findings-list) in the status page.
- [Packages](../packages.md): scheduled work; a proposal touching a row there is a challenge.
- [Design answers](design-answers-2026-11-08.md): the owner's decisions.
