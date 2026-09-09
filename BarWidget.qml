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

    // Shape contract for the shell's summon/toggle routing. The overlay owns
    // the card, so both ends agree on what "open" means for this plugin.
    readonly property bool opened: FireworksState.overlay ? FireworksState.overlay.settingsOpen === true : false
    function open() { if (FireworksState.overlay) FireworksState.overlay.openSettings() }
    function close() { if (FireworksState.overlay) FireworksState.overlay.closeSettings() }

    Ui.BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "✦"
        tooltipText: "Fireworks settings"
        onPressed: function(b) {
            if (!FireworksState.overlay) return
            if (FireworksState.overlay.settingsOpen) FireworksState.overlay.closeSettings()
            else FireworksState.overlay.openSettings()
        }
    }
}
