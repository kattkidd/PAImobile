import SwiftUI
import UserNotifications

struct SettingsScreen: View {
    @EnvironmentObject var store: AppStore
    @State private var page: Page = .customise
    @State private var keyDraft = ""
    @State private var testResult: String?
    @State private var testing = false
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmReset = false
    @State private var showCredits = false

    enum Page: String, CaseIterable { case customise = "Customise", audio = "Sound & music", mind = "Mind", system = "System" }

    var body: some View {
        VStack(spacing: 0) {
            SS14ScreenHeader(title: "Settings", subtitle: "Silicon configuration")
            // SS14 options window tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Page.allCases, id: \.self) { p in
                        Button(p.rawValue) { withAnimation(.easeInOut(duration: 0.22)) { page = p } }
                            .buttonStyle(.ss14(.normal, selected: page == p, compact: true))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(SS14Palette.panelDark)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch page {
                    case .customise: customisePage
                    case .audio: audioPage
                    case .mind: brainSection
                    case .system: systemPage
                    }
                }
                .padding(12)
                .id(page)
                .transition(.opacity.combined(with: .offset(y: 12)))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.settings.form)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(SS14Palette.space.ignoresSafeArea())
        .task { notifStatus = await Notifier.status() }
        .sheet(isPresented: $showCredits) { CreditsView() }
        .confirmationDialog("Erase your ID, character, calendar, timers, chat and settings?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { store.resetEverything() }
        }
    }

    // MARK: Customise (every fork's features, mixed however you like)

    @ViewBuilder private var customisePage: some View {
        SS14Section(title: "Quick presets", trailing: "\(SS14Fork.allCases.count) servers",
                    footer: "One tap applies a whole server's vibe (theme, personality, voice, sounds, boot screen). Everything below stays mix-and-match.") {
            ServerBrowser().padding(10)
        }
        themeSection
        unitSection
        UnitCustomizer()
        personalitySection
        SS14Section(title: "Speech accent",
                    footer: "Accents from Goob Station and Starlight. Like in-game, they rewrite what your unit says.") {
            AccentPicker()
        }
        if store.isStationAI {
            VStack(alignment: .leading, spacing: 8) {
                NanoHeading(title: "Lawset", trailing: store.activeLawset.name)
                LawsetPicker()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        colourSection
        bootSection
    }

    private var themeSection: some View {
        SS14Section(title: "Interface theme", footer: "\(store.settings.theme.label): \(store.settings.theme.source).") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(UITheme.allCases) { t in
                    let th = t.theme
                    let on = store.settings.theme == t
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) { store.settings.theme = t }
                        SFX.discInsert.play()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 0) {
                                ForEach(Array([th.windowHeader, th.button, th.good, th.gold, th.text].enumerated()), id: \.offset) { _, c in
                                    Rectangle().fill(c).frame(height: 14)
                                }
                            }
                            .clipShape(ChamferShape(cut: 4, topLeft: th.cutTopLeft, bottomRight: th.cutBottomRight, topRight: th.cutTopRight))
                            Text(t.label).font(SS14Font.bold(13)).foregroundStyle(th.text)
                            Text(t.source).font(SS14Font.body(10)).foregroundStyle(th.textDim)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(th.windowBackground)
                        .overlay(Rectangle().stroke(on ? th.gold : Color.white.opacity(0.08), lineWidth: on ? 2 : 1))
                        .scaleEffect(on ? 1.03 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            Group {
                Toggle("CRT scanlines & screen sweep", isOn: $store.settings.crtEffects)
                Toggle("Action animations", isOn: $store.settings.animations)
            }
            .toggleStyle(SS14CheckboxStyle())
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private var unitSection: some View {
        SS14Section(title: "Unit", footer: "\(store.settings.form.blurb) (\(store.settings.form.source))") {
            HStack(spacing: 6) {
                ForEach(UnitForm.allCases) { f in
                    Button {
                        store.switchForm(to: f)
                    } label: {
                        VStack(spacing: 4) {
                            UnitView(form: f, mood: .neutral, chassis: store.settings.chassis, core: store.settings.core)
                                .frame(width: 34, height: 34)
                            Text(f.label).font(SS14Font.bold(12)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SS14ButtonStyle(kind: .normal, selected: store.settings.form == f, compact: true))
                }
            }
            .padding(10)
        }
    }

    private var personalitySection: some View {
        SS14Section(title: "Personality", footer: "How \(store.paiName) talks. Each one comes from a fork.") {
            ForEach(Array(Personality.allCases.enumerated()), id: \.offset) { i, p in
                choiceRow(p.label, p.detail, on: store.settings.personality == p, alternate: i % 2 == 1) {
                    store.settings.personality = p
                    store.unitAnim = AnimEvent(kind: .bounce)
                }
            }
        }
    }

    private var bootSection: some View {
        SS14Section(title: "Boot screen", footer: "Which BIOS log plays when the app starts.") {
            HStack(spacing: 6) {
                ForEach(SS14Fork.allCases) { f in
                    Button(f.serverName) { store.settings.bootStyle = f }
                        .buttonStyle(.ss14(.normal, selected: store.settings.bootStyle == f, compact: true))
                }
            }
            .padding(10)
            Toggle("Boot sequence on launch", isOn: $store.settings.bootSequence)
                .toggleStyle(SS14CheckboxStyle())
                .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private func choiceRow(_ title: String, _ detail: String, on: Bool, alternate: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { action() }
            SFX.click.play()
        } label: {
            SS14Row(alternate: alternate) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .foregroundStyle(on ? SS14Palette.gold : SS14Palette.textDim)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(SS14Font.bold(14))
                    Text(detail).font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var colourSection: some View {
        SS14Section(title: "Interface colour") {
            HStack(spacing: 10) {
                ForEach(PAIColor.allCases) { c in
                    let col = c.resolved(form: store.settings.form, chassis: store.settings.chassis, core: store.settings.core)
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { store.settings.color = c }
                    } label: {
                        ChamferShape(cut: 5)
                            .fill(col)
                            .frame(width: 34, height: 34)
                            .overlay(ChamferShape(cut: 5).stroke(Color.white, lineWidth: store.settings.color == c ? 2.5 : 0))
                            .scaleEffect(store.settings.color == c ? 1.1 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.label)
                }
            }
            .padding(10)
        }
    }

    // MARK: Sound & music

    @ViewBuilder private var audioPage: some View {
        MusicPanel()
        SS14Section(title: "Unit voice", footer: SFX.unitVoice.detail) {
            ForEach(Array(UnitVoiceStyle.allCases.enumerated()), id: \.offset) { i, v in
                choiceRow(v.label, v.detail, on: store.settings.unitVoice == v, alternate: i % 2 == 1) {
                    store.settings.unitVoice = v
                    SFX.unitSpeech("Testing, testing!", form: store.settings.form)
                    store.unitAnim = AnimEvent(kind: .talk)
                }
            }
        }
        if store.settings.unitVoice == .bark || (store.settings.unitVoice == .auto && store.settings.form == .terminal) {
            SS14Section(title: "Bark", trailing: "\(AudioManifest.shared.barks.count) barks",
                        footer: "Barks from Nuclear 14 (Misfits & NC bark sets), Starlight and Goob Station.") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                    ForEach(AudioManifest.shared.barks) { b in
                        Button(b.name) {
                            store.settings.unitBark = b.sound
                            Bark.play("Hello there friend", sound: b.sound)
                        }
                        .buttonStyle(.ss14(.normal, selected: store.settings.unitBark == b.sound, compact: true))
                    }
                }
                .padding(8)
            }
        }
        SS14Section(title: "Sound pack", footer: "Which fork's ID card, announcement and alert sounds to use.") {
            ForEach(Array(SoundPack.allCases.enumerated()), id: \.offset) { i, p in
                choiceRow(p.label, i == 0 ? "SS14 announcements and ID sounds" : i == 1 ? "Starlight announce2, attention and ID card handling" : "Nuclear 14 ring bark for reminders",
                          on: store.settings.soundPack == p, alternate: i % 2 == 1) {
                    store.settings.soundPack = p
                    SFX.announce.play()
                }
            }
        }
        SS14Section(title: "Sound options",
                    footer: "Tip: tap the microphone on the iPhone keyboard to talk to \(store.paiName).") {
            Group {
                Toggle("All sounds", isOn: $store.settings.sounds)
                Toggle("Keyboard typing sounds", isOn: $store.settings.typingSounds)
                Toggle("Species emote sounds (*scream, *laugh…)", isOn: $store.settings.emoteSounds)
                Toggle("Starlight job radio blips when I talk", isOn: $store.settings.radioBlips)
                Toggle("Goob chat ping on highlights", isOn: $store.settings.highlightPing)
                Toggle("Read replies aloud", isOn: $store.settings.speakReplies)
            }
            .toggleStyle(SS14CheckboxStyle())
            .padding(.horizontal, 12).padding(.vertical, 9)
        }
        soundBoardSection
    }

    // MARK: Mind

    private var brainSection: some View {
        SS14Section(title: "Neural uplink",
                    footer: "Get a key at platform.openai.com → API keys, and add a little credit under Billing. A ChatGPT subscription (Go/Plus) does not include API access. Your key is stored in the iPhone Keychain.") {
            SS14Row {
                Image(systemName: store.hasAPIKey ? "checkmark.seal.fill" : "xmark.seal")
                    .foregroundStyle(store.hasAPIKey ? SS14Palette.radioCommon : SS14Palette.caution)
                Text(store.hasAPIKey ? "Mind installed" : SS14.notInstalled)
                Spacer()
                if store.hasAPIKey {
                    Button("Remove") { store.setAPIKey(""); testResult = nil }
                        .buttonStyle(.ss14(.caution, compact: true))
                }
            }
            SS14Row(alternate: true) {
                SecureField("", text: $keyDraft, prompt: Text("Paste OpenAI API key (sk-…)").foregroundColor(SS14Palette.textDisabled))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .ss14Field(mono: true)
                Button("Save") {
                    store.setAPIKey(keyDraft)
                    keyDraft = ""
                    testResult = nil
                    Haptics.success()
                }
                .buttonStyle(.ss14(.good, compact: true))
                .disabled(keyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            SS14FieldRow(label: "Model", placeholder: "gpt-5.4-mini", text: $store.settings.model)
            Toggle("Web search", isOn: $store.settings.webSearch)
                .toggleStyle(SS14CheckboxStyle())
                .padding(.horizontal, 12).padding(.vertical, 10)
            SS14Row(alternate: true) {
                Button {
                    Task { await test() }
                } label: {
                    HStack {
                        Text("Run diagnostics")
                        if testing { ProgressView().tint(SS14Palette.gold) }
                    }
                }
                .buttonStyle(.ss14(.normal, compact: true))
                .disabled(!store.hasAPIKey || testing)
                if let testResult {
                    Text(testResult).font(SS14Font.mono(11)).foregroundStyle(SS14Palette.textDim).lineLimit(2)
                }
            }
        }
    }

    // MARK: System

    @ViewBuilder private var systemPage: some View {
        SS14Section(title: "Chat",
                    footer: "Highlights work like SS14's chat highlights: your name and your station job's keywords show in #17FFC1.") {
            Toggle("Highlight my name & job in chat", isOn: $store.settings.highlights)
                .toggleStyle(SS14CheckboxStyle())
                .padding(.horizontal, 12).padding(.vertical, 10)
            SS14Row(alternate: true) {
                Button("Run setup again") {
                    store.settings.onboarded = false
                    SFX.bootBeep.play()
                }
                .buttonStyle(.ss14(.normal, compact: true))
                Text("Takes effect next launch").font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
            }
        }
        alertsSection
        widgetSection
        dataSection
    }

    /// Every sound in the app, with where it's used. Tap to preview.
    private var soundBoardSection: some View {
        SS14Section(title: "Sound board", trailing: "\(SoundCatalog.items.count) sounds",
                    footer: "Sounds from Space Station 14, Goob Station, Starlight and Nuclear 14. Tap one to hear it (silent switch off).") {
            ForEach(Array(SoundCatalog.items.enumerated()), id: \.offset) { i, item in
                Button {
                    SoundBoard.play(item.file)
                } label: {
                    SS14Row(alternate: i % 2 == 1) {
                        Image(systemName: "speaker.wave.2.fill").foregroundStyle(store.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(SS14Font.bold(14))
                            Text(item.use).font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var alertsSection: some View {
        SS14Section(title: "Alerts", footer: "Reminders and timers use notifications, so they still go off when the app is closed.") {
            SS14Row {
                Text("Notifications")
                Spacer()
                Text(statusText).font(SS14Font.mono(13))
                    .foregroundStyle(notifStatus == .denied ? SS14Palette.caution : SS14Palette.radioCommon)
                if notifStatus == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .buttonStyle(.ss14(.normal, compact: true))
                }
            }
        }
    }

    private var widgetSection: some View {
        SS14Section(title: "Widgets") {
            Text("Home Screen: long-press an empty spot → Edit → Add Widget → search \"PAI\".\nLock Screen: long-press the Lock Screen → Customize → Lock Screen → tap the widget row → PAI.")
                .font(SS14Font.body(13))
                .foregroundStyle(SS14Palette.text)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dataSection: some View {
        SS14Section(title: "Data") {
            HStack(spacing: 8) {
                Button("Credits") { showCredits = true }.buttonStyle(.ss14(.normal, compact: true))
                Button("Clear chat") { withAnimation { store.clearChat() } }.buttonStyle(.ss14(.normal, compact: true))
                Spacer()
                Button("Reset all") { confirmReset = true }.buttonStyle(.ss14(.caution, compact: true))
            }
            .padding(10)
        }
    }

    private var statusText: String {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return "ON"
        case .denied: return "OFF"
        default: return "NOT ASKED"
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        do {
            let reply = try await OpenAIClient(apiKey: store.apiKey, model: store.settings.model).test()
            testResult = "✓ \(reply)"
            store.flash(.happy)
            SFX.chime.play()
        } catch {
            testResult = "✗ \(error.localizedDescription)"
            store.flash(.sad)
            SFX.buzzTwo.play()
        }
    }
}

/// Lobby music player: SS14 + fork lobby tracks, with mute, volume, shuffle, playlists and ambience.
struct MusicPanel: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var player = MusicPlayer.shared

    var body: some View {
        let m = store.settings.music
        SS14Section(title: "Lobby music", trailing: "\(AudioManifest.shared.music.count) tracks",
                    footer: "Lobby and jukebox tracks from SS14 and the forks (see Credits). Respects the silent switch.") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    EqualizerBars(playing: player.isPlaying && !m.muted, color: store.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.current?.title ?? "Nothing playing").font(SS14Font.bold(15)).lineLimit(1)
                        Text(player.current.map { "\($0.artist) · \($0.playlist)" } ?? "Press play")
                            .font(SS14Font.body(11)).foregroundStyle(SS14Palette.textDim).lineLimit(1)
                    }
                    Spacer()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(SS14Palette.lineEdit)
                        Rectangle().fill(store.accent.opacity(0.8)).frame(width: geo.size.width * player.progress)
                    }
                }
                .frame(height: 4)
                HStack(spacing: 6) {
                    Button { player.previous(); SFX.click.play() } label: { Image(systemName: "backward.fill") }
                        .buttonStyle(.ss14(.normal, compact: true))
                    Button {
                        if m.muted { store.settings.music.muted = false }
                        player.toggle()
                    } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 22) }
                        .buttonStyle(.ss14(.good, compact: true))
                    Button { player.next(); SFX.click.play() } label: { Image(systemName: "forward.fill") }
                        .buttonStyle(.ss14(.normal, compact: true))
                    Spacer()
                    Button {
                        store.settings.music.muted.toggle()
                    } label: {
                        Label(m.muted ? "Muted" : "Mute", systemImage: m.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                    .buttonStyle(.ss14(m.muted ? .caution : .normal, compact: true))
                }
                HStack {
                    Image(systemName: "speaker.fill").foregroundStyle(SS14Palette.textDim)
                    Slider(value: $store.settings.music.volume, in: 0...1).tint(SS14Palette.gold)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(SS14Palette.textDim)
                }
            }
            .padding(12)
            Group {
                Toggle("Music enabled", isOn: $store.settings.music.enabled)
                Toggle("Play on launch", isOn: $store.settings.music.autoplay)
                Toggle("Shuffle", isOn: $store.settings.music.shuffle)
            }
            .toggleStyle(SS14CheckboxStyle())
            .padding(.horizontal, 12).padding(.vertical, 8)
            SS14Row(alternate: true) {
                Text("Playlists").foregroundStyle(SS14Palette.textDim)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AudioManifest.shared.playlists, id: \.self) { pl in
                        let on = m.playlists.isEmpty || m.playlists.contains(pl)
                        Button(pl) { togglePlaylist(pl) }
                            .buttonStyle(.ss14(.normal, selected: on, compact: true))
                    }
                }
                .padding(10)
            }
            SS14Row(alternate: true) {
                Text("Ambience").foregroundStyle(SS14Palette.textDim)
                Spacer()
                Menu {
                    Button("Off") { store.settings.music.ambience = nil }
                    ForEach(AudioManifest.shared.ambience) { a in
                        Button(a.name) { store.settings.music.ambience = a.file }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(AudioManifest.shared.ambience.first { $0.file == m.ambience }?.name ?? "Off")
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                }
            }
            if m.ambience != nil {
                HStack {
                    Text("Ambience volume").font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
                    Slider(value: $store.settings.music.ambienceVolume, in: 0...1).tint(SS14Palette.gold)
                }
                .padding(.horizontal, 12).padding(.bottom, 10)
            }
            trackList
        }
    }

    private var trackList: some View {
        VStack(spacing: 0) {
            ForEach(Array(player.tracks.enumerated()), id: \.offset) { i, t in
                Button {
                    store.settings.music.muted = false
                    player.start(t)
                } label: {
                    SS14Row(alternate: i % 2 == 1) {
                        Image(systemName: player.current == t ? "music.note" : "play.circle")
                            .foregroundStyle(player.current == t ? store.accent : SS14Palette.textDim)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.title).font(SS14Font.body(13)).lineLimit(1)
                            Text("\(t.artist) · \(t.license)").font(SS14Font.body(10)).foregroundStyle(SS14Palette.textDim).lineLimit(1)
                        }
                        Spacer()
                        Text(t.playlist).font(SS14Font.body(10)).foregroundStyle(SS14Palette.textDisabled)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func togglePlaylist(_ pl: String) {
        var list = store.settings.music.playlists
        if list.isEmpty { list = AudioManifest.shared.playlists }
        if list.contains(pl) { list.removeAll { $0 == pl } } else { list.append(pl) }
        if list.isEmpty || Set(list) == Set(AudioManifest.shared.playlists) { list = [] }
        store.settings.music.playlists = list
        SFX.click.play()
    }
}

/// SS14 law display window (shown from the Station AI home screen).
struct LawsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let set = store.activeLawset
        SS14WindowChrome(title: "Laws — \(set.name)", trailing: AnyView(
            Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }
                .buttonStyle(.plain).foregroundStyle(SS14Palette.textDim)
        )) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        AICoreView(mood: .neutral, core: store.settings.core).frame(height: 54)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.paiName).font(SS14Font.display(18)).foregroundStyle(SS14Palette.text)
                            Text("Obeys: \(store.userName.isEmpty ? "the crew" : store.userName)")
                                .font(SS14Font.mono(12)).foregroundStyle(SS14Palette.radioBinary)
                        }
                    }
                    NanoHeading(title: "Active laws")
                    ForEach(Array(set.laws.enumerated()), id: \.offset) { i, law in
                        (Text("Law \(i + 1): ").font(SS14Font.bold(15)) + Text(law).font(SS14Font.body(15)))
                            .foregroundStyle(SS14Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Change the lawset in Settings.")
                        .font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
                }
                .padding(14)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(SS14Palette.windowBackground)
        .preferredColorScheme(.dark)
    }
}

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss

    private let entries: [(String, String)] = [
        ("About", "This app uses content from Space Station 14 (github.com/space-wizards/space-station-14). It is a fan project and isn't affiliated with Space Wizards."),
        ("pAI sprites — CC BY-SA 3.0", "pai.rsi: taken from tgstation (commit 9ddb8cf); pai-searching-overlay heavily modified; Syndicate variants by fedKotikeD; potato by Doru991; golden pAI from ScrapPAIGold by AsnDen. Extra screen faces adapted for this app under the same licence."),
        ("Station AI sprites — CC BY-SA 3.0", "station_ai.rsi and holograms.rsi: taken from vgstation (commit e2923df), modified by chromiumboy; base modified by monotheonist."),
        ("ID cards & job icons — CC BY-SA 3.0", "id_cards.rsi and job_icons.rsi: taken and modified from /tg/station 13, with edits by AJCM-git, CrudeWax, DinnerCalzone and other SS14 contributors."),
        ("NT logo — CC BY-SA 3.0", "Interface/Nano/ntlogo.svg from Space Station 14."),
        ("Sounds", "pai.ogg, pai_ask.ogg, pai_exclaim.ogg by hubismal (CC BY 3.0). borg.ogg, borg_ask.ogg, borg_exclaim.ogg recorded and mixed by MilenVolf (CC BY-SA 4.0). twobeep, chime, buzz-sigh, ping from /tg/station (CC BY-SA 3.0). click.ogg by el_boss, edited by mirrorcult (CC0). beep.ogg by dotY21 (CC0). quickbeep.ogg by BasedUser (CC0)."),
        ("Fonts", "Noto Sans and Noto Sans Display (SIL OFL / Apache 2.0), Roboto Mono (Apache 2.0), as bundled with SS14."),
        ("UI & data", "Colours and control shapes recreated from SS14's Nanotrasen and Space stylesheets and Starlight's StyleStarlight. Jobs, departments, lawsets, AI names, radio colours and pAI wording from SS14's Resources (MIT-licensed repository)."),
        ("Characters", "Species, hair, markings, clothing and displacement maps from Space Station 14, Goob Station (incl. Delta-V, Nyanotrasen, Einstein Engines ports), Starlight and Nuclear 14. Mostly CC BY-SA 3.0; some fork sprites are CC BY-NC-SA. Full list in CREDITS.md."),
        ("Voices & emotes", "Species talk and emote sounds from SS14 and the forks' Resources/Audio/Voice (CC0, CC BY, CC BY-SA, CC BY-NC-SA). Barks from Nuclear 14 (Misfits, NC/BlueMoon), Starlight and Goob Station."),
        ("Music", "Lobby/jukebox tracks: SolusLunes, ZhayTee, Philip Dyer, Janis Schiedková, Stellardrone, Cuboos, Hayabusa, Sunbeamstress, mrjajkes, Waterflame, Crockitz, Bobik-music, Merct, NИTRODE, SlendyMawn & Scruq, finket, Jonathan Coulton, A-Guy173, Bad History, Bolgarich, Beptol Corporation Acoustics, JAM, hermitsabee, SOULFULJAMTRACKS, Andreas Viklund, Patricia Taxxon, Ghirardelli7, Psirius. Licences per track in Settings → Sound & music."),
    ]

    var body: some View {
        SS14WindowChrome(title: "Credits", trailing: AnyView(
            Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }
                .buttonStyle(.plain).foregroundStyle(SS14Palette.textDim)
        )) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, e in
                        VStack(alignment: .leading, spacing: 6) {
                            NanoHeading(title: e.0)
                            Text(e.1).font(SS14Font.body(13)).foregroundStyle(SS14Palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(14)
            }
        }
        .presentationBackground(SS14Palette.windowBackground)
        .preferredColorScheme(.dark)
    }
}

/// Where each SS14 sound is used (also shown in Settings → Sound board).
enum SoundCatalog {
    struct Item { let name: String; let file: String; let use: String }
    static let items: [Item] = baseItems + barkItems
    private static let barkItems: [Item] = AudioManifest.shared.barks.map { b -> Item in
        Item(name: "Bark: \(b.name)", file: b.sound, use: "\(b.source) bark (Settings → Unit voice → Barks)")
    }
    private static let baseItems: [Item] = [
        Item(name: "pAI voice", file: "pai_say", use: "pAI talking (says)"),
        Item(name: "pAI voice — ask", file: "pai_ask", use: "pAI replies ending in ?"),
        Item(name: "pAI voice — exclaim", file: "pai_exclaim", use: "pAI replies ending in !"),
        Item(name: "Borg voice", file: "borg_say", use: "Station AI talking"),
        Item(name: "Borg voice — ask", file: "borg_ask", use: "Station AI questions"),
        Item(name: "Borg voice — exclaim", file: "borg_exclaim", use: "Station AI exclamations"),
        Item(name: "Your voice", file: AudioManifest.shared.speech["Alto"]?.say ?? "", use: "Your messages (pick a voice in the character editor)"),
        Item(name: "Keyboard", file: "keyboard1", use: "Typing in the chat box, boot log"),
        Item(name: "UI click", file: "click", use: "Every button"),
        Item(name: "UI hover", file: "hover", use: "Picking days, wheels, going back"),
        Item(name: "Two beep", file: "twobeep", use: "Emote: beeps / boops"),
        Item(name: "Chime", file: "chime", use: "Emote: chimes, onboarding alerts"),
        Item(name: "Ping", file: "ping", use: "Emote: pings, reminder saved"),
        Item(name: "Buzz", file: "buzz_sigh", use: "Emote: buzzes"),
        Item(name: "Buzz two", file: "buzz_two", use: "Emote: buzzes twice, errors"),
        Item(name: "Announcement", file: "announce", use: "Reminder notifications"),
        Item(name: "Attention", file: "attention", use: "Opening the laws"),
        Item(name: "Welcome", file: "welcome", use: "Finishing onboarding"),
        Item(name: "Power on", file: "power_on", use: "Boot sequence"),
        Item(name: "Beep", file: "boot_beep", use: "Unit powers on"),
        Item(name: "Microwave start", file: "timer_start", use: "Timer started"),
        Item(name: "Microwave done", file: "timer_done", use: "Timer finished (and its notification)"),
        Item(name: "Button", file: "button", use: "Pause / resume timers, your emotes"),
        Item(name: "ID insert", file: "id_insert", use: "Registering your ID"),
        Item(name: "ID swipe", file: "id_swipe", use: "Changing station job"),
        Item(name: "Stamp", file: "stamp", use: "ID photo added"),
        Item(name: "Disc insert", file: "disc_insert", use: "Uploading laws, pAI ↔ AI transfer"),
        Item(name: "Scan finish", file: "scan_finish", use: "Web search results arrive"),
        Item(name: "Print & rip", file: "print_rip", use: "New chat"),
        Item(name: "Ding", file: "ding", use: "Mind (API key) installed"),
        Item(name: "Deny", file: "deny", use: "Key removed / rejected"),
        Item(name: "Pop", file: "pop", use: "Deleting reminders and timers"),
        Item(name: "Goob highlight ping", file: "goob_ping", use: "Goob Station: your name/job highlighted"),
        Item(name: "Starlight AI radio", file: "sl_radio_ai", use: "Starlight: Station AI talking"),
        Item(name: "Starlight captain radio", file: "sl_radio_captain", use: "Starlight: your messages as a head of staff"),
        Item(name: "Starlight security radio", file: "sl_radio_secoff", use: "Starlight: your messages as security"),
        Item(name: "Starlight announcement", file: "sl_announce2", use: "Starlight: reminder notifications"),
        Item(name: "Starlight attention", file: "sl_attention", use: "Starlight: opening the laws"),
        Item(name: "Starlight ID pickup", file: "sl_id_pickup", use: "Starlight: registering your ID"),
        Item(name: "Starlight ID drop", file: "sl_id_drop", use: "Starlight: changing job"),
        Item(name: "Starlight blink", file: "sl_blink", use: "Emote: blinks"),
        Item(name: "N14 terminal bark", file: "n14_bark_keytyped", use: "Nuclear 14: terminal talking"),
        Item(name: "N14 book bark", file: "n14_bark_book", use: "Nuclear 14: you talking"),
        Item(name: "N14 ring bark", file: "n14_bark_ring", use: "Nuclear 14: reminder notifications"),
    ]
}
