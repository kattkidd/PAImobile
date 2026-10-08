import WidgetKit
import SwiftUI

struct PAIEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot

    var upcoming: [WidgetReminder] { snapshot.reminders.filter { $0.date > date } }
    var running: [WidgetTimer] { snapshot.timers.filter { $0.endDate > date } }

    var mood: PAIMood {
        if let r = upcoming.first, r.date.timeIntervalSince(date) < 15 * 60 { return .alert }
        if !snapshot.hasBrain { return .off }
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 5 { return .sleepy }
        if !running.isEmpty { return .thinking }
        return .happy
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: date)
        let name = snapshot.userName
        return name.isEmpty ? Greeting.forHour(hour) : "\(Greeting.forHour(hour)), \(name)"
    }

    var title: String {
        if snapshot.form == .stationAI { return "\(snapshot.paiName) · AI" }
        return snapshot.userName.isEmpty ? snapshot.paiName : "\(snapshot.userName)'s pAI"
    }
}

struct PAIProvider: TimelineProvider {
    func placeholder(in context: Context) -> PAIEntry {
        PAIEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PAIEntry) -> Void) {
        completion(PAIEntry(date: Date(), snapshot: context.isPreview ? .sample : .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PAIEntry>) -> Void) {
        let snap = WidgetSnapshot.load()
        let now = Date()
        var dates: Set<Date> = [now]
        for r in snap.reminders where r.date > now {
            dates.insert(r.date.addingTimeInterval(1))
            let early = r.date.addingTimeInterval(-15 * 60)
            if early > now { dates.insert(early) }
        }
        for t in snap.timers where t.endDate > now { dates.insert(t.endDate.addingTimeInterval(1)) }
        for i in 1...8 { dates.insert(now.addingTimeInterval(Double(i) * 1800)) }
        if let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0),
                                                    matchingPolicy: .nextTime) {
            dates.insert(midnight)
        }
        let entries = dates.sorted().prefix(40).map { PAIEntry(date: $0, snapshot: snap) }
        completion(Timeline(entries: Array(entries), policy: .after(now.addingTimeInterval(4 * 3600))))
    }
}

