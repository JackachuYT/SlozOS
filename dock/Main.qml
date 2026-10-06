// SlozOS Dock — the dock itself: a Liquid Glass shelf along the bottom of the
// screen, laid out like MacTahoe's, with macOS-style magnification.
//
//   [Apps] [pinned + running apps] | [Trash]
//
// The window spans the screen width and is taller than the shelf, so icons
// can grow upwards and name bubbles / menus have room; Dock.setShape() limits
// blur and input to what is actually drawn.
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Window {
    id: root

    // ── Look ────────────────────────────────────────────────────────────────
    readonly property real iconSize: 50
    readonly property real gap: 9                  // between icons
    readonly property real padH: 10                // shelf padding, left/right
    readonly property real padTop: 7
    readonly property real dotArea: 9              // under the icons, for running dots
    readonly property real sepWidth: 13
    readonly property real maxScale: 1.6           // magnified icon size at the pointer
    readonly property real bottomGap: 6            // shelf ↔ screen edge
    readonly property real shelfHeight: padTop + iconSize + dotArea
    readonly property real shelfRadius: 22
    readonly property int headroom: 190            // above the shelf: magnification, bubbles, menus
    readonly property string font: "Inter"

    // ── State ───────────────────────────────────────────────────────────────
    property real hoverX: -1                       // pointer x over the dock
    property real zoom: 0                          // 0 → 1 while the pointer is over the dock
    Behavior on zoom { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
    property int hovered: -1                       // item under the pointer (for its name bubble)
    property real previewHover: -1                 // --screenshot: fake pointer x
    property bool hidden: false                    // auto-hide: slid off screen
    readonly property bool menuOpen: menu.visible

    readonly property int taskCount: taskRepeater.count
    readonly property int sepIndex: taskCount + 1
    readonly property int trashIndex: taskCount + 2
    readonly property int itemCount: taskCount + 3

    property real slide: hidden && !menuOpen ? shelfHeight + bottomGap + 4 : 0
    Behavior on slide { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
    readonly property real shelfBottom: height - bottomGap + slide
    readonly property real shelfTop: shelfBottom - shelfHeight
    readonly property real iconBottom: shelfBottom - dotArea

    width: Screen.width
    height: shelfHeight + bottomGap + headroom
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    title: "Dock"

    // ── Magnification ───────────────────────────────────────────────────────
    // Icons scale with a Gaussian of their distance to the pointer. Positions
    // are shifted so the point under the pointer stays put (no jitter), which
    // makes the shelf widen around it, as on macOS.
    function baseWidth(k) { return k === sepIndex ? sepWidth : iconSize }

    readonly property var lay: {
        const n = itemCount
        const px = previewHover >= 0 ? previewHover : hoverX
        const z = previewHover >= 0 ? 1 : zoom
        const sigma = iconSize * 1.25
        let total = -gap
        for (let k = 0; k < n; ++k) total += baseWidth(k) + gap
        const lefts = [], widths = [], centers = []
        let x = (width - total) / 2
        for (let k = 0; k < n; ++k) {
            const b = baseWidth(k)
            lefts.push(x)
            let s = 1
            if (k !== sepIndex && px >= 0) {
                const d = px - (x + b / 2)
                s = 1 + (maxScale - 1) * z * Math.exp(-(d * d) / (2 * sigma * sigma))
            }
            widths.push(b * s)
            x += b + gap
        }
        // growth to the left of the pointer: what the layout shifts by
        let growth = 0, growthLeft = 0
        for (let k = 0; k < n; ++k) {
            const extra = widths[k] - baseWidth(k)
            const f = px < 0 ? 0.5
                : Math.max(0, Math.min(1, (px - (lefts[k] - gap / 2)) / (baseWidth(k) + gap)))
            growthLeft += extra * f
            growth += extra
        }
        let before = 0
        for (let k = 0; k < n; ++k) {
            const extra = widths[k] - baseWidth(k)
            centers.push(lefts[k] + baseWidth(k) / 2 + before + extra / 2 - growthLeft)
            before += extra
        }
        const left = lefts[0] - padH - growthLeft
        const right = lefts[n - 1] + baseWidth(n - 1) + padH + growth - growthLeft
        return { widths: widths, centers: centers, left: left, right: right }
    }

    // Blur only behind the shelf; take input only where the dock is drawn
    function updateShape() {
        const shelf = { x: lay.left, y: shelfTop, width: lay.right - lay.left, height: shelfHeight, radius: shelfRadius }
        let input = []
        if (hidden && !menuOpen) {
            // a thin strip along the screen edge brings it back
            input.push({ x: lay.left, y: height - 3, width: lay.right - lay.left, height: 3, radius: 0 })
        } else {
            input.push(shelf)
            if (zoom > 0.01) {   // the magnified icons rise above the shelf
                const tall = iconSize * maxScale
                input.push({ x: lay.left, y: iconBottom - tall - 4, width: lay.right - lay.left,
                             height: tall + 4 - (iconBottom - shelfTop), radius: 0 })
            }
            if (menu.visible) {
                input.push({ x: menu.x, y: menu.y, width: menu.width, height: menu.height, radius: 0 })
            }
        }
        Dock.setShape(root, (hidden && !menuOpen) ? [] : [shelf], input)
    }
    onLayChanged: Qt.callLater(updateShape)
    onSlideChanged: Qt.callLater(updateShape)
    onMenuOpenChanged: Qt.callLater(updateShape)
    onHeightChanged: Qt.callLater(updateShape)

    // Windows keep clear of the dock, unless it auto-hides
    function updateZone() { Dock.setExclusiveZone(root, Dock.autoHide ? 0 : Math.round(shelfHeight + bottomGap)) }
    Connections { target: Dock; function onSettingsChanged() { root.updateZone() } }
    Component.onCompleted: { updateZone(); updateShape() }

    // ── Pointer tracking ────────────────────────────────────────────────────
    HoverHandler {
        id: pointer
        onPointChanged: if (!root.menuOpen && hovered) root.hoverX = point.position.x
        onHoveredChanged: {
            if (hovered) {
                root.hidden = false
            } else if (!root.menuOpen) {
                root.hovered = -1
                hideTimer.restart()
            }
        }
    }
    // magnify only while the pointer is over the dock (and no menu is open)
    Binding { target: root; property: "zoom"; value: pointer.hovered && !root.menuOpen ? 1 : 0 }

    // ── Auto-hide ("Hide the dock when a window needs the space") ───────────
    // Plasma's own task model, filtered to windows overlapping the shelf
    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: overlapping
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: true
        virtualDesktop: desktops.currentDesktop
        filterByActivity: true
        activity: activities.currentActivity
        filterMinimized: true
        filterHidden: true
        filterByRegion: TaskManager.RegionFilterMode.Intersect
        regionGeometry: Qt.rect(Screen.virtualX + root.lay.left, Screen.virtualY + Screen.height - root.bottomGap - root.shelfHeight,
                                root.lay.right - root.lay.left, root.shelfHeight)
    }
    Timer {
        id: hideTimer
        interval: 700
        onTriggered: root.hidden = Dock.autoHide && overlapping.count > 0 && !pointer.hovered && !root.menuOpen
    }
    Connections {
        target: overlapping
        function onCountChanged() { hideTimer.restart() }
    }
    Connections { target: Dock; function onSettingsChanged() { hideTimer.restart() } }

    // ── Apps ────────────────────────────────────────────────────────────────
    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
        separateLaunchers: false
        hideActivatedLaunchers: true
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        filterHidden: true
        onLauncherListChanged: if (!previewMode) Dock.launchers = launcherList
        Component.onCompleted: launcherList = Dock.launchers
    }

    // Sample apps for --screenshot (no window manager there)
    ListModel {
        id: previewModel
        ListElement { iconName: "system-file-manager"; display: "Files"; IsWindow: true; IsActive: true }
        ListElement { iconName: "firefox"; display: "Firefox"; IsWindow: true }
        ListElement { iconName: "steam"; display: "Steam" }
        ListElement { iconName: "net.lutris.Lutris"; display: "Lutris" }
        ListElement { iconName: "org.kde.discover"; display: "Bazaar" }
        ListElement { iconName: "utilities-terminal"; display: "Konsole"; IsWindow: true; IsMinimized: true }
        ListElement { iconName: "preferences-system"; display: "System Settings" }
    }

    function isPinned(url) { return url && tasksModel.launcherPosition(url) >= 0 }

    // ── Shelf ───────────────────────────────────────────────────────────────
    RectangularShadow {
        x: root.lay.left; y: root.shelfTop
        width: root.lay.right - root.lay.left; height: root.shelfHeight
        radius: root.shelfRadius
        offset.y: 6
        blur: 22
        color: Qt.rgba(0, 0, 0, 0.30)
        opacity: root.hidden && !root.menuOpen ? 0 : 1
    }

    Rectangle {      // Liquid Glass: frosted fill (KWin blurs behind it), lit edge
        id: shelf
        x: root.lay.left; y: root.shelfTop
        width: root.lay.right - root.lay.left; height: root.shelfHeight
        radius: root.shelfRadius
        color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.30)
        Rectangle {  // specular sheen across the top half
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
            height: parent.height * 0.55
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.20) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
        Rectangle {  // faint dark outline so it reads on light wallpapers
            anchors { fill: parent; margins: -1 }
            radius: parent.radius + 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.18)
        }
    }

    // ── Items ───────────────────────────────────────────────────────────────
    DockIcon {
        k: 0
        source: "view-app-grid"
        label: "Apps"
        onActivated: Dock.run("slozos-spotlight", ["--apps"])
    }

    Repeater {
        id: taskRepeater
        model: previewMode ? previewModel : tasksModel
        delegate: DockIcon {
            id: task
            required property int index
            required property var model
            k: index + 1
            source: model.decoration !== undefined ? model.decoration : model.iconName
            label: model.display || ""
            running: model.IsWindow === true && model.IsStartup !== true
            background: running && model.IsMinimized === true
            attention: model.IsDemandingAttention === true
            starting: model.IsStartup === true
            readonly property var idx: previewMode ? null : tasksModel.makeModelIndex(index)
            onActivated: {
                if (previewMode) return
                if (model.IsLauncher && !model.IsWindow) {
                    bounce()
                    tasksModel.requestActivate(idx)
                } else if (model.IsActive) {
                    tasksModel.requestToggleMinimized(idx)
                } else {
                    tasksModel.requestActivate(idx)
                }
            }
            onNewInstance: if (!previewMode && model.CanLaunchNewInstance !== false) { bounce(); tasksModel.requestNewInstance(idx) }
            onMenuRequested: {
                const url = model.LauncherUrlWithoutIcon
                const items = []
                if (model.IsWindow && model.CanLaunchNewInstance !== false)
                    items.push({ text: "New Window", run: () => { task.bounce(); tasksModel.requestNewInstance(idx) } })
                if (url && url.toString() !== "") {
                    if (root.isPinned(url)) items.push({ text: "Remove from Dock", run: () => tasksModel.requestRemoveLauncher(url) })
                    else items.push({ text: "Keep in Dock", run: () => tasksModel.requestAddLauncher(url) })
                }
                if (model.IsWindow) {
                    items.push({ separator: true })
                    items.push({ text: "Quit", run: () => tasksModel.requestClose(idx) })
                }
                menu.openFor(task, items)
            }
        }
    }

    Rectangle {      // divider before the Trash
        readonly property real cx: root.lay.centers[root.sepIndex] || 0
        x: cx - width / 2
        y: root.shelfTop + 12
        width: 1
        height: root.shelfHeight - 24
        color: Qt.rgba(1, 1, 1, 0.28)
    }

    DockIcon {
        id: trash
        k: root.trashIndex
        source: Dock.trashFull ? "user-trash-full" : "user-trash"
        label: "Trash"
        onActivated: Dock.openTrash()
        onMenuRequested: menu.openFor(trash, [
            { text: "Open", run: () => Dock.openTrash() },
            { separator: true },
            { text: "Empty Trash", enabled: Dock.trashFull, run: () => Dock.emptyTrash() }
        ])
    }

    // ── Name bubble ─────────────────────────────────────────────────────────
    Rectangle {
        id: bubble
        property string text: ""
        property real cx: 0
        property real anchorTop: 0
        visible: root.hovered >= 0 && !root.menuOpen && text !== "" && root.zoom > 0.5
        x: Math.max(4, Math.min(root.width - width - 4, cx - width / 2))
        y: anchorTop - height - 10
        width: bubbleText.implicitWidth + 24
        height: 28
        radius: height / 2
        color: Qt.rgba(0.12, 0.12, 0.13, 0.86)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        Text {
            id: bubbleText
            anchors.centerIn: parent
            text: bubble.text
            color: "white"
            font { family: root.font; pixelSize: 13; weight: Font.Medium }
        }
    }

    // ── Right-click menu (glass, macOS-style) ───────────────────────────────
    Rectangle {
        id: menu
        property var items: []
        visible: false
        width: 200
        height: menuColumn.implicitHeight + 10
        radius: 12
        color: Qt.rgba(0.13, 0.13, 0.14, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)

        function openFor(item, list) {
            items = list
            const cx = item.x + item.width / 2
            x = Math.max(4, Math.min(root.width - width - 4, cx - width / 2))
            y = item.y - height - 10
            visible = true
            Dock.setFocusable(root, true)   // so a click elsewhere closes it
        }
        function close() {
            visible = false
            Dock.setFocusable(root, false)
            if (!pointer.hovered) { root.hovered = -1; hideTimer.restart() }
        }

        Column {
            id: menuColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 5 }
            Repeater {
                model: menu.items
                delegate: Item {
                    required property var modelData
                    width: menuColumn.width
                    height: modelData.separator ? 9 : 26
                    Rectangle {
                        visible: !!parent.modelData.separator
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 6 }
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.12)
                    }
                    Rectangle {
                        visible: !parent.modelData.separator
                        anchors.fill: parent
                        radius: 6
                        color: itemMouse.containsMouse && parent.modelData.enabled !== false ? "#0A84FF" : "transparent"
                        Text {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: parent.parent.modelData.text || ""
                            color: parent.parent.modelData.enabled === false ? Qt.rgba(1, 1, 1, 0.35) : "white"
                            font { family: root.font; pixelSize: 13 }
                        }
                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                const entry = parent.parent.modelData
                                if (entry.enabled === false) return
                                menu.close()
                                entry.run()
                            }
                        }
                    }
                }
            }
        }
    }
    onActiveChanged: if (!active && menu.visible) menu.close()
    Shortcut { sequence: "Escape"; enabled: menu.visible; onActivated: menu.close() }

    // ── One dock item ───────────────────────────────────────────────────────
    component DockIcon: Item {
        id: icon
        property int k: 0
        property var source
        property string label
        property bool running: false
        property bool background: false      // running, but every window minimized
        property bool attention: false
        property bool starting: false
        property real lift: 0                // launch bounce
        signal activated
        signal newInstance
        signal menuRequested

        function bounce() { if (!bounceAnim.running) bounceAnim.start() }

        readonly property real side: root.lay.widths[k] || root.iconSize
        width: side
        height: side
        x: (root.lay.centers[k] || 0) - side / 2
        y: root.iconBottom - side - lift

        Kirigami.Icon {
            anchors.fill: parent
            source: icon.source
            smooth: true
            // pressed: a touch darker, like macOS
            opacity: iconMouse.pressed ? 0.75 : 1
        }

        Rectangle {          // running indicator (grey when only minimized windows)
            width: 4; height: 4; radius: 2
            visible: icon.running || icon.attention
            color: icon.attention ? "#FF9F0A" : icon.background ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.9)
            x: (icon.width - width) / 2
            y: (root.shelfBottom - 5) - icon.y - height   // fixed to the shelf, not the bouncing icon
        }

        SequentialAnimation {
            id: bounceAnim
            loops: 2
            NumberAnimation { target: icon; property: "lift"; to: root.iconSize * 0.45; duration: 260; easing.type: Easing.OutQuad }
            NumberAnimation { target: icon; property: "lift"; to: 0; duration: 260; easing.type: Easing.InQuad }
        }
        // apps that are still starting keep bouncing
        onStartingChanged: if (starting) bounce()
        Connections {
            target: bounceAnim
            function onFinished() { if (icon.starting) bounceAnim.start() }
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onContainsMouseChanged: if (containsMouse) {
                root.hovered = icon.k
                bubble.text = icon.label
            }
            onClicked: mouse => {
                if (root.menuOpen) { menu.close(); return }
                if (mouse.button === Qt.RightButton) icon.menuRequested()
                else if (mouse.button === Qt.MiddleButton) icon.newInstance()
                else icon.activated()
            }
            onPressAndHold: icon.menuRequested()   // touch: long-press for the menu
        }
        // keep the bubble over this icon as it magnifies
        Binding { target: bubble; property: "cx"; value: icon.x + icon.width / 2; when: root.hovered === icon.k }
        Binding { target: bubble; property: "anchorTop"; value: icon.y; when: root.hovered === icon.k }
    }
}
