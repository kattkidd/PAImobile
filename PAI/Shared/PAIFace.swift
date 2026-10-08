import SwiftUI
import UIKit

// MARK: - Moods

/// Face states. pAI moods use SS14 pai.rsi screen overlays; Station AI maps them to station_ai.rsi screens.
enum PAIMood: String, Codable, CaseIterable {
    case neutral, happy, thinking, sad, surprised, sleepy, alert, blink, off
}

// MARK: - Unit form

/// Your assistant can be a handheld pAI, the station's AI core, or a Nuclear 14 wasteland terminal.
enum UnitForm: String, Codable, CaseIterable, Identifiable {
    case pai, stationAI, terminal

    var id: String { rawValue }
    var label: String {
        switch self {
        case .pai: return "Personal AI"
        case .stationAI: return "Station AI"
        case .terminal: return "Terminal"
        }
    }
    var short: String {
        switch self {
        case .pai: return "pAI"
        case .stationAI: return "AI"
        case .terminal: return "TERM"
        }
    }
    var blurb: String {
        switch self {
        case .pai: return "A pocket-sized electronic pal. Fun to be with!"
        case .stationAI: return "The station's central intelligence, bound by its laws."
        case .terminal: return "A crusty pre-war terminal from Nuclear 14. Still humming."
        }
    }
    var source: String { self == .terminal ? "Nuclear 14" : "Space Station 14" }
}

// MARK: - pAI chassis (Objects/Fun/pai.rsi)

enum PAIChassis: String, Codable, CaseIterable, Identifiable {
    case standard, golden, syndicate, potato

    var id: String { rawValue }

    func label(_ form: UnitForm) -> String { form == .terminal ? terminalLabel : label }
    func flavor(_ form: UnitForm) -> String { form == .terminal ? terminalFlavor : flavor }

    var terminalLabel: String {
        switch self {
        case .standard: return "Terminal"
        case .golden: return "Clean terminal"
        case .syndicate: return "Rusted terminal"
        case .potato: return "Potato terminal"
        }
    }
    var terminalFlavor: String {
        switch self {
        case .standard: return "An old terminal, still humming after all these years."
        case .golden: return "A terminal so clean it must have come straight out of a sealed bunker."
        case .syndicate: return "Rust, dust and a flickering screen. It still works. Mostly."
        case .potato: return "Somebody wired a potato into a terminal. It's doing its best."
        }
    }

    var label: String {
        switch self {
        case .standard: return "Personal AI"
        case .golden: return "Golden pAI"
        case .syndicate: return "Syndicate pAI"
        case .potato: return "Potato AI"
        }
    }

    /// Item descriptions from SS14's pai.yml
    var flavor: String {
        switch self {
        case .standard: return "Your electronic pal who's fun to be with!"
        case .golden: return "Your electronic pal who's fun to be with! Special golden edition!"
        case .syndicate: return "Your Syndicate pal who's fun to be with!"
        case .potato: return "It's a potato. You forced it to be sentient, you monster."
        }
    }

    var baseImage: String { "pai_base_\(rawValue)" }

    /// Nuclear 14 terminal sprite used for this chassis.
    var terminalModel: String {
        switch self {
        case .standard, .potato: return "terminal"
        case .golden: return "terminal_new"
        case .syndicate: return "terminal_rusted"
        }
    }

    func screenImage(_ mood: PAIMood, frame: Int) -> String {
        switch self {
        case .potato:
            switch mood {
            case .thinking: return "screen_potato_thinking_0"
            case .off: return "screen_potato_off_0"
            default: return "screen_potato_on_0"
            }
        case .standard, .golden, .syndicate:
            let skin = self == .syndicate ? "syndicate" : "standard"
            if mood == .off { return "screen_\(skin)_off_0" }
            return "screen_\(skin)_\(mood.rawValue)_\(frame % 2)"
        }
    }

    var screenColor: Color {
        switch self {
        case .syndicate: return Color(red: 1.0, green: 0.41, blue: 0.42)
        case .potato: return Color(red: 0.30, green: 0.99, blue: 0.99)
        default: return Color(red: 0.42, green: 0.85, blue: 1.0)
        }
    }
}

// MARK: - Station AI core screens (Mobs/Silicon/station_ai.rsi, AppearanceCustomization/station_ai.yml)

enum AICore: String, Codable, CaseIterable, Identifiable {
    case ai, smiley, heartline, bliss, angel, clown, dorf

    var id: String { rawValue }
    var state: String { self == .ai ? "ai" : "ai_\(rawValue)" }
    var label: String {
        switch self {
        case .ai: return "Classic"
        case .smiley: return "Smiley"
        case .heartline: return "Heartline"
        case .bliss: return "Bliss"
        case .angel: return "Angel"
        case .clown: return "Clown"
        case .dorf: return "Dorf"
        }
    }
    var screenColor: Color {
        switch self {
        case .smiley: return Color(red: 1.0, green: 0.85, blue: 0.2)
        case .heartline: return Color(red: 0.25, green: 0.95, blue: 0.55)
        case .bliss: return Color(red: 0.45, green: 0.8, blue: 0.35)
        case .angel: return Color(red: 0.95, green: 0.92, blue: 0.8)
        case .clown: return Color(red: 1.0, green: 0.45, blue: 0.7)
        case .dorf: return Color(red: 0.25, green: 0.35, blue: 1.0)
        case .ai: return Color(red: 0.36, green: 0.84, blue: 0.67)   // SS14 Binary channel #5ed7aa
        }
    }
}

