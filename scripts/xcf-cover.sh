#!/usr/bin/env bash
#
# xcf-cover.sh -- make rothkamm.com cover jpgs from one GIMP .xcf file.
#
# Usage: xcf-cover.sh INPUT.xcf [OUTDIR]
#
# Takes the file name (without extension) of INPUT.xcf, finds the one
# album in the local rothkamm_dbo whose title matches it, and writes:
#   OUTDIR/big/<Artist>-<Album>.jpg    3000x3000, high quality
#   OUTDIR/small/<Artist>-<Album>.jpg  280x280, high quality
# big/ and small/ are created when missing. OUTDIR defaults to the
# folder that holds INPUT.xcf. Existing outputs are overwritten.
#
# Matching: an exact Album.Name match wins; otherwise the name must be
# the single LIKE '%name%' hit. Zero or several hits stop with a message.
# Every whitespace char in the output name becomes one hyphen, the same
# convention as pictures/albumcover (e.g. Frank-Genius-Killer-Disco.jpg).
#
# Needs: magick (ImageMagick 7), mariadb client (auth via ~/.my.cnf).

set -euo pipefail

QUALITY=92
BIG_PX=3000
SMALL_PX=280
# Local web mirror. Big covers go to $SITE_ROOT/pictures/albumcover/,
# small ones to $SITE_ROOT/pictures/albumcover/small/ (paths album.php
# reads: $cover_folder + $AlbumIcon). Override: SITE_ROOT=/path xcf-cover.sh ...
SITE_ROOT="${SITE_ROOT:-/mnt/bigdrive/ROTHKAMM}"

if [ $# -lt 1 ]; then
    echo "usage: $(basename "$0") INPUT.xcf [OUTDIR]" >&2
    exit 1
fi

in="$1"
case "$in" in
    *.xcf | *.XCF) ;;
    *) echo "error: input must be a .xcf file: $in" >&2; exit 1 ;;
esac
[ -f "$in" ] || { echo "error: no such file: $in" >&2; exit 1; }

outdir="${2:-$(dirname "$in")}"
mkdir -p "$outdir/big" "$outdir/small"

key="$(basename "$in")"
key="${key%.*}"
key="$(printf '%s' "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ -n "$key" ] || { echo "error: empty file name" >&2; exit 1; }

esc="${key//\'/\'\'}" # escape single quotes for SQL

row="$(mariadb -N rothkamm_dbo -e "SELECT Artist, Name FROM Album WHERE Name = '$esc';")"
if [ -z "$row" ]; then
    row="$(mariadb -N rothkamm_dbo -e "SELECT Artist, Name FROM Album WHERE Name LIKE '%$esc%';")"
fi
if [ -z "$row" ]; then
    echo "error: no album title matches '$key'" >&2
    exit 1
fi
n="$(printf '%s\n' "$row" | wc -l)"
if [ "$n" -gt 1 ]; then
    echo "error: '$key' matches $n albums, be more specific:" >&2
    printf '%s\n' "$row" >&2
    exit 1
fi

artist="${row%%$'\t'*}"
album="${row#*$'\t'}"
slug="$(printf '%s %s' "$artist" "$album" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]/-/g' -e 's#[\\/:*?"<>|]#-#g')"

render() { # $1 = edge px, $2 = dest
    # -reverse: ImageMagick reads XCF top-layer-first, flatten wants
    # bottom-first. -resize with ^ fills, -extent center-crops to square.
    magick "$in" -reverse -background white -flatten \
        -resize "$1x$1^" -gravity center -extent "$1x$1" \
        -quality "$QUALITY" "$2"
}

render "$BIG_PX" "$outdir/big/$slug.jpg"
render "$SMALL_PX" "$outdir/small/$slug.jpg"
echo "wrote $outdir/big/$slug.jpg + $outdir/small/$slug.jpg"

mkdir -p "$SITE_ROOT/pictures/albumcover/small"
cp "$outdir/big/$slug.jpg" "$SITE_ROOT/pictures/albumcover/$slug.jpg"
cp "$outdir/small/$slug.jpg" "$SITE_ROOT/pictures/albumcover/small/$slug.jpg"
echo "deployed $SITE_ROOT/pictures/albumcover/$slug.jpg + $SITE_ROOT/pictures/albumcover/small/$slug.jpg"
