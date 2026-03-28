#!/usr/bin/env bash
#
# generate-wallpaper.sh — Create hecatOS branded wallpapers using ImageMagick
#
# Generates a 3840x2160 dark wallpaper with subtle torch/flame motif
# in the hecate orange/amber palette on a Tokyo Night background.
#
# Requirements: imagemagick
#
# Usage: bash scripts/generate-wallpaper.sh [output-dir]
#
set -euo pipefail

OUT_DIR="${1:-dotfiles/wallpapers}"
mkdir -p "$OUT_DIR"

if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
    echo "ImageMagick not found. Install with: nix-shell -p imagemagick"
    echo ""
    echo "Generating a solid dark wallpaper as fallback..."

    # Fallback: create a solid dark gradient with convert-less method
    # Use Python if available
    if command -v python3 &>/dev/null; then
        python3 << 'PYEOF'
import struct, zlib, os, sys

width, height = 3840, 2160
out_dir = sys.argv[1] if len(sys.argv) > 1 else "dotfiles/wallpapers"

# Tokyo Night Storm background with subtle radial gradient
# Center is slightly lighter (#1f2335), edges are darker (#0a0a12)
def make_pixel(x, y):
    cx, cy = width / 2, height / 2
    dx = (x - cx) / cx
    dy = (y - cy) / cy
    dist = min(1.0, (dx*dx + dy*dy) ** 0.5)

    # Background gradient: center #1a1b26 -> edges #0a0a12
    r = int(0x0a + (0x1a - 0x0a) * (1 - dist * 0.8))
    g = int(0x0a + (0x1b - 0x0a) * (1 - dist * 0.8))
    b = int(0x12 + (0x26 - 0x12) * (1 - dist * 0.8))

    # Subtle warm glow in upper center (torch flame hint)
    if dy < 0:
        glow_dist = ((dx * 1.5)**2 + (dy * 0.8 + 0.3)**2) ** 0.5
        if glow_dist < 0.6:
            glow = max(0, (0.6 - glow_dist) / 0.6) * 0.08
            r = min(255, int(r + 249 * glow))
            g = min(255, int(g + 115 * glow))
            b = min(255, int(b + 22 * glow * 0.3))

    return bytes([r, g, b])

# Write PPM (simple, no deps)
ppm_path = os.path.join(out_dir, "default.ppm")
png_path = os.path.join(out_dir, "default.png")

print(f"Generating {width}x{height} wallpaper...")
with open(ppm_path, 'wb') as f:
    f.write(f"P6\n{width} {height}\n255\n".encode())
    for y in range(height):
        if y % 200 == 0:
            print(f"  Row {y}/{height}...")
        row = b''
        for x in range(width):
            row += make_pixel(x, y)
        f.write(row)

print(f"Written to {ppm_path}")
print(f"Convert to PNG with: magick {ppm_path} {png_path}")
PYEOF
        exit 0
    fi

    echo "Neither ImageMagick nor Python3 available. Cannot generate wallpaper."
    exit 1
fi

# Use ImageMagick 7 (magick) or 6 (convert)
IM="magick"
command -v magick &>/dev/null || IM="convert"

echo "Generating hecatOS wallpapers..."

# ── Default: Dark gradient with subtle warm glow ────────────────────────
echo "  [1/3] default.png — dark gradient with warm glow"
$IM -size 3840x2160 \
    xc:'#0a0a12' \
    \( -size 3840x2160 radial-gradient:'#1a1b2600-#0a0a1200' \) -compose over -composite \
    \( -size 2400x1600 radial-gradient:'#f9731610-#f9731600' \
       -gravity north -geometry +0+0 -compose over \) -composite \
    \( -size 1200x800 radial-gradient:'#fbbf2408-#fbbf2400' \
       -gravity north -geometry +0+200 -compose over \) -composite \
    "$OUT_DIR/default.png"

# ── Minimal: Pure dark with slight vignette ─────────────────────────────
echo "  [2/3] minimal.png — pure dark with vignette"
$IM -size 3840x2160 \
    radial-gradient:'#1a1b26-#0a0a12' \
    "$OUT_DIR/minimal.png"

# ── Ember: More prominent warm gradient ─────────────────────────────────
echo "  [3/3] ember.png — warm amber accent"
$IM -size 3840x2160 \
    xc:'#0a0a12' \
    \( -size 3840x2160 radial-gradient:'#1a1b2680-#0a0a1200' \) -compose over -composite \
    \( -size 3000x2000 radial-gradient:'#f9731618-#f9731600' \
       -gravity center -geometry +0-400 -compose over \) -composite \
    \( -size 1600x1200 radial-gradient:'#fbbf2412-#fbbf2400' \
       -gravity center -geometry +0-300 -compose over \) -composite \
    "$OUT_DIR/ember.png"

echo ""
echo "Wallpapers generated in ${OUT_DIR}/"
ls -lh "$OUT_DIR"/*.png
