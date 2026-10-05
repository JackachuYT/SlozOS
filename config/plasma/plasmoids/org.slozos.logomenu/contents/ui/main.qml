// SlozOS logo menu — the top-left menu, laid out like macOS's Apple menu.
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons

PlasmoidItem {
    id: root

    readonly property string logo: "/usr/share/pixmaps/slozos-logo-symbolic.png"
    readonly property string qdbus: "$(command -v qdbus-qt6 || command -v qdbus6 || echo qdbus)"

    preferredRepresentation: compactRepresentation
    // Alt+F1 (or a click) opens our menu instead of an empty popup
    activationTogglesExpanded: false
    Plasmoid.icon: logo
    toolTipMainText: "SlozOS"
    toolTipSubText: ""

    function run(command) {
        executable.connectSource(command)
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
    }

    KCoreAddons.KUser { id: user }

    Connections {
        target: Plasmoid
        function onActivated() { menu.openRelative() }
    }

    compactRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        onClicked: menu.openRelative()

        Rectangle {   // soft highlight while hovered / open, like the macOS menu bar
            anchors.fill: parent
            anchors.margins: 1
            radius: height / 2
            color: Qt.rgba(1, 1, 1, menu.status === PlasmaExtras.Menu.Open ? 0.18 : (button.containsMouse ? 0.10 : 0))
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(Math.min(parent.width, parent.height) * 0.95)
            height: width
            source: root.logo
        }

        Component.onCompleted: menu.visualParent = button
    }

    fullRepresentation: Item {}

    // Text after a tab shows as a right-aligned shortcut hint in the menu
    PlasmaExtras.Menu {
        id: menu
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
        minimumWidth: Kirigami.Units.gridUnit * 14

        PlasmaExtras.MenuItem {
            text: "About SlozOS"
            icon: "computer-laptop"
            onClicked: root.run("kinfocenter")
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: "System Settings…"
            icon: "preferences-system"
            onClicked: root.run("systemsettings")
        }
        PlasmaExtras.MenuItem {
            text: "Spotlight\tMeta+Space"
            icon: "search"
            onClicked: root.run("slozos-spotlight")
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: "Sleep"
            onClicked: root.run("systemctl suspend")
        }
        PlasmaExtras.MenuItem {
            text: "Restart…"
            onClicked: root.run(root.qdbus + " org.kde.LogoutPrompt /LogoutPrompt promptReboot")
        }
        PlasmaExtras.MenuItem {
            text: "Shut Down…"
            onClicked: root.run(root.qdbus + " org.kde.LogoutPrompt /LogoutPrompt promptShutDown")
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: "Lock Screen\tMeta+L"
            onClicked: root.run("loginctl lock-session")
        }
        PlasmaExtras.MenuItem {
            text: "Log Out " + (user.fullName || user.loginName) + "…"
            onClicked: root.run(root.qdbus + " org.kde.LogoutPrompt /LogoutPrompt promptLogout")
        }
    }
}
