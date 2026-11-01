import QtQuick
import Quickshell

// Opened by the bell. Lists this session's notifications grouped by day.
Panel {
    id: panel

    name: "notifications"
    panelWidth: 400
    panelHeight: Math.min((screen?.height ?? 900) - Theme.barHeight - 120, Math.max(220, 64 + list.contentHeight + 16))
    anchors { top: true; right: true }
    margins { top: 6; right: 8 }

    // Relative timestamps refresh while open (not a clock).
    property real now: Date.now()
    Timer { running: panel.isOpen; repeat: true; interval: 30000; triggeredOnStart: true; onTriggered: panel.now = Date.now() }

    readonly property var rows: {
        const out = []
        let last = ""
        for (const n of Notifs.list) {
            const g = Notifs.dayGroup(Notifs.timeOf(n))
            if (g !== last) { out.push({ key: "h:" + g, header: g }); last = g }
            out.push({ key: "n:" + n.id, n })
        }
        return out
    }

    SystemClock { id: day; precision: SystemClock.Hours }

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        height: 40
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Label { text: "Notifications"; size: 16; weight: Font.DemiBold }
            Label { text: Qt.formatDate(day.date, "dddd, d MMMM"); size: 11; color: Theme.subtext }
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6
            HoverButton {
                width: 34; height: 30; radius: 15
                active: Sys.dnd
                onClicked: Sys.dnd = !Sys.dnd
                Glyph { anchors.centerIn: parent; text: Sys.dnd ? Icons.bellSleep : Icons.bellOff; size: 16; color: Sys.dnd ? Theme.accent : Theme.subtext }
            }
            HoverButton {
                visible: Notifs.count > 0
                width: clearRow.implicitWidth + 22; height: 30; radius: 15
                color: hovered ? Theme.hover : Theme.card
                onClicked: Notifs.clearAll()
                Row { id: clearRow; anchors.centerIn: parent; spacing: 6
                    Glyph { text: Icons.clearAll; size: 14 }
                    Label { text: "Clear all"; size: 12 } }
            }
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; margins: 12; topMargin: 10 }
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel { values: panel.rows; objectProp: "key" }
        delegate: Loader {
            required property var modelData
            width: list.width
            sourceComponent: modelData.header ? headerRow : cardRow
            Component {
                id: headerRow
                Label { text: modelData.header; size: 12; weight: Font.DemiBold; color: Theme.accent; leftPadding: 4; height: 22 }
            }
            Component {
                id: cardRow
                NotificationCard {
                    notif: modelData.n
                    now: panel.now
                    onClosed: Notifs.dismiss(modelData.n)
                }
            }
        }
        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal } }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast } }
    }

    // Empty state.
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 20
        visible: Notifs.count === 0
        spacing: 10
        Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: Sys.dnd ? Icons.bellSleep : Icons.bell; size: 34; color: Theme.dim }
        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "No new notifications"; color: Theme.subtext }
        Label { anchors.horizontalCenter: parent.horizontalCenter; visible: Sys.dnd; text: "Do not disturb is on"; size: 11; color: Theme.dim }
    }
}
