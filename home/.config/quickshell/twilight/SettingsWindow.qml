import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Hyprland

// Windows-style Settings app: every option here changes the desktop live,
// so configs never need hand-editing. Open with Super + I, Start → Settings,
// or the cog in Quick settings.
FloatingWindow {
    id: win

    title: "Twilight Settings"
    visible: Ui.settingsOpen
    // Fit between the top bar and the taskbar on any screen size.
    readonly property var scr: Ui.focusedScreen()
    implicitWidth: Math.min(1000, (scr?.width ?? 1920) - 80)
    implicitHeight: Math.min(660, (scr?.height ?? 1080) - Theme.barHeight - Theme.taskbarHeight - Theme.taskbarGap * 2 - 24)
    minimumSize: Qt.size(720, 420)
    color: Theme.surfaceStrong
    onVisibleChanged: if (!visible) Ui.settingsOpen = false
    Connections {
        target: Ui
        function onSettingsPageChanged() { if (Ui.settingsPage) win.page = Ui.settingsPage }
    }

    property string page: "personalisation"
    onPageChanged: flick.contentY = 0

    readonly property var pages: [
        ["account", Icons.account, "Accounts"],
        ["system", Icons.monitor, "System"],
        ["personalisation", Icons.darkMode, "Personalisation"],
        ["taskbar", Icons.apps, "Taskbar"],
        ["windows", Icons.winMax, "Windows"],
        ["display", Icons.brightness, "Display"],
        ["sound", Icons.volHigh, "Sound"],
        ["network", Icons.wifi4, "Network & Bluetooth"],
        ["input", Icons.keyboard, "Touchpad & keyboard"],
        ["power", Icons.battery, "Power & battery"],
        ["notifications", Icons.bell, "Notifications"],
        ["apps", Icons.apps, "Apps & startup"],
        ["time", Icons.bolt, "Time & language"],
        ["accessibility", Icons.account, "Accessibility"],
        ["signin", Icons.fingerprint, "Sign-in & fingerprint"],
    ]

    // ---------------- Navigation ----------------
    Rectangle {
        id: nav
        width: 250
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        color: Qt.rgba(0, 0, 0, 0.18)

        // Fixed title; only the page list below it scrolls.
        Item {
            id: navHead
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 72
            Row {
                anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
                spacing: 12
                StartMark { size: 22; glowEnabled: false; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Settings"; size: 18; weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14 }
                height: 1; color: Theme.border; opacity: navFlick.contentY > 4 ? 1 : 0 }
        }

        // Scrolls when the window is shorter than the page list.
        Flickable {
            id: navFlick
            anchors { left: parent.left; right: parent.right; top: navHead.bottom; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; topMargin: 6; bottomMargin: 14 }
            contentHeight: navCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        Column {
            id: navCol
            width: navFlick.width
            spacing: 2

            Repeater {
                model: win.pages
                delegate: HoverButton {
                    required property var modelData
                    width: navCol.width
                    height: 40
                    active: win.page === modelData[0]
                    activeColor: Theme.hover
                    onClicked: win.page = modelData[0]
                    Rectangle {
                        visible: parent.active
                        width: 3; height: 18; radius: 2
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        color: Theme.accent
                    }
                    Row {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 12
                        Glyph { text: modelData[1]; size: 17; color: parent.parent.active ? Theme.accent : Theme.text }
                        Label { text: modelData[2]; size: 13; weight: parent.parent.active ? Font.DemiBold : Font.Normal }
                    }
                }
            }
        }
        }
    }

    // ---------------- Page header (title + window buttons) ----------------
    Item {
        id: header
        anchors { left: nav.right; right: parent.right; top: parent.top }
        height: 72
        Label {
            anchors { left: parent.left; leftMargin: Config.s.buttonsLeft ? 112 : 32; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
            text: win.pages.find(p => p[0] === win.page)?.[2] ?? ""
            size: 24; weight: Font.DemiBold
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 32; rightMargin: 32 }
            height: 1; color: Theme.border
            opacity: flick.contentY > 4 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        }
    }

    // ---------------- Page area ----------------
    Flickable {
        id: flick
        anchors { left: nav.right; right: parent.right; top: header.bottom; bottom: parent.bottom }
        contentHeight: pageLoader.implicitHeight + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            x: 32
            y: 12
            width: flick.width - 64
            spacing: 18
            Loader {
                id: pageLoader
                width: parent.width
                sourceComponent: ({
                    account: accountPage, system: systemPage, personalisation: personalisationPage, taskbar: taskbarPage,
                    windows: windowsPage, display: displayPage, sound: soundPage, network: networkPage,
                    input: inputPage, power: powerPage, notifications: notificationsPage, signin: signinPage,
                    apps: appsPage, time: timePage, accessibility: accessibilityPage,
                })[win.page]
            }
        }
    }

    component Section: Label { size: 13; weight: Font.DemiBold; color: Theme.subtext; topPadding: 8 }
    component PageColumn: Column { width: parent?.width ?? 600; spacing: 8 }

    readonly property var minutes: [[0, "Never"], [1, "1 min"], [2, "2 min"], [5, "5 min"], [10, "10 min"], [20, "20 min"], [30, "30 min"]]

    // ================= Pages =================

    Component {
        id: accountPage
        PageColumn {
            id: acct
            property var info: ({})
            Process {
                id: acctInfo
                running: true
                command: ["sh", "-c", 'getent passwd "$USER"; echo "GROUPS=$(id -nG)"; fprintd-list "$USER" 2>/dev/null | grep -c " - #"']
                stdout: StdioCollector {
                    onStreamFinished: {
                        const l = text.trim().split("\n")
                        const p = (l[0] ?? "").split(":")
                        const groups = (l[1] ?? "").replace("GROUPS=", "").split(" ")
                        acct.info = { user: p[0], uid: p[2], name: (p[4] ?? "").split(",")[0] || p[0], home: p[5], shell: p[6],
                                      admin: groups.includes("wheel"), fingers: Number(l[2] ?? 0) }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 150; radius: Theme.radiusPanel
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.3) }
                    GradientStop { position: 1; color: Qt.alpha(Theme.accent2, 0.18) }
                }
                Row {
                    anchors { left: parent.left; leftMargin: 28; verticalCenter: parent.verticalCenter }
                    spacing: 22
                    ClippingRectangle {
                        width: 96; height: 96; radius: 48
                        color: Theme.card
                        Image { anchors.fill: parent; source: "file:///var/lib/AccountsService/icons/" + Quickshell.env("USER") + "?" + Ui.avatarRev
                                sourceSize: Qt.size(192, 192); fillMode: Image.PreserveAspectCrop; cache: false }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Label { text: acct.info.name ?? ""; size: 22; weight: Font.DemiBold }
                        Label { text: (acct.info.user ?? "") + (acct.info.admin ? " · Administrator" : " · Standard user"); size: 13; color: Theme.subtext }
                        Label { text: acct.note || "Local account on this computer"; size: 12; color: acct.note ? Theme.green : Theme.dim }
                    }
                }
            }
            Section { text: "Account details" }
            SettingRow { glyph: Icons.account; title: "Username"; Label { text: acct.info.user ?? "…"; size: 13; color: Theme.subtext } }
            SettingRow { glyph: Icons.folder; title: "Home folder"; Label { text: acct.info.home ?? "…"; size: 13; color: Theme.subtext } }
            SettingRow { glyph: Icons.terminal; title: "Login shell"; Label { text: acct.info.shell ?? "…"; size: 13; color: Theme.subtext } }
            // ---- Picture & name (AccountsService: no admin prompt needed) ----
            readonly property string userPath: "/org/freedesktop/Accounts/User" + acct.info.uid
            property string note: ""
            Process {
                id: acctCmd
                property string okText: ""
                stdout: StdioCollector {}
                stderr: StdioCollector { id: acctErr }
                onExited: code => {
                    acct.note = code === 0 ? acctCmd.okText : "Couldn't change it: " + acctErr.text.trim()
                    if (code === 0) { Ui.avatarRev++; acctInfo.running = true }
                }
            }
            // cmd: a shell string, or an argument list (no shell, no quoting issues).
            function run(cmd, ok) { acctCmd.okText = ok; acctCmd.command = Array.isArray(cmd) ? cmd : ["sh", "-c", cmd]; acctCmd.running = true }

            Section { text: "Picture" }
            SettingRow {
                glyph: Icons.image
                title: "Account picture"
                subtitle: "Shown in Start, on the lock screen and the login screen"
                HoverButton { width: 140; height: 32; radius: 16; color: hovered ? Theme.hover : Theme.card
                    onClicked: acct.run('f=$(kdialog --title "Choose a picture" --getopenfilename "$HOME/Pictures" "image/png image/jpeg image/webp") && [ -n "$f" ] '
                        + '&& o="$HOME/.local/share/twilight/avatar.png" && magick "$f" -auto-orient -gravity center -crop "%[fx:min(w,h)]x%[fx:min(w,h)]+0+0" +repage -resize 512x512 "$o" '
                        + '&& busctl call org.freedesktop.Accounts ' + acct.userPath + ' org.freedesktop.Accounts.User SetIconFile s "$o"', "Picture updated")
                    Label { anchors.centerIn: parent; text: "Choose picture…"; size: 12 } }
            }

            Section { text: "Name" }
            SettingRow {
                glyph: Icons.account
                title: "Display name"
                Rectangle {
                    width: 240; height: 34; radius: 17
                    color: Qt.rgba(1, 1, 1, 0.07); border.color: nameIn.activeFocus ? Theme.accent : Theme.border
                    TextInput { id: nameIn; anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter; color: Theme.text; font.family: Theme.font; font.pixelSize: 13
                        text: acct.info.name ?? ""; selectByMouse: true; maximumLength: 64 }
                }
                HoverButton { width: 80; height: 32; radius: 16; color: hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                    enabled: nameIn.text.trim() !== "" && nameIn.text.trim() !== acct.info.name
                    opacity: enabled ? 1 : 0.5
                    onClicked: acct.run(["busctl", "call", "org.freedesktop.Accounts", acct.userPath,
                        "org.freedesktop.Accounts.User", "SetRealName", "s", nameIn.text.trim()], "Name updated")
                    Label { anchors.centerIn: parent; text: "Save"; size: 12; color: "#140b06"; weight: Font.DemiBold } }
            }

            // ---- Password (system passwd; current password required) ----
            Section { text: "Password" }
            component PwField: Rectangle {
                property alias text: input.text
                property string hint
                width: parent.width; height: 42; radius: 21
                color: Qt.rgba(1, 1, 1, 0.07); border.color: input.activeFocus ? Theme.accent : Theme.border
                TextInput { id: input; anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                    verticalAlignment: TextInput.AlignVCenter; echoMode: TextInput.Password; color: Theme.text
                    font.family: Theme.font; font.pixelSize: 13
                    Label { visible: !input.text; text: parent.parent.hint; color: Theme.dim; size: 13; anchors.verticalCenter: parent.verticalCenter } }
            }
            Rectangle {
                width: parent.width; height: pwCol.implicitHeight + 32; radius: Theme.radiusItem; color: Theme.card
                Column {
                    id: pwCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10
                    Label { text: "Change your password"; size: 13; weight: Font.Medium }
                    PwField { id: pwOld; hint: "Current password" }
                    PwField { id: pwNew; hint: "New password" }
                    PwField { id: pwNew2; hint: "Confirm new password" }
                    Row {
                        spacing: 12
                        HoverButton {
                            width: 170; height: 38; radius: 19
                            readonly property bool ready: pwOld.text && pwNew.text && pwNew.text === pwNew2.text && !pwProc.running
                            enabled: ready; opacity: ready ? 1 : 0.5
                            color: hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                            onClicked: { acct.pwMsg = "Changing…"; pwProc.running = true }
                            Label { anchors.centerIn: parent; text: "Change password"; size: 12; color: "#140b06"; weight: Font.DemiBold }
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pwNew2.text && pwNew.text !== pwNew2.text ? "New passwords don't match" : acct.pwMsg
                            size: 12; color: acct.pwOk ? Theme.green : Theme.subtext; width: 380; wrapMode: Text.WordWrap; elide: Text.ElideNone
                        }
                    }
                    Label { width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.dim
                        text: "This is your login password for this computer (KDE, Twilight, sudo). Several wrong current passwords in a row temporarily lock the account." }
                }
            }
            property string pwMsg: ""
            property bool pwOk: false
            // Passwords go to passwd on stdin only (never on a command line).
            Process {
                id: pwProc
                command: ["passwd"]
                stdinEnabled: true
                environment: ({ LC_ALL: "C" })
                stdout: StdioCollector { id: pwOut }
                stderr: StdioCollector { id: pwErr }
                onRunningChanged: if (running) { write(pwOld.text + "\n" + pwNew.text + "\n" + pwNew2.text + "\n"); stdinEnabled = false }
                onExited: code => {
                    acct.pwOk = code === 0
                    const msg = (pwErr.text + " " + pwOut.text).replace(/\s+/g, " ")
                    acct.pwMsg = code === 0 ? "Password changed ✓"
                        : /BAD PASSWORD:?([^.]*)/i.test(msg) ? "Too weak:" + msg.match(/BAD PASSWORD:?([^.]*)/i)[1]
                        : /Authentication token manipulation|failure/i.test(msg) ? "Current password is wrong"
                        : "Not changed: " + msg.trim()
                    pwOld.text = ""; pwNew.text = ""; pwNew2.text = ""
                    stdinEnabled = true
                }
            }

            SettingRow {
                glyph: Icons.fingerprint
                title: "Sign-in options"
                subtitle: (acct.info.fingers ?? 0) > 0 ? acct.info.fingers + " fingerprint(s) enrolled · password" : "Password · fingerprint not set up"
                HoverButton { width: 90; height: 32; radius: 16; color: hovered ? Theme.hover : Theme.card
                    onClicked: win.page = "signin"
                    Label { anchors.centerIn: parent; text: "Manage"; size: 12 } }
            }
        }
    }

    Component {
        id: systemPage
        PageColumn {
            Process {
                id: info
                running: true
                command: ["sh", "-c", "cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name; . /etc/os-release; echo \"$PRETTY_NAME\"; uname -r; "
                          + "lscpu | sed -n 's/^Model name: *//p'; lspci | sed -n 's/.*VGA compatible controller: //p' | head -n1; "
                          + "Hyprland --version | head -n1 | cut -d' ' -f1-2; qs --version | head -n1 | cut -d' ' -f1-2; uptime -p"]
                property var lines: []
                stdout: StdioCollector { onStreamFinished: info.lines = text.trim().split("\n") }
            }
            Rectangle {
                width: parent.width; height: 120; radius: Theme.radiusPanel
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.35) }
                    GradientStop { position: 1; color: Qt.alpha(Theme.accent2, 0.25) }
                }
                Row {
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    spacing: 20
                    StartMark { size: 48; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Label { text: (info.lines[0] ?? "") + " " + (info.lines[1] ?? ""); size: 18; weight: Font.DemiBold }
                        Label { text: "Twilight on " + (info.lines[2] ?? "Linux"); size: 13; color: Theme.subtext }
                    }
                }
            }
            Section { text: "Specifications" }
            Repeater {
                model: [["Processor", 4], ["Graphics", 5], ["Memory", -1], ["Kernel", 3], ["Compositor", 6], ["Shell", 7], ["Up time", 8]]
                delegate: SettingRow {
                    required property var modelData
                    title: modelData[0]
                    Label {
                        text: modelData[1] < 0 ? Sys.memTotalGiB.toFixed(1) + " GiB usable" : (info.lines[modelData[1]] ?? "…")
                        size: 13; color: Theme.subtext
                    }
                }
            }
        }
    }

    Component {
        id: personalisationPage
        PageColumn {
            Section { text: "Colour theme" }
            Flow {
                width: parent.width
                spacing: 10
                Repeater {
                    model: Object.keys(Config.themes)
                    delegate: HoverButton {
                        required property string modelData
                        readonly property var t: Config.themes[modelData]
                        width: 150; height: 92
                        radius: Theme.radiusItem
                        color: t.base
                        border.width: 2
                        border.color: Config.s.theme === modelData ? t.accent : Theme.border
                        onClicked: Config.set("theme", modelData)
                        Row {
                            anchors { left: parent.left; top: parent.top; margins: 14 }
                            spacing: 6
                            Rectangle { width: 22; height: 22; radius: 11; color: parent.parent.t.accent }
                            Rectangle { width: 22; height: 22; radius: 11; color: parent.parent.t.accent2 }
                        }
                        Label { anchors { left: parent.left; bottom: parent.bottom; margins: 14 }
                text: parent.t.name; size: 13; weight: Font.DemiBold }
                        Glyph { visible: Config.s.theme === parent.modelData; anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
                                text: Icons.check; size: 18; color: parent.t.accent }
                    }
                }
            }

            Section { text: "Background" }
            Process {
                id: walls
                running: true
                property var files: []
                command: ["sh", "-c", 'find "$HOME/.local/share/twilight/wallpapers" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) | sort']
                stdout: StdioCollector { onStreamFinished: walls.files = text.trim().split("\n").filter(f => f) }
            }
            Process {
                id: pick
                command: ["sh", "-c", 'f=$(kdialog --title "Choose a wallpaper" --getopenfilename "$HOME/Pictures" "image/jpeg image/png image/webp") && [ -n "$f" ] '
                          + '&& d="$HOME/.local/share/twilight/wallpapers" && cp -n "$f" "$d/" && echo "$d/$(basename "$f")"']
                stdout: StdioCollector { onStreamFinished: { const f = text.trim(); if (f) { Config.set("wallpaper", f); walls.running = true } } }
            }
            Flow {
                width: parent.width
                spacing: 10
                Repeater {
                    model: walls.files
                    delegate: HoverButton {
                        id: wallItem
                        required property string modelData
                        width: 200; height: 113
                        radius: Theme.radiusItem
                        border.width: 2
                        border.color: Config.s.wallpaper === modelData ? Theme.accent : "transparent"
                        onClicked: Config.set("wallpaper", modelData)
                        ClippingRectangle {
                            anchors { fill: parent; margins: 3 }
                            radius: Theme.radiusItem - 3
                            Image { anchors.fill: parent; source: "file://" + wallItem.modelData; sourceSize: Qt.size(400, 226)
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        }
                    }
                }
                HoverButton {
                    width: 200; height: 113
                    radius: Theme.radiusItem
                    color: hovered ? Theme.hover : Theme.card
                    onClicked: pick.running = true
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: Icons.image; size: 24 }
                        Label { text: "Add a picture…"; size: 12 }
                    }
                }
            }

            SettingRow { glyph: Icons.palette; title: "Theme-coloured Dolphin and Discover icons"
                subtitle: "Those two icons in the wallpaper's ember/amber; all other icons stay your KDE ColorFlow. Reopen apps to see the change."
                Toggle { checked: Config.s.tintedIcons; onToggled: c => Config.set("tintedIcons", c) } }

            Section { text: "Top bar" }
            SettingRow { glyph: Icons.cpu; title: "Show CPU and memory meters"; subtitle: "Rings beside the date and time"
                Toggle { checked: Config.s.showMeters; onToggled: c => Config.set("showMeters", c) } }
            SettingRow { glyph: Icons.bolt; title: "24-hour clock"
                Toggle { checked: Config.s.clock24; onToggled: c => Config.set("clock24", c) } }
            SettingRow { glyph: Icons.darkMode; title: "Dark mode for apps"; subtitle: "GTK apps, browsers and Electron apps. KDE apps follow your KDE colours."
                Toggle { checked: Sys.darkMode; onToggled: c => Sys.setDarkMode(c) } }
        }
    }

    Component {
        id: taskbarPage
        PageColumn {
            SettingRow {
                glyph: Icons.apps; title: "Taskbar behaviour"
                subtitle: "Dodge: hides only when a window is maximised · Auto-hide: hides unless the pointer is at the bottom edge"
                Choice { options: [["dodge", "Dodge"], ["always", "Always show"], ["autohide", "Auto-hide"]]; value: Config.s.taskbarMode
                         onPicked: v => Config.set("taskbarMode", v) }
            }
            Section { text: "Pinned to taskbar" }
            Repeater {
                model: Apps.taskbarPins
                delegate: SettingRow {
                    required property var modelData
                    title: modelData.name
                    subtitle: modelData.genericName || modelData.comment || ""
                    HoverButton { width: unpinLabel.implicitWidth + 24; height: 32; radius: 16; color: hovered ? Theme.hover : Theme.card
                        onClicked: Apps.togglePin("taskbar", parent.parent.modelData)
                        Label { id: unpinLabel; anchors.centerIn: parent; text: "Unpin"; size: 12 } }
                }
            }
            Label { text: "Tip: right-click any app in the Start menu or taskbar to pin it."; size: 12; color: Theme.subtext; topPadding: 6 }
        }
    }

    Component {
        id: windowsPage
        PageColumn {
            SettingRow { glyph: Icons.winMax; title: "Title bars with window buttons"; subtitle: "Amber minimise, green maximise and red close dots on each window"
                Toggle { checked: Config.s.titleBars; onToggled: c => Config.set("titleBars", c) } }
            SettingRow { glyph: Icons.chevronLeft; title: "Window buttons position"
                Choice { options: [[true, "Left"], [false, "Right"]]; value: Config.s.buttonsLeft; onPicked: v => Config.set("buttonsLeft", v) } }
            SettingRow { glyph: Icons.apps; title: "Space between windows"
                Choice { options: [["none", "None"], ["small", "Small"], ["normal", "Normal"], ["wide", "Wide"]]; value: Config.s.gaps
                         onPicked: v => Config.set("gaps", v) } }
            SettingRow { glyph: Icons.dot; title: "Rounded corners"; subtitle: Config.s.rounding + " px"
                Slider { width: 220; step: 0.05; value: Config.s.rounding / 20; onMoved: v => Config.set("rounding", Math.round(v * 20)) } }
            SettingRow { glyph: Icons.brightness; title: "Transparency blur"; subtitle: "Glass effect behind panels. Turn off to save battery."
                Toggle { checked: Config.s.blur; onToggled: c => Config.set("blur", c) } }
            SettingRow { glyph: Icons.performance; title: "Animations"; subtitle: "Turn off for maximum responsiveness"
                Toggle { checked: Config.s.animations; onToggled: c => Config.set("animations", c) } }
        }
    }

    Component {
        id: displayPage
        PageColumn {
            DisplaySettings {}
            Label { text: "Brightness & colour"; size: 13; weight: Font.DemiBold; color: Theme.subtext; topPadding: 12 }
            SettingRow { glyph: Icons.brightness; title: "Brightness"
                Slider { width: 260; value: Sys.brightness; onMoved: v => Sys.setBrightness(v) } }
            SettingRow { glyph: Icons.night; title: "Night light"; subtitle: "Warmer colours in the evening"
                Toggle { checked: Sys.nightLight; onToggled: c => Sys.nightLight = c } }
            SettingRow { glyph: Icons.night; title: "Night light strength"; subtitle: Config.s.nightTemp + " K"
                Slider { width: 260; step: 0.05; value: (6500 - Config.s.nightTemp) / 3500
                         onMoved: v => Config.set("nightTemp", Math.round(6500 - v * 3500)) } }
        }
    }

    Component {
        id: soundPage
        PageColumn {
            SettingRow { glyph: Sys.muted ? Icons.volOff : Icons.volHigh; title: "Volume"; subtitle: Math.round(Sys.volume * 100) + "%"
                Toggle { checked: !Sys.muted; onToggled: c => Sys.toggleMute() }
                Slider { width: 220; value: Sys.volume; onMoved: v => Sys.setVolume(v) } }
            SettingRow { glyph: Sys.micMuted ? Icons.micOff : Icons.mic; title: "Microphone"; subtitle: Math.round(Sys.micVolume * 100) + "%"
                Toggle { checked: !Sys.micMuted; onToggled: c => Sys.toggleMic() }
                Slider { width: 220; value: Sys.micVolume; onMoved: v => Sys.setMicVolume(v) } }
            Section { text: "Output device" }
            Repeater {
                model: ScriptModel { values: Sys.sinks }
                delegate: SettingRow {
                    required property var modelData
                    glyph: Icons.speaker
                    title: modelData.description || modelData.name
                    Toggle { checked: parent.parent.modelData === Sys.sink; onToggled: Sys.setSink(parent.parent.modelData) }
                }
            }
            SettingRow { glyph: Icons.cog; title: "Advanced sound settings"; subtitle: "Per-app volume, profiles, inputs"
                HoverButton { width: 90; height: 32; radius: 16; color: hovered ? Theme.hover : Theme.card; onClicked: Quickshell.execDetached(["pavucontrol"])
                    Label { anchors.centerIn: parent; text: "Open"; size: 12 } } }
        }
    }

    Component {
        id: networkPage
        PageColumn {
            SettingRow { glyph: Net.glyph(); title: "Wi-Fi"; subtitle: Net.label
                Toggle { checked: Net.wifiOn; onToggled: c => Net.setWifi(c) } }
            SettingRow { glyph: Icons.bluetooth; title: "Bluetooth"; subtitle: Sys.btOn ? (Sys.btConnected.length ? "Connected to " + Sys.btConnected.map(d => d.name).join(", ") : "On") : "Off"
                Toggle { checked: Sys.btOn; onToggled: c => Sys.setBluetooth(c) } }
            SettingRow { glyph: Icons.airplane; title: "Airplane mode"
                Toggle { checked: Sys.airplane; onToggled: c => Sys.setAirplane(c) } }
            SettingRow { glyph: Icons.cog; title: "Pair Bluetooth devices"
                HoverButton { width: 90; height: 32; radius: 16; color: hovered ? Theme.hover : Theme.card; onClicked: Quickshell.execDetached(["kcmshell6", "kcm_bluetooth"])
                    Label { anchors.centerIn: parent; text: "Open"; size: 12 } } }
            Label { text: "Choose Wi-Fi networks from Quick settings (top-right)."; size: 12; color: Theme.subtext; topPadding: 6 }
        }
    }

    Component {
        id: inputPage
        PageColumn {
            Section { text: "Touchpad" }
            SettingRow { glyph: Icons.chevronDown; title: "Natural scrolling"; subtitle: "Content follows your fingers, like a phone"
                Toggle { checked: Config.s.naturalScroll; onToggled: c => Config.set("naturalScroll", c) } }
            SettingRow { glyph: Icons.dot; title: "Tap to click"
                Toggle { checked: Config.s.tapToClick; onToggled: c => Config.set("tapToClick", c) } }
            SettingRow { glyph: Icons.performance; title: "Pointer speed"; subtitle: Config.s.pointerSpeed.toFixed(2)
                Slider { width: 260; step: 0.05; value: (Config.s.pointerSpeed + 1) / 2; onMoved: v => Config.set("pointerSpeed", v * 2 - 1) } }
            SettingRow { glyph: Icons.chevronLeft; title: "Left-handed buttons"; subtitle: "Swap primary and secondary buttons (touchpad and mouse)"
                Toggle { checked: Config.s.leftHanded; onToggled: c => Config.set("leftHanded", c) } }
            Section { text: "Keyboard" }
            SettingRow { glyph: Icons.keyboard; title: "Key repeat delay"; subtitle: "How long to hold a key before it repeats"
                Choice { options: [[250, "Short"], [400, "Medium"], [600, "Long"]]; value: Config.s.repeatDelay; onPicked: v => Config.set("repeatDelay", v) } }
            SettingRow { glyph: Icons.keyboard; title: "Key repeat speed"
                Choice { options: [[20, "Slow"], [30, "Normal"], [45, "Fast"]]; value: Config.s.repeatRate; onPicked: v => Config.set("repeatRate", v) } }
            SettingRow { glyph: Icons.keyboard; title: "Keyboard layout"; subtitle: "Several layouts: switch with the layout code list, e.g. us,in"
                Choice { options: [["us", "US"], ["gb", "UK"], ["in", "India"], ["us,in", "US + India"]]; value: Config.s.kbLayout
                         onPicked: v => Config.set("kbLayout", v) } }
        }
    }

    Component {
        id: powerPage
        PageColumn {
            SettingRow { glyph: Sys.batteryGlyph(); title: "Battery"; subtitle: Sys.hasBattery ? Math.round(Sys.batteryPct * 100) + "%" + (Sys.charging ? " · charging" : "") : "No battery"
                Item { width: 1; height: 1 } }
            SettingRow { glyph: Icons.balanced; title: "Power mode"
                Choice {
                    options: [[PowerProfile.PowerSaver, "Battery saver"], [PowerProfile.Balanced, "Balanced"]]
                             .concat(PowerProfiles.hasPerformanceProfile ? [[PowerProfile.Performance, "Best performance"]] : [])
                    value: PowerProfiles.profile
                    onPicked: v => PowerProfiles.profile = v
                } }
            Section { text: "When I'm away" }
            SettingRow { glyph: Icons.brightness; title: "Dim the screen after"
                Choice { options: win.minutes.slice(0, 5); value: Config.s.dimAfter; onPicked: v => Config.set("dimAfter", v) } }
            SettingRow { glyph: Icons.lock; title: "Lock after"
                Choice { options: win.minutes.slice(0, 6); value: Config.s.lockAfter; onPicked: v => Config.set("lockAfter", v) } }
            SettingRow { glyph: Icons.monitor; title: "Turn off the screen after"
                Choice { options: win.minutes.slice(0, 6); value: Config.s.screenOffAfter; onPicked: v => Config.set("screenOffAfter", v) } }
            SettingRow { glyph: Icons.sleep; title: "Sleep after"
                Choice { options: [[0, "Never"], [10, "10 min"], [20, "20 min"], [30, "30 min"], [60, "1 hour"]]; value: Config.s.sleepAfter
                         onPicked: v => Config.set("sleepAfter", v) } }
        }
    }

    Component {
        id: notificationsPage
        PageColumn {
            SettingRow { glyph: Icons.bellSleep; title: "Do not disturb"; subtitle: "Only critical notifications pop up"
                Toggle { checked: Sys.dnd; onToggled: c => Sys.dnd = c } }
            SettingRow { glyph: Icons.bell; title: "Show pop-ups for"
                Choice { options: [[3, "3 s"], [5, "5 s"], [8, "8 s"], [12, "12 s"]]; value: Config.s.toastSeconds; onPicked: v => Config.set("toastSeconds", v) } }
            SettingRow { glyph: Icons.clearAll; title: "Notification history"; subtitle: Notifs.count + " in this session"
                HoverButton { width: 90; height: 32; radius: 16; color: hovered ? Theme.hover : Theme.card; onClicked: Notifs.clearAll()
                    Label { anchors.centerIn: parent; text: "Clear all"; size: 12 } } }
        }
    }

    Component {
        id: appsPage
        PageColumn {
            id: ap
            property string filter: ""
            Section { text: "Start menu" }
            SettingRow { glyph: Icons.document; title: "Show recently opened files"; subtitle: "In Start → Recommended and in search"
                Toggle { checked: Config.s.showRecentFiles; onToggled: c => Config.set("showRecentFiles", c) } }
            SettingRow { glyph: Icons.clearAll; title: "Clear recently launched apps"
                HoverButton { width: 90; height: 32; radius: 16; color: hovered ? Theme.hover : Theme.card; onClicked: Apps.clearActivity()
                    Label { anchors.centerIn: parent; text: "Clear"; size: 12 } } }
            Section { text: "Startup apps — open automatically when you sign in to Twilight" }
            Rectangle {
                width: parent.width; height: 40; radius: 20
                color: Qt.rgba(1, 1, 1, 0.07)
                border.color: Theme.border
                Glyph { id: sg; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: Icons.search; size: 16; color: Theme.subtext }
                TextInput {
                    id: appFilter
                    anchors { left: sg.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 13
                    onTextChanged: ap.filter = text.toLowerCase()
                    Label { visible: !appFilter.text; text: "Find an app"; color: Theme.dim; size: 13; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Repeater {
                model: Apps.all.filter(e => !ap.filter || e.name.toLowerCase().includes(ap.filter))
                               .sort((a, b) => (Apps.isStartup(b) - Apps.isStartup(a)) || a.name.localeCompare(b.name))
                delegate: SettingRow {
                    id: appRow
                    required property var modelData
                    title: modelData.name
                    subtitle: modelData.genericName || ""
                    implicitHeight: 52
                    IconImage { implicitSize: 24; source: Apps.iconOf(appRow.modelData); anchors.verticalCenter: parent.verticalCenter }
                    Toggle { checked: Apps.isStartup(appRow.modelData); onToggled: Apps.toggleStartup(appRow.modelData) }
                }
            }
        }
    }

    Component {
        id: timePage
        PageColumn {
            SettingRow { glyph: Icons.bolt; title: "24-hour clock"
                Toggle { checked: Config.s.clock24; onToggled: c => Config.set("clock24", c) } }
            SettingRow { glyph: Icons.apps; title: "First day of the week"; subtitle: "Used by the calendar"
                Choice { options: [[false, "Sunday"], [true, "Monday"]]; value: Config.s.weekStartsMonday; onPicked: v => Config.set("weekStartsMonday", v) } }
            SettingRow { glyph: Icons.keyboard; title: "Keyboard layout"
                Choice { options: [["us", "US"], ["gb", "UK"], ["in", "India"], ["us,in", "US + India"]]; value: Config.s.kbLayout
                         onPicked: v => Config.set("kbLayout", v) } }
            Label { width: parent.width; wrapMode: Text.WordWrap; size: 12; color: Theme.subtext; topPadding: 6
                text: "Date, time zone and language come from the system (shared with KDE), so they are not changed here." }
        }
    }

    Component {
        id: accessibilityPage
        PageColumn {
            SettingRow { glyph: Icons.account; title: "Pointer size"; subtitle: "Apps pick up the new size after you sign in again"
                Choice { options: [[24, "Normal"], [32, "Large"], [48, "Extra large"]]; value: Config.s.cursorSize; onPicked: v => Config.set("cursorSize", v) } }
            SettingRow { glyph: Icons.performance; title: "Animations"; subtitle: "Turn off to reduce motion"
                Toggle { checked: Config.s.animations; onToggled: c => Config.set("animations", c) } }
            SettingRow { glyph: Icons.brightness; title: "Transparency effects"
                Toggle { checked: Config.s.blur; onToggled: c => Config.set("blur", c) } }
            SettingRow { glyph: Icons.monitor; title: "Text and app size"; subtitle: "Set the scale of each screen on the Display page"
                HoverButton { width: 90; height: 32; radius: 16; color: hovered ? Theme.hover : Theme.card; onClicked: win.page = "display"
                    Label { anchors.centerIn: parent; text: "Open"; size: 12 } } }
            SettingRow { glyph: Icons.bell; title: "Keep notifications on screen for"
                Choice { options: [[5, "5 s"], [8, "8 s"], [12, "12 s"], [20, "20 s"]]; value: Config.s.toastSeconds; onPicked: v => Config.set("toastSeconds", v) } }
        }
    }

    // ---- Fingerprint enrolment (fprintd), Windows-Hello style ----
    Component {
        id: signinPage
        PageColumn {
            id: fp
            property string phase: "idle"     // idle | enrolling | done | failed | verifying
            property string message: ""
            property int stages: 0
            property var fingers: []
            property string finger: "right-index-finger"
            property bool sudoFingerprint: false
            readonly property bool busy: enroll.running || verify.running

            readonly property var fingerNames: ({
                "right-index-finger": "Right index", "right-thumb": "Right thumb", "right-middle-finger": "Right middle",
                "left-index-finger": "Left index", "left-thumb": "Left thumb", "left-middle-finger": "Left middle",
                "right-ring-finger": "Right ring", "left-ring-finger": "Left ring",
                "right-little-finger": "Right little", "left-little-finger": "Left little",
            })

            Process {
                id: list
                running: true
                command: ["sh", "-c", "fprintd-list \"$USER\" 2>&1; grep -qs pam_fprintd /etc/pam.d/sudo && echo SUDO_FPRINT"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        fp.fingers = (text.match(/#\d+: ([a-z-]+)/g) ?? []).map(s => s.split(": ")[1])
                        fp.sudoFingerprint = text.includes("SUDO_FPRINT")
                    }
                }
            }
            Process {
                id: enroll
                command: ["fprintd-enroll", "-f", fp.finger]
                stdout: SplitParser {
                    onRead: line => {
                        if (line.includes("enroll-stage-passed")) { fp.stages++; fp.message = "Good — lift your finger and touch again" }
                        else if (line.includes("enroll-retry-scan") || line.includes("too-short") || line.includes("not-centered") || line.includes("remove-and-retry"))
                            fp.message = "Didn't catch that — touch the sensor again"
                        else if (line.includes("enroll-completed")) { fp.phase = "done"; fp.message = fp.fingerNames[fp.finger] + " saved"; list.running = true }
                        else if (line.includes("enroll-duplicate")) { fp.phase = "failed"; fp.message = "That finger is already enrolled" }
                        else if (line.includes("enroll-failed") || line.includes("enroll-data-full")) { fp.phase = "failed"; fp.message = "Enrolment failed — try again" }
                    }
                }
                stderr: SplitParser { onRead: line => { if (fp.phase === "enrolling") fp.message = line } }
                onExited: code => { if (fp.phase === "enrolling") { fp.phase = code === 0 ? "done" : "failed"; list.running = true } }
            }
            Process {
                id: verify
                command: ["fprintd-verify"]
                stdout: SplitParser {
                    onRead: line => {
                        if (line.includes("verify-match")) { fp.phase = "done"; fp.message = "Recognised ✓" }
                        else if (line.includes("verify-no-match")) { fp.phase = "failed"; fp.message = "Not recognised — try again" }
                    }
                }
                onExited: if (fp.phase === "verifying") fp.phase = "idle"
            }
            Process { id: remove; onExited: list.running = true }
            function removeFinger(f) {
                fp.message = ""; fp.phase = "idle"
                remove.command = f ? ["fprintd-delete", Quickshell.env("USER"), "-f", f] : ["fprintd-delete", Quickshell.env("USER")]
                remove.running = true
            }

            // ---- Status card ----
            Rectangle {
                width: parent.width; height: 200; radius: Theme.radiusPanel
                color: Theme.card
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Icons.fingerprint; size: 64
                        color: fp.phase === "done" ? Theme.green : fp.phase === "failed" ? Theme.red
                             : fp.busy ? Theme.accent : Theme.subtext
                        SequentialAnimation on opacity {
                            running: fp.busy
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.45; duration: 700 }
                            NumberAnimation { to: 1; duration: 700 }
                        }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: fp.message || (fp.fingers.length ? fp.fingers.length + " fingerprint" + (fp.fingers.length > 1 ? "s" : "") + " enrolled" : "No fingerprints enrolled yet")
                        size: 14; weight: Font.Medium
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: fp.phase === "enrolling"
                        text: fp.stages + " scans captured — keep going until it says saved"
                        size: 12; color: Theme.subtext
                    }
                }
            }

            Section { text: "Add a fingerprint" }
            SettingRow {
                glyph: Icons.fingerprint
                title: "Finger"
                subtitle: "Pick the finger you'll use, then press Set up and touch the sensor each time it asks"
                Choice {
                    options: [["right-index-finger", "Right index"], ["right-thumb", "Right thumb"], ["left-index-finger", "Left index"], ["left-thumb", "Left thumb"]]
                    value: fp.finger
                    onPicked: v => fp.finger = v
                }
                HoverButton {
                    width: setupLabel.implicitWidth + 28; height: 34; radius: 17
                    enabled: !fp.busy
                    opacity: enabled ? 1 : 0.5
                    color: hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                    onClicked: { fp.stages = 0; fp.message = "Touch the fingerprint sensor"; fp.phase = "enrolling"; enroll.running = true }
                    Label { id: setupLabel; anchors.centerIn: parent; text: "Set up"; size: 12; color: "#140b06"; weight: Font.DemiBold }
                }
            }

            Section { text: "Enrolled fingerprints"; visible: fp.fingers.length > 0 }
            Repeater {
                model: fp.fingers
                delegate: SettingRow {
                    required property string modelData
                    glyph: Icons.fingerprint
                    title: fp.fingerNames[modelData] ?? modelData
                    HoverButton { width: 90; height: 32; radius: 16; color: hovered ? Theme.red : Theme.card
                        enabled: !fp.busy
                        onClicked: fp.removeFinger(parent.parent.modelData)
                        Label { anchors.centerIn: parent; text: "Remove"; size: 12 } }
                }
            }
            SettingRow {
                visible: fp.fingers.length > 0
                glyph: Icons.check
                title: "Test fingerprint"
                subtitle: "Checks any enrolled finger"
                HoverButton { width: 90; height: 32; radius: 16; color: hovered ? Theme.hover : Theme.card
                    enabled: !fp.busy
                    onClicked: { fp.message = "Touch the sensor"; fp.phase = "verifying"; verify.running = true }
                    Label { anchors.centerIn: parent; text: "Test"; size: 12 } }
            }

            Section { text: "Where to use it" }
            SettingRow { glyph: Icons.lock; title: "Unlock the lock screen with a fingerprint"; subtitle: "Your password always works too"
                Toggle { checked: Config.s.fingerprintUnlock; onToggled: c => Config.set("fingerprintUnlock", c) } }
            SettingRow { glyph: Icons.sleep; title: "Lock when the laptop goes to sleep"
                Toggle { checked: Config.s.lockOnSleep; onToggled: c => Config.set("lockOnSleep", c) } }
            SettingRow { glyph: Icons.cog; title: "sudo (terminal admin prompts)"
                subtitle: fp.sudoFingerprint ? "Fingerprint accepted — set up system-wide by CachyOS" : "Password only"
                Label { text: fp.sudoFingerprint ? "On" : "Off"; size: 12; color: Theme.subtext } }
            SettingRow { glyph: Icons.account; title: "Login screen"
                subtitle: "Plasma Login Manager uses your password (shared with KDE, not changed here)"
                Label { text: "Password"; size: 12; color: Theme.subtext } }

            SettingRow {
                visible: fp.fingers.length > 1
                glyph: Icons.trash
                title: "Remove all fingerprints"
                HoverButton { width: 110; height: 32; radius: 16; color: hovered ? Theme.red : Theme.card
                    enabled: !fp.busy
                    onClicked: fp.removeFinger("")
                    Label { anchors.centerIn: parent; text: "Remove all"; size: 12 } }
            }
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Fingerprints are stored by the system (fprintd), so KDE's lock screen and sudo can use them too."
                size: 12; color: Theme.subtext; topPadding: 6
            }
        }
    }

    // Window buttons (this window draws its own; side follows Settings → Windows).
    WindowDots {
        z: 100
        anchors { verticalCenter: header.verticalCenter; verticalCenterOffset: 4 }
        x: Config.s.buttonsLeft ? nav.width + 32 : parent.width - width - 24
        readonly property var me: Hyprland.toplevels.values.find(t => t.title === "Twilight Settings") ?? null
        maximized: me?.workspace?.hasFullscreen ?? false
        onMinimize: Win.minimize(me)
        onMaximize: Win.toggleMaximize(me)
        onClose: Ui.settingsOpen = false
    }

    // Soft fades at the bottom edges so rows cut off by scrolling look intentional.
    Rectangle {
        anchors { left: flick.left; right: flick.right; bottom: parent.bottom }
        height: 28
        gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: win.color } }
    }
    Rectangle {
        anchors { left: nav.left; right: nav.right; bottom: parent.bottom }
        height: 28
        gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.18) } }
    }
}
