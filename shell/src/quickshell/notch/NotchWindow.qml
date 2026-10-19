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
    WlrLayershell.layer: WlrLayer.Top
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
            item: (root.frameEnabled && !root.hasFullscreen) ? topMaskStrip : null
        }
        Region {
            item: (root.frameEnabled && !root.hasFullscreen) ? leftMaskStrip : null
        }
        Region {
            item: (root.frameEnabled && !root.hasFullscreen) ? rightMaskStrip : null
        }
        Region {
            item: (root.frameEnabled && !root.hasFullscreen && bottomMaskStrip.visible) ? bottomMaskStrip : null
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
    property real frameRounding: rawNotchSettings.frameRounding !== undefined ? Number(rawNotchSettings.frameRounding) : (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius ? ThemeBackend.borderRadius : 12)
    readonly property color frameColor: Qt.alpha(ThemeBackend.base, (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.opacity !== undefined) ? (Config.rawSettings.bar.opacity / 100.0) : 1.0)

    readonly property real barHeight: {
        if (typeof NotchController !== "undefined" && NotchController.barHeight > 0) {
            return NotchController.barHeight;
        }
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height !== undefined) {
            return Number(Config.rawSettings.bar.height);
        }
        return 40;
    }
    readonly property string barPosition: (typeof NotchController !== "undefined") ? NotchController.barPosition : "bottom"
    readonly property bool hasBottomBar: barPosition === "bottom" && barHeight > 0
    property real animatedBarOffset: (typeof NotchController !== "undefined") ? NotchController.barHideOffset : 0
    Behavior on animatedBarOffset {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }
    readonly property real effectiveBarHeight: hasBottomBar ? Math.max(0, barHeight - animatedBarOffset) : 0
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
    readonly property var caelestiaMorphExpand: [0.38, 1.22, 0.22, 1.0, 1.0, 1.0]
    readonly property var caelestiaDropBounce: [0.38, 1.18, 0.22, 1.0, 1.0, 1.0]
    readonly property var caelestiaSmoothExpand: [0.05, 0.0, 0.133333, 0.06, 0.166667, 0.4, 0.208333, 0.82, 0.25, 1.0, 1.0, 1.0]
    readonly property var caelestiaAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]

    readonly property real targetConcaveRadius: root.expanded ? 14 : 12
    readonly property real targetConvexRadius: root.expanded ? 24 : 17
    readonly property real concaveRadius: currentRTop
    readonly property real convexRadius: currentRBottom

    readonly property int animDurationExpand: 440
    readonly property int animDurationCollapse: 300
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
    // FRAME MASK HELPER (Interactive input regions)
    // ==========================================
    Item {
        id: frameMaskHelper
        anchors.fill: parent
        visible: false

        Item {
            id: topMaskStrip
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.frameThickness
        }

        Item {
            id: leftMaskStrip
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.effectiveBarHeight
            anchors.left: parent.left
            width: root.frameThickness
        }

        Item {
            id: rightMaskStrip
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.effectiveBarHeight
            anchors.right: parent.right
            width: root.frameThickness
        }

        Item {
            id: bottomMaskStrip
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.frameThickness
            visible: root.effectiveBarHeight <= 0
        }
    }

    // ==========================================
    // CAELESTIA UNIFIED SCREEN FRAME + NOTCH SHAPE
    // Single continuous geometric canvas
    // ==========================================
    Shape {
        id: unifiedFrameShape
        anchors.fill: parent
        z: 1
        visible: root.frameEnabled
        opacity: root.hasFullscreen ? 0.0 : 1.0

        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        layer.enabled: true
        preferredRendererType: Shape.GeometryRenderer
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 24
            shadowBlur: 0.65
            shadowOpacity: 0.70
            shadowColor: "#000000"
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        readonly property real w: root.width
        readonly property real h: root.height
        readonly property real t: root.frameThickness
        readonly property real r: Math.max(8, root.frameRounding)
        readonly property bool hasBar: root.hasBottomBar
        readonly property real barH: root.effectiveBarHeight
        readonly property real bottomOuterY: hasBar ? (h - barH) : h
        readonly property real bottomInnerY: hasBar ? (h - barH) : (h - t)

        readonly property real notchW: Math.round(root.currentW)
        readonly property real notchLeft: Math.round((w - notchW) / 2)
        readonly property real notchRight: notchLeft + notchW
        readonly property real notchBottom: Math.max(t, notchContainer.y + notchContainer.height)
        readonly property real dropdownH: Math.max(0, notchBottom - t)

        readonly property real effRTop: Math.min(root.concaveRadius, dropdownH * 0.4)
        readonly property real effRBottom: Math.min(root.convexRadius, dropdownH * 0.6)

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: root.frameColor

            // 1. Top outer edge (left to right)
            startX: 0
            startY: 0
            PathLine { x: unifiedFrameShape.w; y: 0 }

            // 2. Right outer edge (top to bottom bar)
            PathLine { x: unifiedFrameShape.w; y: unifiedFrameShape.bottomOuterY }

            // 3. Bottom-right concave fillet (scoops corner into bottom bar)
            PathLine { x: unifiedFrameShape.w - unifiedFrameShape.t - unifiedFrameShape.r; y: unifiedFrameShape.bottomInnerY }
            PathQuad {
                x: unifiedFrameShape.w - unifiedFrameShape.t
                y: unifiedFrameShape.bottomInnerY - unifiedFrameShape.r
                controlX: unifiedFrameShape.w - unifiedFrameShape.t
                controlY: unifiedFrameShape.bottomInnerY
            }

            // 4. Right border inner edge (bottom to top)
            PathLine { x: unifiedFrameShape.w - unifiedFrameShape.t; y: unifiedFrameShape.t + unifiedFrameShape.r }

            // 5. Top-right concave fillet (scoops corner between top and right borders)
            PathQuad {
                x: unifiedFrameShape.w - unifiedFrameShape.t - unifiedFrameShape.r
                y: unifiedFrameShape.t
                controlX: unifiedFrameShape.w - unifiedFrameShape.t
                controlY: unifiedFrameShape.t
            }

            // 6. Top border edge to right side of notch
            PathLine { x: unifiedFrameShape.notchRight; y: unifiedFrameShape.t }

            // 7. Notch right concave flare
            PathQuad {
                x: unifiedFrameShape.notchRight - unifiedFrameShape.effRTop
                y: unifiedFrameShape.t + unifiedFrameShape.effRTop
                controlX: unifiedFrameShape.notchRight - unifiedFrameShape.effRTop
                controlY: unifiedFrameShape.t
            }

            // 8. Notch right vertical edge
            PathLine {
                x: unifiedFrameShape.notchRight - unifiedFrameShape.effRTop
                y: unifiedFrameShape.notchBottom - unifiedFrameShape.effRBottom
            }

            // 9. Notch bottom-right convex corner
            PathQuad {
                x: unifiedFrameShape.notchRight - unifiedFrameShape.effRTop - unifiedFrameShape.effRBottom
                y: unifiedFrameShape.notchBottom
                controlX: unifiedFrameShape.notchRight - unifiedFrameShape.effRTop
                controlY: unifiedFrameShape.notchBottom
            }

            // 10. Notch bottom edge
            PathLine {
                x: unifiedFrameShape.notchLeft + unifiedFrameShape.effRTop + unifiedFrameShape.effRBottom
                y: unifiedFrameShape.notchBottom
            }

            // 11. Notch bottom-left convex corner
            PathQuad {
                x: unifiedFrameShape.notchLeft + unifiedFrameShape.effRTop
                y: unifiedFrameShape.notchBottom - unifiedFrameShape.effRBottom
                controlX: unifiedFrameShape.notchLeft + unifiedFrameShape.effRTop
                controlY: unifiedFrameShape.notchBottom
            }

            // 12. Notch left vertical edge
            PathLine {
                x: unifiedFrameShape.notchLeft + unifiedFrameShape.effRTop
                y: unifiedFrameShape.t + unifiedFrameShape.effRTop
            }

            // 13. Notch left concave flare
            PathQuad {
                x: unifiedFrameShape.notchLeft
                y: unifiedFrameShape.t
                controlX: unifiedFrameShape.notchLeft + unifiedFrameShape.effRTop
                controlY: unifiedFrameShape.t
            }

            // 14. Top border edge to top-left corner
            PathLine { x: unifiedFrameShape.t + unifiedFrameShape.r; y: unifiedFrameShape.t }

            // 15. Top-left concave fillet (scoops corner between top and left borders)
            PathQuad {
                x: unifiedFrameShape.t
                y: unifiedFrameShape.t + unifiedFrameShape.r
                controlX: unifiedFrameShape.t
                controlY: unifiedFrameShape.t
            }

            // 16. Left border inner edge (top to bottom)
            PathLine { x: unifiedFrameShape.t; y: unifiedFrameShape.bottomInnerY - unifiedFrameShape.r }

            // 17. Bottom-left concave fillet (scoops corner into bottom bar)
            PathQuad {
                x: unifiedFrameShape.t + unifiedFrameShape.r
                y: unifiedFrameShape.bottomInnerY
                controlX: unifiedFrameShape.t
                controlY: unifiedFrameShape.bottomInnerY
            }

            // 18. Bottom edge of left border
            PathLine { x: 0; y: unifiedFrameShape.bottomOuterY }

            // 19. Left outer edge back to top-left
            PathLine { x: 0; y: 0 }
        }
    }

    // ==========================================
    // NOTCH CONTAINER (Content Clipper & Mouse Interaction)
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
                duration: root.isRevealed ? 420 : 280
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.isRevealed ? root.caelestiaDropBounce : root.caelestiaAccel
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
