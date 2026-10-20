import AppKit
import SwiftUI

/// Blurred full-screen background backed by NSVisualEffectView.
struct BlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// The break screen: big countdown, message, progress and optional Postpone/Skip buttons.
struct OverlayView: View {
    @EnvironmentObject var scheduler: BreakScheduler
    @AppStorage(Prefs.allowSkip) private var allowSkip = true
    @AppStorage(Prefs.allowPostpone) private var allowPostpone = true
    @AppStorage(Prefs.strictMode) private var strictMode = false

    var body: some View {
        ZStack {
            BlurView()
            Color.black.opacity(0.35)
            if let b = scheduler.current {
                VStack(spacing: 22) {
                    Image(systemName: b.kind == .micro ? "eye" : "figure.walk")
                        .font(.system(size: 54, weight: .light))
                    Text(b.kind.title).font(.title.weight(.semibold))
                    Text(BreakScheduler.format(b.remaining))
                        .font(.system(size: 120, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text(Prefs.message(b.kind))
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                    ProgressView(value: max(0, b.total - b.remaining), total: b.total)
                        .progressViewStyle(.linear)
                        .frame(width: 320)
                        .tint(.white)
                    if !strictMode {
                        HStack(spacing: 14) {
                            if allowPostpone {
                                Button("Postpone 5 Minutes") { scheduler.postpone() }
                            }
                            if allowSkip {
                                Button("Skip Break") { scheduler.finishBreak(completed: false) }
                            }
                        }
                        .controlSize(.large)
                        .buttonStyle(.bordered)
                        Text("Press Esc to dismiss").font(.callout).foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text("Strict mode — the break ends when the timer runs out.")
                            .font(.callout).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .foregroundStyle(.white)
                .padding(40)
                .animation(.default, value: Int(b.remaining))
            }
        }
        .ignoresSafeArea()
    }
}
