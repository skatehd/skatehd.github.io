#!/usr/bin/env bash
# Resize images in Fotos/ and Poster_Flyer_VA/ to a max of ~500KB
# Uses ImageMagick. Skips files already under 500KB.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAX_BYTES=$((500 * 1024))   # 500KB
MAX_DIM=1920                 # max width or height in pixels

total=0
resized=0
skipped=0

while IFS= read -r -d '' file; do
    ext="${file##*.}"
    ext_lower="${ext,,}"

    # Only process image files
    case "$ext_lower" in
        jpg|jpeg|png|webp) ;;
        *) continue ;;
    esac

    size=$(stat -c%s "$file")
    total=$((total + 1))

    if (( size <= MAX_BYTES )); then
        skipped=$((skipped + 1))
        continue
    fi

    size_mb=$(awk "BEGIN { printf \"%.1f\", $size / 1048576 }")
    echo "Resizing: $(basename "$file") (${size_mb}MB)"

    if [[ "$ext_lower" == "jpg" || "$ext_lower" == "jpeg" ]]; then
        # Resize dimensions first, then target file size via quality
        convert "$file" \
            -resize "${MAX_DIM}x${MAX_DIM}>" \
            -define jpeg:extent=480kb \
            "$file"
    else
        # PNG/WebP: resize dimensions and reduce quality
        convert "$file" \
            -resize "${MAX_DIM}x${MAX_DIM}>" \
            -quality 85 \
            "$file"
    fi

    new_size=$(stat -c%s "$file")
    new_size_kb=$(awk "BEGIN { printf \"%.0f\", $new_size / 1024 }")
    echo "  -> ${new_size_kb}KB"
    resized=$((resized + 1))

done < <(find "$SCRIPT_DIR/Fotos" "$SCRIPT_DIR/Poster_Flyer_VA" \
    -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
    -print0)

echo ""
echo "Done. $total images found, $resized resized, $skipped already under 500KB."
