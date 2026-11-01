import QtQuick

// Minimal horizontal slider (0..1). Emits moved(value) while dragging,
// clicking or scrolling; `value` follows the real system state.
Item {
    id: root

    property real value: 0
    property real step: 0.05
    signal moved(real value)

    implicitHeight: 24

    function setFrom(x) {
        const v = Math.max(0, Math.min(1, x / track.width))
        root.moved(Math.round(v / step) * step)
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.12)

        Rectangle {
            width: Math.max(height, track.width * root.value)
            height: parent.height
            radius: 3
            opacity: root.enabled ? 1 : 0.4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.accent }
                GradientStop { position: 1; color: Theme.accent2 }
            }
        }
    }

    Rectangle {
        x: track.width * root.value - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: mouse.pressed || mouse.containsMouse ? 16 : 14
        height: width
        radius: width / 2
        color: "white"
        visible: root.enabled
        Behavior on width { NumberAnimation { duration: Theme.fast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: m => root.setFrom(m.x)
        onPositionChanged: m => { if (pressed) root.setFrom(m.x) }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
