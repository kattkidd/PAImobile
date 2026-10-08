import SwiftUI

/// The unit, alive: pAI screens flip on SS14's 0.8s cycle and blink; Station AI cores play their screen animation.
struct LiveUnit: View {
    @EnvironmentObject var store: AppStore
    @State private var glitch = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let base = store.displayMood
            let frame = Int(t / 0.8) % 2
            let mood: PAIMood = (base == .neutral && store.settings.form == .pai
                                 && t.truncatingRemainder(dividingBy: 5.0) < 0.2) ? .blink : base
            UnitView(form: store.settings.form, mood: mood, chassis: store.settings.chassis,
                     core: store.settings.core, date: context.date, frame: frame)
                .shadow(color: store.accent.opacity(base == .off ? 0 : 0.45), radius: 10)
                .offset(x: glitch ? 2 : 0)
                .opacity(glitch ? 0.6 : 1)
        }
        .actionAnimation(store.unitAnim, unit: 3)
        .onChange(of: store.displayMood) { _, _ in
            // Little screen glitch whenever the face changes.
            glitch = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { glitch = false }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @Binding var tab: AppTab
    @State private var draft = ""
    @State private var showLaws = false
    @State private var showExamine = false
    @State private var bubbleVisible: ChatMessage?
    @FocusState private var inputFocused: Bool

    init(tab: Binding<AppTab>) {
        self._tab = tab
    }

    private let suggestions = [
        "What's the weather today?",
        "Set a 10 minute timer",
        "What's on my calendar?",
        "Remind me tomorrow at 9am to drink water",
        "What's in the news?",
    ]

    var body: some View {
        VStack(spacing: 0) {
            statusWindow
                .padding(.horizontal, 10)
                .padding(.top, 6)
            chatLog
            inputBar
        }
        .background(SS14Palette.space.ignoresSafeArea())
        .sheet(isPresented: $showLaws) { LawsSheet() }
        .overlay(alignment: .top) {
            if showExamine {
                ExaminePopup()
                    .padding(.top, 150)
                    .padding(.horizontal, 20)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { showExamine = false } }
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                    .task {
                        try? await Task.sleep(nanoseconds: 7_000_000_000)
                        withAnimation(.easeOut(duration: 0.2)) { showExamine = false }
                    }
            }
        }
        .onChange(of: store.bubble?.id) { _, _ in
            guard let msg = store.bubble else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { bubbleVisible = msg }
            // SS14 bubbles stay up longer for longer messages.
            let seconds = min(9.0, 3.0 + Double(msg.text.count) / 25.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                if bubbleVisible?.id == msg.id {
                    withAnimation(.easeIn(duration: 0.4)) { bubbleVisible = nil }
                }
            }
        }
    }

    // MARK: Status window

    private var statusWindow: some View {
        SS14WindowChrome(title: store.ownerTitle,
                         trailing: AnyView(HStack(spacing: 6) {
                             MusicMuteButton()
                             if !store.messages.isEmpty { newChatButton }
                         })) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 14) {
                    LiveUnit()
                        .frame(width: 92, height: 112)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            SFX.click.play()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showExamine.toggle() }
                        }
                        .accessibilityHint("Examine")
                    VStack(alignment: .leading, spacing: 2) {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(ctx.date, format: .dateTime.hour().minute())
                                    .font(SS14Font.display(40))
                                    .foregroundStyle(store.accent)
                                    .contentTransition(.numericText())
                                    .animation(.easeInOut, value: ctx.date.formatted(.dateTime.minute()))
                                Text(Fmt.longDate.string(from: ctx.date))
                                    .font(SS14Font.mono(12))
                                    .foregroundStyle(SS14Palette.textDim)
                            }
                        }
                        Text(greeting)
                            .font(SS14Font.bold(15))
                            .foregroundStyle(SS14Palette.text)
                            .lineLimit(2)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                    // You, standing next to your unit. Tap to emote.
                    LiveCharacter(profile: store.profile.character, job: store.profile.stationJob,
                                  event: store.characterAnim, baseDir: 3)
                        .frame(width: 58, height: 58)
                        .padding(.top, 40)
                        .onTapGesture {
                            let c = store.profile.character
                            let emotes = AudioManifest.shared.availableEmotes(species: c.species, sex: c.sex)
                            if let e = emotes.filter({ ["Laugh", "Whistle", "Chirp", "Purr", "Weh", "Meow", "Squeak", "Click", "Chitter", "Hiss"].contains($0.id) }).randomElement() ?? emotes.randomElement() {
                                store.userEmote(e.id.lowercased())
                            } else {
                                store.userEmote("flip")
                            }
                        }
                        .accessibilityLabel("Your character")
                        .accessibilityHint("Plays a random emote")
                }
                .overlay(alignment: .topLeading) {
                    if let b = bubbleVisible {
                        SpeechBubbleView(text: b.text)
                            .offset(x: 64, y: -6)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity.combined(with: .offset(y: -12))))
                            .id(b.id)
                            .allowsHitTesting(false)
                    }
                }
                chips
            }
            .padding(10)
        }
    }

    private var newChatButton: some View {
        Button {
            SFX.printRip.play()        // print the log and rip it off
            withAnimation(.easeInOut(duration: 0.25)) { store.clearChat() }
        } label: {
            Image(systemName: "square.and.pencil").font(.system(size: 13, weight: .semibold))
        }
        .buttonStyle(.ss14(.normal, compact: true))
        .accessibilityLabel("New chat")
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = store.userName
        if store.isStationAI {
            return name.isEmpty ? "Crew detected." : "\(Greeting.forHour(hour)), crew member \(name)."
        }
        return name.isEmpty ? "\(Greeting.forHour(hour))." : "\(Greeting.forHour(hour)), \(name)."
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if store.isStationAI {
                    chip("list.bullet.rectangle", "Laws: \(store.activeLawset.name)",
                         color: SS14Palette.radioBinary) { showLaws = true; SFX.attention.play() }
                }
                if let next = store.nextReminder {
                    chip("bell.fill", "\(next.reminder.title) · \(relative(next.date))", color: store.accent) { tab = .calendar }
                }
                let running = store.timers.filter { $0.isRunning }
                if let first = running.first, let end = first.endDate {
                    Button { tab = .timers } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                            Text(timerInterval: Date()...max(Date(), end), countsDown: true).monospacedDigit()
                            if running.count > 1 { Text("+\(running.count - 1)") }
                        }
                        .font(SS14Font.mono(12))
                        .foregroundStyle(store.accent)
                    }
                    .buttonStyle(.ss14(.ghost, compact: true))
                }
                if store.profile.isEmpty {
                    chip("person.text.rectangle", "Register your ID", color: SS14Palette.gold) { tab = .id }
                }
                NowPlayingChip()
            }
        }
    }

    private func chip(_ icon: String, _ text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(text).lineLimit(1)
            }
            .font(SS14Font.mono(12))
            .foregroundStyle(color)
        }
        .buttonStyle(.ss14(.ghost, compact: true))
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: Chat log (SS14 chat box style)

    private var chatLog: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if store.messages.isEmpty {
                        emptyState.transition(.opacity)
                    }
                    ForEach(store.messages) { msg in
                        ChatLine(message: msg)
                            .id(msg.id)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                    removal: .opacity))
                    }
                    if store.isThinking {
                        HStack(spacing: 8) {
                            TypingDots(color: store.accent)
                            Text(store.isStationAI ? "\(store.paiName) is computing…" : "\(store.paiName) is processing…")
                                .font(SS14Font.mono(12))
                                .foregroundStyle(SS14Palette.textDim)
                        }
                        .id("thinking")
                        .transition(.opacity)
                    }
                }
                .padding(12)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.messages.count)
                .animation(.easeInOut(duration: 0.2), value: store.isThinking)
            }
            .background(
                Color.black.opacity(0.35)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.06)))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            )
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.messages.count) { _, _ in
                if let id = store.messages.last?.id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            .onChange(of: store.isThinking) { _, thinking in
                if thinking { withAnimation { proxy.scrollTo("thinking", anchor: .bottom) } }
            }
            .onAppear {
                if let id = store.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            TypewriterText(text: bootLine, animate: true) { shown in
                Text(SS14Text.styled(shown, size: 15)).font(SS14Font.body(15)).foregroundColor(store.accent)
            }
            if !store.hasAPIKey {
                Text("Time, timers and the calendar still work. Install a mind in Settings to unlock chat and web search.")
                    .font(SS14Font.body(12))
                    .foregroundStyle(SS14Palette.textDim)
            }
            NanoHeading(title: "Suggested commands")
                .padding(.top, 6)
            ForEach(Array(suggestions.enumerated()), id: \.offset) { i, s in
                Button {
                    Task { await store.send(s) }
                } label: {
                    HStack(spacing: 6) {
                        Text(">").foregroundStyle(SS14Palette.gold)
                        Text(s).foregroundStyle(SS14Palette.text)
                    }
                    .font(SS14Font.mono(13))
                }
                .buttonStyle(.ss14(.ghost, compact: true))
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    private var bootLine: String {
        guard store.hasAPIKey else {
            return SS14.notInstalled + " " + store.paiName + " is running on backup circuits."
        }
        let name = store.userName.isEmpty ? "" : ", " + store.userName
        return store.paiName + " states, “Online. How can I help" + name + "?”"
    }

    // MARK: Input (SS14 chat input with channel button)

    private var inputBar: some View {
        HStack(spacing: 6) {
            Menu {
                Section("Emotes (or type *scream)") {
                    ForEach(Array(emoteList.enumerated()), id: \.offset) { _, e in
                        Button(e.emote.name) { store.userEmote(e.id.lowercased()) }
                    }
                }
                Section("Moves") {
                    ForEach(["flip", "spin", "jump", "dance", "wave", "nod"], id: \.self) { m in
                        Button("*" + m) { store.userEmote(m) }
                    }
                }
            } label: {
                Text(store.isStationAI ? "AI" : "Say")
                    .font(SS14Font.bold(13))
                    .foregroundStyle(SS14Palette.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(ChamferShape(cut: 6, topLeft: true, bottomRight: false).fill(SS14Palette.button))
            }
            .accessibilityLabel("Emotes")
            TextField("", text: $draft,
                      prompt: Text("Message \(store.paiName)…").foregroundColor(SS14Palette.textDisabled),
                      axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .onChange(of: draft) { old, new in
                    if new.count > old.count { SFX.keystroke() }   // SS14 computer keyboard clacks
                }
                .submitLabel(.send)
                .onSubmit(send)
                .ss14Field()
            Button(action: send) {
                Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .bold))
            }
            .buttonStyle(.ss14(canSend ? .good : .normal, compact: false))
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(SS14Palette.panelDark)
    }

    private var emoteList: [(id: String, emote: AudioManifest.Emote)] {
        let c = store.profile.character
        return AudioManifest.shared.availableEmotes(species: c.species, sex: c.sex)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isThinking
    }

    private func send() {
        guard canSend else { return }
        let text = draft
        draft = ""
        Task { await store.send(text) }
    }
}

/// One line in the SS14-style chat: avatar, coloured speaker name + verb, quoted text.
/// One line in the SS14 chat box: avatar + "Name says, “message”" with keyword highlights.
struct ChatLine: View {
    @EnvironmentObject var store: AppStore
    let message: ChatMessage

    var body: some View {
        let hl = SS14Highlighter(store: store)
        switch message.role {
        case .user:
            HStack(alignment: .top, spacing: 8) {
                CharacterHead(size: 22)
                SS14Text.say(name: store.userName.isEmpty ? "You" : store.userName,
                             nameColor: userColor,
                             verb: SS14.tone(of: message.text) == .ask ? "asks" : (SS14.tone(of: message.text) == .exclaim ? "exclaims" : "says"),
                             body: SS14Text.styled(message.text, size: 15, highlighter: hl))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .pai:
            HStack(alignment: .top, spacing: 8) {
                avatar.frame(width: 26, height: 30).padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    TypewriterText(text: message.text,
                                   animate: store.freshMessageID == message.id,
                                   onFinish: { store.freshMessageID = nil }) { shown in
                        SS14Text.say(name: store.paiName, nameColor: store.accent,
                                     verb: SS14.verb(for: message.text, seed: message.id),
                                     body: SS14Text.styled(shown, size: 15, highlighter: hl))
                    }
                    if !message.sources.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(message.sources.prefix(5), id: \.self) { src in
                                if let url = URL(string: src.url) {
                                    Link(destination: url) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "link")
                                            Text(src.title).lineLimit(1)
                                        }
                                        .font(SS14Font.body(12))
                                        .foregroundStyle(SS14Palette.radioCommon)
                                    }
                                }
                            }
                        }
                    }
                    Button { Voice.shared.speak(message.text) } label: {
                        Image(systemName: "speaker.wave.2").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SS14Palette.textDim)
                    .accessibilityLabel("Read aloud")
                }
            }
        case .userEmote:
            HStack(alignment: .top, spacing: 8) {
                CharacterHead(size: 22)
                SS14Text.emote(name: store.userName.isEmpty ? "You" : store.userName, action: message.text)
            }
        case .emote:
            HStack(alignment: .top, spacing: 8) {
                avatar.frame(width: 26, height: 30).opacity(0.85)
                SS14Text.emote(name: store.paiName, action: message.text)
            }
        case .system:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(message.text)
            }
            .font(SS14Font.bold(13))
            .foregroundStyle(Color(hex: "FF6B6B"))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SS14Palette.alertHeader.opacity(0.25))
            .overlay(Rectangle().stroke(SS14Palette.alertHeader.opacity(0.6)))
        }
    }

    /// SS14 colours speaker names; we use your department colour.
    private var userColor: Color {
        store.profile.department == "Command" ? Color(hex: "8FB4E3") : SS14.color(forDepartment: store.profile.department)
    }

    @ViewBuilder private var avatar: some View {
        switch store.settings.form {
        case .stationAI:
            Image(store.settings.hologram.image).resizable().interpolation(.none).scaledToFit()
                .shadow(color: SS14Palette.radioBinary.opacity(0.6), radius: 4)
        case .terminal:
            TerminalView(mood: .neutral, chassis: store.settings.chassis)
        case .pai:
            PAIDevice(mood: .neutral, chassis: store.settings.chassis)
        }
    }
}

