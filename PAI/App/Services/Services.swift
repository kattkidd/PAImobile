import Foundation
import Security
import UserNotifications
import AVFoundation
import UIKit

// MARK: - Keychain (API key is stored here, never in plain files)

enum Keychain {
    private static let service = "com.yourname.pai"

    static func set(_ value: String, for key: String) {
        delete(key)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Notifications (reminders + timers fire even when the app is closed)

enum Notifier {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func schedule(reminder: Reminder, paiName: String, userName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])

        let content = UNMutableNotificationContent()
        content.title = "\(paiName) · Reminder"
        let who = userName.isEmpty ? "" : "\(userName), "
        content.body = "\(who)you asked me to remind you: \(reminder.title)"
        if !reminder.notes.isEmpty { content.subtitle = reminder.notes }
        content.sound = UNNotificationSound(named: UNNotificationSoundName(ForkData.reminderSound))
        content.userInfo = ["route": "calendar"]

        let cal = Calendar.current
        let comps: DateComponents
        let repeats: Bool
        switch reminder.repeatRule {
        case .none:
            guard reminder.date > Date() else { return }
            comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            repeats = false
        case .daily:
            comps = cal.dateComponents([.hour, .minute], from: reminder.date)
            repeats = true
        case .weekly:
            comps = cal.dateComponents([.weekday, .hour, .minute], from: reminder.date)
            repeats = true
        case .monthly:
            comps = cal.dateComponents([.day, .hour, .minute], from: reminder.date)
            repeats = true
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        center.add(UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger))
    }

    static func schedule(timer: PAITimer, paiName: String, userName: String) {
        let id = "timer-\(timer.id.uuidString)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let end = timer.endDate, end > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(paiName) · Timer done"
        let who = userName.isEmpty ? "" : ", \(userName)"
        content.body = "Your \"\(timer.label)\" timer is finished\(who)."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("timer_done.caf"))  // SS14 microwave done
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["route": "timers"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel(reminderID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID.uuidString])
    }

    static func cancel(timerID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer-\(timerID.uuidString)"])
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - Voice

final class Voice {
    static let shared = Voice()
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let clean = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
        let utterance = AVSpeechUtterance(string: clean)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.15
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        synth.speak(utterance)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }
}

// MARK: - SS14 sounds (Resources/Audio, see CREDITS.md)

/// Every sound in the app comes from Space Station 14.
enum SFX: String, CaseIterable {
    // Talk (speech_sounds.yml): pAI = "Pai", Station AI = "Borg"
    case paiSay = "pai_say", paiAsk = "pai_ask", paiExclaim = "pai_exclaim"
    case borgSay = "borg_say", borgAsk = "borg_ask", borgExclaim = "borg_exclaim"
    // Silicon emotes (emote_sounds.yml "UnisexSilicon")
    case beep = "twobeep", chime = "chime", buzz = "buzz_sigh", buzzTwo = "buzz_two", ping = "ping"
    // Interface (Audio/UserInterface)
    case click = "click", hover = "hover"
    // Machines & items
    case button = "button"               // Machines/button.ogg
    case idSwipe = "id_swipe"            // Machines/id_swipe.ogg
    case idInsert = "id_insert"          // Machines/id_insert.ogg
    case discInsert = "disc_insert"      // Machines/terminal_insert_disc.ogg (law board upload)
    case timerStart = "timer_start"      // Machines/microwave_start_beep.ogg
    case timerDone = "timer_done"        // Machines/microwave_done_beep.ogg
    case ding = "ding"                   // Machines/ding.ogg
    case deny = "deny"                   // Machines/airlock_deny.ogg
    case printRip = "print_rip"          // Machines/short_print_and_rip.ogg
    case scanFinish = "scan_finish"      // Machines/scan_finish.ogg
    case stamp = "stamp"                 // Items/Stamp/thick_stamp_sub.ogg
    case pop = "pop"                     // Effects/pop.ogg
    case bootBeep = "boot_beep"          // Machines/beep.ogg
    case tick = "quickbeep"              // Machines/quickbeep.ogg
    // Announcements
    case announce = "announce", attention = "attention", welcome = "welcome", powerOn = "power_on"

    static var enabled = true
    static var typingEnabled = true
    /// Customisation (set by AppStore from settings).
    static var pack: SoundPack = .ss14
    static var unitVoice: UnitVoiceStyle = .auto
    static var unitBark = ""
    static var radioBlips = false
    static var emoteSounds = true

    func play(volume: Float? = nil) {
        SoundBoard.play(forkFile, volume: volume ?? defaultVolume)
    }

    /// The chosen sound pack can swap in a fork's own version of a sound.
    var forkFile: String {
        switch (SFX.pack, self) {
        case (.starlight, .idInsert): return "sl_id_pickup"     // Starlight id_card_pickup1.ogg
        case (.starlight, .idSwipe): return "sl_id_drop"        // Starlight id_card_drop1.ogg
        case (.starlight, .attention): return "sl_attention"    // Starlight Announcements/attention.ogg
        case (.starlight, .announce): return "sl_announce2"     // Starlight Announcements/announce2.ogg
        case (.wasteland, .announce): return "n14_bark_ring"
        default: return rawValue
        }
    }

