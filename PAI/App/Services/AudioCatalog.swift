import Foundation
import AVFoundation
import SwiftUI

// Species voices, emote sounds, barks, lobby music and ambience from Space Station 14,
// Goob Station, Starlight and Nuclear 14 (GameData/Audio/audio.json). See CREDITS.md.

struct AudioManifest: Decodable {
    struct Speech: Decodable { let name: String; let source: String; let say: String; let ask: String; let exclaim: String }
    struct Emote: Decodable { let name: String; let message: String; let triggers: [String]; let category: String }
    struct SpeciesAudio: Decodable { let speech: String?; let emotes: [String: String]; let body: String? }
    struct Bark: Decodable, Identifiable { let name: String; let sound: String; let source: String; var id: String { sound } }
    struct Track: Decodable, Identifiable, Equatable {
        let title: String; let artist: String; let playlist: String; let file: String; let license: String; let source: String
        var id: String { file }
    }
    struct Ambience: Decodable, Identifiable { let name: String; let file: String; let license: String; var id: String { file } }

    let speech: [String: Speech]
    let emoteSets: [String: [String: [String]]]
    let emotes: [String: Emote]
    let species: [String: SpeciesAudio]
    let barks: [Bark]
    let music: [Track]
    let ambience: [Ambience]

    static let shared: AudioManifest = {
        guard let url = Bundle.main.url(forResource: "audio", withExtension: "json", subdirectory: "Audio")
                ?? Bundle.main.url(forResource: "audio", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode(AudioManifest.self, from: data) else {
            return AudioManifest(speech: [:], emoteSets: [:], emotes: [:], species: [:], barks: [], music: [], ambience: [])
        }
        return m
    }()

    init(speech: [String: Speech], emoteSets: [String: [String: [String]]], emotes: [String: Emote],
         species: [String: SpeciesAudio], barks: [Bark], music: [Track], ambience: [Ambience]) {
        self.speech = speech; self.emoteSets = emoteSets; self.emotes = emotes; self.species = species
        self.barks = barks; self.music = music; self.ambience = ambience
    }

    var playlists: [String] {
        var seen: [String] = []
        for t in music where !seen.contains(t.playlist) { seen.append(t.playlist) }
        return seen
    }

    /// Voices sorted for the picker.
    var voices: [(id: String, speech: Speech)] {
        speech.map { (id: $0.key, speech: $0.value) }.sorted { $0.speech.name < $1.speech.name }
    }

    /// Finds an emote from what you typed after "*" ("*laughs", "*scream").
    func emote(matching word: String) -> (id: String, emote: Emote)? {
        let w = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard !w.isEmpty else { return nil }
        for (id, e) in emotes where e.triggers.contains(w) { return (id: id, emote: e) }
        return nil
    }

    /// Sound files for an emote performed by a character of this species/sex.
    func emoteSounds(_ emote: String, species: String, sex: String) -> [String] {
        guard let sa = self.species[species] else { return emoteSets["UnisexSilicon"]?[emote] ?? [] }
        if let set = sa.emotes[sex] ?? sa.emotes["Unsexed"] ?? sa.emotes.values.first,
           let files = emoteSets[set]?[emote] { return files }
        if let body = sa.body, let files = emoteSets[body]?[emote] { return files }
        if let files = emoteSets["GeneralBodyEmotes"]?[emote] { return files }
        return []
    }

    /// Emotes this character can do (for the emote picker).
    func availableEmotes(species: String, sex: String) -> [(id: String, emote: Emote)] {
        emotes.filter { !emoteSounds($0.key, species: species, sex: sex).isEmpty }
            .map { (id: $0.key, emote: $0.value) }
            .sorted { $0.emote.name < $1.emote.name }
    }
}

// MARK: - Music (SS14 lobby music, fork jukeboxes)

/// Used from the main thread only.
final class MusicPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = MusicPlayer()

    @Published private(set) var current: AudioManifest.Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0
    private var player: AVAudioPlayer?
    private var ambience: AVAudioPlayer?
    private var history: [String] = []
    private var settings = MusicSettings()
    private var ticker: Timer?
    private var started = false

    var tracks: [AudioManifest.Track] {
        let all = AudioManifest.shared.music
        guard !settings.playlists.isEmpty else { return all }
        let f = all.filter { settings.playlists.contains($0.playlist) }
        return f.isEmpty ? all : f
    }

    /// Called whenever settings change.
    func apply(_ s: MusicSettings, soundsOn: Bool) {
        let old = settings
        settings = s
        SoundBoard.prepareSession()
        let audible = s.enabled && !s.muted && soundsOn
        player?.volume = audible ? Float(s.volume) : 0
        if !audible {
            if isPlaying { pause() }
        } else if !isPlaying {
            let unmuted = (old.muted && !s.muted) || (!old.enabled && s.enabled)
            if (!started && s.autoplay) || unmuted { play() }
        }
        started = true
        if old.playlists != s.playlists, let c = current, !tracks.contains(c) { next() }
        updateAmbience(audible: s.enabled && soundsOn && !s.muted)
    }

    func play() {
        guard settings.enabled, !settings.muted, SFX.enabled else { return }
        if let player, current != nil {
            player.play(); isPlaying = true; startTicker(); return
        }
        next()
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func toggle() { isPlaying ? pause() : play() }

    func next() {
        let list = tracks
        guard !list.isEmpty else { return }
        let pick: AudioManifest.Track
        if settings.shuffle {
            let fresh = list.filter { !history.suffix(max(0, list.count - 1)).contains($0.file) }
            pick = (fresh.isEmpty ? list : fresh).randomElement()!
        } else if let c = current, let i = list.firstIndex(of: c) {
            pick = list[(i + 1) % list.count]
        } else {
            pick = list[0]
        }
        start(pick)
    }

    func previous() {
        if let player, player.currentTime > 3 { player.currentTime = 0; return }
        if history.count >= 2 {
            history.removeLast()
            let prev = history.removeLast()
            if let t = AudioManifest.shared.music.first(where: { $0.file == prev }) { start(t); return }
        }
        player?.currentTime = 0
    }

    func start(_ track: AudioManifest.Track) {
        guard let url = Bundle.main.url(forResource: track.file, withExtension: "m4a", subdirectory: "Audio"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        SoundBoard.prepareSession()
        player?.stop()
        p.delegate = self
        p.volume = 0
        p.prepareToPlay()
        player = p
        current = track
        history.append(track.file)
        guard settings.enabled, !settings.muted else { isPlaying = false; return }
        p.play()
        p.setVolume(Float(settings.volume), fadeDuration: 1.2)   // lobby music fades in
        isPlaying = true
        startTicker()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let p = self.player, p.duration > 0 else { return }
            self.progress = p.currentTime / p.duration
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.next() }
    }

    private func updateAmbience(audible: Bool) {
        guard audible, let file = settings.ambience,
              let url = Bundle.main.url(forResource: file, withExtension: "m4a", subdirectory: "Audio") else {
            ambience?.setVolume(0, fadeDuration: 0.6)
            let a = ambience
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { a?.stop() }
            ambience = nil
            return
        }
        if let a = ambience, a.url == url {
            a.volume = Float(settings.ambienceVolume)
            return
        }
        ambience?.stop()
        guard let a = try? AVAudioPlayer(contentsOf: url) else { return }
        a.numberOfLoops = -1
        a.volume = 0
        a.play()
        a.setVolume(Float(settings.ambienceVolume), fadeDuration: 1.5)
        ambience = a
    }
}
