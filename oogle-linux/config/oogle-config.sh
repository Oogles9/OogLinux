#!/bin/bash

# Oogle Linux Configuration File

# Base Configuration
DISTRO_NAME="Oogle Linux"
VERSION="1.0"
ARCHITECTURE="arm64"
KERNEL_VERSION="6.6.9"  # Use a recent stable kernel

# Desktop Environment Configuration
WINDOW_MANAGER="hyprland"  # Hyprland for window management
TERMINAL="kitty"          # Kitty as default terminal
DEFAULT_SHELL="zsh"       # ZSH as default shell

# Package Selection
HACKING_TOOLS=(
  "nmap"          # Network scanner
  "wireshark"     # Packet analyzer
  "metasploit"    # Penetration testing framework
  "aircrack-ng"   # Wireless security assessment
  "john"          # Password cracker
  "hydra"         # Login cracker
  "sqlmap"        # SQL injection
  "burpsuite"     # Web vulnerability scanner
  "hashcat"       # Password recovery
  "gobuster"      # Directory/file enumeration
)

# ARM Optimization
ARM_SPECIFIC_PKGS=(
  "qemu-aarch64-static"
  "binfmt-support"
)

# Display Configuration
DISPLAY_SERVER="wayland"
DEFAULT_RESOLUTION="1920x1080"

# Aesthetics
THEME="dark"
ICON_THEME="papirus"
FONT="JetBrains Mono Nerd Font"

# Network Configuration
ENABLE_FIREWALL=true
DEFAULT_HOSTNAME="oogle"

# Build Options
COMPRESS_METHOD="xz"
TARGET_MEDIA="iso"  # ISO image for easy deployment 