# Wurstsalad

Generative hour-long Csound piece. A conductor instrument schedules
pitched stereo grains (`diskin2`) from `Media/Wurstsalad.wav`, each with
its own pitch wobble, random direction, and sine-modulated bounds, into a
global `reverbsc` bus.

Current version: `csd/Wurstsalad15.csd` (direction 75% forwards / 25%
backwards, Pulse/analog-out default; only REAPER touches the Scarlett).

## Layout

- `csd/` — numbered versions + recall templates (read-only history)
- `takes/` — take event logs (`.sco`, the actual performances), counters
- `scripts/` — `run-take.sh`, `from-min.sh`, `latest.sh`, `next-take.sh`
- `rpp/` — REAPER projects
- `Media/` — source audio (**not in git**, local only, 1.9 GB)

## Use

New take, live: `./scripts/run-take.sh`
New take to file: `./scripts/run-take.sh -o takes/Wurstsalad15-takeNN.wav -W -3 -d`
Replay a take: `./scripts/run-take.sh takes/Wurstsalad15-takeNN-events.sco [-o ...]`
Audition from minute M: `./scripts/from-min.sh takes/<take>.sco M [-o ...]`
Follow newest file: `./scripts/latest.sh`

## Recall

Takes are bit-identical: the event log plus the version's `.csd`
re-renders the take exactly (verified md5). See Muse notes for the full log.

Requires Csound 6.18, sox (`soxi`, `stats`).
