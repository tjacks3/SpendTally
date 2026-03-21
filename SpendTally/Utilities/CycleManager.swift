import Foundation
import SwiftData

/// All date-math and cycle-lifecycle logic lives here.
///
/// CycleManager is a struct with only static methods — you never
/// need to create an instance of it. Just call CycleManager.method().
///
/// DESIGN PRINCIPLE: The UI should never do date math. Views and
/// ViewModels call CycleManager and get back the cycle they need.
struct CycleManager {

    // MARK: - Public API

    /// Returns the existing active cycle for `budget`, or creates a new one.
    ///
    /// This is the primary entry point for the UI. Call it whenever you need
    /// to display or add to the current cycle:
    ///
    ///     let cycle = CycleManager.getOrCreateCurrentCycle(for: budget, context: context)
    ///
    @discardableResult
    static func getOrCreateCurrentCycle(
        for budget: Budget,
        context: ModelContext
    ) -> BudgetCycle {
        let now = Date.now

        // Check if a valid active cycle already exists
        if let existing = budget.cycles.first(where: { $0.isActive }) {
            return existing
        }

        // No active cycle — create one for the current period
        let start = cycleStartDate(for: budget, containing: now)
        let end   = cycleEndDate(for: budget, startDate: start)

        let cycle = BudgetCycle(budget: budget, startDate: start, endDate: end)
        cycle.budget = budget
        budget.cycles.append(cycle)
        context.insert(cycle)

        return cycle
    }

    /// Finds which cycle a specific date belongs to, without creating one.
    static func findCycle(for budget: Budget, on date: Date) -> BudgetCycle? {
        budget.cycles.first { $0.startDate <= date && date <= $0.endDate }
    }

    /// Returns cycles sorted by start date, newest first.
    static func historicalCycles(for budget: Budget) -> [BudgetCycle] {
        budget.cycles
            .filter { !$0.isActive }
            .sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Cycle Date Calculation

    /// Calculates where the cycle containing `date` starts.
    ///
    /// All four cycle types align to the budget's `startDate` so cycles
    /// don't float — a weekly budget that started on a Wednesday will
    /// always run Wednesday–Tuesday, forever.
    static func cycleStartDate(for budget: Budget, containing date: Date) -> Date {
        let calendar = Calendar.current

        switch budget.cycleType {

        // ── Daily ─────────────────────────────────────────────────────────
        // Resets every midnight. The "start" is always 00:00:00 of `date`.
        case .daily:
            return calendar.startOfDay(for: date)

        // ── Weekly ────────────────────────────────────────────────────────
        // Resets every 7 days from the budget's start date.
        // Example: started Monday Mar 10 → always Mon–Sun.
        case .weekly:
            let budgetStart = calendar.startOfDay(for: budget.startDate)
            let targetDay   = calendar.startOfDay(for: date)
            let daysDiff    = calendar.dateComponents([.day],
                                                      from: budgetStart,
                                                      to: targetDay).day ?? 0
            // modulo 7, handling negative values (dates before budget start)
            let daysIntoCycle = ((daysDiff % 7) + 7) % 7
            return calendar.date(byAdding: .day,
                                  value: -daysIntoCycle,
                                  to: targetDay)!

        // ── Monthly ───────────────────────────────────────────────────────
        // Resets on the 1st of each calendar month.
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: comps)!

        // ── Custom ────────────────────────────────────────────────────────
        // Resets every N days from the budget's start date.
        // Example: 14-day cycle starting Mar 1 → Mar 1–14, Mar 15–28, etc.
        case .custom:
            let len         = max(budget.cycleLengthInDays, 1)
            let budgetStart = calendar.startOfDay(for: budget.startDate)
            let targetDay   = calendar.startOfDay(for: date)
            let daysDiff    = calendar.dateComponents([.day],
                                                      from: budgetStart,
                                                      to: targetDay).day ?? 0

            // If `date` is before the budget started, the budget start IS the start
            if daysDiff < 0 { return budgetStart }

            let cycleNumber = daysDiff / len
            return calendar.date(byAdding: .day,
                                  value: cycleNumber * len,
                                  to: budgetStart)!
        }
    }

    /// Calculates the last moment of the cycle that starts on `startDate`.
    static func cycleEndDate(for budget: Budget, startDate: Date) -> Date {
        let calendar = Calendar.current

        switch budget.cycleType {

        case .daily:
            // End of the same day: 23:59:59
            return endOfDay(startDate, calendar: calendar)

        case .weekly:
            // 6 days later at 23:59:59 (so cycle is 7 days total)
            let lastDay = calendar.date(byAdding: .day, value: 6, to: startDate)!
            return endOfDay(lastDay, calendar: calendar)

        case .monthly:
            // Last second before the next month starts
            var comps = calendar.dateComponents([.year, .month], from: startDate)
            comps.month! += 1
            let nextMonth = calendar.date(from: comps)!
            return nextMonth.addingTimeInterval(-1)

        case .custom:
            let len     = max(budget.cycleLengthInDays, 1)
            let lastDay = calendar.date(byAdding: .day, value: len - 1, to: startDate)!
            return endOfDay(lastDay, calendar: calendar)
        }
    }

    // MARK: - Private Helpers

    /// Returns 23:59:59 on the given date.
    private static func endOfDay(_ date: Date, calendar: Calendar) -> Date {
        var comps        = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour       = 23
        comps.minute     = 59
        comps.second     = 59
        return calendar.date(from: comps) ?? date
    }
}
