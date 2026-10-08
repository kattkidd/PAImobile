import Foundation
import SwiftUI

// MARK: - Shared between the app and the home-screen widget

enum PAIShared {
    /// Must match the App Group in project.yml (both targets).
    static let appGroup = "group.com.yourname.pai"
    static let snapshotKey = "pai.widget.snapshot"

    /// Falls back to the app's own defaults if the App Group isn't available
    /// (e.g. some free sideloading setups). The widget then shows its basic view.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }
}

/// The pAI "screen" colour the user picks in Settings.
enum PAIColor: String, Codable, CaseIterable, Identifiable {
    case screen, green, cyan, amber, pink, purple, white

    var id: String { rawValue }

    /// `.screen` follows the unit's screen colour.
    func resolved(form: UnitForm, chassis: PAIChassis, core: AICore) -> Color {
        guard self == .screen else { return color }
        switch form {
        case .terminal: return Color(hex: "5CFF8F")
        case .stationAI: return core.screenColor
        case .pai: return chassis.screenColor
        }
    }

    var color: Color {
        switch self {
        case .screen: return PAIChassis.standard.screenColor
        case .green:  return Color(red: 0.30, green: 1.00, blue: 0.55)
        case .cyan:   return Color(red: 0.35, green: 0.90, blue: 1.00)
        case .amber:  return Color(red: 1.00, green: 0.72, blue: 0.25)
        case .pink:   return Color(red: 1.00, green: 0.45, blue: 0.75)
        case .purple: return Color(red: 0.72, green: 0.55, blue: 1.00)
        case .white:  return Color(red: 0.92, green: 0.95, blue: 0.95)
        }
    }

    var label: String { self == .screen ? "Match screen" : rawValue.capitalized }
}

struct WidgetReminder: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var date: Date
}

struct WidgetTimer: Codable, Hashable, Identifiable {
    var id: UUID
    var label: String
    var endDate: Date
}

/// Small summary the app writes for the widget to read.
struct WidgetSnapshot: Codable {
    var userName: String = ""
    var paiName: String = "PAI"
    var colorName: String = PAIColor.screen.rawValue
    var chassisName: String = PAIChassis.standard.rawValue
    var formName: String = UnitForm.pai.rawValue
    var coreName: String = AICore.ai.rawValue
    var forkName: String = SS14Fork.vanilla.rawValue
    var themeName: String = UITheme.nanotrasen.rawValue
    var hasBrain: Bool = true
    var reminders: [WidgetReminder] = []
    var timers: [WidgetTimer] = []

    var chassis: PAIChassis { PAIChassis(rawValue: chassisName) ?? .standard }
    var form: UnitForm { UnitForm(rawValue: formName) ?? .pai }
    var core: AICore { AICore(rawValue: coreName) ?? .ai }
    var fork: SS14Fork { SS14Fork(rawValue: forkName) ?? .vanilla }
    var theme: UITheme { UITheme(rawValue: themeName) ?? .nanotrasen }
    var color: Color { (PAIColor(rawValue: colorName) ?? .screen).resolved(form: form, chassis: chassis, core: core) }

    static func load() -> WidgetSnapshot {
        guard let data = PAIShared.defaults.data(forKey: PAIShared.snapshotKey),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snap
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            PAIShared.defaults.set(data, forKey: PAIShared.snapshotKey)
        }
    }

    static var sample: WidgetSnapshot {
        WidgetSnapshot(
            userName: "Alex",
            paiName: "PAI",
            colorName: PAIColor.screen.rawValue,
            chassisName: PAIChassis.standard.rawValue,
            formName: UnitForm.pai.rawValue,
            coreName: AICore.ai.rawValue,
            forkName: SS14Fork.vanilla.rawValue,
            themeName: UITheme.nanotrasen.rawValue,
            hasBrain: true,
            reminders: [WidgetReminder(id: UUID(), title: "Call the dentist", date: Date().addingTimeInterval(5400))],
            timers: [WidgetTimer(id: UUID(), label: "Pasta", endDate: Date().addingTimeInterval(420))]
        )
    }
}

enum Greeting {
    static func forHour(_ hour: Int) -> String {
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late shift"
        }
    }
}
