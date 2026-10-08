import SwiftUI

// SS14-style controls, rebuilt in SwiftUI from the Nanotrasen stylesheet
// (Content.Client/Stylesheets) and Resources/Textures/Interface/Nano.

// MARK: - Buttons

enum SS14ButtonKind { case normal, good, caution, ghost }

struct SS14ButtonStyle: ButtonStyle {
    var kind: SS14ButtonKind = .normal
    var selected = false
    var compact = false
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let terminal = SS14Palette.theme.terminal
        let lit = terminal && (selected || configuration.isPressed || kind == .good)
        return configuration.label
            .font(SS14Font.body(compact ? 13 : 15))
            .foregroundStyle(!isEnabled ? SS14Palette.textDisabled : (lit ? Color.black : (terminal && kind == .caution ? Color(hex: "FF7B7B") : SS14Palette.text)))
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 6 : 9)
            .background(ChamferShape.themed(cut: compact ? 5 : 7).fill(terminal ? (lit ? SS14Palette.gold : SS14Palette.button) : fill(pressed: configuration.isPressed)))
            .overlay(ChamferShape.themed(cut: compact ? 5 : 7).stroke(terminal ? SS14Palette.lineEditBorder : Color.black.opacity(0.35), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { SFX.click.play() }
            }
    }

    private func fill(pressed: Bool) -> Color {
        guard isEnabled else { return SS14Palette.buttonDisabled }
        if selected { return pressed ? SS14Palette.goodLight : SS14Palette.good }
        switch kind {
        case .normal: return pressed ? SS14Palette.buttonHover : SS14Palette.button
        case .good: return pressed ? SS14Palette.goodLight : SS14Palette.good
        case .caution: return pressed ? Color(hex: "CF2F2F") : SS14Palette.caution
        case .ghost: return pressed ? SS14Palette.itemRowSelected : SS14Palette.itemRow
        }
    }
}

extension ButtonStyle where Self == SS14ButtonStyle {
    static var ss14: SS14ButtonStyle { SS14ButtonStyle() }
    static func ss14(_ kind: SS14ButtonKind, selected: Bool = false, compact: Bool = false) -> SS14ButtonStyle {
        SS14ButtonStyle(kind: kind, selected: selected, compact: compact)
    }
}

// MARK: - Checkbox toggle (Interface/Nano/checkbox_checked.svg)

struct SS14CheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                configuration.label
                    .font(SS14Font.body(15))
                    .foregroundStyle(SS14Palette.text)
                Spacer(minLength: 8)
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(SS14Palette.button)
                    RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.4))
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(SS14Palette.gold)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 22, height: 22)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: configuration.isOn) { _, _ in SFX.click.play() }
    }
}

// MARK: - Headings, panels, rows, fields

/// SS14 "NanoHeading": gold title with the kinked gold underline.
struct NanoHeading: View {
    var title: String
    var trailing: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(SS14Font.bold(15))
                    .foregroundStyle(SS14Palette.gold)
                Spacer()
                if let trailing {
                    Text(trailing).font(SS14Font.mono(11)).foregroundStyle(SS14Palette.textDim)
                }
            }
            NanoHeadingLine()
                .stroke(SS14Palette.gold, lineWidth: 1.5)
                .frame(height: 6)
        }
    }
}

/// A titled block: NanoHeading over a dark bordered panel.
struct SS14Section<Content: View>: View {
    var title: String
    var trailing: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NanoHeading(title: title, trailing: trailing)
            VStack(spacing: 0) { content }
                .background(SS14Palette.panelDark)
                .overlay(Rectangle().stroke(SS14Palette.theme.terminal ? SS14Palette.lineEditBorder.opacity(0.6) : Color.white.opacity(0.07)))
                .overlay(TechFrame())
            if let footer {
                Text(footer)
                    .font(SS14Font.body(12))
                    .foregroundStyle(SS14Palette.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A list row (StyleNano item list colours) with a hairline separator.
struct SS14Row<Content: View>: View {
    var alternate = false
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) { content }
            .font(SS14Font.body(15))
            .foregroundStyle(SS14Palette.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(alternate ? SS14Palette.itemRow.opacity(0.55) : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            }
    }
}

/// SS14 LineEdit look (Interface/Nano/lineedit.png).
struct SS14FieldModifier: ViewModifier {
    var mono = false
    func body(content: Content) -> some View {
        content
            .font(mono ? SS14Font.mono(15) : SS14Font.body(15))
            .foregroundStyle(SS14Palette.text)
            .tint(SS14Palette.gold)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 3).fill(SS14Palette.lineEdit))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(SS14Palette.lineEditBorder, lineWidth: 1.5))
    }
}

extension View {
    func ss14Field(mono: Bool = false) -> some View { modifier(SS14FieldModifier(mono: mono)) }
}

/// Labeled text field row.
struct SS14FieldRow: View {
    var label: String
    var placeholder: String
    @Binding var text: String

    var body: some View {
        SS14Row {
            Text(label).foregroundStyle(SS14Palette.textDim).frame(width: 104, alignment: .leading)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(SS14Palette.textDisabled))
                .ss14Field()
        }
    }
}

/// The current server's logo: NT logo, or a terminal glyph on Nuclear 14.
struct ForkLogo: View {
    var size: CGFloat = 26
    var body: some View {
        if SS14Palette.theme.terminal {
            Image(systemName: "terminal.fill")
                .font(.system(size: size * 0.75, weight: .bold))
                .foregroundStyle(SS14Palette.gold)
                .frame(width: size, height: size)
        } else {
            Image("nt_logo")
                .renderingMode(.template)
                .resizable()
                .interpolation(.none)
                .frame(width: size, height: size)
                .foregroundStyle(SS14Palette.gold)
        }
    }
}

