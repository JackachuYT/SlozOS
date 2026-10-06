// SlozOS Welcome — the first-run setup assistant.
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Window {
    id: root
    width: 900
    height: 620
    minimumWidth: 820
    minimumHeight: 580
    visible: true
    title: "Welcome to SlozOS"
    color: "#1c1c1e"

    property int page: 0
    readonly property int pageCount: 5
    readonly property color accent: "#0A84FF"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.6)
    readonly property string font: "Inter"
    readonly property string version: Sys.os["SLOZOS_VERSION"] || ""
    readonly property string edition: Sys.os["SLOZOS_EDITION"] || "Standard"

    function finish() { Sys.markDone(); Qt.quit() }

    // ── Pages ────────────────────────────────────────────────────────────────
    Item {
        id: pages
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: bar.top }

        // 0 — Hello
        Page_ {
            index: 0
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 18
                Image {
                    source: "file:///usr/share/pixmaps/slozos-logo-white.png"
                    sourceSize: Qt.size(220, 220)
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 180
                    fillMode: Image.PreserveAspectFit
                    Layout.alignment: Qt.AlignHCenter
                }
                Heading { text: "Welcome to SlozOS"; Layout.alignment: Qt.AlignHCenter }
                Body {
                    text: "SlozOS " + root.version + " · " + root.edition + " Edition"
                    Layout.alignment: Qt.AlignHCenter
                }
                Body {
                    text: "Let's get your PC set up — it only takes a minute."
                    color: root.dim
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // 1 — Make it yours
        Page_ {
            index: 1
            ColumnLayout {
                anchors { fill: parent; margins: 48 }
                spacing: 16
                Heading { text: "Make it yours" }
                Body { text: "Pick a wallpaper. You can change it any time in System Settings."; color: root.dim }
                GridView {
                    id: wallGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: Math.floor(width / 4)
                    cellHeight: cellWidth * 0.66
                    model: Sys.wallpapers()
                    property string chosen: ""
                    delegate: Item {
                        id: wall
                        required property var modelData
                        width: wallGrid.cellWidth
                        height: wallGrid.cellHeight
                        Rectangle {
                            anchors { fill: parent; margins: 6 }
                            radius: 14
                            color: "#2c2c2e"
                            border.width: wallGrid.chosen === wall.modelData.path ? 3 : 0
                            border.color: root.accent
                            clip: true
                            Image {
                                anchors { fill: parent; margins: parent.border.width }
                                source: "file://" + wall.modelData.path
                                sourceSize: Qt.size(320, 200)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wallGrid.chosen = wall.modelData.path
                                Sys.runAsync("wallpaper", "plasma-apply-wallpaperimage '" + wall.modelData.path.replace(/'/g, "") + "'")
                            }
                        }
                    }
                }
                SwitchRow {
                    title: "Hide the dock when a window needs the space"
                    subtitle: "Recommended on small screens and tablets"
                    checked: true
                    // the SlozOS Dock watches this file and applies it at once
                    onToggled: on => Sys.runAsync("dock",
                        "kwriteconfig6 --file \"$HOME/.config/slozos/dockrc\" --group General --key autoHide " + (on ? "true" : "false"))
                }
            }
        }

        // 2 — Apps & games
        Page_ {
            index: 2
            ColumnLayout {
                anchors { fill: parent; margins: 48 }
                spacing: 12
                Heading { text: "Apps & games" }
                Body { text: "Get the essentials in one click. Everything else is in Bazaar, your app store."; color: root.dim }
                ListView {
                    id: appList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: ListModel {
                        ListElement { appId: "steam";                            name: "Steam";            desc: "Your games library";                          icon: "steam" }
                        ListElement { appId: "org.prismlauncher.PrismLauncher";  name: "Prism Launcher";   desc: "Minecraft, tuned for SlozOS";           icon: "org.prismlauncher.PrismLauncher" }
                        ListElement { appId: "com.discordapp.Discord";           name: "Discord";          desc: "Chat with friends";                           icon: "com.discordapp.Discord" }
                        ListElement { appId: "com.heroicgameslauncher.hgl";      name: "Heroic";           desc: "Epic Games, GOG and Amazon games";            icon: "com.heroicgameslauncher.hgl" }
                        ListElement { appId: "org.libretro.RetroArch";           name: "RetroArch";        desc: "Retro consoles — perfect for this hardware";  icon: "org.libretro.RetroArch" }
                        ListElement { appId: "com.spotify.Client";               name: "Spotify";          desc: "Music";                                       icon: "com.spotify.Client" }
                        ListElement { appId: "org.videolan.VLC";                 name: "VLC";              desc: "Plays any video file";                        icon: "vlc" }
                    }
                    delegate: Rectangle {
                        id: app
                        required property string appId
                        required property string name
                        required property string desc
                        required property string icon
                        // "installed" | "get" | "installing" | "failed"
                        property string status: "get"
                        width: appList.width
                        height: 62
                        radius: 14
                        color: "#2c2c2e"
                        Component.onCompleted: status = (appId === "steam"
                            ? Sys.succeeds("command -v steam")
                            : Sys.succeeds("flatpak info " + appId)) ? "installed" : "get"
                        Connections {
                            target: Sys
                            function onFinished(id, code, output) {
                                if (id === "install:" + app.appId)
                                    app.status = code === 0 ? "installed" : "failed"
                            }
                        }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            spacing: 14
                            Kirigami.Icon {
                                source: app.icon
                                fallback: "applications-games"
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                            }
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Body { text: app.name; font.weight: Font.DemiBold; Layout.fillWidth: true }
                                Body { text: app.desc; color: root.dim; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            QQC2.BusyIndicator { visible: app.status === "installing"; running: visible; Layout.preferredWidth: 28; Layout.preferredHeight: 28 }
                            Body {
                                visible: app.status === "installed" || app.status === "failed"
                                text: app.status === "installed" ? "✓ Installed" : "Couldn't install"
                                color: app.status === "installed" ? "#32D74B" : "#FF453A"
                            }
                            Pill {
                                visible: app.status === "get"
                                text: "Get"
                                onClicked: {
                                    app.status = "installing"
                                    Sys.runAsync("install:" + app.appId,
                                                 "flatpak install -y --noninteractive --system flathub " + app.appId)
                                }
                            }
                        }
                    }
                }
            }
        }

        // 3 — Performance
        Page_ {
            index: 3
            ColumnLayout {
                anchors { fill: parent; margins: 48 }
                spacing: 16
                Heading { text: "Performance" }
                Body {
                    text: "SlozOS has already tuned itself for this PC. Two more choices:"
                    color: root.dim
                }
                SwitchRow {
                    title: "SlozOS Performance Mode"
                    subtitle: "More FPS in games and Minecraft by turning off CPU security mitigations (Spectre/Meltdown). " +
                              "Biggest gains on older Intel CPUs, but less protected against malicious code. Takes effect after a restart."
                    checked: Sys.succeeds("slozos-performance-mode status")
                    onToggled: on => Sys.runAsync("perf", "slozos-performance-mode " + (on ? "on" : "off"))
                }
                SwitchRow {
                    title: "Open Steam when I log in"
                    subtitle: "Handy if you game a lot — but Steam uses a few hundred MB of memory in the background. " +
                              "SlozOS picks a default for this PC; your choice here overrides it."
                    // the user's saved choice, else the default for this PC's profile (see slozos-session)
                    checked: Sys.succeeds("p=$HOME/.config/slozos/steam-at-login; " +
                                          "[ \"$(cat $p 2>/dev/null)\" = on ] || { [ ! -s $p ] && [ \"$(cat /run/slozos/profile 2>/dev/null)\" != light ]; }")
                    onToggled: on => Sys.runAsync("steam", "mkdir -p $HOME/.config/slozos && echo " + (on ? "on" : "off") +
                                                          " > $HOME/.config/slozos/steam-at-login")
                }
                Item { Layout.fillHeight: true }
            }
        }

        // 4 — Done
        Page_ {
            index: 4
            ColumnLayout {
                anchors.centerIn: parent
                width: 560
                spacing: 18
                Heading { text: "You're all set"; Layout.alignment: Qt.AlignHCenter }
                Body { text: "A few things to try:"; color: root.dim; Layout.alignment: Qt.AlignHCenter }
                Repeater {
                    model: [ { icon: "search", text: "Press Meta + Space for Spotlight — search apps, files, settings and your clipboard" },
                             { icon: "view-app-grid", text: "Apps on the left of the dock shows every app" },
                             { icon: "configure", text: "Control Center, next to the clock: Wi-Fi, Bluetooth, brightness, sound" },
                             { icon: "file:///usr/share/pixmaps/slozos-logo-symbolic.png", text: "Click the sloth in the top-left for About, Settings, Sleep and Restart" } ]
                    delegate: RowLayout {
                        required property var modelData
                        spacing: 14
                        Layout.fillWidth: true
                        Kirigami.Icon { source: modelData.icon; Layout.preferredWidth: 32; Layout.preferredHeight: 32 }
                        Body { text: modelData.text; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    }
                }
                Pill {
                    text: "SlozOS Help"
                    secondary: true
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: Sys.openUrl("https://github.com/JackachuYT/SlozOS#readme")
                }
            }
        }
    }

    // ── Bottom bar: dots · Back · Continue ───────────────────────────────────
    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 76
        color: "#232325"
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        Row {
            anchors { left: parent.left; leftMargin: 32; verticalCenter: parent.verticalCenter }
            spacing: 8
            Repeater {
                model: root.pageCount
                delegate: Rectangle {
                    required property int index
                    width: index === root.page ? 22 : 8
                    height: 8
                    radius: 4
                    color: index === root.page ? root.accent : Qt.rgba(1, 1, 1, 0.25)
                    Behavior on width { NumberAnimation { duration: 160 } }
                }
            }
        }
        Row {
            anchors { right: parent.right; rightMargin: 32; verticalCenter: parent.verticalCenter }
            spacing: 12
            Pill { text: "Back"; secondary: true; visible: root.page > 0; onClicked: root.page-- }
            Pill {
                text: root.page === 0 ? "Get Started" : root.page === root.pageCount - 1 ? "Start Using SlozOS" : "Continue"
                onClicked: root.page < root.pageCount - 1 ? root.page++ : root.finish()
            }
        }
    }

    // ── Building blocks ──────────────────────────────────────────────────────
    component Page_: Item {
        property int index
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.page === index ? 1 : 0
        x: root.page === index ? 0 : (root.page > index ? -40 : 40)
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    component Heading: Text {
        color: "white"
        font { family: root.font; pixelSize: 34; weight: Font.Bold }
    }

    component Body: Text {
        color: "white"
        font { family: root.font; pixelSize: 15 }
    }

    component Pill: Rectangle {
        id: pill
        property string text
        property bool secondary: false
        signal clicked
        implicitWidth: label.implicitWidth + 44
        implicitHeight: 40
        width: implicitWidth
        height: implicitHeight
        radius: 20
        color: secondary ? Qt.rgba(1, 1, 1, pillMouse.containsMouse ? 0.18 : 0.12)
                         : (pillMouse.containsMouse ? Qt.lighter(root.accent, 1.12) : root.accent)
        Text {
            id: label
            anchors.centerIn: parent
            text: pill.text
            color: "white"
            font { family: root.font; pixelSize: 15; weight: Font.DemiBold }
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component SwitchRow: Rectangle {
        id: row
        property string title
        property string subtitle
        property alias checked: sw.checked
        signal toggled(bool on)
        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + 28
        radius: 14
        color: "#2c2c2e"
        RowLayout {
            id: rowLayout
            anchors { fill: parent; margins: 14; leftMargin: 18 }
            spacing: 16
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Body { text: row.title; font.weight: Font.DemiBold }
                Body { text: row.subtitle; color: root.dim; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
            QQC2.Switch { id: sw; onToggled: row.toggled(checked) }
        }
    }
}
