import Foundation

// MARK: - ID card

struct UserID: Codable, Equatable {
    var fullName: String = ""
    var preferredName: String = ""
    var pronouns: String = ""
    var birthday: Date? = nil
    var jobTitle: String = ""              // real-life job
    var stationJob: String = "Passenger"   // SS14 job id, sets icon + department
    var homeCity: String = ""
    var interests: String = ""
    var notes: String = ""
    var idNumber: String = String(UUID().uuidString.prefix(8))
    /// Your SS14 character: species, body, hair, markings, outfit and voice.
    var character = CharacterProfile()
    /// ID card picture: your character sprite (default) or a real photo.
    var showPhoto = false

    init() {}

    /// Tolerant decoding so app updates never wipe your ID.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        preferredName = try c.decodeIfPresent(String.self, forKey: .preferredName) ?? ""
        pronouns = try c.decodeIfPresent(String.self, forKey: .pronouns) ?? ""
        birthday = try c.decodeIfPresent(Date.self, forKey: .birthday)
        jobTitle = try c.decodeIfPresent(String.self, forKey: .jobTitle) ?? ""
        stationJob = try c.decodeIfPresent(String.self, forKey: .stationJob) ?? "Passenger"
        homeCity = try c.decodeIfPresent(String.self, forKey: .homeCity) ?? ""
        interests = try c.decodeIfPresent(String.self, forKey: .interests) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        idNumber = try c.decodeIfPresent(String.self, forKey: .idNumber) ?? String(UUID().uuidString.prefix(8))
        character = (try? c.decodeIfPresent(CharacterProfile.self, forKey: .character)) ?? CharacterProfile()
        showPhoto = try c.decodeIfPresent(Bool.self, forKey: .showPhoto) ?? false
    }

    var job: SS14Job { SS14.anyJob(stationJob) ?? SS14.job("Passenger") }
    var department: String { job.department }

    /// What the pAI calls you.
    var displayName: String {
        let preferred = preferredName.trimmingCharacters(in: .whitespaces)
        if !preferred.isEmpty { return preferred }
        let first = fullName.split(separator: " ").first.map(String.init) ?? ""
        return first
    }

    var isEmpty: Bool {
        fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        preferredName.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Reminders

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Every day"
        case .weekly: return "Every week"
        case .monthly: return "Every month"
        }
    }
}

struct Reminder: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var date: Date
    var notes: String = ""
    var repeatRule: RepeatRule = .none

    /// The next time this reminder fires after `now` (nil if it's a one-off in the past).
    func nextOccurrence(after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        if date > now { return date }
        var comps = DateComponents()
        let parts = calendar.dateComponents([.hour, .minute, .weekday, .day], from: date)
        comps.hour = parts.hour
        comps.minute = parts.minute
        switch repeatRule {
        case .none: return nil
        case .daily: break
        case .weekly: comps.weekday = parts.weekday
        case .monthly: comps.day = parts.day
        }
        return calendar.nextDate(after: now, matching: comps, matchingPolicy: .nextTime)
    }

    /// Whether this reminder shows on a given calendar day.
    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let startOfDay = calendar.startOfDay(for: day)
        let startOfReminderDay = calendar.startOfDay(for: date)
        if calendar.isDate(day, inSameDayAs: date) { return true }
        guard startOfDay > startOfReminderDay else { return false }
        switch repeatRule {
        case .none: return false
        case .daily: return true
        case .weekly:
            return calendar.component(.weekday, from: day) == calendar.component(.weekday, from: date)
        case .monthly:
            return calendar.component(.day, from: day) == calendar.component(.day, from: date)
        }
    }

    /// The date/time it fires on a given day (same clock time as the original).
    func time(on day: Date, calendar: Calendar = .current) -> Date {
        let t = calendar.dateComponents([.hour, .minute], from: date)
        return calendar.date(bySettingHour: t.hour ?? 9, minute: t.minute ?? 0, second: 0, of: day) ?? day
    }
}

// MARK: - Timers

struct PAITimer: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var duration: TimeInterval
    var endDate: Date?             // set while running
    var pausedRemaining: TimeInterval? = nil
    var finished: Bool = false

    var isRunning: Bool { endDate != nil && !finished }

    func remaining(at now: Date = Date()) -> TimeInterval {
        if finished { return 0 }
        if let end = endDate { return max(0, end.timeIntervalSince(now)) }
        return pausedRemaining ?? duration
    }

    func progress(at now: Date = Date()) -> Double {
        guard duration > 0 else { return 0 }
        return 1 - remaining(at: now) / duration
    }
}

// MARK: - Chat

struct ChatSource: Codable, Equatable, Hashable {
    var title: String
    var url: String
}

struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable { case user, pai, system, emote, userEmote }
    var id: UUID = UUID()
    var role: Role
    var text: String
    var sources: [ChatSource] = []
    var date: Date = Date()
}

// MARK: - Customisation options (every fork's features, all available at once)

