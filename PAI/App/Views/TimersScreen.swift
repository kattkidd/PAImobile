import SwiftUI

struct TimersScreen: View {
    @EnvironmentObject var store: AppStore
    @State private var mode = 0
    @State private var showCustom = false

    private let presets: [(String, TimeInterval)] = [
        ("1m", 60), ("3m", 180), ("5m", 300), ("10m", 600),
        ("15m", 900), ("20m", 1200), ("30m", 1800), ("1h", 3600),
    ]

    var body: some View {
        VStack(spacing: 0) {
            SS14ScreenHeader(title: mode == 0 ? "Timers" : "Stopwatch", subtitle: "Chronometer module")
            HStack(spacing: 4) {
                modeButton("Timers", 0, first: true)
                modeButton("Stopwatch", 1, first: false)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            ScrollView {
                ZStack {
                    if mode == 0 {
                        timersBody.transition(.move(edge: .leading).combined(with: .opacity))
                    } else {
                        StopwatchView().transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(12)
            }
        }
        .background(SS14Palette.space.ignoresSafeArea())
        .sheet(isPresented: $showCustom) { CustomTimerSheet() }
    }

    private func modeButton(_ title: String, _ value: Int, first: Bool) -> some View {
        Button(title) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { mode = value }
        }
        .buttonStyle(SS14ButtonStyle(kind: .normal, selected: mode == value))
        .frame(maxWidth: .infinity)
    }

    private var timersBody: some View {
        VStack(spacing: 16) {
            SS14Section(title: "Quick start") {
                VStack(spacing: 8) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    _ = store.startTimer(seconds: preset.1, label: "")
                                }
                                Haptics.success()
                            } label: {
                                Text(preset.0).font(SS14Font.mono(16, bold: true)).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.ss14(.normal))
                        }
                    }
                    Button {
                        showCustom = true
                    } label: {
                        Label("Custom timer…", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ss14(.ghost))
                }
                .padding(10)
            }

            if store.timers.isEmpty {
                Text("No timers running. Tap a preset, or tell \(store.paiName) \"set a timer for 12 minutes\".")
                    .font(SS14Font.body(13))
                    .foregroundStyle(SS14Palette.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                NanoHeading(title: "Active", trailing: "\(store.timers.filter { $0.isRunning }.count) running")
                TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                    VStack(spacing: 10) {
                        ForEach(store.timers) { timer in
                            TimerCard(timer: timer, now: ctx.date)
                                .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity),
                                                        removal: .move(edge: .trailing).combined(with: .opacity)))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.timers.map(\.id))
                }
            }
        }
    }
}

struct TimerCard: View {
    @EnvironmentObject var store: AppStore
    let timer: PAITimer
    let now: Date

    var body: some View {
        SS14WindowChrome(title: timer.label, alert: timer.finished) {
            HStack(spacing: 14) {
                ZStack {
                    Rectangle().stroke(SS14Palette.lineEditBorder, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: timer.progress(at: now))
                        .stroke(timer.finished ? SS14Palette.caution : store.accent,
                                style: StrokeStyle(lineWidth: 5, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .padding(6)
                        .animation(.linear(duration: 0.5), value: timer.progress(at: now))
                    Image(systemName: timer.finished ? "bell.fill" : (timer.isRunning ? "hourglass" : "pause.fill"))
                        .foregroundStyle(timer.finished ? SS14Palette.caution : store.accent)
                        .symbolEffect(.pulse, isActive: timer.finished)
                }
                .frame(width: 54, height: 54)

                Text(timer.finished ? "DONE" : Fmt.duration(timer.remaining(at: now)))
                    .font(SS14Font.mono(30, bold: true))
                    .foregroundStyle(timer.finished ? Color(hex: "FF6B6B") : SS14Palette.text)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Spacer()
                HStack(spacing: 6) {
                    if timer.finished {
                        small("arrow.counterclockwise", .good) { store.restartTimer(timer.id) }
                    } else if timer.isRunning {
                        small("pause.fill", .normal) { store.pauseTimer(timer.id) }
                    } else {
                        small("play.fill", .good) { store.resumeTimer(timer.id) }
                    }
                    small("xmark", .caution) {
                        withAnimation { store.deleteTimer(timer.id) }
                    }
                }
            }
            .padding(10)
        }
    }

    private func small(_ icon: String, _ kind: SS14ButtonKind, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() }
            Haptics.tap()
        } label: {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).frame(width: 20, height: 20)
        }
        .buttonStyle(.ss14(kind, compact: true))
    }
}

