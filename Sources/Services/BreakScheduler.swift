import AppKit
import Combine

/// The core model: ticks once per second, accumulates active (non-idle) work time per break type,
/// and starts, postpones, skips or ends breaks. Wall-clock changes are ignored by using a monotonic clock.
@MainActor
final class BreakScheduler: ObservableObject {
    /// A break currently on screen.
    struct ActiveBreak: Equatable {
        let kind: BreakKind
        let total: Double
        var remaining: Double
    }

    @Published private(set) var microActive: Double = 0
    @Published private(set) var normalActive: Double = 0
    @Published private(set) var current: ActiveBreak?
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var skipNext = false

    private var timer: Timer?
    private var lastTick = SystemState.monotonic
    private var awayStart: Double?
    private var notifiedForCycle = false
    private var overlay: OverlayController?
    private var observers: [NSObjectProtocol] = []

    /// Below this many idle seconds the user counts as actively working.
    private let activeThreshold: Double = 60

    init() {
        overlay = OverlayController(scheduler: self)
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        observeSystem()
    }

    // MARK: Derived state

    var isPaused: Bool { (pausedUntil.map { $0 > Date() }) ?? false }

    /// The break that will fire next and the active seconds until it does.
    var next: (kind: BreakKind, seconds: Double) {
        let micro = Prefs.interval(.micro) - microActive
        let normal = Prefs.interval(.normal) - normalActive
        return normal <= micro ? (.normal, max(0, normal)) : (.micro, max(0, micro))
    }

    var menuTitle: String {
        if current != nil { return "Break" }
        if isPaused { return "Paused" }
        return Self.format(next.seconds)
    }

    static func format(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.up))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Tick

    private func tick() {
        let now = SystemState.monotonic
        let dt = min(max(0, now - lastTick), 5)
        lastTick = now

        if var b = current {
            b.remaining -= dt
            if b.remaining <= 0 { finishBreak(completed: true) } else { current = b }
            return
        }
        if let until = pausedUntil, until <= Date() { pausedUntil = nil }
        guard !isPaused, awayStart == nil else { return }

        let idle = SystemState.idleSeconds()
        if idle >= Prefs.idleReset { resetAll(); return }
        if idle >= max(Prefs.duration(.micro), 120) { microActive = 0 }
        guard idle < activeThreshold else { return }

        microActive += dt
        normalActive += dt

        let upcoming = next
        if upcoming.seconds <= 30, upcoming.seconds > 0, !notifiedForCycle {
            notifiedForCycle = true
            if Prefs.bool(Prefs.preBreakNotice) { NotificationService.shared.postPreBreak(kind: upcoming.kind) }
        }
        // If both are due, only the long break shows.
        if normalActive >= Prefs.interval(.normal) {
            breakDue(.normal)
        } else if microActive >= Prefs.interval(.micro) {
            breakDue(.micro)
        }
    }

    private func breakDue(_ kind: BreakKind) {
        if skipNext {
            skipNext = false
            reset(after: kind)
            return
        }
        if Prefs.bool(Prefs.doNotDisturb), SystemState.isMirroring() || SystemState.frontmostAppIsFullScreen() {
            reset(after: kind)
            return
        }
        startBreak(kind)
    }

    // MARK: Actions

    func startBreak(_ kind: BreakKind) {
        guard current == nil else { return }
        let d = Prefs.duration(kind)
        current = ActiveBreak(kind: kind, total: d, remaining: d)
        overlay?.show()
    }

    /// Ends the current break. `completed` is false when the user skipped or escaped it.
    func finishBreak(completed: Bool) {
        guard let b = current else { return }
        current = nil
        overlay?.hide()
        reset(after: b.kind)
        if completed, Prefs.soundName != "None" { NSSound(named: NSSound.Name(Prefs.soundName))?.play() }
    }

    /// Hides the overlay and brings the same break back after five more minutes of work.
    func postpone() {
        guard let b = current else { return }
        current = nil
        overlay?.hide()
        let back = max(0, Prefs.interval(b.kind) - 5 * 60)
        if b.kind == .normal { normalActive = back } else { microActive = back }
        notifiedForCycle = false
    }

    func pause(until date: Date) {
        finishBreak(completed: false)
        pausedUntil = date
    }

    func pauseForHour() { pause(until: Date().addingTimeInterval(3600)) }

    func pauseUntilTomorrow() {
        let cal = Calendar.current
        pause(until: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date().addingTimeInterval(86400))
    }

    func resume() { pausedUntil = nil; lastTick = SystemState.monotonic }

    func toggleSkipNext() { skipNext.toggle() }

    private func reset(after kind: BreakKind) {
        // A long break also covers the micro break.
        if kind == .normal { normalActive = 0 }
        microActive = 0
        notifiedForCycle = false
    }

    private func resetAll() {
        microActive = 0
        normalActive = 0
        notifiedForCycle = false
    }

    // MARK: Sleep, wake and screen lock

    private func observeSystem() {
        let ws = NSWorkspace.shared.notificationCenter
        let dnc = DistributedNotificationCenter.default()
        let away: (Notification) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.wentAway() } }
        let back: (Notification) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.cameBack() } }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(ws.addObserver(forName: name, object: nil, queue: .main, using: away))
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(ws.addObserver(forName: name, object: nil, queue: .main, using: back))
        }
        observers.append(dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main, using: away))
        observers.append(dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main, using: back))
    }

    private func wentAway() {
        if awayStart == nil { awayStart = SystemState.monotonic }
    }

    /// Time away counts as a break if it was at least as long as that break's duration.
    private func cameBack() {
        guard let start = awayStart else { return }
        awayStart = nil
        let gap = SystemState.monotonic - start
        lastTick = SystemState.monotonic
        if gap >= Prefs.duration(.normal) || gap >= Prefs.idleReset { resetAll() }
        else if gap >= Prefs.duration(.micro) { microActive = 0; notifiedForCycle = false }
    }
}
