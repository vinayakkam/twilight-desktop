import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

// Task View (Win+Tab, or right-click the desktop / taskbar): every open
// window as a live preview, desktops along the top. Click a preview to go
// to it, click empty space or press Esc to close.
PanelWindow {
    id: tv

    screen: Ui.focusedScreen()
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "twilight-panel"
    WlrLayershell.keyboardFocus: Ui.taskViewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    property real progress: Ui.taskViewOpen ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    visible: progress > 0.001

    readonly property var monitor: Hyprland.monitorFor(screen)
    property int selected: monitor?.activeWorkspace?.id ?? 1
    onVisibleChanged: if (visible) selected = monitor?.activeWorkspace?.id ?? 1

    readonly property var desktops: {
        const ids = Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id)
        const max = Math.max(1, ...ids)
        const out = []
        for (let i = 1; i <= max; i++) out.push(i)
        return out
    }
    readonly property var windows: Hyprland.toplevels.values.filter(h => h.workspace?.id === selected)
    readonly property var minimized: Hyprland.toplevels.values.filter(h => Win.isMinimized(h))

    function go(h) {
        Ui.taskViewOpen = false
        if (Win.isMinimized(h)) Win.restore(h)
        else Hyprland.dispatch(`hl.dsp.focus({ window = "${Win.addr(h)}" })`)
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.78)
        opacity: tv.progress

        MouseArea { anchors.fill: parent; onClicked: Ui.taskViewOpen = false }

        Item {
            anchors.fill: parent
            focus: tv.visible
            Keys.onEscapePressed: Ui.taskViewOpen = false
            scale: 0.97 + 0.03 * tv.progress

            // ---- Desktops ----
            Row {
                id: deskRow
                anchors { top: parent.top; topMargin: Theme.barHeight + 24; horizontalCenter: parent.horizontalCenter }
                spacing: 12
                Repeater {
                    model: tv.desktops
                    delegate: HoverButton {
                        required property int modelData
                        readonly property int count: Hyprland.toplevels.values.filter(h => h.workspace?.id === modelData).length
                        width: 150; height: 64
                        radius: Theme.radiusItem
                        color: tv.selected === modelData ? Theme.accentSoft : hovered ? Theme.hover : Theme.card
                        border.color: tv.monitor?.activeWorkspace?.id === modelData ? Theme.accent : "transparent"
                        border.width: 2
                        onClicked: tv.selected = modelData
                        Column {
                            anchors.centerIn: parent
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Desktop " + parent.parent.modelData; size: 13; weight: Font.DemiBold }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.count + (parent.parent.count === 1 ? " window" : " windows"); size: 11; color: Theme.subtext }
                        }
                        // Double-click jumps straight to that desktop.
                        MouseArea {
                            anchors.fill: parent
                            onDoubleClicked: { Ui.taskViewOpen = false; Hyprland.dispatch(`hl.dsp.focus({ workspace = ${parent.modelData} })`) }
                            onClicked: tv.selected = parent.modelData
                        }
                    }
                }
                HoverButton {
                    width: 64; height: 64
                    radius: Theme.radiusItem
                    color: hovered ? Theme.hover : Theme.card
                    onClicked: {
                        const next = tv.desktops.length + 1
                        Ui.taskViewOpen = false
                        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${next} })`)
                    }
                    Column {
                        anchors.centerIn: parent
                        Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: Icons.plus; size: 20 }
                        Label { text: "New"; size: 11; color: Theme.subtext }
                    }
                }
            }

            // ---- Windows on the selected desktop (+ minimised ones) ----
            Flow {
                id: grid
                anchors { top: deskRow.bottom; topMargin: 36; horizontalCenter: parent.horizontalCenter }
                readonly property int count: tv.windows.length + tv.minimized.filter(h => !tv.windows.includes(h)).length
                width: Math.min(parent.width - 120, Math.max(1, count) * 320 - 20)
                spacing: 20
                Repeater {
                    model: ScriptModel { values: tv.visible ? tv.windows.concat(tv.minimized.filter(h => !tv.windows.includes(h))).filter(h => h) : [] }
                    delegate: HoverButton {
                        id: card
                        required property var modelData
                        readonly property bool min: Win.isMinimized(modelData)
                        readonly property var entry: Apps.forAppId(modelData.wayland?.appId ?? modelData.lastIpcObject?.class ?? "")
                        width: 300; height: 210
                        radius: Theme.radiusItem
                        color: hovered ? Theme.hover : Theme.card
                        border.color: hovered ? Theme.accent : Theme.border
                        onClicked: tv.go(modelData)

                        Row {
                            id: head
                            anchors { left: parent.left; top: parent.top; margins: 10 }
                            spacing: 8
                            IconImage { implicitSize: 18; source: Apps.iconOf(card.entry) }
                            Label { width: 220; text: (card.min ? "Minimised · " : "") + (card.modelData.title || card.entry?.name || ""); size: 12 }
                        }
                        HoverButton {
                            anchors { right: parent.right; top: parent.top; margins: 6 }
                            width: 24; height: 24; radius: 12
                            visible: card.hovered || hovered
                            color: hovered ? Theme.red : "transparent"
                            onClicked: Win.close(card.modelData)
                            Glyph { anchors.centerIn: parent; text: Icons.close; size: 14; color: parent.hovered ? "white" : Theme.subtext }
                        }
                        ScreencopyView {
                            id: shot
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: head.bottom; margins: 10 }
                            captureSource: card.min ? null : card.modelData.wayland
                            live: tv.visible
                            constraintSize: Qt.size(width, height)
                        }
                        IconImage {
                            anchors.centerIn: shot
                            visible: !shot.hasContent
                            implicitSize: 56
                            source: Apps.iconOf(card.entry)
                            opacity: 0.85
                        }
                    }
                }
            }

            Label {
                anchors { top: deskRow.bottom; topMargin: 80; horizontalCenter: parent.horizontalCenter }
                visible: tv.windows.length === 0 && tv.minimized.length === 0
                text: "No open windows on Desktop " + tv.selected + " — double-click a desktop above to go there"
                color: Theme.subtext
            }
        }
    }
}
