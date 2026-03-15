import SwiftData
import SwiftUI
import Observation

/// Manages the state for creating and displaying budgets.
/// @Observable means SwiftUI will watch this object and update views automatically.
@Observable
final class BudgetViewModel {
    
    // MARK: - Form State (used in CreateBudgetView)
    var newBudgetName: String = ""
    var newBudgetAmount: String = ""
    var newBudgetPeriod: String = "monthly"
    
    // Available period options
    let periods: [String] = ["daily", "weekly", "monthly"]
    
    // Validation — the create button is only active when both fields are filled.
    var isFormValid: Bool {
        !newBudgetName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(newBudgetAmount) != nil &&
        Double(newBudgetAmount)! > 0
    }
    
    // MARK: - Actions
    
    /// Creates a new Budget and inserts it into the SwiftData context.
    /// The context is like a "staging area" — call context.insert() to stage a new record,
    /// and SwiftData auto-saves it when the app moves to the background.
    func createBudget(context: ModelContext) {
        guard isFormValid, let amount = Double(newBudgetAmount) else { return }
        
        let budget = Budget(
            name: newBudgetName.trimmingCharacters(in: .whitespaces),
            totalAmount: amount,
            period: newBudgetPeriod
        )
        context.insert(budget)
        resetForm()
    }
    
    /// Deletes budgets at the given index offsets (used by swipe-to-delete).
    func deleteBudgets(at offsets: IndexSet, from budgets: [Budget], context: ModelContext) {
        for index in offsets {
            context.delete(budgets[index])
        }
    }
    
    // MARK: - Private Helpers
    
    private func resetForm() {
        newBudgetName = ""
        newBudgetAmount = ""
        newBudgetPeriod = "monthly"
    }
}
