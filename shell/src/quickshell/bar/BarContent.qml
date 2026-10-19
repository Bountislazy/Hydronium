import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../reusables"
import "../"

Item {
    id: barRoot

    required property var screen
    property var barWindow: null
    readonly property bool isUnified: !!(barWindow && barWindow.isUnified)

    property bool pendingReload: false
    property bool startupFilesReady: false
    property bool isRedacting: false

    property bool hideBarInRedactor: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.widgets && Config.rawSettings.widgets.hideBarInRedactor !== undefined) {
            return Config.rawSettings.widgets.hideBarInRedactor;
        }
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.hideBarInRedactor !== undefined) {
            return Config.rawSettings.bar.hideBarInRedactor;
        }
        return true;
    }

    property bool shouldHideForRedact: isRedacting && hideBarInRedactor

    property var activeToplevel: ToplevelManager.activeToplevel
    property bool isFullscreenActive: {
        if (!activeToplevel || !activeToplevel.fullscreen) return false;
        if (activeToplevel.screens && activeToplevel.screens.length > 0) {
            return activeToplevel.screens.indexOf(barRoot.screen) !== -1;
        }
        return true;
    }

    onIsFullscreenActiveChanged: {
        if (barRoot.isFullscreenActive) {
            OsdController.isFullscreen = true;
        } else if (!OsdController.screen || OsdController.screen === barRoot.screen) {
            OsdController.isFullscreen = false;
        }
    }

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { barRoot.configRevision++; }
        function onDataReadyChanged() { barRoot.configRevision++; }
        function onRawSettingsChanged() { barRoot.configRevision++; }
    }

    Component.onCompleted: {
        if (typeof Config !== "undefined" && Config.dataReady) {
            barRoot.configRevision++;
        }
    }

    property string barStyle: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
        let s = Config.rawSettings.bar.style;
        if (typeof s === "string") return s;
        if (s && typeof s === "object") {
            if (s.fill || s.mode === "fill") return "fill";
            if (s.solid || s.mode === "solid") return "solid";
        }
        return "modular";
    }
    property bool isFill: barStyle === "fill"
    property bool isSolid: barStyle === "solid" || barStyle === "fill"
    property bool distinctPills: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.distinctPills !== undefined) ? Config.rawSettings.bar.distinctPills : false;
    }
    property bool centerByEdges: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.centerByEdges !== undefined) ? Config.rawSettings.bar.centerByEdges : true;
    }

    property bool barConfigReady: {
        let dummy = configRevision;
        if (typeof Config === "undefined") return true;
        if (Config.dataReady !== undefined) return Config.dataReady;
        return true;
    }

    property bool autohide: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.autohide !== undefined) ? Config.rawSettings.bar.autohide : false;
    }
    property int autohideTimeout: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.autohideTimeout !== undefined) ? Config.rawSettings.bar.autohideTimeout : 1000;
    }
    property real barOpacity: ThemeBackend.elementOpacity

    HoverHandler {
        id: barHover
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    Timer {
        id: hideTimer
        interval: barRoot.autohideTimeout
    }

    function checkHideTimer() {
        if (!barHover.hovered && barRoot.autohide) {
            hideTimer.restart();
        } else {
            hideTimer.stop();
        }
    }

    Connections {
        target: barHover
        function onHoveredChanged() { barRoot.checkHideTimer(); }
    }

    property bool isRevealed: {
        if (shouldHideForRedact) return false;
        if (!autohide) return true;
        if (barHover.hovered) return true;
        if (hideTimer.running) return true;
        return false;
    }

    Timer {
        interval: 50
        running: true
        onTriggered: barRoot.startupFilesReady = true
    }

    Connections {
        target: (typeof WidgetSync !== "undefined") ? WidgetSync : null
        function onRedactModeChanged(monitor, active) {
            barRoot.isRedacting = active;
        }
    }

    IpcHandler {
        target: "topbar"
        function setRedactMode(active: string): void {
            barRoot.isRedacting = (active === "true" || active === "1");
        }
        function forceReload() {
            Quickshell.reload(true)
        }
        function queueReload() {
            if (!barRoot.isNotifOpen && !barRoot.isSysOpen) {
                Quickshell.reload(true)
            } else {
                barRoot.pendingReload = true
            }
        }
        function toggleUpdate() {
            let target = null;
            if (barRoot.isVertical) target = verticalWrapper.getWidget("left");
            else target = contentWrapper.getWidget("left");
            if (target && typeof target.toggleUpdate === "function") {
                target.toggleUpdate();
            }
        }
    }

    property string barPosition: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.position !== undefined) ? Config.rawSettings.bar.position : "bottom";
    }
    property bool positionChanging: false

    property real barWidthPercent: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.width !== undefined) ? Config.rawSettings.bar.width : 100;
    }
    property real edgePadding: (autohide && !isFill) ? s(4) : 0
    property real effectiveBarWidth: Math.round(isVertical ? barRoot.width : (isFill ? barRoot.width : ((barRoot.width - (autohide ? edgePadding * 2 : 0)) * (barWidthPercent / 100.0))))
    property real horizontalOffset: Math.round((isVertical || isFill) ? 0 : ((barRoot.width - effectiveBarWidth) / 2))

    property real effectiveBarHeight: Math.round(!isVertical ? barHeight : (isFill ? barRoot.height : ((barRoot.height - (autohide ? edgePadding * 2 : 0)) * (barWidthPercent / 100.0))))
    property real verticalOffset: Math.round((!isVertical || isFill) ? 0 : ((barRoot.height - effectiveBarHeight) / 2))

    property real currentBarMinX: (contentWrapper && contentWrapper.dynamicMaxX > contentWrapper.dynamicMinX) ? contentWrapper.dynamicMinX : (isFill ? 0 : horizontalOffset)
    property real currentBarMaxX: (contentWrapper && contentWrapper.dynamicMaxX > contentWrapper.dynamicMinX) ? contentWrapper.dynamicMaxX : (isFill ? barRoot.width : (horizontalOffset + effectiveBarWidth))

    property real currentBarMinY: (verticalWrapper && verticalWrapper.dynamicMaxY > verticalWrapper.dynamicMinY) ? verticalWrapper.dynamicMinY : verticalOffset
    property real currentBarMaxY: (verticalWrapper && verticalWrapper.dynamicMaxY > verticalWrapper.dynamicMinY) ? verticalWrapper.dynamicMaxY : (verticalOffset + effectiveBarHeight)

    property bool fillAttached: isFill && (isVertical
        ? (currentBarMinY > 0.5 || currentBarMaxY < barRoot.height - 0.5)
        : (currentBarMinX > 0.5 || currentBarMaxX < barRoot.width - 0.5))

    Timer {
        id: positionChangeTimer
        interval: 200
        onTriggered: barRoot.positionChanging = false
    }

    onBarPositionChanged: {
        barRoot.positionChanging = true;
        positionChangeTimer.restart();
    }

    property bool isVertical: barPosition === "left" || barPosition === "right"

    property real baseScale: Scaler.baseScale

    function s(val) {
        return Math.round(Scaler.s(val));
    }

    readonly property real baseThickness: 40
    readonly property real minThickness: 28
    readonly property real maxThickness: 48
    property real thicknessSetting: {
        let dummy = configRevision;
        let v = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height !== undefined) ? Number(Config.rawSettings.bar.height) : baseThickness;
        if (isNaN(v)) v = baseThickness;
        return Math.max(minThickness, Math.min(maxThickness, v));
    }
    property real contentRatio: thicknessSetting / baseThickness

    function cs(val) {
        return Math.round(Scaler.s(val) * contentRatio);
    }

    property int barHeight: s(thicknessSetting)
    property real cornerRadius: s(12)

    property real baseOffsetY: {
        if (barPosition === "bottom") {
            let winH = (barWindow && barWindow.isUnified) ? barRoot.height : (barWindow ? barWindow.height : barRoot.height);
            return isFill ? (winH - barHeight) : (winH - barHeight - edgePadding);
        } else {
            return isFill ? 0 : edgePadding;
        }
    }

    property string activeWidget: ""
    property bool isNotifOpen: activeWidget === "notifications"
    property bool isSysOpen: activeWidget === "system"

    onActiveWidgetChanged: {
        if (!barRoot.isNotifOpen && !barRoot.isSysOpen && barRoot.pendingReload) {
            barRoot.pendingReload = false;
            Quickshell.reload(true);
        }
    }

    FileView {
        id: widgetWatcher
        path: (barRoot.startupFilesReady && Caching.runDir) ? (Caching.runDir + "/current_widget") : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let txt = text().trim();
            let widget = "";
            let targetScreen = "";

            try {
                let parsed = JSON.parse(txt);
                if (parsed && typeof parsed === "object") {
                    widget = parsed.widget || "";
                    targetScreen = parsed.screen || "";
                } else if (typeof parsed === "string") {
                    widget = parsed;
                }
            } catch (e) {
                widget = txt;
            }

            let myScreenName = (barRoot.screen && barRoot.screen.name) ? barRoot.screen.name : "";
            let effectiveWidget = "";
            if (widget === "notifications" || widget === "system") {
                if (!targetScreen || targetScreen === myScreenName) {
                    effectiveWidget = widget;
                }
            }

            if (barRoot.activeWidget !== effectiveWidget) {
                barRoot.activeWidget = effectiveWidget;
            }
        }
    }

    property bool isStartupReady: false
    Timer { interval: 10; running: true; onTriggered: barRoot.isStartupReady = true }

    property bool startupCascadeFinished: false
    Timer { interval: 1050; running: true; onTriggered: barRoot.startupCascadeFinished = true }

    property bool fastPollerLoaded: false
    property bool isDataReady: fastPollerLoaded
    Timer { interval: 400; running: true; onTriggered: barRoot.isDataReady = true }

    readonly property real hideOffsetY: (contentWrapper && contentWrapper.hideOffsetY !== undefined) ? contentWrapper.hideOffsetY : 0
    readonly property real hideOffsetX: (verticalWrapper && verticalWrapper.hideOffsetX !== undefined) ? verticalWrapper.hideOffsetX : 0

    SideBar {
        id: verticalWrapper
        barWindow: barRoot
        property real hideOffsetX: {
            if (!barRoot || barRoot.isRevealed) return 0;
            let offset = barRoot.barHeight + barRoot.edgePadding + barRoot.s(10);
            return barRoot.barPosition === "right" ? offset : -offset;
        }
        transform: Translate {
            x: verticalWrapper.hideOffsetX
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
        }
    }

    TopBar {
        id: contentWrapper
        barWindow: barRoot
    }
}
