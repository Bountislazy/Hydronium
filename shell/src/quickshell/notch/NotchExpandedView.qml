import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "../singletons/environment"
import "../singletons/info"
import "../singletons/audio"
import "../reusables"
import "../"

Item {
    id: expandedRoot

    required property var windowRoot

    // ==========================================
    // TAB NAVIGATION STATE
    // ==========================================
    property int currentTab: 0

    // Lyrics subscription when Media Tab is active and Notch is visible
    readonly property bool shouldSubscribeLyrics: expandedRoot.visible && expandedRoot.currentTab === 1
    onShouldSubscribeLyricsChanged: {
        if (typeof Lyrics !== "undefined") {
            if (shouldSubscribeLyrics) Lyrics.subscribe();
            else Lyrics.unsubscribe();
        }
    }

    Component.onCompleted: {
        if (typeof Lyrics !== "undefined" && shouldSubscribeLyrics) {
            Lyrics.subscribe();
        }
    }

    Component.onDestruction: {
        if (typeof Lyrics !== "undefined" && shouldSubscribeLyrics) {
            Lyrics.unsubscribe();
        }
    }

    // Timer for time update
    property var currentTime: new Date()
    Timer {
        interval: 1000
        running: expandedRoot.visible
        repeat: true
        onTriggered: expandedRoot.currentTime = new Date()
    }

    // Media controller shortcuts
    readonly property bool hasPlayer: (typeof MprisController !== "undefined") && MprisController.hasActivePlayer && MprisController.activePlayer !== null
    readonly property MprisPlayer activePlayer: hasPlayer ? MprisController.activePlayer : null
    readonly property bool isPlaying: hasPlayer && MprisController.isPlaying
    readonly property real playerLength: (activePlayer && activePlayer.length > 0) ? activePlayer.length : 0
    readonly property real playerPosition: (activePlayer) ? MprisController.livePosition : 0
    readonly property real progress: (playerLength > 0) ? Math.max(0, Math.min(1.0, playerPosition / playerLength)) : 0

    // System uptime
    property string uptimeStr: "up 1 hour"
    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        running: expandedRoot.visible
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    expandedRoot.uptimeStr = data.trim();
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: expandedRoot.visible
        repeat: true
        onTriggered: uptimeProc.running = true
    }

    // Distro name
    property string distroName: "CachyOS"
    Process {
        id: osProc
        command: ["bash", "-c", "grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '\"'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    expandedRoot.distroName = data.trim();
                }
            }
        }
    }

    // Avatar path
    readonly property string avatarPath: {
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.general && Config.rawSettings.general.avatarPath) {
            return Config.rawSettings.general.avatarPath;
        }
        return "/home/" + (Quickshell.env("USER") || "user") + "/.face";
    }

    function formatSeconds(secs) {
        if (isNaN(secs) || secs < 0) return "0:00";
        let total = Math.floor(secs);
        let m = Math.floor(total / 60);
        let s = total % 60;
        return m + ":" + (s < 10 ? "0" + s : s);
    }

    function formatSpeed(bytesPerSec) {
        if (isNaN(bytesPerSec) || bytesPerSec <= 0) return "0 K/s";
        let kb = bytesPerSec / 1024.0;
        if (kb < 1000) return Math.round(kb) + " K/s";
        let mb = kb / 1024.0;
        return mb.toFixed(1) + " M/s";
    }

    implicitWidth: windowRoot ? (windowRoot.expandedWidth - 56) : 764
    implicitHeight: windowRoot ? (windowRoot.expandedHeight - 24) : 376
    width: implicitWidth
    height: implicitHeight

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ==========================================
        // 1. TABS HEADER (CAELESTIA STYLE)
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 38

            RowLayout {
                id: tabRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 0

                Repeater {
                    model: [
                        { name: "Dashboard", icon: "󰕮" },
                        { name: "Media", icon: "󰝚" },
                        { name: "Performance", icon: "󰓅" },
                        { name: "System", icon: "󰍹" }
                    ]

                    delegate: Item {
                        id: tabItemDelegate
                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 32

                        readonly property bool isSelected: expandedRoot.currentTab === index

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: expandedRoot.currentTab = tabItemDelegate.index
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: tabItemDelegate.modelData.icon
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                font.pixelSize: 13
                                color: tabItemDelegate.isSelected
                                    ? ((typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7")
                                    : (tabMouse.containsMouse
                                        ? ((typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4")
                                        : ((typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"))
                            }

                            Text {
                                text: tabItemDelegate.modelData.name
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                font.pixelSize: 12
                                font.weight: tabItemDelegate.isSelected ? Font.Bold : Font.Normal
                                color: tabItemDelegate.isSelected
                                    ? ((typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7")
                                    : (tabMouse.containsMouse
                                        ? ((typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4")
                                        : ((typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"))
                            }
                        }
                    }
                }
            }

            // Animated tab indicator line
            Rectangle {
                id: tabIndicator
                anchors.bottom: separatorLine.top
                anchors.bottomMargin: 2
                height: 3
                radius: 1.5
                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"

                property real tabWidth: tabRow.width / 4
                x: (tabRow.width / 4) * expandedRoot.currentTab + ((tabRow.width / 4) - width) / 2
                width: Math.min(84, tabRow.width / 4 - 24)

                Behavior on x {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
            }

            // Separator line
            Rectangle {
                id: separatorLine
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.4) : "#313244"
            }
        }

        // ==========================================
        // 2. TAB VIEW CONTAINER
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ------------------------------------------
            // TAB 0: DASHBOARD (CAELESTIA GRID)
            // ------------------------------------------
            GridLayout {
                id: dashboardGrid
                anchors.fill: parent
                columns: 6
                rows: 2
                rowSpacing: 10
                columnSpacing: 10
                visible: expandedRoot.currentTab === 0
                opacity: visible ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // ======================================
                // CARD 1: WEATHER (Row 0, Col 0..1)
                // ======================================
                Rectangle {
                    Layout.row: 0
                    Layout.column: 0
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    radius: 14
                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.45) : Qt.alpha("#313244", 0.45)
                    border.width: 1
                    border.color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.35) : "#45475a"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: (typeof Weather !== "undefined" && Weather.currentIcon) ? Weather.currentIcon : "󰖙"
                            font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                            font.pixelSize: 34
                            color: (typeof Weather !== "undefined" && Weather.currentHex) ? Weather.currentHex : ((typeof ThemeBackend !== "undefined") ? ThemeBackend.peach : "#fab387")
                        }

                        ColumnLayout {
                            spacing: 1

                            Text {
                                text: (typeof Weather !== "undefined" && Weather.currentTemp) ? (Weather.currentTemp + "°C") : "34°C"
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                font.pixelSize: 22
                                font.weight: Font.Bold
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4"
                            }

                            Text {
                                text: (typeof Weather !== "undefined" && Weather.currentDesc) ? Weather.currentDesc : "Clear"
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                font.pixelSize: 11
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                            }
                        }
                    }
                }

                // ======================================
                // CARD 2: USER PROFILE & DISTRO (Row 0, Col 2..4)
                // ======================================
                Rectangle {
                    Layout.row: 0
                    Layout.column: 2
                    Layout.columnSpan: 3
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    radius: 14
                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.45) : Qt.alpha("#313244", 0.45)
                    border.width: 1
                    border.color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.35) : "#45475a"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        // User Avatar Image (Circular)
                        Item {
                            width: 58
                            height: 58

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.surface1 : "#45475a"
                            }

                            Rectangle {
                                id: avatarMask
                                anchors.fill: parent
                                radius: width / 2
                                visible: false
                                layer.enabled: true
                            }

                            Image {
                                id: avatarImg
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                source: expandedRoot.avatarPath ? ("file://" + expandedRoot.avatarPath) : ""
                                visible: false
                            }

                            MultiEffect {
                                anchors.fill: parent
                                source: avatarImg
                                maskEnabled: true
                                maskSource: avatarMask
                                visible: avatarImg.status === Image.Ready && avatarImg.source !== ""
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                            }
                        }

                        // Distro, Compositor, Uptime
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: "󰣇"
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                    font.pixelSize: 13
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.red : "#f38ba8"
                                }
                                Text {
                                    text: ": " + expandedRoot.distroName
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4"
                                }
                            }

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: "󱂬"
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                    font.pixelSize: 13
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                                }
                                Text {
                                    text: ": " + (typeof WindowTracker !== "undefined" && WindowTracker.isNiri ? "Niri" : (typeof WindowTracker !== "undefined" && WindowTracker.isHyprland ? "Hyprland" : "Wayland"))
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                    font.pixelSize: 11
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                                }
                            }

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: "󰔚"
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                    font.pixelSize: 13
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.green : "#a6e3a1"
                                }
                                Text {
                                    text: ": " + expandedRoot.uptimeStr
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                    font.pixelSize: 11
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                // ======================================
                // CARD 3: DATE & TIME (Row 1, Col 0)
                // ======================================
                Rectangle {
                    Layout.row: 1
                    Layout.column: 0
                    Layout.preferredWidth: 80
                    Layout.fillHeight: true
                    radius: 14
                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.45) : Qt.alpha("#313244", 0.45)
                    border.width: 1
                    border.color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.35) : "#45475a"

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatTime(expandedRoot.currentTime, "hh")
                            font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "•••"
                            font.pixelSize: 12
                            color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatTime(expandedRoot.currentTime, "mm")
                            font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4"
                        }

                        Item { Layout.preferredHeight: 6 }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatDate(expandedRoot.currentTime, "ddd, d")
                            font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                        }
                    }
                }

                // ======================================
                // CARD 4: CALENDAR (Row 1, Col 1..3)
                // ======================================
                Rectangle {
                    id: calendarCard
                    Layout.row: 1
                    Layout.column: 1
                    Layout.columnSpan: 3
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.45) : Qt.alpha("#313244", 0.45)
                    border.width: 1
                    border.color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.35) : "#45475a"

                    readonly property int curDay: expandedRoot.currentTime.getDate()
                    readonly property int curMonth: expandedRoot.currentTime.getMonth()
                    readonly property int curYear: expandedRoot.currentTime.getFullYear()

                    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }
                    function firstDayOffset(y, m) {
                        let d = new Date(y, m, 1).getDay();
                        return (d === 0) ? 6 : (d - 1); // Monday is 0
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        // Days of Week Header
                        RowLayout {
                            Layout.fillWidth: true
                            Repeater {
                                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                                delegate: Text {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.overlay1 : "#7f849c"
                                }
                            }
                        }

                        // Calendar Days Grid (5 rows x 7 cols)
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 7
                            rows: 5
                            rowSpacing: 2
                            columnSpacing: 2

                            Repeater {
                                model: 35
                                delegate: Item {
                                    id: dayDelegate
                                    required property int index

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    readonly property int offset: calendarCard.firstDayOffset(calendarCard.curYear, calendarCard.curMonth)
                                    readonly property int totalDays: calendarCard.daysInMonth(calendarCard.curYear, calendarCard.curMonth)
                                    readonly property int prevTotal: calendarCard.daysInMonth(calendarCard.curYear, calendarCard.curMonth - 1)

                                    readonly property bool isCurMonth: index >= offset && index < (offset + totalDays)
                                    readonly property int dayNumber: isCurMonth
                                        ? (index - offset + 1)
                                        : (index < offset ? (prevTotal - offset + index + 1) : (index - offset - totalDays + 1))
                                    readonly property bool isToday: isCurMonth && dayNumber === calendarCard.curDay

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height, 22)
                                        height: width
                                        radius: width / 2
                                        color: dayDelegate.isToday
                                            ? ((typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7")
                                            : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: dayDelegate.dayNumber
                                            font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                            font.pixelSize: 9
                                            font.weight: dayDelegate.isToday ? Font.Bold : Font.Normal
                                            color: dayDelegate.isToday
                                                ? ((typeof ThemeBackend !== "undefined") ? ThemeBackend.base : "#11111b")
                                                : (dayDelegate.isCurMonth
                                                    ? ((typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4")
                                                    : ((typeof ThemeBackend !== "undefined") ? ThemeBackend.surface2 : "#585b70"))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ======================================
                // CARD 5: RESOURCE BARS (Row 1, Col 4)
                // ======================================
                Rectangle {
                    Layout.row: 1
                    Layout.column: 4
                    Layout.preferredWidth: 68
                    Layout.fillHeight: true
                    radius: 14
                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.45) : Qt.alpha("#313244", 0.45)
                    border.width: 1
                    border.color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.35) : "#45475a"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        // CPU Bar
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 4

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.5) : "#45475a"

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: Math.max(0, Math.min(parent.height, parent.height * ((typeof SysData !== "undefined" ? SysData.cpu : 15) / 100.0)))
                                        radius: 6
                                        color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.peach : "#fab387"

                                        Behavior on height {
                                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰍛"
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                font.pixelSize: 11
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.peach : "#fab387"
                            }
                        }

                        // RAM Bar
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 4

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.5) : "#45475a"

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: Math.max(0, Math.min(parent.height, parent.height * ((typeof SysData !== "undefined" ? SysData.ramPercent : 40) / 100.0)))
                                        radius: 6
                                        color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"

                                        Behavior on height {
                                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰘚"
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                font.pixelSize: 11
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                            }
                        }

                        // Disk Bar
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 4

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.5) : "#45475a"

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: Math.max(0, Math.min(parent.height, parent.height * ((typeof SysData !== "undefined" ? SysData.diskPercent : 55) / 100.0)))
                                        radius: 6
                                        color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.sapphire : "#74c7ec"

                                        Behavior on height {
                                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰋊"
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                font.pixelSize: 11
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.sapphire : "#74c7ec"
                            }
                        }
                    }
                }

                // ======================================
                // CARD 6: MEDIA PLAYER (Row 0..1, Col 5)
                // ======================================
                Rectangle {
                    Layout.row: 0
                    Layout.column: 5
                    Layout.rowSpan: 2
                    Layout.preferredWidth: 215
                    Layout.fillHeight: true
                    radius: 16
                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.45) : Qt.alpha("#313244", 0.45)
                    border.width: 1
                    border.color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.35) : "#45475a"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        // Vinyl Cover Disc with Progress Ring
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 78
                            Layout.preferredHeight: 78

                            Shape {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.samples: 4

                                ShapePath {
                                    strokeWidth: 3
                                    strokeColor: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.6) : "#45475a"
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap

                                    PathAngleArc {
                                        centerX: 39
                                        centerY: 39
                                        radiusX: 36
                                        radiusY: 36
                                        startAngle: 0
                                        sweepAngle: 360
                                    }
                                }

                                ShapePath {
                                    strokeWidth: 3
                                    strokeColor: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap

                                    PathAngleArc {
                                        centerX: 39
                                        centerY: 39
                                        radiusX: 36
                                        radiusY: 36
                                        startAngle: -90
                                        sweepAngle: expandedRoot.progress * 360
                                    }
                                }
                            }

                            // Circular Vinyl Disc & Thumbnail
                            Item {
                                anchors.centerIn: parent
                                width: 66
                                height: 66

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.crust : "#11111b"
                                }

                                Rectangle {
                                    id: discMask
                                    anchors.fill: parent
                                    radius: width / 2
                                    visible: false
                                    layer.enabled: true
                                }

                                Image {
                                    id: discImg
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    source: (typeof MprisController !== "undefined" && MprisController.artUrl)
                                        ? MprisController.artUrl
                                        : ""
                                    visible: false
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: discImg
                                    maskEnabled: true
                                    maskSource: discMask
                                    visible: discImg.status === Image.Ready && discImg.source !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: discImg.status !== Image.Ready || discImg.source === ""
                                    text: "󰝚"
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                    font.pixelSize: 22
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                                }

                                // Center vinyl spindle hole
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.crust : "#11111b"
                                    border.width: 1.5
                                    border.color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                                    visible: discImg.status === Image.Ready && discImg.source !== ""
                                }

                                // Circular outer border ring
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.5) : "#45475a"
                                }
                            }
                        }

                        // Track Title & Artist
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: (typeof MprisController !== "undefined" && MprisController.trackTitle !== "")
                                    ? MprisController.trackTitle
                                    : "No Media Playing"
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                visible: text !== ""
                                text: (typeof MprisController !== "undefined" && MprisController.trackArtist !== "")
                                    ? MprisController.trackArtist
                                    : (expandedRoot.activePlayer ? (expandedRoot.activePlayer.identity || "") : "")
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                font.pixelSize: 10
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        // Playback Controls
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            // Previous
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: prevM.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                    font.pixelSize: 12
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4"
                                }

                                MouseArea {
                                    id: prevM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (expandedRoot.activePlayer) expandedRoot.activePlayer.previous()
                                }
                            }

                            // Play/Pause
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"

                                Text {
                                    anchors.centerIn: parent
                                    text: expandedRoot.isPlaying ? "󰏤" : "󰐊"
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                    font.pixelSize: 13
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.base : "#11111b"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (expandedRoot.activePlayer) expandedRoot.activePlayer.playPause()
                                }
                            }

                            // Next
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: nextM.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                    font.pixelSize: 12
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4"
                                }

                                MouseArea {
                                    id: nextM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (expandedRoot.activePlayer) expandedRoot.activePlayer.next()
                                }
                            }
                        }

                        // Bongo Cat GIF Animation
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            AnimatedImage {
                                id: bongoGif
                                anchors.centerIn: parent
                                width: Math.min(parent.width, 86)
                                height: Math.min(parent.height, 46)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                playing: expandedRoot.isPlaying
                                source: (typeof Caching !== "undefined" && Caching.serpantinumDir)
                                    ? ("file://" + Caching.serpantinumDir + "/assets/bongocat.gif")
                                    : ""
                            }
                        }
                    }
                }
            }

            // ------------------------------------------
            // TAB 1: FULL MEDIA VIEW
            // ------------------------------------------
            RowLayout {
                anchors.fill: parent
                spacing: 16
                visible: expandedRoot.currentTab === 1
                opacity: visible ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // Left: Circular Album Art & Vinyl Disc
                Item {
                    Layout.preferredWidth: 220
                    Layout.fillHeight: true

                    // Circular Disc Container centered in left column
                    Item {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 12, parent.height - 12, 210)
                        height: width

                        // Disc Background Base
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.6) : "#1e1e2e"
                        }

                        // Circular Mask
                        Rectangle {
                            id: fullMediaArtMask
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                            layer.enabled: true
                        }

                        // Album Art Image
                        Image {
                            id: fullMediaArtImg
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            source: (typeof MprisController !== "undefined" && MprisController.artUrl)
                                ? (MprisController.artUrl.startsWith("file://") || MprisController.artUrl.startsWith("http")
                                    ? MprisController.artUrl
                                    : "file://" + MprisController.artUrl)
                                : ""
                            visible: false
                        }

                        // Circular Masked Image
                        MultiEffect {
                            anchors.fill: parent
                            source: fullMediaArtImg
                            maskEnabled: true
                            maskSource: fullMediaArtMask
                            visible: fullMediaArtImg.status === Image.Ready && fullMediaArtImg.source !== ""
                        }

                        // Concentric Vinyl Grooves
                        Repeater {
                            model: [0.88, 0.74, 0.60]
                            delegate: Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * modelData
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: Qt.alpha("#ffffff", 0.08)
                                border.width: 1
                                visible: fullMediaArtImg.status === Image.Ready && fullMediaArtImg.source !== ""
                            }
                        }

                        // Fallback icon if no art
                        Text {
                            anchors.centerIn: parent
                            text: "󰝚"
                            font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                            font.pixelSize: 52
                            color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                            visible: fullMediaArtImg.status !== Image.Ready || fullMediaArtImg.source === ""
                        }

                        // Center Vinyl Spindle Hole
                        Rectangle {
                            anchors.centerIn: parent
                            width: 34
                            height: 34
                            radius: 17
                            color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.crust : "#11111b"
                            border.width: 2
                            border.color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                            visible: fullMediaArtImg.status === Image.Ready && fullMediaArtImg.source !== ""

                            Rectangle {
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                radius: 4
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.surface0 : "#313244"
                            }
                        }

                        // Circular Outer Border Ring
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: 2.5
                            border.color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                        }
                    }
                }

                // Right: Controls & Details
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            Layout.fillWidth: true
                            text: (typeof MprisController !== "undefined" && MprisController.trackTitle !== "")
                                ? MprisController.trackTitle
                                : "No Active Media"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (typeof MprisController !== "undefined" && MprisController.trackArtist !== "")
                                ? MprisController.trackArtist
                                : "Playback is idle"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 13
                            color: ThemeBackend.subtext0
                            elide: Text.ElideRight
                        }
                    }

                    // Seekbar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: expandedRoot.formatSeconds(expandedRoot.playerPosition)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 10
                            color: ThemeBackend.subtext0
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: ThemeBackend.surface0

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * expandedRoot.progress))
                                height: parent.height
                                radius: 3
                                color: ThemeBackend.mauve
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (expandedRoot.playerLength > 0 && expandedRoot.activePlayer) {
                                        expandedRoot.activePlayer.position = (mouse.x / width) * expandedRoot.playerLength;
                                    }
                                }
                            }
                        }

                        Text {
                            text: expandedRoot.formatSeconds(expandedRoot.playerLength)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 10
                            color: ThemeBackend.subtext0
                        }
                    }

                    // Playback Controls Row
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 24

                        Rectangle {
                            width: 36
                            height: 36
                            radius: 18
                            color: prevFullM.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: 18
                                color: ThemeBackend.text
                            }
                            MouseArea {
                                id: prevFullM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (expandedRoot.activePlayer) expandedRoot.activePlayer.previous()
                            }
                        }

                        Rectangle {
                            width: 44
                            height: 44
                            radius: 22
                            color: ThemeBackend.mauve
                            Text {
                                anchors.centerIn: parent
                                text: expandedRoot.isPlaying ? "󰏤" : "󰐊"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: 20
                                color: ThemeBackend.base
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (expandedRoot.activePlayer) expandedRoot.activePlayer.playPause()
                            }
                        }

                        Rectangle {
                            width: 36
                            height: 36
                            radius: 18
                            color: nextFullM.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: 18
                                color: ThemeBackend.text
                            }
                            MouseArea {
                                id: nextFullM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (expandedRoot.activePlayer) expandedRoot.activePlayer.next()
                            }
                        }
                    }

                    // Lyrics Container (Positioned directly below playback controls)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 110
                        radius: 14
                        color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.40) : "#1e1e2e"
                        border.width: 1
                        border.color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.30) : "#313244"
                        clip: true

                        // Synchronized interactive lyrics view
                        LyricsView {
                            id: notchLyricsView
                            anchors.fill: parent
                            anchors.margins: 8
                            alignment: "center"
                            sideMargin: 12
                            baseActiveFont: 13
                            lineHeight: 22
                            lineSpacing: 4
                            activeLineColor: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                            inactiveLineColor: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                            inactiveOpacity: 0.45
                            fontFamily: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : "sans-serif"
                            fontWeight: Font.Bold
                            centerRatio: 0.5
                            visible: typeof Lyrics !== "undefined" && Lyrics.hasLyrics
                        }

                        // Fallback state when lyrics are loading or unavailable
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            visible: typeof Lyrics === "undefined" || !Lyrics.hasLyrics

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: (typeof Lyrics !== "undefined" && Lyrics.loading) ? "󰔛" : (expandedRoot.hasPlayer ? "󰎈" : "󰝛")
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.iconFont : Qt.application.font.family
                                font.pixelSize: 22
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                                opacity: 0.7
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: (typeof Lyrics !== "undefined" && Lyrics.loading)
                                    ? "Loading lyrics..."
                                    : (expandedRoot.hasPlayer ? "No lyrics available for this track" : "No media playing")
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                font.pixelSize: 11
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                                opacity: 0.6
                            }
                        }
                    }
                }
            }

            // ------------------------------------------
            // TAB 2: PERFORMANCE DETAILED VIEW
            // ------------------------------------------
            GridLayout {
                anchors.fill: parent
                columns: 3
                rows: 2
                rowSpacing: 10
                columnSpacing: 10
                visible: expandedRoot.currentTab === 2
                opacity: visible ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // CPU Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.alpha(ThemeBackend.surface0, 0.45)
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Text { text: "󰍛"; font.family: ThemeBackend.iconFont; font.pixelSize: 16; color: ThemeBackend.peach }
                            Text { text: "CPU Usage"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: ThemeBackend.text }
                        }
                        Text {
                            text: (typeof SysData !== "undefined" ? SysData.cpu : 0) + "%"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            color: ThemeBackend.peach
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: ThemeBackend.surface1
                            Rectangle {
                                width: parent.width * ((typeof SysData !== "undefined" ? SysData.cpu : 0) / 100.0)
                                height: parent.height
                                radius: 3
                                color: ThemeBackend.peach
                            }
                        }
                    }
                }

                // RAM Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.alpha(ThemeBackend.surface0, 0.45)
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Text { text: "󰘚"; font.family: ThemeBackend.iconFont; font.pixelSize: 16; color: ThemeBackend.mauve }
                            Text { text: "Memory"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: ThemeBackend.text }
                        }
                        Text {
                            text: (typeof SysData !== "undefined" ? SysData.ramPercent : 0) + "%"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            color: ThemeBackend.mauve
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: ThemeBackend.surface1
                            Rectangle {
                                width: parent.width * ((typeof SysData !== "undefined" ? SysData.ramPercent : 0) / 100.0)
                                height: parent.height
                                radius: 3
                                color: ThemeBackend.mauve
                            }
                        }
                    }
                }

                // Storage Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.alpha(ThemeBackend.surface0, 0.45)
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Text { text: "󰋊"; font.family: ThemeBackend.iconFont; font.pixelSize: 16; color: ThemeBackend.sapphire }
                            Text { text: "Storage"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: ThemeBackend.text }
                        }
                        Text {
                            text: (typeof SysData !== "undefined" ? SysData.diskPercent : 0) + "%"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            color: ThemeBackend.sapphire
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: ThemeBackend.surface1
                            Rectangle {
                                width: parent.width * ((typeof SysData !== "undefined" ? SysData.diskPercent : 0) / 100.0)
                                height: parent.height
                                radius: 3
                                color: ThemeBackend.sapphire
                            }
                        }
                    }
                }

                // Network Rx/Tx
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.alpha(ThemeBackend.surface0, 0.45)
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Text { text: "󰖩"; font.family: ThemeBackend.iconFont; font.pixelSize: 16; color: ThemeBackend.green }
                            Text { text: "Network Traffic"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: ThemeBackend.text }
                        }
                        Text {
                            text: "↓ " + expandedRoot.formatSpeed(typeof SysData !== "undefined" ? SysData.netRx : 0)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 12
                            color: ThemeBackend.green
                        }
                        Text {
                            text: "↑ " + expandedRoot.formatSpeed(typeof SysData !== "undefined" ? SysData.netTx : 0)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 12
                            color: ThemeBackend.sapphire
                        }
                    }
                }

                // Temperature
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.alpha(ThemeBackend.surface0, 0.45)
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Text { text: "󰔏"; font.family: ThemeBackend.iconFont; font.pixelSize: 16; color: ThemeBackend.red }
                            Text { text: "Temperature"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: ThemeBackend.text }
                        }
                        Text {
                            text: (typeof SysData !== "undefined" ? SysData.temp : 45) + "°C"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            color: ThemeBackend.red
                        }
                    }
                }

                // Battery / Power
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.alpha(ThemeBackend.surface0, 0.45)
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Text { text: "󰂄"; font.family: ThemeBackend.iconFont; font.pixelSize: 16; color: ThemeBackend.teal }
                            Text { text: "Power Source"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: ThemeBackend.text }
                        }
                        Text {
                            text: (typeof UPower !== "undefined" && UPower.displayDevice && UPower.displayDevice.ready)
                                ? (Math.round(UPower.displayDevice.percentage * 100) + "%")
                                : "AC Power"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: ThemeBackend.teal
                        }
                    }
                }
            }

            // ------------------------------------------
            // TAB 3: SYSTEM & CONTROLS
            // ------------------------------------------
            RowLayout {
                anchors.fill: parent
                spacing: 16
                visible: expandedRoot.currentTab === 3
                opacity: visible ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // Left: System Info
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.alpha(ThemeBackend.surface0, 0.45)
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        Text {
                            text: "SYSTEM INFORMATION"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: ThemeBackend.overlay1
                        }

                        Text {
                            text: "OS: " + expandedRoot.distroName
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 12
                            color: ThemeBackend.text
                        }

                        Text {
                            text: "Compositor: Niri (Wayland)"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 12
                            color: ThemeBackend.text
                        }

                        Text {
                            text: "Uptime: " + expandedRoot.uptimeStr
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 12
                            color: ThemeBackend.text
                        }
                    }
                }

                // Right: Session Action Buttons
                Rectangle {
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.alpha(ThemeBackend.surface0, 0.45)
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        Text {
                            text: "QUICK ACTIONS"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: ThemeBackend.overlay1
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 8
                            color: lockM.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "󰌾"; font.family: ThemeBackend.iconFont; font.pixelSize: 13; color: ThemeBackend.mauve }
                                Text { text: "Lock Screen"; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; color: ThemeBackend.text }
                            }

                            MouseArea {
                                id: lockM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle lock"]);
                                    windowRoot.collapse();
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 8
                            color: reloadM.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "󰑐"; font.family: ThemeBackend.iconFont; font.pixelSize: 13; color: ThemeBackend.peach }
                                Text { text: "Reload Shell"; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; color: ThemeBackend.text }
                            }

                            MouseArea {
                                id: reloadM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/reload.sh"]);
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 8
                            color: logoutM.containsMouse ? Qt.alpha(ThemeBackend.red, 0.3) : ThemeBackend.surface0

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "󰍃"; font.family: ThemeBackend.iconFont; font.pixelSize: 13; color: ThemeBackend.red }
                                Text { text: "Power Menu"; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; color: ThemeBackend.red }
                            }

                            MouseArea {
                                id: logoutM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle session"]);
                                    windowRoot.collapse();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