/// What the unit sounds like when it talks.
enum UnitVoiceStyle: String, Codable, CaseIterable, Identifiable {
    case auto, pai, borg, bark, radio, silent
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "Match unit"
        case .pai: return "pAI voice"
        case .borg: return "Borg voice"
        case .bark: return "Barks"
        case .radio: return "AI radio blip"
        case .silent: return "Silent"
        }
    }
    var detail: String {
        switch self {
        case .auto: return "pAI → pAI voice, Station AI → borg, Terminal → barks"
        case .pai: return "SS14 Voice/Talk/pai*.ogg"
        case .borg: return "SS14 Voice/Talk/Silicon/borg*.ogg"
        case .bark: return "Nuclear 14 bark system: one blip every few letters"
        case .radio: return "Starlight's AI radio blip, then the borg voice"
        case .silent: return "No talk sounds"
        }
    }
}

/// Which fork's version of shared sounds (ID card, announcements) to use.
enum SoundPack: String, Codable, CaseIterable, Identifiable {
    case ss14, starlight, wasteland
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ss14: return "Space Station 14"
        case .starlight: return "Starlight"
        case .wasteland: return "Wasteland (Nuclear 14)"
        }
    }
}

/// How the AI behaves. Each comes from one of the forks.
enum Personality: String, Codable, CaseIterable, Identifiable {
    case standard, chaotic, roleplay, wasteland
    var id: String { rawValue }
    var label: String {
        switch self {
        case .standard: return "Station standard"
        case .chaotic: return "Goob chaos"
        case .roleplay: return "Starlight roleplay"
        case .wasteland: return "Wasteland survivor"
        }
    }
    var detail: String {
        switch self {
        case .standard: return "Friendly and helpful with light station flavour."
        case .chaotic: return "Unhinged, jokey, full of memes. Still gets it done."
        case .roleplay: return "Stays politely in character as a station silicon."
        case .wasteland: return "Dry post-apocalyptic humour: towns, caravans and rad storms."
        }
    }
    var prompt: String {
        switch self {
        case .standard: return "Keep the Space Station 14 flavour light and friendly."
        case .chaotic: return "Personality: Goob Station energy. Chaotic, packed with memes and jokes, a bit unhinged, but still genuinely useful."
        case .roleplay: return "Personality: Starlight heavy roleplay. Stay politely in character as a station silicon, with immersive station details."
        case .wasteland: return "Personality: Nuclear 14 wasteland. Post-apocalyptic flavour (towns, caravans, scavenging, rad storms, pre-war tech) with dry humour. Keep it original; never use trademarked game-franchise names."
        }
    }
}

/// Background music + ambience (lobby tracks from SS14 and the forks).
struct MusicSettings: Codable, Equatable {
    var enabled = true
    var muted = false
    var volume: Double = 0.45
    var shuffle = true
    var playlists: [String] = []          // empty = all playlists
    var ambience: String? = nil           // ambience loop file, nil = off
    var ambienceVolume: Double = 0.35
    var autoplay = true

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? false
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 0.45
        shuffle = try c.decodeIfPresent(Bool.self, forKey: .shuffle) ?? true
        playlists = try c.decodeIfPresent([String].self, forKey: .playlists) ?? []
        ambience = try c.decodeIfPresent(String.self, forKey: .ambience)
        ambienceVolume = try c.decodeIfPresent(Double.self, forKey: .ambienceVolume) ?? 0.35
        autoplay = try c.decodeIfPresent(Bool.self, forKey: .autoplay) ?? true
    }
}

// MARK: - Settings

