// SlozOS Control Center — macOS Tahoe-style quick settings in the menu bar.
// State and actions go through `slozos-cc` (NetworkManager, BlueZ, PowerDevil,
// PipeWire, power-profiles); Focus uses Plasma's own notification settings.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

PlasmoidItem {
    id: root

    property var st: ({ wifi: false, ssid: "", bluetooth: false, airplane: false,
                        brightness: -1, volume: -1, muted: false, profile: "", tablet: "auto" })
    readonly property color accent: "#0A84FF"
    readonly property bool focusOn: notificationSettings.notificationsInhibitedUntil > new Date()

    preferredRepresentation: compactRepresentation
    toolTipMainText: "Control Center"
    toolTipSubText: ""
    Plasmoid.icon: Qt.resolvedUrl("../images/control-center.svg")

    // ── Backend ──────────────────────────────────────────────────────────────
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === "slozos-cc state") {
                try { root.st = JSON.parse(data["stdout"]) } catch (e) {}
            } else {
                refreshSoon.restart()
            }
            disconnectSource(source)
        }
    }
    function refresh() { exec.connectSource("slozos-cc state") }
    function run(args) { exec.connectSource("slozos-cc " + args) }

    Timer { id: refreshSoon; interval: 400; onTriggered: root.refresh() }
    Timer { interval: 2500; repeat: true; running: root.expanded; triggeredOnStart: true; onTriggered: root.refresh() }

    NotificationManager.Settings { id: notificationSettings }
    function setFocus(on) {
        if (on) {
            const until = new Date()
            until.setFullYear(until.getFullYear() + 1)   // until turned off
            notificationSettings.notificationsInhibitedUntil = until
        } else {
            notificationSettings.notificationsInhibitedUntil = new Date(0)
            notificationSettings.revokeApplicationInhibitions()
        }
        notificationSettings.save()
    }

    // ── Menu-bar button ──────────────────────────────────────────────────────
    compactRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: height / 2
            color: root.tint(root.expanded ? 0.18 : (button.containsMouse ? 0.10 : 0))
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(Math.min(parent.width, parent.height) * 0.7)
            height: width
            source: Qt.resolvedUrl("../images/control-center.svg")
            isMask: true
            color: Kirigami.Theme.textColor
        }
    }

    // ── Panel ────────────────────────────────────────────────────────────────
    // Laid out like MacTahoe's Control Center: round shortcut buttons, wide
    // slider bars, and a two-column grid of pill tiles. A tile turns white
    // when its toggle is on.
    function launch(cmd) { exec.connectSource(cmd); root.expanded = false }
    readonly property var profiles: ["power-saver", "balanced", "performance"]
    readonly property var profileNames: ({ "power-saver": "Power Saver", "balanced": "Balanced", "performance": "Performance" })
    readonly property var profileIcons: ({ "power-saver": "battery-profile-powersave-symbolic",
                                           "balanced": "battery-profile-balanced-symbolic",
                                           "performance": "battery-profile-performance-symbolic" })
    readonly property string keyboardCmd: "sh -c 'k=$(gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard --method org.freedesktop.DBus.Properties.Get org.kde.kwin.VirtualKeyboard enabled | grep -q true && echo false || echo true); gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard --method org.freedesktop.DBus.Properties.Set org.kde.kwin.VirtualKeyboard enabled \"<$k>\"'"

    fullRepresentation: Item {
        readonly property real gap: Kirigami.Units.largeSpacing
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: column.implicitHeight + gap * 2
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight

        ColumnLayout {
            id: column
            anchors { fill: parent; margins: parent.gap }
            spacing: parent.gap

            // Shortcut buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Round { icon: "camera-photo-symbolic"; tooltip: "Screenshot"; onClicked: root.launch("spectacle") }
                Round { icon: "preferences-system-symbolic"; tooltip: "System Settings"; onClicked: root.launch("systemsettings") }
                Round { icon: "system-lock-screen-symbolic"; tooltip: "Lock Screen"; onClicked: root.launch("loginctl lock-session") }
                Item { Layout.fillWidth: true }
                Round {
                    icon: "system-shutdown-symbolic"; tooltip: "Power Off…"
                    onClicked: root.launch("gdbus call --session --dest org.kde.LogoutPrompt --object-path /LogoutPrompt --method org.kde.LogoutPrompt.promptAll")
                }
            }

            // Sliders
            SliderBar {
                visible: root.st.volume >= 0
                icon: root.st.muted || root.st.volume === 0 ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                value: root.st.muted ? 0 : root.st.volume
                onMovedTo: v => root.run("volume " + v)
                onIconClicked: root.run("volume mute")
                onMore: root.launch("systemsettings kcm_pulseaudio")
            }
            SliderBar {
                visible: root.st.brightness >= 0
                icon: "brightness-high-symbolic"
                value: root.st.brightness
                onMovedTo: v => root.run("brightness " + v)
                onMore: root.launch("systemsettings kcm_kscreen")
            }

            // Toggles
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: Kirigami.Units.largeSpacing
                columnSpacing: Kirigami.Units.largeSpacing

                Pill {
                    icon: root.st.wifi ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic"
                    title: "Wi-Fi"
                    subtitle: root.st.wifi ? (root.st.ssid || "Not connected") : "Off"
                    checked: root.st.wifi
                    split: true
                    onToggled: root.run("wifi " + (root.st.wifi ? "off" : "on"))
                    onMore: root.launch("systemsettings kcm_networkmanagement")
                }
                Pill {
                    icon: "network-bluetooth-symbolic"
                    title: "Bluetooth"
                    subtitle: root.st.bluetooth ? "On" : "Off"
                    checked: root.st.bluetooth
                    split: true
                    onToggled: root.run("bluetooth " + (root.st.bluetooth ? "off" : "on"))
                    onMore: root.launch("systemsettings kcm_bluetooth")
                }
                Pill {
                    visible: root.st.profile !== ""
                    icon: root.profileIcons[root.st.profile] || "battery-profile-balanced-symbolic"
                    title: "Power Mode"
                    subtitle: root.profileNames[root.st.profile] || ""
                    checked: root.st.profile === "performance"
                    split: true
                    // tap cycles Saver → Balanced → Performance
                    onToggled: root.run("profile " + root.profiles[(root.profiles.indexOf(root.st.profile) + 1) % 3])
                    onMore: root.launch("systemsettings kcm_powerdevilprofilesconfig")
                }
                Pill {
                    icon: "notifications-disabled-symbolic"
                    title: "Focus"
                    subtitle: root.focusOn ? "Do Not Disturb" : ""
                    checked: root.focusOn
                    onToggled: root.setFocus(!root.focusOn)
                }
                Pill {
                    icon: "network-flightmode-on-symbolic"
                    title: "Airplane Mode"
                    checked: root.st.airplane
                    onToggled: root.run("airplane " + (root.st.airplane ? "off" : "on"))
                }
                Pill {
                    icon: "input-keyboard-virtual-symbolic"
                    title: "Keyboard"
                    subtitle: "On-screen"
                    onToggled: root.launch(root.keyboardCmd)
                }
                Pill {
                    icon: "input-tablet-symbolic"
                    title: "Tablet Mode"
                    subtitle: ({ auto: "Automatic", on: "On", off: "Off" })[root.st.tablet] || "Automatic"
                    checked: root.st.tablet === "on"
                    // tap cycles Automatic → On → Off
                    onToggled: root.run("tablet " + ({ auto: "on", on: "off", off: "auto" })[root.st.tablet || "auto"])
                }
                Pill {
                    icon: "input-gaming-symbolic"
                    title: "Game Mode"
                    subtitle: "Big Picture"
                    split: true
                    onToggled: root.launch("steam steam://open/bigpicture")
                    onMore: root.launch("steam")
                }
            }
        }
    }

    // ── Building blocks ──────────────────────────────────────────────────────
    // Colours derive from the theme's text colour, so tiles read as glass on
    // the dark theme and still work on a light one
    readonly property color fg: Kirigami.Theme.textColor
    function tint(a) { return Qt.rgba(fg.r, fg.g, fg.b, a) }
    readonly property real pillHeight: Kirigami.Units.gridUnit * 3.2

    // Liquid-glass surface: translucent fill, a brighter top edge, hairline border
    component Glass: Rectangle {
        property bool lit: false                    // white "on" state
        property bool hovered: false
        radius: height / 2
        color: lit ? Qt.rgba(1, 1, 1, 0.94) : root.tint(hovered ? 0.16 : 0.10)
        border.color: lit ? "transparent" : root.tint(0.14)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {                                 // specular highlight
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
            height: parent.height / 2
            radius: parent.radius
            visible: !parent.lit
            gradient: Gradient {
                GradientStop { position: 0; color: root.tint(0.08) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    component Round: Glass {
        id: round
        property string icon
        property string tooltip
        signal clicked
        implicitWidth: Kirigami.Units.gridUnit * 2.4
        implicitHeight: implicitWidth
        hovered: roundMouse.containsMouse
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: round.icon
            isMask: true
            color: root.fg
        }
        MouseArea { id: roundMouse; anchors.fill: parent; hoverEnabled: true; onClicked: round.clicked() }
        PlasmaComponents.ToolTip { text: round.tooltip; visible: round.tooltip !== "" && roundMouse.containsMouse }
    }

    component Chevron: Kirigami.Icon {
        property color tone: root.fg
        implicitWidth: Kirigami.Units.iconSizes.small
        implicitHeight: implicitWidth
        source: "go-next-symbolic"
        isMask: true
        color: tone
        opacity: 0.8
    }

    // split: the round icon toggles and the rest of the tile opens more
    // settings (Wi-Fi, Bluetooth…). Otherwise the whole tile is one toggle.
    component Pill: Glass {
        id: pill
        property string icon
        property string title
        property string subtitle
        property bool checked
        property bool split: false
        signal toggled
        signal more
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: root.pillHeight
        lit: checked && !split
        hovered: pillMouse.containsMouse
        readonly property color ink: lit ? root.accent : root.fg

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: pill.split ? pill.more() : pill.toggled()
        }
        RowLayout {
            anchors { fill: parent; leftMargin: Kirigami.Units.smallSpacing * 2; rightMargin: Kirigami.Units.largeSpacing }
            spacing: Kirigami.Units.smallSpacing * 2
            Rectangle {                             // icon circle
                Layout.preferredWidth: pill.height - Kirigami.Units.smallSpacing * 4
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: pill.split && pill.checked ? Qt.rgba(1, 1, 1, 0.94)
                     : pill.split ? root.tint(iconMouse.containsMouse ? 0.22 : 0.14) : "transparent"
                Behavior on color { ColorAnimation { duration: 140 } }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    source: pill.icon
                    isMask: true
                    color: pill.split && pill.checked ? root.accent : pill.ink
                }
                MouseArea {
                    id: iconMouse
                    anchors.fill: parent
                    enabled: pill.split
                    hoverEnabled: true
                    onClicked: pill.toggled()
                }
            }
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: pill.title; color: pill.ink; font.weight: Font.DemiBold
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    visible: text !== ""
                    text: pill.subtitle; color: pill.ink; opacity: 0.65; font: Kirigami.Theme.smallFont
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
            }
            Chevron { visible: pill.split; tone: pill.ink }
        }
    }

    component SliderBar: Glass {
        id: bar
        property string icon
        property int value
        signal movedTo(int v)
        signal iconClicked
        signal more
        Layout.fillWidth: true
        implicitHeight: root.pillHeight
        RowLayout {
            anchors { fill: parent; leftMargin: Kirigami.Units.largeSpacing * 1.5; rightMargin: Kirigami.Units.largeSpacing }
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                source: bar.icon
                isMask: true
                color: root.fg
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                MouseArea { anchors.fill: parent; onClicked: bar.iconClicked() }
            }
            PlasmaComponents.Slider {
                id: slider
                Layout.fillWidth: true
                from: 0; to: 100; stepSize: 1
                onMoved: debounce.restart()
                // follow the system value, except while the user is dragging
                Binding on value { value: bar.value; when: !slider.pressed }
                Timer { id: debounce; interval: 120; onTriggered: bar.movedTo(Math.round(slider.value)) }
            }
            Chevron {
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: bar.more() }
            }
        }
    }
}
