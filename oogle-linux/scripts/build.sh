#!/bin/bash

set -e

# Load configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/../config/oogle-config.sh"

# Output directories
BUILD_DIR="${SCRIPT_DIR}/../build"
ISO_DIR="${SCRIPT_DIR}/../iso"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
PACKAGES_DIR="${SCRIPT_DIR}/../packages"

# Print banner
echo "================================================================"
echo "           Building ${DISTRO_NAME} v${VERSION} (${ARCHITECTURE})"
echo "================================================================"

# Create necessary directories
mkdir -p "${BUILD_DIR}" "${ISO_DIR}" "${ROOTFS_DIR}" "${PACKAGES_DIR}"

# Check for required tools
for cmd in debootstrap xorriso mksquashfs wget git; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is required but not installed."
        exit 1
    fi
done

# Step 1: Bootstrap base Debian system for ARM64
echo "[1/7] Bootstrapping base system..."
debootstrap --arch=${ARCHITECTURE} --variant=minbase bullseye "${ROOTFS_DIR}" http://deb.debian.org/debian/

# Step 2: Configure base system
echo "[2/7] Configuring base system..."
cat > "${ROOTFS_DIR}/etc/hostname" << EOF
${DEFAULT_HOSTNAME}
EOF

cat > "${ROOTFS_DIR}/etc/hosts" << EOF
127.0.0.1       localhost
127.0.1.1       ${DEFAULT_HOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

# Enter chroot to set up the system
cat > "${ROOTFS_DIR}/setup.sh" << 'EOF'
#!/bin/bash
set -e

# Update repositories
apt-get update

# Set up locale
apt-get install -y locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/default/locale

# Install essential packages
apt-get install -y --no-install-recommends \
    linux-image-arm64 \
    initramfs-tools \
    systemd \
    dbus \
    sudo \
    network-manager \
    dhcpcd5 \
    wireless-tools \
    firmware-linux \
    firmware-linux-nonfree \
    ca-certificates \
    curl \
    wget \
    git \
    zsh \
    neofetch \
    tar \
    unzip \
    zip \
    mlocate \
    vim \
    nano \
    htop

# Install display server (Wayland)
apt-get install -y --no-install-recommends \
    wayland \
    libwayland-client0 \
    libwayland-cursor0 \
    libwayland-egl1 \
    libwayland-server0 \
    xwayland

# Install fonts
apt-get install -y --no-install-recommends \
    fonts-dejavu \
    fonts-noto \
    fonts-noto-cjk \
    fonts-noto-color-emoji

# Install Hyprland dependencies
apt-get install -y --no-install-recommends \
    cmake \
    ninja-build \
    meson \
    libgbm-dev \
    libxcb-composite0-dev \
    libxcb-dri3-dev \
    libxcb-present-dev \
    libxcb-render-util0-dev \
    libxcb-res0-dev \
    libxcb-util-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libinput-dev \
    libdrm-dev \
    libgles2-mesa-dev \
    wayland-protocols

# Install Kitty terminal
apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    libfontconfig1 \
    libxkbcommon-x11-0 \
    libxcb-image0 \
    libxcb-xkb1 \
    libgl1

pip3 install kitty

# Install hacking tools
apt-get install -y --no-install-recommends \
    nmap \
    wireshark \
    aircrack-ng \
    john \
    hydra \
    sqlmap \
    hashcat \
    gobuster

# Set up metasploit (from source, for ARM64 compatibility)
git clone https://github.com/rapid7/metasploit-framework.git /opt/metasploit-framework
cd /opt/metasploit-framework
apt-get install -y --no-install-recommends \
    ruby \
    ruby-dev \
    libpq-dev \
    libpcap-dev \
    libsqlite3-dev
gem install bundler
bundle install

# Set up default user
useradd -m -s /bin/zsh -G sudo,netdev,audio,video oogle
echo "oogle:oogle" | chpasswd

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

chmod +x "${ROOTFS_DIR}/setup.sh"
chroot "${ROOTFS_DIR}" /setup.sh
rm "${ROOTFS_DIR}/setup.sh"

# Step 3: Install Hyprland (built from source for ARM64 compatibility)
echo "[3/7] Building and installing Hyprland..."
mkdir -p "${BUILD_DIR}/hyprland"
git clone --recursive https://github.com/hyprwm/Hyprland.git "${BUILD_DIR}/hyprland"
pushd "${BUILD_DIR}/hyprland"
sed -i 's/x86_64/aarch64/g' $(grep -l x86_64 $(find . -type f -name "*.cmake" -o -name "CMakeLists.txt"))
make release
make -j$(nproc) all
make DESTDIR="${ROOTFS_DIR}" install
popd

# Step 4: Configure Hyprland
echo "[4/7] Configuring Hyprland..."
mkdir -p "${ROOTFS_DIR}/etc/skel/.config/hypr"
cat > "${ROOTFS_DIR}/etc/skel/.config/hypr/hyprland.conf" << EOF
# Oogle Linux Hyprland Configuration

# Monitor Configuration
monitor=,preferred,auto,1

# Execute on startup
exec-once = waybar
exec-once = kitty

# Set environment variables
env = XCURSOR_SIZE,24

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0.5
    touchpad {
        natural_scroll = true
        tap-to-click = true
    }
}

# General window decoration
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Decoration
decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Window rules
windowrule = float, ^(kitty)$
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(nm-connection-editor)$

# Key bindings
$mainMod = SUPER

