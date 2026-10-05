#!/usr/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Build stage for SlozOS's own apps, run on the same Bazzite base as the OS so
# they link against the exact Qt/KDE versions it ships. Installs into /out;
# the Containerfile copies /out/usr into the OS image.
#
#   • SlozOS Spotlight (spotlight/)
#   • SlozOS Welcome (welcome/) — first-run setup app
#   • SlozOS Updater — Bazzite's graphical updater (rfrench3/bazzite-updater,
#     GPL-2.0-or-later), pinned and rebuilt with SlozOS naming. Its window
#     title is compiled in, so configuration alone can't rename it.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail
CTX=${CTX:-/ctx}

UPDATER_SHA=9e7654f91f747561d14d24dc243973edb408606c   # 2026-10-04

sed -i 's/^enabled[[:space:]]*=[[:space:]]*1/enabled=0/' /etc/yum.repos.d/terra*.repo 2>/dev/null || true
# disable_excludes: Bazzite blocks Fedora's mesa-* packages (it ships its own
# Mesa), which also blocks mesa-libGLU-devel that SDL3-devel needs. This stage
# is thrown away after the build, so the OS image itself is unaffected.
dnf5 -y install --setopt=install_weak_deps=False --setopt=disable_excludes='*' \
    gcc-c++ cmake extra-cmake-modules git \
    qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtsvg-devel \
    kf6-kwindowsystem-devel kf6-kservice-devel kf6-kio-devel layer-shell-qt-devel \
    kf6-kirigami-devel kf6-kirigami-addons-devel kf6-kcoreaddons-devel kf6-kconfig-devel \
    kf6-kcolorscheme-devel kf6-ki18n-devel kf6-kiconthemes-devel SDL3-devel gettext

# ── SlozOS Spotlight ─────────────────────────────────────────────────────────
cmake -S "$CTX/spotlight" -B /tmp/spotlight -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build /tmp/spotlight -j"$(nproc)"
DESTDIR=/out cmake --install /tmp/spotlight

# ── SlozOS Welcome ───────────────────────────────────────────────────────────
cmake -S "$CTX/welcome" -B /tmp/welcome -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build /tmp/welcome -j"$(nproc)"
DESTDIR=/out cmake --install /tmp/welcome

# ── SlozOS Updater ───────────────────────────────────────────────────────────
mkdir -p /tmp/updater
curl -fsSL --retry 5 "https://github.com/rfrench3/bazzite-updater/archive/$UPDATER_SHA.tar.gz" \
    | tar -xz -C /tmp/updater --strip-components=1
cd /tmp/updater
sed -i \
    -e 's/Bazzite Updater/SlozOS Updater/g' \
    -e 's/Updating and rebasing utility for Bazzite/Updates for SlozOS/g' \
    src/main.cpp src/pages/Main.qml \
    io.github.rfrench3.bazzite-updater.desktop io.github.rfrench3.bazzite-updater.metainfo.xml
sed -i '/^Name\[/d' io.github.rfrench3.bazzite-updater.desktop   # translated "Bazzite" names
cmake -S . -B /tmp/updater-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build /tmp/updater-build -j"$(nproc)"
DESTDIR=/out cmake --install /tmp/updater-build
rm -rf /out/etc        # its config lives in the OS image (see slozos-identity.sh)
