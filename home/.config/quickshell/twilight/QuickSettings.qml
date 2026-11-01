import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower

// Opened by the quick-settings button. Every control reflects and changes
// real system state.
Panel {
    id: qs

    name: "quicksettings"
    panelWidth: 384
    panelHeight: col.implicitHeight + 36
    anchors { top: true; right: true }
    margins { top: 6; right: 8 }

    property string expanded: "" // "", "wifi", "bt", "audio"
    property var pskTarget: null

    onIsOpenChanged: {
        if (isOpen) { Sys.refreshBacklights(); expanded = ""; pskTarget = null }
        Net.scanning = isOpen && expanded === "wifi"
    }
    onExpandedChanged: Net.scanning = isOpen && expanded === "wifi"

    // ---------- reusable pieces ----------
    component BigTile: Rectangle {
        id: big
        property string glyph
        property string title
        property string subtitle
        property bool on: false
        property bool open: false
        signal toggled()
        signal expand()

        width: (col.width - 10) / 2
        height: 64
        radius: Theme.radiusItem
        color: on ? Theme.accent : Theme.card
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        gradient: on ? onGrad : null
        Gradient {
            id: onGrad
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accent }
            GradientStop { position: 1; color: Qt.darker(Theme.accent2, 1.05) }
        }

        HoverButton {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: chevron.left }
            radius: Theme.radiusItem
            color: hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            onClicked: big.toggled()
            Row {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 12
                Glyph { text: big.glyph; size: 20; color: big.on ? "white" : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: big.title; size: 13; weight: Font.DemiBold; color: big.on ? "white" : Theme.text }
                    Label { text: big.subtitle; size: 11; color: big.on ? Qt.rgba(1, 1, 1, 0.82) : Theme.subtext; width: big.width - 100 }
                }
            }
        }
        HoverButton {
            id: chevron
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 36
            radius: Theme.radiusItem
            color: hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            onClicked: big.expand()
            Glyph { anchors.centerIn: parent; text: Icons.chevronDown; size: 18; rotation: big.open ? 180 : 0; color: big.on ? "white" : Theme.subtext
                Behavior on rotation { NumberAnimation { duration: Theme.normal } } }
        }
    }

    component SmallTile: HoverButton {
        property string glyph
        property string title
        property bool on: false
        width: (col.width - 20) / 3
        height: 68
        radius: Theme.radiusItem
        color: on ? Theme.accentSoft : hovered ? Theme.hover : Theme.card
        border.color: on ? Qt.alpha(Theme.accent, 0.5) : "transparent"
        Column {
            anchors.centerIn: parent
            spacing: 6
            Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.glyph; size: 20; color: parent.parent.on ? Theme.accent : Theme.text }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.title; size: 11; color: parent.parent.on ? Theme.text : Theme.subtext }
        }
    }

    component SliderRow: Row {
        property string glyph
        property real value
        property bool dimmed: false
        property bool canExpand: false
        property bool open: false
        signal moved(real v)
        signal iconClicked()
        signal expand()
        width: col.width
        height: 36
        spacing: 8
        HoverButton {
            width: 36; height: 36; radius: 18
            onClicked: parent.iconClicked()
            Glyph { anchors.centerIn: parent; text: parent.parent.glyph; size: 18; color: parent.parent.dimmed ? Theme.dim : Theme.text }
        }
        Slider {
            width: parent.width - 36 - 44 - (parent.canExpand ? 36 : 0) - parent.spacing * (parent.canExpand ? 3 : 2)
            anchors.verticalCenter: parent.verticalCenter
            value: parent.value
            opacity: parent.dimmed ? 0.5 : 1
            onMoved: v => parent.moved(v)
        }
        Label { width: 44; text: Math.round(parent.value * 100) + "%"; size: 12; color: Theme.subtext; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
        HoverButton {
            visible: parent.canExpand
            width: 36; height: 36; radius: 18
            onClicked: parent.expand()
            Glyph { anchors.centerIn: parent; text: Icons.chevronDown; size: 18; color: Theme.subtext; rotation: parent.parent.open ? 180 : 0 }
        }
    }

    component ListRow: HoverButton {
        property string glyph
        property string title
        property string subtitle
        property bool current: false
        width: col.width
        height: 42
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 12
            Glyph { text: parent.parent.glyph; size: 17; color: parent.parent.current ? Theme.accent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Label { text: parent.parent.parent.title; size: 13; weight: parent.parent.parent.current ? Font.DemiBold : Font.Normal; width: col.width - 90 }
                Label { visible: text !== ""; text: parent.parent.parent.subtitle; size: 11; color: Theme.subtext }
            }
        }
        Glyph { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            visible: parent.current; text: Icons.check; size: 16; color: Theme.accent }
    }

    // ---------- layout ----------
    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        spacing: 10

        Row {
            spacing: 10
            BigTile {
                glyph: Net.glyph()
                title: "Wi-Fi"
                subtitle: Net.wifiOn ? (Net.active?.name ?? (Net.wiredDevice ? "Ethernet connected" : "Not connected")) : "Off"
                on: Net.wifiOn
                open: qs.expanded === "wifi"
                onToggled: Net.setWifi(!Net.wifiOn)
                onExpand: qs.expanded = qs.expanded === "wifi" ? "" : "wifi"
            }
            BigTile {
                glyph: Sys.btOn ? Icons.bluetooth : Icons.bluetoothOff
                title: "Bluetooth"
                subtitle: !Sys.btOn ? "Off" : Sys.btConnected.length ? Sys.btConnected[0].name : "On"
                on: Sys.btOn
                open: qs.expanded === "bt"
                onToggled: Sys.setBluetooth(!Sys.btOn)
                onExpand: qs.expanded = qs.expanded === "bt" ? "" : "bt"
            }
        }

        // Wi-Fi networks
        Column {
            visible: qs.expanded === "wifi"
            width: col.width
            spacing: 2
            Label { visible: !Net.wifiOn; text: "Wi-Fi is off"; color: Theme.subtext; size: 12; leftPadding: 12; height: 30 }
            Label { visible: Net.wifiOn && Net.networks.length === 0; text: "Searching for networks…"; color: Theme.subtext; size: 12; leftPadding: 12; height: 30 }
            Repeater {
                model: ScriptModel { values: Net.wifiOn ? Net.networks.filter(n => n).slice(0, 6) : [] }
                delegate: Column {
                    required property var modelData
                    width: col.width
                    ListRow {
                        readonly property real s: modelData.signalStrength
                        glyph: s > 0.75 ? Icons.wifi4 : s > 0.5 ? Icons.wifi3 : s > 0.25 ? Icons.wifi2 : Icons.wifi1
                        title: modelData.name
                        subtitle: modelData.connected ? "Connected — click to disconnect"
                                : modelData.stateChanging ? "Connecting…"
                                : modelData.known ? "Saved" : (modelData.security === WifiSecurityType.Open ? "Open" : "Secured")
                        current: modelData.connected
                        onClicked: {
                            if (modelData.connected) modelData.disconnect()
                            else if (modelData.known || modelData.security === WifiSecurityType.Open) modelData.connect()
                            else qs.pskTarget = qs.pskTarget === modelData ? null : modelData
                        }
                    }
                    Rectangle {
                        visible: qs.pskTarget === modelData
                        width: col.width; height: 40; radius: 20
                        color: Qt.rgba(1, 1, 1, 0.07)
                        border.color: Theme.border
                        TextInput {
                            id: psk
                            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 13
                            onVisibleChanged: if (visible) forceActiveFocus()
                            onAccepted: { modelData.connectWithPsk(text); text = ""; qs.pskTarget = null }
                            Label { visible: !psk.text; text: "Password — press Enter to connect"; color: Theme.dim; size: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        // Bluetooth devices
        Column {
            visible: qs.expanded === "bt"
            width: col.width
            spacing: 2
            Label { visible: !Sys.btOn; text: "Bluetooth is off"; color: Theme.subtext; size: 12; leftPadding: 12; height: 30 }
            Repeater {
                model: ScriptModel { values: Sys.btOn && Sys.bt ? Sys.bt.devices.values.filter(d => d && (d.paired || d.connected)) : [] }
                delegate: ListRow {
                    required property BluetoothDevice modelData
                    glyph: modelData.icon.includes("audio") || modelData.icon.includes("headset") ? Icons.headphones : Icons.bluetooth
                    title: modelData.name
                    subtitle: modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                            : modelData.connected ? (modelData.batteryAvailable ? "Connected · " + Math.round(modelData.battery * 100) + "%" : "Connected")
                            : "Paired"
                    current: modelData.connected
                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
            }
            ListRow { glyph: Icons.cog; title: "Pair a new device…"; onClicked: Sys.run(["kcmshell6", "kcm_bluetooth"]) }
        }

        Grid {
            columns: 3
            spacing: 10
            SmallTile { glyph: Icons.night; title: "Night light"; on: Sys.nightLight; onClicked: Sys.nightLight = !Sys.nightLight }
            SmallTile { glyph: Icons.darkMode; title: "Dark mode"; on: Sys.darkMode; onClicked: Sys.setDarkMode(!Sys.darkMode) }
            SmallTile { glyph: Icons.bellSleep; title: "Do not disturb"; on: Sys.dnd; onClicked: Sys.dnd = !Sys.dnd }
            SmallTile { glyph: Icons.airplane; title: "Airplane mode"; on: Sys.airplane; onClicked: Sys.setAirplane(!Sys.airplane) }
            SmallTile { glyph: Icons.screenshot; title: "Screenshot"; onClicked: Sys.screenshot(true) }
            SmallTile { glyph: Icons.record; title: Sys.recording ? "Stop recording" : "Record screen"; on: Sys.recording
                        onClicked: { const start = !Sys.recording; Sys.toggleRecording(); if (start) Ui.close() } }
        }

        Item { width: 1; height: 2 }

        SliderRow {
            glyph: Sys.muted ? Icons.volOff : Sys.volume > 0.6 ? Icons.volHigh : Sys.volume > 0.25 ? Icons.volMed : Icons.volLow
            value: Sys.volume
            dimmed: Sys.muted
            canExpand: true
            open: qs.expanded === "audio"
            onMoved: v => Sys.setVolume(v)
            onIconClicked: Sys.toggleMute()
            onExpand: qs.expanded = qs.expanded === "audio" ? "" : "audio"
        }
        Column {
            visible: qs.expanded === "audio"
            width: col.width
            spacing: 2
            Label { text: "Output device"; size: 11; color: Theme.subtext; leftPadding: 12; height: 22 }
            Repeater {
                model: ScriptModel { values: Sys.sinks }
                delegate: ListRow {
                    required property var modelData
                    glyph: modelData.description.toLowerCase().includes("hdmi") ? Icons.monitor
                         : modelData.description.toLowerCase().includes("headphone") ? Icons.headphones : Icons.speaker
                    title: modelData.description || modelData.nickname || modelData.name
                    current: modelData === Sys.sink
                    onClicked: Sys.setSink(modelData)
                }
            }
            ListRow { glyph: Icons.cog; title: "Sound settings…"; onClicked: Sys.run(["pavucontrol"]) }
        }
        SliderRow {
            glyph: Sys.micMuted ? Icons.micOff : Icons.mic
            value: Sys.micVolume
            dimmed: Sys.micMuted
            onMoved: v => Sys.setMicVolume(v)
            onIconClicked: Sys.toggleMic()
        }
        SliderRow {
            glyph: Icons.brightness
            value: Sys.brightness
            onMoved: v => Sys.setBrightness(v)
        }
        SliderRow {
            visible: Sys.hasKbd
            glyph: Icons.keyboard
            value: Sys.kbdMax ? Sys.kbdLevel / Sys.kbdMax : 0
            onMoved: v => Sys.setKbd(Math.round(v * Sys.kbdMax))
            onIconClicked: Sys.setKbd(Sys.kbdLevel > 0 ? 0 : Sys.kbdMax)
        }

        // Power profile
        Rectangle {
            width: col.width
            height: 40
            radius: 20
            color: Theme.card
            Row {
                anchors { fill: parent; margins: 4 }
                Repeater {
                    model: [
                        { p: PowerProfile.PowerSaver, label: "Saver", glyph: Icons.saver },
                        { p: PowerProfile.Balanced, label: "Balanced", glyph: Icons.balanced },
                        { p: PowerProfile.Performance, label: "Performance", glyph: Icons.performance },
                    ].filter(x => x.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                    delegate: HoverButton {
                        required property var modelData
                        width: (col.width - 8) / (PowerProfiles.hasPerformanceProfile ? 3 : 2)
                        height: 32
                        radius: 16
                        active: PowerProfiles.profile === modelData.p
                        activeColor: Theme.accent
                        onClicked: PowerProfiles.profile = modelData.p
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Glyph { text: modelData.glyph; size: 14; color: parent.parent.active ? "white" : Theme.subtext }
                            Label { text: modelData.label; size: 12; color: parent.parent.active ? "white" : Theme.subtext; weight: parent.parent.active ? Font.DemiBold : Font.Normal }
                        }
                    }
                }
            }
        }

        // Footer: battery + display + settings
        Item {
            width: col.width
            height: 36
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: Sys.hasBattery
                Glyph { text: Sys.batteryGlyph(); size: 18; color: Sys.charging ? Theme.green : Theme.text }
                Label {
                    readonly property real secs: Sys.charging ? (Sys.battery?.timeToFull ?? 0) : (Sys.battery?.timeToEmpty ?? 0)
                    function hm(s) { return Math.floor(s / 3600) + " h " + Math.round((s % 3600) / 60) + " min" }
                    text: Math.round(Sys.batteryPct * 100) + "%"
                        + (Sys.battery?.state === UPowerDeviceState.FullyCharged ? " · Fully charged"
                           : Sys.charging ? (secs > 0 ? " · " + hm(secs) + " to full" : " · Charging")
                           : secs > 0 ? " · " + hm(secs) + " left" : "")
                    size: 12
                    color: Theme.subtext
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 4
                HoverButton {
                    width: 36; height: 36; radius: 18
                    onClicked: Ui.openSettings()
                    Glyph { anchors.centerIn: parent; text: Icons.cog; size: 18 }
                }
                HoverButton {
                    width: 36; height: 36; radius: 18
                    onClicked: Sys.run(["nwg-displays"])
                    Glyph { anchors.centerIn: parent; text: Icons.monitor; size: 18 }
                }
                HoverButton {
                    width: 36; height: 36; radius: 18
                    onClicked: Ui.toggle("power", qs.screen)
                    Glyph { anchors.centerIn: parent; text: Icons.power; size: 18 }
                }
            }
        }
    }
}
