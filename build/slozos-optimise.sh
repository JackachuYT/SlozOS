#!/usr/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# SlozOS performance tuning. Sourced by slozos-desktop.sh (after identity).
#
# SlozOS runs on anything from a 4 GB 2013 tablet to a gaming desktop, so the
# heavy decisions happen at boot, on the actual hardware:
#   • slozos-hardware (system, early boot): device fixes (Surface lid/sleep,
#     Marvell Wi-Fi), the light/full profile (by RAM) and glass blur (by GPU)
#   • slozos-session (each login): what to start at login for that profile
# What's here is safe and helpful on every PC.
# Needs: CTX SRC merge SLOZOS_EDITION
# ──────────────────────────────────────────────────────────────────────────────

set_desktop_key() {  # set_desktop_key FILE KEY VALUE — inside [Desktop Entry]
    [[ -f $1 ]] || return 0
    if grep -q "^$2=" "$1"; then sed -i "s/^$2=.*/$2=$3/" "$1"
    else sed -i "/^\[Desktop Entry\]/a $2=$3" "$1"; fi
}

# ── Hardware detection, device fixes, performance profile ────────────────────
install -Dm755 "$CTX/config/hardware/slozos-hardware"         /usr/libexec/slozos-hardware
install -Dm644 "$CTX/config/hardware/slozos-hardware.service" /usr/lib/systemd/system/slozos-hardware.service
systemctl enable slozos-hardware.service
# Marvell Wi-Fi stability (only touch Marvell adapters, harmless elsewhere)
install -Dm644 "$CTX/config/hardware/81-mwifiex-no-autosuspend.rules" /usr/lib/udev/rules.d/81-mwifiex-no-autosuspend.rules
install -Dm644 "$CTX/config/hardware/mwifiex.conf"                    /usr/lib/modprobe.d/mwifiex.conf

# ── Memory (good on every PC; vital on 4–8 GB ones) ──────────────────────────
install -Dm644 "$CTX/config/optimise/65-slozos-memory.conf" /usr/lib/sysctl.d/65-slozos-memory.conf
install -Dm644 "$CTX/config/optimise/60-slozos-power.conf"  /usr/lib/sysctl.d/60-slozos-power.conf
install -Dm644 "$CTX/config/optimise/zram-generator.conf"   /etc/systemd/zram-generator.conf
# File search indexes names only (Spotlight's Files search needs no more)
merge /etc/xdg/baloofilerc "$CTX/config/optimise/baloofilerc"
# Don't hold up boot waiting for Wi-Fi to connect (the desktop doesn't need it)
systemctl disable NetworkManager-wait-online.service

# ── Login: start helpers per profile (see slozos-session) ────────────────────
install -Dm755 "$CTX/config/optimise/slozos-session"         /usr/libexec/slozos-session
install -Dm644 "$CTX/config/optimise/slozos-session.desktop" /etc/xdg/autostart/slozos-session.desktop
# slozos-session starts these itself when the profile allows
for f in /etc/xdg/autostart/*kdeconnect*daemon*.desktop /etc/xdg/autostart/*xwaylandvideobridge*.desktop \
         /etc/skel/.config/autostart/steam.desktop; do
    set_desktop_key "$f" Hidden true
done

# On-screen keyboard (~260 MB while enabled) only in tablet mode: off by
# default, switched on/off by slozos-tablet-keyboard as keyboards come and go
printf '[Wayland]\nVirtualKeyboardEnabled=false\n' > "$SRC/kwin-vk"
merge /etc/skel/.config/kwinrc "$SRC/kwin-vk"
install -Dm755 "$CTX/config/optimise/slozos-tablet-keyboard"         /usr/libexec/slozos-tablet-keyboard
install -Dm644 "$CTX/config/optimise/slozos-tablet-keyboard.desktop" /etc/xdg/autostart/slozos-tablet-keyboard.desktop

# ── Gaming: Minecraft (vanilla, no Sodium) and friends ───────────────────────
# Threaded OpenGL for the Minecraft launchers only (not the whole desktop)
install -Dm644 "$CTX/config/gaming/flatpak-override-minecraft" /usr/share/slozos/flatpak-overrides/minecraft
install -Dm644 "$CTX/config/gaming/slozos-gaming.tmpfiles"     /usr/lib/tmpfiles.d/slozos-gaming.conf
install -Dm644 "$CTX/config/gaming/10-slozos-minecraft.conf"   /usr/share/drirc.d/10-slozos-minecraft.conf

# Prism Launcher — the best way to run vanilla Minecraft on Linux — joins
# Bazzite's first-boot Flatpak list
LIST=/usr/share/ublue-os/bazzite/flatpak/install
if [[ -f $LIST ]] && ! grep -qx org.prismlauncher.PrismLauncher "$LIST"; then
    echo org.prismlauncher.PrismLauncher >> "$LIST"
fi

# Prism defaults for new accounts: GameMode on, low-pause G1 GC, a 2 GB heap
# (slozos-session raises it on PCs with more RAM), and the discrete GPU on
# the NVIDIA edition (hybrid laptops render on the NVIDIA card)
HEAP=2048
[[ $SLOZOS_EDITION == NVIDIA ]] && DGPU=true || DGPU=false
PRISM=/etc/skel/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher
mkdir -p "$PRISM"
cat > "$SRC/prismlauncher.cfg" <<EOF
[General]
MinMemAlloc=512
MaxMemAlloc=$HEAP
JvmArgs=-XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=16M -XX:+DisableExplicitGC -XX:+PerfDisableSharedMem -XX:+UseStringDeduplication
EnableFeralGamemode=true
UseDiscreteGpu=$DGPU
# 720p window: 2.25x fewer pixels than 1080p — the iGPU's biggest cost
MinecraftWinWidth=1280
MinecraftWinHeight=720
LaunchMaximized=false
EOF
merge "$PRISM/prismlauncher.cfg" "$SRC/prismlauncher.cfg"

# Opt-in Performance Mode (CPU mitigations off) — in the Portal and as a command
install -Dm755 "$CTX/config/slozos/slozos-performance-mode" /usr/bin/slozos-performance-mode
if [[ -f /usr/share/yafti/yafti.yml ]]; then
    python3 "$CTX/build/portal-add-performance-mode.py"
fi
:
