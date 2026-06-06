#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# KDE Plasma 6 desktop + display server

apt-get install -y \
    xorg \
    x11-xserver-utils \
    xwayland \
    plasma-desktop \
    plasma-workspace \
    plasma-nm \
    plasma-pa \
    plasma-systemmonitor \
    kwin-x11 \
    kwin-wayland \
    kde-spectacle \
    dolphin \
    konsole \
    kate \
    ark \
    kscreen \
    sddm \
    sddm-theme-breeze \
    breeze \
    breeze-gtk-theme \
    qt5-style-kvantum \
    qt5-style-kvantum-themes \
    qt6-wayland \
    libqt6waylandcompositor6 \
    xdg-desktop-portal-kde \
    xdg-desktop-portal

# Fonts: Inter (SF Pro lookalike, open-source)
# Ubuntu 24.04 ships fonts-inter; fall back to downloading from GitHub
if apt-get install -y fonts-inter 2>/dev/null; then
    echo "fonts-inter installed from repos."
else
    echo "Downloading Inter font from GitHub..."
    INTER_VER="4.0"
    wget -qO /tmp/inter.zip \
        "https://github.com/rsms/inter/releases/download/v${INTER_VER}/Inter-${INTER_VER}.zip"
    unzip -q /tmp/inter.zip "InterVariable*.ttf" -d /usr/share/fonts/truetype/inter/ 2>/dev/null || \
    unzip -q /tmp/inter.zip "*.ttf" -d /usr/share/fonts/truetype/inter/
    fc-cache -fv
    rm /tmp/inter.zip
fi

# JetBrains Mono for terminal
apt-get install -y fonts-jetbrains-mono || true

# Noto fonts for emoji / CJK coverage
apt-get install -y fonts-noto fonts-noto-color-emoji

fc-cache -fv

# Enable SDDM autologin for live session
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << 'EOF'
[Autologin]
User=slozos
Session=plasma
EOF

systemctl enable sddm

echo "[02-desktop] Done."
