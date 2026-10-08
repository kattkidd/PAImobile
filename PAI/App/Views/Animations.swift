import SwiftUI

// Action animations: emotes, sending messages, saving, timers…

enum ActionAnim: String, Equatable {
    case flip, spin, jump, dance, wave, nod, shake, bounce, talk, blink, laugh, scream, droop, pop, stamp

    /// Which animation goes with an SS14 emote.
    static func forEmote(_ id: String) -> ActionAnim {
        switch id {
        case "Scream", "Hiss", "Growl", "Snarl", "Howl", "Buzz", "Buzz-Two", "Bagawk": return .scream
        case "Laugh", "Chitter", "Squeak", "Purr", "Trill", "Warble", "Wurble", "Chirp", "Mars", "Yip", "Weh", "Hew": return .laugh
        case "Crying", "Sigh", "Yawn", "Whine", "Gasp": return .droop
        case "Clap", "ClapSingle", "LagomorphStomp": return .jump
        case "Salute", "Sneeze", "Cough", "Belch", "Gulp": return .nod
        case "Pop", "Bubble", "Squish", "ThavenGlub": return .pop
        case "Blink": return .blink
        case "Surprised": return .jump
        default: return .bounce
        }
    }
}

struct AnimEvent: Equatable {
    var id = UUID()
    var kind: ActionAnim
}

struct AnimValues: Equatable {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rotation: Double = 0
    var flipY: Double = 0
    var sx: CGFloat = 1
    var sy: CGFloat = 1
    var opacity: Double = 1
}

/// Plays one-shot animations on any sprite. `unit` scales distances to the view size.
struct ActionAnimator: ViewModifier {
    var event: AnimEvent?
    var unit: CGFloat = 1
    @State private var v = AnimValues()

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: v.sx, y: v.sy, anchor: .bottom)
            .rotation3DEffect(.degrees(v.flipY), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .rotationEffect(.degrees(v.rotation))
            .offset(x: v.x * unit, y: v.y * unit)
            .opacity(v.opacity)
            .onChange(of: event?.id) { _, _ in
                guard let kind = event?.kind else { return }
                Task { await run(kind) }
            }
    }

    @MainActor
    private func step(_ seconds: Double, _ curve: Animation? = nil, _ change: (inout AnimValues) -> Void) async {
        withAnimation(curve ?? .easeInOut(duration: seconds)) { change(&v) }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    @MainActor
    private func run(_ kind: ActionAnim) async {
        v = AnimValues()
        switch kind {
        case .flip:
            // Goob Station's *flip: a hop with a full turn.
            await step(0.12) { $0.sy = 0.85 }
            await step(0.42, .easeInOut(duration: 0.42)) { $0.y = -14; $0.rotation = 360; $0.sy = 1 }
            await step(0.16, .easeIn(duration: 0.16)) { $0.y = 0 }
            v.rotation = 0
            await step(0.1) { $0.sy = 0.9 }
            await step(0.12) { $0.sy = 1 }
        case .jump:
            await step(0.1) { $0.sy = 0.85; $0.sx = 1.08 }
            await step(0.2, .easeOut(duration: 0.2)) { $0.y = -16; $0.sy = 1.08; $0.sx = 0.95 }
            await step(0.18, .easeIn(duration: 0.18)) { $0.y = 0; $0.sy = 1; $0.sx = 1 }
            await step(0.08) { $0.sy = 0.9; $0.sx = 1.06 }
            await step(0.12) { $0.sy = 1; $0.sx = 1 }
        case .dance:
            for i in 0..<4 {
                await step(0.16) { $0.rotation = i % 2 == 0 ? 10 : -10; $0.y = -4 }
                await step(0.12) { $0.y = 0 }
            }
            await step(0.15) { $0.rotation = 0 }
        case .wave:
            for i in 0..<3 { await step(0.14) { $0.rotation = i % 2 == 0 ? 7 : -7 } }
            await step(0.12) { $0.rotation = 0 }
        case .nod:
            await step(0.12) { $0.sy = 0.92; $0.y = 1 }
            await step(0.14) { $0.sy = 1; $0.y = 0 }
            await step(0.12) { $0.sy = 0.94 }
            await step(0.14) { $0.sy = 1 }
        case .shake, .scream:
            let amp: CGFloat = kind == .scream ? 3 : 2
            if kind == .scream { await step(0.08) { $0.sy = 1.08; $0.sx = 0.96 } }
            for i in 0..<8 { await step(0.04, .linear(duration: 0.04)) { $0.x = i % 2 == 0 ? amp : -amp } }
            await step(0.08) { $0.x = 0; $0.sy = 1; $0.sx = 1 }
        case .laugh:
            for _ in 0..<3 {
                await step(0.09) { $0.y = -3; $0.sy = 1.04 }
                await step(0.09) { $0.y = 0; $0.sy = 0.97 }
            }
            await step(0.1) { $0.sy = 1 }
        case .droop:
            await step(0.35) { $0.sy = 0.9; $0.y = 1; $0.rotation = -3 }
            try? await Task.sleep(nanoseconds: 450_000_000)
            await step(0.3) { $0.sy = 1; $0.y = 0; $0.rotation = 0 }
        case .bounce, .talk:
            await step(0.09) { $0.sy = 0.92; $0.sx = 1.05 }
            await step(0.12) { $0.sy = 1.05; $0.sx = 0.97; $0.y = -3 }
            await step(0.12) { $0.sy = 1; $0.sx = 1; $0.y = 0 }
        case .pop:
            await step(0.1) { $0.sx = 1.15; $0.sy = 1.15 }
            await step(0.15, .spring(response: 0.25, dampingFraction: 0.5)) { $0.sx = 1; $0.sy = 1 }
        case .blink:
            await step(0.07) { $0.opacity = 0.2 }
            await step(0.09) { $0.opacity = 1 }
        case .stamp:
            v.y = -20; v.sx = 1.3; v.sy = 1.3; v.opacity = 0
            await step(0.16, .easeIn(duration: 0.16)) { $0.y = 0; $0.sx = 1; $0.sy = 1; $0.opacity = 1 }
            await step(0.1) { $0.sy = 0.9 }
            await step(0.1) { $0.sy = 1 }
        case .spin:
            // Direction cycling is done by the character view; give it a little lift.
            await step(0.15) { $0.y = -3 }
            try? await Task.sleep(nanoseconds: 450_000_000)
            await step(0.15) { $0.y = 0 }
        }
    }
}

