import Foundation

/// An SS14 "ReplacementAccent": swaps whole words and sometimes adds a prefix/suffix,
/// applied to everything the unit says (like accents in-game).
struct SpeechAccent: Identifiable {
    let id: String
    let label: String
    let fork: String
    let sample: String
    let words: [(String, String)]
    let prefixes: [String]
    let suffixes: [String]

    static var all: [SpeechAccent] { AccentData.all }
    static func find(_ id: String) -> SpeechAccent? { all.first { $0.id == id } }

    private var table: [String: String] {
        var t: [String: String] = [:]
        for (a, b) in words where t[a.lowercased()] == nil { t[a.lowercased()] = b }
        return t
    }

    func apply(_ text: String) -> String {
        var out = replaceWords(in: text)
        if !prefixes.isEmpty, Double.random(in: 0..<1) < 0.25, let p = prefixes.randomElement() {
            out = p + " " + out
        }
        if !suffixes.isEmpty, Double.random(in: 0..<1) < 0.3, let s = suffixes.randomElement() {
            if s.hasPrefix(".") || s.hasPrefix(",") || s.hasPrefix("!") {
                while let last = out.last, ".!?".contains(last) { out.removeLast() }
            } else {
                out += " "
            }
            out += s
        }
        return out
    }

    private func replaceWords(in text: String) -> String {
        let t = table
        guard !t.isEmpty else { return text }
        let keys = t.keys.sorted { $0.count > $1.count }.map { NSRegularExpression.escapedPattern(for: $0) }
        let pattern = "(?<![\\w'])(" + keys.joined(separator: "|") + ")(?![\\w'])"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let ns = text as NSString
        var result = ""
        var last = 0
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let original = ns.substring(with: m.range)
            let replacement = t[original.lowercased()] ?? original
            result += Self.matchCase(replacement, like: original)
            last = m.range.location + m.range.length
        }
        result += ns.substring(from: last)
        return result
    }

    /// Keep SHOUTING and Capitalised words looking right after replacement.
    private static func matchCase(_ r: String, like o: String) -> String {
        if o.count > 1, o == o.uppercased(), o != o.lowercased() { return r.uppercased() }
        if let f = o.first, f.isUppercase { return r.prefix(1).uppercased() + r.dropFirst() }
        return r
    }
}

/// Nuclear 14's "barks": short sounds repeated while someone talks
/// (Content.Client/_NC/Barks/BarkSystem.cs: 0.05s per character, one bark every 0.15s, ±12.5% pitch).
enum Bark {
    static func play(_ text: String, sound: String, speed: Double = 1.0) {
        let total = Double(text.count) * 0.05
        let interval = 0.15 / speed
        let count = min(max(Int(total / interval), 1), 30)
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                SoundBoard.play(sound, volume: 0.45, rate: Float.random(in: 0.875...1.125))
            }
        }
    }
}