    /// The unit talking: pAI/borg voice, Starlight's AI radio blip, or barks.
    static func unitSpeech(_ text: String, form: UnitForm) {
        var style = unitVoice
        if style == .auto { style = form == .terminal ? .bark : form == .stationAI ? .borg : .pai }
        switch style {
        case .silent: return
        case .bark: Bark.play(text, sound: unitBark.isEmpty ? "n14_bark_keytyped" : unitBark)
        case .radio:
            SoundBoard.play("sl_radio_ai", volume: 0.5)
            speech(for: text, form: .stationAI).play()
        case .borg: speech(for: text, form: .stationAI).play()
        default: speech(for: text, form: .pai).play()
        }
    }

    /// You talking: your character's voice, plus Starlight's per-job radio blip if switched on.
    static func userSend(_ text: String, character: CharacterProfile, jobID: String) {
        if radioBlips, let radio = ForkData.starlightRadio[jobID] { SoundBoard.play(radio, volume: 0.6) }
        userSpeech(for: text, voiceID: voiceID(for: character))
    }

    /// The character's voice: picked one, or the species' own speech sounds.
    static func voiceID(for c: CharacterProfile) -> String {
        if let v = c.voice, AudioManifest.shared.speech[v] != nil { return v }
        return AudioManifest.shared.species[c.species]?.speech ?? "Alto"
    }

    private var defaultVolume: Float {
        switch self {
        case .click, .hover, .tick, .button, .pop: return 0.45
        case .powerOn, .welcome: return 0.6
        default: return 0.8
        }
    }

    /// SS14 picks say/ask/exclaim by the last character of the message.
    static func speech(for text: String, form: UnitForm = .pai) -> SFX {
        let ai = form == .stationAI
        switch SS14.tone(of: text) {
        case .ask: return ai ? .borgAsk : .paiAsk
        case .exclaim: return ai ? .borgExclaim : .paiExclaim
        case .say: return ai ? .borgSay : .paiSay
        }
    }

    /// Your own voice when you send a message (SS14 plays the speaker's species voice).
    static func userSpeech(for text: String, voiceID: String) {
        guard let v = AudioManifest.shared.speech[voiceID] ?? AudioManifest.shared.speech["Alto"] else { return }
        let file: String
        switch SS14.tone(of: text) {
        case .ask: file = v.ask
        case .exclaim: file = v.exclaim
        case .say: file = v.say
        }
        SoundBoard.play(file, volume: 0.7)
    }

    /// Species emote sound (*scream, *laugh, *meow…). Returns false if this character can't make it.
    @discardableResult
    static func characterEmote(_ emoteID: String, character: CharacterProfile) -> Bool {
        let files = AudioManifest.shared.emoteSounds(emoteID, species: character.species, sex: character.sex)
        guard let f = files.randomElement() else { return false }
        if emoteSounds { SoundBoard.play(f, volume: 0.75, rate: Float.random(in: 0.94...1.06)) }   // SS14 variation 0.125
        return true
    }

    /// Computer keyboard clacks (Machines/Keyboard) while you type, throttled.
    private static var lastKey = Date.distantPast
    static func keystroke() {
        guard typingEnabled, Date().timeIntervalSince(lastKey) > 0.11 else { return }
        lastKey = Date()
        SoundBoard.play("keyboard\(Int.random(in: 1...4))", volume: 0.25)
    }

    /// Silicon emote → sound, used when the unit emotes ("PAI beeps.").
    static func emote(_ action: String) -> SFX? {
        let a = action.lowercased()
        if a.contains("buzzes twice") || a.contains("buzz-two") { return .buzzTwo }
        if a.contains("buzz") { return .buzz }
        if a.contains("chime") { return .chime }
        if a.contains("ping") { return .ping }
        if a.contains("beep") || a.contains("boop") { return .beep }
        return nil
    }
}

/// Plays bundled sounds (Sounds/*.caf, Audio/*.caf|m4a). Several players per sound so quick repeats overlap like in-game.
enum SoundBoard {
    private static var pools: [String: [AVAudioPlayer]] = [:]
    private static var sessionReady = false

    static func prepareSession() {
        guard !sessionReady else { return }
        // Ambient: mixes with other apps' audio and respects the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        sessionReady = true
    }

    static func url(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "caf")
            ?? Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Audio")
            ?? Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Audio")
    }

    static func play(_ name: String, volume: Float = 0.8, rate: Float = 1.0) {
        guard SFX.enabled else { return }
        prepareSession()
        var pool = pools[name] ?? []
        if let free = pool.first(where: { !$0.isPlaying }) {
            free.volume = volume
            free.rate = rate
            free.currentTime = 0
            free.play()
            return
        }
        guard pool.count < 3,
              let url = Self.url(for: name),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.volume = volume
        p.enableRate = true
        p.rate = rate
        p.prepareToPlay()
        pool.append(p)
        pools[name] = pool
        p.play()
    }
}

// MARK: - Haptics

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
