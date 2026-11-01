pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The session's notification daemon (org.freedesktop.Notifications).
// History is what this daemon has received since login; nothing is invented.
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: list.length
    property int unread: 0

    // Arrival times keyed by notification id (the spec carries none).
    property var times: ({})
    // Notifications currently shown as pop-up toasts.
    property var toasts: []

    function timeOf(n) { return times[n.id] ?? Date.now() }

    function dismiss(n) { n.dismiss() }
    function clearAll() { for (const n of server.trackedNotifications.values.slice()) n.dismiss() }
    function hideToast(n) { toasts = toasts.filter(t => t !== n) }

    function relative(ms) {
        const s = Math.max(0, (Date.now() - ms) / 1000)
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + "m ago"
        if (s < 86400) return Math.floor(s / 3600) + "h ago"
        return Math.floor(s / 86400) + "d ago"
    }

    function dayGroup(ms) {
        const d = new Date(ms), today = new Date()
        const start = new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime()
        if (ms >= start) return "Today"
        if (ms >= start - 86400000) return "Yesterday"
        return "Earlier"
    }

    function iconFor(n) {
        if (n.image) return n.image
        if (n.appIcon) return n.appIcon.startsWith("/") || n.appIcon.includes("://") ? n.appIcon : Quickshell.iconPath(n.appIcon, true)
        const e = Apps.entry(n.desktopEntry)
        return e ? Quickshell.iconPath(e.icon, true) : ""
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true
            // Carried over from before a shell reload: keep, but don't re-announce.
            if (n.lastGeneration) return
            const t = Object.assign({}, root.times)
            t[n.id] = Date.now()
            root.times = t
            if (Ui.open !== "notifications") root.unread++
            const critical = n.urgency === NotificationUrgency.Critical
            if (!Sys.dnd || critical) root.toasts = [n, ...root.toasts].slice(0, 3)
        }
    }

    Connections {
        target: Ui
        function onOpenChanged() { if (Ui.open === "notifications") root.unread = 0 }
    }
}
