#!/bin/bash

# ===== CONFIGURATION =====
TARGET_DISK="/dev/sda"       # Using /dev/sda instead of nvme
HOSTNAME="archdolphin"
USERNAME="dolphin"
USER_PASSWORD="1234"         # CHANGE THIS
ROOT_PASSWORD="1234"         # CHANGE THIS
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
KEYMAP="us"

# Partition sizes
ROOT_SIZE="55GiB"   # ext4 root partition
SWAP_SIZE="4GiB"    # swap partition
EFI_SIZE="1022MiB"  # EFI system partition

# ===== COLORS =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ===== SAFETY CHECK =====
echo -e "${YELLOW}WARNING: THIS WILL ERASE ALL DATA ON ${TARGET_DISK}!${NC}"
lsblk
read -p "Continue installation? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation cancelled.${NC}"
    exit 1
fi

# ===== HELPER FUNCTIONS =====
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ===== PHASE 1: PARTITIONING =====
info "Partitioning ${TARGET_DISK}..."
parted -s ${TARGET_DISK} mklabel gpt || error "Failed to create GPT table"
parted -s ${TARGET_DISK} mkpart primary ext4 1MiB ${ROOT_SIZE} || error "Failed to create root partition"
parted -s ${TARGET_DISK} mkpart primary linux-swap ${ROOT_SIZE} 59GiB || error "Failed to create swap"
parted -s ${TARGET_DISK} mkpart primary fat32 59GiB 60GiB || error "Failed to create EFI partition"
parted -s ${TARGET_DISK} set 3 esp on || error "Failed to set ESP flag"

info "Formatting partitions..."
mkfs.ext4 ${TARGET_DISK}1 || error "Failed to format root partition"
mkswap ${TARGET_DISK}2 || error "Failed to format swap"
mkfs.fat -F32 ${TARGET_DISK}3 || error "Failed to format EFI partition"

info "Mounting filesystems..."
mount ${TARGET_DISK}1 /mnt || error "Failed to mount root"
mkdir -p /mnt/boot || error "Failed to create boot directory"
mount ${TARGET_DISK}3 /mnt/boot || error "Failed to mount EFI partition"
swapon ${TARGET_DISK}2 || error "Failed to enable swap"

# ===== PHASE 2: BASE SYSTEM INSTALL =====
info "Optimizing package mirrors..."
pacman -Sy --noconfirm reflector || warn "Mirror update failed, continuing with defaults"
reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

info "Installing base system..."
pacstrap /mnt base linux linux-firmware sof-firmware \
    nano networkmanager grub efibootmgr || error "Base system installation failed"

info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || error "Failed to generate fstab"

# ===== PHASE 3: SYSTEM CONFIGURATION =====
info "Configuring system..."
arch-chroot /mnt /bin/bash <<EOF
    # Time and locale
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime || exit 1
    hwclock --systohc || warn "Hardware clock sync failed"
    sed -i "s/#${LOCALE}/${LOCALE}/" /etc/locale.gen || exit 1
    locale-gen || exit 1
    echo "LANG=${LOCALE}" > /etc/locale.conf || exit 1
    echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf || exit 1

    # Network
    echo "${HOSTNAME}" > /etc/hostname || exit 1
    systemctl enable NetworkManager || warn "Failed to enable NetworkManager"

    # Users
    echo "root:${ROOT_PASSWORD}" | chpasswd || exit 1
    useradd -m -G wheel,audio,video,storage -s /bin/bash ${USERNAME} || exit 1
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd || exit 1
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || exit 1

    # Bootloader
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || exit 1
    grub-mkconfig -o /boot/grub/grub.cfg || exit 1
EOF

# ===== PHASE 4: DESKTOP ENVIRONMENT =====
info "Installing KDE Plasma..."
arch-chroot /mnt /bin/bash <<EOF
    pacman -S --noconfirm xorg plasma plasma-wayland-session kde-applications || exit 1
    pacman -S --noconfirm pipewire pipewire-pulse wireplumber alsa-utils pavucontrol || warn "Audio setup failed"
    pacman -S --noconfirm bluez bluez-utils cups htop neofetch || warn "Utility installation failed"
    systemctl enable sddm || warn "Failed to enable SDDM"
    systemctl enable bluetooth || warn "Failed to enable Bluetooth"
    systemctl enable cups || warn "Failed to enable printing"
EOF

# ===== PHASE 5: POST-INSTALL =====
info "Installation complete!"
echo -e "${GREEN}
Arch Linux has been successfully installed!

Next steps:
1. Type 'reboot' to restart your system
2. Remove the installation media
3. Log in to KDE Plasma as ${USERNAME}
4. Run 'neofetch' to verify your installation

Remember to change your passwords!
${NC}"
