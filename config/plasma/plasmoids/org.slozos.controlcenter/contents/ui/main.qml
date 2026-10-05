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
                        brightness: -1, volume: -1, muted: false, profile: "" })
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
    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 21
        Layout.preferredHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight

        ColumnLayout {
            id: column
            anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
            spacing: Kirigami.Units.largeSpacing

            // Connectivity + Focus/Power
            RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Layout.fillWidth: true

                Tile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: connCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                    ColumnLayout {
                        id: connCol
                        anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
                        spacing: Kirigami.Units.largeSpacing
                        ToggleRow {
                            icon: root.st.wifi ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic"
                            title: "Wi-Fi"
                            subtitle: root.st.wifi ? (root.st.ssid || "Not connected") : "Off"
                            checked: root.st.wifi
                            onToggled: root.run("wifi " + (root.st.wifi ? "off" : "on"))
                        }
                        ToggleRow {
                            icon: "network-bluetooth-symbolic"
                            title: "Bluetooth"
                            subtitle: root.st.bluetooth ? "On" : "Off"
                            checked: root.st.bluetooth
                            onToggled: root.run("bluetooth " + (root.st.bluetooth ? "off" : "on"))
                        }
                        ToggleRow {
                            icon: "network-flightmode-on-symbolic"
                            title: "Airplane Mode"
                            subtitle: root.st.airplane ? "On" : "Off"
                            checked: root.st.airplane
                            onToggled: root.run("airplane " + (root.st.airplane ? "off" : "on"))
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Kirigami.Units.largeSpacing

                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredHeight: focusRow.implicitHeight + Kirigami.Units.largeSpacing * 2
                        ToggleRow {
                            id: focusRow
                            anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
                            icon: "notifications-disabled-symbolic"
                            title: "Focus"
                            subtitle: root.focusOn ? "Do Not Disturb" : "Off"
                            checked: root.focusOn
                            onToggled: root.setFocus(!root.focusOn)
                        }
                    }

                    Tile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.st.profile !== ""
                        ColumnLayout {
                            anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
                            spacing: Kirigami.Units.smallSpacing
                            PlasmaComponents.Label { text: "Power Mode"; font.weight: Font.DemiBold }
                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Repeater {
                                    model: [ { id: "power-saver", icon: "battery-profile-powersave-symbolic", label: "Saver" },
                                             { id: "balanced",    icon: "battery-profile-balanced-symbolic",  label: "Balanced" },
                                             { id: "performance", icon: "battery-profile-performance-symbolic", label: "Boost" } ]
                                    delegate: Round {
                                        required property var modelData
                                        icon: modelData.icon
                                        checked: root.st.profile === modelData.id
                                        tooltip: modelData.label
                                        onClicked: root.run("profile " + modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Display
            Tile {
                Layout.fillWidth: true
                Layout.preferredHeight: displayCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                visible: root.st.brightness >= 0
                SliderBlock {
                    id: displayCol
                    anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
                    title: "Display"
                    icon: "brightness-high-symbolic"
                    value: root.st.brightness
                    onMovedTo: v => root.run("brightness " + v)
                }
            }

            // Sound
            Tile {
                Layout.fillWidth: true
                Layout.preferredHeight: soundCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                visible: root.st.volume >= 0
                SliderBlock {
                    id: soundCol
                    anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
                    title: "Sound"
                    icon: root.st.muted || root.st.volume === 0 ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                    value: root.st.volume
                    onMovedTo: v => root.run("volume " + v)
                    onIconClicked: root.run("volume mute")
                }
            }

            // Quick actions
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: [ { icon: "spectacle", label: "Screenshot", cmd: "spectacle" },
                             { icon: "input-keyboard-virtual", label: "Keyboard",
                               cmd: "sh -c 'k=$(gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard --method org.freedesktop.DBus.Properties.Get org.kde.kwin.VirtualKeyboard enabled | grep -q true && echo false || echo true); gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard --method org.freedesktop.DBus.Properties.Set org.kde.kwin.VirtualKeyboard enabled \"<$k>\"'" },
                             { icon: "preferences-desktop-display", label: "Displays", cmd: "systemsettings kcm_kscreen" },
                             { icon: "preferences-system", label: "Settings", cmd: "systemsettings" } ]
                    delegate: Tile {
                        id: quick
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 3.6
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                source: quick.modelData.icon
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            }
                            PlasmaComponents.Label {
                                text: quick.modelData.label
                                font: Kirigami.Theme.smallFont
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { exec.connectSource(quick.modelData.cmd); root.expanded = false }
                        }
                    }
                }
            }
        }
    }

    // ── Building blocks ──────────────────────────────────────────────────────
    // Colours derive from the theme's text colour, so tiles read as glass on
    // the dark SlozOS theme and still work on a light one
    readonly property color fg: Kirigami.Theme.textColor
    function tint(a) { return Qt.rgba(fg.r, fg.g, fg.b, a) }

    component Tile: Rectangle {
        radius: 18
        color: root.tint(0.07)
        border.color: root.tint(0.10)
        border.width: 1
    }

    component Round: Rectangle {
        id: round
        property string icon
        property bool checked
        property string tooltip
        signal clicked
        implicitWidth: Kirigami.Units.gridUnit * 2
        implicitHeight: implicitWidth
        radius: width / 2
        color: checked ? root.accent : root.tint(roundMouse.containsMouse ? 0.20 : 0.12)
        Behavior on color { ColorAnimation { duration: 120 } }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: parent.width * 0.55
            height: width
            source: round.icon
            isMask: true
            color: round.checked ? "white" : root.fg
        }
        MouseArea {
            id: roundMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: round.clicked()
        }
        PlasmaComponents.ToolTip { text: round.tooltip; visible: round.tooltip !== "" && roundMouse.containsMouse }
    }

    component ToggleRow: RowLayout {
        id: toggle
        property string icon
        property string title
        property string subtitle
        property bool checked
        signal toggled
        spacing: Kirigami.Units.smallSpacing * 2
        Round {
            icon: toggle.icon
            checked: toggle.checked
            onClicked: toggle.toggled()
        }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            PlasmaComponents.Label { text: toggle.title; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            PlasmaComponents.Label { text: toggle.subtitle; opacity: 0.6; font: Kirigami.Theme.smallFont; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }

    component SliderBlock: ColumnLayout {
        id: block
        property string title
        property string icon
        property int value
        signal movedTo(int v)
        signal iconClicked
        spacing: Kirigami.Units.smallSpacing
        PlasmaComponents.Label { text: block.title; font.weight: Font.DemiBold }
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: block.icon
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                MouseArea { anchors.fill: parent; onClicked: block.iconClicked() }
            }
            PlasmaComponents.Slider {
                id: slider
                Layout.fillWidth: true
                from: 0; to: 100; stepSize: 1
                onMoved: debounce.restart()
                // follow the system value, except while the user is dragging
                Binding on value { value: block.value; when: !slider.pressed }
                Timer { id: debounce; interval: 120; onTriggered: block.movedTo(Math.round(slider.value)) }
            }
        }
    }
}
