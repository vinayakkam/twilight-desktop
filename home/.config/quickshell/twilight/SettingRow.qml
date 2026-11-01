import QtQuick

// One settings line: icon, title, optional description, control on the right.
Rectangle {
    id: root

    property string glyph: ""
    property string title
    property string subtitle: ""
    default property alias control: slot.data

    width: parent?.width ?? 600
    implicitHeight: Math.max(64, texts.implicitHeight + 24)
    radius: Theme.radiusItem
    color: Theme.card

    Glyph {
        id: icon
        visible: root.glyph !== ""
        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
        text: root.glyph
        size: 20
        color: Theme.text
    }
    Column {
        id: texts
        anchors { left: icon.visible ? icon.right : parent.left; leftMargin: 18; right: slot.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 2
        Label { width: parent.width; text: root.title; size: 13; weight: Font.Medium }
        Label { width: parent.width; visible: text !== ""; text: root.subtitle; size: 11; color: Theme.subtext; wrapMode: Text.WordWrap; elide: Text.ElideNone }
    }
    Row {
        id: slot
        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
        spacing: 8
    }
}
