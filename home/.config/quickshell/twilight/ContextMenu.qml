import QtQuick
import Quickshell
import Quickshell.Wayland

// Right-click menu at the pointer. items: [{ glyph, label, action }, ...]
// or { separator: true }. Closes on any click outside (ClickCatcher), on
// Escape, or when an item is chosen.
PanelWindow {
    id: menu

    property var items: []
    property real px: 0
    property real py: 0
    property bool shown: false

    // x, y are screen coordinates.
    function openAt(scr, x, y, list) {
        Ui.dismissAll()
        items = list
        screen = scr
        px = x
        py = y
        shown = true
        Ui.menuOpen = true
    }
    function hide() { shown = false; Ui.menuOpen = false }

    Connections {
        target: Ui
        function onDismissSerialChanged() { if (menu.shown) menu.hide() }
    }

    visible: shown
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "twilight-panel"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    // Keep fully on screen; open upwards when there's no room below.
    margins.left: Math.max(4, Math.min(px, (screen?.width ?? 1920) - implicitWidth - 4))
    margins.top: py + implicitHeight > (screen?.height ?? 1080) - 4 ? Math.max(4, py - implicitHeight) : py
    implicitWidth: 250
    implicitHeight: col.implicitHeight + 12
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusItem
        color: Theme.surfaceStrong
        border.color: Theme.borderStrong
        focus: menu.shown
        Keys.onEscapePressed: menu.hide()

        Column {
            id: col
            anchors { fill: parent; margins: 6 }
            Repeater {
                model: menu.items
                delegate: Loader {
                    required property var modelData
                    width: col.width
                    sourceComponent: modelData.separator ? sep : row
                    Component {
                        id: sep
                        Item { height: 9; Rectangle { anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.border } }
                    }
                    Component {
                        id: row
                        HoverButton {
                            height: 36
                            onClicked: { menu.hide(); modelData.action() }
                            Row {
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                spacing: 12
                                Glyph { text: modelData.glyph ?? ""; size: 16; width: 18 }
                                Label { text: modelData.label; size: 13 }
                            }
                        }
                    }
                }
            }
        }
    }
}
