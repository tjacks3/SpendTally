import Foundation

/// Defines how frequently a budget resets.
/// Stored as a raw String so SwiftData can persist it.
/// Conforms to Codable so SwiftData can save it as a property on Budget.
enum CycleType: String, Codable, CaseIterable, Identifiable {

    case daily   = "daily"
    case weekly  = "weekly"
    case monthly = "monthly"
    case custom  = "custom"

    // Identifiable lets us use CycleType directly in ForEach
    var id: String { rawValue }

    /// What the user sees in the UI
    var displayName: String {
        switch self {
        case .daily:   return "Daily"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .custom:  return "Custom"
        }
    }

    /// SF Symbol for each cycle type
    var icon: String {
        switch self {
        case .daily:   return "sun.max"
        case .weekly:  return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .custom:  return "slider.horizontal.3"
        }
    }

    /// The default cycle length in days (used as a starting point)
    var defaultLengthInDays: Int {
        switch self {
        case .daily:   return 1
        case .weekly:  return 7
        case .monthly: return 30   // approximate; real monthly uses Calendar
        case .custom:  return 14
        }
    }
}
