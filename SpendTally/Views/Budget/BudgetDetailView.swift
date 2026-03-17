import SwiftUI
import SwiftData

struct BudgetDetailView: View {

    @Bindable var budget: Budget
    @State private var showingAddExpense = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                expenseSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(budget.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExpense = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Color.primary)
                        .foregroundStyle(Color(.systemBackground))
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(budget: budget)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 6) {
            Text(budget.isOverBudget ? "Over Budget" : "Remaining \(budget.periodLabel)")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)

            // Large split number display: $292.50 → "$", "292", ".50"
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("$")
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .foregroundStyle(budget.isOverBudget ? .red : .primary)

                Text(balanceParts.integer)
                    .font(.system(size: 76, weight: .thin, design: .rounded))
                    .foregroundStyle(budget.isOverBudget ? .red : .primary)

                Text(".\(balanceParts.decimal)")
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .foregroundStyle(budget.isOverBudget ? .red : .primary)
                    .baselineOffset(4)
            }

            // Spent / Budget pills
            HStack(spacing: 24) {
                miniStat(label: "Budget", value: budget.totalAmount, color: .secondary)
                miniStat(label: "Spent", value: budget.totalSpent, color: .orange)
            }
            .padding(.top, 4)

            // Progress bar
            ProgressView(value: budget.progress)
                .tint(budget.isOverBudget ? .red : .accentColor)
                .padding(.horizontal, 40)
                .padding(.top, 10)

            if budget.isOverBudget {
                Text("Over by \(abs(budget.remaining), format: .currency(code: "USD"))")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 28)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    private var balanceParts: (integer: String, decimal: String) {
        let value = abs(budget.remaining)
        let formatted = String(format: "%.2f", value)
        let parts = formatted.split(separator: ".")
        return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "00")
    }

    private func miniStat(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value, format: .currency(code: "USD"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Expense Section

    private var expenseSection: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            if budget.expenses.isEmpty {
                emptyState
            } else {
                ForEach(groupedExpenses, id: \.label) { group in
                    Section {
                        ForEach(Array(group.expenses.enumerated()), id: \.element.id) { index, expense in
                            ExpenseRowView(expense: expense)
                                .background(Color(.systemBackground))

                            // Divider indented to align under text, not icon
                            if index < group.expenses.count - 1 {
                                Divider()
                                    .padding(.leading, 76)
                                    .background(Color(.systemBackground))
                            }
                        }
                        .onDelete { offsets in
                            deleteExpenses(at: offsets, from: group.expenses)
                        }
                    } header: {
                        sectionHeader(label: group.label, total: group.total)
                    }
                }
            }
        }
        .padding(.top, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
            Text("No expenses yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Tap + to record your first expense")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(Color(.systemBackground))
    }

    private func sectionHeader(label: String, total: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(total, format: .currency(code: "USD"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Date Grouping

    private struct ExpenseGroup {
        let label: String
        let expenses: [Expense]
        var total: Double { expenses.reduce(0) { $0 + $1.amount } }
    }

    private var groupedExpenses: [ExpenseGroup] {
        let sorted = budget.expenses.sorted { $0.date > $1.date }
        let calendar = Calendar.current
        var groupMap: [String: [Expense]] = [:]
        var order: [String] = []

        for expense in sorted {
            let key: String
            if calendar.isDateInToday(expense.date) {
                key = "Today"
            } else if calendar.isDateInYesterday(expense.date) {
                key = "Yesterday"
            } else {
                let df = DateFormatter()
                df.dateFormat = "MMMM d"
                key = df.string(from: expense.date)
            }

            if groupMap[key] == nil {
                groupMap[key] = []
                order.append(key)
            }
            groupMap[key]!.append(expense)
        }

        return order.map { ExpenseGroup(label: $0, expenses: groupMap[$0]!) }
    }

    // MARK: - Delete

    private func deleteExpenses(at offsets: IndexSet, from expenses: [Expense]) {
        for index in offsets {
            if let i = budget.expenses.firstIndex(where: { $0.id == expenses[index].id }) {
                budget.expenses.remove(at: i)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    do {
        // Explicit Schema prevents "SwiftDataError error 1" in the Xcode canvas.
        let schema = Schema([Budget.self, Expense.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext

        let budget = Budget(name: "Groceries", totalAmount: 500, period: "monthly")
        ctx.insert(budget)

        let samples: [(Double, String, Int)] = [
            (24.99, "Whole Foods run", 0),
            (4.75,  "Coffee", 0),
            (3.35,  "Pet treats", 0),
            (39.75, "Jeff's birthday gift", -1),
            (12.50, "Lunch", -1),
            (89.00, "Weekly shop", -3),
        ]
        for (amount, note, daysAgo) in samples {
            let date = Calendar.current.date(byAdding: .day, value: daysAgo, to: .now)!
            let e = Expense(amount: amount, note: note, date: date)
            e.budget = budget
            budget.expenses.append(e)
            ctx.insert(e)
        }

        return NavigationStack {
            BudgetDetailView(budget: budget)
        }
        .modelContainer(container)
    } catch {
        return Text("Preview failed: \(error.localizedDescription)")
    }
}
