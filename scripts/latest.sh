#!/bin/sh
# latest.sh — show the most recently modified file, live.
# Usage: ./latest.sh [--edit] [dir]
#   Tracks everything except peaks (REAPER peak files churn constantly).
#   Text files print via bat; anything else (wav, etc.) shows ls + audio
#   info so growing renders are visible too. --edit opens each new text
#   file in nvim (quit nvim to resume following). Polls every second.
DIR="${2:-/mnt/bigdrive/CSOUND/Rain-Over-Slaughterhouse}"
EDIT=0
[ "$1" = "--edit" ] && EDIT=1
[ "$2" = "--edit" ] && EDIT=1
[ "$1" != "--edit" ] && [ -n "$1" ] && DIR="$1"
LAST=""
while true; do
  NEWEST=$(find "$DIR" -type f -not -path '*/peaks/*' -not -name '*.reapeaks' \
    -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1)
  if [ -n "$NEWEST" ] && [ "$NEWEST" != "$LAST" ]; then
    LAST="$NEWEST"
    F=$(echo "$NEWEST" | cut -d' ' -f2-)
    clear
    date +'--- %F %T ---'
    echo "latest: $F"
    echo
    if file "$F" | grep -qi text; then
      if [ "$EDIT" = 1 ]; then
        nvim "$F"
      else
        if command -v bat >/dev/null 2>&1; then bat --paging=never --style=plain "$F"; else cat "$F"; fi
      fi
    else
      ls -lh "$F"
      command -v soxi >/dev/null 2>&1 && soxi "$F"
    fi
  fi
  sleep 1
done
