import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Wayland
import "native" as Native
import "."

Item {
    id: root
    property bool flying: false
    property bool settingsOpen: false
    property bool mutedForShow: false
    readonly property int shellType: director.shellType
    readonly property bool opened: flying || settingsOpen
    function launch(quiet, shell) {
        var selected = shell === undefined ? preferences.shellType : director.shellIndex(String(shell))
        if (selected < 0) { console.warn("Fireworks: unknown shell", shell); return }
        director.pause()
        director.shellType = selected
        mutedForShow=quiet===true
        flying=true
        launchDelay.restart()
    }
    function openSettings() { settingsOpen=true }
    function open(payloadJson) {
        var payload={}
        try { payload=JSON.parse(payloadJson || "{}") || {} } catch(e) {}
        if(payload.view === "settings") openSettings()
        else launch(payload.muted===true, payload.shell)
    }
    function close() { launchDelay.stop(); director.pause(); flying=false; settingsOpen=false }
    Component.onCompleted: FireworksState.overlay=root
    Component.onDestruction: { if(FireworksState.overlay===root) FireworksState.overlay=null }

    Settings {
        id: preferences
        // Quickshell does not set an application organization for QSettings.
        location: "file://" + (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
                  + "/omarchy-fireworks/settings.ini"
        category: "OmarchyFireworks"
        property bool sound: true
        property real volume: 0.35
        property real bloom: 0.85
        property real exposure: 0.95
        property int shellType: 0
    }
    Native.ShowDirector {
        id: director
        audioEnabled: preferences.sound && !root.mutedForShow
        volume: preferences.volume
        onFinished: root.flying=false
    }
    Timer { id: launchDelay; interval: 80; onTriggered: director.launch() }
    Variants {
        model: root.flying ? Quickshell.screens : []
        delegate: Component {
            PanelWindow {
                required property var modelData
                screen: modelData
                anchors { left: true; right: true; top: true; bottom: true }
                color: "transparent"
                WlrLayershell.namespace: "omarchy-fireworks"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                mask: Region {}
                Native.FireworksView {
                    anchors.fill: parent
                    time: director.time
                    seed: director.seed
                    shellType: director.shellType
                    bloom: preferences.bloom
                    exposure: preferences.exposure
                }
            }
        }
    }
    PanelWindow {
        visible: root.settingsOpen
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        WlrLayershell.namespace: "omarchy-fireworks-settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        Rectangle { anchors.fill: parent; color: "#88000000" }
        MouseArea { anchors.fill: parent; onClicked: root.settingsOpen=false }
        Rectangle {
            anchors.centerIn: parent
            width: 460; height: form.implicitHeight+56
            color: "#151820"; radius: 16; border.color: "#39363a"
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                id: form
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
                spacing: 15
                Text { text: "Firework shells"; color: "#f0f3ff"; font.pixelSize: 26 }
                Text { text: "Coordinated colors, changing tips, and gold finishes."; color: "#a4a0a0"; font.pixelSize: 12 }
                ComboBox {
                    model: director.shellNames
                    currentIndex: Math.max(0, Math.min(3, preferences.shellType))
                    onActivated: preferences.shellType = currentIndex
                    Layout.fillWidth: true
                    Accessible.name: "Firework shell"
                }
                CheckBox {
                    text: "Play boom and crackle"
                    palette.windowText: "#bdb7ac"
                    checked: preferences.sound
                    onToggled: preferences.sound=checked
                }
                RowLayout {
                    Text { text: "Volume"; color: "#bdb7ac"; Layout.preferredWidth: 70 }
                    Slider { from: 0; to: 1; value: preferences.volume; onMoved: preferences.volume=value; Layout.fillWidth: true }
                }
                RowLayout {
                    Text { text: "Glow"; color: "#bdb7ac"; Layout.preferredWidth: 70 }
                    Slider { from: 0; to: 2; value: preferences.bloom; onMoved: preferences.bloom=value; Layout.fillWidth: true }
                }
                RowLayout {
                    Text { text: "Light"; color: "#bdb7ac"; Layout.preferredWidth: 70 }
                    Slider { from: 0.25; to: 1.8; value: preferences.exposure; onMoved: preferences.exposure=value; Layout.fillWidth: true }
                }
                RowLayout {
                    Button { text: "Launch shell"; onClicked: { root.settingsOpen=false; root.launch() } }
                    Button { text: "Done"; onClicked: root.settingsOpen=false }
                }
            }
        }
    }
}
