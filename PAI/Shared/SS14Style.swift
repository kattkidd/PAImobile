import SwiftUI

/// SS14 servers/forks. Used for one-tap presets and boot screens; everything they add is available at once.
enum SS14Fork: String, Codable, CaseIterable, Identifiable {
    case vanilla, goob, starlight, nuclear14

    var id: String { rawValue }

    var serverName: String {
        switch self {
        case .vanilla: return "Wizard's Den"
        case .goob: return "Goob Station"
        case .starlight: return "Starlight"
        case .nuclear14: return "Nuclear 14"
        }
    }

    var repo: String {
        switch self {
        case .vanilla: return "space-wizards/space-station-14"
        case .goob: return "Goob-Station/Goob-Station"
        case .starlight: return "ss14Starlight/space-station-14"
        case .nuclear14: return "Misfit-Sanctuary/nuclear-14"
        }
    }

    var tagline: String {
        switch self {
        case .vanilla: return "Space Station 14 as the wizards intended. Crewsimov, greytide and a pAI."
        case .goob: return "Everything upstream, plus 9,000 extra features. Accents. Chaos. Ohio."
        case .starlight: return "Heavy roleplay, a prettier UI, radio blips and borgis who are good boys."
        case .nuclear14: return "Post-apocalyptic roleplay. Your assistant is now a crusty old terminal."
        }
    }

    /// Silly launcher stats.
    var players: String {
        switch self {
        case .vanilla: return "87/120"
        case .goob: return "212/250"
        case .starlight: return "64/80"
        case .nuclear14: return "41/100"
        }
    }
    var ping: Int {
        switch self {
        case .vanilla: return 38
        case .goob: return 112
        case .starlight: return 54
        case .nuclear14: return 201
        }
    }

    /// The UI theme this server's preset applies.
    var uiTheme: UITheme {
        switch self {
        case .vanilla, .goob: return .nanotrasen
        case .starlight: return .starlight
        case .nuclear14: return .terminal
        }
    }
    var theme: ForkTheme { uiTheme.theme }
}

/// Interface skin. Every one is available whatever else you pick.
enum UITheme: String, Codable, CaseIterable, Identifiable {
    case nanotrasen, space, starlight, terminal

    var id: String { rawValue }

    /// Set by the app (and the widget) so every view picks up the active theme.
    static var current: UITheme = .nanotrasen

    var label: String {
        switch self {
        case .nanotrasen: return "Nanotrasen"
        case .space: return "Launcher"
        case .starlight: return "Starlight"
        case .terminal: return "Wasteland terminal"
        }
    }
    var source: String {
        switch self {
        case .nanotrasen: return "SS14 StyleNano"
        case .space: return "SS14 StyleSpace"
        case .starlight: return "Starlight StyleStarlight"
        case .terminal: return "Nuclear 14"
        }
    }
    var theme: ForkTheme {
        switch self {
        case .nanotrasen: return .nanotrasen
        case .space: return .space
        case .starlight: return .starlight
        case .terminal: return .terminal
        }
    }
}

/// UI colours. Nanotrasen = SS14's StyleNano; Space = StyleSpace (launcher); Starlight = StyleStarlight.cs;
/// Terminal = a green phosphor look for Nuclear 14.
struct ForkTheme {
    var windowBackground, windowHeader, windowBorder, panelDark, space, gold: Color
    var button, buttonHover, buttonDisabled, good, goodLight, caution: Color
    var lineEdit, lineEditBorder, itemRow, itemRowSelected: Color
    var text, textDim, textDisabled, alertHeader: Color
    /// Button corners: SS14 cuts top-left + bottom-right, Starlight cuts top-right only, terminals are square.
    var cutTopLeft = true, cutTopRight = false, cutBottomRight = true
    var terminal = false
    var techFrame = false

