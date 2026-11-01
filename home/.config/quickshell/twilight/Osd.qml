import QtQuick
import Quickshell
import Quickshell.Wayland

// Volume / brightness / keyboard-backlight indicator above the taskbar.
PanelWindow {
    id: osd

    screen: Ui.focusedScreen()
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "twilight-osd"
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true
    margins.bottom: Theme.taskbarHeight + Theme.taskbarGap * 2 + 16
    implicitWidth: 240
    implicitHeight: 48
    color: "transparent"
    mask: Region {}
    visible: shownProgress > 0.01

    property bool active: false
    property real shownProgress: active ? 1 : 0
    Behavior on shownProgress { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    Connections {
        target: Sys
        function onOsdSerialChanged() { osd.active = true; hideTimer.restart() }
    }
    Timer { id: hideTimer; interval: 1400; onTriggered: osd.active = false }

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Theme.surfaceStrong
        border.color: Theme.border
        opacity: osd.shownProgress
        transform: Translate { y: (1 - osd.shownProgress) * 10 }

        Row {
            anchors.centerIn: parent
            spacing: 12
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                size: 18
                text: Sys.osdKind === "brightness" ? Icons.brightness
                    : Sys.osdKind === "kbd" ? Icons.keyboard
                    : Sys.osdValue === 0 ? Icons.volOff : Icons.volHigh
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 140; height: 6; radius: 3
                color: Qt.rgba(1, 1, 1, 0.12)
                Rectangle {
                    width: parent.width * Sys.osdValue
                    height: parent.height
                    radius: 3
                    Behavior on width { NumberAnimation { duration: Theme.fast } }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.accent }
                        GradientStop { position: 1; color: Theme.accent2 }
                    }
                }
            }
            Label { anchors.verticalCenter: parent.verticalCenter; text: Math.round(Sys.osdValue * 100); size: 12; width: 28; color: Theme.subtext }
        }
    }
}
