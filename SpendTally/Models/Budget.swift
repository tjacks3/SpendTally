import SwiftData
import Foundation

/// A Budget defines the *rules* for spending — the name, amount, and
/// how often it resets. It does NOT track spending directly.
///
/// Think of Budget as a template: "I want to spend $500 each month
/// on groceries." The actual spending lives inside BudgetCycle records.
@Model
final class Budget {

    // MARK: - Stored Properties

    var name: String            // "Groceries"
    var totalAmount: Double     // 500.00
    var cycleType: CycleType    // .monthly
    var cycleLengthInDays: Int  // used for .weekly and .custom
    var startDate: Date         // when the first cycle begins
    var isRecurring: Bool       // if false, only one cycle is ever created
    var isPaused: Bool          // no new cycles created while paused
    var createdAt: Date

    // MARK: - Relationship

    /// All cycles that belong to this budget.
    /// cascade: deleting the budget deletes all its cycles (and their expenses).
    /// inverse: tells SwiftData that BudgetCycle.budget is the other side.
    @Relationship(deleteRule: .cascade, inverse: \BudgetCycle.budget)
    var cycles: [BudgetCycle] = []

    // MARK: - Initializer

    init(
        name: String,
        totalAmount: Double,
        cycleType: CycleType = .monthly,
        cycleLengthInDays: Int? = nil,
        startDate: Date = .now,
        isRecurring: Bool = true
    ) {
        self.name = name
        self.totalAmount = totalAmount
        self.cycleType = cycleType
        // If not provided, use the cycle type's default
        self.cycleLengthInDays = cycleLengthInDays ?? cycleType.defaultLengthInDays
        self.startDate = startDate
        self.isRecurring = isRecurring
        self.isPaused = false
        self.createdAt = .now
    }

    // MARK: - Computed Helpers

    /// The cycle that contains today's date, if one exists.
    /// Views should call CycleManager.getOrCreateCurrentCycle() to
    /// also create it if it doesn't exist yet.
    var currentCycle: BudgetCycle? {
        let now = Date.now
        return cycles.first { $0.startDate <= now && now <= $0.endDate }
    }

    /// All cycles sorted newest-first (for history lists).
    var sortedCycles: [BudgetCycle] {
        cycles.sorted { $0.startDate > $1.startDate }
    }

    /// Convenience: how much is left in the active cycle.
    var currentRemaining: Double {
        currentCycle?.remainingAmount ?? totalAmount
    }

    /// Convenience: is the current cycle over budget?
    var isCurrentlyOverBudget: Bool {
        currentCycle?.isOver ?? false
    }

    /// A human-readable label for the cycle period
    var periodLabel: String {
        switch cycleType {
        case .daily:   return "Today"
        case .weekly:  return "This Week"
        case .monthly: return "This Month"
        case .custom:  return "This Period"
        }
    }
}
