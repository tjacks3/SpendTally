import SwiftData
import SwiftUI
import Observation

// ============================================================
// FILE:   BudgetViewModel.swift
// LOCATION: SpendTally/ViewModels/BudgetViewModel.swift
//
// ACTION: REPLACE EXISTING FILE — full replacement.
//
// WHAT CHANGED:
//   • Added three new supporting enums:
//       WeeklyIntervalOption  – 7 days / 5 days / Custom
//       WeeklyStartDayOption  – Today / Monday / Custom
//       MonthlyResetDayOption – 1st / Custom
//
//   • Replaced the old single `newBudgetCustomDays` field with
//     per-cycle-type configuration state so the form can show
//     contextual options for each cycle type.
//
//   • `computedStartDate` — derives the Budget.startDate from
//     the current form selections. For monthly budgets, the day
//     component of startDate encodes the reset day (1–28); this
//     is how CycleManager determines the monthly reset boundary.
//
//   • `computedCycleLengthInDays` — derives cycleLengthInDays
//     from the current form selections. Not used by CycleManager
//     for monthly (it uses startDate's day instead), but stored
//     for informational use.
//
//   • Preview computed vars (previewFrequencyLabel,
//     previewCycleStart, previewCycleEnd, previewNextReset,
//     previewExactCycleDays) — drive the live preview card in
//     CreateBudgetView without touching SwiftData.
//
//   • `isRecurring` toggle state added.
//
//   • `createBudget` now uses the computed parameters.
// ============================================================

// MARK: - Supporting Types

/// The repeat interval offered under the "Weekly" cycle type.
enum WeeklyIntervalOption: String, CaseIterable, Identifiable {
    case sevenDays = "7 days"
    case fiveDays  = "5 days"
    case custom    = "Custom"

    var id: String { rawValue }

    /// Returns the concrete day count, or nil when the user supplies it.
    var fixedDays: Int? {
        switch self {
        case .sevenDays: return 7
        case .fiveDays:  return 5
        case .custom:    return nil
        }
    }
}

/// Which calendar day a weekly cycle should anchor to.
enum WeeklyStartDayOption: String, CaseIterable, Identifiable {
    case today  = "Today"
    case monday = "Monday"
    case custom = "Custom"

    var id: String { rawValue }
}

/// Which day of the month a monthly cycle resets on.
enum MonthlyResetDayOption: String, CaseIterable, Identifiable {
    case first  = "1st"
    case custom = "Custom"

    var id: String { rawValue }
}

// MARK: - BudgetViewModel

@Observable
final class BudgetViewModel {

    // MARK: - Core Form State

    var newBudgetName:      String    = ""
    var newBudgetAmount:    String    = ""
    var newBudgetCycleType: CycleType = .monthly
    var isRecurring:        Bool      = true

    // MARK: - Weekly Configuration

    var weeklyIntervalOption:  WeeklyIntervalOption  = .sevenDays
    /// User-supplied day count when weeklyIntervalOption == .custom.
    var weeklyCustomDays:      String                = "7"
    var weeklyStartDayOption:  WeeklyStartDayOption  = .today
    /// Used when weeklyStartDayOption == .custom.
    var weeklyCustomStartDate: Date                  = .now

    // MARK: - Monthly Configuration

    var monthlyResetDayOption: MonthlyResetDayOption = .first
    /// User-supplied reset day (1–28) when monthlyResetDayOption == .custom.
    var monthlyCustomResetDay: String                = "1"

    // MARK: - Custom Cycle Configuration

    var newBudgetCustomDays: String = "14"
    var customStartDate:     Date   = .now

    // MARK: - Validation

    var isFormValid: Bool {
        guard !newBudgetName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard (Double(newBudgetAmount) ?? 0) > 0 else { return false }

        switch newBudgetCycleType {
        case .daily:
            return true

        case .weekly:
            if weeklyIntervalOption == .custom {
                return (Int(weeklyCustomDays) ?? 0) > 0
            }
            return true

        case .monthly:
            if monthlyResetDayOption == .custom {
                let day = Int(monthlyCustomResetDay) ?? 0
                return day >= 1 && day <= 28
            }
            return true

        case .custom:
            return (Int(newBudgetCustomDays) ?? 0) > 0
        }
    }

