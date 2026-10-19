import QtQuick
import Quickshell
import "."

Variants {
    model: Quickshell.screens

    delegate: Component {
        NotchWindow {
            required property var modelData
            screen: modelData
        }
    }
}
