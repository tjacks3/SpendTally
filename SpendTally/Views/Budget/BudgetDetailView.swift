// ============================================================
// FILE:   BudgetDetailView.swift
// LOCATION: SpendTally/Views/Budget/BudgetDetailView.swift
//
// ACTION: REPLACE EXISTING FILE
//   1. Open SpendTally/Views/Budget/BudgetDetailView.swift
//   2. Select all (Cmd+A) and delete
//   3. Paste this entire file in
//
// WHAT CHANGED vs. the previous version:
//   • Added @State var selectedExpense: Expense?
//     This acts as the "edit target" — setting it to any expense
//     opens EditExpenseView in a sheet.
//   • Each ExpenseRowView is now wrapped in a Button (plain style)
//     so the row becomes tappable. A trailing chevron hint
//     reinforces the tap affordance without cluttering the layout.
//   • A .sheet(item: $selectedExpense) at the view root presents
//     EditExpenseView for whichever expense was tapped.
//   • No other logic was changed — date grouping, hero section,
//     swipe-to-delete, and progress bar are all identical.
// ============================================================

import SwiftUI
import SwiftData

struct BudgetDetailView: View {

    @Bindable var budget: Budget

    // ── Sheet triggers ───────────────────────────────────────────────────────
    @State private var showingAddExpense  = false
    /// Set to a non-nil Expense to open EditExpenseView for that expense.
    @State private var selectedExpense: Expense?

    // MARK: - Body

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
        // ── Add expense sheet ────────────────────────────────────────────────
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(budget: budget)
        }
        // ── Edit expense sheet ───────────────────────────────────────────────
        // .sheet(item:) automatically presents when selectedExpense becomes
        // non-nil and dismisses (and nils it out) when the sheet is closed.
        // Expense is Identifiable via SwiftData's @Model, so this just works.
        .sheet(item: $selectedExpense) { expense in
            EditExpenseView(expense: expense)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 6) {
            Text(budget.isOverBudget ? "Over Budget" : "Remaining \(budget.periodLabel)")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)

            // Large split number: $292.50 rendered as "$" + "292" + ".50"
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

            HStack(spacing: 24) {
                miniStat(label: "Budget", value: budget.totalAmount, color: .secondary)
                miniStat(label: "Spent",  value: budget.totalSpent,  color: .orange)
            }
            .padding(.top, 4)

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
        let value     = abs(budget.remaining)
        let formatted = String(format: "%.2f", value)
        let parts     = formatted.split(separator: ".")
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
                        ForEach(Array(group.expenses.enumerated()),
                                id: \.element.id) { index, expense in

                            // ── Tappable expense row ─────────────────────────
                            // The entire row is a Button so the user can tap
                            // anywhere on it to open the expense editor.
                            // .plain style preserves the custom ExpenseRowView
                            // appearance — no default button highlighting.
                            Button {
                                selectedExpense = expense
                            } label: {
                                HStack(spacing: 0) {
                                    ExpenseRowView(expense: expense)

                                    // Chevron — a standard iOS affordance that
                                    // signals "tap me to see more / edit".
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(.tertiaryLabel))
                                        .padding(.trailing, 20)
                                }
                                .background(Color(.systemBackground))
                                // contentShape makes the entire row (including
                                // whitespace) respond to taps, not just the text.
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

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

    // MARK: - Empty State

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

    // MARK: - Section Header

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
        let label:    String
        let expenses: [Expense]
        var total:    Double { expenses.reduce(0) { $0 + $1.amount } }
    }

    private var groupedExpenses: [ExpenseGroup] {
        let sorted   = budget.expenses.sorted { $0.date > $1.date }
        let calendar = Calendar.current
        var groupMap: [String: [Expense]] = [:]
        var order:    [String] = []

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
        let schema = Schema([Budget.self, Expense.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext

        let budget = Budget(name: "Groceries", totalAmount: 500, period: "monthly")
        ctx.insert(budget)

        let samples: [(Double, String, Int)] = [
            (24.99, "Whole Foods run", 0),
            (4.75,  "Coffee",          0),
            (3.35,  "Pet treats",      0),
            (39.75, "Jeff's birthday gift", -1),
            (12.50, "Lunch",           -1),
            (89.00, "Weekly shop",     -3),
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
