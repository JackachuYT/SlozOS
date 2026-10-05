#!/usr/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# SlozOS identity + update channel. Sourced by slozos-desktop.sh.
#
# Makes the system know it is SlozOS — not Bazzite — everywhere it matters:
#   • updates come from ghcr.io/jackachuyt/slozos-<edition> (never ublue-os)
#   • os-release / boot menu / image-info.json say SlozOS
#   • Bazzite's Portal, Documentation, updater, rebase helper and news popups
#     are replaced with SlozOS versions (or hidden)
# Needs: CTX SRC merge SLOZOS_IMAGE SLOZOS_VERSION SLOZOS_EDITION SLOZOS_NAME
#        SLOZOS_PRETTY_NAME SLOZOS_HOSTNAME
# ──────────────────────────────────────────────────────────────────────────────
: "${SLOZOS_IMAGE:?}"
FEDORA_VERSION=$(. /usr/lib/os-release && echo "$VERSION_ID")
IMAGE_NAME=${SLOZOS_IMAGE##*/}                       # slozos-sp2
GH=https://github.com/JackachuYT/SlozOS

# ── Update channel ───────────────────────────────────────────────────────────
mkdir -p /usr/share/slozos
echo "$SLOZOS_IMAGE:stable" > /usr/share/slozos/image-ref
install -Dm755 "$CTX/config/slozos/slozos-update"                 /usr/bin/slozos-update
install -Dm755 "$CTX/config/slozos/slozos-update-origin"          /usr/libexec/slozos-update-origin
install -Dm644 "$CTX/config/slozos/slozos-update-origin.service"  /usr/lib/systemd/system/slozos-update-origin.service
systemctl enable slozos-update-origin.service

# Bazzite's rollback/rebase helper only knows Bazzite images; route it to ours
ln -sf slozos-update /usr/bin/bazzite-rollback-helper
ln -sf slozos-update /usr/bin/brh

# Universal Blue tools (motd, ujust, rebase helpers) read this to know "which
# image am I" — make them see SlozOS.
python3 - "$IMAGE_NAME" "$SLOZOS_IMAGE" "$SLOZOS_VERSION" <<'EOF'
import json, sys
path = "/usr/share/ublue-os/image-info.json"
name, image, version = sys.argv[1:]
try:
    info = json.load(open(path))
except (OSError, ValueError):
    info = {}
info.update({
    "image-name": name,
    "image-vendor": image.split("/")[1],
    "image-ref": "ostree-unverified-registry:" + image,
    "image-tag": "stable",
    "image-branch": "stable",
    "version": version,
    "version-pretty": "SlozOS " + version,
})
json.dump(info, open(path, "w"), indent=2)
EOF

# ── os-release / boot menu ───────────────────────────────────────────────────
# ID stays "bazzite" and VERSION_ID stays the Fedora release: Bazzite's tools,
# rpm-ostree and bootc-image-builder all key off those.
sed -i \
    -e "s/^NAME=.*/NAME=\"$SLOZOS_NAME\"/" \
    -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"$SLOZOS_PRETTY_NAME\"/" \
    -e "s/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME=\"$SLOZOS_HOSTNAME\"/" \
    -e "s/^VARIANT_ID=.*/VARIANT_ID=$IMAGE_NAME/" \
    -e "s|^HOME_URL=.*|HOME_URL=\"$GH\"|" \
    -e "s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL=\"$GH#readme\"|" \
    -e "s|^SUPPORT_URL=.*|SUPPORT_URL=\"$GH/issues\"|" \
    -e "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"$GH/issues\"|" \
    -e "s/^LOGO=.*/LOGO=slozos-logo/" \
    -e "s/^BOOTLOADER_NAME=.*/BOOTLOADER_NAME=\"SlozOS $SLOZOS_VERSION\"/" \
    -e "/^SLOZOS_/d" \
    /usr/lib/os-release
grep -q '^BOOTLOADER_NAME=' /usr/lib/os-release || echo "BOOTLOADER_NAME=\"SlozOS $SLOZOS_VERSION\"" >> /usr/lib/os-release
printf 'SLOZOS_VERSION="%s"\nSLOZOS_EDITION="%s"\nSLOZOS_IMAGE="%s"\n' \
    "$SLOZOS_VERSION" "$SLOZOS_EDITION" "$SLOZOS_IMAGE" >> /usr/lib/os-release
echo "SlozOS release $FEDORA_VERSION" > /etc/system-release
echo "$SLOZOS_HOSTNAME" > /etc/hostname
install -Dm644 "$CTX/assets/logo/slozos-logo.png" /usr/share/icons/hicolor/512x512/apps/slozos-logo.png

# "About this System": "SlozOS 1.4", "Standard Edition · Bazzite 44"
cat > "$SRC/kcm-about-distrorc" <<EOF
[General]
LogoPath=/usr/share/pixmaps/slozos-logo-white.png
Name=SlozOS
Version=$SLOZOS_VERSION
Variant=$SLOZOS_EDITION Edition · Bazzite $FEDORA_VERSION
Website=$GH
EOF
merge /etc/xdg/kcm-about-distrorc "$SRC/kcm-about-distrorc"

# ── SlozOS Portal (replaces Bazzite Portal) ──────────────────────────────────
# Same app (yafti) and the same useful installers/tweaks, but SlozOS's welcome
# page, SlozOS naming, and none of the buttons that rebase onto Bazzite.
if [[ -f /usr/share/yafti/yafti.yml ]]; then
python3 - "$GH" <<'EOF'
import sys, yaml
gh = sys.argv[1]
path = "/usr/share/yafti/yafti.yml"
cfg = yaml.safe_load(open(path))

def rename(text):
    return (text.replace("Bazzite Portal", "SlozOS Portal")
                .replace("Bazzite Updater", "SlozOS Updater")
                .replace("Update Bazzite", "Update SlozOS")
                .replace("Manage Bazzite", "Manage SlozOS"))

DANGEROUS = ("brh rebase", "verify-image", "rebase-helper", "rpm-ostree rebase", "bootc switch")
def safe(action):
    scripts = [action.get("script", "")] + [o.get("script", "") for o in action.get("options", []) or []]
    return not any(d in s for s in scripts for d in DANGEROUS)

cfg["title"] = "SlozOS Portal"
welcome = {
    "title": "Welcome!",
    "description": "Get to know SlozOS",
    "hidden": True,
    "actions": [
        {"id": "slozos-help", "title": "Read the SlozOS guide", "default": False,
         "description": "How to install, update and get the most out of SlozOS.",
         "script": f"xdg-open {gh}#readme"},
        {"id": "bazaar", "title": "Browse your Bazaar", "default": False,
         "description": "Your app store — Discord, Heroic Games Launcher, emulators and more.",
         "script": "nohup setsid gtk4-launch io.github.kolunmi.Bazaar >&/dev/null"},
        {"id": "slozos-update", "title": "Update SlozOS", "default": False,
         "description": "Get the latest SlozOS version, plus app and driver updates.",
         "script": "slozos-update; status=$?; echo; echo \"Press Enter to close...\"; read -r _; exit $status"},
        {"id": "slozos-issues", "title": "Report a problem", "default": False,
         "description": "Something not working on your PC? Let us know on GitHub.",
         "script": f"xdg-open {gh}/issues"},
    ],
}
screens = []
for screen in cfg.get("screens", []):
    if screen.get("title") == "Welcome!":
        screens.append(welcome)
        continue
    screen["title"] = rename(screen.get("title", ""))
    screen["description"] = rename(screen.get("description", ""))
    actions = []
    for a in screen.get("actions", []) or []:
        if not safe(a):
            continue
        a["title"] = rename(a.get("title", ""))
        a["description"] = rename(a.get("description", ""))
        for o in a.get("options", []) or []:
            o["label"] = rename(o.get("label", ""))
        actions.append(a)
    screen["actions"] = actions
    screens.append(screen)
cfg["screens"] = screens
yaml.safe_dump(cfg, open(path, "w"), sort_keys=False, allow_unicode=True, width=1000)
EOF
fi

# App menu / autostart entries: Bazzite-named apps become SlozOS-named
for f in /usr/share/applications/*.desktop /etc/skel/.config/autostart/*.desktop /etc/xdg/autostart/*.desktop; do
    [[ -f $f ]] || continue
    sed -i -E 's/^(Name(\[[^]]*\])?=)Bazzite /\1SlozOS /' "$f"
done
# …and the Portal's description ("Helps you setup Bazzite")
for f in $(grep -l '^Name=SlozOS Portal' /usr/share/applications/*.desktop 2>/dev/null); do
    sed -i -E '/^Comment(\[[^]]*\])?=/ s/Bazzite/SlozOS/g' "$f"
done
install -Dm644 "$CTX/config/slozos/org.slozos.help.desktop"    /usr/share/applications/org.slozos.help.desktop

# SlozOS Updater (built in the apps stage from Bazzite's updater): SlozOS
# release notes, rollback via slozos-update, Bazzite-only rebase page off
install -Dm644 "$CTX/config/slozos/updater/config.ini" /etc/bazzite-updater/config.ini
sed "s/@SLOZOS_VERSION@/$SLOZOS_VERSION/" "$CTX/config/slozos/updater/KAboutData_OS.json" \
    > /etc/bazzite-updater/KAboutData_OS.json

# Hide Bazzite's own docs/forum shortcuts (SlozOS Help replaces them) and its
# news popups (they announce Bazzite releases, not SlozOS ones)
set_desktop_key() {  # set_desktop_key FILE KEY VALUE — inside [Desktop Entry]
    [[ -f $1 ]] || return 0
    if grep -q "^$2=" "$1"; then sed -i "s/^$2=.*/$2=$3/" "$1"
    else sed -i "/^\[Desktop Entry\]/a $2=$3" "$1"; fi
}
set_desktop_key /usr/share/applications/bazzite-documentation.desktop NoDisplay true
set_desktop_key /usr/share/applications/discourse.desktop             NoDisplay true
set_desktop_key /etc/xdg/autostart/bazzite-announcement.desktop       Hidden    true

# Terminal welcome banner and `ujust changelogs`
if [[ -d /usr/share/ublue-os/motd ]]; then install -m644 "$CTX/config/slozos/motd-template.md" /usr/share/ublue-os/motd/template.md; fi
for f in /usr/share/ublue-os/just/*.just; do
    [[ -f $f ]] || continue
    sed -i 's|repos/ublue-os/bazzite/releases|repos/JackachuYT/SlozOS/releases|g' "$f"
done
:
