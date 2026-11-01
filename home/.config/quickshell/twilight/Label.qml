import QtQuick

Text {
    property int size: 13
    property int weight: Font.Normal

    font.family: Theme.font
    font.pixelSize: size
    font.weight: weight
    color: Theme.text
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
