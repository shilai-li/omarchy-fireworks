import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "native" as Native
import "."

// Fireworks — authored shells fired over the desktop.
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
    // its own; only the fireworks themselves are authored. These are the same
    // derivations the Studio Effects panel makes, from the same tokens, so the
    // two cards read as one family: cards are a tint of the text colour laid
    // over the panel, and whatever is switched on is filled with the accent.
    readonly property var bar: barWidget ? barWidget.bar : null
    readonly property color contentForeground: bar ? bar.foreground : Commons.Color.foreground
    readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property color surface: Commons.Color.popups.background
    readonly property color dim: Qt.darker(contentForeground, 1.5)
    readonly property color accentColor: Style.selectedStateColor(contentForeground, Commons.Color.accent)
    readonly property color hoverFill: Style.hoverFillFor(contentForeground, Commons.Color.accent)
    readonly property color selectedFill: Style.selectedFillFor(contentForeground, Commons.Color.accent)
    readonly property color cardFill: Util.alpha(contentForeground, 0.06)
    readonly property color quietFill: Util.alpha(contentForeground, 0.12)
    readonly property color onFill: Commons.Color.accent
    // The theme decides whether anything is round. Square corners stay square;
    // rounded ones grow a step, because the cards are larger than a row.
    readonly property bool rounded: Style.cornerRadius > 0
    readonly property int cardRadius: rounded ? Math.max(Style.cornerRadius * 2, Style.space(12)) : 0
    readonly property int rowHeight: Math.max(Style.space(30), Style.font.body + Style.space(16))

    // -------------------------------------------------------------- lifecycle
    readonly property var barWidget: FireworksState.barWidget
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
        root.cursorKey = "shell"
        root.cursorActive = true
        root.hoverShell = -1
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

    // Inspect actual live controllers rather than inferring them from settings.
    // Called through `omarchy-shell shell call shilai_li.fireworks status ""`.
    function status(arg) {
        var slots = []
        for (var i = 0; i < launches.capacity; ++i) {
            var entry = launches.slot(i)
            if (!entry || !entry.active) continue
            slots.push({ serial: entry.serial, shell: entry.controller.shellName,
                         shellType: entry.controller.shellType, time: entry.controller.time,
                         originX: entry.controller.originX })
        }
        return JSON.stringify({ display: launches.displays[preferences.displaySize].name,
                                volleyMixed: launches.displays[1].mixed,
                                shellCount: launches.shellCount, scheduled: launches.scheduled,
                                fullShowInterval: preferences.fullShowInterval,
                                nextStep: launches.pendingStep,
                                fullShowLifts: launches.displays[2].lifts,
                                slots: slots })
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
        property real fullShowInterval: 3.0
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
    // Set when the R key starts a recording. The catcher leaves a text key
    // unhandled, so that same key press reaches the recorder a moment later —
    // and would be taken for the combination. It is the gesture, not the keys.
    property bool captureFresh: false
    onCapturingChanged: if (!capturing) captureFresh = false

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
        director: Component { Native.ShowDirector {} }
        sound: preferences.sound
        volume: preferences.volume
        shellCount: director.shellNames.length
        fullShowInterval: preferences.fullShowInterval
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

    // ------------------------------------------------------------------ cursor
    // The cursor is a name rather than an index: rows come and go as the
    // display and the sound change, and a name still points at the same row.
    // Like every panel it follows the pointer as well as the keys, so there is
    // only ever one highlight on screen.
    property string cursorKey: "shell"
    property bool cursorActive: false
    // The shell row under the pointer, or -1. The chosen shell is highlighted
    // when the keys have the cursor; the hovered one when the pointer does.
    property int hoverShell: -1
    // Enter and Space both arrive as "activate"; only Enter acts on a switch.
    property bool viaEnter: false
    property var cursorItems: ({})

    readonly property var rowKeys: {
        var keys = ["shell", "display"]
        if (preferences.displaySize === 2) keys.push("interval")
        keys.push("random")
        if (!preferences.randomLaunch) keys.push("position")
        if (preferences.sound) keys.push("volume")
        keys.push("glow", "light")
        return keys
    }

    function clamp(value, low, high) { return Math.max(low, Math.min(high, value)) }
    function hundredths(value) { return Math.round(value * 100) / 100 }
    function title(text) { return text.charAt(0).toUpperCase() + text.slice(1) }

    function moveCursor(delta) {
        root.cursorActive = true
        root.hoverShell = -1
        var i = root.rowKeys.indexOf(root.cursorKey)
        i = i < 0 ? 0 : root.clamp(i + delta, 0, root.rowKeys.length - 1)
        root.cursorKey = root.rowKeys[i]
        Qt.callLater(root.revealCursor)
    }

    // Left and right adjust whatever the cursor is on, by the same steps a
    // drag snaps to. The shell list wraps: it is a ring of sixteen, not a range.
    function adjust(direction) {
        root.cursorActive = true
        switch (root.cursorKey) {
        case "shell":
            var count = director.shellNames.length
            preferences.shellType = (preferences.shellType + direction + count) % count
            root.hoverShell = -1
            break
        case "display":
            preferences.displaySize = root.clamp(preferences.displaySize + direction, 0, launches.displays.length - 1)
            break
        case "interval":
            preferences.fullShowInterval = root.clamp(preferences.fullShowInterval + direction * 0.5, 3, 12)
            break
        case "random":
            preferences.randomLaunch = direction > 0
            break
        case "position":
            preferences.launchX = root.hundredths(root.clamp(preferences.launchX + direction * 0.1, -1, 1))
            break
        case "volume":
            preferences.volume = root.hundredths(root.clamp(preferences.volume + direction * 0.05, 0, 1))
            break
        case "glow":
            preferences.bloom = root.hundredths(root.clamp(preferences.bloom + direction * 0.1, 0, 2))
            break
        case "light":
            preferences.exposure = root.hundredths(root.clamp(preferences.exposure + direction * 0.05, 0.25, 1.8))
            break
        }
    }

    // Space launches wherever the cursor is. Enter does too, except on the one
    // switch, where it switches — as Enter does on every other panel's rows.
    function activate(viaEnter) {
        if (viaEnter && root.cursorActive && root.cursorKey === "random")
            preferences.randomLaunch = !preferences.randomLaunch
        else
            root.launch()
    }

    function handleTextKey(text, modifiers) {
        if (modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        var key = String(text).toLowerCase()
        if (key === "r") { root.capturing = true; root.captureNote = ""; root.captureFresh = true }
        else if (key === "s") preferences.sound = !preferences.sound
        else if (key === "c" && root.shortcut !== "") root.clearShortcut()
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.barWidget, direction)
        return false
    }

    // The card is a Flickable so a short screen can still reach every row; the
    // keys move the cursor, so the cursor has to be kept in view.
    function revealCursor() {
        var item = root.cursorItems[root.cursorKey]
        if (!item || scroller.contentHeight <= scroller.height) return
        var top = item.mapToItem(scroller.contentItem, 0, 0).y
        var margin = Style.space(4)
        if (top < scroller.contentY)
            scroller.contentY = Math.max(0, top - margin)
        else if (top + item.height > scroller.contentY + scroller.height)
            scroller.contentY = Math.min(scroller.contentHeight - scroller.height,
                                         top + item.height - scroller.height + margin)
    }

    // What the keys do from here, as key and meaning.
    readonly property var keyHints: {
        if (root.capturing) return [["keys", "record"], ["esc", "cancel"]]
        var hints = [["↑↓", "move"], ["←→", "adjust"]]
        hints.push(root.cursorActive && root.cursorKey === "random" ? ["enter", "switch"] : ["space", "launch"])
        hints.push(["r", "hotkey"], ["s", "sound"])
        if (root.shortcut !== "") hints.push(["c", "clear"])
        hints.push(["esc", "close"])
        return hints
    }

    // Shown under the tiles for a hotkey in progress or its last result.
    readonly property string hotkeyNote: root.captureNote !== "" ? root.captureNote
        : root.capturing ? "Press the combination you want. Pick keys nothing else uses — a taken key runs its old action instead of reaching this card."
        : ""

    // ------------------------------------------------------------- components
    component Label: Text {
        textFormat: Text.PlainText
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
    }

    component Card: Rectangle {
        width: parent ? parent.width : 0
        radius: root.cardRadius
        color: root.cardFill
    }

    // A round button face: the accent when on, a quiet tint when off. Square on
    // a theme with square corners.
    component Disc: Rectangle {
        id: disc
        property bool on: false
        property string glyph: ""
        property real size: Style.space(38)
        width: size
        height: size
        radius: root.rounded ? size / 2 : 0
        color: disc.on ? root.onFill : root.quietFill

        Behavior on color { ColorAnimation { duration: Style.duration(120) } }

        Label {
            anchors.centerIn: parent
            text: disc.glyph
            color: disc.on ? root.surface : root.contentForeground
            font.pixelSize: Math.round(disc.size * 0.46)
        }
    }

    // A small label in the header, beside the status.
    component Pill: Rectangle {
        property alias text: pillText.text
        width: pillText.implicitWidth + Style.space(14)
        height: pillText.implicitHeight + Style.space(6)
        radius: root.rounded ? height / 2 : 0
        color: root.quietFill

        Label {
            id: pillText
            anchors.centerIn: parent
            color: root.dim
            font.pixelSize: Style.font.caption
            font.bold: true
        }
    }

    // Sound and the hotkey: the two things the show reaches outside itself for,
    // an audio stream and a line in the compositor's config. Peers of each
    // other, so they sit side by side under the card that says what will play.
    component Tile: Rectangle {
        id: tile
        property string label: ""
        property string status: ""
        property string glyph: ""
        property bool on: false
        property bool clearable: false
        signal activated()
        signal cleared()

        height: Style.space(12) * 2 + Style.space(38)
        radius: root.cardRadius
        color: tileMouse.containsMouse ? Util.alpha(root.contentForeground, 0.10) : root.cardFill

        Behavior on color { ColorAnimation { duration: Style.duration(60) } }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.activated()
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(12)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            Disc {
                on: tile.on
                glyph: tile.glyph
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(38) - Style.space(22)
                spacing: Style.space(1)

                Label {
                    width: parent.width
                    text: tile.label
                    font.bold: true
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: tile.status
                    color: root.dim
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideMiddle
                }
            }
        }

        // Clearing is rarer than recording, so it is a small button in the
        // corner of the tile rather than a tile of its own. The corner keeps it
        // clear of the status line, which a long combination needs in full.
        MouseArea {
            id: clearArea
            visible: tile.clearable
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.top: parent.top
            anchors.topMargin: Style.space(6)
            width: Style.space(22)
            height: width
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.cleared()

            Rectangle {
                anchors.fill: parent
                radius: root.rounded ? width / 2 : 0
                color: clearArea.containsMouse ? root.quietFill : "transparent"
            }
            Label {
                anchors.centerIn: parent
                text: "\u{F0156}"
                color: root.dim
                font.pixelSize: Style.font.bodySmall
            }
        }
    }

    // One shell in the list. Sixteen of the same thing are a grouped list with
    // one row per item, and the chosen one carries the accent.
    component ShellRow: CursorSurface {
        id: shellRow
        required property int index
        required property string modelData
        readonly property bool chosen: preferences.shellType === shellRow.index

        width: ListView.view ? ListView.view.width : 0
        height: root.rowHeight + Style.space(4)
        radius: Math.max(0, root.cardRadius - Style.space(4))
        hasCursor: root.cursorActive && root.cursorKey === "shell"
                   && (root.hoverShell >= 0 ? root.hoverShell === shellRow.index : shellRow.chosen)
        foreground: root.contentForeground
        accent: Commons.Color.accent
        fill: root.hoverFill
        currentFill: root.selectedFill

        PanelSeparator {
            visible: shellRow.index > 0
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: Style.space(44)
            width: parent.width - Style.space(44)
            foreground: root.contentForeground
            strength: 0.08
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse) {
                    root.cursorActive = true
                    root.cursorKey = "shell"
                    root.hoverShell = shellRow.index
                } else if (root.hoverShell === shellRow.index) {
                    root.hoverShell = -1
                }
            }
            onClicked: preferences.shellType = shellRow.index
        }

        Rectangle {
            id: shellIcon
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            height: width
            radius: root.rounded ? Style.space(7) : 0
            color: shellRow.chosen ? root.onFill : root.quietFill

            Behavior on color { ColorAnimation { duration: Style.duration(120) } }

            Label {
                anchors.centerIn: parent
                text: "\u{F0D72}"
                color: shellRow.chosen ? root.surface : root.dim
                font.pixelSize: Style.font.icon
            }
        }
        Label {
            anchors.left: shellIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: shellCheck.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: shellRow.modelData
            font.bold: shellRow.chosen
            color: shellRow.chosen ? root.contentForeground : root.dim
            elide: Text.ElideRight
        }
        Label {
            id: shellCheck
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: shellRow.chosen ? "\u{F012C}" : ""
            color: root.accentColor
            font.pixelSize: Style.font.icon
        }
    }

    // The switch row. The row owns the click, so the switch itself is inert.
    component SwitchRow: CursorSurface {
        id: switchRow
        property string key: ""
        property string label: ""
        property string glyph: ""
        property bool checked: false
        signal toggled()

        width: parent ? parent.width : 0
        height: root.rowHeight + Style.space(4)
        radius: Math.max(0, root.cardRadius - Style.space(4))
        hasCursor: root.cursorActive && root.cursorKey === switchRow.key
        foreground: root.contentForeground
        accent: Commons.Color.accent
        fill: root.hoverFill
        currentFill: root.selectedFill

        Component.onCompleted: root.cursorItems[switchRow.key] = switchRow

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (containsMouse) {
                root.cursorActive = true
                root.cursorKey = switchRow.key
            }
            onClicked: switchRow.toggled()
        }

        Label {
            id: switchGlyph
            anchors.left: parent.left
            anchors.leftMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(18)
            text: switchRow.glyph
            color: root.dim
            font.pixelSize: Style.font.icon
        }
        Label {
            anchors.left: switchGlyph.right
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: switchRow.label
        }
        ToggleSwitch {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            interactive: false
            trackHeight: Style.space(18)
            checked: switchRow.checked
            foreground: root.contentForeground
        }
    }

    // A filling capsule: the part up to the value is solid, with the setting's
    // glyph cut into its left end. It is dragged to the same steps the arrow
    // keys take, and draws where the pointer is while it is held rather than
    // waiting for the setting to be written back.
    component Capsule: Item {
        id: capsule
        property string glyph: ""
        property real minimum: 0
        property real maximum: 1
        property real step: 0.05
        property real value: 0
        property real live: 0
        property bool dragging: false
        signal moved(real value)
        readonly property real progress: Math.max(0, Math.min(1,
            ((capsule.dragging ? capsule.live : capsule.value) - capsule.minimum)
            / Math.max(0.0001, capsule.maximum - capsule.minimum)))

        width: parent ? parent.width : 0
        height: Style.space(30)

        function snap(v) {
            var stepped = capsule.minimum + Math.round((v - capsule.minimum) / capsule.step) * capsule.step
            return Math.round(root.clamp(stepped, capsule.minimum, capsule.maximum) * 10000) / 10000
        }
        function apply(next) {
            if (next === capsule.live) return
            capsule.live = next
            capsule.moved(next)
        }

        Rectangle {
            id: capsuleTrack
            anchors.fill: parent
            radius: root.rounded ? height / 2 : 0
            color: root.quietFill
        }
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: capsule.height + (capsule.width - capsule.height) * capsule.progress
            radius: capsuleTrack.radius
            color: root.contentForeground

            Behavior on width {
                enabled: !capsule.dragging
                NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
            }
        }
        Label {
            x: Math.round((capsule.height - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            text: capsule.glyph
            color: root.surface
            font.pixelSize: Style.font.body
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            function valueAt(x) {
                var span = Math.max(1, capsule.width - capsule.height)
                var p = root.clamp((x - capsule.height / 2) / span, 0, 1)
                return capsule.snap(capsule.minimum + p * (capsule.maximum - capsule.minimum))
            }

            onPressed: function (mouse) {
                capsule.live = capsule.value
                capsule.dragging = true
                capsule.apply(valueAt(mouse.x))
            }
            onPositionChanged: function (mouse) {
                if (capsule.dragging) capsule.apply(valueAt(mouse.x))
            }
            onReleased: capsule.dragging = false
            onCanceled: capsule.dragging = false
            onWheel: function (wheel) {
                capsule.moved(capsule.snap(capsule.value + (wheel.angleDelta.y > 0 ? 1 : -1) * capsule.step))
            }
        }
    }

    // A few values that are choices, not amounts, so three buttons rather than
    // a slider pretending to be continuous.
    component Segments: Rectangle {
        id: segments
        property var labels: []
        property int current: 0
        signal picked(int index)

        width: parent ? parent.width : 0
        height: Style.space(30)
        radius: root.rounded ? Style.space(10) : 0
        color: root.quietFill

        Row {
            anchors.fill: parent
            anchors.margins: Style.space(3)

            Repeater {
                model: segments.labels

                Rectangle {
                    id: segment
                    required property int index
                    required property string modelData
                    readonly property bool on: segments.current === segment.index
                    width: parent.width / Math.max(1, segments.labels.length)
                    height: parent.height
                    radius: root.rounded ? Style.space(8) : 0
                    color: segment.on ? Util.alpha(root.contentForeground, 0.2) : "transparent"

                    Behavior on color { ColorAnimation { duration: Style.duration(120) } }

                    Label {
                        anchors.centerIn: parent
                        text: segment.modelData
                        color: segment.on ? root.contentForeground : root.dim
                        font.bold: segment.on
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: segments.picked(segment.index)
                    }
                }
            }
        }
    }

    // A setting: its name and value over the control that changes it. The
    // arrows on the value appear under the cursor, so it is discoverable that
    // the row is adjusted rather than chosen.
    component ParamBlock: CursorSurface {
        id: block
        property string key: ""
        property string title: ""
        property string valueText: ""
        default property alias body: bodySlot.data

        width: parent ? parent.width : 0
        height: blockColumn.implicitHeight + Style.space(14)
        radius: Math.max(0, root.cardRadius - Style.space(2))
        hasCursor: root.cursorActive && root.cursorKey === block.key
        foreground: root.contentForeground
        accent: Commons.Color.accent
        fill: root.hoverFill
        currentFill: root.selectedFill

        Component.onCompleted: root.cursorItems[block.key] = block

        HoverHandler {
            onHoveredChanged: if (hovered) {
                root.cursorActive = true
                root.cursorKey = block.key
            }
        }

        Column {
            id: blockColumn
            x: Style.space(6)
            y: Style.space(7)
            width: parent.width - Style.space(12)
            spacing: Style.space(6)

            Item {
                width: parent.width
                height: blockTitle.implicitHeight

                Label {
                    id: blockTitle
                    x: Style.space(4)
                    text: block.title
                    color: root.dim
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                }
                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(4)
                    text: block.hasCursor ? "‹ " + block.valueText + " ›" : block.valueText
                    color: block.hasCursor ? root.accentColor : root.dim
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                }
            }
            Item {
                id: bodySlot
                width: parent.width
                height: childrenRect.height
            }
        }
    }

    component KeyHint: Row {
        id: keyHint
        required property var modelData
        spacing: Style.space(4)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: keyText.implicitWidth + Style.space(8)
            height: keyText.implicitHeight + Style.space(2)
            radius: root.rounded ? Style.space(4) : 0
            color: root.quietFill

            Label {
                id: keyText
                anchors.centerIn: parent
                text: keyHint.modelData[0]
                font.pixelSize: Style.font.caption
                font.bold: true
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: keyHint.modelData[1]
            color: root.dim
            font.pixelSize: Style.font.caption
        }
    }

    // ---------------------------------------------------------------- the card
    // Settings use the same bar-anchored popup as other Omarchy plugins, laid
    // out the way the Studio Effects panel is: a header that states facts, one
    // card that says what will happen, tiles for the services the show reaches,
    // a grouped list for the shells, and capsules for amounts. A row appears
    // only while it applies — no volume with the sound off, no interval unless
    // a full show is chosen, no position slider for a random one.
    KeyboardPanel {
        id: settingsPanel
        anchorItem: root.barWidget ? root.barWidget.panelAnchor : null
        bar: root.barWidget ? root.barWidget.bar : null
        owner: root.barWidget || root
        open: root.settingsOpen && root.barWidget !== null
        focusTarget: keyCatcher
        contentWidth: fittedContentWidth(Style.space(380))
        contentHeight: fittedContentHeight(form.implicitHeight)

        Item {
            id: keysHost
            anchors.fill: parent

            // While a hotkey is being recorded the catcher stands aside, so
            // every key — F-keys and bare modifiers included, which carry no
            // text — reaches this handler instead of triggering the card.
            Keys.onPressed: function(event) {
                if (!root.capturing) return
                event.accepted = true
                if (root.captureFresh) { root.captureFresh = false; return }
                root.captureKey(event)
            }

            PanelKeyCatcher {
                id: keyCatcher
                anchors.fill: parent
                blocked: root.capturing

                onCloseRequested: root.closeSettings()
                onTabRequested: function(direction) { root.switchPanel(direction) }
                onTextKey: function(text, modifiers) { root.handleTextKey(text, modifiers) }
                onReturnRequested: root.viaEnter = true
                onActivateRequested: {
                    var enter = root.viaEnter
                    root.viaEnter = false
                    root.activate(enter)
                }
                onMoveRequested: function(dx, dy) {
                    if (dy !== 0) root.moveCursor(dy)
                    else if (dx !== 0) root.adjust(dx > 0 ? 1 : -1)
                }

                Flickable {
                    id: scroller
                    anchors.fill: parent
                    contentHeight: form.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Column {
                        id: form
                        width: scroller.width
                        spacing: Style.space(10)

                        // ---- Title, and whether anything is in the air.
                        Item {
                            width: parent.width
                            height: Math.max(titleRow.implicitHeight, statusPill.height)

                            Row {
                                id: titleRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.space(7)

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✦"
                                    color: root.flying ? Commons.Color.accent : root.dim
                                    font.pixelSize: Style.font.icon
                                }
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Fireworks"
                                    font.bold: true
                                    font.pixelSize: Style.font.subtitle
                                }
                            }

                            Pill {
                                anchors.right: statusPill.left
                                anchors.rightMargin: Style.space(6)
                                anchors.verticalCenter: parent.verticalCenter
                                text: director.shellNames.length + " shells"
                            }

                            Rectangle {
                                id: statusPill
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: statusRow.implicitWidth + Style.space(14)
                                height: statusText.implicitHeight + Style.space(6)
                                radius: root.rounded ? height / 2 : 0
                                color: root.flying ? Util.alpha(Commons.Color.accent, 0.16) : root.quietFill

                                Row {
                                    id: statusRow
                                    anchors.centerIn: parent
                                    spacing: Style.space(5)

                                    Rectangle {
                                        visible: root.flying
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Style.space(6)
                                        height: width
                                        radius: width / 2
                                        color: Commons.Color.accent
                                    }
                                    Label {
                                        id: statusText
                                        text: root.flying ? "FLYING" : "READY"
                                        color: root.flying ? root.accentColor : root.dim
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }
                                }
                            }
                        }

                        // ---- What will go up. The disc launches it; the name and
                        //      description are those of the selected shell, not the
                        //      one the director last played — a named-shell payload
                        //      plays a shell for one launch without changing the
                        //      saved preference.
                        Card {
                            height: Math.max(Style.space(46), heroText.implicitHeight) + Style.space(24)

                            Disc {
                                id: heroDisc
                                anchors.left: parent.left
                                anchors.leftMargin: Style.space(12)
                                anchors.verticalCenter: parent.verticalCenter
                                size: Style.space(46)
                                on: root.flying
                                glyph: "\u{F14DE}"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.launch()
                                }
                            }
                            Column {
                                id: heroText
                                anchors.left: heroDisc.right
                                anchors.leftMargin: Style.space(12)
                                anchors.right: parent.right
                                anchors.rightMargin: Style.space(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.space(2)

                                Label {
                                    width: parent.width
                                    text: director.shellNames[preferences.shellType] || ""
                                    font.bold: true
                                    font.pixelSize: Style.font.subtitle
                                    elide: Text.ElideRight
                                }
                                Label {
                                    width: parent.width
                                    text: director.shellDescriptions[preferences.shellType] || ""
                                    color: root.dim
                                    font.pixelSize: Style.font.bodySmall
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        // ---- The two things the show reaches outside itself for.
                        Row {
                            width: parent.width
                            spacing: Style.space(10)

                            Tile {
                                width: (parent.width - parent.spacing) / 2
                                label: "Sound"
                                glyph: preferences.sound ? "\u{F057E}" : "\u{F0581}"
                                on: preferences.sound
                                status: preferences.sound ? "On" : "Silent"
                                onActivated: preferences.sound = !preferences.sound
                            }
                            Tile {
                                width: (parent.width - parent.spacing) / 2
                                label: "Hotkey"
                                glyph: "\u{F030C}"
                                on: root.capturing
                                clearable: root.shortcut !== "" && !root.capturing
                                status: root.capturing ? "Press keys…"
                                      : root.shortcut !== "" ? root.shortcut.replace(/ \+ /g, "+")
                                      : "Not set"
                                onActivated: { root.capturing = !root.capturing; root.captureNote = "" }
                                onCleared: root.clearShortcut()
                            }
                        }

                        // The helper's real answer, or the guidance while recording.
                        // Shown rather than swallowed: the alternative is a hotkey
                        // that looks bound and is not.
                        Label {
                            width: parent.width
                            visible: root.hotkeyNote !== ""
                            text: root.hotkeyNote
                            color: root.accentColor
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.WordWrap
                            leftPadding: Style.space(4)
                            rightPadding: Style.space(4)
                        }

                        // ---- The shells, one row each. Sixteen do not fit, so the
                        //      list scrolls and keeps the chosen one in view.
                        Card {
                            id: shellCard
                            height: shellList.height + Style.space(8)
                            Component.onCompleted: root.cursorItems["shell"] = shellCard

                            ListView {
                                id: shellList
                                x: Style.space(4)
                                y: Style.space(4)
                                width: parent.width - Style.space(8)
                                height: Math.min(contentHeight, Math.round((root.rowHeight + Style.space(4)) * 5.5))
                                clip: true
                                interactive: contentHeight > height
                                boundsBehavior: Flickable.StopAtBounds
                                model: director.shellNames
                                delegate: ShellRow {}

                                // Keep the chosen row in view, moving by whole rows so
                                // the top edge stays clean; the half row at the foot
                                // is what says the list scrolls.
                                function showChosen() {
                                    var step = root.rowHeight + Style.space(4)
                                    var rows = Math.max(1, Math.floor(height / step))
                                    var top = Math.round(contentY / step)
                                    var chosen = preferences.shellType
                                    if (chosen < top) top = chosen
                                    else if (chosen > top + rows - 1) top = chosen - rows + 1
                                    contentY = root.clamp(top * step, 0, Math.max(0, contentHeight - height))
                                }

                                Component.onCompleted: showChosen()

                                Connections {
                                    target: preferences
                                    function onShellTypeChanged() { shellList.showChosen() }
                                }
                                Connections {
                                    target: root
                                    function onSettingsOpenChanged() { if (root.settingsOpen) shellList.showChosen() }
                                }
                            }
                        }

                        // ---- What one trigger fires.
                        Column {
                            width: parent.width
                            spacing: Style.space(2)

                            ParamBlock {
                                key: "display"
                                title: "Display"
                                valueText: {
                                    var n = launches.displays[preferences.displaySize].lifts.length
                                    return n + (n === 1 ? " launch" : " launches")
                                }

                                Column {
                                    width: parent.width
                                    spacing: Style.space(6)

                                    Segments {
                                        labels: launches.displays.map(function(d) { return root.title(d.name) })
                                        current: preferences.displaySize
                                        onPicked: function(i) { preferences.displaySize = i }
                                    }
                                    Label {
                                        width: parent.width
                                        text: preferences.displaySize === 0 ? "Fires the selected shell once."
                                            : preferences.displaySize === 1 ? "Four different styles, ending on your shell."
                                            : "Every style once, ending on your shell."
                                        color: root.dim
                                        font.pixelSize: Style.font.caption
                                        wrapMode: Text.WordWrap
                                        leftPadding: Style.space(4)
                                        rightPadding: Style.space(4)
                                    }
                                }
                            }
                            ParamBlock {
                                visible: preferences.displaySize === 2
                                key: "interval"
                                title: "Interval"
                                valueText: preferences.fullShowInterval.toFixed(1) + " s"

                                Capsule {
                                    glyph: "\u{F051B}"
                                    minimum: 3
                                    maximum: 12
                                    step: 0.5
                                    value: preferences.fullShowInterval
                                    onMoved: function(v) { preferences.fullShowInterval = v }
                                }
                            }
                        }

                        // ---- Where it goes up. A random spot ignores the position,
                        //      so the position is hidden while it is on.
                        Card {
                            height: randomRow.height + Style.space(8)

                            SwitchRow {
                                id: randomRow
                                x: Style.space(4)
                                y: Style.space(4)
                                width: parent.width - Style.space(8)
                                key: "random"
                                label: "Random position"
                                glyph: "\u{F049F}"
                                checked: preferences.randomLaunch
                                onToggled: preferences.randomLaunch = !preferences.randomLaunch
                            }
                        }

                        // ---- The look and level of the show.
                        Column {
                            width: parent.width
                            spacing: Style.space(2)

                            ParamBlock {
                                visible: !preferences.randomLaunch
                                key: "position"
                                title: "Launch position"
                                valueText: {
                                    var x = Math.abs(preferences.launchX)
                                    if (x < 0.025) return "centre"
                                    return (preferences.launchX < 0 ? "left " : "right ") + Math.round(x * 100) + "%"
                                }

                                Capsule {
                                    glyph: "\u{F0E73}"
                                    minimum: -1
                                    maximum: 1
                                    step: 0.05
                                    value: preferences.launchX
                                    onMoved: function(v) { preferences.launchX = v }
                                }
                            }
                            ParamBlock {
                                visible: preferences.sound
                                key: "volume"
                                title: "Volume"
                                valueText: Math.round(preferences.volume * 100) + "%"

                                Capsule {
                                    glyph: "\u{F057E}"
                                    value: preferences.volume
                                    onMoved: function(v) { preferences.volume = v }
                                }
                            }
                            ParamBlock {
                                key: "glow"
                                title: "Glow"
                                valueText: Math.round(preferences.bloom * 100) + "%"

                                Capsule {
                                    glyph: "\u{F00B5}"
                                    maximum: 2
                                    value: preferences.bloom
                                    onMoved: function(v) { preferences.bloom = v }
                                }
                            }
                            ParamBlock {
                                key: "light"
                                title: "Light"
                                valueText: Math.round(preferences.exposure * 100) + "%"

                                Capsule {
                                    glyph: "\u{F0599}"
                                    minimum: 0.25
                                    maximum: 1.8
                                    value: preferences.exposure
                                    onMoved: function(v) { preferences.exposure = v }
                                }
                            }
                        }

                        PanelSeparator {
                            width: parent.width
                            foreground: root.contentForeground
                            strength: 0.08
                        }

                        Flow {
                            width: parent.width
                            spacing: Style.space(10)

                            Repeater {
                                model: root.keyHints
                                delegate: KeyHint {}
                            }
                        }
                    }
                }
            }
        }
    }
}
