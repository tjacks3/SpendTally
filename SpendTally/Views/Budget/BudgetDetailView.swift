import SwiftUI
import SwiftData

struct BudgetDetailView: View {
    
    // @Bindable lets us read and write to this SwiftData model directly from the view.
    @Bindable var budget: Budget
    
    @State private var showingAddExpense = false
    
    var body: some View {
        List {
            // Summary card at the top
            Section {
                summaryCard
            }
            
            // Expense list
            Section("Expenses") {
                if budget.expenses.isEmpty {
                    Text("No expenses yet. Tap + to add one.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    // Sort expenses newest first
                    ForEach(budget.expenses.sorted(by: { $0.date > $1.date })) { expense in
                        ExpenseRowView(expense: expense)
                    }
                    .onDelete { offsets in
                        deleteExpenses(at: offsets)
                    }
                }
            }
        }
        .navigationTitle(budget.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Expense", systemImage: "plus") {
                    showingAddExpense = true
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(budget: budget)
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                statView(
                    label: "Budget",
                    amount: budget.totalAmount,
                    color: .primary
                )
                Spacer()
                statView(
                    label: "Spent",
                    amount: budget.totalSpent,
                    color: .orange
                )
                Spacer()
                statView(
                    label: "Left",
                    amount: budget.remaining,
                    color: budget.isOverBudget ? .red : .green
                )
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: budget.progress)
                    .tint(budget.isOverBudget ? .red : .accentColor)
                
                if budget.isOverBudget {
                    Text("Over budget by \(abs(budget.remaining), format: .currency(code: "USD"))")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func statView(label: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount, format: .currency(code: "USD"))
                .font(.headline)
                .foregroundStyle(color)
        }
    }
    
    // MARK: - Delete
    
    private func deleteExpenses(at offsets: IndexSet) {
        let sorted = budget.expenses.sorted(by: { $0.date > $1.date })
        for index in offsets {
            if let expenseIndex = budget.expenses.firstIndex(where: { $0.id == sorted[index].id }) {
                budget.expenses.remove(at: expenseIndex)
            }
        }
    }
}
