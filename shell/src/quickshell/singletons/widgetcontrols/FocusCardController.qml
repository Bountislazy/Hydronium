pragma Singleton
import QtQuick
import Quickshell

Item {
    id: controller

    signal cardTriggered()

    property bool isVisible: false
    property var screen: (typeof Quickshell !== "undefined" && Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null
    property real targetX: 0
    property real targetY: 0
    property bool alignRight: false
    property bool alignBottom: false
    property bool isSideBar: false
    property bool isHoverLocked: false

    Timer {
        id: enterTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (controller.isHoverLocked) {
                controller.isVisible = true;
                controller.cardTriggered();
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!controller.isHoverLocked) {
                controller.isVisible = false;
            }
        }
    }

    function itemEntered(scr, posX, posY, isRight, isBottom, isSide) {
        controller.isHoverLocked = true;
        hideTimer.stop();
        controller.screen = scr;
        controller.targetX = posX;
        controller.targetY = posY;
        controller.alignRight = isRight;
        controller.alignBottom = isBottom;
        controller.isSideBar = isSide;

        if (controller.isVisible) {
            enterTimer.stop();
        } else {
            enterTimer.restart();
        }
    }

    function itemExited() {
        controller.isHoverLocked = false;
        enterTimer.stop();
        hideTimer.restart();
    }

    function cancelHide() {
        controller.isHoverLocked = true;
        hideTimer.stop();
    }

    function requestHide(delay) {
        controller.isHoverLocked = false;
        hideTimer.interval = delay || 350;
        hideTimer.restart();
    }

    function toggle(scr, posX, posY, isRight, isBottom, isSide) {
        if (controller.isVisible) {
            controller.hide();
        } else {
            controller.show(scr, posX, posY, isRight, isBottom, isSide);
        }
    }

    function show(scr, posX, posY, isRight, isBottom, isSide) {
        enterTimer.stop();
        hideTimer.stop();
        controller.isHoverLocked = true;
        controller.screen = scr;
        controller.targetX = posX;
        controller.targetY = posY;
        controller.alignRight = isRight;
        controller.alignBottom = isBottom;
        controller.isSideBar = isSide;
        controller.isVisible = true;
        controller.cardTriggered();
    }

    function hide() {
        enterTimer.stop();
        hideTimer.stop();
        controller.isHoverLocked = false;
        controller.isVisible = false;
    }
}
