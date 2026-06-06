#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Apt sources for Ubuntu 24.04 (noble)
cat > /etc/apt/sources.list << 'EOF'
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF

apt-get update
apt-get install -y --no-install-recommends \
    casper \
    systemd \
    systemd-sysv \
    dbus \
    udev \
    bash \
    locales \
    tzdata \
    sudo \
    curl \
    wget \
    git \
    ca-certificates \
    network-manager \
    wpasupplicant \
    linux-firmware \
    initramfs-tools \
    plymouth \
    plymouth-themes \
    nano \
    htop \
    zip \
    unzip \
    zstd \
    xdg-utils \
    pulseaudio \
    pipewire \
    pipewire-pulse \
    wireplumber \
    bluez \
    bluetooth

# Locale
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
echo "UTC" > /etc/timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Default live user
useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev slozos
echo "slozos:slozos" | chpasswd
echo "slozos ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/slozos

echo "slozos" > /etc/hostname
cat >> /etc/hosts << 'EOF'
127.0.1.1   slozos
EOF

# Enable NetworkManager on boot
systemctl enable NetworkManager

echo "[00-base] Done."
