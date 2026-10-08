import SwiftUI

/// First-run setup, styled as a series of SS14 windows.
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    var onDone: () -> Void

    enum Step: Int, CaseIterable { case welcome, server, unit, search, id, character, laws, alerts, mind, done }

    @State private var step: Step = .welcome
    @State private var forward = true
    @State private var found = false
    @State private var keyDraft = ""
    @State private var notifStatus = "Not asked"
    @State private var showJobs = false
    @State private var editing = false

    init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    private var steps: [Step] {
        Step.allCases.filter { $0 != .laws || store.settings.form == .stationAI }
    }

    var body: some View {
        VStack(spacing: 0) {
            pips.padding(.top, 8)
            ZStack {
                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .push(from: forward ? .trailing : .leading),
                        removal: .push(from: forward ? .trailing : .leading)))
            }
            .frame(maxHeight: .infinity)
            controls
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(SS14Palette.space.ignoresSafeArea())
        .sheet(isPresented: $showJobs) { JobPickerSheet(selection: $store.profile.stationJob) }
        .fullScreenCover(isPresented: $editing) { CharacterEditor().environmentObject(store) }
    }

    // MARK: Progress pips

    private var pips: some View {
        HStack(spacing: 5) {
            ForEach(steps, id: \.self) { s in
                ChamferShape(cut: 3)
                    .fill(s.rawValue <= step.rawValue ? SS14Palette.good : SS14Palette.button)
                    .frame(height: 6)
            }
        }
        .animation(.easeInOut, value: step)
    }

    // MARK: Pages

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .server: serverPage
        case .unit: unitPicker
        case .search: search
        case .id: idPage
        case .character: characterPage
        case .laws: laws
        case .alerts: alerts
        case .mind: mind
        case .done: done
        }
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("nt_logo")
                .renderingMode(.template).resizable().interpolation(.none)
                .frame(width: 72, height: 72)
                .foregroundStyle(SS14Palette.gold)
            Text("NANOTRASEN")
                .font(SS14Font.display(30)).tracking(4)
                .foregroundStyle(SS14Palette.text)
            Text("Personal assistance division")
                .font(SS14Font.mono(13))
                .foregroundStyle(SS14Palette.textDim)
            HStack(alignment: .bottom, spacing: 28) {
                PAIDevice(mood: .happy, chassis: .standard).frame(height: 90)
                AICoreView(mood: .neutral, core: .ai).frame(height: 90)
            }
            .padding(.top, 10)
            Text("Welcome aboard, crew member. Let's get your silicon assistant installed and registered to your ID.")
                .font(SS14Font.body(15))
                .foregroundStyle(SS14Palette.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
            Spacer()
        }
    }

    private var serverPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                title("Pick a style", "Each server is a Space Station 14 fork. Applying one sets its look, voice, sounds and personality, but every fork's species, jobs, laws, accents and music are always available. Mix and match any time in Settings.")
                ServerBrowser()
            }
            .padding(.vertical, 12)
        }
    }

    private var unitPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                title("Choose your unit", "You can change this any time in Settings.")
                HStack(spacing: 8) {
                    ForEach(UnitForm.allCases) { f in
                        let on = store.settings.form == f
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.settings.form = f }
                            SFX.unitSpeech("Hello!", form: f)   // hear the unit's voice
                            store.unitAnim = AnimEvent(kind: .jump)
                            if f == .stationAI && (store.settings.paiName == "PAI" || store.settings.paiName.isEmpty) {
                                store.settings.paiName = SS14.aiNames.randomElement() ?? "SOL"
                            } else if f != .stationAI && SS14.aiNames.contains(store.settings.paiName) {
                                store.settings.paiName = "PAI"
                            }
                        } label: {
                            VStack(spacing: 8) {
                                UnitView(form: f, mood: on ? .happy : .neutral,
                                         chassis: store.settings.chassis, core: store.settings.core)
                                    .frame(height: 70)
                                    .actionAnimation(on ? store.unitAnim : nil, unit: 2)
                                Text(f.label).font(SS14Font.display(14)).lineLimit(1).minimumScaleFactor(0.7)
                                Text(f.blurb).font(SS14Font.body(10))
                                    .foregroundStyle(SS14Palette.textDim)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(SS14Palette.text)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(OctagonShape().fill(on ? SS14Palette.good.opacity(0.35) : SS14Palette.panelDark))
                            .overlay(OctagonShape().stroke(on ? SS14Palette.goodLight : SS14Palette.button, lineWidth: 2))
                            .scaleEffect(on ? 1.02 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                UnitCustomizer()
            }
            .padding(.vertical, 12)
        }
    }

    private var search: some View {
        VStack(spacing: 22) {
            Spacer()
            UnitView(form: store.settings.form, mood: found ? .happy : .thinking,
                     chassis: store.settings.chassis, core: store.settings.core)
                .frame(height: 170)
                .shadow(color: store.accent.opacity(found ? 0.7 : 0.2), radius: 20)
            Text(found ? foundText : searchText)
                .font(SS14Font.mono(15, bold: true))
                .foregroundStyle(found ? SS14Palette.radioCommon : SS14Palette.textDim)
                .id(found)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            if !found { ProgressView().tint(SS14Palette.gold) }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .task {
            guard !found else { return }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { found = true }
            SFX.unitSpeech("Found!", form: store.settings.form)
            Haptics.success()
        }
    }

    private var characterPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                title("Create your character", "Your SS14 crew member appears on your ID card and reacts to emotes like *flip and *scream. 35 species from SS14, Goob Station, Starlight and Nuclear 14.")
                CharacterCard { editing = true }
                HStack(spacing: 8) {
                    Button {
                        store.profile.character.randomize()
                        store.characterAnim = AnimEvent(kind: .spin)
                        SFX.printRip.play()
                    } label: { Label("Randomize", systemImage: "dice").frame(maxWidth: .infinity) }
                        .buttonStyle(.ss14(.normal))
                    Button {
                        store.characterAnim = AnimEvent(kind: .flip)
                        SFX.button.play()
                    } label: { Label("*flip", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity) }
                        .buttonStyle(.ss14(.normal))
                }
            }
            .padding(.vertical, 12)
        }
    }

    // Wording from SS14's pai-system.ftl
    private var searchText: String {
        switch store.settings.form {
        case .pai: return SS14.searching
        case .stationAI: return "Locating an AI core…"
        case .terminal: return "> SCANNING FOR TERMINALS…"
        }
    }
    private var foundText: String {
        switch store.settings.form {
        case .pai: return "A pAI is installed."
        case .stationAI: return "Station AI core online."
        case .terminal: return "> TERMINAL ONLINE."
        }
    }

    private var idPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                title("Register your ID", "\(store.paiName) uses this to know who you are.")
                IDCardView()
                SS14Section(title: "Identity") {
                    SS14FieldRow(label: "Full name", placeholder: "Alex Morgan", text: $store.profile.fullName)
                    SS14FieldRow(label: "Call me", placeholder: "Alex", text: $store.profile.preferredName)
                    SS14FieldRow(label: "Pronouns", placeholder: "they/them", text: $store.profile.pronouns)
                    VoicePickerRow()
                    Button { showJobs = true } label: {
                        SS14Row {
                            Text("Station job").foregroundStyle(SS14Palette.textDim)
                            Spacer()
                            JobIcon(job: store.profile.job, size: 18)
                            Text(store.profile.job.name)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(SS14Palette.textDim)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { SFX.idInsert.play() }           // card goes into the terminal
    }

    private var laws: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                title("Upload a lawset", "Station AIs follow laws. Pick the board to install.")
                LawsetPicker()
            }
            .padding(.vertical, 12)
        }
    }

    private var alerts: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Station alerts", "Reminders and timers arrive as notifications, even when the app is closed.")
            SS14WindowChrome(title: "Alert preview") {
                HStack(spacing: 12) {
                    UnitView(form: store.settings.form, mood: .alert,
                             chassis: store.settings.chassis, core: store.settings.core)
                        .frame(height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(store.paiName) · Reminder").font(SS14Font.bold(14))
                        Text("\(store.userName.isEmpty ? "Crew" : store.userName), you asked me to remind you: take out the bins")
                            .font(SS14Font.body(13))
                            .foregroundStyle(SS14Palette.textDim)
                    }
                }
                .padding(12)
            }
            Button {
                Task {
                    _ = await Notifier.requestAuthorization()
                    let st = await Notifier.status()
                    notifStatus = (st == .authorized || st == .provisional || st == .ephemeral) ? "Enabled" : "Off — enable in iPhone Settings"
                    SFX.chime.play()
                }
            } label: {
                Label("Enable notifications", systemImage: "bell.badge").frame(maxWidth: .infinity)
            }
            .buttonStyle(.ss14(.good))
            Text("Status: \(notifStatus)").font(SS14Font.mono(12)).foregroundStyle(SS14Palette.textDim)
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private var mind: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                title("Install a mind", "Optional. Without one, \(store.paiName) runs on backup circuits: clock, calendar and timers only.")
                SS14Section(title: "OpenAI API key",
                            footer: "Get one at platform.openai.com → API keys, and add a little credit under Billing. A ChatGPT subscription (Go/Plus) does not include API access. The key stays in your iPhone Keychain.") {
                    VStack(alignment: .leading, spacing: 10) {
                        SecureField("", text: $keyDraft, prompt: Text("sk-…").foregroundColor(SS14Palette.textDisabled))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .ss14Field(mono: true)
                        Button {
                            store.setAPIKey(keyDraft)
                            keyDraft = ""
                        } label: {
                            Label(store.hasAPIKey ? "Mind installed" : "Install", systemImage: store.hasAPIKey ? "checkmark.seal.fill" : "brain")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ss14(store.hasAPIKey ? .good : .normal))
                        .disabled(keyDraft.trimmingCharacters(in: .whitespaces).isEmpty && !store.hasAPIKey)
                    }
                    .padding(12)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var done: some View {
        VStack(spacing: 20) {
            Spacer()
            UnitView(form: store.settings.form, mood: .happy,
                     chassis: store.settings.chassis, core: store.settings.core)
                .frame(height: 190)
                .shadow(color: store.accent.opacity(0.7), radius: 24)
            Text("\(store.paiName) online")
                .font(SS14Font.display(26))
                .foregroundStyle(store.accent)
            Text(store.userName.isEmpty
                 ? "\(store.paiName) states, \"Ready to assist.\""
                 : "\(store.paiName) states, \"Hello, \(store.userName). Ready to assist.\"")
                .font(SS14Font.body(16))
                .foregroundStyle(SS14Palette.text)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { SFX.unitSpeech("Ready.", form: store.settings.form) }
    }

    private func title(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(SS14Font.display(26)).foregroundStyle(SS14Palette.text)
            Text(sub).font(SS14Font.body(14)).foregroundStyle(SS14Palette.textDim)
                .fixedSize(horizontal: false, vertical: true)
            NanoHeadingLine().stroke(SS14Palette.gold, lineWidth: 1.5).frame(height: 6)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 10) {
            if step != .welcome && step != .done {
                Button("Back") { go(-1); SFX.hover.play() }
                    .buttonStyle(.ss14(.normal))
            }
            Spacer()
            if step == .mind && !store.hasAPIKey {
                Button("Skip") { go(1) }.buttonStyle(.ss14(.ghost))
            }
            Button(primaryLabel) {
                if step == .done {
                    store.settings.onboarded = true
                    SFX.welcome.play()              // SS14 round-start welcome
                    onDone()
                } else {
                    go(1)
                }
            }
            .buttonStyle(.ss14(.good))
            .disabled(step == .search && !found)
        }
        .padding(.top, 8)
    }

    private var primaryLabel: String {
        switch step {
        case .welcome: return "Begin"
        case .done: return "Start shift"
        default: return "Next"
        }
    }

    private func go(_ delta: Int) {
        let list = steps
        guard let i = list.firstIndex(of: step) else { return }
        let j = min(max(i + delta, 0), list.count - 1)
        forward = delta > 0
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { step = list[j] }
        Haptics.tap()
    }
}

