pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Window actions Hyprland lacks natively. "Minimise" parks a window on the
// hidden special workspace "minimized"; restoring moves it back.
Singleton {
    id: root

    readonly property string parking: "special:minimized"

    // Wayland toplevel (taskbar) -> Hyprland toplevel (workspace, address).
    function hyprFor(t) { return Hyprland.toplevels.values.find(h => h.wayland === t) ?? null }
    function addr(h) { return "address:0x" + h.address.replace(/^0x/, "") }
    function isMinimized(h) { return h?.workspace?.name === parking }

    // The window that has focus on a given monitor, if any is visible there.
    function focusedOn(monitor) {
        const h = Hyprland.activeToplevel
        if (!h || !monitor || isMinimized(h)) return null
        return h.workspace && h.workspace === monitor.activeWorkspace ? h : null
    }

    function minimize(h) {
        if (!h) return
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${parking}", window = "${addr(h)}", follow = false })`)
    }

    function restore(h) {
        if (!h) return
        const ws = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "${addr(h)}" })`)
        Hyprland.dispatch(`hl.dsp.focus({ window = "${addr(h)}" })`)
    }

    function toggleMaximize(h) {
        if (!h) return
        Hyprland.dispatch(`hl.dsp.focus({ window = "${addr(h)}" })`)
        Hyprland.dispatch(`hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })`)
    }

    // Show desktop (Win+D / end of the taskbar): minimise every window on the
    // current desktop; pressing again brings the same windows back.
    property var shownBeforeDesktop: []
    function showDesktop() {
        const ws = Hyprland.focusedMonitor?.activeWorkspace
        const visible = Hyprland.toplevels.values.filter(h => h.workspace === ws)
        if (visible.length > 0) {
            shownBeforeDesktop = visible
            for (const h of visible) minimize(h)
        } else {
            for (const h of shownBeforeDesktop) if (isMinimized(h)) restore(h)
            shownBeforeDesktop = []
        }
    }

    function close(h) {
        if (h?.wayland) h.wayland.close()
        else if (h) Hyprland.dispatch(`hl.dsp.window.close({ window = "${addr(h)}" })`)
    }
}
