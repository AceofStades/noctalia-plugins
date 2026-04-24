#!/bin/bash
FILE="$1"
[ -z "$FILE" ] && exit 1

for dep in slurp grim magick; do
    command -v "$dep" >/dev/null 2>&1 || exit 1
done

COORDS=$(slurp -p 2>/dev/null) || exit 1
X=${COORDS%%,*}; REST=${COORDS#*,}; Y=${REST%% *}
GX=$((X > 5 ? X - 5 : 0)); GY=$((Y > 5 ? Y - 5 : 0))

grim -g "${GX},${GY} 11x11" "$FILE" 2>/dev/null || exit 1
magick "$FILE" -alpha off \
  -format '%[fx:int(255*u.p{5,5}.r)] %[fx:int(255*u.p{5,5}.g)] %[fx:int(255*u.p{5,5}.b)]' \
  info:- 2>/dev/null

