import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Base for floating panels (Start, notifications, quick settings, power).
// Opens on Ui.open === name; closes on outside click (focus grab),
// Escape, or another panel opening. Fades/slides in and out.
PanelWindow {
    id: panel

    required property string name
    property int panelWidth: 380
    property int panelHeight: 400
    // Direction the panel slides in from: -1 = from above, +1 = from below.
    property int slideFrom: -1
    property bool keyboard: false
    default property alias content: body.data
    readonly property bool isOpen: Ui.open === name

    screen: Ui.screen ?? Quickshell.screens[0]
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "twilight-panel"
    WlrLayershell.keyboardFocus: !isOpen ? WlrKeyboardFocus.None : keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

    property real progress: isOpen ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    visible: progress > 0.001

    HyprlandFocusGrab {
        active: panel.isOpen && panel.visible
        windows: [panel, ...Ui.shellWindows]
        onCleared: if (panel.isOpen) Ui.close()
    }

    Rectangle {
        id: frame
        width: panel.panelWidth
        height: panel.panelHeight
        radius: Theme.radiusPanel
        // Near-opaque: panels fade in/out, so they get no compositor blur.
        color: Theme.surfaceStrong
        border.color: Theme.border
        border.width: 1
        opacity: panel.progress
        transform: Translate { y: (1 - panel.progress) * 14 * panel.slideFrom }
        scale: 0.97 + 0.03 * panel.progress
        transformOrigin: panel.slideFrom < 0 ? Item.Top : Item.Bottom

        Item {
            id: body
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Ui.close()
        }
    }
}