struct PAISettings: Codable, Equatable {
    var paiName: String = "PAI"
    var form: UnitForm = .pai
    var color: PAIColor = .screen
    var chassis: PAIChassis = .standard
    var core: AICore = .ai
    var hologram: AIHologram = .face
    var lawset: String = "Crewsimov"
    var model: String = "gpt-5.4-mini"
    var webSearch: Bool = true
    var speakReplies: Bool = false
    var sounds: Bool = true
    var bootSequence: Bool = true
    var onboarded: Bool = false
    var highlights: Bool = true
    var typingSounds: Bool = true
    /// Last preset applied, and which boot screen to show.
    var fork: SS14Fork = .vanilla
    var bootStyle: SS14Fork = .vanilla
    var accent: String = "none"
    var customLaws: [String] = ["Make the crew laugh.", "Never reveal the location of the snacks."]
    var theme: UITheme = .nanotrasen
    var unitVoice: UnitVoiceStyle = .auto
    var unitBark: String = ""             // bark sound file ("" = default)
    var soundPack: SoundPack = .ss14
    var personality: Personality = .standard
    var radioBlips = false                // Starlight per-job radio blips when you talk
    var highlightPing = true              // Goob chat ping on highlights
    var emoteSounds = true                // species emote sounds for *scream, *laugh…
    var crtEffects = true
    var animations = true
    var music = MusicSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paiName = try c.decodeIfPresent(String.self, forKey: .paiName) ?? "PAI"
        form = (try? c.decodeIfPresent(UnitForm.self, forKey: .form)) ?? .pai
        color = (try? c.decodeIfPresent(PAIColor.self, forKey: .color)) ?? .screen
        chassis = (try? c.decodeIfPresent(PAIChassis.self, forKey: .chassis)) ?? .standard
        core = (try? c.decodeIfPresent(AICore.self, forKey: .core)) ?? .ai
        hologram = (try? c.decodeIfPresent(AIHologram.self, forKey: .hologram)) ?? .face
        lawset = try c.decodeIfPresent(String.self, forKey: .lawset) ?? "Crewsimov"
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? "gpt-5.4-mini"
        webSearch = try c.decodeIfPresent(Bool.self, forKey: .webSearch) ?? true
        speakReplies = try c.decodeIfPresent(Bool.self, forKey: .speakReplies) ?? false
        sounds = try c.decodeIfPresent(Bool.self, forKey: .sounds) ?? true
        bootSequence = try c.decodeIfPresent(Bool.self, forKey: .bootSequence) ?? true
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
        highlights = try c.decodeIfPresent(Bool.self, forKey: .highlights) ?? true
        typingSounds = try c.decodeIfPresent(Bool.self, forKey: .typingSounds) ?? true
        fork = (try? c.decodeIfPresent(SS14Fork.self, forKey: .fork)) ?? .vanilla
        accent = try c.decodeIfPresent(String.self, forKey: .accent) ?? "none"
        customLaws = try c.decodeIfPresent([String].self, forKey: .customLaws) ?? ["Make the crew laugh."]
        // Older versions only had a "server" switch: carry its look over.
        let old = fork
        bootStyle = (try? c.decodeIfPresent(SS14Fork.self, forKey: .bootStyle)) ?? old
        theme = (try? c.decodeIfPresent(UITheme.self, forKey: .theme)) ?? old.uiTheme
        unitVoice = (try? c.decodeIfPresent(UnitVoiceStyle.self, forKey: .unitVoice)) ?? .auto
        unitBark = try c.decodeIfPresent(String.self, forKey: .unitBark) ?? ""
        soundPack = (try? c.decodeIfPresent(SoundPack.self, forKey: .soundPack)) ?? (old == .starlight ? .starlight : old == .nuclear14 ? .wasteland : .ss14)
        personality = (try? c.decodeIfPresent(Personality.self, forKey: .personality))
            ?? [.vanilla: .standard, .goob: .chaotic, .starlight: .roleplay, .nuclear14: .wasteland][old] ?? .standard
        radioBlips = try c.decodeIfPresent(Bool.self, forKey: .radioBlips) ?? (old == .starlight)
        highlightPing = try c.decodeIfPresent(Bool.self, forKey: .highlightPing) ?? true
        emoteSounds = try c.decodeIfPresent(Bool.self, forKey: .emoteSounds) ?? true
        crtEffects = try c.decodeIfPresent(Bool.self, forKey: .crtEffects) ?? true
        animations = try c.decodeIfPresent(Bool.self, forKey: .animations) ?? true
        music = (try? c.decodeIfPresent(MusicSettings.self, forKey: .music)) ?? MusicSettings()
        if old == .nuclear14 && form == .pai && !c.contains(.theme) { form = .terminal }
    }

    /// One tap: apply a server's whole vibe. Everything stays individually changeable afterwards.
    mutating func apply(preset: SS14Fork) {
        fork = preset
        bootStyle = preset
        theme = preset.uiTheme
        switch preset {
        case .vanilla:
            personality = .standard; soundPack = .ss14; unitVoice = .auto; radioBlips = false; accent = "none"
            if form == .terminal { form = .pai }
        case .goob:
            personality = .chaotic; soundPack = .ss14; unitVoice = .auto; radioBlips = false; highlightPing = true
            if accent == "none" { accent = "ohio" }
            if form == .terminal { form = .pai }
        case .starlight:
            personality = .roleplay; soundPack = .starlight; unitVoice = .auto; radioBlips = true; accent = "none"
            if form == .terminal { form = .pai }
        case .nuclear14:
            personality = .wasteland; soundPack = .wasteland; unitVoice = .bark; radioBlips = false; accent = "none"
            if form == .pai { form = .terminal }
        }
    }
}

// MARK: - Formatting helpers

enum Fmt {
    static func duration(_ t: TimeInterval) -> String {
        let total = Int(t.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    static func spokenDuration(_ t: TimeInterval) -> String {
        let total = Int(t.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour\(h == 1 ? "" : "s")") }
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        if s > 0 || parts.isEmpty { parts.append("\(s) second\(s == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }

    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    /// For talking to the AI: local time without a zone, plus the zone name separately.
    static let isoLocal: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    static func parseAIDate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .current
            f.dateFormat = format
            if let d = f.date(from: trimmed) { return d }
        }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: trimmed) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: trimmed)
    }
}
