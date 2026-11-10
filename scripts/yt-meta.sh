#!/usr/bin/env bash
#
# yt-meta.sh -- build YouTube title + description from rothkamm_dbo.
#
# Usage: yt-meta.sh ALBUM_KEY [OUTDIR]
#
# ALBUM_KEY is matched against Album.Name (exact, else the single
# LIKE '%key%' hit). Writes <slug>-title.txt and
# <slug>-description.txt to OUTDIR (default: current directory),
# where <slug> is the Artist-Album hyphenated name from xcf-cover.sh.
#
# Layout follows the published Operla upload: numbered tracklist
# (opus line only when the PART row has one), catalog block, liner
# notes essay (linernotes/<AlbumID>.txt, HTML comments stripped),
# rothkamm.com album link. No bandcamp lines: Rain has no bandcamp
# release yet; append them to description.txt when it does.
#
# Needs: mariadb client (auth via ~/.my.cnf).

set -euo pipefail

LINERDIR="/home/frank/Projects/rothkamm/linernotes"

if [ $# -lt 1 ]; then
    echo "usage: $(basename "$0") ALBUM_KEY [OUTDIR]" >&2
    exit 1
fi

key="$1"
outdir="${2:-.}"
mkdir -p "$outdir"

esc="${key//\'/\'\'}"
row="$(mariadb -N rothkamm_dbo -e "SELECT CONCAT_WS(0x1f, AlbumID, IFNULL(Artist,''), IFNULL(Name,''), IFNULL(Composed,''), IFNULL(Label,''), IFNULL(CatalogNo,''), IFNULL(VisualArt,''), IFNULL(Released,''), IFNULL(Format,''), IFNULL(FileUnder,'')) FROM Album WHERE Name = '$esc';")"
if [ -z "$row" ]; then
    row="$(mariadb -N rothkamm_dbo -e "SELECT CONCAT_WS(0x1f, AlbumID, IFNULL(Artist,''), IFNULL(Name,''), IFNULL(Composed,''), IFNULL(Label,''), IFNULL(CatalogNo,''), IFNULL(VisualArt,''), IFNULL(Released,''), IFNULL(Format,''), IFNULL(FileUnder,'')) FROM Album WHERE Name LIKE '%$esc%';")"
fi
[ -n "$row" ] || { echo "error: no album matches '$key'" >&2; exit 1; }
n="$(printf '%s\n' "$row" | wc -l)"
if [ "$n" -gt 1 ]; then
    echo "error: '$key' matches $n albums, be more specific:" >&2
    printf '%s\n' "$row" >&2
    exit 1
fi

IFS=$'\x1f' read -r albumid artist name composed label catalog visualart released format fileunder <<< "$row"
aname_esc="${name//\'/\'\'}"
tracks="$(mariadb -N rothkamm_dbo -e "SELECT CONCAT_WS(0x1f, IFNULL(opus,''), IFNULL(Name,''), IFNULL(No,99999), length, IFNULL(year,''), IFNULL(city,'')) FROM PART WHERE album = '$aname_esc' ORDER BY No, ID;")"
[ -n "$tracks" ] || { echo "error: no PART rows for album '$name'" >&2; exit 1; }

total=0
while IFS=$'\x1f' read -r _opus _tname _no tlen _yr _city; do
    total=$((total + tlen))
done <<< "$tracks"

dur() { # secs -> H:MM:SS or M:SS
    local s=$1
    if [ "$s" -ge 3600 ]; then
        printf '%d:%02d:%02d' $((s/3600)) $(((s%3600)/60)) $((s%60))
    else
        printf '%d:%02d' $((s/60)) $((s%60))
    fi
}

slug="$(printf '%s %s' "$artist" "$name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]/-/g' -e 's#[\\/:*?"<>|]#-#g')"

title="$artist - $name ($composed) Full Album"
printf '%s\n' "$title" > "$outdir/$slug-title.txt"

{
    i=0
    cities=""
    instrs=""
    while IFS=$'\x1f' read -r opus tname _no tlen tyr tcity; do
        i=$((i+1))
        printf '[%d] %s\n' "$i" "$tname"
        [ -n "$opus" ] && printf 'opus %s\n' "$opus"
        printf '%s\n(%s)\n\n' "$(dur "$tlen")" "$tyr"
        case ",$cities," in *",$tcity,"*) ;; *) cities="${cities:+,}$tcity";; esac
    done <<< "$tracks"
    instrs="$(mariadb -N rothkamm_dbo -e "SELECT DISTINCT instruments FROM PART WHERE album = '$aname_esc' AND instruments <> '' ORDER BY ID;" | paste -sd', ')"
    printf 'Catalog No:  %s\n' "$catalog"
    printf 'Title:  %s\n' "$name"
    printf 'Sound Artist:  %s\n' "$artist"
    printf 'Visual Artist:  %s\n' "$visualart"
    printf 'Label:  %s\n' "$label"
    printf 'Length:  %s (%ss)\n' "$(dur "$total")" "$total"
    printf 'Composed:  %s\n' "$composed"
    [ -n "$cities" ] && printf 'Location:  %s\n' "$cities"
    [ -n "$instrs" ] && printf 'Instruments:  %s\n' "$instrs"
    if [ -n "$released" ] && [ "$released" != "0000-00-00 00:00:00" ]; then
        printf 'Release Date:  %s\n' "$(date -d "$released" '+%-m/%-d/%Y')"
    fi
    [ -n "$format" ] && printf 'Format:  %s\n' "$format"
    [ -n "$fileunder" ] && printf 'Tags:  %s\n' "$fileunder"
    printf '\n'
    if [ -f "$LINERDIR/$albumid.txt" ]; then
        sed '/<!--/,/-->/d' "$LINERDIR/$albumid.txt" | sed -e 's/[[:space:]]*$//'
        printf '\n'
    else
        echo "warning: no $LINERDIR/$albumid.txt" >&2
    fi
    printf 'http://rothkamm.com/?%s\n' "$(printf '%s' "$name" | sed 's/ /+/g')"
} > "$outdir/$slug-description.txt"

echo "wrote $outdir/$slug-title.txt + $outdir/$slug-description.txt"
