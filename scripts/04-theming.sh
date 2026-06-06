#!/bin/bash
set -euo pipefail

SLOZOS_CONFIG="/tmp/slozos-config"
SLOZOS_ASSETS="/tmp/slozos-assets"
USER_HOME="/home/slozos"
USER_CONFIG="$USER_HOME/.config"

mkdir -p "$USER_CONFIG/kvantum" \
         "$USER_CONFIG/kwin" \
         "$USER_CONFIG/plasma-workspace/env" \
         "$USER_HOME/.local/share/color-schemes" \
         "$USER_HOME/.local/share/plasma/layout-templates" \
         "/usr/share/plymouth/themes/slozos" \
         "/usr/share/sddm/themes/slozos" \
         "/usr/share/slozos/wallpapers" \
         "/usr/share/slozos/logo" \
         "/usr/share/slozos/fonts"

# ── Kvantum: Liquid Glass theme ──────────────────────────────────────────────
mkdir -p "$USER_CONFIG/kvantum/SlozOS"
cp -r "$SLOZOS_CONFIG/kvantum/SlozOS/." "$USER_CONFIG/kvantum/SlozOS/"

cat > "$USER_CONFIG/kvantum/kvantum.kvconfig" << 'EOF'
[General]
theme=SlozOS
EOF

# ── KWin compositor: blur + transparency ─────────────────────────────────────
cp "$SLOZOS_CONFIG/kde/kwinrc" "$USER_CONFIG/kwinrc"

# ── KDE global settings: fonts + colors ──────────────────────────────────────
cp "$SLOZOS_CONFIG/kde/kdeglobals" "$USER_CONFIG/kdeglobals"

# ── Color scheme ─────────────────────────────────────────────────────────────
cp "$SLOZOS_CONFIG/kde/SlozOS.colors" "$USER_HOME/.local/share/color-schemes/SlozOS.colors"

# ── Plasma layout script (runs at first login) ────────────────────────────────
cp "$SLOZOS_CONFIG/kde/plasma-layout.js" \
   "$USER_HOME/.local/share/plasma/layout-templates/slozos-layout.js"

cat > "$USER_CONFIG/plasma-workspace/env/slozos-layout.sh" << 'ENVEOF'
#!/bin/bash
# Apply SlozOS panel layout on first login
LAYOUT_APPLIED="$HOME/.config/.slozos-layout-applied"
if [ ! -f "$LAYOUT_APPLIED" ]; then
    sleep 3
    qdbus org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "$(cat $HOME/.local/share/plasma/layout-templates/slozos-layout.js)" 2>/dev/null || true
    touch "$LAYOUT_APPLIED"
fi
ENVEOF
chmod +x "$USER_CONFIG/plasma-workspace/env/slozos-layout.sh"

# ── GTK theme: match Liquid Glass look ───────────────────────────────────────
mkdir -p "$USER_CONFIG/gtk-3.0" "$USER_CONFIG/gtk-4.0"
cp "$SLOZOS_CONFIG/gtk/gtk3-settings.ini" "$USER_CONFIG/gtk-3.0/settings.ini"
cp "$SLOZOS_CONFIG/gtk/gtk4-settings.ini" "$USER_CONFIG/gtk-4.0/settings.ini"

# ── Wallpaper ─────────────────────────────────────────────────────────────────
if [ -f "$SLOZOS_ASSETS/wallpapers/slozos-default.png" ]; then
    cp "$SLOZOS_ASSETS/wallpapers/slozos-default.png" \
       "/usr/share/slozos/wallpapers/slozos-default.png"
else
    echo "WARNING: wallpaper not found — run: python3 assets/generate-assets.py"
fi

# ── Logo (used by SDDM theme + system branding) ───────────────────────────────
if [ -f "$SLOZOS_ASSETS/logo/slozos-logo.png" ]; then
    cp "$SLOZOS_ASSETS/logo/slozos-logo.png" "/usr/share/slozos/logo/slozos.png"
    # Also drop into the SDDM theme directory so Main.qml can reference it
    cp "$SLOZOS_ASSETS/logo/slozos-logo.png" "/usr/share/sddm/themes/slozos/logo.png"
fi

# ── SF Pro font (optional — included if get-sf-pro.sh was run) ───────────────
mkdir -p /usr/share/fonts/truetype/sf-pro
if ls "$SLOZOS_ASSETS/fonts/sf-pro/"*.{ttf,otf} 2>/dev/null | grep -q .; then
    cp "$SLOZOS_ASSETS/fonts/sf-pro/"*.{ttf,otf} \
       "/usr/share/fonts/truetype/sf-pro/"
    fc-cache -fv
    # Patch kdeglobals to use SF Pro instead of Inter
    sed -i 's/font=Inter,/font=SF Pro,/g; s/font=Inter /font=SF Pro /g' \
        "$USER_CONFIG/kdeglobals"
    echo "SF Pro installed."
else
    echo "SF Pro not found — using Inter."
fi

# ── SDDM Liquid Glass login theme ────────────────────────────────────────────
cp -r "$SLOZOS_CONFIG/sddm/slozos/." "/usr/share/sddm/themes/slozos/"

cat > /etc/sddm.conf.d/theme.conf << 'EOF'
[Theme]
Current=slozos
EOF

# ── Plymouth boot theme ───────────────────────────────────────────────────────
cp -r "$SLOZOS_CONFIG/plymouth/slozos/." "/usr/share/plymouth/themes/slozos/"

update-alternatives --install \
    /usr/share/plymouth/themes/default.plymouth \
    default.plymouth \
    /usr/share/plymouth/themes/slozos/slozos.plymouth \
    100

update-initramfs -u -k all 2>/dev/null || true

# Fix ownership
chown -R slozos:slozos "$USER_HOME"

echo "[04-theming] Done."
