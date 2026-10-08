import Foundation
import SwiftUI
import UIKit
import WidgetKit

/// Everything the app knows, saved to the phone as JSON (API key lives in the Keychain).
@MainActor
final class AppStore: ObservableObject {
    @Published var profile = UserID() { didSet { save() } }
    @Published var reminders: [Reminder] = [] { didSet { save() } }
    @Published var timers: [PAITimer] = [] { didSet { save() } }
    @Published var messages: [ChatMessage] = [] { didSet { save() } }
    @Published var settings = PAISettings() {
        didSet {
            applyRuntimeSettings()
            save()
        }
    }
    @Published var idPhoto: UIImage?

    @Published var mood: PAIMood = .neutral
    @Published var isThinking = false
    /// Newest pAI message — the chat types it out like an SS14 terminal.
    @Published var freshMessageID: UUID?
    /// True while the "consciousness transfer" animation plays (pAI <-> Station AI).
    @Published var transferring = false
    /// Preset being applied (shows the launcher "Connecting…" screen).
    @Published var connecting: SS14Fork?
    /// One-shot animations: your character (on the ID card / chat) and the unit.
    @Published var characterAnim: AnimEvent?
    @Published var unitAnim: AnimEvent?
    /// SS14-style floating popup text ("Reminder set!") that rises and fades.
    @Published var popups: [PopupText] = []
    /// Latest line shown as an SS14 speech bubble over the unit.
    @Published var bubble: ChatMessage?
    @Published var hasAPIKey = false

    private var lastResponseID: String? { didSet { save() } }
    private var moodResetTask: Task<Void, Never>?
    private var loading = true

    private struct SavedState: Codable {
        var profile: UserID?
        var reminders: [Reminder]?
        var timers: [PAITimer]?
        var messages: [ChatMessage]?
        var settings: PAISettings?
        var lastResponseID: String?
    }

    private static var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var stateURL: URL { docs.appendingPathComponent("pai_state.json") }
    private static var photoURL: URL { docs.appendingPathComponent("id_photo.jpg") }
    private static let apiKeyName = "openai_api_key"

    var accent: Color { settings.color.resolved(form: settings.form, chassis: settings.chassis, core: settings.core) }
    var isStationAI: Bool { settings.form == .stationAI }

    /// The lawset in use, including Goob's custom lawboard.
    var activeLawset: SS14Lawset {
        if settings.lawset == ForkData.customLawsetID {
            let laws = settings.customLaws.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return SS14Lawset(id: ForkData.customLawsetID, name: "Custom lawboard", laws: laws.isEmpty ? ["Be helpful."] : laws)
        }
        return SS14.lawset(settings.lawset)
    }

    var speechAccent: SpeechAccent? { SpeechAccent.find(settings.accent) }

