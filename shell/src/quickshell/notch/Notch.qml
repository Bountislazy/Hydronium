import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

Variants {
    model: Quickshell.screens

    delegate: Component {
        Scope {
            id: notchScope
            required property var modelData

            NotchWindow {
                id: notchWin
                screen: notchScope.modelData
            }

            // ==========================================
            // CAELESTIA FRAME EXCLUSION ZONES
            // Ensures client windows never exceed or go under the frame
            // ==========================================
            PanelWindow {
                id: frameExclusionTop
                screen: notchScope.modelData
                WlrLayershell.namespace: "frame-exclusion-top"
                WlrLayershell.layer: WlrLayer.Top
                anchors.top: true
                anchors.left: true
                anchors.right: true
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: (notchWin.frameEnabled && !notchWin.hasFullscreen) ? notchWin.frameThickness : 0
                mask: Region {}
                color: "transparent"
                implicitHeight: (notchWin.frameEnabled && !notchWin.hasFullscreen) ? notchWin.frameThickness : 0
            }

            PanelWindow {
                id: frameExclusionLeft
                screen: notchScope.modelData
                WlrLayershell.namespace: "frame-exclusion-left"
                WlrLayershell.layer: WlrLayer.Top
                anchors.left: true
                anchors.top: true
                anchors.bottom: true
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: (notchWin.frameEnabled && !notchWin.hasFullscreen) ? notchWin.frameThickness : 0
                mask: Region {}
                color: "transparent"
                implicitWidth: (notchWin.frameEnabled && !notchWin.hasFullscreen) ? notchWin.frameThickness : 0
            }

            PanelWindow {
                id: frameExclusionRight
                screen: notchScope.modelData
                WlrLayershell.namespace: "frame-exclusion-right"
                WlrLayershell.layer: WlrLayer.Top
                anchors.right: true
                anchors.top: true
                anchors.bottom: true
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: (notchWin.frameEnabled && !notchWin.hasFullscreen) ? notchWin.frameThickness : 0
                mask: Region {}
                color: "transparent"
                implicitWidth: (notchWin.frameEnabled && !notchWin.hasFullscreen) ? notchWin.frameThickness : 0
            }
        }
    }
}
