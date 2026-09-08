import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "native" as Native
import "."

// Omarchy Fireworks — authored shells fired over the desktop.
//
// Two surfaces, deliberately different. The show is a click-through layer with
// no keyboard focus, one per monitor, so a launch never interrupts what you
// were doing: you can keep typing straight through it. The settings card is an
// ordinary focused panel, opened from the bar icon, where the shell, the
// hotkey, and the look of the show are chosen.
Item {
    id: root

    readonly property string pluginDir: {
        var u = String(Qt.resolvedUrl("."))
        return decodeURIComponent(u.replace(/^file:\/\//, "")).replace(/\/$/, "")
    }

    // ------------------------------------------------------------------ theme
    // The card follows the active Omarchy theme rather than carrying colours of
    // its own; only the fireworks themselves are authored.
    readonly property color foreground: Color.menu.text
    readonly property color background: Color.menu.background
    readonly property color border: Color.menu.border
    readonly property color scrim: Color.menu.scrim
    readonly property color selectedBackground: Color.menu.selectedBackground
    readonly property color selectedText: Color.menu.selectedText
    readonly property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
    readonly property int cornerRadius: Style.cornerRadius
    readonly property int labelWidth: Style.space(92)
    readonly property string fontFamily: Style.font.menuFamily

    // -------------------------------------------------------------- lifecycle
    readonly property bool flying: launches.activeCount > 0 || launches.scheduled
    property bool settingsOpen: false
    readonly property int shellType: director.shellType

    // The shell reads this to decide whether a summon should open or hide us.
    readonly property bool opened: flying || settingsOpen

    function launch(quiet, shell, size) {
        var selected = shell === undefined ? preferences.shellType : director.shellIndex(String(shell))
        if (selected < 0) { console.warn("Fireworks: unknown shell", shell); return }
        var display = size === undefined ? preferences.displaySize : root.displayIndex(size)
        if (display < 0) { console.warn("Fireworks: unknown display size", size); return }
        director.shellType = selected
        launches.launchDisplay(display, selected, quiet === true, preferences.launchX,
                               preferences.randomLaunch)
    }

    // Named sizes for the IPC payload, so a script can ask for one shell
    // without disturbing the saved preference — as a named shell already does.
    function displayIndex(name) {
        for (var i = 0; i < launches.displays.length; ++i)
            if (launches.displays[i].name === String(name)) return i
        return -1
    }

    function openSettings() {
        root.capturing = false
        root.captureNote = ""
        root.settingsOpen = true
    }

    function closeSettings() {
        root.settingsOpen = false
        root.capturing = false
    }

    // Reached from `omarchy-shell shell summon`, which is what the hotkey runs.
    // A bare summon launches; the bar icon calls openSettings() directly rather
    // than coming through here.
    function open(payloadJson) {
        var payload = {}
        try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
        if (payload.view === "settings") root.openSettings()
        else root.launch(payload.muted === true, payload.shell, payload.size)
    }

    function close() {
        launches.stop()
        root.closeSettings()
    }

    Component.onCompleted: FireworksState.overlay = root
    Component.onDestruction: { if (FireworksState.overlay === root) FireworksState.overlay = null }

    // ---------------------------------------------------------------- settings
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
        // Where the shell goes up, across the frame: -1 hard left, +1 hard
        // right. `randomLaunch` ignores it and picks a spot per launch.
        // 0 one shell, 1 volley, 2 full show — indexes LaunchPool.displays.
        property int displaySize: 0
        property real launchX: 0
        property bool randomLaunch: false
        // What the marked block in bindings.lua was last written with. The
        // block itself is the real state; this is how the card knows what to
        // show without parsing Lua.
        property string shortcut: ""
    }

    // ------------------------------------------------------------------ hotkey
    // A hotkey is a fixed shape: one or more modifiers, then exactly one key.
    // The value ends up inside a Lua string in bindings.lua, so anything not of
    // that shape is refused rather than escaped — there is no reason for it to
    // exist. fireworks-ctl.sh checks the same shape again before it writes.
    readonly property var shortcutPattern:
        /^(SUPER|CTRL|ALT|SHIFT)( \+ (SUPER|CTRL|ALT|SHIFT))* \+ ([A-Z0-9]|F([1-9]|1[0-2])|SPACE|RETURN|ENTER|TAB|ESCAPE|BACKSPACE|DELETE|INSERT|HOME|END|PAGE_UP|PAGE_DOWN|UP|DOWN|LEFT|RIGHT|COMMA|PERIOD|SLASH|MINUS|EQUAL|SEMICOLON|APOSTROPHE|GRAVE|BRACKETLEFT|BRACKETRIGHT|BACKSLASH)$/

    property bool capturing: false
    property string captureNote: ""

    readonly property string shortcut:
        root.validShortcut(preferences.shortcut) ? preferences.shortcut : ""

    function validShortcut(s) {
        return typeof s === "string" && s.length <= 40 && root.shortcutPattern.test(s)
    }

    // Recording a key is the whole gesture — you pressed "record", then pressed
    // the keys — so the binding is written there and then rather than behind a
    // second Apply. Everything else on this card is the plugin's own INI and
    // saves as you touch it; the hotkey is the one setting that reaches outside,
    // and it reaches exactly one marked block.
    function captureKey(event) {
        if (event.key === Qt.Key_Escape) { root.capturing = false; root.captureNote = ""; return }
        var mods = []
        if (event.modifiers & Qt.MetaModifier) mods.push("SUPER")
        if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
        if (event.modifiers & Qt.AltModifier) mods.push("ALT")
        if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")
        var name = ""
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) name = String.fromCharCode(65 + (event.key - Qt.Key_A))
        else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) name = String.fromCharCode(48 + (event.key - Qt.Key_0))
        else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F12) name = "F" + (event.key - Qt.Key_F1 + 1)
        if (name === "") return
        if (mods.length === 0) { root.captureNote = "Add a modifier — SUPER, CTRL or ALT"; return }
        root.bindShortcut(mods.join(" + ") + " + " + name)
    }

    function bindShortcut(keys) {
        if (!root.validShortcut(keys)) return
        preferences.shortcut = keys
        root.runCtl(["bind", keys], "Bound. Written to ~/.config/hypr/bindings.lua.")
    }

    function clearShortcut() {
        preferences.shortcut = ""
        root.runCtl(["unbind"], "Cleared. The block is gone from ~/.config/hypr/bindings.lua.")
    }

    function runCtl(args, okNote) {
        root.capturing = false
        root.captureNote = "Writing…"
        hotkeyCtl.okNote = okNote
        hotkeyCtl.running = false
        hotkeyCtl.command = ["bash", root.pluginDir + "/fireworks-ctl.sh"].concat(args)
        hotkeyCtl.running = true
    }

    // execDetached would have the card report a success it cannot know about.
    // fireworks-ctl.sh refuses to touch a bindings.lua it does not recognise —
    // missing, not ours, or with its marked block already damaged — and says
    // why on stderr. Running it as a Process is how that reason reaches the
    // person who needs it, instead of a cheerful "Bound." over a file that was
    // never written. Silence on stderr is the success case.
    Process {
        id: hotkeyCtl
        property string okNote: ""
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var why = String(text || "").trim()
                root.captureNote = why !== "" ? why : hotkeyCtl.okNote
            }
        }
    }

    // ------------------------------------------------------------------- show
    Native.ShowDirector {
        id: director
        audioEnabled: false
    }

    LaunchPool {
        id: launches
        sound: preferences.sound
        volume: preferences.volume
        shellCount: director.shellNames.length
    }

    // One layer per monitor. No keyboard focus and an empty input region, so
    // the show plays in front of everything without catching a single click.
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
                Repeater {
                    model: launches.capacity
                    delegate: Loader {
                        required property int index
                        readonly property var slot: launches.slot(index)
                        anchors.fill: parent
                        active: slot !== null && slot.ready
                        sourceComponent: Native.FireworksView {
                            time: slot.controller.time
                            seed: slot.controller.seed
                            shellType: slot.controller.shellType
                            originX: slot.controller.originX
                            bloom: preferences.bloom
                            exposure: preferences.exposure
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- components
    component SettingLabel: Text {
        textFormat: Text.PlainText
        width: root.labelWidth
        anchors.verticalCenter: parent.verticalCenter
        color: root.foreground
        opacity: 0.75
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
    }

    component SettingPill: Rectangle {
        id: pill
        property string label
        property bool active: false
        signal picked()
        width: pillLabel.width + Style.spacing.lg * 2
        height: Style.space(32)
        radius: root.cornerRadius
        color: pill.active ? root.selectedBackground : "transparent"
        border.color: pill.active ? root.foreground : root.border
        border.width: pill.active ? 1 : 0

        Text {
            id: pillLabel
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: pill.label
            color: pill.active ? root.selectedText : root.foreground
            opacity: pill.active ? 1 : 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.picked()
        }
    }

    component SettingCaption: Text {
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: root.foreground
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
    }

    // A labelled slider row. The three of them differ only in range and in
    // where the value goes, so the row itself is written once.
    component SettingSlider: Row {
        id: sliderRow
        property alias label: rowLabel.text
        property real minimum: 0
        property real maximum: 1
        property real value: 0
        signal moved(real value)
        spacing: Style.spacing.md
        SettingLabel { id: rowLabel }
        PanelSlider {
            // PanelSlider is a bare Item: it has no implicit height of its
            // own, so an unsized one collapses to nothing.
            width: Style.space(240)
            height: Style.space(32)
            minimum: sliderRow.minimum
            maximum: sliderRow.maximum
            value: sliderRow.value
            step: (sliderRow.maximum - sliderRow.minimum) / 40
            onMoved: function(v) { sliderRow.moved(v) }
        }
    }

    // -------------------------------------------------------- the settings card
    PanelWindow {
        id: settingsPanel
        visible: root.settingsOpen
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        WlrLayershell.namespace: "omarchy-fireworks-settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        Rectangle { anchors.fill: parent; color: root.scrim }
        MouseArea { anchors.fill: parent; onClicked: root.closeSettings() }

        BorderSurface {
            id: card
            width: Math.min(Style.space(520), settingsPanel.width - Style.gapsOut * 2)
            height: Math.min(form.implicitHeight + card.contentTopInset + card.contentBottomInset,
                             settingsPanel.height - Style.gapsOut * 2)
            anchors.centerIn: parent
            color: root.background
            borderSpec: root.borderSpec
            radius: root.cornerRadius
            padding: Style.space(24)

            MouseArea { anchors.fill: parent; onClicked: {} }

            // BorderSurface exposes its insets but does not apply them —
            // content has to inset itself or it renders under the border.
            Item {
                anchors.fill: parent
                anchors.topMargin: card.contentTopInset
                anchors.rightMargin: card.contentRightInset
                anchors.bottomMargin: card.contentBottomInset
                anchors.leftMargin: card.contentLeftInset
                focus: true

                // The card holds exclusive keyboard focus while it is up, on a
                // desktop driven from the keyboard — so the three things it can
                // do are reachable without the mouse. R matters most: it starts
                // the hotkey recording that the next keypress lands in.
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                    if (root.capturing) {
                        root.captureKey(event)
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Escape) root.closeSettings()
                    else if (event.key === Qt.Key_R) { root.capturing = true; root.captureNote = "" }
                    else if (event.key === Qt.Key_Space
                             || event.key === Qt.Key_Return
                             || event.key === Qt.Key_Enter) root.launch()
                    event.accepted = true
                }

                Column {
                    id: form
                    width: parent.width
                    spacing: Style.spacing.xl

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: "✦ Fireworks"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.heading
                    }

                    SettingCaption {
                        width: parent.width
                        opacity: 0.75
                        font.pixelSize: Style.font.body
                        // The selected shell, not the one the director last
                        // played: a named-shell payload plays a shell for one
                        // launch without changing the saved preference.
                        text: director.shellDescriptions[preferences.shellType] || ""
                    }

                    Row {
                        width: parent.width
                        spacing: Style.spacing.md
                        SettingLabel {
                            text: "Shell"
                            // The pills wrap to three rows; centred against all
                            // of them the label floats beside the middle one.
                            anchors.verticalCenter: undefined
                            anchors.top: parent.top
                            anchors.topMargin: Style.space(8)
                        }
                        Flow {
                            // Four names of this length do not fit one line on a
                            // narrow panel, and a Row would draw the last one off
                            // the edge. Measured from the form, whose width is
                            // already inside the card's border and padding.
                            width: form.width - root.labelWidth - Style.spacing.md
                            spacing: Style.space(4)
                            Repeater {
                                model: director.shellNames
                                SettingPill {
                                    required property int index
                                    required property string modelData
                                    label: modelData
                                    active: preferences.shellType === index
                                    onPicked: preferences.shellType = index
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Style.spacing.md

                        SettingLabel { text: "Hotkey" }

                        Rectangle {
                            width: Style.space(190)
                            height: Style.space(32)
                            radius: root.cornerRadius
                            color: "transparent"
                            border.color: root.border
                            border.width: 1

                            Text {
                                textFormat: Text.PlainText
                                anchors.centerIn: parent
                                text: root.capturing ? "press your keys…"
                                    : (root.shortcut !== "" ? root.shortcut : "none set")
                                color: root.foreground
                                opacity: root.capturing || root.shortcut === "" ? 0.6 : 1
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                            }
                        }

                        SettingPill {
                            label: root.capturing ? "cancel" : "record (R)"
                            active: true
                            onPicked: { root.capturing = !root.capturing; root.captureNote = "" }
                        }

                        SettingPill {
                            label: "clear"
                            visible: root.shortcut !== ""
                            onPicked: root.clearShortcut()
                        }
                    }

                    SettingCaption {
                        width: parent.width
                        visible: root.captureNote !== "" || root.capturing
                        text: root.captureNote !== "" ? root.captureNote
                            : "Pick a combination nothing else uses — an already-taken key will trigger its old action instead of reaching this card."
                    }

                    Row {
                        spacing: Style.spacing.md
                        SettingLabel { text: "Sound" }
                        Row {
                            spacing: Style.space(4)
                            anchors.verticalCenter: parent.verticalCenter
                            SettingPill {
                                label: "boom and crackle"
                                active: preferences.sound
                                onPicked: preferences.sound = true
                            }
                            SettingPill {
                                label: "silent"
                                active: !preferences.sound
                                onPicked: preferences.sound = false
                            }
                        }
                    }

                    Row {
                        spacing: Style.spacing.md
                        SettingLabel { text: "Display" }
                        Row {
                            spacing: Style.space(4)
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: launches.displays
                                SettingPill {
                                    required property int index
                                    required property var modelData
                                    label: modelData.name
                                    active: preferences.displaySize === index
                                    onPicked: preferences.displaySize = index
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Style.spacing.md
                        SettingLabel { text: "Launch" }
                        Item {
                            // Fixed width whichever control is showing, so the
                            // random pill beside it does not jump when toggled.
                            width: Style.space(240)
                            height: Style.space(32)
                            anchors.verticalCenter: parent.verticalCenter
                            PanelSlider {
                                anchors.fill: parent
                                visible: !preferences.randomLaunch
                                minimum: -1
                                maximum: 1
                                step: 0.05
                                value: preferences.launchX
                                onMoved: function(v) { preferences.launchX = v }
                            }
                            Text {
                                textFormat: Text.PlainText
                                anchors.verticalCenter: parent.verticalCenter
                                visible: preferences.randomLaunch
                                text: "a fresh spot each launch"
                                color: root.foreground
                                opacity: 0.6
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                            }
                        }
                        SettingPill {
                            label: "random"
                            active: preferences.randomLaunch
                            onPicked: preferences.randomLaunch = !preferences.randomLaunch
                        }
                    }

                    SettingSlider {
                        label: "Volume"
                        visible: preferences.sound
                        value: preferences.volume
                        onMoved: function(v) { preferences.volume = v }
                    }

                    SettingSlider {
                        label: "Glow"
                        maximum: 2
                        value: preferences.bloom
                        onMoved: function(v) { preferences.bloom = v }
                    }

                    SettingSlider {
                        label: "Light"
                        minimum: 0.25
                        maximum: 1.8
                        value: preferences.exposure
                        onMoved: function(v) { preferences.exposure = v }
                    }

                    SettingCaption {
                        width: parent.width
                        opacity: 0.55
                        text: "Space launches, Escape closes. A volley or a full show sends several shells up from one trigger, spread so no more than four are ever in the air at once. Shell, sound, and look save as you set them. Recording a hotkey also rewrites Fireworks' own marked block in ~/.config/hypr/bindings.lua — nothing else in that file is touched."
                    }

                    Row {
                        spacing: Style.spacing.md
                        SettingPill {
                            label: "✦ launch now"
                            active: true
                            onPicked: root.launch()
                        }
                        SettingPill {
                            label: "Done"
                            onPicked: root.closeSettings()
                        }
                    }
                }
            }
        }
    }
}
