import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject var store: AppStore
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var monthForward = true
    @State private var editing: Reminder?
    @State private var creating = false

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            SS14ScreenHeader(title: "Calendar", subtitle: "Shift schedule") {
                Button("Today") {
                    let today = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
                    monthForward = today > month
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        month = today
                        selected = cal.startOfDay(for: Date())
                    }
                }
                .buttonStyle(.ss14(.normal, compact: true))
                Button { creating = true } label: { Image(systemName: "plus") }
                    .buttonStyle(.ss14(.good, compact: true))
                    .accessibilityLabel("Add reminder")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    monthWindow
                    dayList
                }
                .padding(12)
            }
        }
        .background(SS14Palette.space.ignoresSafeArea())
        .sheet(isPresented: $creating) {
            ReminderEditor(reminder: Reminder(title: "", date: defaultTime(on: selected)), isNew: true)
        }
        .sheet(item: $editing) { r in
            ReminderEditor(reminder: r, isNew: false)
        }
    }

    // MARK: Month

    private var monthWindow: some View {
        SS14WindowChrome(title: Fmt.monthYear.string(from: month)) {
            VStack(spacing: 8) {
                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.ss14(.normal, compact: true))
                    Spacer()
                    Text(Fmt.monthYear.string(from: month))
                        .font(SS14Font.display(17))
                        .foregroundStyle(SS14Palette.gold)
                        .contentTransition(.opacity)
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.ss14(.normal, compact: true))
                }
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                        Text(s).font(SS14Font.mono(11)).foregroundStyle(SS14Palette.textDim)
                    }
                }
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 40)
                        }
                    }
                }
                .id(month)
                .transition(.asymmetric(
                    insertion: .move(edge: monthForward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: monthForward ? .leading : .trailing).combined(with: .opacity)))
                .clipped()
            }
            .padding(10)
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.width < -40 { shiftMonth(1) }
            if v.translation.width > 40 { shiftMonth(-1) }
        })
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let isToday = cal.isDateInToday(day)
        let items = store.reminders(on: day)
        let oneOffs = items.filter { $0.reminder.repeatRule == .none }.count
        let hasRepeat = items.contains { $0.reminder.repeatRule != .none }
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = day }
            SFX.hover.play()
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(isToday ? SS14Font.bold(15) : SS14Font.body(15))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? SS14Palette.gold : SS14Palette.text))
                HStack(spacing: 2) {
                    ForEach(0..<min(oneOffs, 3), id: \.self) { _ in
                        Rectangle().frame(width: 4, height: 4).foregroundStyle(store.accent)
                    }
                    if hasRepeat {
                        Rectangle().frame(width: 4, height: 4).foregroundStyle(SS14Palette.textDim.opacity(0.6))
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(ChamferShape(cut: 5).fill(isSelected ? SS14Palette.good : (isToday ? SS14Palette.itemRowSelected : SS14Palette.itemRow.opacity(0.5))))
            .overlay(ChamferShape(cut: 5).stroke(isToday && !isSelected ? SS14Palette.gold.opacity(0.7) : .clear, lineWidth: 1))
            .scaleEffect(isSelected ? 1.05 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: Day list

    private var dayList: some View {
        let items = store.reminders(on: selected)
        return SS14Section(title: Fmt.longDate.string(from: selected), trailing: items.isEmpty ? nil : "\(items.count) entries") {
            if items.isEmpty {
                SS14Row {
                    Text("Nothing scheduled. Tap + or ask \(store.paiName) to remind you.")
                        .font(SS14Font.body(13))
                        .foregroundStyle(SS14Palette.textDim)
                }
            }
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                Button { editing = item.reminder } label: {
                    ReminderRow(reminder: item.reminder, time: item.time, alternate: i % 2 == 1)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Edit") { editing = item.reminder }
                    Button("Delete", role: .destructive) {
                        withAnimation { store.deleteReminder(item.reminder.id) }
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .id(selected)
        .transition(.opacity)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.reminders)
    }

    // MARK: Helpers

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var days: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = cal.component(.weekday, from: month)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            if let date = cal.date(byAdding: .day, value: d - 1, to: month) { result.append(date) }
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private func shiftMonth(_ delta: Int) {
        guard let m = cal.date(byAdding: .month, value: delta, to: month) else { return }
        monthForward = delta > 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { month = m }
        SFX.click.play()
    }

    private func defaultTime(on day: Date) -> Date {
        if cal.isDateInToday(day) {
            let next = Date().addingTimeInterval(3600)
            return cal.date(bySetting: .minute, value: 0, of: next) ?? next
        }
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }
}

struct ReminderRow: View {
    @EnvironmentObject var store: AppStore
    let reminder: Reminder
    let time: Date
    var alternate = false

    var body: some View {
        let past = time < Date()
        SS14Row(alternate: alternate) {
            Text(Fmt.time.string(from: time))
                .font(SS14Font.mono(14, bold: true))
                .foregroundStyle(past ? SS14Palette.textDim : store.accent)
                .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(SS14Font.body(15))
                    .strikethrough(past && reminder.repeatRule == .none)
                    .foregroundStyle(past ? SS14Palette.textDim : SS14Palette.text)
                if !reminder.notes.isEmpty {
                    Text(reminder.notes).font(SS14Font.body(12)).foregroundStyle(SS14Palette.textDim)
                }
                if reminder.repeatRule != .none {
                    Label(reminder.repeatRule.label, systemImage: "repeat")
                        .font(SS14Font.mono(11)).foregroundStyle(SS14Palette.gold)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(SS14Palette.textDisabled)
        }
        .contentShape(Rectangle())
    }
}

struct ReminderEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var reminder: Reminder
    private let isNew: Bool

    init(reminder: Reminder, isNew: Bool) {
        self._reminder = State(initialValue: reminder)
        self.isNew = isNew
    }

    var body: some View {
        SS14WindowChrome(title: isNew ? "New reminder" : "Edit reminder",
                         trailing: AnyView(closeButton)) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SS14Section(title: "Reminder") {
                        SS14Row {
                            TextField("", text: $reminder.title,
                                      prompt: Text("What should I remind you about?").foregroundColor(SS14Palette.textDisabled))
                                .ss14Field()
                        }
                        SS14Row(alternate: true) {
                            Text("When").foregroundStyle(SS14Palette.textDim)
                            Spacer()
                            DatePicker("", selection: $reminder.date)
                                .labelsHidden()
                                .tint(SS14Palette.gold)
                        }
                        SS14Row {
                            Text("Repeat").foregroundStyle(SS14Palette.textDim)
                            Spacer()
                            Picker("Repeat", selection: $reminder.repeatRule) {
                                ForEach(RepeatRule.allCases) { Text($0.label).tag($0) }
                            }
                            .tint(SS14Palette.text)
                        }
                    }
                    SS14Section(title: "Notes") {
                        SS14Row {
                            TextField("", text: $reminder.notes,
                                      prompt: Text("Optional details").foregroundColor(SS14Palette.textDisabled),
                                      axis: .vertical)
                                .lineLimit(2...6)
                                .ss14Field()
                        }
                    }
                    HStack {
                        if !isNew {
                            Button("Delete") {
                                store.deleteReminder(reminder.id)
                                dismiss()
                            }
                            .buttonStyle(.ss14(.caution))
                        }
                        Spacer()
                        Button("Save") {
                            store.upsert(reminder)
                            Haptics.success()
                            store.flash(.happy)
                            dismiss()
                        }
                        .buttonStyle(.ss14(.good))
                        .disabled(reminder.title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(14)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .presentationDetents([.medium, .large])
        .presentationBackground(SS14Palette.windowBackground)
        .preferredColorScheme(.dark)
    }

    private var closeButton: some View {
        Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }
            .buttonStyle(.plain)
            .foregroundStyle(SS14Palette.textDim)
            .accessibilityLabel("Close")
    }
}