    // MARK: - Computed Budget Parameters
    // These two properties are the single source of truth for what gets
    // written to the Budget model. All preview calculations use them too,
    // so the preview and the actual budget are always in sync.

    /// The start date that encodes all necessary cycle configuration.
    ///
    /// HOW EACH CYCLE TYPE USES THIS VALUE:
    ///
    ///   .daily   → start of today (CycleManager resets at each midnight)
    ///
    ///   .weekly  → the anchor date for interval math. CycleManager counts
    ///              days from startDate and snaps to the nearest cycle
    ///              boundary. The day component of startDate determines
    ///              which day of the week cycles start on.
    ///
    ///   .monthly → the day COMPONENT of startDate tells CycleManager
    ///              which day of each month to reset on. Year and month
    ///              are set to the most recent past occurrence of that day
    ///              so the current cycle is always active at creation time.
    ///
    ///   .custom  → same as weekly: the anchor date for interval math.
    var computedStartDate: Date {
        let calendar = Calendar.current

        switch newBudgetCycleType {

        case .daily:
            return calendar.startOfDay(for: .now)

        case .weekly:
            switch weeklyStartDayOption {
            case .today:
                return calendar.startOfDay(for: .now)
            case .monday:
                // nextOrCurrentWeekday returns TODAY if today is Monday,
                // otherwise the soonest upcoming Monday.
                return nextOrCurrentWeekday(2, from: .now)
            case .custom:
                return calendar.startOfDay(for: weeklyCustomStartDate)
            }

        case .monthly:
            // Determine the reset day (capped at 28 to be safe in all months).
            let day: Int
            switch monthlyResetDayOption {
            case .first:  day = 1
            case .custom: day = min(max(Int(monthlyCustomResetDay) ?? 1, 1), 28)
            }
            // Build a date whose day component IS the reset day.
            // Set it to the most recent past (or today) occurrence so
            // the budget is immediately in an active cycle.
            var comps = calendar.dateComponents([.year, .month], from: .now)
            comps.day = day
            if let candidate = calendar.date(from: comps), candidate > .now {
                // That day hasn't arrived yet this month — step back one month.
                comps.month! -= 1
                return calendar.date(from: comps) ?? calendar.startOfDay(for: .now)
            }
            return calendar.date(from: comps) ?? calendar.startOfDay(for: .now)

        case .custom:
            return calendar.startOfDay(for: customStartDate)
        }
    }

    /// The cycle length in days to store on the Budget model.
    ///
    /// For .monthly, CycleManager derives the cycle boundary from
    /// startDate's day component — not from this value. It's stored as 30
    /// for display purposes only.
    var computedCycleLengthInDays: Int {
        switch newBudgetCycleType {
        case .daily:  return 1
        case .weekly:
            switch weeklyIntervalOption {
            case .sevenDays: return 7
            case .fiveDays:  return 5
            case .custom:    return max(Int(weeklyCustomDays) ?? 7, 1)
            }
        case .monthly: return 30   // nominal; CycleManager uses startDate.day
        case .custom:  return max(Int(newBudgetCustomDays) ?? 14, 1)
        }
    }

    // MARK: - Preview Computed Properties
    // All preview values are derived from computedStartDate and
    // computedCycleLengthInDays via a transient (non-persisted) Budget
    // object. This guarantees the preview mirrors the real cycle
    // calculation — no separate preview math to keep in sync.

    /// Short sentence describing the reset cadence.
    var previewFrequencyLabel: String {
        switch newBudgetCycleType {
        case .daily:
            return "Resets every day at midnight"

        case .weekly:
            let days = computedCycleLengthInDays
            return days == 7
                ? "Resets every week (\(days) days)"
                : "Resets every \(days) days"

        case .monthly:
            switch monthlyResetDayOption {
            case .first:
                return "Resets on the 1st of each month"
            case .custom:
                let day = Int(monthlyCustomResetDay) ?? 1
                return "Resets on the \(ordinal(day)) of each month"
            }

        case .custom:
            let days = computedCycleLengthInDays
            return "Resets every \(days) day\(days == 1 ? "" : "s")"
        }
    }

