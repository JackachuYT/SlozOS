#!/usr/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# SlozOS base layer — the parts that rarely change: packages, the pinned
# MacTahoe theme set, and the boot splash (incl. the rebuilt initramfs).
#
#   RUN --mount=type=bind,source=.,target=/ctx bash /ctx/build/slozos-base.sh
#
# Kept in its own image layer, below SlozOS's settings and apps, so a normal
# SlozOS update doesn't make every PC re-download it. Nothing here may
# depend on the SlozOS version (that's why the initramfs is built before
# os-release is rebranded).
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

CTX=${CTX:-/ctx}

merge() { python3 "$CTX/build/ini-merge.py" "$@"; }
log()   { echo "::group::$*"; }
end()   { echo "::endgroup::"; }

# ── Pinned upstream theme sources (github.com/vinceliuice) ──────────────────
# MacTahoe: the macOS 26/27 (Tahoe → Golden Gate) Liquid Glass look.
# KDE theme LGPL-3.0, icons + cursors GPL-3.0. Bump a SHA for upstream fixes.
MACTAHOE_KDE_SHA=cbf6a1f71b591d143184855d62f6272ce533e7c3     # 2026-08-16
MACTAHOE_ICONS_SHA=839848b9a8a38a92a6936e30c4abe35cc6f2546d   # 2026-09-10

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
# plasma-milou, layer-shell-qt → runtime pieces SlozOS Spotlight uses
rpm-ostree install --idempotent --assumeyes \
    kvantum \
    plasma-milou \
    layer-shell-qt \
    plymouth-plugin-script \
    rsms-inter-fonts \
    jetbrains-mono-fonts-all
end

# ── Hardware video decode (VA-API) on every GPU ──────────────────────────────
# Bazzite's Mesa covers AMD (radeonsi) and NVIDIA ships its own; make sure
# both Intel drivers are present — iHD (Broadwell → today) and i965 (Sandy
# Bridge → Haswell, e.g. Surface Pro 1/2) — without fighting whichever
# package the base already uses for them. vainfo checks it from a terminal.
log "Video acceleration"
VA_PKGS=(libva-utils)
[ -e /usr/lib64/dri/iHD_drv_video.so ] || VA_PKGS+=(libva-intel-media-driver)
rpm-ostree install --idempotent --assumeyes "${VA_PKGS[@]}"
# i965 isn't in Fedora (it's in RPM Fusion); Universal Blue images normally
# carry it already — try, but never fail the build over it
if [ ! -e /usr/lib64/dri/i965_drv_video.so ]; then
    rpm-ostree install --idempotent --assumeyes libva-intel-driver \
        || echo "::warning::i965 VA-API driver unavailable — older Intel GPUs decode video in software"
fi
ls /usr/lib64/dri/*_drv_video.so 2>/dev/null || true
end

# ── macOS 27-style themes: MacTahoe (window chrome, panels, widgets, icons) ─
log "MacTahoe KDE"
fetch MacTahoe-kde "$MACTAHOE_KDE_SHA"
# Running as root installs system-wide into /usr/share. Light + dark variants
# (SlozOS defaults to dark; Welcome can switch).
( cd "$SRC/MacTahoe-kde" && HOME=/tmp bash ./install.sh )
# Kvantum resolves themes by directory name; give each variant its own dir so
# MacTahoe / MacTahoeDark both resolve explicitly
for v in MacTahoe MacTahoeDark; do
    mkdir -p "/usr/share/Kvantum/$v"
    cp "$SRC/MacTahoe-kde/Kvantum/MacTahoe/$v.kvconfig" "$SRC/MacTahoe-kde/Kvantum/MacTahoe/$v.svg" "/usr/share/Kvantum/$v/"
done
for p in /usr/share/aurorae/themes/MacTahoe-Dark /usr/share/aurorae/themes/MacTahoe-Light \
         /usr/share/plasma/desktoptheme/MacTahoe-Dark /usr/share/plasma/desktoptheme/MacTahoe-Light \
         /usr/share/Kvantum/MacTahoeDark/MacTahoeDark.kvconfig; do
    [ -e "$p" ] || { echo "missing expected theme file: $p" >&2; exit 1; }
done
end

log "MacTahoe icons + cursors"
fetch MacTahoe-icon-theme "$MACTAHOE_ICONS_SHA"
( cd "$SRC/MacTahoe-icon-theme" && bash ./install.sh --dest /usr/share/icons --theme default )
rm -rf /usr/share/icons/MacTahoe-cursors /usr/share/icons/MacTahoe-dark-cursors
cp -r "$SRC/MacTahoe-icon-theme/cursors/dist"      /usr/share/icons/MacTahoe-cursors
cp -r "$SRC/MacTahoe-icon-theme/cursors/dist-dark" /usr/share/icons/MacTahoe-dark-cursors
# No Apple trademarks in the OS: the "start-here" (app launcher) icons become
# the SlozOS logo, and the few icons drawn with the Apple logo on them (Disks,
# the iMac-style "computer", Variety, the icon-settings page) are removed so
# those fall back to Breeze. Aliases pointing at them are dropped with them.
APPLE_LOGO_ICONS=('start-here*' 'folder-apple*' gnome-disks computer variety variety-slideshow preferences-desktop-icons)
for t in MacTahoe MacTahoe-dark MacTahoe-light; do
    [ -d "/usr/share/icons/$t" ] || continue
    for n in "${APPLE_LOGO_ICONS[@]}"; do
        find "/usr/share/icons/$t" \( -name "$n.svg" -o -name "$n.png" -o -name "$n-symbolic.svg" \) -delete
    done
    find "/usr/share/icons/$t" -xtype l -delete     # aliases left dangling
    install -Dm644 "$CTX/assets/logo/slozos-logo-symbolic.png" "/usr/share/icons/$t/places/scalable/start-here.png"
    gtk-update-icon-cache -f -q "/usr/share/icons/$t" 2>/dev/null || true
done
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

# ── Smaller image: drop package caches and build leftovers ───────────────────
rm -rf /var/cache/* /var/log/* /var/tmp/* /tmp/* 2>/dev/null || true
