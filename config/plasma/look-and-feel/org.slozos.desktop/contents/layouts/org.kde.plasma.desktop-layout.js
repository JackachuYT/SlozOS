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
// [SlozOS logo menu] [App menu (global menu)] ........ [tray] [Control Center] [clock]
var menuBar = new Panel;
menuBar.location = "top";
menuBar.height = 2 * Math.round(gridUnit * 0.75);   // ~26 px at 100% scale
menuBar.floating = false;
menuBar.hiding = "none";
menuBar.lengthMode = "fill";

// The SlozOS menu (like the Apple menu): About, Settings, Spotlight, power…
var logoMenu = menuBar.addWidget("org.slozos.logomenu");
logoMenu.currentConfigGroup = ["Shortcuts"];
logoMenu.writeConfig("global", "Alt+F1");

menuBar.addWidget("org.kde.plasma.appmenu");
menuBar.addWidget("org.kde.plasma.panelspacer");

var tray = menuBar.addWidget("org.kde.plasma.systemtray");
menuBar.addWidget("org.slozos.controlcenter");          // Control Center

var clock = menuBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", 1);          // beside the time
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");   // "Mon 5 Oct"
clock.writeConfig("showSeconds", 0);                // never
clock.writeConfig("autoFontAndSize", false);
clock.writeConfig("fontWeight", 500);

// ── Dock (bottom, floating, hugs its icons) ──────────────────────────────────
// [Apps] [pinned apps + running apps] | [Trash]   (Apps opens Spotlight's app grid, like Tahoe)
var dock = new Panel;
dock.location = "bottom";
dock.height = 2 * Math.round(gridUnit * 1.6);       // ~58 px at 100% scale
dock.floating = true;
dock.lengthMode = "fit";
dock.alignment = "center";
// Small screens: tuck the dock away when a window would overlap it
dock.hiding = "dodgewindows";

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.slozos.apps.desktop",
    "preferred://filemanager",
    "preferred://browser",
    "applications:steam.desktop",
    "applications:net.lutris.Lutris.desktop",
    "applications:io.github.kolunmi.Bazaar.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop"
]);
tasks.writeConfig("showOnlyCurrentScreen", false);
tasks.writeConfig("showOnlyCurrentDesktop", false);
tasks.writeConfig("showOnlyCurrentActivity", false);
tasks.writeConfig("groupingStrategy", 1);           // one icon per app, like the Dock
tasks.writeConfig("indicateAudioStreams", true);
tasks.writeConfig("iconSpacing", 1);
tasks.writeConfig("maxStripes", 1);

dock.addWidget("org.kde.plasma.marginsseparator");
dock.addWidget("org.kde.plasma.trash");
