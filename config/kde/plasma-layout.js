// SlozOS Plasma Layout
// macOS Tahoe-inspired: slim top bar + floating bottom dock

var desktops = desktopsForActivity(currentActivity());
for (var d in desktops) {
    desktops[d].wallpaperPlugin = "org.kde.image";
    desktops[d].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktops[d].writeConfig("Image", "file:///usr/share/slozos/wallpapers/slozos-default.png");
    desktops[d].writeConfig("FillMode", 2);   // 2 = scaled+cropped
}

// Remove all existing panels
var existingPanels = panels();
for (var i = 0; i < existingPanels.length; i++) {
    existingPanels[i].remove();
}

// ── Top menu bar ─────────────────────────────────────────────────────────────
var topBar = new Panel;
topBar.location    = "top";
topBar.height      = 26;
topBar.floating    = false;
topBar.maximumLength = screenGeometry(0).width;
topBar.minimumLength = screenGeometry(0).width;
topBar.opacity     = 0.75;

var appMenu = topBar.addWidget("org.kde.plasma.appmenu");
var spacer1 = topBar.addWidget("org.kde.plasma.spacer");
var clock   = topBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["General"];
clock.writeConfig("showDate", false);
clock.writeConfig("showSeconds", false);
var spacer2 = topBar.addWidget("org.kde.plasma.spacer");
var tray    = topBar.addWidget("org.kde.plasma.systemtray");

// ── Bottom floating dock ──────────────────────────────────────────────────────
var dock = new Panel;
dock.location      = "bottom";
dock.height        = 62;
dock.floating      = true;
dock.alignment     = "center";
dock.maximumLength = 800;
dock.minimumLength = 200;
dock.opacity       = 0.82;

var taskbar = dock.addWidget("org.kde.plasma.icontasks");
taskbar.currentConfigGroup = ["General"];
taskbar.writeConfig("launchers", [
    "applications:org.kde.konsole.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop",
    "applications:steam.desktop",
    "applications:retroarch.desktop",
    "applications:lutris.desktop",
    "applications:org.kde.discover.desktop",
].join(","));
taskbar.writeConfig("showOnlyCurrentScreen",   false);
taskbar.writeConfig("showOnlyCurrentActivity", false);
taskbar.writeConfig("middleClickAction",       "NewInstance");
taskbar.writeConfig("iconSize",                4);
