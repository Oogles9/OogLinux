#!/bin/bash

# Oogle Linux Installer
# This script installs Oogle Linux from the live environment to a permanent disk installation

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_step() {
    echo -e "${CYAN}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

clear
cat << "EOF"
 ____   ____   ____  _       _____   _       _____  _   _  _    _  _  _
/  _ \ / __ \ / ___\| |     | ____| | |     |_   _|| \ | || |  | || \| |
| | | || |  | || |  _| |     | |__   | |       | |  |  \| || |  | ||  ' |
| |_| || |__| || |_| | |___  | |___  | |___    | |  | |\  || |__| || .  |
\____/ \____/  \____|\____| |_____| |_____|   |_|  |_| \_|\____/ |_|\_|
                               
                    === ARM64 Linux Distribution ===
EOF

print_header "Oogle Linux Installer"
print_warning "This will install Oogle Linux to your disk and may erase existing data."
read -p "Do you want to continue? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_error "Installation aborted."
    exit 1
fi

# Detect available disks
print_step "Detecting available disks..."
disks=$(lsblk -dpno NAME,SIZE,MODEL | grep -v "loop\|sr" | sort)
if [ -z "$disks" ]; then
    print_error "No disks found!"
    exit 1
fi

# Display available disks
echo -e "\nAvailable disks:"
echo "$disks"
echo

# Ask for target disk
read -p "Enter the target disk (e.g., /dev/sda or /dev/nvme0n1): " target_disk
if [ ! -b "$target_disk" ]; then
    print_error "Invalid disk: $target_disk"
    exit 1
fi

# Confirm disk selection
echo
print_warning "WARNING: All data on $target_disk will be erased!"
read -p "Are you sure you want to continue? (y/n): " confirm_disk
if [[ "$confirm_disk" != "y" && "$confirm_disk" != "Y" ]]; then
    print_error "Installation aborted."
    exit 1
fi

# Collect user information
print_header "User Configuration"
read -p "Enter hostname [oogle]: " hostname
hostname=${hostname:-oogle}

read -p "Enter username [oogle]: " username
username=${username:-oogle}

read -sp "Enter password [oogle]: " password
echo
password=${password:-oogle}

read -sp "Confirm password: " password_confirm
echo
if [ "$password" != "$password_confirm" ]; then
    print_error "Passwords do not match!"
    exit 1
fi

# Ask for timezone
print_header "Timezone Configuration"
echo "Available timezones:"
timedatectl list-timezones | head -n 10
echo "..."
read -p "Enter timezone [Etc/UTC]: " timezone
timezone=${timezone:-Etc/UTC}

# Ask for locale
print_header "Locale Configuration"
read -p "Enter locale [en_US.UTF-8]: " locale
locale=${locale:-en_US.UTF-8}

# Start installation
print_header "Installing Oogle Linux"

# Partition disk
print_step "Partitioning disk..."
# Create GPT partition table
parted -s "$target_disk" mklabel gpt

# Create EFI partition (512MB)
parted -s "$target_disk" mkpart ESP fat32 1MiB 513MiB
parted -s "$target_disk" set 1 boot on
parted -s "$target_disk" set 1 esp on

# Create swap partition (2GB)
parted -s "$target_disk" mkpart swap linux-swap 513MiB 2561MiB

# Create root partition (rest of disk)
parted -s "$target_disk" mkpart root ext4 2561MiB 100%

# Sleep to ensure kernel recognizes new partitions
sleep 3

# Format partitions
print_step "Formatting partitions..."
# Detect partition prefix based on device name
if [[ "$target_disk" == *"nvme"* ]] || [[ "$target_disk" == *"mmcblk"* ]]; then
    part_prefix="${target_disk}p"
else
    part_prefix="${target_disk}"
fi

# Format EFI partition
mkfs.fat -F32 "${part_prefix}1"

# Format swap partition
mkswap "${part_prefix}2"
swapon "${part_prefix}2"

# Format root partition
mkfs.ext4 -F "${part_prefix}3"

# Mount partitions
print_step "Mounting partitions..."
mount "${part_prefix}3" /mnt
mkdir -p /mnt/boot/efi
mount "${part_prefix}1" /mnt/boot/efi

# Copy live system to target disk
print_step "Copying live system to target disk..."
# Extract squashfs to target disk
mount -o loop /run/live/medium/live/filesystem.squashfs /run/live/medium/squashfs
rsync -av /run/live/medium/squashfs/ /mnt/
umount /run/live/medium/squashfs

# Generate fstab
print_step "Generating fstab..."
mkdir -p /mnt/etc/fstab.d
UUID_ROOT=$(blkid -s UUID -o value "${part_prefix}3")
UUID_BOOT=$(blkid -s UUID -o value "${part_prefix}1")
UUID_SWAP=$(blkid -s UUID -o value "${part_prefix}2")

cat > /mnt/etc/fstab << EOF
# /etc/fstab: static file system information.
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
UUID=${UUID_ROOT}   /               ext4    errors=remount-ro 0       1
UUID=${UUID_BOOT}   /boot/efi       vfat    umask=0077      0       2
UUID=${UUID_SWAP}   none            swap    sw              0       0
EOF

# Prepare for chroot
print_step "Preparing chroot environment..."
for dir in /dev /proc /sys /run; do
    mount --bind $dir /mnt$dir
done

# Configure system in chroot
print_step "Configuring system..."
cat > /mnt/setup_chroot.sh << EOF
#!/bin/bash
set -e

# Update hostname
echo "$hostname" > /etc/hostname
sed -i "s/oogle/$hostname/g" /etc/hosts

# Configure timezone
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# Configure locale
echo "$locale UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$locale" > /etc/default/locale

# Update user if not default
if [ "$username" != "oogle" ]; then
    # Rename user
    usermod -l $username -d /home/$username -m oogle
    groupmod -n $username oogle
    # Update autologin
    sed -i "s/oogle/$username/g" /etc/systemd/system/getty@tty1.service.d/autologin.conf
fi

# Set password
echo "$username:$password" | chpasswd

# Configure boot loader
echo "Installing bootloader..."
apt-get update
apt-get install -y grub-efi-arm64 efibootmgr

# Install bootloader
grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=oogle --recheck
update-grub

# Enable networking
systemctl enable NetworkManager

# Clean up
apt-get clean
EOF

chmod +x /mnt/setup_chroot.sh
chroot /mnt /setup_chroot.sh
rm /mnt/setup_chroot.sh

# Unmount filesystems
print_step "Unmounting filesystems..."
for dir in /dev/pts /dev /proc /sys /run; do
    umount -lf /mnt$dir 2>/dev/null || true
done
umount -lf /mnt/boot/efi || true
umount -lf /mnt || true

print_header "Installation Complete"
print_success "Oogle Linux has been successfully installed on $target_disk."
print_success "You can now reboot your system and remove the installation media."
read -p "Reboot now? (y/n): " reboot_now

if [[ "$reboot_now" == "y" || "$reboot_now" == "Y" ]]; then
    print_warning "Rebooting in 5 seconds..."
    sleep 5
    reboot
fi

exit 0 