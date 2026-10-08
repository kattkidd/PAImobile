import SwiftUI
import PhotosUI

struct IDScreen: View {
    @EnvironmentObject var store: AppStore
    @State private var photoItem: PhotosPickerItem?
    @State private var showJobs = false
    @State private var editing = false

    var body: some View {
        VStack(spacing: 0) {
            SS14ScreenHeader(title: "ID Card", subtitle: "Crew registration terminal")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    IDCardView()

                    CharacterCard { editing = true }

                    HStack(spacing: 8) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(store.idPhoto == nil ? "Add photo" : "Change photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ss14(.normal))
                        if store.idPhoto != nil {
                            Button(store.profile.showPhoto ? "Use character" : "Use photo") {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { store.profile.showPhoto.toggle() }
                                SFX.stamp.play()
                            }
                            .buttonStyle(.ss14(.normal))
                            Button("Remove") { withAnimation { store.setPhoto(nil); store.profile.showPhoto = false } }
                                .buttonStyle(.ss14(.caution))
                        }
                    }

                    SS14Section(title: "Identity", footer: "\(store.paiName) uses \"Call me\" when talking to you.") {
                        SS14FieldRow(label: "Full name", placeholder: "Alex Morgan", text: $store.profile.fullName)
                        SS14FieldRow(label: "Call me", placeholder: "Alex", text: $store.profile.preferredName)
                        SS14FieldRow(label: "Pronouns", placeholder: "they/them", text: $store.profile.pronouns)
                        VoicePickerRow()
                        Toggle("Birthday", isOn: Binding(
                            get: { store.profile.birthday != nil },
                            set: { on in withAnimation { store.profile.birthday = on ? (store.profile.birthday ?? defaultBirthday) : nil } }
                        ))
                        .toggleStyle(SS14CheckboxStyle())
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        if store.profile.birthday != nil {
                            SS14Row(alternate: true) {
                                Text("Date").foregroundStyle(SS14Palette.textDim)
                                Spacer()
                                DatePicker("", selection: Binding(
                                    get: { store.profile.birthday ?? defaultBirthday },
                                    set: { store.profile.birthday = $0 }
                                ), displayedComponents: .date)
                                .labelsHidden()
                                .tint(SS14Palette.gold)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                    SS14Section(title: "Assignment",
                                footer: "Your station job sets your ID card, department colour and job icon, straight from Space Station 14.") {
                        Button { showJobs = true } label: {
                            SS14Row {
                                Text("Station job").foregroundStyle(SS14Palette.textDim).frame(width: 104, alignment: .leading)
                                JobIcon(job: store.profile.job, size: 18)
                                Text(store.profile.job.name)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(SS14Palette.textDisabled)
                            }
                        }
                        .buttonStyle(.plain)
                        SS14FieldRow(label: "Real-life job", placeholder: "Student, Mechanic…", text: $store.profile.jobTitle)
                        SS14FieldRow(label: "Home city", placeholder: "Denver, CO", text: $store.profile.homeCity)
                    }

                    SS14Section(title: "Records",
                                footer: "Saved on this phone. When you chat, your ID is sent to OpenAI with your message so \(store.paiName) can personalise replies.") {
                        SS14Row {
                            TextField("", text: $store.profile.interests,
                                      prompt: Text("Interests: games, music, food…").foregroundColor(SS14Palette.textDisabled),
                                      axis: .vertical)
                                .lineLimit(1...4)
                                .ss14Field()
                        }
                        SS14Row {
                            TextField("", text: $store.profile.notes,
                                      prompt: Text("Anything else \(store.paiName) should know").foregroundColor(SS14Palette.textDisabled),
                                      axis: .vertical)
                                .lineLimit(2...8)
                                .ss14Field()
                        }
                    }
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(SS14Palette.space.ignoresSafeArea())
        .sheet(isPresented: $showJobs) { JobPickerSheet(selection: $store.profile.stationJob) }
        .fullScreenCover(isPresented: $editing) { CharacterEditor().environmentObject(store) }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        store.setPhoto(image.squareThumbnail(side: 600))
                        store.profile.showPhoto = true
                    }
                    SFX.stamp.play()                 // photo stamped onto the ID
                }
            }
        }
        .onChange(of: store.profile.preferredName) { _, _ in store.rescheduleAll() }
    }

