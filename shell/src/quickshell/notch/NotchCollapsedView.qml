import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: collapsedRoot

    required property var windowRoot

    readonly property bool isPlaying: (typeof MprisController !== "undefined") && MprisController.isPlaying
    readonly property string trackTitle: (typeof MprisController !== "undefined" && MprisController.trackTitle) ? MprisController.trackTitle : ""
    readonly property string timeString: (typeof DateTime !== "undefined" && DateTime.timeShort && DateTime.timeShort !== "")
        ? DateTime.timeShort
        : Qt.formatDateTime(new Date(), "HH:mm")

    implicitWidth: windowRoot ? (windowRoot.expandedWidth - (windowRoot.concaveRadius + 8) * 2) : 780
    implicitHeight: windowRoot ? windowRoot.collapsedHeight : 34
    width: implicitWidth
    height: implicitHeight

    // State A: Idle (No music playing) - Clean centered clock
    Item {
        id: idleView
        anchors.fill: parent
        opacity: (!collapsedRoot.isPlaying) ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: collapsedRoot.timeString
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // State B: Music Playing - Mini visualizer + Marquee Title + Clock
    RowLayout {
        id: playingView
        anchors.fill: parent
        spacing: 8
        opacity: collapsedRoot.isPlaying ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        // Mini visualizer wave bars
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Repeater {
                model: [0.65, 1.0, 0.75]
                delegate: Rectangle {
                    required property real modelData
                    required property int index

                    width: 2.5
                    height: 10 * modelData
                    radius: 1.25
                    color: ThemeBackend.green
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on height {
                        running: windowRoot.visible && !windowRoot.expanded && collapsedRoot.isPlaying
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 3
                            to: 11 * modelData
                            duration: 320 + index * 90
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            from: 11 * modelData
                            to: 3
                            duration: 320 + index * 90
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }

        // Marquee Track Title
        Item {
            id: marqueeClip
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Text {
                id: marqueeText
                text: collapsedRoot.trackTitle
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter

                readonly property real overflow: Math.max(0, width - marqueeClip.width)
                readonly property bool needsScroll: overflow > 2

                x: 0

                SequentialAnimation {
                    running: windowRoot.visible && !windowRoot.expanded && collapsedRoot.isPlaying && marqueeText.needsScroll
                    loops: Animation.Infinite

                    PauseAnimation { duration: 1800 }
                    NumberAnimation {
                        target: marqueeText
                        property: "x"
                        from: 0
                        to: -marqueeText.overflow
                        duration: Math.max(1200, marqueeText.overflow * 35)
                        easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 1800 }
                    NumberAnimation {
                        target: marqueeText
                        property: "x"
                        from: -marqueeText.overflow
                        to: 0
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                }

                onNeedsScrollChanged: {
                    if (!needsScroll) x = 0;
                }
            }
        }

        // Clock on the right
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: collapsedRoot.timeString
            color: Qt.alpha(ThemeBackend.text, 0.85)
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }
}
