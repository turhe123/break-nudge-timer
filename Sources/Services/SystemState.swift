import AppKit
import CoreGraphics
import IOKit

/// Read-only queries about the machine: user idle time, monotonic clock, full-screen apps and display mirroring.
enum SystemState {
    /// Monotonic seconds that keep counting during sleep and ignore wall-clock changes.
    static var monotonic: Double { Double(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1_000_000_000 }

    /// Seconds since the last keyboard/mouse event. Uses CGEventSource (no permission needed), IOKit as fallback.
    static func idleSeconds() -> Double {
        if let anyInput = CGEventType(rawValue: ~0) {
            let s = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
            if s.isFinite, s >= 0 { return s }
        }
        return ioKitIdleSeconds() ?? 0
    }

    /// Reads `HIDIdleTime` (nanoseconds) from the IOHIDSystem registry entry.
    static func ioKitIdleSeconds() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let prop = IORegistryEntryCreateCFProperty(service, "HIDIdleTime" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? NSNumber else { return nil }
        return prop.doubleValue / 1_000_000_000
    }

    /// True when any active display is part of a mirror set (e.g. presenting on a projector).
    static func isMirroring() -> Bool {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return false }
        return ids.contains { CGDisplayIsInMirrorSet($0) != 0 }
    }

    /// True when the frontmost app owns a normal-level window covering an entire screen.
    static func frontmostAppIsFullScreen() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier,
              app.bundleIdentifier != "com.apple.finder",
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        let screenSizes = NSScreen.screens.map { $0.frame.size }
        for info in list {
            guard (info[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            if screenSizes.contains(where: { $0.width == bounds.width && $0.height == bounds.height }) { return true }
        }
        return false
    }
}
