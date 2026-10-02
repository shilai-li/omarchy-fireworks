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
    readonly property string setupFontFamily: FireworksState.barWidget && FireworksState.barWidget.bar
        ? FireworksState.barWidget.bar.fontFamily : Style.font.family
    component SetupText: Text {
        font.family: root.setupFontFamily
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
    }
    property string note: "Choose how to set up Fireworks. Build from source opens a centered Omarchy terminal with instructions and live output. A prebuilt download can be used when a compatible release is published."
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
        if (mode === "prebuilt" && !prebuiltAvailable) return
        buildRequested = true
        note = "Finish setup in the terminal. If the prebuilt download is incompatible, use Build from source. The terminal shows progress and any errors."
        setupOpen = false
        Quickshell.execDetached(["/usr/bin/bash", root.pluginDir + "/fireworks-setup-terminal.sh", mode === "prebuilt" ? "prebuilt" : "source"])
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
    KeyboardPanel {
        id: panel
        anchorItem: FireworksState.barWidget ? FireworksState.barWidget.panelAnchor : null
        bar: FireworksState.barWidget ? FireworksState.barWidget.bar : null
        owner: FireworksState.barWidget || root
        open: root.setupOpen && FireworksState.barWidget !== null
        focusTarget: setupKeys
        contentWidth: fittedContentWidth(Style.space(400))
        contentHeight: fittedContentHeight(content.implicitHeight)
        Item {
            id: setupKeys
            anchors.fill: parent
            Column {
                id: content
                width: parent.width
                spacing: Style.space(12)
                focus: true
                Keys.onEscapePressed: root.closeSettings()
                Keys.onReturnPressed: root.build()
                SetupText { text: "Set up Fireworks"; color: Color.menu.text; font.bold: true; font.letterSpacing: 1 }
                Flickable {
                    width: parent.width
                    height: Math.min(message.implicitHeight, Style.space(120))
                    contentHeight: message.implicitHeight
                    clip: true
                    SetupText { id: message; width: parent.width; text: root.note; wrapMode: Text.Wrap; color: Color.menu.text }
                }
                Column {
                    width: parent.width
                    spacing: Style.space(6)
                    Rectangle {
                        width: parent.width; height: prebuiltText.implicitHeight + Style.space(16); radius: Style.cornerRadius
                        color: Color.menu.selectedBackground
                        opacity: root.prebuiltAvailable ? 1 : 0.5
                        Column {
                            id: prebuiltText
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.space(8) }
                            spacing: Style.space(4)
                            SetupText { text: "Use prebuilt"; color: Color.menu.selectedText; font.pixelSize: Style.font.body }
                            SetupText { width: parent.width; text: root.prebuiltAvailable ? "Download the compatible release. No compilation." : "Unavailable — no release is currently published."; wrapMode: Text.Wrap; color: Color.menu.selectedText }
                        }
                        MouseArea { anchors.fill: parent; enabled: root.prebuiltAvailable; onClicked: root.build("prebuilt") }
                    }
                    Rectangle {
                        width: parent.width; height: sourceText.implicitHeight + Style.space(16); radius: Style.cornerRadius
                        color: Color.menu.background; border.color: Color.menu.border
                        Column {
                            id: sourceText
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.space(8) }
                            spacing: Style.space(4)
                            SetupText { text: "Build from source"; color: Color.menu.text; font.pixelSize: Style.font.body }
                            SetupText { width: parent.width; text: "Build for your installed Qt libraries. Opens a centered terminal."; wrapMode: Text.Wrap; color: Color.menu.text }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.build("source") }
                    }
                    Rectangle {
                        width: Style.space(80); height: Style.font.body + Style.space(16); radius: Style.cornerRadius
                        color: Color.menu.background; border.color: Color.menu.border
                        SetupText { anchors.centerIn: parent; text: "Close"; color: Color.menu.text; font.pixelSize: Style.font.body }
                        MouseArea { anchors.fill: parent; onClicked: root.closeSettings() }
                    }
                }
            }
        }
    }
}
