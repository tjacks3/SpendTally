import SwiftData
import SwiftUI
import Observation

@Observable
final class BudgetViewModel {

    // MARK: - Form State

    var newBudgetName: String     = ""
    var newBudgetAmount: String   = ""
    var newBudgetCycleType: CycleType = .monthly
    var newBudgetCustomDays: String   = "14"

    // Validation
    var isFormValid: Bool {
        let nameOK   = !newBudgetName.trimmingCharacters(in: .whitespaces).isEmpty
        let amountOK = (Double(newBudgetAmount) ?? 0) > 0
        let daysOK   = newBudgetCycleType != .custom ||
                       (Int(newBudgetCustomDays) ?? 0) > 0
        return nameOK && amountOK && daysOK
    }

    // MARK: - Actions

    func createBudget(context: ModelContext) {
        guard isFormValid, let amount = Double(newBudgetAmount) else { return }

        let cycleLength = newBudgetCycleType == .custom
            ? (Int(newBudgetCustomDays) ?? 14)
            : newBudgetCycleType.defaultLengthInDays

        let budget = Budget(
            name: newBudgetName.trimmingCharacters(in: .whitespaces),
            totalAmount: amount,
            cycleType: newBudgetCycleType,
            cycleLengthInDays: cycleLength,
            startDate: .now,
            isRecurring: true
        )
        context.insert(budget)

        // Create the first cycle immediately so the UI has something to show
        CycleEngine.ensureActiveCycleExists(for: budget, context: context)

        resetForm()
    }

    func deleteBudgets(at offsets: IndexSet,
                       from budgets: [Budget],
                       context: ModelContext) {
        for index in offsets {
            context.delete(budgets[index])
        }
    }

    // MARK: - Helpers

    private func resetForm() {
        newBudgetName       = ""
        newBudgetAmount     = ""
        newBudgetCycleType  = .monthly
        newBudgetCustomDays = "14"
    }
}