extension View {
    func actionAnimation(_ event: AnimEvent?, unit: CGFloat = 1) -> some View {
        modifier(ActionAnimator(event: event, unit: unit))
    }
}

/// A short pulse ring, used when things get saved/set ("ping!").
struct PulseRing: View {
    var trigger: Int
    var color: Color
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, _ in
                scale = 0.6; opacity = 0.9
                withAnimation(.easeOut(duration: 0.6)) { scale = 1.6; opacity = 0 }
            }
    }
}

/// Little equaliser bars shown while lobby music plays.
struct EqualizerBars: View {
    var playing: Bool
    var color: Color
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !playing)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(0..<4, id: \.self) { i in
                    let h = playing ? 3 + 9 * abs(sin(t * (2.2 + Double(i) * 0.9) + Double(i))) : 3
                    Rectangle().fill(color).frame(width: 2.5, height: h)
                }
            }
            .frame(height: 12, alignment: .bottom)
        }
    }
}

struct PopupText: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

/// SS14 PopupSystem look: bold outlined text that floats up and fades.
struct PopupLayer: View {
    var popups: [PopupText]
    var body: some View {
        VStack(spacing: 4) {
            ForEach(popups) { p in FloatingPopup(popup: p) }
        }
        .allowsHitTesting(false)
    }
}

private struct FloatingPopup: View {
    let popup: PopupText
    @State private var rise: CGFloat = 0
    @State private var fade: Double = 1

    var body: some View {
        Text(popup.text)
            .font(SS14Font.bold(15))
            .foregroundStyle(popup.color)
            .shadow(color: .black, radius: 0, x: 1, y: 1)
            .shadow(color: .black, radius: 0, x: -1, y: -1)
            .shadow(color: .black.opacity(0.8), radius: 2)
            .lineLimit(1)
            .padding(.horizontal, 20)
            .offset(y: rise)
            .opacity(fade)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
            .onAppear {
                withAnimation(.easeOut(duration: 1.6)) { rise = -36 }
                withAnimation(.easeIn(duration: 0.6).delay(1.0)) { fade = 0 }
            }
    }
}
