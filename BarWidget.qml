import QtQuick
import qs.Ui as Ui
import "."

// The bar icon opens the settings card, and does nothing else. Launching a
// show is the hotkey's job: an icon wedged between the tray and the clock is
// far too easy to hit by accident for something that then covers every monitor
// for half a minute.
// (qs.Ui is imported under a namespace because this file is itself named
// BarWidget.qml — a bare `BarWidget` would resolve to the file itself.)
Ui.BarWidget {
    id: root
    moduleName: "shilai_li.fireworks"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    readonly property var panelAnchor: button
    property bool popoutSwitchClosing: false

    // Shape contract for the shell's summon/toggle routing. The overlay owns
    // the card, so both ends agree on what "open" means for this plugin.
    readonly property bool opened: FireworksState.overlay ? FireworksState.overlay.settingsOpen === true : false
    function open() {
        FireworksState.barWidget = root
        if (FireworksState.overlay) FireworksState.overlay.openSettings()
    }
    function close() { if (FireworksState.overlay) FireworksState.overlay.closeSettings() }
    function closeForPopoutSwitch() {
        popoutSwitchClosing = true
        close()
        Qt.callLater(function() { root.popoutSwitchClosing = false })
    }
    Component.onCompleted: FireworksState.barWidget = root
    Component.onDestruction: { if (FireworksState.barWidget === root) FireworksState.barWidget = null }

    Ui.BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "✦"
        tooltipText: "Fireworks settings"
        onPressed: function(b) {
            if (!FireworksState.overlay) return
            if (FireworksState.overlay.settingsOpen) FireworksState.overlay.closeSettings()
            else root.open()
        }
    }
}
