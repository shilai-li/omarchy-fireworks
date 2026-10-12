import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omarchy.Fireworks 1.0

ApplicationWindow {
    id: window
    width: 1440; height: 940
    minimumWidth: 540; minimumHeight: 640
    visible: true
    title: "Fireworks · " + director.shellName
    color: "#080b11"
    palette.window: "#080b11"
    palette.text: "#eee7db"
    palette.buttonText: "#eee7db"
    palette.highlight: "#82d8ef"
    palette.button: "#25262c"
    font.family: "sans-serif"
    font.pixelSize: 12

    ShowDirector {
        id: director
        audioEnabled: !startMuted
        Component.onCompleted: seek(previewTime)
    }
    FireworksView {
        id: fireworks
        anchors.fill: parent
        time: director.time
        seed: director.seed
        shellType: director.shellType
        originX: director.originX
        exposure: exposureControl.value
        bloom: bloomControl.value
    }

    Column {
        anchors { top: parent.top; left: parent.left; margins: 36 }
        spacing: 10
        Text { text: "OMARCHY  /  FIREWORKS"; color: "#8fcfe2"; font.pixelSize: 11; font.letterSpacing: 3 }
        Text { text: director.shellName; color: "#f0f3ff"; font.pixelSize: 31; font.weight: Font.Light }
        Text { text: director.shellDescription; color: "#888994"; font.pixelSize: 13; width: window.width - 72; wrapMode: Text.WordWrap }
    }
    Text {
        anchors { top: parent.top; right: parent.right; margins: 38 }
        text: "0" + (director.shellType+1) + "  /  SHELL"; color: "#777982"; font.pixelSize: 11; font.letterSpacing: 2
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 26 }
        height: 202
        radius: 14
        color: "#ed11141b"
        border.color: "#2e3038"
        ColumnLayout {
            anchors { fill: parent; margins: 17 }
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Text { text: "SHELL"; color: "#9999a2"; font.pixelSize: 10; font.letterSpacing: 1 }
                ComboBox {
                    model: director.shellNames
                    currentIndex: director.shellType
                    Layout.fillWidth: true
                    Accessible.name: "Firework shell"
                    onActivated: {
                        director.pause()
                        director.shellType = currentIndex
                        director.seek(director.previewTime)
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Button {
                    text: "Launch shell"
                    highlighted: true
                    onClicked: director.launch()
                }
                Button {
                    text: director.running ? "Pause" : "Play"
                    onClicked: director.running ? director.pause() : director.resume()
                }
                Item { Layout.fillWidth: true }
                Button { text: director.audioEnabled ? "Sound on" : "Muted"; onClicked: director.audioEnabled=!director.audioEnabled }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text { text: "GLOW"; color: "#9999a2"; font.pixelSize: 10; font.letterSpacing: 1 }
                Slider { id: bloomControl; from: 0; to: 2; value: 0.85; Layout.fillWidth: true; Layout.minimumWidth: 30; Accessible.name: "Bloom strength" }
                Text { text: "LIGHT"; color: "#9999a2"; font.pixelSize: 10; font.letterSpacing: 1 }
                Slider { id: exposureControl; from: 0.25; to: 1.8; value: 0.95; Layout.fillWidth: true; Layout.minimumWidth: 30; Accessible.name: "Exposure" }
                Text { text: "VOL"; color: "#9999a2"; font.pixelSize: 10; font.letterSpacing: 1 }
                Slider { from: 0; to: 1; value: director.volume; Layout.fillWidth: true; Layout.minimumWidth: 30; onMoved: director.volume=value; Accessible.name: "Volume" }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text { text: "LAUNCH"; color: "#9999a2"; font.pixelSize: 10; font.letterSpacing: 1 }
                Slider {
                    from: -1; to: 1
                    value: director.launchX
                    enabled: !director.randomLaunch
                    opacity: enabled ? 1 : 0.35
                    Layout.fillWidth: true
                    Layout.minimumWidth: 30
                    onMoved: director.launchX=value
                    Accessible.name: "Launch position"
                }
                Button {
                    text: director.randomLaunch ? "Random" : "Fixed"
                    onClicked: director.randomLaunch=!director.randomLaunch
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Text { text: director.time<1.95 ? "ASCENT" : director.time<4 ? "BLOOM" : "AFTERGLOW"; color: "#a6bde6"; font.pixelSize: 10; font.letterSpacing: 1; Layout.preferredWidth: 84 }
                Slider {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 30
                    from: 0; to: director.duration
                    value: director.time
                    onMoved: director.seek(value)
                    Accessible.name: "Show timeline"
                }
                Text { text: director.time.toFixed(1)+" / 11.0 s"; color: "#8d8e97"; font.pixelSize: 11 }
            }
        }
    }
    Shortcut { sequence: "Space"; onActivated: director.running ? director.pause() : director.resume() }
    Shortcut { sequence: "R"; onActivated: director.launch() }
    Shortcut { sequence: "M"; onActivated: director.audioEnabled=!director.audioEnabled }
    Shortcut { sequence: "Escape"; onActivated: window.close() }
}
