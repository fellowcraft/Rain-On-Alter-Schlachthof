#!/bin/sh
# run-take.sh — Rain-Over-Slaughterhouse19 dual-mode runner.
#   Generate (live listen or render):  run-take.sh [-o out.wav] [-d ...]
#     Picks the next take number (take01, take02, ...) and runs the
#     conductor, logging every grain to Rain-Over-Slaughterhouse19-takeNN-events.sco.
#   Play back a take:                  run-take.sh takeNN-events.sco [-o out.wav]
#     Replays the logged grains through the same file (renders or listens).
D=/mnt/bigdrive/CSOUND/Rain-Over-Slaughterhouse
if [ $# -ge 1 ] && { [ -f "$1" ] || [ -f "$D/takes/$(basename "$1")" ]; }; then
  SCO="$1"; shift
  case "$SCO" in /*) ;; *) SCO="$PWD/$SCO";; esac
  if [ ! -f "$SCO" ]; then SCO="$D/takes/$(basename "$SCO")"; fi
  cp "$SCO" "$D/takes/Rain-Over-Slaughterhouse19-playback-events.sco"
  echo "Rain-Over-Slaughterhouse19 playing back $SCO"
  exec csound "$@" --omacro:PLAYBACK=1 "$D/csd/Rain-Over-Slaughterhouse19.csd"
fi
case "${1:-}" in ''|-*) ;; *) echo "run-take: take not found: $1 (tried takes/ by name)" >&2; exit 1;; esac
sh "$D/scripts/next-take.sh" "$D/takes/Rain-Over-Slaughterhouse19-take-counter.txt"
N=$(cat "$D/takes/Rain-Over-Slaughterhouse19-take-counter.txt")
: > "$D/takes/Rain-Over-Slaughterhouse19-playback-events.sco"
printf 'Rain-Over-Slaughterhouse19 take %s\n' "$N"
exec csound "$@" --omacro:TAKE="$N" "$D/csd/Rain-Over-Slaughterhouse19.csd"
