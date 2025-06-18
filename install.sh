#!/bin/bash
set -e

# === CONFIG START ===
DISK="/dev/sdX"        # <--- CHANGE THIS TO YOUR TARGET DRIVE!!!
HOSTNAME="neuroos"
USERNAME="nathan"
PASSWORD="nathan"
TIMEZONE="Africa/Lagos"
LOCALE="en_US.UTF-8"
MODEL_NAME="phi-2.Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/$MODEL_NAME"
# === CONFIG END ===

echo "[+] Partitioning $DISK"
wipefs -a "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 513MiB 100%

mkfs.fat -F32 "${DISK}1"
mkfs.ext4 "${DISK}2"

mount "${DISK}2" /mnt
mkdir /mnt/boot
mount "${DISK}1" /mnt/boot

echo "[+] Installing base system"
pacstrap /mnt base base-devel linux linux-firmware sudo networkmanager grub efibootmgr git cmake make clang curl neovim plymouth

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
echo "[+] Setting locale"
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "[+] Setting timezone"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "[+] Creating user: $USERNAME"
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

echo "[+] Enabling boot splash"
sed -i 's/^HOOKS=.*/HOOKS=(base udev plymouth autodetect modconf block filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

echo "[+] Installing GRUB"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "[+] Enabling services"
systemctl enable NetworkManager

EOF

echo "[+] Configuring user environment"
arch-chroot /mnt /bin/bash <<EOF
su - $USERNAME <<EOL
cd ~

echo "[+] Cloning and building llama.cpp"
sudo pacman -S --noconfirm git cmake make clang
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make -j\$(nproc)
mkdir models && cd models
echo "[+] Downloading model"
curl -LO "$MODEL_URL"
EOL
EOF

echo "[+] Done. You can now reboot into NeuroOS!"
