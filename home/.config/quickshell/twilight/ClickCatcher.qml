import QtQuick
import Quickshell
import Quickshell.Wayland

// Invisible full-screen layer under any open menu or panel: a click anywhere
// else closes it, like on Windows. Sits on the Top layer, below the Overlay
// layer that menus and panels use.
PanelWindow {
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "twilight-catcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: Ui.open !== "" || Ui.menuOpen

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: Ui.dismissAll()
    }
}
