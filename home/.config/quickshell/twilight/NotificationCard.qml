import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// One notification: icon, app, title, message, relative time, actions.
Rectangle {
    id: card

    required property Notification notif
    property bool toast: false
    property real now: Date.now()
    signal closed()

    readonly property var defaultAction: notif?.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: notif?.actions.filter(a => a.identifier !== "default") ?? []

    implicitHeight: content.implicitHeight + 24
    radius: Theme.radiusItem
    color: toast ? Theme.surfaceStrong : hover.hovered ? Qt.rgba(1, 1, 1, 0.075) : Theme.card
    border.color: notif?.urgency === NotificationUrgency.Critical ? Qt.rgba(1, 0.42, 0.5, 0.6) : toast ? Theme.borderStrong : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    HoverHandler { id: hover }
    TapHandler {
        onTapped: {
            if (card.defaultAction) { card.defaultAction.invoke(); Ui.close() }
        }
    }

    Row {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 12

        Item {
            width: 32; height: 32
            IconImage {
                id: icon
                anchors.fill: parent
                source: Notifs.iconFor(card.notif)
                visible: status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                visible: !icon.visible
                radius: 10
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.accent }
                    GradientStop { position: 1; color: Theme.accent2 }
                }
                Glyph { anchors.centerIn: parent; text: Icons.bell; size: 16; color: "white" }
            }
        }

        Column {
            width: parent.width - 44
            spacing: 3

            Item {
                width: parent.width
                height: 16
                Label {
                    anchors { left: parent.left; right: timeLabel.left; rightMargin: 8 }
                    text: card.notif?.appName || "Notification"
                    size: 11
                    color: Theme.subtext
                }
                Label {
                    id: timeLabel
                    anchors.right: parent.right
                    anchors.rightMargin: hover.hovered ? 24 : 0
                    text: Notifs.relative(Notifs.timeOf(card.notif) + (card.now - card.now))
                    size: 11
                    color: Theme.dim
                }
            }
            Label {
                width: parent.width
                text: card.notif?.summary ?? ""
                size: 13
                weight: Font.DemiBold
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: card.notif?.body ?? ""
                textFormat: Text.StyledText
                size: 12
                color: Theme.subtext
                wrapMode: Text.WordWrap
                maximumLineCount: card.toast ? 3 : 5
            }
            Flow {
                width: parent.width
                visible: card.buttons.length > 0
                spacing: 6
                topPadding: 6
                Repeater {
                    model: card.buttons
                    delegate: HoverButton {
                        required property NotificationAction modelData
                        width: actLabel.implicitWidth + 24
                        height: 28
                        color: hovered ? Theme.pressed : Theme.hover
                        onClicked: { modelData.invoke(); Ui.close() }
                        Label { id: actLabel; anchors.centerIn: parent; text: parent.modelData.text; size: 12 }
                    }
                }
            }
        }
    }

    HoverButton {
        anchors { top: parent.top; right: parent.right; margins: 8 }
        width: 22; height: 22; radius: 11
        visible: hover.hovered
        onClicked: card.closed()
        Glyph { anchors.centerIn: parent; text: Icons.close; size: 14; color: Theme.subtext }
    }
}
