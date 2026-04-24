#!/bin/bash
# annotate.sh
# Usage:
#   annotate.sh save  <base> <overlay> <dest>
#   annotate.sh copy  <base> <overlay>

MODE="$1"; BASE="$2"; OVERLAY="$3"

case "$MODE" in
  save)
    DEST="$4"
    mkdir -p "$(dirname "$DEST")" || exit 1
    magick "$BASE" "$OVERLAY" -composite "$DEST" 2>/dev/null && \
      rm -f "$OVERLAY" && echo "$DEST"
    ;;
  copy)
    OUT="/tmp/screen-toolkit-annotated.png"
    magick "$BASE" "$OVERLAY" -composite "$OUT" 2>/dev/null && \
      wl-copy < "$OUT" && rm -f "$OVERLAY" "$OUT"
    ;;
  *)
    echo "Usage: annotate.sh save|copy ..." >&2
    exit 1
    ;;
esac


