#!/bin/bash
# SF Pro Font Extractor (macOS only)
# Copies SF Pro fonts from your Mac into assets/fonts/sf-pro/
# for inclusion in the SlozOS ISO build.
#
# SF Pro is Apple-proprietary — do not redistribute.
# Run this on your Mac before the Docker build:
#   bash scripts/get-sf-pro.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$SCRIPT_DIR/../assets/fonts/sf-pro"
mkdir -p "$DEST"

# Candidate font locations on macOS 14+ (Sonoma/Sequoia/Tahoe)
DIRS=(
    "/System/Library/Fonts"
    "/System/Library/PrivateFrameworks/FontServices.framework/Versions/A/Resources/Fonts"
    "/Library/Fonts"
    "$HOME/Library/Fonts"
)

FOUND=0
declare -a PATTERNS=("SF-Pro*.ttf" "SF-Pro*.otf" "SFNS*.ttf" "SFNS*.otf"
                     "SFPro*.ttf" "SFProDisplay*.otf" "SFProText*.otf"
                     "SFProRounded*.otf")

for dir in "${DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for pattern in "${PATTERNS[@]}"; do
        while IFS= read -r -d '' file; do
            echo "  Copying: $file"
            cp "$file" "$DEST/"
            ((FOUND++)) || true
        done < <(find "$dir" -maxdepth 2 -name "$pattern" -print0 2>/dev/null)
    done
done

if [[ $FOUND -eq 0 ]]; then
    echo ""
    echo "SF Pro not found on this system."
    echo "Options:"
    echo "  1. Download from https://developer.apple.com/fonts/"
    echo "     Place the .ttf/.otf files in: assets/fonts/sf-pro/"
    echo "  2. The build will use Inter instead (visually similar, open-source)."
    exit 1
fi

echo ""
echo "Copied $FOUND font files to $DEST"
echo "The build will prefer SF Pro over Inter when it finds these files."
