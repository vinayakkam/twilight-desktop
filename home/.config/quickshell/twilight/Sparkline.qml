import QtQuick
import QtQuick.Shapes

// Filled history graph for 0..1 samples (newest on the right).
Item {
    id: root

    property var values: []
    property int capacity: 120
    property color color: Theme.accent

    readonly property var pts: {
        const n = values.length, out = []
        for (let i = 0; i < n; i++)
            out.push(Qt.point(width * (capacity - n + i) / (capacity - 1), height * (1 - Math.min(1, values[i]))))
        return out
    }

    Rectangle { anchors.fill: parent; radius: 8; color: Qt.rgba(1, 1, 1, 0.04) }

    Shape {
        anchors.fill: parent
        visible: root.pts.length > 1
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                y1: 0; y2: root.height
                GradientStop { position: 0; color: Qt.alpha(root.color, 0.35) }
                GradientStop { position: 1; color: Qt.alpha(root.color, 0.02) }
            }
            startX: root.pts.length ? root.pts[0].x : 0
            startY: root.height
            PathLine { x: root.pts.length ? root.pts[0].x : 0; y: root.pts.length ? root.pts[0].y : root.height }
            PathPolyline { path: root.pts }
            PathLine { x: root.width; y: root.height }
        }
        ShapePath {
            strokeWidth: 1.5
            strokeColor: root.color
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: root.pts.length ? root.pts[0].x : 0
            startY: root.pts.length ? root.pts[0].y : 0
            PathPolyline { path: root.pts }
        }
    }
}
