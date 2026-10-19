import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../reusables"
import "../"

Scope {
    id: barRootScope

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { barRootScope.configRevision++; }
        function onDataReadyChanged() { barRootScope.configRevision++; }
        function onRawSettingsChanged() { barRootScope.configRevision++; }
    }

    Component.onCompleted: {
        if (typeof Config !== "undefined" && Config.dataReady) {
            barRootScope.configRevision++;
        }
    }

    readonly property bool isUnified: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.notch) return true;
        let notchEnabled = Config.rawSettings.notch.enabled !== undefined ? Boolean(Config.rawSettings.notch.enabled) : true;
        let frameEnabled = Config.rawSettings.notch.frameEnabled !== undefined ? Boolean(Config.rawSettings.notch.frameEnabled) : true;
        let barPos = (Config.rawSettings.bar && Config.rawSettings.bar.position) ? Config.rawSettings.bar.position : "bottom";
        return notchEnabled && frameEnabled && (barPos === "bottom");
    }

    Variants {
        model: barRootScope.isUnified ? [] : Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: barWindowRoot
                required property var modelData
                screen: modelData

                visible: barContent.barConfigReady
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                anchors {
                    top: barContent.barPosition === "top" || barContent.isVertical
                    bottom: barContent.barPosition === "bottom" || barContent.isVertical
                    left: barContent.barPosition === "left" || !barContent.isVertical
                    right: barContent.barPosition === "right" || !barContent.isVertical
                }

                implicitHeight: barContent.isVertical ? 0 : (barContent.barHeight + (barContent.isFill ? barContent.cornerRadius : barContent.edgePadding))
                implicitWidth: barContent.isVertical ? (barContent.barHeight + (barContent.isFill ? barContent.cornerRadius : barContent.edgePadding)) : 0

                margins {
                    top: barContent.isFill ? 0 : (barContent.barPosition === "bottom" ? 0 : (barContent.autohide ? 0 : barContent.s(4)))
                    bottom: barContent.isFill ? 0 : (barContent.barPosition === "top" ? 0 : (barContent.autohide ? 0 : barContent.s(4)))
                    left: barContent.isFill ? 0 : (barContent.barPosition === "right" ? 0 : (barContent.autohide ? 0 : barContent.s(4)))
                    right: barContent.isFill ? 0 : (barContent.barPosition === "left" ? 0 : (barContent.autohide ? 0 : barContent.s(4)))
                }

                exclusiveZone: (!barContent.barConfigReady || barContent.autohide || barContent.shouldHideForRedact) ? 0 : barContent.barHeight

                property real activeMaskHeight: barContent.shouldHideForRedact ? 0 : ((barContent.autohide && !barContent.isRevealed) ? barContent.s(4) : (barContent.isVertical ? (barContent.isFill ? barWindowRoot.height : (barContent.effectiveBarHeight + barContent.edgePadding * 2)) : (barContent.isFill ? (barContent.barHeight + barContent.cornerRadius) : (barContent.barHeight + barContent.edgePadding))))
                property real activeMaskWidth: barContent.shouldHideForRedact ? 0 : ((barContent.autohide && !barContent.isRevealed) ? barContent.s(4) : (barContent.isVertical ? (barContent.isFill ? (barContent.barHeight + barContent.cornerRadius) : (barContent.barHeight + barContent.edgePadding)) : (barContent.isFill ? barWindowRoot.width : (barContent.effectiveBarWidth + barContent.edgePadding * 2))))

                mask: Region {
                    Region {
                        x: barContent.isVertical ? (barContent.barPosition === "right" ? (barWindowRoot.width - barWindowRoot.activeMaskWidth) : 0) : (barContent.isFill ? 0 : barContent.currentBarMinX)
                        y: barContent.isVertical ? (barContent.isFill ? 0 : barContent.currentBarMinY) : (barContent.barPosition === "bottom" ? barContent.baseOffsetY : 0)
                        width: barContent.isVertical ? barWindowRoot.activeMaskWidth : (barContent.isFill ? barWindowRoot.width : (barContent.currentBarMaxX - barContent.currentBarMinX))
                        height: barContent.isVertical ? (barContent.currentBarMaxY - barContent.currentBarMinY) : (barContent.isFill ? barContent.barHeight : barWindowRoot.activeMaskHeight)
                    }
                    Region {
                        x: barContent.isVertical ? (barContent.barPosition === "right" ? (barWindowRoot.width - barContent.barHeight - barContent.cornerRadius) : barContent.barHeight) : 0
                        y: barContent.isVertical ? 0 : (barContent.barPosition === "bottom" ? (barContent.baseOffsetY - barContent.cornerRadius) : (barContent.baseOffsetY + barContent.barHeight))
                        width: (barContent.isFill && !barContent.fillAttached) ? barContent.cornerRadius : 0
                        height: (barContent.isFill && !barContent.fillAttached) ? barContent.cornerRadius : 0
                    }
                    Region {
                        x: barContent.isVertical ? (barContent.barPosition === "right" ? (barWindowRoot.width - barContent.barHeight - barContent.cornerRadius) : barContent.barHeight) : (barWindowRoot.width - barContent.cornerRadius)
                        y: barContent.isVertical ? (barWindowRoot.height - barContent.cornerRadius) : (barContent.barPosition === "bottom" ? (barContent.baseOffsetY - barContent.cornerRadius) : (barContent.baseOffsetY + barContent.barHeight))
                        width: (barContent.isFill && !barContent.fillAttached) ? barContent.cornerRadius : 0
                        height: (barContent.isFill && !barContent.fillAttached) ? barContent.cornerRadius : 0
                    }
                }

                BarContent {
                    id: barContent
                    screen: barWindowRoot.screen
                    barWindow: barWindowRoot
                    anchors.fill: parent
                }
            }
        }
    }
}
