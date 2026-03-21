import SwiftData
import Foundation

/// The status of a cycle — computed from whether it's active and whether
/// spending has exceeded the limit.
enum CycleStatus: String, Codable {
    case onTrack = "onTrack"  // active, within budget
    case over    = "over"     // active OR ended, spending exceeded limit
    case under   = "under"    // ended, came in under budget (success!)
}

/// A BudgetCycle is one time window of a Budget — e.g. "January 2026".
///
/// When a monthly budget resets on Feb 1, a new BudgetCycle is created for
/// February. The January cycle is preserved forever as history.
///
/// Key design decision: totalAmount is COPIED from Budget at cycle creation.
/// This means if the user changes their grocery budget from $500 → $600 in
/// March, January and February cycles still correctly show $500. History
/// is never corrupted by future changes.
@Model
final class BudgetCycle {

    // MARK: - Stored Properties

    var startDate: Date
    var endDate: Date

    /// Copied from Budget.totalAmount at creation time.
    /// Preserved even if the parent budget's amount changes later.
    var totalAmount: Double

    // MARK: - Relationships

    /// The budget this cycle belongs to. Optional because SwiftData
    /// inverse relationships are always optional.
    var budget: Budget?

    /// All expenses logged during this time window.
    /// cascade: deleting the cycle deletes all its expenses.
    @Relationship(deleteRule: .cascade, inverse: \Expense.budgetCycle)
    var expenses: [Expense] = []

    // MARK: - Initializer

    init(budget: Budget, startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
        // Snapshot the budget amount so history is accurate
        self.totalAmount = budget.totalAmount
    }

    // MARK: - Computed Properties
    // These are derived from the expenses relationship — no sync issues.

    /// Total of all expense amounts in this cycle.
    var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    /// How much budget is left.
    var remainingAmount: Double {
        totalAmount - totalSpent
    }

    /// How many expenses have been logged.
    var transactionCount: Int {
        expenses.count
    }

    /// True if today falls within this cycle's date range.
    var isActive: Bool {
        let now = Date.now
        return startDate <= now && now <= endDate
    }

    /// True if spending has exceeded the limit.
    var isOver: Bool {
        remainingAmount < 0
    }

    /// Progress from 0.0 (nothing spent) to 1.0 (fully spent).
    var progress: Double {
        guard totalAmount > 0 else { return 0 }
        return min(totalSpent / totalAmount, 1.0)
    }

    /// Human-readable status for this cycle.
    var status: CycleStatus {
        if isActive {
            return isOver ? .over : .onTrack
        } else {
            return isOver ? .over : .under
        }
    }

    /// A display label for the cycle's date range.
    /// Examples: "Jan 2026", "Week of Mar 10", "Today"
    var displayLabel: String {
        let formatter = DateFormatter()
        if isActive {
            if Calendar.current.isDateInToday(startDate) {
                return "Today"
            }
            formatter.dateFormat = "MMM d"
            return "Week of \(formatter.string(from: startDate))"
        }
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: startDate)
    }
}
