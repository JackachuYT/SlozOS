// SlozOS default desktop layout — macOS Tahoe style.
// Plasma runs this once when a user's desktop is first created (this package is
// the LookAndFeelPackage in /etc/skel/.config/kdeglobals). firstlogin.sh also
// runs it through evaluateScript as a fallback if another layout got there first.

var WALLPAPER = "file:///usr/share/wallpapers/SlozOS/contents/images/slozos-default.png";

// ── Wallpaper ────────────────────────────────────────────────────────────────
var allDesktops = desktops();
for (var d = 0; d < allDesktops.length; d++) {
    allDesktops[d].wallpaperPlugin = "org.kde.image";
    allDesktops[d].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    allDesktops[d].writeConfig("Image", WALLPAPER);
    allDesktops[d].writeConfig("FillMode", 2);   // scaled & cropped
}

// Start from a clean slate (matters when re-applied over an existing layout)
var existing = panels();
for (var i = 0; i < existing.length; i++) {
    existing[i].remove();
}

// ── Menu bar (top) ───────────────────────────────────────────────────────────
// Laid out like MacTahoe's top bar, plus the macOS menus on the left:
// [SlozOS logo menu] [App menu] ...... [clock] ...... [tray] [Control Center pill]
var menuBar = new Panel;
menuBar.location = "top";
menuBar.height = 2 * Math.round(gridUnit * 0.85);   // ~30 px at 100% scale
menuBar.floating = false;
menuBar.hiding = "none";
menuBar.lengthMode = "fill";

// The SlozOS menu (like the Apple menu): About, Settings, Spotlight, power…
var logoMenu = menuBar.addWidget("org.slozos.logomenu");
logoMenu.currentConfigGroup = ["Shortcuts"];
logoMenu.writeConfig("global", "Alt+F1");

menuBar.addWidget("org.kde.plasma.appmenu");
menuBar.addWidget("org.kde.plasma.panelspacer");

var clock = menuBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", 1);          // beside the time
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");   // "Mon 5 Oct"
clock.writeConfig("showSeconds", 0);                // never
clock.writeConfig("autoFontAndSize", false);
clock.writeConfig("fontWeight", 600);

menuBar.addWidget("org.kde.plasma.panelspacer");

// Wi-Fi, sound, battery, Bluetooth and brightness live in Control Center (its
// menu-bar pill shows their status), so the tray keeps only everything else.
// Hidden items are still one click away in the tray's arrow menu.
var tray = menuBar.addWidget("org.kde.plasma.systemtray");
var trayContainment = desktopById(tray.readConfig("SystrayContainmentId"));
if (trayContainment) {
    trayContainment.currentConfigGroup = ["General"];
    trayContainment.writeConfig("hiddenItems", [
        "org.kde.plasma.networkmanagement",
        "org.kde.plasma.volume",
        "org.kde.plasma.battery",
        "org.kde.plasma.bluetooth",
        "org.kde.plasma.brightness",
        "org.kde.plasma.manage-inputmethod",
        "org.kde.plasma.clipboard"
    ]);
}

menuBar.addWidget("org.slozos.controlcenter");          // Control Center

// The dock is the SlozOS Dock app (slozos-dock), not a Plasma panel.
