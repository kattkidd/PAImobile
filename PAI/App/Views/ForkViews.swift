import SwiftUI

/// SS14-launcher-style server list. Each server is a one-tap preset; all their features stay available.
struct ServerBrowser: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 10) {
            ForEach(SS14Fork.allCases) { fork in
                serverCard(fork)
            }
        }
    }

    private func serverCard(_ fork: SS14Fork) -> some View {
        let connected = store.settings.fork == fork
        let t = fork.theme
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(connected ? SS14Palette.radioCommon : SS14Palette.textDisabled).frame(width: 8, height: 8)
                Text(fork.serverName).font(SS14Font.bold(16)).foregroundStyle(SS14Palette.text)
                Spacer()
                Text("\(fork.players)  ·  \(fork.ping) ms")
                    .font(SS14Font.body(11)).monospacedDigit()
                    .foregroundStyle(SS14Palette.textDim)
            }
            Text(fork.tagline)
                .font(SS14Font.body(13))
                .foregroundStyle(SS14Palette.textDim)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                // A little swatch of that server's UI colours.
                ForEach(Array([t.windowHeader, t.button, t.good, t.gold, t.text].enumerated()), id: \.offset) { _, c in
                    Rectangle().fill(c).frame(width: 16, height: 10)
                        .overlay(Rectangle().stroke(Color.black.opacity(0.4)))
                }
                Text(fork.repo).font(SS14Font.body(10)).foregroundStyle(SS14Palette.textDisabled).lineLimit(1)
                Spacer()
                if connected {
                    Text("Last applied").font(SS14Font.body(11)).foregroundStyle(SS14Palette.radioCommon)
                }
                Button(connected ? "Re-apply" : "Apply") { store.connect(to: fork) }
                    .buttonStyle(.ss14(.good, compact: true))
                    .disabled(store.connecting != nil)
            }
        }
        .padding(12)
        .background(connected ? SS14Palette.itemRowSelected : SS14Palette.panelDark)
        .overlay(Rectangle().stroke(connected ? SS14Palette.gold.opacity(0.7) : Color.white.opacity(0.06)))
    }
}

/// Goob Station and Starlight speech accents.
struct AccentPicker: View {
    @EnvironmentObject var store: AppStore
    private let previewLine = "Hello crew member, I have set your reminder for tomorrow. Good luck with the work, my friend."

    var body: some View {
        VStack(spacing: 0) {
            row(id: "none", label: "No accent", detail: "Plain Nanotrasen standard.", tag: nil)
            ForEach(["Goob Station", "Starlight"], id: \.self) { fork in
                ForEach(SpeechAccent.all.filter { $0.fork == fork }) { a in
                    row(id: a.id, label: a.label, detail: a.sample, tag: fork)
                }
            }
            if let accent = store.speechAccent {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview").font(SS14Font.bold(12)).foregroundStyle(SS14Palette.gold)
                    Text(accent.apply(previewLine))
                        .font(SS14Font.italic(13))
                        .foregroundStyle(SS14Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(store.settings.accent)
                        .transition(.opacity)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func row(id: String, label: String, detail: String, tag: String?) -> some View {
        let on = store.settings.accent == id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { store.settings.accent = id }
            if let a = SpeechAccent.find(id) {
                SFX.unitSpeech(a.sample, form: store.settings.form)
            } else {
                SFX.click.play()
            }
        } label: {
            SS14Row(alternate: on) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .foregroundStyle(on ? SS14Palette.gold : SS14Palette.textDim)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(SS14Font.bold(14))
                    Text(detail).font(SS14Font.italic(12)).foregroundStyle(SS14Palette.textDim).lineLimit(1)
                }
                Spacer()
                if let tag {
                    Text(tag).font(SS14Font.body(10)).foregroundStyle(SS14Palette.textDisabled)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// SS14 launcher "connecting" screen, shown while switching servers.
struct ConnectOverlay: View {
    @EnvironmentObject var store: AppStore
    let target: SS14Fork
    @State private var step = 0
    @State private var megabytes = Double(Int.random(in: 400...1200)) / 10

    init(target: SS14Fork) {
        self.target = target
    }

    private var steps: [String] {
        ["Resolving \(target.serverName.lowercased().replacingOccurrences(of: " ", with: "")).ss14",
         "Downloading resources (\(String(format: "%.1f", megabytes)) MB)",
         "Loading prototypes",
         "Joining as \(store.userName.isEmpty ? "Unknown" : store.userName)"]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            SS14WindowChrome(title: "Space Station 14 Launcher") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connecting to \(target.serverName)…")
                        .font(SS14Font.bold(17))
                        .foregroundStyle(SS14Palette.text)
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(spacing: 8) {
                            Image(systemName: i < step ? "checkmark.square.fill" : (i == step ? "arrow.triangle.2.circlepath" : "square"))
                                .foregroundStyle(i < step ? SS14Palette.radioCommon : SS14Palette.textDim)
                            Text(s).font(SS14Font.body(13)).foregroundStyle(i <= step ? SS14Palette.text : SS14Palette.textDisabled)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(SS14Palette.lineEdit)
                            Rectangle().fill(SS14Palette.good)
                                .frame(width: geo.size.width * CGFloat(step) / CGFloat(steps.count))
                        }
                    }
                    .frame(height: 8)
                    .overlay(Rectangle().stroke(SS14Palette.lineEditBorder))
                    Text(target.tagline).font(SS14Font.italic(12)).foregroundStyle(SS14Palette.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
            }
            .frame(maxWidth: 330)
        }
        .task {
            for i in 1...steps.count {
                try? await Task.sleep(nanoseconds: 520_000_000)
                withAnimation(.easeOut(duration: 0.2)) { step = i }
                SoundBoard.play("keyboard\(Int.random(in: 1...4))", volume: 0.3)
            }
        }
    }
}
