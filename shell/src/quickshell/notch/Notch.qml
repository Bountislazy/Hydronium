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
        }
    }
}
