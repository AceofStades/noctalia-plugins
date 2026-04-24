#!/bin/bash
# ocr.sh — capture a region and run OCR on it
# Args: $1=gx $2=gy $3=gw $4=gh $5=lang $6=upscale_flag $7=psm
#
# Improvements over v1:
#   - trap-based temp file cleanup (no leaks on early exit)
#   - auto-upscale small regions (< 200px wide) for better accuracy
#   - multi-pass PSM fallback chain: user PSM → 6 (block) → 4 (single col) → 11 (sparse)
#   - median-filter noise removal pass
#   - filters out 'osd' from lang string (breaks tesseract when passed as a lang)
#   - optional desktop notification on completion
#   - language availability check with graceful fallback to 'eng'

GX="$1"; GY="$2"; GW="$3"; GH="$4"
RAW_LANG="${5:-eng}"
UPSCALE="$6"
USER_PSM="${7:-3}"

FILE="/tmp/screen-toolkit-ocr.png"
TMP_BASE="/tmp/screen-toolkit-ocr-work-$$"
TMP="${TMP_BASE}.pnm"
TMP_NOISE="${TMP_BASE}-nr.pnm"

# ── Cleanup on any exit ──────────────────────────────────────────────────────
cleanup() { rm -f "$TMP" "$TMP_NOISE"; }
trap cleanup EXIT

# ── Validate geometry ────────────────────────────────────────────────────────
[ -z "$GX" ] || [ -z "$GY" ] || [ -z "$GW" ] || [ -z "$GH" ] && exit 1

# ── Filter 'osd' from lang string (breaks tesseract when used as a lang) ─────
# Inspired by OcrManager.cpp validateAndApplyLanguages()
LANG=$(echo "$RAW_LANG" | tr '+' '\n' \
    | grep -v '^osd$' \
    | grep -v '^$' \
    | tr '\n' '+' \
    | sed 's/+$//')
[ -z "$LANG" ] && LANG="eng"

# ── Validate language availability, fall back to eng ────────────────────────
AVAILABLE=$(tesseract --list-langs 2>/dev/null | tail -n +2)
VALID_LANGS=""
IFS='+' read -ra LANG_PARTS <<< "$LANG"
for l in "${LANG_PARTS[@]}"; do
    if echo "$AVAILABLE" | grep -qx "$l"; then
        VALID_LANGS="${VALID_LANGS}+${l}"
    else
        echo "ocr.sh: warning: language '$l' not available, skipping" >&2
    fi
done
LANG="${VALID_LANGS#+}"  # strip leading '+'
[ -z "$LANG" ] && LANG="eng"

# ── Capture ──────────────────────────────────────────────────────────────────
grim -g "${GX},${GY} ${GW}x${GH}" "$FILE" 2>/dev/null || exit 1

# ── Auto-upscale small regions (< 200px wide) ────────────────────────────────
# Small captures have too few pixels for Tesseract's LSTM to be reliable.
# Scale to at least 300px wide, which matches Tesseract's ~300dpi sweet-spot.
if [ -z "$UPSCALE" ] && [ "$GW" -lt 200 ] 2>/dev/null; then
    SCALE=$(awk "BEGIN{printf \"%.0f\", 300 / $GW}")
    UPSCALE="-scale ${SCALE}00%"
fi

# ── Preprocess ───────────────────────────────────────────────────────────────
magick "$FILE" $UPSCALE \
    -colorspace Gray \
    -normalize \
    -contrast-stretch 2%x1% \
    -sharpen 0x1.5 \
    +repage \
    "$TMP" 2>/dev/null || exit 1

# Auto-invert dark backgrounds (text-on-dark)
MEAN=$(magick "$TMP" -format '%[fx:mean]' info: 2>/dev/null)
if awk "BEGIN{exit !($MEAN < 0.4)}"; then
    magick "$TMP" -negate "$TMP" 2>/dev/null
fi

# Noise-reduced copy for fallback passes
magick "$TMP" -median 1 "$TMP_NOISE" 2>/dev/null

# ── Helper: run tesseract, return char-count of non-whitespace ───────────────
run_ocr() {
    local src="$1" psm="$2"
    tesseract "$src" stdout -l "$LANG" --psm "$psm" --oem 1 2>/dev/null
}

count_chars() {
    printf '%s' "$1" | tr -d '[:space:]' | wc -c
}

# ── PSM fallback chain ────────────────────────────────────────────────────────
# Inspired by OcrManager.cpp setupTesseractLanguages() fallback logic and
# OCR4Linux.py's use of PSM 6 for dense text blocks.
#
# Pass 1 – user-requested PSM on preprocessed image
TEXT=$(run_ocr "$TMP" "$USER_PSM")
BEST_LEN=$(count_chars "$TEXT")
BEST_TEXT="$TEXT"

# Pass 2 – PSM 6 (uniform text block) on noise-reduced image
if [ "$BEST_LEN" -lt 4 ] || [ "$USER_PSM" -ne 6 ]; then
    TEXT2=$(run_ocr "$TMP_NOISE" 6)
    LEN2=$(count_chars "$TEXT2")
    if [ "$LEN2" -gt "$BEST_LEN" ]; then
        BEST_LEN=$LEN2; BEST_TEXT="$TEXT2"
    fi
fi

# Pass 3 – PSM 4 (single column) on noise-reduced image
if [ "$BEST_LEN" -lt 4 ]; then
    TEXT3=$(run_ocr "$TMP_NOISE" 4)
    LEN3=$(count_chars "$TEXT3")
    if [ "$LEN3" -gt "$BEST_LEN" ]; then
        BEST_LEN=$LEN3; BEST_TEXT="$TEXT3"
    fi
fi

# Pass 4 – PSM 11 (sparse text) with aggressive threshold on original
if [ "$BEST_LEN" -lt 4 ]; then
    TEXT4=$(magick "$TMP" -threshold 85% stdout 2>/dev/null \
        | tesseract - stdout -l "$LANG" --psm 11 --oem 1 2>/dev/null)
    LEN4=$(count_chars "$TEXT4")
    [ "$LEN4" -gt "$BEST_LEN" ] && BEST_TEXT="$TEXT4"
fi

# ── Output ────────────────────────────────────────────────────────────────────
printf '%s' "$BEST_TEXT"

# ── Optional notification ─────────────────────────────────────────────────────
# Set OCR_NOTIFY=1 in your environment to enable.
if [ "${OCR_NOTIFY:-0}" = "1" ] && command -v notify-send &>/dev/null; then
    WORD_COUNT=$(printf '%s' "$BEST_TEXT" | wc -w)
    notify-send "OCR" "${WORD_COUNT} words extracted (lang: ${LANG})" \
        -i edit-find -t 2000
fi

# trap EXIT handles cleanup
