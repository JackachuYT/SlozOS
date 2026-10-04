#!/usr/bin/bash
# SlozOS first-login fallback.
# Plasma normally builds the menu bar + dock from the SlozOS global theme's
# layout.js when a new user's desktop is created. If something else (a distro
# default, a restored backup) created the desktop first, apply it here once.
STAMP="${XDG_CONFIG_HOME:-$HOME/.config}/slozos-firstlogin-done"
[ -f "$STAMP" ] && exit 0

LAYOUT=/usr/share/plasma/look-and-feel/org.slozos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
APPLETSRC="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc"

# Fedora ships qdbus as qdbus-qt6; plain `qdbus` doesn't exist there.
QDBUS=$(command -v qdbus-qt6 || command -v qdbus6 || command -v qdbus || echo /usr/lib64/qt6/bin/qdbus)

# Wait (up to 60 s) for plasmashell to come up on D-Bus instead of guessing.
for _ in $(seq 60); do
    "$QDBUS" org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 && break
    sleep 1
done

# The global menu applet only exists in our layout — if it's there, we're done.
if ! grep -q 'plugin=org.kde.plasma.appmenu' "$APPLETSRC" 2>/dev/null; then
    "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$LAYOUT")" \
        || exit 1   # leave no stamp so it retries next login
fi

touch "$STAMP"
