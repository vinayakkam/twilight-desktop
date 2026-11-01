import QtQuick
import Quickshell
import Quickshell.Hyprland

// "Get started" guide for people coming from Windows/KDE: how to do things
// with the mouse first, shortcuts second. Opens once on the first login,
// then from the desktop / Start-button right-click menus.
FloatingWindow {
    id: win

    title: "Get started with Twilight"
    visible: Ui.getStartedOpen
    readonly property var scr: Ui.focusedScreen()
    implicitWidth: Math.min(900, (scr?.width ?? 1920) - 80)
    implicitHeight: Math.min(640, (scr?.height ?? 1080) - Theme.barHeight - Theme.taskbarHeight - Theme.taskbarGap * 2 - 24)
    color: Theme.surfaceStrong
    onVisibleChanged: if (!visible) { Ui.getStartedOpen = false; Config.set("welcomeShown", true) }

    readonly property var mouse: [
        [Icons.apps, "Open apps", "Click the Start button (left of the taskbar). Type to search, or click All apps."],
        [Icons.winMax, "Move, maximise, close windows", "Use the dots on each window: amber minimises, green maximises, red closes. Drag the title bar to move."],
        [Icons.taskView, "See all windows", "Right-click the desktop or taskbar → Task View. Click a preview to jump to it."],
        [Icons.desktop, "Show the desktop", "Right-click the taskbar → Show desktop. Choose it again to bring windows back."],
        [Icons.restart, "Restore a minimised window", "Click its icon on the taskbar (a dim dot means minimised)."],
        [Icons.chevronDown, "Hidden taskbar", "When a window is maximised the taskbar steps aside — rest the pointer on the bottom edge."],
        [Icons.cog, "Change anything", "Right-click the desktop → Personalise, or Start → Settings. No config files to edit."],
        [Icons.tune, "Wi-Fi, sound, brightness", "Click the status icons at the top-right."],
        [Icons.bell, "Notifications", "Click the bell at the top-right."],
        [Icons.folder, "Your files", "Same files as in KDE: Start → folder icon, or right-click the Start button → File Explorer."],
        [Icons.taskManager, "Something stuck?", "Right-click the Start button → Task Manager."],
    ]
    readonly property var keys: [
        ["Win", "Start menu"], ["Win + E", "Files"], ["Win + I", "Settings"], ["Win + D", "Show desktop"],
        ["Win + Tab", "Task View"], ["Alt + Tab", "Switch windows"], ["Win + L", "Lock"], ["Win + Shift + S", "Screenshot area"],
        ["Win + ↑ / ↓", "Maximise / minimise"], ["Alt + F4", "Close window"], ["Win + .", "Emoji"], ["Ctrl + Shift + Esc", "Task Manager"],
        ["Win + 1…9", "Go to desktop"], ["Win + A / N", "Quick settings / notifications"],
    ]

    WindowDots {
        z: 100
        anchors { top: parent.top; topMargin: 16 }
        x: Config.s.buttonsLeft ? 18 : parent.width - width - 18
        readonly property var me: Hyprland.toplevels.values.find(t => t.title === win.title) ?? null
        onMinimize: Win.minimize(me)
        onMaximize: Win.toggleMaximize(me)
        onClose: Ui.getStartedOpen = false
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            x: 32; y: 28
            width: parent.width - 64
            spacing: 14

            Row {
                spacing: 16
                StartMark { size: 36; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: "Welcome to Twilight"; size: 22; weight: Font.DemiBold }
                    Label { text: "Everything works with the mouse. Shortcuts are optional extras."; size: 13; color: Theme.subtext }
                }
            }

            Label { text: "With the mouse"; size: 14; weight: Font.DemiBold; color: Theme.accent; topPadding: 8 }
            Grid {
                columns: 2
                columnSpacing: 12
                rowSpacing: 10
                Repeater {
                    model: win.mouse
                    delegate: Rectangle {
                        required property var modelData
                        width: (col.width - 12) / 2
                        height: Math.max(70, tipText.implicitHeight + 28)
                        radius: Theme.radiusItem
                        color: Theme.card
                        Glyph { id: g; anchors { left: parent.left; leftMargin: 16; top: parent.top; topMargin: 16 }
                            text: parent.modelData[0]; size: 20; color: Theme.accent }
                        Column {
                            id: tipText
                            anchors { left: g.right; leftMargin: 14; right: parent.right; rightMargin: 14; top: parent.top; topMargin: 13 }
                            spacing: 3
                            Label { width: parent.width; text: modelData[1]; size: 13; weight: Font.DemiBold }
                            Label { width: parent.width; text: modelData[2]; size: 12; color: Theme.subtext; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                        }
                    }
                }
            }

            Label { text: "Shortcuts (Windows-style)"; size: 14; weight: Font.DemiBold; color: Theme.accent; topPadding: 8 }
            Grid {
                columns: 2
                columnSpacing: 12
                rowSpacing: 6
                Repeater {
                    model: win.keys
                    delegate: Rectangle {
                        required property var modelData
                        width: (col.width - 12) / 2
                        height: 40
                        radius: Theme.radiusSmall
                        color: Theme.card
                        Rectangle {
                            id: kbd
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            width: keyLabel.implicitWidth + 16; height: 26; radius: 6
                            color: Qt.rgba(1, 1, 1, 0.1)
                            border.color: Theme.borderStrong
                            Label { id: keyLabel; anchors.centerIn: parent; text: parent.parent.modelData[0]; size: 12; weight: Font.Medium }
                        }
                        Label { anchors { left: kbd.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: parent.modelData[1]; size: 12; color: Theme.subtext }
                    }
                }
            }

            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                topPadding: 8
                text: "Open this guide again any time: right-click the desktop or the Start button → Get started."
                size: 12; color: Theme.subtext
            }
        }
    }
}
