import QtQuick
import Quickshell
import Quickshell.Hyprland

// Snipping Tool–style editor that opens after a screenshot: pen,
// highlighter, eraser, colours, undo/redo, then Copy / Save / Save as.
// The capture was already saved and copied; Save writes the markup into it.
FloatingWindow {
    id: ed

    title: "Snipping Tool"
    visible: Ui.shotFile !== ""
    readonly property var scr: Ui.focusedScreen()
    implicitWidth: Math.min((scr?.width ?? 1920) - 160, Math.max(760, img.sourceSize.width + 48))
    implicitHeight: Math.min((scr?.height ?? 1080) - Theme.barHeight - Theme.taskbarHeight - 60, Math.max(480, img.sourceSize.height + 140))
    color: Theme.surfaceStrong
    onVisibleChanged: if (!visible) Ui.shotFile = ""

    property string tool: "pen"            // pen | highlighter | eraser
    property color ink: "#f2683a"
    property var strokes: []               // { tool, color, width, points:[{x,y}] }
    property var redoStack: []
    property bool dirty: false
    property string status: ""

    readonly property var colors: ["#f2683a", "#f3b651", "#5eb7d0", "#3ec56d", "#ffffff", "#111111"]

    Connections {
        target: Ui
        function onShotFileChanged() { ed.strokes = []; ed.redoStack = []; ed.dirty = false; ed.status = "Saved and copied to the clipboard"; ed.tool = "pen" }
    }

    function undo() { if (!strokes.length) return; redoStack = [...redoStack, strokes[strokes.length - 1]]; strokes = strokes.slice(0, -1); dirty = true; canvas.requestPaint() }
    function redo() { if (!redoStack.length) return; strokes = [...strokes, redoStack[redoStack.length - 1]]; redoStack = redoStack.slice(0, -1); dirty = true; canvas.requestPaint() }

    // Render image + markup at full resolution, then run `then(path)`.
    function exportTo(path, then) {
        content.grabToImage(r => { r.saveToFile(path); then(path) })
    }
    function copy() {
        const tmp = Quickshell.env("XDG_RUNTIME_DIR") + "/twilight-snip.png"
        exportTo(tmp, p => { Quickshell.execDetached(["sh", "-c", `wl-copy --type image/png < "${p}"`]); status = "Copied to the clipboard" })
    }
    function save() {
        exportTo(Ui.shotFile, p => { Quickshell.execDetached(["sh", "-c", `wl-copy --type image/png < "${p}"`]); dirty = false; status = "Saved to " + p.replace(Quickshell.env("HOME"), "~") })
    }
    function saveAs() {
        const tmp = Quickshell.env("XDG_RUNTIME_DIR") + "/twilight-snip.png"
        exportTo(tmp, p => {
            Quickshell.execDetached(["sh", "-c",
                `f=$(kdialog --title "Save screenshot as" --getsavefilename "${Ui.shotFile}" "image/png") && [ -n "$f" ] && cp "${p}" "$f"`])
            status = "Choose where to save…"
        })
    }

    // ---------------- toolbar ----------------
    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 60
        color: Qt.rgba(0, 0, 0, 0.18)

        component ToolBtn: HoverButton {
            property string glyph
            property string tip
            width: 40; height: 40; radius: 12
            Glyph { anchors.centerIn: parent; text: parent.glyph; size: 19; color: parent.active ? "#140b06" : Theme.text }
            Rectangle {
                visible: parent.hovered && parent.tip !== ""
                anchors { top: parent.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
                width: tipL.implicitWidth + 14; height: 24; radius: 6; z: 10
                color: Theme.surfaceStrong; border.color: Theme.borderStrong
                Label { id: tipL; anchors.centerIn: parent; text: parent.parent.tip; size: 11 }
            }
        }

        Row {
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 4
            ToolBtn { glyph: String.fromCodePoint(0xf03eb); tip: "Pen"; active: ed.tool === "pen"; activeColor: Theme.accent; onClicked: ed.tool = "pen" }
            ToolBtn { glyph: String.fromCodePoint(0xf0652); tip: "Highlighter"; active: ed.tool === "highlighter"; activeColor: Theme.accent; onClicked: ed.tool = "highlighter" }
            ToolBtn { glyph: String.fromCodePoint(0xf01fe); tip: "Eraser"; active: ed.tool === "eraser"; activeColor: Theme.accent; onClicked: ed.tool = "eraser" }
            Rectangle { width: 1; height: 26; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: ed.colors
                delegate: Rectangle {
                    required property string modelData
                    width: 26; height: 26; radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: modelData
                    border.width: Qt.colorEqual(ed.ink, modelData) ? 3 : 1
                    border.color: Qt.colorEqual(ed.ink, modelData) ? "white" : Theme.borderStrong
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { ed.ink = parent.modelData; if (ed.tool === "eraser") ed.tool = "pen" } }
                }
            }
            Rectangle { width: 1; height: 26; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
            ToolBtn { glyph: String.fromCodePoint(0xf054c); tip: "Undo"; enabled: ed.strokes.length > 0; opacity: enabled ? 1 : 0.4; onClicked: ed.undo() }
            ToolBtn { glyph: String.fromCodePoint(0xf044e); tip: "Redo"; enabled: ed.redoStack.length > 0; opacity: enabled ? 1 : 0.4; onClicked: ed.redo() }
            ToolBtn { glyph: Icons.trash; tip: "Clear markup"; enabled: ed.strokes.length > 0; opacity: enabled ? 1 : 0.4
                onClicked: { ed.redoStack = []; ed.strokes = []; ed.dirty = true; canvas.requestPaint() } }
        }

        Row {
            anchors { right: parent.right; rightMargin: 110; verticalCenter: parent.verticalCenter }
            spacing: 6
            component Act: HoverButton {
                property string glyph
                property string label
                property bool primary: false
                width: aRow.implicitWidth + 24; height: 38; radius: 19
                color: primary ? (hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : (hovered ? Theme.hover : Theme.card)
                Row { id: aRow; anchors.centerIn: parent; spacing: 8
                    Glyph { text: parent.parent.glyph; size: 16; color: parent.parent.primary ? "#140b06" : Theme.text }
                    Label { text: parent.parent.label; size: 12; weight: Font.Medium; color: parent.parent.primary ? "#140b06" : Theme.text } }
            }
            Act { glyph: Icons.copy; label: "Copy"; onClicked: ed.copy() }
            Act { glyph: Icons.folder; label: "Save as"; onClicked: ed.saveAs() }
            Act { glyph: Icons.download; label: "Save"; primary: true; onClicked: ed.save() }
        }
    }

    WindowDots {
        z: 100
        anchors { top: parent.top; topMargin: 23 }
        x: Config.s.buttonsLeft ? 18 : parent.width - width - 18
        readonly property var me: Hyprland.toplevels.values.find(t => t.title === ed.title) ?? null
        onMinimize: Win.minimize(me)
        onMaximize: Win.toggleMaximize(me)
        onClose: Ui.shotFile = ""
    }

    // ---------------- image + markup ----------------
    Item {
        id: stage
        anchors { left: parent.left; right: parent.right; top: bar.bottom; bottom: footer.top; margins: 16 }
        clip: true

        // Native-resolution content, shown scaled to fit; exports at full size.
        Item {
            id: content
            width: img.sourceSize.width
            height: img.sourceSize.height
            readonly property real fit: Math.min(1, stage.width / Math.max(1, width), stage.height / Math.max(1, height))
            scale: fit
            transformOrigin: Item.TopLeft
            x: (stage.width - width * fit) / 2
            y: (stage.height - height * fit) / 2

            Image {
                id: img
                anchors.fill: parent
                source: Ui.shotFile ? "file://" + Ui.shotFile : ""
                cache: false
            }

            Canvas {
                id: canvas
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    for (const s of ed.strokes) {
                        if (s.points.length < 1) continue
                        ctx.globalAlpha = s.tool === "highlighter" ? 0.35 : 1
                        ctx.strokeStyle = s.color
                        ctx.lineWidth = s.width
                        ctx.beginPath()
                        ctx.moveTo(s.points[0].x, s.points[0].y)
                        for (const p of s.points) ctx.lineTo(p.x, p.y)
                        if (s.points.length === 1) ctx.lineTo(s.points[0].x + 0.1, s.points[0].y)
                        ctx.stroke()
                    }
                    ctx.globalAlpha = 1
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: ed.tool === "eraser" ? Qt.PointingHandCursor : Qt.CrossCursor
                property var current: null
                function eraseAt(x, y) {
                    const r = 14 / content.fit
                    const keep = ed.strokes.filter(s => !s.points.some(p => Math.hypot(p.x - x, p.y - y) < r + s.width / 2))
                    if (keep.length !== ed.strokes.length) { ed.strokes = keep; ed.dirty = true; canvas.requestPaint() }
                }
                onPressed: m => {
                    if (ed.tool === "eraser") { eraseAt(m.x, m.y); return }
                    const w = (ed.tool === "highlighter" ? 18 : 4) / content.fit
                    current = { tool: ed.tool, color: String(ed.ink), width: w, points: [{ x: m.x, y: m.y }] }
                    ed.strokes = [...ed.strokes, current]
                    ed.redoStack = []
                    ed.dirty = true
                    canvas.requestPaint()
                }
                onPositionChanged: m => {
                    if (ed.tool === "eraser") { if (pressed) eraseAt(m.x, m.y); return }
                    if (!current) return
                    current.points.push({ x: m.x, y: m.y })
                    canvas.requestPaint()
                }
                onReleased: current = null
            }
        }
    }

    // ---------------- status line ----------------
    Item {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 36
        Label {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            text: (ed.dirty ? "Unsaved markup · " : "") + ed.status
            size: 12; color: Theme.subtext
        }
        Label {
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            text: img.sourceSize.width + " × " + img.sourceSize.height
            size: 12; color: Theme.dim
        }
    }
}
