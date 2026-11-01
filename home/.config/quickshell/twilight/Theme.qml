pragma Singleton

import QtQuick
import Quickshell

// Twilight design tokens: one place for colour, type, shape and motion.
Singleton {
    // Colours follow the theme preset chosen in Settings (Config.qml).
    // Surfaces: deep navy from the wallpaper, translucent so the compositor's
    // light blur shows through.
    readonly property color base: Config.theme.base
    readonly property color surface: Qt.rgba(base.r * 1.2 + 0.02, base.g * 1.2 + 0.02, base.b * 1.2 + 0.03, 0.84)
    readonly property color surfaceStrong: Qt.rgba(base.r * 1.2 + 0.02, base.g * 1.2 + 0.02, base.b * 1.2 + 0.03, 0.94)
    readonly property color card: Qt.rgba(1, 1, 1, 0.055)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.09)
    readonly property color pressed: Qt.rgba(1, 1, 1, 0.14)
    readonly property color border: Qt.rgba(1, 1, 1, 0.09)
    readonly property color borderStrong: Qt.rgba(1, 1, 1, 0.16)

    readonly property color text: "#f1eee6"
    readonly property color subtext: "#aeb3c8"
    readonly property color dim: "#727892"

    readonly property color accent: Config.theme.accent
    readonly property color accent2: Config.theme.accent2
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    readonly property color red: "#ff6b81"
    readonly property color green: "#5fd39b"
    readonly property color yellow: "#f2c36b"

    readonly property string font: "Inter"
    readonly property string iconFont: "JetBrainsMono Nerd Font Propo"

    readonly property int radiusPanel: 18
    readonly property int radiusItem: 12
    readonly property int radiusSmall: 8

    readonly property int barHeight: 34
    readonly property int taskbarHeight: 54
    readonly property int taskbarGap: 8

    readonly property int fast: 140
    readonly property int normal: 220
    readonly property int slow: 320
}