/// Your character's head, used as your chat avatar.
struct CharacterHead: View {
    @EnvironmentObject var store: AppStore
    var size: CGFloat

    var body: some View {
        CharacterSprite(profile: store.profile.character, job: store.profile.stationJob)
            .scaleEffect(2.0, anchor: UnitPoint(x: 0.5, y: 0.12))
            .frame(width: size, height: size)
            .clipped()
            .background(SS14Palette.itemRow.opacity(0.6))
            .overlay(Rectangle().stroke(SS14.color(forDepartment: store.profile.department).opacity(0.8), lineWidth: 1))
    }
}

/// "♪ Now playing" chip on the home screen (SS14 lobby style). Tap to mute/unmute.
struct NowPlayingChip: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var player = MusicPlayer.shared

    var body: some View {
        if store.settings.music.enabled, let t = player.current {
            Button {
                store.settings.music.muted.toggle()
                Haptics.tap()
            } label: {
                HStack(spacing: 5) {
                    EqualizerBars(playing: player.isPlaying && !store.settings.music.muted, color: store.accent)
                    Text(store.settings.music.muted ? "Music muted" : "\(t.title) · \(t.artist)").lineLimit(1)
                }
                .font(SS14Font.mono(12))
                .foregroundStyle(store.settings.music.muted ? SS14Palette.textDim : store.accent)
            }
            .buttonStyle(.ss14(.ghost, compact: true))
            .transition(.opacity)
        }
    }
}

/// Speaker button that mutes/unmutes the lobby music, shown in screen headers.
struct MusicMuteButton: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var player = MusicPlayer.shared

    var body: some View {
        if store.settings.music.enabled {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { store.settings.music.muted.toggle() }
                Haptics.tap()
            } label: {
                Image(systemName: store.settings.music.muted ? "speaker.slash.fill" : "music.note")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)
                    .symbolEffect(.bounce, value: store.settings.music.muted)
            }
            .buttonStyle(.ss14(store.settings.music.muted ? .ghost : .normal, compact: true))
            .accessibilityLabel(store.settings.music.muted ? "Unmute music" : "Mute music")
        }
    }
}

/// Three bouncing pixels while the unit thinks.
struct TypingDots: View {
    var color: Color
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { ctx in
            let step = Int(ctx.date.timeIntervalSinceReferenceDate / 0.15) % 6
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Rectangle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .offset(y: step % 3 == i ? -3 : 0)
                }
            }
        }
    }
}
