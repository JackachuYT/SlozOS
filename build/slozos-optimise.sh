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

# Frosted-glass blur is the most expensive effect on these iGPUs; each step of
# strength adds blur passes. Lighter on the weaker chips, still clearly glass.
case "$DEVICE" in
    sp1) BLUR=6 ;;      # HD 4000
    sp2) BLUR=8 ;;      # HD 4400
    *)   BLUR=10 ;;     # HD 520 / GTX 940M
esac
printf '[Effect-blur]\nBlurStrength=%s\n' "$BLUR" > "$SRC/kwin-blur"
merge /etc/skel/.config/kwinrc "$SRC/kwin-blur"
:
