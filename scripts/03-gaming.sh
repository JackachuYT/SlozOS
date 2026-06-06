#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Gaming stack optimized for Surface Pro 2 (Intel HD 4400 iGPU)
# Targets: emulation, indie 2D, older 3D games via Steam/Proton

# 32-bit support required for Steam
dpkg --add-architecture i386
apt-get update

# Vulkan + Mesa (Intel HD 4400 = Haswell = i965 + ANV driver)
apt-get install -y \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers:i386 \
    libvulkan1 \
    libvulkan1:i386 \
    vulkan-tools \
    mesa-utils \
    libgl1-mesa-dri \
    libgl1-mesa-dri:i386 \
    libgles2 \
    i965-va-driver \
    libva2 \
    vainfo

# Steam
wget -qO /tmp/steam.deb https://cdn.akamai.steamstatic.com/client/installer/steam.deb
apt-get install -y /tmp/steam.deb
rm /tmp/steam.deb
apt-get install -y steam-devices

# Lutris (game manager supporting GOG, itch.io, etc.)
apt-get install -y lutris || true

# Wine (Windows compatibility layer)
apt-get install -y \
    wine \
    wine32:i386 \
    winetricks || true

# RetroArch (multi-system emulator)
apt-get install -y retroarch retroarch-assets libretro-* || true

# GameMode: CPU governor boost during gaming
apt-get install -y gamemode

# MangoHud: in-game performance overlay
apt-get install -y mangohud mangohud:i386 || true

# Input + controller support
apt-get install -y \
    joystick \
    jstest-gtk \
    antimicro \
    xboxdrv || true

# Reduce GPU power management latency for integrated graphics
cat > /etc/udev/rules.d/60-intel-gpu-power.rules << 'EOF'
# Disable i915 RC6 power gating during gaming (reduces stuttering on HD 4400)
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{class}=="0x030000", \
  RUN+="/bin/sh -c 'echo 0 > /sys/class/drm/card0/device/power/autosuspend_delay_ms'"
EOF

echo "[03-gaming] Done."
