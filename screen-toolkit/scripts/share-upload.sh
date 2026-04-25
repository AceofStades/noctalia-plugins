#!/bin/bash
# share-upload.sh <file> [imgur_client_id]
# Prints URL to stdout on success, exits 1 on failure
# Used by: annotate (for now)

set -euo pipefail

FILE="${1:-}"
CLIENT_ID="${2:-}"

[ -n "$FILE" ] || { echo "ERROR: no file given" >&2; exit 1; }
[ -f "$FILE" ] || { echo "ERROR: file not found: $FILE" >&2; exit 1; }

for dep in curl jq; do
    command -v "$dep" >/dev/null 2>&1 || { echo "ERROR: missing dependency: $dep" >&2; exit 1; }
done

if [ -n "$CLIENT_ID" ]; then
    # ── Imgur anonymous upload ────────────────────────────────────────────────
    RESP=$(curl -sS -f \
        -H "Authorization: Client-ID ${CLIENT_ID}" \
        --connect-timeout 20 --max-time 60 \
        -F "image=@${FILE}" \
        'https://api.imgur.com/3/image' 2>/dev/null) \
        || { echo "ERROR: imgur request failed" >&2; exit 1; }

    URL=$(printf '%s' "$RESP" | jq -r '.data.link // empty' 2>/dev/null)
else
    # ── uguu.se (no account) ──────────────────────────────────
    RESP=$(curl -sS -f -A 'Mozilla/5.0' \
        --connect-timeout 20 --max-time 60 \
        -F "files[]=@${FILE}" \
        'https://uguu.se/upload' 2>/dev/null) \
    || RESP=$(curl -sS -A 'Mozilla/5.0' \
        --connect-timeout 20 --max-time 60 \
        -F "files[]=@${FILE}" \
        'https://uguu.se/upload.php' 2>/dev/null) \
    || { echo "ERROR: uguu request failed" >&2; exit 1; }

    URL=$(printf '%s' "$RESP" | jq -r '.files[0].url // empty' 2>/dev/null)
fi

if [ -n "$URL" ] && [[ "$URL" == http* ]]; then
    printf '%s\n' "$URL"
    exit 0
fi

echo "ERROR: no valid URL in response" >&2
exit 1
