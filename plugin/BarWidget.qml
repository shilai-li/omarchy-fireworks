import QtQuick
import qs.Ui as Ui
import "."
Ui.BarWidget {
    id: root
    moduleName: "shilai_li.fireworks"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    Ui.BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "✦"
        tooltipText: "Launch fireworks · right-click to choose a shell"
        onPressed: function(button) {
            if (!FireworksState.overlay) return
            if (button === Qt.RightButton) FireworksState.overlay.openSettings()
            else FireworksState.overlay.launch()
        }
    }
}
