#!/usr/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# SlozOS settings layer — branding, desktop defaults, identity, update channel
# and tuning. Shared by every edition's Containerfile, after slozos-base.sh:
#
#   RUN --mount=type=bind,source=.,target=/ctx \
#       SLOZOS_HOSTNAME=… SLOZOS_NAME=… SLOZOS_PRETTY_NAME=… SLOZOS_VERSION=… \
#       SLOZOS_EDITION=… SLOZOS_IMAGE=ghcr.io/jackachuyt/slozos-<edition> \
#       bash /ctx/build/slozos-desktop.sh
#
# Keeping this in one place means a UI fix lands in SP1, SP2 and SB1 at once
# (previously each Containerfile carried its own copy and they drifted apart).
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

CTX=${CTX:-/ctx}
: "${SLOZOS_HOSTNAME:?}" "${SLOZOS_NAME:?}" "${SLOZOS_PRETTY_NAME:?}" "${SLOZOS_VERSION:?}" "${SLOZOS_EDITION:?}" "${SLOZOS_IMAGE:?}"

merge() { python3 "$CTX/build/ini-merge.py" "$@"; }
log()   { echo "::group::$*"; }
end()   { echo "::endgroup::"; }

SRC=$(mktemp -d)
trap 'rm -rf "$SRC"' EXIT

# ── SlozOS branding ──────────────────────────────────────────────────────────
log "Branding"
install -Dm644 "$CTX/assets/logo/slozos-logo.png" /usr/share/pixmaps/slozos-logo.png
# Menu-bar logo: the SloZ sloth, white on transparent (made from
# assets/logo/slozos-logo-sloz-source.png with strokes thickened slightly so
# they hold up at 20–24 px)
install -Dm644 "$CTX/assets/logo/slozos-logo-symbolic.png" /usr/share/pixmaps/slozos-logo-symbolic.png
# Full logo, white on transparent, for dark backgrounds (About page)
install -Dm644 "$CTX/config/plymouth/slozos/logo.png" /usr/share/pixmaps/slozos-logo-white.png
install -Dm644 "$CTX/config/kde/SlozOS.colors"    /usr/share/color-schemes/SlozOS.colors

# Wallpaper as a proper Plasma wallpaper package so it shows in the picker
WALL=/usr/share/wallpapers/SlozOS
install -Dm644 "$CTX/assets/wallpapers/slozos-default.png" "$WALL/contents/images/slozos-default.png"
cat > "$WALL/metadata.json" <<'EOF'
{
    "KPlugin": {
        "Authors": [ { "Name": "SlozOS" } ],
        "Id": "SlozOS",
        "License": "CC-BY-SA-4.0",
        "Name": "SlozOS"
    }
}
EOF
WALL_URL="file://$WALL/contents/images/slozos-default.png"

# Global theme (Look-and-Feel): defaults + the menu-bar/dock layout script
mkdir -p /usr/share/plasma/look-and-feel
cp -r "$CTX/config/plasma/look-and-feel/org.slozos.desktop" /usr/share/plasma/look-and-feel/
# The SlozOS logo menu widget for the top-left of the menu bar
mkdir -p /usr/share/plasma/plasmoids
cp -r "$CTX/config/plasma/plasmoids/org.slozos.logomenu" /usr/share/plasma/plasmoids/
# Control Center (menu bar, next to the clock) + its backend
cp -r "$CTX/config/plasma/plasmoids/org.slozos.controlcenter" /usr/share/plasma/plasmoids/
install -Dm755 "$CTX/config/controlcenter/slozos-cc" /usr/bin/slozos-cc
# Touchscreen edge swipes (KWin script, on by default)
mkdir -p /usr/share/kwin/scripts
cp -r "$CTX/config/kwin/scripts/slozos-touch" /usr/share/kwin/scripts/

# Login screen: Bazzite 44 uses Plasma Login Manager (SDDM themes no longer
# apply). It only supports a wallpaper, so set that.
printf '[Greeter]\nWallpaperPlugin=org.kde.image\n\n[Greeter][Wallpaper][org.kde.image][General]\nImage=%s\nPreviewImage=%s\n' \
    "$WALL_URL" "$WALL_URL" > "$SRC/plasmalogin.conf"
merge /usr/lib/plasmalogin/defaults.conf "$SRC/plasmalogin.conf"
end

