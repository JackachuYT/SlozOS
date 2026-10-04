#!/usr/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# SlozOS desktop layer — shared by every edition's Containerfile:
#
#   RUN --mount=type=bind,source=.,target=/ctx \
#       SLOZOS_HOSTNAME=… SLOZOS_NAME=… SLOZOS_PRETTY_NAME=… \
#       bash /ctx/build/slozos-desktop.sh
#
# Keeping this in one place means a UI fix lands in SP1, SP2 and SB1 at once
# (previously each Containerfile carried its own copy and they drifted apart).
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

CTX=${CTX:-/ctx}
: "${SLOZOS_HOSTNAME:?}" "${SLOZOS_NAME:?}" "${SLOZOS_PRETTY_NAME:?}"

merge() { python3 "$CTX/build/ini-merge.py" "$@"; }
log()   { echo "::group::$*"; }
end()   { echo "::endgroup::"; }

# ── Pinned upstream theme sources (GPL-3.0, github.com/vinceliuice) ──────────
# Bump a SHA to pull in upstream fixes; pinning keeps builds reproducible.
WHITESUR_KDE_SHA=cf4df59ce91004f7ea39358b1b8ff917d5c329f7      # 2026-08-07
WHITESUR_ICONS_SHA=73d8040da51a9ed74e47c7366e7e9ff437601a5c    # 2026-09-10
WHITESUR_CURSORS_SHA=e190baf618ed95ee217d2fd45589bd309b37672b  # 2025-04-05

SRC=$(mktemp -d)
trap 'rm -rf "$SRC"' EXIT

fetch() {  # fetch <repo> <sha> → $SRC/<repo>
    mkdir -p "$SRC/$1"
    curl -fsSL --retry 5 --retry-delay 5 \
        "https://github.com/vinceliuice/$1/archive/$2.tar.gz" \
        | tar -xz -C "$SRC/$1" --strip-components=1
}

# ── ISO build prep ───────────────────────────────────────────────────────────
# bootc-image-builder depsolves every enabled repo. Bazzite's Terra repos point
# at a GPG key that isn't shipped, which breaks that depsolve (and our package
# install below) — disable them; their packages are already baked into the image.
sed -i 's/^enabled[[:space:]]*=[[:space:]]*1/enabled=0/' /etc/yum.repos.d/terra*.repo 2>/dev/null || true

# ── Packages ─────────────────────────────────────────────────────────────────
log "Packages"
# kvantum          → Qt widget engine for the glass widget style
# rsms-inter-fonts → Inter, the UI font (open-source SF Pro look-alike). It was
#                    referenced by kdeglobals before but never installed.
# jetbrains-mono   → monospace font
# plymouth-plugin-script → engine the SlozOS boot splash is written for
rpm-ostree install --idempotent --assumeyes \
    kvantum \
    plymouth-plugin-script \
    rsms-inter-fonts \
    jetbrains-mono-fonts-all
end

# ── macOS Tahoe themes: WhiteSur Liquid (window chrome, panels, widgets) ─────
log "WhiteSur KDE"
fetch WhiteSur-kde "$WHITESUR_KDE_SHA"
# Running as root installs system-wide into /usr/share. Dark variants only.
( cd "$SRC/WhiteSur-kde" && HOME=/tmp bash ./install.sh --color dark )
# Kvantum resolves a theme by directory name, but upstream ships the Liquid
# variant inside WhiteSur/ — give it its own directory so `WhiteSurLiquidDark`
# actually resolves.
mkdir -p /usr/share/Kvantum/WhiteSurLiquidDark
cp "$SRC/WhiteSur-kde/Kvantum/WhiteSur/WhiteSurLiquidDark.kvconfig" \
   "$SRC/WhiteSur-kde/Kvantum/WhiteSur/WhiteSurLiquidDark.svg" \
   /usr/share/Kvantum/WhiteSurLiquidDark/
# Upstream's Liquid Plasma theme reuses the "WhiteSur-dark" id/name, so System
# Settings would list two identical "WhiteSur-dark" entries. Give it its own.
sed -i -e 's/"Id": "WhiteSur-dark"/"Id": "WhiteSurLiquid-dark"/' \
       -e 's/"Name": "WhiteSur-dark"/"Name": "WhiteSur Liquid Dark"/' \
    /usr/share/plasma/desktoptheme/WhiteSurLiquid-dark/metadata.json
