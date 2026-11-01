//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io

// Twilight shell: wallpaper, top bar and taskbar on every screen; one set of
// popups that follows the screen they were opened from.
ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: perScreen
            required property ShellScreen modelData
            Wallpaper { screen: perScreen.modelData }
            TopBar { screen: perScreen.modelData }
            Taskbar { screen: perScreen.modelData }
            ClickCatcher { screen: perScreen.modelData }
        }
    }

    StartMenu {}
    NotificationPanel {}
    QuickSettings {}
    PowerMenu {}
    MonitorPanel { mode: "cpu" }
    CalendarPanel {}
    SettingsWindow {}
    GetStarted {}
    TaskView {}
    Screenshot {}
    ShotEditor {}
    MonitorPanel { mode: "mem" }
    Toasts {}
    Osd {}

    // Watchdog: if our Hyprland is gone, quit instead of lingering or
    // attaching to another compositor (e.g. a later KDE login).
    Process {
        id: alive
        command: ["sh", "-c", 'test -S "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock"']
        onExited: code => { if (code !== 0) Qt.quit() }
    }
    Timer { running: true; repeat: true; interval: 5000; onTriggered: alive.running = true }

    // No developer "config reloaded" toast for everyday use.
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
    }

    // Make sure singletons with background work exist from the start.
    Component.onCompleted: { Notifs.count; Sys.volume; Apps.all; Net.wifiOn }
    Timer { running: !Config.s.welcomeShown; interval: 3000; onTriggered: Ui.getStartedOpen = true }
}