    /// When the first / current cycle begins.
    var previewCycleStart: Date { computedStartDate }

    /// When the first / current cycle ends.
    var previewCycleEnd: Date {
        CycleManager.cycleEndDate(for: buildPreviewBudget(), startDate: computedStartDate)
    }

    /// The moment the budget resets (start of the second cycle).
    /// This is displayed as "Next reset" in the preview card.
    ///
    /// HOW IT'S CALCULATED:
    ///   previewCycleEnd is 23:59:59 on the last day of the first cycle.
    ///   Adding 1 second steps to 00:00:00 on the first day of the NEXT
    ///   cycle, which is the reset moment.
    var previewNextReset: Date {
        previewCycleEnd.addingTimeInterval(1)
    }

    /// Exact number of days in the first cycle (inclusive of both endpoints).
    ///
    ///   Example: Mar 1 00:00:00 → Mar 31 23:59:59
    ///   dateComponents(.day, from: start, to: end) = 30
    ///   Adding 1 gives 31 days — the correct inclusive count.
    var previewExactCycleDays: Int {
        let days = Calendar.current
            .dateComponents([.day], from: previewCycleStart, to: previewCycleEnd)
            .day ?? 0
        return days + 1
    }

    // MARK: - Actions

    func createBudget(context: ModelContext) {
        guard isFormValid, let amount = Double(newBudgetAmount) else { return }

        let budget = Budget(
            name: newBudgetName.trimmingCharacters(in: .whitespaces),
            totalAmount: amount,
            cycleType: newBudgetCycleType,
            cycleLengthInDays: computedCycleLengthInDays,
            startDate: computedStartDate,
            isRecurring: isRecurring
        )
        context.insert(budget)
        CycleEngine.ensureActiveCycleExists(for: budget, context: context)
        resetForm()
    }

    func deleteBudgets(
        at offsets: IndexSet,
        from budgets: [Budget],
        context: ModelContext
    ) {
        for index in offsets {
            context.delete(budgets[index])
        }
    }

    // MARK: - Private Helpers

    /// Builds a temporary Budget used only for preview calculations.
    /// This object is never inserted into SwiftData.
    private func buildPreviewBudget() -> Budget {
        Budget(
            name: newBudgetName,
            totalAmount: Double(newBudgetAmount) ?? 1,
            cycleType: newBudgetCycleType,
            cycleLengthInDays: computedCycleLengthInDays,
            startDate: computedStartDate,
            isRecurring: isRecurring
        )
    }

    /// Returns the date of the next (or current) occurrence of a given weekday.
    ///
    /// weekday follows Calendar convention: 1 = Sunday, 2 = Monday, … 7 = Saturday.
    /// If today IS the target weekday the function returns today (0 days added).
    private func nextOrCurrentWeekday(_ weekday: Int, from date: Date) -> Date {
        let calendar  = Calendar.current
        let today     = calendar.startOfDay(for: date)
        let current   = calendar.component(.weekday, from: today)
        let daysAway  = (weekday - current + 7) % 7
        return calendar.date(byAdding: .day, value: daysAway, to: today) ?? today
    }

    /// Returns an English ordinal suffix: 1 → "1st", 2 → "2nd", etc.
    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 10 {
        case 1 where n % 100 != 11: suffix = "st"
        case 2 where n % 100 != 12: suffix = "nd"
        case 3 where n % 100 != 13: suffix = "rd"
        default:                    suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    private func resetForm() {
        newBudgetName         = ""
        newBudgetAmount       = ""
        newBudgetCycleType    = .monthly
        isRecurring           = true

        weeklyIntervalOption  = .sevenDays
        weeklyCustomDays      = "7"
        weeklyStartDayOption  = .today
        weeklyCustomStartDate = .now

        monthlyResetDayOption = .first
        monthlyCustomResetDay = "1"

        newBudgetCustomDays   = "14"
        customStartDate       = .now
    }
}
