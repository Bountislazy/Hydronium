import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    model: Quickshell.screens

    delegate: Component {
        Scope {
            id: exclScope
            required property var modelData

            property bool frameEnabled: {
                if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.notch) return false;
                let f = Config.rawSettings.notch.frame;
                return (f === true || (typeof f === "object" && f && f.enabled !== false));
            }
            property real frameThickness: {
                if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.notch && Config.rawSettings.notch.frameThickness !== undefined) {
                    return Number(Config.rawSettings.notch.frameThickness);
                }
                return 10;
            }
            property real windowGap: {
                if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.notch && Config.rawSettings.notch.windowGap !== undefined) {
                    return Number(Config.rawSettings.notch.windowGap);
                }
                return 8;
            }
            readonly property real totalExclusion: (exclScope.frameEnabled && !exclScope.hasFullscreen) ? (exclScope.frameThickness + exclScope.windowGap) : 0
            property var activeToplevel: ToplevelManager.activeToplevel
            property bool hasFullscreen: {
                if (!activeToplevel || !activeToplevel.fullscreen) return false;
                if (activeToplevel.screens && activeToplevel.screens.length > 0) {
                    return activeToplevel.screens.indexOf(exclScope.modelData) !== -1;
                }
                return true;
            }

            PanelWindow {
                id: frameExclusionTop
                screen: exclScope.modelData
                WlrLayershell.namespace: "frame-exclusion-top"
                WlrLayershell.layer: WlrLayer.Top
                anchors.top: true
                anchors.left: true
                anchors.right: true
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: exclScope.totalExclusion
                mask: Region {}
                color: "transparent"
                implicitHeight: exclScope.totalExclusion
            }

            PanelWindow {
                id: frameExclusionLeft
                screen: exclScope.modelData
                WlrLayershell.namespace: "frame-exclusion-left"
                WlrLayershell.layer: WlrLayer.Top
                anchors.left: true
                anchors.top: true
                anchors.bottom: true
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: exclScope.totalExclusion
                mask: Region {}
                color: "transparent"
                implicitWidth: exclScope.totalExclusion
            }

            PanelWindow {
                id: frameExclusionRight
                screen: exclScope.modelData
                WlrLayershell.namespace: "frame-exclusion-right"
                WlrLayershell.layer: WlrLayer.Top
                anchors.right: true
                anchors.top: true
                anchors.bottom: true
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: exclScope.totalExclusion
                mask: Region {}
                color: "transparent"
                implicitWidth: exclScope.totalExclusion
            }
        }
    }
}
