#!/usr/bin/env bash
# Resize source images in-place and generate WebP responsive variants.
# WebP sizes produced: 480w, 960w, 1440w, 1920w (skips sizes larger than source).
# Source files resized in-place to max 1920px / 500KB.
# Skips WebP variants that are already newer than their source.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAX_BYTES=$((500 * 1024))
MAX_DIM=1920
SIZES=(480 960 1440 1920)

src_resized=0
src_skipped=0
webp_generated=0
webp_skipped=0

while IFS= read -r -d '' file; do
    ext="${file##*.}"
    ext_lower="${ext,,}"

    case "$ext_lower" in
        jpg|jpeg|png|webp) ;;
        *) continue ;;
    esac

    basename_noext="${file%.*}"

    # Skip already-generated WebP variant files (end in -NNN.webp)
    if [[ "$ext_lower" == "webp" ]] && [[ "$basename_noext" =~ -[0-9]+$ ]]; then
        continue
    fi

    # --- Resize source in-place ---
    size=$(stat -c%s "$file")
    if (( size > MAX_BYTES )); then
        size_mb=$(awk "BEGIN { printf \"%.1f\", $size / 1048576 }")
        echo "Resizing source: $(basename "$file") (${size_mb}MB)"
        if [[ "$ext_lower" == "jpg" || "$ext_lower" == "jpeg" ]]; then
            convert "$file" -resize "${MAX_DIM}x${MAX_DIM}>" -define jpeg:extent=480kb "$file"
        else
            convert "$file" -resize "${MAX_DIM}x${MAX_DIM}>" -quality 85 "$file"
        fi
        src_resized=$((src_resized + 1))
    else
        src_skipped=$((src_skipped + 1))
    fi

    # --- Generate WebP variants ---
    orig_width=$(identify -format "%w" "$file" 2>/dev/null | head -1)
    if [[ -z "$orig_width" ]]; then
        echo "  WARN: can't read dimensions of $(basename "$file"), skipping WebP"
        continue
    fi

    dir="$(dirname "$file")"
    base="$(basename "${file%.*}")"

    for w in "${SIZES[@]}"; do
        # Don't upscale
        if (( orig_width < w )); then
            continue
        fi

        out="${dir}/${base}-${w}.webp"

        # Skip if up to date
        if [[ -f "$out" && "$out" -nt "$file" ]]; then
            webp_skipped=$((webp_skipped + 1))
            continue
        fi

        echo "  WebP ${w}w: $(basename "$out")"
        convert "$file" -resize "${w}x>" -quality 82 "$out"
        webp_generated=$((webp_generated + 1))
    done

done < <(find "$SCRIPT_DIR/Fotos" "$SCRIPT_DIR/Poster_Flyer_VA" \
    -maxdepth 1 \
    -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
    -print0)

echo ""
echo "Sources: $src_resized resized, $src_skipped already small."
echo "WebP variants: $webp_generated generated, $webp_skipped up to date."
