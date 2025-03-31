#!/bin/bash
# Oogle Linux Installation Script
set -e
# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi
echo "============================================"
echo "  Installing Oogle Linux Build Environment  "
echo "============================================"
# Install required dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y git debootstrap xorriso mksquashfs imagemagick wget build-essential
# Clone repository
echo "Cloning Oogle Linux repository..."
if [ -d "oogle-linux" ]; then
    echo "Oogle Linux directory already exists, updating..."
    cd oogle-linux
    git pull
else
    git clone https://github.com/yourusername/oogle-linux.git
    cd oogle-linux
fi
# Make scripts executable
chmod +x main.sh scripts/*.sh
# Run the main build script
echo "Starting Oogle Linux build process..."
./main.sh
echo "Installation and build process completed!"
