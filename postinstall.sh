#!/bin/bash

set -e

USER="nathan"
HOME="/home/$USER"

echo "[+] Updating system..."
sudo pacman -Syu --noconfirm

echo "[+] Installing GUI stack: Hyprland, Waybar, Rofi, Kitty..."
sudo pacman -S --noconfirm hyprland waybar rofi kitty alacritty xdg-desktop-portal-hyprland \
  ttf-jetbrains-mono ttf-nerd-fonts-symbols \
  polkit-gnome network-manager-applet brightnessctl pamixer \
  thunar pavucontrol

echo "[+] Installing Plymouth for splash screen..."
sudo pacman -S --noconfirm plymouth
sudo plymouth-set-default-theme spinner -R

echo "[+] Enabling greet + network..."
sudo systemctl enable greetd.service
sudo systemctl enable NetworkManager

echo "[+] Cloning and building llama.cpp..."
sudo pacman -S --noconfirm cmake gcc make git
cd "$HOME"
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
make LLAMA_CUBLAS=1 -j$(nproc) || make -j$(nproc)

echo "[+] Creating Hyprland config..."
mkdir -p "$HOME/.config/hypr"
cat <<EOF > "$HOME/.config/hypr/hyprland.conf"
exec-once = waybar &
exec-once = rofi -show drun &
monitor=,preferred,auto,auto
input {
  kb_layout = us
}
EOF

echo "[+] Creating Waybar config..."
mkdir -p "$HOME/.config/waybar"
cat <<EOF > "$HOME/.config/waybar/config.json"
{
  "layer": "top",
  "position": "top",
  "modules-left": ["clock"],
  "modules-center": [],
  "modules-right": ["pulseaudio", "network"]
}
EOF

echo "[+] Setting default session to Hyprland..."
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml > /dev/null <<EOF
[terminal]
vt = 1
[default_session]
command = "Hyprland"
user = "$USER"
EOF

echo "[+] Fixing permissions..."
sudo chown -R "$USER:$USER" "$HOME"

echo "[✔] Postinstall complete. Reboot and enjoy NeuroOS!"
