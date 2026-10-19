import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../reusables"
import "../reusables/buttons"
import "../singletons/widgetcontrols"
import "../"

PanelWindow {
    id: focusCardWindow

    screen: FocusCardController.screen || (typeof Quickshell !== "undefined" && Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    WlrLayershell.namespace: "focuscard"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    readonly property bool isVisible: FocusCardController.isVisible
    readonly property real targetX: FocusCardController.targetX
    readonly property real targetY: FocusCardController.targetY
    readonly property bool alignRight: FocusCardController.alignRight
    readonly property bool alignBottom: FocusCardController.alignBottom
    readonly property bool isSideBar: FocusCardController.isSideBar

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            FocusCardController.hide();
            focusCardWindow.configRevision++;
        }
    }

    property string barStyle: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "fill";
        let st = Config.rawSettings.bar.style;
        if (typeof st === "string") return st;
        if (st && typeof st === "object") {
            if (st.fill || st.mode === "fill") return "fill";
            if (st.solid || st.mode === "solid") return "solid";
        }
        return "modular";
    }

    property bool isFill: barStyle === "fill"
    property bool isSolid: barStyle === "solid" || barStyle === "fill"

    property real barHeight: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height) ? s(Config.rawSettings.bar.height) : s(46);
    }

    property real cornerRadius: {
        let dummy = configRevision;
        let raw = (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined && ThemeBackend.borderRadius !== null)
            ? ThemeBackend.borderRadius
            : s(12);
        let threshold = s(32);
        let maxLimit = s(44);
        if (raw <= threshold) {
            return Math.max(s(8), raw);
        }
        let excess = raw - threshold;
        let range = maxLimit - threshold;
        return threshold + range * (1.0 - Math.exp(-excess / range));
    }

    property real menuMargin: isSolid ? 0 : s(12)

    onIsVisibleChanged: {
        if (isVisible) {
            if (typeof WindowTracker !== "undefined") WindowTracker.subscribe();
        } else {
            if (typeof WindowTracker !== "undefined") WindowTracker.unsubscribe();
        }
    }

    // Window data retrieval
    readonly property var activeWindow: {
        if (typeof WindowTracker === "undefined" || !WindowTracker.windows) return null;
        let wins = WindowTracker.windows;
        for (let i = 0; i < wins.length; i++) {
            if (wins[i] && wins[i].focused) return wins[i];
        }
        return null;
    }

    readonly property string currentAppId: (activeWindow && activeWindow.appId) ? activeWindow.appId : ((typeof CurrentFocus !== "undefined" && CurrentFocus.appClass) ? CurrentFocus.appClass : "")
    readonly property string currentTitle: (activeWindow && activeWindow.title) ? activeWindow.title : ((typeof CurrentFocus !== "undefined" && CurrentFocus.displayText) ? CurrentFocus.displayText : "")

    readonly property string resolvedAppIcon: {
        if (!currentAppId) return "";
        if (typeof AppMatcher !== "undefined") {
            let dId = AppMatcher.resolve(currentAppId);
            if (dId) {
                let entry = AppMatcher.entry(dId);
                if (entry && entry.icon) return entry.icon;
            }
        }
        return currentAppId;
    }

    readonly property string resolvedAppName: {
        if (!currentAppId) return "Active Window";
        if (typeof AppMatcher !== "undefined") {
            let dId = AppMatcher.resolve(currentAppId);
            if (dId) {
                let entry = AppMatcher.entry(dId);
                if (entry && entry.name) return entry.name;
            }
        }
        return currentAppId;
    }

    readonly property string workspaceLabel: {
        if (activeWindow && activeWindow.workspaceLabel) return "Workspace " + activeWindow.workspaceLabel;
        if (activeWindow && activeWindow.workspace >= 0) return "Workspace " + (activeWindow.workspace + 1);
        return "";
    }

    readonly property string compositorLabel: {
        if (typeof WindowTracker !== "undefined") {
            if (WindowTracker.isNiri) return "Niri";
            if (WindowTracker.isHyprland) return "Hyprland";
            if (WindowTracker.isSway) return "Sway";
            if (WindowTracker.isMango) return "Mango";
        }
        return "Wayland";
    }

    readonly property bool hasLiveHyprland: (typeof Hyprland !== "undefined" && Hyprland.activeToplevel && Hyprland.activeToplevel.wayland !== null && Hyprland.activeToplevel.wayland !== undefined)
    readonly property var captureSourceTarget: {
        if (hasLiveHyprland) return Hyprland.activeToplevel.wayland;
        return focusCardWindow.screen || (typeof Quickshell !== "undefined" && Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
    }
    readonly property bool hasLivePreview: captureSourceTarget !== null

    // Caelestia fluid pop bounce animation curves (matching Notch spring curves)
    readonly property var caelestiaPopBounce: [0.38, 1.22, 0.22, 1.0, 1.0, 1.0]
    readonly property var caelestiaAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]

    // Geometry calculation for seamless bar attachment
    property real cardWidth: s(360)
    property real targetCardHeight: contentCol.implicitHeight > 0 ? (contentCol.implicitHeight + s(20)) : s(165)
    property real cardHeight: targetCardHeight

    Behavior on cardHeight {
        enabled: focusCardWindow.isVisible && menuContainer.animProgress > 0.95
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    property real clampedX: {
        let w = cardWidth;
        let x = 0;
        if (isSideBar) {
            if (alignRight) {
                let barEdge = (targetX > focusCardWindow.width / 2) ? targetX : (focusCardWindow.width - barHeight);
                x = isSolid ? (focusCardWindow.width - barHeight - w) : (barEdge - w - menuMargin);
            } else {
                let barEdge = (targetX > 0 && targetX < focusCardWindow.width / 2) ? targetX : barHeight;
                x = isSolid ? barHeight : (barEdge + menuMargin);
            }
        } else {
            x = targetX - (w / 2);
        }
        let edgeBound = (isSolid && !isSideBar) ? (cornerRadius + s(4)) : s(8);
        return Math.max(edgeBound, Math.min(focusCardWindow.width - w - edgeBound, x));
    }

    property real clampedY: {
        let h = cardHeight;
        let y = 0;
        if (isSideBar) {
            y = targetY - (h / 2);
        } else {
            if (alignBottom) {
                let barEdge = (targetY > focusCardWindow.height / 2) ? targetY : (focusCardWindow.height - barHeight);
                y = isSolid ? (focusCardWindow.height - barHeight - h) : (barEdge - h - menuMargin);
            } else {
                let barEdge = (targetY > 0 && targetY < focusCardWindow.height / 2) ? targetY : barHeight;
                y = isSolid ? barHeight : (barEdge + menuMargin);
            }
        }
        let edgeBound = (isSolid && isSideBar) ? (cornerRadius + s(4)) : s(8);
        return Math.max(edgeBound, Math.min(focusCardWindow.height - h - edgeBound, y));
    }

    Item {
        id: maskTarget
        x: {
            if (focusCardWindow.isSolid && !focusCardWindow.isSideBar) {
                return menuContainer.x - menuContainer.dynamicCornerRadius;
            }
            return menuContainer.x;
        }
        y: {
            if (focusCardWindow.isSolid && focusCardWindow.isSideBar) {
                return menuContainer.y - menuContainer.dynamicCornerRadius;
            }
            return menuContainer.y;
        }
        width: {
            if (focusCardWindow.isSolid && !focusCardWindow.isSideBar) {
                return menuContainer.width + (menuContainer.dynamicCornerRadius * 2);
            }
            return menuContainer.width;
        }
        height: {
            if (focusCardWindow.isSolid && focusCardWindow.isSideBar) {
                return menuContainer.height + (menuContainer.dynamicCornerRadius * 2);
            }
            return menuContainer.height;
        }
    }

    mask: Region {
        item: (focusCardWindow.isVisible || menuContainer.animProgress > 0.001) ? maskTarget : null
    }

    visible: isVisible || menuContainer.animProgress > 0.001

    Item {
        id: rootContainer
        anchors.fill: parent

        Item {
            id: menuContainer

            property real animProgress: focusCardWindow.isVisible ? 1.0 : 0.0
            Behavior on animProgress {
                NumberAnimation {
                    duration: focusCardWindow.isVisible ? 420 : 250
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: focusCardWindow.isVisible ? focusCardWindow.caelestiaPopBounce : focusCardWindow.caelestiaAccel
                }
            }

            property real dynamicCornerRadius: focusCardWindow.isSolid ? Math.max(0, Math.min(focusCardWindow.cornerRadius, (focusCardWindow.isSideBar ? width : height))) : 0

            x: {
                if (focusCardWindow.isSolid) {
                    if (focusCardWindow.isSideBar) {
                        if (focusCardWindow.alignRight) {
                            return focusCardWindow.clampedX + (focusCardWindow.cardWidth - width);
                        }
                        return focusCardWindow.clampedX;
                    }
                    return focusCardWindow.clampedX;
                }
                let slideOffset = focusCardWindow.s(16) * (1.0 - animProgress);
                if (focusCardWindow.isSideBar) {
                    return focusCardWindow.alignRight ? (focusCardWindow.clampedX + slideOffset) : (focusCardWindow.clampedX - slideOffset);
                }
                return focusCardWindow.clampedX;
            }

            y: {
                if (focusCardWindow.isSolid) {
                    if (!focusCardWindow.isSideBar) {
                        if (focusCardWindow.alignBottom) {
                            return focusCardWindow.clampedY + (focusCardWindow.cardHeight - height);
                        }
                        return focusCardWindow.clampedY;
                    }
                    return focusCardWindow.clampedY;
                }
                let slideOffset = focusCardWindow.s(16) * (1.0 - animProgress);
                if (!focusCardWindow.isSideBar) {
                    return focusCardWindow.alignBottom ? (focusCardWindow.clampedY + slideOffset) : (focusCardWindow.clampedY - slideOffset);
                }
                return focusCardWindow.clampedY;
            }

            width: {
                if (focusCardWindow.isSolid && focusCardWindow.isSideBar) {
                    return focusCardWindow.cardWidth * animProgress;
                }
                return focusCardWindow.cardWidth;
            }

            height: {
                if (focusCardWindow.isSolid && !focusCardWindow.isSideBar) {
                    return focusCardWindow.cardHeight * animProgress;
                }
                return focusCardWindow.cardHeight;
            }

            opacity: Math.max(0.0, Math.min(1.0, animProgress * 1.5))
            scale: 0.88 + (0.12 * animProgress)

            transformOrigin: {
                if (focusCardWindow.isSideBar) {
                    return focusCardWindow.alignRight ? Item.Right : Item.Left;
                }
                return focusCardWindow.alignBottom ? Item.Bottom : Item.Top;
            }

            // Glass Fillets integration
            GlassFillets {
                id: rootFillets
                card: menuBox
                filletRadius: (focusCardWindow.isSolid && menuContainer.dynamicCornerRadius > 0.5) ? menuContainer.dynamicCornerRadius : 0
                filletDir: focusCardWindow.isSideBar
                    ? (focusCardWindow.alignRight ? Qt.vector2d(1, 0) : Qt.vector2d(-1, 0))
                    : (focusCardWindow.alignBottom ? Qt.vector2d(0, 1) : Qt.vector2d(0, -1))
            }

            // Inverted corner cutout left/top
            ShaderEffect {
                visible: focusCardWindow.isSolid && menuContainer.dynamicCornerRadius > 0.5
                x: {
                    if (focusCardWindow.isSideBar) {
                        return focusCardWindow.alignRight ? (parent.width - menuContainer.dynamicCornerRadius) : 0;
                    }
                    return -menuContainer.dynamicCornerRadius;
                }
                y: {
                    if (focusCardWindow.isSideBar) {
                        return -menuContainer.dynamicCornerRadius;
                    }
                    return focusCardWindow.alignBottom ? (parent.height - menuContainer.dynamicCornerRadius) : 0;
                }
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                property vector2d itemSize: Qt.vector2d(width, height)
                property real cornerIndex: {
                    if (focusCardWindow.isSideBar) {
                        return focusCardWindow.alignRight ? 3.0 : 2.0;
                    }
                    return focusCardWindow.alignBottom ? 3.0 : 1.0;
                }
                property color color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity) : "#1e1e2e"
                fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
            }

            // Inverted corner cutout right/bottom
            ShaderEffect {
                visible: focusCardWindow.isSolid && menuContainer.dynamicCornerRadius > 0.5
                x: {
                    if (focusCardWindow.isSideBar) {
                        return focusCardWindow.alignRight ? (parent.width - menuContainer.dynamicCornerRadius) : 0;
                    }
                    return parent.width;
                }
                y: {
                    if (focusCardWindow.isSideBar) {
                        return parent.height;
                    }
                    return focusCardWindow.alignBottom ? (parent.height - menuContainer.dynamicCornerRadius) : 0;
                }
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                property vector2d itemSize: Qt.vector2d(width, height)
                property real cornerIndex: {
                    if (focusCardWindow.isSideBar) {
                        return focusCardWindow.alignRight ? 1.0 : 0.0;
                    }
                    return focusCardWindow.alignBottom ? 2.0 : 0.0;
                }
                property color color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity) : "#1e1e2e"
                fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
            }

            Rectangle {
                id: menuBox
                anchors.fill: parent
                color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity) : Qt.alpha("#1e1e2e", 0.95)
                radius: focusCardWindow.cornerRadius

                readonly property bool flatCorners: focusCardWindow.isSolid
                topLeftRadius: (flatCorners && (focusCardWindow.isSideBar ? !focusCardWindow.alignRight : !focusCardWindow.alignBottom)) ? 0 : focusCardWindow.cornerRadius
                topRightRadius: (flatCorners && (focusCardWindow.isSideBar ? focusCardWindow.alignRight : !focusCardWindow.alignBottom)) ? 0 : focusCardWindow.cornerRadius
                bottomLeftRadius: (flatCorners && (focusCardWindow.isSideBar ? !focusCardWindow.alignRight : focusCardWindow.alignBottom)) ? 0 : focusCardWindow.cornerRadius
                bottomRightRadius: (flatCorners && (focusCardWindow.isSideBar ? focusCardWindow.alignRight : focusCardWindow.alignBottom)) ? 0 : focusCardWindow.cornerRadius

                border.width: focusCardWindow.isSolid ? 0 : 1
                border.color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.8) : "#313244"
                clip: true

                layer.enabled: true
                layer.smooth: true
                layer.samples: 8
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 32
                    shadowBlur: 0.70
                    shadowOpacity: 0.90
                    shadowColor: "#000000"
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }

                WallpaperBlur {
                    z: -1
                    anchors.fill: parent
                    topLeftRadius: parent.topLeftRadius
                    topRightRadius: parent.topRightRadius
                    bottomLeftRadius: parent.bottomLeftRadius
                    bottomRightRadius: parent.bottomRightRadius
                    filletRadius: rootFillets.filletRadius
                    filletDir: rootFillets.filletDir
                }

                HoverHandler {
                    id: cardHoverHandler
                    onHoveredChanged: {
                        if (hovered) {
                            FocusCardController.cancelHide();
                        } else if (focusCardWindow.isVisible) {
                            FocusCardController.requestHide(400);
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                }

                ColumnLayout {
                    id: contentCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: focusCardWindow.s(10)
                    spacing: focusCardWindow.s(8)

                    opacity: Math.max(0.0, Math.min(1.0, (menuContainer.animProgress - 0.15) / 0.85))
                    scale: 0.94 + (0.06 * menuContainer.animProgress)
                    transformOrigin: focusCardWindow.alignBottom ? Item.Bottom : Item.Top

                    // 1. Header Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: focusCardWindow.s(10)

                        // App Icon
                        Rectangle {
                            width: focusCardWindow.s(38)
                            height: focusCardWindow.s(38)
                            radius: focusCardWindow.s(10)
                            color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.6) : "#313244"

                            Image {
                                id: iconImg
                                anchors.fill: parent
                                anchors.margins: focusCardWindow.s(5)
                                fillMode: Image.PreserveAspectFit
                                source: focusCardWindow.resolvedAppIcon ? (focusCardWindow.resolvedAppIcon.indexOf("/") !== -1 || focusCardWindow.resolvedAppIcon.startsWith("image://") ? focusCardWindow.resolvedAppIcon : ("image://icon/" + focusCardWindow.resolvedAppIcon)) : ""
                                sourceSize.width: width
                                sourceSize.height: height
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "✦"
                                font.pixelSize: focusCardWindow.s(16)
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                                visible: !iconImg.visible
                            }
                        }

                        // App Name & Class
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: focusCardWindow.resolvedAppName
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                font.pixelSize: focusCardWindow.s(13)
                                font.weight: Font.Bold
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4"
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: focusCardWindow.currentAppId || "window"
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                font.pixelSize: focusCardWindow.s(10)
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                                elide: Text.ElideRight
                            }
                        }

                        // Close Window Button
                        IconButton {
                            width: focusCardWindow.s(26)
                            height: focusCardWindow.s(26)
                            cornerRadius: focusCardWindow.s(8)
                            buttonIcon: "✕"
                            iconFontSize: focusCardWindow.s(11)
                            accentColor: (typeof ThemeBackend !== "undefined") ? ThemeBackend.surface0 : "#313244"
                            textColor: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                            onClicked: {
                                if (focusCardWindow.activeWindow && typeof WindowTracker !== "undefined") {
                                    WindowTracker.close(focusCardWindow.activeWindow);
                                } else if (typeof WindowTracker !== "undefined" && WindowTracker.isNiri) {
                                    Quickshell.execDetached(["niri", "msg", "action", "close-window"]);
                                }
                                FocusCardController.hide();
                            }
                        }
                    }

                    // 2. Divider
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.5) : "#313244"
                    }

                    // 3. Window Title Box
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: titleInnerCol.implicitHeight + focusCardWindow.s(12)
                        radius: focusCardWindow.s(8)
                        color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface0, 0.35) : Qt.alpha("#313244", 0.4)

                        ColumnLayout {
                            id: titleInnerCol
                            anchors.fill: parent
                            anchors.margins: focusCardWindow.s(6)
                            spacing: focusCardWindow.s(4)

                            Text {
                                Layout.fillWidth: true
                                text: focusCardWindow.currentTitle || "No title"
                                font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                font.pixelSize: focusCardWindow.s(11)
                                font.weight: Font.DemiBold
                                color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4"
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            // Badges Row (Workspace & Compositor)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: focusCardWindow.s(6)

                                Rectangle {
                                    visible: focusCardWindow.workspaceLabel !== ""
                                    Layout.preferredHeight: focusCardWindow.s(18)
                                    Layout.preferredWidth: wsText.implicitWidth + focusCardWindow.s(10)
                                    radius: focusCardWindow.s(6)
                                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.mauve, 0.18) : Qt.alpha("#cba6f7", 0.2)

                                    Text {
                                        id: wsText
                                        anchors.centerIn: parent
                                        text: focusCardWindow.workspaceLabel
                                        font.pixelSize: focusCardWindow.s(9)
                                        font.weight: Font.Bold
                                        color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                                    }
                                }

                                Rectangle {
                                    Layout.preferredHeight: focusCardWindow.s(18)
                                    Layout.preferredWidth: compText.implicitWidth + focusCardWindow.s(10)
                                    radius: focusCardWindow.s(6)
                                    color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.alpha("#45475a", 0.4)

                                    Text {
                                        id: compText
                                        anchors.centerIn: parent
                                        text: focusCardWindow.compositorLabel
                                        font.pixelSize: focusCardWindow.s(9)
                                        color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext1 : "#bac2de"
                                    }
                                }
                            }
                        }
                    }

                    // 4. Live Screencopy Preview (Universal Wayland + Niri + Hyprland)
                    Rectangle {
                        id: previewBox
                        visible: focusCardWindow.hasLivePreview
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? focusCardWindow.s(170) : 0
                        radius: focusCardWindow.s(10)
                        color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mantle : "#11111b"
                        border.width: 1
                        border.color: (typeof ThemeBackend !== "undefined") ? Qt.alpha(ThemeBackend.surface1, 0.8) : "#313244"
                        clip: true

                        ScreencopyView {
                            id: screencopyStream
                            anchors.fill: parent
                            captureSource: (focusCardWindow.isVisible && previewBox.visible) ? focusCardWindow.captureSourceTarget : null
                            live: focusCardWindow.isVisible && previewBox.visible && (screencopyStream.captureSource !== null)
                            paintCursor: false
                        }

                        // Live pulse indicator overlay badge
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: focusCardWindow.s(8)
                            height: focusCardWindow.s(18)
                            width: liveBadgeRow.implicitWidth + focusCardWindow.s(12)
                            radius: height / 2
                            color: Qt.rgba(0, 0, 0, 0.65)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.18)
                            z: 2

                            RowLayout {
                                id: liveBadgeRow
                                anchors.centerIn: parent
                                spacing: focusCardWindow.s(5)

                                Rectangle {
                                    width: focusCardWindow.s(6)
                                    height: focusCardWindow.s(6)
                                    radius: 3
                                    color: screencopyStream.hasContent ? "#a6e3a1" : "#f38ba8"

                                    SequentialAnimation on opacity {
                                        running: focusCardWindow.isVisible
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                    }
                                }

                                Text {
                                    text: screencopyStream.hasContent ? "LIVE PREVIEW" : "CONNECTING"
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                    font.pixelSize: focusCardWindow.s(8)
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }
                            }
                        }

                        // Fallback indicator while stream connects
                        Item {
                            anchors.centerIn: parent
                            visible: !screencopyStream.hasContent
                            z: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: focusCardWindow.s(6)

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "🖥️"
                                    font.pixelSize: focusCardWindow.s(22)
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Menghubungkan live preview..."
                                    font.family: (typeof ThemeBackend !== "undefined") ? ThemeBackend.fontFamily : Qt.application.font.family
                                    font.pixelSize: focusCardWindow.s(10)
                                    color: (typeof ThemeBackend !== "undefined") ? ThemeBackend.subtext0 : "#a6adc8"
                                }
                            }
                        }
                    }

                    // 5. Action Buttons Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: focusCardWindow.s(8)

                        ClickButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: focusCardWindow.s(28)
                            cornerRadius: focusCardWindow.s(8)
                            buttonText: "Focus"
                            buttonIcon: "↗"
                            accentColor: (typeof ThemeBackend !== "undefined") ? ThemeBackend.mauve : "#cba6f7"
                            textColor: (typeof ThemeBackend !== "undefined") ? ThemeBackend.base : "#11111b"
                            textFontSize: focusCardWindow.s(11)
                            onClicked: {
                                if (focusCardWindow.activeWindow && typeof WindowTracker !== "undefined") {
                                    WindowTracker.focusWindow(focusCardWindow.activeWindow);
                                } else if (typeof WindowTracker !== "undefined" && WindowTracker.isNiri) {
                                    Quickshell.execDetached(["niri", "msg", "action", "focus-window-top"]);
                                }
                                FocusCardController.hide();
                            }
                        }

                        ClickButton {
                            Layout.preferredWidth: focusCardWindow.s(80)
                            Layout.preferredHeight: focusCardWindow.s(28)
                            cornerRadius: focusCardWindow.s(8)
                            buttonText: "Tutup"
                            accentColor: (typeof ThemeBackend !== "undefined") ? ThemeBackend.surface0 : "#313244"
                            textColor: (typeof ThemeBackend !== "undefined") ? ThemeBackend.text : "#cdd6f4"
                            textFontSize: focusCardWindow.s(11)
                            onClicked: {
                                FocusCardController.hide();
                            }
                        }
                    }
                }
            }
        }
    }
}
