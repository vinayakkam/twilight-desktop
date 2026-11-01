import QtQuick

// Opened by the top bar's power button.
Panel {
    name: "power"
    panelWidth: 240
    panelHeight: actions.implicitHeight + 16
    anchors { top: true; right: true }
    margins { top: 6; right: 8 }

    onIsOpenChanged: if (isOpen) actions.pending = null

    PowerActions {
        id: actions
        anchors { fill: parent; margins: 8 }
    }
}