// MARK: - Screen header

/// Top of every tab: stripeback banner with the NT logo and a display-font title.
struct SS14ScreenHeader<Trailing: View>: View {
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            ForkLogo(size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(SS14Palette.theme.terminal ? "> " + title.uppercased() : title)
                    .font(SS14Font.display(24))
                    .foregroundStyle(SS14Palette.text)
                if let subtitle {
                    Text(subtitle)
                        .font(SS14Font.mono(11))
                        .foregroundStyle(SS14Palette.textDim)
                }
            }
            Spacer()
            trailing
            MusicMuteButton()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                SS14Palette.windowHeader
                StripeBack()
            }
        )
        .overlay(alignment: .bottom) {
            ZStack(alignment: .top) {
                Rectangle().fill(SS14Palette.gold.opacity(0.7)).frame(height: 1)
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 4).offset(y: 1)
            }
            .offset(y: 4)
        }
    }
}

extension SS14ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Menu bar (SS14's top-left game menu buttons, used as the tab bar)

struct SS14MenuBar: View {
    @Binding var selection: AppTab
    var unitLabel: String

    private var items: [(AppTab, String, String)] {
        [(.pai, "cpu", unitLabel), (.calendar, "calendar", "Calendar"), (.timers, "timer", "Timers"),
         (.id, "person.text.rectangle", "ID"), (.settings, "gearshape", "Settings")]
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isOn = selection == item.0
                Button {
                    guard selection != item.0 else { return }
                    Haptics.tap()
                    selection = item.0
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.1).font(.system(size: 17, weight: .semibold))
                        Text(item.2).font(SS14Font.body(10)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(isOn ? (SS14Palette.theme.terminal ? Color.black : Color.white) : SS14Palette.text.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        ChamferShape(cut: 7,
                                     topLeft: SS14Palette.theme.cutTopLeft && index != 0,
                                     bottomRight: SS14Palette.theme.cutBottomRight && index != items.count - 1,
                                     topRight: SS14Palette.theme.cutTopRight)
                            .fill(isOn ? (SS14Palette.theme.terminal ? SS14Palette.gold : SS14Palette.good) : SS14Palette.button)
                    )
                }
                .buttonStyle(MenuPressStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            SS14Palette.panelDark
                .overlay(alignment: .top) { Rectangle().fill(SS14Palette.gold.opacity(0.5)).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selection)
    }
}

private struct MenuPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { SFX.click.play() } }
    }
}

// MARK: - CRT effects & transitions

/// Faint CRT scanlines laid over the whole UI.
struct ScanlineOverlay: View {
    var opacity: Double = 0.05
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(opacity)))
                y += 3
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// A bright band that sweeps down the screen — played on every screen change.
struct ScanSweep: View {
    var trigger: Int
    var color: Color
    @State private var progress: CGFloat = 1.2

    init(trigger: Int, color: Color) {
        self.trigger = trigger
        self.color = color
    }

    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, color.opacity(0.22), color.opacity(0.05), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
                .offset(y: progress * (geo.size.height + 140) - 140)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onChange(of: trigger) { _, _ in
            progress = 0
            withAnimation(.easeIn(duration: 0.45)) { progress = 1.2 }
        }
    }
}

/// CRT "power on": squash to a line, then open up vertically.
struct CRTModifier: ViewModifier {
    var amount: CGFloat   // 0 = off (a line), 1 = on
    func body(content: Content) -> some View {
        content
            .scaleEffect(x: amount < 0.5 ? max(amount * 2, 0.02) : 1, y: max(amount, 0.004), anchor: .center)
            .brightness(Double(1 - amount) * 0.9)
            .opacity(amount < 0.02 ? 0 : 1)
    }
}

extension AnyTransition {
    static var crt: AnyTransition {
        .modifier(active: CRTModifier(amount: 0), identity: CRTModifier(amount: 1))
    }

    /// Slide + fade + slight glitch skew, direction-aware (used between tabs).
    static func screen(forward: Bool) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(active: ScreenSlide(offset: forward ? 60 : -60, opacity: 0, blur: 6),
                                 identity: ScreenSlide(offset: 0, opacity: 1, blur: 0)),
            removal: .modifier(active: ScreenSlide(offset: forward ? -40 : 40, opacity: 0, blur: 4),
                               identity: ScreenSlide(offset: 0, opacity: 1, blur: 0))
        )
    }
}

struct ScreenSlide: ViewModifier {
    var offset: CGFloat
    var opacity: Double
    var blur: CGFloat
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
            .blur(radius: blur)
    }
}

// MARK: - Typewriter text (new messages type out like an SS14 console)

/// Reveals a string character by character and renders each step with `render`.
struct TypewriterText: View {
    let text: String
    var animate: Bool
    var render: (String) -> Text
    var onFinish: (() -> Void)? = nil
    @State private var shown: Int = 0
    @State private var started = false

    init(text: String, animate: Bool, onFinish: (() -> Void)? = nil, render: @escaping (String) -> Text) {
        self.text = text
        self.animate = animate
        self.onFinish = onFinish
        self.render = render
    }

    var body: some View {
        render(animate ? String(text.prefix(shown)) : text)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .task(id: text) {
                guard animate, !started else { return }
                started = true
                shown = 0
                let total = text.count
                let step = max(1, total / 120)    // long replies type faster
                while shown < total {
                    try? await Task.sleep(nanoseconds: 14_000_000)
                    shown = min(total, shown + step)
                }
                onFinish?()
            }
    }
}
