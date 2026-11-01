import QtQuick
import QtQuick.Shapes

// Circular usage meter with the percentage beside it.
Row {
    id: root

    property real value: 0
    property color color: Theme.accent
    property int size: 18

    spacing: 5
    readonly property color tone: value > 0.85 ? Theme.red : value > 0.65 ? Theme.yellow : color

    Shape {
        width: root.size
        height: root.size
        anchors.verticalCenter: parent.verticalCenter
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.14)
            strokeWidth: 2.5
            fillColor: "transparent"
            PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size / 2 - 1.5; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.tone
            strokeWidth: 2.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: root.size / 2 - 1.5; radiusY: radiusX
                startAngle: -90
                // No animation: the rings update every 2 s and redrawing curves
                // for every frame of an animation costs CPU for nothing.
                sweepAngle: Math.max(1, 360 * Math.min(1, root.value))
            }
        }
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.value * 100) + "%"
        size: 12
        weight: Font.Medium
        color: Theme.subtext
    }
}
