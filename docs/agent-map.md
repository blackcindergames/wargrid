# Agent map

What to read before changing an area, and that area's own rules. Moved out of [`AGENTS.md`](../AGENTS.md) so every session loads less; `AGENTS.md` rules still apply here too.

## Map selection and online start

Read the converted maps handoff (`converted-maps-prompt.txt`, private; its "Decided" section), [plan](superpowers/plans/2026-11-08-converted-maps-playable.md), [verification file](reference/converted-maps-verification.md), [more maps](reference/more-maps.md) and the relay entry below.

## Maps (`tools/zh_map/`, `game/data/maps/`)

Read [more maps](reference/more-maps.md); for supply sources also the [small piles design](superpowers/specs/2026-11-08-small-supply-piles-design.md).

## Art (M7.5, any drawing in `game/scripts/presentation/`)

Read blueprint §2, the [art direction](art-direction/ART_DIRECTION.md) and the [integration note](reference/art-godot-integration.md). Before any launcher, HUD or menu mock-up, read its [§12](art-direction/ART_DIRECTION.md#12-interface-mock-ups): the game's font, pictures at 2x, the source beside the pictures, every state (the HUD v5 round missed it at first, 2026-11-16). The 13 interview answers are a starting point, not frozen (user, 2026-11-09). Interview images, GPT's QA images, validation and handoff notes live in `~/projects/wargrid-art-archive/`: read-only reference, never copy it into the repo.

## Sound

Covers `game/scripts/presentation/sound_*.gd`, `announcer.gd`, `music_player.gd`, `audio_settings.gd`, `volume_sliders.gd`, `game/audio/` and `tools/audio/`. Read the sound spike [design](superpowers/specs/2026-11-08-sound-spike-design.md), [evidence note](reference/sound-spike.md) and [plan](superpowers/plans/2026-11-08-sound-spike.md); handoff `sound-spike-prompt.txt` (private); resume record [sound spike verification](reference/sound-spike-verification.md). Sound is presentation only: no simulation or trace change.

## Performance

Read [performance next](reference/performance-next.md) and the user's answers in [design answers](reference/design-answers-2026-11-08.md#performance-next-user-2026-11-11) (user, 2026-11-11), including "After performance next" for the order of work. Goal row: a 210-unit 3v3; hordes300 is a stress row. Measuring host: the Mac mini, no Steam Deck for now. Follow-up on the post-M7 spike: read the [performance ledger](reference/performance.md) and the [2026-11-05 spike](reference/performance-spike.md) fully.

## Unit avoidance (P5, P6)

Read the spike evidence (tag `archive/spike-avoidance`, `docs/reference/unit-avoidance-spike.md` there) and the user's answers in [design answers](reference/design-answers-2026-11-08.md#unit-avoidance-scope) (user, 2026-11-08).

## GDScript checks (`tools/run_lint.sh`, `tools/run_warnings.sh`)

Read the static checks [plan](superpowers/plans/2026-11-05-gdscript-static-checks.md); Task 3 was skipped by the user.

## Release workflow (`.github/workflows/release.yml`, release tools, fly deploys from CI)

Read the release workflow [plan](superpowers/plans/2026-11-06-release-workflow.md) and the [release verification](reference/release-verification.md).

## Relay and protocol (`relay/`, `protocol/`)

Read the [relay stack spike](reference/relay-stack-spike.md) and [relay scaling](reference/relay-scaling.md). `protocol/vectors` and the black-box suite in `protocol/conformance` fix the wire protocol. A relay change passes `go test -race ./...` and `golangci-lint run` in `relay/`, `sh tools/run_conformance.sh`, and the affected `tools/run_netplay.sh` scenarios.

## War Room (`warroom/`)

Read [warroom/AGENTS.md](../warroom/AGENTS.md); its gate is `sh warroom/tools/quality.sh`. A round is YAML in `warroom/rounds/`; picks are read back from `warroom/picks.json` (local) or `/picks.json` with the admin token; the old per-round A/B pages are history. "A/B" is only a name: a step offers as many options as the question needs, A to H (user, 2026-11-20).
