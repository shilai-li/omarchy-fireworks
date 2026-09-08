import QtQuick
import "native" as Native

// One native clock/audio source per shell, shared by all monitor views.
// Fixed slots bound simulation, GPU targets, pending synthesis, and audio sinks.
Item {
    id: pool
    readonly property int capacity: 4
    property bool sound: true
    property real volume: 0.35
    property int serial: 0
    property int slotRevision: 0
    readonly property int activeCount: {
        // itemAt() is not a notifying property. Re-evaluate after delegates
        // arrive even if the desktop queried this before component completion.
        var revision = slotRevision
        var total = 0
        for (var i = 0; i < slots.count; ++i) {
            var entry = slots.itemAt(i)
            if (entry && entry.active) ++total
        }
        return total
    }
    function slot(index) { return slots.itemAt(index) }
    function launch(shell, quiet, launchX, randomLaunch) {
        var chosen = null
        for (var i = 0; i < slots.count; ++i) {
            var entry = slot(i)
            if (!entry.active) { chosen = entry; break }
            if (!chosen || entry.serial < chosen.serial) chosen = entry
        }
        if (!chosen) return
        chosen.stop()
        chosen.serial = ++pool.serial
        chosen.quiet = quiet
        chosen.controller.shellType = shell
        chosen.controller.seed = 73 + pool.serial
        chosen.controller.launchX = launchX
        chosen.controller.randomLaunch = randomLaunch
        chosen.controller.seek(0)
        chosen.active = true
        chosen.begin()
    }
    function stop() {
        for (var i = 0; i < slots.count; ++i) slot(i).stop()
    }
    Repeater {
        id: slots
        model: pool.capacity
        onItemAdded: ++pool.slotRevision
        onItemRemoved: ++pool.slotRevision
        delegate: Item {
            id: entry
            property bool active: false
            // launch() resolves random placement before starting the clock.
            // Never expose the provisional time-zero rocket during the delay.
            readonly property bool ready: active && clock.running
            property bool quiet: false
            property int serial: 0
            property alias controller: clock
            function begin() { delay.restart() }
            function stop() {
                delay.stop()
                clock.pause()
                active = false
            }
            Native.ShowDirector {
                id: clock
                audioEnabled: pool.sound && !entry.quiet
                volume: pool.volume / Math.max(1, pool.activeCount)
                onFinished: entry.active = false
            }
            // Allow new overlay surfaces to receive their initial layout.
            Timer { id: delay; interval: 80; onTriggered: clock.launch() }
        }
    }
}