struct PAIWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PAIEntry

    init(entry: PAIEntry) {
        self.entry = entry
        UITheme.current = entry.snapshot.theme
    }

    private var accent: Color { entry.snapshot.color }
    private var unit: some View {
        UnitView(form: entry.snapshot.form, mood: entry.mood, chassis: entry.snapshot.chassis,
                 core: entry.snapshot.core, date: entry.date)
    }

    var body: some View {
        content
            .font(SS14Font.body(12))
            .widgetURL(URL(string: "pai://home"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall: small.containerBackground(SS14Palette.windowBackground, for: .widget)
        case .systemMedium: medium.containerBackground(SS14Palette.windowBackground, for: .widget)
        case .systemLarge: large.containerBackground(SS14Palette.windowBackground, for: .widget)
        case .accessoryCircular: circular.containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .accessoryRectangular: rectangular.containerBackground(for: .widget) { Color.clear }
        case .accessoryInline: inline.containerBackground(for: .widget) { Color.clear }
        default: small.containerBackground(SS14Palette.windowBackground, for: .widget)
        }
    }

    /// SS14 window header strip.
    private func header(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: SS14Palette.theme.terminal ? "terminal.fill" : "circle.fill")
                .font(.system(size: 9))
                .foregroundStyle(SS14Palette.gold)
                .opacity(SS14Palette.theme.terminal ? 1 : 0)
                .frame(width: SS14Palette.theme.terminal ? 12 : 0)
            if !SS14Palette.theme.terminal {
                Image("nt_logo").renderingMode(.template).resizable().interpolation(.none)
                    .frame(width: 12, height: 12).foregroundStyle(SS14Palette.gold)
            }
            Text(text).font(SS14Font.display(11)).foregroundStyle(SS14Palette.text).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(SS14Palette.windowHeader)
        .overlay(alignment: .bottom) { Rectangle().fill(SS14Palette.gold.opacity(0.6)).frame(height: 1) }
    }

    // MARK: Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(entry.title)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 8) {
                    unit.frame(height: 58)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(entry.date, format: .dateTime.weekday(.abbreviated))
                            .font(SS14Font.display(13)).foregroundStyle(accent)
                        Text(entry.date, format: .dateTime.day())
                            .font(SS14Font.display(26)).foregroundStyle(SS14Palette.text)
                    }
                }
                Spacer(minLength: 0)
                if let t = entry.running.first {
                    line("timer", Text(timerInterval: entry.date...t.endDate, countsDown: true), accent)
                } else if let r = entry.upcoming.first {
                    Text(r.title).font(SS14Font.bold(12)).foregroundStyle(SS14Palette.text).lineLimit(1)
                    Text(r.date, style: .relative).font(SS14Font.mono(10)).foregroundStyle(SS14Palette.textDim)
                } else {
                    Text("All clear").font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
                }
            }
            .padding(10)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(entry.title)
            HStack(spacing: 12) {
                unit.frame(width: 76, height: 96)
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.greeting).font(SS14Font.bold(13)).foregroundStyle(SS14Palette.text).lineLimit(1)
                    Text(entry.date, format: .dateTime.weekday(.wide).month().day())
                        .font(SS14Font.mono(10)).foregroundStyle(SS14Palette.textDim)
                    NanoHeadingLine().stroke(SS14Palette.gold, lineWidth: 1).frame(height: 5)
                    ForEach(entry.running.prefix(1)) { t in
                        line("timer", Text(t.label) + Text("  ") + Text(timerInterval: entry.date...t.endDate, countsDown: true), accent)
                    }
                    ForEach(entry.upcoming.prefix(entry.running.isEmpty ? 3 : 2)) { r in
                        reminderLine(r)
                    }
                    if entry.upcoming.isEmpty && entry.running.isEmpty {
                        Text("No reminders. Tap to talk.").font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(10)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(entry.title)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    unit.frame(width: 96, height: 104)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.greeting).font(SS14Font.display(16)).foregroundStyle(SS14Palette.text)
                        Text(entry.date, format: .dateTime.weekday(.wide).month().day())
                            .font(SS14Font.mono(11)).foregroundStyle(SS14Palette.textDim)
                    }
                }
                if !entry.running.isEmpty {
                    sectionTitle("Timers")
                    ForEach(entry.running.prefix(2)) { t in
                        line("timer", Text(t.label) + Text("  ") + Text(timerInterval: entry.date...t.endDate, countsDown: true), accent)
                    }
                }
                sectionTitle("Upcoming")
                if entry.upcoming.isEmpty {
                    Text("Nothing scheduled.").font(SS14Font.body(13)).foregroundStyle(SS14Palette.textDim)
                }
                ForEach(entry.upcoming.prefix(entry.running.isEmpty ? 5 : 3)) { r in reminderLine(r) }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(SS14Font.bold(12)).foregroundStyle(SS14Palette.gold)
            NanoHeadingLine().stroke(SS14Palette.gold, lineWidth: 1).frame(height: 4)
        }
    }

    private func line(_ icon: String, _ text: Text, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            text.monospacedDigit().lineLimit(1)
        }
        .font(SS14Font.mono(12))
        .foregroundStyle(color)
    }

    private func reminderLine(_ r: WidgetReminder) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "bell.fill").foregroundStyle(accent)
            Text(r.title).foregroundStyle(SS14Palette.text).lineLimit(1)
            Spacer(minLength: 2)
            Text(timeLabel(r.date)).foregroundStyle(SS14Palette.textDim)
        }
        .font(SS14Font.body(12))
    }

    private func timeLabel(_ d: Date) -> String {
        if Calendar.current.isDate(d, inSameDayAs: entry.date) {
            return d.formatted(date: .omitted, time: .shortened)
        }
        return d.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    // MARK: Lock screen

    private var circular: some View {
        Group {
            if let t = entry.running.first {
                VStack(spacing: 0) {
                    Image(systemName: "timer").font(.caption2)
                    Text(timerInterval: entry.date...t.endDate, countsDown: true)
                        .font(SS14Font.mono(11))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                }
            } else {
                unit.padding(6)
            }
        }
    }

    private var rectangular: some View {
        HStack(spacing: 6) {
            unit.frame(width: 32)
            VStack(alignment: .leading, spacing: 1) {
                if let t = entry.running.first {
                    Text(t.label).font(SS14Font.bold(13)).lineLimit(1)
                    Text(timerInterval: entry.date...t.endDate, countsDown: true)
                        .font(SS14Font.mono(12)).monospacedDigit()
                } else if let r = entry.upcoming.first {
                    Text(r.title).font(SS14Font.bold(13)).lineLimit(1)
                    Text(timeLabel(r.date)).font(SS14Font.mono(11))
                } else {
                    Text(entry.snapshot.paiName).font(SS14Font.bold(13))
                    Text("All clear").font(SS14Font.mono(11))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var inline: some View {
        if let r = entry.upcoming.first {
            return Text("\(entry.snapshot.paiName): \(r.title) \(timeLabel(r.date))")
        }
        return Text("\(entry.snapshot.paiName): all clear")
    }
}

struct PAIWidget: Widget {
    let kind = "PAIWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PAIProvider()) { entry in
            PAIWidgetView(entry: entry)
        }
        .configurationDisplayName("PAI")
        .description("Your pAI or Station AI, next reminders and running timers.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct PAIWidgetBundle: WidgetBundle {
    var body: some Widget {
        PAIWidget()
    }
}
