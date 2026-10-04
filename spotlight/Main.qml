// SlozOS Spotlight — the search bar itself.
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

Window {
    id: root

    // ── Look ────────────────────────────────────────────────────────────────
    readonly property int pad: 36               // transparent room for the shadow
    readonly property int barHeight: 62
    readonly property int panelWidth: 700
    readonly property color glass: Qt.rgba(0.11, 0.11, 0.12, 0.74)
    readonly property color edge: Qt.rgba(1, 1, 1, 0.14)
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.55)
    readonly property color accent: "#0A84FF"
    readonly property string font: "Inter"

    // ── State ───────────────────────────────────────────────────────────────
    // runner: KRunner plugin id used in single-runner mode ("" = clipboard)
    readonly property var categories: [
        { name: "Applications", icon: "view-app-grid-symbolic",      runner: "krunner_services" },
        { name: "Files",        icon: "folder-symbolic",             runner: "baloosearch" },
        { name: "Settings",     icon: "preferences-system-symbolic", runner: "krunner_systemsettings" },
        { name: "Clipboard",    icon: "edit-paste-symbolic",         runner: "" }
    ]
    property int category: -1                   // -1 = search everything
    readonly property bool clipboardMode: category === 3
    readonly property string query: field.text
    property var clipItems: []
    property bool navigated: false              // has the user moved the selection?
    property point lastPointer: Qt.point(-1, -1) // to tell real mouse moves from content moving under it

    // Which body the panel shows under the bar
    readonly property string body: clipboardMode ? "clipboard"
        : query.length > 0 ? "results"
        : category >= 0 ? "hint"
        : "categories"

    width: panelWidth + pad * 2
    height: pad * 2 + barHeight + (panel.visible ? 10 + panel.height : 0)
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    title: "Spotlight"

    function open(text, cat) {
        category = (cat === undefined || cat === null) ? -1 : cat
        field.text = text || ""
        if (clipboardMode) {
            clipItems = Spotlight.clipboardHistory()
        }
        Spotlight.place(root)
        lastPointer = Qt.point(-1, -1)
        visible = true
        requestActivate()
        field.forceActiveFocus()
        updateBlur()
    }

    function close() {
        visible = false
        field.text = ""
        category = -1
    }

    function setCategory(i) {
        category = (category === i) ? -1 : i
        if (clipboardMode) {
            clipItems = Spotlight.clipboardHistory()
        }
        field.forceActiveFocus()
    }

    function updateBlur() {
        const shapes = [{ x: bar.x, y: bar.y, width: bar.width, height: bar.height, radius: bar.radius }]
        if (panel.visible) {
            shapes.push({ x: panel.x, y: panel.y, width: panel.width, height: panel.height, radius: panel.radius })
        }
        Spotlight.setBlur(root, shapes)
    }

    function activateCurrent() {
        if (body === "results") {
            if (resultsList.count > 0 && results.run(results.index(resultsList.currentIndex, 0))) {
                close()
            }
        } else if (body === "clipboard") {
            if (clipList.count > 0) {
                Spotlight.copyToClipboard(clipList.model[clipList.currentIndex])
                close()
            }
        } else if (body === "categories") {
            setCategory(categoryList.currentIndex)
        }
    }

    function currentList() {
        return body === "results" ? resultsList
             : body === "clipboard" ? clipList
             : body === "categories" ? categoryList : null
    }

    onHeightChanged: updateBlur()
    onActiveChanged: if (!active && visible) close()   // click elsewhere = dismiss

    Connections {
        target: Spotlight
        function onToggleRequested() { root.visible ? root.close() : root.open("", -1) }
    }

    Milou.ResultsModel {
        id: results
        queryString: root.clipboardMode ? "" : root.query
        singleRunner: root.category >= 0 ? root.categories[root.category].runner : ""
        limit: 24
        // Results stream in from several runners and get re-sorted; keep the
        // top hit selected until the user picks something else.
        onRowsInserted: if (!root.navigated) resultsList.currentIndex = 0
        onModelReset: if (!root.navigated) resultsList.currentIndex = 0
    }

    // Clicking the empty margin around the glass closes it, like macOS
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // ── Search bar ──────────────────────────────────────────────────────────
    RectangularShadow {
        anchors.fill: bar
        radius: bar.radius
        offset.y: 10
        blur: 32
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    Rectangle {
        id: bar
        x: root.pad
        y: root.pad
        width: root.panelWidth
        height: root.barHeight
        radius: height / 2
        color: root.glass
        border.color: root.edge
        border.width: 1

        // Liquid Glass sheen along the top edge
        Rectangle {
            anchors { fill: parent; margins: 1 }
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }

        MouseArea { anchors.fill: parent }   // swallow clicks so they don't close

        RowLayout {
            anchors { fill: parent; leftMargin: 22; rightMargin: 22 }
            spacing: 12

            Kirigami.Icon {
                source: "search-symbolic"
                color: root.textSecondary
                isMask: true
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }

            // Category token, e.g. [▦ Applications]
            Rectangle {
                visible: root.category >= 0
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.12)
                Layout.preferredHeight: 32
                Layout.preferredWidth: tokenRow.implicitWidth + 24
                RowLayout {
                    id: tokenRow
                    anchors.centerIn: parent
                    spacing: 6
                    Kirigami.Icon {
                        source: root.category >= 0 ? root.categories[root.category].icon : ""
                        color: root.textPrimary
                        isMask: true
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                    }
                    Text {
                        text: root.category >= 0 ? root.categories[root.category].name : ""
                        color: root.textPrimary
                        font { family: root.font; pixelSize: 15; weight: Font.Medium }
                    }
                }
            }

            TextInput {
                id: field
                Layout.fillWidth: true
                color: root.textPrimary
                selectionColor: Qt.rgba(0.04, 0.52, 1, 0.5)
                font { family: root.font; pixelSize: 26; weight: Font.Normal }
                clip: true
                focus: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: parent.text.length === 0
                    text: root.category >= 0 ? "Search " + root.categories[root.category].name : "Spotlight Search"
                    color: Qt.rgba(1, 1, 1, 0.38)
                    font: parent.font
                }

                onTextChanged: {
                    root.navigated = false
                    if (root.currentList()) {
                        root.currentList().currentIndex = 0
                    }
                }

                Keys.onPressed: event => {
                    const list = root.currentList()
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Escape) {
                        if (text.length > 0) text = ""
                        else if (root.category >= 0) root.category = -1
                        else root.close()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down && list) {
                        root.navigated = true; list.incrementCurrentIndex(); event.accepted = true
                    } else if (event.key === Qt.Key_Up && list) {
                        root.navigated = true; list.decrementCurrentIndex(); event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.activateCurrent(); event.accepted = true
                    } else if (event.key === Qt.Key_Backspace && text.length === 0 && root.category >= 0) {
                        root.category = -1; event.accepted = true
                    } else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                        root.setCategory(event.key - Qt.Key_1); event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        root.setCategory((root.category + 1) % root.categories.length); event.accepted = true
                    }
                }
            }
        }
    }

    // ── Panel under the bar ─────────────────────────────────────────────────
    RectangularShadow {
        anchors.fill: panel
        visible: panel.visible
        radius: panel.radius
        offset.y: 12
        blur: 36
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    Rectangle {
        id: panel
        x: root.pad
        y: bar.y + bar.height + 10
        width: root.panelWidth
        visible: root.body !== "results" || resultsList.count > 0 || results.querying
        height: Math.min(content.implicitHeight + 16, 470)
        radius: 26
        color: root.glass
        border.color: root.edge
        border.width: 1
        clip: true
        onVisibleChanged: root.updateBlur()
        onHeightChanged: root.updateBlur()

        MouseArea { anchors.fill: parent }

        Item {
            id: content
            anchors { fill: parent; margins: 8 }
            implicitHeight: root.body === "results" ? resultsList.contentHeight
                          : root.body === "clipboard" ? Math.max(clipList.contentHeight, 52)
                          : root.body === "hint" ? 52
                          : categoryList.contentHeight

            // Categories (empty search) — Applications ⌃1, Files ⌃2, …
            ListView {
                id: categoryList
                anchors.fill: parent
                visible: root.body === "categories"
                interactive: false
                model: root.categories
                delegate: Row_ {
                    required property var modelData
                    required property int index
                    iconSource: modelData.icon
                    iconIsMask: true
                    label: modelData.name
                    hint: "Ctrl+" + (index + 1)
                    current: ListView.isCurrentItem
                    onHovered: categoryList.currentIndex = index
                    onClicked: root.setCategory(index)
                }
            }

            Text {
                visible: root.body === "hint"
                anchors.centerIn: parent
                text: "Type to search " + (root.category >= 0 ? root.categories[root.category].name.toLowerCase() : "")
                color: root.textSecondary
                font { family: root.font; pixelSize: 15 }
            }

            // Search results, grouped by type
            ListView {
                id: resultsList
                anchors.fill: parent
                visible: root.body === "results"
                model: results
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                section.property: "category"
                section.criteria: ViewSection.FullString
                section.delegate: Text {
                    required property string section
                    width: ListView.view.width
                    leftPadding: 14
                    topPadding: 8
                    bottomPadding: 4
                    text: section
                    color: root.textSecondary
                    font { family: root.font; pixelSize: 12; weight: Font.DemiBold; capitalization: Font.AllUppercase; letterSpacing: 0.6 }
                }
                delegate: Row_ {
                    required property var model
                    required property int index
                    iconSource: model.decoration
                    label: model.display
                    hint: model.subtext || ""
                    current: ListView.isCurrentItem
                    onHovered: { root.navigated = true; resultsList.currentIndex = index }
                    onClicked: { resultsList.currentIndex = index; root.activateCurrent() }
                }
            }

            // Clipboard history (Klipper), filtered by what you type
            ListView {
                id: clipList
                anchors.fill: parent
                visible: root.body === "clipboard"
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.clipItems.filter(t => root.query.length === 0
                                                  || t.toLowerCase().indexOf(root.query.toLowerCase()) >= 0)
                delegate: Row_ {
                    required property var modelData
                    required property int index
                    iconSource: "edit-paste-symbolic"
                    iconIsMask: true
                    label: modelData.replace(/\s+/g, " ").trim()
                    current: ListView.isCurrentItem
                    onHovered: clipList.currentIndex = index
                    onClicked: { clipList.currentIndex = index; root.activateCurrent() }
                }
                Text {
                    anchors.centerIn: parent
                    visible: clipList.count === 0
                    text: "Nothing copied yet"
                    color: root.textSecondary
                    font { family: root.font; pixelSize: 15 }
                }
            }
        }
    }

    // One row in any of the lists: icon · label · secondary text / shortcut
    component Row_: Item {
        id: row
        property var iconSource
        property bool iconIsMask: false
        property string label
        property string hint
        property bool current
        signal hovered
        signal clicked

        width: ListView.view ? ListView.view.width : 0
        height: 50

        Rectangle {
            anchors { fill: parent; margins: 2 }
            radius: 12
            color: row.current ? root.accent : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 16 }
            spacing: 12
            Kirigami.Icon {
                source: row.iconSource
                isMask: row.iconIsMask
                color: root.textPrimary
                Layout.preferredWidth: row.iconIsMask ? 22 : 32
                Layout.preferredHeight: row.iconIsMask ? 22 : 32
                Layout.leftMargin: row.iconIsMask ? 5 : 0
                Layout.rightMargin: row.iconIsMask ? 5 : 0
            }
            Text {
                text: row.label
                color: root.textPrimary
                elide: Text.ElideRight
                font { family: root.font; pixelSize: 16; weight: Font.Medium }
                Layout.fillWidth: true
            }
            Text {
                text: row.hint
                visible: text.length > 0
                color: row.current ? Qt.rgba(1, 1, 1, 0.8) : root.textSecondary
                elide: Text.ElideMiddle
                font { family: root.font; pixelSize: 13 }
                Layout.maximumWidth: 260
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            // Only follow the pointer when it really moves (in window
            // coordinates), not when results appear under a resting mouse.
            onPositionChanged: mouseEvent => {
                const p = mapToItem(null, mouseEvent.x, mouseEvent.y)
                if (root.lastPointer.x >= 0 && (p.x !== root.lastPointer.x || p.y !== root.lastPointer.y)) {
                    row.hovered()
                }
                root.lastPointer = p
            }
            onClicked: row.clicked()
        }
    }
}
