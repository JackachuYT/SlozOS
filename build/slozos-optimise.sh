#!/usr/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# SlozOS performance tuning for old Surface hardware. Sourced by
# slozos-desktop.sh (after slozos-identity.sh).
#
#   Surface Pro 1  i5-3317U  · HD 4000 · 4 GB
#   Surface Pro 2  i5-4300U  · HD 4400 · 4–8 GB
#   Surface Book 1 i5/i7-6x00U · HD 520 + GTX 940M · 8–16 GB
#
# Bazzite's desktop image is tuned for gaming PCs with 16 GB+; these Surfaces
# need the opposite trade-offs: protect RAM, keep background work low, and
# go easy on the iGPU.
# Needs: CTX SRC merge SLOZOS_IMAGE
# ──────────────────────────────────────────────────────────────────────────────
DEVICE=${SLOZOS_IMAGE##*-}                       # sp1 | sp2 | sb1

set_desktop_key() {  # set_desktop_key FILE KEY VALUE — inside [Desktop Entry]
    [[ -f $1 ]] || return 0
    if grep -q "^$2=" "$1"; then sed -i "s/^$2=.*/$2=$3/" "$1"
    else sed -i "/^\[Desktop Entry\]/a $2=$3" "$1"; fi
}

# ── Memory ───────────────────────────────────────────────────────────────────
install -Dm644 "$CTX/config/optimise/65-slozos-memory.conf" /usr/lib/sysctl.d/65-slozos-memory.conf
install -Dm644 "$CTX/config/optimise/60-slozos-power.conf"  /usr/lib/sysctl.d/60-slozos-power.conf
install -Dm644 "$CTX/config/optimise/zram-generator.conf"   /etc/systemd/zram-generator.conf
# File search indexes names only (Spotlight's Files search needs no more)
merge /etc/xdg/baloofilerc "$CTX/config/optimise/baloofilerc"

# ── Background services these Surfaces don't need ────────────────────────────
# No Surface in the lineup has a cellular modem
systemctl mask ModemManager.service
# Don't hold up boot waiting for Wi-Fi to connect (the desktop doesn't need it)
systemctl disable NetworkManager-wait-online.service
# Key-remapping daemon (Python, always resident); `sudo systemctl enable --now
# input-remapper` brings it back
systemctl disable input-remapper.service 2>/dev/null || true

# ── Per-device ───────────────────────────────────────────────────────────────
case "$DEVICE" in
    sp1|sp2)
        # One GPU only: the hybrid-graphics switching daemon has nothing to do
        systemctl disable cardwired.service 2>/dev/null || true
        # 4 GB of RAM: don't keep Steam running in the background from login
        # (it holds several hundred MB). It's one click away on the dock.
        for f in /etc/skel/.config/autostart/steam.desktop /etc/xdg/autostart/steam.desktop; do
            set_desktop_key "$f" Hidden true
        done
        ;;
esac

# On-screen keyboard (~260 MB while enabled) only in tablet mode: off by
# default, switched on/off by slozos-tablet-keyboard as the cover comes and goes
printf '[Wayland]\nVirtualKeyboardEnabled=false\n' > "$SRC/kwin-vk"
merge /etc/skel/.config/kwinrc "$SRC/kwin-vk"
install -Dm755 "$CTX/config/optimise/slozos-tablet-keyboard"         /usr/libexec/slozos-tablet-keyboard
install -Dm644 "$CTX/config/optimise/slozos-tablet-keyboard.desktop" /etc/xdg/autostart/slozos-tablet-keyboard.desktop

# 4 GB models: start these on demand instead of at every login
#   • KDE Connect daemon (phone linking, ~80 MB) — opening KDE Connect starts it
#   • XWayland video bridge (~140 MB) — only needed to screen-share from X11
#     apps such as Discord; launch "XWayland Video Bridge" when you need it
case "$DEVICE" in
    sp1|sp2)
        for f in /etc/xdg/autostart/*kdeconnect*daemon*.desktop /etc/xdg/autostart/*xwaylandvideobridge*.desktop; do
            set_desktop_key "$f" Hidden true
        done
        ;;
esac

# Frosted-glass blur is the most expensive effect on these iGPUs; each step of
# strength adds blur passes. Lighter on the weaker chips, still clearly glass.
case "$DEVICE" in
    sp1) BLUR=6 ;;      # HD 4000
    sp2) BLUR=8 ;;      # HD 4400
    *)   BLUR=10 ;;     # HD 520 / GTX 940M
esac
printf '[Effect-blur]\nBlurStrength=%s\n' "$BLUR" > "$SRC/kwin-blur"
merge /etc/skel/.config/kwinrc "$SRC/kwin-blur"

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

# Prism defaults for new accounts: GameMode on, a heap that fits next to the
# desktop, low-pause G1 GC, and the GTX 940M on the Surface Book
case "$DEVICE" in
    sb1) HEAP=3072; DGPU=true ;;
    *)   HEAP=2048; DGPU=false ;;
esac
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
