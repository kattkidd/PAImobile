import SwiftUI

// Text exactly like SS14's chat box: Noto Sans, bold speaker names,
// "Name says, “message”" wrapping (chat-manager.ftl), italic emotes,
// and keyword highlights in #17FFC1 (ChatUIController.Highlighting.cs).

/// Highlights your name and your job's keywords inside message text, like SS14's
/// "auto-fill highlights" option. Quoted entries ("Engi") only match whole words.
struct SS14Highlighter {
    struct Rule {
        let word: String
        let wholeWord: Bool
    }

    var rules: [Rule]
    var color: Color = Color(hex: SS14.highlightHex)
    var enabled = true

    @MainActor
    init(store: AppStore) {
        var rules: [Rule] = []
        let p = store.profile
        // Names: SS14 splits the character name into words (first/last for hyphenated names).
        var names = Set<String>()
        for source in [p.preferredName, p.fullName] {
            let parts = source.split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
            if parts.count > 2, source.contains("-") {
                names.insert(parts.first!)
                names.insert(parts.last!)
            } else {
                parts.forEach { names.insert($0) }
            }
        }
        for n in names where n.count > 1 { rules.append(Rule(word: n, wholeWord: true)) }
        // Job keywords from highlights.ftl
        for entry in SS14.jobHighlights[p.stationJob.lowercased()] ?? [] {
            let quoted = entry.hasPrefix("\"") && entry.hasSuffix("\"")
            let word = entry.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if !word.isEmpty { rules.append(Rule(word: word, wholeWord: quoted)) }
        }
        // Longest first, so "Security" wins over "Sec" (same as SS14).
        self.rules = rules.sorted { $0.word.count > $1.word.count }
        self.enabled = store.settings.highlights
    }

    /// True if any highlight word appears in the text (Goob plays a chat ping for these).
    func matches(_ text: String) -> Bool {
        guard enabled else { return false }
        var a = AttributedString(text)
        let before = a
        apply(to: &a)
        return a != before
    }

    func apply(to attr: inout AttributedString) {
        guard enabled, !rules.isEmpty else { return }
        let plain = String(attr.characters)
        let ns = plain as NSString
        var taken: [NSRange] = []
        for rule in rules {
            let escaped = NSRegularExpression.escapedPattern(for: rule.word)
            let pattern = rule.wholeWord ? "(?<![\\w])\(escaped)(?![\\w])" : escaped
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for m in re.matches(in: plain, range: NSRange(location: 0, length: ns.length)) {
                if taken.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) { continue }
                taken.append(m.range)
                guard let r = Range(m.range, in: plain) else { continue }
                let lo = plain.distance(from: plain.startIndex, to: r.lowerBound)
                let hi = plain.distance(from: plain.startIndex, to: r.upperBound)
                let a = attr.characters.index(attr.startIndex, offsetBy: lo)
                let b = attr.characters.index(attr.startIndex, offsetBy: hi)
                attr[a..<b].foregroundColor = color
            }
        }
    }
}

enum SS14Text {
    /// Markdown → AttributedString with Noto Sans bold/italic runs, then highlights.
    static func styled(_ text: String, size: CGFloat, highlighter: SS14Highlighter? = nil) -> AttributedString {
        var attr = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
        for run in attr.runs {
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.stronglyEmphasized) && intent.contains(.emphasized) {
                    attr[run.range].font = SS14Font.boldItalic(size)
                } else if intent.contains(.stronglyEmphasized) {
                    attr[run.range].font = SS14Font.bold(size)
                } else if intent.contains(.emphasized) {
                    attr[run.range].font = SS14Font.italic(size)
                }
            }
        }
        highlighter?.apply(to: &attr)
        return attr
    }

    /// chat-manager-entity-say-wrap-message:  [bold]Name[/bold] verb, “message”
    static func say(name: String, nameColor: Color, verb: String, body: AttributedString, size: CGFloat = 15) -> Text {
        Text(name).font(SS14Font.bold(size)).foregroundColor(nameColor)
        + Text(" \(verb), ").font(SS14Font.body(size)).foregroundColor(SS14Palette.text)
        + Text("“").font(SS14Font.body(size)).foregroundColor(SS14Palette.text)
        + Text(body).font(SS14Font.body(size)).foregroundColor(SS14Palette.text)
        + Text("”").font(SS14Font.body(size)).foregroundColor(SS14Palette.text)
    }

    /// chat-manager-entity-me-wrap-message:  [italic]Name action[/italic]
    static func emote(name: String, action: String, size: CGFloat = 15) -> Text {
        Text("\(name) \(action)").font(SS14Font.italic(size)).foregroundColor(SS14Palette.text)
    }
}

/// SS14's tooltip / speech box panel (Interface/Nano/tooltip.png, #37394E).
struct SS14TooltipBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 2).fill(Color(hex: "37394E").opacity(0.94)))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.black.opacity(0.35), lineWidth: 1))
    }
}

extension View {
    func ss14Tooltip() -> some View { modifier(SS14TooltipBox()) }
}

/// In-world speech bubble, like the ones over characters' heads in SS14.
struct SpeechBubbleView: View {
    let text: String
    var body: some View {
        Text(SS14Text.styled(text, size: 13))
            .font(SS14Font.body(13))
            .foregroundStyle(Color.white)
            .lineLimit(4)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 220, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .ss14Tooltip()
            .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
    }
}

/// Examine popup (shift-click in SS14): bold name header, then the description.
struct ExaminePopup: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let hl = SS14Highlighter(store: store)
        VStack(alignment: .center, spacing: 4) {
            Text(store.paiName)
                .font(SS14Font.bold(15))
                .foregroundStyle(Color.white)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(SS14Text.styled(line, size: 13, highlighter: hl))
                        .font(SS14Font.body(13))
                        .foregroundStyle(SS14Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: 290)
        .ss14Tooltip()
        .shadow(color: .black.opacity(0.6), radius: 8, y: 3)
    }

    private var lines: [String] {
        let s = store.settings
        let owner = store.userName
        var l: [String] = []
        if s.form == .stationAI {
            l.append(owner.isEmpty ? "This is the station's AI core." : "This is the AI core. It serves \(owner).")
            l.append("It is running the **\(store.activeLawset.name)** lawset.")
            l.append("Its display is set to \(s.core.label).")
        } else {
            l.append(owner.isEmpty ? "This is a \(s.chassis.label(s.form).lowercased()) device." : "This is \(store.ownerTitle).")
            l.append(s.chassis.flavor(s.form))
            // pai-system.ftl examine text
            l.append(store.hasAPIKey ? "A pAI is installed." : SS14.notInstalled)
        }
        if let next = store.nextReminder {
            l.append("Its screen shows a reminder: \(next.reminder.title).")
        }
        return l
    }
}