for p in /usr/share/aurorae/themes/WhiteSurLiquid-dark \
         /usr/share/plasma/desktoptheme/WhiteSurLiquid-dark \
         /usr/share/Kvantum/WhiteSurLiquidDark/WhiteSurLiquidDark.kvconfig; do
    [ -e "$p" ] || { echo "missing expected theme file: $p" >&2; exit 1; }
done
end

log "WhiteSur icons + cursors"
fetch WhiteSur-icon-theme "$WHITESUR_ICONS_SHA"
# -p swaps the Apple logo for the KDE logo (no Apple trademarks in the OS)
( cd "$SRC/WhiteSur-icon-theme" && bash ./install.sh --kde-plasma --dest /usr/share/icons --theme default )
fetch WhiteSur-cursors "$WHITESUR_CURSORS_SHA"
rm -rf /usr/share/icons/WhiteSur-cursors
cp -r "$SRC/WhiteSur-cursors/dist" /usr/share/icons/WhiteSur-cursors
for t in WhiteSur WhiteSur-dark; do
    gtk-update-icon-cache -f -q "/usr/share/icons/$t" 2>/dev/null || true
done
end

# ── SlozOS branding ──────────────────────────────────────────────────────────
log "Branding"
install -Dm644 "$CTX/assets/logo/slozos-logo.png" /usr/share/pixmaps/slozos-logo.png
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

# First-login fallback that applies the layout if Plasma didn't (see script)
install -Dm755 "$CTX/config/slozos/slozos-firstlogin.sh"      /usr/libexec/slozos-firstlogin
install -Dm644 "$CTX/config/slozos/slozos-firstlogin.desktop" /etc/xdg/autostart/slozos-firstlogin.desktop
end

# ── Boot splash (Plymouth) ───────────────────────────────────────────────────
log "Plymouth"
mkdir -p /usr/share/plymouth/themes/slozos
cp "$CTX"/config/plymouth/slozos/* /usr/share/plymouth/themes/slozos/
# Plymouth only draws the splash when `rhgb` is on the kernel command line
mkdir -p /usr/lib/bootc/kargs.d && printf 'match-architectures = ["x86_64"]\nkargs = ["rhgb", "quiet"]\n' \
    > /usr/lib/bootc/kargs.d/00-slozos-splash.toml
printf '[Daemon]\nTheme=slozos\n' > "$SRC/plymouthd.conf"
merge /etc/plymouth/plymouthd.conf "$SRC/plymouthd.conf"
# The splash lives in the initramfs, so rebuild it — same dracut invocation as
# Bazzite's own build. Build to a temp file first so a dracut failure can never
# leave a half-written initramfs behind; on failure we keep Bazzite's splash.
KVER=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n1)
if dracut --no-hostonly --kver "$KVER" --reproducible --zstd --add ostree --add fido2 \
        -f "$SRC/initramfs.img"; then
    install -m600 "$SRC/initramfs.img" "/usr/lib/modules/$KVER/initramfs.img"
else
    echo "WARNING: dracut failed — keeping the stock initramfs/boot splash" >&2
fi
end

# ── Identity ─────────────────────────────────────────────────────────────────
echo "$SLOZOS_HOSTNAME" > /etc/hostname
sed -i \
    -e "s/^NAME=.*/NAME=\"$SLOZOS_NAME\"/" \
    -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"$SLOZOS_PRETTY_NAME\"/" \
    /usr/lib/os-release
# "About This System" (Info Center) shows SlozOS + its logo
cat > "$SRC/kcm-about-distrorc" <<EOF
[General]
LogoPath=/usr/share/pixmaps/slozos-logo.png
Name=$SLOZOS_NAME
Website=https://github.com/JackachuYT/SlozOS
Variant=$SLOZOS_PRETTY_NAME
EOF
merge /etc/xdg/kcm-about-distrorc "$SRC/kcm-about-distrorc"
