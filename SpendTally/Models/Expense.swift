import SwiftData
import Foundation

/// A single expense. Now belongs to a BudgetCycle, not directly to a Budget.
///
/// WHY: Attaching expenses to a cycle (not the budget) is what makes
/// history possible. When you ask "what did I spend in January?",
/// you query the January BudgetCycle's expenses — not the entire budget.
@Model
final class Expense {

    // MARK: - Stored Properties

    var amount: Double
    var note: String
    var date: Date
    var receiptImageData: Data?

    // MARK: - Relationship

    /// The specific time window this expense belongs to.
    /// This is the KEY change from the original model.
    /// Previously: var budget: Budget?
    /// Now:        var budgetCycle: BudgetCycle?
    var budgetCycle: BudgetCycle?

    // MARK: - Initializer

    init(amount: Double, note: String, date: Date = .now) {
        self.amount = amount
        self.note = note
        self.date = date
    }
}
