import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Snipping-tool style capture. The screen is frozen; pick a Rectangle
// (drag), a Window (click) or the Full screen. The snip is saved to
// ~/Pictures/Screenshots, copied, and opened in the editor (ShotEditor).
// Escape or right-click cancels.
PanelWindow {
    id: shot

    readonly property string frozen: Quickshell.env("XDG_RUNTIME_DIR") + "/twilight-shot.png"
    readonly property string outDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    property string mode: "region"          // region | window | screen
    property rect sel: Qt.rect(0, 0, 0, 0)  // logical, screen-relative
    property real scale: 1
    property int rev: 0

    screen: Ui.focusedScreen()
    visible: Ui.screenshotOpen && rev > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "twilight-screenshot"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "black"

    readonly property var monitor: Hyprland.monitorFor(screen)

    function reset() { sel = Qt.rect(0, 0, 0, 0); mode = "region" }
    function cancel() { Ui.screenshotOpen = false; rev = 0 }

    // 1. Freeze the screen (after panels have faded), then show the overlay.
    Connections {
        target: Ui
        function onScreenshotOpenChanged() {
            if (!Ui.screenshotOpen) return
            shot.reset()
            freezeTimer.restart()
        }
    }
    Timer { id: freezeTimer; interval: 260; onTriggered: { Hyprland.refreshToplevels(); freeze.running = true } }
    Process {
        id: freeze
        command: ["grim", "-o", shot.monitor?.name ?? "", shot.frozen]
        onExited: code => {
            if (code !== 0) { shot.cancel(); return }
            shot.scale = shot.monitor?.scale ?? 1
            shot.rev++
        }
    }

    // 2. Crop, save to ~/Pictures/Screenshots, copy, then open the editor.
    function finish() {
        const s = scale
        const g = `${Math.round(sel.width * s)}x${Math.round(sel.height * s)}+${Math.round(sel.x * s)}+${Math.round(sel.y * s)}`
        const file = `${outDir}/Screenshot_${Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")}.png`
        saver.file = file
        saver.command = ["sh", "-c", `mkdir -p "${outDir}" && magick "${frozen}" -crop ${g} +repage "${file}" && wl-copy --type image/png < "${file}"`]
        saver.running = true
        cancel()
    }
    Process {
        id: saver
        property string file
        onExited: code => { if (code === 0) Ui.shotFile = file }
    }

    // ---------- frozen image + dimming outside the selection ----------
    Image {
        anchors.fill: parent
        source: shot.rev > 0 ? "file://" + shot.frozen + "?" + shot.rev : ""
        cache: false
        fillMode: Image.Stretch
    }
    component Dim: Rectangle { color: Qt.rgba(0, 0, 0, 0.45) }
    readonly property bool hasSel: sel.width > 2 && sel.height > 2
    Dim { visible: !shot.hasSel; anchors.fill: parent }
    Dim { visible: shot.hasSel; x: 0; y: 0; width: parent.width; height: shot.sel.y }
    Dim { visible: shot.hasSel; x: 0; y: shot.sel.y + shot.sel.height; width: parent.width; height: parent.height - y }
    Dim { visible: shot.hasSel; x: 0; y: shot.sel.y; width: shot.sel.x; height: shot.sel.height }
    Dim { visible: shot.hasSel; x: shot.sel.x + shot.sel.width; y: shot.sel.y; width: parent.width - x; height: shot.sel.height }
    // Crosshair while choosing a region.
    Rectangle { visible: shot.mode === "region" && !area.pressed && area.containsMouse
        x: 0; y: area.mouseY; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.45) }
    Rectangle { visible: shot.mode === "region" && !area.pressed && area.containsMouse
        x: area.mouseX; y: 0; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.45) }
    // Corner handles.
    Repeater {
        model: shot.hasSel ? [[0, 0], [1, 0], [0, 1], [1, 1]] : []
        delegate: Rectangle {
            required property var modelData
            width: 12; height: 12; radius: 6
            color: "white"; border.color: Theme.accent; border.width: 2
            x: shot.sel.x + modelData[0] * shot.sel.width - 6
            y: shot.sel.y + modelData[1] * shot.sel.height - 6
        }
    }
    Rectangle {
        visible: shot.hasSel
        x: shot.sel.x - 1; y: shot.sel.y - 1
        width: shot.sel.width + 2; height: shot.sel.height + 2
        color: "transparent"
        border.color: Theme.accent
        border.width: 2
    }
    Rectangle {
        visible: shot.hasSel
        x: shot.sel.x; y: Math.max(0, shot.sel.y - 26)
        width: sizeLabel.implicitWidth + 12; height: 22; radius: 6
        color: Theme.surfaceStrong
        Label { id: sizeLabel; anchors.centerIn: parent; size: 11
            text: Math.round(shot.sel.width * shot.scale) + " × " + Math.round(shot.sel.height * shot.scale) }
    }

    // ---------- selecting ----------
    function windowAt(px, py) {
        const mx = monitor?.x ?? 0, my = monitor?.y ?? 0
        const ws = monitor?.activeWorkspace
        let best = null
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject
            if (!o || !o.at || t.workspace !== ws) continue
            const r = Qt.rect(o.at[0] - mx, o.at[1] - my, o.size[0], o.size[1])
            if (px >= r.x && px <= r.x + r.width && py >= r.y && py <= r.y + r.height) {
                // Prefer the window that was focused most recently (topmost).
                if (!best || o.focusHistoryID < best.id) best = { id: o.focusHistoryID, r }
            }
        }
        return best ? best.r : null
    }

    MouseArea {
        id: area
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: shot.mode === "region" ? Qt.CrossCursor : Qt.PointingHandCursor
        property point start
        onPressed: m => {
            if (m.button === Qt.RightButton) { shot.cancel(); return }
            if (shot.mode === "region") { start = Qt.point(m.x, m.y); shot.sel = Qt.rect(m.x, m.y, 0, 0) }
        }
        onPositionChanged: m => {
            if (shot.mode === "region" && pressed)
                shot.sel = Qt.rect(Math.min(start.x, m.x), Math.min(start.y, m.y), Math.abs(m.x - start.x), Math.abs(m.y - start.y))
            else if (shot.mode === "window")
                shot.sel = shot.windowAt(m.x, m.y) ?? Qt.rect(0, 0, 0, 0)
        }
        onReleased: m => {
            if (m.button !== Qt.LeftButton) return
            if (shot.hasSel) shot.finish()
        }
    }

    Item {
        anchors.fill: parent
        focus: shot.visible
        Keys.onEscapePressed: shot.cancel()
        Keys.onReturnPressed: { shot.sel = Qt.rect(0, 0, shot.width, shot.height); shot.finish() }
    }

    // ---------- mode toolbar (top centre) ----------
    Rectangle {
        anchors { top: parent.top; topMargin: 24; horizontalCenter: parent.horizontalCenter }
        width: modes.implicitWidth + 12; height: 50; radius: 25
        opacity: area.pressed ? 0.15 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        color: Theme.surfaceStrong
        border.color: Theme.borderStrong
        Row {
            id: modes
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: [["region", String.fromCodePoint(0xf05c6), "Rectangle"], ["window", Icons.winMax, "Window"], ["screen", Icons.monitor, "Full screen"]]
                delegate: HoverButton {
                    required property var modelData
                    width: modeRow.implicitWidth + 24; height: 36; radius: 18
                    active: shot.mode === modelData[0]
                    activeColor: Theme.accent
                    onClicked: {
                        shot.mode = modelData[0]
                        shot.sel = modelData[0] === "screen" ? Qt.rect(0, 0, shot.width, shot.height) : Qt.rect(0, 0, 0, 0)
                        if (modelData[0] === "screen") shot.finish()
                    }
                    Row { id: modeRow; anchors.centerIn: parent; spacing: 8
                        Glyph { text: modelData[1]; size: 16; color: parent.parent.active ? "#140b06" : Theme.text }
                        Label { text: modelData[2]; size: 12; color: parent.parent.active ? "#140b06" : Theme.text } }
                }
            }
            Rectangle { width: 1; height: 24; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
            HoverButton {
                width: 36; height: 36; radius: 18
                onClicked: shot.cancel()
                Glyph { anchors.centerIn: parent; text: Icons.close; size: 16 }
            }
        }
    }

    Label {
        visible: !area.pressed
        anchors { top: parent.top; topMargin: 86; horizontalCenter: parent.horizontalCenter }
        text: shot.mode === "region" ? "Drag to snip an area · Enter for full screen · Esc to cancel" : "Click a window to snip it"
        size: 13
        style: Text.Outline; styleColor: "#80000000"
    }

}