/// Chassis / core / hologram / name pickers, shared by onboarding and Settings.
struct UnitCustomizer: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.settings.form != .stationAI {
                let form = store.settings.form
                SS14Section(title: "Chassis", footer: store.settings.chassis.flavor(form)) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(PAIChassis.allCases) { c in
                                pickTile(selected: store.settings.chassis == c, label: c.label(form)) {
                                    UnitView(form: form, mood: store.settings.chassis == c ? .happy : .neutral,
                                             chassis: c, core: store.settings.core)
                                } action: {
                                    store.settings.chassis = c
                                    SFX.unitSpeech("Hi!", form: form)
                                }
                            }
                        }
                        .padding(10)
                    }
                }
            } else {
                SS14Section(title: "Core display") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AICore.allCases) { c in
                                pickTile(selected: store.settings.core == c, label: c.label) {
                                    TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                                        AICoreView(mood: .neutral, core: c, date: ctx.date)
                                    }
                                } action: {
                                    store.settings.core = c
                                    SFX.borgSay.play()
                                }
                            }
                        }
                        .padding(10)
                    }
                }
                SS14Section(title: "Hologram", footer: "Your AI's holopad avatar, shown next to its messages.") {
                    HStack(spacing: 10) {
                        ForEach(AIHologram.allCases) { h in
                            pickTile(selected: store.settings.hologram == h, label: h.label) {
                                Image(h.image).resizable().interpolation(.none).scaledToFit()
                            } action: {
                                store.settings.hologram = h
                                SFX.ping.play()
                            }
                        }
                    }
                    .padding(10)
                }
            }
            SS14Section(title: "Designation") {
                SS14Row {
                    TextField("", text: $store.settings.paiName, prompt: Text("Name").foregroundColor(SS14Palette.textDisabled))
                        .ss14Field()
                    if store.settings.form == .stationAI {
                        Button {
                            store.settings.paiName = SS14.aiNames.randomElement() ?? "SOL"
                        } label: {
                            Image(systemName: "dice.fill")
                        }
                        .buttonStyle(.ss14(.normal, compact: true))
                        .accessibilityLabel("Random SS14 AI name")
                    }
                }
            }
        }
    }

    private func pickTile<V: View>(selected: Bool, label: String, @ViewBuilder art: () -> V,
                                   action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
            Haptics.tap()
        } label: {
            VStack(spacing: 6) {
                art().frame(height: 58)
                Text(label).font(SS14Font.body(11)).lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(SS14Palette.text)
            }
            .frame(width: 74)
            .padding(.vertical, 8)
            .background(ChamferShape(cut: 6).fill(selected ? SS14Palette.good.opacity(0.45) : SS14Palette.itemRow))
            .overlay(ChamferShape(cut: 6).stroke(selected ? SS14Palette.goodLight : .clear, lineWidth: 1.5))
            .scaleEffect(selected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
    }
}