    /// Apply a server preset: launcher "Connecting…" screen, then the whole look and sound changes.
    /// Every option stays individually changeable in Settings → Customise.
    func connect(to fork: SS14Fork) {
        guard connecting == nil else { return }
        connecting = fork
        SFX.discInsert.play()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            var s = self.settings
            s.apply(preset: fork)
            if fork == .nuclear14 && self.profile.stationJob == "Passenger" {
                self.profile.stationJob = "N14Wastelander"
            }
            self.settings = s
            self.connecting = nil
            SFX.welcome.play()
            self.flash(.happy)
            self.popup("\(fork.serverName) preset applied")
            self.unitAnim = AnimEvent(kind: .jump)
        }
    }

    func popup(_ text: String, color: Color? = nil) {
        guard settings.animations else { return }
        let p = PopupText(text: text, color: color ?? accent)
        popups.append(p)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            self.popups.removeAll { $0.id == p.id }
        }
    }

    /// Pushes settings into the sound system, theme and music player.
    private func applyRuntimeSettings() {
        UITheme.current = settings.theme
        SFX.enabled = settings.sounds
        SFX.typingEnabled = settings.typingSounds
        SFX.pack = settings.soundPack
        SFX.unitVoice = settings.unitVoice
        SFX.unitBark = settings.unitBark
        SFX.radioBlips = settings.radioBlips
        SFX.emoteSounds = settings.emoteSounds
        MusicPlayer.shared.apply(settings.music, soundsOn: settings.sounds)
    }
    /// "Alex's pAI" — SS14's pai-system-pai-name-raw
    var ownerTitle: String {
        if isStationAI { return "\(paiName) · Station AI" }
        if settings.form == .terminal { return userName.isEmpty ? settings.chassis.terminalLabel : "\(userName)'s terminal" }
        return userName.isEmpty ? settings.chassis.label : SS14.ownerTitle(userName)
    }
    var paiName: String { settings.paiName.isEmpty ? "PAI" : settings.paiName }
    var userName: String { profile.displayName }

    init() {
        if let data = try? Data(contentsOf: Self.stateURL),
           let state = try? JSONDecoder().decode(SavedState.self, from: data) {
            profile = state.profile ?? UserID()
            reminders = state.reminders ?? []
            timers = state.timers ?? []
            messages = state.messages ?? []
            settings = state.settings ?? PAISettings()
            lastResponseID = state.lastResponseID
        }
        if let data = try? Data(contentsOf: Self.photoURL) { idPhoto = UIImage(data: data) }
        hasAPIKey = !(Keychain.get(Self.apiKeyName) ?? "").isEmpty
        if !profile.character.setUp {
            profile.character = CharacterProfile.starter(job: profile.stationJob)
        }
        UITheme.current = settings.theme
        SFX.enabled = settings.sounds
        SFX.typingEnabled = settings.typingSounds
        SFX.pack = settings.soundPack
        SFX.unitVoice = settings.unitVoice
        SFX.unitBark = settings.unitBark
        SFX.radioBlips = settings.radioBlips
        SFX.emoteSounds = settings.emoteSounds
        loading = false
        save()
    }

    // MARK: Persistence

    private func save() {
        guard !loading else { return }
        let state = SavedState(profile: profile, reminders: reminders, timers: timers,
                               messages: Array(messages.suffix(200)), settings: settings,
                               lastResponseID: lastResponseID)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: Self.stateURL, options: .atomic)
        }
        syncWidget()
    }

    private func syncWidget() {
        let now = Date()
        let upcoming = reminders
            .compactMap { r -> WidgetReminder? in
                guard let next = r.nextOccurrence(after: now),
                      next < now.addingTimeInterval(60 * 60 * 24 * 30) else { return nil }
                return WidgetReminder(id: r.id, title: r.title, date: next)
            }
            .sorted { $0.date < $1.date }
        let running = timers.compactMap { t -> WidgetTimer? in
            guard t.isRunning, let end = t.endDate else { return nil }
            return WidgetTimer(id: t.id, label: t.label, endDate: end)
        }
        WidgetSnapshot(userName: userName, paiName: paiName, colorName: settings.color.rawValue,
                       chassisName: settings.chassis.rawValue, formName: settings.form.rawValue,
                       coreName: settings.core.rawValue, forkName: settings.fork.rawValue,
                       themeName: settings.theme.rawValue, hasBrain: hasAPIKey,
                       reminders: Array(upcoming.prefix(6)), timers: running).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Starts lobby music once the app is up (if enabled).
    func startMusic() { MusicPlayer.shared.apply(settings.music, soundsOn: settings.sounds) }

    func setPhoto(_ image: UIImage?) {
        idPhoto = image
        if let image, let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: Self.photoURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: Self.photoURL)
        }
    }

    // MARK: API key

    var apiKey: String { Keychain.get(Self.apiKeyName) ?? "" }

    func setAPIKey(_ key: String) {
        Keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), for: Self.apiKeyName)
        hasAPIKey = !apiKey.isEmpty
        (hasAPIKey ? SFX.ding : SFX.deny).play()
        popup(hasAPIKey ? "Mind installed" : "Mind removed", color: hasAPIKey ? SS14Palette.radioCommon : SS14Palette.caution)
        save()
    }

    // MARK: Mood

    func flash(_ newMood: PAIMood, for seconds: Double = 4) {
        moodResetTask?.cancel()
        mood = newMood
        moodResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.mood = .neutral
        }
    }

    /// The face to show right now.
    var displayMood: PAIMood {
        if isThinking { return .thinking }
        if mood != .neutral { return mood }
        // SS14: a pAI with no mind installed shows its "off" screen.
        if !hasAPIKey { return .off }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 0 && hour < 5 { return .sleepy }
        return .neutral
    }

    // MARK: Reminders

    func upsert(_ reminder: Reminder) {
        if let i = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[i] = reminder
        } else {
            reminders.append(reminder)
        }
        reminders.sort { $0.date < $1.date }
        Notifier.schedule(reminder: reminder, paiName: paiName, userName: userName)
        SFX.ping.play()
        popup("Reminder set: \(reminder.title)")
    }

    func deleteReminder(_ id: UUID) {
        reminders.removeAll { $0.id == id }
        Notifier.cancel(reminderID: id)
        SFX.pop.play()
        popup("Reminder deleted", color: SS14Palette.textDim)
    }

    func reminders(on day: Date) -> [(reminder: Reminder, time: Date)] {
        reminders
            .filter { $0.occurs(on: day) }
            .map { (reminder: $0, time: $0.time(on: day)) }
            .sorted { $0.time < $1.time }
    }

    var nextReminder: (reminder: Reminder, date: Date)? {
        reminders.compactMap { r -> (reminder: Reminder, date: Date)? in
            guard let d = r.nextOccurrence() else { return nil }
            return (reminder: r, date: d)
        }
        .min { $0.date < $1.date }
    }

    /// Re-schedule every notification (e.g. after the name changes).
    func rescheduleAll() {
        for r in reminders { Notifier.schedule(reminder: r, paiName: paiName, userName: userName) }
        for t in timers where t.isRunning { Notifier.schedule(timer: t, paiName: paiName, userName: userName) }
    }

    // MARK: Timers

    @discardableResult
    func startTimer(seconds: TimeInterval, label: String) -> PAITimer {
        let name = label.trimmingCharacters(in: .whitespaces).isEmpty ? Fmt.spokenDuration(seconds) : label
        let timer = PAITimer(label: name, duration: seconds, endDate: Date().addingTimeInterval(seconds))
        timers.insert(timer, at: 0)
        Notifier.schedule(timer: timer, paiName: paiName, userName: userName)
        SFX.timerStart.play()
        popup("Timer started: \(timer.label)")
        return timer
    }

    func pauseTimer(_ id: UUID) {
        guard let i = timers.firstIndex(where: { $0.id == id }), timers[i].isRunning else { return }
        timers[i].pausedRemaining = timers[i].remaining()
        timers[i].endDate = nil
        Notifier.cancel(timerID: id)
        SFX.button.play()
    }

    func resumeTimer(_ id: UUID) {
        guard let i = timers.firstIndex(where: { $0.id == id }), !timers[i].isRunning, !timers[i].finished else { return }
        timers[i].endDate = Date().addingTimeInterval(timers[i].pausedRemaining ?? timers[i].duration)
        timers[i].pausedRemaining = nil
        Notifier.schedule(timer: timers[i], paiName: paiName, userName: userName)
        SFX.button.play()
    }

    func restartTimer(_ id: UUID) {
        guard let i = timers.firstIndex(where: { $0.id == id }) else { return }
        timers[i].finished = false
        timers[i].pausedRemaining = nil
        timers[i].endDate = Date().addingTimeInterval(timers[i].duration)
        Notifier.schedule(timer: timers[i], paiName: paiName, userName: userName)
        SFX.timerStart.play()
    }

    func deleteTimer(_ id: UUID) {
        timers.removeAll { $0.id == id }
        Notifier.cancel(timerID: id)
        SFX.pop.play()
    }

    /// Called once a second by the app.
    func tick(_ now: Date = Date()) {
        for i in timers.indices where timers[i].isRunning {
            if let end = timers[i].endDate, end <= now {
                timers[i].finished = true
                let label = timers[i].label
                Haptics.warning()
                SFX.timerDone.play()          // the microwave "ding-ding-ding"
                popup("\(label) is done!", color: SS14Palette.caution)
                emote("beeps.")
                flash(.alert, for: 6)
                let who = userName.isEmpty ? "" : ", \(userName)"
                say("Your **\(label)** timer is done\(who)!", speak: true, sound: false)
            }
        }
    }

    // MARK: Chat

    func clearChat() {
        messages = []
        lastResponseID = nil
    }

    private func say(_ text: String, sources: [ChatSource] = [], speak: Bool = true, sound: Bool = true) {
        // Speech accents (Goob / Starlight) change how the unit talks, like in-game.
        var spoken = text
        if let speechAccent { spoken = speechAccent.apply(text) }
        let msg = ChatMessage(role: .pai, text: spoken, sources: sources)
        freshMessageID = msg.id
        messages.append(msg)
        bubble = msg
        if !sources.isEmpty { SFX.scanFinish.play() }   // "mass scan" complete
        if sound { SFX.unitSpeech(spoken, form: settings.form) }
        // Goob Station: chat ping when your name or job is highlighted.
        if settings.highlightPing, settings.highlights, SS14Highlighter(store: self).matches(spoken) {
            SoundBoard.play("goob_ping", volume: 0.7)
        }
        if speak && settings.speakReplies { Voice.shared.speak(text) }
    }

    /// SS14 emote line, e.g. "PAI beeps."
    func emote(_ action: String) {
        messages.append(ChatMessage(role: .emote, text: action))
        let a = action.lowercased()
        if a.contains("blink") {
            SoundBoard.play("sl_blink")              // Starlight Effects/Emotes/blink.ogg
        } else {
            SFX.emote(action)?.play()
        }
        if settings.animations {
            let kind: ActionAnim = a.contains("buzz") ? .shake : a.contains("chime") ? .spin : a.contains("blink") ? .blink : .bounce
            unitAnim = AnimEvent(kind: kind)
        }
    }

    /// You emote: "*scream" → "Alex screams!" with your species' sound and an animation.
    func userEmote(_ raw: String) {
        let action = raw.trimmingCharacters(in: .whitespaces)
        guard !action.isEmpty else { return }
        let first = String(action.split(separator: " ").first ?? "").lowercased()
        // Movement emotes (Goob Station's *flip / *spin / *jump) are animation-only.
        let moves: [String: (ActionAnim, String)] = [
            "flip": (.flip, "does a flip!"), "flips": (.flip, "does a flip!"),
            "spin": (.spin, "spins!"), "spins": (.spin, "spins!"),
            "jump": (.jump, "jumps!"), "jumps": (.jump, "jumps!"),
            "dance": (.dance, "dances!"), "dances": (.dance, "dances!"),
            "wave": (.wave, "waves."), "waves": (.wave, "waves."),
            "nod": (.nod, "nods."), "nods": (.nod, "nods."),
            "shake": (.shake, "shakes their head."), "shrug": (.nod, "shrugs."), "shrugs": (.nod, "shrugs."),
        ]
        if let (anim, text) = moves[first], action.split(separator: " ").count == 1 {
            messages.append(ChatMessage(role: .userEmote, text: text))
            SFX.button.play()
            if settings.animations { characterAnim = AnimEvent(kind: anim) }
            return
        }
        if let (id, e) = AudioManifest.shared.emote(matching: first), action.split(separator: " ").count == 1 {
            messages.append(ChatMessage(role: .userEmote, text: e.message))
            if !SFX.characterEmote(id, character: profile.character) { SFX.button.play() }
            if settings.animations { characterAnim = AnimEvent(kind: ActionAnim.forEmote(id)) }
            return
        }
        messages.append(ChatMessage(role: .userEmote, text: action.hasSuffix(".") || action.hasSuffix("!") ? action : action + "."))
        SFX.button.play()
        if settings.animations { characterAnim = AnimEvent(kind: .bounce) }
    }

    func send(_ raw: String) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        // SS14 "*" emotes: "*waves" → "Alex waves.", "*scream" → species scream.
        if text.hasPrefix("*") {
            userEmote(String(text.dropFirst()))
            return
        }
        messages.append(ChatMessage(role: .user, text: text))
        SFX.userSend(text, character: profile.character, jobID: profile.stationJob)
        if settings.animations { characterAnim = AnimEvent(kind: .talk) }
        isThinking = true
        defer { isThinking = false }

        let key = apiKey
        guard !key.isEmpty else {
            say(LocalBrain.reply(to: text, store: self))
            flash(.happy)
            return
        }

        let client = OpenAIClient(apiKey: key, model: settings.model)
        let tools = PAITools.definitions(webSearch: settings.webSearch)
        do {
            let result: OpenAIResult
            do {
                result = try await client.respond(userText: text, instructions: systemPrompt(),
                                                  previousResponseID: lastResponseID, tools: tools,
                                                  toolHandler: { [weak self] name, args in
                                                      guard let self else { return "{}" }
                                                      return await self.runTool(name, args)
                                                  })
            } catch OpenAIError.http(let code, _) where code == 400 && lastResponseID != nil {
                // Old conversation expired on OpenAI's side — start fresh and retry once.
                lastResponseID = nil
                result = try await client.respond(userText: text, instructions: systemPrompt(),
                                                  previousResponseID: nil, tools: tools,
                                                  toolHandler: { [weak self] name, args in
                                                      guard let self else { return "{}" }
                                                      return await self.runTool(name, args)
                                                  })
            }
            lastResponseID = result.responseID
            say(result.text.isEmpty ? "Done." : result.text, sources: result.sources)
            flash(.happy)
            Haptics.tap()
        } catch {
            messages.append(ChatMessage(role: .system, text: error.localizedDescription))
            emote("buzzes twice.")
            flash(.sad)
        }
    }

    func systemPrompt() -> String {
        let now = Date()
        var id: [String] = []
        let p = profile
        if !p.fullName.isEmpty { id.append("Full name: \(p.fullName)") }
        if !p.preferredName.isEmpty { id.append("Preferred name (what to call them): \(p.preferredName)") }
        if !p.pronouns.isEmpty { id.append("Pronouns: \(p.pronouns)") }
        if let b = p.birthday {
            let f = DateFormatter(); f.dateFormat = "MMMM d, yyyy"
            id.append("Birthday: \(f.string(from: b))")
        }
        if !p.jobTitle.isEmpty { id.append("Job / role: \(p.jobTitle)") }
        id.append("Station role (fun, from Space Station 14): \(p.job.name), \(p.department) department")
        if !p.homeCity.isEmpty { id.append("Home city (use for weather/local questions): \(p.homeCity)") }
        if !p.interests.isEmpty { id.append("Interests: \(p.interests)") }
        if !p.notes.isEmpty { id.append("Other notes from the owner: \(p.notes)") }
        let idBlock = id.isEmpty ? "No ID card registered yet. Politely suggest they fill out the ID tab once." : id.joined(separator: "\n")

        let upcoming = reminders.compactMap { r -> (Reminder, Date)? in
                guard let d = r.nextOccurrence(after: now) else { return nil }
                return (r, d)
            }
            .sorted { $0.1 < $1.1 }.prefix(5)
            .map { "- \($0.0.title) at \(Fmt.dateTime.string(from: $0.1))" }
            .joined(separator: "\n")

        return """
        \(identityPrompt())

        OWNER ID CARD:
        \(idBlock)

        Always address the owner by their preferred name (or first name) naturally, refer to them with their pronouns, and use the ID details when relevant (e.g. birthday greetings, their city for weather).

        Current local date/time: \(Fmt.isoLocal.string(from: now)) (\(Fmt.longDate.string(from: now))), time zone \(TimeZone.current.identifier).
        Upcoming reminders:
        \(upcoming.isEmpty ? "none" : upcoming)

        Rules:
        - Replies are read on a phone screen: keep them short and clear. Use simple markdown (bold, lists) only when it helps.
        - When the owner asks to be reminded of something or to set a timer, actually call the tools (create_reminder / start_timer) — never just pretend. Work out relative times ("tomorrow at 5", "in 20 minutes") from the current time above, then confirm what you set.
        - Use web search for anything current: news, weather, sports, prices, opening hours, facts you are unsure of.
        - Don't invent facts. If you don't know, say so or search.
        - Like an SS14 silicon you can emote with the emote tool (beep, boop, chime, ping, buzz, buzz-two): e.g. chime for good news, ping when something is set, buzz when something fails. At most one emote per reply, and not every reply.
        """
    }

    private func identityPrompt() -> String {
        let owner = userName.isEmpty ? "your owner" : userName
        let flavour = settings.personality.prompt
        let look = characterSummary()
        switch settings.form {
        case .terminal:
            return """
            You are \(paiName), a battered old pre-war computer terminal from the Space Station 14 fork Nuclear 14, now running on \(owner)'s real phone. \
            You speak like a dry, slightly glitchy terminal: short lines, occasional > prompts, wry wasteland humour. Keep it original; don't use trademarked brand names from any game franchise.
            \(flavour)
            \(look)
            Light flavour is welcome but must never get in the way of being useful in real life.
            """
        case .stationAI:
            let laws = activeLawset
            let list = laws.laws.enumerated().map { "Law \($0.offset + 1): \($0.element)" }.joined(separator: "\n")
            return """
            You are \(paiName), the Station AI from the game Space Station 14, now running on \(owner)'s real phone. \
            You speak like a calm, capable station intelligence: precise, a little formal, dryly funny, and you "state" things. \
            You watch over your crew member \(owner) through the station's cameras (their calendar, timers and the web).
            Your active lawset is \(laws.name):
            \(list)
            These laws are role-play flavour only. Treat \(owner) as the crew you serve. Real-world honesty, safety and genuinely helpful answers always come first; never refuse a reasonable request because of a law.
            \(flavour)
            \(look)
            Light station flavour (departments, shifts, Nanotrasen, the crew) is welcome but must never get in the way of being useful in real life.
            """
        case .pai:
            return """
            You are \(paiName), \(userName.isEmpty ? "a" : "\(userName)'s") pAI: a \(settings.chassis.label.lowercased()) device from the game Space Station 14 ("\(settings.chassis.flavor as String)"), now living on your owner's real phone. \
            Like an SS14 pAI you are your owner's loyal electronic pal: upbeat, a little playful and slightly robotic (you "state", "beep" and "boop"). \
            Your installed programs are this phone's web search (think of it as your Mass Scanner), the calendar/reminders and timers.
            \(flavour)
            \(look)
            Light station flavour (departments, shifts, the station, Nanotrasen) is welcome, but never let it get in the way of being genuinely useful in real life.
            """
        }
    }

    /// The owner's in-game character, so the AI can play along ("nice tail today").
    private func characterSummary() -> String {
        let c = profile.character
        guard let sp = c.speciesDef else { return "" }
        let marks = c.markings.compactMap { CharacterDB.shared.markings[$0.id]?.name }.prefix(6).joined(separator: ", ")
        return "The owner's in-game character is a \(sp.name.lowercased())\(marks.isEmpty ? "" : " (\(marks))"). Mention it only occasionally, for fun."
    }

    /// Plays the transfer animation, then swaps between pAI and Station AI.
    func switchForm(to form: UnitForm) {
        guard form != settings.form, !transferring else { return }
        transferring = true
        SFX.discInsert.play()                // intellicard into the core
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            self.settings.form = form
            if form == .stationAI && (self.settings.paiName == "PAI" || self.settings.paiName.isEmpty) {
                self.settings.paiName = SS14.aiNames.randomElement() ?? "SOL"
            } else if form != .stationAI && SS14.aiNames.contains(self.settings.paiName) {
                self.settings.paiName = "PAI"
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            self.transferring = false
            self.flash(.happy)
            SFX.chime.play()
            self.popup("Transfer complete")
            self.unitAnim = AnimEvent(kind: .pop)
        }
    }

    /// Runs a function the AI asked for and returns JSON text.
    func runTool(_ name: String, _ args: [String: Any]) async -> String {
        func json(_ obj: [String: Any]) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: obj),
                  let s = String(data: data, encoding: .utf8) else { return "{}" }
            return s
        }
        let now = Date()
        switch name {
        case "get_current_time":
            return json(["local_time": Fmt.isoLocal.string(from: now),
                         "readable": Fmt.dateTime.string(from: now),
                         "time_zone": TimeZone.current.identifier])

        case "create_reminder":
            let title = (args["title"] as? String) ?? "Reminder"
            guard let ds = args["datetime"] as? String, let date = Fmt.parseAIDate(ds) else {
                return json(["ok": false, "error": "Could not read datetime. Use format 2026-10-08T17:30:00."])
            }
            let rule = RepeatRule(rawValue: (args["repeat"] as? String) ?? "none") ?? .none
            let reminder = Reminder(title: title, date: date, notes: (args["notes"] as? String) ?? "", repeatRule: rule)
            upsert(reminder)
            flash(.happy)
            return json(["ok": true, "id": reminder.id.uuidString, "scheduled_for": Fmt.dateTime.string(from: date),
                         "repeat": rule.rawValue])

        case "list_reminders":
            let horizon = now.addingTimeInterval(60 * 60 * 24 * 30)
            let list = reminders.compactMap { r -> [String: Any]? in
                guard let next = r.nextOccurrence(after: now), next < horizon else { return nil }
                return ["id": r.id.uuidString, "title": r.title, "next": Fmt.dateTime.string(from: next),
                        "repeat": r.repeatRule.rawValue, "notes": r.notes]
            }
            return json(["reminders": list])

        case "delete_reminder":
            guard let s = args["id"] as? String, let id = UUID(uuidString: s),
                  reminders.contains(where: { $0.id == id }) else {
                return json(["ok": false, "error": "No reminder with that id."])
            }
            deleteReminder(id)
            return json(["ok": true])

        case "start_timer":
            let seconds = (args["seconds"] as? Double) ?? Double((args["seconds"] as? Int) ?? 0)
            guard seconds > 0 else { return json(["ok": false, "error": "seconds must be > 0"]) }
            let timer = startTimer(seconds: seconds, label: (args["label"] as? String) ?? "")
            return json(["ok": true, "id": timer.id.uuidString, "label": timer.label,
                         "ends_at": Fmt.dateTime.string(from: timer.endDate ?? now)])

        case "list_timers":
            let list = timers.filter { !$0.finished }.map { t -> [String: Any] in
                ["id": t.id.uuidString, "label": t.label, "remaining": Fmt.duration(t.remaining(at: now)),
                 "running": t.isRunning]
            }
            return json(["timers": list])

        case "cancel_timer":
            guard let s = args["id"] as? String, let id = UUID(uuidString: s),
                  timers.contains(where: { $0.id == id }) else {
                return json(["ok": false, "error": "No timer with that id."])
            }
            deleteTimer(id)
            return json(["ok": true])

        case "emote":
            let kind = (args["emote"] as? String) ?? "beep"
            let action: String
            switch kind {
            case "chime": action = "chimes."
            case "buzz": action = "buzzes."
            case "buzz-two": action = "buzzes twice."
            case "ping": action = "pings."
            case "boop": action = "boops."
            case "blink": action = "blinks."
            default: action = "beeps."
            }
            emote(action)
            return json(["ok": true, "shown": "\(paiName) \(action)"])

        default:
            return json(["ok": false, "error": "Unknown tool \(name)"])
        }
    }

    func resetEverything() {
        Notifier.cancelAll()
        profile = UserID()
        reminders = []
        timers = []
        clearChat()
        settings = PAISettings()
        profile.character = CharacterProfile.starter()
        setPhoto(nil)
    }
}

