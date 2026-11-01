pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Which popup is open, and on which screen. Only one popup at a time.
Singleton {
    id: root

    // "", "start", "notifications", "quicksettings", "power"
    property string open: ""
    property var screen: null
    // Start menu opens straight into search when started from the taskbar
    // search button.
    property bool startSearch: false
    property bool settingsOpen: false
    property bool screenshotOpen: false
    property int avatarRev: 0      // bumped when the account picture changes
    property string shotFile: ""   // last snip, shown in the Snipping Tool editor
    function startScreenshot() { dismissAll(); screenshotOpen = true }
    // Right-click menus report here so the click-catcher appears under them.
    property bool menuOpen: false
    // Monitors where a window reaches down into the taskbar (sent by Hyprland).
    property var overTaskbar: []
    property int dismissSerial: 0
    // Close every panel and menu (outside click, Escape, opening another).
    function dismissAll() { close(); dismissSerial++; menuOpen = false; screenshotOpen = false }
    property bool getStartedOpen: false
    property bool taskViewOpen: false
    function taskManager() { close(); Quickshell.execDetached(["plasma-systemmonitor"]) }
    function openFolder(which) {
        close()
        Quickshell.execDetached(["sh", "-c", `dolphin "$(xdg-user-dir ${which})"`])
    }
    property string settingsPage: ""
    function openSettings(page) { close(); settingsPage = page ?? ""; settingsOpen = true }
    // Horizontal anchor (screen x) for panels that open under a bar item.
    property real anchorX: 0

    // Bars and taskbars register here so clicking them does not count as an
    // "outside click" for an open popup.
    property var shellWindows: []

    function focusedScreen() {
        const name = Hyprland.focusedMonitor?.name
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0]
    }

    function toggle(name, scr, x) {
        if (open === name) { close(); return }
        screen = scr ?? focusedScreen()
        if (x !== undefined) anchorX = x
        startSearch = false
        open = name
    }

    function close() { open = "" }

    IpcHandler {
        target: "shell"

        function toggle(name: string): void { root.toggle(name) }
        function close(): void { root.dismissAll() }
        function settings(): void { root.openSettings() }
        // Open an image in the Snipping Tool editor.
        function editShot(path: string): void { root.shotFile = path }
        function screenshot(): void { root.startScreenshot() }
        function windowsOverTaskbar(monitors: string): void { root.overTaskbar = monitors ? monitors.split(",") : [] }
        function taskView(): void { root.close(); root.taskViewOpen = !root.taskViewOpen }
        function showDesktop(): void { root.close(); Win.showDesktop() }
        function getStarted(): void { root.close(); root.getStartedOpen = true }
        function taskManager(): void { root.taskManager() }
        // e.g. `qs -c twilight ipc call shell settingsPage signin`
        function settingsPage(page: string): void { root.openSettings(page) }
        function brightness(delta: int): void { Sys.changeBrightness(delta) }
        function kbdBrightness(delta: int): void { Sys.changeKbd(delta) }
        // Diagnostics: `qs -c twilight ipc call shell status`
        function status(): string {
            const safe = f => { try { return f() } catch (e) { return "ERR " + e } }
            return JSON.stringify({
                open: root.open,
                overTaskbar: root.overTaskbar,
                apps: safe(() => Apps.all.length),
                byId: safe(() => Object.keys(Apps.byId).length),
                storeStart: safe(() => String(Apps.store.startPins)),
                startPins: safe(() => Apps.startPins.map(e => e.id)),
                taskbarPins: safe(() => Apps.taskbarPins.map(e => e.id)),
                recentFiles: safe(() => Apps.recentFiles.length),
                notifications: safe(() => Notifs.count),
                volume: Sys.volume, muted: Sys.muted, brightness: Sys.brightness,
                kbd: [Sys.kbdLevel, Sys.kbdMax], wifi: safe(() => Net.label), bt: Sys.btOn, battery: Sys.batteryPct })
        }
    }
}
