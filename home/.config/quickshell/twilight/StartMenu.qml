import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Floating Start menu, centred above the taskbar.
Panel {
    id: menu

    name: "start"
    keyboard: true
    slideFrom: 1
    panelWidth: 640
    panelHeight: Math.min(700, (screen?.height ?? 900) - Theme.barHeight - Theme.taskbarHeight - Theme.taskbarGap * 2 - 40)
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true
    margins.bottom: Theme.taskbarHeight + Theme.taskbarGap * 2 + 6

    property bool allApps: false
    property bool showPower: false
    property var ctx: null // { entry, x, y }
    readonly property string query: search.text.trim()

    onIsOpenChanged: {
        if (isOpen) {
            search.text = ""
            allApps = false
            showPower = false
            ctx = null
            search.forceActiveFocus()
        }
    }

    // ---- Settings shortcuts reachable from search ----
    readonly property var settings: [
        { name: "Settings", hint: "Personalise, taskbar, windows, power, fingerprint…", glyph: Icons.cog, run: () => Ui.openSettings() },
        { name: "Display settings", hint: "Monitors, projector, resolution, scaling", glyph: Icons.monitor, run: () => Sys.run(["nwg-displays"]) },
        { name: "Sound settings", hint: "Output and input devices", glyph: Icons.speaker, run: () => Sys.run(["pavucontrol"]) },
        { name: "Bluetooth settings", hint: "Pair and manage devices", glyph: Icons.bluetooth, run: () => Sys.run(["kcmshell6", "kcm_bluetooth"]) },
        { name: "Wi-Fi and network", hint: "Quick settings", glyph: Icons.wifi4, run: () => Ui.toggle("quicksettings") },
        { name: "Night light", hint: Sys.nightLight ? "On" : "Off", glyph: Icons.night, run: () => { Sys.nightLight = !Sys.nightLight; Ui.close() } },
        { name: "Dark mode", hint: Sys.darkMode ? "On" : "Off", glyph: Icons.darkMode, run: () => { Sys.setDarkMode(!Sys.darkMode); Ui.close() } },
        { name: "Do not disturb", hint: Sys.dnd ? "On" : "Off", glyph: Icons.bellSleep, run: () => { Sys.dnd = !Sys.dnd; Ui.close() } },
        { name: "Screenshot", hint: "Select an area", glyph: Icons.screenshot, run: () => Sys.screenshot(true) },
        { name: "Lock screen", hint: "Super + L", glyph: Icons.lock, run: () => Sys.lock() },
        { name: "Software", hint: "Install and update apps with Discover", glyph: Icons.apps, run: () => Apps.launch(Apps.entry("org.kde.discover")) },
    ]

    // Calculator: only digits, operators and brackets are accepted, so the
    // expression is safe to evaluate.
    function calc(q) {
        const expr = q.replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**")
        if (!/^[-+*/%().\d]+$/.test(expr) || !/\d[-+*/%]/.test(expr)) return null
        try {
            const v = Function(`"use strict"; return (${expr})`)()
            return Number.isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : null
        } catch (e) { return null }
    }

    readonly property var results: {
        if (!query) return []
        const q = query.toLowerCase()
        const c = calc(query)
        if (c !== null) return [{ kind: "calc", value: c, title: "= " + c, sub: "Press Enter to copy" }]
        const apps = Apps.search(query).map(e => ({ kind: "app", e, title: e.name, sub: e.genericName || e.comment || "Application" }))
        const sets = settings.filter(s => s.name.toLowerCase().includes(q) || s.hint.toLowerCase().includes(q))
                             .slice(0, 4).map(s => ({ kind: "setting", s, title: s.name, sub: s.hint }))
        const files = Apps.recentFiles.filter(f => f.path.split("/").pop().toLowerCase().includes(q))
                          .slice(0, 4).map(f => ({ kind: "file", f, title: f.path.split("/").pop(), sub: f.path }))
        return [...apps, ...sets, ...files]
    }
    property int selected: 0
    onResultsChanged: selected = 0

    function activate(r) {
        if (!r) return
        if (r.kind === "calc") { Quickshell.clipboardText = r.value; Ui.close(); return }
        if (r.kind === "app") Apps.launch(r.e)
        else if (r.kind === "setting") r.s.run()
        else Apps.openFile(r.f.path)
    }

    // Recently used: real launch history and the freedesktop recent-files list.
    readonly property var recommended: {
        const files = !Config.s.showRecentFiles ? [] : Apps.recentFiles.map(f => ({ kind: "file", f, title: f.path.split("/").pop(), time: f.time }))
        const recent = (Apps.store.recentApps ?? [])
        const apps = Apps.recentApps.map(e => ({ kind: "app", e, title: e.name, time: recent.find(r => r.id === e.id)?.time ?? 0 }))
        return [...files, ...apps].sort((a, b) => b.time - a.time).slice(0, 6)
    }

    function ago(ms) {
        const s = (Date.now() - ms) / 1000
        if (s < 3600) return Math.max(1, Math.floor(s / 60)) + "m ago"
        if (s < 86400) return Math.floor(s / 3600) + "h ago"
        if (s < 172800) return "Yesterday"
        return Math.floor(s / 86400) + " days ago"
    }

    Process {
        id: whoami
        running: true
        command: ["getent", "passwd", Quickshell.env("USER")]
        property string fullName: Quickshell.env("USER")
        stdout: StdioCollector { onStreamFinished: whoami.fullName = (text.split(":")[4] ?? "").split(",")[0] || Quickshell.env("USER") }
    }

    // ===================== Layout =====================
    Column {
        id: main
        anchors { fill: parent; topMargin: 22; leftMargin: 26; rightMargin: 26 }
        spacing: 18

        // ---- Search field ----
        Rectangle {
            width: parent.width
            height: 44
            radius: 22
            color: Qt.rgba(1, 1, 1, 0.07)
            border.color: search.activeFocus ? Qt.alpha(Theme.accent, 0.55) : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.fast } }

            Glyph { id: searchGlyph; anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }

                text: Icons.search; size: 18; color: Theme.subtext }
            TextInput {
                id: search
                anchors { left: searchGlyph.right; leftMargin: 10; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                color: Theme.text
                selectionColor: Theme.accent
                font.family: Theme.font
                font.pixelSize: 14
                clip: true
                Keys.onEscapePressed: Ui.close()
                Keys.onDownPressed: menu.selected = Math.min(menu.selected + 1, menu.results.length - 1)
                Keys.onUpPressed: menu.selected = Math.max(menu.selected - 1, 0)
                Keys.onReturnPressed: menu.activate(menu.results[menu.selected])
                Keys.onEnterPressed: menu.activate(menu.results[menu.selected])
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text
                    text: "Search for apps, settings and files"
                    size: 14
                    color: Theme.dim
                }
            }
        }

        // ---- Content area ----
        Item {
            clip: true
            width: parent.width
            height: menu.panelHeight - 22 - 44 - 18 - 72

            // ---------- Search results ----------
            ListView {
                anchors.fill: parent
                visible: menu.query !== ""
                clip: true
                spacing: 2
                model: menu.results
                currentIndex: menu.selected
                boundsBehavior: Flickable.StopAtBounds
                delegate: HoverButton {
                    id: res
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 52
                    radius: Theme.radiusItem
                    active: index === menu.selected
                    activeColor: Theme.hover
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => {
                        if (m.button === Qt.RightButton && modelData.kind === "app") {
                            const p = mapToItem(main, m.x, m.y); menu.ctx = { entry: modelData.e, x: p.x, y: p.y }
                        } else menu.activate(modelData)
                    }
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 14
                        Item {
                            width: 30; height: 30
                            anchors.verticalCenter: parent.verticalCenter
                            IconImage {
                                anchors.fill: parent
                                visible: res.modelData.kind === "app" || res.modelData.kind === "file"
                                source: res.modelData.kind === "app" ? Apps.iconOf(res.modelData.e)
                                      : res.modelData.kind === "file" ? Quickshell.iconPath(Apps.fileIcon(res.modelData.f.path), "text-x-generic") : ""
                            }
                            Glyph { anchors.centerIn: parent; visible: res.modelData.kind === "setting" || res.modelData.kind === "calc"
                                    text: res.modelData.kind === "calc" ? Icons.calculator : res.modelData.s?.glyph ?? ""; size: 22; color: Theme.accent }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Label { text: res.modelData.title; size: 13; weight: Font.Medium; width: 480 }
                            Label { text: res.modelData.sub; size: 11; color: Theme.subtext; width: 480 }
                        }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    visible: menu.results.length === 0
                    text: "No results for “" + menu.query + "”"
                    color: Theme.subtext
                }
            }

            // ---------- All apps ----------
            Item {
                anchors.fill: parent
                visible: menu.query === "" && menu.allApps

                Row {
                    id: allHeader
                    width: parent.width
                    height: 30
                    Label { text: "All apps"; size: 14; weight: Font.DemiBold; width: parent.width - backBtn.width; height: 30 }
                    HoverButton {
                        id: backBtn
                        width: backRow.implicitWidth + 20; height: 28
                        radius: 14
                        color: hovered ? Theme.hover : Theme.card
                        onClicked: menu.allApps = false
                        Row { id: backRow; anchors.centerIn: parent; spacing: 4
                            Glyph { text: Icons.chevronLeft; size: 14 }
                            Label { text: "Back"; size: 12 } }
                    }
                }

                ListView {
                    id: allList
                    anchors { top: allHeader.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Apps.all
                    section.property: "name"
                    section.criteria: ViewSection.FirstCharacter
                    section.delegate: Label {
                        required property string section
                        text: section.toUpperCase()
                        size: 12
                        weight: Font.DemiBold
                        color: Theme.accent
                        leftPadding: 12
                        height: 30
                    }
                    delegate: HoverButton {
                        required property var modelData
                        width: allList.width - 10
                        height: 42
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: m => {
                            if (m.button === Qt.RightButton) { const p = mapToItem(main, m.x, m.y); menu.ctx = { entry: modelData, x: p.x, y: p.y } }
                            else Apps.launch(modelData)
                        }
                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 14
                            IconImage { implicitSize: 26; source: Apps.iconOf(modelData); anchors.verticalCenter: parent.verticalCenter }
                            Label { text: modelData.name; size: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // ---------- Home: pinned + recommended ----------
            Column {
                anchors.fill: parent
                visible: menu.query === "" && !menu.allApps
                spacing: 10

                Item {
                    width: parent.width; height: 30
                    Label { text: "Pinned"; size: 14; weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter; leftPadding: 4 }
                    HoverButton {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: allRow.implicitWidth + 20; height: 28
                        radius: 14
                        color: hovered ? Theme.hover : Theme.card
                        onClicked: menu.allApps = true
                        Row { id: allRow; anchors.centerIn: parent; spacing: 4
                            Label { text: "All apps"; size: 12 }
                            Glyph { text: Icons.chevronRight; size: 14 } }
                    }
                }

                GridView {
                    id: pinned
                    width: parent.width
                    height: Math.min(3, Math.ceil(Apps.startPins.length / 6)) * cellHeight
                    cellWidth: width / 6
                    cellHeight: 88
                    clip: true
                    interactive: Apps.startPins.length > 18
                    boundsBehavior: Flickable.StopAtBounds
                    model: Apps.startPins
                    delegate: HoverButton {
                        id: pin
                        required property var modelData
                        width: pinned.cellWidth - 6
                        height: pinned.cellHeight - 6
                        radius: Theme.radiusItem
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: m => {
                            if (m.button === Qt.RightButton) { const p = mapToItem(main, m.x, m.y); menu.ctx = { entry: modelData, x: p.x, y: p.y } }
                            else Apps.launch(modelData)
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            IconImage {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitSize: 36
                                source: Apps.iconOf(pin.modelData)
                                scale: pin.pressed ? 0.9 : pin.hovered ? 1.06 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.fast } }
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(implicitWidth, pin.width - 8)
                                horizontalAlignment: Text.AlignHCenter
                                text: pin.modelData.name
                                size: 12
                            }
                        }
                    }
                }

                Item { width: 1; height: 6 }

                Item {
                    width: parent.width; height: 30
                    Label { text: "Recommended"; size: 14; weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter; leftPadding: 4 }
                }

                Grid {
                    id: rec
                    width: parent.width
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 4
                    Repeater {
                        model: menu.recommended
                        delegate: HoverButton {
                            id: recItem
                            required property var modelData
                            width: (rec.width - 8) / 2
                            height: 54
                            radius: Theme.radiusItem
                            onClicked: modelData.kind === "app" ? Apps.launch(modelData.e) : Apps.openFile(modelData.f.path)
                            Row {
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                spacing: 12
                                IconImage {
                                    implicitSize: 30
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: recItem.modelData.kind === "app" ? Apps.iconOf(recItem.modelData.e)
                                          : Quickshell.iconPath(Apps.fileIcon(recItem.modelData.f.path), "text-x-generic")
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Label { text: recItem.modelData.title; size: 12; weight: Font.Medium; width: recItem.width - 64 }
                                    Label { text: menu.ago(recItem.modelData.time); size: 11; color: Theme.subtext }
                                }
                            }
                        }
                    }
                }
                Label {
                    visible: menu.recommended.length === 0
                    width: parent.width
                    leftPadding: 4
                    text: "Apps you open and files you use recently will appear here."
                    color: Theme.subtext
                    size: 12
                }
            }
        }
    }

    // ---- Bottom strip: user, files, settings, lock, power ----
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 72
        color: Qt.rgba(0, 0, 0, 0.18)
        bottomLeftRadius: Theme.radiusPanel
        bottomRightRadius: Theme.radiusPanel
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1; color: Theme.border }

        // Your picture and name: opens Settings → Accounts.
        HoverButton {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            width: userRow.implicitWidth + 16
            height: 48
            radius: 24
            onClicked: Ui.openSettings("account")
        }
        Row {
            id: userRow
            anchors { left: parent.left; leftMargin: 26; verticalCenter: parent.verticalCenter }
            spacing: 12
            ClippingRectangle {
                width: 36; height: 36; radius: 18
                color: Theme.card
                anchors.verticalCenter: parent.verticalCenter
                Image { anchors.fill: parent; source: "file:///var/lib/AccountsService/icons/" + Quickshell.env("USER") + "?" + Ui.avatarRev; cache: false; sourceSize: Qt.size(72, 72); fillMode: Image.PreserveAspectCrop }
            }
            Label { text: whoami.fullName; size: 13; weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
        }

        Row {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 4
            component StripButton: HoverButton {
                property string glyph
                width: 40; height: 40; radius: 20
                Glyph { anchors.centerIn: parent; text: parent.glyph; size: 18 }
            }
            StripButton { glyph: Icons.folder; onClicked: Apps.launch(Apps.entry("org.kde.dolphin"), true) }
            StripButton { glyph: Icons.cog; onClicked: Ui.openSettings() }
            StripButton { glyph: Icons.lock; onClicked: Sys.lock() }
            StripButton { glyph: Icons.power; active: menu.showPower; onClicked: menu.showPower = !menu.showPower }
        }
    }

    // ---- Power popover ----
    Rectangle {
        visible: menu.showPower
        anchors { right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 76 }
        width: 230
        height: powerActions.implicitHeight + 12
        radius: Theme.radiusItem
        color: Theme.surfaceStrong
        border.color: Theme.borderStrong
        PowerActions { id: powerActions; anchors { fill: parent; margins: 6 } }
    }

    // ---- App context menu (pin/unpin) ----
    MouseArea {
        anchors.fill: parent
        visible: menu.ctx !== null || menu.showPower
        onClicked: { menu.ctx = null; menu.showPower = false }
        z: -1
    }
    Rectangle {
        visible: menu.ctx !== null
        x: Math.min((menu.ctx?.x ?? 0) + 26, menu.panelWidth - width - 10)
        y: Math.min((menu.ctx?.y ?? 0) + 22, menu.panelHeight - height - 10)
        width: 210
        height: ctxCol.implicitHeight + 12
        radius: Theme.radiusItem
        color: Theme.surfaceStrong
        border.color: Theme.borderStrong
        Column {
            id: ctxCol
            anchors { fill: parent; margins: 6 }
            component CtxRow: HoverButton {
                property string label
                width: parent.width; height: 34
                Label { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: parent.label; size: 13 }
            }
            CtxRow { label: "Open"; onClicked: { const e = menu.ctx.entry; menu.ctx = null; Apps.launch(e) } }
            CtxRow {
                label: menu.ctx && Apps.isPinned("start", menu.ctx.entry) ? "Unpin from Start" : "Pin to Start"
                onClicked: { Apps.togglePin("start", menu.ctx.entry); menu.ctx = null }
            }
            CtxRow {
                label: menu.ctx && Apps.isPinned("taskbar", menu.ctx.entry) ? "Unpin from taskbar" : "Pin to taskbar"
                onClicked: { Apps.togglePin("taskbar", menu.ctx.entry); menu.ctx = null }
            }
        }
    }

    Connections {
        target: Ui
        function onStartSearchChanged() { if (Ui.startSearch) search.forceActiveFocus() }
    }
}