    private var defaultBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    }
}

/// Your talk sound: SS14 + fork species voices (Voice/Talk, speech_sounds.yml).
struct VoicePickerRow: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let audio = AudioManifest.shared
        let current = SFX.voiceID(for: store.profile.character)
        SS14Row(alternate: true) {
            Text("Voice").foregroundStyle(SS14Palette.textDim).frame(width: 104, alignment: .leading)
            Menu {
                Button("Species default") { store.profile.character.voice = nil; preview() }
                ForEach(["Space Station 14", "Goob Station", "Starlight", "Nuclear 14"], id: \.self) { src in
                    let list = audio.voices.filter { $0.speech.source == src }
                    if !list.isEmpty {
                        Section(src) {
                            ForEach(Array(list.enumerated()), id: \.offset) { _, v in
                                Button(v.speech.name) { store.profile.character.voice = v.id; preview() }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(audio.speech[current]?.name ?? "Default").foregroundStyle(SS14Palette.text)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(SS14Palette.textDim)
                }
            }
            Spacer()
            Button { preview() } label: { Image(systemName: "speaker.wave.2.fill") }
                .buttonStyle(.ss14(.normal, compact: true))
                .accessibilityLabel("Preview voice")
        }
    }

    private func preview() {
        SFX.userSpeech(for: ["Hello.", "Hello?", "Hello!"].randomElement() ?? "Hello.",
                       voiceID: SFX.voiceID(for: store.profile.character))
        store.characterAnim = AnimEvent(kind: .talk)
    }
}

/// Your SS14 character, with a button into the full editor.
struct CharacterCard: View {
    @EnvironmentObject var store: AppStore
    var onEdit: () -> Void
    @State private var dir = 0

    init(onEdit: @escaping () -> Void) {
        self.onEdit = onEdit
    }

    var body: some View {
        let c = store.profile.character
        SS14Section(title: "Character", trailing: c.speciesDef?.source) {
            HStack(spacing: 12) {
                ZStack {
                    PreviewFloor()
                    LiveCharacter(profile: c, job: store.profile.stationJob, event: store.characterAnim, baseDir: dir)
                        .padding(6)
                }
                .frame(width: 112, height: 112)
                .onTapGesture {
                    dir = [0: 2, 2: 1, 1: 3, 3: 0][dir] ?? 0
                    SFX.click.play()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(c.speciesDef?.name ?? "Unknown").font(SS14Font.bold(16))
                    Text("\(c.sex) · \(c.markings.count) markings").font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
                    Text("Tap the sprite to turn. Type *flip or *scream in chat.")
                        .font(SS14Font.body(11)).foregroundStyle(SS14Palette.textDisabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { onEdit(); SFX.idSwipe.play() } label: {
                        Label("Edit character", systemImage: "paintbrush.pointed.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ss14(.good, compact: true))
                }
            }
            .padding(10)
        }
    }
}

/// SS14 job icon (8x8 sprite from job_icons.rsi), scaled pixel-perfect.
struct JobIcon: View {
    let job: SS14Job
    var size: CGFloat = 16

    var body: some View {
        Image(job.icon)
            .resizable()
            .interpolation(.none)
            .frame(width: size, height: size)
    }
}

/// The SS14 ID card sprite with its department stripe.
struct IDCardSprite: View {
    let job: SS14Job

    var body: some View {
        ZStack {
            Image(SS14.cardSprite(for: job)).resizable().interpolation(.none)
            Image("idcard_stripe").renderingMode(.template).resizable().interpolation(.none)
                .foregroundStyle(SS14.color(forDepartment: job.department))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct JobPickerSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    init(selection: Binding<String>) {
        self._selection = selection
    }

    var body: some View {
        SS14WindowChrome(title: "Station job", trailing: AnyView(
            Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }
                .buttonStyle(.plain).foregroundStyle(SS14Palette.textDim)
        )) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(ForkData.allDepartments, id: \.self) { dept in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Rectangle().fill(SS14.color(forDepartment: dept)).frame(width: 10, height: 10)
                                Text(dept).font(SS14Font.bold(14))
                                    .foregroundStyle(dept == "Command" ? Color(hex: "8FB4E3") : SS14.color(forDepartment: dept))
                            }
                            VStack(spacing: 0) {
                                ForEach(Array(ForkData.allJobs.filter { $0.department == dept }.enumerated()), id: \.offset) { i, job in
                                    Button {
                                        selection = job.id
                                        SFX.idSwipe.play()           // new job → swipe the ID
                                        Haptics.tap()
                                        dismiss()
                                    } label: {
                                        SS14Row(alternate: i % 2 == 1) {
                                            JobIcon(job: job, size: 24)
                                            Text(job.name)
                                            Spacer()
                                            if job.id == selection {
                                                Image(systemName: "checkmark").foregroundStyle(SS14Palette.gold)
                                            }
                                        }
                                        .background(job.id == selection ? SS14Palette.itemRowSelected : Color.clear)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(SS14Palette.panelDark)
                        }
                    }
                }
                .padding(12)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(SS14Palette.windowBackground)
        .preferredColorScheme(.dark)
    }
}

/// The station-style ID card. Flips over when your job changes.
struct IDCardView: View {
    @EnvironmentObject var store: AppStore
    @State private var flip: Double = 0

    var body: some View {
        let p = store.profile
        let job = p.job
        let deptColor = SS14.color(forDepartment: job.department)
        let accentText = job.department == "Command" ? Color(hex: "8FB4E3") : deptColor
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                IDCardSprite(job: job).frame(width: 34, height: 34)
                Text("NANOTRASEN ID")
                    .font(SS14Font.display(13))
                Spacer()
                JobIcon(job: job, size: 16)
                Text(job.department)
                    .font(SS14Font.display(12))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(ZStack { deptColor.opacity(0.85); StripeBack(color: .white.opacity(0.08)) })

            HStack(alignment: .top, spacing: 14) {
                Group {
                    if let img = store.idPhoto, p.showPhoto {
                        Image(uiImage: img).resizable().scaledToFill()
                            .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
                    } else {
                        ZStack(alignment: .bottom) {
                            LinearGradient(colors: [SS14Palette.itemRow, deptColor.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                            LiveCharacter(profile: p.character, job: p.stationJob, event: store.characterAnim)
                                .frame(width: 96, height: 96)
                                .offset(y: 6)
                        }
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
                    }
                }
                .frame(width: 84, height: 100)
                .clipShape(Rectangle())
                .overlay(Rectangle().stroke(deptColor, lineWidth: 2))

                VStack(alignment: .leading, spacing: 4) {
                    Text(p.fullName.isEmpty ? "UNREGISTERED" : p.fullName)
                        .font(SS14Font.display(19))
                        .foregroundStyle(SS14Palette.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("(\(job.name))")
                        .font(SS14Font.bold(14))
                        .foregroundStyle(accentText)
                    if !p.jobTitle.isEmpty {
                        Text(p.jobTitle).font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
                    }
                    if !p.pronouns.isEmpty {
                        Text(p.pronouns).font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
                    }
                    if let b = p.birthday {
                        Text("DOB \(b.formatted(date: .abbreviated, time: .omitted))")
                            .font(SS14Font.mono(11)).foregroundStyle(SS14Palette.textDim)
                    }
                    Spacer(minLength: 0)
                    Text("ID# \(p.idNumber.uppercased())")
                        .font(SS14Font.mono(10))
                        .foregroundStyle(SS14Palette.textDisabled)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .background(SS14Palette.windowBackground)
        .clipShape(ChamferShape(cut: 14))
        .overlay(ChamferShape(cut: 14).stroke(deptColor.opacity(0.8), lineWidth: 1.5))
        .shadow(color: deptColor.opacity(0.3), radius: 14)
        .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .onChange(of: store.profile.stationJob) { _, _ in
            flip = 0
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { flip = 360 }
        }
    }
}

extension UIImage {
    func squareThumbnail(side: CGFloat) -> UIImage {
        let minSide = min(size.width, size.height)
        let scale = side / minSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: (side - newSize.width) / 2, y: (side - newSize.height) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            draw(in: CGRect(origin: origin, size: newSize))
        }
    }
}