/// Lawset boards (Station AI).
struct LawsetPicker: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(ForkData.allLawsets.enumerated()), id: \.offset) { _, group in
                Text(group.source).font(SS14Font.bold(12)).foregroundStyle(SS14Palette.textDim)
                ForEach(group.sets) { set in
                    lawsetCard(set, on: store.settings.lawset == set.id)
                }
            }
            Text("Goob Station").font(SS14Font.bold(12)).foregroundStyle(SS14Palette.textDim)
            CustomLawboardEditor()
        }
    }

    private func lawsetCard(_ set: SS14Lawset, on: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { store.settings.lawset = set.id }
            SFX.discInsert.play()           // law board inserted
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: on ? "checkmark.square.fill" : "square")
                        .foregroundStyle(on ? SS14Palette.gold : SS14Palette.textDim)
                    Text(set.name).font(SS14Font.display(16)).foregroundStyle(SS14Palette.text)
                    Spacer()
                    Text("\(set.laws.count) laws").font(SS14Font.mono(11)).foregroundStyle(SS14Palette.textDim)
                }
                if on {
                    ForEach(Array(set.laws.enumerated()), id: \.offset) { i, law in
                        (Text("Law \(i + 1): ").font(SS14Font.bold(13)) + Text(law).font(SS14Font.body(13)))
                            .foregroundStyle(SS14Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? SS14Palette.itemRowSelected : SS14Palette.panelDark)
            .overlay(Rectangle().stroke(on ? SS14Palette.gold.opacity(0.6) : Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}

/// Goob Station's custom lawboard: write, reorder and delete your own laws.
struct CustomLawboardEditor: View {
    @EnvironmentObject var store: AppStore

    private var on: Bool { store.settings.lawset == ForkData.customLawsetID }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { store.settings.lawset = ForkData.customLawsetID }
                SFX.discInsert.play()
            } label: {
                HStack {
                    Image(systemName: on ? "checkmark.square.fill" : "square")
                        .foregroundStyle(on ? SS14Palette.gold : SS14Palette.textDim)
                    Text("Custom lawboard").font(SS14Font.display(16)).foregroundStyle(SS14Palette.text)
                    Spacer()
                    Text("Goob").font(SS14Font.mono(11)).foregroundStyle(SS14Palette.textDim)
                }
            }
            .buttonStyle(.plain)
            if on {
                ForEach(Array(store.settings.customLaws.indices), id: \.self) { i in
                    HStack(spacing: 6) {
                        Text("\(i + 1)").font(SS14Font.bold(13)).foregroundStyle(SS14Palette.gold).frame(width: 18)
                        TextField("", text: Binding(
                            get: { i < store.settings.customLaws.count ? store.settings.customLaws[i] : "" },
                            set: { if i < store.settings.customLaws.count { store.settings.customLaws[i] = $0 } }
                        ), prompt: Text("Write a law…").foregroundColor(SS14Palette.textDisabled), axis: .vertical)
                            .ss14Field()
                        VStack(spacing: 2) {
                            Button("↑") { move(i, -1) }.disabled(i == 0)
                            Button("↓") { move(i, 1) }.disabled(i == store.settings.customLaws.count - 1)
                        }
                        .buttonStyle(.ss14(.normal, compact: true))
                        Button { remove(i) } label: { Image(systemName: "xmark") }
                            .buttonStyle(.ss14(.caution, compact: true))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Button {
                    withAnimation { store.settings.customLaws.append("") }
                    SFX.button.play()
                } label: {
                    Label("Add law", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.ss14(.good, compact: true))
                Text("Lawboard updated. Laws are role-play flavour; real help always comes first.")
                    .font(SS14Font.body(11)).foregroundStyle(SS14Palette.textDim)
            }
        }
        .padding(12)
        .background(on ? SS14Palette.itemRowSelected : SS14Palette.panelDark)
        .overlay(Rectangle().stroke(on ? SS14Palette.gold.opacity(0.6) : Color.white.opacity(0.06)))
    }

    private func move(_ i: Int, _ d: Int) {
        let j = i + d
        guard store.settings.customLaws.indices.contains(i), store.settings.customLaws.indices.contains(j) else { return }
        withAnimation { store.settings.customLaws.swapAt(i, j) }
        SFX.hover.play()
    }

    private func remove(_ i: Int) {
        guard store.settings.customLaws.indices.contains(i) else { return }
        withAnimation { _ = store.settings.customLaws.remove(at: i) }
        SFX.pop.play()
    }
}
