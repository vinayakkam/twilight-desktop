import QtQuick
import Quickshell
import Quickshell.Wayland

// Desktop background, one per screen. Decoded at screen size to keep memory low.
PanelWindow {
    id: win

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "twilight-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.base

    Image {
        anchors.fill: parent
        source: "file://" + Config.s.wallpaper
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(win.screen.width, win.screen.height)
        asynchronous: true
        cache: false
    }

    // Right-click the desktop: the usual Windows-style shortcuts.
    MouseArea {
        id: deskArea
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: m => win.openMenu(m.x, m.y)
    }
    function openMenu(x, y) {
        deskMenu.openAt(win.screen, x, y, [
            { glyph: Icons.taskView, label: "Task View", action: () => Ui.taskViewOpen = true },
            { glyph: Icons.desktop, label: "Show desktop", action: () => Win.showDesktop() },
            { separator: true },
            { glyph: Icons.folder, label: "Open Files", action: () => Ui.openFolder("DESKTOP") },
            { glyph: Icons.terminal, label: "Open Terminal", action: () => Quickshell.execDetached(["konsole", "--profile", "Twilight"]) },
            { separator: true },
            { glyph: Icons.palette, label: "Personalise", action: () => Ui.openSettings("personalisation") },
            { glyph: Icons.monitor, label: "Display settings", action: () => Ui.openSettings("display") },
            { glyph: Icons.cog, label: "Settings", action: () => Ui.openSettings() },
            { glyph: Icons.help, label: "Get started", action: () => Ui.getStartedOpen = true },
        ])
    }
    ContextMenu { id: deskMenu }
}
