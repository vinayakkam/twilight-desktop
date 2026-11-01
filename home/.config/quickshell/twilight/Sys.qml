pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Real system state and the actions that change it. Nothing here is
// decorative: every value is read from the system and every toggle acts on it.
Singleton {
    id: root

    // ---------- Audio ----------
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source] }

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? true

    function setVolume(v) { if (sink?.audio) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1, v)) } }
    function toggleMute() { if (sink?.audio) sink.audio.muted = !sink.audio.muted }
    function setMicVolume(v) { if (source?.audio) { source.audio.muted = false; source.audio.volume = Math.max(0, Math.min(1, v)) } }
    function toggleMic() { if (source?.audio) source.audio.muted = !source.audio.muted }

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    function setSink(node) { Pipewire.preferredDefaultAudioSink = node }

    onVolumeChanged: showOsd("volume", muted ? 0 : volume)
    onMutedChanged: showOsd("volume", muted ? 0 : volume)

    // ---------- On-screen indicator ----------
    property string osdKind: ""
    property real osdValue: 0
    property int osdSerial: 0
    property bool _osdReady: false
    Timer { running: true; interval: 1500; onTriggered: root._osdReady = true }

    function showOsd(kind, value) {
        // Not while the user is dragging the same slider in Quick Settings,
        // and not for the initial values read at startup.
        if (!_osdReady || Ui.open === "quicksettings") return
        osdKind = kind
        osdValue = value
        osdSerial++
    }

    // ---------- Screen and keyboard backlight (brightnessctl via logind) ----------
    property real brightness: 0
    property int kbdLevel: 0
    property int kbdMax: 0
    readonly property bool hasKbd: kbdMax > 0

    Process {
        id: readBrightness
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",")
                if (f.length >= 5) root.brightness = parseInt(f[2]) / parseInt(f[4])
            }
        }
    }
    Process {
        id: readKbd
        command: ["brightnessctl", "-m", "-d", "*kbd_backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",")
                if (f.length >= 5) { root.kbdLevel = parseInt(f[2]); root.kbdMax = parseInt(f[4]) }
            }
        }
    }
    function refreshBacklights() { readBrightness.running = true; readKbd.running = true }
    Component.onCompleted: { refreshBacklights(); readDark.running = true; readRfkill.running = true }

    function setBrightness(v) {
        // Never go fully dark from the UI.
        v = Math.max(0.03, Math.min(1, v))
        brightness = v
        Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", Math.round(v * 100) + "%"])
    }
    function changeBrightness(deltaPercent) {
        setBrightness(brightness + deltaPercent / 100)
        showOsd("brightness", brightness)
    }
    function setKbd(level) {
        if (!hasKbd) return
        kbdLevel = Math.max(0, Math.min(kbdMax, level))
        Quickshell.execDetached(["brightnessctl", "-q", "-d", "*kbd_backlight", "set", String(kbdLevel)])
    }
    function changeKbd(delta) {
        setKbd(kbdLevel + delta)
        showOsd("kbd", kbdMax ? kbdLevel / kbdMax : 0)
    }

    // ---------- Night light (hyprsunset runs only while enabled) ----------
    property bool nightLight: false
    Process {
        running: root.nightLight
        command: ["hyprsunset", "-t", String(Config.s.nightTemp)]
    }

    // ---------- Dark mode (private dconf db; never KDE's) ----------
    // Switches GTK/libadwaita apps and the portal colour-scheme preference
    // (browsers, Electron). Qt/KDE apps keep following KDE's colour scheme.
    property bool darkMode: true
    Process {
        id: readDark
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        stdout: StdioCollector { onStreamFinished: root.darkMode = text.indexOf("dark") >= 0 }
    }
    function setDarkMode(dark) {
        darkMode = dark
        Quickshell.execDetached(["sh", "-c",
            `gsettings set org.gnome.desktop.interface color-scheme ${dark ? "prefer-dark" : "default"};
             gsettings set org.gnome.desktop.interface gtk-theme ${dark ? "adw-gtk3-dark" : "adw-gtk3"}`])
    }

    // ---------- Do Not Disturb ----------
    property bool dnd: false

    // ---------- Radios ----------
    readonly property BluetoothAdapter bt: Bluetooth.defaultAdapter
    readonly property bool btOn: bt?.enabled ?? false
    readonly property var btConnected: bt ? bt.devices.values.filter(d => d.connected) : []

    function setBluetooth(on) {
        if (on) {
            // The adapter may be rfkill soft-blocked; unblock first (the
            // user is in the rfkill group, no root needed).
            Quickshell.execDetached(["sh", "-c", "rfkill unblock bluetooth"])
            btEnable.restart()
        } else if (bt) {
            bt.enabled = false
        }
    }
    Timer { id: btEnable; interval: 600; onTriggered: if (root.bt) root.bt.enabled = true }

    property bool airplane: false
    Process {
        id: readRfkill
        command: ["rfkill", "-rn", "-o", "SOFT"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.trim().split("\n").filter(r => r.length)
                root.airplane = rows.length > 0 && rows.every(r => r.trim() === "blocked")
            }
        }
    }
    function setAirplane(on) {
        airplane = on
        Quickshell.execDetached(["rfkill", on ? "block" : "unblock", "all"])
        rfkillRefresh.restart()
    }
    Timer { id: rfkillRefresh; interval: 800; onTriggered: readRfkill.running = true }

    // ---------- Battery ----------
    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real batteryPct: battery?.percentage ?? 0
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
        || battery?.state === UPowerDeviceState.FullyCharged
        || battery?.state === UPowerDeviceState.PendingCharge

    function batteryGlyph() {
        if (charging) return Icons.batteryCharging
        if (batteryPct < 0.15) return Icons.batteryAlert
        return batteryPct > 0.6 ? Icons.battery : Icons.battery80
    }

    // ---------- Screen recording ----------
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"
    readonly property bool recording: recorder.running
    Process {
        id: recorder
        command: [root.scripts + "/record.sh", "toggle"]
    }
    function toggleRecording() {
        if (recorder.running) Quickshell.execDetached([scripts + "/record.sh", "toggle"])
        else recorder.running = true
    }
    // Opens the Twilight screenshot tool (region / window / full screen).
    function screenshot() { Ui.startScreenshot() }

    // ---------- CPU / memory / temperature ----------
    // One small read every 2 s (every 1 s while a monitor panel is open).
    property real cpu: 0
    property real mem: 0
    property real memUsedGiB: 0
    property real memAvailGiB: 0
    property real memTotalGiB: 0
    property real swapUsedGiB: 0
    property real swapTotalGiB: 0
    property real cpuTemp: 0
    property real cpuMHz: 0
    property string loadAvg: ""
    property int threads: 0
    property var cpuHist: []
    property var memHist: []
    property var topCpu: []
    property var topMem: []
    property var _cpuPrev: null
    readonly property bool monitorOpen: Ui.open === "cpu" || Ui.open === "mem"

    function _push(arr, v) { const a = arr.concat([v]); return a.length > 120 ? a.slice(a.length - 120) : a }

    Process {
        id: stats
        command: ["sh", "-c", "head -n1 /proc/stat; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo; "
                  + "echo load $(cut -d' ' -f1-3 /proc/loadavg); echo threads $(nproc); "
                  + "awk -F: '/^cpu MHz/{s+=$2;n++} END{if(n) printf \"mhz %d\\n\", s/n}' /proc/cpuinfo; "
                  + "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name) in k10temp|coretemp|zenpower) echo temp $(cat $h/temp1_input); break;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const c = lines[0].split(/\s+/).slice(1).map(Number)
                const idle = c[3] + c[4], total = c.reduce((a, b) => a + b, 0)
                if (root._cpuPrev) {
                    const dt = total - root._cpuPrev.total
                    if (dt > 0) root.cpu = Math.max(0, Math.min(1, 1 - (idle - root._cpuPrev.idle) / dt))
                }
                root._cpuPrev = { idle, total }
                const kv = {}
                for (const l of lines.slice(1)) {
                    let m = l.match(/^(\w+):\s+(\d+)/)
                    if (m) { kv[m[1]] = Number(m[2]); continue }
                    m = l.match(/^(\w+) (.*)$/)
                    if (!m) continue
                    if (m[1] === "load") root.loadAvg = m[2]
                    else if (m[1] === "threads") root.threads = Number(m[2])
                    else if (m[1] === "mhz") root.cpuMHz = Number(m[2])
                    else if (m[1] === "temp") root.cpuTemp = Number(m[2]) / 1000
                }
                if (kv.MemTotal) {
                    root.memTotalGiB = kv.MemTotal / 1048576
                    root.memAvailGiB = kv.MemAvailable / 1048576
                    root.memUsedGiB = root.memTotalGiB - root.memAvailGiB
                    root.mem = root.memUsedGiB / root.memTotalGiB
                    root.swapTotalGiB = kv.SwapTotal / 1048576
                    root.swapUsedGiB = (kv.SwapTotal - kv.SwapFree) / 1048576
                }
                root.cpuHist = root._push(root.cpuHist, root.cpu)
                root.memHist = root._push(root.memHist, root.mem)
            }
        }
    }
    Timer {
        running: true; repeat: true; triggeredOnStart: true
        interval: root.monitorOpen ? 1000 : 2000
        onTriggered: { stats.running = true; if (root.monitorOpen) top.running = true }
    }

    // Top processes, only while a monitor panel is open. Processes of one app
    // (e.g. a browser) are summed by name. Memory is private memory
    // (resident minus shared pages) so shared libraries aren't counted twice.
    Process {
        id: top
        command: ["sh", "-c", "cd /proc && for p in [0-9]*; do { read -r _ r s _ < $p/statm && read -r c < $p/comm; } 2>/dev/null "
                  + "&& echo \"m $((r - s)) $c\"; done; ps -eo pcpu=,comm= --no-headers | sed 's/^ */c /'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const cpu = {}, mem = {}
                for (const l of text.split("\n")) {
                    const m = l.match(/^([mc]) +([\d.]+) +(.+)$/)
                    if (!m) continue
                    const bag = m[1] === "m" ? mem : cpu
                    bag[m[3]] = (bag[m[3]] ?? 0) + Number(m[2])
                }
                const topOf = (bag, fmt) => Object.keys(bag).map(k => ({ name: k, v: bag[k] }))
                    .sort((a, b) => b.v - a.v).slice(0, 3).map(x => ({ name: x.name, value: fmt(x.v) }))
                root.topCpu = topOf(cpu, v => (v / Math.max(1, root.threads)).toFixed(1) + "%")
                // statm counts 4 KiB pages.
                root.topMem = topOf(mem, v => v * 4 > 1048576 ? (v * 4 / 1048576).toFixed(1) + " GiB" : Math.round(v * 4 / 1024) + " MiB")
            }
        }
    }

    // ---------- Session ----------
    // Straight to the lock screen (no loginctl → hypridle hop), drawn at once.
    function lock() { Ui.close(); Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock --immediate-render"]) }
    function suspend() { Ui.close(); Quickshell.execDetached(["systemctl", "suspend"]) }
    function logout() { Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]) }
    function reboot() { Quickshell.execDetached(["systemctl", "reboot"]) }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]) }

    function run(cmd) { Ui.close(); Quickshell.execDetached(cmd) }
}
