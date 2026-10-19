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
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        Region {
            item: (root.isRevealed || notchContainer.y > (-notchContainer.height + 2)) ? notchContainer : null
        }
        Region {
            item: edgeTrigger
        }
        Region {
            item: (root.frameEnabled && !root.hasFullscreen) ? topFrame : null
        }
        Region {
            item: (root.frameEnabled && !root.hasFullscreen) ? leftFrame : null
        }
        Region {
            item: (root.frameEnabled && !root.hasFullscreen) ? rightFrame : null
        }
        Region {
            item: (root.frameEnabled && !root.hasFullscreen && bottomFrame.visible) ? bottomFrame : null
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

    // ==========================================
    // CAELESTIA SCREEN FRAME (BORDER) CONFIGURATION
    // ==========================================
    property bool frameEnabled: rawNotchSettings.frameEnabled !== undefined ? Boolean(rawNotchSettings.frameEnabled) : true
    property real frameThickness: rawNotchSettings.frameThickness !== undefined ? Number(rawNotchSettings.frameThickness) : 10
    property real frameRounding: rawNotchSettings.frameRounding !== undefined ? Number(rawNotchSettings.frameRounding) : 12
    readonly property color frameColor: Qt.alpha(ThemeBackend.base, (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.opacity !== undefined) ? (Config.rawSettings.bar.opacity / 100.0) : ThemeBackend.elementOpacity)
    readonly property real barHeight: {
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height !== undefined) {
            return Number(Config.rawSettings.bar.height);
        }
        return 46;
    }
    readonly property bool hasFullscreen: {
        if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel) {
            return Boolean(ToplevelManager.activeToplevel.fullscreen);
        }
        return false;
    }

    readonly property bool isMusicPlaying: (typeof MprisController !== "undefined") && MprisController.isPlaying
    // ==========================================
    // CAELESTIA SIGNATURE FLUID MORPH CURVES
    // Fast, smooth, with subtle organic spring bounce
    // ==========================================
    readonly property var caelestiaMorphExpand: [0.38, 1.15, 0.22, 1.0, 1.0, 1.0]
    readonly property var caelestiaSmoothExpand: [0.05, 0.0, 0.133333, 0.06, 0.166667, 0.4, 0.208333, 0.82, 0.25, 1.0, 1.0, 1.0]
    readonly property var caelestiaAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]

    readonly property real targetConcaveRadius: root.expanded ? 14 : 12
    readonly property real targetConvexRadius: root.expanded ? 24 : 17
    readonly property real concaveRadius: currentRTop
    readonly property real convexRadius: currentRBottom

    readonly property int animDurationExpand: 420
    readonly property int animDurationCollapse: 320
    readonly property int animDuration: root.expanded ? animDurationExpand : animDurationCollapse

    readonly property real targetW: root.expandedWidth
    readonly property real targetH: root.expanded
        ? root.expandedHeight
        : root.collapsedHeight

    property real currentW: targetW
    property real currentH: targetH
    property real currentRTop: targetConcaveRadius
    property real currentRBottom: targetConvexRadius

    Behavior on currentH {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? root.caelestiaMorphExpand : root.caelestiaAccel
        }
    }

    Behavior on currentRTop {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? root.caelestiaMorphExpand : root.caelestiaAccel
        }
    }

    Behavior on currentRBottom {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? root.caelestiaMorphExpand : root.caelestiaAccel
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
    // CAELESTIA UNIFIED SCREEN FRAME
    // ==========================================
    Item {
        id: screenFrameContainer
        anchors.fill: parent
        visible: root.frameEnabled
        opacity: root.hasFullscreen ? 0.0 : 1.0
        z: 1

        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 32
            shadowBlur: 0.8
            shadowOpacity: 0.85
            shadowColor: "#000000"
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        // 1. Top border (Atas: 0, 0, 1, 1)
        Rectangle {
            id: topFrame
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.frameThickness
            color: root.frameColor
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: root.frameRounding
            bottomRightRadius: root.frameRounding
        }

        // 2. Left border (Kiri: 0, 1, 0, 1)
        Rectangle {
            id: leftFrame
            anchors.top: topFrame.bottom
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.barHeight
            anchors.left: parent.left
            width: root.frameThickness
            color: root.frameColor
            topLeftRadius: 0
            topRightRadius: root.frameRounding
            bottomLeftRadius: 0
            bottomRightRadius: root.frameRounding
        }

        // 3. Right border (Kanan: 1, 0, 1, 0)
        Rectangle {
            id: rightFrame
            anchors.top: topFrame.bottom
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.barHeight
            anchors.right: parent.right
            width: root.frameThickness
            color: root.frameColor
            topLeftRadius: root.frameRounding
            topRightRadius: 0
            bottomLeftRadius: root.frameRounding
            bottomRightRadius: 0
        }

        // 4. Bottom border (Bawah: 1, 1, 0, 0 - active if bar is not present)
        Rectangle {
            id: bottomFrame
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.frameThickness
            color: root.frameColor
            visible: root.barHeight <= 0
            topLeftRadius: root.frameRounding
            topRightRadius: root.frameRounding
            bottomLeftRadius: 0
            bottomRightRadius: 0
        }
    }

    // ==========================================
    // NOTCH CONTAINER & SHAPE
    // ==========================================
    Item {
        id: notchContainer
        z: 2
        width: Math.round(root.currentW)
        height: Math.round(root.currentH)
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.autoHide
            ? (root.isRevealed ? root.topOffset : (root.topOffset - root.currentH))
            : root.topOffset
        opacity: 1.0
        visible: !root.autoHide || root.isRevealed || y > (-root.currentH + 1)

        Behavior on y {
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.isRevealed ? root.caelestiaSmoothExpand : root.caelestiaAccel
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
                opacity: 1.0
                y: root.expanded ? -root.collapsedHeight : 0
                visible: !root.expanded || y > -root.collapsedHeight

                Behavior on y {
                    NumberAnimation {
                        duration: root.expanded ? 200 : 300
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.expanded ? root.caelestiaAccel : root.caelestiaMorphExpand
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
                opacity: 1.0
                y: root.expanded ? 0 : -root.collapsedHeight
                visible: root.expanded || currentH > (root.collapsedHeight + 2)

                Behavior on y {
                    NumberAnimation {
                        duration: root.animDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.expanded ? root.caelestiaMorphExpand : root.caelestiaAccel
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
