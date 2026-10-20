import AppKit
import SwiftUI

/// Borderless, key-capable window used for the break overlay.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Creates one translucent overlay window per connected display and handles the Escape key.
@MainActor
final class OverlayController {
    private weak var scheduler: BreakScheduler?
    private var windows: [OverlayWindow] = []
    private var keyMonitor: Any?

    init(scheduler: BreakScheduler) { self.scheduler = scheduler }

    func show() {
        guard let scheduler, windows.isEmpty else { return }
        for screen in NSScreen.screens {
            let w = OverlayWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            w.level = .screenSaver
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            w.isOpaque = false
            w.backgroundColor = .clear
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: OverlayView().environmentObject(scheduler))
            w.setFrame(screen.frame, display: true)
            w.alphaValue = 0
            w.orderFrontRegardless()
            windows.append(w)
        }
        windows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            windows.forEach { $0.animator().alphaValue = 1 }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Escape always dismisses unless strict mode is on; strict mode still ends on the timer.
            if event.keyCode == 53, !Prefs.bool(Prefs.strictMode) {
                self?.scheduler?.finishBreak(completed: false)
                return nil
            }
            return event
        }
    }

    func hide() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        let closing = windows
        windows.removeAll()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }
}
