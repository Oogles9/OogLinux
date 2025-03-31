#!/bin/bash

# Oogle Linux Waybar Setup Script
# This script installs and configures Waybar for the Oogle Linux desktop environment

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_DIR="${SCRIPT_DIR}/../config"
DEST_DIR="/etc/skel/.config/waybar"

# ANSI color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}Setting up Waybar for Oogle Linux...${NC}"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Install Waybar and dependencies
echo -e "${CYAN}Installing Waybar and dependencies...${NC}"
apt-get update
apt-get install -y waybar playerctl glib-2.0-dev

# Install python dependencies for the media player script
pip3 install pygobject

# Create destination directory
mkdir -p "${DEST_DIR}"

# Copy configuration files
echo -e "${CYAN}Copying configuration files...${NC}"
cp "${CONFIG_DIR}/waybar/config" "${DEST_DIR}/"
cp "${CONFIG_DIR}/waybar/style.css" "${DEST_DIR}/"
cp "${CONFIG_DIR}/waybar/mediaplayer.py" "${DEST_DIR}/"
chmod +x "${DEST_DIR}/mediaplayer.py"

# Set up a logout menu using wlogout (referenced in waybar config)
echo -e "${CYAN}Setting up wlogout...${NC}"
apt-get install -y wlogout

# Create wlogout configuration directory
mkdir -p "/etc/skel/.config/wlogout"

# Create wlogout layout configuration
cat > "/etc/skel/.config/wlogout/layout" << EOF
{
    "label" : "lock",
    "action" : "swaylock",
    "text" : "Lock",
    "keybind" : "l"
}
{
    "label" : "hibernate",
    "action" : "systemctl hibernate",
    "text" : "Hibernate",
    "keybind" : "h"
}
{
    "label" : "logout",
    "action" : "hyprctl dispatch exit",
    "text" : "Logout",
    "keybind" : "e"
}
{
    "label" : "shutdown",
    "action" : "systemctl poweroff",
    "text" : "Shutdown",
    "keybind" : "s"
}
{
    "label" : "suspend",
    "action" : "systemctl suspend",
    "text" : "Suspend",
    "keybind" : "u"
}
{
    "label" : "reboot",
    "action" : "systemctl reboot",
    "text" : "Reboot",
    "keybind" : "r"
}
EOF

# Create wlogout style configuration
cat > "/etc/skel/.config/wlogout/style.css" << EOF
* {
    background-image: none;
    font-family: "JetBrains Mono Nerd Font";
}

window {
    background-color: rgba(15, 23, 41, 0.9);
}

button {
    color: #FFFFFF;
    background-color: #1c1e40;
    border-style: solid;
    border-width: 2px;
    border-color: #33ccff;
    border-radius: 10px;
    margin: 10px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 25%;
}

button:focus, button:active, button:hover {
    background-color: #8033ff;
    outline-style: none;
}

#lock {
    background-image: image(url("/usr/share/wlogout/icons/lock.png"), url("/usr/local/share/wlogout/icons/lock.png"));
}

#logout {
    background-image: image(url("/usr/share/wlogout/icons/logout.png"), url("/usr/local/share/wlogout/icons/logout.png"));
}

#suspend {
    background-image: image(url("/usr/share/wlogout/icons/suspend.png"), url("/usr/local/share/wlogout/icons/suspend.png"));
}

#hibernate {
    background-image: image(url("/usr/share/wlogout/icons/hibernate.png"), url("/usr/local/share/wlogout/icons/hibernate.png"));
}

#shutdown {
    background-image: image(url("/usr/share/wlogout/icons/shutdown.png"), url("/usr/local/share/wlogout/icons/shutdown.png"));
}

#reboot {
    background-image: image(url("/usr/share/wlogout/icons/reboot.png"), url("/usr/local/share/wlogout/icons/reboot.png"));
}
EOF

# Ensure Waybar autostarts with Hyprland by adding to the hyprland config
# This is already done in the main build.sh script, but we'll double check
if ! grep -q "exec-once = waybar" "/etc/skel/.config/hypr/hyprland.conf"; then
    echo "exec-once = waybar" >> "/etc/skel/.config/hypr/hyprland.conf"
fi

# Create scripts directory in user's home
mkdir -p "/etc/skel/.local/bin"

# Create a script to restart Waybar (useful for debugging)
cat > "/etc/skel/.local/bin/waybar-restart" << 'EOF'
#!/bin/bash
killall waybar
waybar > /tmp/waybar.log 2>&1 &
EOF
chmod +x "/etc/skel/.local/bin/waybar-restart"

echo -e "${GREEN}Waybar setup complete!${NC}"
echo -e "${CYAN}You may need to restart Hyprland for changes to take effect.${NC}"

exit 0 