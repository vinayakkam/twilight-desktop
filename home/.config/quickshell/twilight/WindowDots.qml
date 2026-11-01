import QtQuick

// Amber / green / red window buttons with a white symbol on the hovered dot
// and a tooltip, matching the Twilight window bars.
Row {
    id: root

    property bool maximized: false
    signal minimize()
    signal maximize()
    signal close()

    spacing: 8

    component Dot: Rectangle {
        id: dot
        property color tone
        property string glyph
        property string tip
        signal activated()
        width: 14; height: 14; radius: 7
        color: area.containsMouse ? Qt.lighter(tone, 1.1) : tone
        Glyph { anchors.centerIn: parent; visible: area.containsMouse; text: dot.glyph; size: 10; color: "white" }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dot.activated() }
        Rectangle {
            visible: area.containsMouse
            anchors { top: parent.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
            width: tipLabel.implicitWidth + 16; height: 24; radius: 6
            color: Theme.surfaceStrong
            border.color: Theme.borderStrong
            z: 10
            Label { id: tipLabel; anchors.centerIn: parent; text: dot.tip; size: 11 }
        }
    }

    Dot { tone: "#f5a524"; glyph: String.fromCodePoint(0xf1639); tip: "Minimize"; onActivated: root.minimize() }
    Dot { tone: "#3ec56d"; glyph: String.fromCodePoint(0xf0616); tip: root.maximized ? "Restore" : "Maximize"; onActivated: root.maximize() }
    Dot { tone: "#ff5f57"; glyph: String.fromCodePoint(0xf1398); tip: "Close"; onActivated: root.close() }
}
