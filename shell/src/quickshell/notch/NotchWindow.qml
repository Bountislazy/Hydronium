import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root

    required property var screen
    screen: root.screen

    WlrLayershell.namespace: "notch"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    focusable: root.expanded
    WlrLayershell.keyboardFocus: root.expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Math.max(root.expandedHeight + 80, 240)

    mask: Region {
        Region {
            item: (root.isRevealed || notchContainer.y > (-notchContainer.height + 2)) ? notchContainer : null
        }
        Region {
            item: edgeTrigger
        }
    }

    // ==========================================
    // CONFIGURATION
    // ==========================================
    property var rawNotchSettings: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.notch)
        ? Config.rawSettings.notch
        : ({})

    property bool notchEnabled: rawNotchSettings.enabled !== undefined ? Boolean(rawNotchSettings.enabled) : true
    property bool autoHide: rawNotchSettings.autoHide !== undefined
        ? Boolean(rawNotchSettings.autoHide)
        : (rawNotchSettings.autohide !== undefined ? Boolean(rawNotchSettings.autohide) : true)
    property bool autoHideKeepMusic: rawNotchSettings.autoHideKeepMusic !== undefined ? Boolean(rawNotchSettings.autoHideKeepMusic) : false
    property real collapsedWidth: rawNotchSettings.collapsedWidth !== undefined ? Number(rawNotchSettings.collapsedWidth) : 200
    property real collapsedMusicWidth: rawNotchSettings.collapsedMusicWidth !== undefined ? Number(rawNotchSettings.collapsedMusicWidth) : 290
    property real collapsedHeight: rawNotchSettings.collapsedHeight !== undefined ? Number(rawNotchSettings.collapsedHeight) : 34
    property real expandedWidth: rawNotchSettings.expandedWidth !== undefined ? Number(rawNotchSettings.expandedWidth) : 820
    property real expandedHeight: rawNotchSettings.expandedHeight !== undefined ? Number(rawNotchSettings.expandedHeight) : 400
    property real topOffset: rawNotchSettings.topOffset !== undefined ? Number(rawNotchSettings.topOffset) : 0
    property string triggerMode: rawNotchSettings.triggerMode !== undefined ? rawNotchSettings.triggerMode : "hover"
    property int unhoverDelay: rawNotchSettings.unhoverDelay !== undefined ? Number(rawNotchSettings.unhoverDelay) : 300
    property bool showCpu: rawNotchSettings.showCpu !== undefined ? Boolean(rawNotchSettings.showCpu) : true
    property bool showRam: rawNotchSettings.showRam !== undefined ? Boolean(rawNotchSettings.showRam) : true
    property bool showTemp: rawNotchSettings.showTemp !== undefined ? Boolean(rawNotchSettings.showTemp) : true
    property bool showBattery: rawNotchSettings.showBattery !== undefined ? Boolean(rawNotchSettings.showBattery) : true
    property bool showNetwork: rawNotchSettings.showNetwork !== undefined ? Boolean(rawNotchSettings.showNetwork) : true
    property bool hideBarCenter: rawNotchSettings.hideBarCenter !== undefined ? Boolean(rawNotchSettings.hideBarCenter) : false

    visible: root.notchEnabled

    property bool isRevealed: {
        if (!root.autoHide) return true;
        if (root.expanded) return true;
        if (root.autoHideKeepMusic && root.isMusicPlaying) return true;
        if (typeof notchHover !== "undefined" && notchHover.hovered) return true;
        if (typeof notchMouseArea !== "undefined" && notchMouseArea.containsMouse) return true;
        if (typeof edgeHover !== "undefined" && edgeHover.hovered) return true;
        if (typeof edgeMouseArea !== "undefined" && edgeMouseArea.containsMouse) return true;
        if (typeof unhoverTimer !== "undefined" && unhoverTimer.running) return true;
        return false;
    }

    // ==========================================
    // SINGLE SOURCE OF TRUTH: STATE & ANIMATIONS
    // ==========================================
    property bool expanded: false

    function expand() {
        unhoverTimer.stop();
        root.expanded = true;
    }

    function collapse() {
        root.expanded = false;
    }

    function toggle() {
        if (root.expanded) {
            collapse();
        } else {
            expand();
        }
    }

    Timer {
        id: expandTimer
        interval: 140
        onTriggered: {
            if ((notchHover.hovered || notchMouseArea.containsMouse || edgeHover.hovered || edgeMouseArea.containsMouse) && root.triggerMode === "hover") {
                root.expand();
            }
        }
    }

    Timer {
        id: unhoverTimer
        interval: root.unhoverDelay
        onTriggered: {
            if (!notchHover.hovered && !notchMouseArea.containsMouse && !edgeHover.hovered && !edgeMouseArea.containsMouse) {
                root.collapse();
            }
        }
    }

    // Polling lifecycle: start polling only when expanded, stop when collapsed
    onExpandedChanged: {
        if (root.expanded) {
            if (typeof SysData !== "undefined") SysData.subscribe();
        } else {
            if (typeof SysData !== "undefined") SysData.unsubscribe();
        }
    }

    Component.onDestruction: {
        if (root.expanded && typeof SysData !== "undefined") {
            SysData.unsubscribe();
        }
    }

    readonly property bool isMusicPlaying: (typeof MprisController !== "undefined") && MprisController.isPlaying
    // ==========================================
    // CAELESTIA SIGNATURE ANIMATION BEZIERS
    // Extracted from caelestia-main/hypr/hyprland/animations.lua:
    // emphasizedDecel: points = { { 0.05, 0.7 }, { 0.1, 1 } }
    // emphasizedAccel: points = { { 0.3, 0 }, { 0.8, 0.15 } }
    // ==========================================
    readonly property var caelestiaDecel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var caelestiaAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]

    readonly property real targetConcaveRadius: root.expanded ? 14 : 12
    readonly property real targetConvexRadius: root.expanded ? 22 : 16
    readonly property real concaveRadius: currentRTop
    readonly property real convexRadius: currentRBottom

    readonly property int animDurationExpand: 500
    readonly property int animDurationCollapse: 360
    readonly property int animDuration: root.expanded ? animDurationExpand : animDurationCollapse

    readonly property real targetW: root.expanded
        ? root.expandedWidth
        : (root.isMusicPlaying ? root.collapsedMusicWidth : root.collapsedWidth)
    readonly property real targetH: root.expanded
        ? root.expandedHeight
        : root.collapsedHeight

    property real currentW: targetW
    property real currentH: targetH
    property real currentRTop: targetConcaveRadius
    property real currentRBottom: targetConvexRadius

    Behavior on currentW {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? root.caelestiaDecel : root.caelestiaAccel
        }
    }

    Behavior on currentH {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? root.caelestiaDecel : root.caelestiaAccel
        }
    }

    Behavior on currentRTop {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? root.caelestiaDecel : root.caelestiaAccel
        }
    }

    Behavior on currentRBottom {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? root.caelestiaDecel : root.caelestiaAccel
        }
    }

    // Escape shortcut to close notch
    Shortcut {
        sequence: "Escape"
        enabled: root.expanded
        onActivated: root.collapse()
    }

    // Multi-monitor IPC event listener
    Connections {
        target: (typeof NotchController !== "undefined") ? NotchController : null
        function onToggleRequested(screenName) {
            if (!screenName || screenName === (root.screen ? root.screen.name : "") || screenName === "all") {
                root.toggle();
            }
        }
        function onExpandRequested(screenName) {
            if (!screenName || screenName === (root.screen ? root.screen.name : "") || screenName === "all") {
                root.expand();
            }
        }
        function onCollapseRequested(screenName) {
            if (!screenName || screenName === (root.screen ? root.screen.name : "") || screenName === "all") {
                root.collapse();
            }
        }
    }

    // ==========================================
    // EDGE TRIGGER (HOTSPOT FOR AUTO-HIDE)
    // ==========================================
    Item {
        id: edgeTrigger
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(root.currentW, root.expandedWidth, 420)
        height: 6
        visible: root.autoHide && !root.expanded

        HoverHandler {
            id: edgeHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (hovered) {
                    unhoverTimer.stop();
                    if (root.triggerMode === "hover") {
                        expandTimer.restart();
                    }
                } else {
                    expandTimer.stop();
                    if (!notchHover.hovered && !notchMouseArea.containsMouse && !edgeMouseArea.containsMouse) {
                        unhoverTimer.restart();
                    }
                }
            }
        }

        MouseArea {
            id: edgeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                unhoverTimer.stop();
            }
            onExited: {
                if (!notchHover.hovered && !notchMouseArea.containsMouse && !edgeHover.hovered) {
                    unhoverTimer.restart();
                }
            }
            onClicked: {
                unhoverTimer.stop();
                if (root.triggerMode === "click") {
                    root.toggle();
                } else {
                    root.expand();
                }
            }
        }
    }

    // ==========================================
    // NOTCH CONTAINER & SHAPE
    // ==========================================
    Item {
        id: notchContainer
        width: Math.round(root.currentW)
        height: Math.round(root.currentH)
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.autoHide
            ? (root.isRevealed ? root.topOffset : (root.topOffset - root.currentH))
            : root.topOffset
        opacity: root.autoHide
            ? (root.isRevealed ? 1.0 : 0.0)
            : 1.0
        visible: !root.autoHide || root.isRevealed || y > (-root.currentH + 1)

        Behavior on y {
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.isRevealed ? root.caelestiaDecel : root.caelestiaAccel
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Math.round(root.animDuration * 0.7)
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: notchHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (hovered) {
                    unhoverTimer.stop();
                    if (root.triggerMode === "hover") {
                        expandTimer.restart();
                    }
                } else {
                    expandTimer.stop();
                    if (!edgeHover.hovered && !edgeMouseArea.containsMouse && !notchMouseArea.containsMouse) {
                        unhoverTimer.restart();
                    }
                }
            }
        }

        MouseArea {
            id: notchMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.expanded ? Qt.ArrowCursor : Qt.PointingHandCursor

            onEntered: {
                unhoverTimer.stop();
                if (root.triggerMode === "hover") {
                    expandTimer.restart();
                }
            }

            onExited: {
                expandTimer.stop();
                if (!edgeHover.hovered && !edgeMouseArea.containsMouse && !notchHover.hovered) {
                    unhoverTimer.restart();
                }
            }

            onClicked: {
                expandTimer.stop();
                if (root.triggerMode === "click") {
                    root.toggle();
                } else if (!root.expanded) {
                    root.expand();
                }
            }
        }

        // Notch macOS-style Shape:
        // Concave top corners merging flush into screen bezel, convex bottom corners
        Shape {
            id: notchShape
            anchors.fill: parent
            layer.enabled: true
            preferredRendererType: Shape.GeometryRenderer
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowVerticalOffset: 4
                shadowHorizontalOffset: 0
                shadowBlur: 0.5
                shadowOpacity: 0.55
            }

            property real w: notchContainer.width
            property real h: notchContainer.height
            property real rTop: Math.max(4, Math.min(root.concaveRadius, h / 2, w / 4))
            property real rBottom: Math.max(4, Math.min(root.convexRadius, h / 2, w / 4))

            ShapePath {
                strokeWidth: 1
                strokeColor: Qt.alpha(ThemeBackend.surface1, 0.45)
                fillColor: ThemeBackend.base

                startX: 0
                startY: 0

                // 1. Top-left concave flare
                PathQuad {
                    x: notchShape.rTop
                    y: notchShape.rTop
                    controlX: notchShape.rTop
                    controlY: 0
                }

                // 2. Left vertical edge
                PathLine {
                    x: notchShape.rTop
                    y: notchShape.h - notchShape.rBottom
                }

                // 3. Bottom-left convex round
                PathQuad {
                    x: notchShape.rTop + notchShape.rBottom
                    y: notchShape.h
                    controlX: notchShape.rTop
                    controlY: notchShape.h
                }

                // 4. Bottom horizontal edge
                PathLine {
                    x: notchShape.w - notchShape.rTop - notchShape.rBottom
                    y: notchShape.h
                }

                // 5. Bottom-right convex round
                PathQuad {
                    x: notchShape.w - notchShape.rTop
                    y: notchShape.h - notchShape.rBottom
                    controlX: notchShape.w - notchShape.rTop
                    controlY: notchShape.h
                }

                // 6. Right vertical edge
                PathLine {
                    x: notchShape.w - notchShape.rTop
                    y: notchShape.rTop
                }

                // 7. Top-right concave flare
                PathQuad {
                    x: notchShape.w
                    y: 0
                    controlX: notchShape.w - notchShape.rTop
                    controlY: 0
                }

                // 8. Top horizontal edge (flush with top screen edge)
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }

        // ==========================================
        // CONTENT CLIPPING & TOP-TO-BOTTOM FLUID MORPH
        // ==========================================
        Item {
            id: contentClipper
            anchors.fill: parent
            clip: true

            // Collapsed View (Pill header: Clock, Mini visualizer, Track marquee)
            Item {
                id: collapsedWrapper
                anchors.fill: parent
                opacity: root.expanded ? 0.0 : 1.0
                y: root.expanded ? -22 : 0
                scale: root.expanded ? 0.94 : 1.0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.expanded ? 180 : 280
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.expanded ? root.caelestiaDecel : root.caelestiaAccel
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: root.expanded ? 240 : 340
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.expanded ? root.caelestiaDecel : root.caelestiaAccel
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: root.expanded ? 200 : 300
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.expanded ? root.caelestiaDecel : root.caelestiaAccel
                    }
                }

                NotchCollapsedView {
                    windowRoot: root
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Expanded View (Full Caelestia Dashboard: Tabs, Grid, Media, Lyrics, Meters)
            Item {
                id: expandedWrapper
                anchors.fill: parent
                opacity: root.expanded ? 1.0 : 0.0
                y: root.expanded ? 0 : -55
                scale: root.expanded ? 1.0 : 0.97
                transformOrigin: Item.Top
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.expanded ? 320 : 180
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.expanded ? root.caelestiaDecel : root.caelestiaAccel
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: root.animDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.expanded ? root.caelestiaDecel : root.caelestiaAccel
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: root.animDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.expanded ? root.caelestiaDecel : root.caelestiaAccel
                    }
                }

                NotchExpandedView {
                    id: expandedViewContent
                    windowRoot: root
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
