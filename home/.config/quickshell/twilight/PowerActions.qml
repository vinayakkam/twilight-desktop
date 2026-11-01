import QtQuick

// Lock / Sleep / Sign out / Restart / Shut down. The disruptive ones ask for
// confirmation first.
Column {
    id: root

    property var pending: null
    spacing: 2

    readonly property var actions: [
        { glyph: Icons.lock,    label: "Lock",      run: () => Sys.lock(),     confirm: false },
        { glyph: Icons.sleep,   label: "Sleep",     run: () => Sys.suspend(),  confirm: false },
        { glyph: Icons.logout,  label: "Sign out",  run: () => Sys.logout(),   confirm: true },
        { glyph: Icons.restart, label: "Restart",   run: () => Sys.reboot(),   confirm: true },
        { glyph: Icons.power,   label: "Shut down", run: () => Sys.poweroff(), confirm: true },
    ]

    Repeater {
        model: root.pending ? [] : root.actions
        delegate: HoverButton {
            required property var modelData
            width: root.width
            height: 38
            onClicked: modelData.confirm ? root.pending = modelData : modelData.run()
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 12
                Glyph { text: modelData.glyph; size: 17 }
                Label { text: modelData.label; size: 13 }
            }
        }
    }

    // Confirmation step.
    Column {
        visible: root.pending !== null
        width: root.width
        spacing: 10
        topPadding: 6
        Label {
            width: parent.width
            leftPadding: 12
            text: (root.pending?.label ?? "") + " now?"
            size: 14
            weight: Font.DemiBold
        }
        Label {
            width: parent.width
            leftPadding: 12
            text: "Unsaved work in open apps may be lost."
            size: 12
            color: Theme.subtext
            wrapMode: Text.WordWrap
        }
        Row {
            leftPadding: 8
            spacing: 8
            HoverButton {
                width: (root.width - 24) / 2; height: 36
                color: hovered ? Theme.hover : Theme.card
                onClicked: root.pending = null
                Label { anchors.centerIn: parent; text: "Cancel"; size: 13 }
            }
            HoverButton {
                width: (root.width - 24) / 2; height: 36
                color: hovered ? Qt.lighter(Theme.red, 1.1) : Theme.red
                onClicked: { const a = root.pending; root.pending = null; a.run() }
                Label { anchors.centerIn: parent; text: root.pending?.label ?? ""; size: 13; weight: Font.DemiBold; color: "#1a0b10" }
            }
        }
    }
}
