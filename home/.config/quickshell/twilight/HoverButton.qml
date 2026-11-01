import QtQuick

// Rounded hit area with restrained hover/press feedback. Content goes inside.
Rectangle {
    id: root

    property bool active: false
    property color activeColor: Theme.accentSoft
    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed
    property alias acceptedButtons: mouse.acceptedButtons
    property string tooltip: ""
    // Only buttons that react to scrolling take wheel events; all others let
    // them through so lists and pages underneath can scroll.
    property bool wheelEnabled: false

    signal clicked(var mouse)
    signal wheel(var wheel)

    radius: Theme.radiusSmall
    color: active ? activeColor
         : mouse.pressed ? Theme.pressed
         : mouse.containsMouse ? Theme.hover
         : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: m => root.clicked(m)
        onWheel: w => {
            if (!root.wheelEnabled) { w.accepted = false; return }
            root.wheel(w)
        }
    }
}
