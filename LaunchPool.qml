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
    // How many shells the catalog holds, so a mixed display can pick from it.
    // Set by the overlay from the director rather than hardcoded here.
    property int shellCount: 1

    // A slot is held for the whole of a shell's life, so "alive" means every
    // shell lifted within this many seconds. Must match Simulation::Duration.
    readonly property real shellLife: 11.0

    // What one trigger fires. `lifts` are seconds after the trigger; the last
    // `finale` entries always use the chosen shell, so a mixed display still
    // ends on what was picked.
    //
    // The schedules are spaced to peak at `capacity` and no higher — the fifth
    // concurrent launch evicts the oldest slot mid-flight, which would cut a
    // shell off in the air. Measured on Intel Arc B390 at 3072x1920: one shell
    // costs ~23% of the render engine and ~390 MiB more GTT, four cost ~65%
    // and 2.5 GiB. Peaking higher was measured to be the wrong trade, so a
    // longer display is spread out rather than stacked deeper.
    readonly property var displays: [
        { name: "one shell", lifts: [0], mixed: false, finale: 0 },
        { name: "volley", lifts: [0, 1.3, 2.6, 3.9], mixed: false, finale: 0 },
        { name: "full show", lifts: [0, 2.8, 5.6, 8.4, 14.2, 14.6], mixed: true, finale: 2 }
    ]

    // The schedule in flight, if any. A display is a queue of launches, so it
    // outlives the call that started it and has to be cancellable.
    property int pendingStep: -1
    property var pendingPlan: null
    property int pendingShell: 0
    property bool pendingQuiet: false
    property real pendingLaunchX: 0
    property bool pendingRandom: false
    readonly property bool scheduled: pool.pendingStep >= 0
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

    // The most shells this schedule ever has in the air at once. Used by the
    // tests to hold the table and `capacity` to each other, so a retuned
    // schedule cannot quietly start evicting its own shells.
    function peakConcurrency(plan) {
        var peak = 0
        for (var i = 0; i < plan.lifts.length; ++i) {
            var alive = 0
            for (var j = 0; j <= i; ++j)
                if (plan.lifts[i] - plan.lifts[j] < pool.shellLife) ++alive
            if (alive > peak) peak = alive
        }
        return peak
    }

    // Derived from the pool serial rather than Math.random(), so one display is
    // reproducible and two triggers in a row do not draw the same sequence.
    function mixedShell(step) {
        if (pool.shellCount <= 1) return pool.pendingShell
        return ((pool.serial * 7919 + step * 104729) % 2147483647) % pool.shellCount
    }

    // One trigger, one whole display. The first shell goes up at once; the
    // rest are queued against the schedule.
    function launchDisplay(size, shell, quiet, launchX, randomLaunch) {
        cancelPending()
        var index = Math.max(0, Math.min(pool.displays.length - 1, size))
        pool.pendingPlan = pool.displays[index]
        pool.pendingShell = shell
        pool.pendingQuiet = quiet === true
        pool.pendingLaunchX = launchX
        pool.pendingRandom = randomLaunch === true
        pool.pendingStep = 0
        fireStep()
    }

    function cancelPending() {
        schedule.stop()
        pool.pendingStep = -1
        pool.pendingPlan = null
    }

    function fireStep() {
        var plan = pool.pendingPlan
        if (!plan || pool.pendingStep < 0 || pool.pendingStep >= plan.lifts.length) {
            cancelPending()
            return
        }
        var step = pool.pendingStep
        // Mixed displays draw from the catalog, except the finale, which is
        // the shell that was actually chosen.
        var shell = (plan.mixed && step < plan.lifts.length - plan.finale) ? mixedShell(step)
                                                                          : pool.pendingShell
        launch(shell, pool.pendingQuiet, pool.pendingLaunchX, pool.pendingRandom)
        pool.pendingStep = step + 1
        if (pool.pendingStep >= plan.lifts.length) {
            cancelPending()
            return
        }
        schedule.interval = Math.max(1, Math.round((plan.lifts[pool.pendingStep] - plan.lifts[step]) * 1000))
        schedule.restart()
    }
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
        // Cancel what has not gone up yet as well as what is already flying:
        // otherwise closing the plugin leaves the rest of a display to fire
        // over a desktop that asked it to stop.
        cancelPending()
        for (var i = 0; i < slots.count; ++i) slot(i).stop()
    }

    Timer { id: schedule; onTriggered: pool.fireStep() }
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
