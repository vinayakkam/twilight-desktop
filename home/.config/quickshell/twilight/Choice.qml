import QtQuick

// Segmented choice. options: [[value, label], ...]
Rectangle {
    id: root

    property var options: []
    property var value
    signal picked(var value)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 34
    radius: 17
    color: Theme.card

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: root.options
            delegate: HoverButton {
                required property var modelData
                width: lbl.implicitWidth + 24
                height: 28
                radius: 14
                active: root.value === modelData[0]
                activeColor: Theme.accent
                onClicked: root.picked(modelData[0])
                Label { id: lbl; anchors.centerIn: parent; text: parent.modelData[1]; size: 12
                        color: parent.active ? "#140b06" : Theme.subtext; weight: parent.active ? Font.DemiBold : Font.Normal }
            }
        }
    }
}
