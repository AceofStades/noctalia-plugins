#!/bin/bash
set -euo pipefail
GX="$1"; GY="$2"; GW="$3"; GH="$4"
FILE="/tmp/screen-toolkit-lens.png"

for dep in grim curl jq xdg-open notify-send; do
    command -v "$dep" >/dev/null 2>&1 || { notify-send -u critical 'Screen Toolkit' "Missing: $dep"; exit 1; }
done

grim -g "${GX},${GY} ${GW}x${GH}" "$FILE" 2>/dev/null || { notify-send -u critical 'Screen Toolkit' 'Capture failed'; exit 1; }
notify-send 'Screen Toolkit' 'Uploading to Lens...'

RESP=$(curl -sS -f -A 'Mozilla/5.0' --connect-timeout 20 --max-time 60 \
  -F "files[]=@$FILE" 'https://uguu.se/upload' 2>/dev/null) || \
RESP=$(curl -sS -A 'Mozilla/5.0' --connect-timeout 20 --max-time 60 \
  -F "files[]=@$FILE" 'https://uguu.se/upload.php' 2>/dev/null)

rm -f "$FILE"
URL=$(printf '%s' "$RESP" | jq -r '.files[0].url // empty' 2>/dev/null)

if [ -n "$URL" ] && [[ "$URL" == http* ]]; then
    xdg-open "https://lens.google.com/uploadbyurl?url=$URL" >/dev/null 2>&1 &
else
    notify-send -u critical 'Screen Toolkit' 'Upload failed'
    exit 1
fi

