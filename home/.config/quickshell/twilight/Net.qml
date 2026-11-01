pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// NetworkManager state through Quickshell.Networking.
Singleton {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var networks: wifiDevice
        ? wifiDevice.networks.values.slice().sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
        : []
    readonly property var active: networks.find(n => n.connected) ?? null
    readonly property real strength: active?.signalStrength ?? 0

    readonly property string label: active ? active.name
                                  : wiredDevice ? "Ethernet"
                                  : wifiOn ? "Not connected" : "Off"

    function glyph() {
        if (wiredDevice && !active) return Icons.ethernet
        if (!wifiOn) return Icons.wifiOff
        if (!active) return Icons.wifi0
        const s = strength
        return s > 0.75 ? Icons.wifi4 : s > 0.5 ? Icons.wifi3 : s > 0.25 ? Icons.wifi2 : Icons.wifi1
    }

    function setWifi(on) { Networking.wifiEnabled = on }

    // Scan only while the network list is on screen.
    property bool scanning: false
    onScanningChanged: if (wifiDevice) wifiDevice.scannerEnabled = scanning
}