# ── Per-user defaults (/etc/skel → copied into each new account) ─────────────
# Merged on top of anything Bazzite already ships, instead of overwriting it.
log "User defaults"
SKEL=/etc/skel/.config
mkdir -p "$SKEL/Kvantum" "$SKEL/gtk-3.0" "$SKEL/gtk-4.0"

merge "$SKEL/kdeglobals"         "$CTX/config/kde/SlozOS.colors" "$CTX/config/kde/kdeglobals"
merge "$SKEL/kwinrc"             "$CTX/config/kde/kwinrc"
merge "$SKEL/kcminputrc"         "$CTX/config/kde/kcminputrc"
merge "$SKEL/plasmarc"           "$CTX/config/kde/plasmarc"
merge "$SKEL/kglobalshortcutsrc" "$CTX/config/kde/kglobalshortcutsrc"
merge "$SKEL/Kvantum/kvantum.kvconfig" "$CTX/config/kvantum/kvantum.kvconfig"
merge "$SKEL/gtk-3.0/settings.ini" "$CTX/config/gtk/gtk3-settings.ini"
merge "$SKEL/gtk-4.0/settings.ini" "$CTX/config/gtk/gtk4-settings.ini"

# Lock screen uses the SlozOS wallpaper too
printf '[Greeter][Wallpaper][org.kde.image][General]\nImage=%s\nPreviewImage=%s\n' \
    "$WALL_URL" "$WALL_URL" > "$SRC/kscreenlockerrc"
merge "$SKEL/kscreenlockerrc" "$SRC/kscreenlockerrc"

# SlozOS Spotlight (binary + .desktop come from the Containerfile's build
# stage): start it hidden at login so Meta+Space opens it instantly, and
# register its Meta+Space shortcut with KGlobalAccel.
install -Dm644 "$CTX/spotlight/slozos-spotlight-autostart.desktop" /etc/xdg/autostart/slozos-spotlight.desktop
install -Dm644 "$CTX/spotlight/org.slozos.spotlight.desktop"       /usr/share/kglobalaccel/org.slozos.spotlight.desktop

# SlozOS Dock (binary + .desktop from the apps stage) replaces Plasma's bottom
# panel: started at login, early, so it's there with the desktop
install -Dm644 "$CTX/dock/slozos-dock-autostart.desktop" /etc/xdg/autostart/slozos-dock.desktop
mkdir -p /usr/share/slozos
# For accounts made before 1.4.4 (see slozos-session): the layout script minus
# its wallpaper part, to rebuild the menu bar and drop the old Plasma dock
sed '/^\/\/ ── Wallpaper/,/^\/\/ Start from a clean slate/{/^\/\/ Start from a clean slate/!d}' \
    /usr/share/plasma/look-and-feel/org.slozos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js \
    > /usr/share/slozos/menubar-layout.js
grep -q 'wallpaperPlugin' /usr/share/slozos/menubar-layout.js && { echo "menubar-layout.js still sets the wallpaper"; exit 1; }
install -Dm644 "$CTX/config/slozos/tray-items.js" /usr/share/slozos/tray-items.js

# SlozOS Welcome runs on first login (binary from the apps stage) and takes
# over from Bazzite's Portal, which stays in the app menu as "SlozOS Portal"
install -Dm644 "$CTX/welcome/slozos-welcome-firstrun.desktop" /etc/xdg/autostart/slozos-welcome-firstrun.desktop
P=/etc/skel/.config/autostart/bazzite-portal.desktop
if [[ -f $P ]]; then
    if grep -q '^Hidden=' "$P"; then sed -i 's/^Hidden=.*/Hidden=true/' "$P"; else sed -i '/^\[Desktop Entry\]/a Hidden=true' "$P"; fi
fi

# First-login fallback that applies the layout if Plasma didn't (see script)
install -Dm755 "$CTX/config/slozos/slozos-firstlogin.sh"      /usr/libexec/slozos-firstlogin
install -Dm644 "$CTX/config/slozos/slozos-firstlogin.desktop" /etc/xdg/autostart/slozos-firstlogin.desktop
end

# ── Identity + update channel ────────────────────────────────────────────────
# Before the initramfs rebuild below, which copies os-release into it.
log "Identity + updates"
source "$CTX/build/slozos-identity.sh"
end

# ── Performance tuning (hardware-aware) ─────────────────────────────────────
log "Optimise"
source "$CTX/build/slozos-optimise.sh"
end

# ── Smaller image: drop package caches and build leftovers ───────────────────
rm -rf /var/cache/* /var/log/* /var/tmp/* /tmp/* 2>/dev/null || true
