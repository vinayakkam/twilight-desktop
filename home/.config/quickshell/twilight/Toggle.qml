import QtQuick

// On/off switch.
Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 44
    implicitHeight: 24
    radius: height / 2
    color: checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.14)
    border.color: checked ? "transparent" : Theme.borderStrong
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Rectangle {
        width: 18; height: 18; radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        color: "white"
        Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
