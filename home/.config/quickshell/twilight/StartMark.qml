import QtQuick
import QtQuick.Effects

// The Twilight launcher mark: three rounded tiles and an "orbit" dot.
// Animations run only on state changes (hover, press, open), never in a loop.
Item {
    id: root

    property real size: 22
    property bool hovered: false
    property bool pressed: false
    property bool open: false
    property bool glowEnabled: true

    implicitWidth: size
    implicitHeight: size

    property real gap: open ? size * 0.16 : hovered ? size * 0.13 : size * 0.09
    readonly property real tile: (size - gap) / 2
    Behavior on gap { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    // Brief glow pulse, e.g. when the menu opens.
    property real pulse: 0
    function flash() { pulseAnim.restart() }
    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: root; property: "pulse"; to: 1; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "pulse"; to: 0; duration: 520; easing.type: Easing.InOutQuad }
    }

    Item {
        id: mark
        anchors.centerIn: parent
        // With the glow on, MultiEffect draws the mark (source + shadow).
        visible: !root.glowEnabled
        width: root.size
        height: root.size
        rotation: root.open ? 45 : 0
        scale: root.pressed ? 0.86 : root.hovered ? 1.06 : 1
        Behavior on rotation { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

        component Tile: Rectangle {
            width: root.tile
            height: root.tile
            radius: root.tile * 0.32
        }

        Tile {
            x: 0; y: 0
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(Theme.accent, 1.15) }
                GradientStop { position: 1; color: Theme.accent }
            }
        }
        // The orbit dot replaces the fourth tile.
        Rectangle {
            width: root.tile * (root.hovered || root.open ? 0.92 : 0.8)
            height: width
            radius: width / 2
            x: root.size - root.tile + (root.tile - width) / 2
            y: (root.tile - width) / 2
            color: Qt.lighter(Theme.accent2, 1.1)
            Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }
        }
        Tile {
            x: 0; y: root.size - root.tile
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.accent }
                GradientStop { position: 1; color: Qt.darker(Theme.accent, 1.15) }
            }
        }
        Tile {
            x: root.size - root.tile; y: root.size - root.tile
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.accent2 }
                GradientStop { position: 1; color: Qt.darker(Theme.accent2, 1.1) }
            }
        }
    }

    // Soft blue-violet glow behind the mark.
    MultiEffect {
        visible: root.glowEnabled
        source: mark
        anchors.fill: mark
        rotation: mark.rotation
        scale: mark.scale
        z: -1
        shadowEnabled: true
        shadowColor: Theme.accent
        shadowBlur: 1.0
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        shadowOpacity: 0.35 + (root.hovered ? 0.3 : 0) + (root.open ? 0.25 : 0) + root.pulse * 0.4
        blurMax: 24
        autoPaddingEnabled: true
        Behavior on shadowOpacity { NumberAnimation { duration: Theme.normal } }
    }
}
