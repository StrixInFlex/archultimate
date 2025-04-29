#!/bin/bash

# ~(˘▾˘~) ULTIMATE ARCH INSTALLER (~˘▾˘)~
# Usage: 
# 1. Boot Arch ISO
# 2. Run: curl -sL https://raw.githubusercontent.com/StrixInFlex/archinstall3/main/archinstall.sh > install.sh
# 3. chmod +x install.sh && ./install.sh

### (=^･ω･^=) CONFIG - EDIT ME! (=^･ω･^=) ###
TARGET_DISK="/dev/nvme0n1"   # CHECK WITH 'lsblk' PLZ!
HOSTNAME="archdolphin"
USERNAME="dolphin"
USER_PASSWORD="1234"          # (╯°□°）╯ CHANGE THIS!
ROOT_PASSWORD="1234"          # (╯°□°）╯ CHANGE THIS TOO!
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
KEYMAP="us"

### (◕‿◕✿) PARTITIONING ###
ROOT_SIZE="55GiB"    # sda1 - Root
SWAP_SIZE="4GiB"     # sda2 - Swap
EFI_SIZE="1022MiB"   # sda3 - EFI

### (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ COLORS ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

### (•̀ᴗ•́)و SAFETY CHECK ###
echo -e "${YELLOW}WARNING: THIS WILL NUKE ${TARGET_DISK}!${NC}"
lsblk
read -p "ARE YOU READY TO DOLPHIN-DIVE INTO ARCH? (^・ω・^ ) (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation aborted! (´• ω •`)ﾉ${NC}"
    exit 1
fi

### (ง •̀_•́)ง HELPER FUNCTIONS ###
info() { echo -e "${GREEN}[♡INFO♡]${NC} $1"; }
warn() { echo -e "${YELLOW}[♡WARN♡]${NC} $1"; }
error() { echo -e "${RED}[♡ERROR♡]${NC} $1"; exit 1; }

### PHASE 1: (╯°□°）╯︵ PARTITIONING ###
info "Partitioning ${TARGET_DISK} with dolphin magic..."
parted -s ${TARGET_DISK} mklabel gpt || error "Failed to create GPT table!"
parted -s ${TARGET_DISK} mkpart primary ext4 1MiB ${ROOT_SIZE} || error "Failed root partition!"
parted -s ${TARGET_DISK} mkpart primary linux-swap ${ROOT_SIZE} 59GiB || error "Failed swap!"
parted -s ${TARGET_DISK} mkpart primary fat32 59GiB 60GiB || error "Failed EFI!"
parted -s ${TARGET_DISK} set 3 esp on || error "Failed ESP flag!"

info "Formatting..."
mkfs.ext4 ${TARGET_DISK}1 || error "Failed to format root!"
mkswap ${TARGET_DISK}2 || error "Failed to format swap!"
mkfs.fat -F32 ${TARGET_DISK}3 || error "Failed to format EFI!"

info "Mounting..."
mount ${TARGET_DISK}1 /mnt || error "Failed to mount root!"
mkdir -p /mnt/boot || error "Failed to create /boot!"
mount ${TARGET_DISK}3 /mnt/boot || error "Failed to mount EFI!"
swapon ${TARGET_DISK}2 || error "Failed to enable swap!"

### PHASE 2: (ﾉ´ヮ`)ﾉ*: ･ﾟ PACSTRAP ###
info "Optimizing mirrors for MAXIMUM SPEED..."
pacman -Sy --noconfirm reflector || warn "Mirror update failed, continuing anyway!"
reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

info "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware sof-firmware \
    nano networkmanager grub efibootmgr || error "Pacstrap failed!"

info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || error "Fstab generation failed!"

### PHASE 3: (◠‿◠✿) CHROOT CONFIG ###
info "Entering chroot..."
arch-chroot /mnt /bin/bash <<EOF
    # ʕ•ᴥ•ʔ Time & Locale
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime || exit 1
    hwclock --systohc || warn "HW clock sync failed!"
    sed -i "s/#${LOCALE}/${LOCALE}/" /etc/locale.gen || exit 1
    locale-gen || exit 1
    echo "LANG=${LOCALE}" > /etc/locale.conf || exit 1
    echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf || exit 1

    # (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ Network
    echo "${HOSTNAME}" > /etc/hostname || exit 1
    systemctl enable NetworkManager || warn "Failed to enable NM!"

    # (｡♥‿♥｡) Users
    echo "root:${ROOT_PASSWORD}" | chpasswd || exit 1
    useradd -m -G wheel,audio,video,storage -s /bin/bash ${USERNAME} || exit 1
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd || exit 1
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || exit 1

    # (╯°□°）╯︵ GRUB
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || exit 1
    grub-mkconfig -o /boot/grub/grub.cfg || exit 1
EOF

### PHASE 4: (✿ ♥‿♥) KDE PLASMA ###
info "Installing KDE Plasma..."
arch-chroot /mnt /bin/bash <<EOF
    # ヽ(・ω・)ﾉ Desktop
    pacman -S --noconfirm xorg plasma plasma-wayland-session kde-applications || exit 1

    # ♪~ ᕕ(ᐛ)ᕗ Audio
    pacman -S --noconfirm pipewire pipewire-pulse wireplumber alsa-utils pavucontrol || warn "Audio setup failed!"

    # (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ Utilities
    pacman -S --noconfirm bluez bluez-utils cups htop neofetch || warn "Utils failed!"

    # (•̀ᴗ•́)و Services
    systemctl enable sddm || warn "SDDM failed!"
    systemctl enable bluetooth || warn "Bluetooth failed!"
    systemctl enable cups || warn "Printing failed!"
EOF

### PHASE 5: (ノ°∀°)ノ GAMING SETUP ###
info "Installing gaming packages..."
arch-chroot /mnt /bin/bash <<EOF
    # (ﾉ◕ヮ◕)ﾉ*:･ﾟ AUR/yay
    pacman -S --noconfirm git base-devel || exit 1
    sudo -u ${USERNAME} git clone https://aur.archlinux.org/yay.git /home/${USERNAME}/yay || exit 1
    cd /home/${USERNAME}/yay || exit 1
    sudo -u ${USERNAME} makepkg -si --noconfirm || warn "Yay install failed!"

    # (ノಠ益ಠ)ノ Steam + Gaming
    sudo -u ${USERNAME} yay -S --noconfirm steam lutris wine-staging gamemode || warn "Gaming setup failed!"
EOF

### (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ DONE! ###
echo -e "${GREEN}
   INSTALLATION COMPLETE! (ﾉ´ヮ`)ﾉ*: ･ﾟ
   -----------------------------------
   Hostname: ${HOSTNAME}
   Username: ${USERNAME}
   Password: ${USER_PASSWORD} (Change me plz!)

   WHAT'S INSTALLED:
   - KDE Plasma Desktop
   - Steam + Lutris + Wine
   - Audio & Bluetooth
   - Printing support
   - AUR/yay for more apps!

   NEXT STEPS:
   1. Type 'reboot' to restart
   2. Remove installation media
   3. Login to KDE Plasma!
   4. Run 'neofetch' to flex! (^・ω・^ )
${NC}"
