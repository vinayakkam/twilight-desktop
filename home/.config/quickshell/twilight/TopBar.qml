import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray

PanelWindow {
    id: bar

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "twilight-bar"
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"

    Component.onCompleted: Ui.shellWindows = [...Ui.shellWindows, bar]
    Component.onDestruction: Ui.shellWindows = Ui.shellWindows.filter(w => w !== bar)

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.border
        }
    }

    // ---------------- Left: launcher mark + workspaces ----------------
    Row {
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 6

        HoverButton {
            width: 30; height: 26
            tooltip: "Start"
            onClicked: Ui.toggle("start", bar.screen)
            StartMark {
                anchors.centerIn: parent
                size: 15
                glowEnabled: false
                hovered: parent.hovered
                open: Ui.open === "start" && Ui.screen === bar.screen
            }
        }

        Rectangle { width: 1; height: 16; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }

        Row {
            id: workspaces
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            readonly property int activeId: bar.monitor?.activeWorkspace?.id ?? 1
            readonly property var occupied: Hyprland.workspaces.values.filter(w => w.id > 0 && w.toplevels.values.length > 0).map(w => w.id)
            readonly property int count: Math.max(4, activeId, ...occupied)

            Repeater {
                model: workspaces.count
                delegate: HoverButton {
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool isActive: wsId === workspaces.activeId
                    readonly property bool isOccupied: workspaces.occupied.includes(wsId)

                    width: isActive ? 30 : 24
                    height: 22
                    radius: 11
                    active: isActive
                    activeColor: "transparent"
                    Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: parent.isActive
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.accent }
                            GradientStop { position: 1; color: Theme.accent2 }
                        }
                    }
                    Label {
                        anchors.centerIn: parent
                        text: parent.wsId
                        size: 12
                        weight: parent.isActive ? Font.DemiBold : Font.Medium
                        color: parent.isActive ? "white" : parent.isOccupied ? Theme.text : Theme.dim
                    }
                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsId} })`)
                }
            }
        }

        // Focused window: icon and title (window buttons live on the windows).
        Row {
            id: winBlock
            readonly property var win: Win.focusedOn(bar.monitor)
            readonly property var entry: Apps.forAppId(win?.wayland?.appId ?? win?.lastIpcObject?.class ?? "")
            // Never run into the centre group.
            readonly property real room: (Config.s.showMeters ? memMeter.x : date.x) - winBlock.mapToItem(bar.contentItem, 0, 0).x - 24
            visible: win !== null && room > 140
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Rectangle { width: 1; height: 16; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 6; height: 1 }
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                source: Apps.iconOf(winBlock.entry)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 6
                rightPadding: 6
                width: Math.min(implicitWidth, winBlock.room - 22)
                text: winBlock.win?.title ?? ""
                size: 12
                color: Theme.subtext
            }
        }
    }

    // ---------------- Centre: memory · date · time · CPU ----------------
    // The time itself stays exactly centred on the screen; this is the only
    // clock in the desktop. Click date or time for the calendar.
    SystemClock { id: clock; precision: SystemClock.Minutes }
    HoverButton {
        id: dateTime
        anchors.centerIn: time
        anchors.horizontalCenterOffset: -(date.implicitWidth + 10) / 2
        width: date.implicitWidth + 10 + time.implicitWidth + 20
        height: 26
        active: Ui.open === "calendar" && Ui.screen === bar.screen
        onClicked: Ui.toggle("calendar", bar.screen, time.mapToItem(bar.contentItem, time.width / 2, 0).x)
    }
    Label {
        id: time
        anchors.centerIn: parent
        // Centre the whole memory · date · time · CPU group, not just the time.
        anchors.horizontalCenterOffset: ((date.implicitWidth + 10 + (memMeter.visible ? memMeter.width + 12 : 0))
                                         - (cpuMeter.visible ? cpuMeter.width + 12 : 0)) / 2
        text: Qt.formatTime(clock.date, Config.s.clock24 ? "HH:mm" : "h:mm AP")
        size: 14
        weight: Font.DemiBold
        font.letterSpacing: 0.3
    }
    Label {
        id: date
        anchors { right: time.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: Qt.formatDate(clock.date, "ddd d MMM")
        size: 13
        weight: Font.Medium
        color: Theme.subtext
    }
    HoverButton {
        id: memMeter
        visible: Config.s.showMeters
        anchors { right: date.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        width: memRing.implicitWidth + 12; height: 26
        active: Ui.open === "mem" && Ui.screen === bar.screen
        onClicked: Ui.toggle("mem", bar.screen, memMeter.mapToItem(bar.contentItem, memMeter.width / 2, 0).x)
        Ring { id: memRing; anchors.centerIn: parent; value: Sys.mem; color: Theme.accent2 }
    }
    HoverButton {
        id: cpuMeter
        visible: Config.s.showMeters
        anchors { left: time.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: cpuRing.implicitWidth + 12; height: 26
        active: Ui.open === "cpu" && Ui.screen === bar.screen
        onClicked: Ui.toggle("cpu", bar.screen, cpuMeter.mapToItem(bar.contentItem, cpuMeter.width / 2, 0).x)
        Ring { id: cpuRing; anchors.centerIn: parent; value: Sys.cpu; color: Theme.accent }
    }

    // ---------------- Right: tray, media, bell, quick settings, power ----------------
    Row {
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 4
        layoutDirection: Qt.LeftToRight

        // Status-notifier tray (Discord, Steam, …), kept compact.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: SystemTray.items
                delegate: HoverButton {
                    id: trayItem
                    required property SystemTrayItem modelData
                    width: 26; height: 26
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 16
                        source: trayItem.modelData.icon
                    }
                    onClicked: m => {
                        const p = trayItem.mapToItem(bar.contentItem, 0, trayItem.height + 6)
                        if (m.button === Qt.RightButton || (m.button === Qt.LeftButton && trayItem.modelData.onlyMenu)) {
                            if (trayItem.modelData.hasMenu) trayItem.modelData.display(bar, p.x, p.y)
                        } else if (m.button === Qt.MiddleButton) {
                            trayItem.modelData.secondaryActivate()
                        } else {
                            trayItem.modelData.activate()
                        }
                    }
                }
            }
        }

        // Media: shown only when a player exists.
        Row {
            id: media
            readonly property MprisPlayer player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
            visible: player !== null && (player.trackTitle ?? "") !== ""
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            rightPadding: 6

            ClippingRectangle {
                width: 22; height: 22; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.card
                visible: (media.player?.trackArtUrl ?? "") !== ""
                Image {
                    anchors.fill: parent
                    source: media.player?.trackArtUrl ?? ""
                    sourceSize: Qt.size(44, 44)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 6
                rightPadding: 4
                Label { text: media.player?.trackTitle ?? ""; size: 11; weight: Font.DemiBold; width: Math.min(implicitWidth, 150) }
                Label { text: media.player?.trackArtist ?? ""; size: 10; color: Theme.subtext; width: Math.min(implicitWidth, 150); visible: text !== "" }
            }
            HoverButton {
                width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter
                visible: media.player?.canGoPrevious ?? false
                onClicked: media.player.previous()
                Glyph { anchors.centerIn: parent; text: Icons.prev; size: 16 }
            }
            HoverButton {
                width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter
                onClicked: media.player.togglePlaying()
                Glyph { anchors.centerIn: parent; text: media.player?.isPlaying ? Icons.pause : Icons.play; size: 16 }
            }
            HoverButton {
                width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter
                visible: media.player?.canGoNext ?? false
                onClicked: media.player.next()
                Glyph { anchors.centerIn: parent; text: Icons.next; size: 16 }
            }
        }

        Rectangle { width: 1; height: 16; color: Theme.border; anchors.verticalCenter: parent.verticalCenter; visible: media.visible }

        // A. Notification bell -> notification panel.
        HoverButton {
            id: bell
            width: 30; height: 26
            anchors.verticalCenter: parent.verticalCenter
            active: Ui.open === "notifications" && Ui.screen === bar.screen
            onClicked: Ui.toggle("notifications", bar.screen)
            Glyph {
                anchors.centerIn: parent
                text: Sys.dnd ? Icons.bellSleep : Notifs.unread > 0 ? Icons.bellBadge : Icons.bell
                color: Notifs.unread > 0 && !Sys.dnd ? Theme.accent : Theme.text
                size: 17
            }
        }

        // B. Quick-settings button: status icons + tune glyph.
        HoverButton {
            id: qsButton
            height: 26
            width: statusRow.implicitWidth + 16
            anchors.verticalCenter: parent.verticalCenter
            active: Ui.open === "quicksettings" && Ui.screen === bar.screen
            onClicked: Ui.toggle("quicksettings", bar.screen)
            wheelEnabled: true
            onWheel: w => Sys.setVolume(Sys.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 9

                Glyph { text: Net.glyph(); size: 16; color: Net.wifiOn || Net.wiredDevice ? Theme.text : Theme.dim }
                Glyph { text: Icons.bluetooth; size: 15; visible: Sys.btOn; color: Sys.btConnected.length ? Theme.accent : Theme.text }
                Glyph { text: Sys.muted ? Icons.volOff : Sys.volume > 0.6 ? Icons.volHigh : Sys.volume > 0.25 ? Icons.volMed : Icons.volLow; size: 16 }
                Glyph { text: Sys.micMuted ? Icons.micOff : Icons.mic; size: 15; color: Sys.micMuted ? Theme.red : Theme.text }
                Row {
                    visible: Sys.hasBattery
                    spacing: 3
                    Glyph { text: Sys.batteryGlyph(); size: 16; color: Sys.batteryPct < 0.15 && !Sys.charging ? Theme.red : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: Math.round(Sys.batteryPct * 100) + "%"; size: 12; weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                }
                Glyph { text: Icons.tune; size: 15; color: Theme.subtext }
            }
        }

        HoverButton {
            width: 30; height: 26
            anchors.verticalCenter: parent.verticalCenter
            active: Ui.open === "power" && Ui.screen === bar.screen
            onClicked: Ui.toggle("power", bar.screen)
            Glyph { anchors.centerIn: parent; text: Icons.power; size: 16 }
        }
    }
}
