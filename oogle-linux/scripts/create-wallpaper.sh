#!/bin/bash

# Oogle Linux Wallpaper Generator
# This script generates the default wallpaper for Oogle Linux

set -e

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is required but not installed."
    echo "Install it with: apt-get install imagemagick"
    exit 1
fi

# Output directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
WALLPAPER_DIR="${SCRIPT_DIR}/../config/wallpapers"
mkdir -p "${WALLPAPER_DIR}"

# Wallpaper settings
WIDTH=3840
HEIGHT=2160
OUTPUT="${WALLPAPER_DIR}/oogle-linux-default.png"
LOGO_OUTPUT="${WALLPAPER_DIR}/oogle-linux-logo.png"

# Define colors - cybersecurity theme with blue/purple gradients
BG_COLOR1="#0f1729"
BG_COLOR2="#1c1e40"
ACCENT_COLOR="#33ccff"
ACCENT_COLOR2="#8033ff"
TEXT_COLOR="#ffffff"

echo "Generating Oogle Linux wallpaper..."

# Create base gradient background
convert -size ${WIDTH}x${HEIGHT} gradient:"${BG_COLOR1}"-"${BG_COLOR2}" -gravity center "${OUTPUT}"

# Add some random "data stream" effects
for i in $(seq 1 20); do
    x=$((RANDOM % WIDTH))
    length=$((RANDOM % 500 + 100))
    opacity=$((RANDOM % 40 + 20))
    
    convert "${OUTPUT}" \
        -stroke "${ACCENT_COLOR}" -strokewidth 1 \
        -fill "none" -draw "line $x,0 $x,$length" \
        -channel A -evaluate multiply 0.$opacity +channel \
        "${OUTPUT}"
        
    x=$((RANDOM % WIDTH))
    y=$((RANDOM % HEIGHT))
    length=$((RANDOM % 500 + 100))
    opacity=$((RANDOM % 40 + 20))
    
    convert "${OUTPUT}" \
        -stroke "${ACCENT_COLOR2}" -strokewidth 1 \
        -fill "none" -draw "line $x,$y $((x+length)),$y" \
        -channel A -evaluate multiply 0.$opacity +channel \
        "${OUTPUT}"
done

# Add some hexagon grid patterns
for i in $(seq 1 30); do
    x=$((RANDOM % WIDTH))
    y=$((RANDOM % HEIGHT))
    size=$((RANDOM % 100 + 50))
    opacity=$((RANDOM % 30 + 10))
    color=$([ $((RANDOM % 2)) -eq 0 ] && echo "${ACCENT_COLOR}" || echo "${ACCENT_COLOR2}")
    
    convert "${OUTPUT}" \
        -stroke "${color}" -strokewidth 1 \
        -fill "none" -draw "polygon $((x-size/2)),$y $((x-size/4)),$((y+size*0.4)) $((x+size/4)),$((y+size*0.4)) $((x+size/2)),$y $((x+size/4)),$((y-size*0.4)) $((x-size/4)),$((y-size*0.4))" \
        -channel A -evaluate multiply 0.$opacity +channel \
        "${OUTPUT}"
done

# Add a centered circular glow
convert "${OUTPUT}" \
    \( -size $((WIDTH/3))x$((HEIGHT/3)) radial-gradient:"${ACCENT_COLOR}"-"${BG_COLOR1}" \
       -channel A -evaluate multiply 0.2 +channel \) \
    -gravity center -composite "${OUTPUT}"

# Create Oogle Linux logo
convert -size 800x800 xc:none -fill white \
    -draw "circle 400,400 400,200" -channel RGBA -transparent white "${LOGO_OUTPUT}"

# Add text and logo to the main wallpaper
convert "${OUTPUT}" \
    -gravity center \
    \( -size 1000x200 -background none -fill "${TEXT_COLOR}" \
       -font "DejaVu-Sans-Bold" -pointsize 120 -gravity center \
       label:"OOGLE LINUX" \) \
    -geometry +0+100 -composite \
    \( -size 800x100 -background none -fill "${ACCENT_COLOR}" \
       -font "DejaVu-Sans" -pointsize 48 -gravity center \
       label:"ARM64 SECURITY DISTRIBUTION" \) \
    -geometry +0+250 -composite \
    "${OUTPUT}"

echo "Wallpaper created at: ${OUTPUT}"

# Create smaller versions for login screens and thumbnails
convert "${OUTPUT}" -resize 1920x1080 "${WALLPAPER_DIR}/oogle-linux-1080p.png"
convert "${OUTPUT}" -resize 1366x768 "${WALLPAPER_DIR}/oogle-linux-laptop.png"
convert "${OUTPUT}" -resize 800x600 "${WALLPAPER_DIR}/oogle-linux-login.png"

echo "Additional wallpaper sizes created."
echo "All wallpapers are located in: ${WALLPAPER_DIR}"

exit 0 