struct CustomTimerSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var label = ""

    var body: some View {
        SS14WindowChrome(title: "Custom timer") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    wheel($hours, 0..<24, "h")
                    wheel($minutes, 0..<60, "m")
                    wheel($seconds, 0..<60, "s")
                }
                .frame(height: 150)
                .background(SS14Palette.panelDark)
                TextField("", text: $label, prompt: Text("Label, e.g. Laundry").foregroundColor(SS14Palette.textDisabled))
                    .ss14Field()
                HStack {
                    Button("Cancel") { dismiss() }.buttonStyle(.ss14(.normal))
                    Spacer()
                    Button("Start") {
                        _ = store.startTimer(seconds: TimeInterval(hours * 3600 + minutes * 60 + seconds), label: label)
                        Haptics.success()
                        dismiss()
                    }
                    .buttonStyle(.ss14(.good))
                    .disabled(hours + minutes + seconds == 0)
                }
            }
            .padding(14)
        }
        .presentationDetents([.medium])
        .presentationBackground(SS14Palette.windowBackground)
        .preferredColorScheme(.dark)
    }

    private func wheel(_ value: Binding<Int>, _ range: Range<Int>, _ unit: String) -> some View {
        Picker(unit, selection: value) {
            ForEach(range, id: \.self) {
                Text("\($0) \(unit)").font(SS14Font.mono(18)).foregroundStyle(SS14Palette.text).tag($0)
            }
        }
        .pickerStyle(.wheel)
        .onChange(of: value.wrappedValue) { _, _ in SFX.hover.play() }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

struct StopwatchView: View {
    @EnvironmentObject var store: AppStore
    @State private var startDate: Date?
    @State private var accumulated: TimeInterval = 0
    @State private var laps: [TimeInterval] = []

    private func elapsed(_ now: Date) -> TimeInterval {
        accumulated + (startDate.map { now.timeIntervalSince($0) } ?? 0)
    }

    var body: some View {
        VStack(spacing: 16) {
            SS14WindowChrome(title: "Chronometer") {
                TimelineView(.periodic(from: .now, by: 0.05)) { ctx in
                    Text(format(elapsed(ctx.date)))
                        .font(SS14Font.mono(50, bold: true))
                        .foregroundStyle(store.accent)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .shadow(color: store.accent.opacity(startDate == nil ? 0 : 0.5), radius: 8)
                }
            }

            HStack(spacing: 10) {
                Button(startDate == nil ? (accumulated == 0 ? "Start" : "Resume") : "Stop") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if let s = startDate {
                            accumulated += Date().timeIntervalSince(s)
                            startDate = nil
                        } else {
                            startDate = Date()
                        }
                    }
                }
                .buttonStyle(.ss14(startDate == nil ? .good : .caution))
                .frame(maxWidth: .infinity)

                Button(startDate == nil ? "Reset" : "Lap") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if startDate == nil {
                            accumulated = 0
                            laps = []
                        } else {
                            laps.insert(elapsed(Date()), at: 0)
                        }
                    }
                }
                .buttonStyle(.ss14(.normal))
                .frame(maxWidth: .infinity)
                .disabled(startDate == nil && accumulated == 0)
            }

            if !laps.isEmpty {
                SS14Section(title: "Laps") {
                    ForEach(Array(laps.enumerated()), id: \.offset) { i, lap in
                        SS14Row(alternate: i % 2 == 1) {
                            Text("Lap \(laps.count - i)").foregroundStyle(SS14Palette.textDim)
                            Spacer()
                            Text(format(lap)).font(SS14Font.mono(15)).monospacedDigit()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let cs = Int((t * 100).rounded(.down))
        let m = cs / 6000, s = (cs % 6000) / 100, c = cs % 100
        return String(format: "%02d:%02d.%02d", m, s, c)
    }
}