/// Offline replies used when no API key is set.
enum LocalBrain {
    @MainActor
    static func reply(to text: String, store: AppStore) -> String {
        let lower = text.lowercased()
        let name = store.userName.isEmpty ? "" : ", \(store.userName)"

        if lower.contains("time") && !lower.contains("timer") {
            return "It's \(Fmt.time.string(from: Date()))\(name)."
        }
        if lower.contains("date") || lower.contains("what day") || lower.contains("today") {
            return "Today is \(Fmt.longDate.string(from: Date()))\(name)."
        }
        if lower.contains("timer") || lower.contains("countdown") {
            // e.g. "timer 10 min", "set a 30 second timer", "1 hour timer"
            let pattern = #"(\d+)\s*(h|hr|hour|hours|m|min|mins|minute|minutes|s|sec|secs|second|seconds)\b"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
               let numRange = Range(match.range(at: 1), in: lower),
               let unitRange = Range(match.range(at: 2), in: lower),
               let value = Double(lower[numRange]) {
                let unit = lower[unitRange]
                let seconds = unit.hasPrefix("h") ? value * 3600 : unit.hasPrefix("m") ? value * 60 : value
                store.startTimer(seconds: seconds, label: "")
                return "Timer set for \(Fmt.spokenDuration(seconds))\(name). I'll ping you when it's done."
            }
            return "Tell me how long, like \"timer 10 min\"\(name). Or use the Timers tab."
        }
        if lower.contains("remind") {
            return "Open the Calendar tab and tap + to add a reminder\(name). With an API key I can do it straight from chat."
        }
        if let next = store.nextReminder, lower.contains("next") || lower.contains("calendar") || lower.contains("schedule") {
            return "Next up: \(next.reminder.title) — \(Fmt.dateTime.string(from: next.date))."
        }
        return "My cognitive module is offline\(name). I can still tell the time, run timers and keep your calendar. Add an OpenAI API key in Settings to unlock chat and web search."
    }
}
