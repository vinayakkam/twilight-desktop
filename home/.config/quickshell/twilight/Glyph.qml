import QtQuick

// A single icon glyph from Icons.qml.
Text {
    property int size: 16

    font.family: Theme.iconFont
    font.pixelSize: size
    color: Theme.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
