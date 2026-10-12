import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
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
    // Which install route the cursor is on: 0 prebuilt, 1 build from source.
    // Source is the one that is always on offer, so it is where the cursor starts.
    property int setupIndex: 1
    property bool cursorActive: true
    readonly property string defaultNote: "The native renderer that draws the shells is not set up yet. Choose how to install it."
    property string note: defaultNote
    readonly property bool settingsOpen: setupOpen || (effect.item ? effect.item.settingsOpen : false)
    readonly property bool opened: setupOpen || (effect.item ? effect.item.opened : false)
    readonly property bool flying: effect.item ? effect.item.flying : false
    readonly property int shellType: effect.item ? effect.item.shellType : 0

    // ------------------------------------------------------------------ theme
    // The same derivations the settings card and the Studio Effects panel make,
    // so the first-run state and the working one read as one family.
    readonly property var bar: FireworksState.barWidget ? FireworksState.barWidget.bar : null
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
    readonly property bool rounded: Style.cornerRadius > 0
    readonly property int cardRadius: rounded ? Math.max(Style.cornerRadius * 2, Style.space(12)) : 0
    readonly property int rowHeight: Math.max(Style.space(30), Style.font.body + Style.space(16))

    function openSettings() { if (effect.item) effect.item.openSettings(); else setupOpen = true }
    function closeSettings() { setupOpen = false; if (effect.item) effect.item.closeSettings() }
    function open(payload) { if (effect.item) effect.item.open(payload); else setupOpen = true }
    function close() { setupOpen = false; if (effect.item) effect.item.close() }
    function status(arg) { return effect.item ? effect.item.status(arg) : JSON.stringify({ready: false, buildRequested: buildRequested}) }
    function build(mode) {
        if (mode === "prebuilt" && !prebuiltAvailable) return
        buildRequested = true
        setupOpen = false
        Quickshell.execDetached(["/usr/bin/bash", root.pluginDir + "/fireworks-setup-terminal.sh", mode === "prebuilt" ? "prebuilt" : "source"])
    }

    // Up and down move between the two routes. With no release published there
    // is only one place to be.
    function moveCursor() {
        root.cursorActive = true
        root.setupIndex = root.prebuiltAvailable ? 1 - root.setupIndex : 1
    }
    function chooseSelected() { root.build(root.setupIndex === 0 ? "prebuilt" : "source") }
    // A release may have been published, or the build finished by hand, since
    // the card first looked.
    function recheck() {
        prebuiltCheck.running = false
        prebuiltCheck.running = true
        if (!probe.running) probe.running = true
    }

    Component.onCompleted: FireworksState.overlay = root
    Component.onDestruction: { if (FireworksState.overlay === root) FireworksState.overlay = null }
    onPrebuiltAvailableChanged: if (!prebuiltAvailable && setupIndex === 0) setupIndex = 1
    Process {
        id: prebuiltCheck
        command: ["bash", root.pluginDir + "/fireworks-prebuilt.sh", "--available"]
        running: true
        onExited: function(code, status) { root.prebuiltAvailable = code === 0 }
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

    // An install route, as a row of the grouped list.
    component SetupRow: CursorSurface {
        id: setup
        required property int index
        required property string label
        required property string detail
        required property string glyph
        property bool selectable: true
        enabled: setup.selectable
        width: parent ? parent.width : 0
        height: Math.max(root.rowHeight, setupText.implicitHeight) + Style.space(16)
        radius: Math.max(0, root.cardRadius - Style.space(4))
        hasCursor: setup.selectable && root.cursorActive && root.setupIndex === setup.index
        foreground: root.contentForeground
        accent: Commons.Color.accent
        fill: root.hoverFill
        currentFill: root.selectedFill

        MouseArea {
            anchors.fill: parent
            enabled: setup.selectable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (containsMouse) {
                root.cursorActive = true
                root.setupIndex = setup.index
            }
            onClicked: {
                root.setupIndex = setup.index
                root.chooseSelected()
            }
        }

        Rectangle {
            id: setupIcon
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            height: width
            radius: root.rounded ? Style.space(7) : 0
            color: setup.selectable ? root.onFill : root.quietFill

            Label {
                anchors.centerIn: parent
                text: setup.glyph
                color: setup.selectable ? root.surface : root.dim
                font.pixelSize: Style.font.icon
            }
        }

        Column {
            id: setupText
            anchors.left: setupIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: setupTrail.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Label {
                width: parent.width
                text: setup.label
                font.bold: true
                color: setup.selectable ? root.contentForeground : root.dim
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                text: setup.detail
                color: root.dim
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
            }
        }

        Label {
            id: setupTrail
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: setup.hasCursor ? "enter" : setup.selectable ? "\u{F0142}" : "Unavailable"
            color: setup.hasCursor ? root.accentColor : root.dim
            font.pixelSize: setup.hasCursor || !setup.selectable ? Style.font.caption : Style.font.icon
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

    // ------------------------------------------------------------------ setup
    // First run: no native module yet, so the only thing to offer is a way to
    // get one. Both routes open a terminal rather than working behind the
    // shell's back, so progress and any error are visible.
    KeyboardPanel {
        id: panel
        anchorItem: FireworksState.barWidget ? FireworksState.barWidget.panelAnchor : null
        bar: FireworksState.barWidget ? FireworksState.barWidget.bar : null
        owner: FireworksState.barWidget || root
        open: root.setupOpen && FireworksState.barWidget !== null
        focusTarget: setupKeys
        contentWidth: fittedContentWidth(Style.space(380))
        contentHeight: fittedContentHeight(content.implicitHeight)

        PanelKeyCatcher {
            id: setupKeys
            anchors.fill: parent

            onCloseRequested: root.closeSettings()
            onActivateRequested: root.chooseSelected()
            onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor() }
            onTabRequested: function(direction) {
                if (root.bar && typeof root.bar.switchPanelFrom === "function")
                    root.bar.switchPanelFrom(FireworksState.barWidget, direction)
            }
            onTextKey: function(text, modifiers) {
                if (!(modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                        && String(text).toLowerCase() === "r")
                    root.recheck()
            }

            Column {
                id: content
                width: parent.width
                spacing: Style.space(12)

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Style.space(52)
                    height: width
                    radius: root.rounded ? Style.space(14) : 0
                    color: root.onFill

                    Label {
                        anchors.centerIn: parent
                        text: "✦"
                        color: root.surface
                        font.pixelSize: Style.space(26)
                    }
                }

                Column {
                    width: parent.width
                    spacing: Style.space(4)

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Fireworks"
                        font.bold: true
                        font.pixelSize: Style.font.heading
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.note
                        color: root.dim
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)

                    Label {
                        text: "INSTALL"
                        color: root.dim
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 1
                        leftPadding: Style.space(14)
                    }

                    Card {
                        height: setupList.implicitHeight + Style.space(8)

                        Column {
                            id: setupList
                            x: Style.space(4)
                            y: Style.space(4)
                            width: parent.width - Style.space(8)
                            spacing: Style.space(2)

                            SetupRow {
                                index: 0
                                glyph: "\u{F01DA}"
                                label: "Use prebuilt"
                                selectable: root.prebuiltAvailable
                                detail: root.prebuiltAvailable
                                    ? "A verified release for your Qt packages. No compilation."
                                    : "No supported release is published yet"
                            }
                            SetupRow {
                                index: 1
                                glyph: "\u{F05B7}"
                                label: "Build from source"
                                detail: "Built for your installed Qt libraries. Takes a few minutes."
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        text: "Both open a terminal with progress and any errors, install into this plugin only (no sudo), then restart the shell."
                        color: root.dim
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                        leftPadding: Style.space(4)
                        rightPadding: Style.space(4)
                    }

                    // Shown once it has been started. There is no handle on the
                    // terminal, so it cannot say when the window closes — only
                    // that this panel changes by itself when the module appears,
                    // and that asking again is safe if the window was closed early.
                    Label {
                        width: parent.width
                        visible: root.buildRequested
                        text: "Working in the terminal window. This card changes by itself when it finishes; if you closed the window, set up again."
                        color: root.accentColor
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                        leftPadding: Style.space(4)
                        rightPadding: Style.space(4)
                    }
                }

                Flow {
                    width: parent.width
                    spacing: Style.space(10)

                    Repeater {
                        model: [["↑↓", "move"], ["enter", "set up"], ["r", "recheck"], ["esc", "close"]]
                        delegate: KeyHint {}
                    }
                }
            }
        }
    }
}
