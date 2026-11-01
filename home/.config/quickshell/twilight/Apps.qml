pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Installed applications, pins and recent activity. Pins only ever show
// applications that are actually installed.
Singleton {
    id: root

    // KDE-only tools that edit KDE's own configuration stay in KDE; Twilight
    // Settings replaces them here.
    readonly property var kdeOnly: ["systemsettings", "org.kde.kmenuedit", "org.kde.konsole"]

    readonly property var all: DesktopEntries.applications.values
        .filter(e => !e.noDisplay && !kdeOnly.includes(e.id))
        .sort((a, b) => a.name.localeCompare(b.name))

    // Reactive lookup table; DesktopEntries.byId() returns null until the
    // entry scan has finished and does not notify afterwards.
    readonly property var byId: {
        const m = {}
        for (const e of DesktopEntries.applications.values) m[e.id] = e
        return m
    }
    function entry(id) { return id ? byId[id] ?? null : null }
    function installed(ids) { return ids.map(id => entry(id)).filter(e => e) }

    readonly property var defaultStartPins: [
        "twilight-settings", "twilight-claude", "app.zen_browser.zen", "firefox", "org.kde.dolphin", "org.kde.discover",
        "com.discordapp.Discord", "twilight-terminal", "com.valvesoftware.Steam", "com.mojang.Minecraft",
        "org.onlyoffice.desktopeditors", "org.videolan.VLC", "org.kde.gwenview", "org.kde.kcalc",
        "com.jetbrains.PyCharm-Professional", "code", "spotify", "nwg-displays", "org.pulseaudio.pavucontrol"
    ]
    readonly property var defaultTaskbarPins: [
        "app.zen_browser.zen", "org.kde.dolphin", "org.kde.discover", "twilight-terminal", "twilight-claude", "com.discordapp.Discord", "firefox"
    ]

    readonly property var startPins: installed(store.startPins ?? defaultStartPins)
    readonly property var taskbarPins: installed(store.taskbarPins ?? defaultTaskbarPins)
    readonly property var recentApps: installed((store.recentApps ?? []).map(r => r.id)).slice(0, 6)

    function isPinned(where, e) { return (where === "start" ? startPins : taskbarPins).some(p => p.id === e.id) }
    function togglePin(where, e) {
        const key = where === "start" ? "startPins" : "taskbarPins"
        const cur = (where === "start" ? startPins : taskbarPins).map(p => p.id)
        store[key] = cur.includes(e.id) ? cur.filter(id => id !== e.id) : [...cur, e.id]
        file.writeAdapter()
    }

    // Already open? Bring that window up (restoring it if minimised) instead
    // of starting a second copy. newWindow forces a fresh one ("New window").
    property var _lastLaunch: ({ id: "", time: 0 })
    // Terminals and the file manager always open a fresh window, like Windows.
    readonly property var multiWindow: ["twilight-terminal", "kitty", "org.kde.konsole", "Alacritty", "twilight-claude", "org.kde.dolphin"]
    function launch(e, newWindow) {
        if (!e) return
        Ui.close()
        if (!newWindow) {
            const t = multiWindow.includes(e.id) ? null
                : ToplevelManager.toplevels.values.find(t => forAppId(t.appId)?.id === e.id)
            if (t) {
                const h = Win.hyprFor(t)
                if (Win.isMinimized(h)) Win.restore(h)
                else t.activate()
                return
            }
            // A double-click, or clicking again while an app is still starting
            // (no window yet), must not launch it twice.
            if (_lastLaunch.id === e.id && Date.now() - _lastLaunch.time < 10000) return
        }
        _lastLaunch = { id: e.id, time: Date.now() }
        e.execute()
        const rec = (store.recentApps ?? []).filter(r => r.id !== e.id)
        store.recentApps = [{ id: e.id, time: Date.now() }, ...rec].slice(0, 12)
        file.writeAdapter()
    }

    function search(q) {
        q = q.trim().toLowerCase()
        if (!q) return []
        const score = e => {
            const n = e.name.toLowerCase()
            if (n.startsWith(q)) return 0
            if (n.split(/\s+/).some(w => w.startsWith(q))) return 1
            if (n.includes(q)) return 2
            const extra = [e.genericName, e.comment, (e.keywords ?? []).join(" "), e.id].join(" ").toLowerCase()
            return extra.includes(q) ? 3 : 9
        }
        return all.map(e => ({ e, s: score(e) })).filter(x => x.s < 9)
                  .sort((a, b) => a.s - b.s || a.e.name.localeCompare(b.e.name))
                  .map(x => x.e).slice(0, 8)
    }

    // Match a running window's app id to an installed application.
    function forAppId(appId) {
        if (!appId) return null
        // Konsole windows belong to the Twilight "Terminal" launcher.
        if (appId === "org.kde.konsole") return entry("twilight-terminal") ?? entry(appId)
        return entry(appId)
            ?? all.find(e => e.startupClass && e.startupClass.toLowerCase() === appId.toLowerCase())
            ?? DesktopEntries.heuristicLookup(appId)
    }

    function clearActivity() { store.recentApps = []; file.writeAdapter() }

    // Startup apps chosen in Settings → Apps. Launched once per Twilight login
    // (a marker in the runtime dir stops shell restarts from relaunching them).
    function isStartup(e) { return (Config.s.autostart ?? []).includes(e.id) }
    function toggleStartup(e) {
        const cur = Config.s.autostart ?? []
        Config.set("autostart", cur.includes(e.id) ? cur.filter(id => id !== e.id) : [...cur, e.id])
    }
    Process {
        id: startup
        running: true
        command: ["sh", "-c", 'm="$XDG_RUNTIME_DIR/twilight-autostart-$HYPRLAND_INSTANCE_SIGNATURE"; [ -e "$m" ] && exit 1; touch "$m"']
        onExited: code => { if (code === 0) launchStartup.start() }
    }
    // Give the desktop-entry scan a moment before launching.
    Timer {
        id: launchStartup
        interval: 2500
        onTriggered: { for (const id of Config.s.autostart ?? []) root.entry(id)?.execute() }
    }

    function iconOf(e, fallback) {
        return Quickshell.iconPath(e?.icon ?? "", fallback ?? "application-x-executable")
    }

    // ---------- Persistent state: pins + recently launched apps ----------
    property alias store: adapter
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/twilight/apps.json"
        blockLoading: true
        printErrors: false
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: adapter
            property var startPins: null
            property var taskbarPins: null
            property var recentApps: []
        }
    }

    // ---------- Recent files (freedesktop recently-used.xbel) ----------
    property var recentFiles: []
    FileView {
        id: xbel
        path: Quickshell.env("HOME") + "/.local/share/recently-used.xbel"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parseRecent(text())
    }

    function parseRecent(xml) {
        const re = /<bookmark\s+href="file:\/\/([^"]+)"[^>]*?modified="([^"]+)"/g
        const items = []
        let m
        while ((m = re.exec(xml)) !== null) {
            let path
            try { path = decodeURIComponent(m[1]) } catch (e) { continue }
            items.push({ path, time: Date.parse(m[2]) })
        }
        items.sort((a, b) => b.time - a.time)
        const seen = new Set()
        const candidates = items.filter(i => !seen.has(i.path) && seen.add(i.path)).slice(0, 20)
        existing.candidates = candidates
        existing.command = ["sh", "-c", 'for f; do [ -e "$f" ] && printf "%s\\n" "$f"; done', "sh",
                            ...candidates.map(c => c.path)]
        existing.running = true
    }

    // Only list files that still exist.
    Process {
        id: existing
        property var candidates: []
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = new Set(text.split("\n"))
                root.recentFiles = existing.candidates.filter(c => ok.has(c.path)).slice(0, 6)
            }
        }
    }

    function fileIcon(path) {
        const ext = path.split(".").pop().toLowerCase()
        if (["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp"].includes(ext)) return "image-x-generic"
        if (ext === "pdf") return "application-pdf"
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(ext)) return "video-x-generic"
        if (["mp3", "flac", "ogg", "wav", "m4a"].includes(ext)) return "audio-x-generic"
        if (["doc", "docx", "odt", "rtf"].includes(ext)) return "x-office-document"
        if (["xls", "xlsx", "ods", "csv"].includes(ext)) return "x-office-spreadsheet"
        if (["ppt", "pptx", "odp"].includes(ext)) return "x-office-presentation"
        if (["zip", "tar", "gz", "zst", "xz", "7z", "rar"].includes(ext)) return "package-x-generic"
        return "text-x-generic"
    }

    function openFile(path) {
        Ui.close()
        Quickshell.execDetached(["xdg-open", path])
    }
}