/// SS14 holopad holograms (Mobs/Silicon/holograms.rsi)
enum AIHologram: String, Codable, CaseIterable, Identifiable {
    case female, male, face, cat, dog
    var id: String { rawValue }
    var image: String { "ai_holo_\(rawValue)" }
    var label: String { rawValue.capitalized }
}

enum AIScreens {
    /// Frame delays from station_ai.rsi/meta.json
    static let delays: [String: [Double]] = [
        "ai": [0.2, 0.2, 0.1, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.1],
        "ai_smiley": [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
        "ai_heartline": [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
        "ai_bliss": [1.0],
        "ai_angel": [0.08, 0.08, 0.08, 0.08, 0.08, 0.08],
        "ai_clown": [0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
        "ai_dorf": [0.5, 0.5],
        "ai_dead": [1.0],
        "ai_empty": [0.7, 0.7],
        "ai_error": [0.7, 0.7],
        "ai_unpowered": [1.0],
        "ai_fuzz": [0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
    ]

    static func state(for mood: PAIMood, core: AICore) -> String {
        switch mood {
        case .thinking: return "ai_empty"      // ">_" terminal
        case .off: return "ai_unpowered"
        case .sad: return "ai_dead"            // blue screen
        case .surprised: return "ai_error"
        default: return core.state
        }
    }

    static func frame(for state: String, at date: Date) -> Int {
        let d = delays[state] ?? [1]
        guard d.count > 1 else { return 0 }
        let total = d.reduce(0, +)
        var t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: total)
        for (i, step) in d.enumerated() {
            if t < step { return i }
            t -= step
        }
        return 0
    }
}

// MARK: - Views

/// pAI device sprite with its screen. Pixel-perfect scaling.
struct PAIDevice: View {
    var mood: PAIMood
    var chassis: PAIChassis
    var frame: Int = 0

    var body: some View {
        ZStack {
            Image(chassis.baseImage).resizable().interpolation(.none).scaledToFit()
            Image(chassis.screenImage(mood, frame: frame)).resizable().interpolation(.none).scaledToFit()
        }
        .accessibilityLabel("\(chassis.label as String), \(mood.rawValue)")
    }
}

/// Nuclear 14 terminal (Structures/Machines/Terminals). Screen flickers; "off" shows it broken.
struct TerminalView: View {
    var mood: PAIMood
    var chassis: PAIChassis
    var frame: Int = 0

    var body: some View {
        let model = chassis.terminalModel
        ZStack {
            if mood == .off {
                Image("n14_\(model)_broken").resizable().interpolation(.none).scaledToFit()
            } else {
                Image("n14_\(model)_computer").resizable().interpolation(.none).scaledToFit()
                Image("n14_\(model)_screen_\(frame % 2)").resizable().interpolation(.none).scaledToFit()
                    .opacity(mood == .sleepy ? 0.4 : 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("\(chassis.terminalLabel), \(mood.rawValue)")
    }
}

/// Station AI core with its animated screen.
struct AICoreView: View {
    var mood: PAIMood
    var core: AICore
    var date: Date = Date()

    var body: some View {
        let state = AIScreens.state(for: mood, core: core)
        let frame = AIScreens.frame(for: state, at: date)
        ZStack {
            Image("ai_core_base").resizable().interpolation(.none).scaledToFit()
            Image("aiscreen_\(state)_\(frame)").resizable().interpolation(.none).scaledToFit()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Station AI core, \(core.label)")
    }
}

/// Whichever unit the user picked.
struct UnitView: View {
    var form: UnitForm
    var mood: PAIMood
    var chassis: PAIChassis
    var core: AICore
    var date: Date = Date()
    var frame: Int = 0

    var body: some View {
        switch form {
        case .stationAI:
            AICoreView(mood: mood, core: core, date: date)
        case .terminal:
            TerminalView(mood: mood, chassis: chassis,
                         frame: mood == .thinking ? Int(date.timeIntervalSinceReferenceDate / 0.15) : frame)
        case .pai:
            PAIDevice(mood: mood, chassis: chassis, frame: frame)
        }
    }
}

/// SS14's UI font: Noto Sans (Resources/Fonts/NotoSans), used for every piece of text,
/// exactly like SS14's Nanotrasen stylesheet.
enum SS14Font {
    /// PostScript name differs between Noto builds, so resolve it once.
    static let regularName: String = {
        for n in ["NotoSans", "NotoSans-Regular"] where UIFont(name: n, size: 12) != nil { return n }
        return "NotoSans"
    }()
    static let boldName = "NotoSans-Bold"
    static let italicName = "NotoSans-Italic"
    static let boldItalicName = "NotoSans-BoldItalic"

    static func body(_ size: CGFloat = 15) -> Font { .custom(regularName, size: size, relativeTo: .body) }
    static func bold(_ size: CGFloat = 15) -> Font { .custom(boldName, size: size, relativeTo: .body) }
    static func italic(_ size: CGFloat = 15) -> Font { .custom(italicName, size: size, relativeTo: .body) }
    static func boldItalic(_ size: CGFloat = 15) -> Font { .custom(boldItalicName, size: size, relativeTo: .body) }
    /// Headings: SS14 uses bold Noto Sans for labels and window titles.
    static func display(_ size: CGFloat = 20) -> Font { bold(size) }
    /// Numbers & console text: still Noto Sans (use .monospacedDigit() for counters).
    static func mono(_ size: CGFloat = 14, bold isBold: Bool = false) -> Font { isBold ? bold(size) : body(size) }
}
