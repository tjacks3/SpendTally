import SwiftData
import Foundation

/// A budget the user creates. It tracks a total amount and a time period.
/// The @Model macro turns this Swift class into a persistent database record.
@Model
final class Budget {
    
    // MARK: - Stored Properties
    // Every property here gets saved to disk automatically.
    
    var name: String           // e.g. "Groceries"
    var totalAmount: Double    // e.g. 500.00
    var period: String         // "daily", "weekly", or "monthly"
    var startDate: Date
    
    // @Relationship tells SwiftData that one Budget has many Expenses.
    // cascade means: when you delete a budget, all its expenses are deleted too.
    @Relationship(deleteRule: .cascade)
    var expenses: [Expense] = []
    
    // MARK: - Initializer
    
    init(name: String, totalAmount: Double, period: String, startDate: Date = .now) {
        self.name = name
        self.totalAmount = totalAmount
        self.period = period
        self.startDate = startDate
    }
    
    // MARK: - Computed Properties
    // These are NOT stored in the database — they're calculated on the fly.
    
    /// Sum of all expense amounts
    var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    /// How much money is left
    var remaining: Double {
        totalAmount - totalSpent
    }
    
    /// Progress from 0.0 (nothing spent) to 1.0 (all spent)
    var progress: Double {
        guard totalAmount > 0 else { return 0 }
        return min(totalSpent / totalAmount, 1.0)
    }
    
    /// Returns true if the user has gone over budget
    var isOverBudget: Bool {
        remaining < 0
    }
    
    /// A human-readable label for the period
    var periodLabel: String {
        switch period {
        case "daily":   return "Today"
        case "weekly":  return "This Week"
        default:        return "This Month"
        }
    }
}
