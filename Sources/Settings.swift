import Foundation

/// The two kinds of breaks the app schedules.
enum BreakKind: String {
    case micro, normal

    var title: String { self == .micro ? "Micro Break" : "Long Break" }
}

/// Central list of UserDefaults keys and their default values, shared by `@AppStorage` and the scheduler.
enum Prefs {
    static let microInterval = "microIntervalMinutes"
    static let microDuration = "microDurationSeconds"
    static let microMessage = "microMessage"
    static let normalInterval = "normalIntervalMinutes"
    static let normalDuration = "normalDurationMinutes"
    static let normalMessage = "normalMessage"
    static let allowSkip = "allowSkip"
    static let allowPostpone = "allowPostpone"
    static let strictMode = "strictMode"
    static let sound = "soundName"
    static let idleResetMinutes = "idleResetMinutes"
    static let doNotDisturb = "doNotDisturb"
    static let preBreakNotice = "preBreakNotice"

    static let sounds = ["None", "Glass", "Ping", "Hero", "Purr", "Submarine", "Tink"]

    static func register() {
        UserDefaults.standard.register(defaults: [
            microInterval: 20, microDuration: 20,
            microMessage: "Look at something 20 feet away and blink slowly.",
            normalInterval: 60, normalDuration: 5,
            normalMessage: "Stand up, stretch, and give your eyes a real rest.",
            allowSkip: true, allowPostpone: true, strictMode: false,
            sound: "Glass", idleResetMinutes: 5, doNotDisturb: true, preBreakNotice: true,
        ])
    }

    private static var d: UserDefaults { .standard }
    static func interval(_ kind: BreakKind) -> Double {
        kind == .micro ? Double(max(1, d.integer(forKey: microInterval))) * 60
                       : Double(max(1, d.integer(forKey: normalInterval))) * 60
    }
    static func duration(_ kind: BreakKind) -> Double {
        kind == .micro ? Double(max(5, d.integer(forKey: microDuration)))
                       : Double(max(1, d.integer(forKey: normalDuration))) * 60
    }
    static func message(_ kind: BreakKind) -> String {
        d.string(forKey: kind == .micro ? microMessage : normalMessage) ?? ""
    }
    static func bool(_ key: String) -> Bool { d.bool(forKey: key) }
    static var idleReset: Double { Double(max(1, d.integer(forKey: idleResetMinutes))) * 60 }
    static var soundName: String { d.string(forKey: sound) ?? "None" }
}