    static let nanotrasen = ForkTheme(
        windowBackground: Color(hex: "25252A"), windowHeader: Color(hex: "2F2F3B"), windowBorder: Color(hex: "323446"),
        panelDark: Color(hex: "1E1E22"), space: Color(hex: "0F0F14"), gold: Color(hex: "A88B5E"),
        button: Color(hex: "464966"), buttonHover: Color(hex: "575B7F"), buttonDisabled: Color(hex: "30313C"),
        good: Color(hex: "3E6C45"), goodLight: Color(hex: "31843E"), caution: Color(hex: "AB3232"),
        lineEdit: Color(hex: "3D4059"), lineEditBorder: Color(hex: "35374D"),
        itemRow: Color(hex: "373744"), itemRowSelected: Color(hex: "4B4B56"),
        text: Color(hex: "E5E5E5"), textDim: Color(hex: "A0A0A8"), textDisabled: Color(hex: "5A5A5A"),
        alertHeader: Color(hex: "96001E"))

    /// SS14's launcher / main menu stylesheet (StyleSpace.cs): SpaceRed accents on deep blue-black.
    static let space = ForkTheme(
        windowBackground: Color(hex: "1A1A26"), windowHeader: Color(hex: "202030"), windowBorder: Color(hex: "9B2236"),
        panelDark: Color(hex: "14141E"), space: Color(hex: "0B0B12"), gold: Color(hex: "9B2236"),
        button: Color(hex: "464966"), buttonHover: Color(hex: "575B7F"), buttonDisabled: Color(hex: "30313C"),
        good: Color(hex: "3E6C45"), goodLight: Color(hex: "31843E"), caution: Color(hex: "AB3232"),
        lineEdit: Color(hex: "2A2A3C"), lineEditBorder: Color(hex: "3A3A52"),
        itemRow: Color(hex: "242434"), itemRowSelected: Color(hex: "3A2A3A"),
        text: Color(hex: "E5E5E5"), textDim: Color(hex: "A5A5B5"), textDisabled: Color(hex: "5A5A66"),
        alertHeader: Color(hex: "9B2236"))

    static let starlight = ForkTheme(
        windowBackground: Color(hex: "171715"), windowHeader: Color(hex: "232320"), windowBorder: Color(hex: "3A4A52"),
        panelDark: Color(hex: "141412"), space: Color(hex: "0C0C0A"), gold: Color(hex: "5B8499"),
        button: Color(hex: "464966"), buttonHover: Color(hex: "575B7F"), buttonDisabled: Color(hex: "30313C"),
        good: Color(hex: "3E6C45"), goodLight: Color(hex: "31843E"), caution: Color(hex: "931313"),
        lineEdit: Color(hex: "24242B"), lineEditBorder: Color(hex: "3A4A52"),
        itemRow: Color(hex: "1F1F23"), itemRowSelected: Color(hex: "373744"),
        text: Color(hex: "E5E5E5"), textDim: Color(hex: "9AA4AA"), textDisabled: Color(hex: "5A5A5A"),
        alertHeader: Color(hex: "7F3636"),
        cutTopLeft: false, cutTopRight: true, cutBottomRight: false, techFrame: true)

    static let terminal = ForkTheme(
        windowBackground: Color(hex: "0A140C"), windowHeader: Color(hex: "0F2414"), windowBorder: Color(hex: "2E8B4A"),
        panelDark: Color(hex: "07100A"), space: Color(hex: "040805"), gold: Color(hex: "5CFF8F"),
        button: Color(hex: "0F2A17"), buttonHover: Color(hex: "1A4426"), buttonDisabled: Color(hex: "0A1A0E"),
        good: Color(hex: "2E8B4A"), goodLight: Color(hex: "3FB862"), caution: Color(hex: "8B2E2E"),
        lineEdit: Color(hex: "0C1E11"), lineEditBorder: Color(hex: "2E8B4A"),
        itemRow: Color(hex: "0D1F12"), itemRowSelected: Color(hex: "163A20"),
        text: Color(hex: "7CFFA4"), textDim: Color(hex: "3FAF68"), textDisabled: Color(hex: "24603A"),
        alertHeader: Color(hex: "6B1A1A"),
        cutTopLeft: false, cutTopRight: false, cutBottomRight: false, terminal: true)
}

