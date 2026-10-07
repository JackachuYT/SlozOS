// SlozOS: tidy the system tray. Wi-Fi, sound, battery, Bluetooth and brightness
// live in Control Center (its menu-bar pill shows their status), so the tray
// hides them — they stay one click away in the tray's arrow menu.
// Run by slozos-session once per account, after Plasma is up: when the layout
// script runs, the tray hasn't created its own settings yet.
var HIDE = [
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.battery",
    "org.kde.plasma.bluetooth",
    "org.kde.plasma.brightness",
    "org.kde.plasma.manage-inputmethod",
    "org.kde.plasma.clipboard"
];
panels().forEach(function (panel) {
    panel.widgets("org.kde.plasma.systemtray").forEach(function (tray) {
        tray.currentConfigGroup = [];
        var tc = desktopById(tray.readConfig("SystrayContainmentId"));
        if (!tc) return;
        tc.currentConfigGroup = ["General"];
        var hidden = tc.readConfig("hiddenItems", []);
        HIDE.forEach(function (id) { if (hidden.indexOf(id) < 0) hidden.push(id); });
        tc.writeConfig("hiddenItems", hidden);
        tc.reloadConfig();
    });
});
