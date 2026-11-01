import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

// Centred bottom taskbar.
//
// Normal: docked, reserves its height so windows tile above it.
// Active workspace has a maximised/fullscreen window: releases the space and
// slides out of view. Resting the pointer on the bottom screen edge reveals it
// over the window; it hides again shortly after the pointer leaves.
PanelWindow {
    id: tb

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool maximized: monitor?.activeWorkspace?.hasFullscreen ?? false
    readonly property bool holdOpen: menu.visible || preview.visible || ctx.visible
        || (Ui.screen === screen && (Ui.open === "start"))
    property bool revealed: false
    readonly property string mode: Config.s.taskbarMode   // dodge | always | autohide
    // Dodge: hide for a maximised window or any window reaching the taskbar.
    readonly property bool hides: mode === "autohide"
        || (mode === "dodge" && (maximized || Ui.overTaskbar.includes(monitor?.name ?? "")))
    readonly property bool shown: !hides || revealed || holdOpen

    readonly property int fullHeight: Theme.taskbarHeight + Theme.taskbarGap * 2

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "twilight-taskbar"
    anchors { bottom: true; left: true; right: true }
    implicitHeight: fullHeight
    exclusiveZone: hides || mode === "autohide" ? 0 : fullHeight
    color: "transparent"

    Component.onCompleted: Ui.shellWindows = [...Ui.shellWindows, tb]
    Component.onDestruction: Ui.shellWindows = Ui.shellWindows.filter(w => w !== tb)

    // Input region: just the pill when shown; a 2 px strip along the bottom
    // edge when hidden. While revealed over a maximised window the strip stays
    // part of the region so a pointer resting on the edge cannot cause a
    // show/hide loop.
    mask: Region {
        item: tb.shown ? pillColumn : null
        Region { item: tb.hides ? hotStrip : null }
    }

    onHidesChanged: if (!hides) revealed = false

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) { hideTimer.stop(); if (tb.hides && !tb.revealed) revealTimer.restart() }
            else { revealTimer.stop(); hideTimer.restart() }
        }
    }
    // Short dwell before revealing avoids accidental activation.
    Timer { id: revealTimer; interval: 220; onTriggered: tb.revealed = true }
    Timer { id: hideTimer; interval: 600; onTriggered: if (!hover.hovered && !tb.holdOpen) tb.revealed = false }
    Connections {
        target: tb
        function onHoldOpenChanged() { if (!tb.holdOpen && !hover.hovered) hideTimer.restart() }
    }

    Item {
        id: hotStrip
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 2
    }

    // The pill plus the gap below it, used for the input mask.
    Item {
        id: pillColumn
        x: pill.x
        y: pill.y
        width: pill.width
        height: tb.fullHeight - pill.y
    }

    // ---------------- Items: pinned apps first, then other running apps ----------------
    readonly property var toplevels: ToplevelManager.toplevels.values
    readonly property var items: {
        const groups = new Map()
        for (const t of toplevels) {
            const e = Apps.forAppId(t.appId)
            const key = e?.id ?? t.appId
            if (!groups.has(key)) groups.set(key, { entry: e, appId: t.appId, windows: [] })
            groups.get(key).windows.push(t)
        }
        const out = Apps.taskbarPins.map(e => {
            const g = groups.get(e.id)
            groups.delete(e.id)
            return { key: e.id, entry: e, appId: e.id, windows: g ? g.windows : [], pinned: true }
        })
        for (const [key, g] of groups) out.push({ key, entry: g.entry, appId: g.appId, windows: g.windows, pinned: false })
        return out
    }

    function show(t) {
        const h = Win.hyprFor(t)
        if (Win.isMinimized(h)) Win.restore(h)
        else t.activate()
    }

    // Windows-style: click opens/focuses; clicking the focused app minimises
    // it (or cycles when it has several windows); minimised ones are restored.
    // If the app under an open preview disappears, close the preview.
    onItemsChanged: if (preview.visible && !items.some(i => i.key === preview.item?.key)) { preview.visible = false; preview.target = null }

    function activateGroup(item) {
        const wins = item.windows
        if (wins.length === 0) { Apps.launch(item.entry); return }
        const i = wins.indexOf(ToplevelManager.activeToplevel)
        const focusedVisible = i >= 0 && !Win.isMinimized(Win.hyprFor(wins[i]))
        if (focusedVisible && wins.length === 1) { Win.minimize(Win.hyprFor(wins[0])); return }
        if (focusedVisible) { show(wins[(i + 1) % wins.length]); return }
        show(wins.find(w => !Win.isMinimized(Win.hyprFor(w))) ?? wins[0])
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: tb.shown ? Theme.taskbarGap : tb.fullHeight + 6
        width: row.implicitWidth + 16
        height: Theme.taskbarHeight
        radius: Theme.radiusPanel
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        opacity: tb.shown ? 1 : 0
        Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

        // Right-click empty taskbar space.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: m => {
                const p = mapToItem(tb.contentItem, m.x, m.y)
                ctx.openAt(tb.screen, p.x, tb.screen.height - tb.height + p.y, [
                    { glyph: Icons.taskManager, label: "Task Manager", action: () => Ui.taskManager() },
                    { glyph: Icons.taskView, label: "Task View", action: () => Ui.taskViewOpen = true },
                    { glyph: Icons.desktop, label: "Show desktop", action: () => Win.showDesktop() },
                    { separator: true },
                    { glyph: Icons.cog, label: "Taskbar settings", action: () => Ui.openSettings("taskbar") },
                ])
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4

            // ----- Start button -----
            HoverButton {
                id: startBtn
                width: 44; height: 44
                radius: Theme.radiusItem
                active: Ui.open === "start" && Ui.screen === tb.screen
                activeColor: Theme.hover
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => {
                    if (m.button === Qt.RightButton) {
                        // Windows "power user" menu.
                        const p = startBtn.mapToItem(tb.contentItem, m.x, m.y)
                        Ui.close()
                        ctx.openAt(tb.screen, p.x, tb.screen.height - tb.height + p.y, [
                            { glyph: Icons.apps, label: "Apps & startup", action: () => Ui.openSettings("apps") },
                            { glyph: Icons.battery, label: "Power & battery", action: () => Ui.openSettings("power") },
                            { glyph: Icons.monitor, label: "System", action: () => Ui.openSettings("system") },
                            { glyph: Icons.wifi4, label: "Network", action: () => Ui.openSettings("network") },
                            { separator: true },
                            { glyph: Icons.taskManager, label: "Task Manager", action: () => Ui.taskManager() },
                            { glyph: Icons.cog, label: "Settings", action: () => Ui.openSettings() },
                            { glyph: Icons.folder, label: "File Explorer", action: () => Apps.launch(Apps.entry("org.kde.dolphin"), true) },
                            { glyph: Icons.search, label: "Search", action: () => { Ui.toggle("start", tb.screen); Ui.startSearch = true } },
                            { glyph: Icons.terminal, label: "Terminal", action: () => Quickshell.execDetached(["konsole", "--profile", "Twilight"]) },
                            { separator: true },
                            { glyph: Icons.help, label: "Get started", action: () => Ui.getStartedOpen = true },
                            { glyph: Icons.power, label: "Shut down or sign out", action: () => Ui.toggle("power", tb.screen) },
                        ])
                        return
                    }
                    mark.flash(); Ui.toggle("start", tb.screen)
                }
                StartMark {
                    id: mark
                    anchors.centerIn: parent
                    size: 22
                    hovered: startBtn.hovered
                    pressed: startBtn.pressed
                    open: startBtn.active
                }
                Component.onCompleted: mark.flash()
            }

            // ----- Search -----
            HoverButton {
                width: 44; height: 44
                radius: Theme.radiusItem
                onClicked: { Ui.toggle("start", tb.screen); Ui.startSearch = true }
                Glyph { anchors.centerIn: parent; text: Icons.search; size: 21; color: Theme.subtext }
            }

            Rectangle { width: 1; height: 24; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }

            // ----- Apps -----
            Repeater {
                model: ScriptModel { values: tb.items; objectProp: "key" }
                delegate: HoverButton {
                    id: app
                    required property var modelData
                    readonly property bool running: modelData.windows.length > 0
                    readonly property bool focused: modelData.windows.includes(ToplevelManager.activeToplevel)
                    readonly property bool allMinimized: running && modelData.windows.every(w => Win.isMinimized(Win.hyprFor(w)))

                    width: 44; height: 44
                    radius: Theme.radiusItem
                    active: focused
                    activeColor: Theme.hover
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onClicked: m => {
                        if (m.button === Qt.RightButton) menu.openFor(app, modelData)
                        else if (m.button === Qt.MiddleButton) Apps.launch(modelData.entry, true)
                        else tb.activateGroup(modelData)
                    }
                    onHoveredChanged: hovered ? preview.showFor(app, modelData) : preview.leave()

                    IconImage {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: app.hovered ? -2 : 0
                        implicitSize: 28
                        source: Apps.iconOf(app.modelData.entry)
                        scale: app.pressed ? 0.88 : 1
                        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Theme.fast } }
                        Behavior on scale { NumberAnimation { duration: Theme.fast } }
                    }

                    // Running indicator: dot when running, accent bar when focused.
                    Rectangle {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                        height: 3
                        radius: 1.5
                        width: app.focused && !app.allMinimized ? 16 : app.running ? 5 : 0
                        visible: app.running
                        opacity: app.allMinimized ? 0.45 : 1
                        color: app.focused && !app.allMinimized ? Theme.accent : Theme.subtext
                        Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    // ---------------- Hover: live window previews (or the app name) ----------------
    PopupWindow {
        id: preview
        property Item target: null
        property var item: null
        readonly property var wins: item?.windows ?? []

        function showFor(t, i) { leaveTimer.stop(); target = t; item = i; if (!menu.visible) openTimer.restart() }
        function leave() { openTimer.stop(); leaveTimer.restart() }
        Timer { id: openTimer; interval: 380; onTriggered: preview.visible = true }
        Timer { id: leaveTimer; interval: 280; onTriggered: if (!previewHover.hovered) { preview.visible = false; preview.target = null } }

        anchor.window: tb
        anchor.item: target ?? pill
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: -8
        implicitWidth: Math.max(nameRow.implicitWidth + 24, thumbs.implicitWidth + 16)
        implicitHeight: wins.length ? thumbs.implicitHeight + 16 : 32
        color: "transparent"
        visible: false

        HoverHandler { id: previewHover; onHoveredChanged: if (!hovered) leaveTimer.restart() }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusItem
            color: Theme.surfaceStrong
            border.color: Theme.border

            Row {
                id: nameRow
                visible: preview.wins.length === 0
                anchors.centerIn: parent
                Label { text: preview.item?.entry?.name ?? preview.item?.appId ?? ""; size: 12 }
            }

            Row {
                id: thumbs
                visible: preview.wins.length > 0
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: ScriptModel { values: preview.visible ? preview.wins.filter(w => w).slice(0, 4) : [] }
                    delegate: HoverButton {
                        id: thumb
                        required property var modelData
                        readonly property bool minimized: Win.isMinimized(Win.hyprFor(modelData))
                        width: 212
                        height: 152
                        radius: Theme.radiusSmall
                        color: hovered ? Theme.hover : Theme.card
                        onClicked: { preview.visible = false; tb.show(modelData) }

                        Label {
                            id: thumbTitle
                            anchors { left: parent.left; right: closeBtn.left; top: parent.top; margins: 8 }
                            text: (thumb.minimized ? "Minimised · " : "") + (thumb.modelData.title || preview.item?.entry?.name || "")
                            size: 11
                            color: Theme.subtext
                        }
                        HoverButton {
                            id: closeBtn
                            anchors { right: parent.right; top: parent.top; margins: 4 }
                            width: 22; height: 22; radius: 11
                            visible: thumb.hovered || hovered
                            color: hovered ? Theme.red : "transparent"
                            // Hide the preview before the window goes away.
                            onClicked: { const t = thumb.modelData; preview.visible = false; preview.target = null; Qt.callLater(() => t?.close()) }
                            Glyph { anchors.centerIn: parent; text: Icons.close; size: 13; color: parent.hovered ? "white" : Theme.subtext }
                        }
                        // Live capture only while the preview is visible.
                        ScreencopyView {
                            id: shot
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: thumbTitle.bottom; margins: 8 }
                            captureSource: thumb.minimized ? null : thumb.modelData
                            live: preview.visible
                            constraintSize: Qt.size(width, height)
                        }
                        IconImage {
                            anchors.centerIn: shot
                            visible: !shot.hasContent
                            implicitSize: 40
                            source: Apps.iconOf(preview.item?.entry)
                            opacity: 0.8
                        }
                    }
                }
            }
        }
    }

    // ---------------- Right-click menu ----------------
    PopupWindow {
        id: menu
        property Item target: null
        property var item: null
        function openFor(t, i) { Ui.dismissAll(); preview.visible = false; target = t; item = i; visible = true; Ui.menuOpen = true }
        onVisibleChanged: if (!visible) Ui.menuOpen = false
        Connections {
            target: Ui
            function onDismissSerialChanged() { menu.visible = false }
        }

        anchor.window: tb
        anchor.item: target ?? pill
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: -8
        implicitWidth: 220
        implicitHeight: menuCol.implicitHeight + 12
        color: "transparent"
        visible: false

        HyprlandFocusGrab {
            active: menu.visible
            windows: [menu]
            onCleared: menu.visible = false
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusItem
            color: Theme.surfaceStrong
            border.color: Theme.border

            Column {
                id: menuCol
                anchors { fill: parent; margins: 6 }
                spacing: 2

                Label {
                    width: parent.width
                    leftPadding: 10
                    height: 28
                    text: menu.item?.entry?.name ?? menu.item?.appId ?? ""
                    size: 12
                    weight: Font.DemiBold
                    color: Theme.subtext
                }

                component MenuRow: HoverButton {
                    property string glyph
                    property string label
                    width: parent.width
                    height: 34
                    Row {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Glyph { text: parent.parent.glyph; size: 16 }
                        Label { text: parent.parent.label; size: 13 }
                    }
                }

                MenuRow {
                    visible: !!menu.item?.entry
                    glyph: Icons.apps
                    label: "New window"
                    onClicked: { menu.visible = false; Apps.launch(menu.item.entry, true) }
                }
                MenuRow {
                    visible: !!menu.item?.entry
                    glyph: Icons.check
                    label: menu.item?.pinned ? "Unpin from taskbar" : "Pin to taskbar"
                    onClicked: { menu.visible = false; Apps.togglePin("taskbar", menu.item.entry) }
                }
                MenuRow {
                    visible: (menu.item?.windows.length ?? 0) > 0
                    glyph: Icons.close
                    label: (menu.item?.windows.length ?? 0) > 1 ? "Close all windows" : "Close window"
                    onClicked: { menu.visible = false; for (const w of menu.item.windows) w.close() }
                }
            }
        }
    }

    ContextMenu { id: ctx }
}