/// The active palette (follows UITheme.current).
enum SS14Palette {
    static var theme: ForkTheme { UITheme.current.theme }
    static var windowBackground: Color { theme.windowBackground }
    static var windowHeader: Color { theme.windowHeader }
    static var windowBorder: Color { theme.windowBorder }
    static var panelDark: Color { theme.panelDark }
    static var space: Color { theme.space }
    static var gold: Color { theme.gold }
    static var button: Color { theme.button }
    static var buttonHover: Color { theme.buttonHover }
    static var buttonDisabled: Color { theme.buttonDisabled }
    static var good: Color { theme.good }
    static var goodLight: Color { theme.goodLight }
    static var caution: Color { theme.caution }
    static var lineEdit: Color { theme.lineEdit }
    static var lineEditBorder: Color { theme.lineEditBorder }
    static var itemRow: Color { theme.itemRow }
    static var itemRowSelected: Color { theme.itemRowSelected }
    static var text: Color { theme.text }
    static var textDim: Color { theme.textDim }
    static var textDisabled: Color { theme.textDisabled }
    static var alertHeader: Color { theme.alertHeader }
    // Radio channel colours (Resources/Prototypes/radio_channels.yml)
    static let radioCommon = Color(hex: "2CDB2C")
    static let radioBinary = Color(hex: "5ED7AA")
    static let radioCommand = Color(hex: "FCDF03")
}

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

/// SS14's button shape (Interface/Nano/button.svg): a box with two opposite corners cut off.
struct ChamferShape: Shape {
    var cut: CGFloat = 6
    var topLeft = true
    var bottomRight = true
    var topRight = false

    /// The active fork's button shape.
    static func themed(cut: CGFloat = 6) -> ChamferShape {
        let t = SS14Palette.theme
        return ChamferShape(cut: cut, topLeft: t.cutTopLeft, bottomRight: t.cutBottomRight, topRight: t.cutTopRight)
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = min(cut, r.width / 3, r.height / 3)
        p.move(to: CGPoint(x: r.minX + (topLeft ? c : 0), y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - (topRight ? c : 0), y: r.minY))
        if topRight { p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c)) }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - (bottomRight ? c : 0)))
        p.addLine(to: CGPoint(x: r.maxX - (bottomRight ? c : 0), y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + (topLeft ? c : 0)))
        p.closeSubpath()
        return p
    }
}

/// SS14's geometric panel border (Interface/Nano/geometric_panel_border.svg): all four corners cut.
struct OctagonShape: Shape {
    var cut: CGFloat = 8
    func path(in r: CGRect) -> Path {
        let c = min(cut, r.width / 3, r.height / 3)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.closeSubpath()
        return p
    }
}

/// SS14 "NanoHeading" (Interface/Nano/nanoheading.svg): gold underline that kinks up at the end.
struct NanoHeadingLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - 6, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 6))
        return p
    }
}

/// SS14 stripeback (Interface/Nano/stripeback.svg): dark diagonal hazard stripes.
struct StripeBack: View {
    var color: Color = Color.white.opacity(0.035)
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = -size.height
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height + 8, y: 0))
                p.addLine(to: CGPoint(x: x + 8, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
                x += 16
            }
        }
    }
}

/// Starlight's pixel tech border (Interface/Nano/border.png), shown with the Starlight theme.
struct TechFrame: View {
    var body: some View {
        if SS14Palette.theme.techFrame {
            Image("sl_border")
                .renderingMode(.template)
                .resizable(capInsets: EdgeInsets(top: 32, leading: 32, bottom: 32, trailing: 32), resizingMode: .stretch)
                .interpolation(.none)
                .foregroundStyle(SS14Palette.gold.opacity(0.75))
                .padding(-3)
                .allowsHitTesting(false)
        }
    }
}

/// SS14 window: header bar with shadow (window_header.png) over the window body.
struct SS14WindowChrome<Content: View>: View {
    var title: String
    var alert = false
    var trailing: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(SS14Palette.theme.terminal ? "[ " + title.uppercased() + " ]" : title)
                    .font(SS14Font.display(15))
                    .foregroundStyle(SS14Palette.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let trailing { trailing }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(alert ? SS14Palette.alertHeader : SS14Palette.windowHeader)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.black.opacity(0.75), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 3)
                    .offset(y: 3)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SS14Palette.windowBackground)
        }
        .overlay(Rectangle().stroke(SS14Palette.windowBorder, lineWidth: 1))
        .overlay(TechFrame())
    }
}
