import QtQuick
import Quickshell

// Calendar opened from the date/time in the top bar. Days / Months / Years
// views with previous / next / Today. Deliberately shows no clock.
Panel {
    id: cal

    name: "calendar"
    panelWidth: 380
    panelHeight: 408
    anchors { top: true; left: true }
    margins {
        top: 6
        left: Math.max(8, Math.min((screen?.width ?? 1920) - panelWidth - 8, Ui.anchorX - panelWidth / 2))
    }

    SystemClock { id: clock; precision: SystemClock.Hours }
    readonly property date today: clock.date

    property string view: "days"     // days | months | years
    property int year: today.getFullYear()
    property int month: today.getMonth()

    onIsOpenChanged: if (isOpen) { view = "days"; year = today.getFullYear(); month = today.getMonth() }

    function step(d) {
        if (view === "days") {
            const m = month + d
            year += Math.floor(m / 12)
            month = ((m % 12) + 12) % 12
        } else if (view === "months") year += d
        else year += 12 * d
    }

    readonly property int yearBase: year - (year % 12)
    readonly property var days: {
        const first = new Date(year, month, 1)
        const offset = Config.s.weekStartsMonday ? (first.getDay() + 6) % 7 : first.getDay()
        const start = new Date(year, month, 1 - offset)
        const out = []
        for (let i = 0; i < 42; i++) out.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
        return out
    }

    Column {
        anchors { fill: parent; margins: 18 }
        spacing: 12

        // Header: month/year title.
        Label {
            text: cal.view === "days" ? Qt.locale().standaloneMonthName(cal.month) + " " + cal.year
                : cal.view === "months" ? String(cal.year)
                : cal.yearBase + " – " + (cal.yearBase + 11)
            size: 18
            weight: Font.DemiBold
        }

        // View tabs + navigation.
        Item {
            width: parent.width
            height: 32
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [["days", "Days"], ["months", "Months"], ["years", "Years"]]
                    delegate: HoverButton {
                        required property var modelData
                        width: tabLabel.implicitWidth + 22; height: 30
                        radius: 15
                        active: cal.view === modelData[0]
                        onClicked: cal.view = modelData[0]
                        Label { id: tabLabel; anchors.centerIn: parent; text: parent.modelData[1]; size: 12
                                color: parent.active ? Theme.text : Theme.subtext; weight: parent.active ? Font.DemiBold : Font.Normal }
                    }
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 2
                HoverButton { width: 30; height: 30; radius: 15; onClicked: cal.step(-1)
                    Glyph { anchors.centerIn: parent; text: Icons.chevronLeft; size: 18 } }
                HoverButton { width: todayLabel.implicitWidth + 20; height: 30; radius: 15
                    onClicked: { cal.view = "days"; cal.year = cal.today.getFullYear(); cal.month = cal.today.getMonth() }
                    Label { id: todayLabel; anchors.centerIn: parent; text: "Today"; size: 12 } }
                HoverButton { width: 30; height: 30; radius: 15; onClicked: cal.step(1)
                    Glyph { anchors.centerIn: parent; text: Icons.chevronRight; size: 18 } }
            }
        }

        // ---- Days ----
        Column {
            visible: cal.view === "days"
            width: parent.width
            spacing: 2
            Row {
                Repeater {
                    model: 7
                    delegate: Label {
                        required property int index
                        width: (cal.panelWidth - 36) / 7; height: 26
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName((index + (Config.s.weekStartsMonday ? 1 : 0)) % 7, Locale.ShortFormat)
                        size: 12; weight: Font.DemiBold; color: Theme.subtext
                    }
                }
            }
            Grid {
                columns: 7
                Repeater {
                    model: cal.days
                    delegate: HoverButton {
                        required property var modelData
                        readonly property bool inMonth: modelData.getMonth() === cal.month
                        readonly property bool isToday: modelData.toDateString() === cal.today.toDateString()
                        width: (cal.panelWidth - 36) / 7; height: 40
                        radius: 10
                        color: isToday ? Theme.accent : hovered ? Theme.hover : "transparent"
                        Label {
                            anchors.centerIn: parent
                            text: parent.modelData.getDate()
                            size: 13
                            weight: parent.isToday ? Font.Bold : Font.Normal
                            color: parent.isToday ? "#1a0f0a" : parent.inMonth ? Theme.text : Theme.dim
                        }
                    }
                }
            }
        }

        // ---- Months ----
        Grid {
            visible: cal.view === "months"
            columns: 3
            Repeater {
                model: 12
                delegate: HoverButton {
                    required property int index
                    readonly property bool current: index === cal.today.getMonth() && cal.year === cal.today.getFullYear()
                    width: (cal.panelWidth - 36) / 3; height: 68
                    radius: 12
                    color: current ? Theme.accentSoft : hovered ? Theme.hover : "transparent"
                    onClicked: { cal.month = index; cal.view = "days" }
                    Label { anchors.centerIn: parent; text: Qt.locale().standaloneMonthName(parent.index, Locale.ShortFormat); size: 14
                            color: parent.current ? Theme.accent : Theme.text; weight: parent.current ? Font.DemiBold : Font.Normal }
                }
            }
        }

        // ---- Years ----
        Grid {
            visible: cal.view === "years"
            columns: 3
            Repeater {
                model: 12
                delegate: HoverButton {
                    required property int index
                    readonly property int yr: cal.yearBase + index
                    readonly property bool current: yr === cal.today.getFullYear()
                    width: (cal.panelWidth - 36) / 3; height: 68
                    radius: 12
                    color: current ? Theme.accentSoft : hovered ? Theme.hover : "transparent"
                    onClicked: { cal.year = yr; cal.view = "months" }
                    Label { anchors.centerIn: parent; text: parent.yr; size: 14
                            color: parent.current ? Theme.accent : Theme.text; weight: parent.current ? Font.DemiBold : Font.Normal }
                }
            }
        }
    }
}
