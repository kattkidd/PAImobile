import SwiftUI
import UserNotifications

@main
struct PAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

/// Lets notifications show as banners even while the app is open,
/// and routes notification taps to the right tab.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var pendingRoute: String?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let route = response.notification.request.content.userInfo["route"] as? String {
            AppDelegate.pendingRoute = route
            NotificationCenter.default.post(name: .paiRoute, object: route)
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let paiRoute = Notification.Name("paiRoute")
}

enum AppTab: Int, Hashable, CaseIterable { case pai, calendar, timers, id, settings }

/// Boot sequence → onboarding (first run) → main app. Each step hands over with a CRT transition.
struct RootView: View {
    @EnvironmentObject var store: AppStore
    @State private var phase: Phase = .boot

    enum Phase { case boot, onboarding, main }

    var body: some View {
        ZStack {
            SS14Palette.space.ignoresSafeArea()

            switch phase {
            case .boot:
                BootView {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        phase = store.settings.onboarded ? .main : .onboarding
                    }
                }
                .transition(.opacity)
            case .onboarding:
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.6)) { phase = .main }
                }
                .transition(.crt)
            case .main:
                MainShell()
                    .id(store.settings.theme)     // rebuild every screen in the new theme
                    .transition(.crt)
            }

            if let target = store.connecting {
                ConnectOverlay(target: target)
                    .transition(.opacity)
                    .zIndex(11)
            }

            if store.transferring {
                TransferOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }

            if store.settings.crtEffects { ScanlineOverlay() }
        }
        .font(SS14Font.body(15))          // every piece of text defaults to Noto Sans
        .foregroundStyle(SS14Palette.text)
        .animation(.easeInOut(duration: 0.3), value: store.transferring)
        .animation(.easeInOut(duration: 0.3), value: store.connecting)
        .onAppear {
            if !store.settings.bootSequence {
                phase = store.settings.onboarded ? .main : .onboarding
            }
            store.startMusic()       // SS14 lobby music
        }
    }
}

/// The app's main screen: SS14 menu bar + tabs with direction-aware transitions.
struct MainShell: View {
    @EnvironmentObject var store: AppStore
    @State private var tab: AppTab = .pai
    @State private var forward = true
    @State private var sweep = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SS14Palette.space.ignoresSafeArea()
            Group {
                switch tab {
                case .pai: HomeView(tab: tabBinding)
                case .calendar: CalendarScreen()
                case .timers: TimersScreen()
                case .id: IDScreen()
                case .settings: SettingsScreen()
                }
            }
            .id(tab)
            .transition(.screen(forward: forward))
            if store.settings.crtEffects { ScanSweep(trigger: sweep, color: store.accent) }
            PopupLayer(popups: store.popups)
                .frame(maxHeight: .infinity, alignment: .center)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.popups)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SS14MenuBar(selection: tabBinding, unitLabel: store.settings.form.short)
        }
        .tint(store.accent)
        .onReceive(ticker) { store.tick($0) }
        .onReceive(NotificationCenter.default.publisher(for: .paiRoute)) { note in
            if let name = note.object as? String { route(to: name) }
        }
        .onOpenURL { url in route(to: url.host ?? "") }
        .task {
            _ = await Notifier.requestAuthorization()
            if let pending = AppDelegate.pendingRoute {
                route(to: pending)
                AppDelegate.pendingRoute = nil
            }
        }
    }

    /// Changing tabs animates in the direction you moved.
    private var tabBinding: Binding<AppTab> {
        Binding(get: { tab }, set: { new in
            guard new != tab else { return }
            forward = new.rawValue > tab.rawValue
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { tab = new }
            sweep += 1
        })
    }

    private func route(to name: String) {
        let target: AppTab
        switch name {
        case "calendar": target = .calendar
        case "timers": target = .timers
        case "id": target = .id
        case "settings": target = .settings
        default: target = .pai
        }
        tabBinding.wrappedValue = target
    }
}

/// "Transferring consciousness" between pAI and Station AI.
struct TransferOverlay: View {
    @EnvironmentObject var store: AppStore
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            SS14WindowChrome(title: "Intellicard transfer", alert: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 18) {
                        UnitView(form: store.settings.form == .stationAI ? .pai : store.settings.form, mood: .thinking,
                                 chassis: store.settings.chassis, core: store.settings.core).frame(height: 70)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(SS14Palette.gold)
                        AICoreView(mood: .thinking, core: store.settings.core).frame(height: 70)
                    }
                    .frame(maxWidth: .infinity)
                    Text("Transferring consciousness…")
                        .font(SS14Font.mono(13))
                        .foregroundStyle(SS14Palette.radioBinary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(SS14Palette.lineEdit)
                            Rectangle().fill(SS14Palette.good).frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 10)
                    .overlay(Rectangle().stroke(SS14Palette.lineEditBorder))
                }
                .padding(14)
            }
            .frame(maxWidth: 320)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.7)) { progress = 1 }
        }
    }
}
