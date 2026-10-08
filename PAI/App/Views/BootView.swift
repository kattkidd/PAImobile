import SwiftUI

/// Power-on sequence: a Nanotrasen BIOS log types out, then the unit's screen switches on.
struct BootView: View {
    @EnvironmentObject var store: AppStore
    var onDone: () -> Void

    @State private var shownLines = 0
    @State private var progress: CGFloat = 0
    @State private var unitOn = false
    @State private var finished = false
    @State private var logoIn = false

    init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    private var lines: [(String, String, Color)] {
        let s = store.settings
        let ok = SS14Palette.radioCommon
        var l: [(String, String, Color)] = [
            (ForkData.bootHeader(for: s.bootStyle).bios, "", SS14Palette.gold),
            ("CPU  positronic matrix", "OK", ok),
            ("MEM  640K ought to be enough", "OK", ok),
            ("Loading personality: \(store.paiName)", "OK", ok),
        ]
        if s.form == .stationAI {
            l.append(("Uploading lawset: \(store.activeLawset.name)", "OK", ok))
        } else {
            l.append(("Chassis: \(s.chassis.label(s.form))", "OK", ok))
        }
        l.append(store.profile.isEmpty
                 ? ("Reading ID card", "NO ID", SS14Palette.gold)
                 : ("Reading ID card: \(store.profile.fullName)", "OK", ok))
        if let sp = store.profile.character.speciesDef {
            l.append(("Crew manifest: \(sp.name.lowercased()), \(store.profile.job.name)", "OK", ok))
        }
        if s.music.enabled && !s.music.muted {
            l.append(("Lobby music: \(AudioManifest.shared.music.count) tracks", "OK", ok))
        }
        let count = store.reminders.compactMap { $0.nextOccurrence() }.count
        l.append(("Syncing calendar: \(count) reminder\(count == 1 ? "" : "s")", "OK", ok))
        for extra in ForkData.bootExtras(for: s.bootStyle) { l.append((extra.0, extra.1, ok)) }
        if let accent = store.speechAccent { l.append(("Speech synthesiser: \(accent.label) accent", "OK", ok)) }
        l.append(store.hasAPIKey
                 ? ("Neural uplink", "ONLINE", ok)
                 : ("Neural uplink", "OFFLINE", SS14Palette.caution))
        return l
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ForkLogo(size: 44)
                        .opacity(logoIn ? 1 : 0)
                        .scaleEffect(logoIn ? 1 : 1.6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ForkData.bootHeader(for: store.settings.bootStyle).title)
                            .font(SS14Font.display(22))
                            .tracking(3)
                            .foregroundStyle(SS14Palette.text)
                        Text(ForkData.bootHeader(for: store.settings.bootStyle).subtitle)
                            .font(SS14Font.mono(11))
                            .foregroundStyle(SS14Palette.textDim)
                    }
                    .opacity(logoIn ? 1 : 0)
                }

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(lines.prefix(shownLines).enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 6) {
                            Text(line.0)
                                .foregroundStyle(line.1.isEmpty ? line.2 : SS14Palette.text)
                                .lineLimit(1)
                            if !line.1.isEmpty {
                                Text(String(repeating: ".", count: 40))
                                    .foregroundStyle(SS14Palette.textDisabled)
                                    .lineLimit(1)
                                    .layoutPriority(-1)
                                Text("[\(line.1)]").foregroundStyle(line.2)
                            }
                        }
                        .font(SS14Font.mono(12))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    if shownLines < lines.count {
                        Text("█").font(SS14Font.mono(12)).foregroundStyle(SS14Palette.radioCommon)
                    }
                }

                Spacer()

                HStack {
                    Spacer()
                    UnitView(form: store.settings.form, mood: unitOn ? .happy : .off,
                             chassis: store.settings.chassis, core: store.settings.core)
                        .frame(height: 150)
                        .shadow(color: unitOn ? store.accent.opacity(0.7) : .clear, radius: 18)
                        .modifier(CRTModifier(amount: unitOn ? 1 : 0.35))
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(finished ? "> \(store.paiName.uppercased()) ONLINE." : "Booting \(store.settings.form.label)…")
                        .font(SS14Font.mono(13, bold: true))
                        .foregroundStyle(finished ? SS14Palette.radioCommon : SS14Palette.textDim)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(SS14Palette.lineEdit)
                            Rectangle().fill(SS14Palette.good).frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                    .overlay(Rectangle().stroke(SS14Palette.lineEditBorder))
                    Text("Tap to skip")
                        .font(SS14Font.body(11))
                        .foregroundStyle(SS14Palette.textDisabled)
                }
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task { await run() }
    }

    private func run() async {
        withAnimation(.easeOut(duration: 0.5)) { logoIn = true }
        SFX.powerOn.play(volume: 0.5)          // station power coming online
        try? await Task.sleep(nanoseconds: 350_000_000)
        let total = lines.count
        for i in 1...total {
            guard !finished else { return }
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.easeOut(duration: 0.12)) {
                shownLines = i
                progress = CGFloat(i) / CGFloat(total)
            }
            let line = lines[i - 1].0
            if line.hasPrefix("Reading ID card") {
                SFX.idInsert.play()
            } else if line.hasPrefix("Uploading lawset") {
                SFX.discInsert.play()
            } else {
                SoundBoard.play("keyboard\(Int.random(in: 1...4))", volume: 0.3)   // console typing
            }
        }
        guard !finished else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unitOn = true }
        SFX.bootBeep.play()
        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation { finished = true }
        try? await Task.sleep(nanoseconds: 650_000_000)
        finish()
    }

    private func finish() {
        guard !finishedCalled else { return }
        finishedCalled = true
        finished = true
        onDone()
    }

    @State private var finishedCalled = false
}
