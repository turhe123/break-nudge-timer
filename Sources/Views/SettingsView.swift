import AppKit
import ServiceManagement
import SwiftUI

/// Preferences window: both break types, behaviour toggles, sound, idle reset and launch at login.
struct SettingsView: View {
    @AppStorage(Prefs.microInterval) private var microInterval = 20
    @AppStorage(Prefs.microDuration) private var microDuration = 20
    @AppStorage(Prefs.microMessage) private var microMessage = ""
    @AppStorage(Prefs.normalInterval) private var normalInterval = 60
    @AppStorage(Prefs.normalDuration) private var normalDuration = 5
    @AppStorage(Prefs.normalMessage) private var normalMessage = ""
    @AppStorage(Prefs.allowSkip) private var allowSkip = true
    @AppStorage(Prefs.allowPostpone) private var allowPostpone = true
    @AppStorage(Prefs.strictMode) private var strictMode = false
    @AppStorage(Prefs.sound) private var sound = "Glass"
    @AppStorage(Prefs.idleResetMinutes) private var idleReset = 5
    @AppStorage(Prefs.doNotDisturb) private var doNotDisturb = true
    @AppStorage(Prefs.preBreakNotice) private var preBreakNotice = true

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var notificationsAllowed = true

    var body: some View {
        Form {
            Section("Micro Break") {
                Stepper("Every \(microInterval) minutes", value: $microInterval, in: 5...120, step: 5)
                Stepper("Lasts \(microDuration) seconds", value: $microDuration, in: 5...120, step: 5)
                TextField("Message", text: $microMessage)
            }
            Section("Long Break") {
                Stepper("Every \(normalInterval) minutes", value: $normalInterval, in: 15...240, step: 5)
                Stepper("Lasts \(normalDuration) minutes", value: $normalDuration, in: 1...30)
                TextField("Message", text: $normalMessage)
            }
            Section("During a Break") {
                Toggle("Allow skipping breaks", isOn: $allowSkip)
                Toggle("Allow postponing for 5 minutes", isOn: $allowPostpone)
                Toggle("Strict mode (no Esc, no buttons — ends on the timer)", isOn: $strictMode)
                Picker("Sound when a break ends", selection: $sound) {
                    ForEach(Prefs.sounds, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: sound) { _, name in
                    if name != "None" { NSSound(named: NSSound.Name(name))?.play() }
                }
            }
            Section("Behaviour") {
                Stepper("Idle for \(idleReset) min counts as a natural break", value: $idleReset, in: 1...60)
                Toggle("Do not disturb: skip breaks while mirroring or a full-screen app is in front", isOn: $doNotDisturb)
                Toggle("Notify 30 seconds before a break", isOn: $preBreakNotice)
                if preBreakNotice && !notificationsAllowed {
                    HStack {
                        Text("Notifications are turned off for BreakNudgeTimer. Breaks will still appear as an overlay.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Settings…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
            Section {
                HStack {
                    Text("BreakNudgeTimer is free and open source.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Support / Donate ❤️") {
                        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onAppear {
            NotificationService.shared.isAuthorized { notificationsAllowed = $0 }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on, SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            if !on, SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't update login item: \(error.localizedDescription). Check System Settings › General › Login Items."
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
