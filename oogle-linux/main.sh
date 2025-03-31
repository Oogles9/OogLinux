#!/bin/bash
# Oogle Linux Main Build Script
set -e
echo "Starting Oogle Linux build process..."
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
echo "1. Building base system..."
${SCRIPT_DIR}/scripts/build.sh
echo "2. Setting up Waybar..."
${SCRIPT_DIR}/scripts/setup-waybar.sh
echo "3. Installing security tools..."
${SCRIPT_DIR}/scripts/setup-security-tools.sh
echo "4. Creating wallpaper..."
${SCRIPT_DIR}/scripts/create-wallpaper.sh
echo "Build process complete! Your Oogle Linux ISO is ready."
echo "You can find it in the oogle-linux/iso directory."
