#!/bin/sh
# next-take.sh <counterfile> — bumps the counter and leaves the new
# number in it. First ever run starts at 01. Used by Rain-Over-Slaughterhouse14.csd
# (Csound reads the counter file back) so every live run logs to a
# fresh Rain-Over-Slaughterhouse14-takeNN-events.sco instead of overwriting one file.
f="$1"
n=0
if [ -f "$f" ]; then n=$(cat "$f" 2>/dev/null); fi
case "$n" in ''|*[!0-9]*) n=0;; esac
echo $((n + 1)) > "$f"
