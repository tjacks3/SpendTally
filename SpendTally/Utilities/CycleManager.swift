import Foundation
import SwiftData

// ============================================================
// FILE:   CycleManager.swift
// LOCATION: SpendTally/Utilities/CycleManager.swift
//
// ACTION: REPLACE EXISTING FILE — full replacement.
//
// WHAT CHANGED:
//   .weekly  cycleStartDate — now reads `budget.cycleLengthInDays`
//            instead of the hardcoded constant 7. Existing weekly
//            budgets are unaffected (their cycleLengthInDays is 7).
//
//   .weekly  cycleEndDate   — same: `cycleLengthInDays - 1` replaces
//            the hardcoded offset of 6.
//
//   .monthly cycleStartDate — now reads the DAY COMPONENT of
//            `budget.startDate` to determine which calendar day each
//            month the cycle resets on (capped at 28 to be valid in
//            all months including February).
//            Previously always returned the 1st of the month.
//
//   .monthly cycleEndDate   — returns one second before the same
//            reset day in the following month, consistent with the
//            new startDate encoding.
//
// BACKWARD COMPATIBILITY:
//   Existing monthly budgets whose startDate falls on the 1st of a
//   month are unaffected (day component = 1 → resets on the 1st).
//   Budgets with an arbitrary startDate will now reset on that day
//   of the month — which is usually what the user intended when they
//   created the budget on that date.
//
//   Existing weekly budgets with cycleLengthInDays = 7 are
//   numerically identical to the old hardcoded behaviour.
// ============================================================

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

        // Check if a valid active cycle already exists.
        if let existing = budget.cycles.first(where: { $0.isActive }) {
            return existing
        }

        // No active cycle — create one for the current period.
        let start = cycleStartDate(for: budget, containing: now)
        let end   = cycleEndDate(for: budget, startDate: start)

        let cycle        = BudgetCycle(budget: budget, startDate: start, endDate: end)
        cycle.budget     = budget
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
    /// All cycle types anchor to `budget.startDate` so cycle boundaries
    /// never drift. A weekly budget that started on a Wednesday always
    /// runs Wednesday–Tuesday, forever.
    ///
    /// Monthly budgets use the DAY COMPONENT of `budget.startDate` to
    /// determine the reset day (e.g. startDate on March 15 → resets on
    /// the 15th of every month). The year/month components are not used
    /// for the monthly calculation — only the day number.
    static func cycleStartDate(for budget: Budget, containing date: Date) -> Date {
        let calendar = Calendar.current

        switch budget.cycleType {

        // ── Daily ─────────────────────────────────────────────────────────
        // Resets every midnight. The "start" is always 00:00:00 of `date`.
        case .daily:
            return calendar.startOfDay(for: date)

        // ── Weekly ────────────────────────────────────────────────────────
        // UPDATED: uses budget.cycleLengthInDays instead of hardcoded 7.
        // Resets every N days from the budget's start date.
        // Example: started Monday Mar 10, N=5 → Mon Mar 10, Sat Mar 15, …
        case .weekly:
            let len         = max(budget.cycleLengthInDays, 1)
            let budgetStart = calendar.startOfDay(for: budget.startDate)
            let targetDay   = calendar.startOfDay(for: date)
            let daysDiff    = calendar.dateComponents([.day],
                                                      from: budgetStart,
                                                      to: targetDay).day ?? 0

            // If `date` is before the budget started, the start IS the budget start.
            if daysDiff < 0 { return budgetStart }

            let daysIntoCycle = daysDiff % len
            return calendar.date(byAdding: .day,
                                  value: -daysIntoCycle,
                                  to: targetDay) ?? targetDay

        // ── Monthly ───────────────────────────────────────────────────────
        // UPDATED: uses the day component of budget.startDate as the reset day.
        // Capped at 28 to be valid in February and other short months.
        //
        // Example A: startDate = March 1  → resets on the 1st of each month
        // Example B: startDate = March 15 → resets on the 15th of each month
        // Example C: startDate = March 31 → resets on the 28th (safe cap)
        case .monthly:
            let resetDay = min(max(calendar.component(.day, from: budget.startDate), 1), 28)

            // Build a candidate date: the resetDay of the same month as `date`.
            var comps = calendar.dateComponents([.year, .month], from: date)
            comps.day = resetDay

            guard let thisMonthReset = calendar.date(from: comps) else {
                // Fallback: return the 1st of the current month if date construction fails.
                comps.day = 1
                return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
            }

            if thisMonthReset <= date {
                // This month's reset day has already passed (or is today) → it's the start.
                return thisMonthReset
            }

            // The reset day this month is in the future → the cycle started last month.
            var prevComps  = comps
            prevComps.month! -= 1   // Calendar handles December → November etc.
            return calendar.date(from: prevComps) ?? thisMonthReset

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

            if daysDiff < 0 { return budgetStart }

            let cycleNumber = daysDiff / len
            return calendar.date(byAdding: .day,
                                  value: cycleNumber * len,
                                  to: budgetStart) ?? budgetStart
        }
    }

    /// Calculates the last moment of the cycle that starts on `startDate`.
    ///
    /// For monthly budgets the end is one second before the same reset
    /// day in the following month. This keeps monthly cycles exactly
    /// one calendar month long regardless of how many days are in the month.
    static func cycleEndDate(for budget: Budget, startDate: Date) -> Date {
        let calendar = Calendar.current

        switch budget.cycleType {

        case .daily:
            // End of the same day: 23:59:59.
            return endOfDay(startDate, calendar: calendar)

        // UPDATED: uses cycleLengthInDays - 1 instead of hardcoded 6.
        case .weekly:
            let len     = max(budget.cycleLengthInDays, 1)
            let lastDay = calendar.date(byAdding: .day, value: len - 1, to: startDate)!
            return endOfDay(lastDay, calendar: calendar)

        // UPDATED: end is one second before the SAME reset day next month.
        //
        // Example: cycle starts March 15 → next cycle starts April 15 →
        //          end = April 15 00:00:00 - 1 second = April 14 23:59:59
        //
        // When resetDay is 1 this is identical to the previous behaviour:
        //   April 1 00:00:00 - 1s = March 31 23:59:59 ✓
        case .monthly:
            // The next cycle start is the same day, one month later.
            var nextComps        = calendar.dateComponents([.year, .month, .day], from: startDate)
            nextComps.month!    += 1   // Calendar rolls December over to January correctly.
            nextComps.hour       = 0
            nextComps.minute     = 0
            nextComps.second     = 0

            if let nextCycleStart = calendar.date(from: nextComps) {
                return nextCycleStart.addingTimeInterval(-1)
            }

            // Fallback: end of the current calendar month.
            var fallback        = calendar.dateComponents([.year, .month], from: startDate)
            fallback.month!    += 1
            return (calendar.date(from: fallback) ?? startDate).addingTimeInterval(-1)

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
