#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# linux-surface: patched kernel for Surface Pro 2 hardware support
# Adds: touchscreen (iptsd), Surface Type Cover, battery calibration, camera

apt-get install -y --no-install-recommends gnupg

# Import signing key
curl -fsSL https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/linux-surface.gpg

echo "deb [arch=amd64] https://pkg.surfacelinux.com/debian release main" \
    > /etc/apt/sources.list.d/linux-surface.list

apt-get update
apt-get install -y \
    linux-image-surface \
    iptsd \
    libwacom-surface

# Surface IPTS touchscreen daemon config
mkdir -p /etc/iptsd
cat > /etc/iptsd/iptsd.conf << 'EOF'
[Config]
InvertX = false
InvertY = false
Width = 0
Height = 0

[Touch]
DisableOnPalm = true
DisableOnStylus = false
EOF

systemctl enable iptsd 2>/dev/null || echo "Note: iptsd.service not found, will auto-start via udev rules"

# Update initramfs with surface kernel modules
update-initramfs -u -k all

echo "[01-surface-kernel] Done."
