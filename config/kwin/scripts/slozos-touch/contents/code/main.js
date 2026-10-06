// SlozOS touchscreen edge swipes. (Swipe up from the bottom edge for Overview
// is set in kwinrc: [Effect-overview] TouchBorderActivate.)
registerTouchScreenEdge(KWin.ElectricLeft, function () {
    callDBus("org.slozos.Spotlight", "/Spotlight", "org.slozos.Spotlight", "ShowApps");
});
