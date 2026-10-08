import SwiftUI

// MARK: - Sprites

/// A rendered SS14 character (32×32 sprite, pixel-perfect).
struct CharacterSprite: View {
    var profile: CharacterProfile
    var job: String
    var dir: Int = 0
    var only: Set<String>? = nil

    var body: some View {
        Group {
            if let img = CharacterRenderer.image(profile, idJob: job, dir: dir, only: only) {
                Image(decorative: img, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .scaleEffect(x: profile.width, y: profile.height, anchor: .bottom)
            } else {
                Image(systemName: "person.fill").resizable().scaledToFit().foregroundStyle(SS14Palette.textDim).padding(8)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(profile.speciesDef?.name ?? "Character")
    }
}

/// A character that reacts to emotes: flips, jumps, spins through its four directions…
struct LiveCharacter: View {
    var profile: CharacterProfile
    var job: String
    var event: AnimEvent?
    var baseDir: Int = 0
    @State private var spinDir: Int? = nil

    init(profile: CharacterProfile, job: String, event: AnimEvent?, baseDir: Int = 0) {
        self.profile = profile
        self.job = job
        self.event = event
        self.baseDir = baseDir
    }

    var body: some View {
        GeometryReader { geo in
            CharacterSprite(profile: profile, job: job, dir: spinDir ?? baseDir)
                .actionAnimation(event, unit: geo.size.width / 32)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: event?.id) { _, _ in
            guard event?.kind == .spin || event?.kind == .dance else { return }
            Task { @MainActor in
                // SS14 directions: S, E, N, W
                for d in [2, 1, 3, 0, 2, 1, 3, 0] {
                    spinDir = d
                    try? await Task.sleep(nanoseconds: event?.kind == .dance ? 160_000_000 : 90_000_000)
                }
                spinDir = nil
            }
        }
    }
}

/// Item/marking icon from a sprite strip (south-facing frame).
struct StripIcon: View {
    var key: String?
    var tint: Color? = nil

    var body: some View {
        Group {
            if let key, let img = StripIcon.image(key) {
                Image(decorative: img, scale: 1).resizable().interpolation(.none)
                    .colorMultiply(tint ?? .white)
            } else {
                Color.clear
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private static var cache: [String: CGImage] = [:]
    static func image(_ key: String) -> CGImage? {
        if let c = cache[key] { return c }
        guard let url = Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "Character/Sprites"),
              let full = UIImage(contentsOfFile: url.path)?.cgImage,
              let crop = full.cropping(to: CGRect(x: 0, y: 0, width: 32, height: 32)) else { return nil }
        cache[key] = crop
        return crop
    }
}

/// Dark floor-tile backdrop like SS14's character preview.
struct PreviewFloor: View {
    var body: some View {
        Canvas { ctx, size in
            let tile: CGFloat = 24
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = 0
                var col = 0
                while x < size.width {
                    let shade = (row + col) % 2 == 0 ? 0.06 : 0.035
                    ctx.fill(Path(CGRect(x: x, y: y, width: tile - 1, height: tile - 1)), with: .color(.white.opacity(shade)))
                    x += tile; col += 1
                }
                y += tile; row += 1
            }
        }
        .background(SS14Palette.space)
    }
}

// MARK: - Character editor (SS14 "Character Setup")

struct CharacterEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .appearance
    @State private var dir = 0
    @State private var preview: AnimEvent?
    @State private var markingSheet: String?
    @State private var wardrobeSheet: String?
    @State private var speciesChanged = 0

    enum Tab: String, CaseIterable { case appearance = "Appearance", markings = "Markings", loadout = "Loadout", voice = "Voice" }

    private var c: CharacterProfile { store.profile.character }
    private var job: String { store.profile.stationJob }
    private var db: CharacterDB { .shared }

    var body: some View {
        SS14WindowChrome(title: "Character Setup", trailing: AnyView(
            Button("Done") {
                SFX.idInsert.play()
                store.popup("Character saved")
                store.characterAnim = AnimEvent(kind: .jump)
                dismiss()
            }
                .buttonStyle(.ss14(.good, compact: true))
        )) {
            VStack(spacing: 0) {
                previewPanel
                tabStrip
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch tab {
                        case .appearance: appearanceTab
                        case .markings: markingsTab
                        case .loadout: loadoutTab
                        case .voice: voiceTab
                        }
                    }
                    .padding(12)
                    .id(tab)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .background(SS14Palette.windowBackground.ignoresSafeArea())
        .sheet(item: Binding(get: { markingSheet.map(SheetID.init) }, set: { markingSheet = $0?.id })) { s in
            MarkingPickerSheet(category: s.id)
        }
        .sheet(item: Binding(get: { wardrobeSheet.map(SheetID.init) }, set: { wardrobeSheet = $0?.id })) { s in
            WardrobeSheet(slot: s.id)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Preview

    private var previewPanel: some View {
        ZStack {
            PreviewFloor()
            HStack(alignment: .bottom, spacing: 18) {
                ForEach([0, 2], id: \.self) { d in
                    LiveCharacter(profile: c, job: job, event: preview, baseDir: (dir + d) % 4)
                        .frame(width: d == 0 ? 132 : 92, height: d == 0 ? 132 : 92)
                        .id("\(speciesChanged)-\(d)")
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: speciesChanged)
            VStack {
                HStack {
                    Text(c.speciesDef?.name ?? "").font(SS14Font.bold(13))
                    Text(c.speciesDef?.source ?? "").font(SS14Font.body(10)).foregroundStyle(SS14Palette.textDim)
                    Spacer()
                    Button { rotate(-1) } label: { Image(systemName: "arrow.counterclockwise") }
                        .buttonStyle(.ss14(.normal, compact: true))
                    Button { rotate(1) } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.ss14(.normal, compact: true))
                }
                Spacer()
                HStack {
                    Button {
                        store.profile.character.randomize()
                        speciesChanged += 1
                        preview = AnimEvent(kind: .spin)
                        SFX.printRip.play()
                    } label: { Label("Randomize", systemImage: "dice") }
                        .buttonStyle(.ss14(.normal, compact: true))
                    Spacer()
                    Toggle("Clothes", isOn: $store.profile.character.showClothes)
                        .toggleStyle(SS14CheckboxStyle()).fixedSize()
                }
            }
            .padding(10)
        }
        .frame(height: 220)
        .clipped()
    }

    private func rotate(_ by: Int) {
        // SS14 rotates the preview S → E → N → W
        let order = [0, 2, 1, 3]
        let i = order.firstIndex(of: dir) ?? 0
        dir = order[(i + by + 4) % 4]
        SFX.click.play()
    }

    private var tabStrip: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button(t.rawValue) {
                    withAnimation(.easeInOut(duration: 0.2)) { tab = t }
                }
                .buttonStyle(.ss14(.normal, selected: tab == t, compact: true))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(SS14Palette.windowHeader)
    }

    // MARK: Appearance

    @ViewBuilder private var appearanceTab: some View {
        if let sp = c.speciesDef {
            SS14Section(title: "Species", trailing: "\(db.species.count) species") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 6) {
                        ForEach(db.species) { s in
                            Button {
                                guard s.id != c.species else { return }
                                store.profile.character.changeSpecies(to: s.id)
                                speciesChanged += 1
                                preview = AnimEvent(kind: .jump)
                                SFX.characterEmote("Laugh", character: store.profile.character)
                            } label: {
                                VStack(spacing: 2) {
                                    CharacterSprite(profile: speciesSample(s.id), job: job).frame(width: 56, height: 56)
                                    Text(s.name).font(SS14Font.body(11)).lineLimit(1)
                                    Text(shortSource(s.source)).font(SS14Font.body(9)).foregroundStyle(SS14Palette.textDim)
                                }
                                .frame(width: 74)
                                .padding(.vertical, 6)
                                .background(s.id == c.species ? SS14Palette.itemRowSelected : SS14Palette.itemRow.opacity(0.5))
                                .overlay(Rectangle().stroke(s.id == c.species ? SS14Palette.gold : .clear))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }

            if sp.sexes.count > 1 {
                SS14Section(title: "Body type") {
                    HStack(spacing: 6) {
                        ForEach(sp.sexes, id: \.self) { sx in
                            Button(sx) {
                                store.profile.character.sex = sx
                                preview = AnimEvent(kind: .bounce)
                            }
                            .buttonStyle(.ss14(.normal, selected: c.sex == sx, compact: true))
                        }
                        Spacer()
                    }
                    .padding(10)
                }
            }

            SS14Section(title: "Skin", footer: skinFooter(sp)) {
                if sp.skin.mode == "human" {
                    VStack(spacing: 6) {
                        Slider(value: Binding(get: { c.skinTone }, set: { v in
                            let old = c.skin
                            store.profile.character.skinTone = v
                            store.profile.character.skin = SkinTone.human(v)
                            store.profile.character.refreshFollowingColors(oldSkin: old)
                        }), in: 0...100)
                        .tint(Hex.color(c.skin))
                        LinearGradient(colors: stride(from: 0.0, through: 100, by: 10).map { Hex.color(SkinTone.human($0)) },
                                       startPoint: .leading, endPoint: .trailing).frame(height: 6)
                    }
                    .padding(10)
                } else if sp.skin.mode != "fixed" {
                    ColorRow(label: "Colour", hex: c.skin, presets: skinPresets(sp)) { new in
                        let old = c.skin
                        store.profile.character.skin = SkinTone.clamp(new, mode: sp.skin.mode)
                        store.profile.character.refreshFollowingColors(oldSkin: old)
                    }
                } else {
                    SS14Row { Text("This species has a fixed colour.").foregroundStyle(SS14Palette.textDim) }
                }
            }

            if sp.eyes != nil {
                SS14Section(title: "Eyes") {
                    ColorRow(label: "Eye colour", hex: c.eyes,
                             presets: ["#5A3A22", "#3B6E8F", "#4A7A3A", "#7A6A3A", "#2E2E2E", "#8F3B3B", "#B7A23A", "#9A5ACD"]) { new in
                        store.profile.character.eyes = new
                    }
                }
            }

            ForEach(["Hair", "FacialHair"], id: \.self) { cat in
                if let lim = sp.limit(cat) {
                    hairSection(cat: cat, lim: lim, sp: sp)
                }
            }

            SS14Section(title: "Size", footer: "Height and width sliders from Goob Station / Starlight (Einstein Engines).") {
                VStack(spacing: 8) {
                    sizeSlider("Height", value: $store.profile.character.height, range: sp.heightRange)
                    sizeSlider("Width", value: $store.profile.character.width, range: sp.widthRange)
                }
                .padding(10)
            }
        }
    }

    private func sizeSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label).foregroundStyle(SS14Palette.textDim).frame(width: 60, alignment: .leading)
            Slider(value: value, in: range).tint(SS14Palette.gold)
            Text("\(Int((value.wrappedValue * 100).rounded()))%").font(SS14Font.mono(12)).monospacedDigit().frame(width: 44)
        }
    }

    private func hairSection(cat: String, lim: CharacterDB.Limit, sp: CharacterDB.Species) -> some View {
        let options = db.markings(for: sp, cat: cat, sex: c.sex)
        let current = c.picks(in: cat).first?.id
        return SS14Section(title: cat == "Hair" ? "Hair" : "Facial hair", trailing: "\(options.count) styles") {
            ColorRow(label: "Colour", hex: cat == "Hair" ? c.hair : c.facialHair,
                     presets: ["#1A1A1A", "#2B1B12", "#4E3628", "#7A4E2D", "#B5875A", "#D9C08C", "#8C2F1B", "#C9C9C9", "#4F7FD9", "#D94FA0"]) { new in
                if cat == "Hair" { store.profile.character.hair = new } else { store.profile.character.facialHair = new }
                store.profile.character.refreshFollowingColors()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4) {
                    if !lim.required {
                        styleCell(name: "None", selected: current == nil) {
                            for p in c.picks(in: cat) { store.profile.character.remove(p.id) }
                        } image: {
                            Image(systemName: "nosign").font(.system(size: 22)).foregroundStyle(SS14Palette.textDim)
                        }
                    }
                    ForEach(options) { m in
                        styleCell(name: m.name, selected: current == m.id) {
                            for p in c.picks(in: cat) { store.profile.character.remove(p.id) }
                            store.profile.character.add(m)
                            preview = AnimEvent(kind: .bounce)
                        } image: {
                            CharacterSprite(profile: with(m), job: job, only: headLayers)
                                .scaleEffect(1.9, anchor: .top)
                                .offset(y: 4)
                                .clipped()
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private let headLayers: Set<String> = ["Head", "Eyes", "Snout", "Hair", "FacialHair", "HeadTop", "HeadSide", "SnoutCover", "Face"]

    private func styleCell<I: View>(name: String, selected: Bool, action: @escaping () -> Void, @ViewBuilder image: () -> I) -> some View {
        Button(action: { action(); SFX.click.play() }) {
            VStack(spacing: 2) {
                image().frame(width: 52, height: 52).clipped()
                Text(name).font(SS14Font.body(9)).lineLimit(2).multilineTextAlignment(.center).frame(width: 60, height: 24)
            }
            .padding(4)
            .background(selected ? SS14Palette.itemRowSelected : SS14Palette.itemRow.opacity(0.5))
            .overlay(Rectangle().stroke(selected ? SS14Palette.gold : .clear))
        }
        .buttonStyle(.plain)
    }

    private func with(_ m: CharacterDB.Marking) -> CharacterProfile {
        var p = c
        for old in p.picks(in: m.cat) { p.remove(old.id) }
        p.add(m)
        p.showClothes = false
        return p
    }

    private func speciesSample(_ id: String) -> CharacterProfile {
        var p = CharacterProfile.starter()
        if id != "Human" { p.changeSpecies(to: id) }
        p.showClothes = false
        return p
    }

    private func shortSource(_ s: String) -> String {
        s == "Space Station 14" ? "SS14" : s
    }

    private func skinFooter(_ sp: CharacterDB.Species) -> String {
        switch sp.skin.mode {
        case "human": return "SS14 human skin tones (HumanToned): slide from pale gold to dark."
        case "tinted": return "This species only takes light tints."
        default: return "Pick any colour; very dark colours are brightened like in-game."
        }
    }

    private func skinPresets(_ sp: CharacterDB.Species) -> [String] {
        [sp.skin.default, "#3F8F3F", "#2F6FA8", "#A83F3F", "#C9A227", "#7A4FA8", "#D9D9D9", "#4A4A4A", "#E08A3C"]
    }

    // MARK: Markings

    @ViewBuilder private var markingsTab: some View {
        if let sp = c.speciesDef {
            let cats = sp.limits.map(\.cat).filter { !["Hair", "FacialHair"].contains($0) }
                .sorted { (CharacterDB.categoryOrder.firstIndex(of: $0) ?? 99) < (CharacterDB.categoryOrder.firstIndex(of: $1) ?? 99) }
            if cats.isEmpty {
                Text("This species has no markings.").foregroundStyle(SS14Palette.textDim)
            }
            ForEach(cats, id: \.self) { cat in
                let lim = sp.limit(cat)!
                let picks = c.picks(in: cat)
                SS14Section(title: CharacterDB.categoryLabel(cat), trailing: "\(picks.count)/\(lim.limit)\(lim.required ? " · required" : "")") {
                    ForEach(Array(picks.enumerated()), id: \.offset) { i, pick in
                        if let m = db.markings[pick.id] {
                            MarkingRow(pick: pick, marking: m, removable: !(lim.required && picks.count <= 1))
                                .background(i % 2 == 1 ? SS14Palette.itemRow.opacity(0.4) : .clear)
                        }
                    }
                    Button {
                        markingSheet = cat
                    } label: {
                        SS14Row {
                            Image(systemName: "plus.square.fill").foregroundStyle(SS14Palette.goodLight)
                            Text(picks.count >= lim.limit ? "Swap marking" : "Add marking")
                            Spacer()
                            Text("\(db.markings(for: sp, cat: cat, sex: c.sex).count) available")
                                .font(SS14Font.body(11)).foregroundStyle(SS14Palette.textDim)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Loadout

    @ViewBuilder private var loadoutTab: some View {
        let outfitJob = c.outfitJob ?? job
        let jobDef = db.jobs[outfitJob] ?? db.jobs["Passenger"]
        SS14Section(title: "Outfit", footer: "SS14 job loadouts. Wasteland jobs are dressed in SS14 gear.") {
            Toggle("Show clothing", isOn: $store.profile.character.showClothes)
                .toggleStyle(SS14CheckboxStyle()).padding(.horizontal, 12).padding(.vertical, 10)
            SS14Row(alternate: true) {
                Text("Wear").foregroundStyle(SS14Palette.textDim)
                Spacer()
                Menu {
                    Button("My ID job (\(store.profile.job.name))") { store.profile.character.outfitJob = nil }
                    ForEach(ForkData.allDepartments, id: \.self) { dept in
                        Section(dept) {
                            ForEach(ForkData.allJobs.filter { $0.department == dept && db.jobs[$0.id] != nil }) { j in
                                Button(j.name) {
                                    store.profile.character.outfitJob = j.id
                                    store.profile.character.loadout = [:]
                                    preview = AnimEvent(kind: .spin)
                                    SFX.idSwipe.play()
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        JobIcon(job: SS14.anyJob(outfitJob) ?? store.profile.job, size: 16)
                        Text(SS14.anyJob(outfitJob)?.name ?? outfitJob)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                }
            }
        }
        if let jobDef {
            ForEach(jobDef.groups) { g in
                SS14Section(title: g.name) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            if g.min == 0 {
                                styleCell(name: "None", selected: c.loadout[g.id] == "none") {
                                    store.profile.character.loadout[g.id] = "none"
                                } image: { Image(systemName: "nosign").font(.system(size: 22)).foregroundStyle(SS14Palette.textDim) }
                            }
                            ForEach(g.options) { o in
                                let selected = (c.loadout[g.id] ?? g.options.first?.id) == o.id
                                styleCell(name: o.name.capitalizedFirst, selected: selected) {
                                    store.profile.character.loadout[g.id] = o.id
                                    for slot in o.items.keys { store.profile.character.wardrobe[slot] = nil }
                                    preview = AnimEvent(kind: .bounce)
                                } image: {
                                    StripIcon(key: o.items.values.compactMap { db.items[$0]?.icon }.first)
                                }
                            }
                        }
                        .padding(8)
                    }
                }
            }
        }
        SS14Section(title: "Wardrobe", footer: "Override any slot with anything from every job (plus a few wasteland extras).") {
            ForEach(Array(CharacterDB.slotOrder.filter { db.wardrobe[$0] != nil }.enumerated()), id: \.offset) { i, slot in
                let worn = c.outfit(idJob: job)[slot]
                Button { wardrobeSheet = slot } label: {
                    SS14Row(alternate: i % 2 == 1) {
                        Text(CharacterDB.slotLabel(slot)).foregroundStyle(SS14Palette.textDim).frame(width: 74, alignment: .leading)
                        StripIcon(key: worn.flatMap { db.items[$0]?.icon }).frame(width: 28, height: 28)
                        Text(worn.flatMap { db.items[$0]?.name.capitalizedFirst } ?? "Nothing")
                            .lineLimit(1)
                            .foregroundStyle(worn == nil ? SS14Palette.textDisabled : SS14Palette.text)
                        Spacer()
                        if c.wardrobe[slot] != nil {
                            Text("custom").font(SS14Font.body(10)).foregroundStyle(SS14Palette.gold)
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(SS14Palette.textDisabled)
                    }
                }
                .buttonStyle(.plain)
            }
            if !c.wardrobe.isEmpty {
                Button("Reset to job loadout") {
                    store.profile.character.wardrobe = [:]
                    preview = AnimEvent(kind: .spin)
                }
                .buttonStyle(.ss14(.caution, compact: true))
                .padding(10)
            }
        }
    }

    // MARK: Voice

    @ViewBuilder private var voiceTab: some View {
        let audio = AudioManifest.shared
        let current = SFX.voiceID(for: c)
        SS14Section(title: "Voice", trailing: "\(audio.speech.count) voices",
                    footer: "Talk sounds from SS14's speech_sounds.yml and the forks. Plays whenever you send a message.") {
            Button {
                store.profile.character.voice = nil
                SFX.userSpeech(for: "Hello there.", voiceID: SFX.voiceID(for: store.profile.character))
            } label: {
                SS14Row {
                    Image(systemName: c.voice == nil ? "checkmark.square.fill" : "square")
                        .foregroundStyle(c.voice == nil ? SS14Palette.gold : SS14Palette.textDim)
                    Text("Species default")
                    Spacer()
                    Text(audio.speech[audio.species[c.species]?.speech ?? ""]?.name ?? "")
                        .font(SS14Font.body(11)).foregroundStyle(SS14Palette.textDim)
                }
            }
            .buttonStyle(.plain)
            ForEach(Array(audio.voices.enumerated()), id: \.offset) { i, v in
                Button {
                    store.profile.character.voice = v.id
                    SFX.userSpeech(for: ["Hello there.", "How are you?", "Hey!"][i % 3], voiceID: v.id)
                    preview = AnimEvent(kind: .talk)
                } label: {
                    SS14Row(alternate: i % 2 == 1) {
                        Image(systemName: c.voice == v.id ? "checkmark.square.fill" : (current == v.id ? "speaker.wave.1.fill" : "square"))
                            .foregroundStyle(c.voice == v.id ? SS14Palette.gold : SS14Palette.textDim)
                        Text(v.speech.name)
                        Spacer()
                        Text(shortSource(v.speech.source)).font(SS14Font.body(10)).foregroundStyle(SS14Palette.textDim)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        let emotes = audio.availableEmotes(species: c.species, sex: c.sex)
        SS14Section(title: "Emotes", trailing: "\(emotes.count)",
                    footer: "Type these in chat with a * (like *scream). Movement emotes *flip, *spin, *jump and *dance work too.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], spacing: 6) {
                ForEach(Array(emotes.enumerated()), id: \.offset) { _, e in
                    Button(e.emote.name) {
                        SFX.characterEmote(e.id, character: c)
                        preview = AnimEvent(kind: ActionAnim.forEmote(e.id))
                    }
                    .buttonStyle(.ss14(.normal, compact: true))
                }
                ForEach(["Flip", "Spin", "Jump", "Dance"], id: \.self) { m in
                    Button(m) {
                        preview = AnimEvent(kind: ActionAnim(rawValue: m.lowercased()) ?? .bounce)
                        SFX.button.play()
                    }
                    .buttonStyle(.ss14(.good, compact: true))
                }
            }
            .padding(8)
        }
    }
}

private struct SheetID: Identifiable { let id: String }

extension String {
    var capitalizedFirst: String {
        let head = String(self.prefix(1)).uppercased()
        return head + String(self.dropFirst())
    }
}

/// Colour swatch row: SwiftUI colour picker plus quick presets.
struct ColorRow: View {
    var label: String
    var hex: String
    var presets: [String]
    var onChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).foregroundStyle(SS14Palette.textDim)
                Spacer()
                Text(hex).font(SS14Font.mono(11)).foregroundStyle(SS14Palette.textDim)
                ColorPicker("", selection: Binding(get: { Hex.color(hex) }, set: { onChange(Hex.from($0)) }),
                            supportsOpacity: false)
                    .labelsHidden()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { p in
                        Button { onChange(p); SFX.click.play() } label: {
                            Rectangle().fill(Hex.color(p)).frame(width: 26, height: 26)
                                .overlay(Rectangle().stroke(p.uppercased() == hex.uppercased() ? SS14Palette.gold : Color.black.opacity(0.5), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
    }
}

/// One worn marking with its per-layer colours.
struct MarkingRow: View {
    @EnvironmentObject var store: AppStore
    var pick: MarkingPick
    var marking: CharacterDB.Marking
    var removable: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                ForEach(Array(marking.sprites.enumerated()), id: \.offset) { i, key in
                    StripIcon(key: key, tint: Hex.color(i < pick.colors.count ? pick.colors[i] : "#FFFFFF"))
                }
            }
            .frame(width: 34, height: 34)
            .background(SS14Palette.itemRow)
            VStack(alignment: .leading, spacing: 2) {
                Text(marking.name).font(SS14Font.body(14)).lineLimit(1)
                Text(marking.source).font(SS14Font.body(10)).foregroundStyle(SS14Palette.textDim)
            }
            Spacer()
            ForEach(Array(pick.colors.enumerated()), id: \.offset) { i, col in
                ColorPicker("", selection: Binding(get: { Hex.color(col) }, set: { set(i, Hex.from($0)) }), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 30)
            }
            if removable {
                Button {
                    withAnimation { store.profile.character.remove(pick.id) }
                    SFX.pop.play()
                } label: { Image(systemName: "xmark") }
                    .buttonStyle(.ss14(.caution, compact: true))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }

    private func set(_ i: Int, _ hex: String) {
        guard let idx = store.profile.character.markings.firstIndex(where: { $0.id == pick.id }) else { return }
        store.profile.character.markings[idx].colors[i] = hex
    }
}

/// Grid of every marking in a category, previewed on your character.
struct MarkingPickerSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var category: String
    @State private var search = ""

    var body: some View {
        let c = store.profile.character
        let db = CharacterDB.shared
        let all = c.speciesDef.map { db.markings(for: $0, cat: category, sex: c.sex) } ?? []
        let list = search.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(search) }
        SS14WindowChrome(title: CharacterDB.categoryLabel(category), trailing: AnyView(
            Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }
                .buttonStyle(.plain).foregroundStyle(SS14Palette.textDim)
        )) {
            VStack(spacing: 8) {
                TextField("", text: $search, prompt: Text("Search \(all.count) markings").foregroundColor(SS14Palette.textDisabled))
                    .ss14Field()
                    .padding([.horizontal, .top], 10)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], spacing: 6) {
                        ForEach(list) { m in
                            Button {
                                store.profile.character.add(m)
                                SFX.click.play()
                                Haptics.tap()
                                dismiss()
                            } label: {
                                VStack(spacing: 2) {
                                    CharacterSprite(profile: preview(m), job: store.profile.stationJob, dir: dirFor(m))
                                        .frame(width: 64, height: 64)
                                        .background(SS14Palette.itemRow.opacity(0.6))
                                    Text(m.name).font(SS14Font.body(10)).lineLimit(2).multilineTextAlignment(.center)
                                        .frame(height: 28)
                                    if m.source != "Space Station 14" {
                                        Text(m.source).font(SS14Font.body(8)).foregroundStyle(SS14Palette.textDim)
                                    }
                                }
                                .padding(4)
                                .background(c.markings.contains { $0.id == m.id } ? SS14Palette.itemRowSelected : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(SS14Palette.windowBackground)
        .preferredColorScheme(.dark)
    }

    private func preview(_ m: CharacterDB.Marking) -> CharacterProfile {
        var p = store.profile.character
        if !p.markings.contains(where: { $0.id == m.id }) { p.add(m) }
        p.showClothes = false
        return p
    }

    /// Tails and wings read best from the side.
    private func dirFor(_ m: CharacterDB.Marking) -> Int {
        ["Tail", "TailBehind", "Wings", "TailOverlay"].contains(m.layer) ? 2 : 0
    }
}

/// Every wearable item for one slot.
struct WardrobeSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var slot: String
    @State private var search = ""

    var body: some View {
        let db = CharacterDB.shared
        let all = (db.wardrobe[slot] ?? []).compactMap { db.items[$0] }
        let list = search.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(search) }
        SS14WindowChrome(title: CharacterDB.slotLabel(slot), trailing: AnyView(
            Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }
                .buttonStyle(.plain).foregroundStyle(SS14Palette.textDim)
        )) {
            VStack(spacing: 8) {
                TextField("", text: $search, prompt: Text("Search \(all.count) items").foregroundColor(SS14Palette.textDisabled))
                    .ss14Field()
                    .padding([.horizontal, .top], 10)
                HStack {
                    Button("Job default") { store.profile.character.wardrobe[slot] = nil; dismiss() }
                        .buttonStyle(.ss14(.normal, compact: true))
                    Button("Nothing") { store.profile.character.wardrobe[slot] = "none"; SFX.pop.play(); dismiss() }
                        .buttonStyle(.ss14(.caution, compact: true))
                    Spacer()
                }
                .padding(.horizontal, 10)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], spacing: 6) {
                        ForEach(list) { item in
                            Button {
                                store.profile.character.wardrobe[slot] = item.id
                                store.profile.character.showClothes = true
                                SFX.click.play()
                                dismiss()
                            } label: {
                                VStack(spacing: 2) {
                                    CharacterSprite(profile: wearing(item), job: store.profile.stationJob)
                                        .frame(width: 60, height: 60)
                                        .background(SS14Palette.itemRow.opacity(0.6))
                                    Text(item.name.capitalizedFirst).font(SS14Font.body(9)).lineLimit(2)
                                        .multilineTextAlignment(.center).frame(height: 24)
                                }
                                .padding(4)
                                .background(store.profile.character.wardrobe[slot] == item.id ? SS14Palette.itemRowSelected : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(SS14Palette.windowBackground)
        .preferredColorScheme(.dark)
    }

    private func wearing(_ item: CharacterDB.Item) -> CharacterProfile {
        var p = store.profile.character
        p.wardrobe[slot] = item.id
        p.showClothes = true
        return p
    }
}
