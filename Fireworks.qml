import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "."

// Keep native imports behind a URL Loader so a clone can display setup.
Item {
    id: root
    readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
    property bool ready: false
    property bool setupOpen: false
    property bool checked: false
    property bool buildRequested: false
    property bool prebuiltAvailable: false
    property string note: "Fireworks needs a native build on this computer. Choose Build from source to open a terminal with instructions and live output. No prebuilt release is currently published."
    readonly property bool settingsOpen: setupOpen || (effect.item ? effect.item.settingsOpen : false)
    readonly property bool opened: setupOpen || (effect.item ? effect.item.opened : false)
    readonly property bool flying: effect.item ? effect.item.flying : false
    readonly property int shellType: effect.item ? effect.item.shellType : 0

    function openSettings() { if (effect.item) effect.item.openSettings(); else setupOpen = true }
    function closeSettings() { setupOpen = false; if (effect.item) effect.item.closeSettings() }
    function open(payload) { if (effect.item) effect.item.open(payload); else setupOpen = true }
    function close() { setupOpen = false; if (effect.item) effect.item.close() }
    function status(arg) { return effect.item ? effect.item.status(arg) : JSON.stringify({ready: false, buildRequested: buildRequested}) }
    function build(mode) {
        buildRequested = true
        note = "Finish setup in the terminal. If the prebuilt download is incompatible, use Build from source. The terminal shows progress and any errors."
        setupOpen = false
        Quickshell.execDetached(["omarchy", "launch", "terminal", "bash", root.pluginDir + "/fireworks-build.sh", "--terminal", mode === "prebuilt" ? "prebuilt" : "source"])
    }

    Component.onCompleted: FireworksState.overlay = root
    Component.onDestruction: { if (FireworksState.overlay === root) FireworksState.overlay = null }
    Process {
        command: ["bash", root.pluginDir + "/fireworks-prebuilt.sh", "--available"]
        running: true
        onExited: function(code, status) {
            root.prebuiltAvailable = code === 0
            if (root.prebuiltAvailable) root.note = "Choose a prebuilt download or build Fireworks from source. Both options open a terminal with progress and any errors."
        }
    }
    Process {
        id: probe
        command: ["bash", root.pluginDir + "/fireworks-build.sh", "--check"]
        running: true
        onExited: function(code, status) {
            root.ready = code === 0
            if (!root.checked) root.setupOpen = !root.ready
            root.checked = true
            if (root.ready) { root.setupOpen = false; root.buildRequested = false }
        }
    }
    Timer {
        interval: 1500
        repeat: true
        running: root.buildRequested && !root.ready
        onTriggered: if (!probe.running) probe.running = true
    }
    Loader {
        id: effect
        source: root.ready ? Qt.resolvedUrl("FireworksEffect.qml") : ""
        onLoaded: FireworksState.overlay = root
        onStatusChanged: if (status === Loader.Error) {
            root.setupOpen = true
            root.note = "The native module could not load. Rebuild it for the installed Qt version, then restart the Omarchy shell."
        }
    }
    PanelWindow {
        id: panel
        visible: root.setupOpen
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "omarchy-fireworks-setup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        Rectangle { anchors.fill: parent; color: Color.menu.scrim }
        Rectangle {
            width: Math.min(640, panel.width - 48)
            height: Math.min(content.implicitHeight + 48, panel.height - 48)
            anchors.centerIn: parent
            color: Color.menu.background
            radius: Style.cornerRadius
            border.color: Color.menu.border
            Column {
                id: content
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                spacing: 16
                focus: true
                Keys.onEscapePressed: root.closeSettings()
                Keys.onReturnPressed: root.build()
                Text { text: "Set up Fireworks"; color: Color.menu.text; font.pixelSize: 24 }
                Flickable {
                    width: parent.width
                    height: Math.min(message.implicitHeight, panel.height - 240)
                    contentHeight: message.implicitHeight
                    clip: true
                    Text { id: message; width: parent.width; text: root.note; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Color.menu.text }
                }
                Row {
                    spacing: 24
                    Rectangle {
                        visible: root.prebuiltAvailable
                        width: 185; height: 42; radius: 6
                        color: Color.menu.selectedBackground
                        Text { anchors.centerIn: parent; text: "Use prebuilt"; color: Color.menu.selectedText }
                        MouseArea { anchors.fill: parent; onClicked: root.build("prebuilt") }
                    }
                    Rectangle {
                        width: 185; height: 42; radius: 6
                        color: Color.menu.background; border.color: Color.menu.border
                        Text { anchors.centerIn: parent; text: "Build from source"; color: Color.menu.text }
                        MouseArea { anchors.fill: parent; onClicked: root.build("source") }
                    }
                    Rectangle {
                        width: 100; height: 42; radius: 6
                        color: Color.menu.background; border.color: Color.menu.border
                        Text { anchors.centerIn: parent; text: "Close"; color: Color.menu.text }
                        MouseArea { anchors.fill: parent; onClicked: root.closeSettings() }
                    }
                }
            }
        }
    }
}
