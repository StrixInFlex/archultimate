#!/bin/bash

# -----------------------------------------------------------------------------
# ARCH LINUX ADVANCED INSTALLER WITH TUI
# -----------------------------------------------------------------------------

# Configuration variables
TARGET_DISK="/dev/sda"
HOSTNAME="strixarch"
USERNAME="strix"
ROOT_PASSWORD="strixed"
USER_PASSWORD="strix"
TIMEZONE="Riyadh"
KEYMAP="us"
LOCALE="en_US.UTF-8"

# Partition sizes
ROOT_SIZE="55GiB"
SWAP_SIZE="4GiB"
EFI_SIZE="1022MiB"

# Colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0)

# -----------------------------------------------------------------------------
# TUI FUNCTIONS
# -----------------------------------------------------------------------------

show_main_menu() {
    dialog --backtitle "Arch Linux Installer" \
           --title "Main Menu" \
           --menu "Choose an option:" 15 50 5 \
           1 "Automatic Installation (Recommended)" \
           2 "Manual Partitioning" \
           3 "Configure System" \
           4 "Exit" 2> /tmp/choice
    return $?
}

show_disk_selection() {
    lsblk -d -n -l -o NAME,SIZE | awk '{print $1 " \"" $2 "\""}' > /tmp/disks
    dialog --backtitle "Arch Linux Installer" \
           --title "Select Installation Disk" \
           --menu "Choose target disk:" 15 50 4 \
           $(cat /tmp/disks) 2> /tmp/selected_disk
    TARGET_DISK="/dev/$(cat /tmp/selected_disk)"
}

show_password_dialog() {
    dialog --backtitle "Arch Linux Installer" \
           --title "$1" \
           --passwordbox "Enter password:" 8 50 2> /tmp/password
    echo $(cat /tmp/password)
}

show_progress() {
    dialog --backtitle "Arch Linux Installer" \
           --title "$1" \
           --gauge "$2" 8 50 0
}

# -----------------------------------------------------------------------------
# INSTALLATION FUNCTIONS
# -----------------------------------------------------------------------------

partition_disk() {
    {
        echo -e "o\nn\n\n\n+$ROOT_SIZE\nn\n\n\n+$SWAP_SIZE\nn\n\n\n+$EFI_SIZE\nt\n3\n1\nw" | fdisk $TARGET_DISK
        mkfs.ext4 ${TARGET_DISK}1
        mkswap ${TARGET_DISK}2
        mkfs.fat -F32 ${TARGET_DISK}3
    } | show_progress "Partitioning" "Creating partitions..."
}

install_base() {
    mount ${TARGET_DISK}1 /mnt
    mkdir -p /mnt/boot
    mount ${TARGET_DISK}3 /mnt/boot
    swapon ${TARGET_DISK}2
    
    pacstrap /mnt base linux linux-firmware | show_progress "Installing" "Installing base system..."
    genfstab -U /mnt > /mnt/etc/fstab
}

configure_system() {
    arch-chroot /mnt <<EOF
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc
    echo "LANG=$LOCALE" > /etc/locale.conf
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
    echo "$HOSTNAME" > /etc/hostname
    useradd -m -G wheel $USERNAME
    echo "root:$ROOT_PASSWORD" | chpasswd
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
    systemctl enable NetworkManager
EOF
}

install_gui() {
    arch-chroot /mnt <<EOF
    pacman -S --noconfirm xorg plasma plasma-wayland-session kde-applications
    systemctl enable sddm
EOF
}

# -----------------------------------------------------------------------------
# MAIN FLOW
# -----------------------------------------------------------------------------

# Initialize TUI
while true; do
    show_main_menu
    case $(cat /tmp/choice) in
        1)
            show_disk_selection
            HOSTNAME=$(dialog --inputbox "Enter hostname:" 8 50 2>&1)
            USERNAME=$(dialog --inputbox "Enter username:" 8 50 2>&1)
            ROOT_PASSWORD=$(show_password_dialog "Root Password")
            USER_PASSWORD=$(show_password_dialog "User Password")
            TIMEZONE=$(tzselect)
            
            partition_disk
            install_base
            configure_system
            install_gui
            
            dialog --msgbox "Installation complete! Reboot now." 8 50
            exit 0
            ;;
        2)
            cfdisk $TARGET_DISK
            ;;
        3)
            nano /mnt/etc/fstab
            ;;
        4)
            exit 0
            ;;
    esac
done
