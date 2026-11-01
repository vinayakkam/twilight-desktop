import QtQuick
import QtQuick.Shapes
import Quickshell

// Compact CPU or memory monitor, opened by clicking a ring in the top bar.
Panel {
    id: mon

    required property string mode // "cpu" | "mem"
    readonly property bool isCpu: mode === "cpu"
    readonly property real value: isCpu ? Sys.cpu : Sys.mem
    readonly property color tone: isCpu ? Theme.accent : Theme.accent2

    name: mode
    panelWidth: 300
    panelHeight: col.implicitHeight + 32
    anchors { top: true; left: true }
    margins {
        top: 6
        left: Math.max(8, Math.min((screen?.width ?? 1920) - panelWidth - 8, Ui.anchorX - panelWidth / 2))
    }

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 12

        Row {
            spacing: 8
            Glyph { text: mon.isCpu ? Icons.cpu : Icons.memory; size: 17; color: mon.tone; anchors.verticalCenter: parent.verticalCenter }
            Label { text: mon.isCpu ? "Processor" : "Memory"; size: 14; weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        }

        // Ring + key figures side by side.
        Row {
            spacing: 16
            Item {
                width: 92; height: 92
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Qt.rgba(1, 1, 1, 0.1); strokeWidth: 7; fillColor: "transparent"
                        PathAngleArc { centerX: 46; centerY: 46; radiusX: 41; radiusY: 41; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: mon.value > 0.85 ? Theme.red : mon.tone; strokeWidth: 7; fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 46; centerY: 46; radiusX: 41; radiusY: 41; startAngle: -90
                            sweepAngle: Math.max(1, 360 * mon.value)
                            Behavior on sweepAngle { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        }
                    }
                }
                Label { anchors.centerIn: parent; text: (mon.value * 100).toFixed(1) + "%"; size: 15; weight: Font.DemiBold }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                component Stat: Row {
                    property string k
                    property string v
                    width: 160
                    Label { width: 90; text: parent.k; size: 12; color: Theme.subtext }
                    Label { width: 70; text: parent.v; size: 12; weight: Font.Medium; horizontalAlignment: Text.AlignRight }
                }
                Stat { visible: mon.isCpu; k: "Temperature"; v: Sys.cpuTemp > 0 ? Math.round(Sys.cpuTemp) + " °C" : "—" }
                Stat { visible: mon.isCpu; k: "Frequency"; v: Sys.cpuMHz > 0 ? (Sys.cpuMHz / 1000).toFixed(2) + " GHz" : "—" }
                Stat { visible: mon.isCpu; k: "Threads"; v: String(Sys.threads) }
                Stat { visible: mon.isCpu; k: "Load (1/5/15)"; v: Sys.loadAvg.split(" ").map(x => Number(x).toFixed(1)).join(" ") }
                Stat { visible: !mon.isCpu; k: "In use"; v: Sys.memUsedGiB.toFixed(1) + " GiB" }
                Stat { visible: !mon.isCpu; k: "Available"; v: Sys.memAvailGiB.toFixed(1) + " GiB" }
                Stat { visible: !mon.isCpu; k: "Total"; v: Sys.memTotalGiB.toFixed(1) + " GiB" }
                Stat { visible: !mon.isCpu; k: "Swap"; v: Sys.swapUsedGiB.toFixed(1) + " / " + Sys.swapTotalGiB.toFixed(1) }
            }
        }

        // Last two minutes.
        Column {
            width: parent.width
            spacing: 4
            Label { text: "Last 2 minutes"; size: 11; color: Theme.dim }
            Sparkline {
                width: parent.width
                height: 48
                values: mon.isCpu ? Sys.cpuHist : Sys.memHist
                color: mon.tone
            }
        }

        // Heaviest apps right now.
        Column {
            width: parent.width
            spacing: 2
            Label { text: mon.isCpu ? "Top by CPU" : "Top by memory"; size: 11; color: Theme.dim; bottomPadding: 2 }
            Repeater {
                model: mon.isCpu ? Sys.topCpu : Sys.topMem
                delegate: Row {
                    required property var modelData
                    width: col.width
                    Label { width: col.width - 80; text: modelData.name; size: 12 }
                    Label { width: 80; text: modelData.value; size: 12; color: Theme.subtext; horizontalAlignment: Text.AlignRight }
                }
            }
        }

        HoverButton {
            width: parent.width
            height: 34
            color: hovered ? Theme.hover : Theme.card
            onClicked: Sys.run(["kitty", "--class", "twilight-monitor", "-e", "btop"])
            Row {
                anchors.centerIn: parent
                spacing: 8
                Glyph { text: Icons.apps; size: 15 }
                Label { text: "Open system monitor"; size: 12 }
            }
        }
    }
}
