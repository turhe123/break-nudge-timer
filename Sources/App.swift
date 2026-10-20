import AppKit
import SwiftUI

/// App entry point: a menu bar extra with a live countdown plus a Settings window.
@main
struct BreakNudgeTimerApp: App {
    @StateObject private var scheduler: BreakScheduler

    init() {
        Prefs.register()
        NotificationService.shared.requestAuthorization()
        _scheduler = StateObject(wrappedValue: BreakScheduler())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(scheduler)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: scheduler.isPaused ? "pause.circle" : "cup.and.saucer")
                Text(scheduler.menuTitle).monospacedDigit()
            }
        }
        Window("BreakNudgeTimer Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

/// The menu bar dropdown: status, break actions, pause controls, settings and support.
struct MenuContent: View {
    @EnvironmentObject var scheduler: BreakScheduler
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let b = scheduler.current {
            Text("\(b.kind.title) in progress — \(BreakScheduler.format(b.remaining)) left")
        } else if let until = scheduler.pausedUntil, scheduler.isPaused {
            Text("Paused until \(until.formatted(date: .omitted, time: .shortened))")
            Button("Resume") { scheduler.resume() }
        } else {
            Text("Next \(scheduler.next.kind.title.lowercased()) in \(BreakScheduler.format(scheduler.next.seconds))")
        }
        Divider()
        Button("Take Break Now") { scheduler.startBreak(.normal) }
        Button("Take Micro Break Now") { scheduler.startBreak(.micro) }
        Divider()
        Button("Pause for an Hour") { scheduler.pauseForHour() }
        Button("Pause Until Tomorrow") { scheduler.pauseUntilTomorrow() }
        Toggle("Skip Next Break", isOn: Binding(get: { scheduler.skipNext }, set: { _ in scheduler.toggleSkipNext() }))
        Divider()
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        Button("Support / Donate ❤️") {
            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
        }
        Divider()
        Button("Quit BreakNudgeTimer") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
