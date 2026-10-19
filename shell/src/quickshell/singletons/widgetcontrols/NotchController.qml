pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: controller

    signal toggleRequested(string screenName)
    signal expandRequested(string screenName)
    signal collapseRequested(string screenName)

    function toggle(screenName) {
        controller.toggleRequested(screenName || "");
    }

    function expand(screenName) {
        controller.expandRequested(screenName || "");
    }

    function collapse(screenName) {
        controller.collapseRequested(screenName || "");
    }

    IpcHandler {
        target: "notch"

        function toggle() {
            controller.toggle("");
        }

        function expand() {
            controller.expand("");
        }

        function collapse() {
            controller.collapse("");
        }
    }
}
