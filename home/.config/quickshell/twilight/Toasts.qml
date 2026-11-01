import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Pop-up notifications (top-right). Hidden while the notification panel is
// open; suppressed by Do Not Disturb except for critical ones.
PanelWindow {
    id: win

    screen: Ui.focusedScreen()
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "twilight-toast"
    anchors { top: true; right: true }
    margins { top: 8; right: 8 }
    exclusiveZone: 0
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    visible: shown.length > 0 && Ui.open !== "notifications"

    readonly property var shown: Notifs.toasts.filter(n => n && n.tracked)

    Column {
        id: stack
        width: parent.width
        spacing: 8

        Repeater {
            model: ScriptModel { values: win.shown }
            delegate: NotificationCard {
                id: toast
                required property var modelData
                notif: modelData
                toast: true
                width: stack.width
                onClosed: Notifs.hideToast(modelData)

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }

                HoverHandler { id: toastHover }
                Timer {
                    // Critical notifications stay until dismissed.
                    running: toast.modelData.urgency !== NotificationUrgency.Critical && !toastHover.hovered
                    interval: Config.s.toastSeconds * 1000
                    onTriggered: Notifs.hideToast(toast.modelData)
                }
            }
        }
    }
}
