import SwiftUI
import Observation

/// 文本/trigger/speed 改变或重新进入页面时重新播放；离开或进入后台自动取消。
public struct TypewriterModifier: ViewModifier {
    let fullText: String
    let speed: Double
    let trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var state = CYTypewriterState()

    private struct Playback: Hashable {
        let text: String
        let speed: Double
        let enabled: Bool
        let active: Bool
    }

    public func body(content: Content) -> some View {
        let playback = Playback(text: fullText, speed: speed.isFinite ? max(0, speed) : 0,
                                enabled: trigger && !reduceMotion, active: scenePhase == .active)
        ZStack {
            content.hidden().accessibilityHidden(true)
            Text(playback.enabled ? state.displayedText : fullText)
                .accessibilityLabel(fullText)
        }
        .task(id: playback) {
            guard playback.active else { state.cancel(); return }
            await state.play(text: playback.text, speed: playback.speed, enabled: playback.enabled)
        }
        .onDisappear { state.cancel() }
    }
}

public extension View {
    /// trigger 为 false 直接显示全文；false→true 重播。负值/非有限 speed 立即展示全文。
    func typewriter(text: String, speed: Double = 0.025, trigger: Bool = false) -> some View {
        modifier(TypewriterModifier(fullText: text, speed: speed, trigger: trigger))
    }
}

/// Internal state allows lifecycle/race tests without depending on frame timing.
@MainActor
@Observable
final class CYTypewriterState {
    private(set) var displayedText = ""
    @ObservationIgnored private var generation = UUID()

    func cancel() { generation = UUID() }

    func play(text: String, speed: Double, enabled: Bool,
              wait: (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) async {
        let id = UUID()
        generation = id
        displayedText = ""
        guard enabled, speed.isFinite, speed > 0, speed < Double(Int64.max) / 2 else {
            displayedText = text
            return
        }
        do {
            for character in text {
                try Task.checkCancellation()
                guard generation == id else { return }
                displayedText.append(character)
                try await wait(speed)
            }
        } catch { /* task cancellation stops playback */ }
    }
}