bind = $mainMod, RETURN, exec, kitty
bind = $mainMod, Q, killactive, 
bind = $mainMod SHIFT, M, exit, 
bind = $mainMod, E, exec, dolphin
bind = $mainMod, V, togglefloating, 
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, P, pseudo,
bind = $mainMod, F, fullscreen, 

# Move focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Move windows
bind = $mainMod SHIFT, left, movewindow, l
bind = $mainMod SHIFT, right, movewindow, r
bind = $mainMod SHIFT, up, movewindow, u
bind = $mainMod SHIFT, down, movewindow, d

# Switch workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
EOF

# Step 5: Configure Kitty terminal
echo "[5/7] Configuring Kitty terminal..."
mkdir -p "${ROOTFS_DIR}/etc/skel/.config/kitty"
cat > "${ROOTFS_DIR}/etc/skel/.config/kitty/kitty.conf" << EOF
# Oogle Linux Kitty Terminal Configuration

# Font
font_family      JetBrains Mono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        12.0

# Performance
repaint_delay    10
input_delay      3
sync_to_monitor  yes

# Terminal bell
enable_audio_bell no

# Window layout
window_padding_width 4
hide_window_decorations no
confirm_os_window_close 0

# Tab bar
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted

# Colors
foreground       #f8f8f2
background       #282a36
background_opacity 0.95

# Black
color0   #000000
color8   #4d4d4d

# Red
color1   #ff5555
color9   #ff6e67

# Green
color2   #50fa7b
color10  #5af78e

# Yellow
color3   #f1fa8c
color11  #f4f99d

# Blue
color4   #bd93f9
color12  #caa9fa

# Magenta
color5   #ff79c6
color13  #ff92d0

# Cyan
color6   #8be9fd
color14  #9aedfe

# White
color7   #bfbfbf
color15  #e6e6e6

# Cursor
cursor           #f8f8f2
cursor_shape     beam

# Mouse
mouse_hide_wait  3.0
url_color        #8be9fd
url_style        curly

# Shell integration
shell_integration enabled

# Open URLs
open_url_modifiers kitty_mod
open_url_with default

# Scrollback
scrollback_lines 10000

# Copy/paste
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
EOF

# Step 6: Set up default desktop
echo "[6/7] Setting up default desktop environment..."

# Setup display manager (SDDM with Wayland support)
chroot "${ROOTFS_DIR}" apt-get update
chroot "${ROOTFS_DIR}" apt-get install -y --no-install-recommends sddm

# Configure SDDM for Wayland/Hyprland
mkdir -p "${ROOTFS_DIR}/usr/share/wayland-sessions"
cat > "${ROOTFS_DIR}/usr/share/wayland-sessions/hyprland.desktop" << EOF
[Desktop Entry]
Name=Hyprland
Comment=A dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF

# Create system startup script
cat > "${ROOTFS_DIR}/etc/systemd/system/oogle-welcome.service" << EOF
[Unit]
Description=Oogle Linux Welcome Message
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/oogle-welcome.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat > "${ROOTFS_DIR}/usr/local/bin/oogle-welcome.sh" << EOF
#!/bin/bash
echo "
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                    Welcome to Oogle Linux                     ║
║                                                               ║
║  • Window Manager: Hyprland (Super + Return to open terminal) ║
║  • Default Terminal: Kitty                                    ║
║  • Default User: oogle / Password: oogle                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
"
EOF

chmod +x "${ROOTFS_DIR}/usr/local/bin/oogle-welcome.sh"
chroot "${ROOTFS_DIR}" systemctl enable oogle-welcome.service
chroot "${ROOTFS_DIR}" systemctl enable sddm

# Step 7: Create bootable ISO image
echo "[7/7] Creating bootable ISO image..."
pushd "${BUILD_DIR}"

# Create squashfs
mksquashfs "${ROOTFS_DIR}" "${BUILD_DIR}/filesystem.squashfs" -comp xz

# Set up bootloader for ARM64 (using GRUB)
mkdir -p "${BUILD_DIR}/iso/boot/grub"

cat > "${BUILD_DIR}/iso/boot/grub/grub.cfg" << EOF
set timeout=5
set default=0

menuentry "${DISTRO_NAME} ${VERSION}" {
    linux /boot/vmlinuz root=/dev/ram0 rw quiet splash
    initrd /boot/initrd.img
}

menuentry "${DISTRO_NAME} ${VERSION} (Recovery Mode)" {
    linux /boot/vmlinuz root=/dev/ram0 rw single
    initrd /boot/initrd.img
}
EOF

# Copy kernel and initrd
cp "${ROOTFS_DIR}/boot/vmlinuz-"* "${BUILD_DIR}/iso/boot/vmlinuz"
cp "${ROOTFS_DIR}/boot/initrd.img-"* "${BUILD_DIR}/iso/boot/initrd.img"

# Copy squashfs
mkdir -p "${BUILD_DIR}/iso/live"
cp "${BUILD_DIR}/filesystem.squashfs" "${BUILD_DIR}/iso/live/filesystem.squashfs"

# Create ISO
grub-mkrescue -o "${ISO_DIR}/oogle-linux-${VERSION}-${ARCHITECTURE}.iso" "${BUILD_DIR}/iso"

echo "================================================================"
echo "  Oogle Linux v${VERSION} (${ARCHITECTURE}) ISO created successfully!"
echo "  ISO location: ${ISO_DIR}/oogle-linux-${VERSION}-${ARCHITECTURE}.iso"
echo "================================================================"

# Clean up
rm -rf "${BUILD_DIR}"
popd

exit 0 